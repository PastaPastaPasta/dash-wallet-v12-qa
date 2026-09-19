# S2 QA journal — emulator-5556 / dw-qa2
Stream S2: A2 (clean install + restore reference seed, sync to 100%) then Tier B (B4, B2, B3, B1).
Build under test: fix-12.0.0-testnet3-release-signed.apk (versionCode 12000000)
Reference seed: [seed phrase redacted]  (READ-ONLY)
Expected balance: 107.43173749 tDASH

## Journal
2026-09-19T00:10:05 S2 start. emulator-5556 = dw-qa2 confirmed. No pre-existing app package (uninstall returned DELETE_FAILED_INTERNAL_ERROR = not installed).
2026-09-19T00:10:14 Installed fix-12.0.0 (versionCode=12000000 minSdk=29 targetSdk=35 versionName=12.0.0). logcat-start + memlog(30s) armed.
2026-09-19T00:10:17
2026-09-19T00:10:54 NOTE: Recover Wallet screen is FLAG_SECURE -> screencap returns an all-black frame (02-restore-tapped.png). Capturing uiautomator dumps as textual evidence for these screens.
2026-09-19T00:11:16 T0 RESTORE SUBMITTED: tapped Continue on Recover Wallet with the 12-word reference seed (no creation date set -> full scan). uidump: A2/03-seed-entered-uidump.txt
2026-09-19T00:12:11 PIN 1234 set + confirmed.
2026-09-19T00:13:23 Onboarding complete: notifications ALLOW, background-run ALLOW (x2 dialogs). Home screen reached.
2026-09-19T00:13:54 Clock mapping: wallet.log timestamps are UTC; host local `date +%FT%T` is UTC-5. Host 00:11:16 local == 05:11:16 UTC == wallet.log 05:11:18.
2026-09-19T00:13:54 wallet.log: 'cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))' @05:11:18; 'L1 shadow SPV started' @05:12:17 (exactly once); no 'starting peergroup'.
2026-09-19T00:14:22 OBSERVED: app self-locked to 'Enter PIN' lock screen ~35s after onboarding finished while in the FOREGROUND (wallet.log 05:13:48 LockScreenActivity LockState = ENTER_PIN). Screenshot A2/10-lockscreen-check.png. Unlocking with 1234.

## A2 sync phase landmarks (wallet.log timestamps; host time = wallet.log - 5h)
05:11:18 cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))   [host 00:11:18, = restore submit]
05:12:12 armSpvRescan: filter watermark rewind to 0 armed on b7118ed5…
05:12:17 L1 shadow SPV started (exactly once)
05:12:17 L1Shadow phase=IDLE 0.0%
05:12:47 phase=HEADERS  9.1%  headers 380000/1556549   filters 5999      wallet 5999     <- FIRST BLOCK/HEIGHT CHANGE (host 00:12:47, T0+91s)
05:13:18 phase=HEADERS 31.0%  headers 912000/1556549   filters 70999     wallet 70999
05:13:49 phase=FILTER_HEADERS 59.7% headers 1556549/1556549 filters 110999 wallet 110999
05:14:19 phase=FILTERS 71.9%  filters 245999/1556550
05:14:49 phase=FILTERS 75.3%  filters 400999/1556551
05:15:19 phase=FILTERS 77.9%  filters 525999/1556551
2026-09-19T00:15:40 DEFECT CANDIDATE: home screen shows a PARTIAL (and inflated) balance during replay: 825.481794 tDASH at 61% (expected final 107.43173749). Label 'Syncing balance' is greyed, big number is prominent. Evidence A2/11-unlocked-home.png.

### OBSERVATION: app auto-locks to Enter-PIN while in the FOREGROUND during sync
wallet.log lines (no preceding `foreground: 0` in WalletActivityTracker, i.e. app was never backgrounded):
  478:05:13:48 [main] LockScreenActivity - fingerprint was disabled
  479:05:13:48 [main] LockScreenActivity - LockState = ENTER_PIN
  1056:05:15:35 [main] LockScreenActivity - fingerprint was disabled
  1057:05:15:35 [main] LockScreenActivity - LockState = ENTER_PIN
