"use strict";
// Cloud Functions for media: taste, recommendations and AI shuffle.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { getFirestore } = require("firebase-admin/firestore");
const { MediaTaste } = require("./taste");
const { LedgerError } = require("../ledger/service");
const { FirestoreStore } = require("../ledger/stores/firestore");

const OPTS = { enforceAppCheck: process.env.LEDGER_ENFORCE_APP_CHECK === "true" };
let instance = null;
const taste = () => (instance ||= new MediaTaste({ store: new FirestoreStore(getFirestore()) }));

async function guarded(fn) {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("media error", { error: e.message });
    throw new HttpsError("internal", "Something went wrong. Please try again.");
  }
}
const uidOf = (req) => {
  if (!req.auth || !req.auth.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.uid;
};

exports.mediaRecord = onCall(OPTS, (req) => guarded(async () => {
  const uid = uidOf(req);
  const data = req.data || {};
  const res = await taste().record(uid, data);
  // Tell the creator when their work reaches a milestone (first play, 10, 100...).
  if (res.recorded && data.event === "start") {
    try {
      const item = await taste()._item(data.type, data.id);
      if (item && item.creatorId && item.creatorId !== uid) {
        await require("../notify/functions").notifier().countAndCelebrate({ type: data.type, id: data.id, title: item.title, ownerId: item.creatorId, imageUrl: item.imageUrl });
      }
    } catch (e) {
      logger.warn("milestone check failed", { error: e.message });
    }
  }
  return res;
}));
exports.mediaRecommend = onCall(OPTS, (req) => guarded(() => taste().recommend(uidOf(req), req.data || {})));
exports.mediaSmartShuffle = onCall(OPTS, (req) => guarded(() => taste().smartShuffle(uidOf(req), req.data || {})));
