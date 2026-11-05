# MangoChain

MangoChain is the MangoCoin (MNG) ledger. It replaces the on-device "blockchain", where the phone calculated its own rewards, wrote its own balance, and signed blocks with a timestamp and a random number.

## What it guarantees

| Property | How |
| --- | --- |
| Balances can only change by valid transactions | All writes happen in Cloud Functions inside Firestore transactions; security rules forbid every client write to ledger and wallet collections |
| History cannot be edited silently | Blocks are hash-linked, each holds a Merkle root (RFC 6962) of its transactions and an Ed25519 signature from a key only the functions hold |
| Anyone can check the whole ledger | `scripts/audit.js` replays every block from genesis, re-checks every rule, and compares every stored balance with the replay. A daily scheduled audit writes its result to `ledger_meta/audit` |
| Supply is fixed | 100,000,000 MNG maximum, matching `MAX_SUPPLY` in `MangoToken.sol`. The verifier rejects any mint above the per-epoch emission or the cap |
| Transfers cannot be double-spent or duplicated | A global sequence orders every transaction; transfers carry an idempotency key |
| Optional public proof | `ledgerAnchor` publishes the chain head to the `MangoChainAnchor` contract on Polygon daily, so history up to that point cannot be rewritten even by the operator without it showing |

### Trust model

MangoChain is a **permissioned ledger operated by Mango**, not a decentralised network. Its signing key and Cloud Functions are the single authority, the same way an exchange or a payment app runs its internal ledger. That is the right design for an in-app currency, because phones cannot secure a chain: proof-of-work on phones costs battery and can be outrun by one laptop.

What it adds over a plain database is **verifiability**. Every change is signed and replayable, so Mango cannot quietly mint, move or erase coins without the audit failing. With anchoring on, Mango cannot rewrite history without the public anchor showing it either. Moving to multiple independent validators later is possible, because blocks and rules are already deterministic.

## Economics

| Item | Value |
| --- | --- |
| Unit | 1 MNG = 100,000,000 base units (8 decimals, as the app already used) |
| Maximum supply | 100,000,000 MNG |
| Genesis | 10,000,000 MNG to the treasury (ecosystem, grants, creator programmes) |
| Mining pool | 90,000,000 MNG, released only through activity |
| Epoch | 1 hour |
| First-era emission | about 1,283 MNG per epoch (about 30,800 per day) |
| Halving | every 35,064 epochs (about 4 years) |
| Per-point ceiling | 0.01 MNG per point; unminted emission stays in the pool, extending mining |
| Transfer fee | 0.001 MNG, burned |

## How mining works (proof of activity)

The server observes real activity and credits **points** to the account that actually did it. When an epoch closes, its emission is shared pro rata by points, capped at the per-point ceiling.

| Activity | Points | Split | Daily cap | Source of truth |
| --- | ---: | --- | ---: | --- |
| Create a post | 5 | author 100% | 5 | `posts/{id}` created, writer identity from Firebase |
| Like a post | 1 | liker 20%, post author 80% | 50 | `posts/{id}/likes/{uid}`, once per post ever |
| Follow someone | 2 | follower 20%, followed 80% | 20 | `users/{uid}/followers/{uid}`, once per pair ever |
| Daily check-in | 1 to 2 | you 100% (+10%/day streak, max +100%) | 1 | `ledgerCheckIn` |
| Listen to a song | 2 × duration | listener 20%, artist 80% (in a Space: 20 / 70 / 10 Space owner) | 100 | server-timed session; artist from `music/{id}.artistId` |
| Listen to a podcast | 1.5 × duration | as above | 50 | `podcasts/{id}.userId` |
| Watch a film | 5 × duration | as above | 10 | `movies/{id}.userId` |
| Spend time in a Space | 0.8 × duration | visitor 10%, owner 90% | 20 | `spaces/{id}` owner |

Duration multipliers: up to 30 s ×1.0, 60 s ×1.2, 5 min ×1.5, 30 min ×2.0, longer ×2.5. Minimums: 30 s (song, Space), 60 s (podcast), 5 min (film). Sessions are capped at 4 hours.

### Anti-abuse rules

