# QA report: S1 — A1 + Tier C (+ D3, SR-28/29/30)   (agent: Opus S1, emulator-5554 / dw-qa1, 2026-09-19 00:09–01:27 local)

Build under test: `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29 / targetSdk 35.
Wallet: fresh, created on this build. Recovery phrase (throwaway testnet): `[seed phrase redacted]`.
Username: **qa1s13939**, identity `DYjxDk3kTzf2PXAK3LfGj2cWitnyLKhx1y8u3626hbMm`.

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| A1.1 create wallet, phrase, verify | PASS | `A1/01-onboarding/01..15-*.png` | 12-word flow + "Verified Successfully" OK; phrase screen is FLAG_SECURE (screenshots black by design) |
| A1.2 receive from faucet | PASS | `A1/02-receive/04-home-after-faucet.png`, `07-insight-addr.json` | 1.0 tDASH detected pre-block and InstantSend-locked within the same second |
| A1.3 shield everything (Max) | PASS w/ defects | `A1/03-shield/08-confirm.png`, `14-shield-tx-detail.png`, `s1-shield-1.mp4` | works in ~8 s; no fee shown anywhere; 0.00213115 lost silently; 737 duffs dust left; first attempt fails + silent retry |
| A1.4 non-contested username | PASS | `A1/04-username/13-home-username-ready.png`, `14-explorer-identity.json` | registered in ~30 s, verified on the testnet Platform explorer (contested=false) |
| A1.5 reference state | PASS | `A1/05-before-reset/02-exact-balances.png`, `04-txlist-scrolled.png`, `wallet.log` | transparent 0.00000737 / shielded 0.96786148 / 2 tx rows |
| A1.6 reset wallet | PASS w/ defect | `A1/06-reset-restore/03,04,05*.png`, `s1-reset-1.mp4` | wipe is clean, but **no PIN is ever requested** |
| A1.7 restore + parity | **PASS** | `A1/07-after-restore/03-home.png`, `06-exact-balances.png`, `files/log/wallet.log` | balances, shielded, username and tx list all identical; only the shield row's displayed time moved 12:21→12:30 (block time) |
| A1.8 negative restore inputs | PASS w/ defect | `A1/08-negative/10,11,12-*.txt` | all three rejected, no crash; error text is a literal placeholder `Error` |
| C1 send to address | **FAIL** | `C1/08-after-confirm.png`, `09-send-blocked-log.txt`, `13-after-retry2.png` | send impossible after 4 min idle ("not fully synced"); only an app restart recovers |
| C2 send-all / drain | PASS w/ defects | `C2/05-sendall-log.txt`, `09-home-drained.png`, `11-drain-log.txt` | send-all to address is clean; Max→shielded leaves 1225 duffs of dust (does not drain to zero) |
| C3 receive | **FAIL** | `C3/01-receive.png`, `02-insight-addr-reused.json`, `05-receive-with-amount.png` | QR + amount flow fine, but the Receive tab never rotates the address after use |
| C4 unshield | PASS w/ defect | `C4/06-home-after-unshield.png`, `07-unshield-tx-detail.png` | list row correctly "Unshielded"; the detail sheet still says "Amount Received"/Income |
| C5 memo + tax category persistence | PASS | `C5/03-memo-saved.png`, `05-after-relaunch-detail.png` | both survive force-stop + relaunch, no stuck "Loading" |
| C6 payment URI | PASS | `C6/01-deeplink-prefilled.png`, `02-invalid-uri.png` | valid URI pre-fills address+amount; invalid URI → clean error, no crash |
| C7 tools | PASS / partly BLOCKED | `C7/03-xpub.png`, `C7/06-export.csv`, `C7/08-scan-key.png` | address book, tpub, CSV export OK (CSV has issues); WIF import is camera-only → BLOCKED |
| D3 contact request from S5 | PASS | `D3/01-notifications.png`, `07-after-send.png`, `08-home-txrow.png` | request survived the reset/restore, accepted, paid 0.001 by username, row shows the contact name |
| SR-28 confirm fee vs actual | **CONFIRMED** | `C1/07-after-pin.png`, `C1/17-insight-sendtx.txt` | quoted 0.0001, actual 0.00000226 (~44x) |
| SR-29 send-all failed-then-retry | NOT REPRODUCED | `C2/05-sendall-log.txt` | single `l1SendAll` broadcast, no failure, no retry |
| SR-30 Max on shielded send | **CONFIRMED** | `SR30/01,02*.png`, notes `06:10:44` excerpt | Max amount always fails pre-broadcast; rescued by one silent auto-retry |

Memory over the whole 78-minute session (`mem.csv`, 77 samples): peak TOTAL PSS **480 MB**, peak native heap **316 MB** (both at 00:40:51, during the post-restore replay), peak Dalvik heap 42 MB. No LMK/OOM kill — `exitinfo.txt` shows only my own two FORCE STOPs. No `FATAL`/`AndroidRuntime` in 117k lines of logcat, no `OutOfMemory`, no `OverlappingFileLockException`, no `filter-stall watchdog`.

## Per-test detail

### A1.1–A1.2 create + fund
- 00:10 install, 00:11 create wallet → 12-word security level → PIN 1234 → "Backup your recovery phrase" → phrase → verify-by-tapping-in-order → "Verified Successfully".
- `wallet.log 05:10:33 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))`, `05:13:06 L1ShadowSyncService - L1 shadow SPV started`.
- Faucet: `qa-faucet.sh` failed (Cloudflare 1010, headless UA banned — environment, not product). Requested once through the studio browser: txid `7efffea3f48e144dbe6f13ae0eb491c67d1018a9e890bd11fa47e8b68abed4d2`, 1.0 tDASH.
- `05:15:24 L1ShadowSyncService - L1 engine tx event: Detected(... netAmountDuffs=100000000 ...)` → `CutoverUiDataService - engine detected tx ... pre-block — syncing display row now` → `InstantLocked(...)` → `display row flipped pre-block`, all inside the same second. Explorer agrees (`A1/02-receive/07-insight-addr.json`).

### A1.3 shield (Max)
- Entry point is **not** the More screen (its "Shielded" card is inert); it is Payments → **Internal** → "Shielded balance".
- Result: transparent `0.00000737`, shielded `0.99786148` — total `0.99786885` from `1.00000000`, i.e. **0.00213115 consumed**, of which only `0.00000263` (the L1 network fee) is visible anywhere in the UI.
- `05:21:58 ShieldedBalanceServiceImpl - shielded shieldFromWallet rejected pre-broadcast (no lock tracked)` (+ full stack trace), then `05:21:58 ShieldedTransferExecutor - max shield auto-adjusting for L1 asset-lock fee: requested 1, reserve 1000 duffs (1 UTXOs), retrying once with 0.99999`.

### A1.4 username
- Non-contested rule confirmed by the app's own explainer: "Any username that has a number 2–9 or 20 or more characters will be automatically approved". `qa1s13939` qualifies.
- `05:26:58 BlockchainIdentityData - creation: BlockchainIdentityData(DONE, qa1s13939, CONFIRMED, null, null, DYjxDk3kTzf2PXAK3LfGj2cWitnyLKhx1y8u3626hbMm)`.
- Explorer (`https://testnet.platform-explorer.pshenmic.dev`): alias `qa1s13939.dash`, `status ok`, `contested false`, `totalTopUpsAmount 3000000000` credits = exactly 0.03 DASH. Shielded went 0.99786148 → 0.96786148, exactly −0.03.
- The brief's `platform-explorer.pshenmic.dev` is the **mainnet** instance (its status reports core height 2 539 047); the testnet instance is `testnet.platform-explorer.pshenmic.dev`.

