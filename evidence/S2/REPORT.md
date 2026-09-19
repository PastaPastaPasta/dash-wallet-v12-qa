# QA report: S2 — A2 + Tier B (B1–B4)   (agent: Opus QA stream S2, emulator-5556 / AVD dw-qa2, 2026-09-19)

Build under test: `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29, targetSdk 35.
Wallet: reference seed `job flower agree lyrics industry note boost finger buddy dog exact fat` — kept **read-only** all session
(no send, no shield, no username; every wallet reset used "Reset wallet **without saving**" so nothing was written to Platform).

> **Expected-balance correction.** The brief's 107.43173749 is **stale**. The wallet made a confirmed on-chain spend of
> 0.35000227 on 2026-09-05 (block 1,547,938). On-chain truth today is **107.08173522** and that is the figure every
> assertion below uses. Evidence in A2.3.

Times are host-local (UTC-5) unless suffixed UTC. `wallet.log` timestamps are UTC.

## Summary table

| Test | Verdict | Key evidence | One-line finding |
|---|---|---|---|
| **A2** Clean install + restore reference seed, does sync finish | **PASS** | `A2/17-SYNCED-balance.png`, `A2/walletlog-after-sync/files/log/wallet.log`, `A2/a2-sync-100.mp4` | Sync finished in **10 min 06 s**, balance exactly **107.08173522**, confirmed against the insight explorer to the duff; zero watchdog/stall/OOM lines |
| **A2 (a)** Balance assertion | **PASS** | `A2/18-txdetail-sent-0.35.png`, explorer tx `bbd61b83…2953` | App 107.08173522 == explorer sum over the 810 addresses backing its UTXOs; brief constant is stale, not a defect |
| **A2 (b)** Home-screen balance during sync | **FAIL (D-S2-2)** | `A2/11-unlocked-home.png` | Mid-replay the home screen shows a partial, *inflated* balance (825.481794 at 61%) as the dominant number |
| **A2 (c)** Receive-address check | **FAIL (D-S2-3)** | `A2/26-receive-address.png` | Receive screen offers `m/44'/1'/0'/0/0`, an address with 107 on-chain appearances, although `externalHighestUsed=245` |
| **B4** Background idle 30 min | **PASS** | `B4/04-home-after-30min-idle.png`, `B4/batterystats-{mid,end}.txt` | Exactly **one** service stop/start cycle in 30 min, no wakelock/alarm growth, balance and synced state intact |
| **B2** Kill/restart torture | **PASS** (blocks-lost target) / **FAIL** (post-kill balance, D-S2-1) | `B2/kill3/kill3-results.txt`, `B2/kill3/k{1,2,3}.mp4` | **0 blocks lost on all 5 kills** (target ≤ 5,000); but after any mid-replay kill the finished UI shows a ~22× inflated balance |
| **B3** Network flap ×3 | **PASS** | `B3/torture-timeline.txt`, `B3/03-during-net-off-3.png` | Cursor freezes exactly during each 2-min outage and resumes within 30 s; 0 watchdog restarts; correct offline banner |
| **B1** Low-memory pressure | **PASS** | `B3/torture-timeline.txt`, `mem.csv` | 5 × `RUNNING_CRITICAL` survived, cursor kept advancing, no LMK/ANR/crash, reached 100% |
| **D-037 confirmation** (orchestrator request) | **CONFIRMED** | `B3/`, `B2/kill3/walletlog/files/log/wallet.log` | App logs "display cache is missing rows"; the count it calls "SDK records" is exactly the **txos union (2375)**, not `transactions` (3269) |

## Per-test detail

### A2 — Clean install, restore reference seed, sync to 100%

Uninstall (not present) -> install fix APK 00:10:05 -> `logcat-start` + `memlog 30s` armed 00:10:14 -> launch 00:10:17 ->
Restore wallet 00:10:37 -> seed typed, **Continue = T0 00:11:18** -> PIN 1234 set+confirmed 00:12:11 -> notifications ALLOW
-> background-run ALLOW x2 -> home reached 00:12:3x.

