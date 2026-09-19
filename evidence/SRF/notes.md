2026-09-19T11:43:50 SRF start: emulator-5566 (dw-qa6, API 35), FIX 12.0.0 vc12000000 installed

## Setup
- 2026-09-19 11:43 CDT: emulator-5566 (AVD dw-qa6, Android 15 / API 35) started by me (it was not running). `adb root` OK.
- FIX apk already installed: versionCode=12000000 versionName=12.0.0. Pre-existing wallet on the device (created ~01:30 by an earlier session), PIN 1234 works. Transparent balance 0, history empty.
- Receive address #1: yThkc1p6c3w2KPPwaSZiNgnWL3KiHsewWU
- 16:46 UTC faucet drop #1: 1 tDASH, txid d2ae1885fd47a0d69fbb3135a5cf4e6354dca83d293534320ebd706814626e54
- Faucet refuses a 2nd drop to the SAME address ("already received 1 tDASH today"). Will try a fresh address.
- LEDGER: transparent 0.0 / shielded ? (pre-faucet)
- 11:51:20 CDT: shielded 0.9 from Dash Wallet. Completed in **< 8 s** (no 30 s proof on this emulator); auto-navigated to More.
  LEDGER after: transparent 0.099 / shielded 0.897.  Evidence: setup/13..18*.png, setup/srf-shield-fund.mp4

## SR-12 (11:53-12:03 CDT / 16:53-17:03 UTC)
- LEDGER before: transparent 0.09999737 / shielded 0.89787148
- Unshield 0.1 (Shielded -> Dash Wallet). PIN at 11:56:56. At T+2 s: `iptables -A OUTPUT -p tcp --dport 1443/443 -j DROP` + `emu network speed gsm` + `delay gprs`.
- T+5..T+36 s: "Sending your transfer… / This could take up to 10 minutes…" (Hide).
- **T+41 s: "Still finishing your transfer" overlay + system notification** (strings-dashpay.xml:714 shielded_transfer_stalled_title). Button = "Continue in the background". SR-12/t041.png
- wallet.log 16:57:36 `ShieldedTransferExecutor - shielded transfer has no outcome after 40000 ms — surfacing Stalled (the spend keeps running; a terminal result will supersede)`
- 16:57:41 the app AUTO-LOCKED (LockScreenActivity LockState = ENTER_PIN) 5 s after the overlay, hiding it behind the PIN screen. Unlock restored the overlay intact.
- "Continue in the background" FINISHES the activity (back to Payments > Internal). SR-12/21-after-ack.png
- Re-entering the screen: Continue button reads "Sending your transfer…", keypad dead (amount stays 0), "0.10 pending" badge. SR-12/22-reenter.png, 23, 24 -> screen NOT usable for a second transfer while Stalled.
- Network restored 12:01:05. 12:01:37 the transfer completed and the app navigated to More: **transparent 0.199 / shielded 0.795** (SR-12/r030.png). So Stalled was a soft advisory, not a brick.
- LEDGER after: transparent 0.199 / shielded 0.795

## SR-31 (12:11-12:27 CDT / 17:11-17:27 UTC) — transfer screen, fiat Max
- Currency toggle is the "USD"/"DASH" label at the RIGHT of the amount (1080x2400: tap 995,556). The chevron under the amount is NOT the toggle.
- Round-trip loss visible immediately: 0.05 DASH -> $2.9816 -> 0.04999932 DASH (-68 duffs).
- Fiat Max on Dash Wallet -> Shielded with transparent 0.19999737: shows $11.8751 / 0.19999663 DASH (6..74 duffs short of the balance).
- Confirm + PIN -> fails in ~8 s: **"This transfer was not sent / Nothing left your balance. Check the details and try again."** Balance unchanged. SR-31/w008.png
- wallet.log 17:23:16 `ShieldedBalanceServiceImpl - shielded shieldFromWallet rejected pre-broadcast (no lock tracked)` and `ShieldedTransferExecutor - shielded transfer not sent: pre-broadcast asset-lock coin-selection failure`
- CONTROL, same screen/balance, DASH-mode Max: SUCCEEDS in <8 s (transparent 0.19999737 -> 0.000008). SR-31/d008.png
- Root cause matches the SR: `ShieldedTransferViewModel.onConfirm` computes `isMaxSpend = state.amount == state.availableBalance`; in fiat mode the fiat->DASH round trip makes them unequal, so the executor never gets the max-spend hint and never runs the fee-adjust retry.
- LEDGER after: transparent 0.000008 / shielded ~0.995
- NEW (D-SRF-1): if the shielded runtime is momentarily not READY, Confirm + PIN is a SILENT NO-OP — `onConfirm()` returns early on `!canContinue` with no message, twice in a row at 17:15:16 and 17:17:39 (PIN verified in the log, nothing else happened, sheet stayed open). Evidence SR-31/07-stuck-sheet.png.

