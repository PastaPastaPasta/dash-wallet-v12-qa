# Stream SR — static risk review (no devices) of fix/upgrade-memory-and-sync @ 616ac58ff

Paths relative to `~/workspace/dash-wallet-qa/wt-fix/`.

## Findings table (most severe first)

| ID | Sev | Title | File:line | Ledger |
|---|---|---|---|---|
| SR-01 | **S1** | Filter-stall watchdog cancels its own coroutine inside `stop()`; the SPV engine is stopped and **never restarted** — the 99%-forever stall becomes permanent | `wallet/src/de/schildbach/wallet/service/platform/sdk/L1ShadowSyncService.kt:2713-2723`, `:2777-2806`, `:2320-2333`, `:3396-3401` | **NEW — regression in HEAD commit `616ac58ff`** |
| SR-02 | **S1** | Shielded-invite one-time spending key is discarded if the flow is cancelled after the note is funded → permanent, silent fund loss | `…/sdk/SdkShieldedInviteCreation.kt:349-419` (key at `:350`, spend at `:359`, persist at `:413`); caller `ui/more/ConfirmInviteDialogFragment.kt:147` | NEW |
| SR-03 | **S1** | Receive screen is pinned to external key **#0** forever — restored wallets publish their oldest, most-reused address | `ui/payments/PaymentsReceiveFragment.kt:115-118` → `ui/payments/PaymentsViewModel.kt:54-59` → `WalletApplication.java:1962-1964` | **root cause of D-003** |
| SR-04 | **S1** | `freshReceiveAddress()` equally poisoned: Topper/Coinbase deposit addresses and paper-wallet sweeps go to already-used addresses | `WalletApplication.java:1968-1970`; `ui/buy_sell/BuyAndSellViewModel.kt:271-278`; `ui/main/shortcuts/ShortcutsViewModel.kt:211-218`; `ui/payments/SweepWalletFragment.java:621` | NEW |
| SR-05 | **S1** | A stale `wallet-wipe.pending` marker destroys a healthy, funded wallet on the next cold launch, with no confirmation | `util/WalletWipeState.kt:95-99`; `WalletApplication.java:390-395`; `WalletApplicationExt.kt:105-125` | NEW |
| SR-06 | **S1** | Periodic background-sync alarm passes `INTERVAL_DAY` as its repeat interval, so the 15-min backoff is discarded and the alarm is never delivered → no dependable background sync | `WalletApplication.java:1818` (interval chosen `:1741-1746`; shared PendingIntent `:1773-1782`) | docs §32, **unfixed in code** |
| SR-07 | **S1** | `fallbackToDestructiveMigration()` is global, not scoped to v1–11 as its comment claims → every table dropped on any downgrade from schema 22 | `di/DatabaseModule.kt:56` (cf. `fallbackToDestructiveMigrationFrom` in `androidTest/…/DatabaseMigrationTest.kt:100`) | NEW |
| SR-08 | **S1** | `prodRelease` silently seeds all five `USE_KOTLIN_SDK_*` flags on first launch after upgrade — real mainnet funds onto unreviewed paths | `ui/dashpay/utils/DashPayConfig.kt:651-660`, `:374-391` (KDoc `:364-372`) | release gate |
| SR-09 | **S2** | `idling detected, stopping service` every minute forever: `stopSelf()` can't destroy a **bound** service but *latches* the stop — the service dies the instant the user leaves MainActivity, and SR-06 means nothing brings it back | `service/BlockchainServiceImpl.kt:2007-2010`; `ui/AbstractBindServiceActivity.kt:48-78` | **root cause of D-004** |
| SR-10 | **S2** | Mid-replay "hold last known balance" is inert on a created/restored wallet (`lastKnown == null` → falls through to the live partial) | `…/sdk/CutoverUiDataService.kt:2384-2398`; seed `:2545-2547`; persist gate `:2769-2786` | **root cause of D-002** |
| SR-11 | **S2** | Username created from the shielded pool writes **no** transaction-history row — a gap, not a design decision | `…/sdk/SdkShieldedUsernameCreation.kt:788-796`; `…/sdk/CutoverUiDataService.kt:375-387`, `:3230-3231`; orphan API `…/ShieldedBalanceServiceImpl.kt:1055-1062` | **root cause of D-007** |
| SR-12 | **S2** | Shielded stall watchdog fires on healthy transfers (40 s vs a ~30 s proof) and, once fired, **permanently bricks** the transfer screen | `ui/shielded/ShieldedTransferExecutor.kt:293-301`, `:631-634`, `:663-670`; `ui/shielded/ShieldedTransferScreen.kt:293`, `:406-416`, `:1108-1152` | NEW |
| SR-13 | **S2** | Shielded Send spend runs in `viewModelScope`; on VM clear the outcome is lost while the JNI proof may still broadcast, and the screen resets to re-submittable | `ui/shielded/ShieldedSendViewModel.kt:160`, `:167`, `:181`, `:218-243` | NEW |
| SR-14 | **S2** | Shielded username/invite creation has **no** stall watchdog; a wedged FFI leaves `Proving` forever and the single-flight gate refuses all retries for the process | `…/sdk/SdkShieldedUsernameCreation.kt:769-800`, `:810-818`; `ui/shielded/ShieldedUi.kt:88-99` | NEW |
| SR-15 | **S2** | Filter-stall watchdog restart costs up to **155,000 blocks** of re-scan, and its 10-min threshold sits inside the window where the filter cursor legitimately doesn't move | `…/sdk/L1ShadowSyncService.kt:3480-3496`, `:2317-2323`, `:2354-2377`; `service/SyncActivityIdleDetector.kt:91-109` | NEW |
| SR-16 | **S2** | Send-all drain guard's dashj half is structurally inert post-cutover (held wallet has 0 UTXOs); the seam half has no live producer → both misses and permanent false positives | `…/sdk/SdkL1SendService.kt:1155`, `:1546`; `ui/send/SendCoinsViewModel.kt:461`; `crowdnode/utils/CrowdNodeConstants.kt:44` | NEW |
| SR-17 | **S2** | `SeamOutputLockRegistry` has **no release API** and the guard consults a global `hasAnyLocks()` — one lock refuses every send-all wallet-wide until process restart | `…/sdk/SeamOutputLockRegistry.kt:56-73` | NEW (latent behind a disabled flag) |
| SR-18 | **S2** | `estimateNetworkFee` never migrated — still calls `completeTx` on the held dashj wallet → Coinbase transfer dead-ends with a false "insufficient funds" and never prompts for auth | `payments/SendCoinsTaskRunner.kt:580-623` (`:602`); `integrations/coinbase/…/TransferDashFragment.kt:137` | NEW |
| SR-19 | **S2** | Memo and exchange rate silently dropped on every SDK-routed send; `onCoinsReceived` backstop never fires for a drain | `ui/send/SendCoinsViewModel.kt:283-284`; `payments/SendCoinsTaskRunner.kt:437`, `:1075`, `:1179`; `service/BlockchainServiceImpl.kt:665-682` | NEW |
| SR-20 | **S2** | `WalletWipeSequence.finish()` calls `markComplete()` even when most of the wipe failed — every step after the first swallows its own exception | `util/WalletWipeSequence.kt:94-103`; `WalletApplicationExt.kt:111-125`, `:167-203`; `WalletApplication.java:1903-1907` | NEW |
| SR-21 | **S2** | Reset can hang on the "resetting…" spinner indefinitely (`wipeInProgress.first { !it }` with no timeout) when the service is already tearing down | `ui/OnboardingActivity.kt:408-412`; `WalletApplication.java:1834-1838`; `service/BlockchainServiceImpl.kt:2696-2700`, `:2872-2876`, `:3005` | NEW |
| SR-22 | **S2** | Restore date picker opens on **today**; one confirm tap sets a birth height that hides the wallet's entire history, and it is not correctable in place | `ui/RestoreWalletFromSeedActivity.kt:167-189`; `…/sdk/SdkWalletBinder.kt:80-90`; `…/sdk/BirthHeightResolver.kt:41`, `:78`, `:83-90`, `:106-122` | NEW |
| SR-23 | **S2** | `targetSdk`/`compileSdk` regressed 36 → 35 in every module — Play rejects new releases targeting < 36 as of 31 Aug 2026 | `wallet/build.gradle:285-287`; `common/build.gradle:11-13`; `features/exploredash/build.gradle:14-16`; all `integrations/*/build.gradle` | **release blocker** |
| SR-24 | **S2** | Autosave debounce stretched to 60 s on wallets ≥ soft limit with **no** forced flush after a send or on background | `WalletApplication.java:954-958`; `util/WalletFileSizeGuard.kt:138-145` | NEW |
| SR-25 | **S2** | RISKY size threshold is ~26 MB (fallback heap) / ~51 MB, far below what the KDoc implies; any OOM there routes to a destructive key-backup recovery announced by a single Toast | `util/WalletFileSizeGuard.kt:98-101`; `WalletApplication.java:1279-1296`, `:1371`, `:1422-1454` | NEW |
| SR-26 | **S2** | Preserved-aside wallet copies (`.oversize/.oomed/.pre-seed-restore`) are never reclaimed | `util/WalletFileSizeGuard.kt:161-180`; `WalletApplication.java:1532-1542` | NEW |
| SR-27 | **S2** | CoinJoin mixing removed and the persisted `privacyMode` dropped with no migration — a silent privacy-posture downgrade on upgrade | `database/entity/BlockchainIdentityData.kt`; `…/sdk/CoinJoinFundsMigrationService.kt:56-62` | NEW |
| SR-28 | S3 | Confirm dialog shows a flat **0.0001 DASH** fee (~44× real) and uses it as the affordability gate → false "insufficient funds" near the balance | `ui/send/SendCoinsViewModel.kt:482`, `:511`, `:519`, `:525`; `ui/send/SendCoinsFragment.kt:295,300-305`; `common/…/util/Constants.kt:47` | NEW |
| SR-29 | S3 | Send-all fee reserve is sized at 1.5 duffs/byte but the drain builds at 2 duffs/byte → **every** send-max fails its first attempt and depends on a string-matched retry | `…/sdk/SdkL1SendService.kt:233-234`, `:342-348`, `:1372`; `…/sdk/CoreSendAllNative.java:120`, `:235` | NEW |
| SR-30 | S3 | Shielded "Max" (send-to-address) can never succeed: no fee reserve, and the fee-adjust retry isn't wired to that screen | `ui/shielded/ShieldedSendViewModel.kt:111-114`, `:185-193`; `…/ShieldedBalanceService.kt:413-419`; cf. `…/SdkShieldedInviteCreation.kt:104-110`, `:128` | NEW |
| SR-31 | S3 | Fiat-mode "Max" loses max-spend handling via a lossy round trip → "Insufficient funds" or a failed transfer after a 30 s proof | `ui/shielded/ShieldedTransferViewModel.kt:257-262`, `:293-294`, `:623-633`, `:710` | NEW |
| SR-32 | S3 | Send screen "Max" has **no** replay hold, so it publishes the untrusted partial while the header holds last-known | `…/sdk/CutoverUiDataService.kt:2400-2413`; `ui/send/SendCoinsViewModel.kt:181-189` | extends D-002 |
| SR-33 | S3 | Foreground auto-lock every ~60 s is the **default** `auto_logout_minutes = 1` + a timer reset only by `onUserInteraction`. **Pre-existing in 11.9.0** | `common/…/Configuration.java:164,172`; `AutoLogout.java:35,88-108`; `ui/LockScreenActivity.kt:166-172,182-192,280,454-456` | **root cause of D-001 — recommend downgrade** |
| SR-34 | S3 | 0-minute ("logout immediately") mode became live for the first time in this branch — `onStoppedLast()` was dead code before MO-995 | `WalletActivityTracker.java:83-89`, `:140-178` (rotation guard `:162-164`) | NEW aggravator to D-001 |
| SR-35 | S3 | Filter-stall watchdog latches `EXHAUSTED` for the life of the process; give-up is WARN/INFO only, no user surface | `…/sdk/L1ShadowSyncService.kt:1143-1155`, `:2797-2814` | NEW |
| SR-36 | S3 | `WalletWipeSequence.begin()` proceeds with a destructive wipe after failing to write its own recovery marker | `util/WalletWipeSequence.kt:60-67`; `util/WalletWipeState.kt:65-76` | NEW |
| SR-37 | S3 | CrowdNode account locking throws `IllegalStateException` mid-flow when the tx seam hasn't primed — after the signup tx is broadcast | `data/WalletDataAdapter.kt:191-201`, `:227`; `…/sdk/CutoverTxSeamService.kt:229`, `:233-238` | NEW (latent) |
| SR-38 | S3 | Oversize / OOM wallet recovery renames the wallet file aside and depends on `restoreWalletFromBackup()`; a null result drops the user to onboarding needing their seed | `WalletApplication.java:1195-1214`, `:1279-1296`; `util/WalletFileSizeGuard.kt:63-108` | NEW |
| SR-39 | S3 | Default `abiFilters` drops `armeabi-v7a`; with minSdk 29 those users silently stop receiving updates; QA never exercises the shipped x86_64 native path | `wallet/build.gradle:294-305` | NEW |
| SR-40 | S3 | `RECEIVER_NOT_EXPORTED` gated at API 26 instead of 33 → receiver **exported** on API 29–32; any app can force-finish the wallet activity | `common/…/InteractionAwareActivity.java:37-41` | pre-existing |
| SR-41 | S3 | 20 s wallet-load budget can strand a legitimately slow launch on the safe-mode crash-report screen | `util/WalletLoadBudget.kt:59`; `WalletApplication.java:1223-1231`; `util/StartupBreadcrumbs.kt:149`, `:311-320` | NEW ("Try again" workaround) |
| SR-42 | S4 | CrowdNode/contact handlers still run on the *received* path for our own bridged sends → polluted frequent-contacts ordering | `service/BlockchainServiceImpl.kt:704`, `:713-717`, `:730`, `:777` | acknowledged NOT FIXED in `e4993d240` |
| SR-43 | S4 | `compileSdk` moved **inside** `defaultConfig {}` in every module; only works via a Groovy closure-owner fallthrough | `wallet/build.gradle:285`; `features/exploredash/build.gradle:13-14` | NEW |
| SR-44 | info | The cutover state machine is a constant in shipping: every install is `CUT_OVER` from first launch; `DUAL_RUNNING`/`READY_OBSERVED`/rollback are dead paths | `…/sdk/CutoverStateMachine.kt:21-45`, `:124-141` | test-planning note |

