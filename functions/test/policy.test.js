"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../ledger/policy");

test("total emission can never exceed the mining pool", () => {
  let total = 0n;
  for (let h = 0; h < 64; h++) total += P.emissionForEpoch(h * P.HALVING_EPOCHS) * BigInt(P.HALVING_EPOCHS);
  assert.ok(total <= P.MINING_POOL);
  assert.equal(P.GENESIS_TREASURY + P.MINING_POOL, P.MAX_SUPPLY);
});

test("emission halves on schedule and ends", () => {
  const e0 = P.emissionForEpoch(0);
  assert.equal(P.emissionForEpoch(P.HALVING_EPOCHS - 1), e0);
  assert.equal(P.emissionForEpoch(P.HALVING_EPOCHS), e0 / 2n);
  assert.equal(P.emissionForEpoch(64 * P.HALVING_EPOCHS), 0n);
  assert.equal(P.emissionForEpoch(-1), 0n);
});

test("activity shares add up to at most 100%", () => {
  for (const [name, a] of Object.entries(P.ACTIVITIES)) {
    for (const s of [a.shares, a.spaceShares].filter(Boolean)) {
      const sum = Object.values(s).reduce((x, y) => x + y, 0);
      assert.ok(sum <= 1000, name);
    }
  }
});
