"use strict";
// Cloud Functions for MangoChain. The app never writes balances: it calls
// these endpoints, and Firestore triggers credit activity using the
// identity Firebase reports for the writer (event.authId), not any user id
// written inside the document.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreatedWithAuthContext } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const { MangoLedger, LedgerError, paths } = require("./service");
const { FirestoreStore } = require("./stores/firestore");
const { loadSigner } = require("./crypto");
const P = require("./policy");

const LEDGER_SIGNING_KEY = defineSecret("LEDGER_SIGNING_KEY");
// Turn on once Firebase App Check is set up in the app (recommended).
const ENFORCE_APP_CHECK = process.env.LEDGER_ENFORCE_APP_CHECK === "true";
const OPTS = { secrets: [LEDGER_SIGNING_KEY], enforceAppCheck: ENFORCE_APP_CHECK };

// Where each content type stores its owner, from the app's data model.
const CONTENT_OWNER = {
  song: ["music", ["artistId"]],
  podcast: ["podcasts", ["userId"]],
  movie: ["movies", ["userId"]],
  // The app stores a Space's owner as `postCreator`; v2 Spaces also set ownerId.
  space: ["spaces", ["ownerId", "postCreator", "createdBy", "creatorId", "userId", "adminId", "owner"]],
};

const ineligibleCache = new Map(); // uid -> checkedAt

async function isEligible(uid) {
  const db = getFirestore();
  const acct = await db.doc(paths.account(uid)).get();
  if (acct.exists && acct.data().eligibleAt) return true;
  const cached = ineligibleCache.get(uid);
  if (cached && Date.now() - cached < 10 * 60 * 1000) return false;
  try {
    const user = await getAuth().getUser(uid);
    const age = Date.now() - Date.parse(user.metadata.creationTime);
    const verified = user.emailVerified || !!user.phoneNumber ||
      user.providerData.some((p) => ["google.com", "apple.com", "phone"].includes(p.providerId));
    if (!user.disabled && verified && age >= P.MIN_ACCOUNT_AGE_MS) {
      await db.doc(paths.account(uid)).set({ eligibleAt: Date.now() }, { merge: true });
      return true;
    }
  } catch (e) {
    logger.warn("eligibility check failed", { uid, error: e.message });
  }
  ineligibleCache.set(uid, Date.now());
  return false;
}

async function resolveContent(type, id) {
  const source = CONTENT_OWNER[type];
  if (!source || !id) return null;
  const snap = await getFirestore().collection(source[0]).doc(id).get();
  if (!snap.exists) return null;
  const data = snap.data();
  const owner = source[1].map((f) => data[f]).find((v) => typeof v === "string" && v.length > 0);
  if (!owner) return null;
  return type === "space" ? { spaceOwnerUid: owner } : { creatorUid: owner };
}

let instance = null;
function ledger() {
  if (!instance) {
    instance = new MangoLedger({
      store: new FirestoreStore(getFirestore()),
      signer: loadSigner(LEDGER_SIGNING_KEY.value()),
      isEligible,
      resolveContent,
    });
  }
  return instance;
}

function requireUser(request) {
  if (!request.auth || !request.auth.uid) throw new HttpsError("unauthenticated", "Sign in to use your wallet.");
  return request.auth.uid;
}

async function guarded(fn) {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("ledger error", { error: e.message, stack: e.stack });
    throw new HttpsError("internal", "The ledger could not complete that request. Please try again.");
  }
}

const publicAccount = (a) => a && ({ address: a.address, balance: a.balance, streak: a.streak || 0, lastCheckInDay: a.lastCheckInDay || null });

// ---------------------------------------------------------------- callables
exports.ledgerOpenAccount = onCall(OPTS, (req) => guarded(async () => {
  const uid = requireUser(req);
  return publicAccount(await ledger().openAccount(uid, Date.now()));
}));

exports.ledgerCheckIn = onCall(OPTS, (req) => guarded(async () => {
  const uid = requireUser(req);
  await ledger().openAccount(uid, Date.now());
  return ledger().checkIn(uid, Date.now());
}));

exports.ledgerStartSession = onCall(OPTS, (req) => guarded(async () => {
  const uid = requireUser(req);
  const { contentType, contentId, spaceId } = req.data || {};
  return ledger().startSession(uid, { contentType, contentId, spaceId }, Date.now());
}));

exports.ledgerEndSession = onCall(OPTS, (req) => guarded(async () => {
  const uid = requireUser(req);
  return (await ledger().endSession(uid, Date.now())) || { credited: false, reason: "no_session" };
}));

