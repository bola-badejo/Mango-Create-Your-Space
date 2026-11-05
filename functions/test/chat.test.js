"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { MemoryStore } = require("../ledger/stores/memory");
const { ChatService, chatIdFor, updateStreak, streakView, DAY } = require("../chat/service");

const T0 = Date.UTC(2026, 10, 5, 10, 0, 0);

async function setup() {
  const store = new MemoryStore();
  const deleted = [];
  const chat = new ChatService({ store, deleteFile: async (p) => { deleted.push(p); }, userExists: async (u) => u !== "ghost" });
  const { chatId } = await chat.open("ada", { peerId: "tobi" }, T0);
  let n = 0;
  const send = async (from, data, at) => {
    const id = `m${++n}`;
    await store.set(`dm_chats/${chatId}/messages/${id}`, { senderId: from, createdAt: at, ...data });
    const res = await chat.onMessage({ chatId, msgId: id, data: { senderId: from, ...data }, authId: from, now: at });
    return { id, res };
  };
  const listExpired = async (now) => (await store.query({ collection: `dm_chats/${chatId}/messages` }))
    .filter((r) => r.data.expiresAt !== null && r.data.expiresAt !== undefined && r.data.expiresAt <= now)
    .map((r) => ({ path: `dm_chats/${chatId}/messages/${r.id}`, data: r.data }));
  return { store, chat, chatId, send, deleted, listExpired };
}

test("opening a chat is idempotent and uses one id for both people", async () => {
  const { chat, chatId } = await setup();
  assert.equal(chatId, chatIdFor("tobi", "ada"));
  assert.deepEqual(await chat.open("tobi", { peerId: "ada" }, T0 + 1), { chatId, created: false });
  await assert.rejects(chat.open("ada", { peerId: "ada" }, T0), /someone/);
  await assert.rejects(chat.open("ada", { peerId: "ghost" }, T0), /account/);
});

test("forged messages are removed; real ones update the summary and unread count", async () => {
  const { store, chat, chatId, send, deleted } = await setup();
  await store.set(`dm_chats/${chatId}/messages/f1`, { senderId: "tobi", kind: "text", text: "hi", media: { path: "chats/x/f.jpg" } });
  const forged = await chat.onMessage({ chatId, msgId: "f1", data: { senderId: "tobi", kind: "text", text: "hi", media: { path: "chats/x/f.jpg" } }, authId: "mallory", now: T0 });
  assert.equal(forged.accepted, false);
  assert.equal(await store.get(`dm_chats/${chatId}/messages/f1`), null);
  assert.deepEqual(deleted, ["chats/x/f.jpg"]);
  const { res } = await send("ada", { kind: "text", text: "hey Tobi" }, T0 + 10);
  assert.equal(res.notify.receiverId, "tobi");
  const c = await store.get(`dm_chats/${chatId}`);
  assert.equal(c.state.tobi.unread, 1);
  assert.equal(c.last.preview, "hey Tobi");
});

test("chats delete after viewing by default; saved messages stay", async () => {
  const ctx = await setup();
  const a = await ctx.send("ada", { kind: "text", text: "one" }, T0 + 10);
  const b = await ctx.send("ada", { kind: "text", text: "two" }, T0 + 20);
  await ctx.chat.toggleSave("tobi", { chatId: ctx.chatId, messageId: b.id }, T0 + 25);
  const v = await ctx.chat.markViewed("tobi", { chatId: ctx.chatId }, T0 + 30);
  assert.equal(v.viewed, 2);
  const r = await ctx.chat.cleanup(T0 + 40, { listExpired: ctx.listExpired });
  assert.equal(r.deleted, 1);
  assert.equal(await ctx.store.get(`dm_chats/${ctx.chatId}/messages/${a.id}`), null);
  assert.ok(await ctx.store.get(`dm_chats/${ctx.chatId}/messages/${b.id}`), "saved message kept");
  assert.equal((await ctx.store.get(`dm_chats/${ctx.chatId}`)).state.tobi.unread, 0);
});

test("unsaving a viewed message lets it expire; 24-hour and keep settings work", async () => {
  const ctx = await setup();
  await ctx.chat.setRetention("ada", { chatId: ctx.chatId, mode: "24h" }, T0);
  const m = await ctx.send("ada", { kind: "text", text: "later" }, T0 + 10);
  await ctx.chat.markViewed("tobi", { chatId: ctx.chatId }, T0 + 20);
  assert.equal((await ctx.chat.cleanup(T0 + DAY / 2, { listExpired: ctx.listExpired })).deleted, 0);
  await ctx.chat.toggleSave("ada", { chatId: ctx.chatId, messageId: m.id }, T0 + 30);
  await ctx.chat.toggleSave("ada", { chatId: ctx.chatId, messageId: m.id }, T0 + 40);
  const msg = await ctx.store.get(`dm_chats/${ctx.chatId}/messages/${m.id}`);
  assert.equal(msg.expiresAt, T0 + 40 + DAY);
  await ctx.chat.setRetention("tobi", { chatId: ctx.chatId, mode: "keep" }, T0 + 50);
  const k = await ctx.send("tobi", { kind: "text", text: "forever" }, T0 + 60);
  await ctx.chat.markViewed("ada", { chatId: ctx.chatId }, T0 + 70);
  assert.equal((await ctx.store.get(`dm_chats/${ctx.chatId}/messages/${k.id}`)).expiresAt, null);
  await assert.rejects(ctx.chat.setRetention("ada", { chatId: ctx.chatId, mode: "forever" }, T0), /Unknown/);
});

