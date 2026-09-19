# SRA — SR device-reproduction report (Reset Wallet / wipe markers / wallet-file recovery)

| | |
|---|---|
| Emulator | `emulator-5554` (AVD **dw-qa1**, Android 15 / API 35, 1080x2400) — was NOT running at session start; started with `qa-emu.sh start dw-qa1 5554` |
| APK under test | `$QA_APKS/fix-12.0.0-testnet3-release-signed.apk` — versionCode **12000000**, versionName 12.0.0 |
| Package | `hashengineering.darkcoin.wallet_test`, largeMemoryClass **576 MB** (`dalvik.vm.heapsize=576m`) |
| Seed (QA throwaway, created on device) | `palace hint east head chronic close length brand right comic excite extra` |
| Funding | faucet txid `a0706d09e1f383216aa2d81697db2418b9e7a9495d860f98d9a442d8180999bd` → `yMKPQKunBcnXBDc7tk7NZEswfeUNNynDPZ` (1 tDASH) |
| Reference seed | NOT touched |
| Start / end | 2026-09-19 11:37 – 12:45 CDT |
| Evidence root | `/Users/dcg/workspace/dash-wallet-qa/evidence/SRA/` |
| Session logs | `evidence/SRA/logcat.txt`, `mem.csv`, `final-logs/files/log/wallet.log`, `notes.md` |

Log quotes are from `/data/data/hashengineering.darkcoin.wallet_test/files/log/wallet.log` (pulled copy: `evidence/SRA/final-logs/files/log/wallet.log`); its timestamps are UTC, wall-clock here is CDT (UTC-5).

## Verdicts

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| SR-20 | **REPRODUCED** | `chmod 500 files/datastore`, then More › Security › Reset Wallet › confirm on a funded wallet | `SR-20/08-decisive-grep.txt`, `09-files-after.txt`, `10-datastore-after.txt`, `13-datastore-md5-before-restore.txt`, `sr20-reset.mp4` | 13 wipe steps failed with EACCES, all swallowed; `markComplete()` still ran (marker gone), no `wipe destruction failed`, UI showed onboarding. 7 datastore files survived byte-identical; the next restored wallet inherited the old wallet's `CUT_OVER` state. |
| SR-36 | **REPRODUCED — consequence is the OPPOSITE of the row, and worse** | `chmod 555 files/` so the marker cannot be created; Reset Wallet ×3 with kills at +2.1/+2.1/+3.3 s | `SR-36/03-wipe-grep.txt`, `12-destroying-nothing.txt`, `06-run1-wallet-alive.png`, `11-run3-files.txt`, `sr36-run{2,3}.mp4` | `wipe started WITHOUT a recovery marker` is logged and the UI hands off to onboarding — but `finish()` reads `pending()==false` and logs `destroying nothing`: **the wipe destroys NOTHING**. Relaunch restores the wallet with balance and same PIN. |
| SR-21 | **PARTIAL** (hazard path hit; no permanent hang in 5 attempts) | 5 timed races (rescan intent, HOME/fg, `am stopservice` −0.5 s, net-off+stopservice, stop/start storm) | `SR-21/a3-log.txt`, `a4-log.txt`, `a5-log.txt`, `sr21-a{1..5}.mp4` | Spinner 1/1/4/13/15 s. a5 hit `Another onDestroy() is already running cleanup, skipping duplicate cleanup` + `CRITICAL: Cleanup did not complete within 15 seconds`, yet another onDestroy carried the wipe. |
| SR-38 | **REPRODUCED (outcome); mechanism different and worse** | (b1) `truncate -s 2000000001` with key backup present; (b2) same + `rm key-backup-protobuf-testnet` | `SR-38/16-guard-log.txt`, `17-breadcrumbs.txt`, `22/23-relaunch*.txt`, `33-null-log.txt`, `34-null-degraded.png`, `sr38-*.mp4` | (b1) recovered from key backup, funds returned — **for that session only**: the recovered wallet is never written to `wallet-protobuf-testnet`, so the next launch goes to onboarding with an unread key backup on disk. (b2) null-backup branch reproduces exactly: degraded screen with Restore/Report/Close. |
| SR-25 | **REPRODUCED (threshold) / NOT REPRODUCED (OOM routing)** | Appended 60 MiB urandom → 62,929,882 bytes, relaunched | `SR-25/06-guard-log.txt`, `07-risky-loaded-ok.png`, `sr25-risky.mp4`, `SR-38/10-t2s.png` | Soft limit logged as **60,397,977 bytes (57.6 MB)** on 576 MB largeHeap; 25.6 MB on the 256 MB fallback, as the row says. No OOM (parse ignored the tail, 211 ms). Single-Toast claim confirmed via the UNPARSEABLE run. |
| SR-26 | **REPRODUCED** | Two UNPARSEABLE recoveries, then restore-from-seed, then a full Reset Wallet | `SR-26/01-after-restore.txt`, `03-after-reset-files.txt` | Both `wallet-protobuf-testnet.oversize.*` (2,000,000,001 B each) survive restore **and** a full Reset Wallet. `cleanupFiles()` patterns never match `.oversize`/`.oomed`. |
| SR-41 | **REPRODUCED** | `kill -STOP` 450 ms into launch (inside the parse) for 21 s, then relaunched | `SR-41/06-attempt3-log.txt`, `07-next-launch.png`, `08-safemode-screen.png`, `09-safemode-log.txt`, `11-retry-log.txt` | One over-budget load + one pre-milestone death suffices (`armSafeModeOnNextDeath()` pre-loads the counter to `THRESHOLD-1`): next launch `safeMode=true` → `WALLET_LOAD_SKIPPED_SAFE_MODE` → `DEGRADED_UI_SHOWN`. "Try Again" recovers in-process. Measured normal loads: **211–257 ms**. |

