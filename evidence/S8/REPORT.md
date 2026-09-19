# QA report: S8 / L1-L8 — massive-wallet stream (agent: S8, emulator-5568 / AVD dw-qa8, 2 GB RAM, 2026-09-19)

Build under test: `$QA_APKS/fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29 / targetSdk 35. Testnet.
Wallet under test: the synthetic "massive wallet" (seed in `$QA_ROOT/massive-wallet-seed.txt`), 800 BIP44 addresses (400 external + 400 internal, `m/44'/1'/0'`), all self-transfers, funded once with 1 tDASH. Grown by `$QA_ROOT/bin/grow-wallet.py` from 1,200 txs (start of L1) to its 3,000 target (finished 02:07). Never sent from, never stopped.
Device log clock runs **host + 5 h** (log `06:09:54` = host `01:09:54`). All times below are host time.

Evidence root: `/Users/dcg/workspace/dash-wallet-qa/evidence/S8/`

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| L1 Restore massive seed, clean install | **FAIL** (sync/memory PASS, history FAIL) | `S8/L1/logs-after-sync/files/log/wallet.log`, `S8/L1/txcount-compare.txt`, `S8/L1/missing-from-display-cache.txt`, `S8/L1/scroll/swipe-0170.png`, `S8/mem.csv` | Restore->100 % in **3 m 27 s**, balance exact, 0 stalls, no LMK on 2 GB — but **111 of 1,601 transactions never get a UI row, including the wallet's only incoming tx** (D-037/S8-D1) |
| L2 Address gap limit | **PASS** | `S8/L2/explorer-utxo-sum-final.txt`, `S8/L2/addresses-800.txt` | App balance 97,444,140 duffs == explorer UTXO sum over all 800 addresses, **0 duffs difference**, 5,204 utxos == grow log; index 399 funded on both chains |
| L3 Live growth (10 min) | **PASS** | `S8/L3/live-watch.log`, `S8/L3/watch-*.png` | New self-transfers appear live via the instant-receive path; UI balance matches the log to 6 dp at every unlocked sample; PSS flat 400-431 MB; 0 idling/stall/restart |
| L4 Kill / background / low-memory / force-stop | **PASS** | `S8/L4/bg-watch.log`, `S8/L4/lowmem.log`, `S8/L4/L4-kill-relaunch.mp4`, `S8/L4/L4-forcestop-relaunch.mp4`, `S8/exitinfo-final.txt` | Relaunch to home in 3 s (wallet load 244-303 ms, MAIN_UI_SHOWN +768/+903 ms); 10 min backgrounded with no death and flat memory; **no LMK kill at any point** on 2 GB |
| L5 Wallet file size / size guard | **PASS with observation** | `S8/L5/01-files.txt`, `S8/L5/02-sizeguard-grep.txt`, `S8/L5/03-files-final.txt` | Legacy dashj file is 15,322 B (0 txs) so the guard is silent by design; the stores that actually grow (`dash-sdk.db`, `l1_shadow_spv` **~479 MB**) are not covered by it (S8-D4) |
| L6 Reset + second restore (+1,800 txs) | **FAIL** (same defect, worse) | `S8/L6/counts.txt`, `S8/L6/sync-watch.log`, `S8/L6/missing-after-second-restore.txt`, `S8/L6/L6-restore-100.mp4` | Restore->100 % in **3 m 12 s** on a 2.6x bigger wallet, balance exact; missing rows grew **111 -> 458** and the set is **different** (only 65 in common) => racy, not deterministic |
| L7 Send screen (never sent) | **PASS during replay / FAIL after 100 %** | `S8/L7/05-max-during-replay.png`, `S8/L7/12-max-synced.png`, `S8/L7/13-max-synced-repeat.png` | SR-32 does **not** reproduce during replay (send screen shows 0.00 and blocks). After 100 %, **Max always fills an amount larger than the balance on the same screen** (S8-D3) |
| L8 CSV export + Network monitor | **FAIL** (export) / PASS (monitor) | `S8/L8/dash-wallet-transactions-2026-09-19.csv`, `S8/L8/06-network-monitor-peers.png` | CSV export hands the share sheet a **header-only 201-byte file** for a 2,753-row history, with no warning, despite an explicit "never hand back a header-only file silently" guard (S8-D2) |

