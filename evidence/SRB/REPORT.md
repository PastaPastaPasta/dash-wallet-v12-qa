# QA stream SRB — SR device-reproduction report

| | |
|---|---|
| Emulator | `emulator-5556` (AVD `dw-qa2`, Android 15 / API 35, `ro.product.cpu.abilist=arm64-v8a`) |
| Builds | FIX `fix-12.0.0-testnet3-release-signed.apk` versionCode **12000000**; MASTER `master-11.9.0-testnet3-release-signed.apk` versionCode **11090002**; mainnet pair `fix-12.0.0-prod-release-signed.apk` / `master-11.9.0-prod-release-signed.apk` (same versionCodes) |
| Packages | testnet `hashengineering.darkcoin.wallet_test`; mainnet `hashengineering.darkcoin.wallet` (created + **uninstalled** at 12:05) |
| Wallets | testnet throwaway, 12-word, PIN 1234, receive addr `yhwrtTL9rpH2B8Er71psqZGFqpZiyGUrkC`, funded 1 tDASH by faucet tx `73e97a1b7cadce0b87621a7a6a2405a7d0c2987014e75ed9c38a05b848666206`. Mainnet throwaway, **never funded**. Reference seed NOT touched. |
| Start / end | 2026-09-19 11:40 – 12:12 local (16:40 – 17:12 in wallet.log UTC timestamps) |
| Evidence root | `/Users/dcg/workspace/dash-wallet-qa/evidence/SRB/` |

Note: the emulator `dw-qa2` was **not running** at session start (only `dw-qa1`/5554 existed). I launched it myself (`emulator -avd dw-qa2 -port 5556 …`). No other serial was touched.

---

## Summary table

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| SR-07 | **REPRODUCED (S1)** — with one correction | Created + funded a FIX wallet, set memo + tax category, snapshotted Room DB, downgraded in place (`install -r -d`) to 11.9.0, relaunched, re-snapshotted, then re-upgraded to FIX | `SR-07/DECISIVE.txt`, `SR-07/rowcounts-diff.txt`, `SR-07/tables-before.txt` vs `tables-after.txt`, `SR-07/32-master-tx-detail.png`, `SR-07/srb07-downgrade.mp4` | Wallet opens, **funds and history survive**. Room DB is rebuilt (user_version 22→21, identity hash changes) and **all user-set tx metadata is permanently destroyed** — re-upgrading does NOT restore it. Correction to the SR row: the **address book is not a Room table** (separate `address_book` SQLite DB via `AddressBookProvider`), so it is not affected. |
| SR-08 | **REPRODUCED (S1)** | Installed mainnet MASTER prod-release, created an **empty** mainnet wallet, let it idle 60 s, captured DataStore (no `dashpay.preferences_pb`), upgraded in place to mainnet FIX prod-release, unlocked, re-captured DataStore | `SR-08/DECISIVE.txt`, `SR-08/datastore-after/dashpay.preferences_pb`, `SR-08/05-datastore-ls-before.txt`, `SR-08/09-datastore-ls-after.txt`, `SR-08/13-tools-screen.png` | All **five** `use_kotlin_sdk_*` keys present and **true** on a **prodRelease mainnet** build, zero user action. Worse than the SR row states: the Tools screen on prodRelease exposes **no toggle** for them — a mainnet user cannot opt out. |
| SR-27 | **REPRODUCED (S2)** | On MASTER testnet with a funded wallet, enabled CoinJoin → Intermediate → Start Mixing; screenshotted Settings; pulled `coinjoin.preferences_pb` + Room DB; upgraded to FIX; re-checked Settings and DataStore | `SR-27/09-settings-coinjoin-on.png` vs `SR-27/11-fix-settings.png`, `SR-27/BEFORE.txt`, `SR-27/AFTER.txt`, `SR-27/13-grep-coinjoin.txt`, `SR-27/srb27-upgrade.mp4` | CoinJoin row **gone from Settings** on FIX. `coinjoin_mode = INTERMEDIATE` is still on disk, orphaned, with no UI to read/change/stop it. Mixing does not resume on FIX. Funds survive. |
| SR-23 | **REPRODUCED (release blocker, S2)** | `aapt dump badging` on all four shipped APKs | `SR-23/SUMMARY-badging.txt`, `SR-23/badging-*.txt` | Artefact-level proof: master targetSdk **36**, fix targetSdk **35**. Plus an unlisted regression: **minSdk 24 → 29**. |
| SR-39 | **REPRODUCED (S3)** | Same badging output + device ABI list | `SR-39/SUMMARY-badging.txt`, `SR-39/device-abilist.txt` | master ships `arm64-v8a armeabi-v7a x86 x86_64`; fix ships only `arm64-v8a x86_64`. Combined with minSdk 29, a large device class is cut off. |
| SR-43 | **REPRODUCED (S4)** | Quoted the gradle lines for wallet + 5 other modules, cross-checked against the built artefacts | `SR-43/gradle-compileSdk-placement.txt`, `SR-23/badging-*.txt` | `compileSdk 35` sits **inside** `defaultConfig {}` in 6 modules; master has it at `android {}` level. The APK really does report `compileSdkVersion='35'`, so the Groovy owner-fallthrough works today — fragile, not broken. |
| SR-42 | **PARTIAL** | On FIX with a funded wallet: one self-send (0.1 tDASH to own receive address) and one external send (0.2 tDASH), then inspected the Send screen and wallet.log | `SR-42/grep-coins-callbacks.txt`, `SR-42/15-send-screen-after-both-sends.png`, `SR-42/srb42-sends.mp4` | The **code path is confirmed**: `onCoinsReceived` fires for our own bridged self-send, so `handleContactPayments(tx)` and the CrowdNode matchers run on it. The **user-visible symptom is NOT observable** here — with no DashPay identity the Send screen renders no frequent-contacts row at all (`contacts_pane` is empty before and after). Needs a DashPay-registered wallet to confirm the ordering pollution. |

