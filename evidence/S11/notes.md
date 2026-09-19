# S11 notes (emulator-5566 / dw-qa7)

Stream S11. Goal: SDK replay memory on real-history wallet under constrained conditions;
confirm/deny D-041 (inflated balance after kill during replay) and D-037 (historical fully-spent
txs missing from history) on the reference seed (READ-ONLY).
Reference seed: job flower agree lyrics industry note boost finger buddy dog exact fat
Expected balance 107.08173522 (per D-014; the brief constant 107.43173749 is stale).

## Journal
2026-09-19T01:50:12 S11 start; device check
2026-09-19T01:50:29 P1: installing fix APK clean
2026-09-19T01:53:07 P1: seed entered, submitting
2026-09-19T01:53:36 P1: PIN set (T0=2026-09-19T01:53:36)
2026-09-19T01:54:28 P1: PIN confirmed, restore starting
2026-09-19T01:55:14 P1: restore complete, sync clock T0 starts
2026-09-19T01:56:11 poll1  
2026-09-19T01:57:00 poll2  
2026-09-19T01:57:50 poll3  
2026-09-19T01:58:40 poll4  
2026-09-19T01:59:29 poll5  

## P1 baseline (3 GB, clean install fix APK, reference seed)
- 06:52:16 app first start (wallet.log device clock = host +5h00)
- 06:53:10 cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))
- 06:54:17 armSpvRescan: filter watermark rewind to 0 armed
- 06:54:21 L1 shadow SPV started (phase=IDLE 0.0%)
- 06:58:52 phase=SYNCED 100.0% headers 1556595/1556595 filters 1556595 wallet 1556595 SETTLED
  => engine start -> 100%: 4 min 31 s ; restore(CUT_OVER) -> 100%: 5 min 42 s
- Final `SDK balance published: 10708173522 duffs` = 107.08173522  == EXPECTED. PASS.
- 0 `starting peergroup`, 0 filter-stall, 0 idling detected during replay, 0 OverlappingFileLockException.
- Peak TOTAL PSS 610,373 kB (596 MB) @01:58:24 host; peak Native Heap 468,360 kB (457 MB); peak Dalvik 40,291 kB.
  Idle after sync: PSS ~465 MB / native ~311 MB. exit-info: EMPTY (no process death) -> P1/exitinfo.txt
- D-001 auto-lock reproduced again: app locked to Enter PIN during the unattended sync poll (P1/10-sync-poll5.png).
- D-002 reproduced: during replay header showed 156.405901 tDASH under "Syncing balance" (P1/09-home-start.png).

### P1 DB counts (P1/db/db-counts.txt)
- dash-sdk.db transactions                      = 3269
- txos-union (txid UNION spendingTxid)          = 2396   (873 transactions have NO txos row)
- dash-wallet-database tx_display_cache          = 1519
- tx_display_cache valueSatoshis > 0             = 397
- titles: Sent 722, Received 391, Internal 354, Mixing Transactions 51, Upgrade Fee 1

### P1 explorer cross-check (first 20 BIP44 m/44'/1'/0'/0/i receive addresses)
- insight txApperances per address: P1/insight-addr-summary.txt (sum 273 appearances)
- distinct txs touching those 20 addrs = 236; pure INCOMING (no input of ours) = 166
- of the 166: 0 missing from dash-sdk.db transactions, 41 missing from the txos-union,
  2 missing from tx_display_cache  -> D-037 mechanism reproduced, small blast radius here
  * 30d25cfa437dc80b83c3f4cda912e466c5c5d9144679d0bedfe3a174bd9c5a16 h1123983 2024-10-19 07:21:52 +0.20000000
  * 301d24c9ab71b31d745188d31642925a8b09ea8e8a6b662a1398b3b2b954ce12 h1123983 2024-10-19 07:21:52 +0.33848582
  both present in `transactions`, both ABSENT from the txos-union => exactly D-037's root cause
- whole-wallet: 399 SDK txs with netAmount>0, exactly those same 2 have no display row (397 rows = the SQL count)
- earliest display row = bc3860520181daa812639c924745597a3c114743c620fa1867cce74a3c91b0a6 "Received" 0.1 tDASH
  2019-07-31 10:04:28 to address index 0 yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd => the wallet's FIRST receive IS present
2026-09-19T02:03:42 P1: disabled auto_logout via shared_prefs (harness change, noted) and relaunched

### P1 UI history verification
- Bottom of history reached after ~170 swipes: section "31 July, 2019" with the last row
  "Received + D 0.1 / 5:04 AM" = the wallet's FIRST receive (bc3860…, block 146742). PRESENT and
  correctly dated -> P1/history/99-bottom-of-history.png, 00-first-receive-2019-07-31.png
  => D-037's worst symptom (earliest receive vanishes) does NOT reproduce on this wallet.
