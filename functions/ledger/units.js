"use strict";
// MangoCoin amounts are integers of base units: 1 MNG = 100,000,000 units
// (8 decimals, the same scale the app already uses). Never use floats.

const DECIMALS = 8;
const UNIT = 10n ** BigInt(DECIMALS);

/** Parses a base-unit amount ("12345" or 12345n) into a non-negative BigInt. */
function toUnits(value) {
  if (typeof value === "bigint") {
    if (value < 0n) throw new RangeError("amount must not be negative");
    return value;
  }
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new RangeError("amount must be a non-negative safe integer");
    }
    return BigInt(value);
  }
  if (typeof value !== "string" || !/^\d{1,30}$/.test(value)) {
    throw new RangeError(`invalid base-unit amount: ${value}`);
  }
  return BigInt(value);
}

/** Parses a human MNG amount ("1.5", "0.00000001") into base units. */
function parseMng(text) {
  if (typeof text !== "string") text = String(text);
  const m = /^(\d{1,12})(?:\.(\d{1,8}))?$/.exec(text.trim());
  if (!m) throw new RangeError(`invalid MNG amount: ${text}`);
  const whole = BigInt(m[1]) * UNIT;
  const frac = BigInt((m[2] || "").padEnd(DECIMALS, "0"));
  return whole + frac;
}

/** Formats base units as an MNG string with 8 decimals. */
function formatMng(units) {
  const u = toUnits(units);
  const whole = u / UNIT;
  const frac = (u % UNIT).toString().padStart(DECIMALS, "0");
  return `${whole}.${frac}`;
}

module.exports = { DECIMALS, UNIT, toUnits, parseMng, formatMng };
