# S7 QA journal (emulator-5566 / dw-qa7)
Stories: E8 (fresh small wallet master 11.9.0 -> fix 12.0.0), B5 (dashj toggle), R1 (rescan), BK1 (backup/restore file), TX1 (tx list/detail), N1 (notifications)

- 2026-09-19T00:22:36 logcat -> evidence/S7/logcat.txt (pid 17767), memlog -> mem.csv 60s (pid 17837)
- 2026-09-19T00:22:40 installed master 11.9.0 (11090002)
- 2026-09-19T00:26 E8: created wallet on master 11.9.0. SEED (throwaway testnet): `air pet hole injury snack toast end share seven cute ghost squirrel`  PIN 1234
- 2026-09-19T00:28:05 E8 receive addr #1: yLRHLPYFiRXPQPm2CaD5AsifEfqpYbSRKo (evidence/S7/E8/14-master-receive.png)
- 2026-09-19T00:29:36 E8 faucet sent 1 tDASH, txid aa57902d1c5547d48cabe6d674babe10b728ab1262f6564bfcca1a6ec7b1bb33 (evidence/S7/E8/15-faucet-sent.png)
- 2026-09-19T00:33:34 E8 master: received 1.00 tDASH, memo 'S7-faucet-memo' saved (25-master-txdetail-memo.png)
- 2026-09-19T00:34:00 E8 receive addr #2 (rotated after use): yMahoHJCR7ZGztjQwxZ7FZpBEMDdnTpRjh
- 2026-09-19T00:36:32 E8 master: sent 0.05 to own addr2; self-send shown as 'Amount Sent -0.00000227' (fee only), change yg6CfcF5yBA9eNaJGgrczqEGLxcAAyJiSq
- 2026-09-19T00:42 E8 master baseline captured:
  - balance 0.999998 tDASH (EUR 53.31), txs: Internal 12:36 (self-send 0.05, fee 0.00000227), Received 12:29 +1.00 memo "S7-faucet-memo"
  - faucet txid aa57902d1c5547d48cabe6d674babe10b728ab1262f6564bfcca1a6ec7b1bb33 ; self-send txid 1a1dac75452c890f0c976a000315cfd96a702feded36e2d57f7828340c3a330a (both confirmed per insight)
  - settings: local currency EUR, hide-balance ON, notifications allowed
  - prefs last_version=11090002, best_chain_height_ever=1556564, wallet-protobuf-testnet 274,663 bytes
  - logs: E8/pre-upgrade/files/log/wallet.log, E8/pre-upgrade/prefs-master.xml
  - mem master pre-upgrade: TOTAL PSS 186776 KB, Native 29364, Dalvik 36140
  - OBSERVATION (master): first attempt at setting local currency to EUR showed "EUR" in Settings but reverted to USD after app relaunch (datastore still USD). Second attempt persisted. Master-only, not reproduced -> noted, low severity.
- 2026-09-19T00:42:17 E8 reinstalled fix 12.0.0 (12000000) in place
- 2026-09-19T00:45 E8 post-upgrade assertions (wallet.log lines 3715-3947 of E8/post-upgrade/files/log/wallet.log):
  - 05:42:20 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)  [exactly 1]
  - 05:42:24 L1ShadowSyncService - L1 shadow SPV started ... [exactly 1]
  - "starting peergroup" occurrences after 05:42: 0 (3 earlier ones are the master build)
  - explainer "A one-time sync is needed" shown once (56-fix-explainer.png); armed line 05:42:20
  - OverlappingFileLockException: 0 occurrences
  - "wallet file size guard" log line: 0 occurrences -> verdict NORMAL (not RISKY). Wallet file 274,663 B vs soft limit min(heap/10,100MB)
  - 05:42:49 L1Shadow phase=SYNCED 100.0% headers 1556564/1556564 filters 1556564 wallet 1556564 SETTLED (29 s after launch)
  - balance identical: master 0.999998 / SDK 99999773 duffs; tx list identical (Internal 12:36, Received 12:29 +1 memo S7-faucet-memo)
  - local currency EUR persisted (€53.31); PIN 1234 still works
  - NOTE: home "tap to hide balance" is a session-scoped toggle in BOTH builds (datastore has no hide_balance key after it is used); the persisted setting lives in More > Security. Tested separately.
