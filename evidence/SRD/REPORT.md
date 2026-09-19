# SRD — SR device-reproduction report

| | |
|---|---|
| Emulator | `emulator-5560` (AVD **dw-qa4**, Android 15 / API 35, 1080x2400). The AVD was **not running** at task start; I booted it (`emulator -avd dw-qa4 -port 5560 -no-snapshot -no-boot-anim -no-audio -gpu swiftshader_indirect -no-window`). |
| Build under test | `apks/fix-12.0.0-testnet3-release-signed.apk` — versionCode **12000000**, versionName 12.0.0, minSdk 29, targetSdk 35 |
| Baseline (end of session only) | `apks/master-11.9.0-testnet3-release-signed.apk` — versionCode **11090002**, versionName 11.9.0 |
| Package | `hashengineering.darkcoin.wallet_test` |
| Seed used | S1 throwaway `swamp dad rent tower dumb cart dust vocal often today chimney amazing` (PIN 1234). Reference seed NOT touched. |
| Throwaway paper key created | WIF `cN8KqavRd5T2gzgxRhwg8oLu2Ks18ERNZVuGL45uJ1tjHU25NLnn` -> `ygbXcPBBUPXPwSbST711hEKdtgVmv9bPbB`, holds 0.01 tDASH (`SR-03-04/26-paperwallet-key.txt`) |
| Session | start **2026-09-19 11:42**, end **13:12** local. **wallet.log timestamps are local + 5 h** (log `17:21:20` = 12:21:20). |
| Permissions granted at onboarding | notifications = Allow, **battery-optimisation exemption = Allow** (`dumpsys deviceidle whitelist` -> `user,hashengineering.darkcoin.wallet_test,10208`) |
| Evidence root | `/Users/dcg/workspace/dash-wallet-qa/evidence/SRD/` (123 files) |
| Running journal | `/Users/dcg/workspace/dash-wallet-qa/evidence/SRD/notes.md` |

---

