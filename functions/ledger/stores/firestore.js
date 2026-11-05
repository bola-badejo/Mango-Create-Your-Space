"use strict";
// Firestore adapter for the ledger (Admin SDK; bypasses security rules).
// Same interface as MemoryStore: paths are "collection/doc[/collection/doc]".
const { FieldPath } = require("firebase-admin/firestore");

class FirestoreStore {
  constructor(db) {
    this.db = db;
  }

  _query(spec, from = this.db) {
    const { collection, where = [], orderBy = "__id__", startAfter, limit } = spec;
    let q = from.collection ? from.collection(collection) : this.db.collection(collection);
    for (const [field, op, value] of where) q = q.where(field, op, value);
    q = q.orderBy(orderBy === "__id__" ? FieldPath.documentId() : orderBy);
    if (startAfter !== undefined && startAfter !== null) q = q.startAfter(startAfter);
    if (limit) q = q.limit(limit);
    return q;
  }

  async get(path) {
    const snap = await this.db.doc(path).get();
    return snap.exists ? snap.data() : null;
  }

  async query(spec) {
    const snap = await this._query(spec).get();
    return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  }

  async set(path, data, { merge = false } = {}) {
    await this.db.doc(path).set(data, { merge });
  }

  async delete(path) {
    await this.db.doc(path).delete();
  }

  async runTransaction(fn) {
    return this.db.runTransaction(async (t) => {
      const tx = {
        get: async (path) => {
          const snap = await t.get(this.db.doc(path));
          return snap.exists ? snap.data() : null;
        },
        query: async (spec) => {
          const snap = await t.get(this._query(spec));
          return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
        },
        set: (path, data, opts = {}) => t.set(this.db.doc(path), data, { merge: !!opts.merge }),
        create: (path, data) => t.create(this.db.doc(path), data),
        delete: (path) => t.delete(this.db.doc(path)),
      };
      return fn(tx);
    });
  }
}

module.exports = { FirestoreStore };
