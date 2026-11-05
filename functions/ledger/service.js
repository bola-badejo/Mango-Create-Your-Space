"use strict";
// MangoChain ledger service. Every balance change happens here, on the
// server, inside a Firestore transaction. The app can only ask: open an
// account, check in, start or end a timed session, or transfer. Rewards are
// minted only by closing an epoch, from points earned by verified activity.
const C = require("./chain");
const P = require("./policy");
const { sha256Hex, inclusionProof } = require("./crypto");
const { toUnits } = require("./units");

const META = "ledger_meta/chain";
const TREASURY_UID = "@treasury";
const pad = (n, w = 12) => String(n).padStart(w, "0");
const paths = {
  account: (uid) => `ledger_accounts/${uid}`,
  address: (a) => `ledger_addresses/${a}`,
  tx: (id) => `ledger_tx/${id}`,
  block: (h) => `ledger_blocks/${pad(h)}`,
  key: (id) => `ledger_keys/${id}`,
  activity: (id) => `ledger_activity/${id}`,
  caps: (uid, day) => `ledger_caps/${uid}_${day}`,
  epoch: (e) => `ledger_epochs/${pad(e, 8)}`,
  points: (e, uid) => `ledger_epochs/${pad(e, 8)}/points/${uid}`,
  pointsCollection: (e) => `ledger_epochs/${pad(e, 8)}/points`,
  session: (uid) => `ledger_sessions/${uid}`,
  idem: (uid, key) => `ledger_idem/${sha256Hex(`${uid}:${key}`).slice(0, 40)}`,
};

class LedgerError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code; // maps to HTTPS callable error codes
  }
}

const utcDay = (ts) => new Date(ts).toISOString().slice(0, 10);

function newAccount(uid, now) {
  return { uid, address: C.addressFor(uid), balance: "0", createdAt: now };
}

class MangoLedger {
  /**
   * @param {object} deps
   * @param {object} deps.store       MemoryStore or FirestoreStore
   * @param {object} deps.signer      from crypto.loadSigner()
   * @param {(uid:string)=>Promise<boolean>} [deps.isEligible] anti-sybil gate
   * @param {(type:string,id:string)=>Promise<{creatorUid?:string,spaceOwnerUid?:string}|null>} [deps.resolveContent]
   */
  constructor({ store, signer, isEligible = async () => true, resolveContent = async () => null }) {
    this.store = store;
    this.signer = signer;
    this.isEligible = isEligible;
    this.resolveContent = resolveContent;
    this._genesisTime = null;
  }

  // ---------------------------------------------------------------- genesis
  async ensureGenesis(now) {
    return this.store.runTransaction(async (tx) => {
      const meta = await tx.get(META);
      if (meta) return { created: false, meta };
      const genesisTime = Math.floor(now / P.EPOCH_MS) * P.EPOCH_MS;
      const gtx = C.makeTx({ type: C.TX.GENESIS, seq: 1, ts: now, to: C.TREASURY, amount: P.GENESIS_TREASURY, memo: "MangoChain genesis" });
      const state = C.applyTx(C.emptyState(), gtx, 0);
      const block = C.buildBlock({ height: 0, prevHash: null, ts: now, txs: [gtx], state, signer: this.signer });
      const newMeta = {
        chainId: P.CHAIN_ID, height: 0, headHash: block.hash, sequence: 1, sealedSeq: 1,
        minted: state.minted.toString(), burned: "0", genesisTime, nextEpoch: 0, keyId: this.signer.keyId,
      };
      tx.set(paths.key(this.signer.keyId), { keyId: this.signer.keyId, publicKeyPem: this.signer.publicKeyPem, algorithm: "Ed25519", since: now });
      tx.set(paths.block(0), block);
      tx.set(paths.tx(gtx.id), { ...gtx, sealed: true, height: 0, index: 0 });
      tx.set(paths.account(TREASURY_UID), { uid: TREASURY_UID, address: C.TREASURY, balance: P.GENESIS_TREASURY.toString(), createdAt: now });
      tx.set(paths.address(C.TREASURY), { uid: TREASURY_UID });
      tx.set(META, newMeta);
      return { created: true, meta: newMeta };
    });
  }

