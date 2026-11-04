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
exports.sendPostNotification = onDocumentCreated(
  "posts/{postId}",
  async (event) => {
    const post = event.data.data();
    if (!post?.authorId) return;

    try {
      // Get all followers with their tokens
      const followersSnap = await db
        .collection("users")
        .doc(post.authorId)
        .collection("followers")
        .get();

      const allTokens = [];
      const followerIds = [];
      
      followersSnap.forEach((doc) => {
        const followerData = doc.data();
        followerIds.push(doc.id);
        
        // Get tokens from follower's user document
        if (followerData.fcmToken) {
          allTokens.push(followerData.fcmToken);
        }
      });
      
      // Also check each follower's user document for multiple tokens
      for (const followerId of followerIds) {
        const userDoc = await db.collection("users").doc(followerId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
            allTokens.push(...userData.fcmTokens);
          } else if (userData.fcmToken) {
            allTokens.push(userData.fcmToken);
          }
        }
      }
      
      // Remove duplicates
      const uniqueTokens = [...new Set(allTokens)];
      
      if (uniqueTokens.length === 0) {
        logger.info(`No tokens for followers of post ${event.params.postId}`);
        return;
      }

      const payload = {
        notification: {
          title: `${post.authorName || "Someone"} posted on Mango`,
          body: post.text || "Check out their new post!",
        },
        data: {
          type: "post",
          postId: event.params.postId,
          authorId: post.authorId,
        },
        webpush: {
          fcmOptions: {
            link: `https://yourdomain.com/post/${event.params.postId}`,
          },
        },
      };

      await sendToTokens(uniqueTokens, payload);
      logger.info(`✅ Post notification sent to ${uniqueTokens.length} followers`);
      
    } catch (error) {
      logger.error("🔥 Error sending post notification:", error);
    }
  }
);

// ==================== SONG PLAY NOTIFICATION ====================
exports.onSongPlayed = onDocumentCreated("plays/{playId}", async (event) => {
  const play = event.data.data();
  if (!play?.artistId) return;

  return sendNotificationToUser(
    play.artistId,
    "Your song was played 🎧",
    `${play.listenerName || "Someone"} just played "${play.songTitle || ""}"`,
    { 
      type: "song", 
      songId: play.songId,
      listenerId: play.listenerId,
      listenerName: play.listenerName 
    }
  );
});

// ==================== PROFILE VIEW NOTIFICATION ====================
exports.onProfileViewed = onDocumentCreated(
  "profileViews/{viewId}",
  async (event) => {
    const view = event.data.data();
    if (!view?.profileOwnerId) return;

    return sendNotificationToUser(
      view.profileOwnerId,
      "Someone viewed your profile 👀",
      `${view.viewerName || "Someone"} checked out your profile`,
      { 
        type: "profile", 
        viewerId: view.viewerId,
        viewerName: view.viewerName 
      }
    );
  }
);

// ==================== BOOK READ NOTIFICATION ====================
exports.onBookRead = onDocumentCreated("bookReads/{readId}", async (event) => {
  const read = event.data.data();
  if (!read?.authorId) return;

  return sendNotificationToUser(
    read.authorId,
    "Your book was read 📖",
    `${read.readerName || "Someone"} read "${read.bookTitle || ""}"`,
    { 
      type: "book", 
      bookId: read.bookId,
      readerId: read.readerId,
      bookTitle: read.bookTitle 
    }
  );
});

// ==================== POST LIKE NOTIFICATION ====================
exports.onPostLiked = onDocumentCreated(
  "posts/{postId}/likes/{likeId}",
  async (event) => {
    const like = event.data.data();
    if (!like) return;

    const postDoc = await db.collection("posts").doc(event.params.postId).get();
    const post = postDoc.exists ? postDoc.data() : null;
    if (!post?.authorId) return;

    // Don't notify if user likes their own post
    if (post.authorId === like.likerId) return;

    return sendNotificationToUser(
      post.authorId,
      "Your post got a like ❤️",
      `${like.likerName || "Someone"} liked your post`,
      { 
        type: "post", 
        postId: event.params.postId,
        likerId: like.likerId,
        likerName: like.likerName 
      }
    );
  }
);

// ==================== PROXY IMAGE ====================
exports.proxyImage = functions.https.onRequest(async (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).send("Missing URL");

  try {
    const response = await fetch(url);
    const buffer = await response.arrayBuffer();
    res.set("Content-Type", response.headers.get("content-type"));
    res.send(Buffer.from(buffer));
  } catch (e) {
    res.status(500).send(e.toString());
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
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  const { userId, title, body, type } = req.body;
  
  if (!userId) {
    res.status(400).json({ error: 'userId is required' });
    return;
  }
  
  try {
    const result = await sendNotificationToUser(
      userId,
      title || "Test Notification",
      body || "This is a test notification",
      { type: type || "test" }
    );
    
    if (result) {
      res.json({ success: true, message: "Test notification sent" });
    } else {
      res.status(404).json({ error: "No tokens found for user" });
    }
    
  } catch (error) {
    logger.error("Error sending test notification:", error);
    res.status(500).json({ error: error.message });
  }
});