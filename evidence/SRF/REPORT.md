# SRF — SR device-reproduction report (shielded / Platform side)

| | |
|---|---|
| Emulator | `emulator-5566` (AVD **dw-qa6**, Android 15 / API 35). It was **not running** at task start; I started it myself (`emulator -avd dw-qa6 -port 5566 …`, booted 11:43 CDT). |
| Build under test | `fix-12.0.0-testnet3-release-signed.apk` — `versionCode=12000000 versionName=12.0.0` (already installed on the AVD) |
| Baseline | not used (all items are fix-build-only shielded flows) |
| Package | `hashengineering.darkcoin.wallet_test` |
| Wallet | pre-existing throwaway wallet on the AVD (SDK wallet `846c2698…`), PIN 1234. **Reference seed not touched.** |
| Funding | 1 tDASH from faucet.thepasta.org -> `yThkc1p6c3w2KPPwaSZiNgnWL3KiHsewWU`, txid `d2ae1885fd47a0d69fbb3135a5cf4e6354dca83d293534320ebd706814626e54`. A 2nd drop was **refused** ("that address already received 1 tDASH today"), so the whole stream ran on 1 tDASH. |
| Username created | `srfqa5566test9` (non-contested, 0.03, funded from the shielded pool), identity `8HeVCaGd…` |
| Own shielded address | `tdash1zzr4ry25kum2f3m24ddcly5weg6tddwpqe9tkku45j06hnwl69zrt580ju0sf5rddtp8crq788jx9` |
| Start / end | 2026-09-19 11:40 – 14:10 CDT (wallet.log timestamps are **UTC**, i.e. CDT+5) |
| Evidence root | `/Users/dcg/workspace/dash-wallet-qa/evidence/SRF/` |

Balance ledger (full running ledger in `notes.md`): 0 -> +1.0 faucet -> shield 0.9 -> unshield 0.1 -> DASH-max shield ->
username -0.03 -> unshield 0.15 -> invite -0.032 -> shielded self-send fee. **Final: transparent 0.150008 / shielded 0.776
(sum 0.926 of 1.0; every 0.074 accounted for). No unexplained loss.**

---

