# QA report: Stream S9 (X1-X8)   (agent: Opus S9, emulator: emulator-5564 / dw-qa6, 2026-09-19 01:29-03:27 CDT)

Build under test: `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29 / targetSdk 35.
Mainnet `hashengineering.darkcoin.wallet` uninstalled first; testnet package `hashengineering.darkcoin.wallet_test` installed clean.
Throwaway wallet seed (in `notes.md`): `[seed phrase redacted]`, PIN 1234.
Faucet: 1 tDASH to `yYxUzAE8SNndkcnWyt1RRXEUvbHVV12Bdk`, txid `afcfb69ab343b09c09d2bce10e880964279112da1a92e8622ef6ea2354daf267`.

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| X1 Sends fail after idle teardown (D-031) | **NOT REPRODUCED** (5/5 sends succeeded) | `X1/x1-cycle4-failed-send.mp4`, `X1/43-c4-RESULT.png`, `final-logs/files/log/wallet.log` | 4 idle teardowns observed; the L1 engine restarted 0s/0s/19s/19s later and every send broadcast fine - but the teardown itself is real and frequent (every 6-24 min) |
| X2 Network monitor (SDK rewrite) | **FAIL** | `X2/03-netmon-synced.png`, `X2/11-netmon-airplane-4min.png`, `X2/13-netmon-during-sync.png`, `X2/04-netmon-landscape.png` | Stage labels/heights/ChainLock/rotation correct online, but with all networking off 4-5 min it still reads "Synced / Connected to the Dash network" |
| X3 Sync status "unable to connect" | **FAIL** | `X3/02-home-no-net.png`, `X3/04-netmon-no-net.png`, `X3/06-netmon-no-net-5min.png`, `X3/10-home-after-reconnect.png` | `sync_status_unable_to_connect` never appears anywhere; also a transient ~2x wrong balance (1.996984) on cold start. Reconnect after network restore: 6 s |
| X4 CSV export | **PASS (caveat)** | `X4/dash-wallet-transactions-2026-09-19.csv`, `X4/03-share-sheet.png`, `X4/13-csv-empty-result.png` | Share sheet reached, file correct; 1 row for a 5-tx wallet because internal self-transfers (and their real fees) are excluded by design. Empty-wallet message correct |
| X5 Safe-mode / degraded startup | **PASS (caveat)** | `X5/x5-safemode.mp4`, `X5/09-safemode-message.png`, `X5/11-recovered-home.png` | Unreadable + truncated wallet files both auto-recover from `key-backup-protobuf-testnet` with the correct balance; safe mode + "Try Again" works, but the ACRA crash sheet covers the explanation first |
| X6 6-hour foreground-service notice | **NOT RUN** (per instruction) | code grep | Channel + both strings exist and are wired to `onTimeout()` |
| X7 DashPay contact-request error surfaces | **PARTIAL FAIL** | `X7/44-request-airplane.png`, `X7/50-request-result.png`, `X7/52-search-nonexistent.png` | Offline "Send request" is silently inert (no `send_contact_request_error_*` ever shown). Online path, pending list and not-found empty state all correct |
| X8 Notification channels | **PASS** | `X8/01-notification-channels.png` | All 6 channels present incl. `dash.notifications.ongoing` (Synchronization) and `dash.notifications.contacts` (Contact requests) |

Memory over the 2 h session (`mem.csv`, 117 samples @60 s): peak **TOTAL PSS 406,696 KB (397 MB)**, peak Dalvik heap 42,021 KB. `oom-exitinfo.txt`: every process exit is `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` - **no LMK, no OOM, no ANR, no crash** all session.

## Per-test detail

### X1 - Sends after the idle teardown (D-031 clean repro attempt)

Five cycles, each ending in a real 0.001 tDASH self-send.

| Cycle | Protocol | Teardown seen | Send |
|---|---|---|---|
| 1 | home fg 3 min (3 auto-locks) -> HOME 3 min -> fg -> unlock -> send | **none** | OK, txid `645fbe3ca203b11dc70a04429992dd93fa058dc0d5fb0f33575c72ae80f918d7` |
| 2 | same protocol repeated | **none** | not attempted (no teardown to test against) |
| 3 | orchestrator variant: Tools > Network monitor left untouched 5.5 min | teardown #1 `06:58:00`, #2 `07:04:35` | OK, txid `31bc6adc0655d87c001b65c9e95dc5473ed753d6d37e668eb97d74efaf95c6ec` |
| 4 | HOME for 9 min (until the teardown fired with the app backgrounded) | teardown #3 `07:16:00`, **no resume while backgrounded** | OK, txid `f31d78d048051dc13a2aca824fd614177dc794abbe301738cd854d333daf1ebe` |
| 5 | race: `dash:` deeplink fired seconds after teardown #4 | teardown #4 `07:32:00` | OK, txid `1c3cff5d3cb51057a5da9a1c545a1e256bb94445075e30eae8d5d669fafb4ebc` |

Log (`final-logs/files/log/wallet.log`):
```
06:58:00 BlockchainServiceImpl - idling detected, stopping service
06:58:14 BlockchainServiceImpl - .onDestroy()
06:58:14 L1ShadowSyncService - L1ShadowLifecycle STOPPED after 24m24s up; all four loops torn down ...; teardown #1 this process. Nothing runs until the next startIfEnabled().
06:58:15 L1ShadowSyncService - L1ShadowLifecycle RESUMING after 0s down (teardown #1 this process)
07:01:00 idling detected, stopping service   07:04:35 onDestroy -> STOPPED (#2) -> 07:04:36 RESUMING after 0s down
07:16:00 idling detected, stopping service -> onDestroy -> STOPPED (#3)  [backgrounded: NO resume]
07:16:20 L1ShadowLifecycle RESUMING after 19s down (teardown #3)   <- triggered by foregrounding the app
07:17:27 SdkL1SendService - SDK l1Send: broadcast 100000 duffs to yYxUzAE8..., txid f31d78d0...
07:32:00 idling detected ... STOPPED (#4)   07:32:20 RESUMING after 19s down   07:33:11 l1Send broadcast OK
```
No `SendEngineNotSyncedException`, no "funding gate closed", no "not fully synced" dialog in any cycle.

Why cycles 1-2 never tripped the detector: `SyncActivityIdleDetector.IDLE_TRANSACTION_TIMEOUT_MIN = 9` - any wallet tx event in the last 9 samples keeps the service "active", and the faucet receive / each self-send resets that window. Once >9 min has passed since the last tx, 3 consecutive block-less minutes suffice; on live testnet that happened every 6-24 minutes (4 times in 100 minutes).

**Conclusion:** the SR-09/D-031 teardown is real and frequent on this build, but the recovery path (`startIfEnabled()` on app foreground) works here - the engine is back in 0-19 s and sends succeed. Residual exposure is the ~13-19 s window right after foregrounding; I could not land a send inside it even driving the flow from a `dash:` deeplink. S7's device-observed failure (engine down 3 m 17 s) did not recur.
Videos: `X1/x1-cycle1-send.mp4`, `x1-cycle3-send.mp4`, `x1-cycle4-failed-send.mp4`, `x1-race-send.mp4`.

Side observations in X1:
- Confirm sheet shows **Network fee 0.0001 / Total 0.0011** but the broadcast paid **226 duffs (0.00000226)** - SR-28 confirmed on device (`X1/28-after-pin-send.png` vs `X1/29-send-result.png`).
- The success sheet for a self-send reads "Sent to `ybhMKMNdRvuKiMrNgmQ13RnGmAMXErLchg`" (the **change** address, not the entered destination) and "Amount Sent -0.00000226".
- Receive screen still showed the used address `yYxUzAE8...` right after the faucet receive (`X1/18-receive-2nd.png`) but had rotated to `yMUsXaTRuRSGHC34tBkpZnXEMVt6UTQXFJ` by 02:59 (`X7/02-payments.png`) - D-003 is a delay, not a permanent pin, on a wallet created on the fix build.

### X2 - Network monitor

Online, synced (`X2/03-netmon-synced.png`): "Synced / Connected to the Dash network", Block headers / Block filters / Masternode list height / ChainLock height all 1,556,595, plus "The wallet engine does not report individual peer connections." and "Peer and block lists come from the dashj diagnostic engine. Turn on dashj sync in Tools to view them." Rotation to landscape and back is clean, no lock, no data loss (`X2/04`, `X2/05`).

During sync (`X2/13-netmon-during-sync.png`): stage label "Downloading block headers", "99%", ranges "1,556,616 / 1,556,621" - per-stage labels work.

Airplane mode ON while running and synced, checked at 1 / 2 / 4 minutes (`X2/09,10,11`): unchanged "Synced / Connected to the Dash network", heights frozen at 1,556,616. The engine's own last phase line was `07:44:53 L1Shadow phase=HEADERS` and then nothing. Net restored -> "Downloading block headers 99%" then Synced 1,556,622 (`X2/12`, `X2/15`).

### X3 - "unable to connect"

Cold launch with wifi+data disabled:
- Home header briefly showed **1.996984 tDASH** - ~2x the true balance - for >30 s (`X3/02`, `X3/03`), then settled to 0.999991 with the "Syncing balance" label (`X3/07`). Root cause in the log: `07:41:08 L1ShadowSyncService - WalletBalanceFacts: total=199698418 ... confirmed=99999322 unconfirmed=99699096 txCount=5`.
- Network monitor after 5 min offline: still "Synced / Connected to the Dash network", heights 1,556,608 (`X3/04`, `X3/06`), while the engine had reported `07:35:32 L1Shadow phase=CONNECTING`.
- Home header never says "Unable to connect to the Dash network" (`sync_status_unable_to_connect`, `wallet/res/values/strings-extra.xml:375`); grepping `wallet/src` shows **no code reference to that string at all**.
- Recovery: network enabled 07:41:35 -> `07:41:37 phase=MASTERNODES` (2 s) -> `07:41:41 phase=SYNCED` 1,556,613 (6 s).

### X4 - CSV export

5 transactions (`dash-sdk.db transactions = 5`; 1 Received + 4 Internal, `X4/04-home-txlist.png`). Export reaches the share sheet as `dash-wallet-transactions-2026-09-19.csv` (`X4/03`); the file lands in `/data/data/<pkg>/cache/report/` and is pulled to `X4/dash-wallet-transactions-2026-09-19.csv`. Content: header + **1 row** -
```
2026-09-19T06:35:54Z,Income,,DASH,DASH Wallet,1.00,DASH,DASH Wallet,,,,afcfb69ab343b09c09d2bce10e880964279112da1a92e8622ef6ea2354daf267
```
Amount, date and txid correct. The 4 internal self-sends are excluded deliberately (`CSVExporter.kt:60`, `shouldExclude = excludeInternal && isInternal(tx) && opReturnBurnDuffs(tx) == 0L`), so 1 row vs 5 UI rows is by design - but the ~904 duffs of real fees those txs paid are absent, and `Fee`/`Fee Currency` are hard-wired empty (`TaxBitExporter.kt:42-43`).

Empty wallet (after Reset Wallet -> Create new wallet): "There are no transactions to export yet." (`X4/13`) - `report_transaction_history_dialog_export_csv_empty` correct.

### X5 - Safe-mode / degraded startup

Wallet file `/data/data/<pkg>/files/wallet-protobuf-testnet` (178,383 bytes). Video `X5/x5-safemode.mp4`.

1. `chmod 000` + launch -> **no** error screen. `07:52:03 WalletApplication - wallet restored from backup: 'key-backup-protobuf-testnet'`, breadcrumb `96 WALLET_RECOVERED_FROM_BACKUP +1986ms`, home shows the correct 0.999991 (`X5/02`, `X5/03`). Every autosave then throws `java.io.FileNotFoundException: .../wallet-protobuf-testnet: open failed: EACCES` silently.
2. `chmod 600` + `chown u0_a209` + relaunch -> wallet intact, 0.999991 (`X5/04`).
3. Truncate to 89,191 of 178,383 bytes + launch -> recovered from backup in 524 ms, balance correct (`X5/06`). Backup restored afterwards.
4. Forced safe mode (breadcrumb trail rewritten to `previous=INCOMPLETE_PRE_MILESTONE prevLastStage=4`, `startup.failures=1`): header became `failures=1 safeModeRuns=1 safeMode=true`, breadcrumb `91 WALLET_LOAD_SKIPPED_SAFE_MODE +165ms`. The **first** thing the user sees is the generic ACRA sheet "Previous crash detected / Would you like to send a crash report..." (`X5/07`); only after Cancel does `safe_mode_startup_message` + **Try Again / Report / Close** appear (`X5/09`). "Try Again" -> `98 SAFE_MODE_RETRY` -> `99 SAFE_MODE_RETRY_OK`, wallet loads, balance 0.999991 (`X5/11`).

### X6 - 6-hour foreground-service notice - NOT RUN

- `wallet/res/values/strings.xml:397` `notification_background_processes_paused` = "Background processing paused"
- `wallet/res/values/strings.xml:398` `notification_background_processes_paused_text` = "You've reached the Android 6-hour foreground service limit for blockchain sync. Tap to reset..."
- Used at `wallet/src/de/schildbach/wallet/service/BlockchainServiceImpl.kt:3077` and `:3079`, reached from `override fun onTimeout(startId, fgsType)` at `:3044`. A test-only simulation hook exists at `:2099-2104` (`TEST_TIMEOUT_MINUTES`) but is not enabled in the release build.

### X7 - DashPay contact requests

- **Without an identity there is no contacts UI at all**: bottom nav has 3 items and the home card routes to "Welcome to Dash Pay / Create a username" (`X7/04`). Searching for `qa1s13939` and hitting a "no identity" error is unreachable.
- Shield 0.99999096 -> shielded 0.997 (fee ~0.003), but only after a kill+relaunch (defect S9-D5): `X7/12`, `X7/19`, `X7/21`.
- Username **`qa9s9zkrmvtpqwxnb3d7`** (20 chars, non-contested) created from the shielded pool for 0.03: `08:16:34 BlockchainIdentityData - creation: BlockchainIdentityData(DONE, qa9s9zkrmvtpqwxnb3d7, CONFIRMED, null, null, DHP9CGTqKAcMt83ryjDosYGEGD3sKzxe9wW9SocKvco5)` (`X7/26`-`X7/34`). No transaction-history row was written for it (confirms D-007 / SR-11) - only the "Shielded" row appears (`X7/39`).
- **Airplane mode + "Send request"**: tapped twice, waited 30 s - the button is completely inert. No spinner, no toast, no `send_contact_request_error_title`/`_message` dialog, no state change (`X7/44`, `X7/45`). Only background DAPI "tcp connect error" noise in the log.
- Network back on -> "Send request" -> "Request sent", Activity row "Contact request sent 3:22 AM" (`X7/50`); Contacts shows "Pending Requests (1) / QA Stream Five / Contact Request Pending" (`X7/51`).
- Non-existent `zzzznotarealuser9999` -> clean empty state "There are no users that match ..." (`X7/52`).

### X8 - Notification channels

`am start -a android.settings.APP_NOTIFICATION_SETTINGS ...` (`X8/01`) plus `/data/system/notification_policy.xml`. All six channels present and enabled:

| id | name | description |
|---|---|---|
| `dash.notifications.ongoing` | Synchronization | "Shows a notification when the app is synchronizing with the network." |
| `dash.notifications.generic` | Generic notifications | "Other Dash Wallet events" |
| `dash.notifications.contacts` | Contact requests | "Alerts you when someone sends you a contact request." |
| `dash.notifications.dashpay` | DashPay | "Status of ongoing DashPay operations." |
| `dash.notifications.push` | Push Notifications | "Shows push notifications sent to you by Dash" |
| `dash.notifications.transactions` | Transactions | "Receive alerts about incoming transactions." |

No live sync foreground notification was posted while I looked (`X8/03-shade.png`) - the wallet was already synced.

## Defects found

| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| S9-D1 | **S2** | Network monitor and home header never show a disconnected state: with wifi+data off for 4-6 min the monitor still reads "Synced / Connected to the Dash network" with frozen heights, while the engine's last phase was CONNECTING/HEADERS | Sync to 100% -> Tools > Network monitor -> `svc wifi disable; svc data disable` -> wait 4 min | `X2/09,10,11`, `X3/04,06`; log `07:35:32 L1Shadow phase=CONNECTING`, `07:44:53 phase=HEADERS`, then nothing | `ui/NetworkMonitorViewModel.kt:73-81` has no disconnected branch; `sync_status_unable_to_connect` (`strings-extra.xml:375`) has **zero** references in `wallet/src` |
| S9-D2 | **S2** | Cold launch shows a balance ~2x the real one for >30 s (1.996984 vs 0.999991) on a wallet whose only txs are self-sends | Wallet with >=1 self-send -> force-stop -> launch -> read the header | `X3/02`, `X3/03`; log `07:41:08 WalletBalanceFacts: total=199698418 ... confirmed=99999322 unconfirmed=99699096 txCount=5` | `L1ShadowSyncService` WalletBalanceFacts / `CutoverUiDataService` publish the partial during rescan (extends D-002 / SR-10) |
| S9-D3 | **S3** | Contact request while offline: "Send request" is silently inert - no spinner, no toast, no `send_contact_request_error_*` dialog | Identity registered -> Contacts > search a real user -> disable wifi+data -> tap "Send request" x2, wait 30 s | `X7/44`, `X7/45` | `send_contact_request_error_title/_message` (`strings-dashpay.xml:160-161`) never surfaced; contact-request send path |
| S9-D4 | **S3** | Safe-mode screen is hidden behind the generic ACRA crash sheet; the user must Cancel a "send a crash report?" prompt before seeing `safe_mode_startup_message` and "Try Again" | Two pre-milestone launch deaths (or equivalent breadcrumb state) -> launch | `X5/07` then `X5/09` | `StartupBreadcrumbs` / crash-report dialog ordering (relates to SR-41) |
| S9-D5 | **S3** | Shielded transfer screen stuck on "Shielded balance is syncing - transfers will be available shortly" for >8 min, blocking Continue; only a force-stop + relaunch cleared it | Fresh wallet with 1 tDASH -> Join DashPay > Continue > Shield your funds first > Max > Continue | `X7/09`, `X7/12`, `X7/14`, then `X7/19` after relaunch; log only repeats `ShieldedBalanceServiceImpl - shielded runtime ready ... (sync loop running)` every ~60 s | `ui/shielded/*` gating flow / `ShieldedBalanceServiceImpl` readiness signal (adjacent to SR-12/SR-14) |
| S9-D6 | **S3** | "Join DashPay" affordability warning reads the transparent balance only: "You have 0.00001225 Dash. Some usernames cost up to 0.25 Dash." while 0.997 tDASH sits in the shielded pool the next screen offers to pay from | Shield all funds -> home > Join DashPay | `X7/22a` vs `X7/24` | DashPay onboarding balance check |
| S9-D7 | **S4** | Self-send result sheet names the **change** address as "Sent to" and shows the fee as the amount ("Amount Sent -0.00000226") instead of the 0.001 sent to the typed address | Send 0.001 to one of your own receive addresses | `X1/29`, `X1/43` | post-cutover tx-detail seam |
| S9-D8 | **S4** | CSV export omits the fees of internal self-transfers: 5 txs in the UI, 1 row in the CSV, and `Fee`/`Fee Currency` are always empty, so ~904 duffs of real spend is invisible to a tax importer | Wallet with self-sends -> Tools > CSV export | `X4/dash-wallet-transactions-2026-09-19.csv` vs `X4/04` | `transactions/CSVExporter.kt:60`, `transactions/TaxBitExporter.kt:42-43` |

Re-confirmations of existing ledger entries: **SR-28** (flat 0.0001 fee shown, 226 duffs actually paid - `X1/28` vs `X1/29`), **D-007 / SR-11** (username creation writes no history row - `X7/39`), **D-001 / SR-33** (1-minute foreground auto-lock fired ~30 times in 2 h and interrupted nearly every multi-step flow), **D-003** (receive address not rotated immediately after use, but it did rotate later - `X1/18` vs `X7/02`).

## Environment problems (not product defects)

- `qa-app.sh <serial> launch` (monkey) does not start this app on emulator-5564; used `am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n hashengineering.darkcoin.wallet_test/de.schildbach.wallet.ui.OnboardingActivity` throughout.
- `adb uninstall hashengineering.darkcoin.wallet_test` returned `DELETE_FAILED_INTERNAL_ERROR`; the mainnet package uninstalled fine and the testnet APK installed clean.
- Faucet: `qa-faucet.sh` not used; the studio browser made exactly one request (`X1/14-faucet.png`).
- The wallet was **reset at 03:25** to test the empty-wallet CSV case, so the device now holds a new, unfunded, unnamed wallet. Pre-reset wallet backup: `X5/wallet-protobuf-testnet.bak`.

## Not run / blocked, with reason

- **X6** - 6-hour FGS timeout: not reachable in a 2-hour session; code path verified by grep.
- **X7 first sub-case** ("search qa1s13939 without an identity"): unreachable - no contacts UI exists before an identity.
- **X1 cycle 2 send**: skipped, no teardown occurred in that window.
- Live sync foreground notification text: not observed; the wallet never re-entered a long replay while the shade was open.

## Artefacts

- `~/workspace/dash-wallet-qa/evidence/S9/notes.md`, `logcat.txt` (22 MB), `mem.csv` (117 samples), `oom-exitinfo.txt`
- `~/workspace/dash-wallet-qa/evidence/S9/final-logs/files/log/wallet.log` (1.46 MB, whole session)
- Videos: `X1/x1-cycle1-send.mp4`, `X1/x1-cycle3-send.mp4`, `X1/x1-cycle4-failed-send.mp4`, `X1/x1-race-send.mp4`, `X5/x5-safemode.mp4`
- Screenshots: `X1/` 64, `X2/` 15, `X3/` 15, `X4/` 14, `X5/` 13, `X7/` 53, `X8/` 3
