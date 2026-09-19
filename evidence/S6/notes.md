# S6 — MAINNET prod build QA journal (emulator-5564 / dw-qa6)

Build under test: `$QA_APKS/fix-12.0.0-prod-release-signed.apk`, package `hashengineering.darkcoin.wallet`.
Helper: `$QA_EVIDENCE/S6/qa-app-prod.sh` (copy of qa-app.sh with PKG overridden to the prod package).

NO REAL FUNDS. Only seeds used: (a) freshly generated throwaway, (b) public BIP39 test vector `abandon…about`.

## Journal
2026-09-19T00:19:34 S6 start — device clean, no darkcoin package installed.
2026-09-19T00:22:21 master prod APK now available for M3.

### M1 fresh mainnet wallet (fix prod 12.0.0 / versionCode 12000000)
- 00:19:39 installed `fix-12.0.0-prod-release-signed.apk` clean (device had no darkcoin package).
- `qa-app.sh launch` (monkey) does NOT start this build; had to use
  `am start -n hashengineering.darkcoin.wallet/de.schildbach.wallet.ui.OnboardingActivity`. Environment/helper quirk, see notes at end.
- Onboarding = identical to testnet: 3-page carousel, "Create new wallet" / "Restore wallet".
  NO mainnet-specific screen, no network banner (expected: prod has no testnet chrome).
- Select Security Level (12 vs 24 words) -> 12 words (default) -> Set PIN 1234 -> Confirm PIN.
- Recovery phrase screen: FLAG_SECURE is honoured (screencap is black -> 07-recovery-phrase.png).
  Phrase is still readable via uiautomator (standard Android a11y behaviour, not a defect).
- THROWAWAY fresh mainnet seed (never funded, never will be):
  `[seed phrase redacted]`
- Onboarding dialogs after Verify: system POST_NOTIFICATIONS (Allow), app "Let Dash Wallet run in the
  background?" (Allow) then system "Let app always run in background?" (Allow).
- Home reached 00:25:30 host. Balance `0` / `$ 0`. NO sync-progress pane rendered on the home header at all
  (sync_status_pane_parent present in the hierarchy but empty). Evidence M1/12-home.png.
- 00:25:52 app auto-locked to Enter PIN while in the FOREGROUND (same as S2's testnet observation).
  Evidence M1/13-autolock-after-onboarding.png. Unlocked with 1234 -> M1/14-home-unlocked.png.
- wallet.log (UTC; host = UTC-5): 05:21:23 `cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))`,
  05:24:10 `L1 shadow SPV started ... /files/l1_shadow_spv/mainnet`. mainnet dataDir confirmed.
- Insight cross-check of XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5 (for M2), captured 00:27 host:
  balance 0, totalReceived 0.01122, totalSent 0.01122, txApperances 4,
  txids 359445e0…c485 (h1988337), 77dc9192…b3f7 (h1988331), f3269c40…319b (h883654), 6d498818…38d8 (h883492).

### M1 RESULT — fresh mainnet wallet sync: PASS
wallet.log (UTC, host = UTC-5):
  05:21:23 cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))   [wallet created]
  05:22:07 armSpvRescan: filter watermark rewind to 2404800 armed on ee230719…          [mainnet checkpoint]
  05:22:07 CutoverUiDataService - "cutover UI active but the engine wallet-event tap is not running
           (USE_KOTLIN_SDK_L1_SHADOW off, or L1ShadowSyncService not started)" — transient, 123 s gap until 05:24:10
  05:24:10 L1 shadow SPV started (EXACTLY ONCE), dataDir=…/l1_shadow_spv/mainnet
  05:24:10 phase=IDLE 0.0%  -> 05:24:42 phase=FILTERS 98.5% headers 2541275/2541275 filters 2428000/2541275
  05:24:52 phase=SYNCED 100.0% headers 2541275/2541275 filters 2541275/2541275 wallet 2541275
  05:24:52 WalletBalanceFacts: total=0 … confirmed=0 unconfirmed=0 txCount=0
  chainlock tracking then follows the tip live: 2541275 -> 2541276 (05:28:22) -> 2541277 (05:29:05)