## Summary

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| SR-12 | **PARTIAL** | Unshield 0.1; at T+2 s `iptables -A OUTPUT -p tcp --dport 1443/443 -j DROP` + `emu network speed gsm/delay gprs`. Watched to T+130 s, then restored the network. | `SR-12/t041.png`, `SR-12/22-reenter.png`, `SR-12/r030.png`, `SR-12/grep-stall.txt`, `SR-12/srf-sr12b.mp4`, `SR-12/timeline.txt` | Watchdog **does** fire at 40 s and **does** lock the whole screen out (keypad dead, Continue = "Sending your transfer…") across leaving and re-entering. It is **not** permanent: when the underlying op finally terminated the transfer completed, balance moved and the screen freed itself. Never fired on a healthy network (shield/unshield complete in < 8 s here). |
| SR-13 | **REPRODUCED** | Shielded send 0.05 -> own shielded address; BACK 3 s after the PIN (VM clear, process alive); waited 65 s; re-entered. | `SR-13/timeline.txt`, `SR-13/grep.txt`, `SR-13/21-balances-after.png`, `SR-13/20-reenter.png`, `SR-13/srf-sr13.mp4` | The spend **still went out** (shielded 0.778 -> 0.776, fee consumed) while the outcome was **lost completely**: no screen state, no toast, no notification, and **no log line at all** for the result. Re-entry gives a fully Idle, immediately re-submittable screen. Rotation / "don't keep activities" variants NOT run (time). |
| SR-14 | **NOT REPRODUCED (as written) / NEW defect found** | Invite (private, non-contested 0.03) from the shielded pool; wifi+data off at T+3 s; watched 3 min; retried offline and after restoring. | `SR-14/timeline.txt`, `SR-14/grep1.txt`, `SR-14/grep2.txt`, `SR-14/n030.png`, `SR-14/21-retry-online.png` | No forever-`Proving`: it terminated in ~22 s. But it terminated with a **wrong** permanent-failure message and then **permanently disabled the Confirm button** (`enabled="false"`) for that dialog, even after the network came back. `submit refused` never appeared. |
| SR-30 | **REPRODUCED** | Parked Send-to-address screen (`--ei screen 1`), Max = 0.77828183 -> Continue -> Confirm -> PIN. | `SR-30/grep.txt`, `SR-30/m070.png`, `SR-30/20-max.png`, `SR-30/srf-sr30.mp4` | Fails pre-broadcast: `Insufficient shielded balance: available 77828183400, required 77991034200` (fee 162850800 credits, no reserve, no fee-adjust retry). Compared with the transfer screen, whose DASH Max **does** auto-adjust and succeed. |
| SR-31 | **REPRODUCED** | Transfer screen, toggle to fiat, Max ($11.8751 = 0.19999663), Continue, Confirm, PIN. Ran the DASH-mode Max control immediately after with the same balance. | `SR-31/w008.png`, `SR-31/d008.png`, `SR-31/grep.txt`, `SR-31/srf-sr31.mp4` | Fiat Max -> "This transfer was not sent / Nothing left your balance" in ~8 s. DASH Max on the same screen/balance -> auto-adjust retry -> succeeds. Exactly the `isMaxSpend = amount == availableBalance` round-trip loss the SR predicts. |
| SR-02 | **NOT REPRODUCED** | 3 invite creations, `am force-stop` at T+2 s, T+4 s, T+6 s after the PIN. Relaunched and checked shielded balance + Invitations History each time. | `SR-02/timeline.txt`, `SR-02/rA-04-balances.png`, `SR-02/rB-04-balances.png`, `SR-02/rC-05-balances.png`, `SR-02/rC-06-invites-history.png`, `SR-02/rC-07-invite-detail.png` | 2 s / 4 s: nothing spent (0.810 unchanged). 6 s: 0.810 -> 0.778 **and** the invite is in Invitations History with a working "Copy Invitation Link" — the one-time key was persisted. **Total lost: 0.** The whole key-gen -> fund -> persist pipeline finishes in < 6 s here, so the :359…:413 window is milliseconds wide. |
| SR-11 | **REPRODUCED** | Created `srfqa5566test9` from the shielded pool (0.03, non-contested). | `SR-11/10-home-history.png`, `SR-11/12-more-after.png`, `SR-11/grep.txt`, `SR-11/srf-sr11.mp4` | Shielded 0.992 -> 0.962 and the Home History contains **no row** for the 0.03. Confirms D-007's root cause on device. |

---

## Detail

### SR-12 — shielded stall watchdog (PARTIAL)

Setup: transparent 0.09999737 / shielded 0.89787148. Transfer screen, direction reversed to
Shielded -> Dash Wallet, amount 0.1.

* 11:56:56 CDT — PIN entered (T0). `SR-12/03-pin.png`
* T+2 s — `adb -s emulator-5566 shell iptables -A OUTPUT -p tcp --dport 1443 -j DROP` (and `--dport 443`), plus
  `emu network speed gsm` / `emu network delay gprs`. Android still reported `hasInternet: true, validated: true`.
* T+5…T+36 s — modal "Sending your transfer… / This could take up to 10 minutes to complete. We will notify you
  when it's done." with a "Hide" action.
* **T+41 s — the stall overlay fires**, plus a heads-up system notification (`SR-12/t041.png`):
  > **Still finishing your transfer**
  > This is taking a little longer than usual. Your transfer is still in progress and will finish in the background — your shielded balance updates automatically when it completes. … Not done yet, but it's safe to leave this screen.
  > [ Continue in the background ]

  Strings are `shielded_transfer_stalled_title` / `_message` in
  `/Users/dcg/workspace/dash-wallet-qa/wt-fix/wallet/res/values/strings-dashpay.xml:714` (they are **not** in
  `values/strings.xml`, which is where the SR points).

  `…/SRF/SR-12/logs/files/log/wallet.log:14342`:
  ```
  16:57:36 [DefaultDispatcher-worker-4] ShieldedTransferExecutor - shielded transfer has no outcome after 40000 ms — surfacing Stalled (the spend keeps running; a terminal result will supersede)
  ```
