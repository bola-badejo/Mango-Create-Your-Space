"use strict";
// Mango Chat: one-to-one conversations with Snapchat-style logic.
//
//   Retention   chats delete after both people have viewed them (default),
//               or 24 hours after viewing, or never; anything saved in the
//               chat is kept until unsaved
//   Snaps       photos and videos that can be opened once, then expire
//   Streaks     both people send a snap within each day to keep it going;
//               an hourglass shows when it is about to end
//   Unsend      senders can delete what they sent; the chat notes it
//
// The summary, status, streak and expiry are computed here, never by the app.
const { LedgerError } = require("../ledger/service");

const fail = (code, message) => { throw new LedgerError(code, message); };
const DAY = 24 * 60 * 60 * 1000;
const RETENTION = ["after_viewing", "24h", "keep"];
const STREAK_GRACE = DAY; // a day without both sending ends the streak
const HOURGLASS_AT = 4 * 60 * 60 * 1000; // warn in the last 4 hours

const chatIdFor = (a, b) => [a, b].sort().join("_");
const dayOf = (ms) => Math.floor(ms / DAY);

function preview(msg) {
  switch (msg.kind) {
    case "snap": return msg.media && /^video\//.test(msg.media.mime || "") ? "Sent a video Snap" : "Sent a Snap";
    case "media": return /^video\//.test((msg.media && msg.media.mime) || "") ? "Sent a video" : "Sent a photo";
    case "voice": return "Sent a voice note";
    case "file": return "Sent a file";
    case "system": return msg.text || "";
    default: return (msg.text || "").slice(0, 120);
  }
}

/** Pure: updates a streak with a snap sent by `sender` at `now`. */
function updateStreak(streak, members, sender, now) {
  const s = { count: 0, lastSnapDay: {}, expiresAt: null, ...(streak || {}) };
  const today = dayOf(now);
  // Expired: start over.
  if (s.expiresAt && now > s.expiresAt) {
    s.count = 0;
    s.lastSnapDay = {};
  }
  const prev = { ...s.lastSnapDay };
  s.lastSnapDay = { ...s.lastSnapDay, [sender]: today };
  const other = members.find((m) => m !== sender);
  const bothToday = s.lastSnapDay[other] === today;
  const wasBothToday = prev[sender] === today && prev[other] === today;
  if (bothToday && !wasBothToday) {
    // First time today that both have snapped: the streak grows.
    s.count += 1;
    s.expiresAt = (today + 1) * DAY + STREAK_GRACE;
  }
  return s;
}

function streakView(streak, now) {
  if (!streak || !streak.count || (streak.expiresAt && now > streak.expiresAt)) return { count: 0, hourglass: false };
  return { count: streak.count, hourglass: !!streak.expiresAt && streak.expiresAt - now < HOURGLASS_AT };
}

function expiryAfterView(msg, retention, now) {
  if (msg.kind === "system") return null;
  if ((msg.savedBy || []).length) return null;
  if (msg.kind === "snap") return now; // view once
  if (retention === "keep") return null;
  if (retention === "24h") return now + DAY;
  return now; // after viewing
}

class ChatService {
  /**
   * @param {object} deps
   * @param {object} deps.store
   * @param {(path:string)=>Promise<void>} [deps.deleteFile] Storage deletion
   * @param {(uid:string)=>Promise<boolean>} [deps.userExists]
   */
  constructor({ store, deleteFile = async () => {}, userExists = async () => true }) {
    this.store = store;
    this.deleteFile = deleteFile;
    this.userExists = userExists;
  }

  async _member(uid, chatId) {
    if (!uid) fail("unauthenticated", "Sign in first.");
    if (typeof chatId !== "string" || !/^[A-Za-z0-9_-]{3,260}$/.test(chatId)) fail("invalid-argument", "Invalid chat.");
    const chat = await this.store.get(`dm_chats/${chatId}`);
    if (!chat || !(chat.members || []).includes(uid)) fail("permission-denied", "You're not in this chat.");
    return chat;
  }

