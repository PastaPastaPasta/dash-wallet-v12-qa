# QA report: S6 / M1-M4 - MAINNET prod build (agent: S6, emulator-5564 / dw-qa6, 2026-09-19)

Build under test: `$QA_APKS/fix-12.0.0-prod-release-signed.apk` - package `hashengineering.darkcoin.wallet`,
versionName 12.0.0, versionCode 12000000, minSdk 29, targetSdk 35.
Baseline for the upgrade path: `$QA_APKS/master-11.9.0-prod-release-signed.apk` - same package,
versionCode 11090002, minSdk 24, targetSdk 36.
Helper used for every device command: `/Users/dcg/workspace/dash-wallet-qa/evidence/S6/qa-app-prod.sh`
(copy of `qa-app.sh` with `PKG` overridden to the prod package).

**No real funds were involved.** Two seeds only: a throwaway freshly generated mainnet seed (never funded)
and the public BIP39 test vector `abandon ... about` (zero balance). Nothing was sent; no purchase, username
or dashj-toggle action was attempted.

Clock note: `wallet.log` timestamps are UTC; host `date` is UTC-5 (host 00:19 == wallet.log 05:19).

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| M1 fresh mainnet wallet sync | **PASS** | `evidence/S6/M1/15-home-synced.png`, `evidence/S6/M1/walletlog/files/log/wallet.log`, `evidence/S6/mem.csv` | Reaches `phase=SYNCED 100.0%` 42 s after the L1 engine starts (3 m 29 s from wallet creation), balance 0, zero engine restarts, peak 444 MB PSS. |
| M2 BIP39 test-vector seed | **PASS** | `evidence/S6/M2/14-SYNCED-home.png`, `evidence/S6/M2/17-txdetail-sent-2018.png`, `evidence/S6/M2/walletlog/files/log/wallet.log` | Full mainnet rescan in 5 m 45 s; balance 0.00; all 4 historical appearances on `XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5` present and matching insight; replay peaks at 995 MB PSS / 847 MB native. |
| M3 mainnet upgrade path | **PASS** | `evidence/S6/M3/upgrade-launch.mp4`, `evidence/S6/M3/10-explainer.png`, `evidence/S6/M3/12-SYNCED-home.png`, `evidence/S6/M3/exitinfo.txt` | All A3 assertions hold: `CUT_OVER (upgraded-wallet launch)`, exactly one `L1 shadow SPV started`, zero `starting peergroup` after upgrade, explainer once, no `OverlappingFileLockException`, 100 % in 5 m 13 s, balance 0, 4 tx visible, no OOM/LMK kill. |
| M4 mainnet UI sanity | **PASS** (3 findings) | `evidence/S6/M4/*.png` | Receive address starts with `X`; testnet address rejected; Explore / Buy&Sell / More / Settings / Security / Tools / Network monitor / About all open. Findings: used receive address, `12.0.0 (0)` build number, tx-detail missing fee/addresses. |

## Per-test detail

### M1 - fresh mainnet wallet, create + sync
- Build: `fix-12.0.0-prod-release-signed.apk` (12000000), clean install on a device with no prior package.
- Steps (host clock): 00:19:39 install - 00:20 launch - 00:21 Create new wallet -> 12-word -> PIN 1234 ->
  phrase shown + verified - 00:24:07 notifications/background dialogs - 00:25:30 home.
- Throwaway seed recorded in `notes.md` (never funded, never will be).
- Observations (`M1/walletlog/files/log/wallet.log`):
  - `05:21:23 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))`
  - `05:22:07 DashSdkServiceImpl - armSpvRescan: filter watermark rewind to 2404800 armed on ee230719...`
  - `05:22:07 CutoverUiDataService - cutover UI active but the engine wallet-event tap is not running
    (USE_KOTLIN_SDK_L1_SHADOW off, or L1ShadowSyncService not started) - instant receives degrade ...`
    (transient: the engine starts 123 s later)
  - `05:24:10 L1ShadowSyncService - L1 shadow SPV started ... dataDir=.../files/l1_shadow_spv/mainnet` (once)
  - `05:24:52 L1Shadow phase=SYNCED 100.0% headers 2541275/2541275 filters 2541275/2541275 wallet 2541275`
  - `05:24:52 WalletBalanceFacts: total=0 ... confirmed=0 unconfirmed=0 txCount=0`
  - chainlock then tracks the tip live (2541275 -> 2541276 -> 2541277).
- Assertions: balance expected 0 / actual `0` and `$ 0` (`M1/15-home-synced.png`); tx list expected empty /
  actual empty; engine restarts expected 0 / actual 0; `starting peergroup` expected 0 / actual 0.
