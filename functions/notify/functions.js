"use strict";
// Notification and account Cloud Functions.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { Notifier } = require("./service");
const { AccountService, remindToResume } = require("../account/service");
const { LedgerError } = require("../ledger/service");
const { FirestoreStore } = require("../ledger/stores/firestore");

const OPTS = { enforceAppCheck: process.env.LEDGER_ENFORCE_APP_CHECK === "true" };
const INVALID_TOKEN = new Set(["messaging/registration-token-not-registered", "messaging/invalid-registration-token", "messaging/invalid-argument"]);

async function push(tokens, payload) {
  const invalid = [];
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: payload.notification,
      data: payload.data,
      android: { priority: "high", notification: { channelId: "mango_default" } },
      apns: { payload: { aps: { sound: "default" } } },
    });
    res.responses.forEach((r, j) => {
      if (!r.success && r.error && INVALID_TOKEN.has(r.error.code)) invalid.push(batch[j]);
    });
  }
  return { invalid };
}

let notifierInstance = null;
let accountInstance = null;
const db = () => getFirestore();
const notifier = () => (notifierInstance ||= new Notifier({ store: new FirestoreStore(db()), push, timestamp: (ms) => Timestamp.fromMillis(ms) }));
const accounts = () => (accountInstance ||= new AccountService({ store: new FirestoreStore(db()), notifier: notifier(), timestamp: () => FieldValue.serverTimestamp() }));

async function nameOf(uid) {
  if (!uid) return "Someone";
  const d = (await db().collection("users").doc(uid).get()).data() || {};
  return d.displayName || d.username || "Someone";
}

