# QA report: S11 (P1–P4) — SDK replay on a real-history wallet under constrained conditions
agent: S11 · emulator: emulator-5566 / AVD dw-qa7 · date: 2026-09-19 (01:50 – 03:01 host)
Builds: `fix-12.0.0-testnet3-release-signed.apk` (versionCode 12000000) and
`master-11.9.0-testnet3-release-signed.apk` (versionCode 11090002).
Reference seed `[seed phrase redacted]`,
READ-ONLY (nothing sent / shielded / no username). Expected balance **107.08173522** (per D-014).

## Summary table
| Test | Verdict | Key evidence | One-line finding |
|---|---|---|---|
| P1 baseline restore (3 GB) | **PASS** | `P1/12-SYNCED-home.png`, `P1/db/db-counts.txt` | restore→100 % in 5 m 42 s (engine start→100 % 4 m 31 s), balance exact, peak 596 MB PSS / 457 MB native, exit-info empty |
| P1 D-037 probe (history completeness) | **FAIL — D-037 CONFIRMED** | `P1/history/52-19-oct-2024-rows.png`, `P1/db/explorer-vs-db.txt` | 2 of 399 SDK receives (0.53848582 tDASH) have no history row; both absent from the txos-union. The wallet's FIRST receive (2019-07-31) IS present, so the severe S8 form does not generalise |
| P2 single kill during replay (D-041) | **FAIL — D-041 CONFIRMED** | `P2/09-BALANCE-after-kill-INFLATED.png`, `P2/p2-recovery.mp4` | ONE force-stop mid-replay → app reports SYNCED with **2336.304271 tDASH** (21.82× wrong); bg/fg does not fix; force-stop+relaunch does |
| P2 no-kill control | **PASS** (= P1) | `P1/12-SYNCED-home.png` | the identical restore without a kill lands on 107.081735 |
| P3 low-memory replay | **PASS** (with ENV caveat) | `P3/05-SYNCED-balance.png`, `P3/pressure-log.txt`, `P3/exitinfo.txt` | survives 5 × RUNNING_CRITICAL, no LMK, 4 m 36 s to 100 %, balance exact; footprint does NOT shrink under trim (peak 568 MB PSS) |
| P4 upgrade path on the constrained device | **PASS** | `P4/09-explainer.png`, `P4/10-replay-home.png`, `P4/12-SYNCED-balance.png` | cutover 1 s after launch, explainer once, zero post-upgrade `starting peergroup`, balance HELD at last-known 794.227628 during replay, 9 m 38 s to 100 %, final balance exact, no LMK at 647 MB peak PSS |
| P4 tx detail during replay | **FAIL — new S11-D1** | `P4/11-replay-4.png`, `P4/14-txdetail-post-sync.png` | a tx-detail sheet opened during the replay never populates and mis-binds labels/values for 9 min; correct after SYNCED |

## Per-test detail

### P1 — baseline restore on the 3 GB device
Steps (wallet.log clock = host + 5 h 00):
1. 01:50 uninstall S7's app, `adb root`, logcat + memlog(30 s) started; clean install of the fix APK.
2. 06:52:16 first launch; Restore wallet → seed → PIN 1234 → notification + background permissions.
3. 06:53:10 `cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))`
   06:54:17 `armSpvRescan: filter watermark rewind to 0 armed on b7118ed5…`
   06:54:21 `L1 shadow SPV started for SDK wallet b7118ed5…`
   06:58:52 `L1Shadow phase=SYNCED 100.0% headers 1556595/1556595 filters 1556595 wallet 1556595 SETTLED`
4. Assertions
   - time: CUT_OVER → 100 % = **5 min 42 s**; engine start → 100 % = **4 min 31 s**
   - balance: `SDK balance published: 10708173522 duffs` = **107.08173522** vs expected 107.08173522 — **MATCH**
   - memory (`mem-p1p2.csv`): peak TOTAL PSS **610,373 kB (596 MB)**, peak Native Heap **468,360 kB (457 MB)**,
     peak Dalvik **40,291 kB**; idle after sync ≈ 465 MB PSS / 311 MB native
   - `dumpsys activity exit-info`: **empty** (no process death) → `P1/exitinfo.txt`
   - 0 `starting peergroup`, 0 `filter-stall`, 0 `idling detected` during the replay, 0 `OverlappingFileLockException`, 0 `OutOfMemory`
   - reproduced D-002 (header 156.405901 under "Syncing balance" early in the replay, `P1/09-home-start.png`)
   - reproduced D-001 (auto-lock to Enter PIN during the unattended poll, `P1/10-sync-poll5.png`).
     After that I disabled `auto_logout_enabled` in shared_prefs so the device could be observed —
     noted as a deliberate harness change in `notes.md`.
