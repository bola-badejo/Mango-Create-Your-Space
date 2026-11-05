"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const C = require("../ledger/chain");
const P = require("../ledger/policy");
const { generateSigningKey, loadSigner } = require("../ledger/crypto");

const signer = loadSigner(generateSigningKey().privateKeyPem);
const keys = { [signer.keyId]: signer.publicKeyPem };
const A = C.addressFor("a");
const B = C.addressFor("b");

function sampleChain() {
  const g = C.makeTx({ type: C.TX.GENESIS, seq: 1, ts: 1, to: C.TREASURY, amount: P.GENESIS_TREASURY });
  const s0 = C.applyTx(C.emptyState(), g, 0);
  const b0 = C.buildBlock({ height: 0, prevHash: null, ts: 1, txs: [g], state: s0, signer });
  const r = C.makeTx({ type: C.TX.REWARD, seq: 2, ts: 2, to: A, amount: 1_000_000n, epoch: 0 });
  const t = C.makeTx({ type: C.TX.TRANSFER, seq: 3, ts: 3, from: A, to: B, amount: 500_000n, fee: P.TRANSFER_FEE });
  C.applyTx(s0, r, 1);
  C.applyTx(s0, t, 1);
  const b1 = C.buildBlock({ height: 1, prevHash: b0.hash, ts: 3, txs: [r, t], state: s0, signer });
  return { blocks: [b0, b1], txs: new Map([g, r, t].map((x) => [x.id, x])) };
}

test("a valid chain verifies and replays balances", () => {
  const { blocks, txs } = sampleChain();
  const res = C.verifyChain(blocks, txs, keys);
  assert.deepEqual(res.errors, []);
  assert.equal(res.state.balances.get(A), 1_000_000n - 500_000n - P.TRANSFER_FEE);
  assert.equal(res.state.balances.get(B), 500_000n);
  assert.equal(res.state.burned, P.TRANSFER_FEE);
});

test("tampering with a transaction amount is detected", () => {
  const { blocks, txs } = sampleChain();
  const [id, t] = [...txs].find(([, x]) => x.type === C.TX.TRANSFER);
  txs.set(id, { ...t, amount: "900000" });
  assert.match(C.verifyChain(blocks, txs, keys).errors[0], /id does not match/);
});

test("swapping a transaction for another valid one is detected", () => {
  const { blocks, txs } = sampleChain();
  const forged = C.makeTx({ type: C.TX.REWARD, seq: 2, ts: 2, to: B, amount: 1_000_000n, epoch: 0 });
  blocks[1] = { ...blocks[1], txIds: [forged.id, blocks[1].txIds[1]] };
  txs.set(forged.id, forged);
  assert.match(C.verifyChain(blocks, txs, keys).errors[0], /transaction root mismatch/);
});

test("a re-signed block from an unknown key is rejected", () => {
  const { blocks, txs } = sampleChain();
  const attacker = loadSigner(generateSigningKey().privateKeyPem);
  const header = { ...blocks[1].header, keyId: attacker.keyId };
  const hash = C.blockHash(header);
  blocks[1] = { ...blocks[1], header, hash, signature: attacker.sign(hash) };
  assert.match(C.verifyChain(blocks, txs, keys).errors[0], /unknown signing key/);
});

test("a header edited without re-signing is rejected", () => {
  const { blocks, txs } = sampleChain();
  blocks[1] = { ...blocks[1], header: { ...blocks[1].header, ts: 999 } };
  assert.match(C.verifyChain(blocks, txs, keys).errors[0], /header hash mismatch/);
});

test("a broken hash link is rejected", () => {
  const { blocks, txs } = sampleChain();
  const header = { ...blocks[1].header, prevHash: "00".repeat(32) };
  const hash = C.blockHash(header);
  blocks[1] = { ...blocks[1], header, hash, signature: signer.sign(hash) };
  assert.match(C.verifyChain(blocks, txs, keys).errors[0], /does not link/);
});

test("overspending, wrong fee, self-transfer and bad sequence are rejected", () => {
  const s = C.emptyState();
  s.balances.set(A, 1000n);
  s.lastSeq = 9;
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.TRANSFER, seq: 10, ts: 1, from: A, to: B, amount: 1000n, fee: P.TRANSFER_FEE })), /insufficient/);
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.TRANSFER, seq: 10, ts: 1, from: A, to: B, amount: 100n, fee: 0n })), /wrong fee/);
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.TRANSFER, seq: 10, ts: 1, from: A, to: A, amount: 100n, fee: P.TRANSFER_FEE })), /malformed/);
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.TRANSFER, seq: 12, ts: 1, from: A, to: B, amount: 100n, fee: P.TRANSFER_FEE })), /out of order/);
});

test("rewards cannot exceed an epoch's emission", () => {
  const s = C.emptyState();
  const cap = P.emissionForEpoch(0);
  C.applyTx(s, C.makeTx({ type: C.TX.REWARD, seq: 1, ts: 1, to: A, amount: cap, epoch: 0 }), 1);
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.REWARD, seq: 2, ts: 1, to: B, amount: 1n, epoch: 0 }), 1), /exceed its emission/);
});

test("genesis can only happen once, first, for the fixed amount", () => {
  assert.throws(() => C.applyTx(C.emptyState(), C.makeTx({ type: C.TX.GENESIS, seq: 1, ts: 1, to: C.TREASURY, amount: 1n }), 0), /fixed/);
  const s = C.emptyState();
  s.lastSeq = 1;
  assert.throws(() => C.applyTx(s, C.makeTx({ type: C.TX.GENESIS, seq: 2, ts: 1, to: C.TREASURY, amount: P.GENESIS_TREASURY }), 3), /first/);
});
