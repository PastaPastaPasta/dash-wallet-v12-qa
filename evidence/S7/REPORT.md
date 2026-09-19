# QA report: S7 — E8, B5, R1, BK1, TX1, N1   (agent: Opus S7, emulator: emulator-5566 / dw-qa7, 2026-09-19)

Builds: `master-11.9.0-testnet3-release-signed.apk` (versionCode 11090002) -> in-place `adb install -r`
`fix-12.0.0-testnet3-release-signed.apk` (versionCode 12000000, `fix/upgrade-memory-and-sync`).
Throwaway testnet wallet, seed `air pet hole injury snack toast end share seven cute ghost squirrel`, PIN 1234.
Collectors: `evidence/S7/mem.csv` (60 s samples 00:22-01:38), `evidence/S7/logcat.txt` (00:22-00:38 only, see Environment problems),
`evidence/S7/notes.md`, `evidence/S7/oom-exitinfo.txt`, `evidence/S7/mem-notes.txt`.

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| **E8** Fresh small wallet created on master 11.9.0, upgraded to fix 12.0.0 | **PASS** | `E8/post-upgrade/files/log/wallet.log`, `E8/26-master-home-balance.png` vs `E8/59-fix-home-full.png`, `E8/56-fix-explainer.png`, `E8/s7-e8-upgrade-launch.mp4` | Cutover clean: `DUAL_RUNNING -> CUT_OVER` once, one `L1 shadow SPV started`, zero post-cutover `starting peergroup`, explainer once, no `OverlappingFileLockException`, size-guard verdict NORMAL (not RISKY), 100% sync in 29 s, balance/tx list/memo/currency/PIN identical across the upgrade. Persisted state stays `CUT_OVER`, never `SETTLED` (D-06). |
| **B5** Tools > dashj sync (diagnostic) toggle | **PASS** | `B5/02-netmon-before.png`, `B5/09-netmon-dashj-on.png`, `B5/11-netmon-blocks.png`, `B5/14-netmon-after-off.png`, `B5/s7-b5-dashj-toggle.mp4` | Cancel leaves it off (no peergroup); confirm starts dashj (`starting peergroup`) and Network monitor gains peers + blocks; off logs `stopping peergroup`. Parity probe: **MATCH sdk=99999547 dashj=99999547, tx 3/3**. ~+15-22 MB PSS with dashj on. |
| **R1** Rescan blockchain (+ creation-date picker) | **PASS** | `R1/07-rescan-dialog.png`, `R1/08-datepicker.png`, `R1/11-rescan-confirm-with-date.png`, `R1/13-after-rescan-home.png`, `R1/s7-r1-rescan.mp4` | Rescan from Sep 1 2026 rewinds the filter watermark to 1401408, resyncs to 100% and leaves balance + tx list + memo unchanged. Only timestamps drift (D-05). `SaveMetadataAndResetDialogFragment` unreachable - see Not run. |
| **BK1** Backup / restore from file | **BLOCKED (feature absent) -> substituted reset + restore-from-seed, PASS** | `R1/01-security.png`, `BK1/03-reset-dialog.png`, `BK1/11-restored-home.png`, `BK1/s7-bk1-reset.mp4` | No file backup in Security and no "Restore from file" button in onboarding - gated behind `BuildConfig.DEBUG` (`OnboardingActivity.kt:301`), and this is a release build. Substitute path clean: wrong seed -> proper error, correct seed -> balance 0.999983 and all 5 txs restored exactly. |
| **TX1** Transaction list & detail edge cases | **PASS with defects** | `TX1/03-filter-sent.png`, `TX1/04-filter-received.png`, `TX1/07-txdetail-received.png`, `TX1/12-txdetail-internal.png`, `TX1/08-explorer.png`, `TX1/13-duplicate-address-rows.png` | Direction/sign correct everywhere (a self-send is never announced as a receive, confirmed in log). Explorer chooser works. Copy-txid and share are **not implemented** in this build. Display defects D-03, D-05, D-07, D-08. |
| **N1** Notifications | **PARTIAL** | `N1/06-notification-shade.png`, `N1/07-notification-expanded.png` | Shade captured with a real wallet notification. The prescribed trick cannot work: the app correctly suppresses a notification for its own send, so a genuine third-party receive-while-backgrounded was not exercised. A stale duplicate receive notification was found instead (D-04). |
| **SR-03 / SR-28 / SR-29** (orchestrator static-review follow-ups) | **SR-03 mixed, SR-28 confirmed, SR-29 confirmed** | see per-test detail | SR-03: the **upgraded** (dashj-born) keychain rotates correctly; after **reset + restore-from-seed on the fix build** every address handed out is already used (D-02). SR-28 and SR-29 reproduced exactly as predicted (D-01, D-01b, D-09). |