**Confirmed non-findings:** migration 21→22 is byte-correct against exported schemas and all of 11→22 are registered (`database/AppDatabaseMigrations.kt:270-288`, `di/DatabaseModule.kt:42-54`); `Sha256Hash`→`TxId` entity change is schema-neutral; no SharedPreferences settings lost on upgrade; DataStore seeding off the main thread; other API-level gates correct; no exact-alarm usage.

## Detail on the items observed by device streams

### SR-01 — the new watchdog kills the engine it was written to revive
`checkFilterStall()` (`L1ShadowSyncService.kt:2777`) executes inside `watchdogJob` (`scope.launch { watchdogLoop() }` at `:2287`). On `Decision.RESTART` it runs `runCatching { stop(); startIfEnabled() }`; `stop()` at `:2328` does `watchdogJob?.cancel()`, cancelling the coroutine currently running it. `source.stopSpv()` (suspend, `:1378`) then throws `CancellationException` (swallowed by `runCatching`, native client may not be torn down). `startIfEnabled()` (`:2214`) begins `if (!isEnabled()) return false`, and `isEnabled()` (`:3396-3401`) wraps a DataStore read in `catch (e: Exception)`; `CancellationException` is an `Exception`, so it returns **false**. Net: engine stopped, all loops cancelled, INFO "engine restart declined to start", nothing ever restarts it. Only the pure decider is unit-tested. **Repro:** grep wallet.log for `filter-stall watchdog: … restarting the SPV engine`; expect no following `L1 shadow SPV started`, an `engine restart declined to start`, and no further `L1Shadow phase=` lines. Force via `filterStallThresholdMs` ctor param at `:1809`.

