"use strict";
// Pure chain rules: transaction and block construction, validation and
// full replay. No I/O, so the same code runs in Cloud Functions, in tests
// and in the public verifier.
const { canonicalize, sha256Hex, merkleRoot, verifySignature } = require("./crypto");
const { toUnits } = require("./units");
const P = require("./policy");

const TX = Object.freeze({ GENESIS: "genesis", REWARD: "reward", TRANSFER: "transfer" });
const TREASURY = addressFor("@treasury");

/** Pseudonymous account address derived from a user id. */
function addressFor(uid) {
  return `mng1${sha256Hex(`mango-address:${uid}`).slice(0, 38)}`;
}

function isAddress(a) {
  return typeof a === "string" && /^mng1[0-9a-f]{38}$/.test(a);
}

/** Builds a transaction body and its id (sha256 of the canonical body). */
function makeTx({ type, seq, ts, from = null, to = null, amount, fee = 0n, memo, epoch, ref, chainId = P.CHAIN_ID }) {
  const body = {
    v: 1,
    chainId,
    type,
    seq,
    ts,
    from,
    to,
    amount: toUnits(amount).toString(),
    fee: toUnits(fee).toString(),
  };
  if (memo !== undefined && memo !== null && memo !== "") body.memo = memo;
  if (epoch !== undefined && epoch !== null) body.epoch = epoch;
  if (ref !== undefined && ref !== null) body.ref = ref;
  return { ...body, id: txId(body) };
}

function txBody(tx) {
  const { id, sealed, height, index, ...body } = tx; // eslint-disable-line no-unused-vars
  return body;
}

function txId(body) {
  return sha256Hex(canonicalize(body));
}

function blockHash(header) {
  return sha256Hex(canonicalize(header));
}

/** Empty chain state for replay. */
function emptyState() {
  return { balances: new Map(), minted: 0n, burned: 0n, epochMinted: new Map(), lastSeq: 0 };
}

const bal = (s, a) => s.balances.get(a) || 0n;

/**
 * Applies one transaction to a state, enforcing every rule. Throws an Error
 * with a reason if the transaction is invalid. `height` is the block height.
 */
function applyTx(state, tx, height) {
  if (tx.v !== 1) throw new Error(`tx ${tx.id}: unsupported version`);
  if (tx.chainId !== P.CHAIN_ID) throw new Error(`tx ${tx.id}: wrong chain id`);
  if (txId(txBody(tx)) !== tx.id) throw new Error(`tx ${tx.id}: id does not match contents`);
  if (!Number.isSafeInteger(tx.seq) || tx.seq !== state.lastSeq + 1) {
    throw new Error(`tx ${tx.id}: sequence ${tx.seq} out of order (expected ${state.lastSeq + 1})`);
  }
  const amount = toUnits(tx.amount);
  const fee = toUnits(tx.fee);

  switch (tx.type) {
    case TX.GENESIS:
      if (height !== 0 || tx.seq !== 1) throw new Error("genesis allocation must be the first transaction");
      if (tx.from !== null || tx.to !== TREASURY) throw new Error("genesis must mint to the treasury");
      if (amount !== P.GENESIS_TREASURY || fee !== 0n) throw new Error("genesis amount is fixed by policy");
      state.balances.set(TREASURY, bal(state, TREASURY) + amount);
      state.minted += amount;
      break;

    case TX.REWARD: {
      if (tx.from !== null || !isAddress(tx.to) || fee !== 0n) throw new Error(`tx ${tx.id}: malformed reward`);
      if (!Number.isSafeInteger(tx.epoch) || tx.epoch < 0) throw new Error(`tx ${tx.id}: reward without epoch`);
      if (amount === 0n) throw new Error(`tx ${tx.id}: zero reward`);
      const epochTotal = (state.epochMinted.get(tx.epoch) || 0n) + amount;
      if (epochTotal > P.emissionForEpoch(tx.epoch)) {
        throw new Error(`tx ${tx.id}: rewards for epoch ${tx.epoch} exceed its emission`);
      }
      if (state.minted + amount > P.MAX_SUPPLY) throw new Error(`tx ${tx.id}: exceeds max supply`);
      state.epochMinted.set(tx.epoch, epochTotal);
      state.balances.set(tx.to, bal(state, tx.to) + amount);
      state.minted += amount;
      break;
    }

    case TX.TRANSFER: {
      if (!isAddress(tx.from) || !isAddress(tx.to) || tx.from === tx.to) {
        throw new Error(`tx ${tx.id}: malformed transfer`);
      }
      if (amount < P.MIN_TRANSFER) throw new Error(`tx ${tx.id}: below minimum transfer`);
      if (fee !== P.TRANSFER_FEE) throw new Error(`tx ${tx.id}: wrong fee`);
      if (tx.memo !== undefined && (typeof tx.memo !== "string" || tx.memo.length > P.MAX_MEMO_LENGTH)) {
        throw new Error(`tx ${tx.id}: invalid memo`);
      }
      const need = amount + fee;
      if (bal(state, tx.from) < need) throw new Error(`tx ${tx.id}: insufficient balance`);
      state.balances.set(tx.from, bal(state, tx.from) - need);
      state.balances.set(tx.to, bal(state, tx.to) + amount);
      state.burned += fee;
      break;
    }

    default:
      throw new Error(`tx ${tx.id}: unknown type ${tx.type}`);
  }
  state.lastSeq = tx.seq;
  return state;
}