### A1.6–A1.7 reset + restore  (the headline assertion)
| item | before reset | after restore | verdict |
|---|---|---|---|
| transparent | 0.00000737 | 0.00000737 | MATCH |
| shielded | 0.96786148 | 0.96786148 | MATCH |
| username | qa1s13939 | qa1s13939 | MATCH |
| tx list | Shielded −0.999993, Received +1 | Shielded −0.999993, Received +1 | MATCH |
| shield row time | 12:21 AM | 12:30 AM | differs (block time, see S1-D11) |

- Restore took ~5 min end to end (`Syncing 6%` → `55%` in 30 s → done by 00:43). `05:41:11 L1Shadow phase=SYNCED 100.0% headers 1556564/1556564 filters 1556564/1556564 wallet 1556564 ... SETTLED`.
- Wipe log is clean: `05:32:42 L1ShadowSyncService - wallet-wipe SDK cleanup ... deleting the SPV dataDir (21 files) ... NO rebind`, `SdkWalletBinder - binder state reset`, `WalletApplicationExt - databases cleared (isWalletWipe = true)`, `OnboardingActivity - reset finished`.

### C1 send to address — the FAIL (ledger item D-029)
Full timeline, UI state and retries are in `notes.md` under "C1 … === D-029 detail ===". Short version: the app was foreground, idle and displaying a fully synced UI (`phase=SYNCED 100.0% headers 1556573/1556573` at 05:57:29, and the send screen itself read `Balance: DASH 0.01000737 ~ $0.61`). At 06:01:00 `BlockchainServiceImpl - idling detected, stopping service` / `serviceJob cancelled after 4 minutes` and `L1ShadowLifecycle STOPPED after 4m7s up; all four loops torn down … Nothing runs until the next startIfEnabled()`. The send 26 s later failed with the modal "Problem sending coins! Currently payments are not possible because the wallet is not fully synced with the network" and, in the log, `SdkL1SendService - SDK l1Send not attempted (L1 funding gate closed: SDK L1 engine not running)` → `SendEngineNotSyncedException` (`SendCoinsTaskRunner.kt:172/451`). An immediate retry 74 s later failed identically. Only force-stop + relaunch restarted the engine (`06:03:14 L1 shadow SPV started`), after which the identical send succeeded (`06:05:00 SDK l1Send: broadcast 100000 duffs … txid bd9fc16d…`, InstantLocked 0 s later).