---

## Detail

### SR-20 — wipe marked complete though most steps failed — REPRODUCED

Setup: wallet created (PIN 1234), funded 1 tDASH, home shows balance + Received row (`setup/15-funded-home.png`).
Fault at 11:50:20: `chmod 500 /data/data/<pkg>/files/datastore` (reads still work, writes/deletes EACCES) — `SR-20/03-datastore-pre.txt`. Reset confirmed 11:50:40 (`sr20-reset.mp4`, `04-reset-confirm.png` → `06-t5s.png`).

Swallowed failures, verbatim (`SR-20/08-decisive-grep.txt`):

```
16:50:43 WalletApplication - failed to delete datastore preferences file: 'dashpay.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'explore.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'coinbase.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'uphold.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'wallet_ui.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'org.dashfoundation.wallet.secrets.preferences_pb'
16:50:43 WalletApplication - failed to delete datastore preferences file: 'exchange_rates_config.preferences_pb'
16:50:43 WalletApplication - datastore preferences cleared; api-cleared: [...], file-deleted: []
16:50:43 WalletApplicationExt - wallet-wipe listener failed        (x6, each java.io.FileNotFoundException ... EACCES)
16:50:43 L1ShadowSyncService - wipe cleanup: removeSdkWallet failed; continuing
16:50:43 CutoverCoordinator - cutover state persist failed (CUT_OVER -> DUAL_RUNNING, wallet wipe); keeping CUT_OVER
16:50:43 WalletApplicationExt - databases cleared (isWalletWipe = true)
16:50:43 OnboardingActivity - reset finished — re-running the onboarding routing
```

Full traces (`FileNotFoundException: …/datastore/dashpay.preferences_pb.tmp: open failed: EACCES`) at line ~926 of `SR-20/logs/files/log/wallet.log`.

The wipe recorded **success**: no `wallet-wipe.pending` in `files/` (`09-files-after.txt`), no `wipe destruction failed` / `Reset Wallet did not finish` anywhere, onboarding shown (`11-onboarding-after-wipe.png`), relaunch also onboarding (`12-relaunch.png`).

