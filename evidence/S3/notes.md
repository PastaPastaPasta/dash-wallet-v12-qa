# S3 notes — A3 upgrade master 11.9.0 -> fix 12.0.0 (emulator-5558 / dw-qa3)

- 2026-09-19T00:10:34 Start. App not installed (clean). Android 15, 1080x2400.
- 2026-09-19T00:13:53 T0: master 11.9.0 restored (seed OK, PIN 1234), home reached. Header sync shows 'Syncing 55%'. Starting 60-min dashj sync window.
- 2026-09-19T00:21 master More/Tools/About captured: 10-master-more.png, 11-master-tools.png, 12-master-settings.png, 13-master-about.png
  - master About: App version "11.9.0 (2) - testnet", DashJ "22.0.5-SNAPSHOT", Platform "4.0.1-SNAPSHOT"
  - master Tools items: Address book, Import private key, Network monitor, Extended public key (BIP44), Masternode keys, CSV export, Connections, Credits, Buy, ZenLedger. NO dashj sync toggle.
  - master More header: "Platform 4, Protocol 11" / "test-platform-4-11"
- NOTE: app auto-locks to PIN screen after a short idle; poll script auto-unlocks with 1234.
- 2026-09-19T00:19 prefs on master: hashengineering.darkcoin.wallet_test_preferences.xml -> last_version=11090002, previous_version=0
- Expected fix log strings (from wt-fix @616ac58ff):
  - CutoverCoordinator.kt:631 "cutover state {} -> {} on {} (ready={})"; :597 "cutover state {} -> {} ({})"
  - CutoverCoordinator.kt:502 "upgrade cutover: one-time sync explainer armed ({})"
  - L1ShadowSyncService.kt:2295 "L1 shadow SPV started for SDK wallet {}…"
  - BlockchainServiceImpl.kt:1531 "starting peergroup" (must NOT appear post-cutover)
  - BlockchainServiceImpl.kt:2008 "idling detected, stopping service"
  - L1ShadowSyncService.kt:2785/2798 "L1Shadow filter-stall watchdog: ..."
  - SdkBindRetryService.kt:286 "SDK bind pending: {} (... device provably locked={} ...)"; :437 "device unlocked (ACTION_USER_PRESENT) — running an immediate SDK bind retry"; :250 "SDK bind established — clearing the pending state"
  - Explainer dialog text: "A one-time sync is needed" / "Got it"
- 2026-09-19T00:20 ENV ISSUE: qa-app.sh `logcat-start` used `nohup A logcat` where A is a shell function -> "nohup: A: No such file or directory"; logcat was NOT being captured from 00:10. Restarted manually at 00:20 with a subshell; the ring buffer back-fill covers the master install window. (Another agent has since patched qa-app.sh the same way.)
- 2026-09-19T00:19:42 dashj progress=64, chain height 325751/1556556
- 2026-09-19T00:21 logcat re-started with the fixed helper -> $QA_EVIDENCE/S3/logcat.txt ; ring buffer snapshot -> logcat-early.txt (33892 lines, covers the master install/restore window); earlier manual capture kept as logcat-manual-0020.txt
- Additional expected fix line (positive assertion that dashj is held): BlockchainServiceImpl.kt:1510 "cutover committed — holding the dashj L1 engine; SDK owns L1 this launch"
- Step 9 expectation (from AboutFragment.kt:87-96): post-cutover the About L1-engine row label flips from "DashJ"/DASHJ_VERSION to about_kotlin_sdk_label/DASH_SDK_VERSION when state.sdkOwnsL1. Tools gains a "dashj sync (diagnostic)" row (ToolsViewModel.DashjDiagnosticUIState) that master does not have.