async function guarded(fn) {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("account error", { error: e.message });
    throw new HttpsError("internal", "Something went wrong. Please try again.");
  }
}
const uidOf = (req) => {
  if (!req.auth || !req.auth.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.uid;
};

// ----------------------------------------------------------- accounts
exports.accountStatus = onCall(OPTS, (req) => guarded(() => accounts().status(uidOf(req))));
exports.accountCheckUsername = onCall(OPTS, (req) => guarded(() => accounts().checkUsername(uidOf(req), (req.data || {}).username)));
exports.accountSuggestUsername = onCall(OPTS, (req) => guarded(() => accounts().suggestUsername(uidOf(req), { name: (req.data || {}).name || req.auth.token.name, email: req.auth.token.email })));
exports.accountOnboard = onCall(OPTS, (req) => guarded(() => accounts().onboard(uidOf(req), req.data || {}, Date.now(), {
  email: req.auth.token.email || "",
  phone: req.auth.token.phone_number || "",
  photoURL: req.auth.token.picture || "",
})));

/** Sends a test notification to your own devices (replaces the open HTTP endpoint). */
exports.notifyTest = onCall(OPTS, (req) => guarded(() => notifier().notify({
  to: uidOf(req), type: "system", title: "Notifications are working 🎉", body: "This is a test from Mango.", target: null,
})));

// ----------------------------------------------------------- activity
exports.notifyOnLike = onDocumentCreated("posts/{postId}/likes/{likerId}", async (event) => {
  const post = (await db().collection("posts").doc(event.params.postId).get()).data();
  if (!post) return;
  await notifier().notify({
    to: post.ownerId || post.postCreator, type: "like", actorId: event.params.likerId, actorName: await nameOf(event.params.likerId),
    title: "", body: post.text ? String(post.text).slice(0, 80) : "", imageUrl: post.image || (post.multiImage || [])[0] || null,
    target: { kind: "post", id: event.params.postId }, group: `post_${event.params.postId}`,
  });
});

exports.notifyOnPost = onDocumentCreated("posts/{postId}", async (event) => {
  const post = event.data && event.data.data();
  if (!post) return;
  const author = post.ownerId || post.postCreator;
  const authorName = await nameOf(author);
  const notified = new Set();
  if (post.repliedPostID) {
    const parent = (await db().collection("posts").doc(post.repliedPostID).get()).data();
    const to = parent && (parent.ownerId || parent.postCreator);
    if (to) {
      notified.add(to);
      await notifier().notify({ to, type: "reply", actorId: author, actorName: authorName, title: `${authorName} replied to your post`, body: String(post.text || "").slice(0, 120), target: { kind: "post", id: post.repliedPostID } });
    }
  }
  const mentions = [...new Set((String(post.text || "").match(/@([a-z0-9._]{3,20})/gi) || []).map((m) => m.slice(1).toLowerCase()))].slice(0, 5);
  for (const handle of mentions) {
    const snap = await db().collection("users").where("username", "==", handle).limit(1).get();
    const to = snap.empty ? null : snap.docs[0].id;
    if (!to || notified.has(to)) continue;
    notified.add(to);
    await notifier().notify({ to, type: "mention", actorId: author, actorName: authorName, title: `${authorName} mentioned you`, body: String(post.text || "").slice(0, 120), target: { kind: "post", id: event.params.postId } });
  }
});

exports.notifyOnFollow = onDocumentCreated("users/{uid}/followers/{followerId}", async (event) => {
  const day = new Date().toISOString().slice(0, 10);
  await notifier().notify({
    to: event.params.uid, type: "follow", actorId: event.params.followerId, actorName: await nameOf(event.params.followerId),
    title: "", target: { kind: "profile", id: event.params.followerId }, group: `follow_${day}`,
  });
});

exports.notifyOnSpaceWall = onDocumentCreated("spaces/{spaceId}/wall/{msgId}", async (event) => {
  const msg = event.data && event.data.data();
  const space = (await db().collection("spaces").doc(event.params.spaceId).get()).data();
  if (!msg || !space) return;
  await notifier().notify({
    to: space.ownerId || space.postCreator, type: "space_message", actorId: msg.authorId, actorName: msg.authorName || (await nameOf(msg.authorId)),
    title: "", body: String(msg.text || "").slice(0, 120), target: { kind: "space", id: event.params.spaceId },
    group: `wall_${event.params.spaceId}`, extra: { spaceTitle: space.title },
  });
});

exports.notifyOnSpaceLive = onDocumentUpdated("spaces/{spaceId}/events/{eventId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after || before.status === "live" || after.status !== "live") return;
  const space = (await db().collection("spaces").doc(event.params.spaceId).get()).data() || {};
  const members = await db().collection("spaces").doc(event.params.spaceId).collection("subscribers").limit(500).get();
  for (const m of members.docs) {
    await notifier().notify({
      to: m.id, type: "space_live", actorId: after.hostId, title: `${space.title || "A Space"} is live`, body: after.title || "Join now",
      target: { kind: "space", id: event.params.spaceId }, group: `live_${event.params.eventId}`,
    });
  }
});

// ------------------------------------------------------- scheduled nudges
exports.notifyProfileReminders = onSchedule({ schedule: "0 10 * * *", timeZone: "Africa/Lagos" }, async () => {
  const snap = await db().collection("users").where("onboarding.version", "==", 2).limit(1000).get();
  const res = await accounts().remindIncomplete(Date.now(), snap.docs.map((d) => ({ id: d.id, data: d.data() })));
  logger.info("profile reminders", res);
});

exports.notifyResumeReminders = onSchedule({ schedule: "0 18 * * *", timeZone: "Africa/Lagos" }, async () => {
  const now = Date.now();
  const snap = await db().collectionGroup("items")
    .where("updatedAt", ">=", Timestamp.fromMillis(now - 4 * 86400000))
    .where("updatedAt", "<=", Timestamp.fromMillis(now - 86400000))
    .limit(2000).get();
  const items = snap.docs
    .filter((d) => d.ref.path.startsWith("media_progress/"))
    .map((d) => {
      const data = d.data();
      return { uid: d.ref.parent.parent.id, key: d.id, ref: d.ref, data: { ...data, updatedMs: data.updatedAt && data.updatedAt.toMillis ? data.updatedAt.toMillis() : 0, remindedMs: data.remindedMs || 0 } };
    });
  const res = await remindToResume({ notifier: notifier(), items, now });
  await Promise.all(items.map((i) => i.ref.set({ remindedMs: now }, { merge: true }).catch(() => {})));
  logger.info("resume reminders", res);
});

module.exports.notifier = notifier;
