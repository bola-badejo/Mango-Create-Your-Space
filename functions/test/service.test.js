"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../ledger/policy");
const C = require("../ledger/chain");
const { paths, META } = require("../ledger/service");
const { makeLedger, HOUR, T0 } = require("./helpers");

async function setup(opts) {
  const ctx = makeLedger(opts);
  await ctx.ledger.ensureGenesis(T0);
  return ctx;
}

const bal = async (ledger, uid) => BigInt((await ledger.getAccount(uid))?.balance || "0");

test("genesis mints the fixed treasury allocation once", async () => {
  const { ledger } = await setup();
  const again = await ledger.ensureGenesis(T0 + 1000);
  assert.equal(again.created, false);
  assert.equal(await bal(ledger, "@treasury"), P.GENESIS_TREASURY);
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
});

test("likes credit liker 20% and creator 80%, once per post", async () => {
  const { ledger } = await setup();
  const first = await ledger.recordActivity({ type: "like_given", actorUid: "alice", creatorUid: "bob", subjectId: "post1", ts: T0 + 1000 });
  assert.deepEqual(first.points, { alice: 200, bob: 800 });
  const again = await ledger.recordActivity({ type: "like_given", actorUid: "alice", creatorUid: "bob", subjectId: "post1", ts: T0 + 2000 });
  assert.equal(again.reason, "duplicate");
});

test("self-engagement and ineligible (fresh or unverified) accounts earn nothing", async () => {
  const { ledger } = await setup();
  assert.equal((await ledger.recordActivity({ type: "like_given", actorUid: "alice", creatorUid: "alice", subjectId: "p", ts: T0 })).reason, "self_engagement");
  assert.equal((await ledger.recordActivity({ type: "like_given", actorUid: "fresh1", creatorUid: "bob", subjectId: "p", ts: T0 })).reason, "not_eligible");
});

test("daily caps and pair caps stop farming between two accounts", async () => {
  const { ledger } = await setup();
  let toBob = 0;
  let capped = 0;
  for (let i = 0; i < 60; i++) {
    const r = await ledger.recordActivity({ type: "like_given", actorUid: "alice", creatorUid: "bob", subjectId: `post${i}`, ts: T0 + i });
    if (r.reason === "daily_cap") capped += 1;
    toBob += r.points?.bob || 0;
  }
  assert.equal(capped, 60 - P.ACTIVITIES.like_given.dailyCap);
  assert.ok(toBob <= P.PAIR_DAILY_CAP, `bob got ${toBob}`);
});

test("sessions are timed by the server; too-short sessions earn nothing", async () => {
  const { ledger } = await setup();
  await ledger.startSession("alice", { contentType: "song", contentId: "s1" }, T0 + 1000);
  const ended = await ledger.endSession("alice", T0 + 1000 + 10_000); // 10 s
  assert.equal(ended.reason, "too_short");
  await ledger.startSession("alice", { contentType: "song", contentId: "s1" }, T0 + 20_000);
  const r = await ledger.endSession("alice", T0 + 20_000 + 90_000); // 90 s -> x1.5
  assert.equal(r.durationSec, 90);
  assert.deepEqual(r.points, { alice: 600, artist: 2400 });
  assert.equal(await ledger.endSession("alice", T0 + 500_000), null, "an ended session cannot be ended twice");
});

test("starting a new session ends and credits the previous one", async () => {
  const { ledger } = await setup();
  await ledger.startSession("alice", { contentType: "podcast", contentId: "p1" }, T0);
  const next = await ledger.startSession("alice", { contentType: "song", contentId: "s1" }, T0 + 120_000);
  assert.equal(next.ended.durationSec, 120);
  assert.ok(next.ended.credited);
});

test("consumption inside a Space splits 20/70/10 with the Space owner", async () => {
  const { ledger } = await setup();
  await ledger.startSession("alice", { contentType: "song", contentId: "s1", spaceId: "sp1" }, T0);
  const r = await ledger.endSession("alice", T0 + 45_000); // 45 s -> x1.2 = 2400 points
  assert.deepEqual(r.points, { alice: 480, artist: 1680, owner: 240 });
});

test("listening to your own song or visiting your own Space earns nothing", async () => {
  const { ledger } = await setup();
  await ledger.startSession("alice", { contentType: "song", contentId: "own" }, T0);
  assert.equal((await ledger.endSession("alice", T0 + 120_000)).reason, "self_engagement");
  await ledger.startSession("alice", { contentType: "space", contentId: "alicespace" }, T0 + 200_000);
  assert.equal((await ledger.endSession("alice", T0 + 400_000)).reason, "self_engagement");
});

test("daily check-in is once per day with a growing streak", async () => {
  const { ledger } = await setup();
  const d1 = await ledger.checkIn("alice", T0 + 1000);
  assert.equal(d1.streak, 1);
  assert.equal((await ledger.checkIn("alice", T0 + 2000)).reason, "duplicate");
  const d2 = await ledger.checkIn("alice", T0 + 24 * HOUR + 1000);
  assert.equal(d2.streak, 2);
  assert.deepEqual(d2.points, { alice: P.checkInPoints(2) });
});

test("a quiet epoch pays the per-point ceiling, not the whole emission", async () => {
  const { ledger } = await setup();
  await ledger.recordActivity({ type: "post_created", actorUid: "alice", subjectId: "p1", ts: T0 + 1000 });
  await ledger.recordActivity({ type: "like_given", actorUid: "carol", creatorUid: "alice", subjectId: "p1", ts: T0 + 2000 });
  // Before the epoch (plus grace) ends, nothing is minted.
  assert.equal(await ledger.produceBlock(T0 + HOUR), null);
  const steps = await ledger.produceAll(T0 + HOUR + P.EPOCH_GRACE_MS + 1);
  assert.deepEqual(steps.map((s) => s.kind), ["rewards", "epoch_closed"]);
  // alice: 5000 + 800 points, carol: 200. Few users, so the ceiling applies.
  assert.equal(await bal(ledger, "alice"), 5800n * P.MAX_UNITS_PER_MILLIPOINT);
  assert.equal(await bal(ledger, "carol"), 200n * P.MAX_UNITS_PER_MILLIPOINT);
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
  assert.ok(BigInt(audit.minted) - P.GENESIS_TREASURY <= P.emissionForEpoch(0));
});