## Verdicts

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| **SR-06** | **PARTIAL — code defect CONFIRMED, "never delivered" DISPROVED** | Determined which scheduler branch runs on API 35 (alarm, never JobScheduler); forced a service teardown so `onDestroy` would arm the alarm; captured `dumpsys alarm` at arm time, 3 min past due, after delivery and after `force-stop`; polled service records every 60 s from 12:24 to 12:41 | `SR-06/05-alarm-entry-excerpt.txt`, `SR-06/08-alarm-still-pending-excerpt.txt`, `SR-06/09-alarm-fired-loglines.txt`, `SR-06/11-dumpsys-alarm-after-fire-next-is-24h.txt`, `SR-06/06-alarm-delivery-watch.txt`, `SR-06/13-dumpsys-alarm-after-forcestop.txt` | The alarm IS armed with an **18-hour delivery window** and a **24-hour repeat**, exactly as `WalletApplication.java:1818` predicts. It missed its nominal 15-min time by 4 m 23 s, then re-armed for **+24 h**. It *was* delivered and the background FGS start *was* permitted (battery-exempt emulator). |
| **SR-09** | **REPRODUCED** | Reached an idle verdict while MainActivity was foregrounded+bound, then pressed HOME and polled `dumpsys activity services` every 10 s | `SR-09/09-latch-set.txt`, `SR-09/11-service-after-latched-home.txt`, `SR-06/03-alarm-armed-loglines.txt` | Service survived `stopSelf()` while bound, then **died within 10 s** of HOME. Happened **twice** (12:21:20 forced, 12:55:42 spontaneous). But "`idling detected` every minute forever" (D-004) is **not** what happens — 4 verdicts in 49 tick-minutes — and a receive **was** noticed and notified while backgrounded. |
| **SR-03** | **REPRODUCED** | Restored the S1 seed, let it sync, read the address off the Receive tab and the home quick-Receive; derived the seed's BIP44 external chain offline and checked every address on Insight | `SR-03-04/10-receive-tab.png`, `SR-03-04/13-payments.png`, `SR-03-04/20-derived-external-addrs.txt`, `SR-03-04/21-explorer-txapperances.txt`, `SR-03-04/11-addr-quickreceive.json` | The displayed address is **exactly `m/44'/1'/0'/0/0` (external key #0)** with `txApperances=5`. After a new receive landed on #0 it advanced to **#1**, itself `txApperances=2`. Not "pinned to #0 forever" — it walks the chain from #0 and re-publishes the whole used range. |
| **SR-04** | **PARTIAL / BLOCKED** | Tried both reachable `freshReceiveAddress()` consumers: Topper and the paper-wallet sweep | `SR-03-04/18-topper-crash-walletlog.txt`, `SR-03-04/17-topper.png`, `SR-04-sweep/09-import-key.png`, `SR-04-sweep/11-scanner.png` | Topper **hard-crashes the app** before producing a URL (stub key — NEW-1). The sweep is camera-QR only and `SweepWalletActivity.INTENT_EXTRA_KEY` is a `Serializable`, so it cannot be injected over adb. No fresh address observable on device. |
| **SR-33** | **REPRODUCED (default confirmed, pre-existing)** | Read More > Security > Advanced Security on a fresh 12.0.0 restore and again on a brand-new wallet under master 11.9.0 | `SR-33-34/07-advanced-security-default.png`, `SR-33-master/04-master-advanced-security-default.png`, `SR-33-34/02-autologout-loglines.txt` | Both builds: Auto Logout ON, **"Logout after 1 min"**, Security Level High. Observed live: the app locked ~40 s after reaching the home screen during the initial sync. |
| **SR-34** | **REPRODUCED (Immediately works) / rotation hazard NOT REPRODUCED** | Set Auto-logout to "Immediately" (`auto_logout_minutes=0`), pressed HOME and returned; then rotated | `SR-33-34/08-immediately-set.png`, `SR-33-34/10-after-return-from-home.png`, `SR-33-34/15-networkmonitor-landscape.png`, `SR-33-34/16-rotate-guard-loglines.txt` | HOME->return locks instantly. Rotation does **not** lock. `MainActivity` is `android:screenOrientation="portrait"` so it cannot rotate; on a rotatable screen (NetworkMonitorActivity) the `isChangingConfigurations` guard fires and logs `stopped for a configuration change — not treating it as background`. |

---

## Detail

### SR-06 — periodic background-sync alarm

**Which branch runs.** `WalletApplication.scheduleStartBlockchainService` only uses JobScheduler when
`SDK_INT == O || SDK_INT == O_MR1` (API 26/27). On API 35 the `else if (!cancelOnly)` branch runs:
`alarmManager.setInexactRepeating(RTC_WAKEUP, now + alarmInterval, AlarmManager.INTERVAL_DAY, alarmIntent)`.
Confirmed on device: `dumpsys jobscheduler` never showed a job for the package
(`SR-06/02-dumpsys-jobscheduler-before-home.txt`), and `scheduling blockchain sync job` / `already scheduled`
never appear in wallet.log.

**Who arms it.** Exactly one call site in the app: `BlockchainServiceImpl.kt:2909`, inside the service teardown
(`WalletApplication.java:1887` only cancels). Same in `wt-master` (`BlockchainServiceImpl.kt:1909`) — not a
regression. Consequence: **while the app is in the foreground and the service is alive there is no alarm and no
job at all** — verified at 12:06 (`SR-06/01-dumpsys-alarm-before-home.txt`: the only `darkcoin` hit in the whole
dump is the deviceidle whitelist line).

**Timeline (local; wallet.log = +5 h):**

| Time | Event | Evidence |
|---|---|---|
| 12:06:48 | HOME pressed, app backgrounded | `SR-09/05-service-after-home.txt` |
| 12:06:48-12:16 | Service stays alive, **no alarm, no job** for ~10 min | `SR-09/05-service-after-home.txt` |
| 12:16:47 | `net off` to force an idle verdict | notes.md |
| 12:21:00 | `idling detected, stopping service` (app still foreground/bound) | wallet.log:5292 |
| 12:21:21 | HOME pressed | |
| 12:21:20 | `.onDestroy()` -> alarm armed | wallet.log:5447-5455 |
| 12:24-12:39 | `ServiceRecords=0 pendingAlarms=1` every 60 s | `SR-06/06-alarm-delivery-watch.txt` |
| 12:36:20 | nominal fire time — **nothing happens** | `SR-06/08-alarm-still-pending-excerpt.txt` (`whenElapsed=-3m14s`, `count=0`) |
| **12:40:43** | alarm finally delivered, FGS start permitted, service restarted | `SR-06/09-alarm-fired-loglines.txt` |
| 12:40:45 | `L1 shadow SPV started ...` — background sync resumed, UI still closed | `SR-06/10-service-start-after-alarm.txt` |
| 12:41:47 | `am force-stop` -> alarm **cancelled** (`Reason=pi_cancelled`), `procs=0` | `SR-06/13-dumpsys-alarm-after-forcestop.txt:588-590` |

**The app's own log** (`SR-06/14-all-alarm-diag-lines.txt`):

```
17:21:20 [DefaultDispatcher-worker-4] WalletApplication - last used 4 minutes ago, rescheduling blockchain sync in roughly 15 minutes
17:21:20 [DefaultDispatcher-worker-4] WalletApplication - ALARM-DIAG armed reason=periodic-15min firstFireInMinutes=15 repeat=1440min exact=false batteryOptimisationExempt=true - if no matching 'started by alarm' line follows, the background FGS start was refused
17:40:43 [main] BlockchainServiceImpl - ALARM-DIAG service started by alarm (reason=periodic-15min) — a background FGS start WAS permitted
```

**What `dumpsys alarm` shows right after arming** (`SR-06/05-alarm-entry-excerpt.txt`):

```
RTC_WAKEUP #7: Alarm{a069021 type 0 origWhen 1789839380673 whenElapsed 3263215 hashengineering.darkcoin.wallet_test}
  tag=*walarm*:hashengineering.darkcoin.wallet_test/de.schildbach.wallet.service.BlockchainServiceImpl
  type=RTC_WAKEUP origWhen=2026-09-19 12:36:20.673 window=+18h0m0s0ms repeatInterval=86400000 count=0 flags=0x8
  whenElapsed=+12m48s764ms maxWhenElapsed=+18h12m48s764ms
  operation=PendingIntent{f3b9c46: PendingIntentRecord{a230e07 hashengineering.darkcoin.wallet_test startForegroundService}}
