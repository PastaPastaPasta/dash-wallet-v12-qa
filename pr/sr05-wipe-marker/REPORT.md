# PR fix validation — SR-05 / SR-20 / SR-36 / D-107 (wallet-wipe marker)

## Header

| item | value |
|---|---|
| Emulator | `emulator-5562` (AVD `dw-qa5`, Android 15 / API 35, google_apis arm64, 4 GB). The serial was **not running** at task start; it was booted for this task on port 5562. No other serial was touched. |
| Base APK | `apks/base-12000014-5f8c0a8ef.apk` — versionCode 12000014, versionName 12.0.0-upgrade, git `5f8c0a8ef` (md5 `0bdcddf6b1a254acf6c254bdbf6ed611`) |
| Candidate APK | `apks/sr05-32c0bd0b2.apk` — versionCode 12000014, versionName 12.0.0-upgrade, git `32c0bd0b2` (md5 `b45f115150f1230ebd742bf7575be948`) |
| APK switch | same versionCode -> `uninstall` + `install` each way (no in-place upgrade possible) |
| Fix worktree | `~/workspace/dash-wallet-qa/pr/sr05-wipe-marker`, 1 commit on `5f8c0a8ef`: `32c0bd0b2 fix(wipe): a bare wallet-wipe marker must not be able to destroy a wallet` |
| Seeds (QA throwaway, testnet) | funded: `rigid genuine settle camp unlock kingdom donor deny enlist portion virtual taxi`; unfunded churn wallets: `dress inflict sad ...`, `fluid minor diet ...`, `travel symptom there ...`, `bulb sure spray ...`, `deputy need mutual ...`, `hope caught admit ...` |
| Funds | faucet.thepasta.org -> `yZ1xjAn1c2aQ1jQDiLnZp4wBKvx1suKiYo`, 1 tDASH, txid `9a3b6f2983b59c13aa4a12e6c87b0b344646a38df3877c9077838313121c6e23` (one drop, whole session) |
| Session | 2026-09-19, 16:10 – 17:25 local (app log stamps are +5h: 21:1x – 22:2x) |
| Unit tests | `:wallet:test_testNet3DebugUnitTest --tests 'de.schildbach.wallet.util.WalletWipeSequenceTest'` -> **23 tests, 0 failures, 0 errors**, BUILD SUCCESSFUL in 52 s |

## Verdict

**FIXED** — all four sub-items behave as specified on the candidate and all four reproduce on the base APK from the same
steps: a bare `wallet-wipe.pending` no longer destroys a funded wallet (SR-05), a genuinely interrupted wipe still
completes (regression B), a partially failed wipe now keeps the marker and names its failed steps (SR-20), and a wipe
whose marker cannot be written destroys anyway instead of silently no-opping (SR-36/D-107). One residual, deliberately
accepted consequence is documented below (the SR-36 end state is a loud PARTIAL wipe that the next launch does **not**
finish), plus review concerns about the identity check and file litter.

| sub-item | base (BEFORE) | candidate (AFTER) | verdict |
|---|---|---|---|
| SR-05 (S1 data loss) | bare marker -> onboarding, wallet + key backup deleted, 1 tDASH gone | marker renamed aside, wallet loads with 1 tDASH, files intact | **FIXED** |
| SR-05 variant (identity guard) | n/a (no identity in base marker) | `started on a different wallet file` -> new wallet untouched | **FIXED** |
| B regression (interrupted wipe) | completes on next launch | completes on next launch at 0.08 s / 0.2 s / 0.3 s / 0.5 s kill offsets | **NO REGRESSION** |
| SR-20 (S2 partial wipe recorded complete) | marker removed, 6 datastore files byte-identical survivors, nothing logged, next wallet inherits CUT_OVER | 13 failed steps named, marker kept, repair launch finishes the wipe, next wallet logs its own `DUAL_RUNNING -> CUT_OVER` | **FIXED** |
| SR-36 / D-107 (S2 silent no-op) | `destroying nothing`, wallet alive and unlockable with the old PIN | `NO recovery marker on disk ... destroying anyway`, 2 failed steps `[wallet-file, key-backup-file]`, wallet no longer accessible | **FIXED (partial-wipe end state, see D)** |

---

## BEFORE — base APK `base-12000014-5f8c0a8ef.apk`