## Per-test detail

### L1 — Restore the massive seed on a clean install

Steps (host time):
1. 01:04:21 `uninstall` then `install fix-12.0.0-testnet3-release-signed.apk` (versionCode 12000000 confirmed).
2. 01:04:32 launch -> onboarding -> **Restore wallet** -> seed typed into the single input, **no creation date** (`S8/L1/04-seed-entered.png`).
3. 01:06:25 Continue (grow tx count at this moment: **1200**). PIN **1234** set + confirmed 01:07:05. Notification + background permissions allowed.
4. Sync watched to 100 %; full tx list scrolled to the end; tx details opened.

Observations (`S8/L1/logs-after-sync/files/log/wallet.log`):
```
06:06:27 RestoreWalletFromSeedViewModel - successfully restored wallet from seed
06:06:27 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))
06:07:05 STARTUP breadcrumb: 12 MAIN_UI_SHOWN +106528ms
06:07:09 L1ShadowSyncService - L1 shadow SPV started for SDK wallet cd7eac70... (dataDir=.../l1_shadow_spv/testnet)
06:07:40 L1Shadow phase=HEADERS 32.3% headers 994000/1556575      <- first height
06:09:54 L1Shadow phase=SYNCED 100.0% headers 1556575/1556575 filters 1556575/1556575
06:09:56 SDK balance published: 98979130 duffs | l1Synced=true
```

Assertions:

| Assertion | Expected | Actual | Verdict |
|---|---|---|---|
| Time to first height | — | **31 s** after engine start (01:07:09 -> 01:07:40) | recorded |
| Time to 100 % | — | **3 m 27 s** from "successfully restored" (01:06:27 -> 01:09:54) | recorded |
| Engine restarts | 0 | **0** (`L1 shadow SPV started` appears once per process launch only) | PASS |
| `filter-stall` lines | 0 | **0** | PASS |
| `idling detected` lines | 0 | **0** | PASS |
| `OutOfMemory` | 0 | **0** | PASS |
| `WalletFileSizeGuard` / `RISKY` / `verdict` / `soft limit` | none (small legacy file) | **0 lines** — see L5 | PASS |
| `WalletLoadBudget` / "OVER budget" | 0 | **0** | PASS |
| `starting peergroup` (dashj) | 0 | **0** | PASS |
| `OverlappingFileLockException` | 0 | **0** | PASS |
| Balance ~ 0.99 tDASH | ~0.99 | 0.98980110 at first 100 %, tracking the grow script's fee burn exactly | PASS |
| Tx list >= grow count at sync end | >= 1,132 | **1,021 display rows vs 1,132 engine txs** | **FAIL — see D-037** |

Memory (`S8/mem.csv`, and `MEM pss=` lines in wallet.log):
* Peak `TOTAL PSS` **550,405 kB** (01:08:48); peak native heap **433,304 kB** (01:09:49); Dalvik <= 50 MB of a 576 MB large heap.
* App-side: `MEM pss=499MB nativeHeap=378/413MB jvm=21/576MB` (01:08), settling to 409-420 MB.
* `TOTAL SWAP PSS` reached **348,748 kB** at 01:10:19 — heavy swapping on the 2 GB AVD — but the process was never killed.
* `dumpsys activity exit-info`: only my two deliberate force-stops (`S8/exitinfo-final.txt`). **No LMK kill**; logcat has no `lowmemorykiller`/`lmkd`/OOM lines for the package.

Tx list scroll: 170 fling swipes to the end (`S8/L1/scroll/swipe-010...0170.png`, log `S8/L1/scroll-log.txt`). PSS stayed 393-405 MB throughout the scroll — no growth, no jank-crash. Bottom of the list is 12:18 AM, matching the grow script's start (`grow-wallet.log` created 00:17:39).