---

## Per-test detail

### E8 - fresh small wallet on master 11.9.0 -> fix 12.0.0

**Steps (wall clock)**
1. 00:22 installed master 11.9.0 clean; 00:23-00:27 created a 12-word wallet, PIN 1234, verified the phrase, granted notifications + background (`E8/02`-`E8/13`).
2. 00:28 receive address #1 `yLRHLPYFiRXPQPm2CaD5AsifEfqpYbSRKo` (`E8/14`). Funded **once** from faucet.thepasta.org (Cap PoW challenge, one request) - txid `aa57902d1c5547d48cabe6d674babe10b728ab1262f6564bfcca1a6ec7b1bb33` (`E8/15-faucet-sent.png`).
3. 00:29-00:33 receive landed and confirmed (`E8/21`, `E8/53`); insight confirms 1 tDASH, 0 unconfirmed. Added memo **"S7-faucet-memo"** (`E8/25-master-txdetail-memo.png`).
4. 00:35 receive address **rotated** on master to `yMahoHJCR7ZGztjQwxZ7FZpBEMDdnTpRjh` (`E8/27`). Sent 0.05 to it - confirm sheet fee **0.00000227**, total 0.05000227 (`E8/35`); result "Amount Sent -0.00000227", change `yg6CfcF5yBA9eNaJGgrczqEGLxcAAyJiSq` (`E8/37`). txid `1a1dac75452c890f0c976a000315cfd96a702feded36e2d57f7828340c3a330a`, confirmed on insight.
5. 00:37-00:40 set Local currency **EUR** (`E8/48`), enabled home tap-to-hide (`E8/52`).
6. 00:42 pre-upgrade capture: `E8/pre-upgrade/files/log/wallet.log`, `E8/pre-upgrade/prefs-master.xml` -> `last_version=11090002`, `previous_version=0`, `best_chain_height_ever=1556564`; wallet file **274,663 bytes**.
7. 00:42:10 `am force-stop`; 00:42:12 `adb install -r` fix 12.0.0; video started; 00:42:19 launched.

**Cutover assertions** (file `E8/post-upgrade/files/log/wallet.log`)

| Assertion | Expected | Actual |
|---|---|---|
| `cutover state` this launch | one DUAL_RUNNING -> CUT_OVER | line 3715 `05:42:20 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)` - exactly 1 |
| `L1 shadow SPV started` | exactly 1 | line 3922; `grep -c` = 1 for that process |
| `starting peergroup` after cutover | 0 | 0 (the 3 occurrences are master, 05:26/05:38/05:40) |
| one-time explainer | shown once | line 3717 `explainer armed`; UI `E8/56-fix-explainer.png`; not shown again after kill+relaunch |
| `OverlappingFileLockException` | 0 | `grep -c` = 0 |
| wallet-file-size guard verdict | not RISKY | `grep -c 'wallet file size guard'` = **0** -> verdict NORMAL (the line only logs when != NORMAL, `WalletApplication.java:1196`). 274,663 B vs soft limit `min(heap/10, 100 MB)`. Also 0 `autosave debounce raised` lines. |
| sync to 100% | yes | line 3946 `05:42:49 L1Shadow phase=SYNCED 100.0% headers 1556564/1556564 filters 1556564/1556564 wallet 1556564` - **29 s after launch** |
| balance identical | 0.999998 | SDK published 99999773 duffs; home shows 0.999998 (`E8/59-fix-home-full.png`) vs master `E8/26-master-home-balance.png` |
| tx list identical | Internal 12:36 + Received 12:29 (+1, memo) | identical; memo `S7-faucet-memo` present |
| memo persisted | yes | `E8/59`, `TX1/07` |
| currency persisted | EUR | EUR 53.31 on the fix home (`E8/58`, `E8/59`) |
| hide balance persisted | - | the home tap-to-hide is **session-scoped in both builds** (no `hide_balance` key in `wallet_ui.preferences_pb`; cf. `E8/pre-upgrade/wallet_ui.preferences_pb`). The persisted setting is More > Security > Autohide Balance; enabled on the fix build and it did persist (`R1/02-autohide-on.png`). |
| PIN still works | yes | `E8/54-fix-first-launch.png` -> unlocked with 1234 |

