# S10 notes (exploratory/adversarial) — emulator-5554 (dw-qa1)
Build: fix-12.0.0-testnet3-release-signed.apk versionCode 12000000
Wallet: inherited from S1 — seed `[seed phrase redacted]`, PIN 1234, username qa1s13939

2026-09-19T01:37:42 start: logcat + memlog started
## 01:39 setup
- Inherited wallet unlocked (PIN 1234 via digit taps; `input text` does NOT work on the custom PIN pad).
- App resumed onto a leftover "Internal transfer" screen with toast "Shielded balance is syncing — transfers will be available shortly".
- Receive address: ydpETkGNb856diaqJoPiUptbVVPEpx5aVW ; username qa1s13939 shown on Receive tab.
- Transparent balance 0.00001225, shielded (initially) 0.00 while syncing.
- Faucet: ONE request made 01:39 -> txid e3c010b517e3c67ca0a510c6dec2cec2c0892a96d7cbb6114be2bfbb58781ced (1 tDASH)

## T1 interrupt tests (01:43-)
- Baseline after 1 tDASH faucet: transparent 1.00001225, shielded 0.95920521 (total 1.95921746)
- Clean shield 0.01 #1: asset-lock tx 1519f7e21eefc97448bad7293363221660c55d075c38c7e6fe0082c4a3897a70, net -1000263 duffs.
  After: transparent 0.99000962, shielded 0.9670767. Shielded only gained 0.00787149 for a 0.01 shield
  -> flat platform cost 0.00212851 (21% of the transfer) disclosed NOWHERE. Extends D-027/D-050.
- "Proving…" is never shown; the modal says "Sending your transfer… This could take about 30 seconds" with a Hide button.
  Actual duration ~5-7 s on this wallet, so the interrupt window is small.
- ROTATION INTERRUPT IS IMPOSSIBLE: 22 of 31 activities in wallet/AndroidManifest.xml are android:screenOrientation="portrait",
  including ShieldedBalanceActivity/SendCoinsActivity/ui.main.MainActivity. `settings put system user_rotation 1` leaves the
  window at ROTATION_0 (dumpsys window: mDisplayRotation=ROTATION_0, "port"). Shield 0.01 #2 completed normally through the attempt.
  After #2: transparent 0.98000699, shielded 0.974x
- T1b HOME during send: transfer completed in background, posted "Transfer completed / Your shielded balance is updated"
  notification, screen reusable on relaunch. T 0.98000699->0.97000436, S 0.97494818->0.98281967. PASS.
- T1c FORCE-STOP during send (01:52:26): asset-lock tx 5ae2c47b5137b925f75ff8d9cc24bb797f69909a59db7e3fd9e58a4443c8250f
  was ALREADY broadcast (block 1556595, type 8, 0.01 OP_RETURN lock, insight confirms). Transparent debited immediately
  0.97000436->0.96000173 but shielded stayed 0.98281967 for ~100 s. Recovery worked:
  06:54:05 "pending wallet-shield lock 5ae2c47b…:0 resumed and consumed" / 06:54:06 "1 pending wallet shield(s) completed
  in the background — announcing" -> shielded 0.99069116. NO FUND LOSS.
- BUT after that announcement the OPEN Internal-transfer screen regressed to showing "Shielded balance 0.00" +
  "Shielded balance is syncing — transfers will be available shortly" and stayed there >3 min (01:55:17-01:57:54)
  while More showed the correct 0.990. Closing and reopening the screen fixed it. => S10-D2.
- On relaunch after the kill the balance stream published 193100121 duffs (2x real) for 19 s with l1Synced=false
  (06:52:35 -> 06:52:54). Root cause visible in the log: WalletBalanceFacts total=192999384 confirmed=97000436
  unconfirmed=95998948 — the spent input is still counted confirmed while its change is counted unconfirmed.
  Same mechanism as D-041 but self-corrected here.
- T1d AIRPLANE MODE mid-send (01:59:31): after ~70 s the app showed a clear dialog
  "Transfer in progress / Your Dash was reserved on the network, but the shielded transfer hasn't finished yet.
   It will finish automatically the next time the app syncs — do not send it again." (08d). Good UX.
  Log: DashSDKException "shielded fund-from-asset-lock failed: Transaction broadcast outcome unknown ...
  SPV broadcast saw no acceptance signal before dash-spv's acceptance timeout"; then
  "wallet shield locked but pending — surfacing auto-retry state".
  Transparent still debited (0.96000173 -> 0.9499991). Net restored 02:01:16; at 02:05 shielded still 0.99069116 and
  07:02:08 "pending wallet-shield lock c5e87e95…:0 resume failed (attempt 1); the lock stays tracked and is retried later".
  => 0.01 in limbo; tracking whether it ever lands.