  async genesisTime() {
    if (this._genesisTime === null) {
      const meta = await this.store.get(META);
      if (!meta) throw new LedgerError("failed-precondition", "ledger has no genesis block yet");
      this._genesisTime = meta.genesisTime;
    }
    return this._genesisTime;
  }

  async epochAt(ts) {
    return Math.floor((ts - (await this.genesisTime())) / P.EPOCH_MS);
  }

  // --------------------------------------------------------------- accounts
  async openAccount(uid, now) {
    if (!uid || uid.startsWith("@")) throw new LedgerError("invalid-argument", "invalid user id");
    return this.store.runTransaction(async (tx) => {
      const existing = await tx.get(paths.account(uid));
      if (existing) return existing;
      const acct = newAccount(uid, now);
      tx.set(paths.account(uid), acct);
      tx.set(paths.address(acct.address), { uid });
      return acct;
    });
  }

  async getAccount(uid) {
    return this.store.get(paths.account(uid));
  }

  // ------------------------------------------------------ activity mining
  /**
   * Plans how an activity's points are split, before any I/O inside the
   * transaction. Returns null with a reason when nothing should be credited.
   */
  _plan({ type, actorUid, creatorUid, spaceOwnerUid, durationSec, pointsOverride }) {
    const pol = P.ACTIVITIES[type];
    if (!pol) throw new LedgerError("invalid-argument", `unknown activity ${type}`);
    if (!actorUid) return { skip: "no_actor" };
    if (pol.minSeconds !== undefined && !(durationSec >= pol.minSeconds)) return { skip: "too_short" };
    // No rewards for engaging with your own content, profile or Space.
    if (creatorUid && creatorUid === actorUid) return { skip: "self_engagement" };
    if (type === "space_visit" && spaceOwnerUid === actorUid) return { skip: "self_engagement" };
    if (pol.shares.creator && !creatorUid) return { skip: "unknown_creator" };
    if (type === "space_visit" && !spaceOwnerUid) return { skip: "unknown_space_owner" };

    let points = pointsOverride ?? pol.points;
    if (pol.minSeconds !== undefined) {
      const secs = Math.min(durationSec, P.MAX_SESSION_SECONDS);
      points = Math.floor((points * P.durationMultiplier(secs)) / 1000);
    }
    const useSpace = spaceOwnerUid && pol.spaceShares && spaceOwnerUid !== actorUid;
    const shares = useSpace ? pol.spaceShares : pol.shares;
    const split = {};
    const add = (uid, pts) => { if (uid && pts > 0) split[uid] = (split[uid] || 0) + pts; };
    add(actorUid, Math.floor((points * (shares.actor || 0)) / 1000));
    add(creatorUid, Math.floor((points * (shares.creator || 0)) / 1000));
    add(useSpace || type === "space_visit" ? spaceOwnerUid : null, Math.floor((points * (shares.spaceOwner || 0)) / 1000));
    return { pol, split };
  }

  async _readCredit(tx, { eventId, actorUid, split, epoch, day }) {
    const event = await tx.get(paths.activity(eventId));
    const caps = (await tx.get(paths.caps(actorUid, day))) || { counts: {}, pairs: {} };
    const points = {};
    const accounts = {};
    for (const uid of Object.keys(split)) {
      points[uid] = (await tx.get(paths.points(epoch, uid))) || { points: 0 };
      accounts[uid] = await tx.get(paths.account(uid));
    }
    return { event, caps, points, accounts };
  }