TIME TO 100%: 42 s from L1 engine start, 3 min 29 s from wallet creation. (Testnet S2 took 10 min 06 s.)
ENGINE RESTARTS: 0. No 'filter-stall', no OutOfMemory, no FATAL, no OverlappingFileLockException,
zero 'starting peergroup'.
BALANCE: 0 / $ 0, empty History (only the "Join DashPay" CTA). Evidence M1/15-home-synced.png. EXPECTED = actual.
MEMORY (evidence/S6/mem.csv): peak TOTAL PSS 454,639 kB (444 MB) @00:24:37 during FILTERS,
  peak Native Heap 322,864 kB, peak Dalvik Heap 32,010 kB; settles to ~350 MB PSS / ~217 MB native.
  ReplayMemTelemetry peak nativeHeapAllocated=375,572,816 jvmUsed=19,020,480 (jvmMax=603,979,776).
EXIT-INFO: empty (no process death at all) — M1/exitinfo.txt.
ODDITIES during sync:
  (a) The home header NEVER rendered a sync-progress pane/percentage at any point (sync finished in 42 s,
      so this may simply be "too fast to see", but nothing was ever shown). M1/12-home.png, sync-*.png.
  (b) App auto-locked to Enter PIN twice while in the FOREGROUND (05:25:52 and ~05:29:2x) — same behaviour
      S2 reports on testnet. M1/13-autolock-after-onboarding.png.
  (c) After SYNCED, `BlockchainServiceImpl - idling detected, stopping service` is logged once per minute
      indefinitely (05:27:00, 05:28:00, …) with no matching restart — same as S2's testnet note.

### M2 RESULT — BIP39 test-vector seed (abandon…about) on mainnet: PASS
00:31:29 host: More > Security > Reset Wallet > "Reset wallet" -> back to onboarding (M2/03,04).
  wallet.log 05:31:31 "Removing all the data and restarting the app"; 05:31:33 "L1 shadow hard reset:
  deleted SPV dataDir …/l1_shadow_spv/mainnet (17 files)". Clean wipe.
00:32:36 host: Restore wallet, single-field seed entry, NO creation date -> full rescan. PIN 1234.
  NOTE: `adb shell input text` needs %s for spaces; the field accepted the full phrase and validated it.
wallet.log:
  05:32:38 cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))
  05:33:19 L1 shadow SPV started (exactly once this restore), phase=IDLE 0.0%
  05:33:50 HEADERS 40.3% -> 05:34:20 FILTER_HEADERS 56.9% -> 05:35:20 FILTERS 74.9%
  -> 05:37:53 FILTERS 97.3% -> 05:38:21 phase=SYNCED 100.0% headers/filters 2541279/2541279
  05:38:21 WalletBalanceFacts: total=0 … confirmed=0 unconfirmed=0 txCount=4
TIME TO 100%: 5 min 45 s (host 00:32:36 restore submit -> 00:38:21 SYNCED). ENGINE RESTARTS: 0.
BALANCE: 0.00 / $0  -> matches expectation and the explorer.
TX LIST (M2/14-SYNCED-home.png) shows exactly the 4 historical appearances:
  15 December 2023  Sent −0.00122 12:45 PM  |  Received +0.00122 12:34 PM
  08 June 2018      Sent −0.01    12:32 PM  |  Received +0.01    5:15 AM
  sum received 0.01122, sum sent 0.01122 == insight totalReceived/totalSent. Dates match insight block times
  (1702665932/1702665284 = 2023-12-15; 1528479127/1528452908 = 2018-06-08).
TX DETAIL (M2/17-txdetail-sent-2018.png): "Sent from XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5",
  "Sent to XfVzg3PPJ11qqmHxWvKLQ5CAi12DhksZGi" -> the expected address is present and correct.
  Received detail (M2/15,16) shows NO address rows and NO fee row for either direction — see defect D3.
WATCHDOG: no filter-stall, no OutOfMemory, no FATAL, no OverlappingFileLockException, no engine restart,
  zero 'starting peergroup'. exit-info empty (M2/exitinfo.txt).
MEMORY (mem.csv): PEAK TOTAL PSS 1,018,245 kB (995 MB) @00:37:43, peak Native Heap 866,932 kB (847 MB),
  Dalvik peak 26,888 kB. ReplayMemTelemetry peak nativeHeapSize=1,181,822,976 (1.18 GB).
  After SYNCED it settles to ~690 MB PSS / ~540 MB native and stays there (does NOT return to the
  ~350 MB of the fresh-wallet case). For comparison S2's testnet full restore peaked at 637 MB PSS /
  492 MB native (evidence/S2/mem.csv) — mainnet replay costs ~1.6x more. See defect D1.

### M3 mainnet upgrade path (master 11.9.0 prod -> fix 12.0.0 prod)
00:42:14 uninstalled fix prod; 00:42:18 installed `master-11.9.0-prod-release-signed.apk`
  (package hashengineering.darkcoin.wallet, versionCode 11090002, minSdk 24, targetSdk 36).