* 16:57:41 (5 s later) the app **auto-locked** and hid the overlay behind the PIN screen
  (`wallet.log` `LockScreenActivity - LockState = ENTER_PIN`). Cause: Security > Advanced Security >
  Auto Logout default **"1 min"**. Unlocking restored the overlay intact. I set it to 24 h afterwards to stop it
  interfering with the rest of the session (environment change, noted).
* "Continue in the background" **finishes the activity** (back to Payments > Internal) — `SR-12/21-after-ack.png`.
* **Re-entering the screen does not give you a working screen**: the button reads "Sending your transfer…", the
  keypad is inert (the amount stays "0" however many digits you tap) and the From row shows a "0.10 pending" badge.
  `SR-12/22-reenter.png`, `23-amount-entered.png`, `24-after-cont.png`.
* Network restored 12:01:05. **12:01:37 the transfer completed by itself**, the app navigated to More and the
  balances moved to transparent 0.199 / shielded 0.795 (`SR-12/r030.png`). `wallet.log:14463`
  `17:00:02 CutoverUiDataService - SDK balance published: 19999737 duffs (was 9999737)`.

What the user sees: a soft, correctly-worded "still working" notice at 40 s, then a screen that refuses any further
transfer until the first one resolves. **The "permanently bricks the screen … cannot be used again in this process"
part of SR-12 did not hold** — the lockout lasts exactly as long as the operation does. It would only be permanent if
the FFI call itself never returned, which I could not produce (the op survived a ~4-minute DAPI blackout and resolved).
Also **not** reproduced: "fires on healthy transfers" — on this emulator a shield completes in < 8 s, so the watchdog
never fired without fault injection.

### SR-13 — shielded Send runs in viewModelScope (REPRODUCED)

Send screen, 0.05 -> my own shielded address, shielded balance 0.77828183 before.

* 13:15:06 PIN (T0). T+3 s: `input keyevent KEYCODE_BACK`. The activity is destroyed immediately
  (`wallet.log` `18:15:06 WalletActivityTracker - activity lifecycle: activity ShieldedBalanceActivity destroyed`)
  and the user lands on Home with **no indication anything is in flight** (`SR-13/12-after-back.png`).
* Waited 65 s on Home: no toast, no system notification, no banner (`SR-13/b065.png`).
* **The log contains no outcome line for this send at all.** `grep -E 'ShieldedSend|transferShielded'` after 18:15:06
  is empty (`SR-13/grep.txt`) — contrast with the app-scoped transfer executor, which always logs and notifies.
* **The spend nevertheless went through**: shielded 0.778 -> **0.776** (`SR-13/21-balances-after.png`). It was a
  self-send, so only the fee (~0.0016) actually left; against a third-party address the full 0.05 would have gone
  with the user never being told.
* Re-entering the screen: address blank, amount 0, **Continue live, fully re-submittable** (`SR-13/20-reenter.png`).

Not covered (ran out of time): the rotation variant, the `always_finish_activities 1` variant, and actually firing a
second submit to prove the double spend. `always_finish_activities` was reset to 0 at the end regardless.

### SR-14 — no watchdog on invite creation (NOT REPRODUCED as written)

* Getting to the flow at all required unshielding first — see **D-SRF-2** below.
* Invitations > "Create a private invitation" > Non-contested 0.03 > Confirm and pay > PIN at 12:52:12; wifi+data
  disabled at T+3 s.