## Defects found

| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| S1-D01 | **S2** | Sending becomes impossible ~4 min after the app goes idle, with a false "not fully synced" message; only an app restart recovers | Open the app, leave it foreground and idle >4 min, then Send → any address → amount → PIN → Confirm | `C1/08-after-confirm.png`, `C1/09-send-blocked-log.txt`, `C1/11-after-retry-confirm.png`; log `06:01:00 idling detected, stopping service` / `serviceJob cancelled after 4 minutes` / `L1ShadowLifecycle STOPPED after 4m7s up` then `06:01:26 SendEngineNotSyncedException: … L1 funding gate closed: SDK L1 engine not running` | `BlockchainServiceImpl` idle shutdown vs `SdkL1SendService`/`SendCoinsTaskRunner.kt:172,451`; the send path should call `startIfEnabled()` instead of failing |
| S1-D02 | S3 | "Reset Wallet" never asks for the PIN | More → Security → Reset Wallet → "Reset wallet" → "Save data and reset wallet" | `A1/06-reset-restore/03,04,05-*.png`, `A1/06-reset-restore/s1-reset-1.mp4` | reset/wipe sequence — the brief's "confirm with PIN" step does not exist, so the wrong-PIN negative test was unrunnable |
| S1-D03 | S3 | Confirm dialog quotes a network fee ~44x the fee actually paid; the post-send detail sheet shows neither the fee nor the recipient | Send 0.001 to any address; read "Network fee 0.0001" on the confirm sheet; compare with insight after broadcast | `C1/07-after-pin.png` (quote 0.0001), `C1/17-insight-sendtx.txt` (`fees 2.26e-06`, 225-byte tx), `C1/13-after-retry2.png` (detail sheet: only "Amount Sent −0.00000226") | send confirm fee estimate (SR-28) |
| S1-D04 | S3 | "Max" on any shielded transfer offers an amount that can never be broadcast; it always fails once and is silently auto-retried with a smaller amount, stranding dust | Payments → Internal → Shielded balance → Max (either direction) → Continue → Confirm → PIN | shield: `05:21:58 shieldFromWallet rejected pre-broadcast (no lock tracked)` + `max shield auto-adjusting … reserve 1000 duffs (1 UTXOs), retrying once with 0.99999`; unshield: `06:10:44 withdrawToCore rejected pre-broadcast … Insufficient shielded balance: available 95510957600, required 95786148200` + `max withdraw auto-adjusting … retrying once with 0.95235766`; drain: `06:25:17 … reserve 1488 duffs (3 UTXOs), retrying once with 0.96133372`. `SR30/*`, `C2/11-drain-log.txt` | `ShieldedTransferExecutor` Max computation (SR-30). Result: the user is charged/credited a different amount than the one they confirmed, and 737–1225 duffs are left stranded so the wallet never drains to zero |
| S1-D05 | S3 | Shielded transfer confirm sheet shows no fee line at all; the shielded-side cost is disclosed nowhere | Shield 1.0 with Max; compare pre/post totals | `A1/03-shield/08-confirm.png` ("Total 1.00 Đ"), `A1/03-shield/15-shielded-screen-after.png` (0.00000737 + 0.99786148 = 0.99786885) | shielded confirm UI — 0.00213115 (0.21%) unexplained |
| S1-D06 | S3 | Unshield transaction detail sheet presents an internal unshield as an external receive and defaults it to taxable "Income" | C4 unshield 0.01, then open the "Unshielded" row | `C4/07-unshield-tx-detail.png` ("Amount Received", "Received at", "Tax Category: Income") vs the list row which correctly reads "Unshielded" | tx-detail classification on the SDK seam (the "stuck on Received" family) |
| S1-D07 | S3 | The Receive tab never rotates the address after it has been used | Receive, note the address; receive funds to it; return to Receive | `C3/01-receive.png`, `C3/02-insight-addr-reused.json` (3 txs, 1.01 received on `yRjAzoy…`), contrast `C3/05-receive-with-amount.png` which does hand out a fresh address | receive screen address provider (privacy) |
| S1-D08 | S3 | DashPay welcome screen reports only the transparent balance although the username is paid from the shielded pool | More/Home → Join DashPay with all funds shielded | `A1/04-username/02-welcome-balance-note.png` — "You have 0.00000737 Dash. Some usernames cost up to 0.25 Dash." while 0.99786148 sat shielded | `WelcomeToDashPayFragment` balance source |
| S1-D09 | S3 | Outgoing address-send defaults its Tax Category to "Income" | Send to an address, open the resulting detail sheet | `C1/13-after-retry2.png` vs the app's own explainer `C1/15-tax-explainer.png` ("Outgoing transactions by default will be marked as Expense"). The contact payment (D3) correctly defaulted to Expense | tax-category defaulting for self/address sends |
| S1-D10 | S3 | CSV export omits internal transactions, exports an own-pool unshield as "Income", and leaves every Fee column empty | Tools → CSV export → Export transactions | `C7/06-export.csv` — 5 rows, missing `bd9fc16d…` (the "Internal" row visible in the app); `Fee`/`Fee Currency` empty on all rows; `31546c95…` (own shielded → own wallet) exported as `Income` | CSV export / tax reporting |
| S1-D11 | S4 | A restored wallet shows a different time for the same transaction (first-seen before reset, block time after) | Compare A1 step 5 and step 7 tx lists | `A1/05-before-reset/04-txlist-scrolled.png` (12:21 AM) vs `A1/07-after-restore/03-home.png` (12:30 AM); insight block time 2026-09-19T00:30:27 (`A1/07-after-restore/04-insight-shieldtx.txt`) | tx timestamp source after restore. Amounts/balances/order all match, so this is display-only — flagged S4 rather than S1, reclassify if the "any difference" rule is meant literally |
| S1-D12 | S4 | Every restore failure shows the same message with a literal `Error` placeholder in place of the reason | Restore with a malformed word / 11 words / bad checksum | `A1/08-negative/10,11,12-*.txt` — all three: "Wallet could not be restored:\n\nError\n\nBad recovery phrase?" | restore error mapping |
| S1-D13 | S4 | The "I accept" label on the username confirm sheet is not clickable; only the checkbox square is | Username flow → Request Username → tap the words "I accept" | `A1/04-username/09-accept-checked.png` (Confirm still `enabled="false"`) vs `10-accept-checked2.png` | username confirm dialog hit target |
| S1-D14 | S4 | "Import private key" offers only a camera scan — no paste/manual field for a WIF | Tools → Import private key | `C7/07-import-key.png`, `C7/08-scan-key.png`, `C7/09-scanner.png` | import flow; also the reason the WIF sweep test is BLOCKED here |

