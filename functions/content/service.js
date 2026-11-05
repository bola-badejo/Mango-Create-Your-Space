"use strict";
// Creator content: contributor registration and clean deletion.
const crypto = require("crypto");
const { LedgerError } = require("../ledger/service");

const fail = (code, message) => { throw new LedgerError(code, message); };

// Owner field per content collection (the app's existing data model).
const OWNER_FIELDS = {
  music: ["ownerId", "artistId"],
  podcasts: ["ownerId", "userId"],
  movies: ["ownerId", "userId"],
  books: ["ownerId", "uploaderId", "contributorId", "userId", "creatorId"],
  products: ["ownerId", "userId"],
  posts: ["ownerId", "postCreator"],
  vines: ["ownerId", "postCreator"],
};

function ownerOf(collection, doc) {
  for (const f of OWNER_FIELDS[collection] || ["ownerId"]) {
    if (doc && typeof doc[f] === "string" && doc[f]) return doc[f];
  }
  return null;
}

/** Storage path from a Firebase Storage download URL, gs:// URL or path. */
function pathFromUrl(url) {
  if (typeof url !== "string" || !url) return null;
  let m = /^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?#]+)/.exec(url);
  if (m) return decodeURIComponent(m[1]);
  m = /^gs:\/\/[^/]+\/(.+)$/.exec(url);
  if (m) return m[1];
  m = /^https:\/\/storage\.googleapis\.com\/[^/]+\/(.+?)(\?|$)/.exec(url);
  if (m) return decodeURIComponent(m[1]);
  return null;
}

/**
 * Files to remove when a content document is deleted: its recorded
 * storagePaths plus any Storage URLs in its fields, never files that sit in
 * another user's folder.
 */
function filesToDelete(collection, doc) {
  const owner = ownerOf(collection, doc);
  const paths = new Set(Array.isArray(doc.storagePaths) ? doc.storagePaths.filter((p) => typeof p === "string") : []);
  const walk = (v, depth = 0) => {
    if (depth > 3 || v == null) return;
    if (typeof v === "string") { const p = pathFromUrl(v); if (p) paths.add(p); return; }
    if (Array.isArray(v)) return v.forEach((x) => walk(x, depth + 1));
    if (typeof v === "object") return Object.values(v).forEach((x) => walk(x, depth + 1));
  };
  walk(doc);
  return [...paths].filter((p) => {
    const m = /^(users|content)\/([^/]+)\//.exec(p);
    if (m) return m[2] === owner; // someone else's folder: never
    return !!owner && !p.includes("..");
  });
}

const ROLES = { creator: "Creator", distributor: "Distributor", vendor: "Vendor" };
const USER_FIELDS = { creator: ["isCreator", "creatorID"], distributor: ["isDistributor", "distributorID"], vendor: ["isVendor", "vendorID"] };

function clean(v, max, field, min = 0) {
  const s = typeof v === "string" ? v.trim().replace(/\s+/g, " ") : "";
  if (s.length < min) fail("invalid-argument", `${field} needs at least ${min} characters.`);
  if (s.length > max) fail("invalid-argument", `${field} can be at most ${max} characters.`);
  return s;
}

class ContentService {
  constructor({ store }) {
    this.store = store;
  }

  /** Creates a contributor profile (Creator, Distributor or Vendor) for the caller. */
  async registerContributor(uid, input = {}, now, { email = "", displayName = "" } = {}) {
    if (!uid) fail("unauthenticated", "Sign in first.");
    const role = String(input.role || "").toLowerCase();
    if (!ROLES[role]) fail("invalid-argument", "Choose Creator, Distributor or Vendor.");
    const name = clean(input.name || displayName, 60, "Name", 2);
    const bio = clean(input.bio || "", 500, "Bio");
    const categories = Array.isArray(input.categories) ? input.categories.filter((c) => typeof c === "string").map((c) => c.trim()).filter(Boolean).slice(0, 10) : [];
    const image = (k) => (typeof input[k] === "string" && /^https:\/\//.test(input[k]) && input[k].length <= 1000 ? input[k] : null);
    const [flag, idField] = USER_FIELDS[role];
    return this.store.runTransaction(async (tx) => {
      const user = (await tx.get(`users/${uid}`)) || {};
      if (user[flag] && user[idField]) return { contributorId: user[idField], created: false };
      const contributorId = `c${crypto.randomBytes(10).toString("hex")}`;
      tx.set(`contributors/${contributorId}`, {
        contributorId, userId: uid, ownerId: uid, type: ROLES[role],
        fullName: name, email, phone: "", address: "", skill: categories[0] || "", tags: categories,
        portfolio: "", bio, socialMedia: "", isActive: true, isVerified: false, isPremium: false,
        profileImageUrl: image("profileImageUrl"), bannerImageUrl: image("bannerImageUrl"), logoImageUrl: image("logoImageUrl"),
        categories, subCategories: [],
        stageName: role === "creator" ? name : null,
        distributorLabel: role === "distributor" ? name : null,
        storeName: role === "vendor" ? name : null,
        followers: 0, rating: 0, reviews: 0, createdAt: now, updatedAt: now,
      });
      tx.set(`users/${uid}`, { [flag]: true, [idField]: contributorId }, { merge: true });
      return { contributorId, created: true };
    });
  }
}

module.exports = { ContentService, OWNER_FIELDS, ownerOf, pathFromUrl, filesToDelete, ROLES };
