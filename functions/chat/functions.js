"use strict";
// Cloud Functions for Mango Chat.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreatedWithAuthContext } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { getAuth } = require("firebase-admin/auth");
const { ChatService } = require("./service");
const { LedgerError } = require("../ledger/service");
const { FirestoreStore } = require("../ledger/stores/firestore");

const OPTS = { enforceAppCheck: process.env.LEDGER_ENFORCE_APP_CHECK === "true" };

async function deleteFile(path) {
  try {
    await getStorage().bucket().file(path).delete({ ignoreNotFound: true });
  } catch (e) {
    logger.warn("could not delete chat media", { path, error: e.message });
  }
}

let instance = null;
const chat = () => (instance ||= new ChatService({
  store: new FirestoreStore(getFirestore()),
  deleteFile,
  userExists: async (uid) => {
    try { await getAuth().getUser(uid); return true; } catch { return false; }
  },
}));

async function guarded(fn) {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("chat error", { error: e.message });
    throw new HttpsError("internal", "Something went wrong. Please try again.");
  }
}
const uidOf = (req) => {
  if (!req.auth || !req.auth.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.uid;
};

exports.chatOpen = onCall(OPTS, (req) => guarded(() => chat().open(uidOf(req), req.data || {}, Date.now())));
exports.chatMarkViewed = onCall(OPTS, (req) => guarded(() => chat().markViewed(uidOf(req), req.data || {}, Date.now())));
exports.chatOpenSnap = onCall(OPTS, (req) => guarded(() => chat().openSnap(uidOf(req), req.data || {}, Date.now())));
exports.chatToggleSave = onCall(OPTS, (req) => guarded(() => chat().toggleSave(uidOf(req), req.data || {}, Date.now())));
exports.chatUnsend = onCall(OPTS, (req) => guarded(() => chat().unsend(uidOf(req), req.data || {}, Date.now())));
exports.chatSetRetention = onCall(OPTS, (req) => guarded(() => chat().setRetention(uidOf(req), req.data || {}, Date.now())));

exports.chatOnMessage = onDocumentCreatedWithAuthContext("dm_chats/{chatId}/messages/{msgId}", async (event) => {
  const data = event.data && event.data.data();
  if (data && data.kind === "system") return; // written by the server itself
  const authId = event.authType === "app_user" ? event.authId : null;
  const res = await chat().onMessage({ chatId: event.params.chatId, msgId: event.params.msgId, data, authId, now: Date.now() });
  if (!res.accepted) {
    logger.warn("chat message rejected", { chatId: event.params.chatId, reason: res.reason });
    return;
  }
  // Reuse the existing push pipeline (sendChatNotification).
  const sender = await getFirestore().collection("users").doc(res.notify.senderId).get();
  const senderName = (sender.exists && (sender.data().displayName || sender.data().username)) || "Someone";
  await getFirestore().collection("notifications").add({
    ...res.notify,
    senderName,
    title: senderName,
    body: res.notify.title === "New Snap" ? "New Snap" : res.notify.body,
    data: { type: "chat", chatId: event.params.chatId },
    createdAt: Date.now(),
  });
});

exports.chatCleanup = onSchedule({ schedule: "every 10 minutes", timeoutSeconds: 300 }, async () => {
  const db = getFirestore();
  const res = await chat().cleanup(Date.now(), {
    listExpired: async (now) => {
      const snap = await db.collectionGroup("messages").where("expiresAt", "<=", now).limit(500).get();
      return snap.docs.filter((d) => d.ref.path.startsWith("dm_chats/")).map((d) => ({ path: d.ref.path, data: d.data() }));
    },
  });
  if (res.deleted) logger.info("expired chats removed", res);
});