- T1d resolution: the pending shield c5e87e95… resumed after the NEXT app relaunch (07:06:37 "resumed and consumed"),
  not while the app stayed running with the network back on (~5 min of retries failed). Shielded finally 0.99856265.
- T1e UNSHIELD 0.01 + force-stop at the same point: log 07:06:26 "shielded withdrawToCore outcome unconfirmed — it MAY be
  on chain and the spent notes stay reserved; do NOT retry (the next shielded sync reconciles)" then
  "shielded transfer ambiguous — surfacing terminal state". After relaunch: T=0.9499991 S=0.99856265 — the unshield did
  NOT happen and nothing stayed reserved. No loss.
- ACCOUNTING CHECK after 5 shields + 1 killed unshield:
  expected 1.95921746 - 5*0.00213114 = 1.94856176 ; actual 0.9499991 + 0.99856265 = 1.94856175 (1 duff rounding). NO FUNDS LOST.

## T1f plain-send interrupts
- PIN step: HOME -> Authenticate dialog restored intact on return. KILL -> state discarded, balance unchanged. No loss.
- Confirm step (PIN comes BEFORE the confirm sheet on the send flow): HOME -> confirm sheet restored intact.
  KILL -> discarded, balance unchanged.
- Confirm + kill 0.5 s later -> tx DID broadcast (0.94999910 -> 0.94899647), exactly ONE "Sent -0.001002" row. No duplicate.
- Send confirm sheet says "Network fee 0.0001"; actual on-chain fee 226-263 duffs (0.00000226-0.00000263) = ~38-44x
  overstated. Confirms SR-28 / D-032 on device.
- Post-send tx detail shows Tax Category "Income" for an outgoing send -> confirms D-048.

## T2 double-submit
- Send: triple tap on Confirm (3 taps in one `input tap` batch) -> exactly ONE tx both times
  (ebb22b2d…, 0.94999910->0.94899647 ; and 0.93799195->0.93698969). PASS.
- Shield: triple tap on Confirm -> ONE extra "Authenticate" dialog was queued and appeared after the first PIN,
  but it self-dismissed and only ONE asset-lock (3bb741567cb9…, -1000263 duffs) was created.
  T 0.94799458->0.93799195, S 0.99856265->1.00643414. PASS (no double spend).
- S4: the More screen balance cards TRUNCATE to 3 decimals instead of rounding: 0.93799195 renders "0.937 Đ",
  0.99069116 renders "0.990 Đ", 0.97494818 renders "0.974 Đ".

## T3 amount edge cases (send screen)
- 0                -> Send button disabled. PASS
- dust 0.00000001  -> ACCEPTED, broadcast. tx e6b8a5ccb5c8471e5a35d2d2a134033f45b5a9688fea7ecf3df306c8825b97f7,
                      vout[0] = 0.00000001 to yPryn…, fee 226 duffs. No dust warning/guard at all. => S10-D4
- 5 (> balance)    -> "Insufficient funds" in red, Send disabled. PASS
- exactly balance (typed 0.93697517) -> field SILENTLY clamped to 0.93688742, no message. Confirms D-032.
- 9 decimals 0.123456789 -> truncated to 0.12345678. PASS
- second "."       -> ignored (0.12). PASS
- fiat mode: $1.23 -> 0.020233 DASH on switching back. PASS
- "paste amount with currency symbol": INAPPLICABLE — the amount field is not an EditText, only a custom numeric
  keypad, so nothing can be pasted into it.
- de-DE (per-app locale): keypad decimal key becomes ",", entry shows "0,001", fiat "0,00 $". BUT:
  * confirm sheet mixes separators: amount "0.0010", "Netzwerk-Gebühr 0.0001", "Gesamt 0.0011" (dots)
    next to "0,06 $" (comma) in the SAME dialog.
  * tx detail: "-0.00100226" and "$  0.06" (US format, symbol first).
  * home header: "0.935985" and "$ 56.84" (US format).
  => three different number formats for one locale. S10-D5.
