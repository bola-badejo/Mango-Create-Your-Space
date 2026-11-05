"use strict";
// Mango Spaces (virtual Spaces) server logic. Anything that must not be
// forged runs here: creating a Space and its @handle, buying items with
// MangoCoin, applying owned skins and icons, running live events, and
// moderating the message wall. Placing objects, presence and wall posts are
// direct Firestore writes, guarded by firestore.rules.
const crypto = require("crypto");
const CATALOG = require("./catalog.json");
const { parseMng } = require("../ledger/units");
const { TREASURY_UID, LedgerError } = require("../ledger/service");

const ITEMS = Object.fromEntries(CATALOG.items.map((i) => [i.id, { ...i, priceUnits: parseMng(i.price) }]));
const FREE_ITEMS = CATALOG.items.filter((i) => i.price === "0").map((i) => i.id);

const VISIBILITY = ["public", "members", "private"];
const MAX_SPACES_PER_OWNER = 20;
const MAX_UPCOMING_EVENTS = 20;
const WALL_MAX_LENGTH = 500;
const WALL_RATE = { windowMs: 60_000, max: 6 };
const RESERVED = new Set(["admin", "mango", "support", "help", "official", "staff", "moderator", "settings", "new", "explore", "featured", "api", "root", "system"]);

// Starter layouts. Coordinates are 0..1 of the Space canvas.
const BUILTIN_OBJECTS = {
  wall: { kind: "wall", label: "Message wall", x: 0.22, y: 0.34 },
  events: { kind: "events", label: "Live stage", x: 0.78, y: 0.34 },
};
const TEMPLATES = {
  creator: {
    label: "Creator studio", category: "Creator",
    pods: { hasMusic: true, hasPodcast: true, hasMovies: true, hasBooks: false, hasLounge: true },
    skinId: "skin.meadow", iconId: "icon.star",
  },
  music: {
    label: "Music room", category: "Music",
    pods: { hasMusic: true, hasPodcast: true, hasMovies: false, hasBooks: false, hasLounge: true },
    skinId: "skin.midnight", iconId: "icon.mango",
  },
  books: {
    label: "Book club", category: "Books",
    pods: { hasMusic: false, hasPodcast: false, hasMovies: false, hasBooks: true, hasLounge: true },
    skinId: "skin.meadow", iconId: "icon.mango",
  },
  shop: {
    label: "Shop", category: "Shop",
    pods: { hasMusic: false, hasPodcast: false, hasMovies: false, hasBooks: false, hasLounge: true },
    skinId: "skin.meadow", iconId: "icon.star",
  },
  community: {
    label: "Community", category: "Community",
    pods: { hasMusic: false, hasPodcast: true, hasMovies: false, hasBooks: false, hasLounge: true },
    skinId: "skin.midnight", iconId: "icon.star",
  },
};

const STARTER_DECOR = [
  { itemId: "obj.welcome", x: 0.5, y: 0.14 },
  { itemId: "obj.plant", x: 0.1, y: 0.82 },
  { itemId: "obj.lamp", x: 0.9, y: 0.82 },
];

const fail = (code, message) => { throw new LedgerError(code, message); };
const newId = (prefix) => `${prefix}${crypto.randomBytes(10).toString("hex")}`;

function normalizeHandle(raw) {
  return String(raw || "").trim().replace(/^@/, "").toLowerCase();
}

function handleProblem(handle) {
  if (handle.length < 3) return "Handles need at least 3 characters.";
  if (handle.length > 30) return "Handles can be at most 30 characters.";
  if (!/^[a-z0-9_]+$/.test(handle)) return "Use only letters, numbers and underscores.";
  if (handle.startsWith("_") || handle.endsWith("_")) return "Handles can't start or end with an underscore.";
  if (RESERVED.has(handle)) return "That handle is reserved.";
  return null;
}

function cleanText(value, { min = 0, max, field }) {
  const text = typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
  if (text.length < min) fail("invalid-argument", `${field} needs at least ${min} characters.`);
  if (text.length > max) fail("invalid-argument", `${field} can be at most ${max} characters.`);
  return text;
}

function isEditor(space, uid) {
  return !!space && !!uid && (space.ownerId === uid || space.postCreator === uid || (space.editors || []).includes(uid));
}

class SpaceService {
  /**
   * @param {object} deps
   * @param {object} deps.store    MemoryStore or FirestoreStore
   * @param {object} deps.ledger   MangoLedger (purchases go through it)
   * @param {(ms:number)=>any} [deps.timestamp] value for legacy `timeStamp`
   */
  constructor({ store, ledger, timestamp = (ms) => ms }) {
    this.store = store;
    this.ledger = ledger;
    this.timestamp = timestamp;
  }

  static catalog() {
    return CATALOG;
  }

  async checkHandle(raw) {
    const handle = normalizeHandle(raw);
    const problem = handleProblem(handle);
    if (problem) return { handle, available: false, reason: problem };
    const taken = await this.store.get(`space_handles/${handle}`);
    return { handle, available: !taken, reason: taken ? "That handle is taken." : null };
  }

