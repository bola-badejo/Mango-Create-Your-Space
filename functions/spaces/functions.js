"use strict";
// Cloud Functions for virtual Spaces.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreatedWithAuthContext } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const { defineSecret } = require("firebase-functions/params");
const { SpaceService } = require("./service");
const { SpaceLive } = require("./live");
const { MangoLedger, LedgerError } = require("../ledger/service");
const { FirestoreStore } = require("../ledger/stores/firestore");

const ENFORCE_APP_CHECK = process.env.LEDGER_ENFORCE_APP_CHECK === "true";
const OPTS = { enforceAppCheck: ENFORCE_APP_CHECK };

let instance = null;
function spaces() {
  if (!instance) {
    const store = new FirestoreStore(getFirestore());
    // Purchases are transfers, which never sign blocks, so no signing key here.
    const ledger = new MangoLedger({ store, signer: null });
    instance = new SpaceService({ store, ledger, timestamp: () => FieldValue.serverTimestamp() });
  }
  return instance;
}

function uidOf(req) {
  if (!req.auth || !req.auth.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  return req.auth.uid;
}

async function guarded(fn) {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("spaces error", { error: e.message, stack: e.stack });
    throw new HttpsError("internal", "Something went wrong. Please try again.");
  }
}

exports.spaceCheckHandle = onCall(OPTS, (req) => guarded(async () => {
  uidOf(req);
  return spaces().checkHandle((req.data || {}).handle);
}));

exports.spaceCreate = onCall(OPTS, (req) => guarded(async () => spaces().create(uidOf(req), req.data || {}, Date.now())));

exports.spaceBuyItem = onCall(OPTS, (req) => guarded(async () => spaces().buyItem(uidOf(req), req.data || {}, Date.now())));

exports.spaceApplyTheme = onCall(OPTS, (req) => guarded(async () => spaces().applyTheme(uidOf(req), req.data || {})));

exports.spaceCreateEvent = onCall(OPTS, (req) => guarded(async () => spaces().createEvent(uidOf(req), req.data || {}, Date.now())));

// ------------------------------------------------ live audio and video
// Opt-in: deploy with LIVEKIT_ENABLED=true and LIVEKIT_URL (wss://...) in
// functions/.env, after setting the LIVEKIT_API_KEY and LIVEKIT_API_SECRET
// secrets. Without them the app shows "not set up yet" instead of failing.
const LIVEKIT_ENABLED = process.env.LIVEKIT_ENABLED === "true";
const LIVEKIT_API_KEY = LIVEKIT_ENABLED ? defineSecret("LIVEKIT_API_KEY") : null;
const LIVEKIT_API_SECRET = LIVEKIT_ENABLED ? defineSecret("LIVEKIT_API_SECRET") : null;
const LIVE_OPTS = LIVEKIT_ENABLED ? { ...OPTS, secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET] } : OPTS;

let liveInstance = null;
function live() {
  if (!liveInstance) {
    const config = LIVEKIT_ENABLED
      ? { url: process.env.LIVEKIT_URL, apiKey: LIVEKIT_API_KEY.value(), apiSecret: LIVEKIT_API_SECRET.value() }
      : null;
    liveInstance = new SpaceLive({ store: new FirestoreStore(getFirestore()), config });
  }
  return liveInstance;
}

exports.spaceSetEventStatus = onCall(LIVE_OPTS, (req) => guarded(async () => {
  const data = req.data || {};
  const result = await spaces().setEventStatus(uidOf(req), data, Date.now());
  // Ending an event closes its media room for everyone.
  if (result.status === "ended") await live().endRoom(data.spaceId, data.eventId);
  return result;
}));

exports.spaceLiveToken = onCall(LIVE_OPTS, (req) => guarded(async () => {
  const name = req.auth && req.auth.token && req.auth.token.name;
  return live().token(uidOf(req), { ...(req.data || {}), name }, Date.now());
}));

exports.spaceSetSpeaker = onCall(LIVE_OPTS, (req) => guarded(async () => live().setSpeaker(uidOf(req), req.data || {})));

async function moderate(event, path) {
  const authId = event.authType === "app_user" ? event.authId : null;
  const res = await spaces().moderateMessage({ path, spaceId: event.params.spaceId, data: event.data && event.data.data(), authId, now: Date.now() });
  if (!res.keep) logger.info("space message removed", { path, reason: res.reason });
}

exports.spaceOnWallMessage = onDocumentCreatedWithAuthContext("spaces/{spaceId}/wall/{msgId}", (event) =>
  moderate(event, `spaces/${event.params.spaceId}/wall/${event.params.msgId}`));

exports.spaceOnEventChat = onDocumentCreatedWithAuthContext("spaces/{spaceId}/events/{eventId}/chat/{msgId}", (event) =>
  moderate(event, `spaces/${event.params.spaceId}/events/${event.params.eventId}/chat/${event.params.msgId}`));
