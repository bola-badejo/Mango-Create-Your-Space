"use strict";
// Cloud Functions for creator content.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { ContentService, OWNER_FIELDS, filesToDelete } = require("./service");
const { LedgerError } = require("../ledger/service");
const { FirestoreStore } = require("../ledger/stores/firestore");

const OPTS = { enforceAppCheck: process.env.LEDGER_ENFORCE_APP_CHECK === "true" };
let instance = null;
const content = () => (instance ||= new ContentService({ store: new FirestoreStore(getFirestore()) }));

exports.contributorRegister = onCall(OPTS, async (req) => {
  if (!req.auth || !req.auth.uid) throw new HttpsError("unauthenticated", "Sign in first.");
  try {
    return await content().registerContributor(req.auth.uid, req.data || {}, Date.now(), {
      email: req.auth.token.email || "",
      displayName: req.auth.token.name || "",
    });
  } catch (e) {
    if (e instanceof LedgerError) throw new HttpsError(e.code, e.message);
    logger.error("contributor register failed", { error: e.message });
    throw new HttpsError("internal", "Couldn't create your profile. Please try again.");
  }
});

// When a creator deletes something, remove its files too.
for (const collection of Object.keys(OWNER_FIELDS)) {
  const name = `contentCleanup_${collection}`;
  exports[name] = onDocumentDeleted(`${collection}/{id}`, async (event) => {
    const doc = event.data && event.data.data();
    if (!doc) return;
    const bucket = getStorage().bucket();
    const paths = filesToDelete(collection, doc);
    await Promise.all(paths.map((p) => bucket.file(p).delete({ ignoreNotFound: true }).catch((e) => logger.warn("cleanup failed", { p, error: e.message }))));
    if (paths.length) logger.info("content files removed", { collection, id: event.params.id, files: paths.length });
  });
}