- 2026-09-19T00:49:26 E8 fix: sent 0.01 to own addr3 yMwdDaL2Ttje2uWJiDTjoV6x4fYxNUt5QM. Confirm sheet showed Network fee 0.0001 / Total 0.0101, but the resulting tx fee was 0.00000226 (screenshots 64-fix-send-confirm.png vs 66-fix-selfsend-detail.png). Master showed the exact fee (0.00000227) on its confirm sheet.
- 2026-09-19T00:50 E8 step 5: sent 0.01 on the FIX build post-cutover (SDK send path). txid 65953a637494d70b30b4279314267f874751012c4e2be3f28e2bf246313d1cb7 (confirmed on insight). Balance 0.999998 -> 0.999995. Detail shows "Amount Sent -0.00000226" (correct direction for a self-send).
- 2026-09-19T00:50 kill + relaunch OK: no second explainer, no "starting peergroup", L1 shadow SPV started once per process, L1Shadow phase=SYNCED 100%, TxDisplayCacheService "cache is complete (SDK holds 3 records, display has 3 rows)".
  BUT persisted cutover_state is still CUT_OVER, not SETTLED. Source check: CutoverAction.SETTLE is never dispatched anywhere in wallet/src (only OBSERVE_READINESS and COMMIT_CUTOVER are, in CutoverCoordinator.kt:142/151), so CutoverState.SETTLED is unreachable in the shipped app. No functional impact (dashjEngineMayStart(CUT_OVER)==false and every "committed" predicate accepts CUT_OVER||SETTLED) but the documented state machine never crosses its horizon.
- 2026-09-19T00:56 B5 dashj diagnostic toggle (fix build, Tools):
  - before: Network monitor "Synced", headers/filters/mnlist/chainlock 1,556,570, hint "Peer and block lists come from the dashj diagnostic engine. Turn on dashj sync in Tools to view them." (B5/02-netmon-before.png)
  - tapping the switch opens "Sync from date" dialog: [Start sync from date / Sync everything (from the beginning) / Cancel] (B5/05, B5/07)
  - Cancel -> toggle stays OFF, no peergroup started (B5/06-after-cancel.png, peergroup count unchanged at 3)
  - Confirm "Start sync from date" -> 05:53:42 "dashj-sync-diagnostic toggle -> true; re-resolved dashjEngineMayStart=true"; 05:53:42 "starting peergroup"
  - Network monitor then lists peers (Dash Core 23.1.8, protocol 70240, latency) and blocks (B5/09, B5/11)
  - 05:54:26 parity MATCH: sdk=99999547 dashj=99999547 confirmed both, tx sdk=3 dashj=3  <-- independent confirmation the SDK seam matches dashj
  - toggle OFF -> 05:56:28 "dashj-sync-diagnostic toggle -> false"; 05:56:28 "stopping peergroup"
  - memory: dashj OFF TOTAL PSS 287,039 KB (Dalvik 19,696); dashj ON 301,266 -> 308,654 KB (Dalvik 28,552 -> 33,380); OFF again 298,478 KB (Dalvik 26,476). Delta ~ +15-22 MB PSS, ~ +9-14 MB Dalvik.
- 2026-09-19T01:03:49 SR-03: fix build receive address DID rotate after use: addr3 yMwdDaL2Ttje2uWJiDTjoV6x4fYxNUt5QM (received 0.01) -> reopening Receive shows fresh yhyt2iGA2rKEQNDRUV5GPGS6cj8QAyeMAC (evidence E8/60-fix-receive-addr3.png vs TX1/SR03-01-fix-receive-after-receive.png)
- 2026-09-19T01:05-01:11 Orchestrator static-review checks (fix build):
  SR-03 PASS on this upgraded wallet: receive address rotates. addr3 yMwdDaL2Ttje2uWJiDTjoV6x4fYxNUt5QM received 0.01; reopening Receive gave a fresh, zero-history yhyt2iGA2rKEQNDRUV5GPGS6cj8QAyeMAC (insight: 0 txAppearances). Evidence E8/60-fix-receive-addr3.png, TX1/SR03-01-fix-receive-after-receive.png.
  SR-28 CONFIRMED: confirm sheet always shows a flat "Network fee 0.0001". Actual fees charged: 0.00000226 (0.01 send) and 0.00000976 (send-all) -> the sheet overstates the fee 10x-44x. Evidence E8/64-fix-send-confirm.png vs E8/66-fix-selfsend-detail.png; TX1/SR29-03-confirm-sheet.png vs TX1/SR29-12-sendall-detail.png. Master 11.9.0 showed the exact fee (0.00000227) on its confirm sheet (E8/35-master-send-confirm-sheet.png).
  SR-28b: entering (balance - 0.00005) is IMPOSSIBLE - the amount field silently CLAMPS to balance-0.0001 (0.99989547) as soon as the typed value exceeds it. No "insufficient funds" error is shown; the 0.0001 flat reserve is simply unspendable via manual entry. Evidence TX1/SR28-02/03. The "Max" button, by contrast, fills the FULL balance 0.99999547 (inconsistent with manual entry) and the drain path subtracts the fee later.
  SR-29 CONFIRMED: send-all first attempt FAILS then retries. wallet.log 06:11:28 "SDK l1SendAll: floor 99998764 duffs not deliverable at fee; retrying engine-authoritatively" + DashSdkError$PlatformWallet$CoreInsufficientFunds "available Some(99999547), required Some(99999740)"; 06:11:29 "SDK l1SendAll: broadcast 99999547 duffs ... txid 065a166e7dcdb2df96c285afd746f45e70bfe89f2fdedffec4fbe2d30e075927". User-visible outcome is success.