Onboarding screenshots: `A2/01-first-launch.png`, `A2/04-after-continue.png` (Set PIN), `A2/05-pin-confirm.png`,
`A2/06-after-pin.png` (notification permission), `A2/07-after-notif-permission.png` (background-run dialog),
`A2/08-after-bg-allow.png`, `A2/09-home-sync-start.png`.
The Recover Wallet screen is `FLAG_SECURE`, so `screencap` returns an all-black frame (`A2/02-restore-tapped.png`);
textual proof captured instead in `A2/02-restore-screen-uidump.txt` and `A2/03-seed-entered-uidump.txt`.

**Cutover assertions (all green).**
```
05:11:18 CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))
05:12:12 DashSdkServiceImpl - armSpvRescan: filter watermark rewind to 0 armed on b7118ed5...
05:12:17 L1ShadowSyncService - L1 shadow SPV started for SDK wallet b7118ed5...      <- exactly once
```
`starting peergroup` (dashj): **0**. `filter-stall`, `engine restart`, `OverlappingFileLockException`, `OutOfMemory`,
app-process `FATAL`: **0**. `idling detected`: 0 during the replay (first at 05:25:00, four minutes after completion).

**Progress timeline** (wallet.log UTC; T0 = 05:11:18 UTC). The engine's own % is phase-weighted and not linear in
blocks — the wallet-block cursor is the linear measure.

| UTC | T+ | engine % | wallet cursor / tip | note |
|---|---|---|---|---|
| 05:11:18 | 0:00 | — | — | restore submitted, cutover committed |
| 05:12:17 | 0:59 | 0.0 | 0 | `L1 shadow SPV started`, phase=IDLE |
| 05:12:47 | 1:29 | 9.1 | 5,999 / 1,556,549 | **first height change** |
| 05:13:18 | 2:00 | 31.0 | 70,999 | |
| 05:13:49 | 2:31 | 59.7 | 110,999 | headers complete -> FILTER_HEADERS |
| 05:14:19 | 3:01 | 71.9 | 245,999 | FILTERS |
| 05:14:49 | 3:31 | 75.3 | 400,999 | |
| 05:15:19 | 4:01 | 77.9 | 525,999 | |
| 05:15:50 | 4:32 | 79.9 | 615,999 | |
| 05:16:21 | 5:03 | 83.3 | 775,999 | |
| 05:16:52 | 5:34 | 87.1 | 955,999 | |
| 05:17:22 | 6:04 | 91.3 | 1,150,999 | |
| 05:17:52 | 6:34 | 96.0 | 1,370,999 | |
| 05:18:23 | 7:05 | 100.0 | 1,555,999 / 1,556,554 | filters at tip-555 |
| **05:21:24** | **10:06** | **100.0** | **1,556,559 / 1,556,559** | **phase=SYNCED + SETTLED** |
| 05:21:27 | 10:09 | — | — | `DashPaySyncStatus - DashPay sync SETTLED` |

UI progression on the home screen: "Syncing 31%" -> 61% -> 64% -> 78% -> 99%, then the indicator disappeared.
Screenshots `A2/09`, `A2/11`, `A2/12`, `A2/14`, `A2/17`. Video of the final minutes incl. the 100% moment:
`A2/a2-sync-100.mp4`. Per-minute sampler timeline: `A2/timeline.txt`.

**Balance assertion.**
- Displayed **107.081735** ($6521.62) — `A2/17-SYNCED-balance.png`
- `wallet.log 05:18:22 CutoverUiDataService - SDK balance published: 10708173522 duffs` -> 107.08173522
- `dash-sdk.db`: `SELECT SUM(amount),COUNT(*) FROM txos WHERE isSpent=0` -> `10708173522 | 811`
- **Explorer cross-check:** summed `insight-api/addrs/<100 at a time>/utxo` over the 810 distinct addresses backing
  those UTXOs -> **10708173522 duffs**, 0 failed chunks. Exact match.
- Expected per brief 107.43173749 -> short by 0.35000227, fully explained below. **Actual vs expected: PASS against
  on-chain truth 107.08173522.**