## Step 2 result (master dashj sync, T0=00:13:xx)
- dashj chain download: 55% @00:14 -> 60% @00:17 -> 68% @00:22 -> 79% @00:27 -> 89% @00:32 -> 99% @00:37 -> 100% (height 1556420/1556563) @00:39:44. Total ~26 min to tip on this emulator.
- Post-chain it moved on to Masternode Lists (progress re-reported 35% then back to 99/100).
- Master memory (poll.log): TOTAL PSS 190-224 MB, Native Heap 37-41 MB, Dalvik Heap 44-81 MB. No FATAL/OOM.
- Poll evidence: evidence/S3/A3/01-master-sync/poll.log + poll-01..05 screenshots.
- ENV NOTE: the poll's auto-unlock tapped digits while the launcher was focused for polls 02-05, so those poll screenshots/UI dumps show the launcher, not the app. The wallet.log numbers in poll.log are unaffected.

## Step 3 pre-upgrade snapshot (00:43)
- Home screen: evidence/S3/A3/02-pre-upgrade/01-home-pre-upgrade.png
- MASTER 11.9.0 BALANCE = 107.081735 tDASH ($6548.78). Expected reference value in the brief = 107.43173749. Delta = 0.35000249, and the newest tx in the list is "Sent −0.35" on 05 September. Flagged for comparison with the fix build.
- Tx list populated (Sent 0.35 / Received 1 / Asd15augiossh −0.0123 / +0.001 ...). No syncing indicator (dashj at tip).
- wallet.log pulled -> evidence/S3/A3/02-pre-upgrade/wallet.log (8.3 MB) + wallet.0.2026-09-19.log.gz
- prefs BEFORE upgrade: last_version=11090002, previous_version=0  (< FIRST_CUTOVER_VERSION_CODE=12000000)

## Step 4-5 UPGRADE (00:43:41 kill, 00:43:43 adb install -r fix APK, 00:43:57 launch)
- version after reinstall: versionCode=12000000 minSdk=29 targetSdk=35, versionName=12.0.0  (in-place, data preserved)
- Screen recording: evidence/S3/A3/03-upgrade-launch/a3-upgrade-launch-1.mp4 (+ -2.mp4)
- Upgrade launch showed the app PIN lock screen first (expected). NOTE (harness): under the replay CPU load, `input tap`/`input text` digits were dropped; it took 3 attempts to enter the PIN (one "Wrong PIN! 7 attempts remaining"). Evidence: 03-upgrade-launch/pin-stuck-004649.png, after-pin-2.png, after-pin-3.png. Product impact: input responsiveness during the replay is degraded but the app never ANR'd.
- ASSERTIONS (all from the live wallet.log; files in 03-upgrade-launch/):
  - cutover state: "05:43:59 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)" — exactly ONE transition. PASS (grep-cutover-state.txt)
  - "L1 shadow SPV started for SDK wallet b7118ed5…" at 05:44:04 — count = 1. PASS (grep-l1-shadow-started.txt)
  - "starting peergroup": ONE occurrence at 05:42:24, i.e. the MASTER build BEFORE the upgrade. None after 05:43:59. PASS (grep-starting-peergroup-ONLY-PRE-UPGRADE.txt). Positive counter-evidence: "cutover committed — holding the dashj L1 engine; SDK owns L1 this launch" repeats on every check() (grep-dashj-held.txt)
  - OverlappingFileLockException: 0 occurrences. PASS
  - "idling detected": 0 occurrences during the replay. PASS
  - explainer: "05:43:59 upgrade cutover: one-time sync explainer armed (upgraded-wallet launch)" — armed once; sheet SHOWN once on screen. PASS (grep-explainer.txt, 03-after-unlock.png / 04-explainer-shown.png)
  - filter-stall watchdog: 0 occurrences. FATAL/OutOfMemory: 0. PASS
- Balance DURING the replay = 107.081735 (identical to the master pre-upgrade value = last known), header label "Syncing balance", explainer progress "Syncing 99%". No wrong/zero number shown. PASS

