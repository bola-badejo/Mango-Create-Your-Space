const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

const functions = require("firebase-functions");
const fetch = require("node-fetch");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Helper: Send to multiple tokens (supports array of tokens)
async function sendToTokens(tokens, payload) {
  if (!tokens || tokens.length === 0) return null;
  try {
    // Send in batches of 500 (FCM limit)
    const batchSize = 500;
    const results = [];
    for (let i = 0; i < tokens.length; i += batchSize) {
      const batch = tokens.slice(i, i + batchSize);
      const result = await messaging.sendEachForMulticast({ tokens: batch, ...payload });
      results.push(result);
    }
    return results;
  } catch (err) {
    logger.error("sendToTokens error:", err);
    return null;
  }
}

// Helper: Send notification to a single user (supports multiple devices)
async function sendNotificationToUser(userId, title, body, data = {}) {
  if (!userId) return null;
  try {
    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) {
      logger.warn(`User not found: ${userId}`);
      return null;
    }
    
    const userData = userSnap.data();
    
    // Check notification settings
    const notificationsEnabled = userData.notificationsEnabled !== false;
    if (!notificationsEnabled) {
      logger.info(`Notifications disabled for ${userId}`);
      return null;
    }
    
    // Check mute
    const muteUntil = userData.muteUntil;
    if (muteUntil && muteUntil.toDate() > new Date()) {
      logger.info(`Notifications muted for ${userId} until ${muteUntil.toDate()}`);
      return null;
    }
    
    // Get all FCM tokens (support multiple devices)
    let tokens = [];
    if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
      tokens = userData.fcmTokens;
    } else if (userData.fcmToken) {
      tokens = [userData.fcmToken];
    }
    
    if (tokens.length === 0) {
      logger.warn(`No FCM tokens for user: ${userId}`);
      return null;
    }
    
    const payload = {
      notification: { title, body },
      data: data,
      webpush: {
        fcmOptions: {
          link: `https://yourdomain.com/${data.type || ''}/${data[`${data.type}Id`] || ''}`,
        },
      },
    };
    
    // Send to all devices
    const results = await sendToTokens(tokens, payload);
    logger.info(`Notification sent to ${userId} on ${tokens.length} devices`);
    return results;
    
  } catch (err) {
    logger.error("sendNotificationToUser error:", err);
    return null;
  }
}

// ==================== CHAT NOTIFICATION ====================
exports.sendChatNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const notification = event.data.data();
    if (!notification) return;

    const { receiverId, senderId, senderName, title, body, data } = notification;

    logger.info(`📨 New chat notification from ${senderId} to ${receiverId}`);

    try {
      const receiverDoc = await db.collection("users").doc(receiverId).get();
      if (!receiverDoc.exists) {
        logger.warn(`❌ Receiver not found: ${receiverId}`);
        return;
      }

      const receiverData = receiverDoc.data();
      
      // Check notification settings
      const notificationsEnabled = receiverData.notificationsEnabled !== false;
      if (!notificationsEnabled) {
        logger.info(`🔕 Notifications disabled for ${receiverId}`);
        return;
      }

      // Check mute
      const muteUntil = receiverData.muteUntil;
      if (muteUntil && muteUntil.toDate() > new Date()) {
        logger.info(`🔇 Notifications muted until ${muteUntil.toDate()}`);
        return;
      }

      // Get all FCM tokens
      let tokens = [];
      if (receiverData.fcmTokens && Array.isArray(receiverData.fcmTokens)) {
        tokens = receiverData.fcmTokens;
      } else if (receiverData.fcmToken) {
        tokens = [receiverData.fcmToken];
      }

      if (tokens.length === 0) {
        logger.warn(`⚠️ No FCM tokens for receiver: ${receiverId}`);
        
        // Update notification as failed
        await event.data.ref.update({
          'status': 'failed',
          'error': 'No FCM tokens',
          'failedAt': new Date().toISOString(),
        });
        return;
      }

      // Prepare notification payload
      const payload = {
        notification: {
          title: title || `New message from ${senderName}`,
          body: body || "Sent you a message",
          sound: "default",
        },
        data: {
          type: "chat",
          senderId: senderId,
          receiverId: receiverId,
          chatId: `${senderId}_${receiverId}`,
          senderName: senderName,
          ...data,
        },
        webpush: {
          fcmOptions: {
            link: `https://yourdomain.com/chat/${senderId}`, // Change to your domain
          },
        },
      };

      // Send to all devices in batches
      const results = await sendToTokens(tokens, payload);
      
      const successCount = results ? results.reduce((sum, r) => sum + (r.successCount || 0), 0) : 0;
      const failCount = results ? results.reduce((sum, r) => sum + (r.failureCount || 0), 0) : 0;
      
      logger.info(`✅ Chat notification sent to ${receiverId}: ${successCount} success, ${failCount} failed`);
      
      // Update notification status
      await event.data.ref.update({
        'status': successCount > 0 ? 'sent' : 'failed',
        'sentAt': new Date().toISOString(),
        'successCount': successCount,
        'failCount': failCount,
      });
      
    } catch (error) {
      logger.error("🔥 Error sending chat notification:", error);
      
      try {
        await event.data.ref.update({
          'status': 'failed',
          'error': error.message,
          'failedAt': new Date().toISOString(),
        });
      } catch (updateError) {
        logger.error("Failed to update notification status:", updateError);
      }
    }
  }
);