### SR-09 — root cause of D-004
`BlockchainServiceImpl.kt:2007-2010` calls `stopSelf()` from the per-minute `ACTION_TIME_TICK` receiver. `MainActivity` extends `AbstractBindServiceActivity` (binds `BIND_AUTO_CREATE` in onResume, unbinds in onPause). Android will not destroy a started service with bound clients, so the line repeats forever while foreground. Wake lock is not leaked (`holdWakeLockWhileReplaying` releases post-sync). Residual cost: dataSync FGS + notification stay up; per-minute `Debug.getPss()` walk. On Android 15+ the 6-hour cap fires `onTimeout` → "background processes paused" notification + a no-op `stopSelf()`. **Real hazard:** the latched stop destroys the service on the first `onPause` of MainActivity, and SR-06 means nothing brings it back.

### SR-10 — root cause of D-002
`CutoverUiDataService.kt:2384-2398`: `when { sdk == null -> dashj; synced -> sdk; lastKnown != null && lastKnown.isPositive -> lastKnown; else -> sdk }`. `_lastKnownTotalBalance` is seeded from `WalletUIConfig.LAST_TOTAL_BALANCE` (`:2545-2547`), written only when `synced && !armedRescanHold && backfillStatus.settled && buildsSettled` (`:2769`, `:2784-2786`). A wallet created or restored on this build has never had a synced launch → `lastKnown == null` → live partial published. S2's log: `SDK balance published: 81792053377 duffs … l1Synced=false … persistedAsLastKnown=false lastKnown=0`. The greyed "Syncing balance" label comes from a different source (`ui/main/HeaderBalanceFragment.kt:58-70`), so label and figure are not coupled.