- 2026-09-19T01:07 NEW DEFECT (S2): after "idling detected, stopping service" tears down the L1 shadow engine, EVERY send fails with "Problem sending coins! Currently payments are not possible because the wallet is not fully synced with the network". wallet.log 06:07:00 "idling detected, stopping service" + "L1ShadowLifecycle STOPPED ... Nothing runs until the next startIfEnabled()"; 06:07:03 / 06:08:25 / 06:09:xx SendEngineNotSyncedException "L1 funding gate closed: SDK L1 engine not running". Retrying in place never recovers (3 attempts, 0.01 and send-all alike). Recovery required backgrounding + re-foregrounding the app: 06:10:17 "L1ShadowLifecycle RESUMING after 3m17s down". Evidence TX1/SR29-05, -07, -08, -09.
- 2026-09-19T01:17:27 SR-03 extra: Receive tab handed out ye3YgWymGiW4CXrBFbFEVKmfpwMXC8nqWm; 'Specify Amount' then handed out a DIFFERENT fresh address yYgceVZFcnUVRC9Y3nd2cuZEc4rwDCAGAR (both zero-history). Evidence N1/01-receive-addr5.png, N1/03-specify-amount-qr.png
- 2026-09-19T01:14-01:22 TX1 results (fix build):
  - Filter: All / Sent / Received / Gift cards. "Received" shows only the faucet receive (self-sends are NOT announced as receives) - correct. "Sent" shows an EMPTY list with NO empty-state text (master showed "There are no transactions to display"); the 4 self-sends are classified "Internal" and excluded from "Sent". Evidence TX1/03-filter-sent.png, TX1/04-filter-received.png.
  - Pull-to-refresh: swipe down on the list produced no visible refresh indicator; list/balance stayed correct. TX1/06-pull-to-refresh.png
  - Tx detail receive: "Amount Received +1.00", memo persisted, Tax Category Income. TX1/07.
  - Tx detail self-send: "Amount Sent -0.00000226", "Moved from"/"Internally moved to" - direction correct. TX1/12.
  - Explorer link: opens a "Select block explorer" sheet (Blockchair / Insight); Insight launches Chrome. TX1/08, TX1/09.
  - Copy txid / share: NOT PRESENT in this build. Verified in source: no ClipboardManager and no Intent.ACTION_SEND in TransactionDetailsDialogFragment.kt or TransactionResultViewBinder.kt. The only share affordance is Receive > "Share Address".
  - DEFECT (S4): tx detail duplicates every input and output address row (1 input shown twice, 2 outputs shown 4 times). TX1/13-duplicate-address-rows.png
  - DEFECT (S4): list vs detail timestamp mismatch for the same tx - list row says "12:30 AM", detail says "September 19 at 12:29 AM" (TX1/06 vs TX1/07). List timestamps also shifted by a few minutes after the R1 rescan (12:29->12:30, 12:36->12:40).
- 2026-09-19T01:19-01:21 N1 notifications (fix build):
  - Notification permission granted at onboarding; shade captured with a real wallet notification. N1/06-notification-shade.png, N1/07-notification-expanded.png
  - Initiated a 0.01 send to my own address and backgrounded immediately: the payment broadcast fine (06:19:51 "SDK l1Send: broadcast 1000000 duffs to ye3YgWym..., txid c178a892b31d0908286c841949c66da9814bc94bb0266ec88569c32c53e184d8") and NO receive notification was posted - log 06:19:51 "tx c178a892... was authored by this wallet - not a receive, no notification". That is the CORRECT behaviour, so the self-send trick cannot produce a receive notification. N1 receive-notification-from-a-third-party remains untested (no second wallet, faucet quota used).
  - DEFECT (S3): duplicate/stale receive notification. The faucet receive (05:29) was already notified at the time; after the R1 rescan the app re-notified it - 06:04:46 "CutoverUiDataService - SDK-discovered receive aa5790... (100000000 duffs) - notifying" - and the shade showed "Received DASH 1.00" timestamped 15m (i.e. 35 min after the actual receive). N1/07.
- 2026-09-19T01:22 BK1 pre-reset state: balance 0.999983 tDASH / EUR 52.22, 5 txs (4 Internal + Received 1.00 with memo). BK1/02-pre-reset-home.png. Logs: BK1/pre-reset/files/log/wallet.log
  - Security screen has NO "Backup wallet"/file-backup entry on this build (R1/01-security.png): View Recovery Phrase, Change PIN, Autohide Balance, Advanced Security, Reset Wallet only.