---

## Detail

### SR-07 — global `fallbackToDestructiveMigration()` wipes tx metadata on downgrade — **REPRODUCED, S1**

Source under test: `wt-fix/wallet/src/de/schildbach/wallet/di/DatabaseModule.kt:55-56`

```
            // destructive migrations are used from versions 1 to 11
            .fallbackToDestructiveMigration()
```

`wt-fix/.../database/AppDatabase.kt:72` → `version = 22`; `wt-master/.../database/AppDatabase.kt:70` → `version = 21`.

Steps / timestamps (local time; wallet.log is UTC+5h):
1. 11:42 installed FIX, created 12-word wallet, PIN 1234 (`SR-07/01..09`).
2. 11:45 receive address `yhwrtTL9rpH2B8Er71psqZGFqpZiyGUrkC`, faucet 1 tDASH, txid `73e97a1b…6206` (`SR-07/11-faucet-sent.png`). Confirmed in-app 11:46, balance 1 (`SR-07/14-home-balance.png`).
3. 11:47 set **Tax Category → Transfer-in** (`SR-07/17-tax-transferin.png`); 11:48 set **Private Note → "SRB07 faucet memo"** (`SR-07/20-note-saved.png`).
4. 11:49–11:52 two sends (see SR-42) so three metadata rows exist.
5. 11:54 snapshot `SR-07/db-before/` — `pragma user_version = 22`, `transaction_metadata` 3 rows, `transaction_metadata_cache` 3 rows, `exchange_rates` 168.
6. 11:55 **downgrade in place**: `adb -s emulator-5556 install -r -d master-11.9.0-testnet3-release-signed.apk` → `Success`. Video `SR-07/srb07-downgrade.mp4`.
7. 11:55 launched 11.9.0 → **PIN screen appears, wallet opens**, balance `0.799995`, all 3 transactions in History (`SR-07/31-master-home.png`). Funds and wallet file are fine.
8. 11:56 opened the faucet transaction: **Tax Category back to "Income", Private Note back to "Add Note"** (`SR-07/32-master-tx-detail.png`).
9. 11:56 snapshot `SR-07/db-after/`.
10. 11:57 re-upgraded to FIX (`install -r`) → snapshot `SR-07/db-reupgrade/`.

Decisive evidence (`SR-07/DECISIVE.txt`):

wallet.log, `/data/data/hashengineering.darkcoin.wallet_test/files/log/wallet.log`:
```
16:55:07 [main] Configuration - detected app downgrade: 12000000 -> 11090002
```
(also in logcat: `09-19 11:55:07.259  8933  8933 W Configuration: [main] detected app downgrade: 12000000 -> 11090002`, `SR-07/grep-logcat-migration.txt`)