Last WalletActivityTracker foreground transition before both: `05:13:08 current: MainActivity, activities: 1 visible: 1 foreground: 1`.
Effect: a user watching a long replay is kicked to the PIN pad roughly every 40-90 s of no touch input.
Evidence: A2/10-lockscreen-check.png, A2/13-sync-progress.png.

## A2 RESULT — sync completed
05:18:23 phase=FILTERS 100.0%  (host 00:18:23)
05:21:24 phase=SYNCED 100.0% headers 1556559/1556559 filters 1556559/1556559 wallet 1556559 + SETTLED   (host 00:21:24)
05:21:27 DashPaySyncStatus - DashPay sync SETTLED: applicable=true initialSyncCompleted=true accountBuilds=true backfill=true
TOTAL: restore submitted host 00:11:18 -> SYNCED host 00:21:24 = 10 min 06 s.
Watchdog greps CLEAN: no filter-stall, no 'idling detected', no OutOfMemory, no FATAL, no OverlappingFileLockException, no engine restart.
Exactly one 'L1 shadow SPV started'; zero 'starting peergroup'.

FINAL BALANCE displayed: 107.081735 tDASH ($6521.62)  [A2/17-SYNCED-balance.png]
wallet.log 05:18:22 CutoverUiDataService - SDK balance published: 10708173522 duffs (= 107.08173522)
EXPECTED per brief: 107.43173749  -> SHORT BY 0.35000227
Top of tx list: '05 September  Sent  - 0.350002  $21.32' -- exactly accounts for the difference.
Note wallet.log 05:18:19 shows an intermediate 'SDK balance published: 10643173749 duffs' (=106.43173749).
NEXT: verify the 0.350002 send on the insight explorer to decide whether the brief constant is stale or the wallet is wrong.

## EXPLORER VERIFICATION of the 0.35 discrepancy  (RESOLVED: brief constant is stale, wallet is correct)
App tx detail (A2/18-txdetail-sent-0.35.png, A2/19-txdetail-scrolled.png):
  Amount Sent 0.35000227, from ye5QiE9Yk6YshTYwEbW9V9UvhCFE2ACMB1, to yMu5gX1fKg3FC2p17DEsQhu1S4ZXhP78F5,
  network fee 0.00000227, date "September 5 at 7:54 AM".
insight-api/tx/bbd61b8301229c8079dc90a6af3f5fbae544b70aecebec1246d593aa43092953:
  time 2026-09-05T12:54:12 UTC, blockheight 1547938, confirmations 8622,
  vin  ye5QiE9Yk6YshTYwEbW9V9UvhCFE2ACMB1  9.89009773
  vout yMu5gX1fKg3FC2p17DEsQhu1S4ZXhP78F5  0.35000000
       yStxXHHzhAx58JhaPBNhn3xsH93UwBM2nd  9.54009546 (change, back to wallet)
  fees 0.00000227
=> net wallet outflow 0.35000227; 107.43173749 - 0.35000227 = 107.08173522 == the app's balance to the duff.
=> The app's balance is on-chain-correct. The brief's 107.43173749 predates this 2026-09-05 spend (which itself
   predates this QA session, started 2026-09-18), so the expected constant is stale, not a product defect.
2026-09-19T00:26:54 NOTE: 'idling detected, stopping service' logged at 05:25:00 and 05:26:00 (once per minute) with NO matching 'service start command' afterwards -> repeating log/tick. Will characterise during B4.

## A2 independent verification
tx_display_cache rows (what the UI list renders): 1553
dash-sdk.db transactions rows: 3269
dash-sdk.db txos WHERE isSpent=0: SUM(amount)=10708173522 duffs over 811 UTXOs == displayed balance to the duff
Wallet xpub (Tools > Extended public key (BIP44)), recorded only, nothing derived by me:
  tpubDDDjGxYK3jDHmnNoEBjKPiqS9DNjHeaWvogRtG7JYnZXmLZJ4PJaKSvRVdPNbf9ZrbPLLDm67sKeaqiCZJoVKg5UhCHjkzQPnfKbZtNBaPd
EXPLORER CROSS-CHECK: summed insight-api /addrs/<100 at a time>/utxo over the 810 distinct addresses holding
those UTXOs -> 10708173522 duffs = 107.08173522 DASH. Exact match, 0 failed chunks.
More screen: Dash Wallet 107.081 D, Shielded 0.000 D, identity 'test-platform-4-11', Platform 4 Protocol 11.