## Step 6 replay metrics (fix 12.0.0)
- Launch 00:43:57 -> cutover CUT_OVER 00:43:59 -> L1 shadow SPV started 00:44:04.
- Time to FIRST height change: synced_height_persisted=Some(1999) at 00:44:14.137 => ~17 s after launch.
- Time to TIP: synced_height_persisted=Some(1556568) at 00:48:23.753 => ~4 min 27 s after launch.
- "replay complete — releasing the wake lock" (BlockchainServiceImpl) at 05:49:00 log clock => ~5 min 3 s after launch.
- SDK balance converged: CutoverUiDataService "SDK balance published: 10708173522 duffs" at 05:46:23, == lastKnown=10708173522 carried over from master. (grep-replay-progress.txt)
- Engine restarts (filter-stall watchdog): 0.
- Memory peaks during the replay (evidence/S3/mem.csv 00:43:53-00:51): TOTAL PSS peak 619,637 KB (~605 MB) @00:47:55; Native Heap peak 463,492 KB (~453 MB) @00:47:55; Dalvik Heap peak ~75.5 MB. Master baseline for comparison was PSS ~190-224 MB / native ~37-41 MB. Settles to ~480-500 MB PSS / ~315-330 MB native after the replay.
- exit-info: only one entry, reason=10 (USER REQUESTED) subreason=21 (FORCE STOP) at 00:43:41 = my own pre-upgrade `kill`. NO LMK / OOM / crash entries. (04-replay/exitinfo.txt)

## BALANCE FINDING
- Expected per brief: 107.43173749. Observed on BOTH builds: 107.08173522 (10708173522 duffs; UI "107.081735").
- master 11.9.0 (dashj) = 107.081735 (evidence 02-pre-upgrade/01-home-pre-upgrade.png)
- fix 12.0.0 (SDK)      = 107.081735 (evidence 04-replay/02-home-after-explainer.png)
- Delta = 0.35000227 = exactly the newest tx "Sent -0.350002" dated 05 September, which both builds list.
- Two independent engines agree => the brief's expected value looks STALE (pre-dates that send), not a fix-build defect.

## Step 7 kill + relaunch (00:52:58 kill, 00:53:03 launch)
- Relaunch reached home after PIN: balance UNCHANGED 107.081735 (06-restart/02-relaunch-home.png)
- NO second explainer: "explainer" appears exactly once in wallet.log, at 05:43:59 on the upgrade launch (06-restart/grep-explainer.txt). Sheet did not reappear.
- "starting peergroup" count still 1 (pre-upgrade master only) -> dashj not started on the relaunch either.
- "L1 shadow SPV started" count 2 = one per process (upgrade launch + this relaunch). Correct.
- DEFECT: cutover state does NOT reach SETTLED. Persisted datastore `dashpay.preferences_pb` holds cutover_state=CUT_OVER after a full 100% replay + process kill + relaunch (06-restart/dashpay-datastore-strings.txt), and wallet.log has only the single "DUAL_RUNNING -> CUT_OVER" transition. Root cause in source: `CutoverAction.SETTLE` (CutoverStateMachine.kt:107,139) is dispatched ONLY from wallet/test/.../CutoverStateMachineTest.kt — there is no production call site, so SETTLED is unreachable. Consequence: ROLLBACK (CUT_OVER -> DUAL_RUNNING) stays legal forever, i.e. the "migration horizon is final" invariant in the KDoc never takes effect.
- ENV NOTE: `logcat -b crash` contains two FATAL entries at 00:44:58 and 00:47:12 — both are `com.android.commands.uiautomator` ("UiAutomationService ... already registered"), caused by my own concurrent uiautomator dumps. NOT the app. Evidence: 04-replay/crash-buffer-uiautomator-only.txt