### SR-33/SR-34 — root cause of D-001, not a regression
`Configuration.java:164` defaults `auto_logout_enabled = true`; `:172` defaults `auto_logout_minutes = 1`. `AutoLogout.java:35` ticks every 5 s, fires at 60 s; reset only by `onUserInteraction()` (`LockScreenActivity.kt:182-192`). Every `LockState = ENTER_PIN` in S2's wallet.log is preceded by `BiometricHelper - No biometric credentials` + `fingerprint was disabled` (the `setLockState` path), never by `show lock screen …`. `git diff master...HEAD` does not touch `AutoLogout.java` or the auto-logout defaults. **Recommend confirming on 11.9.0 and downgrading D-001.** New aggravator (SR-34): `WalletActivityTracker.onStoppedLast()` was dead code before MO-995; now `setAppWentBackground(true)` makes `shouldLogout()` true in 0-minute mode and broadcasts `FORCE_FINISH_ACTION`. Test rotation/dark-mode/font-scale on MainActivity, AddressBookActivity, NetworkMonitorActivity, BlockInfoActivity with auto-logout "immediately".

### SR-11 — the missing username-fee history row is a gap
`SdkShieldedUsernameCreation.kt:788-796`: post-spend bookkeeping after a successful Type-20 `createIdentityFromPool` is one call to `noteExternalShieldedSpendBroadcast()` (sets a balance-stale flag only). The row-title table (`CutoverUiDataService.kt:375-387`) and display-cache planner are keyed on an L1 asset-lock txid; a Type-20 create-from-pool has none. `observeShieldedActivity()` (`ShieldedBalanceService.kt:213`) has zero production consumers. The transparent path does get a row (`AssetLockKind.UPGRADE → dashpay_upgrade_fee`).