| # | step | observed | evidence |
|---|---|---|---|
| A1 | create wallet (PIN 1234), fund 1 tDASH, note balance | `1` tDASH / `$ 58.52`; `wallet-protobuf-testnet` 15322 B, `key-backup-protobuf-testnet` 15328 B | `before/14-home-funded.png`, `before/15-files-before.txt`, `before/12-faucet-sent.png` |
| A2 | `force-stop` + `touch files/wallet-wipe.pending` (0 B, root) | marker present, 0 bytes | `before/16-files-with-marker.txt` |
| A3 | launch | **straight to onboarding**, no confirmation, no PIN; `wallet-protobuf-testnet` and `key-backup-protobuf-testnet` **gone**, marker gone; 1 tDASH lost | `before/17-after-launch.png`, `before/18-files-after.txt`, `before/18b-files-full.txt` |
| A4 | wallet.log | `a previous Reset Wallet did not finish — completing it now; this launch does not load a wallet` / `removing wallet from memory during wipe` | `before/19-decisive-grep.txt` |
| C1 | `chmod 500 files/datastore`, Reset Wallet -> confirm | wallet + key backup deleted, **marker removed**, onboarding | `before/23-sr20-after-reset.png`, `before/25-sr20-grep.txt` |
| C2 | datastore after | all 6 preference files **byte-identical** (same md5 as before), incl. `org.dashfoundation.wallet.secrets.preferences_pb`; log says `file-deleted: []` with **no** failure reported | `before/20-datastore-before.txt`, `before/24-sr20-datastore-after.txt` |
| C3 | swallowed failures | 5 x `wallet-wipe listener failed`, `wipe cleanup: removeSdkWallet failed; continuing`, `cutover state persist failed (CUT_OVER -> DUAL_RUNNING, wallet wipe); keeping CUT_OVER` — wipe still recorded complete | `before/25b-sr20-wipe-lines.txt` |
| D1 | `chmod 555 files`, Reset Wallet -> confirm | `could not create the wallet-wipe marker` -> `wipe started WITHOUT a recovery marker` -> **`wipe teardown reached without a wipe having been started — destroying nothing`** | `before/27-sr36-grep.txt` |
| D2 | files after | `wallet-protobuf-testnet` + `key-backup-protobuf-testnet` **untouched** | `before/26-sr36-after-reset.png` |
| D3 | `chmod 700 files`, relaunch | lock screen, **PIN 1234 unlocks the wallet the user was told had been reset** (D-107) | `before/28-sr36-relaunch-wallet-alive.png`, `before/29-sr36-wallet-usable.png` |
| B0 | Reset Wallet, force-stop 0.3 s after confirm, relaunch | 0-byte marker present after the kill; next launch completes the wipe (`a previous Reset Wallet did not finish`), onboarding | `before/30-baseB-marker.txt`, `before/32-baseB-grep.txt`, `before/31-baseB-relaunch.png` |

---

## AFTER — candidate APK `sr05-32c0bd0b2.apk` (fresh install, funded seed restored -> same 1 tDASH)

| # | step (identical to BEFORE) | observed | evidence |
|---|---|---|---|
| A1 | restore the funded seed, unlock | `1` tDASH / `$ 58.14`, files 15322 B / 15328 B | `after/04-home-restored.png`, `after/05-files-before.txt` |
| A2 | `force-stop` + `touch files/wallet-wipe.pending` (0 B, root) | marker present, 0 bytes | `after/06-files-with-marker.txt` |
| A3 | launch | **lock screen -> wallet loads normally**, balance `1` tDASH / `$ 58.11`, history intact; wallet file + key backup **intact**; no `wallet-wipe.pending`; new `wallet-wipe.pending.stale.1789853676905` (0 B) | `after/07-after-launch.png`, `after/10-wallet-intact.png`, `after/08-files-after.txt`, `after/sr05-after.mp4` |
| A4 | wallet.log (verbatim) | `the wallet-wipe marker at /data/user/0/.../files/wallet-wipe.pending (0 bytes) is empty or unreadable — this is NOT an in-flight wipe; renaming it aside and leaving the wallet alone` and `stale wallet-wipe marker kept at /data/user/0/.../files/wallet-wipe.pending.stale.1789853676905`. **No** `removing wallet from memory during wipe`, **no** `a previous Reset Wallet did not finish` | `after/09-decisive-grep.txt` |
| A5 | identity-guard variant: real 220-byte marker captured during B replanted onto a NEW wallet | wallet intact, marker renamed aside; `the wallet-wipe marker was started on a different wallet file (marker: length=15322 modified=1789853351876; on disk: length=15322 modified=1789853916768) — refusing to destroy this wallet` | `after/14-variant-grep.txt`, `after/12-variant-wallet-intact.png`, `after/13-variant-files-after.txt` |
| A6 | marker cost on the cold-launch path | breadcrumb `3 CONFIG_LOADED +85ms` -> decision -> `4 WALLET_LOAD_BEGIN +86ms`: ~1 ms | `logs/cand/files/log/wallet.log` (21:52:44) |