#### A2.3 — why the brief's constant is stale (explorer verification)
Tx detail of the newest row (`A2/18-txdetail-sent-0.35.png`, `A2/19-txdetail-scrolled.png`): Amount Sent 0.35000227,
from `ye5QiE9Yk6YshTYwEbW9V9UvhCFE2ACMB1`, to `yMu5gX1fKg3FC2p17DEsQhu1S4ZXhP78F5`, network fee 0.00000227,
"September 5 at 7:54 AM". Explorer `insight-api/tx/bbd61b8301229c8079dc90a6af3f5fbae544b70aecebec1246d593aa43092953`:
time **2026-09-05T12:54:12 UTC**, blockheight **1,547,938**, 8,622 confirmations, vin 9.89009773 from that address,
vout 0.35000000 + change 9.54009546 to `yStxXHHzhAx58JhaPBNhn3xsH93UwBM2nd`, fees 0.00000227.
`107.43173749 - 0.35000227 = 107.08173522`, to the duff. The spend predates this QA session (started 2026-09-18).

A sweep over **all** 11,843 rows of `core_addresses` returned 0.0123 more than the app. That single output
(`yYu4XLg7e7BGbPzDGsjrTiEzVu5NJtBKpR`, 0.0123, tx `5e4d7282...272c`) belongs to `accounts.id=17`,
`accountTypeName='dashpayExternalAccount'` (derivation `m/9'/1'/15'/0'/0xea87.../0x9aa3.../0`) — the **contact's**
DIP-15 receiving chain, money this wallet *sent* to a DashPay contact. Correctly excluded. The app's own telemetry
confirms the arithmetic: `total = bip44 2,173,382,240 + coinjoin 8,534,691,282 + dashpayReceiving 100,000 = 10,708,173,522`,
with `dashpayExternal:1,230,000` listed but not summed. **Not a defect.**

**Transaction list.** `tx_display_cache` = 1,553 rows; `dash-sdk.db.transactions` = 3,269 records. 30 scroll pages
captured (`A2/txlist/page-01..30.png`) reaching 09 March 2025; the list is longer than a UI scroll can exhaust, so the
authoritative count is the DB.

**xpub** (recorded, nothing derived by me):
`tpubDDDjGxYK3jDHmnNoEBjKPiqS9DNjHeaWvogRtG7JYnZXmLZJ4PJaKSvRVdPNbf9ZrbPLLDm67sKeaqiCZJoVKg5UhCHjkzQPnfKbZtNBaPd`

**Memory** (`mem.csv`, 30 s interval): peak TOTAL PSS **622 MB**, peak native heap **481 MB**, peak Dalvik **50 MB**,
all at 00:20:54 during the final FILTERS stretch. Idle after 100%: PSS 468 MB / native 313 MB / Dalvik 34 MB.
`wallet.log` peak `MEM pss=606MB nativeHeap=457/547MB jvm=22/576MB` (05:21:00). `ReplayMemTelemetry` peak
`nativeHeapAllocated=395 MB, nativeHeapSize=455 MB`; `jvmUsed` never exceeded 37 MB of 576 MB.
`dumpsys activity exit-info`: **empty** for A2 — no LMK, no ANR, no crash; app pid 5226 survived the whole test.

**A2 step 4 (stall probes) — not needed.** No stall occurred: the cursor never sat still for 10 minutes during any
replay, so the stall-capture branch was not exercised, and there are **no** `filter-stall watchdog` / "filter cursor has
sat at" lines to report for this build on this wallet. Post-100% background/foreground and kill/relaunch probes were
folded into B4 and B2.

**Verdict: PASS.**

### B4 — Background idle 30 minutes