## Follow-up on the 0.0123 "extra" in the full-address explorer sweep -> NOT a defect
Sweeping ALL 11,843 rows of core_addresses gave 10709403522 duffs, i.e. 1,230,000 duffs (0.0123) more than the app.
The single uncounted funded output is:
  yYu4XLg7e7BGbPzDGsjrTiEzVu5NJtBKpR  0.01230000  tx 5e4d7282a266039bd2244c2ff9f8a7f96d40ded15b314c5c7d5e451c4350272c vout 0, height 1534921
core_addresses row: poolTypeTag=2, addressIndex=0, accountId=17,
  derivationPath m/9'/1'/15'/0'/0xea87…/0x9aa3…/0   (DIP-15 friend chain)
accounts.id=17 is accountTypeName='dashpayExternalAccount' = the CONTACT's receiving chain (we do not own those keys);
id=16 is 'dashpayReceivingFunds' (ours). So 0.0123 is money this wallet SENT to a DashPay contact and is correctly
excluded from our balance. The parent tx IS in the SDK store (txid blob is little-endian:
2c2750431c455e7d5c4c315bd1de406df9a7f8f92f4c24d29b0366a282724d5e) and its 0.98770773 change output is counted.
=> A2 balance assertion: app 107.08173522 == explorer 107.08173522 over the 810 addresses that back the wallet's own
   UTXOs. Balance is CORRECT; the brief's 107.43173749 is stale by the confirmed 2026-09-05 spend of 0.35000227.

## DEFECT: Receive screen hands out address index 0, a heavily reused address
Home > Receive (A2/26-receive-address.png) shows "Dash Address yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd".
dash-sdk.db core_addresses: derivationPath m/44'/1'/0'/0/0, addressIndex=0, isUsed=1, accountId=1.
dash-sdk.db accounts id=1 (standardBip44): externalHighestUsed=245, internalHighestUsed=971
   -> a fresh address should be ~index 246.
insight-api/addr/yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd: txApperances=107, totalReceived=896.3243902,
   balance 0.001. So the app is presenting the wallet's very first, most-reused address for a new receive.

## A2 memory (from evidence/S2/mem.csv, 30 s interval, 42 samples 00:10:42 -> 00:31:28 local)
peak TOTAL PSS    622 MB  @ 00:20:54 (during FILTERS/final replay)
peak Native Heap  481 MB  @ 00:20:54
peak Dalvik Heap   50 MB  @ 00:18:21
idle after 100%:  PSS 468 MB, native 313 MB, dalvik 34 MB  (00:31:28)
wallet.log MEM pss= line peak: 05:21:00 'MEM pss=606MB nativeHeap=457/547MB jvm=22/576MB'
dumpsys activity exit-info: EMPTY (no LMK, no ANR, no crash) - A2/... ; app pid 5226 unchanged from launch to end of A2.
NOTE: the crash buffer contains 'FATAL EXCEPTION' entries from PID 11851/12681 = the `uiautomator` helper process
("UiAutomationService ... already registered", caused by my sampler and my own dumps running concurrently).
These are TEST-HARNESS artefacts, not app crashes; the app process never died.
wallet.log pulled: A2/walletlog-after-sync/files/log/wallet.log (1.28 MB)

## B4 background idle start
2026-09-19T00:32:07
B4 backgrounded at 2026-09-19T00:32:09

## A2 full progress table (wallet.log UTC; host local = UTC-5; T0 = restore submitted 05:11:18 UTC)
 UTC       T+      engine%  wallet-block cursor / tip        note
 05:11:18  0:00    -        -                                restore submitted (cutover DUAL_RUNNING -> CUT_OVER)
 05:12:17  0:59    0.0      0                                L1 shadow SPV started, phase=IDLE
 05:12:47  1:29    9.1      5,999 / 1,556,549                FIRST height change
 05:13:18  2:00   31.0      70,999
 05:13:49  2:31   59.7      110,999                          headers complete -> FILTER_HEADERS
 05:14:19  3:01   71.9      245,999                          FILTERS
 05:14:49  3:31   75.3      400,999
 05:15:19  4:01   77.9      525,999
 05:15:50  4:32   79.9      615,999
 05:16:21  5:03   83.3      775,999
 05:16:52  5:34   87.1      955,999
 05:17:22  6:04   91.3      1,150,999
 05:17:52  6:34   96.0      1,370,999
 05:18:23  7:05  100.0      1,555,999 / 1,556,554            filters at tip-555
 05:21:24 10:06  100.0      1,556,559 / 1,556,559            phase=SYNCED + SETTLED  <-- 100%
 05:31:52 20:34  100.0      1,556,561 / 1,556,561            still tracking tip
