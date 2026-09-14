const db = require('../lib/db');
const { upsertUser, mergeUserStreak } = require('../lib/users');
const { upsertStreak, linkFriends, getFriendStreak, getFriendInfo } = require('../lib/invites');
const { syncStreakSchema, acceptInviteSchema } = require('../lib/validation');

module.exports = function (app) {
  app.post('/api/v2/streaks/sync', async (req, res) => {
    const parsed = syncStreakSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const uid = req.uid;
    try {
      await upsertUser(uid, null, null, null);
      // Primary store: users.streak (same table as stars/shields so restore
      // is one query). streaks table kept in sync for the email recap read.
      const today = new Date().toISOString().slice(0, 10);
      const merged = await mergeUserStreak(uid, parsed.data.streak, today);
      await upsertStreak(uid, merged.streak);
      res.json({ success: true, streak: merged.streak });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/v2/invites/accept', async (req, res) => {
    const parsed = acceptInviteSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Validation failed', details: parsed.error.flatten().fieldErrors });
    }
    const { inviterUid, myName, myCat } = parsed.data;
    const uid = req.uid;
    if (inviterUid === uid) {
      return res.status(400).json({ error: 'Cannot invite yourself' });
    }
    try {
      if (myName || myCat) {
        await upsertUser(uid, myName, null, myCat);
      }
      await linkFriends(uid, inviterUid);
      const inviter = await getFriendInfo(uid);
      res.json({
        success: true,
        inviter: inviter || { displayName: null, catName: null },
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/streaks/friend', async (req, res) => {
    const uid = req.uid;
    try {
      // Read from users (primary streak store); fall back to the legacy
      // streaks table for friendships whose users row predates the column.
      const result = await db.execute({
        sql: `
          SELECT u.streak, u.streak_date FROM users u
          WHERE u.id IN (
            SELECT user_b_uid FROM friendships WHERE user_a_uid = ?
            UNION
            SELECT user_a_uid FROM friendships WHERE user_b_uid = ?
          )
          ORDER BY u.streak_date DESC NULLS LAST
          LIMIT 1
        `,
        args: [uid, uid],
      });
      if (!result.rows.length || !(result.rows[0].streak > 0)) {
        const friend = await getFriendStreak(uid);
        if (!friend) return res.json({ linked: false });
        return res.json({ linked: true, streak: friend.streak, updatedAt: friend.updatedAt });
      }
      res.json({ linked: true, streak: Number(result.rows[0].streak), updatedAt: result.rows[0].streak_date });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/v2/friends/info', async (req, res) => {
    const uid = req.uid;
    try {
      const friend = await getFriendInfo(uid);
      if (!friend) return res.json({ linked: false });
      res.json({ linked: true, uid: friend.uid, displayName: friend.displayName, catName: friend.catName });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
};