  _writeCredit(tx, { eventId, type, actorUid, subjectId, split, epoch, day, ts, durationSec, pol }, reads, now) {
    if (reads.event) return { credited: false, reason: "duplicate", eventId };
    const count = reads.caps.counts[type] || 0;
    if (count >= pol.dailyCap) return { credited: false, reason: "daily_cap", eventId };

    const credited = {};
    for (const [uid, wanted] of Object.entries(split)) {
      let pts = wanted;
      if (uid !== actorUid) {
        // Points one account can direct to another per day.
        const used = reads.caps.pairs[uid] || 0;
        pts = Math.min(pts, Math.max(P.PAIR_DAILY_CAP - used, 0));
      }
      pts = Math.min(pts, Math.max(P.ACCOUNT_EPOCH_CAP - reads.points[uid].points, 0));
      if (pts > 0) credited[uid] = pts;
    }

    const caps = {
      counts: { ...reads.caps.counts, [type]: count + 1 },
      pairs: { ...reads.caps.pairs },
    };
    for (const [uid, pts] of Object.entries(credited)) {
      if (uid !== actorUid) caps.pairs[uid] = (caps.pairs[uid] || 0) + pts;
      tx.set(paths.points(epoch, uid), { points: reads.points[uid].points + pts, updatedAt: now });
      if (!reads.accounts[uid]) {
        const acct = newAccount(uid, now);
        tx.set(paths.account(uid), acct);
        tx.set(paths.address(acct.address), { uid });
      }
    }
    tx.set(paths.caps(actorUid, day), caps);
    tx.set(paths.activity(eventId), {
      type, actor: actorUid, subjectId: subjectId || null, epoch, day, ts,
      durationSec: durationSec ?? null, credited,
    });
    return { credited: Object.keys(credited).length > 0, reason: Object.keys(credited).length ? null : "capped", eventId, epoch, points: credited };
  }

  /**
   * Credits a verified activity. Callers are server code only (Firestore
   * triggers using the writer's real identity, or the session endpoints).
   */
  async recordActivity({ type, actorUid, subjectId, creatorUid, spaceOwnerUid, durationSec, eventId, ts }) {
    const plan = this._plan({ type, actorUid, creatorUid, spaceOwnerUid, durationSec });
    if (plan.skip) return { credited: false, reason: plan.skip };
    if (!(await this.isEligible(actorUid))) return { credited: false, reason: "not_eligible" };
    const epoch = await this.epochAt(ts);
    const day = utcDay(ts);
    const id = eventId || sha256Hex(`${type}|${actorUid}|${subjectId}`);
    const ctx = { eventId: id, type, actorUid, subjectId, split: plan.split, epoch, day, ts, durationSec, pol: plan.pol };
    return this.store.runTransaction(async (tx) => {
      const reads = await this._readCredit(tx, ctx);
      return this._writeCredit(tx, ctx, reads, ts);
    });
  }

  /** Daily check-in with a streak bonus. Idempotent per UTC day. */
  async checkIn(uid, now) {
    if (!(await this.isEligible(uid))) return { credited: false, reason: "not_eligible" };
    const epoch = await this.epochAt(now);
    const day = utcDay(now);
    const yesterday = utcDay(now - 24 * 60 * 60 * 1000);
    return this.store.runTransaction(async (tx) => {
      const acct = (await tx.get(paths.account(uid))) || newAccount(uid, now);
      const streak = acct.lastCheckInDay === day ? acct.streak || 1
        : acct.lastCheckInDay === yesterday ? (acct.streak || 0) + 1 : 1;
      const plan = this._plan({ type: "daily_check_in", actorUid: uid, pointsOverride: P.checkInPoints(streak) });
      const ctx = { eventId: `checkin_${uid}_${day}`, type: "daily_check_in", actorUid: uid, subjectId: day, split: plan.split, epoch, day, ts: now, pol: plan.pol };
      const reads = await this._readCredit(tx, ctx);
      const result = this._writeCredit(tx, ctx, { ...reads, accounts: { [uid]: acct } }, now);
      if (result.credited) {
        tx.set(paths.account(uid), { ...acct, lastCheckInDay: day, streak });
        if (!reads.accounts[uid]) tx.set(paths.address(acct.address), { uid });
      }
      return { ...result, streak };
    });
  }

