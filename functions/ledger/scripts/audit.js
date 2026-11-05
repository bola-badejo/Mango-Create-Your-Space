#!/usr/bin/env node
"use strict";
// Verifies MangoChain from genesis.
//   Live (needs Firestore credentials):  node ledger/scripts/audit.js
//   Export for public verification:      node ledger/scripts/audit.js --export chain.json
//   Verify an export offline:            node ledger/scripts/audit.js --file chain.json
const fs = require("fs");
const C = require("../chain");

async function main() {
  const args = process.argv.slice(2);
  const fileIdx = args.indexOf("--file");
  if (fileIdx >= 0) {
    const data = JSON.parse(fs.readFileSync(args[fileIdx + 1], "utf8"));
    const txs = new Map(data.txs.map((t) => [t.id, t]));
    const res = C.verifyChain(data.blocks, txs, data.keys);
    console.log(JSON.stringify({ ok: res.ok, errors: res.errors, height: res.height, minted: res.state.minted.toString(), burned: res.state.burned.toString() }, null, 2));
    process.exit(res.ok ? 0 : 1);
  }
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const { FirestoreStore } = require("../stores/firestore");
  const { MangoLedger } = require("../service");
  initializeApp();
  const ledger = new MangoLedger({ store: new FirestoreStore(getFirestore()), signer: null });
  const exportIdx = args.indexOf("--export");
  if (exportIdx >= 0) {
    const { blocks, txsById, keys } = await ledger.exportChain();
    const txs = [...txsById.values()].filter((t) => t.sealed).map((t) => ({ ...C.txBody(t), id: t.id }));
    fs.writeFileSync(args[exportIdx + 1], JSON.stringify({ blocks, txs, keys }, null, 1));
    console.log(`exported ${blocks.length} blocks and ${txs.length} transactions`);
    return;
  }
  const report = await ledger.audit();
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.ok ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