* T+15 s: "This could take about 30 seconds. We will notify you when it's done."
* **T+30 s** (measured; the log line is at T+22 s) the dialog shows a terminal error — there is no endless spinner:
  > The Dash network rejected this invitation, so trying again will not help. Please try a different invitation type, or update the app if the problem continues.

  ```
  17:52:40 [DefaultDispatcher-worker-11] SdkShieldedInviteCreation - shielded invite funding rejected pre-broadcast
  17:52:40 [main] ConfirmInviteDialogFragment - invite creation failed: kind=REJECTED attempt=1 retryAllowed=false
  ```
* Tapping Confirm again while offline: nothing. After re-enabling wifi+data and waiting 20 s: still nothing —
  `confirm_btn` reports `enabled="false"`. The only way forward is to back all the way out of the flow (which then
  works). `submit refused: an operation is …` never appeared, so the single-flight gate is not what blocks the retry;
  the dialog's own `retryAllowed=false` is.
* No funds were consumed (shielded stayed 0.810).

I did not separately exercise the **username** creation path under a network cut; the username I created (SR-11)
completed in 8 s on a healthy network. So `SdkShieldedUsernameCreation`'s missing watchdog is **untested** — SR-14
is disproved only for the invite path.

### SR-30 — shielded Max to an address can never succeed (REPRODUCED)

The Send-to-address screen has **no UI entry point** (`ShieldedBalanceActivity.SCREEN_SEND` is parked); I reached it with
`am start -n <pkg>/de.schildbach.wallet.ui.shielded.ShieldedBalanceActivity --ei screen 1 --ez LockScreenActivity.keep_unlocked true`.

* Max -> 0.77828183 (the whole pool, no reserve). Continue -> Confirm -> PIN.
* Fails; the screen returns to composing with "Insufficient funds" (`SR-30/m070.png`).
  ```
  18:08:48 [DefaultDispatcher-worker-9] ShieldedBalanceServiceImpl - shielded transferShielded rejected pre-broadcast (notes released)
  18:08:48 [main] ShieldedSendViewModel - shielded send not sent: pre-broadcast shielded note-selection failure
  Caused by: org.dashfoundation.dashsdk.ffi.DashSDKException: shielded transfer failed: Insufficient shielded balance: available 77828183400, required 77991034200
  ```
  The shortfall is exactly the fee, 162 850 800 credits.
* Comparison asked for in the brief — the **transfer** screen's DASH Max on the same build does have the retry:
  ```
  17:25:19 [DefaultDispatcher-worker-8] ShieldedTransferExecutor - max shield auto-adjusting for L1 asset-lock fee: requested 0.19999737, reserve 1192 duffs (2 UTXOs), retrying once with 0.19998545
  ```
  and it succeeded. The send screen has no equivalent.
* Max-minus-a-little: a manual 0.05 on the same screen **does** work (that is the SR-13 run above), so the failure is
  specific to spending the full balance.
* Two extra observations on this screen: a transparent `y…` address is silently rejected (Continue just stays dead,
  no validation message — `SR-30/02-addr.png`), and after any completed/failed shielded op the screen's balance sticks
  at 0 for the rest of the process; only a force-stop restores it (verified: restart -> Max = 0.77828183 again).

### SR-31 — fiat-mode Max (REPRODUCED)

The currency toggle is the **"USD"/"DASH" label to the right of the amount** (tap 995,556 at 1080x2400), not the
chevron under it.

* The lossy round trip is visible immediately: 0.05 DASH -> $2.9816 -> **0.04999932** DASH (-68 duffs).
* With transparent 0.19999737, fiat Max shows **$11.8751 / 0.19999663 DASH** — 74 duffs short of the balance, so
  `amount != availableBalance` and `isMaxSpend` is false.
* Confirm + PIN -> fails in ~8 s: **"This transfer was not sent — Nothing left your balance. Check the details and
  try again."** Balance unchanged. `SR-31/w008.png`
  ```
  17:23:16 [DefaultDispatcher-worker-5] ShieldedBalanceServiceImpl - shielded shieldFromWallet rejected pre-broadcast (no lock tracked)
  17:23:16 [DefaultDispatcher-worker-5] ShieldedTransferExecutor - shielded transfer not sent: pre-broadcast asset-lock coin-selection failure
  ```
