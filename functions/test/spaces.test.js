"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const { SpaceService, ITEMS, FREE_ITEMS, normalizeHandle } = require("../spaces/service");
const { parseMng } = require("../ledger/units");
const P = require("../ledger/policy");
const { makeLedger, HOUR, T0 } = require("./helpers");

async function setup() {
  const ctx = makeLedger();
  await ctx.ledger.ensureGenesis(T0);
  const spaces = new SpaceService({ store: ctx.store, ledger: ctx.ledger });
  return { ...ctx, spaces };
}

const base = { title: "Tobi's Studio", description: "Beats and live sessions", template: "music", visibility: "public", handle: "@TobiBeats" };

async function fund(ctx, uid, mng) {
  // Fund through the real path: a treasury grant (as the migration does).
  await ctx.ledger.openAccount(uid, T0);
  await ctx.ledger.transfer("@treasury", { to: uid, amount: parseMng(mng).toString(), idempotencyKey: `fund-${uid}-${mng}` }, T0);
}

test("the app and the server use the same item catalog", () => {
  const server = fs.readFileSync(path.join(__dirname, "..", "spaces", "catalog.json"), "utf8");
  const app = fs.readFileSync(path.join(__dirname, "..", "..", "asset", "space_catalog.json"), "utf8");
  assert.equal(app, server, "asset/space_catalog.json must equal functions/spaces/catalog.json");
  for (const item of Object.values(ITEMS)) {
    assert.ok(["skin", "icon", "object"].includes(item.kind), item.id);
    assert.ok(item.priceUnits >= 0n);
  }
});

test("creating a Space reserves its handle, sets the owner and lays out a starter world", async () => {
  const { spaces, store } = await setup();
  const { spaceId, handle } = await spaces.create("tobi", base, T0);
  assert.equal(handle, "tobibeats");
  const space = await store.get(`spaces/${spaceId}`);
  assert.equal(space.ownerId, "tobi");
  assert.equal(space.postCreator, "tobi", "legacy owner field kept for existing screens and mining");
  assert.deepEqual(space.theme, { skinId: "skin.midnight", iconId: "icon.mango" });
  const objects = await store.query({ collection: `spaces/${spaceId}/objects` });
  assert.deepEqual(objects.map((o) => o.data.kind).sort(), ["decor", "decor", "decor", "events", "wall"]);
  const inventory = await store.query({ collection: `spaces/${spaceId}/inventory` });
  assert.equal(inventory.length, FREE_ITEMS.length);
  assert.ok(await store.get(`spaces/${spaceId}/subscribers/tobi`));
});

test("handles are unique, validated and reserved words are refused", async () => {
  const { spaces } = await setup();
  await spaces.create("tobi", base, T0);
  assert.equal((await spaces.checkHandle("tobibeats")).available, false);
  await assert.rejects(spaces.create("ada", base, T0), /taken/);
  assert.match((await spaces.checkHandle("ab")).reason, /at least 3/);
  assert.match((await spaces.checkHandle("admin")).reason, /reserved/);
  assert.match((await spaces.checkHandle("bad handle!")).reason, /letters, numbers/);
  assert.equal(normalizeHandle("  @Ada_Reads "), "ada_reads");
  assert.equal((await spaces.checkHandle("ada_reads")).available, true);
});

test("creation validates input and refuses paid looks before purchase", async () => {
  const { spaces } = await setup();
  await assert.rejects(spaces.create("tobi", { ...base, title: "x" }, T0), /at least 3/);
  await assert.rejects(spaces.create("tobi", { ...base, template: "casino" }, T0), /what your Space is for/);
  await assert.rejects(spaces.create("tobi", { ...base, visibility: "everyone" }, T0), /who can enter/);
  await assert.rejects(spaces.create("tobi", { ...base, skinId: "skin.gold" }, T0), /shop/);
});

test("buying an item charges MangoCoin and grants it in one transaction", async () => {
  const ctx = await setup();
  const { spaceId } = await ctx.spaces.create("tobi", base, T0);
  await fund(ctx, "tobi", "50");
  const before = BigInt((await ctx.ledger.getAccount("tobi")).balance);
  const r = await ctx.spaces.buyItem("tobi", { spaceId, itemId: "obj.stage" }, T0 + 1);
  const price = ITEMS["obj.stage"].priceUnits;
  assert.equal(BigInt(r.balance), before - price - P.TRANSFER_FEE);
  const inv = await ctx.store.get(`spaces/${spaceId}/inventory/obj.stage`);
  assert.equal(inv.txId, r.txId);
  // A repeated purchase (double tap, retry) returns the original receipt and
  // never charges twice.
  const again = await ctx.spaces.buyItem("tobi", { spaceId, itemId: "obj.stage" }, T0 + 2);
  assert.equal(again.duplicate, true);
  assert.equal(again.txId, r.txId);
  assert.equal(BigInt((await ctx.ledger.getAccount("tobi")).balance), BigInt(r.balance));
  await ctx.ledger.produceAll(T0 + 3);
  const audit = await ctx.ledger.audit();
  assert.ok(audit.ok, audit.errors.join("; "));
});