Backgrounded 00:32:07, foregrounded 01:02:42. Exactly **one** service stop/start cycle in 30 minutes — no loop:
```
05:32:08 BlockchainServiceImpl - .onDestroy()                                  <- app backgrounded
05:54:38 BlockchainServiceImpl - onCreate completed, processing onStartCommand <- wakes ~22 min later
05:54:39 L1Shadow phase=IDLE 0.0% headers 0/0 filters 0/0 wallet 1556561       (transient re-init)
05:54:46 L1Shadow phase=SYNCED 100.0% headers 1556572/1556572 ... wallet 1556572   <- caught up 11 blocks in 8 s
05:57:00 idling detected, stopping service  +  .onDestroy()
```
`batterystats`: `diff` of every `wake lock|alarm|job` line between `B4/batterystats-mid.txt` (13 min) and
`B4/batterystats-end.txt` (30 min) is **empty** — no growing wakelock/alarm counts, and no app-owned wake lock appears at
all. App pid 5226 unchanged across the whole window. Memory fell from ~313 MB native to ~126 MB while backgrounded.
After foregrounding + PIN: balance **107.081735**, no syncing indicator, `phase=SYNCED` at 1,556,574
(`B4/04-home-after-30min-idle.png`). **Verdict: PASS.**

#### Characterisation of `idling detected, stopping service` (orchestrator request)
- **Foreground, post-sync:** logged at 05:25:00, 05:26:00, 05:27:00, 05:28:00, 05:29:00, 05:30:00 — once a minute — with
  **no** `.onDestroy()`, **no** `stopSelf`, **no** `service start command` in between. The service does **not** stop and
  does **not** restart; the process stays alive. It is a misleading once-a-minute log line, **not** a service loop.
- **Background:** the same line at 05:57:00 **is** immediately followed by `.onDestroy()` — there it means what it says.
- Total `idling detected` occurrences over the whole session: 7.

### B2 — Kill/restart torture

Two passes: restore #2 (T0 01:13:18) with 2 kills, and a dedicated restore #4 (T0 01:50:14) with 3 time-spaced kills so
the 25/50/75 acceptance target could be measured cleanly. Driver `bin/s2-kill3.sh`; raw results
`B2/kill3/kill3-results.txt`, `B2/kill25-kill.txt`, `B2/kill50-kill.txt`.

**Blocks lost per kill** (last persisted watermark before force-stop vs first watermark the new process reports):

| run | kill | at cursor | % of tip | persisted before | persisted after relaunch | **blocks lost** | relaunch -> forward progress |
|---|---|---|---|---|---|---|---|
| #2 | kill25 | 560,000 | 36 % | 560,000 | 560,000 | **0** | 7 s |
| #2 | kill50 | 745,000 | — | 1,290,000 | 1,290,000 | **0** | 7 s |
| #4 | k1 | 488,000 | 31 % | 343,000 | 343,000 | **0** | 7 s |
| #4 | k2 | 1,298,000 | 83 % | 1,553,000 | 1,553,000 | **0** | 7 s |
| #4 | k3 | 1,553,000 | 99 % | 1,552,170 | 1,552,170 | **0** | 6 s |

**0 blocks lost on every one of the 5 kills** against a target of <= 5,000. Worst raw *cursor* regression 830 blocks (k3);
in k1/k2 the relaunched process was already ahead of the pre-kill cursor by the time it first reported.
Videos `B2/kill3/k1.mp4`, `k2.mp4`, `k3.mp4`; before/after-kill/after-relaunch screenshots
`B2/kill3/k{1,2,3}-0{1,2,3}-*.png`; reset+restore video `B2/b2-reset-restore.mp4`.
Sync still reached 100% both times: restore #2 `phase=SYNCED` 06:19:25 UTC (6 min 07 s from T0, 2 kills);
restore #4 `phase=SYNCED` 06:59:13 UTC (8 min 59 s from T0, 3 kills).