```

`window=+18h0m0s0ms` / `maxWhenElapsed=+18h12m48s` is the bug made visible: because `INTERVAL_DAY` is passed as
the repeat interval, AlarmManager derives an **18-hour** window for an alarm the code believes it scheduled for
15 minutes. **After the single delivery it re-arms for +24 h**
(`SR-06/11-dumpsys-alarm-after-fire-next-is-24h.txt`):

```
type=RTC_WAKEUP origWhen=2026-09-20 12:36:20.673 window=+18h0m0s0ms repeatInterval=86400000 count=0 flags=0x8
whenElapsed=+23h55m12s343ms maxWhenElapsed=+1d17h55m12s343ms
```

**Verdict nuance.** The SR row says "the alarm is never delivered". On this device — screen on, no doze, network
up, battery-optimisation exemption granted, process still cached — it *was* delivered 4 m 23 s late and the
background FGS start was permitted. What is unambiguously reproduced:

1. the computed backoff (15 min / 12 h / 24 h) applies **only to the first fire**; every subsequent background
   sync is a **day** apart (`repeatInterval=86400000`) regardless of the chosen backoff;
2. every occurrence carries an **18-hour** inexact window, so delivery time is effectively unbounded — on a
   dozing, non-exempt handset the SR claim is very likely to hold and this lab is not the worst case;
3. the alarm is armed **only** from `BlockchainServiceImpl.onDestroy()`, so a process killed without teardown
   leaves nothing armed, and an explicit `force-stop` **cancels** the armed alarm (`Reason=pi_cancelled`), after
   which only opening the app or a reboot (`BootstrapReceiver`, `AndroidManifest.xml:396-405`) restarts sync.

**What the user would see:** a wallet left in the background refreshes roughly once a day at an unpredictable
hour instead of every 15 minutes after recent use.

### SR-09 — idle `stopSelf()` latches; service dies on leaving MainActivity

**Part 1 — "idling detected every minute forever" (D-004): NOT reproduced.** Across 49 idle-detector ticks in
`logs-final/files/log/wallet.log` there were **4** verdicts (log 16:56:00, 16:57:00, 17:21:00, 17:55:00). Testnet
blocks keep `blocksDownloaded/headersDownloaded/mnListDiffs` non-zero inside the 2-minute recency window most
minutes, so the rule mostly does not trip; I had to cut the network (12:16:47) to get one on demand.

**Part 2 — the latch: REPRODUCED.**

```
17:21:00 [main] BlockchainServiceImpl - idling detected, stopping service      <- app FOREGROUND and bound
```
Immediately after (`SR-09/09-latch-set.txt`, 12:21:11) the service was still alive — `stopSelf()` cannot destroy
a bound service. 10 s after HOME it was gone (`SR-09/11-service-after-latched-home.txt`):

```
12:21:21 t+0s  ServiceRecords=1 app_procs=1
12:21:31 t+10s ServiceRecords=0 app_procs=1
... (0 for the full 2 minutes)
```
with `17:21:20 [main] BlockchainServiceImpl - .onDestroy()` in wallet.log. The **same sequence recurred
spontaneously** at 17:55:00 / 17:55:42 when I backed out of Advanced Security — not an artefact of the network cut.

Control: pressing HOME **without** a pending latch (12:06:48) left the service running for the full 2-minute poll
and another ~10 minutes (`SR-09/05-service-after-home.txt`).

**Part 3 — does a backgrounded app notice incoming funds? YES, while the service is alive.** A faucet payment of
0.98999390 tDASH (tx `61dd9f06d875526f683a62e754bdb171d40044a2bae674468d57789a73f79aef`) landed while the app had
been backgrounded since 12:06:48 (`SR-09/13-background-receive-loglines.txt`):

```
17:11:49 [DefaultDispatcher-worker-9] L1ShadowSyncService - L1 engine tx event: Detected(txidHex=61dd9f06…, netAmountDuffs=98999390, …)
17:11:49 [DefaultDispatcher-worker-6] CutoverUiDataService - SDK balance published: 193397454 duffs (was 94398064) | l1Synced=true …
17:11:49 [DefaultDispatcher-worker-7] CutoverUiDataService - engine-detected receive 61dd9f06… (98999390 duffs) — notifying in 2000ms unless an outgoing sibling classifies it internal
```
`logcat.txt:34992` at `12:11:52.050` shows the notification actually posting with sound
(`requestAudioFocus() ... AA=USAGE_NOTIFICATION ... callingPack=com.android.systemui`, channel
`dash.notifications.transactions`). The "user learns nothing until they reopen" half of the story only applies
once the latch has killed the service.

**Part 4 — reopening.** After `force-stop` at 12:41:47, `am start` at 12:42:15 had MainActivity focused and
`BlockchainServiceImpl` running by 12:42:21 (<= 6 s); the correct balance was on screen as soon as the PIN was
entered (`SR-09/12-reopened.png`, 1.943975 tDASH).

### SR-03 / SR-04 — receive address on a restored keychain

Offline derivation of the S1 seed (`SR-03-04/derive.py`, pure-stdlib BIP39->BIP32->Dash-testnet P2PKH) plus
Insight lookups (`SR-03-04/21-explorer-txapperances.txt`, one JSON per address in `SR-03-04/22-addr-idx*.json`),
taken **before** any new funds arrived:

```
m/44'/1'/0'/0/0   yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52   txApperances=5  totalReceived=1.02        <- shown by the app
m/44'/1'/0'/0/1   ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9   txApperances=2  totalReceived=0.001
m/44'/1'/0'/0/2   ydpETkGNb856diaqJoPiUptbVVPEpx5aVW   txApperances=2  totalReceived=1
m/44'/1'/0'/0/3   ySu3d1VcumES35pzwPHWNuTPFZE4AghPNj   txApperances=0
m/44'/1'/0'/0/4   yMknkjqmb8M2gxwB1V4uDSoWVbLN2SsZq3   txApperances=2  totalReceived=0.95235766
m/44'/1'/0'/0/5..11                                    txApperances=0
```

* **Receive tab** (bottom-nav Payments > Receive) -> `yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52` (`SR-03-04/13-payments.png`)
* **Home shortcut "Receive" / quick receive** -> the same address (`SR-03-04/10-receive-tab.png`)

Both are external key **#0** with five prior on-chain appearances, chosen even though #5 onwards are pristine.
Side effect worth calling out: the faucet refused that address with *"That address already received 1 tDASH
today"* — handing out #0 to every restore makes wallets collide with per-address rate limits and destroys
receive-address privacy.

After a new payment landed on #0, the Receive tab moved to **#1** — `ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9`,
`txApperances=2` (`SR-03-04/24-receive-after-3-receives.png`, `SR-03-04/25-addr-idx1-now.json`). Accurate
statement: *the restored keychain starts at index 0 and advances one index per receive observed by this
installation, re-publishing the seed's whole used range* — not "pinned to #0 forever".

**SR-04** could not be observed on device:
* `More > Buy & Sell > Topper` kills the process before any URL exists (NEW-1). The address never reaches a
  screen, and would not be readable in the URL anyway: `TopperClient.getOnRampUrl` returns `...?bt=<signed JWT>`
  with the receiver address inside the token.
* `Receive > Import Private Key` offers only **"Scan Private Key"** (camera QR). I created and funded a paper
  wallet for it (0.01 tDASH, tx confirmed) but there is no way to present a QR to the emulator, and
  `SweepWalletActivity.INTENT_EXTRA_KEY` is a `Serializable PrefixedChecksummedBytes`, so `am start --es` cannot
  supply it.
* Uphold/Coinbase are unusable in this build ("Keys are missing for these services").

Code-wise the SR row is accurate: `BuyAndSellViewModel.kt:271-278`, `ShortcutsViewModel.kt:211-218` and
`SweepWalletFragment.java:621` all go through `freshReceiveAddress()` /
`WalletDataProviderExt.freshReceiveAddressStringOffMain()`, i.e. the same keychain whose pointer SR-03 shows at #0.

### SR-33 / SR-34 — auto-lock defaults

* **Default (12.0.0):** `SR-33-34/07-advanced-security-default.png` — Security Level **High**, Auto Logout **on**,
  **"Logout after 1 min"**, slider one notch from "Immediately". `shared_prefs` contains **no** `auto_logout_*`
  key on a fresh restore, so the value comes from `Configuration.java:164,172` (`true`, `1`).
* **Default (master 11.9.0, brand-new wallet):** identical — `SR-33-master/04-master-advanced-security-default.png`;
  master additionally writes `auto_logout_minutes=1` into prefs explicitly. `Configuration.java:164,172` is
  byte-identical in `wt-master`. **SR-33 is pre-existing, not a 12.0.0 regression.**
* **Observed live:** at 11:47:47 (log `17:47:47 LockScreenActivity - LockState = ENTER_PIN`) the app locked itself
  ~40 s after reaching the home screen while the initial sync was still running, with no user input in between
  (`SR-33-34/01-after-idle-9min.png`). During a 9-minute unattended sync poll every `uiautomator` sample showed
  the PIN pad.
* **"Immediately" (SR-34):** slider to the far left -> `auto_logout_minutes=0`, Security Level becomes "Very High"
  (`SR-33-34/08-immediately-set.png`). HOME at 12:50:24, return 4 s later -> **Enter PIN**
  (`SR-33-34/10-after-return-from-home.png`). Works as designed.
* **Rotation:** does **not** lock. `MainActivity` is `android:screenOrientation="portrait"`
  (`wallet/AndroidManifest.xml:117`), so `$APP rotate 1` is a no-op there — the SR-34 source comment listing
  MainActivity among the unpinned activities refers to the legacy `de.schildbach.wallet.MainActivity` alias, not
  `de.schildbach.wallet.ui.main.MainActivity`. On a genuinely rotatable screen (NetworkMonitorActivity, confirmed
  `mDisplayRotation=ROTATION_90`, `SR-33-34/15-networkmonitor-landscape.png`) with `Immediately` set the guard
  holds (`SR-33-34/16-rotate-guard-loglines.txt`):
  ```
  17:52:34 [main] WalletActivityTracker - activity lifecycle: NetworkMonitorActivity stopped for a configuration change — not treating it as background
  ```
  Unpinned, unhandled activities: `de.schildbach.wallet.MainActivity` (alias), `AddressBookActivity`,
  `NetworkMonitorActivity`, `BlockInfoActivity`, `ScanActivity`, `SweepWalletActivity`, `WalletUriHandlerActivity`,
  `InviteHandlerActivity`, `ImportSharedImageActivity` — none locked on rotation.

---

## New findings

| # | Severity | Finding | Repro | Evidence |
|---|---|---|---|---|
| **NEW-1** | **S2** | **Topper crashes the whole app with an uncaught exception when its API key is unusable.** `BuyAndSellViewModel.topperBuyUrl` calls `TopperClient.getOnRampUrl` on `Dispatchers.Main.immediate` with no guard; `Decoders.BASE64.decode(privateKey)` throws `io.jsonwebtoken.io.DecodingException: Illegal base64 character: '_'` and the process dies. `TopperClient.hasValidCredentials` exists but is never consulted, and the Buy & Sell list greys out Uphold/Coinbase for missing keys while leaving Topper tappable. | More > Buy & Sell > tap **Topper** | `SR-03-04/17-topper.png`, `SR-03-04/18-topper-crash-walletlog.txt`, `SR-03-04/18-topper-crash-logcat.txt`, `SR-03-04/19-crash-dialog.png`; `TopperClient.kt:91`, `BuyAndSellViewModel.kt:272` |
| **NEW-2** | S3 | **A stale periodic alarm is never cancelled when the service comes back.** `alarmManager.cancel()` only runs inside `scheduleStartBlockchainService`, which only runs from `onDestroy`. After the 12:40:43 delivery the app re-armed for +24 h and kept it armed while the app was foreground with the service already running, so the `startForegroundService` PendingIntent can fire against a live service. | Background the app until teardown, reopen it, read `dumpsys alarm` | `SR-06/11-dumpsys-alarm-after-fire-next-is-24h.txt`, `SR-06/14-all-alarm-diag-lines.txt` |
| **NEW-3** | S3 | **`force-stop` cancels the background-sync alarm permanently.** After `am force-stop` the alarm is gone (`Reason=pi_cancelled`) and no job exists, so background sync never resumes until the user opens the app or reboots. | `am force-stop hashengineering.darkcoin.wallet_test` then `dumpsys alarm` | `SR-06/13-dumpsys-alarm-after-forcestop.txt:587-590` |
| **NEW-4** | S4 | **Restored wallets collide on the faucet / on-chain privacy because every restore republishes key #0.** Requesting testnet coins for the address the app displayed was refused with *"That address already received 1 tDASH today"* — a direct user-visible consequence of SR-03. | Restore any previously-used seed, open Receive, request from a per-address rate-limited service | `SR-03-04/21-explorer-txapperances.txt`, notes.md 12:09 |

## Environment problems

* AVD `dw-qa4` was **not booted** at task start and had to be launched manually; it also carried a **pre-existing
  wallet** from an earlier session, so I ran `pm clear` before restoring the S1 seed.
* `$APP <serial> text 1234` does not drive the PIN pad (matches SRB's note). Tapping by `resource-id` also failed
  intermittently — three fast taps produced "Wrong PIN" three times and tripped the "Wallet disabled — try again
  in 1 minute" lockout (5 of 8 attempts consumed). Reliable recipe: `adb shell input tap <center>` per digit with
  >= 1.2 s between taps.
* The shared faucet's **hourly limit (10/h) was exhausted** by other streams for most of the session, and its
  "already received today" message is emitted even for addresses that then do receive — two of my three requests
  landed several minutes after the UI claimed they were refused.
* Topper/Uphold/Coinbase keys are stubs in the QA build (`service.properties`), which is what surfaces NEW-1 and
  blocks the SR-04 consumers.
* The paper-wallet test key `cN8KqavRd5T2gzgxRhwg8oLu2Ks18ERNZVuGL45uJ1tjHU25NLnn` still holds **0.01 tDASH**.
* 12.0.0 was **uninstalled at 13:05** and master 11.9.0 installed for the SR-33 baseline, so the device now holds a
  brand-new empty 11.9.0 wallet, not the S1 restore.