  /** Creates a Space with its handle, starter items and starter layout, atomically. */
  async create(uid, input, now) {
    if (!uid) fail("unauthenticated", "Sign in to create a Space.");
    const data = input || {};
    const title = cleanText(data.title, { min: 3, max: 60, field: "Name" });
    const description = cleanText(data.description || "", { max: 500, field: "Description" });
    const template = TEMPLATES[data.template] ? data.template : fail("invalid-argument", "Choose what your Space is for.");
    const visibility = VISIBILITY.includes(data.visibility) ? data.visibility : fail("invalid-argument", "Choose who can enter.");
    const handle = normalizeHandle(data.handle);
    const problem = handleProblem(handle);
    if (problem) fail("invalid-argument", problem);
    const t = TEMPLATES[template];
    const skinId = data.skinId || t.skinId;
    const iconId = data.iconId || t.iconId;
    for (const [id, kind] of [[skinId, "skin"], [iconId, "icon"]]) {
      const item = ITEMS[id];
      if (!item || item.kind !== kind) fail("invalid-argument", `Unknown ${kind}.`);
      if (item.priceUnits !== 0n) fail("failed-precondition", `Buy ${item.name} in the shop after creating your Space.`);
    }

    const spaceId = newId("s");
    return this.store.runTransaction(async (tx) => {
      const taken = await tx.get(`space_handles/${handle}`);
      const counter = (await tx.get(`space_owners/${uid}`)) || { count: 0 };
      if (taken) fail("already-exists", "That handle was just taken. Try another.");
      if (counter.count >= MAX_SPACES_PER_OWNER) fail("resource-exhausted", `You can own up to ${MAX_SPACES_PER_OWNER} Spaces.`);

      const space = {
        title, description, category: data.category ? cleanText(data.category, { max: 40, field: "Category" }) : t.category,
        price: "0", ...t.pods,
        isPrivate: visibility !== "public", visibility,
        collaborators: [], editors: [uid], ownerId: uid, postCreator: uid,
        handle, template, theme: { skinId, iconId },
        world: { version: 1 }, members: 1,
        createdAt: now, timeStamp: this.timestamp(now),
      };
      tx.set(`spaces/${spaceId}`, space);
      tx.set(`space_handles/${handle}`, { spaceId, ownerId: uid, createdAt: now });
      tx.set(`space_owners/${uid}`, { count: counter.count + 1 });
      tx.set(`spaces/${spaceId}/subscribers/${uid}`, { userId: uid, role: "owner", joinedAt: now });
      for (const itemId of FREE_ITEMS) {
        tx.set(`spaces/${spaceId}/inventory/${itemId}`, { itemId, kind: ITEMS[itemId].kind, acquiredAt: now, source: "starter" });
      }
      for (const b of Object.values(BUILTIN_OBJECTS)) tx.set(`spaces/${spaceId}/objects/${newId("o")}`, { ...b, scale: 1, z: 1, createdAt: now, createdBy: uid });
      for (const d of STARTER_DECOR) {
        tx.set(`spaces/${spaceId}/objects/${newId("o")}`, { kind: "decor", itemId: d.itemId, x: d.x, y: d.y, scale: 1, z: 0, label: ITEMS[d.itemId].name, createdAt: now, createdBy: uid });
      }
      return { spaceId, handle };
    });
  }

  async _editableSpace(uid, spaceId) {
    if (typeof spaceId !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(spaceId)) fail("invalid-argument", "Invalid Space.");
    const space = await this.store.get(`spaces/${spaceId}`);
    if (!space) fail("not-found", "That Space doesn't exist.");
    if (!isEditor(space, uid)) fail("permission-denied", "Only the Space's owner or editors can do that.");
    return space;
  }

  /** Buys a catalog item for a Space: payment and ownership commit together. */
  async buyItem(uid, { spaceId, itemId } = {}, now) {
    await this._editableSpace(uid, spaceId);
    const item = ITEMS[itemId];
    if (!item) fail("not-found", "That item isn't in the shop.");
    const invPath = `spaces/${spaceId}/inventory/${itemId}`;
    if (item.priceUnits === 0n) {
      const owned = await this.store.get(invPath);
      if (!owned) await this.store.set(invPath, { itemId, kind: item.kind, acquiredAt: now, source: "free" });
      return { itemId, owned: true, paid: "0" };
    }
    const result = await this.ledger.transfer(
      uid,
      { to: TREASURY_UID, amount: item.priceUnits.toString(), memo: `Space item ${itemId}`, idempotencyKey: `space-buy:${spaceId}:${itemId}` },
      now,
      {
        read: async (tx) => {
          if (await tx.get(invPath)) fail("already-exists", "This Space already owns that item.");
        },
        write: (tx, _ctx, payment) => {
          tx.set(invPath, { itemId, kind: item.kind, acquiredAt: now, source: "purchase", txId: payment.txId, buyer: uid });
        },
      },
    );
    return { itemId, owned: true, paid: item.priceUnits.toString(), txId: result.txId, balance: result.balance, duplicate: !!result.duplicate };
  }