test("snaps open once, can't be saved, and their media is deleted", async () => {
  const ctx = await setup();
  const s = await ctx.send("ada", { kind: "snap", media: { path: `chats/${ctx.chatId}/ada/s.jpg`, url: "https://x/s.jpg", mime: "image/jpeg" } }, T0 + 10);
  await assert.rejects(ctx.chat.toggleSave("tobi", { chatId: ctx.chatId, messageId: s.id }, T0), /can't be saved/);
  await assert.rejects(ctx.chat.openSnap("ada", { chatId: ctx.chatId, messageId: s.id }, T0), /You sent/);
  const opened = await ctx.chat.openSnap("tobi", { chatId: ctx.chatId, messageId: s.id }, T0 + 20);
  assert.equal(opened.media.url, "https://x/s.jpg");
  await assert.rejects(ctx.chat.openSnap("tobi", { chatId: ctx.chatId, messageId: s.id }, T0 + 30), /already opened/);
  await ctx.chat.cleanup(T0 + 120_000, { listExpired: ctx.listExpired });
  assert.equal(await ctx.store.get(`dm_chats/${ctx.chatId}/messages/${s.id}`), null);
  assert.ok(ctx.deleted.includes(`chats/${ctx.chatId}/ada/s.jpg`));
});

test("streaks grow once per day when both snap, warn, and reset after a missed day", () => {
  const m = ["ada", "tobi"];
  let s = updateStreak(null, m, "ada", T0);
  assert.equal(s.count, 0);
  s = updateStreak(s, m, "tobi", T0 + 1000);
  assert.equal(s.count, 1);
  s = updateStreak(s, m, "ada", T0 + 2000);
  assert.equal(s.count, 1, "only once per day");
  s = updateStreak(updateStreak(s, m, "ada", T0 + DAY), m, "tobi", T0 + DAY + 1);
  assert.equal(s.count, 2);
  assert.equal(streakView(s, s.expiresAt - 60_000).hourglass, true);
  assert.equal(streakView(s, s.expiresAt + 1).count, 0);
  s = updateStreak(s, m, "ada", s.expiresAt + 10);
  assert.equal(s.count, 0, "missed a day: starts over");
});

test("only senders can unsend, and the chat notes it; outsiders are refused", async () => {
  const ctx = await setup();
  const m = await ctx.send("ada", { kind: "voice", media: { path: `chats/${ctx.chatId}/ada/v.m4a` } }, T0 + 10);
  await assert.rejects(ctx.chat.unsend("tobi", { chatId: ctx.chatId, messageId: m.id }, T0), /only delete what you sent/);
  assert.deepEqual(await ctx.chat.unsend("ada", { chatId: ctx.chatId, messageId: m.id }, T0 + 20), { deleted: true });
  assert.ok(ctx.deleted.includes(`chats/${ctx.chatId}/ada/v.m4a`));
  assert.equal((await ctx.store.get(`dm_chats/${ctx.chatId}/messages/sys_${m.id}`)).text, "deleted a chat");
  await assert.rejects(ctx.chat.markViewed("mallory", { chatId: ctx.chatId }, T0), /not in this chat/);
});

test("old chats migrate once per pair, kept, with media and voice notes", async () => {
  const { migrate } = require("../chat/scripts/migrate-legacy");
  const store = new MemoryStore();
  const rows = [
    { id: "a", data: { sender: "ada", receiver: "tobi", text: "hello", timeStamp: 1000 } },
    { id: "b", data: { sender: "tobi", receiver: "ada", audio: "https://x/v.m4a", audioDuration: 3.2, timeStamp: 2000 } },
    { id: "c", data: { sender: "ada", receiver: "tobi", text: "gone", isDeleted: true, timeStamp: 3000 } },
  ];
  const dry = await migrate({ store, pairs: [{ uid: "ada", peer: "tobi", rows }, { uid: "tobi", peer: "ada", rows }], apply: false });
  assert.deepEqual(dry, { chats: 1, messages: 2 });
  await migrate({ store, pairs: [{ uid: "ada", peer: "tobi", rows }, { uid: "tobi", peer: "ada", rows }], apply: true, now: 5000 });
  const chat = await store.get("dm_chats/ada_tobi");
  assert.equal(chat.retention, "keep");
  assert.equal(chat.last.senderId, "tobi");
  const voice = await store.get("dm_chats/ada_tobi/messages/legacy_b");
  assert.equal(voice.kind, "voice");
  assert.equal(voice.media.durationMs, 3200);
});