(The engine's own % is phase-weighted, so it is not linear in blocks; the wallet cursor column is the linear measure.)
UI reported "Syncing 31%" (00:12), 61%, 64%, 78%, 99% (00:19), then the indicator disappeared after SYNCED.
Engine restarts: 0.  filter-stall watchdog lines: 0.  'idling detected' during replay: 0 (first one at 05:25:00,
i.e. 4 min AFTER sync completed).
ReplayMemTelemetry nativeHeapAllocated peak 395 MB (nativeHeapSize 455 MB) at FILTERS; jvmUsed never above 37 MB of 576 MB.

## CAVEAT on the "foreground auto-lock" observation - needs a controlled probe
Every observed lock event happened while my 60 s uiautomator sampler was running. `uiautomator dump` registers a
UiAutomation accessibility service, which changes window focus and could itself be what trips the app's lock.
=> I will re-test after B4 with the sampler STOPPED, using screencap only (screencap does not touch accessibility),
   leaving the app untouched in the foreground for 5+ minutes. Only if it locks then is it a product defect.
Also note: the logcat "FATAL EXCEPTION ... registerUiTestAutomationService ... already registered" entries all come
from the uiautomator helper PIDs (10547, 11851, 12681), never from the app PID 5226. No LMK kill of the app in logcat.

### B4 observation 1: 'idling detected, stopping service' fires once per minute while FOREGROUND, service does not stop
wallet.log: 05:25:00, 05:26:00, 05:27:00, 05:28:00, 05:29:00, 05:30:00 - six consecutive minutes, app foreground and
synced, with NO 'service start command' and NO '.onDestroy()' in between, i.e. the line is logged every minute but the
stop never happens. The service only actually died when I backgrounded the app:
  05:32:08 [main] BlockchainServiceImpl - .onDestroy()
  05:32:08 [DefaultDispatcher-worker-2] BlockchainServiceImpl - The onCreateCompleted is active: false
So: not a stop/start loop, but a repeating misleading log line while the service is in fact running.
Count of 'idling detected' in the whole log at 00:35 local: 6 (none during the replay itself).
App pid 5226 unchanged.

### Tx list scroll pass 1 (A2/txlist/page-01..30.png, 30 swipes from the top at 00:25 local)
Reached 09 March 2025 after 30 swipes (list starts at 05 September 2026). Not the end of the list.
Authoritative row count from the app's own render cache: dash-wallet-database.tx_display_cache = 1553 rows
(dash-sdk.db.transactions = 3269 raw records; the UI groups CoinJoin mixing rounds, e.g. a single
"Mixing Transactions / 9 transactions / -0.000128" row).
OBSERVATION (cosmetic): many rows read "Sent ... D 0" with no fiat value (A2/txlist/page-30.png) - self-transfer /
CoinJoin denomination sends are rendered as a Sent row with amount 0 rather than being grouped or labelled.
Some rows also show fiat "Not available".

## B4 background idle 30 min — RESULT (00:32:07 -> 01:02:20 local; wallet.log 05:32 -> 06:02 UTC)
Exactly ONE service stop/start cycle in 30 minutes, no loop:
  05:32:08 BlockchainServiceImpl .onDestroy()                      <- app backgrounded, service stops
  05:54:38 onCreate completed, processing onStartCommand           <- wakes ~22 min later
  05:54:39 L1Shadow phase=IDLE 0.0% headers 0/0 filters 0/0 wallet 1556561   (transient re-init)
  05:54:46 L1Shadow phase=SYNCED 100.0% headers 1556572/1556572 filters 1556572/1556572 wallet 1556572
           -> caught up 11 blocks in 8 s while backgrounded
  05:57:00 idling detected, stopping service  +  .onDestroy()      <- here the line DOES stop the service
'idling detected' total count over the whole session: 7 (6 foreground no-ops + this 1 real stop).
batterystats: diff of all 'wake lock|alarm|job' lines between B4/batterystats-mid.txt (13 min) and
B4/batterystats-end.txt (30 min) is EMPTY -> no growing wakelock/alarm counts; no app-owned wake locks appear at all.
App pid 5226 unchanged across the whole 30 min (never killed).
Memory while backgrounded dropped from ~313 MB native to ~126 MB native (mem.csv 00:44:03 onward).

### Characterisation of "idling detected, stopping service" (answers orchestrator's question)
FOREGROUND, post-sync: logged at 05:25:00, 05:26:00, 05:27:00, 05:28:00, 05:29:00, 05:30:00 — once a minute —
with NO '.onDestroy()', NO 'stopSelf', NO 'service start command' in between. The service does NOT stop and does
NOT restart; the process stays alive. So the message is a misleading once-a-minute log line, not a service loop.
BACKGROUND: the same line at 05:57:00 IS immediately followed by '.onDestroy()' — there it means what it says.
2026-09-19T01:03:50 LOCK PROBE START: app foreground on home, untouched. Only screencap (no uiautomator) every 60s for 6 min.

## RESOLVED: the foreground auto-lock is EXPECTED, not a defect of this branch
Controlled probe (A2/lockprobe/probe-1..6.png, 01:03:50 - 01:09:54 local, screencap only, no uiautomator):
'LockState = ENTER_PIN' count went 8 -> 9; the new lock is wallet.log 06:04:31 UTC, ~60 s after my last touch.
So the lock is real and NOT a harness artefact. Root cause in source:
  common/src/main/java/org/dash/wallet/common/Configuration.java:171-173
      public int getAutoLogoutMinutes() { return prefs.getInt(PREFS_KEY_AUTO_LOGOUT_MINUTES, 1); }   // default 1 minute
  wallet/src/de/schildbach/wallet/AutoLogout.java:104-107 shouldLogout(): tickCounter >= autoLogoutMillis
  AutoLogout.java is Copyright 2019 -> pre-existing shipped default, unchanged by this branch.
VERDICT: expected behaviour (Settings > Security auto-logout, default 1 min). Recorded as test-environment friction
only: a user watching a 10-minute replay is returned to the PIN pad every minute unless they keep touching the screen.

## Minor observation (pre-existing, not a defect of this branch): `last_used` pref never refreshes
shared_prefs last_used stayed at 1789794731559 (= 2026-09-19T05:12:11Z, wallet setup) across ~58 min of active use
including unlocks, taps and swipes. Configuration.touchLastUsed() has exactly one caller,
wallet/src/de/schildbach/wallet/ui/main/MainActivity.kt:207, so it only fires when MainActivity is created.
WalletApplication.scheduleStartBlockchainService() feeds getLastUsedAgo() into the alarm backoff
(15 min / 12 h / 24 h buckets via Constants.LAST_USAGE_THRESHOLD_*), so a long-lived process drifts into a longer
alarm interval despite active use. Low impact; flagged for completeness.
2026-09-19T01:11:43 === B2 START: Reset wallet then restore the same seed ===
2026-09-19T01:12:42 Reset dialog 2 offered 'Save data and reset wallet' (writes metadata to Platform) vs 'Reset wallet without saving'. Chose WITHOUT SAVING to keep the reference wallet read-only.
2026-09-19T01:13:18 B2 T0: restore submitted (same reference seed, no creation date).
2026-09-19T01:14:51 B2 kill targets by wallet cursor: 25%=389145, 50%=778289, 75%=1167434 (tip 1556578).

## *** B2 DEFECT: after kill/restart torture the home screen shows a grossly inflated balance and claims to be synced
Screenshot: B2/11-BALANCE-after-kills.png (01:28 local) -- home shows "D 2319.448975  $139322.11", NO "Syncing balance"
label and NO "Syncing NN%" next to History, i.e. the app presents itself as fully synced.
Ground truth at the same moment:
  dash-sdk.db  SELECT SUM(amount),COUNT(*) FROM txos WHERE isSpent=0  ->  10708173522 | 811   (= 107.08173522, correct)
  dash-wallet-database tx_display_cache -> 1546 rows (A2 had 1553)
wallet.log, last balance the UI layer ever received:
  06:19:20 CutoverUiDataService - SDK balance published: 232045497208 duffs (was 232107378387) | l1Synced=false ...
  06:19:20 CutoverUiDataService - SDK balance published: 232004898140 duffs (was 232045497208) | l1Synced=false ...
  06:19:20 CutoverUiDataService - SDK balance published: 231984897940 duffs (was 232004898140) | l1Synced=false ...
  06:19:21 CutoverUiDataService - SDK balance published: 231964897740 duffs (was 231984897940) | l1Synced=false ...
  06:19:21 CutoverUiDataService - SDK balance published: 231954897640 duffs (was 231964897740) | l1Synced=false ...
  06:19:21 CutoverUiDataService - SDK balance published: 231944897540 duffs (was 231954897640) | l1Synced=false ...  <-- LAST, never corrected
  06:19:25 L1ShadowSyncService - L1Shadow phase=SYNCED 100.0% ... wallet 1556580 ... SETTLED
231944897540 duffs = 2319.44897540 -> exactly what the UI renders.
So the published-balance stream was still converging DOWNWARD in small decrements (as it did in A2, where it walked all
the way down to 10708173522) and simply STOPPED 4 s before phase=SYNCED, leaving the stale in-flight value on screen.
Note every one of those lines carries l1Synced=false.
Transaction history itself is correct (same top rows as A2: 05 Sep Sent 0.350002, 22 Aug Received 1, 15 Aug ...).
Still wrong 9 minutes later. Recovery attempts follow.

### Root-cause evidence for the inflated balance: only the bip44 bucket is wrong
wallet.log 'WalletBalanceFacts' at the moment of phase=SYNCED, BAD run (B2, after two kill/relaunch cycles):
  total=231944897540 accounts={bip44:223410106258, bip32:0, coinjoin:8534691282, identityRegistration:0,
  identityTopUpUnbound:0, identityInvitation:0, assetLockTopUp:0, assetLockShieldedTopUp:0, providerVoting:0,
  providerOwner:0, providerOperator:0, providerPlatform:0, dashpayReceiving:100000, dashpayExternal:1230000}
  confirmed=231944897540 unconfirmed=0 txCount=3269
GOOD run (A2, clean replay, and again after the process restart):
  total=10708173522 accounts={bip44:2173382240, ... coinjoin:8534691282, ... dashpayReceiving:100000,
  dashpayExternal:1230000} confirmed=10708173522 unconfirmed=0 txCount=3269
Every bucket is identical except bip44: 2,173,382,240 (correct) vs 223,410,106,258 (bad) — inflated ~102x.
txCount is identical (3269) in both, so no transaction is missing; only the bip44 UTXO-set aggregation is wrong,
consistent with spent outputs not being retired from the in-memory set when blocks are re-processed after a restart.
(Also note total = bip44 + coinjoin + dashpayReceiving exactly; dashpayExternal:1230000 is correctly excluded — this
independently confirms the 0.0123 contact-chain analysis above.)
RECOVERY: force-stop + relaunch fixes it. wallet.log after relaunch:
  'SDK balance published: 10708173522 duffs' and the UI shows 107.081735 again (B2/13-after-process-restart.png).
  bg/fg alone does NOT fix it (B2/12-after-bg-fg.png still 2319.448975).
Video of the restart recovery: B2/b2-restart-recovery.mp4
2026-09-19T01:31:52 === RESTORE #3 for B3 (net flap x3) + B1 (lowmem) — NO kills, to test whether the inflated balance needs a kill ===

## B3 network flap — during outage #3 the UI shows a proper offline banner
B3/03-during-net-off-3.png (01:40:55, 38 s into the third 2-minute outage):
  "Syncing balance / 745.72803 / $44351.06" + banner "Unable to connect to the Dash network — Check your connection"

## B3 + B1 RESULT (restore #3, no kills) — both PASS, and it is the CONTROL for the inflated-balance defect
Timeline file: B3/torture-timeline.txt. T0 (restore submitted) 01:33:04 local; phase=SYNCED 06:46:05 UTC (01:46:05) =
13 min 01 s wall clock, of which 6 min was forced network downtime -> ~7 min of productive replay.
B3 network flap x3 (svc wifi disable + svc data disable, 2 min each):
  #1 OFF T+32s  cursor frozen at headers 324000 / filters 1999 ; ON T+151s ; by T+181s cursor 456000 / 15999
  #2 OFF T+210s cursor frozen at headers 1556586 / filters 110999 ; ON T+331s ; by T+361s filters 360999
  #3 OFF T+390s cursor frozen at headers 1556588 / filters 575999 ; ON T+510s ; by T+540s filters 735999
  -> in all three, the cursor is exactly unchanged across the outage and resumes inside 30 s of the network returning.
  UI during outage #3: banner "Unable to connect to the Dash network — Check your connection" (B3/03-during-net-off-3.png)
  Watchdog restarts: grep -c 'filter-stall|engine restart|restarting engine' = 0.
B1 low memory: 5 x `am send-trim-memory RUNNING_CRITICAL` at T+181, 361, 540, 661, 780 s. The app survived every one,
  the cursor kept advancing across each, the process was never killed, and the replay reached 100%.
  dumpsys activity exit-info: no LMK/ANR/crash entries for the app.
*** CONTROL for the B2 inflated balance: with NO kill, the balance converged correctly:
  06:44:04 SDK balance published: 10684304203 duffs (was 10735304657)
  06:44:04 SDK balance published: 10644303976 duffs (was 10684304203)
  06:44:04 SDK balance published: 10743173749 duffs (was 10644303976)
  06:44:05 SDK balance published: 10708173522 duffs (was 10743173749)   <-- CORRECT, and 2 min BEFORE phase=SYNCED
  06:46:05 L1Shadow phase=SYNCED 100.0% ... wallet 1556591
  UI: 107.081735 (B3/04-BALANCE-after-torture.png). The header never showed a wrong number in this run.
  => the inflated balance needs a mid-replay process KILL; network flaps + RUNNING_CRITICAL trim alone do not trigger it.

## *** Confirmation of D-037 (history rows lost) on the reference wallet, at 100% after restore #3
dash-sdk.db      SELECT COUNT(*) FROM transactions                                              = 3269
dash-sdk.db      SELECT COUNT(*) FROM (SELECT txid FROM txos WHERE txid IS NOT NULL
                   UNION SELECT spendingTxid FROM txos WHERE spendingTxid IS NOT NULL)          = 2375
dash-sdk.db      SELECT COUNT(*) FROM txos                                                      = 5356
dash-wallet-db   SELECT COUNT(*) FROM tx_display_cache                                          = 1531
dash-wallet-db   SELECT COUNT(*) FROM tx_display_cache WHERE valueSatoshis > 0  (received rows) = 394
dash-wallet-db   ... WHERE valueSatoshis <= 0                                                   = 1137
THE APP ITSELF LOGS THE LOSS, and the number it reports as "SDK records" is exactly the txos union (2375), not the
transactions count (3269):
  06:46:05 TxDisplayCacheService - Sync complete (cutoverCommitted=true): SDK=2375 records | dashj wallet=0 txs |
  group cache=1627 txs/51 groups | display=1531 rows — display cache is missing rows (SDK holds 2375 records,
  display has 1531 rows) — requesting an SDK reconcile pass
=> 3269 - 2375 = 894 transactions never reach the display pipeline at all. Matches S8's root cause (the display cache
   walks `txos` instead of `transactions`, so a tx whose outputs were all spent before the replay reached it has no row).