* **Control, same screen, same balance, DASH-mode Max:** succeeds in < 8 s (transparent 0.19999737 -> 0.000008),
  because `isMaxSpend` is true and the executor runs the fee-adjust retry (log line quoted under SR-30).
  `SR-31/20-dashmax.png`, `SR-31/d008.png`

### SR-02 — invite cancel after funding (NOT REPRODUCED)

| run | kill at | shielded before -> after | invite in history? | lost |
|---|---|---|---|---|
| A | T+2 s | 0.810 -> 0.810 | no | 0 |
| B | T+4 s | 0.810 -> 0.810 | no | 0 |
| C | T+6 s | 0.810 -> **0.778** | **yes** — "Invitation 1, Sep 19 01:04 pm", detail screen offers "Copy Invitation Link" | 0 |

`am force-stop` was issued from adb at the stated delay after the PIN, then the app was relaunched, unlocked and the
More card + Invitations History read. `SR-02/timeline.txt` has the exact timestamps.

On this emulator the whole `generateOneTimeOrchardKey` -> `fundNotesToRaw43` -> `persistTracking` pipeline runs in under
6 s, so the window the SR describes (key at :350, spend at :359, persist at :413) is a few milliseconds wide and I
could not land inside it with process kills. **The finding is not disproved in principle — it is a genuine
write-ordering hazard in the code — but it is not reachable by a user cancelling or by a kill at human timescales on
this hardware.** A device where the Halo 2 proof takes the documented ~30 s would widen the window proportionally.

### SR-11 — username from the shielded pool writes no history row (REPRODUCED)

* More > Join DashPay > payment option **"Shielded balance"** > `srfqa5566test9` (non-contested) > 0.03 from
  shielded balance > I accept > Confirm > PIN at 12:40:35.
  ```
  17:40:34 [main] RequestUserNameViewModel - routing username creation to the shielded-funded SDK path
  17:40:42 [DefaultDispatcher-worker-14] SdkShieldedUsernameCreation - shielded-funded identity created at index 0 (8HeVCaGd…) — 0.03 denomination, contested=false
  17:40:47 [DefaultDispatcher-worker-15] CreateIdentityService - SDK username creation broadcast — restore worker will advance the identity tile
  ```
* Shielded card: **0.992 -> 0.962** (`SR-11/12-more-after.png`).
* Home History (`SR-11/10-home-history.png`) contains exactly four rows — Shielded -0.19999 (12:25),
  Unshielded +0.1 (12:00), Shielded -0.900003 (11:51), Received +1 (11:46) — and **nothing for the 0.03**.

---

## New defects found along the way