5. Databases pulled as root into `P1/db/` (dash-sdk.db + -wal/-shm, dash-wallet-database + -wal/-shm).

**SQL counts** (`P1/db/db-counts.txt`)
| query | result |
|---|---|
| `SELECT COUNT(*) FROM transactions` (dash-sdk.db) | **3269** |
| txos-union `SELECT COUNT(*) FROM (SELECT txid … UNION SELECT spendingTxid …)` | **2396** |
| `SELECT COUNT(*) FROM tx_display_cache` (dash-wallet-database) | **1519** |
| `SELECT COUNT(*) FROM tx_display_cache WHERE valueSatoshis > 0` | **397** |

873 SDK transactions have **no** `txos` row at all, i.e. they are invisible to both the display-cache
writer (`SdkTxStoreWalker`) and to `TxDisplayCacheService.decideCacheRebuild` — exactly D-037's root cause.
Display-row titles: Sent 722, Received 391, Internal 354, Mixing Transactions 51, Upgrade Fee 1
(so display rows < transactions is expected because CoinJoin rounds group).

**Explorer cross-check** — first 20 BIP44 receive addresses `m/44'/1'/0'/0/i` (derived with
`uvx --with bip-utils`; index 0 = `yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd`), insight
`addr/<a>?noTxList=1` → `P1/insight-addr-summary.txt` (273 tx appearances), and the full tx bodies via
`addrs/<20 addrs>/txs` → `P1/db/explorer-vs-db.txt`:
- 236 distinct txs touch those addresses; **166 are purely incoming** (no input of ours)
- of those 166: **0** missing from `transactions`, **41** missing from the txos-union, **2** missing from `tx_display_cache`
- whole wallet: 399 SDK transactions with `netAmount > 0`; exactly the same 2 have no display row (399 − 2 = 397 = the SQL count)

The two invisible receives:
```
30d25cfa437dc80b83c3f4cda912e466c5c5d9144679d0bedfe3a174bd9c5a16  h1123983  2024-10-19 07:21:52Z  +0.20000000
301d24c9ab71b31d745188d31642925a8b09ea8e8a6b662a1398b3b2b954ce12  h1123983  2024-10-19 07:21:52Z  +0.33848582
```
Both present in `transactions`, both absent from the txos-union. Total hidden receipts **0.53848582 tDASH**.

**UI verification**
- Scrolled the history to the bottom (~170 swipes): section "31 July, 2019" with the last row
  `Received + D 0.1 / 5:04 AM` — the wallet's **first** receive
  (`bc3860520181daa812639c924745597a3c114743c620fa1867cce74a3c91b0a6`, block 146742, 0.1 tDASH to
  address index 0) is **present and correctly dated** → `P1/history/99-bottom-of-history.png`.
- Section "19 October, 2024" renders exactly **five** `Received +0.2` rows at 2:21 AM
  (`P1/history/52-19-oct-2024-rows.png`). The explorer has **seven** incoming txs in block 1123983 at
  that minute (six × 0.2 and one × 0.33848582). Two are missing from the list.

**Verdict P1: PASS for sync/balance/memory; D-037 CONFIRMED in its display-cache form, with a much
smaller blast radius on this wallet (2 of 399 receives) than on S8's massive wallet, and the
"earliest receives disappear" symptom does NOT reproduce here.**

### P2 — one kill during replay (D-041 confirm/deny) + no-kill control
1. 02:13 uninstall → clean install → restore the seed again (PIN 1234). Replay starts 07:14:21.
2. Kill point 07:16:55 `phase=FILTERS 92.7% headers 1556601/1556601 filters 1215999 wallet 1220999`
   (wallet cursor 78.4 % of tip). The 50 % target was not hittable: `L1Shadow phase=` is logged only
   every 30 s and the cursor jumped 665,999 → 1,220,999 inside one window. **One** `am force-stop`
   at 02:17:09 → `P2/05-before-kill.png`, video `P2/p2-kill-relaunch.mp4`.
3. Relaunch 02:17:17. 07:17:21 `phase=IDLE 0.0% … wallet 1415999` → resumed **above** the last logged
   cursor: **no blocks lost**, no rescan from 0.