Marker payload written by a real wipe (`regression/real-marker-0.3s.txt`):

```
#Dash Wallet - Reset Wallet in progress
#Sat Sep 19 16:36:17 CDT 2026
walletModified=1789853351876
format=1
startedAt=1789853777912
walletLength=15322
versionCode=12000014
token=d7bbe166-1936-4243-ac9d-e8224a96932f
```

---

## REGRESSION

| # | check | result | evidence |
|---|---|---|---|
| B-0.3s | Reset Wallet, kill 0.3 s after confirm | marker present and **non-zero (220 B)**, wallet file already deleted; relaunch: `a previous Reset Wallet did not finish` -> `databases cleared (isWalletWipe = true, failed steps = [])`, onboarding, **no** `wallet-wipe.pending`, **no** `.stale.` file | `regression/01-b03-files.txt`, `regression/04-b03-grep.txt`, `regression/02-b03-relaunch.png`, `regression/regB-03.mp4` |
| B-0.2s | kill 0.2 s after confirm | wipe had already completed inside the window; clean state, onboarding | `regression/40-b02.txt` |
| B-0.5s | kill 0.5 s after confirm | same — wipe completed, clean state | `regression/41-b05.txt` |
| B-0.08s | kill 0.08 s after confirm (adversarial, earliest window reached) | marker survives with payload; relaunch resumes and finishes (`failed steps = []`) | `adversarial/10-b008-early-kill.txt` |
| C (SR-20) | `chmod 500 files/datastore`, Reset Wallet | **marker kept** (220 B) and: `datastore preferences cleared; ... file-FAILED: [dashpay.preferences_pb, coinbase.preferences_pb, uphold.preferences_pb, wallet_ui.preferences_pb, explore.preferences_pb, exchange_rates_config.preferences_pb, org.dashfoundation.wallet.secrets.preferences_pb]` and `wipe destruction finished with 13 failed step(s): [datastore-file:..., wipe-listener#1, #4, #5, #6, #8, #9] — NOT clearing the marker` | `regression/12-sr20-files.txt`, `regression/13-sr20-grep.txt` |
| C-repair | `chmod 700 files/datastore`, force-stop, launch | `a previous Reset Wallet did not finish` -> wipe re-runs, `file-deleted: [explore.preferences_pb, org.dashfoundation.wallet.secrets.preferences_pb]`, `failed steps = []`, marker gone, datastore only holds freshly recreated 0-byte files, onboarding | `regression/16-sr20-repair-files.txt`, `regression/17-sr20-repair-grep.txt`, `regression/15-sr20-repair-launch.png` |
| C-cutover | next wallet after the repair launch | `cutover state DUAL_RUNNING -> CUT_OVER (fresh-wallet setup (restore/new))` — the new wallet runs its own cutover; no inherited CUT_OVER (base leaked it) | `regression/18-sr20-cutover-next-wallet.txt`, `regression/14-sr20-cutover-during-wipe.txt` |
| D (SR-36) | `chmod 555 files`, Reset Wallet | `wipe started WITHOUT a recovery marker`, `Reset Wallet is running with NO recovery marker on disk (begin() could not write one) — destroying anyway because the user explicitly asked for it`, `removing wallet from memory during wipe`, `could not delete the wallet file ... — the wipe did NOT destroy the wallet`, `wipe destruction finished with 2 failed step(s): [wallet-file, key-backup-file]`. **No `destroying nothing`.** | `regression/22-sr36-grep.txt`, `regression/sr36-cand.mp4` |
| D-end state | what survives / next launch | survivors: `wallet-protobuf-testnet`, `key-backup-protobuf-testnet`, `shielded_tree_testnet.sqlite*`; databases dir empty, datastore emptied, keystore secrets removed. `chmod 700 files` + relaunch does **not** finish the wipe (no marker was ever written) — the app shows a lock screen and the old PIN is rejected: `Wrong PIN! 7 attempts remaining` | `regression/26-sr36-survivors.txt`, `regression/27-sr36-next-launch.png`, `regression/30-sr36-pin-attempt.png`, `regression/28-sr36-next-launch-files.txt` |
| everyday path | plain uninterrupted Reset Wallet -> restore the same seed | wipe clean (`failed steps = []`, nothing left in `files/` but the shielded tree); restore brings back `1` tDASH / `$ 58.06`; an earlier restore in the session also worked | `regression/51-plain-reset.png`, `regression/52-plain-reset-files.txt`, `regression/54-restore-after-plain-reset.png`, `regression/plain-reset.mp4`, `regression/50-restore-funded.png` |
| stability | crashes / ANRs | crash buffer empty; `exit-info`: 11 x FORCE STOP (mine) + 1 x bg-ANR at 16:52:58 on a cold launch — the marker decision took ~1 ms, the ANR is `DeterministicKeyChain` key derivation (2.9 s + 1.8 s + 1.7 s) on a Mac running three emulators, i.e. the pre-existing slow-wallet-load area, not this change | `logs/cand-exitinfo.txt`, `logs/logcat-cand.txt` |
| log noise | error-ish lines / line | base 61 / 2991 lines (2.0 %), candidate 141 / 8448 lines (1.7 %) over a session with 4x more wipes — no new storm; the new lines are the intended ERROR reports (`wallet.log` has no level column, so `grep ' WARN \| ERROR '` is useless here) | `logs/base/files/log/wallet.log`, `logs/cand/files/log/wallet.log` |
| D-109 (out of scope) | `shielded_tree_testnet.sqlite` after a clean wipe | still survives (200704 B + `-shm`/`-wal`), **unchanged** from base | `regression/52-plain-reset-files.txt`, `regression/32-shielded-note.txt` |