- Memory (`evidence/S6/mem.csv`): peak TOTAL PSS 454,639 kB, Native Heap 322,864 kB, Dalvik 32,010 kB
  @00:24:37; settles ~350 MB PSS / ~217 MB native. `exit-info` empty (`M1/exitinfo.txt`).
- Screenshots: `/Users/dcg/workspace/dash-wallet-qa/evidence/S6/M1/01-first-launch.png` ...
  `.../M1/15-home-synced.png` (plus `sync-*.png` samples).
- Verdict **PASS**. Onboarding has no mainnet-specific screen and no testnet chrome, correct for prod.
- Oddity: the home header never rendered a sync-progress pane during M1 (sync finished in 42 s).

### M2 - restore the BIP39 test-vector seed
- Steps: 00:31:29 More > Security > Reset Wallet (confirmed) -> onboarding;
  00:32:36 Restore wallet with `abandon abandon ... about`, no creation date (full rescan), PIN 1234.
- Reset evidence: `05:31:31 WalletApplication - Removing all the data and restarting the app.` and
  `05:31:33 L1 shadow hard reset: deleted SPV dataDir .../l1_shadow_spv/mainnet (17 files)`.
- Sync landmarks: `05:32:38 CUT_OVER` -> `05:33:19 L1 shadow SPV started` -> `05:33:50 HEADERS 40.3%` ->
  `05:34:20 FILTER_HEADERS 56.9%` -> `05:35:20 FILTERS 74.9%` -> `05:38:21 phase=SYNCED 100.0%
  headers 2541279/2541279 filters 2541279/2541279` + `WalletBalanceFacts: total=0 ... txCount=4`.
  Wall clock: 5 min 45 s.
- Assertions (expected -> actual):
  - balance `0.00` -> `0` / `$ 0` (`M2/14-SYNCED-home.png`) PASS
  - 4 historical appearances -> shown: `15 December 2023  Sent -0.00122 12:45 PM / Received +0.00122 12:34 PM`
    and `08 June 2018  Sent -0.01 12:32 PM / Received +0.01 5:15 AM`; sum received 0.01122, sum sent 0.01122 PASS
  - address present -> `M2/17-txdetail-sent-2018.png` shows
    `Sent from XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5` / `Sent to XfVzg3PPJ11qqmHxWvKLQ5CAi12DhksZGi` PASS
  - explorer cross-check (`curl -A Mozilla https://insight.dash.org/insight-api/addr/XoJA8qE3...`, 00:27 host):
    `balance 0, totalReceived 0.01122, totalSent 0.01122, txApperances 4`, txids
    `359445e0...c485` (h1988337), `77dc9192...b3f7` (h1988331), `f3269c40...319b` (h883654), `6d498818...38d8` (h883492).
    Block times map to 2023-12-15 and 2018-06-08 - the dates the app shows. PASS
- Watchdogs: no `filter-stall`, no `idling detected` during replay, no `OutOfMemory`, no `FATAL`,
  no `OverlappingFileLockException`, no engine restart, zero `starting peergroup`. `exit-info` empty.
- Memory: peak TOTAL PSS **1,018,245 kB (995 MB)** and Native Heap **866,932 kB (847 MB)** @00:37:43;
  `ReplayMemTelemetry` reports `nativeHeapSize=1,181,822,976` (1.18 GB). Post-sync it settles at
  ~690 MB PSS / ~540 MB native and does not return to the fresh-wallet ~350 MB.
- Verdict **PASS** on correctness; see defect S6-D1 for the memory profile.

### M3 - mainnet upgrade path (master 11.9.0 prod -> fix 12.0.0 prod)
- 00:42:14 uninstall fix - 00:42:18 install master prod - 00:43:11 restore the same seed, PIN 1234 -
  00:44:53 home shows `Syncing balance` / `Syncing 35%`.
- Master baseline over 20 min (`M3/master-samples.txt`, `M3/master-sync-*.png`):
  real dashj peer group on mainnet (`Peer{...subVer=/Dash Core:23.1.8/, height=2541281}`), ~1000-1500 blocks/s,
  chain height 239040 -> 1216108 of 2541289 (`Syncing 64%` at 01:05, `M3/07-master-after-20min.png`).
  Master memory at the 20-min mark: **TOTAL PSS 187,876 kB / Native Heap 44,692 kB / Dalvik 47,437 kB**.
- 01:06:45 `am force-stop` - 01:06:48 `adb install -r fix-12.0.0-prod-release-signed.apk` (same key, data kept,
  versionCode 12000000) - 01:06:56 launch, recorded in `M3/upgrade-launch.mp4`.
- A3 assertions (expected -> actual):