test("a busy epoch shares exactly its emission, never more", async () => {
  const { ledger, store } = await setup();
  // Seed many accounts with large point totals directly (as if after a busy hour).
  // 3,000 accounts at the per-epoch cap: enough points that each pro-rata
  // share is below the per-point ceiling, so the full emission is shared.
  const n = 3000;
  for (let i = 0; i < n; i++) {
    await store.set(paths.points(0, `user${String(i).padStart(4, "0")}`), { points: P.ACCOUNT_EPOCH_CAP });
  }
  const steps = await ledger.produceAll(T0 + HOUR + P.EPOCH_GRACE_MS + 1);
  assert.equal(steps.filter((s) => s.kind === "rewards").length, Math.ceil(n / P.MAX_TX_PER_BLOCK), "rewards span several blocks");
  const epoch = await store.get(paths.epoch(0));
  assert.ok(BigInt(epoch.minted) <= P.emissionForEpoch(0));
  assert.ok(P.emissionForEpoch(0) - BigInt(epoch.minted) < BigInt(n), "rounding loss only");
  assert.ok(store.maxWritesSeen <= 500, `max writes in one transaction: ${store.maxWritesSeen}`);
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
});

test("transfers move funds, burn the fee, are idempotent and are sealed into blocks", async () => {
  const { ledger } = await setup();
  await ledger.recordActivity({ type: "post_created", actorUid: "alice", subjectId: "p1", ts: T0 + 1000 });
  await ledger.produceAll(T0 + HOUR + P.EPOCH_GRACE_MS + 1);
  await ledger.openAccount("bob", T0);
  const before = await bal(ledger, "alice");
  const amount = 1_000_000n;
  const bobAddr = (await ledger.getAccount("bob")).address;
  const r1 = await ledger.transfer("alice", { to: bobAddr, amount: amount.toString(), memo: "thanks", idempotencyKey: "k1" }, T0 + 2 * HOUR);
  const r2 = await ledger.transfer("alice", { to: bobAddr, amount: amount.toString(), memo: "thanks", idempotencyKey: "k1" }, T0 + 2 * HOUR + 5);
  assert.equal(r2.duplicate, true);
  assert.equal(r1.txId, r2.txId);
  assert.equal(await bal(ledger, "alice"), before - amount - P.TRANSFER_FEE);
  assert.equal(await bal(ledger, "bob"), amount);
  // Old-style transfer by user id still works.
  await ledger.transfer("bob", { to: "alice", amount: "1000" }, T0 + 2 * HOUR + 10);
  const sealed = await ledger.produceBlock(T0 + 2 * HOUR + 20);
  assert.equal(sealed.kind, "seal");
  assert.equal(sealed.txCount, 2);
  const proof = await ledger.proofFor(r1.txId);
  assert.ok(proof.sealed);
  const { verifyInclusion } = require("../ledger/crypto");
  assert.ok(verifyInclusion(proof.header.txRoot, proof.id, proof.index, proof.header.txCount, proof.proof));
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
  assert.equal(BigInt(audit.burned), 2n * P.TRANSFER_FEE);
});

test("transfers reject overspending, self-sends, unknown recipients and bad amounts", async () => {
  const { ledger } = await setup();
  await ledger.openAccount("alice", T0);
  await ledger.openAccount("bob", T0);
  await assert.rejects(ledger.transfer("alice", { to: "bob", amount: "1000" }, T0), /insufficient/);
  await assert.rejects(ledger.transfer("alice", { to: "alice", amount: "1000" }, T0), /yourself/);
  await assert.rejects(ledger.transfer("alice", { to: C.addressFor("nobody"), amount: "1000" }, T0), /no account/);
  await assert.rejects(ledger.transfer("alice", { to: "bob", amount: "1.5" }, T0), /invalid/);
  await assert.rejects(ledger.transfer("alice", { to: "bob", amount: "-5" }, T0), /invalid/);
});

test("audit catches a balance edited outside the ledger", async () => {
  const { ledger, store } = await setup();
  await ledger.openAccount("mallory", T0);
  await store.set(paths.account("mallory"), { balance: "999999999999" }, { merge: true });
  const audit = await ledger.audit();
  assert.equal(audit.ok, false);
  assert.match(audit.errors[0], /balance mismatch/);
});

test("pending transfers are sealed before the next reward block, keeping global order", async () => {
  const { ledger, store } = await setup();
  await ledger.recordActivity({ type: "post_created", actorUid: "alice", subjectId: "p1", ts: T0 + 1000 });
  await ledger.produceAll(T0 + HOUR + P.EPOCH_GRACE_MS + 1);
  await ledger.openAccount("bob", T0);
  await ledger.recordActivity({ type: "post_created", actorUid: "bob", subjectId: "p2", ts: T0 + HOUR + 1000 });
  await ledger.transfer("alice", { to: "bob", amount: "5000" }, T0 + 2 * HOUR);
  const steps = await ledger.produceAll(T0 + 2 * HOUR + P.EPOCH_GRACE_MS + 1);
  assert.equal(steps[0].kind, "seal");
  const meta = await store.get(META);
  assert.equal(meta.sealedSeq, meta.sequence);
  const audit = await ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
});