**Balance after the torture: FAIL — defect D-S2-1.** The store was correct
(`txos WHERE isSpent=0 -> 10708173522 | 811`) but the UI showed 2319.448975 (run #2) and 2363.277644 (run #4).

### B3 — Network flap x3 (during restore #3, no kills)

Driver `bin/s2-torture.sh`, timeline `B3/torture-timeline.txt`. Each flap = `svc wifi disable` + `svc data disable`, 2 min.

| flap | off at | cursor frozen at | on at | cursor 30 s after reconnect |
|---|---|---|---|---|
| #1 | T+32 s | headers 324,000 / filters 1,999 | T+151 s | headers 456,000 / filters 15,999 |
| #2 | T+210 s | headers 1,556,586 / filters 110,999 | T+331 s | filters 360,999 |
| #3 | T+390 s | headers 1,556,588 / filters 575,999 | T+510 s | filters 735,999 |

In all three the cursor is exactly unchanged across the outage and resumes within 30 s of the network returning.
`grep -c 'filter-stall|engine restart|restarting engine'` = **0** — no watchdog restart needed.
During outage #3 the UI showed "Unable to connect to the Dash network — Check your connection"
(`B3/03-during-net-off-3.png`). **Verdict: PASS.**

### B1 — Low-memory pressure (same replay)

5 x `am send-trim-memory hashengineering.darkcoin.wallet_test RUNNING_CRITICAL` at T+181, 361, 540, 661, 780 s.
The app survived every one, the cursor kept advancing across each, the process was never killed, and the replay reached
`phase=SYNCED` at 06:46:05 UTC. `dumpsys activity exit-info` has **no** LMK/ANR/crash entry for the app — the only
entries all session are my own 7 `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` kills.
Peak during this run: PSS 647 MB / native 488 MB / Dalvik 67 MB. **Verdict: PASS.**

**This run is also the control for D-S2-1:** with network flaps and memory pressure but **no kill**, the balance
converged correctly to `10708173522` at 06:44:05 — two minutes *before* `phase=SYNCED` — and the header never showed a
wrong number (`B3/04-BALANCE-after-torture.png`).

### D-037 confirmation on the reference wallet (orchestrator request)

Queried at 100% after restore #3 (`sqlite3` is on the device at `/system/bin/sqlite3`):

| query | value |
|---|---|
| `dash-sdk.db  SELECT COUNT(*) FROM transactions` | **3,269** |
| `dash-sdk.db  SELECT COUNT(*) FROM (SELECT txid FROM txos WHERE txid IS NOT NULL UNION SELECT spendingTxid FROM txos WHERE spendingTxid IS NOT NULL)` | **2,375** |
| `dash-sdk.db  SELECT COUNT(*) FROM txos` | 5,356 |
| `dash-wallet-database  SELECT COUNT(*) FROM tx_display_cache` | 1,531 |
| `... WHERE valueSatoshis > 0` (received rows) | **394** |
| `... WHERE valueSatoshis <= 0` | 1,137 |

The app logs the loss itself, and the number it calls "SDK records" is **exactly the txos union (2,375)**, not the
`transactions` count (3,269):
```
06:46:05 TxDisplayCacheService - Sync complete (cutoverCommitted=true): SDK=2375 records | dashj wallet=0 txs |
         group cache=1627 txs/51 groups | display=1531 rows - display cache is missing rows
         (SDK holds 2375 records, display has 1531 rows) - requesting an SDK reconcile pass
```
-> **894 transactions never reach the display pipeline at all**, matching S8's root cause (the display cache walks
`txos` rather than `transactions`, so a transaction whose outputs were all spent before the replay reached them leaves
no row).

**Non-deterministic.** Identical seed, identical wallet, four restores in one session:

| restore | "SDK records" reported | group cache | display rows | `transactions` |
|---|---|---|---|---|
| #1 A2 | — | — | **1,553** | 3,269 |
| #2 B2 (2 kills) | 2,943 | 1,774 txs / 51 groups | **1,546** | 3,269 |
| #3 B3+B1 (no kills) | 2,375 | 1,627 txs / 51 groups | **1,531** | 3,269 |
| #4 B2 (3 kills) | 2,865 | 1,750 txs / 51 groups | **1,557** | 3,269 |

