# S8 — massive-wallet stream (emulator-5568 / dw-qa8, 2 GB RAM)
Build under test: fix-12.0.0-testnet3-release-signed.apk (versionCode 12000000)
Seed: massive wallet (12 words) from $QA_ROOT/massive-wallet-seed.txt
2026-09-19T01:04:16 logcat-start + memlog(30s) started; evidence /Users/dcg/workspace/dash-wallet-qa/evidence/S8
2026-09-19T01:06:25 L1: grow tx count at restore start = 1200
2026-09-19T01:07:05 PIN 1234 set (restore submitted)
poller pid 24217

## L1 timings (device log clock = host clock + 5h)
- 01:06:27 RestoreWalletFromSeedViewModel "successfully restored wallet from seed"
- 01:06:27 CutoverCoordinator cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup)
- 01:07:05 MAIN_UI_SHOWN (breadcrumb 12, +106528ms from process start)
- 01:07:09 L1 shadow SPV started; phase=CONNECTING 0.0%
- 01:07:40 phase=HEADERS 32.3% headers 994000/1556575  <- first height
- 01:09:54 phase=SYNCED 100.0% headers/filters 1556575/1556575   => restore->100% = 3m27s
- 01:09:56 first l1Synced=true, balance 98979130 duffs
- greps: filter-stall=0, "idling detected"=0, OutOfMemory=0, WalletFileSizeGuard/RISKY/verdict/soft limit=0,
  WalletLoadBudget=0, "starting peergroup"=0, OverlappingFileLockException=0, engine restarts=0
- Only exception in wallet.log: FirebaseException "API key not valid" (stub google-services.json => environment)
- MEM pss= lines: 499MB(01:08) 435 409 420 ; native heap peak 433MB (mem.csv 01:09:49); peak TOTAL PSS 550405 kB (01:08:48)
- mem.csv 01:10:19 shows TOTAL SWAP PSS 348748 kB (heavy swap on the 2 GB AVD) but no LMK kill; exit-info empty.

## L2 (gap limit)
- Explorer POST /insight-api/addrs/utxo over all 800 derived addresses (400 ext + 400 int), 16 batches of 50,
  finished 01:12:42 -> 98,754,950 duffs = 0.98754950 tDASH, 3600 utxos.
- App balance at 01:13 = 0.98755 (6dp display) -> EXACT match. Late addresses confirmed funded:
  ext/399 yN5T8SHRVt62bvNzNZFDc5gTnm1hK3jrr2 bal 0.00093631 (16 txs)
  int/399 yWpsdVYG888aiEP9fGkx6YViMyTVkJ7Dv9 bal 0.00017488 (13 txs)
  ext/398 yjJVQba2CgJm8Mb1wCwS2LFg5Y57sCnAH5 0.00025227 ; int/398 yPziqjNtTFq8HJ2zZSFZGab8MHQK2WL1fd 0.00073476
  => no gap-limit shortfall.

## L5 sizes (01:13)
- files/wallet-protobuf-testnet = 15,322 B (legacy dashj file, effectively empty post-cutover)
- files/key-backup-protobuf-testnet = 15,328 B
- databases/dash-sdk.db = 5,332,992 B (+ wal 524,288)
- databases/dash-wallet-database = 466,944 B (+ wal 453,232)
- files/shielded_tree_testnet.sqlite = 200,704 B (+ wal 4,120,032)
- files/l1_shadow_spv = 489,840 kB (~478 MB): blocks 204,528 kB, block_headers 175,240 kB,
  filter_headers 50,184 kB, filters 59,724 kB
- No WalletFileSizeGuard / autosave / soft-limit / verdict lines at all in wallet.log.

## DEFECT CANDIDATE (S8-D1): 111 SDK transactions have no UI display row; the 1 tDASH funding receive is invisible
- 01:17:36-01:20:29, all counters quiescent (grow script paused at txs=1600):
  dash-sdk.db transactions = 1601 (= 1600 grow txs + 1 funding tx)  -> SDK has every tx
  dash-wallet-database tx_display_cache = 1490                      -> UI list source is 111 short