```
Room DB version          BEFORE 22      AFTER 21
room identity_hash       BEFORE 5023599d035fb94c8b8a5481e0576d98
                         AFTER  abe067f8699a6e2202b3bd980a934776
```

`transaction_metadata`:
```
BEFORE:  type      taxCategory  memo
         Received  TransferIn   SRB07 faucet memo
         Received
         Sent
AFTER :  type      taxCategory  memo
         Received               (empty)
```

Row-count diff (`SR-07/rowcounts-diff.txt`), before → after:
```
transaction_metadata            3 -> 1
transaction_metadata_cache      3 -> 1
tx_group_cache                  1 -> 3
user_version                   22 -> 21
```
`exchange_rates` still shows 168 rows but with **different values** (`AED 218.5235` → `218.5500`, `SR-07/tables-after.txt`) — i.e. the table was emptied and 11.9.0 re-fetched it, not preserved. `blockchain_state.chainlockHeight` reset `1556859 → -1`.

After re-upgrading to FIX (`SR-07/rowcounts-reupgrade.txt`): `user_version = 22`, identity hash back to `5023599d…`, but `transaction_metadata` still has the single empty row — **the memo and tax category are gone for good**.

What a user sees: the wallet still opens and the money is still there, but every private note, every manual tax classification, cached gift-card/merchant metadata and the local exchange-rate cache are silently erased, and re-installing 12.0.0 does not bring them back.

**Correction to the SR row:** the claim "every Room table is dropped" is right, but the *address book is not in this database*. `wt-fix/wallet/src/de/schildbach/wallet/data/AddressBookProvider.java:182` uses its own `DATABASE_NAME = "address_book"` SQLite file, so address-book entries are NOT lost. The 21↔22 schema is also SQL-identical for this dataset (`diff` of `sqlite_master` is empty, `SR-07/tables-after.txt`) — the data loss is entirely gratuitous.

### SR-08 — `prodRelease` seeds all five SDK flags on a mainnet wallet — **REPRODUCED, S1**

Steps: 11:45 installed `master-11.9.0-prod-release-signed.apk` (package `hashengineering.darkcoin.wallet`). 11:58–12:00 created a 12-word mainnet wallet, PIN 1234, **never funded, balance 0, zero transactions** (`SR-08/04-mainnet-home.png`). Idled 60 s. 12:02 `install -r fix-12.0.0-prod-release-signed.apk`, launched, entered PIN.

Before (`SR-08/05-datastore-ls-before.txt`) — `/data/data/hashengineering.darkcoin.wallet/files/datastore/` contains coinbase / coinjoin / exchange_rates_config / explore / uphold / wallet_ui only. **No `dashpay.preferences_pb`.**

After (`SR-08/09-datastore-ls-after.txt`) — `dashpay.preferences_pb` appears, 479 bytes, mtime 12:02.

`protoc --decode_raw < SR-08/datastore-after/dashpay.preferences_pb` (`2 { 1: 1 }` is boolean **true**):
```
1 { 1: "use_kotlin_sdk_dpns_reads"        2 { 1: 1 } }
1 { 1: "use_kotlin_sdk_dashpay_writes"    2 { 1: 1 } }
1 { 1: "use_kotlin_sdk_shielded"          2 { 1: 1 } }
1 { 1: "use_kotlin_sdk_l1_invite"         2 { 1: 1 } }
1 { 1: "use_kotlin_sdk_l1_shadow"         2 { 1: 1 } }
1 { 1: "cutover_state"                    2 { 5: "CUT_OVER" } }
1 { 1: "sdk_bind_ever_succeeded"          2 { 1: 1 } }
```

wallet.log (`/data/data/hashengineering.darkcoin.wallet/files/log/wallet.log`, `SR-08/10-grep-walletlog.txt`):
```
17:02:12 [DefaultDispatcher-worker-7] CutoverCoordinator - cutover state DUAL_RUNNING -> CUT_OVER (upgraded-wallet launch)
17:02:12 [DefaultDispatcher-worker-1] CutoverCoordinator - upgrade cutover: one-time sync explainer armed (upgraded-wallet launch)
17:02:12 [DefaultDispatcher-worker-1] CutoverCoordinator - upgrade cutover: replay marked as started for the SDK takeover
```