NON-DETERMINISTIC: the same wallet/seed produced different counts on each restore of this session -
  A2 restore #1: tx_display_cache = 1553
  B2 restore #2 (with kills): SDK=2943 records, group cache=1774 txs/51 groups, display=1546 rows
  B3 restore #3 (no kills):   SDK=2375 records, group cache=1627 txs/51 groups, display=1531 rows
  while dash-sdk.db `transactions` is a stable 3269 every time.
TAIL IS INTACT: oldest display row = 2019-07-31 10:04:28 "Received 10000000" / "Sent -10000000", which matches the real
  first transaction on the index-0 address yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd exactly
  (insight tx bc3860520181daa812639c924745597a3c114743c620fa1867cce74a3c91b0a6, 2019-07-31T10:04:28Z, height 146742,
   vout 0.10000000 to that address). So history is not truncated at the old end; rows are dropped scattered through it.
  Newest display row = 2026-09-05 12:54:12 "Sent -35000227" = the 0.35 spend. Correct.
2026-09-19T01:49:13 === RESTORE #4: dedicated 3-kill pass for the B2 blocks-lost acceptance target ===

## B2 FINAL — dedicated 3-kill pass (restore #4), blocks-lost acceptance target
T0 restore submitted 01:50:14 local; tip ~1,556,595. Results file: B2/kill3/kill3-results.txt
Videos: B2/kill3/k1.mp4, k2.mp4, k3.mp4 ; screenshots k{1,2,3}-0{1,2,3}-*.png

