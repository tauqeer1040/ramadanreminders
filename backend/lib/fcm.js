const { isWorker } = require('./runtime');

/**
 * Send a reminder push (data-only) to one FCM token.
 *
 * Data-only (no `notification` block): Android delivers it straight to the
 * app's onBackgroundMessage even when backgrounded/killed, and the app
 * renders locally through the meowmin_notifications package — so copy comes
 * from native prefs (cat name + name) and delivery is deduped against the
 * alarm chain day-keyed.
 *
 * NOTE: firebase-admin (google-auth-library → gcp-metadata →
 * google-logging-utils) requires bare `node:process` at module-eval time,
 * which workerd does not provide — a top-level require here took down ALL
 * /api/* with Cloudflare 1101 (see [Worker boot failed] logs). The require
 * is therefore lazy AND never executed on Workers; server-side sends run
 * from VPS/CI/cron only.
 */
async function sendReminderPush(token, kind) {
  // TEMP-DISABLED on Workers (reminder-push approved off): firebase-admin
  // cannot evaluate on workerd. The cron hits /internal/send-reminders which
  // is itself 503 on Workers, so this is a second guard, not the primary.
  if (isWorker()) {
    console.warn('[FCM] skipped on Workers (reminder-push temporarily disabled)');
    return false;
  }
  let admin;
  try {
    admin = require('firebase-admin');
  } catch (error) {
    console.warn('[FCM] firebase-admin unavailable:', error?.message || error);
    return false;
  }
  try {
    await admin.messaging().send({
      token,
      android: { priority: 'high' },
      data: {
        type: 'reminder',
        kind, // 'morning' | 'night'
      },
    });
    return true;
  } catch (error) {
    // Token revoked (app uninstalled), unregistered, or invalid → tell the
    // caller so the row can be removed.
    const code = error?.errorInfo?.code || '';
    if (
      code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token' ||
      code === 'messaging/invalid-argument'
    ) {
      return { dead: true };
    }
    console.warn('[FCM] send failed:', error?.message || error);
    return false;
  }
}

module.exports = { sendReminderPush };
