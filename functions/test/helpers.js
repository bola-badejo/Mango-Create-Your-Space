"use strict";
const { MemoryStore } = require("../ledger/stores/memory");
const { MangoLedger } = require("../ledger/service");
const { generateSigningKey, loadSigner } = require("../ledger/crypto");

const HOUR = 60 * 60 * 1000;
const T0 = Date.UTC(2026, 10, 4, 9, 0, 0); // epoch-aligned start

function makeLedger(opts = {}) {
  const store = new MemoryStore();
  const signer = loadSigner(generateSigningKey().privateKeyPem);
  const content = {
    "song:s1": { creatorUid: "artist" },
    "podcast:p1": { creatorUid: "host" },
    "movie:m1": { creatorUid: "director" },
    "song:own": { creatorUid: "alice" },
    "space:sp1": { spaceOwnerUid: "owner" },
    "space:alicespace": { spaceOwnerUid: "alice" },
    ...(opts.content || {}),
  };
  const ledger = new MangoLedger({
    store,
    signer,
    isEligible: opts.isEligible || (async (uid) => !String(uid).startsWith("fresh")),
    resolveContent: async (type, id) => content[`${type}:${id}`] || null,
  });
  return { store, signer, ledger };
}

module.exports = { makeLedger, HOUR, T0 };
