"use strict";
// Taste model, recommendations and AI shuffle for every media type.
//
// The server learns from what people actually do: starting, finishing and
// skipping songs, podcasts, films and books. Taste is a small, decaying
// profile of affinities (genres or categories, and creators), so it adapts
// as someone's listening changes, and it never leaves the server except to
// its owner.
const { LedgerError } = require("../ledger/service");

const fail = (code, message) => { throw new LedgerError(code, message); };

// Where each media type lives and which fields describe it.
const SOURCES = {
  song: { collection: "music", genre: "genre", creator: "artistId", title: "title", image: "artworkUrl", creatorName: "artistName", plays: "plays" },
  podcast: { collection: "podcasts", genre: "category", creator: "userId", title: "title", image: "artworkUrl", creatorName: "host", plays: "plays" },
  movie: { collection: "movies", genre: "genre", creator: "userId", title: "title", image: "posterUrl", creatorName: "director", plays: "views" },
  book: { collection: "books", genre: "genre", creator: "uploaderId", title: "title", image: "coverUrl", creatorName: "author", plays: "reads" },
};

const EVENTS = { start: 0.5, complete: 2.0, skip: -1.5, like: 3.0, save: 2.5 };
const DECAY = 0.97; // applied per event, so recent taste weighs more
const MAX_KEYS = 60; // per map, keeps the profile small
const HISTORY = 200;

function clampMap(map) {
  const entries = Object.entries(map).filter(([, v]) => Math.abs(v) > 0.01);
  entries.sort((a, b) => Math.abs(b[1]) - Math.abs(a[1]));
  return Object.fromEntries(entries.slice(0, MAX_KEYS).map(([k, v]) => [k, Math.round(v * 1000) / 1000]));
}

function decay(map) {
  return Object.fromEntries(Object.entries(map || {}).map(([k, v]) => [k, v * DECAY]));
}

/** Pure: returns a new profile after one event. */
function updateProfile(profile, { type, event, item, positionSec = 0, durationSec = 0 }) {
  const p = profile || { genres: {}, creators: {}, types: {}, skips: {}, recent: [], events: 0 };
  let weight = EVENTS[event];
  if (weight === undefined) fail("invalid-argument", "Unknown event.");
  // A skip in the first 30 seconds says more than one near the end.
  if (event === "skip" && durationSec > 0) weight *= positionSec / durationSec < 0.25 ? 1 : 0.4;
  const genres = decay(p.genres);
  const creators = decay(p.creators);
  const types = decay(p.types);
  const g = item.genre ? `${type}:${String(item.genre).toLowerCase()}` : null;
  const c = item.creatorId ? `${type}:${item.creatorId}` : null;
  if (g) genres[g] = (genres[g] || 0) + weight;
  if (c) creators[c] = (creators[c] || 0) + weight;
  types[type] = (types[type] || 0) + Math.max(weight, 0);
  const skips = { ...(p.skips || {}) };
  if (event === "skip") skips[`${type}:${item.id}`] = (skips[`${type}:${item.id}`] || 0) + 1;
  const recent = [`${type}:${item.id}`, ...(p.recent || []).filter((r) => r !== `${type}:${item.id}`)].slice(0, HISTORY);
  return { genres: clampMap(genres), creators: clampMap(creators), types: clampMap(types), skips: clampMap(skips), recent, events: (p.events || 0) + 1 };
}

/** Pure: how much this profile is expected to enjoy an item. */
function score(profile, type, item, { seed } = {}) {
  const p = profile || {};
  const g = item.genre ? (p.genres || {})[`${type}:${String(item.genre).toLowerCase()}`] || 0 : 0;
  const c = item.creatorId ? (p.creators || {})[`${type}:${item.creatorId}`] || 0 : 0;
  const skipped = (p.skips || {})[`${type}:${item.id}`] || 0;
  const recentIdx = (p.recent || []).indexOf(`${type}:${item.id}`);
  const recency = recentIdx === -1 ? 0 : recentIdx < 10 ? -3 : recentIdx < 50 ? -1 : 0;
  const popularity = Math.log10(1 + (item.plays || 0)) * 0.3;
  let s = g * 1.0 + c * 0.8 - skipped * 1.2 + recency + popularity;
  if (seed) {
    if (seed.genre && item.genre && String(seed.genre).toLowerCase() === String(item.genre).toLowerCase()) s += 1.5;
    if (seed.creatorId && seed.creatorId === item.creatorId) s += 1.0;
  }
  return s;
}

// Deterministic PRNG so shuffles are reproducible in tests.
function rng(seedNum) {
  let x = seedNum >>> 0 || 1;
  return () => {
    x ^= x << 13; x >>>= 0;
    x ^= x >>> 17;
    x ^= x << 5; x >>>= 0;
    return x / 4294967296;
  };
}

/**
 * Pure: AI shuffle. Taste-weighted random order that keeps the current
 * item first, avoids the same creator back to back where possible, and
 * mixes in recommendations (about one in every `mixEvery` items).
 */