**Post-100% send (step 5)** - 00:48 sent 0.01 to own fresh address `yMwdDaL2Ttje2uWJiDTjoV6x4fYxNUt5QM` via the SDK path: `05:48:42 SdkL1SendService - SDK l1Send: broadcast 1000000 duffs ... txid 65953a637494d70b30b4279314267f874751012c4e2be3f28e2bf246313d1cb7` (confirmed on insight). Detail shows "Amount Sent -0.00000226" (`E8/66`). Kill + relaunch 00:49 -> `05:49:36 cutover committed - serving home-screen data from the SDK`, `05:49:44 phase=SYNCED 100.0%`, `TxDisplayCacheService - cache is complete (SDK holds 3 records, display has 3 rows)`, no second explainer, no peergroup.

**Memory** (`evidence/S7/mem.csv`, `evidence/S7/mem-notes.txt`)

| Point | TOTAL PSS | Native heap | Dalvik heap |
|---|---|---|---|
| master 11.9.0, pre-upgrade | 186,776 KB | 29,364 KB | 36,140 KB |
| fix 12.0.0, just after cutover + 100% | 305,268 KB | 172,544 KB | 18,656 KB |
| fix 12.0.0, after kill + relaunch | 279,208 KB | 145,512 KB | 19,516 KB |
| session peak (during the BK1 restore replay) | **631,014 KB** | 461,860 KB | 32,308 KB |

No LMK/OOM kill: `oom-exitinfo.txt` lists only two exits, both `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` - my own force-stops. `grep -cE 'OutOfMemory|FATAL'` on wallet.log = **0**.

**Verdict: PASS.**

### B5 - Tools > dashj sync (diagnostic)

- Before: Network monitor "Synced / Connected to the Dash network", headers=filters=mnlist=chainlock 1,556,570, hint "Peer and block lists come from the dashj diagnostic engine. Turn on dashj sync in Tools to view them." (`B5/02-netmon-before.png`).
- Tapping the switch opens a 3-way dialog **Sync from date** / **Sync everything (from the beginning)** / **Cancel** (`B5/05`, `B5/07`).
- **Cancel** -> toggle stays off, `starting peergroup` count unchanged (`B5/06-after-cancel.png`).
- **Confirm "Start sync from date"** -> `05:53:42 dashj-sync-diagnostic toggle -> true; re-resolved dashjEngineMayStart=true`; `05:53:42 dashj-sync-diagnostic: store head 1556564 at/beyond checkpoint 1405440 for from-date 1789795446 - resuming`; `05:53:42 starting peergroup`.
- Network monitor then shows real peers (`/Dash Core:23.1.8(dcg-masternode-3)/`, protocol 70240, 50-423 ms) and a block list (`B5/09`, `B5/11`).
- Correctness cross-check: `05:54:26 dashj-sync-diagnostic: dashj caught up (100%) - parity MATCH estimated sdk=99999547 dashj=99999547 confirmed sdk=99999547 dashj=99999547 tx sdk=3 dashj=3`.
- **Off** -> `05:56:28 dashj-sync-diagnostic toggle -> false`; `05:56:28 stopping peergroup`; Network monitor reverts to the no-peer hint (`B5/14`).
- Memory: off 287,039 KB PSS / Dalvik 19,696 -> on 301,266 -> 308,654 KB / Dalvik 28,552 -> 33,380 -> off again 298,478 KB. **~ +15-22 MB PSS, +9-14 MB Dalvik with dashj running.**

**Verdict: PASS.**

### R1 - Rescan blockchain