Survivors (`10-datastore-after.txt`, md5s in `13-...txt`): all seven preference files byte-identical, including `org.dashfoundation.wallet.secrets.preferences_pb` (md5 `5a39ab7f17bc39a81a551d395a665dfe`) and `dashpay.preferences_pb` (md5 `53a31a60cfc38852b00ec4fc8e1479de`, identical to the pre-wipe hash captured at 11:50:20).

Leak into the next wallet: restoring the same seed at 11:55 produced a wallet that came up already `cutoverCommitted=true` and never logged its own `cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))` — it inherited the destroyed wallet's cutover state, exactly what `cutoverCoordinator.resetForWalletWipe()` exists to prevent (`17-cutover-leak.txt`). Balance returned to 1 tDASH (`19-restored-funded.png`).

### SR-36 — wipe with no recovery marker — REPRODUCED with the opposite consequence

Fault: `chmod 555 /data/data/<pkg>/files`. Runs at 11:58:06 (kill +2.1 s), 12:00:06 (+2.1 s), 12:01:43 (+3.3 s); videos `sr36-run{2,3}.mp4`.

```
16:58:08 WalletApplication  - Removing all the data and restarting the app.
16:58:08 WalletWipeState    - could not create the wallet-wipe marker
                              java.io.IOException: Permission denied
16:58:08 WalletWipeSequence - wipe started WITHOUT a recovery marker — a process death mid-wipe will not be repaired
16:58:08 AppRestartService  - perform restart on application context: true
```

The row predicts "proceeds with a destructive wipe". It does not — `finish()` gates on the marker it just failed to write:

```
17:00:06 WalletWipeSequence - wipe teardown reached without a wipe having been started — destroying nothing
17:01:43 WalletWipeSequence - wipe teardown reached without a wipe having been started — destroying nothing
```
(`12-destroying-nothing.txt`; the only two occurrences in the whole session log.)

Disk after (`07-run2-files.txt`, `11-run3-files.txt`): `wallet-protobuf-testnet` (15,322 B) and `key-backup-protobuf-testnet` (15,328 B) untouched, no marker. After restoring permissions and relaunching, the app accepts the **same PIN** and shows the **same 1 tDASH balance and history** (`06-run1-wallet-alive.png`, `09-state.png`).

Timing control (`CONTROL/`, 12:03:18, no fault): the marker appears within 0.15 s of the confirm tap and is gone by ~0.9 s — the whole wipe takes <1 s (`CONTROL/02-control-wipe-log.txt`). So all three kills landed *after* the point where a real wipe would have finished destroying; nothing was destroyed because `finish()` refused, not because the kill was early.

Trigger needs no root: anything that makes `filesDir` unwritable (full storage, storage fault, MDM/SELinux oddity) produces the same silent no-op.

### SR-21 — reset spinner with no timeout — PARTIAL

`showWipeInProgressScreen()` awaits `wipeInProgress.first { !it }` with no timeout; the flag is cleared only by `finishWalletWipe()`'s `finally`, which runs only if that onDestroy wins `isCleaningUp.compareAndSet(false, true)`.

| attempt | perturbation | spinner | outcome |
|---|---|---|---|
| a1 12:09:19 | `reset_blockchain` intent fired with the confirm | ~1 s | completed |
| a2 12:12:04 | HOME at confirm, foreground +1 s | ~1 s | completed |
| a3 12:14:00 | `am stopservice` 0.5 s before confirm | 4 s | completed (`a3-log.txt`) |
| a4 12:16:09 | network off + stopservice + confirm together | 13 s | completed (`a4-log.txt`) |
| a5 12:18:30 | net off + 8× (stopservice; reset_blockchain) storm, confirm +1.2 s | 15 s | completed (`a5-log.txt`) |

a5 reached the exact hazard and still recovered:

```
17:18:30 WalletApplication  - Removing all the data and restarting the app.
17:18:30 OnboardingActivity - reset in progress — holding onboarding until the wipe finishes
17:18:45 BlockchainServiceImpl - CRITICAL: Cleanup did not complete within 15 seconds
17:18:45 BlockchainServiceImpl - Another onDestroy() is already running cleanup, skipping duplicate cleanup
17:18:45 WalletApplication  - removing wallet from memory during wipe
17:18:45 WalletApplicationExt - databases cleared (isWalletWipe = true)
17:18:45 OnboardingActivity - reset finished — re-running the onboarding routing
```

A 15 s content-free "resetting…" spinner is reproducible; a permanent hang was not produced in 5 attempts. BACK/relaunch recovery was never needed.

### SR-38 + SR-25 + SR-26 — size guard, recovery, aside copies

Device parameters, verbatim (`SR-25/06-guard-log.txt`):

```
17:23:52 WalletApplication - wallet file size guard: 62929882 bytes, largeHeap 576MB, soft limit 60397977 bytes -> RISKY
17:23:53 WalletApplication - wallet loaded from: '…/wallet-protobuf-testnet', took 211.3 ms (0 DashPay friend chains deferred)
17:23:53 WalletApplication - wallet autosave debounce raised to 60000 ms for a 62929882 byte wallet file
```

**SR-25.** Soft limit is `min(largeHeap/10, 100MB)` = 57.6 MB here; 25.6 MB with the 256 MB fallback, so the row's "~26 MB" is accurate. A 62 MB wallet is RISKY and gets the 60 s autosave tier. I could **not** produce the OOM branch — appending 60 MiB of random bytes did not break the parse (211 ms; the parser stops at the end of the valid message) and the wallet unlocked normally with its balance (`07-risky-loaded-ok.png`). The `.oomed` path is therefore untested on device; it shares the destructive routing with the UNPARSEABLE path below.

**SR-38 b1 — key backup present** (`truncate -s 2000000001`, 12:25:18):

```
17:25:18 WalletApplication   - wallet file size guard: 2000000001 bytes, largeHeap 576MB, soft limit 60397977 bytes -> UNPARSEABLE
17:25:18 StartupBreadcrumbs  - STARTUP breadcrumb: 93 WALLET_FILE_OVERSIZE +18ms size=2000000001 hardLimit=2000000000
17:25:18 WalletFileSizeGuard - wallet file preserved aside: 'wallet-protobuf-testnet' -> 'wallet-protobuf-testnet.oversize.1789838718982' (2000000001 bytes)
17:25:18 WalletApplication   - wallet file is 2000000001 bytes (>= 2000000000 hard limit) — unparseable by construction; preserved as '…', recovering from the key backup
17:25:19 WalletApplication   - wallet restored from backup: 'key-backup-protobuf-testnet'
17:25:19 WalletApplication   - wallet restored from backup: 'key-backup-protobuf-testnet'    <-- twice
```

User-visible: one Toast `Your wallet was reset!  It will take some time to recover.` (`SR-38/10-t2s.png`), then a second Toast reading the raw class name **`java.io.FileNotFoundException`** (`11-t4s.png`). Funds returned after unlock: 1 tDASH (`18-after-recovery-unlock.png`).

Then (NEW-1): 60 s later and after a force-stop, `files/` still has no `wallet-protobuf-testnet`. Next launch:

```
17:27:43 BootstrapReceiver   - wallet does not exist, not showing inactivity warning
17:27:43 WalletActivityTracker - activity lifecycle: activity OnboardingActivity created
```
breadcrumbs go `CONFIG_LOADED → ONCREATE_COMPLETE` with no `WALLET_LOAD_BEGIN` (`22/23-relaunch*.txt`, `21-relaunch-t8s.png`, `sr38-relaunch.mp4`). `key-backup-protobuf-testnet` (15,328 B) was on disk and never consulted.

**SR-38 b2 — key backup removed** (12:30:11), the row's exact scenario:

```
17:30:12 WalletApplication  - wallet file size guard: 2000000001 bytes … -> UNPARSEABLE
17:30:12 WalletFileSizeGuard- wallet file preserved aside: … -> 'wallet-protobuf-testnet.oversize.1789839012413' (2000000001 bytes)
17:30:12 WalletApplication  - cannot read backup — wallet needs a restore from seed
17:30:12 StartupBreadcrumbs - STARTUP breadcrumb: 95 WALLET_BACKUP_UNUSABLE +10ms java.io.FileNotFoundException: …/key-backup-protobuf-testnet
17:30:12 WalletApplication  - wallet load AND key-backup recovery both failed — opening degraded (restore from seed required)
17:30:12 OnboardingActivity - degraded startup: walletFileExists=false, walletLoadDegraded=true, safeMode=false — showing the crash-report path
```
Screen: "Previous crash detected" dialog, then *"Your wallet file could not be read and no automatic backup was usable. Your funds are safe on the network — restore your wallet with your recovery phrase to continue."* with **Restore wallet / Report / Close** (`34-null-degraded.png`). The UI here is clear and offers the right action.

**SR-26.** Both `.oversize` copies (2,000,000,001 B each) survived a restore-from-seed at 12:31 (`SR-26/01-after-restore.txt`) and a full **Reset Wallet** at 12:32:55 (`03-after-reset-files.txt`, `02-after-reset.png`). `cleanupFiles()` deletes only `key-backup-base58*`, `key-backup-protobuf.*` and `*.tmp`; `wallet-protobuf-testnet.oversize.<ms>` matches none and there is no other reclaim path. Nominal occupancy after two events: 4 GB. Caveat: my files are sparse (`truncate`), so `du` showed 60 MB — a genuine oversize wallet would occupy the full size.

### SR-41 — 20 s load budget → safe mode — REPRODUCED

Real loads never approach the budget: measured `took` values are **211.3 / 223.8 / 248.4 / 256.9 ms**, and the 62,929,882-byte file parsed in the same 211 ms as the 15,322-byte one (the tail is ignored), so growing the file cannot slow the parse — CPU burners would need ~80× slowdown. Instead I starved the process deterministically: `kill -STOP` 450 ms into launch (inside `readWallet`) for 21 s, then `kill -CONT`.

```
17:40:22 StartupBreadcrumbs - STARTUP breadcrumb: 4 WALLET_LOAD_BEGIN +11ms size=15322
17:40:43 [wallet-load-budget] WalletApplication   - wallet load exceeded its 20000ms budget (0 DashPay friend chains still deriving) — arming safe mode for the next launch
17:40:43 [wallet-load-budget] StartupBreadcrumbs - STARTUP breadcrumb: 97 WALLET_LOAD_OVERBUDGET +20802ms budgetMs=20000 pendingFriendChains=0
```

The frozen process was reaped before `MAIN_UI_SHOWN`; `startup.failures` was 1 (not 0) because `armSafeModeOnNextDeath()` pre-loads the counter to `SAFE_MODE_THRESHOLD-1`. Next launch (12:41:17):

```
# launch Sat Sep 19 12:41:17 CDT 2026 (previous=INCOMPLETE_PRE_MILESTONE prevLastStage=97 failures=1 safeModeRuns=1 safeMode=true)
0  APP_ONCREATE +2ms
3  CONFIG_LOADED +10ms
91 WALLET_LOAD_SKIPPED_SAFE_MODE +10ms
11 ONCREATE_COMPLETE +18ms
12 DEGRADED_UI_SHOWN +108ms
```

Screen: crash-report dialog (`07-next-launch.png`) then *"The app did not finish starting up the last few times, so this start skipped loading your wallet…"* with **Try Again / Report / Close** (`08-safemode-screen.png`). So **one** over-budget load plus **one** death is enough — the row's "the last two launches died" reading of `SAFE_MODE_THRESHOLD = 2` overstates what must go wrong. "Try Again" works: `SAFE_MODE_RETRY +36660ms` → `SAFE_MODE_RETRY_OK +37074ms`, counters back to 0, normal PIN screen (`10-after-try-again.png`, `11-retry-log.txt`).

---

## NEW defects