Source confirms it is intentional (`wt-fix/wallet/src/de/schildbach/wallet/ui/dashpay/utils/DashPayConfig.kt`, KDoc above `debugSeedFlags`): *"as of 2026-07-30 all variants seed (the BuildConfig.DEBUG gate was removed) … This means prodRelease exposes the SDK paths to REAL funds by default"*.

**New, worse than the SR row:** the FIX **prodRelease** Tools screen (`SR-08/13-tools-screen.png`) lists only Address book / Import private key / Network monitor / Extended public key / Masternode keys / CSV export / ZenLedger / "dashj sync (diagnostic)". There is **no UI to turn any `USE_KOTLIN_SDK_*` flag off** on a store build. A mainnet user is put on the unreviewed SDK paths with no opt-out.

What the user sees first: an unskippable modal — *"A one-time sync is needed / DashPay needs to complete a full sync before you can send any funds."* (`SR-08/08-fix-prod-home.png`).

Mainnet package uninstalled at 12:05.

### SR-27 — CoinJoin removed, persisted mode orphaned — **REPRODUCED, S2**

On MASTER 11.9.0 testnet (funded, 0.799995 tDASH): More → Settings shows **"CoinJoin — Turned off"** (`SR-27/04a-settings-coinjoin-off.png`). Enabled it → Continue → **Intermediate** → Start Mixing. Settings then reads **"CoinJoin — Paused — 0.000 of 0.800"** (`SR-27/09-settings-coinjoin-on.png`).

Persisted state before upgrade, `/data/data/…_test/files/datastore/coinjoin.preferences_pb` (`SR-27/BEFORE.txt`):
```
1 { 1: "last_mixing_progress"  2 { 7: 0x0000000000000000 } }
1 { 1: "first_time_info_shown" 2 { 1: 1 } }
1 { 1: "coinjoin_mode"         2 { 5: "INTERMEDIATE" } }
```
There is **no `blockchain_identity` Room table** in either schema 21 or 22 (`SR-27/BEFORE.txt`) — `privacyMode` lives on `BlockchainIdentityData` (`wt-master/.../database/entity/BlockchainIdentityData.kt:102`, serialised to prefs at `:313`), and that field **does not exist at all in wt-fix** (grep for `privacyMode` in the fix entity returns nothing).

Mixing actually started on master (wallet.log, `SR-27/13-grep-coinjoin.txt`):
```
17:08:06 [DefaultDispatcher-worker-1] CoinJoinMixingService - coinjoin-state: INTERMEDIATE, 1181 ms, true, CONNECTED, synced: true, true
17:08:06 [DefaultDispatcher-worker-1] CoinJoinMixingService - mixing configuration:  { rounds: 4, sessions: 6, amount: 0.79998403 DASH, multisession: false}
17:08:06 [DefaultDispatcher-worker-1] CoinJoinMixingService - coinjoin-state-mixing: FINISHED -> PAUSED
```

12:08 upgraded in place to FIX (`install -r`, video `SR-27/srb27-upgrade.mp4`). Settings now shows only Local currency / Rescan blockchain / About Dash / Notifications / Battery optimization — **the CoinJoin row is gone entirely** (`SR-27/11-fix-settings.png`, re-confirmed after a full relaunch in `SR-27/15-fix-home-after-mixing.png`).

`coinjoin.preferences_pb` is still on disk, unchanged, `coinjoin_mode = INTERMEDIATE` (`SR-27/AFTER.txt`) — orphaned with no reader/writer in the UI.

After the upgrade FIX still *parses* the CoinJoin state but never mixes (`SR-27/14-post-upgrade-coinjoin.txt`):
```
17:08:49 [main] WalletProtobufSerializer - Loading wallet extension org.dashj.wallet.coinjoin
17:08:49 [DefaultDispatcher-worker-2] CoinJoinMixingTxSet - coinjoin grouping 985a668e… as CreateDenomination (inputs=1 outputs=29 dashjCoinJoinBalance=0)
17:08:49 [DefaultDispatcher-worker-2] CoinJoinMixingTxSet - coinjoin grouping ab3797d4… as MakeCollateralInputs (inputs=1 outputs=2 dashjCoinJoinBalance=0)
17:08:56 [DefaultDispatcher-worker-13] L1ShadowSyncService - WalletBalanceFacts: total=79999548 accounts={bip44:79999548, …, coinjoin:0, …}
```
`CoinJoinFundsMigrationService` never appears in the log.

