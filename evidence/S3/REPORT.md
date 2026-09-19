# QA report: S3 — A3 / A3b (upgrade master 11.9.0 -> fix 12.0.0)   (agent: Opus S3, emulator: emulator-5558 / dw-qa3, 2026-09-19)

Builds: `master-11.9.0-testnet3-release-signed.apk` versionCode **11090002** -> `fix-12.0.0-testnet3-release-signed.apk` versionCode **12000000** (same QA key, `adb install -r` = true in-place upgrade; `dumpsys package` confirmed 12000000 / minSdk 29).
Wallet: reference seed `[seed phrase redacted]`, app PIN 1234. READ-ONLY — nothing sent, shielded, or registered.

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| A3.1 Install master, restore seed, onboarding | PASS | `S3/A3/01-master-sync/01..09-home-t0.png` | Restore + PIN + permissions clean on 11.9.0. |
| A3.2 dashj sync window (30-min floor; >=50% from the start) | PASS | `S3/A3/01-master-sync/poll.log`, `poll-01..05-*.png` | 55%->100% (height 1556420/1556563) in ~26 min; PSS 190-224 MB, native 37-41 MB. |
| A3.2b master Tools/About captured for comparison | PASS | `01-master-sync/10..13-master-*.png` | DashJ 22.0.5-SNAPSHOT; no dashj toggle in Tools. |
| A3.3 Pre-upgrade snapshot + `last_version` | PASS | `S3/A3/02-pre-upgrade/01-home-pre-upgrade.png`, `.../files/log/wallet.log` | `last_version=11090002` (< 12000000). Balance 107.081735. |
| A3.4 In-place upgrade to 12000000 | PASS | `S3/A3/03-upgrade-launch/a3-upgrade-launch-1.mp4`, `-2.mp4` | `install -r` succeeded, data preserved, version 12000000. |
| A3.5 Cutover assertions on the upgrade launch | **PASS** | `03-upgrade-launch/grep-cutover-state.txt`, `grep-l1-shadow-started.txt`, `grep-starting-peergroup-ONLY-PRE-UPGRADE.txt`, `grep-explainer.txt`, `03-after-unlock.png` | One `DUAL_RUNNING -> CUT_OVER`, one `L1 shadow SPV started`, zero post-cutover `starting peergroup`, zero `OverlappingFileLockException`, zero `idling detected` during replay, explainer armed+shown exactly once, balance held at last known. |
| A3.6 Replay to 100%, balance, tx list, memory | PASS (balance note) | `S3/A3/04-replay/`, `05-post-sync/00-home-100pct.png`, `txlist-01..12.png`, `S3/mem.csv` | 100% in ~4 min 27 s; balance 107.08173522 (see balance note); PSS peak 620 MB / native 463 MB; no LMK/OOM. |
| A3.7 Kill + relaunch -> SETTLED, no 2nd explainer, balance | **PARTIAL FAIL** | `S3/A3/06-restart/dashpay-datastore-strings.txt`, `grep-cutover-state.txt`, `02-relaunch-home.png` | No 2nd explainer, balance unchanged — but state stays `CUT_OVER`, never `SETTLED` (D-054). |
| A3.7b Background 10 min -> foreground | PASS | `06-restart/grep-background-10min.txt`, `04-after-10min-bg-fg.png` | One clean post-replay `idling detected, stopping service`; memory fell to 271 MB PSS; balance unchanged. |
| A3b Locked upgrade: classification + notification + no engine start | PASS | `S3/A3b/grep-bind-locked.txt`, `08-shade-on-lockscreen.png`, `a3b-locked-upgrade.mp4` | `SDK bind pending: DEVICE_LOCKED`, lock-screen notification shown, zero engine starts while locked. |
| A3b Bind heals within 5 s of unlock | PASS | `S3/A3b/grep-unlock-bind.txt`, `a3b-unlock.mp4` | `ACTION_USER_PRESENT` 06:28:34 -> bind established 06:28:37 = **3 s**. |
| A3b Engine start after unlock -> sync to 100% | **FAIL** | `S3/A3b/grep-engine-never-started.txt`, `15-home.png`, `grep-probe3-recovery.txt` | Engine never re-kicked after the deferred bind heals; replay wedged at 0% for 16 min until a manual force-stop+relaunch (D-056). |
| A3b After forced restart: 100% + balance | PASS | `S3/A3b/grep-a3b-complete.txt`, `16-a3b-final.png` | `phase=SYNCED 100.0% 1556593/1556593`, balance 107.081735 (== A3). |
| A3.9 Tools / About comparison master vs fix | PASS | `S3/A3/07-tools-about/02b-fix-tools-dashj-toggle.png`, `04-fix-about.png` vs `01-master-sync/11,13-master-*.png` | About L1 row flips DashJ -> "Dash Kotlin SDK 0.1.0-v42int19-SNAPSHOT"; Tools gains the dashj-sync diagnostic toggle (OFF). |
| Baseline check 1 (orchestrator): Forgot-PIN back-nav on MASTER | PASS (master safe) | `S3/baseline/m1-01..07-*.png` | Master always returns to the PIN lock screen => the fix-build bypass S4 found is a **regression**. |
| Baseline check 2 (orchestrator): Reset-wallet PIN prompt on MASTER | n/a (master also unprotected) | `S3/baseline/m2-01..04-*.png` | Master wipes with **no PIN prompt either** => the fix-build S1 is **pre-existing**, not a regression. |