Tx details (`S8/L1/30-txdetail-1.png`, `31-...`, `32-txdetail-2.png`): title "Amount Sent", amount `-0.0000049`, "Moved from ybY4YKkUnKGxmqTiqgoFQK7LVLvmQpeuEY", "Internally moved to yaZJ2ma6aH5QeqDBKYbDg1uiprcW8KywNZ", "Network fee 0.0000049", "September 19 at 1:24 AM", "View in Block Explorer". Direction, amount and fee are all correct for a self-transfer (net debit == fee). Minor wording inconsistency: the list row says "Internal", the detail says "Amount Sent".

**Verdict: FAIL** — sync, balance, memory and stability are all good, but the transaction history is incomplete (D-037).

### L2 — Address gap limit

800 addresses derived from the seed with `bip_utils` (`S8/L2/addresses-800.txt`). Explorer sum via `POST https://insight.testnet.networks.dash.org/insight-api/addrs/utxo`, 16 batches of 50 (`S8/L2/explorer-utxo-sum-final.txt`).

Final, static comparison (grow script had finished: `done: 3000 txs`, `periodic rescan: 5204 utxos`):

| | value |
|---|---|
| Explorer UTXO sum over all 800 addresses | **97,444,140 duffs** over **5,204** utxos |
| App balance (log `SDK balance published`) | **97,444,140 duffs** = 0.97444140 tDASH |
| Difference | **0 duffs**; utxo count matches the grow log exactly |

Late addresses confirmed funded and discovered:
`ext/399 yN5T8SHRVt62bvNzNZFDc5gTnm1hK3jrr2` bal 0.00093631 (16 tx appearances) - `int/399 yWpsdVYG888aiEP9fGkx6YViMyTVkJ7Dv9` 0.00017488 (13) - `ext/398 yjJVQba2CgJm8Mb1wCwS2LFg5Y57sCnAH5` 0.00025227 - `int/398 yPziqjNtTFq8HJ2zZSFZGab8MHQK2WL1fd` 0.00073476.
An earlier mid-test comparison matched too (01:12:42 explorer 98,754,950 vs app 0.98755).

**Verdict: PASS** — no gap-limit shortfall; the wallet discovers both chains through index 399.

### L3 — Live growth (10-minute watch)

`S8/L3/live-watch.log`, 20 samples 01:16:08 -> 01:25:25.

* New self-transfers appear live. Pipeline visible in the log: `L1 engine tx event: Detected(...)` -> `engine detected tx <txid> pre-block (context=0, net=... duffs) — syncing display row now` -> `cutover UI display sync: 1 SDK records -> 1 inserts` -> `WalletTransactionsFragment - STARTUP submitData called on thread=main`, with `InstantLocked(...)` following.
* Balance stayed consistent: every unlocked sample matched the log to 6 dp, e.g. 01:25:25 UI `0.984223` vs log `SDK balance published: 98422250 duffs`.
* Memory trend flat: PSS 400-431 MB over the whole watch, SWAP PSS ~205 MB, no growth.
* 0 `idling detected`, 0 `filter-stall`, 0 restarts, 0 `OutOfMemory`.
* Caveat (known **D-001**): the app auto-locked at ~01:17:13 after 60 s without touch and stayed on Enter-PIN until I unlocked at 01:22:48 (`S8/L3/watch-04/08/12.png`). Sync and balance publishing continued behind the lock screen, so nothing was lost — but half the watch was spent locked without any user action.

**Verdict: PASS.**

### L4 — Kill / relaunch, background, low memory, force-stop