  /** Opens (or creates) the one-to-one chat with `peerId`. */
  async open(uid, { peerId } = {}, now) {
    if (!uid) fail("unauthenticated", "Sign in first.");
    if (typeof peerId !== "string" || !peerId || peerId === uid) fail("invalid-argument", "Choose someone to chat with.");
    if (!(await this.userExists(peerId))) fail("not-found", "That person doesn't have an account.");
    const chatId = chatIdFor(uid, peerId);
    return this.store.runTransaction(async (tx) => {
      const existing = await tx.get(`dm_chats/${chatId}`);
      if (existing) return { chatId, created: false };
      const members = [uid, peerId].sort();
      tx.set(`dm_chats/${chatId}`, {
        members, createdAt: now, retention: "after_viewing",
        last: null, state: { [members[0]]: { unread: 0, lastReadAt: 0 }, [members[1]]: { unread: 0, lastReadAt: 0 } },
        streak: { count: 0, lastSnapDay: {}, expiresAt: null },
      });
      return { chatId, created: true };
    });
  }

  /**
   * Trigger: a message was written by the app. Verifies it, then updates the
   * chat summary, unread count and streak, and returns a notification to send.
   */
  async onMessage({ chatId, msgId, data, authId, now }) {
    const path = `dm_chats/${chatId}/messages/${msgId}`;
    const chat = await this.store.get(`dm_chats/${chatId}`);
    const valid = chat && authId && data && data.senderId === authId && (chat.members || []).includes(authId);
    if (!valid) {
      await this.store.delete(path);
      if (data && data.media && data.media.path) await this.deleteFile(data.media.path);
      return { accepted: false, reason: "forged" };
    }
    const peer = chat.members.find((m) => m !== authId);
    return this.store.runTransaction(async (tx) => {
      const c = await tx.get(`dm_chats/${chatId}`);
      const state = { ...(c.state || {}) };
      state[peer] = { ...(state[peer] || {}), unread: ((state[peer] || {}).unread || 0) + 1 };
      state[authId] = { ...(state[authId] || {}), lastSentAt: now };
      const update = {
        ...c,
        state,
        last: { kind: data.kind, senderId: authId, at: now, preview: preview(data), msgId },
      };
      if (data.kind === "snap") update.streak = updateStreak(c.streak, c.members, authId, now);
      tx.set(`dm_chats/${chatId}`, update);
      tx.set(path, { ...data, serverAt: now, viewedBy: {}, savedBy: [], expiresAt: null }, { merge: true });
      return {
        accepted: true,
        notify: { receiverId: peer, senderId: authId, title: data.kind === "snap" ? "New Snap" : "New Chat", body: data.kind === "text" ? preview(data) : preview(data) },
      };
    });
  }

  /** Marks everything the caller has seen as viewed and schedules expiry. */
  async markViewed(uid, { chatId } = {}, now) {
    const chat = await this._member(uid, chatId);
    const lastReadAt = ((chat.state || {})[uid] || {}).lastReadAt || 0;
    const rows = await this.store.query({ collection: `dm_chats/${chatId}/messages`, where: [["serverAt", ">", lastReadAt]], orderBy: "serverAt", limit: 300 });
    return this.store.runTransaction(async (tx) => {
      const c = await tx.get(`dm_chats/${chatId}`);
      let viewed = 0;
      for (const r of rows) {
        const m = r.data;
        if (m.senderId === uid || (m.viewedBy || {})[uid]) continue;
        // Snaps are opened one at a time with openSnap.
        if (m.kind === "snap") continue;
        tx.set(`dm_chats/${chatId}/messages/${r.id}`, { viewedBy: { ...(m.viewedBy || {}), [uid]: now }, expiresAt: expiryAfterView(m, c.retention, now) }, { merge: true });
        viewed += 1;
      }
      const state = { ...(c.state || {}) };
      state[uid] = { ...(state[uid] || {}), unread: 0, lastReadAt: now };
      tx.set(`dm_chats/${chatId}`, { ...c, state });
      return { viewed };
    });
  }

