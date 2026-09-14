// Transactional email via Resend (fetch, no extra deps).
// If RESEND_API_KEY is unset, emails are logged and skipped — never crash.
const db = require('../lib/db');
const { decrypt } = require('../encryption');

const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const EMAIL_FROM = process.env.EMAIL_FROM || 'Meowmin <hello@meowmin.taucity.xyz>';
const PUBLIC_WEB_URL = (process.env.PUBLIC_WEB_URL || 'https://meowmin.taucity.xyz').replace(/\/$/, '');

function esc(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function sendEmail({ to, subject, html }) {
  if (!RESEND_API_KEY) {
    console.log('[email] RESEND_API_KEY unset — skipping send', { to, subject });
    return { ok: false, skipped: true };
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: EMAIL_FROM, to, subject, html }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Resend failed (${res.status}): ${body.slice(0, 300)}`);
  }
  return { ok: true, skipped: false, id: (await res.json().catch(() => ({}))).id };
}

function continueLink(email, tok) {
  return `${PUBLIC_WEB_URL}/pricing?email=${encodeURIComponent(email)}&tok=${encodeURIComponent(tok)}`;
}

// Latest journal + AI insight for the delight email. Prefers the client
// snapshot (onboarding journal may not have synced yet), falls back to DB.
async function delightData(uid, snapshot) {
  const out = {
    intention: snapshot?.intention || null,
    journalExcerpt: snapshot?.journalExcerpt || null,
    insights: Array.isArray(snapshot?.insights) ? snapshot.insights.slice(0, 3) : [],
    verse: snapshot?.verse || null,
    timeSpent: snapshot?.timeSpent || null,
  };
  if (!out.journalExcerpt) {
    try {
      const j = await db.execute({
        sql: 'SELECT id, content FROM journal_entries WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
        args: [uid],
      });
      const row = j.rows[0];
      if (row) {
        try { out.journalExcerpt = String(decrypt(row.content, uid)).slice(0, 280); } catch (_) {}
        const ai = await db.execute({
          sql: 'SELECT summary, quote, reference FROM journal_ai WHERE journal_id = ?',
          args: [row.id],
        });
        const aiRow = ai.rows[0];
        if (aiRow && out.insights.length === 0) {
          try {
            const parsed = JSON.parse(decrypt(aiRow.summary, uid));
            const cards = Array.isArray(parsed) ? parsed : parsed.cards || [];
            out.insights = cards.slice(0, 3).map((c) => c.text || c.title || '').filter(Boolean);
          } catch (_) {
            if (aiRow.quote) out.insights = [String(aiRow.quote)];
          }
          if (!out.verse && aiRow.reference) out.verse = { reference: String(aiRow.reference) };
        }
      }
    } catch (e) {
      console.error('[email] delight fallback query failed:', e.message);
    }
  }
  return out;
}

function delightHtml({ name, email, tok, d }) {
  const link = continueLink(email, tok);
  const first = esc((name || 'friend').split(' ')[0]);
  const cards = d.insights.map((t) => `<li style="margin:6px 0;">${esc(t)}</li>`).join('');
  const verse = d.verse
    ? `<div style="background:#f6f1e7;border-radius:12px;padding:16px;margin:16px 0;">
         ${d.verse.arabic ? `<p dir="rtl" style="font-size:20px;margin:0 0 8px;">${esc(d.verse.arabic)}</p>` : ''}
         ${d.verse.transliteration ? `<p style="font-style:italic;color:#6b5f4c;margin:0 0 8px;">${esc(d.verse.transliteration)}</p>` : ''}
         ${d.verse.english ? `<p style="margin:0 0 8px;">${esc(d.verse.english)}</p>` : ''}
         ${d.verse.reference ? `<p style="font-size:12px;color:#8a7f6a;margin:0;">${esc(d.verse.reference)}</p>` : ''}
       </div>`
    : '';
  const cta = (label) =>
    `<a href="${link}" style="display:inline-block;background:#1a0533;color:#fff;font-weight:700;padding:14px 28px;border-radius:14px;text-decoration:none;">${label}</a>`;
  return `<!doctype html><html><body style="font-family:sans-serif;color:#222;max-width:560px;margin:auto;padding:24px;">
    <div style="text-align:center;margin-bottom:8px;">
      <img src="${PUBLIC_WEB_URL}/images/face.png" alt="Meowmin" width="72" height="72" style="border-radius:50%;display:block;margin:auto;" />
    </div>
    <p>Assalamu alaikum ${first} 🌙</p>
    <p><strong>Your 3-day Meowmin trial is ready — finish setup (no card needed):</strong></p>
    <p>${cta('Continue setup — claim your trial →')}</p>
    <div style="border:2px solid #FACC15;border-radius:16px;padding:20px;margin:24px 0;background:#FFFDF4;">
      <h2 style="margin:0 0 4px;">✨ Your Spiritual Profile</h2>
      ${d.intention ? `<p><em>"${esc(d.intention)}"</em> — your intention, day 1.</p>` : ''}
      <p>🔥 Streak: day 1 &nbsp;·&nbsp; ⏱️ ${esc(d.timeSpent || 'a few mindful minutes')} &nbsp;·&nbsp; 📖 Verses met: ${d.insights.length || 'once'}</p>
      ${verse}
      ${d.journalExcerpt ? `<p style="border-left:3px solid #9D50FF;padding-left:12px;color:#444;">" ${esc(d.journalExcerpt)} "</p><p style="font-size:12px;color:#888;">— your first journal entry</p>` : ''}
      ${cards ? `<p><strong>What the Quran said back:</strong></p><ul>${cards}</ul>` : ''}
    </div>
    <p>${cta('Keep walking — pick your pace →')}</p>
    <p style="font-size:12px;color:#888;">No card needed for the trial. Questions? reply to this email or write to contact@taucity.xyz.</p>
  </body></html>`;
}

// Value recap for Max members: what the subscription delivered — journals
// written, insights revealed, streak — plus plan/expiry context. Computed at
// SEND time (not enqueue) so the 24h-delayed job reflects settled stats.
async function maxRecapData(uid) {
  const d = { journals: 0, decksRevealed: 0, streak: 1, plan: null, expiresAt: null, name: null };
  try {
    const u = await db.execute({
      sql: 'SELECT display_name, subscription_product_id, subscription_expires_at FROM users WHERE id = ?',
      args: [uid],
    });
    const row = u.rows[0];
    if (!row) return d;
    d.name = row.display_name || null;
    d.plan = row.subscription_product_id || null;
    d.expiresAt = row.subscription_expires_at ?? null;
    const j = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM journal_entries WHERE user_id = ?`,
      args: [uid],
    });
    d.journals = Number(j.rows[0]?.n || 0);
    const r = await db.execute({
      sql: `SELECT COUNT(*) AS n FROM insight_decks WHERE user_id = ? AND status = 'revealed'`,
      args: [uid],
    });
    d.decksRevealed = Number(r.rows[0]?.n || 0);
    const s = await db.execute({
      sql: `SELECT COALESCE(streak, 0) AS streak FROM users WHERE id = ?`,
      args: [uid],
    });
    if (s.rows[0] && Number(s.rows[0].streak || 0) > 0) {
      d.streak = Math.max(1, Number(s.rows[0].streak));
    } else {
      const legacy = await db.execute({
        sql: `SELECT streak FROM streaks WHERE uid = ?`,
        args: [uid],
      });
      if (legacy.rows[0]) d.streak = Math.max(1, Number(legacy.rows[0].streak || 1));
    }
  } catch (e) {
    console.error('[email] maxRecapData failed:', e.message);
  }
  return d;
}

