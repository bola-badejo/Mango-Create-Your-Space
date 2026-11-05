"use strict";
// Mango notifications: one path for every notification in the app.
//
//   in-app   users/{uid}/notifications/{id}   (what the notification centre shows)
//   push     FCM to the user's devices         (respecting mute and settings)
//
// Repeats are grouped ("Ada and 3 others liked your post"), pushes are rate
// limited per person, dead device tokens are removed, and every type maps to
// a setting the person can turn off.
const crypto = require("crypto");

// Which setting controls each type (users/{uid}.notificationPrefs[key]).
const PREF = {
  like: "likes", reply: "comments", mention: "comments", follow: "follows",
  space_message: "spaces", space_live: "spaces",
  content_milestone: "content", reading_reminder: "reading",
  welcome: "account", complete_profile: "account", system: "account",
};

const MILESTONES = [1, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000];
const PUSH_PER_HOUR = 20;
const HOUR = 3600 * 1000;

function joinNames(names, count) {
  const shown = names.filter(Boolean).slice(0, 2);
  const others = count - shown.length;
  if (shown.length === 0) return count === 1 ? "Someone" : `${count} people`;
  if (others <= 0) return shown.join(" and ");
  return `${shown.join(", ")} and ${others} other${others === 1 ? "" : "s"}`;
}

function groupedTitle(type, names, count, extra = {}) {
  const who = joinNames(names, count);
  switch (type) {
    case "like": return `${who} liked your post`;
    case "follow": return `${who} started following you`;
    case "space_message": return `${who} left ${count === 1 ? "a message" : "messages"} in ${extra.spaceTitle || "your Space"}`;
    default: return null;
  }
}

class Notifier {
  /**
   * @param {object} deps
   * @param {object} deps.store
   * @param {(tokens:string[], payload:object)=>Promise<{invalid:string[]}>} [deps.push]
   * @param {(ms:number)=>any} [deps.timestamp] Firestore Timestamp in production
   */
  constructor({ store, push = async () => ({ invalid: [] }), timestamp = (ms) => ms }) {
    this.store = store;
    this.push = push;
    this.timestamp = timestamp;
  }

  /**
   * Sends one notification. Returns { delivered, pushed, id } or { skipped }.
   * `group` merges repeats of the same thing into one entry.
   */
  async notify({ to, type, actorId = null, actorName = "", title, body = "", imageUrl = null, target = null, group = null, extra = {}, push = true, now = Date.now() }) {
    if (!to || !type) return { skipped: "invalid" };
    if (actorId && actorId === to) return { skipped: "self" };
    const user = await this.store.get(`users/${to}`);
    if (!user) return { skipped: "no_user" };
    const prefs = user.notificationPrefs || {};
    const key = PREF[type] || "account";
    if (prefs[key] === false) return { skipped: "disabled" };
    const blocked = Array.isArray(user.blockedUsers) ? user.blockedUsers : [];
    if (actorId && blocked.includes(actorId)) return { skipped: "blocked" };

    const id = group ? `g_${crypto.createHash("sha1").update(`${type}:${group}`).digest("hex").slice(0, 20)}` : `n_${crypto.randomBytes(10).toString("hex")}`;
    const path = `users/${to}/notifications/${id}`;
    const entry = await this.store.runTransaction(async (tx) => {
      const existing = group ? await tx.get(path) : null;
      const fresh = !existing || existing.isRead || now - (existing.createdMs || 0) > 24 * HOUR;
      const actors = fresh ? [] : (existing.actors || []);
      const actorIds = fresh ? [] : (existing.actorIds || []);
      if (actorId && !actorIds.includes(actorId)) {
        actorIds.unshift(actorId);
        actors.unshift(actorName || "Someone");
      }
      // With actors, count people; without, count occurrences.
      const count = actorId ? actorIds.length : (fresh ? 1 : (existing.count || 1) + 1);
      const doc = {
        id, type,
        title: (group && groupedTitle(type, actors, count, extra)) || title,
        body, imageUrl, target, actorId, actorIds: actorIds.slice(0, 20), actors: actors.slice(0, 20), count,
        isRead: false, createdMs: fresh ? now : existing.createdMs, updatedMs: now, timestamp: this.timestamp(now),
      };
      tx.set(path, doc);
      return doc;
    });

    if (!push) return { delivered: true, pushed: false, id };
    if (user.muteUntil && Number(user.muteUntil._seconds ? user.muteUntil._seconds * 1000 : user.muteUntil) > now) return { delivered: true, pushed: false, id, reason: "muted" };
    if (user.notificationsEnabled === false) return { delivered: true, pushed: false, id, reason: "push_off" };
    const allowed = await this.store.runTransaction(async (tx) => {
      const r = (await tx.get(`notify_rate/${to}`)) || { windowStart: now, count: 0 };
      const next = now - r.windowStart > HOUR ? { windowStart: now, count: 1 } : { windowStart: r.windowStart, count: r.count + 1 };
      tx.set(`notify_rate/${to}`, next);
      return next.count <= PUSH_PER_HOUR;
    });
    if (!allowed) return { delivered: true, pushed: false, id, reason: "rate_limited" };
    const tokens = [...new Set([...(Array.isArray(user.fcmTokens) ? user.fcmTokens : []), ...(user.fcmToken ? [user.fcmToken] : [])])].filter(Boolean);
    if (!tokens.length) return { delivered: true, pushed: false, id, reason: "no_tokens" };
    const res = await this.push(tokens, {
      notification: { title: entry.title, body: entry.body },
      data: { type, notificationId: id, targetKind: (target && target.kind) || "", targetId: (target && target.id) || "" },
    });
    if (res && res.invalid && res.invalid.length) {
      const keep = tokens.filter((t) => !res.invalid.includes(t));
      await this.store.set(`users/${to}`, { fcmTokens: keep, ...(res.invalid.includes(user.fcmToken) ? { fcmToken: null } : {}) }, { merge: true });
    }
    return { delivered: true, pushed: true, id };
  }

  /** Counts a play/read/view and tells the creator when a milestone is reached. */
  async countAndCelebrate({ type, id, title, ownerId, imageUrl = null, now = Date.now() }) {
    if (!ownerId) return { milestone: null };
    const path = `media_stats/${type}_${id}`;
    const n = await this.store.runTransaction(async (tx) => {
      const s = (await tx.get(path)) || { starts: 0 };
      const next = { starts: (s.starts || 0) + 1, type, id, ownerId };
      tx.set(path, next);
      return next.starts;
    });
    if (!MILESTONES.includes(n)) return { milestone: null };
    const noun = { song: "play", podcast: "listen", movie: "view", book: "read" }[type] || "view";
    const msg = n === 1 ? `Someone just ${type === "book" ? "started reading" : type === "movie" ? "watched" : "played"} "${title}" for the first time` : `"${title}" reached ${n.toLocaleString("en-US")} ${noun}s`;
    await this.notify({
      to: ownerId, type: "content_milestone", title: n === 1 ? "Your first fan 🎉" : "Milestone 🎉", body: msg, imageUrl,
      target: { kind: type, id }, now,
    });
    return { milestone: n };
  }
}

module.exports = { Notifier, PREF, MILESTONES, joinNames, groupedTitle, PUSH_PER_HOUR };