4. During the replay the header was *correct* (107.081735 at 02:18:25–02:19:03), then diverged upward
   (2293.32319 → 2327.154954) and, when `phase=SYNCED` was reached at 07:19:46, the "Syncing balance"
   label and the progress pane **disappeared** leaving **2336.304271 tDASH** on screen
   → `P2/09-BALANCE-after-kill-INFLATED.png`.
   ```
   07:19:44 CutoverUiDataService - SDK balance published: 233630427063 duffs (was 233411690591) | l1Synced=false …
   07:19:46 L1ShadowSyncService - L1Shadow phase=SYNCED 100.0% …
   ```
   Every publish in the run carries `l1Synced=false`; the stream stops converging 2 s before SYNCED
   (`P2/sdk-balance-published.txt`). Error factor **21.82×**.
5. Ground truth from the DB pulled while inflated (`P2/db-inflated/`):
   `SELECT SUM(amount) FROM txos WHERE spendingTxid IS NULL` = **10708173522** duffs = 107.08173522,
   `transactions` = 3269. On-disk state is correct; only the published aggregate is wrong.
6. Recovery: HOME 20 s then foreground → still 2336.304271 (`P2/10`, `P2/11`). `am force-stop` +
   relaunch → 107.081735 immediately (`P2/13-recovered.png`, video `P2/p2-recovery.mp4`):
   ```
   07:21:47 CutoverUiDataService - SDK balance published: 10708173522 duffs (was none) … lastKnown=233630427063
   ```
   **New datum vs S2: the inflated value had been persisted as `lastKnown`**, so any "hold last known
   balance" path would resurface 2336.30 on a later launch.
7. `exit-info` shows only the two deliberate FORCE STOPs, no LMK/OOM (`P2/exitinfo.txt`).

**Verdict P2: FAIL — D-041 CONFIRMED on a second device, and with a SINGLE kill (S2 needed 25/50/75 %
torture). No-kill control = P1, which lands on the correct balance, so the kill is the trigger.**

### P3 — low-memory replay
**ENV limitation:** emulator 37.1 refuses to run this AVD below 2560 MB. Both `hw.ramSize=1536` in
`~/.android/avd/dw-qa7.avd/config.ini` and `emulator -memory 1536` print
`INFO | Increasing RAM size to 2560MB` (`$QA_LOGS/emu-dw-qa7.log`, `$QA_LOGS/emu-dw-qa7-1536.log`).
Guest `MemTotal` = 2,531,992 kB. To approximate a 1.5 GB-class device I added a **600 MB RAM-backed
tmpfs ballast** at `/dev/s11ballast` on top (removed afterwards) and ran the requested
`am send-trim-memory RUNNING_CRITICAL` every 60 s.

1. Clean uninstall + install of the fix APK, restore the seed.
   07:27:52 CUT_OVER, 07:28:33 `L1 shadow SPV started` (phase=CONNECTING).
2. RUNNING_CRITICAL at 02:29:19 / 02:30:19 / 02:31:19 / 02:32:20 / 02:33:20 (`P3/pressure-log.txt`);
   guest `MemAvailable` stayed 778–923 MB with the ballast held.
3. 07:33:09 `phase=SYNCED 100.0%` → **engine start → 100 % in 4 min 36 s** (vs 4 min 31 s at 3 GB:
   no measurable slowdown).
4. Assertions
   - process **survived**: pid 3772 unchanged across all five trims; `exit-info` **empty**, no LMK,
     no OOM → `P3/exitinfo.txt`
   - **no kill occurred, so no watermark resume was exercised in P3 and 0 blocks were lost.**
     `grep -E 'syncedHeight|watermark|resum'` shows only the initial `armSpvRescan: filter watermark
     rewind to 0 armed` at 07:28:29.
   - final balance `10708173522 duffs` = **107.08173522** — MATCH; header 107.081735 → `P3/05-SYNCED-balance.png`
   - peak TOTAL PSS **581,409 kB (568 MB)**, peak native **479,961 kB (469 MB)**, peak Dalvik 53,768 kB
   - 0 filter-stall, 0 `idling detected` during the replay, 0 OOM, 0 `OverlappingFileLockException`
   - video `P3/p3-replay.mp4`

**Key observation:** the app's footprint does **not** shrink in response to RUNNING_CRITICAL — it stays
at the same ~570–610 MB as the unconstrained run. On a real 1.5 GB phone with a 512 MB-class budget
this is the LMK exposure already filed as D-025/D-035.

**Verdict P3: PASS (survives, correct balance, no slowdown), with the ENV caveat that a true 1.5 GB
guest was not achievable on this emulator build.**