00:43:11 Restore wallet with abandon…about (no creation date), PIN 1234, Allow notifications + background.
00:44:53 home reached, header shows "Syncing balance" + "Syncing 35%", "There are no transactions to display".
  Evidence M3/06-master-home-t0.png.
wallet.log (master/dashj): real dashj PeerGroup running against mainnet
  05:45:08 Peer{[85.209.241.65]:9999, version=70240, subVer=/Dash Core:23.1.8/, height=2541281} New peer (5 connected)
  ChainDownloadSpeedCalculator chain/common height 239040/2541281 at 05:45:0x
Letting dashj run 20 minutes with samples every 5 min -> M3/master-samples.txt + M3/master-sync-*.png.
IMPORTANT CONTROL RESULT (master 11.9.0 prod, same device/session):
  - master ALSO auto-locks to Enter PIN while in the foreground: wallet.log 05:44:43
    `WalletActivityTracker … foreground: 1` then 05:45:32 `LockScreenActivity - LockState = ENTER_PIN`
    with no intervening background transition. => the foreground auto-lock is PRE-EXISTING, not a
    regression introduced by fix/upgrade-memory-and-sync.
  - master dashj memory while syncing mainnet: TOTAL PSS 199-208 MB, Native Heap 43 MB, Dalvik 60-69 MB
    (00:50:10 and 00:54:27 samples). Compare fix build: 995 MB PSS / 847 MB native peak for the same seed.
  - master dashj speed: ~1000-1500 blocks/sec, chain height 239040 -> 456180 in 6 min (of 2541282).
MASTER 20-MIN BASELINE (01:05 host): "Syncing 64%", dashj chain/common height 1216108/2541289,
  balance 0, tx list already shows the two 2018 entries: "Sent −0.0099 12:32 PM / Not available" and
  "Received +0.01 5:15 AM / Not available". Evidence M3/07-master-after-20min.png, M3/master-samples.txt.
  Master mem at the 20-min mark: TOTAL PSS 187,876 kB, Native Heap 44,692 kB, Dalvik 47,437 kB.
  NOTE the amount difference vs the fix build: master lists the 2018 send as 0.0099 (payment only);
  the fix build lists it as 0.01 (payment 0.0099 + 0.0001 fee = total wallet debit). insight tx
  f3269c40…319b: valueIn 0.01, valueOut 0.0099, fees 0.0001, single output to XfVzg3PPJ11qqmHxWvKLQ5CAi12DhksZGi.
  Also master shows fiat "Not available" for 2018 rates while fix shows "$ 0.61".
UPGRADE EXECUTED:
  01:06:45 force-stop master; 01:06:48 `adb install -r fix-12.0.0-prod-release-signed.apk` (same key,
    true in-place upgrade, data preserved) -> versionCode 12000000. 01:06:56 launched (video M3/upgrade-launch.mp4).
  Launch lands on Enter PIN (wallet data kept, no re-onboarding). M3/08-upgrade-launch.png.
  After PIN: the one-time explainer sheet "A one-time sync is needed / DashPay needs to complete a full sync
    before you can send any funds. / Your funds are safe… / This happens only once, after this update."
    with an inline "Syncing 58%" progress bar and a single "Got it" button. M3/10-explainer.png. Shown ONCE.
  wallet.log:
    06:06:57 cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)      <- CUT_OVER reached
    06:06:57 upgrade cutover: one-time sync explainer armed (upgraded-wallet launch)
    06:07:00 L1 shadow SPV started … /l1_shadow_spv/mainnet   (exactly once this launch)
    `starting peergroup` appears exactly once in the whole rolling log, at 05:43:52, i.e. during the MASTER
      run; zero occurrences after the upgrade (verified against the pre-upgrade pull
      M3/master-walletlog/files/log/wallet.log line 305).
    No OverlappingFileLockException anywhere.
  Home retains the master-era tx rows during replay ("Sent −0.0099 / Not available") and balance stays 0.
  Replay memory during the upgrade sync (mem.csv 01:06:56 onwards): 22 MB at launch ->
  526 MB @01:07:26 -> 955 MB @01:09:29 -> PEAK 998,095 kB (975 MB) PSS / 918,084 kB native @01:10:59.
  BlockchainServiceImpl MEM lines agree: 06:08:00 pss=271MB, 06:09:00 pss=697MB, 06:10:00 pss=857MB.