| assertion | actual |
|---|---|
| `cutover state ... -> CUT_OVER` on this launch | `06:06:57 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)` PASS |
| exactly one `L1 shadow SPV started` | `06:07:00 ...`, one occurrence PASS |
| no `starting peergroup` post-cutover | only occurrence in the whole log is `05:43:52` during the master run (also present in the pre-upgrade pull `M3/master-walletlog/files/log/wallet.log:305`) PASS |
| explainer shown once | `06:06:57 upgrade cutover: one-time sync explainer armed (upgraded-wallet launch)`; sheet "A one-time sync is needed" with inline `Syncing 58%` and one `Got it` (`M3/10-explainer.png`); not shown again after relaunch PASS |
| no `OverlappingFileLockException` | none PASS |
| no `idling detected` while replaying | first occurrence `06:16:00`, after SYNCED PASS |
| sync reaches 100 % | `06:12:09 L1Shadow phase=SYNCED 100.0% headers 2541295/2541295 filters 2541295/2541295` + `SETTLED` - 5 min 13 s after launch PASS |
| balance 0 | `WalletBalanceFacts: total=0 ... txCount=4`, UI `0` / `$ 0` PASS |
| 4 tx appearances visible | `M3/12-SYNCED-home.png` PASS |
| memory bounded | peak 998,095 kB PSS / 918,084 kB native @01:10:59, then ~584 MB PSS after relaunch - bounded, but see S6-D1 |
| `exitinfo` clean | `M3/exitinfo.txt`: only my two `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` entries; no LMK, no OOM PASS |

- Kill + relaunch (01:16:34 force-stop -> relaunch, `M3/relaunch-after-upgrade.mp4`):
  `06:16:47 L1 shadow SPV started` (once), `06:16:53 phase=SYNCED 100.0%` immediately - resumed from the
  watermark with no re-scan; no second explainer; balance 0, `txCount=4`, 4 rows (`M3/14-relaunch-home.png`).
- Note: the upgrade replay re-scans the whole chain from height 0 - the 1.2 M blocks dashj had already
  downloaded are not reused. Consistent with the explainer's "one-time full sync" wording.
- Verdict **PASS**.

### M4 - mainnet UI sanity on the fix prod build
All screens opened without a crash; see `notes.md` for the per-screen table and
`/Users/dcg/workspace/dash-wallet-qa/evidence/S6/M4/` for the screenshots.
Key checks: Receive shows `XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5` (mainnet `X` prefix) PASS;
Send rejects the testnet address `yRd4FhXfVGHXpsuZXPNkMrfD9GVj46pnjt` with
"Not a valid DASH Address or URL request" and refuses to continue PASS
(`wallet.log`: `PaymentIntentParserException: java.lang.IllegalArgumentException: yRd4FhXfVGHXpsuZXPNkMrfD9GVj46pnjt`);
Tools contains `Network monitor` and the `dashj sync (diagnostic)` toggle, **OFF and not touched** PASS;
Network monitor reports `Synced / Connected to the Dash network`, headers 2,541,297, filters 2,541,297,
masternode list 2,541,295, ChainLock 2,541,295 PASS; About reports Dash Kotlin SDK `0.1.0-v42int19-SNAPSHOT`
and Platform `4.0.1-SNAPSHOT` PASS.

## Memory summary (`/Users/dcg/workspace/dash-wallet-qa/evidence/S6/mem.csv`, 132 samples @30 s)

| Phase | peak TOTAL PSS | peak Native Heap | peak Dalvik Heap | at |
|---|---|---|---|---|
| M1 fresh wallet (fix) | 454,639 kB | 322,864 kB | 32,010 kB | 00:24:37 |
| M2 full restore (fix) | **1,018,245 kB** | **866,932 kB** | 26,888 kB | 00:37:43 |
| M3a master 11.9.0 dashj | 211,462 kB | 44,700 kB | 71,353 kB | 00:49:18 |
| M3b upgrade replay (fix) | 998,095 kB | 918,084 kB | 48,721 kB | 01:10:59 |
| M3c post-relaunch idle (fix) | 643,494 kB | 533,112 kB | 34,993 kB | 01:21:04 |

No LMK kill, no `OutOfMemoryError`, no `FATAL EXCEPTION` in either logcat segment
(`logcat-part1.txt`, `logcat.txt`) or in any `wallet.log` pull.

## Defects found

