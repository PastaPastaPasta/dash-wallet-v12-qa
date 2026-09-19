# PR-sr03-receive-address — running notes (emulator-5560, Android 15 / API 35, AVD dw-qa4)

- 16:26 booted dw-qa4 on port 5560 (emulator-5560 was not running at session start); API 35 confirmed.
- 16:27 `uninstall` then installed base-12000014-5f8c0a8ef.apk (versionCode 12000014, versionName 12.0.0-upgrade). md5 of base == fix-12.0.0-testnet3-release-signed.apk; sr03-0aa28b1d5.apk differs. logcat started.
- 16:28-16:33 BEFORE: restored QA seed `swamp dad … amazing`, PIN 1234, waited for `phase=SYNCED`, cutover `DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))` at 21:30:24.
- 16:34 BEFORE Receive tab = yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52 (ext #0, txApperances 10). quick-Receive identical. Specify Amount = ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9 (#1, txApperances 2). Zero `receive address` log lines (class absent on base).
- 16:37 uninstall; fresh install sr03-0aa28b1d5.apk; restored same seed; synced 16:40.
- 16:40-16:43 AFTER: Receive tab / quick-Receive = ySu3d1Vc… (#3, txApperances 0). Specify Amount x5 = #3,#5,#6,#7,#8 (skips used #4).
- 16:44 faucet drop 1/3 -> #3, txid aee399e9…; balance 2.923964 -> 3.923964; Receive tab advanced to ybr74Sjm… (#5) on reopen (log `index 5 … (35 rows, 5 used)`).
- 16:53 force-stop + relaunch: lock-screen Quick Receive 2 s after launch answered from the SDK pool (index 5), no dashj fallback. Rotation stable. Specify Amount after restart re-issued #5/#6 (process-scoped issued set — documented, acceptable).
- 16:57 regression (c): sent 0.01 to yRjAzoy… tx f854eace…; change went to yc4dR7NSaPe33FF3UHsmw6HXSZH741R2Dt (internal chain), not the shown receive address.
- 17:00 regression (d): could not flip the "dashj sync (diagnostic)" switch from uiautomator; no pref written. L1 shadow engine already running; resolver unaffected.
- 17:02-17:22 regression (a): MASTER 11.9.0 new wallet, key #0 yfyy4WKx…, faucet drop 2/3 txid 349ba6ee…; master rotated to ya5S49h1… (#1). `reinstall` candidate over it -> cutover 22:13:40; at 22:14:01 the resolver served **index 0 yfyy4WKx… (30 rows, 0 used)** = the already-funded address, and the Receive screen displayed it. Converged to index 1 ya5S49h1… (31 rows, 1 used) at 22:22:56.
- 17:24-17:28 regression (b): brand-new wallet on candidate -> index 0 yRsjBRMd…; faucet drop 3/3 txid 07433800…; advanced to index 1 yN51mmAp… (31 rows, 1 used).
- 17:29-17:32 adversarial mid-replay: fresh restore of the QA seed; during the first scan the Receive tab served **index 0 yRjAzoyf… (30 rows, 0 used)** (txApperances 10) for ~3 min after cutover, then converged to index 5.
- 17:33 low-memory trim RUNNING_CRITICAL and wifi/data off: address stable at index 5, no fallback, no crash.
- Unit tests: 16/16 pass (BUILD SUCCESSFUL in 58s).
- No ANR, no FATAL EXCEPTION, no process death other than PACKAGE UPDATED.