- **Identity from Firebase, not from documents:** triggers use `event.authId`, the account that actually wrote the document. A like document claiming to be from someone else earns nothing.
- **Server-timed consumption:** the app only says "start" and "stop"; the server measures the time.
- **Creators from the server:** the creator and Space owner are read from the content's own record, never from the app.
- **No self-dealing:** nothing for engaging with your own post, song, profile or Space.
- **Eligibility:** an account must be at least 24 hours old and verified (email, phone, Google or Apple) to earn.
- **Caps:**
  - a daily cap per activity;
  - at most 20 creator-directed points from one account to another per day;
  - at most 50 points per account per epoch.
- **Idempotent events:** each like, follow, post, session and check-in has a fixed event id, so it can only be credited once.

## Endpoints

| Function | Kind | Purpose |
| --- | --- | --- |
| `ledgerOpenAccount` | callable | Create (or return) the caller's account |
| `ledgerCheckIn` | callable | Daily check-in |
| `ledgerStartSession` / `ledgerEndSession` | callable | Server-timed consumption |
| `ledgerTransfer` | callable | Send MNG (amount in base units, idempotency key) |
| `ledgerProof` | callable | Merkle inclusion proof for a transaction |
| `ledgerOnPostCreated`, `ledgerOnPostLiked`, `ledgerOnFollow` | Firestore triggers | Credit real activity |
| `ledgerProduceBlocks` | every 5 min | Genesis (first run), seal transfers, close epochs and mint rewards |
| `ledgerAudit` | daily | Full replay audit |
| `ledgerAnchor` | daily, opt-in | Publish the head to Polygon |

## Deploying

1. **Signing key.** Create it and store it as a secret, then remove the local file:
   ```
   cd functions && npm ci
   node ledger/scripts/generate-key.js > ledger-signing-key.pem
   firebase functions:secrets:set LEDGER_SIGNING_KEY < ledger-signing-key.pem
   rm ledger-signing-key.pem
   ```
   Keep an offline backup in a password manager. Anyone with this key can sign blocks.
2. **Deploy together, in this order** (the new rules block the old app's balance writes, so ship the app update at the same time):
   ```
   firebase deploy --only firestore:indexes
   firebase deploy --only functions
   firebase deploy --only firestore:rules
   ```
   The block producer creates the genesis block on its first run.
3. **Old balances.** Old wallet balances were writable by any signed-in user, so they cannot be trusted. Review a dry run, then choose a cap:
   ```
   node ledger/scripts/migrate-legacy.js --cap 50            # dry run
   node ledger/scripts/migrate-legacy.js --cap 50 --apply    # grant from the treasury
   ```
4. **App Check (recommended).** After adding Firebase App Check to the app, deploy with `LEDGER_ENFORCE_APP_CHECK=true` in `functions/.env`.
5. **Public anchoring (optional).**
   - Deploy `contracts/MangoChainAnchor.sol` with the publisher address.
   - Set `LEDGER_ANCHOR_ENABLED=true`, `ANCHOR_RPC_URL` and `ANCHOR_CONTRACT` in `functions/.env`.
   - Set the `ANCHOR_PRIVATE_KEY` secret, then redeploy.

## Verifying independently

```
node ledger/scripts/audit.js                       # live, with Firestore credentials
node ledger/scripts/audit.js --export chain.json   # publish an export
node ledger/scripts/audit.js --file chain.json     # anyone can verify an export offline
```

Public keys are readable at `ledger_keys/{keyId}`. A transaction's inclusion proof (`ledgerProof`) can be checked against its block's signed `txRoot`.

## Tests

`npm test` in `functions/` runs 36 tests. They cover:

- chain rules and tamper detection (edited amounts, swapped transactions, forged signatures, broken links);
- Merkle proofs, Ed25519, emission and supply limits;
- every anti-abuse rule, server-timed sessions, transfers and block sealing;
- epoch rewards across many blocks, legacy migration and the offline verifier;
- the anchor contract on a local EVM.

Security rules are tested in `tests/firestore-rules` on the Firestore emulator (CI job `firestore-rules`).

## Limitations

- **Books** store no uploader user id, so reading cannot credit authors yet. Add `uploaderId` to `books` documents to enable it.
- **Scale:** the global sequence counter in `ledger_meta/chain` supports about one transfer per second sustained. Shard the sequencer before transfer volume grows past that.
- **Rules beyond the ledger:** outside the ledger, the existing open rules (any signed-in user can write anywhere) are unchanged and should be tightened separately.
- **Value and law:** MangoCoin's value comes from what it can be used for inside Mango. Before allowing it to be sold, exchanged or cashed out, get legal advice. Rules on digital assets may apply, for example Nigeria's Investments and Securities Act 2025 and the EU's MiCA regulation.