## Step 7 (cont) background 10 min + foreground (00:54:49 -> 01:05:28)
- While backgrounded: "05:56:00 BlockchainServiceImpl - idling detected, stopping service" — correct, this is AFTER the replay completed (the replay-suppression rule only applies during a replay). No wakelock/idle loop; single occurrence. (06-restart/grep-background-10min.txt)
- Process stayed alive; memory FELL while idle: TOTAL PSS 271 MB, Native Heap 106 MB (down from ~485/320 MB). No LMK.
- Foregrounded: balance unchanged 107.081735, no explainer, no crash. (06-restart/04-after-10min-bg-fg.png)
- Master baseline had its own "05:38:32 low memory detected, stopping service" while syncing (pre-upgrade) — noted for comparison.

## Step 9 Tools / About comparison (evidence S3/A3/07-tools-about/ and 01-master-sync/11..13)
| | master 11.9.0 | fix 12.0.0 |
|---|---|---|
| About App version | 11.9.0 (2) - testnet | 12.0.0 (0) - testnet |
| About L1 engine row | "DashJ" 22.0.5-SNAPSHOT | "Dash Kotlin SDK" 0.1.0-v42int19-SNAPSHOT |
| About Platform | 4.0.1-SNAPSHOT | 4.0.1-SNAPSHOT (unchanged) |
| Tools rows | Address book, Import private key, Network monitor, Extended public key (BIP44), Masternode keys, CSV export, **Connections**, Credits/Buy, ZenLedger | same minus **Connections**, plus **"dashj sync (diagnostic)"** toggle (OFF by default) "Run the legacy dashj engine alongside the SDK to compare" |
| More menu | (no balance header), no Invitations | balance header "Dash Wallet 107.081 Đ / Shielded 0.000 Đ", adds **Invitations**, **Username Voting** |
| Settings rows | Local currency, Rescan blockchain, About Dash, Notifications, **CoinJoin (Turned off)**, Transaction metadata, Battery optimization | same minus the **CoinJoin** row |
- The About L1-engine label flip confirms sdkOwnsL1 == true post-cutover (AboutFragment.kt:87).
- COSMETIC: "12.0.0 (0)" — build number is VERSION_CODE % 100 and 12000000 % 100 == 0, so it renders "(0)". Reads like a missing value.

## A3b setup (01:08:30 uninstall fix, install master 11.9.0, restore seed, PIN 1234)
- Home reached 01:10:40, dashj syncing from 55%. 15-min sync window -> ~01:26.
- Master does NOT lock on a short background/foreground or on screen-off/on; it locks on an idle timer (observed ~2 min earlier in A3).

## ORCHESTRATOR BASELINE CHECK 1 — lock-screen bypass via Forgot PIN, MASTER 11.9.0 (01:16-01:19)
Steps: app auto-locked (Enter PIN) -> tap "Forgot PIN?" -> tap "Enter recovery phrase" -> BACK x3 -> relaunch.
Result: **MASTER DOES NOT BYPASS**. BACK returns to the "Enter PIN" lock screen every time; a fresh `launch` also lands on the lock screen. The unlocked home / balance is never reachable without the PIN.
Evidence: S3/baseline/m1-01-locked-pin-screen.png, m1-02-forgot-pin.png, m1-03-enter-recovery-phrase.png, m1-04-after-back1.png, m1-05-after-back2.png (back on "Enter PIN"), m1-06-after-back3.png, m1-07-relaunch.png
=> Verdict for the orchestrator: master baseline PASS. The behaviour S4 found on fix 12.0.0 (BACK lands on the UNLOCKED home with the balance visible) is a REGRESSION introduced by fix/upgrade-memory-and-sync, not pre-existing.

## A3b locked-device upgrade (01:26 setpin/lock/kill, 01:26:42 install -r fix, 01:26:54 am start-foreground-service)
- Device provably locked at service start: `dumpsys trust` -> "deviceLocked=1, strongAuthRequired=0x1", mCurrentFocus=NotificationShade.
- master at 85% when killed (mid-sync upgrade, as intended): "06:25:54 BlockchainServiceImpl - progress 85".
- Locked classification CORRECT (grep-bind-locked.txt):
  - "06:26:48 SdkWalletBinder - SDK bind deferred: the device is locked and the SDK master alias is lock-bound; retrying on unlock / app foreground" (SdkBindDeferredWhileLockedException, SdkWalletBinder.kt:1170)
  - "06:26:52 SdkBindRetryService - SDK bind pending: DEVICE_LOCKED (4 consecutive failure(s); device provably locked=true; ...)" and repeating on the retry ladder
  - "06:26:47 SdkBindRetryService - unlock-heal receiver registered (ACTION_USER_PRESENT, exported — SystemUI is the sender)"