**The tail is intact** — the loss is scattered, not a truncation. Oldest display row is
`2019-07-31 10:04:28  Received 10000000` / `Sent -10000000`, matching the wallet's genuine first transaction on the
index-0 address `yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd`: insight tx
`bc3860520181daa812639c924745597a3c114743c620fa1867cce74a3c91b0a6`, 2019-07-31T10:04:28 UTC, height 146,742,
vout 0.10000000 to that address. Newest display row `2026-09-05 12:54:12 Sent -35000227` = the 0.35 spend. Both correct.

## Defects found

| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| **D-S2-1** | **S1** | After any mid-replay process kill, the finished home screen shows a ~22x inflated balance and claims to be synced | 1. Restore the reference seed. 2. `am force-stop` the app at any point during the replay, relaunch. 3. Let it reach `phase=SYNCED`. 4. Home shows 2319.448975 / 2363.277644 instead of 107.081735, with **no** syncing indicator. Reproduced **2/2** on kill runs, **0/2** without kills. Workaround: force-stop + relaunch (bg/fg alone does **not** fix it). | `B2/11-BALANCE-after-kills.png`, `B2/kill3/20-BALANCE-after-3-kills.png`, `B2/kill3/21-BALANCE-after-restart.png`, `B2/b2-restart-recovery.mp4`, `B2/walletlog-wrong-balance/files/log/wallet.log`, `B2/kill3/walletlog/files/log/wallet.log` | `CutoverUiDataService` / `L1ShadowSyncService.WalletBalanceFacts` — **only the bip44 bucket** is wrong (227,792,973,136 vs correct 2,173,382,240); `coinjoin`, `dashpayReceiving`, `dashpayExternal` and `txCount=3269` all match a good run, so spent outputs are not being retired from the in-memory bip44 UTXO set when blocks are re-processed after a restart |
| **D-S2-2** | **S3** | During replay the home screen presents a partial, *inflated* balance as the dominant number | Restore any wallet with history and watch the home screen mid-replay: at 61 % it read **825.481794** (final 107.08). The "Syncing balance" caption above it is greyed and much smaller. | `A2/11-unlocked-home.png` (825.481794 at "Syncing 61%"), `B3/03-during-net-off-3.png` (745.72803) | Home/balance seam — plan intent is to hold the last known balance or show a syncing state rather than a live partial sum |
| **D-S2-3** | **S3** | Receive screen hands out address index 0, the wallet's most-reused address | Home -> Receive after restoring the reference seed. Shows `yWcaVhiPFfxx7ugWgLDRcQGf1XJGWXkcxd` = `m/44'/1'/0'/0/0`, `isUsed=1`, while `accounts.id=1` has `externalHighestUsed=245`. Explorer: 107 tx appearances, 896.32 DASH lifetime received. Persists across bg/fg. | `A2/26-receive-address.png`, `B4/03-after-fg-balance.png` | Receive / address-rotation on the SDK seam (privacy: address reuse) |
| **D-S2-4** | **S4** | `idling detected, stopping service` logged once per minute in the foreground while the service is in fact running | Reach 100 %, leave the app foregrounded, watch `wallet.log`: the line repeats every 60 s with no `.onDestroy()`/`stopSelf`/`service start command` between. | `A2/walletlog-after-sync/files/log/wallet.log` lines 4975/5114/5243/5388/5482/5626 (05:25:00-05:30:00) | `BlockchainServiceImpl` idle check — misleading log only; no functional impact (verified in B4) |
| **D-S2-5** | **S4** | Self-transfer / CoinJoin denomination rows render as "Sent ... 0" with fiat "Not available" | Scroll the history of a CoinJoin-heavy wallet. | `A2/txlist/page-30.png` | Tx-list row formatting |

### Investigated and rejected as defects
- **Foreground auto-lock every ~60 s.** Real (controlled probe using `screencap` only, no `uiautomator`:
  `A2/lockprobe/probe-1..6.png`; `LockState = ENTER_PIN` count 8->9, the new lock 60 s after the last touch), but it is
  the shipped default: `Configuration.getAutoLogoutMinutes()` returns `prefs.getInt(PREFS_KEY_AUTO_LOGOUT_MINUTES, 1)`
  (`common/src/main/java/org/dash/wallet/common/Configuration.java:171-173`) driving `AutoLogout.shouldLogout()`
  (`wallet/src/de/schildbach/wallet/AutoLogout.java:104-107`), a file dated 2019. Pre-existing, not from this branch.
  Worth noting as UX friction: a user watching a 10-minute replay is returned to the PIN pad every minute.
- **0.0123 "missing" in the all-addresses explorer sweep** — a `dashpayExternalAccount` (DIP-15 contact chain) output,
  money sent *to* a contact, correctly excluded. See A2.3.
- **`last_used` preference never refreshes** (stuck at wallet-setup time across ~58 min of active use).
  `Configuration.touchLastUsed()` has exactly one caller, `wallet/src/de/schildbach/wallet/ui/main/MainActivity.kt:207`,
  so it only fires on MainActivity creation; `WalletApplication.scheduleStartBlockchainService()` feeds
  `getLastUsedAgo()` into the alarm backoff buckets. Pre-existing, low impact.

## Environment problems (not product defects)
- `qa-app.sh logcat-start` produced an empty file for the first ~11 minutes. Fixed by the orchestrator mid-run; the
  pre-fix window is preserved in `logcat-early.txt` (22,565 lines from the ring buffer), the rest in `logcat.txt`.
- The Recover Wallet screen is `FLAG_SECURE`; `screencap` yields an all-black frame there. uiautomator dumps captured
  instead (`A2/02-restore-screen-uidump.txt`, `A2/03-seed-entered-uidump.txt`).
- `logcat -b crash` contains `FATAL EXCEPTION ... registerUiTestAutomationService ... already registered` from PIDs
  10547/11319/11343/11366/11851/12681. These are the **`uiautomator` helper process** (my 60 s sampler colliding with my
  own dumps), not the app. Verified zero `FATAL` lines from any app PID (5226, 22930, 23456, 24825, 28170, 28706, 29214).
- Replay on this AVD is far faster than the plan's "~1 hour" estimate (~7-10 min), which made precise 25/50/75 % kill
  targeting hard on the first pass — `synced_height_persisted` is written to `wallet.log` in bursts, so thresholds
  overshoot. Restore #4 used time-spaced kills instead, giving 31 % / 83 % / 99 %.

## Not run / blocked
- Nothing in the assigned scope was blocked. A2 step 4's stall-capture branch (`grep-log` + `mem` + `procstat` +
  `exitinfo` + `wallet.log` into `A2/stall-<time>/`) was **not triggered** because no stall occurred — the cursor never
  went 10 minutes without advancing in any of the four replays.
- Full UI scroll to the bottom of the ~1,500-row history was not attempted (~400 swipes); 30 pages were captured and the
  row counts come from `tx_display_cache`, which is what the list renders.

## Evidence index (all under `/Users/dcg/workspace/dash-wallet-qa/evidence/S2/`)
```
notes.md                      running timestamped journal
REPORT.md                     this file
logcat.txt, logcat-early.txt  full logcat (early ring buffer + post-fix stream)
mem.csv                       dumpsys meminfo every 30 s, 199 samples, 00:10:42 -> 01:51:04
A2/                           onboarding + sync screenshots, timeline.txt, txlist/, lockprobe/,
                              a2-sync-100.mp4, walletlog-after-sync/files/log/wallet.log
B4/                           before/after-background screenshots, batterystats-mid.txt, batterystats-end.txt
B2/                           reset+restore screenshots, kill25/kill50 results, b2-reset-restore.mp4,
                              b2-restart-recovery.mp4, walletlog-wrong-balance/, kill3/ (k1-k3 videos,
                              screenshots, kill3-results.txt, walletlog/)
B3/                           torture-timeline.txt, offline-banner + final-balance screenshots
96 screenshots, 8 videos, 93 MB total
```
Helper scripts written for this stream: `bin/s2-sampler.sh`, `bin/s2-watch.sh`, `bin/s2-killat.sh`,
`bin/s2-kill3.sh`, `bin/s2-torture.sh`.