Kill -> relaunch (video `S8/L4/L4-kill-relaunch.mp4`):
```
06:32:24 PROCESS EXIT REASON: USER_REQUESTED(10) — previous process died 2m ago at 2026-09-19T01:29:51,
         importance=SERVICE(300), rss=317884KB/310.4MB, description="[FORCE STOP] ..."
06:32:24 STARTUP breadcrumb: 4 WALLET_LOAD_BEGIN +17ms size=15322
06:32:24 WalletApplication - wallet loaded from: '.../files/wallet-protobuf-testnet', took 244.1 ms (0 DashPay friend chains deferred)
06:32:25 STARTUP breadcrumb: 12 MAIN_UI_SHOWN +903ms
06:32:28 STARTUP breadcrumb: 22 SDK_L1_ENGINE_STARTED +3974ms
```
MainActivity focused **3 s** after `am start`. No `WalletLoadBudget` over-budget warning.

Background 10 min (01:33:47 -> 01:44:23, `S8/L4/bg-watch.log`, 21 samples): process never died (pid 12930 throughout), PSS 418-448 MB flat, the SDK kept ingesting (sdk 2001 -> 2383) and kept writing display rows (1890 -> 2272). 0 idling / stall / restart lines.

Low memory while foreground (01:45:49, `S8/L4/lowmem.log`): the first `am send-trim-memory RUNNING_CRITICAL` landed; #2 and #3 were rejected by AMS (`Unable to set a higher trim level than current level`) and `COMPLETE` was rejected (`Unable to set a background trim level on a foreground process`) — harness limitations, not product defects. App reaction:
```
06:45:49 BlockchainServiceImpl - onTrimMemory(15) called
06:45:49 BlockchainServiceImpl - memory pressure (onTrimMemory level 15), stopping service
06:46:44 L1ShadowSyncService - L1Shadow phase=SYNCED 100.0% ...
06:47:28 L1ShadowSyncService - L1Shadow phase=SYNCED 100.0% ...
```
The stop is announced but latched, not effective (same shape as **D-004 / SR-09**); the engine kept syncing. PSS 434 -> 423 MB. Process survived.

Force-stop + relaunch (01:47:41 -> 01:47:46, video `S8/L4/L4-forcestop-relaunch.mp4`): MainActivity in **3 s**, wallet load 302.6 ms, `MAIN_UI_SHOWN +768ms`, `SDK_L1_ENGINE_STARTED +3068ms`.

`dumpsys activity exit-info` for the whole session: exactly two entries, both `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` — **no low-memory kill on a 2 GB device across a 1,600-tx replay, a 3,000-tx replay, a 10-minute background and a critical trim.**

**Verdict: PASS.**

### L5 — Wallet file size and the size guard

`$APP emulator-5568 files` (`S8/L5/01-files.txt`, `03-files-final.txt`):

| Path | Size |
|---|---|
| `files/wallet-protobuf-testnet` (legacy dashj) | **15,322 B** (0 transactions) |
| `files/key-backup-protobuf-testnet` | 15,328 B |
| `databases/dash-sdk.db` | 5,332,992 B (+ 524,288 B WAL) -> `databases/` total **10,816 kB** at the end |
| `databases/dash-wallet-database` | 466,944 B (+ 453,232 B WAL) |
| `files/shielded_tree_testnet.sqlite` | 200,704 B (+ 4,120,032 B WAL) |
| `files/l1_shadow_spv/` | **490,576 kB ~ 479 MB** — blocks 204,528 kB, block_headers 175,240 kB, filter_headers 50,184 kB, filters 59,724 kB |

Size-guard grep (`grep-log 'autosave|WalletFileSizeGuard|soft limit|verdict' 20` -> `S8/L5/02-sizeguard-grep.txt`) returns **only autosave lines, no guard verdict at all**:
```
06:07:10 WalletFiles - Save completed in 12.94 ms (15322 bytes); .../files/wallet-protobuf-testnet
```
That is correct by construction: device largeHeap is 576 MB -> soft limit `min(576MB/10, 100MB)` = 57.6 MB, hard limit 2,000,000,000 B, and `WalletApplication.java:1195-1199` only logs when the verdict is not `NORMAL`. There is likewise no `wallet autosave debounce raised to ...` line, so the autosave delay stays at the default `Constants.Files.WALLET_AUTOSAVE_DELAY_MS` (5 s) — appropriate for a 15 KB file.