## Environment problems (not product defects)
- `$QA_ROOT/bin/qa-faucet.sh` is blocked by Cloudflare error 1010 (`browser_signature_banned`) for the headless Playwright user-agent. Worked around with the studio browser (one request only, txid `7efffea3…`). Now documented in AGENT-BRIEF.md.
- The brief's Platform explorer `platform-explorer.pshenmic.dev` is the **mainnet** deployment; testnet DPNS/identity lookups must go to `testnet.platform-explorer.pshenmic.dev`.
- `qa-app.sh logcat-start` produced an empty file for the first ~65 min; `logcat-early.txt` (ring-buffer dump, 15 978 lines) covers that window, `logcat.txt` (117 172 lines) covers the rest.
- `adb shell input text` needs spaces encoded as `%s`; the first pass of the A1.8 negative tests entered a single word and was re-run correctly.
- The app auto-locks after ~1 min of foreground idle, which repeatedly interrupted poll loops (expected behaviour, not filed).

## Not run / blocked, with reason
- **WIF import/sweep (part of C7)** — BLOCKED: the only entry point is a QR scanner and the emulator has no camera source able to present a QR (restarting the AVD with a virtual-scene poster is out of scope). Error handling partially covered by feeding the generated testnet WIF as a `dash:` URI → "Invalid Dash URI", no crash (`C7/10-wif-as-uri.png`).
- **Wrong-PIN-on-reset negative check (A1.8)** — cannot be run: the reset flow never asks for a PIN (S1-D02).
- **C1 "send to a random valid testnet address"** — deliberately not done; the task restricted sends to my own wallet's addresses to preserve funds.
- Masternode keys / Network monitor / ZenLedger (Tools) — not exercised; out of the assigned scope.

