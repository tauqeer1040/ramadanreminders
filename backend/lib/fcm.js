const admin = require('firebase-admin');

/**
 * Send a reminder push (data-only) to one FCM token.
 *
 * Data-only (no `notification` block): Android delivers it straight to the
 * app's onBackgroundMessage even when backgrounded/killed, and the app
 * renders locally through the meowmin_notifications package — so copy comes
 * from native prefs (cat name + name) and delivery is deduped against the
 * alarm chain day-keyed.
 */
async function sendReminderPush(token, kind) {
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