## SR-11 (12:37-12:43 CDT / 17:37-17:43 UTC) — username from the shielded pool
- More > Join DashPay > "Shielded balance" payment option > username `srfqa5566test9` (non-contested, 0.03).
- wallet.log: `17:40:34 RequestUserNameViewModel - routing username creation to the shielded-funded SDK path`,
  `17:40:42 SdkShieldedUsernameCreation - shielded-funded identity created at index 0 (8HeVCaGd…) — 0.03 denomination, contested=false`,
  `17:40:47 CreateIdentityService - SDK username creation broadcast — restore worker will advance the identity tile`
- Shielded balance 0.992 -> 0.962 (-0.03). Home History shows ONLY: Shielded -0.19999 (12:25), Unshielded +0.1 (12:00), Shielded -0.900003 (11:51), Received +1 (11:46). **No row for the 0.03 username fee.** SR-11/10-home-history.png, SR-11/12-more-after.png
- LEDGER after: transparent 0.000008 / shielded 0.962

## SR-14 (12:47-12:58 CDT / 17:47-17:58 UTC) — invite creation, network cut 3 s in
- More > Invitations only appears once the TRANSPARENT balance >= Constants.DASH_PAY_FEE (0.03); with everything
  shielded (0.962) and 0.000008 transparent the entry is HIDDEN (CreateInviteViewModel.combineLatestData uses
  walletData.observeTotalBalance()). Had to unshield 0.15 first. -> NEW defect D-SRF-2.
- Invitations > "Create a private invitation" > Non-contested (0.03) > Confirm and pay > PIN; wifi+data disabled at T+3 s.
- T+15 s "This could take about 30 seconds…"; **T+30 s terminal error**, NOT a forever spinner:
  "The Dash network rejected this invitation, so trying again will not help. Please try a different invitation type, or update the app if the problem continues."
- wallet.log: `17:52:40 SdkShieldedInviteCreation - shielded invite funding rejected pre-broadcast`
  `17:52:40 ConfirmInviteDialogFragment - invite creation failed: kind=REJECTED attempt=1 retryAllowed=false`
- Retry on the same dialog while offline: no-op. After restoring the network: still a no-op —
  `confirm_btn` is `enabled="false"` permanently. Only backing out of the flow lets you try again (which works).
- Funds NOT consumed (shielded stayed 0.810).

## SR-02 (12:58-13:07 CDT) — invite cancel/kill during the flow
- LEDGER before: transparent 0.150 / shielded 0.810
- run A kill at T+2 s -> shielded 0.810 (unchanged), no invite in history
- run B kill at T+4 s -> shielded 0.810 (unchanged), no invite in history
- run C kill at T+6 s -> shielded 0.810 -> **0.778** AND "Invitation 1, Sep 19 01:04 pm" IS in Invitations History with a
  working "Copy Invitation Link" -> the one-time key WAS persisted; no loss.
- The whole key-gen -> fund -> persist pipeline runs in < 6 s on this emulator, so the :359..:413 window is milliseconds.
- Total funds lost across the three kills: 0.

## SR-30 / SR-13 (13:37-14:07 CDT / 18:37.. UTC) — parked Send-to-address screen
- Screen has NO UI entry point; reached with
  `am start -n <pkg>/de.schildbach.wallet.ui.shielded.ShieldedBalanceActivity --ei screen 1 --ez LockScreenActivity.keep_unlocked true`
- It only accepts a SHIELDED address; a transparent y-address leaves Continue silently dead with no validation message.
- SR-30: Max = 0.77828183, Continue, Confirm, PIN -> fails. wallet.log:
  `18:08:48 ShieldedBalanceServiceImpl - shielded transferShielded rejected pre-broadcast (notes released)`
  `18:08:48 ShieldedSendViewModel - shielded send not sent: pre-broadcast shielded note-selection failure`
  caused by `DashSDKException: shielded transfer failed: Insufficient shielded balance: available 77828183400, required 77991034200`
  (fee 162850800 credits with no reserve). No fee-adjust retry, unlike the transfer screen.
- After that failure the SEND screen's balance sticks at 0 for the rest of the process (Max -> 0, any amount ->
  "Insufficient funds"); only a force-stop restores it.
- SR-13: 0.05 to my own shielded address, PIN at 13:15:06, BACK at T+3 s. Activity destroyed 18:15:06.
  * NO outcome anywhere afterwards: no success screen, no toast, no notification, and NO log line for the result.
  * The spend still went through: shielded 0.778 -> 0.776 (the 0.05 came back to my own address; the ~0.0016 fee was spent).
  * Re-entering the screen: fully Idle, address blank, amount 0, Continue live -> immediately re-submittable.

## FINAL LEDGER
transparent 0.150008 / shielded 0.776 (sum 0.926); 1.0 faucet - 0.03 username - 0.032 invite - ~0.012 fees. No unexplained loss.
