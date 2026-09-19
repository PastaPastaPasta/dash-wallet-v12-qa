# Fix-validation QA — SR-03 / SR-04 (D-003, D-119): receive address served from the SDK pool

## 1. Header

| item | value |
|---|---|
| Emulator | `emulator-5560` (AVD `dw-qa4`, Android 15 / API 35, arm64) — booted for this session; no other serial touched |
| Base APK | `apks/base-12000014-5f8c0a8ef.apk` — versionCode **12000014**, versionName `12.0.0-upgrade`, git `5f8c0a8ef` (md5 `0bdcddf6…`, byte-identical to `fix-12.0.0-testnet3-release-signed.apk`) |
| Candidate APK | `apks/sr03-0aa28b1d5.apk` — versionCode **12000014**, versionName `12.0.0-upgrade`, git `0aa28b1d5` (md5 `9146272c…`) |
| Master APK (regression a) | `apks/master-11.9.0-testnet3-release-signed.apk` — versionCode **11090002** |
| Fix worktree | `/Users/dcg/workspace/dash-wallet-qa/pr/sr03-receive-address` @ `0aa28b1d5` (1 commit on `5f8c0a8ef`) |
| Seeds | QA throwaway `swamp dad rent tower dumb cart dust vocal often today chimney amazing` (restored on base and on candidate); two throwaway wallets created on device for regressions (a) and (b). Reference read-only seed NOT used. |
| Faucet | 3 drops used: `aee399e9…` → `ySu3d1Vc…`, `349ba6ee…` → `yfyy4WKx…`, `07433800…` → `yRsjBRMd…` |
| Session | 2026-09-19 16:26 → 17:35 local (device log timestamps are UTC+5, e.g. 16:44 local = 21:44 in `wallet.log`) |

## 2. Verdict

**FIXED — with one new, narrower defect** (see D-NEW-1, S3): on the steady state the candidate serves a
pristine, engine-unused address from the SDK pool on every consumer (Receive tab, home/lock-screen quick-Receive,
Specify amount, after a receive, after a process restart), and all 16 new unit tests pass. But during the SDK's
**first chain scan** after a restore *or* after the master→candidate upgrade, the pool exists with **zero `isUsed`
markers**, the resolver treats it as authoritative, and the Receive screen shows external key **#0** — the
same already-used address SR-03 is about. The window was ~3 min (restore) and ~9 min (upgrade) here, and on the
upgrade path it is a **regression against the base build**, where dashj's own "used" markers answered correctly.

## 3. BEFORE (base APK 12000014, same seed, `phase=SYNCED`, cutover `CUT_OVER`)

