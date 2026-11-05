"use strict";
// Runs only when ganache, ethers and solc are installed (devDependencies).
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");

let deps = null;
try {
  deps = { ganache: require("ganache"), ethers: require("ethers").ethers, solc: require("solc") };
} catch {
  deps = null;
}

function compile(solc) {
  const src = fs.readFileSync(path.join(__dirname, "..", "ledger", "contracts", "MangoChainAnchor.sol"), "utf8");
  const out = JSON.parse(solc.compile(JSON.stringify({
    language: "Solidity",
    sources: { "MangoChainAnchor.sol": { content: src } },
    settings: { optimizer: { enabled: true, runs: 200 }, outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } } },
  })));
  const errors = (out.errors || []).filter((e) => e.severity === "error");
  if (errors.length) throw new Error(errors.map((e) => e.formattedMessage).join("\n"));
  const c = out.contracts["MangoChainAnchor.sol"].MangoChainAnchor;
  return { abi: c.abi, bytecode: `0x${c.evm.bytecode.object}` };
}

test("MangoChainAnchor publishes heads and rejects outsiders and rewinds", { skip: !deps && "ganache/ethers/solc not installed" }, async () => {
  const { ganache, ethers, solc } = deps;
  const provider = new ethers.BrowserProvider(ganache.provider({ logging: { quiet: true }, wallet: { totalAccounts: 2 } }));
  const [publisher, outsider] = await Promise.all([provider.getSigner(0), provider.getSigner(1)]);
  const { abi, bytecode } = compile(solc);
  const factory = new ethers.ContractFactory(abi, bytecode, publisher);
  const contract = await factory.deploy(await publisher.getAddress());
  await contract.waitForDeployment();

  const h1 = `0x${"ab".repeat(32)}`;
  await (await contract.anchor(10, h1)).wait();
  assert.equal(await contract.latestHeight(), 10n);
  assert.equal(await contract.latestHash(), h1);
  assert.equal(await contract.anchors(10), h1);

  await assert.rejects(contract.connect(outsider).anchor(11, `0x${"cd".repeat(32)}`), /NotPublisher|revert/);
  await assert.rejects(contract.anchor(10, `0x${"cd".repeat(32)}`), /HeightNotIncreasing|revert/);
  await assert.rejects(contract.anchor(12, ethers.ZeroHash), /EmptyHash|revert/);
});

test("anchor.js publishes the current chain head and records it", { skip: !deps && "ganache/ethers/solc not installed" }, async () => {
  const { ganache, ethers, solc } = deps;
  const g = ganache.server({ logging: { quiet: true }, wallet: { deterministic: true, totalAccounts: 1 } });
  await new Promise((r) => g.listen(0, r));
  const port = g.address().port;
  const rpcUrl = `http://127.0.0.1:${port}`;
  try {
    const accounts = g.provider.getInitialAccounts();
    const [addr] = Object.keys(accounts);
    const privateKey = accounts[addr].secretKey;
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const { abi, bytecode } = compile(solc);
    const contract = await new ethers.ContractFactory(abi, bytecode, wallet).deploy(wallet.address);
    await contract.waitForDeployment();

    const written = {};
    const headHash = "12".repeat(32);
    const db = {
      doc: (p) => ({
        get: async () => ({ data: () => (p === "ledger_meta/chain" ? { height: 42, headHash } : undefined) }),
        set: async (d) => { written[p] = d; },
      }),
    };
    const { anchorHead } = require("../ledger/anchor");
    const res = await anchorHead({ db, rpcUrl, contract: await contract.getAddress(), privateKey });
    assert.equal(res.height, 42);
    assert.equal(await contract.latestHash(), `0x${headHash}`);
    assert.equal(written["ledger_anchors/000000000042"].blockHash, headHash);
    const again = await anchorHead({ db, rpcUrl, contract: await contract.getAddress(), privateKey });
    assert.equal(again.skipped, true, "an already-anchored head is not re-sent");
  } finally {
    await g.close();
  }
});