const MAX_RECAP_SUBJECT = 'Your Meowmin Max journey so far 🌙';

function maxRecapHtml({ name, email, d }) {
  const first = esc(((name || (email || 'friend').split('@')[0] || 'friend')).split(' ')[0]);
  const expiry = d.expiresAt
    ? `<p>Your plan renews ${d.plan ? `(${esc(d.plan)}) ` : ''}on <strong>${esc(new Date(d.expiresAt).toDateString())}</strong>. Cancel anytime — your journals stay yours.</p>`
    : '';
  const row = (big, small) =>
    `<td style="text-align:center;padding:12px 6px;"><div style="font-size:22px;font-weight:800;">${esc(String(big))}</div><div style="font-size:12px;color:#8a7f6a;">${esc(small)}</div></td>`;
  return `<!doctype html><html><body style="font-family:sans-serif;color:#222;max-width:560px;margin:auto;padding:24px;">
    <div style="text-align:center;margin-bottom:8px;">
      <img src="${PUBLIC_WEB_URL}/images/face.png" alt="Meowmin" width="72" height="72" style="border-radius:50%;display:block;margin:auto;" />
    </div>
    <p>Assalamu alaikum ${first} 🌙</p>
    <p><strong>Thank you for getting Max.</strong> Here is what your subscription delivered:</p>
    <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
      ${row(d.journals, 'journals written')}
      ${row(d.decksRevealed, 'insight decks revealed')}
      ${row(`${d.streak}-day`, 'streak')}
    </tr></table>
    <div style="background:#f6f1e7;border-radius:12px;padding:16px;margin:16px 0;">
      <p style="margin:0;">Keep walking — unlimited journaling, deeper streaks, and fresh insights queued every day. A calmer, closer you, one page at a time.</p>
    </div>
    ${expiry}
    <p style="font-size:12px;color:#888;">Questions? reply to this email or write to contact@taucity.xyz.</p>
  </body></html>`;
}

module.exports = { sendEmail, delightData, delightHtml, continueLink, esc, maxRecapData, maxRecapHtml, MAX_RECAP_SUBJECT };
