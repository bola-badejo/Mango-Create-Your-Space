"use strict";
// Canonical encoding, hashing, Merkle trees (RFC 6962) and Ed25519 keys.
const crypto = require("crypto");

/**
 * Deterministic JSON: object keys sorted, no whitespace. Only strings,
 * booleans, null, safe integers, arrays and plain objects are allowed, so
 * every implementation (Node, Dart, a browser) hashes the same bytes.
 */
function canonicalize(value) {
  if (value === null) return "null";
  switch (typeof value) {
    case "string":
    case "boolean":
      return JSON.stringify(value);
    case "number":
      if (!Number.isSafeInteger(value)) {
        throw new TypeError(`canonical numbers must be safe integers, got ${value}`);
      }
      return String(value);
    case "object": {
      if (Array.isArray(value)) return `[${value.map(canonicalize).join(",")}]`;
      const keys = Object.keys(value).filter((k) => value[k] !== undefined).sort();
      return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalize(value[k])}`).join(",")}}`;
    }
    default:
      throw new TypeError(`cannot canonicalize ${typeof value}`);
  }
}

const sha256 = (data) => crypto.createHash("sha256").update(data).digest();
const sha256Hex = (data) => sha256(data).toString("hex");

// ---- Merkle tree, RFC 6962 style --------------------------------------
// Leaves and inner nodes use different prefixes, so a leaf can never be
// passed off as a node (the weakness in Bitcoin's duplicate-last-leaf tree).
const LEAF = Buffer.from([0x00]);
const NODE = Buffer.from([0x01]);
const EMPTY_ROOT = sha256Hex(Buffer.alloc(0));

const leafHash = (idHex) => sha256(Buffer.concat([LEAF, Buffer.from(idHex, "hex")]));
const nodeHash = (l, r) => sha256(Buffer.concat([NODE, l, r]));

function largestPowerOfTwoBelow(n) {
  let k = 1;
  while (k * 2 < n) k *= 2;
  return k;
}

function mth(leaves) {
  if (leaves.length === 1) return leaves[0];
  const k = largestPowerOfTwoBelow(leaves.length);
  return nodeHash(mth(leaves.slice(0, k)), mth(leaves.slice(k)));
}

/** Merkle root (hex) of transaction ids (hex strings), in block order. */
function merkleRoot(idsHex) {
  if (idsHex.length === 0) return EMPTY_ROOT;
  return mth(idsHex.map(leafHash)).toString("hex");
}

/** Audit path proving ids[index] is in the tree (RFC 6962 section 2.1.1). */
function inclusionProof(idsHex, index) {
  if (index < 0 || index >= idsHex.length) throw new RangeError("index out of range");
  const path = (m, leaves) => {
    if (leaves.length === 1) return [];
    const k = largestPowerOfTwoBelow(leaves.length);
    if (m < k) return [...path(m, leaves.slice(0, k)), mth(leaves.slice(k))];
    return [...path(m - k, leaves.slice(k)), mth(leaves.slice(0, k))];
  };
  return path(index, idsHex.map(leafHash)).map((b) => b.toString("hex"));
}

/** Verifies an audit path against a root. */
function verifyInclusion(rootHex, idHex, index, size, proofHex) {
  if (index >= size) return false;
  let fn = index;
  let sn = size - 1;
  let r = leafHash(idHex);
  for (const p of proofHex) {
    const pb = Buffer.from(p, "hex");
    if (sn === 0) return false;
    if (fn % 2 === 1 || fn === sn) {
      r = nodeHash(pb, r);
      while (fn % 2 === 0 && fn !== 0) {
        fn >>= 1;
        sn >>= 1;
      }
    } else {
      r = nodeHash(r, pb);
    }
    fn >>= 1;
    sn >>= 1;
  }
  return sn === 0 && r.toString("hex") === rootHex;
}

// ---- Ed25519 block signing ----------------------------------------------
function generateSigningKey() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ed25519");
  return {
    privateKeyPem: privateKey.export({ type: "pkcs8", format: "pem" }),
    publicKeyPem: publicKey.export({ type: "spki", format: "pem" }),
  };
}

function keyIdFor(publicKeyPem) {
  const der = crypto.createPublicKey(publicKeyPem).export({ type: "spki", format: "der" });
  return sha256Hex(der).slice(0, 16);
}

/** Loads a PKCS#8 PEM Ed25519 private key into a signer. */
function loadSigner(privateKeyPem) {
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  if (privateKey.asymmetricKeyType !== "ed25519") {
    throw new Error("ledger signing key must be Ed25519");
  }
  const publicKeyPem = crypto.createPublicKey(privateKey).export({ type: "spki", format: "pem" });
  const keyId = keyIdFor(publicKeyPem);
  return {
    keyId,
    publicKeyPem,
    sign: (hashHex) => crypto.sign(null, Buffer.from(hashHex, "hex"), privateKey).toString("base64"),
  };
}

function verifySignature(hashHex, signatureB64, publicKeyPem) {
  try {
    return crypto.verify(
      null,
      Buffer.from(hashHex, "hex"),
      crypto.createPublicKey(publicKeyPem),
      Buffer.from(signatureB64, "base64"),
    );
  } catch {
    return false;
  }
}

module.exports = {
  canonicalize,
  sha256Hex,
  EMPTY_ROOT,
  merkleRoot,
  inclusionProof,
  verifyInclusion,
  generateSigningKey,
  keyIdFor,
  loadSigner,
  verifySignature,
};
