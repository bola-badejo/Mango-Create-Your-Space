"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const c = require("../ledger/crypto");
const u = require("../ledger/units");

test("canonical JSON is key-order independent and rejects floats", () => {
  assert.equal(c.canonicalize({ b: 1, a: [true, null, "x"] }), c.canonicalize({ a: [true, null, "x"], b: 1 }));
  assert.throws(() => c.canonicalize({ a: 0.1 }));
  assert.throws(() => c.canonicalize({ a: 1n }));
});

test("units parse and format without floating point", () => {
  assert.equal(u.parseMng("1.5"), 150_000_000n);
  assert.equal(u.parseMng("0.00000001"), 1n);
  assert.equal(u.formatMng(123_456_789n), "1.23456789");
  assert.throws(() => u.parseMng("1.000000001"));
  assert.throws(() => u.parseMng("-1"));
  assert.throws(() => u.toUnits("1e5"));
  assert.throws(() => u.toUnits(1.5));
});

test("merkle inclusion proofs verify for every leaf and tree size", () => {
  for (let n = 1; n <= 17; n++) {
    const ids = Array.from({ length: n }, (_, i) => c.sha256Hex(`tx${i}`));
    const root = c.merkleRoot(ids);
    for (let i = 0; i < n; i++) {
      const proof = c.inclusionProof(ids, i);
      assert.ok(c.verifyInclusion(root, ids[i], i, n, proof), `n=${n} i=${i}`);
      assert.ok(!c.verifyInclusion(root, c.sha256Hex("forged"), i, n, proof));
      if (n > 1) assert.ok(!c.verifyInclusion(root, ids[i], (i + 1) % n, n, proof));
    }
  }
  assert.equal(c.merkleRoot([]), c.EMPTY_ROOT);
});

test("merkle root distinguishes a leaf from an inner node (second-preimage defence)", () => {
  const ids = [c.sha256Hex("a"), c.sha256Hex("b"), c.sha256Hex("c")];
  assert.notEqual(c.merkleRoot(ids), c.merkleRoot([...ids, ids[2]]));
});

test("Ed25519 block signatures verify and reject tampering or wrong keys", () => {
  const s = c.loadSigner(c.generateSigningKey().privateKeyPem);
  const other = c.loadSigner(c.generateSigningKey().privateKeyPem);
  const h = c.sha256Hex("block");
  const sig = s.sign(h);
  assert.ok(c.verifySignature(h, sig, s.publicKeyPem));
  assert.ok(!c.verifySignature(c.sha256Hex("block2"), sig, s.publicKeyPem));
  assert.ok(!c.verifySignature(h, sig, other.publicKeyPem));
  assert.ok(!c.verifySignature(h, "not-base64-signature", s.publicKeyPem));
  assert.equal(s.keyId.length, 16);
});
