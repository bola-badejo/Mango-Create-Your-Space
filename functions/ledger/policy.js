"use strict";
// MangoChain economic policy. Every number here is a founder decision;
// changing one after launch needs a documented chain upgrade because the
// verifier checks history against these rules.
const { UNIT } = require("./units");

const CHAIN_ID = process.env.MANGO_CHAIN_ID || "mango-mainnet-1";

// ---- Supply --------------------------------------------------------------
// Matches MAX_SUPPLY in lib/Wallet/logic/MangoToken.sol, so any future
// bridge to Polygon is 1:1 (ERC-20 18 decimals = base units * 10^10).
const MAX_SUPPLY = 100_000_000n * UNIT;
// Minted once in the genesis block to the treasury (ecosystem, grants,
// creator programmes). Matches INITIAL_SUPPLY in MangoToken.sol.
const GENESIS_TREASURY = 10_000_000n * UNIT;
// Released only through activity mining, never by an operator.
const MINING_POOL = MAX_SUPPLY - GENESIS_TREASURY;

// ---- Proof of activity issuance -----------------------------------------
const EPOCH_MS = 60 * 60 * 1000; // one epoch per hour
const HALVING_EPOCHS = 35_064; // about 4 years of hourly epochs
// Geometric series: sum over all halvings = 2 * HALVING_EPOCHS * E0 <= pool.
const INITIAL_EPOCH_EMISSION = MINING_POOL / (2n * BigInt(HALVING_EPOCHS));
// An epoch closes this long after it ends, so in-flight writes land first.
const EPOCH_GRACE_MS = 5 * 60 * 1000;

/** Most MangoCoin that may be minted for an epoch (its "block reward"). */
function emissionForEpoch(epoch) {
  if (!Number.isSafeInteger(epoch) || epoch < 0) return 0n;
  const halvings = Math.floor(epoch / HALVING_EPOCHS);
  if (halvings >= 64) return 0n;
  return INITIAL_EPOCH_EMISSION >> BigInt(halvings);
}

// Points are integers in milli-points. A reward can never exceed this rate,
// so a quiet epoch with few active users cannot hand them the whole
// emission. Unminted emission is never minted later: it stays in the pool,
// which extends the mining life of the supply.
const MAX_UNITS_PER_MILLIPOINT = 1_000n; // 0.01 MNG per point

// ---- Activities ------------------------------------------------------------
// shares are per mille of the activity's points: actor = the account that
// did the activity, creator = the owner of the content or profile engaged
// with, spaceOwner = the owner of the Space it happened in.
const ACTIVITIES = {
  post_created: { points: 5000, shares: { actor: 1000 }, dailyCap: 5 },
  like_given: { points: 1000, shares: { actor: 200, creator: 800 }, dailyCap: 50, oncePerSubject: true },
  follow_given: { points: 2000, shares: { actor: 200, creator: 800 }, dailyCap: 20, oncePerSubject: true },
  daily_check_in: { points: 1000, shares: { actor: 1000 }, dailyCap: 1 },
  consume_song: {
    points: 2000, minSeconds: 30, dailyCap: 100,
    shares: { actor: 200, creator: 800 },
    spaceShares: { actor: 200, creator: 700, spaceOwner: 100 },
  },
  consume_podcast: {
    points: 1500, minSeconds: 60, dailyCap: 50,
    shares: { actor: 200, creator: 800 },
    spaceShares: { actor: 200, creator: 700, spaceOwner: 100 },
  },
  consume_movie: {
    points: 5000, minSeconds: 300, dailyCap: 10,
    shares: { actor: 200, creator: 800 },
    spaceShares: { actor: 200, creator: 700, spaceOwner: 100 },
  },
  space_visit: {
    points: 800, minSeconds: 30, dailyCap: 20,
    shares: { actor: 100, spaceOwner: 900 },
  },
};

const CONSUMPTION_TYPES = { song: "consume_song", podcast: "consume_podcast", movie: "consume_movie", space: "space_visit" };

/** Duration multiplier in per mille, carried over from the original app rules. */
function durationMultiplier(seconds) {
  if (seconds <= 30) return 1000;
  if (seconds <= 60) return 1200;
  if (seconds <= 300) return 1500;
  if (seconds <= 1800) return 2000;
  return 2500;
}

/** Daily check-in streak bonus: +10% per consecutive day, up to +100%. */
function checkInPoints(streak) {
  return 1000 + 100 * Math.min(Math.max(streak - 1, 0), 10);
}

const MAX_SESSION_SECONDS = 4 * 60 * 60;
// Creator-directed points one account can generate for one other account in
// a day, so two accounts cannot farm each other.
const PAIR_DAILY_CAP = 20_000;
// Points any single account can earn in one epoch.
const ACCOUNT_EPOCH_CAP = 50_000;

// ---- Eligibility -------------------------------------------------------------
const MIN_ACCOUNT_AGE_MS = 24 * 60 * 60 * 1000;

// ---- Transfers ----------------------------------------------------------------
const TRANSFER_FEE = 100_000n; // 0.001 MNG, burned
const MIN_TRANSFER = 100n; // 0.000001 MNG
const MAX_MEMO_LENGTH = 140;

// ---- Block production -----------------------------------------------------------
// Firestore transactions allow 500 writes; a block of N sealed transfers or N
// rewards needs at most 2N + 4 writes.
const MAX_TX_PER_BLOCK = 150;

module.exports = {
  CHAIN_ID, MAX_SUPPLY, GENESIS_TREASURY, MINING_POOL,
  EPOCH_MS, HALVING_EPOCHS, INITIAL_EPOCH_EMISSION, EPOCH_GRACE_MS, emissionForEpoch,
  MAX_UNITS_PER_MILLIPOINT, ACTIVITIES, CONSUMPTION_TYPES, durationMultiplier, checkInPoints,
  MAX_SESSION_SECONDS, PAIR_DAILY_CAP, ACCOUNT_EPOCH_CAP, MIN_ACCOUNT_AGE_MS,
  TRANSFER_FEE, MIN_TRANSFER, MAX_MEMO_LENGTH, MAX_TX_PER_BLOCK,
};