exports.ledgerTransfer = onCall(OPTS, (req) => guarded(async () => {
  const uid = requireUser(req);
  const { to, amount, memo, idempotencyKey } = req.data || {};
  return ledger().transfer(uid, { to, amount: String(amount), memo, idempotencyKey }, Date.now());
}));

exports.ledgerProof = onCall(OPTS, (req) => guarded(async () => {
  requireUser(req);
  return ledger().proofFor(String((req.data || {}).txId || ""));
}));

// ------------------------------------------------- activity from real data
function trusted(event) {
  // Only writes made by a signed-in app user count; writes from the Admin
  // SDK or unauthenticated clients are ignored for mining.
  return event.authType === "app_user" && typeof event.authId === "string" ? event.authId : null;
}

exports.ledgerOnPostCreated = onDocumentCreatedWithAuthContext({ document: "posts/{postId}", secrets: [LEDGER_SIGNING_KEY] }, async (event) => {
  const actor = trusted(event);
  if (!actor) return;
  await guarded(() => ledger().recordActivity({
    type: "post_created", actorUid: actor, subjectId: event.params.postId,
    eventId: `post_${event.params.postId}`, ts: Date.now(),
  })).catch((e) => logger.warn("post credit failed", { error: e.message }));
});

exports.ledgerOnPostLiked = onDocumentCreatedWithAuthContext({ document: "posts/{postId}/likes/{likeId}", secrets: [LEDGER_SIGNING_KEY] }, async (event) => {
  const actor = trusted(event);
  if (!actor || event.params.likeId !== actor) return; // the app keys likes by the liker's uid
  const post = await getFirestore().collection("posts").doc(event.params.postId).get();
  const creator = post.exists ? post.data().postCreator || post.data().authorId : null;
  if (!creator) return;
  await guarded(() => ledger().recordActivity({
    type: "like_given", actorUid: actor, creatorUid: creator, subjectId: event.params.postId, ts: Date.now(),
  })).catch((e) => logger.warn("like credit failed", { error: e.message }));
});

exports.ledgerOnFollow = onDocumentCreatedWithAuthContext({ document: "users/{uid}/followers/{followerId}", secrets: [LEDGER_SIGNING_KEY] }, async (event) => {
  const actor = trusted(event);
  if (!actor || event.params.followerId !== actor) return;
  await guarded(() => ledger().recordActivity({
    type: "follow_given", actorUid: actor, creatorUid: event.params.uid, subjectId: event.params.uid, ts: Date.now(),
  })).catch((e) => logger.warn("follow credit failed", { error: e.message }));
});

// ------------------------------------------------------- block production
exports.ledgerProduceBlocks = onSchedule({ schedule: "every 5 minutes", secrets: [LEDGER_SIGNING_KEY], timeoutSeconds: 300 }, async () => {
  const now = Date.now();
  const g = await ledger().ensureGenesis(now);
  if (g.created) logger.info("MangoChain genesis created", { headHash: g.meta.headHash });
  const steps = await ledger().produceAll(now, 60);
  if (steps.length) logger.info("blocks produced", { steps });
});

exports.ledgerAudit = onSchedule({ schedule: "every day 03:30", secrets: [LEDGER_SIGNING_KEY], timeoutSeconds: 540, memory: "1GiB" }, async () => {
  const report = await ledger().audit();
  await getFirestore().doc("ledger_meta/audit").set({ ...report, at: Date.now() });
  if (!report.ok) logger.error("LEDGER AUDIT FAILED", report);
  else logger.info("ledger audit passed", { height: report.height, accounts: report.accountsChecked });
});

// ---------------------------------------- optional public anchoring (Polygon)
// Deploy with LEDGER_ANCHOR_ENABLED=true and set ANCHOR_RPC_URL,
// ANCHOR_CONTRACT and the ANCHOR_PRIVATE_KEY secret to publish the chain head
// to a public chain daily. Anyone can then check the ledger was not rewritten.
if (process.env.LEDGER_ANCHOR_ENABLED === "true") {
  const ANCHOR_PRIVATE_KEY = defineSecret("ANCHOR_PRIVATE_KEY");
  exports.ledgerAnchor = onSchedule({ schedule: "every day 04:00", secrets: [LEDGER_SIGNING_KEY, ANCHOR_PRIVATE_KEY] }, async () => {
    const { anchorHead } = require("./anchor");
    const result = await anchorHead({
      db: getFirestore(),
      rpcUrl: process.env.ANCHOR_RPC_URL,
      contract: process.env.ANCHOR_CONTRACT,
      privateKey: ANCHOR_PRIVATE_KEY.value(),
    });
    logger.info("anchored chain head", result);
  });
}