**Verdict: PASS, with observation S8-D4** — post-cutover both the size guard and the autosave debounce key off the now-empty dashj protobuf, so neither covers the stores that actually grow on this wallet.

### L6 — Reset + restore again (grow count 1200 -> 3000, +1,800 since L1)

```
02:02:05 pre-reset: grow=2879 display=2828 sdk=2876 delta=48
02:03:23 More > Security > Reset Wallet > "Reset wallet"   (NO PIN prompt at any step — matches D-012)
07:03:25 L1ShadowSyncService - wallet-wipe SDK cleanup for wallet cd7eac70: stopping shadow + shielded sync,
         removing the SDK wallet (full cascade), deleting the SPV dataDir, clearing the binder latch ...
07:03:59 RestoreWalletFromSeedViewModel - successfully restored wallet from seed
07:04:32 L1ShadowSyncService - L1 shadow SPV started ...
07:07:11 L1Shadow phase=SYNCED 100.0% headers 1556597/1556597 filters 1556597/1556597
```

| | L1 (first restore) | L6 (second restore) |
|---|---|---|
| Wallet size at 100 % | 1,132 engine txs | **3,001** engine txs (2.6x) |
| Restore -> 100 % | 3 m 27 s | **3 m 12 s** |
| Peak `TOTAL PSS` | 550,405 kB | **560,707 kB** |
| Peak native heap | 433,304 kB | 405,216 kB |
| `ReplayMemTelemetry` at SYNCED | nativeHeapSize 405,635,072 | nativeHeapSize **601,378,816**, jvmUsed 43,938,752 / 603,979,776 |
| LMK kills | 0 | 0 |
| filter-stall / idling / OOM / over-budget | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| Missing display rows | **111** (9.8 %) | **458** (15.3 %) |

The wipe deletes the SPV dataDir, so the full 1.55 M-block header + filter chain is re-downloaded; even so the second restore was slightly faster.

Balance after the second restore is exact (see L2): app 97,444,140 duffs == explorer 97,444,140 duffs.

**Verdict: FAIL** — timing and memory are fine and the second restore does find the newer txs, but the history deficit grew from 111 to 458 and the missing *set changed* (only 65 in common), proving the loss is racy rather than a fixed set of "bad" transactions. Video of the 100 % moment: `S8/L6/L6-restore-100.mp4`.

### L7 — Send screen (sending FORBIDDEN, never confirmed)

**(a) During replay** (01:08-01:10; log shows `SDK balance published: 98980110 duffs ... l1Synced=false rescanArmedHold=true`):
Send -> Send to Address -> own ext-0 address -> Continue. Screen showed `Balance: DASH 0.00 ~ $ 0.00`, amount `0`, and a blocking error *"Currently payments are not possible because the wallet is not fully synced with the network"*. Tapping **Max** did nothing (amount stayed 0), twice. `S8/L7/04,05,06`.
=> **SR-32 did not reproduce**: the send screen does not publish the untrusted partial; it shows 0.00 and refuses. Note for D-002/SR-10: the *home header* did show the moving partial during replay, because on a freshly restored wallet `persistedAsLastKnown=false lastKnown=0`, so there is no last-known to hold.

**(b) After 100 %** (01:48-01:50, `S8/L7/12-max-synced.png`, `13-max-synced-repeat.png`):

| time | balance shown on the send screen | amount Max filled in |
|---|---|---|
| 01:48:5x | DASH 0.9786871 | 0.9787372 -> red **"Insufficient funds"** |
| 01:49:35 | DASH 0.9783779 | 0.9784199 |
| 01:49:44 | DASH 0.9782446 | 0.97832 |
| 01:49:52 | DASH 0.9781366 | 0.9782185 |