| step | observed | evidence |
|---|---|---|
| Restore + sync to 100 % | `cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))` at 21:30:24 | `before/20-cutover.txt`, `before/09-synced.png` |
| Receive tab | **`yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52`** = external **#0**, `"txApperances":10`, `totalReceived 3.00998554` | `before/10-payments-receive.png`, `before/11-insight-receive-tab.txt` |
| Home quick-Receive | identical `yRjAzoyf…` (#0) | `before/17-quick-receive.png` |
| Specify Amount | **`ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9`** = **#1**, `"txApperances":2` — also used | `before/13-specify-amount-addr.png`, `before/14-insight-chain.txt` |
| Resolver log lines | `grep -c 'receive address' wallet.log` = **0** (class absent on base) | `before/18-resolver-loglines-count.txt`, `before/logs/files/log/wallet.log` |

Pristine indices at the time: #3, #5, #6, #7, #8+ all `txApperances:0` (`before/14-insight-chain.txt`).

## 4. AFTER (candidate APK, fresh install, same seed, synced)

| step | observed | evidence |
|---|---|---|
| 1. Receive tab | **`ySu3d1VcumES35pzwPHWNuTPFZE4AghPNj`** = **#3**, `"txApperances":0` | `after/03-receive-tab.png`, `after/04-insight-receive-tab.txt` |
| | log: `SdkReceiveAddressResolver - receive address (current): SDK pool index 3 ySu3d1Vc… (35 rows, 4 used)` | `after/08-resolver-loglines.txt` |
| 2. Home quick-Receive | same `ySu3d1Vc…` (#3); second `(current)` line, index 3 | `after/05-quick-receive.png` |
| 3. Specify amount ×5 | **#3, #5, #6, #7, #8** — distinct, ascending, **used #4 skipped**, all `txApperances:0`; `(fresh)` lines index 3→5→6→7→8 while `(current)` stays 3 | `after/06-specify-amount-addresses.txt`, `after/06-specamt-{1..5}.png`, `after/07-insight-specify-amount.txt` |
| 4. Faucet 1 tDASH → #3 | balance 2.923964 → 3.923964; on reopening Receive: **`ybr74Sjmmc4vUwAEwLdJkMQC8NpZy6pWp1`** = **#5**, `txApperances:0`; log `index 5 ybr74Sjm… (35 rows, 5 used)` | `after/09-faucet-txid.txt`, `after/13-home-after-receive.png`, `after/14-receive-after-funding-reopened.png`, `after/15-insight-index5.txt`, `after/after-receive-rotation.mp4` |
| 5. `force-stop` + relaunch | Receive still **#5** `ybr74Sjm…`, `txApperances:0`; the funded **#3 never reappears** | `after/16-receive-after-relaunch.png`, `after/08-resolver-loglines.txt` |

Caveat on step 4: the *open* Receive screen does not refresh in place — the address only advances when the
screen is reopened (`after/11-receive-still-index3.png` shows #3 still on screen 7 min after the coin landed).
Same on the base build; pre-existing, cosmetic (S4).

### Address table (every address this session showed)

| build | screen | address | ext index | txApperances at the time |
|---|---|---|---|---|
| base | Receive tab | yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52 | 0 | 10 |
| base | home quick-Receive | yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52 | 0 | 10 |
| base | Specify Amount | ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9 | 1 | 2 |
| cand | Receive tab | ySu3d1VcumES35pzwPHWNuTPFZE4AghPNj | 3 | 0 |
| cand | home quick-Receive | ySu3d1VcumES35pzwPHWNuTPFZE4AghPNj | 3 | 0 |
| cand | Specify Amount #1 | ySu3d1VcumES35pzwPHWNuTPFZE4AghPNj | 3 | 0 |
| cand | Specify Amount #2 | ybr74Sjmmc4vUwAEwLdJkMQC8NpZy6pWp1 | 5 | 0 |
| cand | Specify Amount #3 | yRNSttnwVWfxk7XgSoSCCknKHDgUJKEGxL | 6 | 0 |
| cand | Specify Amount #4 | yToWQgMbSd8Zci8shQac9H1vhy78rGJrVU | 7 | 0 |
| cand | Specify Amount #5 | ycQukzCQujw6Fpq5AH3wjbzkVLwsxCwkD3 | 8 | 0 |
| cand | Receive tab after funding #3 | ybr74Sjmmc4vUwAEwLdJkMQC8NpZy6pWp1 | 5 | 0 |
| cand | Receive after relaunch / rotation / lowmem / offline | ybr74Sjmmc4vUwAEwLdJkMQC8NpZy6pWp1 | 5 | 0 |
| cand (mid-replay) | Receive tab | **yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52** | **0** | **12** ← D-NEW-1 (`adversarial/17-insight-index0-final.txt`) |
| master | Receive (new wallet) | yfyy4WKxs9GjGL7u5U9NftraYYCLgRNtxF | 0 | 0 → 1 after faucet |
| master | Receive after its receive | ya5S49h1StUy24HLXRSFeRDQKootiUfWv6 | 1 | 0 |
| cand (upgraded) | Receive, 21 s after cutover | **yfyy4WKxs9GjGL7u5U9NftraYYCLgRNtxF** | **0** | **1** ← D-NEW-1 |
| cand (upgraded) | Receive, +9 min | ya5S49h1StUy24HLXRSFeRDQKootiUfWv6 | 1 | 0 |
| cand (new wallet) | Receive | yRsjBRMdNHFuKqqBmR5eUgDbS9Rk573ZGZ | 0 | 0 |
| cand (new wallet) | Receive after its receive | yN51mmApYUpSKJo7pAYuJyC8v48ECo4evv | 1 | 0 |

## 5. Regression checks

| # | check | verdict | detail | evidence |
|---|---|---|---|---|
| a | S7 E8 — new wallet on MASTER 11.9.0, funded, `reinstall` candidate on top | **PASS (with transient failure)** | master: #0 `yfyy4WKx…` funded 1 tDASH → master rotated to #1 `ya5S49h1…`. Upgrade: `cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)` 22:13:40; **22:14:01 `receive address (current): SDK pool index 0 yfyy4WKx… (30 rows, 0 used)`** — the funded address was shown; **22:22:56 `index 1 ya5S49h1… (31 rows, 1 used)`** — correct. So it does rotate after the cutover, but only once the SDK scan marks the pool. | `regression/24-master-receive.png`, `regression/29-master-receive-after.png`, `regression/31-upgrade-precutover-receive.png`, `regression/37-upgrade-receive-index1.png`, `regression/38-upgrade-resolver-log.txt`, `regression/34-sdk-pool-upgrade.txt` |
| b | brand-new wallet on candidate | **PASS** | Receive = `yRsjBRMd…` `SDK pool index 0 (30 rows, 0 used)`; after the faucet receive → `yN51mmAp…` `SDK pool index 1 (31 rows, 1 used)` within ~2 min | `regression/41-new-wallet-receive.png`, `regression/43-new-wallet-index1.png`, `regression/42-faucet-drop3.txt` |
| c | send still works; change ≠ shown receive address | **PASS** | sent 0.01 to `yRjAzoy…`, tx `f854eace8aa08bc4648f2adc63acac40b1f9abbfed7dabb1f52544d42d8733a3`, InstantLocked, visible on insight. vin `ySu3d1Vc…`; vout `yRjAzoy…` 0.01 + change **`yc4dR7NSaPe33FF3UHsmw6HXSZH741R2Dt`** (internal chain) ≠ the shown receive address `ybr74Sjm…` | `regression/08-send-tx-vin-vout.txt`, `regression/06-send-confirm2.png`, `regression/07-send-result.png`, `regression/regression-send.mp4` |
| d | pre-cutover / dashj diagnostic toggle | **PARTIAL** | The "dashj sync (diagnostic)" switch could not be flipped from uiautomator (Compose switch, no accessible node; no pref written after taps at both the row and the right edge). The L1 shadow dashj engine was already running (`L1ShadowSyncService - L1Shadow phase=SYNCED 100.0%`, L1 tx events for the send) and the resolver kept answering from the SDK pool. A genuinely pre-cutover state could not be produced: both restore and upgrade commit `CUT_OVER` within seconds. | `regression/09-tools.png`, `regression/11-dashj-after-tap.png`, `regression/logs-upgrade/files/log/wallet.log` |
| — | crashes / process death | **PASS** | `dumpsys activity exit-info`: only `reason=16 (PACKAGE UPDATED)`. No `FATAL EXCEPTION`, no `ANR in`, no StrictMode trace naming the resolver or `*ReceiveAddress*`. The 14 `Exception` lines in wallet.log are `Dapi client … tcp connect error` from my deliberate airplane-mode step. | `final-exitinfo.txt`, `adversarial/16-anr-strictmode.txt`, `logs-final/files/log/wallet.log` |

## 6. Adversarial

| # | variation | verdict | observed | evidence |
|---|---|---|---|---|
| 1 | Quick Receive from the lock screen ~2 s after `am start` (before bind) | PASS | answered from the SDK pool immediately: `receive address (current): SDK pool index 5 ybr74Sjm… (35 rows, 5 used)`. No `SDK store unavailable` fallback was ever logged in the whole session. | `adversarial/02-quickreceive-early.png` |
| 2 | rotate to landscape and back on the Receive tab | PASS | address unchanged (#5) in both orientations | `adversarial/03-rotated-landscape.png`, `adversarial/04-rotated-back.png` |
| 3 | Specify amount 5× in a row | PASS | #3,#5,#6,#7,#8 — distinct, unused, ascending, used #4 skipped | `after/06-specify-amount-addresses.txt` |
| 4 | kill + relaunch, then Specify amount again | PASS (documented) | #5 and #6 re-issued because the issued set is process-scoped; both still unused → acceptable, matches the kdoc | `adversarial/05-specamt-after-relaunch.txt` |
| 5 | **open Receive while the first replay is running** | **FAIL → D-NEW-1** | fresh restore of the same seed: `22:30:41 … SDK pool index 0 yRjAzoyf… (30 rows, 0 used)` and the Receive tab displayed `yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52` (`txApperances:12`) for ~3 min after cutover, then converged to `index 5 … (35 rows, 5 used)` | `adversarial/11-midsync-receive.png`, `adversarial/11-midsync-receive.txt`, `adversarial/12-midsync-convergence.txt` |
| 6 | `am send-trim-memory RUNNING_CRITICAL` | PASS | address stable at #5, no crash | `adversarial/14-lowmem-receive.png` |
| 7 | wifi + data off (offline) | PASS | address stable at #5 from the local pool; no dashj fallback | `adversarial/15-offline-receive.png` |

## 7. Unit tests

`./gradlew --no-daemon :wallet:test_testNet3DebugUnitTest --tests '…SdkReceiveAddressResolverTest'` →
**BUILD SUCCESSFUL in 58 s, `tests="16" skipped="0" failures="0" errors="0"`**.
`unit-tests.txt`, `unit-test-results.xml`, `unit-test-names.txt`.

## 8. New defects

| id | sev | title | repro | evidence |
|---|---|---|---|---|
| **D-NEW-1** | **S3 (privacy; S2 on the upgrade path, where it is a regression vs the base build)** | During the SDK's first chain scan the address pool exists with **0 `isUsed` markers**, the resolver treats it as authoritative and hands out external key **#0** — the exact already-used address SR-03 is about. The code's fallback only fires when the store is *unavailable* or has *no rows*; a fully-populated but not-yet-scanned pool passes the check. | (i) fresh install candidate → restore the seed → open Receive during the replay: `yRjAzoyf…` (#0, 12 appearances) for ~3 min; (ii) master wallet funded on #0 → `reinstall` candidate → open Receive right after `CUT_OVER (upgraded-wallet launch)`: the funded `yfyy4WKx…` (#0) is shown for ~9 min, where the base build correctly showed #1 from dashj's markers. | `adversarial/11-midsync-receive.png`, `adversarial/12-midsync-convergence.txt`, `regression/31-upgrade-precutover-receive.png`, `regression/38-upgrade-resolver-log.txt` |
| **D-NEW-2** | **S3 (SR-04 gap, code review — not exercised on device)** | `SweepWalletFragment.handleSweep()` calls `application.getWallet().freshReceiveAddress()` — the **dashj `Wallet` object**, not `WalletApplication.freshReceiveAddress()` — so it bypasses the resolver entirely and the swept funds still land on dashj's key #0. The resolver's own kdoc claims "the sweep's background handler" is one of the callers routed through it; that claim is wrong. | `wallet/src/de/schildbach/wallet/ui/payments/SweepWalletFragment.java:621`; `WalletApplication.getWallet()` returns the dashj `Wallet` (`WalletApplication.java:1161`). Could not be exercised: sweep is camera-QR only on this emulator (same block as SRD's SR-04). | source |
| D-NEW-3 | S4 | The open Receive screen does not refresh in place when a payment lands on the shown address; it only advances on reopen. Present on the base build too (pre-existing). | keep the Receive tab open while funding it | `after/11-receive-still-index3.png` vs `after/14-receive-after-funding-reopened.png` |

## 9. Review concerns about the change itself

1. **The "not yet scanned" state is not handled** (D-NEW-1). `resolveReceiveAddress` cannot distinguish "the engine
   scanned and found nothing used" from "the engine has not scanned yet". A cheap guard would be: if the pool has
   rows but `none { it.isUsed }` **and** dashj's keychain *does* know issued/used keys (the upgrade case), prefer
   dashj; or gate on the SDK's own scan/sync watermark rather than only on `cutoverCommitted()`. The upgrade case
   is the one that actually regresses against the base build.
2. **`SweepWalletFragment` bypasses the new seam** (D-NEW-2) while the kdoc says it does not. Either route it
   through `application.freshReceiveAddress()` or correct the comment.
3. `WalletAddressFragment.java:193` also calls `wallet.currentReceiveAddress()` directly. It appears to be dead
   code (no references outside its own generated databinding class), but it is a second bypass if ever revived.
4. `currentBlockingOrNull()` / `freshBlockingOrNull()` use `runBlocking(Dispatchers.IO)` on the caller's thread.
   No StrictMode or ANR appeared in this session (all exercised callers are off-main as documented), but the Java
   seam is a latent main-thread hazard for any future caller; a `@WorkerThread`/`check(Looper.myLooper() != mainLooper)`
   assertion in debug builds would make that contract enforceable rather than documented.
5. Behaviour matches the docs everywhere else: `(current)` is stable and ignores the issued set, `(fresh)` walks
   above the issued floor, used indices are skipped, the issued set resets on process restart and on a new SDK
   wallet id, and the SDK pool read never blocked or crashed under trim-memory or offline conditions.

## 10. PR evidence (best artefacts)

| role | file |
|---|---|
| BEFORE screenshot (defect) | `before/10-payments-receive.png` — Receive tab showing `yRjAzoyf…` (#0, 10 tx appearances) |
| BEFORE proof | `before/11-insight-receive-tab.txt` + `before/14-insight-chain.txt` — insight `txApperances` for #0…#7 |
| AFTER screenshot (fixed) | `after/03-receive-tab.png` — Receive tab showing `ySu3d1Vc…` (#3, 0 appearances) |
| Decisive log excerpt | `after/08-resolver-loglines.txt` — `(current)` pinned to index 3 while `(fresh)` walks 3→5→6→7→8, `(35 rows, 4 used)` → `(35 rows, 5 used)` after the receive |
| Video | `after/after-receive-rotation.mp4` — the Receive tab across the faucet receive |
| Regression / new defect | `regression/31-upgrade-precutover-receive.png` + `regression/38-upgrade-resolver-log.txt` — the upgraded wallet showing the already-funded `yfyy4WKx…` at `index 0 (30 rows, 0 used)` before converging to `index 1 (31 rows, 1 used)` |