- txid diff (SDK txid is stored byte-reversed): 111 in SDK and not in display, 0 the other way.
  List: evidence/S8/L1/missing-from-display-cache.txt
- All 111 missing rows: transactionType=Standard, context=2, blockHeight 1556555..1556571
  (the historical replay range). 110 direction=2, 1 direction=0.
- The single direction=0 one is 747cb55cc55b8e0b8d8bc8d422fa8fd87e608fd2deff91078e2df361e5d4122e
  netAmount=+100000000 duffs = the wallet's ONLY incoming transaction (the 1 tDASH that funds
  the whole wallet). Explorer: block 1556555, time 1789795129 (00:18:49).
- `select ... from tx_display_cache where valueSatoshis > 0` returns ZERO rows: the app's history
  contains no incoming transaction at all.
- UI confirmation: evidence/S8/L1/scroll/swipe-0170.png — bottom of the list is Internal −0.000015
  rows at 12:18 AM; no "+1.00" receive row anywhere.

## S8-D1 ROOT CAUSE (isolation for orchestrator)
wallet.log 06:09:54 (= host 01:09:54), evidence/S8/L1/logs-isolation/files/log/wallet.log:927-929
  L1ShadowSyncService - WalletHistoryFacts: oldestTx=...height=1556555 count=1021
  L1ShadowSyncService - WalletBalanceFacts: total=98980110 ... txCount=1132
  TxDisplayCacheService - Sync complete (cutoverCommitted=true): SDK=1010 records | dashj wallet=0 txs |
      group cache=0 txs/0 groups | display=1021 rows — cache is complete (SDK holds 1010 records, display has 1021 rows)
  => engine txCount 1132 - display 1021 = 111 = the EXACT permanent deficit.
  The reconcile declares completeness because display(1021) >= its own "SDK records"(1010) count, which is
  smaller than the engine's real tx count (1132). It never backfills.
Same shape on every relaunch, e.g. 06:32:29 "SDK=1817 records ... display=1828 rows — cache is complete"
  while the real dash-sdk.db transactions count was ~1928 at that moment.

(a) Does anything repair it?
  5-min quiescent wait   : NO (delta 111 at 01:23:01 / 01:23:41 / 01:24:21 / 01:25:01)
  bg 70 s -> fg          : NO (01:28:03 before=111, 01:29:13 during=111, 01:29:38 after=111)
  force-stop + relaunch  : NO (01:32:52 display=1890 sdk=2001 delta=111)
(b) evidence/S8/L1/planner-log.txt + evidence/S8/L1/txdisplaycache-lines.txt.
  "LN tx-event buffer full; dropped Detected/InstantLocked (Room snapshot will reconcile)" occurs 204x
  (61 Detected + 143 InstantLocked, 147 distinct txids) but NONE of those txids are among the 111 missing
  -> the buffer-drop path really does reconcile; it is NOT the cause.
  Per-batch "cutover UI display sync: N SDK records -> M inserts" shows the shortfall
  (439->439, 278->272, 272->266, 35->33, 385->11, 115->54, 171->56); summed 2254 records -> 1690 inserts.
(c) Distribution: evidence/S8/L1/missing-by-height.txt. All 111 are in the historical replay window
  (heights 1556555-1556571); heights 1556573+ (arrived live) are 100% complete.
  1556555:10/16 missing, 1556557:2/14, 1556560:36/141, 1556561:3/27, 1556564:29/200, 1556566:17/200,
  1556570:1/15, 1556571:13/180, and 0 missing for 1556558,1556562,1556569,1556573..1556580.
  Not "first N per block" - it is scattered within each block (positions 0..795 of 1601 in firstSeen order).

## L5 extra
- Device largeHeap = 576 MB (dalvik.vm.heapsize), normal heap 192 MB
  => WalletFileSizeGuard soft limit = min(576MB/10, 100MB) = 57.6 MB; hard limit 2,000,000,000 B.