- BUT the mechanism does bite: section "19 October, 2024" shows exactly FIVE "Received +0.2" rows
  at 2:21 AM (P1/history/52-19-oct-2024-rows.png). The explorer has SEVEN incoming txs in block
  1123983 at that minute: six of 0.2 and one of 0.33848582. Missing from the history:
  30d25cfa…5a16 (+0.2) and 301d24c9…ce12 (+0.33848582) = 0.53848582 tDASH of receives invisible.
  Both rows exist in dash-sdk.db `transactions` and both are absent from the txos-union.
  => D-037 CONFIRMED on the reference seed, smaller blast radius (2 of 399 receives) than S8's wallet.
2026-09-19T02:12:53 P2 start: uninstall + clean install
2026-09-19T02:14:55 P2: restore done, replay started, recording
2026-09-19T02:17:09 P2: force-stopped at the above cursor

## P2 — single kill during replay (D-041 confirm/deny on a 2nd device)  => CONFIRMED
- 07:14:16 restore #2 (clean reinstall), replay starts 07:14:21
- kill point: 07:16:55 `phase=FILTERS 92.7% headers 1556601/1556601 filters 1215999 wallet 1220999`
  (wallet cursor = 78.4% of tip; the L1Shadow progress line is only emitted every 30 s and the
  cursor jumped 665,999 -> 1,220,999 inside one window, so the 50% target was not hittable —
  this was ONE force-stop, mid-replay, at 02:17:09 host)  -> P2/05-before-kill.png
- relaunch 02:17:17; 07:17:21 `phase=IDLE 0.0% ... wallet 1415999` => resumed ABOVE the last logged
  cursor, NO blocks lost, no rescan from 0.
- during the replay the header was CORRECT: 107.081735 at 02:18:25..02:19:03 under "Syncing balance"
- then it diverged UPWARD: 02:19:21 2293.32319 -> 02:19:41 2327.154954
- 07:19:46 `phase=SYNCED 100.0%`; the "Syncing balance" label and the progress pane DISAPPEAR and the
  header settles at **2336.304271 tDASH** (expected 107.08173522) = 21.82x inflated, app claims synced
  -> P2/09-BALANCE-after-kill-INFLATED.png
- last `SDK balance published: 233630427063 duffs` @07:19:44, i.e. 2 s BEFORE phase=SYNCED; every
  publish in the run carries l1Synced=false -> P2/sdk-balance-published.txt
- ground truth from the live DB pulled while inflated: SUM(amount) over unspent txos = 10708173522
  duffs = 107.08173522 EXACT. transactions=3269. So on-disk state is right, only the published
  aggregate is wrong -> P2/db-inflated/
- bg (HOME 20 s) + fg: still 2336.304271 -> P2/10,11 (bg/fg does NOT fix, matches S2)
- force-stop + relaunch: 107.081735 immediately -> P2/13-recovered.png, video P2/p2-recovery.mp4
  recovery log: `SDK balance published: 10708173522 duffs (was none) ... lastKnown=233630427063`
  NEW DATUM vs S2: the inflated value WAS persisted as lastKnown, so a "hold last known balance"
  path would resurface 2336.30 on a later start.
- exit-info: only the two deliberate FORCE STOPs, no LMK/OOM -> P2/exitinfo.txt
- videos: P2/p2-kill-relaunch.mp4 (kill + relaunch), P2/p2-recovery.mp4 (bg/fg then force-stop fix)
- VERDICT: D-041 CONFIRMED on emulator-5566 with a SINGLE kill (S2 needed 25/50/75% torture).
2026-09-19T02:23:12 P3: stopping emulator to drop RAM to 1536 MB
2026-09-19T02:24:05 P3: emulator up at 1536 MB

## P3 — low-memory replay
ENV LIMIT: emulator 37.1 refuses to run this AVD below 2560 MB. Both `hw.ramSize=1536` in
~/.android/avd/dw-qa7.avd/config.ini AND `emulator -memory 1536` log
`INFO | Increasing RAM size to 2560MB` (logs/emu-dw-qa7.log, logs/emu-dw-qa7-1536.log).
Guest MemTotal is therefore 2,531,992 kB (2.41 GB) instead of 3 GB. To reach a ~1.5 GB-class
device I added a 600 MB tmpfs ballast at /dev/s11ballast (RAM-backed) on top, and ran the
requested `am send-trim-memory RUNNING_CRITICAL` every 60 s.
2026-09-19T02:29:18 P3: replay started, applying RUNNING_CRITICAL every 60 s
- 07:27:52 cutover DUAL_RUNNING -> CUT_OVER; 07:28:33 L1 shadow SPV started (phase=CONNECTING)
- RUNNING_CRITICAL trims at 02:29:19 / 02:30:19 / 02:31:19 / 02:32:20 / 02:33:20 (P3/pressure-log.txt)
  MemAvailable during the replay stayed 778-923 MB (with the 600 MB ballast held)