  // --------------------------------------------------- timed consumption
  /**
   * Starts a server-timed session (listening, watching, visiting a Space).
   * Any open session is ended and credited first. The duration credited is
   * measured on the server's clock, so it cannot be inflated by the app.
   */
  async startSession(uid, { contentType, contentId, spaceId }, now) {
    if (!P.CONSUMPTION_TYPES[contentType]) throw new LedgerError("invalid-argument", `unsupported content type ${contentType}`);
    if (typeof contentId !== "string" || !contentId || contentId.length > 200) throw new LedgerError("invalid-argument", "invalid content id");
    const ended = await this.endSession(uid, now);
    const session = { id: sha256Hex(`${uid}|${now}|${contentType}|${contentId}`).slice(0, 32), contentType, contentId, spaceId: spaceId || null, startedAt: now, endedAt: null };
    await this.store.set(paths.session(uid), session);
    return { sessionId: session.id, ended };
  }

  async endSession(uid, now) {
    const s = await this.store.get(paths.session(uid));
    if (!s || s.endedAt) return null;
    const durationSec = Math.min(Math.floor((now - s.startedAt) / 1000), P.MAX_SESSION_SECONDS);
    const type = P.CONSUMPTION_TYPES[s.contentType];
    let creatorUid = null;
    let spaceOwnerUid = null;
    if (s.contentType === "space") {
      spaceOwnerUid = (await this.resolveContent("space", s.contentId))?.spaceOwnerUid || null;
    } else {
      creatorUid = (await this.resolveContent(s.contentType, s.contentId))?.creatorUid || null;
      if (s.spaceId) spaceOwnerUid = (await this.resolveContent("space", s.spaceId))?.spaceOwnerUid || null;
    }
    const plan = this._plan({ type, actorUid: uid, creatorUid, spaceOwnerUid, durationSec });
    const eligible = plan.skip ? false : await this.isEligible(uid);
    const epoch = await this.epochAt(now);
    const day = utcDay(now);
    return this.store.runTransaction(async (tx) => {
      const current = await tx.get(paths.session(uid));
      if (!current || current.id !== s.id || current.endedAt) return null; // ended elsewhere
      let result;
      if (plan.skip || !eligible) {
        result = { credited: false, reason: plan.skip || "not_eligible" };
      } else {
        const ctx = { eventId: `session_${s.id}`, type, actorUid: uid, subjectId: s.contentId, split: plan.split, epoch, day, ts: now, durationSec, pol: plan.pol };
        const reads = await this._readCredit(tx, ctx);
        result = this._writeCredit(tx, ctx, reads, now);
      }
      tx.set(paths.session(uid), { ...current, endedAt: now, durationSec });
      return { ...result, durationSec };
    });
  }