- Legacy dashj file is 15,322 B with 0 txs, so verdict = NORMAL and NOTHING is logged (by design:
  WalletApplication.java:1195-1199 only logs when verdict != NORMAL).
- No "wallet autosave debounce raised to ..." line either => autosave stays at the default
  Constants.Files.WALLET_AUTOSAVE_DELAY_MS (5 s). Observed autosave: 12.94 ms / 15,322 bytes.
- OBSERVATION: post-cutover the size guard and the autosave debounce both key off the (now empty) dashj
  protobuf, so neither covers the stores that actually grow on this wallet:
  dash-sdk.db 5.3 MB -> growing, shielded_tree wal 4.1 MB, l1_shadow_spv 478 MB.

## L3 live growth (10 min watch, 01:16:08 - 01:25:25, evidence/S8/L3/live-watch.log)
- New self-transfers appear live: at 01:25:25 UI top rows 1:23 AM, UI balance 0.984223 == log
  "SDK balance published: 98422250 duffs". Every sample where the app was unlocked matched the log
  balance to the 6th decimal.
- Log shows the instant-receive path working: "L1 engine tx event: Detected(...)" ->
  "engine detected tx <txid> pre-block (context=0, net=... duffs) — syncing display row now" ->
  "cutover UI display sync: 1 SDK records → 1 inserts" -> "STARTUP submitData called on thread=main".
  InstantLocked events follow.
- Memory trend over the watch: TOTAL PSS 400-431 MB, flat, no growth. SWAP PSS ~205 MB throughout.
- 0 "idling detected", 0 "filter-stall", 0 restarts, 0 OutOfMemory during the watch.
- CAVEAT (known D-001): the app auto-locked at ~01:17:13 after 60 s without touch and stayed on the
  Enter-PIN screen until 01:22:48 (evidence/S8/L3/watch-04/08/12.png). Sync and balance publishing
  continued behind the lock screen (log balance kept advancing), so no data was lost.
2026-09-19T01:35:59 ENV: logcat stream died at 01:07:33 (adb root from qa-app.sh grep-log/files restarts adbd and kills the logcat pipe). Restarted as logcat-part2.txt. Kernel/AMS coverage for 01:07-01:36 therefore comes from 'dumpsys activity exit-info' (clean) instead.

## S8-D1 FULL ROOT CAUSE (source + live DB proof)
Chain:
1. The display-cache pipeline enumerates SDK records through SdkTxStoreWalker, which walks the
   **`txos`** table, not `transactions`
   (CutoverUiDataService.kt:1361-1387 `currentWalletRecordCount`, SdkTxStoreWalker.kt:41-53):
     SELECT COUNT(*) FROM (
       SELECT t.txid       FROM txos t  WHERE t.walletId=? AND t.txid IS NOT NULL       AND NOT (foreign)
       UNION
       SELECT t2.spendingTxid FROM txos t2 WHERE t2.walletId=? AND t2.spendingTxid IS NOT NULL AND NOT (foreign))
2. TxDisplayCacheService.decideCacheRebuild (TxDisplayCacheService.kt:1704-1723) reconciles only when
   `sdkRecordCount > displayRowCount`, and `sdkRecordCount` is that SAME txos-union number.
3. So any transaction with no `txos` row is invisible to BOTH the writer and the checker: it never gets a
   display row, and the checker still reports "cache is complete". Self-consistent blindness.
Live proof on the device (01:38, dash-sdk.db):
  transactions            = 2190
  txos-union (the count)  = 2079      -> under-counts by 111
  ALL 111 missing display rows are exactly the txids absent from the txos union
  (missing − txo_union = 111, missing ∩ txo_union = 0).
  `select count(*) from txos where hex(txid)=<funding txid wire order>` = 0
  -> the +1 tDASH funding tx has no TXO row at all, which is why the history has no receive row.
  txos: 7268 total (2715 spent, 4553 unspent).
