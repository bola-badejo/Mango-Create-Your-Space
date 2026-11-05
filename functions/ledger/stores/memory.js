"use strict";
// In-memory store with Firestore's transaction rules enforced: all reads
// before any write, at most 500 writes, snapshot isolation. Used by the
// tests and by the offline verifier for JSON exports.
const MAX_WRITES = 500;

const clone = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));

function matches(doc, where = []) {
  return where.every(([field, op, value]) => {
    const v = doc[field];
    switch (op) {
      case "==": return v === value;
      case ">": return v > value;
      case ">=": return v >= value;
      case "<": return v < value;
      case "<=": return v <= value;
      default: throw new Error(`unsupported operator ${op}`);
    }
  });
}

class MemoryStore {
  constructor() {
    this.docs = new Map(); // path -> data
    this.transactions = 0;
    this.maxWritesSeen = 0;
  }

  _query(spec) {
    const { collection, where = [], orderBy = "__id__", startAfter, limit } = spec;
    const prefix = `${collection}/`;
    let rows = [];
    for (const [path, data] of this.docs) {
      if (!path.startsWith(prefix)) continue;
      const id = path.slice(prefix.length);
      if (id.includes("/")) continue; // only direct children
      if (matches(data, where)) rows.push({ id, data: clone(data) });
    }
    const key = (r) => (orderBy === "__id__" ? r.id : r.data[orderBy]);
    rows.sort((a, b) => (key(a) < key(b) ? -1 : key(a) > key(b) ? 1 : 0));
    if (startAfter !== undefined && startAfter !== null) rows = rows.filter((r) => key(r) > startAfter);
    if (limit) rows = rows.slice(0, limit);
    return rows;
  }

  async get(path) {
    return clone(this.docs.get(path)) ?? null;
  }

  async query(spec) {
    return this._query(spec);
  }

  async set(path, data, { merge = false } = {}) {
    this.docs.set(path, merge ? { ...(this.docs.get(path) || {}), ...clone(data) } : clone(data));
  }

  async delete(path) {
    this.docs.delete(path);
  }

  async runTransaction(fn) {
    const writes = [];
    let wrote = false;
    const guardRead = () => {
      if (wrote) throw new Error("Firestore rule: all transaction reads must happen before writes");
    };
    const tx = {
      get: async (path) => { guardRead(); return clone(this.docs.get(path)) ?? null; },
      query: async (spec) => { guardRead(); return this._query(spec); },
      set: (path, data, opts = {}) => { wrote = true; writes.push({ path, data: clone(data), merge: !!opts.merge }); },
      delete: (path) => { wrote = true; writes.push({ path, del: true }); },
      create: (path, data) => {
        wrote = true;
        if (this.docs.has(path)) throw new Error(`document already exists: ${path}`);
        writes.push({ path, data: clone(data), merge: false });
      },
    };
    const result = await fn(tx);
    if (writes.length > MAX_WRITES) throw new Error(`Firestore rule: ${writes.length} writes exceeds ${MAX_WRITES}`);
    for (const w of writes) {
      if (w.del) this.docs.delete(w.path);
      else this.docs.set(w.path, w.merge ? { ...(this.docs.get(w.path) || {}), ...w.data } : w.data);
    }
    this.transactions += 1;
    this.maxWritesSeen = Math.max(this.maxWritesSeen, writes.length);
    return result;
  }
}

module.exports = { MemoryStore, MAX_WRITES };