**What a user loses:** a user who had mixing switched on loses (a) the setting and any way to see it, change it or turn it off — the stored `INTERMEDIATE` value just sits there; (b) all future mixing — their newly received coins stop being mixed silently, a privacy downgrade they are never told about; (c) the "only spend mixed Dash" guarantee they opted into. Funds are intact (balance `0.799981`, `SR-27/16-fix-home-balance.png`) and the already-created mixing transactions still render in History as "Mixing Transactions — 2 transactions".

### SR-23 / SR-39 / SR-43 — build configuration — **REPRODUCED from the artefacts**

`aapt dump badging` (`/opt/homebrew/share/android-commandlinetools/build-tools/36.0.0/aapt`), full output per APK in `SR-23/badging-*.txt`; table in `SR-23/SUMMARY-badging.txt`:

```
APK                                      versionCode  minSdk  targetSdk  compileSdk  native-code
fix-12.0.0-prod-release-signed           12000000     29      35         35          arm64-v8a x86_64
fix-12.0.0-testnet3-release-signed       12000000     29      35         35          arm64-v8a x86_64
master-11.9.0-prod-release-signed        11090002     24      36         36          arm64-v8a armeabi-v7a x86 x86_64
master-11.9.0-testnet3-release-signed    11090002     24      36         36          arm64-v8a armeabi-v7a x86 x86_64
```

- **SR-23**: targetSdk regressed 36 → 35 in the shipped artefacts. Play rejects new releases below target 36 as of 31 Aug 2026 → release blocker, confirmed without reading the source.
- **SR-39**: `armeabi-v7a` and `x86` are both dropped. `SR-39/device-abilist.txt` — this emulator reports `ro.product.cpu.abilist = arm64-v8a`, `abilist32 = (empty)`, so it can only exercise the arm64 path; the shipped `x86_64` lib is never run by any QA device in this fleet, and the 32-bit path is gone entirely. Excluded devices: every 32-bit-only ARM phone (armeabi-v7a, e.g. Moto E/G budget lines, older Samsung A-series) and every x86 device (some tablets, Chromebook Android containers, x86 emulators). They keep the installed 11.9.0 forever and never see an update.
- **Unlisted regression found alongside SR-39**: `minSdk` also went **24 → 29**, so Android 7.0/7.1/8.0/8.1/9 devices are additionally cut off. That is not in the SR-39 row and is a separate, larger user-reach loss.
- **SR-43**: `SR-43/gradle-compileSdk-placement.txt` quotes `wt-fix/wallet/build.gradle:280-306` (`compileSdk 35` on line 282, **inside** `defaultConfig {`, opened on line 281) against `wt-master/wallet/build.gradle:248` (`compileSdk 36` at `android {}` level, `defaultConfig {` opens on line 250). The same misplacement is in `common`, `features/exploredash`, `integrations/uphold`, `integrations/coinbase`, `integrations/crowdnode`. The built APK does report `compileSdkVersion='35'`, so with this AGP the Groovy closure-owner fallthrough resolves — it works, it is just undocumented and AGP-version-fragile. S4 confirmed.

### SR-42 — received-path handlers on our own bridged sends — **PARTIAL**

Setup: FIX testnet, funded wallet. 11:49 self-send 0.1 tDASH to own receive address `yhwrtTL9rpH2B8Er71psqZGFqpZiyGUrkC` (`SR-42/srb42-sends.mp4`, `SR-42/05..08`). 11:52 external send 0.2 tDASH to `yPrynRN6ViX2rCcRL5SoSi8ntcWgdHSEaS` (`SR-42/srb42-normalsend.mp4`, `SR-42/12..14`).

wallet.log (`SR-42/grep-coins-callbacks.txt`):
```
16:50:40 [DefaultDispatcher-worker-15] BlockchainServiceImpl - onCoinsReceived: dcc0f4c5a09640373f019b40f145e71c426a94e97eab3cc83363819c151140fd; rate: null; replaying: true; inside: false, config: PENDING; will update true
16:50:40 [main] BlockchainServiceImpl - tx dcc0f4c5… was authored by this wallet — not a receive, no notification
16:50:40 [DefaultDispatcher-worker-15] SdkBridgedTransactionFactory - bridged SDK tx dcc0f4c5… into the dashj wallet (committed)
16:52:55 [DefaultDispatcher-worker-1] SdkBridgedTransactionFactory - bridged SDK tx ae7ee67d… into the dashj wallet (committed)
```

