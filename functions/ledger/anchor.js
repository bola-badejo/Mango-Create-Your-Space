"use strict";
// Publishes the current MangoChain head to the MangoChainAnchor contract.
const ABI = [
  "function anchor(uint64 height, bytes32 blockHash)",
  "function latestHeight() view returns (uint64)",
  "function latestHash() view returns (bytes32)",
];

async function anchorHead({ db, rpcUrl, contract, privateKey }) {
  if (!rpcUrl || !contract || !privateKey) throw new Error("anchoring is not configured");
  const { ethers } = require("ethers");
  const meta = (await db.doc("ledger_meta/chain").get()).data();
  if (!meta) throw new Error("no chain to anchor");
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const anchor = new ethers.Contract(contract, ABI, wallet);
  const last = await anchor.latestHeight();
  if (BigInt(meta.height) <= last && (await anchor.latestHash()) !== ethers.ZeroHash) {
    return { skipped: true, height: meta.height };
  }
  const tx = await anchor.anchor(meta.height, `0x${meta.headHash}`);
  const receipt = await tx.wait();
  await db.doc(`ledger_anchors/${String(meta.height).padStart(12, "0")}`).set({
    height: meta.height, blockHash: meta.headHash, chainTx: receipt.hash, contract, at: Date.now(),
  });
  return { height: meta.height, chainTx: receipt.hash };
}

module.exports = { anchorHead, ABI };