Max is computed from an older balance snapshot minus a flat 0.0001 reserve (confirming SR-28/D-032's flat reserve), so on a wallet whose balance moves it is always stale-high — the screen offers an amount larger than the balance printed two rows above it. After the first attempt the log reports `executeDryRun finished (cutover-aware: SDK send-all / drain)` and `blockContinue = false, dryRunSuccessful = true`, i.e. the app would let the user continue with that over-balance amount. **Not sent.**

### L8 — CSV export and Network monitor

**Network monitor** (More > Tools > Network monitor, `S8/L8/06-network-monitor-peers.png`): "Synced / Connected to the Dash network", Block headers 1,556,595, Block filters 1,556,595, Masternode list height 1,556,595, ChainLock height 1,556,595, plus the expected post-cutover notice *"The wallet engine does not report individual peer connections. Peer and block lists come from the dashj diagnostic engine."* **PASS.**

**CSV export** (More > Tools > CSV export > Export transactions, 02:00:13, with 2,753 display rows / 2,801 SDK transactions): the share sheet offered `dash-wallet-transactions-2026-09-19.csv`, and the file on disk is **201 bytes / 1 line — the header only, zero data rows** (`S8/L8/dash-wallet-transactions-2026-09-19.csv`). The log records only `ExportCSVDialog - invoked chooser for exporting transaction history`; no warning, no error dialog. **FAIL — S8-D2.**

## Defects found

| ID | Severity | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| **S8-D1** (ledger **D-037**) | **S1** | Transactions with no `txos` row never get a UI history row, and the completeness check is blind to them in exactly the same way — 111/1,601 rows missing after the first restore, 458/3,001 after the second, including the wallet's only incoming transaction | 1. Clean-install the fix APK. 2. Restore a wallet with a large history (800 addresses, 1,600+ self-transfers). 3. Wait for `L1Shadow phase=SYNCED 100%`. 4. `adb root`; `sqlite3 dash-sdk.db 'select count(*) from transactions'` vs `sqlite3 dash-wallet-database 'select count(*) from tx_display_cache'`. 5. Deficit is permanent (see below). 6. `select count(*) from tx_display_cache where valueSatoshis > 0` -> **0**: the history shows no receive at all. | `S8/L1/root-cause.sql`, `S8/L1/txcount-compare.txt`, `S8/L1/missing-from-display-cache.txt` (111), `S8/L1/missing-by-height.txt`, `S8/L6/missing-after-second-restore.txt` (458), `S8/L1/txdisplaycache-lines.txt`, `S8/L1/planner-log.txt`, `S8/L1/scroll/swipe-0170.png`, `S8/L6/08-txlist-bottom-no-receive.png` | `CutoverUiDataService.kt:1361-1387` (`currentWalletRecordCount`), `SdkTxStoreWalker.kt:50-53` (`txoIsForeignSql`), `TxDisplayCacheService.kt:614-650` + `:1704-1723` (`decideCacheRebuild`) |
| **S8-D2** | **S3** | CSV export hands the share sheet a header-only file with no warning, despite an explicit guard that says it must never do that | More > Tools > CSV export > Export transactions on a wallet whose history is entirely self-transfers -> share sheet appears; `/data/data/<pkg>/cache/report/dash-wallet-transactions-<date>.csv` is 201 B / 1 line | `S8/L8/dash-wallet-transactions-2026-09-19.csv`, `S8/L8/07,08-*.png`, `S8/L8/csv-export.txt` | `ToolsViewModel.kt:185-226` tests `transactions.isEmpty()` on the **input** list; `CSVExporter.kt:46-72` then drops every `excludeInternal && isInternal(tx) && opReturnBurnDuffs(tx)==0` row; `ExportCSVDialog.kt:109-111` `ExportCsvResult.Empty` therefore never fires |
| **S8-D3** | **S3** | Send screen "Max" fills an amount **larger than the balance displayed on the same screen** on a wallet whose balance is changing; dry run then reports success for that over-balance amount | After 100 %, Send > Send to Address > any address > Continue > reveal balance > tap Max, repeatedly, while the balance moves | `S8/L7/12-max-synced.png`, `S8/L7/13-max-synced-repeat.png`, wallet.log 06:49:38-06:49:46 | `SendCoinsViewModel` max/dry-run path; flat 0.0001 reserve (extends SR-28/D-032) |
| **S8-D4** | **S4** (observation) | Post-cutover the wallet-file size guard and the autosave debounce both key off the legacy dashj protobuf, which is 15,322 B with 0 txs, so neither covers `dash-sdk.db` or the ~479 MB `l1_shadow_spv` dir that actually grow | Restore any wallet on the fix build; `grep-log 'autosave|WalletFileSizeGuard|soft limit|verdict'` returns no verdict line while `du -sk files/l1_shadow_spv` is ~479 MB | `S8/L5/01-files.txt`, `S8/L5/02-sizeguard-grep.txt`, `S8/L5/03-files-final.txt` | `WalletApplication.java:1195-1199`, `afterLoadWallet()` autosave delay, `WalletFileSizeGuard.kt` |
| **S8-D5** | **S4** | "Rescan blockchain" dialog promises *"This will temporarily hide your wallet balance and remove transactions"*; neither happens — the header holds the last-known balance under a "Syncing balance" label and the tx list is never emptied | More > Settings > Rescan blockchain > Rescan | `S8/L1/rescan-01-dialog.png` ... `rescan-04-home-during.png` | `RescanBlockchainDialogFragment.kt`, `strings.xml:311` |

### S8-D1 / D-037 — root cause and isolation (requested by the orchestrator)

The app's own log states the false verdict, at 01:09:54, three consecutive lines (`S8/L1/logs-isolation/files/log/wallet.log:927-929`):
```
L1ShadowSyncService  - WalletHistoryFacts: oldestTx=2026-09-19T05:18:49Z height=1556555 count=1021
L1ShadowSyncService  - WalletBalanceFacts: total=98980110 accounts={bip44:98980110, ...} txCount=1132
TxDisplayCacheService- Sync complete (cutoverCommitted=true): SDK=1010 records | dashj wallet=0 txs |
                       group cache=0 txs/0 groups | display=1021 rows —
                       cache is complete (SDK holds 1010 records, display has 1021 rows)
```
`1132 - 1021 = 111`, the exact permanent deficit.

**Chain.** The display pipeline enumerates SDK records through `SdkTxStoreWalker`, which walks **`txos`**, not `transactions` (`CutoverUiDataService.kt:1361-1387`):
```sql
SELECT COUNT(*) FROM (
  SELECT t.txid          FROM txos t  WHERE t.walletId=? AND t.txid IS NOT NULL       AND NOT (foreign)
  UNION
  SELECT t2.spendingTxid FROM txos t2 WHERE t2.walletId=? AND t2.spendingTxid IS NOT NULL AND NOT (foreign))
```
`TxDisplayCacheService.decideCacheRebuild` (`:1704-1723`) requests a reconcile only when `sdkRecordCount > displayRowCount`, and `sdkRecordCount` is that same txos-union number. Any transaction with no `txos` row is therefore invisible to **both** the writer and the checker: no display row is written, and the checker still reports "cache is complete". The check can never detect the gap it creates.

**Live proof** (01:38, `S8/L1/root-cause.sql`): `transactions = 2190`, txos-union `= 2079` (111 fewer), `txos = 7268` (2715 spent / 4553 unspent). Every one of the 111 missing display rows is exactly a txid absent from the txos union (`|missing - txo_union| = 111`, `|missing & txo_union| = 0`). `select count(*) from txos where hex(txid) = <funding txid wire order>` = **0** — the +1 tDASH funding transaction `747cb55cc55b8e0b8d8bc8d422fa8fd87e608fd2deff91078e2df361e5d4122e` (netAmount +100000000, direction 0, block 1556555) has no TXO row at all, which is why the history contains no receive row.

**Does anything repair it?**

| Attempt | Result |
|---|---|
| 5-minute quiescent wait (01:23:01 / 01:23:41 / 01:24:21 / 01:25:01) | delta stays **111** |
| `bg` 70 s -> `fg` (01:28:03 / 01:29:13 / 01:29:38) | delta stays **111** |
| force-stop + relaunch (01:32:52) | delta stays **111**; the check re-latches with `SDK=1817 records ... display=1828 rows — cache is complete` |
| 10-minute background (01:33:47-01:44:23) | delta stays **111** while both tables grow |
| **Tools/Settings > Rescan blockchain** (01:50:59 -> SYNCED 01:53:23, ~2 m 22 s) | **111 -> 47**: 64 rows recovered, 47 permanently left (all a subset of the original 111, 0 newly missing). The funding receive is still missing and `valueSatoshis>0` is still 0. Re-latched at 01:53:17 with `SDK=2479 records ... display=2490 rows — cache is complete`. Same mechanism after the rescan: all 47 are absent from the txos union. `S8/L1/rescan-test.txt`, `missing-pre-rescan.txt`, `missing-post-rescan.txt` |
| **Second full restore (L6)** | **111 -> 458**, and the *set changes*: only 65 of the original 111 recur, 393 are new, 15 of the 47 post-rescan survivors are in it => **racy / size-dependent, not deterministic**. All 458 absent from the txos union. |

**Distribution** (`S8/L1/missing-by-height.txt`): all 111 sit in the historical replay window, heights 1556555-1556571; every height from 1556573 on (arrived live) is 100 % complete. Per height 1556555 10/16, 1556557 2/14, 1556560 36/141, 1556561 3/27, 1556564 29/200, 1556566 17/200, 1556570 1/15, 1556571 13/180, and 0 missing at 1556558/1556562/1556569/1556573-1556580. Not "first N per block" — scattered within each block (positions 0-795 of 1601 in firstSeen order).

**Not the cause:** `L1/LN tx-event buffer full; dropped Detected/InstantLocked (...Room snapshot will reconcile)` fires 204 times in one minute during the replay (61 `Detected` + 143 `InstantLocked`, 147 distinct txids), but **zero** of those txids are among the missing set — that path really does reconcile (`S8/L1/planner-log.txt`).

**Suggested fix direction:** enumerate and count from `transactions` (joined to the wallet through `transaction_account_involvements`) rather than from `txos`; at minimum make `currentWalletRecordCount` read `transactions` so `decideCacheRebuild` can actually see the gap it is supposed to close.

## Environment problems (not product defects)

* **ENV — logcat stream dies on `adb root`.** `qa-app.sh logcat-start` writes through a host-side `adb logcat` pipe; the first helper that calls `adb root` (`grep-log`, `wallet-log`, `files`, `prefs`, `memlog`) restarts adbd and silently kills it. My stream stopped at 01:07:33 (`S8/logcat-part1-0104-0107.txt`); I restarted it as `S8/logcat-part2.txt` and covered the gap with `dumpsys activity exit-info` (clean) and the app's own `wallet.log`.
* `am send-trim-memory` on API 35 refuses to raise the trim level twice in a row (`Unable to set a higher trim level than current level`) and refuses background levels on a foreground process, so "RUNNING_CRITICAL x3" could only be delivered once.
* `uiautomator dump` returns empty on the Enter-PIN screen (FLAG_SECURE), which also makes automated polling look like a hang. Combined with **D-001** (60 s foreground auto-lock) this interrupted two unattended watches; I unlocked and re-ran.
* Firebase `API key not valid` in wallet.log — the stub `google-services.json`, expected.
* The `grow-wallet.py` script paused twice (01:17-01:22, 01:34) with no log output; counts were quiescent during those windows, which conveniently made the DB comparisons exact.
* `monkey -p ... LAUNCHER` intermittently left the launcher focused instead of the app; I used `am start -n <pkg>/de.schildbach.wallet.ui.OnboardingActivity` for all timed launches.

## Not run / blocked

* Nothing from L1-L8 was skipped. Sending from the massive wallet was deliberately never executed (forbidden); L7 stops at the amount screen.
* Peer-level detail in Network monitor is unavailable by design post-cutover unless the dashj diagnostic toggle is on; I did not enable it (S7 already covered B5).
* ZenLedger export not attempted (needs credentials that are placeholders in this environment).