Interpretation: the restore replay materialises TXO rows for outputs it can still see, but the
transactions whose outputs were already spent before/while the replay window was walked leave no txos
row, so they drop out of the UI permanently. The class of tx affected is "historical, fully-spent" —
on a real user's wallet that is most of their old history, including old receives.

## L4 (kill/relaunch, background, low memory, force-stop)
Kill -> relaunch (01:29:51 force-stop, 01:32:24 launch; the 01:29:54 monkey launch landed on the launcher,
so the timed launch is the am-start one):
  PROCESS EXIT REASON: USER_REQUESTED(10) FORCE_STOP, rss 310 MB at death
  breadcrumbs: WALLET_LOAD_BEGIN +17ms size=15322 -> wallet loaded 244.1 ms -> MAIN_UI_SHOWN +903ms
               SDK_L1_ENGINE_STARTED +3974ms; NO WalletLoadBudget over-budget warning
  Sync complete check re-ran: "SDK=1817 records ... display=1828 rows — cache is complete" (still wrong)
Background 10 min (01:33:47 -> 01:44:23, evidence/S8/L4/bg-watch.log, 21 samples):
  process never died (pid 12930 throughout), PSS 418-448 MB flat, SWAP PSS ~370 kB
  the SDK kept ingesting in the background (sdk 2001 -> 2383) and kept writing display rows
  (1890 -> 2272); delta pinned at 111 the whole time. 0 "idling detected", 0 filter-stall, 0 restarts.
Low memory while foreground (01:45:49):
  `am send-trim-memory ... RUNNING_CRITICAL` #1 succeeded; #2 and #3 were rejected by AMS with
  "Unable to set a higher trim level than current level" (harness limit, not a product defect);
  `COMPLETE` rejected with "Unable to set a background trim level on a foreground process".
  App log: "BlockchainServiceImpl - onTrimMemory(15) called" then
           "BlockchainServiceImpl - memory pressure (onTrimMemory level 15), stopping service"
  -> the service announces a stop under pressure, but the L1 engine kept running
     (L1Shadow phase=SYNCED again at 01:46:44 and 01:47:28) — same latched-stop shape as D-004/SR-09.
  PSS 434 -> 423 MB after the trim. Process survived (same pid).
Force-stop + relaunch (01:47:41 -> 01:47:46):
  MainActivity focused after 3 s; wallet loaded 302.6 ms; MAIN_UI_SHOWN +768ms;
  SDK_L1_ENGINE_STARTED +3068ms; "Sync complete ... SDK=2279 records ... display=2290 rows — cache is complete"
exit-info after everything: exactly two entries, both reason=10 USER_REQUESTED / subreason=21 FORCE_STOP.
NO LMK kill at any point on the 2 GB AVD. logcat shows no lowmemorykiller/lmkd/am_kill lines.

## L7 (Send screen, FORBIDDEN to actually send — never confirmed)
(a) DURING replay (01:08-01:10, balance published 98980110 duffs but l1Synced=false):
    Send > Send to Address > <own ext-0 address> > Continue
    -> header "Balance: DASH 0.00 ~ $ 0.00", amount field "0", and a blocking error
       "Currently payments are not possible because the wallet is not fully synced with the network".
       Tapping Max did nothing (amount stayed 0). SR-32's "publishes the untrusted partial on the send
       screen" did NOT reproduce here — the send screen showed 0.00 and refused. PASS (safe behaviour).
       Evidence: L7/02,03,04,05,06.
    NOTE for D-002/SR-10: the HOME header did show the moving partial during replay
    (persistedAsLastKnown=false lastKnown=0 on a restored wallet, so there is no last-known to hold).