- de-DE i18n gaps in the new shielded UI: the payments sheet tab label "Internal" and the whole
  "Internal transfer" screen title stay English while the neighbouring tabs are "Empfangen"/"Senden". (T3/20)

## T4 address / URI edge cases
- mainnet X… address: Continue is enabled, then rejected on tap with "Not a valid DASH Address or URL request". PASS
- Platform username `qa5s5ebkdus2c6kkt9m7t` (an actual contact of this wallet) in "Send to Address":
  same generic "Not a valid DASH Address or URL request" — no username resolution, no hint to use "Send to a Contact". S4
- leading/trailing whitespace: trimmed and accepted. PASS
- BIP21 `?amount=0.001&label=QA%20Label%20S10&message=Hello%20from%20S10`:
  address + amount prefilled, label and message DROPPED — shown nowhere on the amount screen, the confirm sheet
  or the resulting tx detail (no note). => S10-D6
- BIP21 `?amount=50` (> balance): Send disabled but NO "Insufficient funds" text (typing 5 manually DOES show it). S4
- `&IS=1` and `&req-IS=1`: both parsed, amount prefilled, no InstantSend affordance anywhere.
  `&req-somethingunknown=xyz` also silently accepted — BIP21 says an unknown `req-` param MUST make the wallet
  reject the URI. => S10-D7 (spec violation)
- `?amount=-1`: "Invalid Dash URI:\ndash:…?amount=-1" dialog. PASS
- QR scan: opens ScanActivity, BACK cancels cleanly back to home. PASS
- Address book: opens on the empty SENDING ADDRESSES tab (D-030). Entries can only be created via overflow
  "Paste from clipboard" / "Scan address" — no manual entry. Add / edit / delete a label all work
  (T4/25..35), BUT the label appears ONLY inside the address book: not in the send flow (still the raw address)
  and not on the tx rows (still "Sent"). => S10-D8
- **S10-D9 (i18n, cached strings)**: the tx-list row created while the app was in de-DE still reads "Gesendet"
  after switching back to en-US, next to rows that read "Sent"; the tx DETAIL for the same tx renders "Amount Sent"
  in English. The list row's direction label is baked into the display cache at insert time instead of being
  resolved at render time. Evidence: T4/28-txlist-with-label.png (row 2:30 AM) vs T4/29-gesendet-txdetail.png.
- Send confirm sheet "Network fee 0.0001" vs the SAME tx's detail sheet "Network fee 0.00000226" — the two screens
  in one flow contradict each other by 44x. Confirms SR-28/D-032.

## T5 accessibility (font_scale 2.0 + wm density 560) and dark mode
LARGE FONT / HIGH DENSITY (T5/01..10):
- Home: shortcut labels wrap ("Rec/eive", "Sca/n QR"); the shortcut card grows and OVERLAPS the
  "Customize shortcut bar" banner whose title is clipped; the banner text is cut mid-sentence
  ("...the function you"). (T5/01)
- Transaction rows: the direction label truncates to "S…" or just "…" for every row — Sent / Received /
  Shielded become indistinguishable. The amount column keeps full width. (T5/02) => S10-D10
- Tx detail sheet: label/value pairs are drawn ON TOP of each other — "Network fee" over "0.00000226",
  "Date" over "September 19 at 2:34 AM", "Tax Category" over "Expense", "Private N…" over "Add Note";
  the amount "-0.00100226" is clipped by the direction icon. (T5/03) => S10-D10
- Internal transfer (shielded): the ENTIRE From/To card block disappears — no balances, no direction-swap
  control, so the user cannot tell whether they are shielding or unshielding. "Max" truncates to "Ma",
  "Continue" is clipped. (T5/07) => S10-D11 (functional loss on a money screen)
- More: "Shielde/d" wraps and the shielded balance truncates to "1.00…" — the value is unreadable. (T5/09)
- Settings: reflows cleanly, no overlap. PASS (T5/10)
DARK MODE (cmd uimode night yes):
- Home, tx detail, payments sheet, Send address, Send amount, More, Settings all render correct dark themes.
- **The shielded "Internal transfer" screen ignores dark mode entirely** — pure white background with black
  text while every other screen is dark. (T5/23 vs T5/25) => S10-D12