| ID | Severity | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| S6-D1 | S2 | Mainnet SDK replay uses ~1 GB PSS / ~850-920 MB native, ~4.7x master, and does not fall back afterwards | Restore any seed on mainnet with no creation date (M2) or upgrade from 11.9.0 (M3); sample `dumpsys meminfo` every 30 s | `evidence/S6/mem.csv` (peaks 1,018,245 kB @00:37:43 and 998,095 kB @01:10:59 vs master 211,462 kB @00:49:18); `wallet.log` `06:12:09 ReplayMemTelemetry ... nativeHeapSize=1168384000`; `M3/exitinfo.txt` records `rss=1.1GB` at force-stop for fix vs `rss=319MB` for master | L1 shadow SPV filter replay (`service/platform/sdk`, `L1ShadowSyncService` / `ReplayMemTelemetry`) |
| S6-D2 | S3 | Idle steady-state footprint stays at ~590-690 MB PSS / ~430-540 MB native after sync, never returning to the fresh-wallet ~350 MB | Complete M2 or M3, leave the app idle at 100 %, sample meminfo | `evidence/S6/mem.csv` rows 01:17-01:25 (final sample: TOTAL PSS 593,259 kB, Native Heap 430,056 kB for a 0-balance, 4-tx wallet) | same as S6-D1 (header/filter stores kept resident) |
| S6-D3 | S3 | Receive screen offers an address the wallet knows already has 4 on-chain appearances | After M2/M3 sync completes, Home > Receive | `M4/02-receive.png` shows `XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5`, the same address whose history the app lists in `M2/14-SYNCED-home.png` and `M2/17-txdetail-sent-2018.png` | post-cutover receive-address issuance on the SDK seam. **Not compared against master** (the master baseline run never opened Receive) |
| S6-D4 | S3 | Tx detail for a received tx shows no counter-party address and no fee row; sent txs show addresses but still no fee row | M2 > tap any history row | `M2/15-txdetail-received-2018.png`, `M2/16-txdetail-scrolled.png` (Amount / Date / Tax Category / Private Note / View in Block Explorer only) vs `M2/17-txdetail-sent-2018.png` (adds "Sent from"/"Sent to", no "network fee"). S2's testnet run did show a `network fee` row on a sent tx, so the row is not unconditionally absent | tx-detail data seam |
| S6-D5 | S4 | About shows `App version 12.0.0 (0)` although the installed versionCode is 12000000 | More > Settings > About Dash | `M4/10-about.png`; `dumpsys package` reports `versionCode=12000000` | About screen version-string formatting |
| S6-D6 | S4 | Historical send amounts changed meaning between master and fix: master lists the 2018 send as `0.0099` (payment), fix lists `0.01` (payment + 0.0001 fee) | Restore the same seed on 11.9.0 and on 12.0.0, compare the 08 June 2018 "Sent" row | master `M3/07-master-after-20min.png` (`-0.0099`) vs fix `M3/12-SYNCED-home.png` and `M2/14-SYNCED-home.png` (`-0.01`); insight tx `f3269c40...319b`: valueIn 0.01, valueOut 0.0099, fees 0.0001, no change output | tx-list amount computation on the SDK seam. Balance is unaffected and correct in both builds |
| S6-D7 | S4 | `BlockchainServiceImpl - idling detected, stopping service` logged once a minute indefinitely after sync, with no matching restart | Reach 100 % and leave the app idle | `grep 'idling detected'` -> 6 occurrences (05:27:00, 05:28:00, 06:16:00, ...) in `M3/fix-walletlog/files/log/wallet.log`. Independently reported by stream S2 on testnet | `BlockchainServiceImpl` idle/stop tick |

### Explicitly NOT a regression
The app auto-locks to the Enter-PIN screen after ~40-90 s while it is in the **foreground** (S2 reports the
same on testnet). I reproduced it on the **master 11.9.0 prod** build on the same device in the same session:
`wallet.log 05:44:43 WalletActivityTracker ... foreground: 1` followed by `05:45:32 LockScreenActivity -
LockState = ENTER_PIN` with no intervening background transition
(`M3/master-walletlog/files/log/wallet.log`). Pre-existing, not introduced by this branch.

## Environment problems (not product defects)
- `qa-app.sh launch` (which uses `monkey`) does not start this build; every launch here used
  `adb shell am start -n hashengineering.darkcoin.wallet/de.schildbach.wallet.ui.OnboardingActivity`.
- `adb shell input text` splits on spaces; seed phrases must be typed with `%s` separators.
- The `adb root` performed by `wallet-log`/`grep-log`/`pull-logs` restarts adbd and kills a running
  `adb logcat`. The first logcat capture died at 00:25:41 for that reason; it is preserved as
  `evidence/S6/logcat-part1.txt` and a second capture (`evidence/S6/logcat.txt`) covers 01:05 onwards.
  `mem.csv` is unaffected (it re-invokes adb per sample) and the app's own `wallet.log` is complete.
- Firebase is a stub: `FirebaseException ... API key not valid` and `Firebase cloud messaging token: Not available`
  are expected. Buy & Sell shows the expected "Keys are missing for these services" banner.

## Not run / blocked
- Nothing from the S6 assignment was blocked. No send, purchase, username creation or dashj-toggle action
  was attempted, per the no-funds constraint.
- The `dashj sync (diagnostic)` toggle was confirmed present and OFF but deliberately not switched on.