## User-story catalogue (from `git diff --name-only master...HEAD -- 'wallet/src/de/schildbach/wallet/ui/**'`, 154 files, + 191 new strings)

| # | Feature | UI package(s) | Key new strings | Covered at time of review |
|---|---|---|---|---|
| 1 | One-time cutover sync notice | `ui/cutover/` | `cutover_sync_notice_*` | S2, S6 partly |
| 2 | Network Monitor rewritten for the SDK engine | `ui/` NetworkMonitorActivity | 20 × `network_monitor_*` | none |
| 3 | Home header balance + "Syncing balance" | `ui/main/` | `syncing_balance` | S2 (D-002) |
| 4 | Shielded balance card, address, tabs | `ui/shielded/` | `shielded_balance_card_title`, `shielded_tab_*`, … | S1, S5 |
| 5 | Shielded transfer both directions incl. stall/ambiguous/failed/resumed | `ui/shielded/` | `shielded_proving_*`, `_transfer_stalled_*`, … | S1, S5 |
| 6 | Shielded balance verification / scan progress | `ui/shielded/` | `shielded_verifying_*`, `_error_*` | partial |
| 7 | Username payment source choice (Dash vs shielded) | `ui/username/` | `username_payment_*` | S1, S5 |
| 8 | Username cost info sheet | `ui/username/` | `username_cost_info_*` | partial |
| 9 | Instant (non-contested) username alongside a contested request | `ui/username/` | `create_instant_username_description`, … | none |
| 10 | Username request failure/ambiguity handling | `ui/username/` | `username_request_ambiguous_*`, … | partial |
| 11 | Identity / top-up progress states | `ui/username/`, `ui/dashpay/` | `identity_processing_*` | none |
| 12 | Buy credits (identity top-up) | `ui/dashpay/` | `buy_credits_*` | none |
| 13 | Invitations — private (shielded) vs standard | `ui/invite/` | `invite_payment_*`, `invitation_fee_amount` | none |
| 14 | Invitation creation failure handling | `ui/invite/` | `invitation_creation_*` | none |
| 15 | CoinJoin removal + mixed-funds migration | `ui/migration/`, `ui/coinjoin/` | 13 × `mixed_funds_migration_*` | none — moves money |
| 16 | Send flow error surfaces | `ui/send/` | `send_coins_error_*` | partial |
| 17 | Tx row classification — shielded, unshielded, invitation | `ui/transactions/` | `transaction_row_*` | S1 (D-007) |
| 18 | DashPay contacts — send/accept errors, pending counts, notification channel | `ui/dashpay/`, `ui/notifications/` | `send_contact_request_error_*`, … | none |
| 19 | SDK bind pending / failed / keystore-blocked notices | `ui/` | `sdk_bind_*` | S3 partly |
| 20 | Degraded-startup / safe-mode onboarding screen | `ui/OnboardingActivity` | `safe_mode_startup_message` | none |
| 21 | Reset wallet / wipe sequence | `ui/more/`, `util/WalletWipe*` | — | S1 (D-012, D-013) |
| 22 | Restore from seed & receive-address selection after restore | `ui/`, `ui/payments/` | — | S2 (D-003) |
| 23 | Lock screen / PIN / biometric enroll | `ui/LockScreenActivity`, `ui/SetPinActivity` | — | S2/S3/S4/S6 (D-001, D-011) |
| 24 | Transaction-history CSV export | `ui/more/` | `report_transaction_history_dialog_export_csv_empty` | none |
| 25 | 6-hour foreground-service limit notice | `service/BlockchainServiceImpl` | `notification_background_processes_paused_text` | none |
| 26 | Sync-status "unable to connect" | `ui/main/` | `sync_status_unable_to_connect` | none |
| 27 | About screen — Kotlin SDK version row | `ui/more/` | `about_kotlin_sdk_label` | trivial |
| 28 | Buy/sell, Explore Dash, backup, compose_views | various | — | none |

## Areas not assessed
Execution (no device/build in this stream); the Rust/Kotlin SDK internals; why the intermediate replay balance overshoots 8×; full audits of the five largest files; D-001 on the 11.9.0 baseline; real oversize-wallet handling (no ≥26 MB fixture); translation completeness of 191 new strings; DIP-15 parity gate sign-off.

**Suggested triage order:** SR-01 → SR-05 + SR-03/SR-04 → SR-07 + SR-08 → SR-23 → SR-06 + SR-09 → SR-10/SR-11.
