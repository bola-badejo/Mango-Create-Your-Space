#!/usr/bin/env node
"use strict";
// Moves balances from the old client-written `wallets` collection onto
// MangoChain as treasury grants. Old balances were writable by any signed-in
// user, so they cannot be trusted as-is: review the dry run, choose a cap,
// and exclude accounts you do not recognise.
//
//   node ledger/scripts/migrate-legacy.js                  dry run (default)
//   node ledger/scripts/migrate-legacy.js --cap 50         dry run, 50 MNG cap each
//   node ledger/scripts/migrate-legacy.js --cap 50 --apply grant from the treasury
//   --exclude uid1,uid2                                    skip these accounts
const { parseMng, formatMng, toUnits } = require("../units");
const { TREASURY_UID } = require("../service");

async function migrate({ ledger, legacyAccounts, capUnits, apply, exclude = new Set(), now = Date.now() }) {
  const plan = [];
  for (const { uid, balance } of legacyAccounts) {
    if (exclude.has(uid)) continue;
    let units;
    try { units = toUnits(Math.max(0, Math.floor(Number(balance) || 0))); } catch { continue; }
    const grant = capUnits !== null && units > capUnits ? capUnits : units;
    if (grant > 0n) plan.push({ uid, legacy: units, grant });
  }
  const total = plan.reduce((s, p) => s + p.grant, 0n);
  const results = [];
  if (apply) {
    for (const p of plan) {
      await ledger.openAccount(p.uid, now);
      const r = await ledger.transfer(TREASURY_UID, { to: p.uid, amount: p.grant.toString(), memo: "Legacy wallet migration", idempotencyKey: `legacy-migration-${p.uid}` }, now);
      results.push({ uid: p.uid, txId: r.txId });
    }
  }
  return { accounts: plan.length, total, plan, results };
}

async function main() {
  const args = process.argv.slice(2);
  const val = (flag) => { const i = args.indexOf(flag); return i >= 0 ? args[i + 1] : null; };
  const capUnits = val("--cap") ? parseMng(val("--cap")) : null;
  const exclude = new Set((val("--exclude") || "").split(",").filter(Boolean));
  const apply = args.includes("--apply");
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const { FirestoreStore } = require("../stores/firestore");
  const { MangoLedger } = require("../service");
  initializeApp();
  const db = getFirestore();
  const snap = await db.collection("wallets").get();
  const legacyAccounts = snap.docs.map((d) => ({ uid: d.id, balance: d.data().balance }));
  const ledger = new MangoLedger({ store: new FirestoreStore(db), signer: null });
  const out = await migrate({ ledger, legacyAccounts, capUnits, apply, exclude });
  for (const p of out.plan) console.log(`${p.uid}\tlegacy ${formatMng(p.legacy)}\tgrant ${formatMng(p.grant)}`);
  console.log(`\n${out.accounts} accounts, total ${formatMng(out.total)} MNG ${apply ? "granted" : "(dry run: nothing written)"}`);
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { migrate };