### P4 — upgrade path master 11.9.0 → fix 12.0.0 on the constrained device
1. Uninstall, install master 11.9.0 (versionCode 11090002), restore the seed, PIN 1234.
   07:36:43 `BlockchainServiceImpl - starting peergroup` (dashj).
2. After ~11 min of dashj: `chain/common height 592721/1556620`, `Chain download 72% done with
   964025 blocks to go, block date 2021-10-12`, header **788.189094** under "Syncing 71 %"
   → `P4/06-master-after-10min.png`. Master memory peak: **263,205 kB PSS / 49,763 kB native /
   101,365 kB Dalvik** — native heap ~10× smaller than the SDK replay.
3. 02:48:58 force-stop, 02:48:59 `adb install -r` the fix APK (true in-place upgrade), launch.
4. Assertions on this launch
   - 07:49:00 `cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)` (1 s after launch)
   - 07:49:00 `upgrade cutover: one-time sync explainer armed` — **exactly one** `explainer` line in the
     whole log; explainer displayed → `P4/09-explainer.png`
   - 07:49:02 `armSpvRescan: filter watermark rewind to 0 armed` → the upgrade re-scans from height 0
   - 07:49:05 `L1 shadow SPV started`; **zero** `starting peergroup` after the upgrade
   - no `OverlappingFileLockException`, no `idling detected` during the replay, no OOM
5. **Balance held at the last-known value during the replay: YES.** At 02:49:5x the header reads
   **794.227628** under "Syncing balance" (`P4/10-replay-home.png`) while the SDK published
   `0 duffs … lastKnown=79422762803` at 07:49:03. S3's observation reproduces on the upgrade path.
6. 07:58:43 `phase=SYNCED 100.0%` → **engine start → 100 % in 9 min 38 s** (≈2× the clean-restore time;
   the run also cycled MASTERNODES/HEADERS/FILTERS again at 100 %).
7. Final balance `10708173522 duffs` = **107.08173522**, header 107.081735 → `P4/12-SYNCED-balance.png`.
8. **No LMK kills:** pid 8640 constant for the whole replay; `exit-info` records only the deliberate
   master FORCE STOP at 02:48:55 → `P4/exitinfo.txt`. Peak **662,100 kB PSS (647 MB)** / **506,947 kB
   native (495 MB)** / 59,556 kB Dalvik — the highest of all four runs, on the most constrained device,
   and still no kill.
9. Video `P4/p4-upgrade.mp4` (first 180 s incl. cutover + explainer).

**Verdict P4: PASS.**

## Defects found
| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| **D-041** (confirmed, 2nd device) | **S1** | Grossly inflated balance after a kill during the replay; app claims to be synced | clean install fix APK → restore the reference seed → **one** `am force-stop` while `phase=FILTERS` (here wallet cursor 1,220,999/1,556,601) → relaunch → wait for `phase=SYNCED`: header shows 2336.304271 with no "Syncing balance" label (expected 107.08173522, 21.82×). bg/fg does not fix; force-stop+relaunch does | `S11/P2/09-BALANCE-after-kill-INFLATED.png`, `S11/P2/sdk-balance-published.txt` (`07:19:44 SDK balance published: 233630427063 duffs … l1Synced=false`, `07:19:46 phase=SYNCED`), `S11/P2/db-inflated/` (`SUM(txos)=10708173522`), `S11/P2/p2-recovery.mp4`, `S11/P2/exitinfo.txt` | in-memory UTXO-set aggregation after a mid-replay restart (`CutoverUiDataService` / SDK bip44 bucket). New: `lastKnown=233630427063` shows the bad value is persisted |
| **D-037** (confirmed on the reference seed) | **S1** | Historical incoming transactions have no history row when the tx has no `txos` row | restore the reference seed on the fix build, sync to 100 %, open History → "19 October, 2024": 5 `Received +0.2` rows where the explorer has 7 incoming txs in block 1123983 | `S11/P1/history/52-19-oct-2024-rows.png`, `S11/P1/db/explorer-vs-db.txt`, `S11/P1/db/db-counts.txt` (transactions 3269, txos-union 2396, display 1519, valueSatoshis>0 397) | `SdkTxStoreWalker` / `TxDisplayCacheService.decideCacheRebuild` enumerate from `txos`, so the 873 transactions with no `txos` row are invisible; 2 of them are real receives worth 0.53848582 tDASH |
| **S11-D1** (new) | S3 | Transaction-detail sheet opened during the replay never populates and mis-binds labels to values | during the post-upgrade replay tap any history row: sheet titled "Sent successfully" with a success check for a 2021 tx, empty amount / "Sent from" / "Sent to"; "Network fee" shows the value `Sent to D`, "Date" shows `Sent to`; Tax Category stuck on "Loading…". Persisted 9 min (02:52→02:58). Correct after SYNCED | `S11/P4/11-replay-4.png` … `S11/P4/11-replay-12.png` vs `S11/P4/14-txdetail-post-sync.png` | TransactionDetails binding while the SDK seam has no data yet |
| D-001 (re-observed) | S4 | Foreground auto-lock after 60 s idle broke two unattended observation windows | leave the app on Home without touching | `S11/P1/10-sync-poll5.png` | `auto_logout_minutes = 1` |
| D-002 (re-observed) | S2 | Inflated partial balance under the greyed "Syncing balance" label during the replay | restore, watch the header | `S11/P1/09-home-start.png` (156.405901), `S11/P3/03-home-replay-start.png` (134.357093) | SR-10 |
| D-025 / D-035 (supporting data) | S2 | SDK replay footprint is ~2.5× dashj's on the same device and does not respond to RUNNING_CRITICAL | compare `mem-p3p4.csv` master window (02:37–02:48) vs fix window (02:49–02:59) | master peak 263 MB PSS / 50 MB native vs fix peak 647 MB PSS / 495 MB native | replay memory telemetry |