| kill | kill time | cursor before | persisted before | cursor after relaunch | persisted after | BLOCKS LOST |
|------|-----------|---------------|------------------|-----------------------|-----------------|-------------|
| k1   | 01:52:20  | 488,000 (31%) | 343,000          | 498,000               | 343,000         | 0           |
| k2   | 01:55:05  | 1,298,000(83%)| 1,553,000        | 1,553,000             | 1,553,000       | 0           |
| k3   | 01:57:45  | 1,553,000(99%)| 1,552,170        | 1,552,170             | 1,552,170       | 0           |
Plus the two kills on restore #2: kill25 at cursor 560,000 -> persisted 560,000 both sides = 0 lost;
                                 kill50 at persisted 1,290,000 -> 1,290,000 both sides = 0 lost.
=> 5 kills total, persisted watermark lost 0 blocks every time; worst raw cursor regression 830 blocks (k3).
   TARGET <= 5,000 blocks per kill: PASS with a large margin. Relaunch to first forward progress was 7-25 s each time.
Sync still reached 100%: phase=SYNCED at 06:59:13 UTC (01:59:13 local) = 8 min 59 s from T0 including 3 kills.

## *** INFLATED BALANCE REPRODUCED 2/2 on kill runs (and 0/2 without kills)
restore #4, after the 3 kills, at 100%:
  UI: D 2363.277644   (B2/kill3/20-BALANCE-after-3-kills.png)
  dash-sdk.db txos WHERE isSpent=0 -> 10708173522 | 811   (= 107.08173522, correct)
  06:59:13 L1Shadow phase=SYNCED 100.0% ... wallet 1556595 ... SETTLED
  06:59:14 CutoverUiDataService - SDK balance published: 236327764418 duffs (was 244621056726) | l1Synced=TRUE
           rescanArmedHold=false dashPayBackfill(armed=false,replaying=false)     <-- LAST, never corrected
  WalletBalanceFacts: total=236327764418 accounts={bip44:227792973136, bip32:0, coinjoin:8534691282,
    identityRegistration:0, ... dashpayReceiving:100000, dashpayExternal:1230000} confirmed=236327764418
    unconfirmed=0 txCount=3269
  Again ONLY bip44 is wrong: 227,792,973,136 vs the correct 2,173,382,240. Every other bucket and txCount match.
  Note this run's last published line carries l1Synced=TRUE, so the app is fully and confidently "synced" while
  displaying a 22x inflated balance with no syncing indicator.
Summary of the 4 restores this session:
  #1 A2   no kills               -> converged to 10708173522, UI 107.081735  CORRECT
  #2 B2   2 kills                -> stopped at 231944897540, UI 2319.448975  WRONG (l1Synced=false)
  #3 B3/B1 net flaps + lowmem    -> converged to 10708173522, UI 107.081735  CORRECT
  #4 B2   3 kills                -> stopped at 236327764418, UI 2363.277644  WRONG (l1Synced=true)
Workaround (verified on run #2): force-stop + relaunch republishes 10708173522 and the UI shows 107.081735.
  bg/fg alone does NOT fix it.
D-037 counts for this run: TxDisplayCacheService "SDK=2865 records | group cache=1750 txs/51 groups | display=1557
  rows — display cache is missing rows (SDK holds 2865 records, display has 1557 rows) — requesting an SDK reconcile
  pass". transactions table still 3269 -> 404 transactions never reach the display pipeline on this run.
  Fourth different value for the same wallet: 1553 / 1546 / 1531 / 1557 display rows.
2026-09-19T02:05:56 SESSION END. memlog + logcat stopped, final wallet.log pulled to S2/final-walletlog/. REPORT.md written.