  // -------------------------------------------------------------- transfers
  /**
   * @param {object} [hooks] For purchases that must commit atomically with
   *   the payment: `read(tx)` runs after the ledger's reads and may throw to
   *   refuse; `write(tx, ctx, result)` adds writes to the same transaction.
   */
  async transfer(fromUid, { to, amount, memo, idempotencyKey }, now, hooks = {}) {
    let units;
    try {
      units = toUnits(amount);
    } catch (e) {
      throw new LedgerError("invalid-argument", e.message);
    }
    if (memo !== undefined && memo !== null && (typeof memo !== "string" || memo.length > P.MAX_MEMO_LENGTH)) {
      throw new LedgerError("invalid-argument", `memo must be at most ${P.MAX_MEMO_LENGTH} characters`);
    }
    if (typeof to !== "string" || !to) throw new LedgerError("invalid-argument", "recipient is required");
    if (idempotencyKey !== undefined && (typeof idempotencyKey !== "string" || idempotencyKey.length > 100)) {
      throw new LedgerError("invalid-argument", "invalid idempotency key");
    }

    // Resolve the recipient (an mng1 address, or a user id as the old app used).
    let toUid = to;
    if (C.isAddress(to)) {
      const idx = await this.store.get(paths.address(to));
      if (!idx) throw new LedgerError("not-found", "no account has that address");
      toUid = idx.uid;
    }
    if (toUid === fromUid) throw new LedgerError("invalid-argument", "cannot transfer to yourself");

    return this.store.runTransaction(async (tx) => {
      const meta = await tx.get(META);
      if (!meta) throw new LedgerError("failed-precondition", "ledger has no genesis block yet");
      const idem = idempotencyKey ? await tx.get(paths.idem(fromUid, idempotencyKey)) : null;
      const sender = await tx.get(paths.account(fromUid));
      const receiver = await tx.get(paths.account(toUid));
      if (idem) return { ...idem.result, duplicate: true };
      const hookCtx = hooks.read ? await hooks.read(tx) : undefined;
      if (!sender) throw new LedgerError("failed-precondition", "you do not have a wallet yet");
      if (!receiver) throw new LedgerError("not-found", "recipient has no wallet");

      const seq = meta.sequence + 1;
      const t = C.makeTx({ type: C.TX.TRANSFER, seq, ts: now, from: sender.address, to: receiver.address, amount: units, fee: P.TRANSFER_FEE, memo: memo || undefined });
      // Validate with exactly the rules the verifier will replay.
      const state = C.emptyState();
      state.lastSeq = seq - 1;
      state.balances.set(sender.address, toUnits(sender.balance));
      try {
        C.applyTx(state, t, null);
      } catch (e) {
        const msg = /insufficient/.test(e.message)
          ? "insufficient balance (amount plus the 0.001 MNG fee)"
          : /minimum/.test(e.message) ? "amount is below the minimum transfer" : e.message;
        throw new LedgerError("failed-precondition", msg);
      }
      const senderBalance = state.balances.get(sender.address);
      const receiverBalance = toUnits(receiver.balance) + units;
      const result = { txId: t.id, seq, amount: units.toString(), fee: P.TRANSFER_FEE.toString(), balance: senderBalance.toString() };

      tx.set(paths.account(fromUid), { ...sender, balance: senderBalance.toString(), updatedAt: now });
      tx.set(paths.account(toUid), { ...receiver, balance: receiverBalance.toString(), updatedAt: now });
      tx.set(paths.tx(t.id), { ...t, sealed: false, height: null, index: null });
      tx.set(META, { ...meta, sequence: seq });
      if (idempotencyKey) tx.set(paths.idem(fromUid, idempotencyKey), { result, ts: now });
      if (hooks.write) hooks.write(tx, hookCtx, result);
      return result;
    });
  }

  // ------------------------------------------------------- block production
  /** Produces at most one block: seals pending transfers, else mints one chunk of epoch rewards. */
  async produceBlock(now) {
    const sealed = await this._sealPending(now);
    if (sealed) return sealed;
    return this._closeEpochStep(now);
  }

  /** Runs produceBlock until there is nothing left to do (bounded). */
  async produceAll(now, maxSteps = 200) {
    const results = [];
    for (let i = 0; i < maxSteps; i++) {
      const r = await this.produceBlock(now);
      if (!r) break;
      results.push(r);
    }
    return results;
  }

  _writeBlock(tx, meta, txs, state, now) {
    const height = meta.height + 1;
    const block = C.buildBlock({ height, prevHash: meta.headHash, ts: now, txs, state, signer: this.signer });
    tx.set(paths.block(height), block);
    if (meta.keyId !== this.signer.keyId) {
      tx.set(paths.key(this.signer.keyId), { keyId: this.signer.keyId, publicKeyPem: this.signer.publicKeyPem, algorithm: "Ed25519", since: now });
    }
    return { block, height };
  }

  async _sealPending(now) {
    return this.store.runTransaction(async (tx) => {
      const meta = await tx.get(META);
      if (!meta || meta.sealedSeq === meta.sequence) return null;
      const pending = await tx.query({ collection: "ledger_tx", where: [["sealed", "==", false]], orderBy: "seq", limit: P.MAX_TX_PER_BLOCK });
      const txs = pending.map((r) => r.data);
      txs.forEach((t, i) => {
        if (t.seq !== meta.sealedSeq + 1 + i) {
          throw new LedgerError("aborted", `pending sequence gap at ${meta.sealedSeq + 1 + i}`);
        }
      });
      if (!txs.length) return null;
      const state = { minted: toUnits(meta.minted), burned: toUnits(meta.burned) };
      for (const t of txs) state.burned += toUnits(t.fee);
      const clean = txs.map((t) => C.txBody(t)).map((b) => ({ ...b, id: C.txId(b) }));
      const { block, height } = this._writeBlock(tx, meta, clean, state, now);
      clean.forEach((t, index) => tx.set(paths.tx(t.id), { sealed: true, height, index }, { merge: true }));
      tx.set(META, { ...meta, height, headHash: block.hash, sealedSeq: clean[clean.length - 1].seq, burned: state.burned.toString(), keyId: this.signer.keyId });
      return { kind: "seal", height, txCount: clean.length, hash: block.hash };
    });
  }

