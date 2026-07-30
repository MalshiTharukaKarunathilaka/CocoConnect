const config = require('../config');

/** Firebase push stub — same idea as the Spring version. */
function sendPush(fcmToken, title, body) {
  if (!fcmToken) {
    console.log(`[Push skipped] no FCM token — title=${title}`);
    return;
  }
  if (!config.firebaseEnabled) {
    console.log(`[Firebase DEMO push] token=${fcmToken} title=${title} body=${body}`);
    return;
  }
  console.warn(`[Firebase] enabled=true but Admin SDK not wired yet — token=${fcmToken}`);
}

module.exports = { sendPush };