  /** Applies an owned skin and/or icon. */
  async applyTheme(uid, { spaceId, skinId, iconId } = {}) {
    const space = await this._editableSpace(uid, spaceId);
    const theme = { ...(space.theme || {}) };
    for (const [id, kind, key] of [[skinId, "skin", "skinId"], [iconId, "icon", "iconId"]]) {
      if (id === undefined || id === null) continue;
      const item = ITEMS[id];
      if (!item || item.kind !== kind) fail("invalid-argument", `Unknown ${kind}.`);
      const owned = await this.store.get(`spaces/${spaceId}/inventory/${id}`);
      if (!owned && item.priceUnits !== 0n) fail("failed-precondition", `Buy ${item.name} first.`);
      theme[key] = id;
    }
    await this.store.set(`spaces/${spaceId}`, { theme }, { merge: true });
    return { theme };
  }

  // ------------------------------------------------------------- events
  async createEvent(uid, { spaceId, title, description, startsAt, durationMinutes } = {}, now) {
    await this._editableSpace(uid, spaceId);
    const cleanTitle = cleanText(title, { min: 3, max: 80, field: "Event title" });
    const cleanDescription = cleanText(description || "", { max: 500, field: "Event description" });
    const start = Number(startsAt);
    const minutes = Number(durationMinutes || 60);
    if (!Number.isFinite(start) || start < now - 5 * 60_000 || start > now + 90 * 86_400_000) {
      fail("invalid-argument", "Pick a start time between now and 90 days from now.");
    }
    if (!Number.isInteger(minutes) || minutes < 15 || minutes > 480) fail("invalid-argument", "Events last between 15 minutes and 8 hours.");
    const upcoming = await this.store.query({ collection: `spaces/${spaceId}/events`, where: [["status", "==", "scheduled"]], limit: MAX_UPCOMING_EVENTS + 1 });
    if (upcoming.length >= MAX_UPCOMING_EVENTS) fail("resource-exhausted", `A Space can have up to ${MAX_UPCOMING_EVENTS} upcoming events.`);
    const eventId = newId("e");
    const event = {
      title: cleanTitle, description: cleanDescription, hostId: uid,
      startsAt: Math.floor(start), endsAt: Math.floor(start) + minutes * 60_000,
      status: "scheduled", createdAt: now, startedAt: null, endedAt: null,
    };
    await this.store.set(`spaces/${spaceId}/events/${eventId}`, event);
    return { eventId, ...event };
  }

  async setEventStatus(uid, { spaceId, eventId, status } = {}, now) {
    const space = await this._editableSpace(uid, spaceId);
    const path = `spaces/${spaceId}/events/${eventId}`;
    return this.store.runTransaction(async (tx) => {
      const event = await tx.get(path);
      if (!event) fail("not-found", "That event doesn't exist.");
      if (event.hostId !== uid && !isEditor(space, uid)) fail("permission-denied", "Only the host can do that.");
      const allowed = { scheduled: ["live", "cancelled"], live: ["ended"] };
      if (!(allowed[event.status] || []).includes(status)) fail("failed-precondition", `An event that is ${event.status} can't become ${status}.`);
      const update = { ...event, status };
      if (status === "live") update.startedAt = now;
      if (status === "ended") update.endedAt = now;
      tx.set(path, update);
      if (status === "live") tx.set(`spaces/${spaceId}`, { liveEventId: eventId }, { merge: true });
      if (status === "ended") tx.set(`spaces/${spaceId}`, { liveEventId: null }, { merge: true });
      return { eventId, status };
    });
  }

  // ------------------------------------------------------- moderation
  /**
   * Checks a newly written wall or event-chat message. Returns
   * { keep: true } or { keep: false, reason } after deleting it.
   */
  async moderateMessage({ path, spaceId, data, authId, now }) {
    const remove = async (reason) => { await this.store.delete(path); return { keep: false, reason }; };
    if (!authId || !data || data.authorId !== authId) return remove("forged_author");
    const text = typeof data.text === "string" ? data.text.trim() : "";
    if (!text || text.length > WALL_MAX_LENGTH) return remove("invalid_text");
    const ratePath = `space_rate/${spaceId}_${authId}`;
    return this.store.runTransaction(async (tx) => {
      const rate = (await tx.get(ratePath)) || { windowStart: now, count: 0 };
      const fresh = now - rate.windowStart > WALL_RATE.windowMs;
      const next = fresh ? { windowStart: now, count: 1 } : { windowStart: rate.windowStart, count: rate.count + 1 };
      tx.set(ratePath, next);
      if (next.count > WALL_RATE.max) {
        tx.delete(path);
        return { keep: false, reason: "rate_limited" };
      }
      return { keep: true };
    });
  }
}

module.exports = { SpaceService, ITEMS, FREE_ITEMS, TEMPLATES, VISIBILITY, normalizeHandle, handleProblem, isEditor, WALL_RATE, CATALOG };