## Environment problems (not product defects)
- **ENV-6 (new):** emulator 37.1 clamps this AVD to 2560 MB — `hw.ramSize=1536` and `emulator -memory
  1536` both log `Increasing RAM size to 2560MB`. A genuine 1.5 GB guest is not reachable; P3/P4 used
  2560 MB + a 600 MB tmpfs ballast + RUNNING_CRITICAL trims instead. `config.ini` has been restored to
  `hw.ramSize=3072` (takes effect on the next boot of dw-qa7); the ballast was deleted.
- `qa-app.sh launch` (monkey) did not start the app on this device at all; every launch in this stream
  used `am start -n …/de.schildbach.wallet.ui.OnboardingActivity`.
- `input text 1234` does not register on the app's PIN pads — the digit buttons must be tapped
  (`tapon 'resource-id=…:id/btn_N'`).
- ENV-4 confirmed: doing `adb root` **before** starting `logcat-start` keeps the pipe alive for the
  whole session (subsequent `adb root` from `grep-log` is a no-op). Both logcat captures are intact.
- D-001 forced a deliberate harness change after P1: `auto_logout_enabled=false` written into
  `shared_prefs/…_preferences.xml` with the app stopped, so the history could be scrolled.

## Not run / blocked
- The P2 kill could not be placed at exactly 50 % of the wallet cursor: the progress line is emitted
  only every 30 s and the cursor jumped 665,999 → 1,220,999 inside one window. The kill landed at
  78.4 %; it was still a single mid-replay kill and reproduced D-041.
- P4's "balance held during replay" was observed at one point (02:49:5x, 794.227628) only: a keep-alive
  gesture accidentally opened a tx-detail sheet (which is how S11-D1 was found) and it covered the
  header for the rest of that replay.

## Evidence paths
- `/Users/dcg/workspace/dash-wallet-qa/evidence/S11/notes.md` (running journal)
- `/Users/dcg/workspace/dash-wallet-qa/evidence/S11/P1/`, `P2/`, `P3/`, `P4/`
- `/Users/dcg/workspace/dash-wallet-qa/evidence/S11/mem-p1p2.csv`, `mem-p3p4.csv`
- `/Users/dcg/workspace/dash-wallet-qa/evidence/S11/logcat-p1p2.txt`, `logcat-p3p4.txt`
- pulled `wallet.log`: `S11/P2/logs/files/log/wallet.log` (P1+P2), `S11/P4/logs/files/log/wallet.log` (P3+P4)

## Evidence notes
- `P1/db/`: all six files (`dash-sdk.db`, `-wal`, `-shm`, `dash-wallet-database`, `-wal`, `-shm`) were
  pulled with `adb pull` as root; opening them with `sqlite3` checkpointed the WALs into the main
  files, so only `dash-sdk.db` and `dash-wallet-database` remain on disk (all rows included).
- `P3/logs/` is empty: P3's `wallet.log` was lost when the package was uninstalled at the start of P4.
  P3 is covered by `P3/phases.txt`, `P3/pressure-log.txt`, `P3/exitinfo.txt`, `mem-p3p4.csv` and
  `logcat-p3p4.txt`, all captured live during the run.
- `P2/logs/files/log/wallet.log` covers P1+P2; `P4/logs/files/log/wallet.log` covers P4.