| # | Sev | Defect | Repro | Evidence |
|---|---|---|---|---|
| NEW-1 | **S1** | After an oversize/OOM key-backup recovery the recovered wallet is **never written to `wallet-protobuf-testnet`**; the next launch finds no wallet file and goes to ONBOARDING while `key-backup-protobuf-testnet` sits unread on disk. Recovery is good for exactly one session; user must restore from seed. | Force-stop; `truncate -s 2000000001 files/wallet-protobuf-testnet`; launch (recovers, balance correct); wait 60 s; force-stop; launch → onboarding. | `SR-38/19-autosave-log.txt`, `22-relaunch-log.txt`, `23-relaunch-head.txt`, `21-relaunch-t8s.png`, `sr38-relaunch.mp4` |
| NEW-2 | **S2** | **Reset Wallet silently no-ops when `filesDir` is unwritable** — `begin()` warns, UI goes to onboarding, `finish()` logs `destroying nothing`. Wallet file, key backup, keystore secrets and databases all survive; the wallet is fully usable again after relaunch with the same PIN, after the user was told it was reset. | `chmod 555 files/`; Reset Wallet; relaunch. | `SR-36/03-wipe-grep.txt`, `12-destroying-nothing.txt`, `06-run1-wallet-alive.png`, `11-run3-files.txt` |
| NEW-3 | **S3** | A catastrophic wallet recovery announces itself with a **raw Java class name Toast** (`java.io.FileNotFoundException`) from the `FileNotFoundException` handler's `Toast.makeText(this, x.getClass().getName(), …)`. Related: the wallet load + `restoreWalletFromBackup()` run **twice** per launch (`WALLET_RECOVERED_FROM_BACKUP` at +303 ms and +1012 ms). | As NEW-1, screenshot at t+4 s. | `SR-38/11-t4s.png`, `17-breadcrumbs.txt`, `16-guard-log.txt` |
| NEW-4 | **S3** | **`shielded_tree_testnet.sqlite` (+`-shm`/`-wal`, ~4.3 MB) survives a clean Reset Wallet** — the previous wallet's shielded note-commitment tree (mtime 11:44) outlived four Reset Wallets. Not covered by `destroyWalletFiles()`/`cleanupFiles()`. | Clean Reset Wallet, no fault injection; `ls -la files/`. | `CONTROL/04-files-after-clean-wipe.txt`, `SR-26/03-after-reset-files.txt` |
| NEW-5 | **S3** | After a Reset Wallet in a process where the degraded path had latched, onboarding shows the **degraded screen with no "Create new wallet"** option (`walletRecoveryFromSeedNeeded` is a process-lifetime latch `triggerWipe()` does not clear). Relaunching restores normal onboarding. | Degraded launch (oversize + no key backup) → Restore wallet → Reset Wallet → observe screen. | `SR-26/02-after-reset.png`, `04-degraded-after-reset.png`, `05-relaunch-after-reset.png` |

## Environment notes

- `emulator-5554` was not running at session start (no emulator processes at all); started via `qa-emu.sh start dw-qa1 5554`, booted in ~5 s, `adb root` OK.
- dw-qa1 carried an unknown wallet from an earlier session (data 00:09–03:56); I uninstalled and clean-installed the FIX APK so every log line here belongs to this session.
- `$APP <serial> text 1234` does not drive the PIN pad (same as SRB's note). On set-PIN screens tap `resource-id=".../btn_<digit>"`; on the lock screen those ids are absent and `tapon 'text="1"'` works.
- Long `adb shell "( … ) &"` background loops hang the adb connection; push a script to `/data/local/tmp` and `nohup … &` it.
- A `truncate`d 2 GB wallet file is sparse, so `du`/`df` under-report; the guard reads file *length* so guard behaviour is faithful, but SR-26's disk-consumption impact is understated by this method.
- Two `wallet-protobuf-testnet.oversize.*` files left on the device as SR-26 evidence. All injected permission changes reverted (`files/` and `files/datastore` back to `700`), helper script removed from `/data/local/tmp`, no CPU burner loops were ever started. logcat/memlog stopped.