/** Builds and signs a block over already-validated transactions. */
function buildBlock({ height, prevHash, ts, txs, state, signer, chainId = P.CHAIN_ID }) {
  const ids = txs.map((t) => t.id);
  const header = {
    v: 1,
    chainId,
    height,
    prevHash,
    ts,
    txRoot: merkleRoot(ids),
    txCount: ids.length,
    firstSeq: txs.length ? txs[0].seq : null,
    lastSeq: txs.length ? txs[txs.length - 1].seq : null,
    minted: state.minted.toString(),
    burned: state.burned.toString(),
    keyId: signer.keyId,
  };
  const hash = blockHash(header);
  return { header, hash, signature: signer.sign(hash), txIds: ids };
}

/**
 * Verifies a whole chain from genesis: hash links, signatures, Merkle roots,
 * sequence order, every transaction rule, emission per epoch and the supply
 * cap. Returns { ok, errors, state, height }.
 */
function verifyChain(blocks, txsById, publicKeys) {
  const errors = [];
  const state = emptyState();
  let prevHash = null;
  for (const [i, block] of blocks.entries()) {
    const h = block.header;
    const where = `block ${h && h.height}`;
    try {
      if (!h || h.height !== i) throw new Error(`${where}: height out of order`);
      if (h.chainId !== P.CHAIN_ID) throw new Error(`${where}: wrong chain id`);
      if (h.prevHash !== prevHash) throw new Error(`${where}: does not link to the previous block`);
      if (blockHash(h) !== block.hash) throw new Error(`${where}: header hash mismatch`);
      const key = publicKeys[h.keyId];
      if (!key) throw new Error(`${where}: unknown signing key ${h.keyId}`);
      if (!verifySignature(block.hash, block.signature, key)) throw new Error(`${where}: bad signature`);
      if (merkleRoot(block.txIds) !== h.txRoot || block.txIds.length !== h.txCount) {
        throw new Error(`${where}: transaction root mismatch`);
      }
      for (const id of block.txIds) {
        const tx = txsById.get(id);
        if (!tx) throw new Error(`${where}: missing transaction ${id}`);
        applyTx(state, tx, h.height);
      }
      if (state.minted.toString() !== h.minted || state.burned.toString() !== h.burned) {
        throw new Error(`${where}: supply totals do not match replay`);
      }
      if (block.txIds.length) {
        const first = txsById.get(block.txIds[0]);
        const last = txsById.get(block.txIds[block.txIds.length - 1]);
        if (first.seq !== h.firstSeq || last.seq !== h.lastSeq) throw new Error(`${where}: sequence range mismatch`);
      }
    } catch (e) {
      errors.push(e.message);
      break;
    }
    prevHash = block.hash;
  }
  return { ok: errors.length === 0, errors, state, height: blocks.length - 1 };
}

module.exports = {
  TX, TREASURY, addressFor, isAddress, makeTx, txBody, txId, blockHash,
  emptyState, applyTx, buildBlock, verifyChain,
};