`dcc0f4c5…` is the self-send. **`onCoinsReceived` runs on our own bridged send.** In `wt-fix/wallet/src/de/schildbach/wallet/service/BlockchainServiceImpl.kt` only the notification is gated by `passFilters`/`shouldAnnounceCoinsReceived` (`:718`, `:777`); the following run unconditionally on that path:
- `:704` `depositReceivedResponse.matches(tx.toTxInfo(…))` — CrowdNode deposit matcher
- `:713-717` `apiConfirmationHandler!!.matches(…)` / `.handle(…)`
- `:730` `handleContactPayments(tx)`

So SR-42's mechanism is confirmed on device. The external send `ae7ee67d…` produced no `onCoinsReceived` line.

**Not reproduced: the user-visible symptom.** `SR-42/01-send-screen-before.png` (before any send) and `SR-42/15-send-screen-after-both-sends.png` (after both) are identical — the Send sheet shows only "Scan QR" and "Send to Address"; `contacts_pane` is an empty `LinearLayout` in both dumps. Frequent contacts require a registered DashPay identity, which this wallet does not have (0.8 tDASH < the 0.25+ needed plus the username flow was out of budget). `dashpay_contact_request` and `dashpay_profile` are 0 rows before and after (`SR-07/rowcounts-before.txt`). Confirming the ordering pollution needs a DashPay-registered wallet — handing that back as unfinished.

---

## New defects found along the way

| ID | Severity | Defect | Repro | Evidence |
|---|---|---|---|---|
| SRB-D01 | **S2** | `minSdk` regressed **24 → 29** between 11.9.0 and 12.0.0 (not covered by SR-23 or SR-39). Every Android 7.0–9 device loses updates permanently, on top of the ABI cut. Combined reach loss is much larger than SR-39 alone states. | `aapt dump badging` on the four APKs | `SR-23/SUMMARY-badging.txt` |
| SRB-D02 | **S2** | On a **prodRelease mainnet** build there is no UI anywhere to disable the five seeded `USE_KOTLIN_SDK_*` flags. Tools exposes only "dashj sync (diagnostic)". A mainnet user is opted in to the SDK paths with real funds and cannot opt out. | Install mainnet fix APK → More → Tools | `SR-08/13-tools-screen.png`, `SR-08/datastore-after/dashpay.preferences_pb` |
| SRB-D03 | S3 | Self-send transaction detail shows the wrong destination. After sending 0.1 tDASH to my own address `yhwrtTL9…`, the detail sheet reads "Sent to **yhuxhoTjG4RB2JsegSfzYu7GEitdh1NuCc**" — an internal change address, not the address the user typed. (Confirmed `yhuxho…` is ours: it is the "Sent from" address of the next transaction.) | FIX, send to own receive address, open the resulting tx | `SR-42/08-selfsend-result.png`, `SR-42/08b-selfsend-detail.png`, `SR-42/14-normalsend-result.png` |
| SRB-D04 | S4 | On the FIX build a newly received transaction defaults to Tax Category "Income" but a **sent** transaction's detail sheet also showed "Income" immediately after sending (it settles to "Expense" only after the tx list refreshes). | FIX, make a send, read the result sheet | `SR-42/07-selfsend-after-pin.png` vs `SR-42/14-normalsend-result.png` |

## Environment problems

- `emulator-5556` / AVD `dw-qa2` was **not running** when this stream started — only `dw-qa1` on 5554. I started it myself. A third serial `emulator-5558` appeared `offline` mid-session (another stream's); untouched.
- `qa-app.sh <serial> text 1234` does **not** drive the app's PIN pad (the digits never register). Tapping `btn_1`…`btn_4` by resource-id works. Worth fixing in the helper — every stream will hit it.
- `qa-app.sh tapon 'text="Confirm"'` matches the screen *title* before the button on the payment-confirm sheet. Use `resource-id="…:id/confirm_payment"`.
- The faucet web flow worked first try (`https://faucet.thepasta.org/` → "Get tDASH" → address → Send → txid in ~10 s). Funds landed in-app in under 60 s.
