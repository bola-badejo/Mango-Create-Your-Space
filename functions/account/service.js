"use strict";
// Accounts: onboarding in about a minute, usernames, profile completeness
// and the follow-up nudges to finish a profile.
const { LedgerError } = require("../ledger/service");

const fail = (code, message) => { throw new LedgerError(code, message); };
const DAY = 24 * 3600 * 1000;
const RESERVED = new Set(["admin", "mango", "support", "help", "official", "staff", "moderator", "settings", "root", "system", "about", "explore", "home", "login", "signup"]);

// Every field the app's user model reads, so new accounts never crash a screen.
const USER_DEFAULTS = {
  email: "", gender: "", bannerImageUrl: "", bannerImage: "", profileImage: "", profileImageUrl: "",
  bio: "", displayName: "", dob: "", country: "", city: "", state: "", profession: "", phone: "",
  username: "", fcmToken: null, fcmTokens: [], creatorID: "", vendorID: "", distributorID: "", hobbies: [],
  verified: false, isCreator: false, isVendor: false, isDistributor: false,
  creatorName: "", vendorName: "", distributorName: "", creatorImageUrl: "", vendorImageUrl: "", distributorImageUrl: "",
  creatorLogoUrl: "", vendorLogoUrl: "", distributorLogoUrl: "",
  followers: 0, following: 0, postCount: 0, likes: 0, views: 0,
};

const PROFILE_STEPS = [
  ["photo", (u) => !!(u.profileImage || u.profileImageUrl)],
  ["bio", (u) => !!(u.bio && u.bio.trim())],
  ["banner", (u) => !!(u.bannerImage || u.bannerImageUrl)],
  ["location", (u) => !!(u.country || u.city)],
  ["interests", (u) => Array.isArray(u.hobbies) && u.hobbies.length > 0],
];

function completeness(user) {
  const done = PROFILE_STEPS.filter(([, test]) => test(user || {})).map(([k]) => k);
  const missing = PROFILE_STEPS.map(([k]) => k).filter((k) => !done.includes(k));
  return { percent: Math.round((done.length / PROFILE_STEPS.length) * 100), done, missing };
}

function normalizeUsername(raw) {
  return String(raw || "").trim().replace(/^@/, "").toLowerCase();
}

function usernameProblem(u) {
  if (u.length < 3) return "At least 3 characters.";
  if (u.length > 20) return "At most 20 characters.";
  if (!/^[a-z0-9._]+$/.test(u)) return "Letters, numbers, dots and underscores only.";
  if (/^[._]|[._]$/.test(u) || /\.\./.test(u)) return "Can't start or end with a dot or underscore.";
  if (RESERVED.has(u)) return "That username is reserved.";
  return null;
}

function baseFromName(name, email) {
  const fromName = String(name || "").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "");
  const fromEmail = String(email || "").split("@")[0].toLowerCase().replace(/[^a-z0-9._]/g, "");
  const base = (fromName || fromEmail || "mango").slice(0, 14);
  return base.length >= 3 ? base : `${base}mango`.slice(0, 14);
}

class AccountService {
  constructor({ store, notifier, timestamp = (ms) => ms, random = Math.random }) {
    this.store = store;
    this.notifier = notifier;
    this.timestamp = timestamp;
    this.random = random;
  }

  async _taken(u, uid) {
    const reserved = await this.store.get(`usernames/${u}`);
    if (reserved && reserved.uid !== uid) return true;
    // Older accounts stored usernames only on their user document.
    const legacy = await this.store.query({ collection: "users", where: [["username", "==", u]], limit: 2 });
    return legacy.some((r) => r.id !== uid);
  }

  async checkUsername(uid, raw) {
    const u = normalizeUsername(raw);
    const problem = usernameProblem(u);
    if (problem) return { username: u, available: false, reason: problem };
    const taken = await this._taken(u, uid);
    return { username: u, available: !taken, reason: taken ? "That username is taken." : null };
  }

  async suggestUsername(uid, { name, email } = {}) {
    const base = baseFromName(name, email);
    const candidates = [base, ...Array.from({ length: 6 }, () => `${base}${Math.floor(this.random() * 9000 + 100)}`)];
    for (const c of candidates) {
      if (!usernameProblem(c) && !(await this._taken(c, uid))) return { username: c };
    }
    return { username: `${base}${Date.now() % 100000}` };
  }

  /** Has this person finished the quick start? */
  async status(uid) {
    const u = await this.store.get(`users/${uid}`);
    // Accounts from the old setup count as onboarded if they have a username.
    const onboarded = !!(u && ((u.onboarding && u.onboarding.completedAt) || (u.username && u.displayName)));
    return { onboarded, profile: completeness(u || {}) };
  }