function smartOrder(profile, type, items, { currentId, recommendations = [], mixEvery = 4, randomSeed = Date.now() } = {}) {
  const rand = rng(randomSeed);
  const pool = items.filter((i) => i.id !== currentId);
  // Weighted sampling without replacement (Efraimidis-Spirakis keys).
  const keyed = pool.map((i) => {
    const w = Math.exp(Math.max(-5, Math.min(5, score(profile, type, i) / 3)));
    return { i, k: Math.pow(rand(), 1 / w) };
  });
  keyed.sort((a, b) => b.k - a.k);
  const ordered = keyed.map((x) => x.i);
  // Spread creators: if the next item repeats the creator, swap in a later one.
  for (let n = 1; n < ordered.length; n++) {
    if (ordered[n].creatorId && ordered[n].creatorId === ordered[n - 1].creatorId) {
      const j = ordered.findIndex((x, idx) => idx > n && x.creatorId !== ordered[n - 1].creatorId);
      if (j > n) [ordered[n], ordered[j]] = [ordered[j], ordered[n]];
    }
  }
  const out = [];
  const current = items.find((i) => i.id === currentId);
  if (current) out.push({ ...current, origin: "queue" });
  const recs = recommendations.filter((r) => !items.some((i) => i.id === r.id));
  let r = 0;
  ordered.forEach((item, idx) => {
    out.push({ ...item, origin: "queue" });
    if (mixEvery > 0 && (idx + 1) % mixEvery === 0 && r < recs.length) out.push({ ...recs[r++], origin: "recommended" });
  });
  return out;
}

class MediaTaste {
  constructor({ store }) {
    this.store = store;
  }

  async _item(type, id) {
    const src = SOURCES[type];
    if (!src) fail("invalid-argument", "Unsupported media type.");
    if (typeof id !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(id)) fail("invalid-argument", "Invalid item.");
    const d = await this.store.get(`${src.collection}/${id}`);
    if (!d) return null;
    return this._shape(type, id, d);
  }

  _shape(type, id, d) {
    const src = SOURCES[type];
    return {
      id, type,
      title: d[src.title] || "",
      genre: d[src.genre] || null,
      creatorId: d[src.creator] || d.postCreator || null,
      creatorName: d[src.creatorName] || "",
      imageUrl: d[src.image] || null,
      plays: Number(d[src.plays] || 0) || 0,
    };
  }

  /** Records a play, completion, skip, like or save into the caller's taste. */
  async record(uid, { type, id, event, positionSec, durationSec } = {}) {
    if (!uid) fail("unauthenticated", "Sign in first.");
    const item = await this._item(type, id);
    if (!item) return { recorded: false };
    const path = `media_taste/${uid}`;
    return this.store.runTransaction(async (tx) => {
      const profile = await tx.get(path);
      const next = updateProfile(profile, { type, event, item, positionSec: Number(positionSec) || 0, durationSec: Number(durationSec) || 0 });
      tx.set(path, { ...next, updatedAt: Date.now() });
      return { recorded: true, events: next.events };
    });
  }

  async _candidates(type, { seed, limit = 60 }) {
    const src = SOURCES[type];
    const rows = [];
    const seen = new Set();
    const add = (list) => list.forEach((r) => { if (!seen.has(r.id)) { seen.add(r.id); rows.push(this._shape(type, r.id, r.data)); } });
    if (seed && seed.genre) add(await this.store.query({ collection: src.collection, where: [[src.genre, "==", seed.genre]], limit }));
    if (seed && seed.creatorId) add(await this.store.query({ collection: src.collection, where: [[src.creator, "==", seed.creatorId]], limit: 20 }));
    if (rows.length < limit) add(await this.store.query({ collection: src.collection, limit }));
    return rows;
  }

  /**
   * Recommends items of a type for the caller, optionally "more like" a
   * seed item, excluding ids already queued or seen.
   */
  async recommend(uid, { type, seedId, exclude = [], limit = 20 } = {}) {
    if (!SOURCES[type]) fail("invalid-argument", "Unsupported media type.");
    const n = Math.max(1, Math.min(50, Number(limit) || 20));
    const profile = uid ? await this.store.get(`media_taste/${uid}`) : null;
    const seed = seedId ? await this._item(type, seedId) : null;
    const skip = new Set([...(Array.isArray(exclude) ? exclude.slice(0, 500) : []), seedId].filter(Boolean));
    const candidates = (await this._candidates(type, { seed })).filter((c) => !skip.has(c.id));
    const ranked = candidates
      .map((c) => ({ c, s: score(profile, type, c, { seed }) }))
      .sort((a, b) => b.s - a.s)
      .map((x) => x.c);
    // Diversity: at most two in a row from the same creator.
    const out = [];
    for (const c of ranked) {
      const last2 = out.slice(-2);
      if (last2.length === 2 && last2.every((x) => x.creatorId && x.creatorId === c.creatorId)) continue;
      out.push(c);
      if (out.length >= n) break;
    }
    return { items: out, personalised: !!(profile && profile.events) };
  }

  /** AI shuffle for a queue of ids of one type; returns the new order. */
  async smartShuffle(uid, { type, ids = [], currentId, mixRecommendations = true } = {}) {
    if (!SOURCES[type]) fail("invalid-argument", "Unsupported media type.");
    const list = Array.isArray(ids) ? ids.slice(0, 300) : [];
    const items = (await Promise.all(list.map((id) => this._item(type, id)))).filter(Boolean);
    const profile = uid ? await this.store.get(`media_taste/${uid}`) : null;
    const recs = mixRecommendations ? (await this.recommend(uid, { type, seedId: currentId, exclude: list, limit: 10 })).items : [];
    return { items: smartOrder(profile, type, items, { currentId, recommendations: recs }) };
  }
}

module.exports = { MediaTaste, SOURCES, updateProfile, score, smartOrder, EVENTS };