  async _closeEpochStep(now) {
    const meta = await this.store.get(META);
    if (!meta) return null;
    const E = meta.nextEpoch;
    const epochEnd = meta.genesisTime + (E + 1) * P.EPOCH_MS;
    if (now < epochEnd + P.EPOCH_GRACE_MS) return null;

    // Total points for the epoch, scanned once after it closes to writes.
    let ep = await this.store.get(paths.epoch(E));
    if (!ep || ep.totalPoints === undefined) {
      let total = 0;
      let cursor = null;
      for (;;) {
        const rows = await this.store.query({ collection: paths.pointsCollection(E), orderBy: "__id__", startAfter: cursor, limit: 500 });
        if (!rows.length) break;
        for (const r of rows) total += r.data.points || 0;
        cursor = rows[rows.length - 1].id;
      }
      ep = { epoch: E, totalPoints: total, emission: P.emissionForEpoch(E).toString(), cursor: null, minted: "0", closed: false };
      await this.store.set(paths.epoch(E), ep, { merge: true });
    }

    return this.store.runTransaction(async (tx) => {
      const m = await tx.get(META);
      if (!m || m.nextEpoch !== E) return null;
      if (m.sealedSeq !== m.sequence) return null; // seal pending transfers first to keep order
      const e = await tx.get(paths.epoch(E));
      const rows = await tx.query({ collection: paths.pointsCollection(E), orderBy: "__id__", startAfter: e.cursor, limit: P.MAX_TX_PER_BLOCK });
      if (!rows.length) {
        tx.set(paths.epoch(E), { ...e, closed: true, closedAt: now });
        tx.set(META, { ...m, nextEpoch: E + 1 });
        return { kind: "epoch_closed", epoch: E, minted: e.minted, emission: e.emission };
      }
      const accounts = [];
      for (const r of rows) accounts.push(await tx.get(paths.account(r.id)));

      const emission = toUnits(e.emission);
      const total = BigInt(e.totalPoints);
      const state = { minted: toUnits(m.minted), burned: toUnits(m.burned) };
      let epochMinted = toUnits(e.minted);
      let seq = m.sequence;
      const txs = [];
      const credits = [];
      rows.forEach((r, i) => {
        const pts = BigInt(r.data.points || 0);
        if (pts === 0n || total === 0n) return;
        const proRata = (emission * pts) / total;
        const ceiling = pts * P.MAX_UNITS_PER_MILLIPOINT;
        let reward = proRata < ceiling ? proRata : ceiling;
        if (epochMinted + reward > emission) reward = emission - epochMinted;
        if (state.minted + reward > P.MAX_SUPPLY) reward = P.MAX_SUPPLY - state.minted;
        if (reward <= 0n) return;
        const acct = accounts[i] || newAccount(r.id, now);
        seq += 1;
        const t = C.makeTx({ type: C.TX.REWARD, seq, ts: now, to: acct.address, amount: reward, epoch: E, ref: `points:${r.data.points}` });
        txs.push(t);
        credits.push({ uid: r.id, acct, reward, isNew: !accounts[i] });
        epochMinted += reward;
        state.minted += reward;
      });

      const cursor = rows[rows.length - 1].id;
      if (!txs.length) {
        tx.set(paths.epoch(E), { ...e, cursor });
        return { kind: "epoch_progress", epoch: E, cursor };
      }
      const { block, height } = this._writeBlock(tx, m, txs, state, now);
      txs.forEach((t, index) => tx.set(paths.tx(t.id), { ...t, sealed: true, height, index }));
      for (const c of credits) {
        tx.set(paths.account(c.uid), { ...c.acct, balance: (toUnits(c.acct.balance) + c.reward).toString(), updatedAt: now });
        if (c.isNew) tx.set(paths.address(c.acct.address), { uid: c.uid });
      }
      tx.set(paths.epoch(E), { ...e, cursor, minted: epochMinted.toString() });
      tx.set(META, { ...m, height, headHash: block.hash, sequence: seq, sealedSeq: seq, minted: state.minted.toString(), keyId: this.signer.keyId });
      return { kind: "rewards", epoch: E, height, txCount: txs.length, hash: block.hash };
    });
  }

