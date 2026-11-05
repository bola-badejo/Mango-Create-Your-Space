#!/usr/bin/env node
"use strict";
// Creates the Ed25519 key that signs MangoChain blocks.
//   node ledger/scripts/generate-key.js > ledger-signing-key.pem
//   firebase functions:secrets:set LEDGER_SIGNING_KEY < ledger-signing-key.pem
// Then delete the local file (or keep it in an offline password manager).
const { generateSigningKey, keyIdFor } = require("../crypto");
const { privateKeyPem, publicKeyPem } = generateSigningKey();
process.stdout.write(privateKeyPem);
process.stderr.write(`\nKey id: ${keyIdFor(publicKeyPem)}\nPublic key (safe to publish):\n${publicKeyPem}\n`);