- Minor: the "Shielded" row icon in the tx list keeps its light-blue circle on the dark list. (T5/20)

## T7 background sync with screen off (02:51:48 lock -> 02:57:17 unlock, 5m29s)
- L1 engine kept running and advancing the whole time: 07:52:23 synced_height_persisted=Some(1556624),
  07:55:45 phase=SYNCED 1556625, 07:57:06 phase=SYNCED 1556626.
- NO "idling detected, stopping service" in this launch at all (the only occurrences in wallet.log are
  06:01:00 / 06:35:00 / 06:55:00 from earlier sessions). No engine teardown, no service onDestroy.
- Memory flat across the window: 389 MB PSS / 246 MB native at t=2min, 388 MB / 245 MB at t=5min.
- Send immediately after unlock (02:57:43) succeeded first try — D-031 NOT reproduced on this path.

## T8 deep links with the app killed
- `dash:<own addr>?amount=0.001` on a force-stopped app: goes STRAIGHT to the pre-filled Send screen with
  NO lock screen, while a plain launcher start of the same force-stopped app DOES show "Enter PIN"
  (T8/04 vs T8/05). BACK from there exits to the launcher — the unlocked wallet is NOT exposed.
  Spending IS still PIN-gated: tapping Send, the balance eye-reveal and "Max" all raise "Authenticate".
  => S10-D13 (S4: inconsistent lock-screen policy, no data leak found)