- 07:33:09 phase=SYNCED 100.0% => engine start -> 100% in 4 min 36 s (vs 4 min 31 s at 3 GB: no
  measurable slowdown under pressure)
- final `SDK balance published: 10708173522 duffs` = 107.08173522 EXACT; header shows 107.081735
  -> P3/05-SYNCED-balance.png
- PROCESS SURVIVED: pid 3772 unchanged across all 5 trims; `dumpsys activity exit-info` EMPTY
  (no LMK, no OOM kill) -> P3/exitinfo.txt
- 0 filter-stall watchdog lines, 0 `idling detected` during the replay, 0 OutOfMemory,
  0 OverlappingFileLockException; no watermark rewind/resume was needed (no kill in P3)
- peak TOTAL PSS 581,409 kB (568 MB) @02:32:45, peak native heap 479,961 kB (469 MB), peak Dalvik
  53,768 kB -> mem-p3p4.csv. i.e. the app's footprint did NOT shrink under RUNNING_CRITICAL: it is
  the same ~570-610 MB as the unconstrained 3 GB run, so on a real 1.5 GB phone this is an LMK risk
  (consistent with D-025/D-035).
- video P3/p3-replay.mp4
- VERDICT P3: PASS (survives, correct balance, no slowdown) with the ENV caveat that a true 1.5 GB
  guest was not achievable.
2026-09-19T02:34:46 P4: uninstall, install MASTER 11.9.0
2026-09-19T02:37:31 P4: master restored, dashj running for 10 min

## P4 — upgrade path master 11.9.0 -> fix 12.0.0 on the constrained device
- 07:36:43 master `starting peergroup` (dashj); restore at 02:37:27 host
- after ~11 min of dashj: chain/common height 592721/1556620 (38%), "Chain download 72% done with
  964025 blocks to go, block date 2021-10-12", header 788.189094 under "Syncing 71%"
  -> P4/06-master-after-10min.png
- master memory over that window: peak PSS 263,205 kB / native 49,763 kB / Dalvik 101,365 kB
  (native heap is ~10x smaller than the SDK replay's 480 MB — the D-025/D-035 gap, reproduced here)
- 02:48:58 force-stop master; 02:48:59 `adb install -r` fix APK (versionCode 11090002 -> 12000000);
  launched 02:48:59
- 07:49:00 `cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)`
- 07:49:00 `upgrade cutover: one-time sync explainer armed` (EXACTLY ONE explainer line in the whole log)
  explainer shown -> P4/09-explainer.png ("A one-time sync is needed … Your balance stays at its last
  known amount until the sync finishes")
- 07:49:02 `armSpvRescan: filter watermark rewind to 0 armed` -> the upgrade re-scans from height 0
- 07:49:05 L1 shadow SPV started; ZERO `starting peergroup` after the upgrade (only the pre-upgrade
  master line at 07:36:43)
- BALANCE HELD: at 02:49:5x the header shows 794.227628 under "Syncing balance" = the last-known
  dashj value, while the SDK published 0 duffs at 07:49:03 (lastKnown=79422762803). So the hold DOES
  work on the upgrade path (S3's observation reproduced) -> P4/10-replay-home.png
- 07:58:43 phase=SYNCED 100.0% => engine start -> 100% in 9 min 38 s (2x the clean-restore time;
  the run also went through extra MASTERNODES/HEADERS/FILTERS cycles at 100%)
- final balance 107.081735 in the header, `SDK balance published: 10708173522 duffs` EXACT
  -> P4/12-SYNCED-balance.png, P4/13-home-after-sync.png
- NO LMK: pid 8640 constant for the whole replay; exit-info records ONLY the deliberate master
  FORCE STOP at 02:48:55 -> P4/exitinfo.txt
- peak TOTAL PSS 662,100 kB (647 MB), peak native 506,947 kB (495 MB), peak Dalvik 59,556 kB — the
  highest of all four runs, on the MOST constrained device, and still no kill.
  Master/dashj on the same device peaked at 263 MB PSS / 50 MB native.
- 0 filter-stall, 0 OutOfMemory, 0 OverlappingFileLockException
- video P4/p4-upgrade.mp4 (first 180 s incl. cutover + explainer)

### NEW DEFECT found during P4 (S11-D1)
Opening a transaction-detail sheet WHILE the post-upgrade replay is running produces a permanently
broken sheet: title "Sent successfully" with a green success check for a 2021 historical tx, empty
amount, empty "Sent from"/"Sent to", and the label/value binding is shifted — "Network fee" renders
the value "Sent to D" and "Date" renders the value "Sent to"; Tax Category stuck on "Loading…".
It never recovered over 9 minutes (02:52 -> 02:58, P4/11-replay-4.png … 11-replay-12.png).
After SYNCED the same gesture renders a correct sheet (P4/14-txdetail-post-sync.png:
"Amount Received +1.00 / Received at yh37iX… / Date August 22 at 5:51 AM / Tax Category Income").