- Entry point: More > Settings > **Rescan blockchain** (present on both builds).
- Dialog: "Are you sure you want to rescan blockchain? This will temporarily hide your wallet balance and remove transactions..." with optional **Select wallet creation date** (`R1/07`).
- Date picker (`WalletCreationDatePickerDialog`): picked **Tuesday, September 1, 2026**, OK; dialog then reads "September 1, 2026" (`R1/08`, `R1/10`, `R1/11`).
- Confirm -> `06:00:30 SettingsFragment - -> blockchain rescan starting at date: Tue Sep 01 00:00:00 CDT 2026`; `06:00:30 DashSdkServiceImpl - armSpvRescan: filter watermark rewind to 1401408 armed`; `06:00:30 SdkWalletBinder - blockchain-reset rescan arm ...: armed=true`.
- Sync restarted from the rewound watermark: `06:00:31 phase=FILTERS 98.3% ... filters 1476408/1556573` -> `06:00:33 phase=SYNCED 100.0%`.
- After: balance **0.999995** and the identical 3-row tx list with memo intact (`R1/13-after-rescan-home.png`).

**Verdict: PASS** (with D-05 on timestamps).

### BK1 - Backup / restore from file

**Feature absent in this build, proven from source**
- More > Security offers only View Recovery Phrase / Change PIN / Autohide Balance / Advanced Security / Reset Wallet - no "Backup wallet" (`R1/01-security.png`).
- Onboarding shows only Create new wallet and Restore wallet, and Restore wallet goes straight to the seed screen (`BK1/06`, `BK1/07`). `wt-fix/wallet/src/de/schildbach/wallet/ui/OnboardingActivity.kt:301` wraps the restore-from-file button in `if (BuildConfig.DEBUG)`, so it is compiled out of this release APK.

**Substitute coverage executed (reset + restore from recovery phrase)**
1. Reset Wallet dialog, **Cancel** path first -> returns to Security untouched (`BK1/03`, `BK1/04`).
2. Confirm -> wipe completes and hands the UI to onboarding (`BK1/05`, `BK1/06`).
3. **Wrong recovery phrase** (`...ghost zebra`) -> error dialog "Wallet could not be restored: Error - Bad recovery phrase?" (the literal `Error` placeholder in the message is cosmetic).
4. Correct phrase + PIN 1234 -> replay `06:28:44 phase=FILTERS ... filters 225999` -> `06:29:44 phase=SYNCED 100.0% headers 1556585/1556585`.
5. **Balance and txs match exactly**: pre-reset 0.999983 / 5 rows (`BK1/02-pre-reset-home.png`); post-restore 0.999983 / same 5 rows (`BK1/11-restored-home.png`). SDK published 99998345 duffs.
6. Expected losses after a full wipe: private note, local currency (back to USD), Autohide Balance. The reset dialog warns only about the recovery phrase - UX note, not filed.

**Verdict: BLOCKED for the file-backup path (feature not in a release build); PASS for the equivalent reset + restore-from-seed path.**

### TX1 - Transaction list & detail

- **Filter tabs**: All / Sent / Received / Gift cards. *Received* correctly shows only the faucet receive (`TX1/04`) - the four self-sends are classified **Internal** and never announced as receives. *Sent* renders an **empty list with no empty-state text** (`TX1/03`) where master printed "There are no transactions to display".
- **Pull-to-refresh**: swipe-down produced no visible refresh indicator; list and balance stayed correct (`TX1/06`).
- **Receive detail**: "Amount Received +1.00", received-at address, Tax Category Income, memo (`TX1/07`).
- **Send / self-send detail**: "Amount Sent -0.00000226", "Moved from" / "Internally moved to" - direction and sign correct (`TX1/12`). Log corroboration: `05:48:42 tx 65953a63... was authored by this wallet - not a receive, no notification`.
- **Explorer link**: opens a "Select block explorer" sheet (Blockchair / Insight); Insight launches Chrome (`TX1/08`, `TX1/09`).
- **Copy txid / share**: **not implemented**. `grep -niE "clipboard|ACTION_SEND|share"` over `TransactionDetailsDialogFragment.kt` and `TransactionResultViewBinder.kt` returns nothing; the only share affordance nearby is Receive > "Share Address".

**Verdict: PASS with defects D-03, D-05, D-07, D-08.**

### N1 - Notifications