// ==================== POST NOTIFICATION ====================
// sendPostNotification: removed. It checked post.authorId, which posts never have, so it never ran. Followers are not pushed for every post; replies and mentions are (notify/functions.js).

// ==================== SONG PLAY NOTIFICATION ====================
// onSongPlayed: replaced by content milestones in mediaRecord (the app never wrote plays/).

// ==================== PROFILE VIEW NOTIFICATION ====================
// onProfileViewed: removed (the app never wrote profileViews/).

// ==================== BOOK READ NOTIFICATION ====================
// onBookRead: replaced by content milestones and reading reminders (the app never wrote bookReads/).

// ==================== POST LIKE NOTIFICATION ====================
// onPostLiked: replaced by notifyOnLike, which groups likes and fills the in-app centre.

// ==================== PROXY IMAGE ====================
// Only images from trusted hosts can be proxied (it fetched any URL before).
const PROXY_HOSTS = new Set(["firebasestorage.googleapis.com", "storage.googleapis.com", "lh3.googleusercontent.com", "i.scdn.co", "mosaic.scdn.co", "image-cdn-ak.spotifycdn.com", "i.ytimg.com", "covers.openlibrary.org", "books.google.com"]);
exports.proxyImage = functions.https.onRequest(async (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).send("Missing URL");
  let parsed;
  try { parsed = new URL(String(url)); } catch { return res.status(400).send("Invalid URL"); }
  if (parsed.protocol !== "https:" || !PROXY_HOSTS.has(parsed.hostname)) return res.status(403).send("Host not allowed");

  try {
    const response = await fetch(parsed.toString(), { redirect: "error" });
    if (!(response.headers.get("content-type") || "").startsWith("image/")) return res.status(415).send("Not an image");
    const buffer = await response.arrayBuffer();
    res.set("Content-Type", response.headers.get("content-type"));
    res.send(Buffer.from(buffer));
  } catch (e) {
    res.status(502).send("Could not fetch image");
  }
});

// ==================== HEALTH CHECK ====================
exports.healthCheck = functions.https.onRequest(async (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'notification-service'
  });
});

// ==================== TEST NOTIFICATION ====================
// sendTestNotification: replaced by the notifyTest callable, which only reaches your own devices (this endpoint let anyone notify anyone).

// ==================== MANGOCHAIN LEDGER ====================
// Server-validated MangoCoin ledger: activity mining, transfers, signed
// blocks and audits. See functions/ledger/README.md.
Object.assign(exports, require("./ledger/functions"));

// ==================== VIRTUAL SPACES ====================
Object.assign(exports, require("./spaces/functions"));

// ==================== MEDIA: TASTE, RECOMMENDATIONS, AI SHUFFLE ====================
Object.assign(exports, require("./media/functions"));

// ==================== CHAT ====================
Object.assign(exports, require("./chat/functions"));

// ==================== CREATOR CONTENT ====================
Object.assign(exports, require("./content/functions"));

// ==================== NOTIFICATIONS & ACCOUNTS ====================
Object.assign(exports, require("./notify/functions"));
