"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryStore } = require("../ledger/stores/memory");
const { MediaTaste, updateProfile, score, smartOrder } = require("../media/taste");

async function seedCatalog() {
  const store = new MemoryStore();
  const songs = [
    ["afro1", "Afrobeats", "tobi", 900], ["afro2", "Afrobeats", "tobi", 50], ["afro3", "Afrobeats", "ada", 10],
    ["afro4", "Afrobeats", "kemi", 5], ["jazz1", "Jazz", "miles", 3000], ["jazz2", "Jazz", "miles", 20],
    ["rock1", "Rock", "rocky", 100], ["rock2", "Rock", "rocky", 100],
  ];
  for (const [id, genre, artistId, plays] of songs) {
    await store.set(`music/${id}`, { title: id, genre, artistId, artistName: artistId, plays, artworkUrl: `https://img/${id}` });
  }
  await store.set("podcasts/p1", { title: "Tech talk", category: "Tech", userId: "host1", plays: 5 });
  return { store, taste: new MediaTaste({ store }) };
}

test("completions raise taste; early skips lower it more than late skips", () => {
  const item = { id: "a", genre: "Afrobeats", creatorId: "tobi" };
  const liked = updateProfile(null, { type: "song", event: "complete", item });
  assert.ok(liked.genres["song:afrobeats"] > 0);
  const early = updateProfile(liked, { type: "song", event: "skip", item, positionSec: 5, durationSec: 200 });
  const late = updateProfile(liked, { type: "song", event: "skip", item, positionSec: 190, durationSec: 200 });
  assert.ok(early.genres["song:afrobeats"] < late.genres["song:afrobeats"]);
  assert.equal(early.recent[0], "song:a");
});

test("scores prefer liked genres and creators and penalise recent repeats", () => {
  let p = null;
  for (let i = 0; i < 5; i++) p = updateProfile(p, { type: "song", event: "complete", item: { id: `x${i}`, genre: "Jazz", creatorId: "miles" } });
  const jazz = score(p, "song", { id: "new", genre: "Jazz", creatorId: "miles" });
  const rock = score(p, "song", { id: "r", genre: "Rock", creatorId: "rocky" });
  assert.ok(jazz > rock);
  assert.ok(score(p, "song", { id: "x4", genre: "Jazz", creatorId: "miles" }) < jazz, "just-played items rank lower");
});

test("AI shuffle keeps the current item first, keeps everything, spreads creators, mixes in picks", () => {
  const items = ["a", "b", "c", "d", "e", "f"].map((id, i) => ({ id, creatorId: i < 3 ? "same" : `c${i}`, genre: "Afrobeats" }));
  const recs = [{ id: "r1", creatorId: "x" }, { id: "r2", creatorId: "y" }];
  const out = smartOrder(null, "song", items, { currentId: "c", recommendations: recs, mixEvery: 2, randomSeed: 42 });
  assert.equal(out[0].id, "c");
  assert.deepEqual(out.filter((o) => o.origin === "queue").map((o) => o.id).sort(), ["a", "b", "c", "d", "e", "f"]);
  assert.ok(out.some((o) => o.origin === "recommended"));
  const queued = out.filter((o) => o.origin === "queue").slice(1);
  let repeats = 0;
  for (let i = 1; i < queued.length; i++) if (queued[i].creatorId === queued[i - 1].creatorId) repeats++;
  assert.ok(repeats <= 1, `creator repeats: ${repeats}`);
  const again = smartOrder(null, "song", items, { currentId: "c", recommendations: recs, mixEvery: 2, randomSeed: 42 });
  assert.deepEqual(again.map((o) => o.id), out.map((o) => o.id), "deterministic for a seed");
});

test("recommendations follow taste and the seed, exclude what is queued, and stay diverse", async () => {
  const { taste } = await seedCatalog();
  for (const id of ["afro1", "afro2"]) await taste.record("ada", { type: "song", id, event: "complete" });
  await taste.record("ada", { type: "song", id: "rock1", event: "skip", positionSec: 3, durationSec: 200 });
  const r = await taste.recommend("ada", { type: "song", seedId: "afro1", exclude: ["afro2"], limit: 5 });
  assert.equal(r.personalised, true);
  const ids = r.items.map((i) => i.id);
  assert.ok(!ids.includes("afro1") && !ids.includes("afro2"), "seed and excluded items are left out");
  assert.ok(["afro3", "afro4"].includes(ids[0]), `afrobeats first, got ${ids}`);
  assert.ok(ids.indexOf("rock1") === -1 || ids.indexOf("rock1") > ids.indexOf("afro3"));
});

test("works for podcasts too, and rejects unknown types and odd ids", async () => {
  const { taste } = await seedCatalog();
  const r = await taste.recommend("ada", { type: "podcast", limit: 5 });
  assert.equal(r.items[0].id, "p1");
  await assert.rejects(taste.recommend("ada", { type: "casino" }), /Unsupported/);
  await assert.rejects(taste.record("ada", { type: "song", id: "../../etc", event: "start" }), /Invalid item/);
  assert.deepEqual(await taste.record("ada", { type: "song", id: "missing", event: "start" }), { recorded: false });
});

test("server AI shuffle returns every queued id once plus recommendations", async () => {
  const { taste } = await seedCatalog();
  const ids = ["afro1", "afro2", "jazz1", "rock1"];
  const { items } = await taste.smartShuffle("ada", { type: "song", ids, currentId: "jazz1" });
  assert.equal(items[0].id, "jazz1");
  assert.deepEqual(items.filter((i) => i.origin === "queue").map((i) => i.id).sort(), [...ids].sort());
});