- Notification permission granted during onboarding; the shade contains genuine wallet notifications (`N1/06-notification-shade.png`, `N1/07-notification-expanded.png`, captured with `cmd statusbar expand-notifications` / `collapse`).
- The prescribed trick (start a send to your own address, background immediately) **cannot produce a receive notification by design**: `06:19:51 SdkL1SendService - SDK l1Send: broadcast 1000000 duffs to ye3YgWym..., txid c178a892b31d0908286c841949c66da9814bc94bb0266ec88569c32c53e184d8` followed by `06:19:51 tx c178a892... was authored by this wallet - not a receive, no notification`. That is the correct behaviour under test ("never announce our own send as a receive"), so it doubles as positive evidence for TX1.
- A genuine third-party receive while backgrounded could not be produced (no second wallet on this stream, faucet quota already used) -> **PARTIAL**.
- What did surface is D-04, a stale duplicate receive notification triggered by the R1 rescan.

---

## Defects found

| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| **D-10** | **S2** | After "idling detected, stopping service" tears down the L1 shadow engine, **every send fails** with a misleading "not fully synced" error and never recovers in place | Fix build, cutover committed, 100% synced. Leave the app idle ~2 min. `06:07:00 BlockchainServiceImpl - idling detected, stopping service` -> `06:07:00 L1ShadowLifecycle STOPPED after 2m42s up; ... Nothing runs until the next startIfEnabled()`. Now confirm any payment: UI shows **"Problem sending coins! Currently payments are not possible because the wallet is not fully synced with the network"**, log throws `SendEngineNotSyncedException: cutover committed but the SDK engine cannot fund a send yet (L1 funding gate closed: SDK L1 engine not running)` at 06:07:03, 06:08:25 and ~06:09. Reproduced for both a 0.01 send and a send-all; retrying in place never recovers. Recovery needed backgrounding + re-foregrounding: `06:10:17 L1ShadowLifecycle RESUMING after 3m17s down`. The app idles out roughly every 1-5 min (7 `idling detected` lines this session). | `TX1/SR29-05-problem-sending.png`, `TX1/SR29-07-retry-result.png`, `TX1/SR29-08-normal-send-in-enginedown.png`, `TX1/SR29-09-after-bg-fg.png`, `BK1/pre-reset/files/log/wallet.log` | `BlockchainServiceImpl` idle teardown vs `L1ShadowSyncService.startIfEnabled()` / `SendCoinsTaskRunner.sendViaSdkBridged` (`SendCoinsTaskRunner.kt:451`, `:172`) |
| **D-01 (SR-28)** | S3 | Send confirm sheet shows a flat 0.0001 DASH network fee, 10x-44x the fee actually charged | Fix build, post-cutover. Send any amount -> confirm sheet always reads `Network fee 0.0001`, `Total = amount + 0.0001`. Complete it and open the tx detail: real fee 0.00000226 (0.01 send) / 0.00000976 (send-all). Master 11.9.0 showed the exact 0.00000227 on its confirm sheet. | `E8/64-fix-send-confirm.png` vs `E8/66-fix-selfsend-detail.png`; `TX1/SR29-03-confirm-sheet.png` vs `TX1/SR29-12-sendall-detail.png`; master baseline `E8/35-master-send-confirm-sheet.png` | SDK send seam / fee estimation (`SdkL1SendService`, `SendCoinsViewModel.executeDryRun`) |
| **D-01b (SR-28)** | S3 | Amount field silently clamps to `balance - 0.0001`; that reserve is unspendable and "Max" is inconsistent with it | Balance 0.999995. On the amount screen type `.99994547` (balance - 0.00005): at the 4th `9` the field jumps to `0.99989547` (= balance - 0.0001) and refuses to go higher. **No "insufficient funds" message is shown** - it silently clamps. Tapping **Max** instead fills the *full* balance `0.99999547`. | `TX1/SR28-02-amount-entered.png`, `TX1/SR28-03-clamped-to-balance-minus-0.0001.png`, `TX1/SR29-01-max.png` | enter-amount / max-button fee reserve |
| **D-02 (SR-03)** | S3 | After reset + restore-from-seed on the fix build, Receive and "Specify Amount" hand out **already-used** addresses | Fix build: Security > Reset Wallet, restore the same seed, wait for 100%. Receive -> `yLRHLPYFiRXPQPm2CaD5AsifEfqpYbSRKo` (insight: 3 tx appearances, 1.01 received). Specify Amount -> `yMahoHJCR7ZGztjQwxZ7FZpBEMDdnTpRjh` (2 appearances). Continue again -> `yMwdDaL2Ttje2uWJiDTjoV6x4fYxNUt5QM` (2 appearances). Send 0.01 to the shown address, reopen Receive -> it advances to `yhyt2iGA2rKEQNDRUV5GPGS6cj8QAyeMAC`, also already used (2 appearances). The **upgraded** (dashj-born) keychain by contrast rotated to genuinely fresh zero-history addresses every time. | before `BK1/12-SR03-restored-receive-before.png`, `BK1/13-SR03-specify-amount-restored.png`; after `BK1/18-SR03-receive-after-receive.png`; upgraded-wallet contrast `E8/60-fix-receive-addr3.png` + `TX1/SR03-01-fix-receive-after-receive.png` (0 appearances on insight) | SDK keychain "next fresh address" pointer after restore-from-seed (matches S1/S2) |
| **D-03** | S3 | Send-result sheet shows the **change** address as the recipient and classifies an outgoing tx as "Income" (restored/SDK-native wallet) | On the restored wallet, send 0.01 to `yLRHLPYFiRXPQPm2CaD5AsifEfqpYbSRKo`. The result sheet reads `Sent to yMUaVA6tLcgR1n43WdSWyQcwPZiPSiosVY` and `Tax Category: Income`. On chain (`insight /tx/17302fc4d75f30b5ecb8890c44a984a4e6adcd69df031eb56283890f23b718af`) the outputs are `0.01 -> yLRHLPYF...` (real recipient) and `0.97998119 -> yMUaVA6t...` (change). The intended recipient is never displayed. Broadcast itself was correct: `06:35:21 SDK l1Send: broadcast 1000000 duffs to yLRHLPYF...`. | `BK1/15-SR03-send-result.png`, `BK1/17-state.png` | post-cutover tx seam change detection / `TransactionResultViewBinder` |
| **D-04** | S3 | Duplicate/stale receive notification after a rescan | Fix build with an already-notified receive in history. Settings > Rescan blockchain, confirm. ~4 min later the app re-notifies the old receive: `06:04:46 CutoverUiDataService - SDK-discovered receive aa5790... (100000000 duffs) - notifying`; the shade shows "Received DASH 1.00" timestamped 15m although the receive happened 35 min earlier and was already notified at `05:29:18`. | `N1/06-notification-shade.png`, `N1/07-notification-expanded.png`, `BK1/pre-reset/files/log/wallet.log` | `CutoverUiDataService` SDK-discovered-receive notifier (no already-seen suppression across a rescan) |
| **D-05** | S4 | Tx list and tx detail disagree on the timestamp; list timestamps shift after a rescan | Same tx, same moment: list row `12:30 AM` (`TX1/06-pull-to-refresh.png`), detail `September 19 at 12:29 AM` (`TX1/07-txdetail-received.png`). Before the R1 rescan the list said 12:29 / 12:36; after it said 12:30 / 12:40 (block times). | `E8/59-fix-home-full.png` (pre-rescan) vs `TX1/06` vs `TX1/07` | tx display cache vs detail time source |
| **D-06** | S4 | `CutoverState.SETTLED` is unreachable - the state machine never crosses its own horizon | After cutover, kill + relaunch any number of times: persisted `cutover_state` in `files/datastore/dashpay.preferences_pb` stays `CUT_OVER`. Source: `CutoverAction.SETTLE` is dispatched nowhere in `wallet/src` - only `OBSERVE_READINESS` (`CutoverCoordinator.kt:142`) and `COMMIT_CUTOVER` (`:151`); `SETTLE`/`ROLLBACK` appear only in `CutoverStateMachine.kt` and its unit test. No functional impact (`dashjEngineMayStart(CUT_OVER) == false`; every "committed" predicate accepts `CUT_OVER || SETTLED`). | `E8/post-upgrade/dashpay-datastore-strings.txt`, `CutoverStateMachine.kt:139`, `CutoverCoordinator.kt:142,151` | `CutoverCoordinator` |
| **D-07** | S4 | Tx detail duplicates every input and output address row | Open the detail of a tx with 1 input and 2 outputs: "Moved from" lists the single input **twice**, "Internally moved to" lists the two outputs **four times**. | `TX1/13-duplicate-address-rows.png` | `TransactionResultViewBinder` / `transaction_result_address_row` inflation |
| **D-08** | S4 | Filtered tx list shows a blank area instead of the empty-state text | Home > Filter > Sent on a wallet whose outgoing txs are all "Internal": the list area is completely blank. Master 11.9.0 printed "There are no transactions to display". | `TX1/03-filter-sent.png`, master baseline `E8/13-master-home.png` | home tx-list empty state under filter |
| **D-09 (SR-29)** | S4 | Send-all first attempt fails on an insufficient-funds error, then succeeds on an internal retry | Fix build, post-cutover, Max -> Send. `06:11:28 SdkL1SendService - SDK l1SendAll: floor 99998764 duffs not deliverable at fee; retrying engine-authoritatively` with `DashSdkError$PlatformWallet$CoreInsufficientFunds: available Some(99999547), required Some(99999740)`, then `06:11:29 SDK l1SendAll: broadcast 99999547 duffs ... txid 065a166e7dcdb2df96c285afd746f45e70bfe89f2fdedffec4fbe2d30e075927`. User-visible outcome is success; cost is a thrown exception and ~1 s extra latency. Same root cause as D-01 (0.0001 flat fee floor). | `TX1/SR29-11-sendmax-result.png`, `TX1/SR29-12-sendall-detail.png`, `BK1/pre-reset/files/log/wallet.log` around 06:11:28 | `CoreSendAllNative.buildSignBroadcastDrain` / fee floor |

