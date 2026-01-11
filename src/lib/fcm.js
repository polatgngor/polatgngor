const fcmService = require('../services/fcmService');

/**
 * Proxy function to usage new robust FCMService
 * This replaces the old legacy implementation to ensure we use Dual-Project logic
 */
async function sendPushToTokens(tokens, notification, data = {}) {
  if (!tokens || tokens.length === 0) return;

  const title = notification ? notification.title : null;
  const body = notification ? notification.body : null;

  let successCount = 0;
  let failureCount = 0;

  // Execute in parallel
  const promises = tokens.map(async (token) => {
    try {
      const result = await fcmService.sendNotification(token, title, body, data);
      if (result) successCount++;
      else failureCount++;
    } catch (err) {
      console.error('[lib/fcm] Wrapper error:', err);
      failureCount++;
    }
  });

  await Promise.all(promises);
  console.log(`[fcm-proxy] Finished. Success: ${successCount}, Failure: ${failureCount}`);
}

// Deprecated but kept for compatibility if called explicitly, though we use the service now
function initFirebase() {
  // no-op, service handles this
}

module.exports = {
  sendPushToTokens,
  initFirebase
};