  /** Opens a snap once. Returns its media; it expires right after. */
  async openSnap(uid, { chatId, messageId } = {}, now) {
    await this._member(uid, chatId);
    const path = `dm_chats/${chatId}/messages/${messageId}`;
    return this.store.runTransaction(async (tx) => {
      const m = await tx.get(path);
      if (!m || m.kind !== "snap") fail("not-found", "That Snap is no longer available.");
      if (m.senderId === uid) fail("failed-precondition", "You sent this Snap.");
      if ((m.viewedBy || {})[uid]) fail("failed-precondition", "You've already opened this Snap.");
      tx.set(path, { viewedBy: { ...(m.viewedBy || {}), [uid]: now }, expiresAt: now + 60_000 }, { merge: true });
      return { media: m.media, durationMs: m.kind === "snap" ? (m.media && m.media.durationMs) || 10_000 : null };
    });
  }

  /** Saves a message in the chat for both people, or unsaves it. */
  async toggleSave(uid, { chatId, messageId } = {}, now) {
    const chat = await this._member(uid, chatId);
    const path = `dm_chats/${chatId}/messages/${messageId}`;
    return this.store.runTransaction(async (tx) => {
      const m = await tx.get(path);
      if (!m || m.kind === "system") fail("not-found", "That message is gone.");
      if (m.kind === "snap") fail("failed-precondition", "Snaps can't be saved in chat.");
      const saved = new Set(m.savedBy || []);
      const nowSaved = !saved.has(uid);
      if (nowSaved) saved.add(uid); else saved.delete(uid);
      const peerViewed = Object.keys(m.viewedBy || {}).some((v) => v !== m.senderId);
      const expiresAt = saved.size ? null : (peerViewed ? expiryAfterView({ ...m, savedBy: [] }, chat.retention, now) : null);
      tx.set(path, { savedBy: [...saved], expiresAt }, { merge: true });
      return { saved: nowSaved, savedBy: [...saved] };
    });
  }

  /** Sender deletes what they sent, for both people. */
  async unsend(uid, { chatId, messageId } = {}, now) {
    await this._member(uid, chatId);
    const path = `dm_chats/${chatId}/messages/${messageId}`;
    const m = await this.store.get(path);
    if (!m) return { deleted: false };
    if (m.senderId !== uid) fail("permission-denied", "You can only delete what you sent.");
    await this.store.delete(path);
    if (m.media && m.media.path) await this.deleteFile(m.media.path);
    await this.store.set(`dm_chats/${chatId}/messages/sys_${messageId}`, { senderId: uid, kind: "system", text: "deleted a chat", createdAt: now, serverAt: now, viewedBy: {}, savedBy: [], expiresAt: now + DAY });
    return { deleted: true };
  }

  async setRetention(uid, { chatId, mode } = {}, now) {
    await this._member(uid, chatId);
    if (!RETENTION.includes(mode)) fail("invalid-argument", "Unknown setting.");
    await this.store.set(`dm_chats/${chatId}`, { retention: mode }, { merge: true });
    const label = { after_viewing: "set chats to delete after viewing", "24h": "set chats to delete 24 hours after viewing", keep: "set chats to be kept" }[mode];
    await this.store.set(`dm_chats/${chatId}/messages/sys_ret_${now}`, { senderId: uid, kind: "system", text: label, createdAt: now, serverAt: now, viewedBy: {}, savedBy: [], expiresAt: now + DAY });
    return { retention: mode };
  }

  /** Scheduled: deletes expired messages and their media files. */
  async cleanup(now, { listExpired } = {}) {
    const rows = await listExpired(now);
    let deleted = 0;
    for (const { path, data } of rows) {
      if ((data.savedBy || []).length) continue;
      await this.store.delete(path);
      if (data.media && data.media.path) await this.deleteFile(data.media.path);
      deleted += 1;
    }
    return { deleted };
  }
}

module.exports = { ChatService, chatIdFor, updateStreak, streakView, expiryAfterView, preview, DAY, RETENTION };
