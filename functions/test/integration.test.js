"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const P = require("../ledger/policy");
const C = require("../ledger/chain");
const { migrate } = require("../ledger/scripts/migrate-legacy");
const { makeLedger, HOUR, T0 } = require("./helpers");

test("legacy migration grants capped balances from the treasury and stays auditable", async () => {
  const { ledger } = makeLedger();
  await ledger.ensureGenesis(T0);
  const legacy = [
    { uid: "u1", balance: 5_000_000_000 }, // 50 MNG
    { uid: "u2", balance: 999_999_999_999_999 }, // forged-looking
    { uid: "u3", balance: "garbage" },
  ];
  const dry = await migrate({ ledger, legacyAccounts: legacy, capUnits: 2_000_000_000n, apply: false, now: T0 });
  assert.equal(dry.results.length, 0);
  assert.equal(dry.total, 4_000_000_000n);
  const run = await migrate({ ledger, legacyAccounts: legacy, capUnits: 2_000_000_000n, apply: true, now: T0 });
  assert.equal(run.results.length, 2);
  const again = await migrate({ ledger, legacyAccounts: legacy, capUnits: 2_000_000_000n, apply: true, now: T0 });
  assert.equal(again.results[0].txId, run.results[0].txId, "migration is idempotent");
  await ledger.produceAll(T0 + 1);
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
});

test("the offline verifier accepts an exported chain and rejects a tampered one", async () => {
  const { ledger } = makeLedger();
  await ledger.ensureGenesis(T0);
  await ledger.recordActivity({ type: "post_created", actorUid: "alice", subjectId: "p", ts: T0 + 1000 });
  await ledger.produceAll(T0 + HOUR + P.EPOCH_GRACE_MS + 1);
  const { blocks, txsById, keys } = await ledger.exportChain();
  const txs = [...txsById.values()].map((t) => ({ ...C.txBody(t), id: t.id }));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mango-"));
  const good = path.join(dir, "chain.json");
  fs.writeFileSync(good, JSON.stringify({ blocks, txs, keys }));
  const script = path.join(__dirname, "..", "ledger", "scripts", "audit.js");
  const out = JSON.parse(execFileSync(process.execPath, [script, "--file", good]).toString());
  assert.equal(out.ok, true);
  const bad = path.join(dir, "bad.json");
  const tampered = txs.map((t) => (t.type === "reward" ? { ...t, amount: "999999999999" } : t));
  fs.writeFileSync(bad, JSON.stringify({ blocks, txs: tampered, keys }));
  assert.throws(() => execFileSync(process.execPath, [script, "--file", bad], { stdio: "pipe" }));
});