(b) AFTER 100% (01:48-01:50): Max produces an amount ABOVE the balance shown on the same screen:
       01:48:5x  balance DASH 0.9786871   Max -> 0.9787372  -> red "Insufficient funds"
       01:49:35  balance DASH 0.9783779   Max -> 0.9784199
       01:49:44  balance DASH 0.9782446   Max -> 0.97832
       01:49:52  balance DASH 0.9781366   Max -> 0.9782185
    i.e. Max = (an older balance snapshot) − 0.0001 flat reserve (confirms SR-28/D-032's flat reserve),
    and on a wallet whose balance is moving it is always stale-high. After the first attempt the log
    reports "executeDryRun finished (cutover-aware: SDK send-all / drain)" and
    "blockContinue = false, dryRunSuccessful = true", i.e. the app would let the user proceed with an
    amount larger than the balance it is displaying. NOT sent (forbidden).
    Evidence: L7/11,12,13.

## Rescan blockchain (orchestrator request: does it repair the display cache?)
01:50:46 PRE-RESCAN display=2490 sdk=2601 delta=111 (missing set saved: L1/missing-pre-rescan.txt)
01:50:59 More > Settings > Rescan blockchain > "Rescan" (no creation date)
01:51:01 log: "DashSdkServiceImpl - armSpvRescan: filter watermark rewind to 0 armed on cd7eac70…"
         "SdkWalletBinder - blockchain-reset rescan arm on cd7eac70…: armed=true"
During the rescan the home header shows "Syncing balance" over the HELD last-known balance
(0.979288) and the transaction list is NOT emptied — the dialog text promises
"This will temporarily hide your wallet balance and remove transactions", so the copy does not match
the behaviour (minor, S4). Evidence: L1/rescan-01..04.
RESULT: Rescan blockchain PARTIALLY repairs it and then re-latches.
  01:50:46 pre-rescan  display=2490 sdk=2601 delta=111
  01:53:23 phase=SYNCED 100% (rescan took ~2 min 22 s)   display=2554 sdk=2601 delta=47
  delta then stays at 47 (01:53:53 .. 01:56:54, while the wallet keeps growing).
  Set analysis (L1/missing-post-rescan.txt vs L1/missing-pre-rescan.txt):
    recovered by the rescan : 64
    still missing           : 47  (all 47 are a subset of the original 111; 0 newly missing)
    funding tx 747cb55c…    : STILL MISSING
    `select count(*) from tx_display_cache where valueSatoshis>0` = 0  -> still no receive row at all
  Same mechanism post-rescan: transactions=2801, txos-union=2753, and all 47 missing rows are exactly
  the txids absent from the txos union (47 absent / 0 present).
  The completeness check re-latched at 01:53:17: "SDK=2479 records ... display=2490 rows — cache is complete".
=> Rescan is NOT a workaround for D-037; it recovers some rows and permanently leaves the rest.

## L8 CSV export + Network monitor
Network monitor (More > Tools > Network monitor), 02:00, evidence/S8/L8/06-network-monitor-peers.png:
  "Synced / Connected to the Dash network", Block headers 1,556,595, Block filters 1,556,595,
  Masternode list height 1,556,595, ChainLock height 1,556,595.
  "The wallet engine does not report individual peer connections. Peer and block lists come from the
   dashj diagnostic engine. Turn on dashj sync in Tools to view them." (expected post-cutover)
CSV export (More > Tools > CSV export > Export transactions), 02:00:13:
  at that moment display=2753 rows, sdk=2801 transactions.
  Result: share sheet for "dash-wallet-transactions-2026-09-19.csv", and the file is
  /data/data/<pkg>/cache/report/dash-wallet-transactions-2026-09-19.csv = 201 bytes, 1 line:
  the HEADER ONLY, zero data rows. Pulled to evidence/S8/L8/dash-wallet-transactions-2026-09-19.csv.
  log: "ExportCSVDialog - invoked chooser for exporting transaction history" (no warning, no error).
  Cause (source): CSVExporter.exportString (CSVExporter.kt:46-72) skips every tx where
  `excludeInternal && isInternal(tx) && opReturnBurnDuffs(tx) == 0L`. This wallet is 100% entirely-self
  transfers, so every row is skipped — defensible for a TAX export. The defect is the guard:
  ToolsViewModel.exportCsv (ToolsViewModel.kt:185-226) only tests `transactions.isEmpty()`, and
  ExportCSVDialog.kt:109-111 states "Never hand back a header-only file silently" — but the emptiness
  test is on the INPUT list, not on the produced row count, so a header-only file IS handed to the
  share sheet silently. Suggested fix: test the generated content for >0 data rows.
  Note: the one transaction that WOULD be exportable (the +1 tDASH Income row) is absent because of
  D-037, so even with the guard fixed this wallet exports nothing.

## L6 second restore (reset + restore, grow had risen 1200 -> 3000 since L1)
02:02:05 pre-reset: grow=2879 display=2828 sdk=2876 delta=48
02:03:23 More > Security > Reset Wallet > "Reset wallet"  — NO PIN prompt at any step (matches D-012)
02:03:25 log: "wallet-wipe SDK cleanup for wallet cd7eac70: stopping shadow + shielded sync, removing the
         SDK wallet (full cascade), deleting the SPV dataDir, clearing the binder latch" then
         "wallet-wipe SDK cleanup complete"
02:03:59 "successfully restored wallet from seed"; cutover DUAL_RUNNING -> CUT_OVER
02:04:32 L1 shadow SPV started
02:07:11 L1Shadow phase=SYNCED 100.0% headers/filters 1556597/1556597
   => restore -> 100% = 3 m 12 s  (L1 was 3 m 27 s) on a wallet 2.6x bigger (3001 vs 1132 txs).
   The whole 1.55 M-block filter chain was re-downloaded (the wipe deletes the SPV dataDir).
Memory: peak TOTAL PSS 560,707 kB at 02:05:11 (L1 peak 550,405 kB), native heap peak 405,216 kB
   (L1 405-433 MB). App log MEM pss=571MB nativeHeap=372/422MB jvm=90/576MB at 02:07:00.
   ReplayMemTelemetry at SYNCED: nativeHeapAllocated=496,131,664 nativeHeapSize=601,378,816
   jvmUsed=43,938,752 jvmMax=603,979,776. No OOM, no LMK — exit-info still only the 2 force-stops.
Greps: filter-stall 0, "idling detected" 0, OutOfMemory 0, WalletFileSizeGuard/RISKY 0,
   "wallet load ... OVER budget" 0.
BALANCE, exact: app 0.974441 tDASH (log "SDK balance published: 97444140 duffs"); the grow script had
   finished ("done: 3000 txs", "periodic rescan: 5204 utxos"), so the wallet is static.
   Explorer POST /addrs/utxo over all 800 derived addresses (evidence/S8/L2/explorer-utxo-sum-final.txt)
   = 97,444,140 duffs over 5,204 utxos -> difference 0 duffs, utxo count matches the grow log exactly.
   L2 PASS (no gap-limit shortfall through index 399 on both chains).

### D-037 after the SECOND restore: NOT deterministic, and much worse
02:07:11 "Sync complete ... SDK=2534 records | display=2543 rows — cache is complete" while
         WalletBalanceFacts in the same second reported txCount=3001.
02:10:10 and 02:10:40: display=2543 sdk=3001 delta=458 (stable; wallet static)
  L1 (1132 txs)                     : 111 missing  ( 9.8 %)
  after Rescan blockchain           :  47 missing
  L6 second restore (3001 txs)      : 458 missing  (15.3 %)
  Missing-set overlap: only 65 of the original 111 are in the new 458; 393 are new; 15 of the 47
  post-rescan survivors are in it. => the set is RACY/size-dependent, not deterministic.
  Mechanism identical: all 458 are exactly the txids absent from the txos union (458 absent, 0 present).
  The +1 tDASH funding receive is missing in BOTH restores, and
  `select count(*) from tx_display_cache where valueSatoshis>0` = 0 again.
  Visual: evidence/S8/L6/08-txlist-bottom-no-receive.png — oldest rows are Internal −0.000015 at
  12:18 AM, no receive row anywhere.
  Files: evidence/S8/L6/missing-after-second-restore.txt (458 txids).