- `dashpay://invite?…` (S5's already-claimed invite) on a force-stopped app: PIN screen FIRST, then after
  unlock it lands silently on Home. No hang — but also NO message. wallet.log shows the app knows exactly
  why: `InvitationLinkData(… validationState=ALREADY_HAS_IDENTITY …)` at 08:01:19 and then
  "activity InviteHandlerActivity destroyed" one line later. The user gets no feedback at all.
  => S10-D14 (S3)
- Note: `adb shell am start -d '<url>'` must be run as `adb shell "am start … -d '<url>'"`; quoting only on
  the host side lets the device shell split the URL on `&` (the invite link silently lost its last two params).

## T9 process death (`am kill` + reopen from recents)
- Send screen with a typed amount: address AND amount (0.0777) restored exactly, no crash. PASS (T9/05)
  (NB: the send-amount keypad reuses the SAME resource ids btn_1..btn_9 as the lock-screen PIN pad, which
   made my first attempt look like a PIN leak — it was a harness artifact, not an app bug.)
- Tx detail bottom sheet: NOT restored, app returns to Home. No crash. (T9/07) — acceptable
- Edit Profile with a typed Display Name: screen AND the typed text "S10 ProcDeath" restored. PASS (T9/10)
  Minor: the "13/25 characters" counter under Display Name is not re-rendered after restore.
- The username-REQUEST screen is unreachable on this wallet (it already owns qa1s13939), so Edit Profile
  was used as the closest analogue.
- exit-info confirms reason=10 (USER REQUESTED) subreason=24 (KILL BACKGROUND) for each probe.

## T8 addendum
- The invite "already used" error IS eventually shown: dialog "Username already found / You cannot claim this
  invite since you already have a Dash username" appeared at 03:12:26 — 11 min 31 s after the deep link was
  fired at 03:00:55, while the user was on an unrelated screen. Evidence T8/11-invite-error-delayed.png.
  So S10-D14 is "correct message, wrong time": detached from the user's action by ~11 min.

## T6 baseline before reset (03:12)
- transparent 0.933981, shielded 1.00643414
- username qa1s13939, display name "S10 QA Profile", about me "S10 exploratory QA bio" (broadcast to Platform 08:11:41)
- contacts: "QA Stream Five" (qa5s5ebkdus2c6kkt9m7t) with avatar
- tx row "QA Stream Five  − 0.001007  1:08 AM" with the contact avatar (T6/06)

## T6 reset ("Save data") + restore  — 03:14:01 reset, 03:15 restore start, 03:18:10 SYNCED (~3 min)
- "Save data and reset wallet" wiped the wallet in ~5 s with NO PIN prompt at any step (re-confirms D-012).
- Contra D-013: this time the metadata publish worked — 08:14:06 "publish txmetadata successful:
  TxMetadataSaveInfo(itemsSaved=16, itemsToSave=16)" (S1 saw itemsSaved=0).
- Wipe log is clean: "L1 shadow hard reset: deleted SPV dataDir … (134 files)", "binder state reset", "databases cleared".
- AFTER RESTORE — PASS on: transparent 0.933981 (==), shielded 1.00643414 (==), username qa1s13939,
  display name "S10 QA Profile", about me "S10 exploratory QA bio" (T6/17, T6/18), contact list still shows
  "QA Stream Five" (T6/19), and the contact payment row still carries the contact name + avatar (T6/22).
- **FAIL 1 — a transaction disappeared from the history.** dash-sdk.db `transactions` = 22 rows, but
  `tx_display_cache` = 21 rows, and TxDisplayCacheService still logs
  "Sync complete … SDK=8 records | display=21 rows — cache is complete".
  The one SDK tx with no display row is 31546c95e66cbdc787f36a3993f8480d54dddfc594bc59cd8afd3560a4e6cde2 —
  insight: type 9 (asset unlock), block 1556579, valueOut 0.95235766 — i.e. exactly the
  "Unshielded + 0.952358  1:13 AM" row that was visible before the reset (T6/06) and is absent after (T6/22).
  A +0.95 tDASH credit is now invisible in the history. Balance is unaffected. => S10-D1 (S2)
- **FAIL 2 — the contact payment amount changed.** Before: "QA Stream Five − 0.001007  1:08 AM  $0.06" (T6/06).
  After: "QA Stream Five − 0.000007  1:10 AM  $0.00" (T6/22); tx_display_cache row
  0499bd57a5d4853b32715f677893ce65783be7b651de02e59eecaf29e3a9aa69 = valueSatoshis -737 (was -100737).
  Insight: the tx pays 0.001 to ygeMkM3f9y2PJARzYn6HFojijvSMQTELFf, which is the FIRST address of the
  contact's DIP-15 "sending" chain (see ContactDerivationFacts sending=[ygeMkM3f9y2PJARzYn6HFojijvSMQTELFf,…]).
  After the restore the wallet watches that chain as its own, so the 0.001 output is treated as change and the
  row reports only the fee. A 0.001 payment to a contact now looks free. => S10-D3 (S2)
- Cosmetic: row times shift again after restore (1:48->1:51, 1:25->1:35, 1:05->1:10, 1:08->1:10 — D-018/D-044),
  and the "Unshielded +0.01 / S1 memo test" row's icon changes from the blue internal-transfer glyph to the
  green Received glyph.
- Auto-logout reverted to the 1-minute default after the wipe (expected — settings are wiped too).

## T6 ar-EG RTL (03:26-03:30) then back to en-US
- Layout mirrors correctly (nav bar, headers, list alignment).
- MIRRORED NUMERIC KEYPAD on BOTH money screens: 3-2-1 / 6-5-4 / 9-8-7 / backspace-0-separator
  (T6/35 shielded, T6/36 send). Numeric keypads must stay LTR.
- Shielded "Internal transfer" screen is 100% untranslated (title, From/To, Dash Wallet, Shielded balance, Max).
- Home: "Spend" shortcut and the whole "Customize shortcut bar" banner stay English (T6/30).
- Contacts: "Contacts", "Search for a contact", "My Contacts", "Sort by:" stay English (T6/37).
- Tx detail: the ">" disclosure chevron is drawn ON TOP of the last character of
  "عرض في بلوك إكسبلورر"; "Private Note"/"Add Note" stay English; the amount renders "Ð0.00100226-"
  with a trailing minus (T6/31).
- Send screen mixes numeral systems: DASH "0" (Western) and fiat "٠,٠٠ US$" (Eastern Arabic) (T6/36).
- Receive address after restore is yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52 (was ydpETkGNb856diaqJoPiUptbVVPEpx5aVW
  before the reset) — the restored wallet does hand out a different index.

## 03:35 teardown
- locale en-US, font_scale 1.0, wm density reset, night mode no, user_rotation 0 — all restored.
- logcat + memlog stopped; wallet.log pulled to logs/files/log/wallet.log; exitinfo.txt, oom.txt, watchlist.txt saved.
- Peak TOTAL PSS 500016 KB (488 MB), native heap 323348 KB (316 MB), Dalvik 43004 KB (42 MB).
- 0 app crashes / ANRs / LMK. The single FATAL in logcat.txt (03:16:55) is the uiautomator harness (ENV-3).
- REPORT.md written.