- NO engine start while locked: "L1 shadow SPV started" count = 0; "L1 shadow sync not started: app wallet not bound to the SDK yet"; "starting peergroup" only at 06:09:55 (master, pre-upgrade). PASS
- Cutover still committed while locked: "06:26:47 cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)".
- NOTIFICATION shown on the lock screen: "Unlock your phone to finish the wallet update" / "Tap here once your phone is unlocked and the update will finish setting up. Your funds are safe, and your balance stays at its last known amount until then." Evidence: A3b/08-shade-on-lockscreen.png, 06-lockscreen-notification-shade.png. Video: a3b-locked-upgrade.mp4
- UNLOCK at 01:28:30 (`unlockpin 1234`):
  - "06:28:34 SdkBindRetryService - device unlocked (ACTION_USER_PRESENT) — running an immediate SDK bind retry"
  - "06:28:37 SdkWalletBinder - SDK wallet bind established after 6 failed pass(es); retry pressure cleared"
  - "06:28:37 SdkBindRetryService - SDK bind retry 1 (device unlock) succeeded — the wallet is bound"
  - "06:28:37 SdkBindRetryService - SDK bind established — clearing the pending state (DEVICE_LOCKED)"
  => bind succeeded 3 s after the unlock broadcast (< 5 s). PASS. Video: a3b-unlock.mp4
  - Pending notification cleared from the shade (dumpsys notification: 0 matches for "Unlock your phone to finish").
- Explainer shown once on this install too ("A one-time sync is needed", progress "Starting sync…"): A3b/12-explainer-a3b.png
- OPEN CONCERN (under observation): "L1 shadow SPV started" is STILL absent several minutes after the successful bind. The service logs "idle counters, but a replay is in progress (0%) — keeping the service alive until it completes" and the home header sits at "Syncing…" with the last-known partial balance 6.932082. Watching.

## A3b DEFECT (S2): after a LOCKED-device upgrade the SDK L1 engine never starts in that process — replay wedged at 0%
Sequence from wallet.log (A3b/grep-engine-never-started.txt, grep-unlock-bind.txt):
1. 06:26:47 process start while the device is locked; PlatformSyncService kicks the bind.
2. 06:26:48 breadcrumb 21 SDK_L1_ENGINE_STARTING -> `L1ShadowSyncService.startIfEnabled()` runs and returns FALSE:
   "06:26:48 L1ShadowSyncService - L1 shadow sync not started: app wallet not bound to the SDK yet"
   breadcrumb 22 SDK_L1_ENGINE_STARTED is marked anyway (it marks the call, not the outcome).
3. 06:26:48..06:28:07 bind keeps failing with SdkBindDeferredWhileLockedException -> blocker DEVICE_LOCKED (correct).
4. 06:28:34 unlock -> 06:28:37 "SDK wallet bind established after 6 failed pass(es)" (correct, 3 s).
5. Nothing re-kicks the engine. Source check (wt-fix @616ac58ff): the only production call sites of
   `l1ShadowSyncService.startIfEnabled()` are PlatformSyncService.kickSdkEngines (line 462, reached from
   BlockchainServiceImpl.resume() on a foreground-service start), the filter-stall watchdog (needs a RUNNING
   engine, L1ShadowSyncService.kt:2795) and the post-wallet-re-creation restart (:3259). Neither
   SdkBindRetryService.onBindEstablished() nor SdkWalletBinder re-kicks it.