## Per-test detail

### A3 — upgrade master 11.9.0 -> fix 12.0.0

Wall clock (host):
- 00:10 clean device, install master 11090002; 00:13 seed restored, PIN set, home reached (header already "Syncing 55%").
- 00:14->00:39:44 dashj: 55 -> 60 -> 68 -> 79 -> 89 -> 99 -> 100 % (`chain/common height 1556420/1556563`), then masternode-list phase. ~26 min to tip.
- 00:43:36 pre-upgrade sample; 00:43:41 `kill`; 00:43:43 `adb install -r` fix APK; version 12000000.
- 00:43:52 `screenrecord` started; 00:43:57 `launch`.
- 00:48:10 explainer visible; 00:49:00 replay complete; 00:52:58 kill; 00:53:03 relaunch; 00:54:49->01:05:28 background 10 min.

Assertions (quoted from the live `wallet.log`; the `05:xx` prefix is the log's own clock, host time = prefix - 5 h):

| Assertion | Expected | Actual | Verdict |
|---|---|---|---|
| cutover transition on the upgrade launch | `DUAL_RUNNING -> ... -> CUT_OVER` | `05:43:59 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)` — exactly one | PASS |
| `L1 shadow SPV started` | exactly 1 | 1, at `05:44:04 ... for SDK wallet b7118ed5... (dataDir=.../l1_shadow_spv/testnet)` | PASS |
| dashj `starting peergroup` after cutover | 0 | only `05:42:24` (master, ~95 s BEFORE the upgrade). Counter-evidence repeats on every `check()`: `BlockchainServiceImpl - cutover committed — holding the dashj L1 engine; SDK owns L1 this launch` | PASS |
| `OverlappingFileLockException` | 0 | 0 | PASS |
| `idling detected` during the replay | 0 | 0 (the guard logged `idle counters, but a replay is in progress (...%) — keeping the service alive`) | PASS |
| one-time explainer | armed + shown once | `05:43:59 upgrade cutover: one-time sync explainer armed (upgraded-wallet launch)`; sheet on screen with live "Syncing 99%" | PASS |
| balance during the replay | last known, not a wrong number | `107.081735` under a "Syncing balance" header — identical to the master pre-upgrade value; `CutoverUiDataService ... lastKnown=10708173522` | PASS |
| `filter-stall watchdog` / engine restarts | 0 | 0 | PASS |
| `OutOfMemory` / `FATAL` in wallet.log | 0 | 0 | PASS |

Replay metrics: first height change `synced_height_persisted=Some(1999)` at 00:44:14 = **17 s** after launch; tip `Some(1556568)` at 00:48:23 = **4 min 27 s**; `replay complete — releasing the wake lock` at 05:49:00 = **~5 min 3 s**. SDK balance converged to `10708173522 duffs` at 05:46:23.

Memory (`S3/mem.csv`, 30 s cadence): session peak **TOTAL PSS 635,726 KB (~621 MB)**, **Native Heap 492,576 KB (~481 MB)**; during the A3 replay window peak PSS 619,637 KB / native 463,492 KB at 00:47:55. Master baseline on the same wallet was PSS 190-224 MB / native 37-41 MB — roughly **3x PSS and 11x native heap**. Settles to ~480 MB PSS / ~320 MB native after the replay, and **271 MB PSS / 106 MB native** when idle in the background. `dumpsys activity exit-info` shows only `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` — my own kill. No LMK, no OOM kill.

Tx list after 100%: populated and scrollable across 12 pages (`05-post-sync/txlist-01..12.png`) — Sent/Received/Internal/CoinJoin "Mixing Transactions" groups, DashPay contact rows ("Asd15augiossh"), fiat values resolved.

### A3b — locked-device upgrade

- master reinstalled, seed restored 01:10:40, synced 15 min to **85 %** (`06:25:54 ... progress 85`) — a genuine mid-sync upgrade.
- 01:26 `setpin 1234`, `kill`, `lock`. Device provably locked at service start: `dumpsys trust` -> `deviceLocked=1, strongAuthRequired=0x1`, `mCurrentFocus=Window{... NotificationShade}`.
- 01:26:42 `adb install -r` fix APK; 01:26:54 `am start-foreground-service -n .../de.schildbach.wallet.service.BlockchainServiceImpl`.
- Classification exactly right: `SdkBindDeferredWhileLockedException: SDK bind deferred: the device is locked, so the lock-bound master alias would be denied` -> `SDK bind pending: DEVICE_LOCKED (... device provably locked=true ...)`, plus `unlock-heal receiver registered (ACTION_USER_PRESENT, exported — SystemUI is the sender)`.
- Lock-screen notification: **"Unlock your phone to finish the wallet update / Tap here once your phone is unlocked and the update will finish setting up. Your funds are safe, and your balance stays at its last known amount until then."**
- No engine start while locked: `L1 shadow SPV started` = 0, `L1 shadow sync not started: app wallet not bound to the SDK yet`, `starting peergroup` only at `06:09:55` (master, pre-upgrade).
- Unlock 01:28:30 -> `06:28:34 device unlocked (ACTION_USER_PRESENT) — running an immediate SDK bind retry` -> `06:28:37 SDK wallet bind established after 6 failed pass(es)` -> `SDK bind established — clearing the pending state (DEVICE_LOCKED)`. **3 s**, within the 5 s target. Pending notification cleared.
- Then D-056: the replay never started until a manual force-stop + relaunch at 01:44:35. After that: `06:48:03 L1Shadow phase=SYNCED 100.0% headers 1556593/1556593 filters 1556593/1556593 wallet 1556593`, `06:49:00 replay complete`, balance **107.081735** — identical to A3. Whole-run counts: SPV starts 1, peergroup 1 (master only), explainer 1, file-lock 0, watchdog 0, OOM/FATAL 0. `exit-info`: `reason=10 FORCE STOP` + `reason=16 PACKAGE UPDATED` only.

### A3.9 Tools / About: master vs fix

| | master 11.9.0 | fix 12.0.0 |
|---|---|---|
| About — App version | `11.9.0 (2) - testnet` | `12.0.0 (0) - testnet` |
| About — L1 engine row | **DashJ** `22.0.5-SNAPSHOT` | **Dash Kotlin SDK** `0.1.0-v42int19-SNAPSHOT` |
| About — Platform | `4.0.1-SNAPSHOT` | `4.0.1-SNAPSHOT` (unchanged) |
| Tools | Address book, Import private key, Network monitor, Extended public key (BIP44), Masternode keys, CSV export, **Connections**, Credits/Buy, ZenLedger | same minus **Connections**, plus **"dashj sync (diagnostic)"** toggle, OFF by default ("Run the legacy dashj engine alongside the SDK to compare") |
| More | no balance header, no Invitations | balance header "Dash Wallet 107.081 D / Shielded 0.000 D", adds **Invitations** and **Username Voting** |
| Settings | ..., **CoinJoin (Turned off)**, ... | same list **without** the CoinJoin row |

The About label flip confirms `state.sdkOwnsL1 == true` post-cutover (`AboutFragment.kt:87-96`).

## Defects found

| ID | Sev | Title | Repro | Evidence | Suspected area |
|---|---|---|---|---|---|
| D-056 | **S1** | After a locked-device upgrade the SDK L1 engine never starts; replay wedged at 0% until the user force-stops the app | master 11.9.0 with a synced wallet -> set device PIN -> lock screen -> `adb install -r` fix APK -> `am start-foreground-service ...BlockchainServiceImpl` while locked -> unlock. Bind heals in 3 s but the replay stays at 0%. | `S3/A3b/grep-engine-never-started.txt`, `grep-unlock-bind.txt`, `15-home.png`, `grep-probe3-recovery.txt` | `PlatformSyncService.kickSdkEngines` / `SdkBindRetryService.onBindEstablished` |
| D-054 | S3 | `CutoverState.SETTLED` is unreachable — state stays `CUT_OVER` forever | Complete an upgrade cutover, reach 100%, kill + relaunch, read `files/datastore/dashpay.preferences_pb`. | `S3/A3/06-restart/dashpay-datastore-strings.txt` (`cutover_state` -> `CUT_OVER`), `06-restart/grep-cutover-state.txt` (only one transition ever logged) | `CutoverStateMachine.kt:107,139` / `CutoverCoordinator` |
| D-055 | S3 | SDK replay costs ~3x PSS and ~11x native heap vs dashj on the same wallet | Compare `S3/mem.csv` master window (00:14-00:43) against the fix replay window (00:44-00:49). | `S3/mem.csv`: master 190-224 MB PSS / 37-41 MB native vs fix peak 620-636 MB PSS / 463-493 MB native | L1 shadow SPV native engine |
| D-057 | S4 | About shows "12.0.0 **(0)**" | Open More > Settings > About Dash on the fix build. | `S3/A3/07-tools-about/04-fix-about.png` | `AboutFragment.kt` — build number is `VERSION_CODE % 100`, and `12000000 % 100 == 0` |
| D-058 | S4 | Inactivity notification quotes a stale partial balance | Upgrade with a partially-synced wallet; "You've still got Dash on this device!" said "balance of DASH 6.93208425" while the wallet holds 107.08. | `S3/A3b/08-shade-on-lockscreen.png`; `06:26:47 BootstrapReceiver - detected balance, showing inactivity notification` | `BootstrapReceiver` |

### D-056 detail (the S1)

1. `06:26:47` process starts while the device is locked; `PlatformSyncService` kicks the bind.
2. `06:26:48` breadcrumb `21 SDK_L1_ENGINE_STARTING` -> `L1ShadowSyncService.startIfEnabled()` runs and returns **false**: `L1 shadow sync not started: app wallet not bound to the SDK yet`. Breadcrumb `22 SDK_L1_ENGINE_STARTED` is marked anyway — it records the call, not the outcome, so the trail looks healthy.
3. `06:26:48 ... 06:28:07` bind keeps deferring -> blocker `DEVICE_LOCKED` (correct).
4. `06:28:34` unlock -> `06:28:37` bind established (correct).
5. **Nothing re-kicks the engine.** In `wt-fix @616ac58ff` the only production callers of `l1ShadowSyncService.startIfEnabled()` are `PlatformSyncService.kickSdkEngines` (line 462, reached from `BlockchainServiceImpl.resume()` on a *foreground-service start*), the filter-stall watchdog (`L1ShadowSyncService.kt:2795`, which requires an already-running engine) and the post-wallet-re-creation restart (`:3259`). Neither `SdkBindRetryService.onBindEstablished()` nor `SdkWalletBinder` re-kicks it.
6. Observed for **16 min 10 s** (bind 06:28:37 -> engine start 06:44:47): `grep -c 'L1 shadow SPV started'` = 0, `grep -c 'synced_height_persisted=Some'` = 0, and every minute `BlockchainServiceImpl - idle counters, but a replay is in progress (0%) — keeping the service alive until it completes`. The foreground service is pinned alive by the replay guard while nothing replays.

Recovery probes (orchestrator-requested; 2 min wait + `grep -c 'L1 shadow SPV started'` each):

| # | Action | Result | Recovered |
|---|---|---|---|
| 1 | `bg` then `fg` (foreground visit; bind retry does fire) | 0 starts, 0 heights | **NO** |
| 2 | airplane `net off` 20 s / `net on` | 0 starts, 0 heights | **NO** |
| 3 | `kill` + `launch` (fresh process -> `resume()` -> `kickSdkEngines`) | **1** start at `06:44:47`; 220 height events in 30 s, height 363000 in 60 s, 100% at `06:48:03` | **YES** |

User cost: sync only starts after the user force-stops and relaunches the app. The UI gives no hint — it shows "Syncing..." at 0% with a stale balance (6.932082 here) — so a real user has no reason to try a restart and would see a permanently stuck wallet after an overnight/locked update.

## Orchestrator-requested master baseline checks

1. **Lock-screen bypass via Forgot PIN — MASTER IS SAFE.** With master auto-locked: "Forgot PIN?" -> "Enter recovery phrase" -> BACK x3 returns to the **Enter PIN** lock screen every time, and a fresh `launch` also lands on the lock screen. The unlocked home is never reachable without the PIN. => S4's finding on fix 12.0.0 is a **regression**. Evidence `S3/baseline/m1-01..07-*.png`.
2. **Reset wallet without a PIN — MASTER IS ALSO UNPROTECTED.** More > Security > "Reset Wallet" -> single confirmation dialog ("Are you sure you want to reset the wallet?") -> "Reset wallet" -> wallet wiped immediately, app lands on onboarding. The PIN is never requested; master has no "Save data and reset wallet" step at all. => the fix-build S1 is **pre-existing in 11.9.0**, not a regression (still a real exposure; should be reclassified). Evidence `S3/baseline/m2-01..04-*.png`.

## Balance note (not a fix-build defect)

The brief's expected reference balance is **107.43173749**. Both builds independently report **107.08173522** (`10708173522` duffs):
- master 11.9.0 / dashj: `S3/A3/02-pre-upgrade/01-home-pre-upgrade.png`
- fix 12.0.0 / SDK: `S3/A3/05-post-sync/00-home-100pct.png`, `S3/A3b/16-a3b-final.png`, and `CutoverUiDataService - SDK balance published: 10708173522 duffs`

Delta = **0.35000227**, exactly the newest transaction both builds list ("Sent - 0.350002", 05 September). Two independent engines agreeing means the brief's number pre-dates that send. Recommend updating the expected reference balance to 107.08173522 (or re-deriving it from the explorer).

## Environment problems (not product defects)

- `qa-app.sh logcat-start` used `nohup A logcat` where `A` is a shell function -> `nohup: A: No such file or directory`, so logcat was not captured 00:10-00:20. Re-run with the orchestrator's fixed helper at 00:21; the ring-buffer snapshot `S3/logcat-early.txt` (33,892 lines) back-fills the master install/restore window, and `S3/logcat-manual-0020.txt` holds the interim manual capture.
- `logcat -b crash` contains two `FATAL EXCEPTION` entries (00:44:58, 00:47:12), both `com.android.commands.uiautomator` — "UiAutomationService ... already registered", caused by my own concurrent `uiautomator dump` calls. Not the app. `S3/A3/04-replay/crash-buffer-uiautomator-only.txt`.
- `adb shell input text "a b c"` splits on spaces; seed entry needs `%s` separators. Under the replay's CPU load `input tap` also drops events — the upgrade-launch PIN took three attempts (one "Wrong PIN! 7 attempts remaining"). The app never ANR'd, but input responsiveness during the replay is visibly degraded. `S3/A3/03-upgrade-launch/pin-stuck-004649.png`, `after-pin-2.png`, `after-pin-3.png`.
- The master-sync poll loop's auto-unlock tapped digits while the launcher had focus for polls 02-05, so those poll screenshots show the launcher rather than the app. The `wallet.log`-derived numbers in `poll.log` are unaffected.

## Not run / blocked

- Step 2 asked for a 60-minute dashj window "or until >= 50%, whichever is first, but not less than 30 minutes". The header percentage was already 55% at t=0, so the binding constraint was the 30-minute floor and I upgraded at t~30 min. By then dashj had reached the tip (~26 min on this emulator), so **A3 is an upgrade from a fully-synced master, not mid-sync**. A3b covers the mid-sync case properly (upgraded at 85%).
- E8 (fresh small v11.9 wallet upgrade) was not part of this stream's instructions and was not run.