  // ------------------------------------------------------ proofs and audit
  /** Merkle inclusion proof that a transaction is in a signed block. */
  async proofFor(txId) {
    const t = await this.store.get(paths.tx(txId));
    if (!t) throw new LedgerError("not-found", "unknown transaction");
    if (!t.sealed) return { tx: C.txBody(t), id: txId, sealed: false };
    const block = await this.store.get(paths.block(t.height));
    return {
      id: txId, tx: C.txBody(t), sealed: true, height: t.height, index: t.index,
      header: block.header, blockHash: block.hash, signature: block.signature,
      proof: inclusionProof(block.txIds, t.index),
    };
  }

  /** Loads the whole chain (blocks, transactions, keys) for verification. */
  async exportChain() {
    const blocks = [];
    let cursor = null;
    for (;;) {
      const rows = await this.store.query({ collection: "ledger_blocks", orderBy: "__id__", startAfter: cursor, limit: 500 });
      if (!rows.length) break;
      blocks.push(...rows.map((r) => r.data));
      cursor = rows[rows.length - 1].id;
    }
    const txsById = new Map();
    cursor = null;
    for (;;) {
      const rows = await this.store.query({ collection: "ledger_tx", orderBy: "__id__", startAfter: cursor, limit: 500 });
      if (!rows.length) break;
      for (const r of rows) txsById.set(r.id, r.data);
      cursor = rows[rows.length - 1].id;
    }
    const keys = {};
    for (const r of await this.store.query({ collection: "ledger_keys" })) keys[r.id] = r.data.publicKeyPem;
    return { blocks, txsById, keys };
  }

  /**
   * Full audit: verifies every block from genesis, applies not-yet-sealed
   * transfers in order, and checks every stored balance equals the replay.
   */
  async audit() {
    const { blocks, txsById, keys } = await this.exportChain();
    const result = C.verifyChain(blocks, new Map([...txsById].map(([k, v]) => [k, C.txBody(v) && { ...C.txBody(v), id: k }])), keys);
    const report = { ok: result.ok, errors: [...result.errors], height: result.height, minted: result.state.minted.toString(), burned: result.state.burned.toString() };
    if (!result.ok) return report;
    const pending = [...txsById.values()].filter((t) => !t.sealed).sort((a, b) => a.seq - b.seq);
    try {
      for (const t of pending) C.applyTx(result.state, { ...C.txBody(t), id: t.id }, null);
    } catch (e) {
      report.ok = false;
      report.errors.push(`pending: ${e.message}`);
      return report;
    }
    let cursor = null;
    let checked = 0;
    for (;;) {
      const rows = await this.store.query({ collection: "ledger_accounts", orderBy: "__id__", startAfter: cursor, limit: 500 });
      if (!rows.length) break;
      for (const r of rows) {
        const expected = result.state.balances.get(r.data.address) || 0n;
        if (expected.toString() !== r.data.balance) {
          report.ok = false;
          report.errors.push(`balance mismatch for ${r.data.address}: stored ${r.data.balance}, replay ${expected}`);
        }
        checked += 1;
      }
      cursor = rows[rows.length - 1].id;
    }
    const meta = await this.store.get(META);
    report.accountsChecked = checked;
    report.pendingTransfers = pending.length;
    report.headHash = meta && meta.headHash;
    return report;
  }
}

module.exports = { MangoLedger, LedgerError, paths, META, TREASURY_UID, utcDay };
