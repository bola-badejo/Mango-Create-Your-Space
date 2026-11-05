#!/usr/bin/env node
"use strict";
// Copies old chats (users/{uid}/chats/{peer}/messages) into Mango Chat
// (dm_chats/{a_b}/messages) so nobody loses their history. Migrated chats
// are set to "keep" so old messages don't start disappearing.
//   node chat/scripts/migrate-legacy.js            dry run
//   node chat/scripts/migrate-legacy.js --apply    write
const { chatIdFor } = require("../service");

function toMessage(old) {
  const at = old.timeStamp && old.timeStamp.toMillis ? old.timeStamp.toMillis() : (old.createdAt && old.createdAt.toMillis ? old.createdAt.toMillis() : Number(old.timeStamp) || Date.now());
  const media = old.image || old.video || old.audio || old.fileUrl;
  const kind = old.audio ? "voice" : old.image || old.video ? "media" : old.fileUrl ? "file" : "text";
  return {
    senderId: old.sender, kind,
    ...(old.text ? { text: String(old.text).slice(0, 2000) } : {}),
    ...(media ? { media: { url: media, path: "", mime: old.image ? "image/jpeg" : old.video ? "video/mp4" : old.audio ? "audio/mp4" : (old.fileType || "application/octet-stream"), name: old.fileName || "", durationMs: old.audioDuration ? Math.round(old.audioDuration * 1000) : undefined } } : {}),
    createdAt: at, serverAt: at, viewedBy: { [old.receiver]: at }, savedBy: [], expiresAt: null, migrated: true,
  };
}

async function migrate({ store, pairs, apply, now = Date.now() }) {
  const seen = new Set();
  let chats = 0;
  let messages = 0;
  for (const { uid, peer, rows } of pairs) {
    const chatId = chatIdFor(uid, peer);
    if (seen.has(chatId)) continue; // both users hold a copy; migrate once
    seen.add(chatId);
    const valid = rows.filter((r) => r.data.sender && r.data.receiver && !r.data.isDeleted);
    if (!valid.length) continue;
    chats += 1;
    messages += valid.length;
    if (!apply) continue;
    const members = [uid, peer].sort();
    const last = valid.map((r) => toMessage(r.data)).sort((a, b) => b.serverAt - a.serverAt)[0];
    await store.set(`dm_chats/${chatId}`, {
      members, createdAt: now, retention: "keep",
      last: { kind: last.kind, senderId: last.senderId, at: last.serverAt, preview: last.text || last.kind },
      state: { [members[0]]: { unread: 0, lastReadAt: now }, [members[1]]: { unread: 0, lastReadAt: now } },
      streak: { count: 0, lastSnapDay: {}, expiresAt: null },
    }, { merge: true });
    for (const r of valid) await store.set(`dm_chats/${chatId}/messages/legacy_${r.id}`, toMessage(r.data));
  }
  return { chats, messages };
}

async function main() {
  const apply = process.argv.includes("--apply");
  const { initializeApp } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");
  const { FirestoreStore } = require("../../ledger/stores/firestore");
  initializeApp();
  const db = getFirestore();
  const store = new FirestoreStore(db);
  const pairs = [];
  for (const user of (await db.collection("users").select().get()).docs) {
    for (const c of (await user.ref.collection("chats").get()).docs) {
      const rows = (await c.ref.collection("messages").get()).docs.map((d) => ({ id: d.id, data: d.data() }));
      pairs.push({ uid: user.id, peer: c.id, rows });
    }
  }
  const res = await migrate({ store, pairs, apply });
  console.log(`${res.chats} chats, ${res.messages} messages ${apply ? "migrated" : "(dry run)"}`);
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { migrate, toMessage };