---

## ADVERSARIAL (beyond the recipe)

| # | variation | expectation | observed | evidence |
|---|---|---|---|---|
| 1 | valid payload, `startedAt` 48 h in the past, identity matching | rejected as expired | `the wallet-wipe marker ... is 172801261 ms old (limit 86400000 ms, started 1789681920000, versionCode 12000014) — a wipe that did not finish in a day is not going to` -> renamed aside, wallet intact | `adversarial/02-48h-grep.txt`, `adversarial/01-48h-marker.png` |
| 2 | valid payload dated **72 h in the future** (clock moved) | rejected (negative age) | `... is -259194763 ms old (limit 86400000 ms ...)` -> renamed aside, wallet intact | `adversarial/05-future-grep.txt` |
| 3 | stray `wallet-wipe.pending.writing` staging file left behind | ignored | ignored; wallet loads. **Never cleaned up** — still present after the next successful wipe | `adversarial/04-future-files.txt`, `adversarial/07-wrong-versioncode-files.txt` |
| 4 | fresh valid payload, **wrong versionCode (11090002)**, identity matching the wallet on disk | honoured (versionCode is forensics, not a gate) and the wipe resumes | resumed: `a previous Reset Wallet did not finish` -> `failed steps = []`, wallet + key backup deleted, marker cleared | `adversarial/08-wrong-versioncode-grep.txt`, `adversarial/06-wrong-versioncode.png` |
| 5 | triple-tap the Reset confirm + `am send-trim-memory RUNNING_CRITICAL` during the wipe | one clean wipe, no re-entrancy damage | single wipe, `failed steps = []`, no `destroying nothing`, no leftover marker | `adversarial/21-double-confirm-files.txt`, `adversarial/22-double-confirm-grep.txt` |
| 6 | stray `de.schildbach.wallet.service.wipe_wallet` intent (root) at a healthy wallet, in a process that had already completed a wipe (tests the new in-process "user asked" flag) | nothing destroyed | service received the intent (`onStartCommand ... wipe_wallet`), wallet + key backup untouched, balance screen unchanged | `adversarial/30-stray-wipe-files.txt`, `adversarial/31-stray-wipe-grep.txt`, `adversarial/32-stray-wipe.png` |

---

## PR evidence (best artefacts)

1. `before/17-after-launch.png` — BASE: after planting a bare 0-byte marker the funded wallet is gone, app is at onboarding.
2. `before/19-decisive-grep.txt` — BASE decisive log: `a previous Reset Wallet did not finish ...` + `removing wallet from memory during wipe`.
3. `after/10-wallet-intact.png` — AFTER: same steps, wallet loads with its 1 tDASH balance and history.
4. `after/09-decisive-grep.txt` — AFTER decisive log: `... (0 bytes) is empty or unreadable — this is NOT an in-flight wipe ...` + `stale wallet-wipe marker kept at ...`.
5. `regression/13-sr20-grep.txt` — SR-20 fixed: `wipe destruction finished with 13 failed step(s): [...] — NOT clearing the marker ...`.
6. `regression/22-sr36-grep.txt` — SR-36/D-107 fixed: `Reset Wallet is running with NO recovery marker on disk ... destroying anyway ...` (base logged `destroying nothing`).
7. Video `after/sr05-after.mp4` (stale marker -> wallet survives) and `regression/regB-03.mp4` (interrupted wipe that still completes).

