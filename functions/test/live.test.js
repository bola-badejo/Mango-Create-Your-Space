"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { TokenVerifier } = require("livekit-server-sdk");
const { SpaceService } = require("../spaces/service");
const { SpaceLive, roomName, MAX_SPEAKERS } = require("../spaces/live");
const { makeLedger, HOUR, T0 } = require("./helpers");

const config = { url: "wss://mango-test.livekit.cloud", apiKey: "APItestkey", apiSecret: "test-secret-that-is-long-enough-32chars" };
const verifier = new TokenVerifier(config.apiKey, config.apiSecret);

async function setup({ visibility = "public" } = {}) {
  const ctx = makeLedger();
  await ctx.ledger.ensureGenesis(T0);
  const spaces = new SpaceService({ store: ctx.store, ledger: ctx.ledger });
  const calls = [];
  const rooms = {
    updateParticipant: async (...a) => { calls.push(["update", ...a]); },
    deleteRoom: async (...a) => { calls.push(["delete", ...a]); },
  };
  const live = new SpaceLive({ store: ctx.store, config, rooms });
  const { spaceId } = await spaces.create("tobi", { title: "Tobi's Studio", template: "music", visibility, handle: `tobi_${visibility}` }, T0);
  const ev = await spaces.createEvent("tobi", { spaceId, title: "Listening party", startsAt: T0 + HOUR, durationMinutes: 60 }, T0);
  return { ...ctx, spaces, live, calls, spaceId, eventId: ev.eventId };
}

const goLive = (c) => c.spaces.setEventStatus("tobi", { spaceId: c.spaceId, eventId: c.eventId, status: "live" }, T0 + HOUR);

test("no token before the event is live, or after it ends", async () => {
  const c = await setup();
  await assert.rejects(c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR), /isn't live yet/);
  await goLive(c);
  await c.spaces.setEventStatus("tobi", { spaceId: c.spaceId, eventId: c.eventId, status: "ended" }, T0 + 2 * HOUR);
  await assert.rejects(c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + 2 * HOUR), /has ended/);
});

test("listeners get a signed, subscribe-only token for this room only", async () => {
  const c = await setup();
  await goLive(c);
  const t = await c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId, name: "Ada" }, T0 + HOUR + 1);
  assert.equal(t.role, "listener");
  assert.equal(t.canPublish, false);
  const claims = await verifier.verify(t.token);
  assert.equal(claims.sub, "ada");
  assert.equal(claims.name, "Ada");
  assert.equal(claims.video.room, roomName(c.spaceId, c.eventId));
  assert.equal(claims.video.roomJoin, true);
  assert.equal(claims.video.canSubscribe, true);
  assert.equal(claims.video.canPublish, false);
  assert.ok(!claims.video.roomAdmin);
});

test("the host gets publish and admin rights; a forged token fails verification", async () => {
  const c = await setup();
  await goLive(c);
  const t = await c.live.token("tobi", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR + 1);
  assert.equal(t.role, "host");
  const claims = await verifier.verify(t.token);
  assert.equal(claims.video.canPublish, true);
  assert.equal(claims.video.roomAdmin, true);
  const [h, p, sig] = t.token.split(".");
  const body = JSON.parse(Buffer.from(p, "base64url").toString());
  body.sub = "mallory";
  const forged = [h, Buffer.from(JSON.stringify(body)).toString("base64url"), sig].join(".");
  await assert.rejects(verifier.verify(forged));
  await assert.rejects(new TokenVerifier(config.apiKey, "a-different-secret-of-thirty-two!").verify(t.token));
});

test("the host can invite someone to speak, applied live and in their next token", async () => {
  const c = await setup();
  await goLive(c);
  await assert.rejects(c.live.setSpeaker("ada", { spaceId: c.spaceId, eventId: c.eventId, userId: "ada", speaker: true }), /Only the host/);
  await c.live.setSpeaker("tobi", { spaceId: c.spaceId, eventId: c.eventId, userId: "ada", speaker: true });
  assert.deepEqual(c.calls[0].slice(0, 3), ["update", roomName(c.spaceId, c.eventId), "ada"]);
  assert.equal(c.calls[0][4].canPublish, true);
  const t = await c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR + 1);
  assert.equal(t.role, "speaker");
  assert.equal((await verifier.verify(t.token)).video.canPublish, true);
  await c.live.setSpeaker("tobi", { spaceId: c.spaceId, eventId: c.eventId, userId: "ada", speaker: false });
  assert.equal((await c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR + 2)).role, "listener");
});

test("speakers are capped", async () => {
  const c = await setup();
  await goLive(c);
  for (let i = 0; i < MAX_SPEAKERS; i++) await c.live.setSpeaker("tobi", { spaceId: c.spaceId, eventId: c.eventId, userId: `u${i}`, speaker: true });
  await assert.rejects(c.live.setSpeaker("tobi", { spaceId: c.spaceId, eventId: c.eventId, userId: "one-more", speaker: true }), /Up to/);
});

test("members-only and private Spaces need membership to watch", async () => {
  for (const visibility of ["members", "private"]) {
    const c = await setup({ visibility });
    await goLive(c);
    await assert.rejects(c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR + 1), /Join this Space/);
    await c.store.set(`spaces/${c.spaceId}/subscribers/ada`, { userId: "ada" });
    assert.equal((await c.live.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0 + HOUR + 1)).role, "listener");
  }
});

test("ending an event closes the media room; missing setup gives a clear message", async () => {
  const c = await setup();
  assert.deepEqual(await c.live.endRoom(c.spaceId, c.eventId), { closed: true });
  assert.deepEqual(c.calls.at(-1), ["delete", roomName(c.spaceId, c.eventId)]);
  const unconfigured = new SpaceLive({ store: c.store, config: null });
  await assert.rejects(unconfigured.token("ada", { spaceId: c.spaceId, eventId: c.eventId }, T0), /aren't set up/);
});