Master-build observation (not a fix-branch defect, not reproduced): on master 11.9.0 the first attempt to set Local currency to EUR showed "EUR" in Settings but the datastore still held `USD` and it reverted to USD on the next launch; a second attempt persisted correctly.

---

## Environment problems (not product defects)

- `qa-app.sh <serial> launch` (monkey) does not start this app on these AVDs; used `am start -n hashengineering.darkcoin.wallet_test/de.schildbach.wallet.ui.OnboardingActivity` throughout.
- `qa-app.sh text` did not escape spaces when I entered the recovery phrase (only the first word landed). Worked around with `input text 'a%sb%sc'`; the helper has since been fixed on disk.
- The session `logcat.txt` stopped collecting at 00:38 (the backgrounded `adb logcat` died, probably at an `adb root` transition). All log evidence here cites the app's own `wallet.log`, pulled three times and covering the whole session.
- The recovery-phrase and restore screens set `FLAG_SECURE`, so `screencap` returns an all-black image (`BK1/07-restore-options.png`). Those steps are evidenced by uiautomator text dumps quoted above.
- Default Auto Logout is 1 min, which locked the screen repeatedly between steps; raised to 1 hour via More > Security > Advanced Security (`R1/05-autologout.png`).
- Master had a `CoinJoin` row in Settings; the fix build does not. Not investigated - flagging only.

---

## Not run / blocked, with reason

- **BK1 file backup / restore-from-file with a password**: not present in a release build (`OnboardingActivity.kt:301`, `if (BuildConfig.DEBUG)`), and Security has no backup entry. The "wrong password -> error" path has no UI. Substituted with reset + restore-from-seed including a wrong-seed negative path.
- **R1 "Save metadata and reset" dialog** (`SaveMetadataAndResetDialogFragment`): unreachable on this wallet. `SecurityFragment.kt:196` only shows it when `viewModel.hasIdentity && viewModel.hasPendingTxMetadataToSave()`; this wallet has no DashPay identity, so `doReset()` is called directly. Needs a stream that created a username.
- **B5 "Sync everything (from the beginning)"**: displayed but not confirmed - a full dashj chain scan would have consumed the rest of the session. "Start sync from date" was confirmed instead.
- **N1 third-party receive while backgrounded**: not possible on this stream (self-sends are correctly not notified, no second wallet, faucet quota spent).
- **Copy txid / share from tx detail**: feature does not exist in this build (verified in source).