  /**
   * The one-minute onboarding: name, username, optional photo and interests.
   * Creates (or completes) the user document, reserves the username, and
   * sends the welcome and "finish your profile" notifications.
   */
  async onboard(uid, input = {}, now, { email = "", phone = "", photoURL = "" } = {}) {
    if (!uid) fail("unauthenticated", "Sign in first.");
    const displayName = String(input.displayName || "").trim().replace(/\s+/g, " ");
    if (displayName.length < 2 || displayName.length > 50) fail("invalid-argument", "Your name should be 2 to 50 characters.");
    const username = normalizeUsername(input.username);
    const problem = usernameProblem(username);
    if (problem) fail("invalid-argument", problem);
    if (await this._taken(username, uid)) fail("already-exists", "That username was just taken. Try another.");
    const interests = Array.isArray(input.interests) ? input.interests.filter((i) => typeof i === "string").map((i) => i.trim()).filter(Boolean).slice(0, 12) : [];
    const photo = typeof input.photoUrl === "string" && /^https:\/\//.test(input.photoUrl) ? input.photoUrl : (photoURL || "");

    const user = await this.store.runTransaction(async (tx) => {
      const reserved = await tx.get(`usernames/${username}`);
      if (reserved && reserved.uid !== uid) fail("already-exists", "That username was just taken. Try another.");
      const existing = (await tx.get(`users/${uid}`)) || {};
      const previous = existing.username && normalizeUsername(existing.username) !== username ? normalizeUsername(existing.username) : null;
      // Firestore transactions read everything before writing.
      const prevDoc = previous ? await tx.get(`usernames/${previous}`) : null;
      const merged = {
        ...USER_DEFAULTS,
        ...existing,
        id: uid,
        email: existing.email || email,
        phone: existing.phone || phone,
        displayName,
        username,
        hobbies: interests.length ? interests : (existing.hobbies || []),
        profileImage: existing.profileImage || photo,
        profileImageUrl: existing.profileImageUrl || photo,
        onboarding: { ...(existing.onboarding || {}), completedAt: (existing.onboarding && existing.onboarding.completedAt) || now, version: 2, reminders: 0, lastReminderAt: null },
        createdAt: existing.createdAt || this.timestamp(now),
      };
      tx.set(`users/${uid}`, merged);
      tx.set(`usernames/${username}`, { uid, createdAt: now });
      if (previous && prevDoc && prevDoc.uid === uid) tx.delete(`usernames/${previous}`);
      return merged;
    });

    const first = displayName.split(" ")[0];
    await this.notifier.notify({
      to: uid, type: "welcome", title: `Welcome to Mango, ${first} 🥭`,
      body: "Follow creators, join Spaces, and earn MangoCoin when people enjoy what you share.",
      target: { kind: "explainer", id: "" }, push: false, now,
    });
    const p = completeness(user);
    if (p.missing.length) {
      await this.notifier.notify({
        to: uid, type: "complete_profile", title: "Finish your profile",
        body: `Add your ${p.missing.slice(0, 2).join(" and ")} so people recognise you. It takes a minute.`,
        target: { kind: "settings", id: "profile" }, group: "complete_profile", push: false, now: now + 1,
      });
    }
    return { onboarded: true, username, profile: p };
  }

  /** Scheduled: nudges people whose profile is still unfinished (max 3, 3 days apart). */
  async remindIncomplete(now, users) {
    let sent = 0;
    for (const { id, data } of users) {
      const o = data.onboarding || {};
      if (!o.completedAt || now - o.completedAt < DAY) continue;
      if ((o.reminders || 0) >= 3) continue;
      if (o.lastReminderAt && now - o.lastReminderAt < 3 * DAY) continue;
      const p = completeness(data);
      if (!p.missing.length) continue;
      await this.notifier.notify({
        to: id, type: "complete_profile", title: `Your profile is ${p.percent}% done`,
        body: `Add your ${p.missing.slice(0, 2).join(" and ")} to help people find you.`,
        target: { kind: "settings", id: "profile" }, group: "complete_profile", now,
      });
      await this.store.set(`users/${id}`, { onboarding: { ...o, reminders: (o.reminders || 0) + 1, lastReminderAt: now } }, { merge: true });
      sent += 1;
    }
    return { sent };
  }
}

/** Scheduled: "pick up where you left off" for unfinished books, episodes and films. */
async function remindToResume({ notifier, items, now }) {
  let sent = 0;
  for (const { uid, key, data } of items) {
    if (data.completed || !data.updatedMs) continue;
    const age = now - data.updatedMs;
    if (age < DAY || age > 4 * DAY) continue;
    if (data.remindedMs && data.remindedMs >= data.updatedMs) continue;
    const where = data.type === "book" && data.page ? `page ${data.page}${data.pageCount ? ` of ${data.pageCount}` : ""}` : (data.positionMs ? `${Math.round(data.positionMs / 60000)} min in` : "where you stopped");
    const verb = { book: "reading", podcast: "listening to", movie: "watching" }[data.type] || "enjoying";
    const res = await notifier.notify({
      to: uid, type: "reading_reminder", title: `Continue ${verb} "${data.title || "where you left off"}"`,
      body: `You're ${where}. Pick up where you left off.`, imageUrl: data.imageUrl || null,
      target: { kind: data.type, id: data.id }, group: `resume_${key}`, now,
    });
    if (res.delivered) sent += 1;
  }
  return { sent };
}

module.exports = { AccountService, remindToResume, completeness, normalizeUsername, usernameProblem, baseFromName, USER_DEFAULTS, PROFILE_STEPS };