test("a failed payment grants nothing; non-editors cannot buy for a Space", async () => {
  const ctx = await setup();
  const { spaceId } = await ctx.spaces.create("tobi", base, T0);
  await ctx.ledger.openAccount("tobi", T0);
  await assert.rejects(ctx.spaces.buyItem("tobi", { spaceId, itemId: "skin.gold" }, T0), /insufficient/);
  assert.equal(await ctx.store.get(`spaces/${spaceId}/inventory/skin.gold`), null);
  await fund(ctx, "mallory", "500");
  await assert.rejects(ctx.spaces.buyItem("mallory", { spaceId, itemId: "skin.gold" }, T0), /owner or editors/);
  await assert.rejects(ctx.spaces.buyItem("tobi", { spaceId, itemId: "skin.fake" }, T0), /isn't in the shop/);
});

test("themes apply only from owned or free items, by editors", async () => {
  const ctx = await setup();
  const { spaceId } = await ctx.spaces.create("tobi", base, T0);
  await assert.rejects(ctx.spaces.applyTheme("tobi", { spaceId, skinId: "skin.aurora" }), /Buy Aurora first/);
  await fund(ctx, "tobi", "30");
  await ctx.spaces.buyItem("tobi", { spaceId, itemId: "skin.aurora" }, T0 + 1);
  const r = await ctx.spaces.applyTheme("tobi", { spaceId, skinId: "skin.aurora", iconId: "icon.star" });
  assert.deepEqual(r.theme, { skinId: "skin.aurora", iconId: "icon.star" });
  await assert.rejects(ctx.spaces.applyTheme("ada", { spaceId, skinId: "skin.meadow" }), /owner or editors/);
});

test("live events: scheduled by editors, go live and end only in order", async () => {
  const ctx = await setup();
  const { spaceId } = await ctx.spaces.create("tobi", base, T0);
  const ev = await ctx.spaces.createEvent("tobi", { spaceId, title: "Friday listening party", startsAt: T0 + HOUR, durationMinutes: 90 }, T0);
  assert.equal(ev.status, "scheduled");
  await assert.rejects(ctx.spaces.createEvent("ada", { spaceId, title: "Hijack", startsAt: T0 + HOUR }, T0), /owner or editors/);
  await assert.rejects(ctx.spaces.createEvent("tobi", { spaceId, title: "Too long", startsAt: T0 + HOUR, durationMinutes: 600 }, T0), /8 hours/);
  await assert.rejects(ctx.spaces.setEventStatus("tobi", { spaceId, eventId: ev.eventId, status: "ended" }, T0), /can't become ended/);
  await ctx.spaces.setEventStatus("tobi", { spaceId, eventId: ev.eventId, status: "live" }, T0 + HOUR);
  assert.equal((await ctx.store.get(`spaces/${spaceId}`)).liveEventId, ev.eventId);
  await ctx.spaces.setEventStatus("tobi", { spaceId, eventId: ev.eventId, status: "ended" }, T0 + 2 * HOUR);
  assert.equal((await ctx.store.get(`spaces/${spaceId}`)).liveEventId, null);
});

test("wall moderation removes forged authors, bad text and floods", async () => {
  const ctx = await setup();
  const put = async (id, data) => { await ctx.store.set(`spaces/s1/wall/${id}`, data); return `spaces/s1/wall/${id}`; };
  const forged = await put("m0", { authorId: "victim", text: "hi" });
  assert.equal((await ctx.spaces.moderateMessage({ path: forged, spaceId: "s1", data: { authorId: "victim", text: "hi" }, authId: "mallory", now: T0 })).reason, "forged_author");
  assert.equal(await ctx.store.get(forged), null);
  const results = [];
  for (let i = 0; i < 8; i++) {
    const p = await put(`m${i + 1}`, { authorId: "ada", text: `hello ${i}` });
    results.push((await ctx.spaces.moderateMessage({ path: p, spaceId: "s1", data: { authorId: "ada", text: `hello ${i}` }, authId: "ada", now: T0 + i })).keep);
  }
  assert.deepEqual(results, [true, true, true, true, true, true, false, false]);
  const later = await put("m20", { authorId: "ada", text: "after a minute" });
  assert.equal((await ctx.spaces.moderateMessage({ path: later, spaceId: "s1", data: { authorId: "ada", text: "after a minute" }, authId: "ada", now: T0 + 61_000 })).keep, true);
});

test("time spent in a Space mines for its owner via the ledger", async () => {
  const { ledger, spaces, store } = await setup();
  const { spaceId } = await spaces.create("tobi", base, T0);
  const ownerOf = async (type, id) => {
    if (type !== "space") return null;
    const s = await store.get(`spaces/${id}`);
    return s ? { spaceOwnerUid: s.ownerId || s.postCreator } : null;
  };
  ledger.resolveContent = ownerOf;
  await ledger.startSession("ada", { contentType: "space", contentId: spaceId }, T0);
  const r = await ledger.endSession("ada", T0 + 120_000);
  assert.ok(r.credited);
  assert.ok(r.points.tobi > r.points.ada, "owner earns the larger share of a visit");
});