### M3 RESULT — mainnet upgrade path master 11.9.0 -> fix 12.0.0: PASS
  06:06:57 cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)                 PASS
  exactly ONE `L1 shadow SPV started` for this launch (06:07:00)                            PASS
  zero `starting peergroup` after the upgrade (only 05:43:52, the master run)               PASS
  explainer armed + displayed exactly once, dismissed with "Got it"                         PASS
  no OverlappingFileLockException anywhere                                                  PASS
  no `idling detected` while replaying (first one is 06:16:00, i.e. after SYNCED)           PASS
  06:12:09 L1Shadow phase=SYNCED 100.0% headers/filters 2541295/2541295 + SETTLED           PASS
  06:12:09 WalletBalanceFacts total=0 txCount=4 ; UI balance 0 / $0                          PASS
  4 historical tx appearances visible post-upgrade (M3/12-SYNCED-home.png)                  PASS
  TIME: upgrade launch 01:06:56 -> SYNCED 01:12:09 host = 5 min 13 s (full re-scan from 0,
    the 1.2M blocks dashj had already downloaded are not reused).
  KILL + RELAUNCH (01:16:34 force-stop, 01:16:4x relaunch):
    06:16:47 one `L1 shadow SPV started`; 06:16:53 phase=SYNCED 100.0% immediately (resumed
    from watermark, no re-scan); NO second explainer; balance 0, txCount 4, 4 rows visible.
    Evidence M3/14-relaunch-home.png, video M3/relaunch-after-upgrade.mp4.
  MEMORY: peak TOTAL PSS 998,095 kB (975 MB) / native 918,084 kB @01:10:59 during replay;
    584,313 kB PSS / 427,812 kB native after the post-sync relaunch (no replay).
  EXIT-INFO (M3/exitinfo.txt): only my two deliberate force-stops, reason=10 USER REQUESTED.
    No LMK, no OOM kill. Note the recorded RSS at force-stop: fix build 1.1 GB vs master 319 MB.
  VIDEOS: M3/upgrade-launch.mp4 (install -r + first launch + explainer), M3/relaunch-after-upgrade.mp4.

### M4 RESULT — mainnet UI sanity on fix prod: PASS (with findings)
  Home                 M4/01-home.png                  balance 0 / $0, 4 tx rows, no sync pane.
  Receive              M4/02-receive.png               "Dash Address XoJA8qE3N2Y3jMLEtZ3vcN42qseZ8LvFf5"
                                                        -> starts with X (mainnet). BUT this is the already-used
                                                        historical address, not a fresh one — see defect D4.
  Send                 M4/03-send.png, 04, 05, 06      testnet address yRd4FhXfVGHXpsuZXPNkMrfD9GVj46pnjt
                                                        REJECTED with "Not a valid DASH Address or URL request",
                                                        Continue does not advance. Correct.
  Explore              M4/07-explore.png               opens (Where to Spend / ATMs / etc.), no crash.
  Buy & Sell           M4/08-buysell.png               Uphold / Coinbase / Topper / Dash DEX listed +
                                                        expected "Keys are missing for these services" QA-stub banner.
  More                 M4/20-more.png, 20b             Dash Wallet 0.000 Đ, Shielded 0.000 Đ, Tools, Username Voting…
  Settings             M4/09-settings.png              Local currency USD, Rescan blockchain, About Dash,
                                                        Notifications, Battery optimization = Unrestricted.
  Security             M4/13-security.png              View Recovery Phrase / Change PIN / Autohide Balance /
                                                        Advanced Security / Reset Wallet.
  Tools                M4/11-tools.png                 Address book, Import private key, Network monitor,
                                                        Extended public key (BIP44), Masternode keys, CSV export,
                                                        ZenLedger, and "dashj sync (diagnostic)" toggle present and OFF.
                                                        (Toggle NOT touched.)
  Network monitor      M4/12-network-monitor.png       "Synced / Connected to the Dash network",
                                                        Block headers 2,541,297, Block filters 2,541,297,
                                                        Masternode list height 2,541,295, ChainLock height 2,541,295.
                                                        Explicit note: "The wallet engine does not report individual
                                                        peer connections… Turn on dashj sync in Tools to view them."
  About                M4/10-about.png                 App version "12.0.0 (0)"  <- build number renders as (0)
                                                        although the installed versionCode is 12000000 (defect D5);
                                                        Dash Kotlin SDK 0.1.0-v42int19-SNAPSHOT; Platform 4.0.1-SNAPSHOT.
  No purchase, username, send or dashj toggle was attempted. No funds involved at any point.
2026-09-19T01:28:25 S6 complete. REPORT.md written. logcat + memlog stopped.