6. Observed consequence at 01:32 (>4 min after the successful bind, still true at the next samples):
   - `grep -c 'L1 shadow SPV started'` = 0
   - `grep -c 'synced_height_persisted=Some'` = 0
   - every minute: "BlockchainServiceImpl - idle counters, but a replay is in progress (0%) — keeping the service alive until it completes"
   - home header stuck on "Syncing…" with the stale last-known balance 6.932082 (A3b/15-home.png)
   So the wallet never leaves 0% and the foreground service is pinned alive forever by the replay guard.

## D-056 recovery probes (orchestrator request)
| # | Action | Time | `grep -c 'L1 shadow SPV started'` after 2 min | Recovered? |
|---|---|---|---|---|
| 1 | `bg` then `fg` (app foreground visit) | 01:39:18 -> 01:41:43 | 0 (heights 0) | NO |
| 2 | airplane `net off` 20 s / `net on` | 01:41:50 -> 01:44:27 | 0 (heights 0) | NO |
| 3 | `kill` + `launch` (fresh process) | 01:44:35 -> 01:44:47 | **1** (heights 220 within 30 s, 363000 within 60 s) | **YES** |
- Recovery line: "06:44:47 L1ShadowSyncService - L1 shadow SPV started for SDK wallet b7118ed5…" (A3b/grep-probe3-recovery.txt)
- Total wedge duration before the restart: bind healed 06:28:37, engine started 06:44:47 => 16 min 10 s of 0% with the foreground service pinned alive.
- USER COST: after a locked-device upgrade the sync only starts once the user force-stops and relaunches the app. Neither foregrounding the app nor a network change recovers it, and the UI gives no hint (it shows "Syncing…" at 0% with a stale balance), so a real user has no reason to try a restart.

## ORCHESTRATOR BASELINE CHECK 2 — Reset wallet without a PIN, MASTER 11.9.0 (01:53-01:55)
Steps (master 11.9.0, reference seed restored, PIN 1234 set): More -> Security -> "Reset Wallet" -> dialog
"Are you sure you want to reset the wallet? / If you reset your wallet the only way to get access to it is to recover
the wallet with the recovery phrase." -> tap "Reset wallet".
Result: **MASTER ALSO WIPES WITH NO PIN PROMPT**. The wallet is destroyed immediately and the app lands on the
onboarding screen ("Create new wallet" / "Restore wallet"); a relaunch confirms the wallet is gone. At no point in
the path is the PIN requested. Master has no "Save data and reset wallet" step at all — just the one confirmation.
Evidence: S3/baseline/m2-01-security.png, m2-02-reset-confirm.png, m2-03-after-confirm.png, m2-04-relaunch-onboarding.png
=> Verdict for the orchestrator: the fix-build S1 (reset with no PIN) is **PRE-EXISTING in master 11.9.0**, NOT a
regression introduced by fix/upgrade-memory-and-sync. Still a genuine "anyone holding the unlocked phone can wipe
the wallet" exposure, but it should be reclassified as pre-existing.

## A3b final (01:48:33)
- "06:48:03 L1Shadow phase=SYNCED 100.0% headers 1556593/1556593 filters 1556593/1556593 wallet 1556593"
- "06:49:00 BlockchainServiceImpl - replay complete — releasing the wake lock"
- Balance == 107.081735 (10708173522 duffs), identical to A3. tx list populated. (A3b/16-a3b-final.png)
- Counts over the whole A3b run: L1 shadow SPV started=1, starting peergroup=1 (master pre-upgrade at 06:09:55 only),
  explainer=1, OverlappingFileLockException=0, filter-stall watchdog=0, OutOfMemory/FATAL=0.
- exit-info: reason=10 FORCE STOP (my kills) and reason=16 PACKAGE UPDATED (the install -r). No LMK, no crash.
- Memory after A3b replay: TOTAL PSS 456 MB, Native Heap 313 MB.
- Device PIN cleared (`clearpin 1234`).