| id | Sev | Defect | Repro | Evidence |
|---|---|---|---|---|
| **D-SRF-1** | **S2** | **Confirm + PIN on the shielded transfer screen is a silent no-op when the shielded runtime is momentarily not READY.** `ShieldedTransferViewModel.onConfirm()` starts with `if (!state.canContinue || !state.showConfirm) return` and `canContinue` requires `ready`; the user authenticates with their PIN and nothing happens — no error, no spinner, no log line. Happened twice in a row. | Transfer screen; wait until the To row shows "0.00" instead of the shielded balance; Continue -> Confirm -> PIN. | `SR-31/07-stuck-sheet.png`; wallet.log `17:15:16` and `17:17:39` `ModernEncryptionProvider - Decrypted data for alias: ui_pin_key` (PIN verified) with no transfer afterwards. `wt-fix/…/ui/shielded/ShieldedTransferViewModel.kt` `onConfirm()` |
| **D-SRF-2** | **S2** | **The invite entry point is gated on the TRANSPARENT balance, so shielding everything locks you out of shielded invites.** `CreateInviteViewModel.combineLatestData` requires `walletData.observeTotalBalance() >= Constants.DASH_PAY_FEE` (0.03). With 0.000008 transparent and 0.962 shielded, More > Invitations is **hidden** — even though the private-invite path funds itself entirely from the shielded pool. | Shield the whole L1 balance, create a username, open More. | `SR-14/03-more-scrolled.png` (no Invitations) vs `SR-02/00-balances-before.png` (present after unshielding 0.15); `wt-fix/…/ui/invite/CreateInviteViewModel.kt:82-86` |
| **D-SRF-3** | **S3** | **An offline invite creation is reported as a permanent network rejection and permanently disables retry.** Airplane mode during the funding step produces `kind=REJECTED … retryAllowed=false` and "The Dash network rejected this invitation, so trying again will not help" — the network rejected nothing, the device was offline. Confirm stays `enabled="false"` even after connectivity returns. | Invite > private > non-contested > Confirm > PIN, then `svc wifi disable; svc data disable` 3 s later. | `SR-14/n030.png`, `SR-14/21-retry-online.png`, `SR-14/grep2.txt` |
| **D-SRF-4** | **S3** | **The parked Send-to-address screen's shielded balance sticks at 0 after any shielded operation in the same process.** Max returns 0 and every amount shows "Insufficient funds" while the More card correctly shows 0.778. Survives leaving and re-entering; only `am force-stop` + relaunch restores it. `ShieldedSendViewModel` consumes `observeShieldedBalance()` raw, without the last-known/stale fallback MoreFragment has. | Do any shielded send/transfer, then open `--ei screen 1` and tap Max. | `SR-30/10-max.png` (Max = 0) vs `SR-30/08-more-balances.png` (0.992 on the card) vs `SR-30/20-max.png` (correct after restart) |
| **D-SRF-5** | **S4** | A transparent `y…` address on the Send-to-address screen is rejected with **no message at all** — Continue simply never enables. | `--ei screen 1`, paste a transparent address, enter an amount, tap Continue. | `SR-30/02-addr.png` |
| **D-SRF-6** | **S4** | The **1-minute Auto Logout default** locks the app while a shielded transfer overlay is on screen, hiding the 40 s stall notice behind the PIN pad 5 s after it appears. | Start a slow shielded transfer, do not touch the screen. | wallet.log `16:57:36` (Stalled) then `16:57:41 LockScreenActivity - LockState = ENTER_PIN`; `SR-12/t045.png` |

## Environment / harness notes

* **dw-qa6 was not running** when the task started; I started it. With seven emulators live the host is saturated and
  `adb shell input tap` events are dropped fairly often — PIN entry needs **>= 1.2 s between digits** and should be
  verified (three wrong PINs briefly disabled the wallet for 1 minute). `$APP <serial> text 1234` does not drive the
  PIN pad at all.
* The keypad geometries differ: lock screen `btn_1` at (208,1898), in-app Authenticate dialog at (208,1836).
  Helpers are in the evidence dir: `SRF/pin.sh` (bounds-based PIN entry) and `SRF/k.sh` (shielded keypad).
* Layout on the Send screen shifts once the address field is filled — the Max button moves from y=848 to y=936.
* `am start -n <pkg>/de.schildbach.wallet.ui.shielded.ShieldedBalanceActivity --ei screen {0,1,2} --ez LockScreenActivity.keep_unlocked true`
  is a reliable way into the transfer / parked send / parked receive screens; the bottom-nav route was flaky.
* Faucet: one drop per address per UTC day, so a second drop needs a second (unused) receive address; the wallet did
  not rotate its address after the first unconfirmed deposit.
* All fault injection was undone: iptables rules deleted (`iptables -L OUTPUT -n | grep -c DROP` -> 0),
  `emu network speed full` / `delay none`, wifi+data re-enabled, `always_finish_activities 0`. Auto Logout was left at
  24 hours (changed by me at 12:10 CDT to stop the 1-minute lock interfering).
* `logcat.txt`, `mem.csv` and a full `wallet.log` snapshot are in `SRF/` and `SRF/logs/files/log/`.