## Evidence paths
- Root: `/Users/dcg/workspace/dash-wallet-qa/evidence/S1/`
- Journal: `/Users/dcg/workspace/dash-wallet-qa/evidence/S1/notes.md`
- Per-test: `A1/01-onboarding … A1/08-negative`, `C1`, `C2`, `C3`, `C4`, `C5`, `C6`, `C7`, `D3`, `SR30`
- Videos: `A1/03-shield/s1-shield-1.mp4`, `A1/04-username/s1-username-1.mp4`, `A1/06-reset-restore/s1-reset-1.mp4`, `A1/06-reset-restore/s1-restore-1.mp4`, `A1/07-after-restore/s1-restore-2.mp4`, `C1/s1-c1-send.mp4`, `C4/s1-c4-unshield.mp4`, `D3/s1-d3-contact.mp4`, `SR30/s1-sr30-max.mp4`, `C2/s1-c2-sendall.mp4`, `C2/s1-c2-drain.mp4`
- Logs: `logcat-early.txt`, `logcat.txt`, `mem.csv`, `exitinfo.txt`, `A1/05-before-reset/wallet.log`, `A1/07-after-restore/files/log/wallet.log`, `final-logs/wallet.log`
- Shared: `/Users/dcg/workspace/dash-wallet-qa/evidence/shared/usernames.txt`, `/Users/dcg/workspace/dash-wallet-qa/evidence/shared/contact-accepted.txt`