---

## New findings

| id | sev | finding |
|---|---|---|
| N-1 | S3 | **SR-36 end state is an unfinished, unrepairable partial wipe.** With `filesDir` unwritable the wipe now correctly destroys what it can, but no marker exists, so the next launch does **not** finish it: `wallet-protobuf-testnet` and `key-backup-protobuf-testnet` stay on disk while the keystore secrets are gone, and the user lands on a lock screen where the old PIN is rejected (`Wrong PIN! 7 attempts remaining`). Strictly better than base (D-107: fully usable wallet after a "reset"), and the residual files are useless without the keystore keys, but the app should notice `walletFileExists && secrets missing` and finish the job rather than offering an unusable PIN prompt. Evidence: `regression/26-sr36-survivors.txt`, `regression/30-sr36-pin-attempt.png`. |
| N-2 | S4 | In that same state the user is greeted with **"Previous crash detected — would you like to send a crash report?"** (`OnboardingActivity - degraded startup: walletFileExists=true, walletLoadDegraded=false, safeMode=false — showing the crash-report path`) although nothing crashed; the base never reaches this path. Evidence: `regression/23-sr36-crash-dialog.png`, `regression/29-sr36-next-launch-grep.txt`. |
| N-3 | S4 | **Retired markers are litter.** `wallet-wipe.pending.stale.<ms>` files (kept on purpose) and a stray `wallet-wipe.pending.writing` accumulate in `filesDir` forever — nothing, including a later successful wipe or `cleanupFiles()`, removes them. Two stale files plus a `.writing` file survived a full Reset Wallet in this session. Evidence: `adversarial/07-wrong-versioncode-files.txt`. |

## Review concerns about the change itself

1. **Wallet identity is `length + lastModified`, captured in `begin()` before the wallet is detached.** Autosave can rewrite
   `wallet-protobuf-testnet` between the marker write and `shutdownAutosaveAndWait()`; if the process dies in that window,
   the next launch sees a *mismatch* and refuses to resume (`started on a different wallet file`), leaving a half-wiped
   wallet on disk with the keystore secrets possibly already gone — i.e. the N-1 state, reached from an ordinary crash
   rather than fault injection. The window is small (the whole wipe is < 1 s) and the direction is the safe one for
   SR-05, but re-stat'ing the wallet file immediately *after* the detach, or accepting resumption when the on-disk file
   is strictly newer than the recorded one, would close it.
2. **`begin()` keeps an existing valid marker** (to preserve the interrupted wipe's provenance). If wallet A's wipe is
   interrupted, wallet B is restored and reset within 24 h, B's wipe runs under a marker naming A's file; an interruption
   of B's wipe then hits the mismatch path above. Worth a comment, or refreshing the recorded identity when it no longer
   matches the wallet on disk.
3. **`wipeRequestedInThisProcess` is only cleared on a fully successful wipe.** After a partial failure (SR-20 path) the
   flag stays `true` for the life of the process, so any later teardown in that process would destroy without a marker.
   Benign today (the SR-20 repair path restarts the process, and the stray-intent test destroyed nothing), but it is a
   latent "destroy without a request" edge — clearing it after the failure report would be cheap.
4. Minor: `MAX_MARKER_AGE_MS` silently retires a genuinely interrupted wipe after 24 h; documented and in the recoverable
   direction, but a device left off for two days comes back with a half-wiped wallet loaded as if healthy (same class as
   N-1). A "this wallet may be half-reset" signal would help.

## Environment / harness notes

- `emulator-5562` did not exist at task start; booted `dw-qa5` on port 5562 (`emulator -avd dw-qa5 -port 5562 ...`).
- `$APP <serial> launch` (monkey) lands on the launcher; `adb shell am start -n $PKG/de.schildbach.wallet.ui.OnboardingActivity` works (it is the resolved LAUNCHER activity).
- `wallet.log` has no level column, so `grep -c ' WARN \| ERROR '` always returns 0; use `grep -icE 'failed|exception|error'`.
- PIN pad taps by fixed coordinates (btn_1 208,1836 / btn_2 540,1836 / btn_3 872,1836 / btn_4 208,1967) with 1.4 s gaps; on the lock screen use `tapon 'text="N"'`.
- A crafted marker pushed with `adb push` must be `chown`ed to the app uid (`u0_a210` here) or the app cannot rename it aside.
- Helper scripts used: `/tmp/mkwallet5562.sh` (create wallet), `/tmp/restore5562.sh` (restore the funded seed), `/tmp/killreset5562.sh <delay> <tag>` (reset + timed force-stop + relaunch report).
