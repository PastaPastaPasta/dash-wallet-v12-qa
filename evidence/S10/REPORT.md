# QA report: S10 — exploratory / adversarial (agent: S10, emulator-5554 / dw-qa1, 2026-09-19 01:37–03:35 CDT)

Build under test: `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29, targetSdk 35.
Wallet: inherited from S1 — seed `[seed phrase redacted]`, PIN 1234, username `qa1s13939`, identity `DYjxDk3kTzf2PXAK3LfGj2cWitnyLKhx1y8u3626hbMm`.
Funding: ONE faucet request at 01:39 → 1 tDASH, txid `e3c010b517e3c67ca0a510c6dec2cec2c0892a96d7cbb6114be2bfbb58781ced`.

Evidence root: `/Users/dcg/workspace/dash-wallet-qa/evidence/S10/`
(`notes.md`, `logcat.txt`, `mem.csv`, `logs/`, `T1/`…`T9/`; videos `T1/s10-t1a-shield-rotate.mp4`, `T1/s10-t1-interrupts.mp4`, `T1/s10-t1f-t2-send.mp4`, `T2` covered by the same clip, `T6/s10-t6-reset.mp4`, `T8/s10-t8-deeplink.mp4`)

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| T1a rotate mid-shield | N/A (inapplicable) | `T1/04b-rotate-2s.png`, `wt-fix/wallet/AndroidManifest.xml` | 22 of 31 activities are `screenOrientation="portrait"`; the window stays ROTATION_0, so a rotation interrupt cannot be produced on any money screen |
| T1b HOME mid-shield | PASS | `T1/06a..06d` | Transfer completes in background, posts "Transfer completed", screen reusable |
| T1c force-stop mid-shield | PASS (with S10-D2) | `T1/07a..07h`, insight `5ae2c47b…` | Asset lock already broadcast; recovered by "pending wallet-shield lock … resumed and consumed"; no loss. But the open transfer screen then shows shielded **0.00** for >3 min |
| T1d airplane mode mid-shield | PASS | `T1/08a..08f`, insight `c5e87e95…` | Clear "Transfer in progress … do not send it again" dialog; resumed on the NEXT app launch (5 min of in-process retries failed) |
| T1e force-stop mid-unshield | PASS | `T1/09c..09e` | "withdrawToCore outcome unconfirmed … do NOT retry"; nothing reserved, nothing lost |
| T1f send interrupts (PIN / confirm / post-confirm) | PASS | `T1/12a..14c` | State restored on HOME, discarded on kill, exactly one tx when killed 0.5 s after Confirm |
| T2 double-submit (send x2, shield x1) | PASS | `T2/01..11`, `T1/s10-t1f-t2-send.mp4` | Triple-tap Confirm produces exactly ONE tx every time |
| T3 amount edge cases | PASS w/ defects | `T3/01..20` | 0 blocked, >balance blocked, 9 dp truncated; **dust 1 duff accepted (S10-D4)**, exact-balance silently clamped (D-032), de-DE mixed separators (S10-D5) |
| T4 address / URI edge cases | PASS w/ defects | `T4/01..35` | mainnet + username rejected, whitespace trimmed, negative amount rejected; **BIP21 label/message dropped (S10-D6)**, unknown `req-` ignored (S10-D7), address-book label invisible outside the book (S10-D8) |
| T5 large font + high density | **FAIL** | `T5/01..10` | Tx rows truncate to "S…", tx-detail labels overlap values, shielded screen loses its whole From/To card (S10-D10, S10-D11) |
| T5 dark mode | FAIL (1 screen) | `T5/20..27` | Everything dark except the shielded Internal-transfer screen, which stays fully light (S10-D12) |
| T6 reset("Save data") + restore | **FAIL** | `T6/01..22`, `T6/txlist-after-restore.txt` | Balances / username / profile / contacts / contact-name row all come back, but a +0.95 tDASH unshield row vanishes (S10-D1) and the contact payment amount changes (S10-D3) |
| T6 ar-EG RTL | FAIL | `T6/30..37` | Money keypads are mirrored 3-2-1 (S10-D15); most of the shielded UI + several core strings untranslated; chevron overlaps its label |
| T7 5-min screen-off sync | PASS | `notes.md` §T7, `logs/files/log/wallet.log` | Engine kept advancing 1556624→1556626, no `idling detected`, no teardown, send worked immediately after unlock (D-031 not reproduced) |
| T8 deep links with app killed | PASS w/ defects | `T8/01..11`, `T8/s10-t8-deeplink.mp4` | `dash:` skips the app lock screen (S10-D13, spending still PIN-gated); invite gives the right message ~11.5 min late (S10-D14) |
| T9 process-death restoration | PASS | `T9/05`, `T9/10` | Send screen restores address+amount, Edit Profile restores typed text; bottom sheets are dismissed; no crash |

Zero app crashes, zero ANRs, zero LMK/OOM across the session (the single `FATAL EXCEPTION` in `logcat.txt` at 03:16:55 is the uiautomator harness, ENV-3).
Peak memory over 1 h 58 m: **TOTAL PSS 488 MB**, native heap 316 MB, Dalvik 42 MB (`mem.csv`). `logs/exitinfo.txt` shows only USER_REQUESTED force-stops/kill-backgrounds that I issued.

## Money accounting (no funds lost anywhere)

Start (01:43): transparent 1.00001225 + shielded 0.95920521 = **1.95921746**.
6 x shield 0.01 (each costs exactly 0.00213114 = 263-duff L1 fee + 0.00212851 platform), 1 killed unshield (no-op):
expected 1.95921746 − 5×0.00213114 = 1.94856176 ; measured 0.9499991 + 0.99856265 = **1.94856175** (1 duff rounding).
Re-verified after every send and across the reset+restore (0.933981 + 1.00643414 identical before and after).

## Per-test detail (condensed; full timestamped journal in `notes.md`)

### T1 — interrupting money flows
1. `Proving…` is never shown; the modal reads "Sending your transfer… This could take about 30 seconds" with a Hide button. Actual duration was 5–7 s on this wallet, so the interrupt window is small.
2. Rotation: `settings put system user_rotation 1` had no effect on any money screen — `dumpsys window` kept `mDisplayRotation=ROTATION_0 … port`. Manifest audit: 22/31 activities are `android:screenOrientation="portrait"` including `ShieldedBalanceActivity`, `SendCoinsActivity`, `ui.main.MainActivity`, `LockScreenActivity`.
3. HOME mid-shield: completed in background, notification "Transfer completed / Your shielded balance is updated" (dumpsys notification), screen reusable. T 0.98000699→0.97000436, S 0.97494818→0.98281967.
4. Force-stop mid-shield (01:52:26): the asset lock `5ae2c47b5137b925f75ff8d9cc24bb797f69909a59db7e3fd9e58a4443c8250f` was already on chain (insight: type 8, block 1556595). Transparent debited at once, shielded lagged ~100 s, then `06:54:05 ShieldedBalanceServiceImpl - pending wallet-shield lock 5ae2c47b…:0 resumed and consumed` / `06:54:06 ShieldedTransferExecutor - 1 pending wallet shield(s) completed in the background — announcing`. No loss.
5. Airplane mode mid-shield (01:59:31): `DashSDKException: shielded fund-from-asset-lock failed: Transaction broadcast outcome unknown — it may already be on the network; its inputs stay unspendable until this wallet observes them spent: SPV broadcast saw no acceptance signal before dash-spv's acceptance timeout`, then a good user-facing dialog. Network restored 02:01:16; `07:02:08 … resume failed (attempt 1); the lock stays tracked and is retried later`; it only landed after the next app launch — `07:06:37 … resumed and consumed`. Asset lock `c5e87e95…` insight: type 8, block 1556596.
6. Force-stop mid-unshield: `07:06:26 shielded withdrawToCore outcome unconfirmed — it MAY be on chain and the spent notes stay reserved; do NOT retry (the next shielded sync reconciles)` then "shielded transfer ambiguous — surfacing terminal state". Balances unchanged, nothing reserved.
7. Plain send: the PIN step comes BEFORE the confirm sheet. HOME at either step restores the exact dialog; kill at either step discards cleanly; Confirm followed by a kill 0.5 s later still broadcasts exactly once (0.94999910 → 0.94899647, one "Sent −0.001002" row).

### T2 — double submit
Three `input tap` events in a single shell invocation on the Confirm control produced exactly one transaction on both send attempts (`ebb22b2d…`, and 0.93799195→0.93698969) and on the shield (`3bb741567cb9…`, −1000263 duffs). On the shield, one extra "Authenticate" dialog was queued and appeared after the first PIN, but it self-dismissed and produced no second transfer.

### T3 — amount edge cases (send screen)
0 → Send disabled. 0.00000001 → **accepted and broadcast** (S10-D4). 5 (>balance) → red "Insufficient funds", Send disabled. Typed 0.93697517 (= balance) → silently clamped to 0.93688742. 0.123456789 → truncated to 0.12345678. Second "." ignored. Fiat $1.23 → 0.020233 DASH on switching back. de-DE keypad shows "," and accepts "0,001". "Paste an amount with a currency symbol" is not expressible: the amount field is not an `EditText`.

### T4 — address / URI edge cases
Mainnet `Xm77DBJ…` and the Platform username `qa5s5ebkdus2c6kkt9m7t` are both rejected with the same generic "Not a valid DASH Address or URL request". Whitespace is trimmed. `?amount=-1` → "Invalid Dash URI" dialog. `?amount=50` → Send disabled but no "Insufficient funds" text (the typed path does show it). QR scan cancels cleanly with BACK. Address-book add/edit/delete work.

### T5 — accessibility and dark mode
`font_scale 2.0` + `wm density 560`: home shortcut card overlaps and clips the banner; every tx row's direction label truncates to "S…"/"…"; the tx-detail sheet draws labels on top of values; the shielded transfer screen loses its From/To card and swap control. Settings reflows cleanly.
`cmd uimode night yes`: correct on home, tx detail, payments sheet, send address, send amount, More and Settings; the shielded Internal-transfer screen renders a pure light theme.

### T6 — reset ("Save data") + restore + ar-EG
Reset at 03:14:01 (no PIN prompt, ~5 s), restore started 03:15, `L1Shadow phase=SYNCED` 03:18:10 (~3 min). `publish txmetadata successful: TxMetadataSaveInfo(itemsSaved=16, itemsToSave=16)`.
MATCH after restore: transparent 0.933981, shielded 1.00643414, username `qa1s13939`, display name "S10 QA Profile", about me "S10 exploratory QA bio", contact "QA Stream Five" present, contact payment row still carries the contact name and avatar.
MISMATCH after restore: one transaction lost from the history (S10-D1) and the contact payment amount changed (S10-D3). Ground truth taken from `dash-sdk.db` and `dash-wallet-database` via `sqlite3` on the device.

### T7 — screen off for 5 min 29 s
`07:52:23 synced_height_persisted=Some(1556624)` → `07:55:45 phase=SYNCED 1556625` → `07:57:06 phase=SYNCED 1556626`. No `idling detected` in that launch. Memory flat (389 MB → 388 MB PSS). A send at 02:57:43, seconds after unlock, succeeded first try.

### T9 — process death
`am kill` + reopen from recents: the Send screen restored both the recipient and the typed 0.0777; Edit Profile restored the typed Display Name; bottom sheets (tx detail, avatar picker) are dismissed. `exit-info` reports reason=10 subreason=24 (KILL BACKGROUND) for each probe. No crash in any case.

## Defects found

| ID | Sev | Title | Repro | Evidence | Suspected area |
|---|---|---|---|---|---|
| S10-D1 | **S2** | Reset+restore loses a transaction from the history: a type-9 asset-unlock (unshield) of **+0.95235766** has no display row | Wallet with an unshield in history → More › Security › Reset Wallet › "Save data and reset wallet" → restore from seed → wait for SYNCED → scroll history | `T6/06-txlist-contact-row-before.png` (row "Unshielded + 0.952358 1:13 AM") vs `T6/22-txlist-bottom-after.png` (absent). `dash-sdk.db transactions`=22, `tx_display_cache`=21; the only missing txid is `31546c95e66cbdc787f36a3993f8480d54dddfc594bc59cd8afd3560a4e6cde2` (insight: type 9, block 1556579, valueOut 0.95235766). wallet.log 08:17:30 still says "Sync complete … SDK=8 records \| display=21 rows — cache is complete" | `TxDisplayCacheService` completeness check (D-037 family); asset-unlock (type 9) wrapping |
| S10-D2 | S3 | After a background-resumed shield, the open Internal-transfer screen falls back to "Shielded balance 0.00" + "Shielded balance is syncing — transfers will be available shortly" for minutes while More shows the correct balance | Shield 0.01 → force-stop mid-send → relaunch → open Internal transfer → wait for "pending wallet-shield lock … resumed and consumed" | correct 0.99069116 at 01:54:45, then **0.00** from 01:55:17 to 01:57:54 (`T1/07e`, `T1/07f`); More simultaneously 0.990 (`T1/07g`); reopening the screen restores 0.99069116 (`T1/07h`) | `ShieldedBalanceServiceImpl` / transfer-screen VM resets to a pre-sync state on the completion announcement |
| S10-D3 | **S2** | After reset+restore a payment to a DashPay contact reports only the network fee — a 0.001 payment renders as −0.000007 | Pay a contact 0.001 → reset ("Save data") → restore → look at the contact row | before −0.001007 / $0.06 (`T6/06`), after −0.000007 / $0.00 (`T6/22`); `tx_display_cache` row `0499bd57a5d4853b32715f677893ce65783be7b651de02e59eecaf29e3a9aa69` valueSatoshis **−737** (was −100737). Insight: pays 0.001 to `ygeMkM3f9y2PJARzYn6HFojijvSMQTELFf`, the first address of the contact's DIP-15 *sending* chain (wallet.log `ContactDerivationFacts … sending=[ygeMkM3f9y2PJARzYn6HFojijvSMQTELFf,…]`) | DIP-15 friend-chain addresses entering the wallet's own watched set, so contact payments look like change |
| S10-D4 | S4 | No dust guard on send: a 1-duff (0.00000001) payment is accepted, broadcast and confirmed, costing 226 duffs in fee | Send screen → amount 0.00000001 → Send → PIN → Confirm | `T3/02-dust.png` (Send enabled), `T3/05-dust-result.png`; tx `e6b8a5ccb5c8471e5a35d2d2a134033f45b5a9688fea7ecf3df306c8825b97f7`, vout[0]=0.00000001, confirmed block 1556607 | send amount validation (no dust threshold) |
| S10-D5 | S4 (i18n) | Three different number formats inside one locale | `qa-app.sh locale de-DE`, send 0,001 | entry "0,001" (`T3/16`), confirm sheet "0.0010 / 0.0001 / 0.0011" next to "0,06 $" (`T3/17`), tx detail "-0.00100226" and "$  0.06" (`T3/18`), home "0.935985" "$ 56.84" (`T3/19`) | money formatting shims in `common/` |
| S10-D6 | S3 | BIP21 `label` and `message` are silently dropped | `adb shell "am start -a VIEW -d 'dash:y…?amount=0.001&label=QA%20Label%20S10&message=Hello%20from%20S10'"` | `T4/07` (amount screen), `T4/08` (confirm), `T4/09` + `T4/10` (tx detail, no note) | BIP21 parser / send intent plumbing |
| S10-D7 | S4 (spec) | Unknown `req-` BIP21 parameters are silently ignored instead of invalidating the URI | `dash:y…?amount=0.001&req-somethingunknown=xyz` | `T4/14`; `&req-IS=1` also accepted with no InstantSend affordance (`T4/13`) | BIP21 parser |
| S10-D8 | S4 | An address-book label is write-only — it never appears in the send flow or on tx rows | Tools › Address book › ⋮ Paste from clipboard → label "S10 Faucet Return" → ADD; then open the send flow / history for that address | `T4/27` (stored), `T4/28` (rows still say "Sent"), `T4/30` (send shows the raw address); add/edit/delete work (`T4/33`–`T4/35`) | address-book lookup missing in `TxDisplayCacheService` and the send composer |
| S10-D9 | S3 (i18n) | Tx-list row titles are frozen in the locale that was active when the row was inserted | Send in de-DE, switch back to en-US, look at the history | `T4/28` shows "Gesendet" (2:30 AM) among "Sent" rows; the detail sheet for the same tx renders "Amount Sent" in English (`T4/29`). Under ar-EG every pre-existing row keeps its English title (`T6/30`) | `tx_display_cache.title` stores a localized string instead of a type code |
| S10-D10 | S3 (a11y) | At `font_scale 2.0` + `wm density 560` the history is unreadable and the tx detail overlaps | `adb shell settings put system font_scale 2.0; adb shell wm density 560` | `T5/02`: every row's direction label truncates to "S…"/"…". `T5/03`: "Network fee" drawn over "0.00000226", "Date" over the date, "Tax Category" over "Expense", amount clipped by the direction icon. `T5/01`: home banner title clipped, body cut mid-sentence | fixed-width label columns in the tx row + detail sheet |
| S10-D11 | S3 (a11y) | At large font the shielded Internal-transfer screen loses its entire From/To card, including the direction-swap control | same settings → Payments › Internal › Shielded balance | `T5/07`: no balances, no swap arrows — the user cannot tell shield from unshield; "Max" truncates to "Ma", "Continue" clipped | `ui/shielded/*` layout |
| S10-D12 | S3 | The shielded Internal-transfer screen ignores dark mode | `adb shell cmd uimode night yes`, open Payments › Internal › Shielded balance | `T5/23` (fully light) vs `T5/25` (Send amount screen, correctly dark) and `T5/20`, `T5/26`, `T5/27` | `ui/shielded/*` hard-coded light colors |
| S10-D13 | S4 (security hygiene) | A `dash:` deep link on a force-stopped app opens the Send composer with no app lock screen, while a normal launcher start of the same force-stopped app demands the PIN | `qa-app.sh kill` then `adb shell "am start -a VIEW -d 'dash:y…?amount=0.001'"` | `T8/04` (launcher → "Enter PIN") vs `T8/05` (deep link → Send screen). Mitigated: Send, the balance eye-reveal and Max all raise "Authenticate" (`T8/06`–`T8/08`); BACK exits to the launcher, the wallet is not exposed (`T8/02`) | `WalletUriHandlerActivity` lock-screen gating |
| S10-D14 | S3 | The "invite already used" error is correct but arrives ~11.5 minutes late, detached from the user's action | Force-stop the app, open an already-claimed `dashpay://invite?…` link, unlock | deep link fired 03:00:55, app landed silently on Home (`T8/10`) although wallet.log already had `InvitationLinkData(… validationState=ALREADY_HAS_IDENTITY …)` at 08:01:19 followed immediately by "activity InviteHandlerActivity destroyed"; the dialog "Username already found / You cannot claim this invite since you already have a Dash username" only appeared at 03:12:26 (`T8/11`) | `InviteHandlerActivity` finishes before it can present its own result |
| S10-D15 | S3 (RTL) | Under `ar-EG` both money keypads are mirrored (3-2-1 / 6-5-4 / 9-8-7), the tx-detail disclosure chevron overlaps its label, and the whole shielded UI plus several core strings stay English | `qa-app.sh locale ar-EG`, relaunch | `T6/35` (shielded keypad mirrored, screen 100 % English), `T6/36` (send keypad mirrored; fiat in Eastern-Arabic numerals "٠,٠٠ US$" next to Western "0" DASH), `T6/31` (">" drawn on top of "…إكسبلورر"; "Private Note"/"Add Note" English), `T6/30` ("Spend", "Customize shortcut bar" English), `T6/37` ("Contacts", "My Contacts", "Sort by:" English) | keypad needs `layoutDirection="ltr"`; missing `values-ar` strings for `ui/shielded/*` |
| S10-D16 | S4 | The More-screen balance cards truncate instead of rounding | Any balance with a non-zero 4th decimal | 0.93799195 → "0.937 Đ", 0.99069116 → "0.990 Đ", 0.97494818 → "0.974 Đ" (`T2/08`, `T1/07g`) | More-screen balance formatter |
| S10-D17 | S3 | A shield costs a flat 0.00212851 platform fee disclosed nowhere, so small shields lose a large fraction | Shield exactly 0.01 and compare the shielded balance before/after | 0.95920521 → 0.9670767 = **+0.00787149** for a 0.01 shield (21 % lost); the confirm sheet shows "Total 0.01 Đ" and no fee line; the tx row shows only the 263-duff L1 fee. Reproduced identically 6 times | quantified extension of D-027 / D-050; `ShieldedTransferExecutor` cost disclosure |

## Re-observations of known ledger items (confirmed again on device)

- **D-012** — "Save data and reset wallet" wiped the wallet in ~5 s with **no PIN prompt at any step** (`T6/07`, `T6/08`, `T6/09`, `T6/s10-t6-reset.mp4`).
- **D-032 / SR-28** — the send confirm sheet reports "Network fee 0.0001" while the resulting tx detail for the *same* transaction reports "0.00000226" — the two screens in one flow disagree by 44x (`T4/08` vs `T4/09`). Typing an amount above balance − 0.0001 is silently clamped (typed 0.93697517 → field shows 0.93688742, `T3/07`).
- **D-048** — the immediately-post-send detail sheet shows Tax Category **"Income"** for an outgoing send (`T2/02`); reopening the same tx later shows "Expense" (`T5/03`).
- **D-030** — Address book still opens on the empty "SENDING ADDRESSES" tab and offers no manual entry, only "Paste from clipboard" / "Scan address" (`T4/21`, `T4/22`).
- **D-041 mechanism** — on every cold start after a send the balance stream publishes ~2x the real value for 10–20 s with `l1Synced=false`; the cause is visible in `WalletBalanceFacts total=192999384 confirmed=97000436 unconfirmed=95998948` — the spent input is still counted confirmed while its change is counted unconfirmed. Self-corrected here (06:52:35 → 06:52:54), unlike S2's persistent case.
- **D-004** — `idling detected, stopping service` at 08:22:00 / 08:28:00 with no service stop in between (`logs/watchlist.txt`).
- **D-052 / D-021** — the "DashPay contact coverage DEBT …" and "permanently-dark candidate" lines are still emitted about once a minute.

## Contra-findings (ledger items that did NOT reproduce here)

- **D-013 does not always hold**: this reset logged `publish txmetadata successful: TxMetadataSaveInfo(itemsSaved=16, itemsToSave=16)` at 08:14:06 — the metadata *was* saved. S1's `itemsSaved=0` looks situational, not universal.
- **D-031** did **not** reproduce: after 5 min 29 s with the screen off the L1 engine was still advancing (1556624 → 1556626), there were no `idling detected` lines in that launch at all, and a send attempted immediately after unlock succeeded first try (`T7/03`).
- **SR-12** (shielded stall watchdog firing at 40 s) never fired: every shield completed in 5–7 s.
- **"Rotating a screen must not lock the wallet"** is trivially satisfied because rotation cannot happen: 22 of 31 activities in `wallet/AndroidManifest.xml` are `android:screenOrientation="portrait"` (only `de.schildbach.wallet.MainActivity`, `AddressBookActivity`, `NetworkMonitorActivity`, `BlockInfoActivity`, `ScanActivity`, `SweepWalletActivity`, `WalletUriHandlerActivity`, `InviteHandlerActivity`, `ImportSharedImageActivity` are free).

## Environment problems (not product defects)

- ENV-3 confirmed: concurrent `uiautomator dump` calls throw `IllegalStateException: UiAutomationService … already registered!` into the crash buffer. The single FATAL in `logcat.txt` (03:16:55) is this, not the app.
- `adb shell am start -d '<url>'` must be written as `adb shell "am start … -d '<url>'"`; quoting only on the host lets the *device* shell split the URL on `&` (the invite link silently lost its last two parameters on the first attempt).
- The send-amount keypad reuses the same resource ids (`btn_1`…`btn_9`) as the lock-screen PIN pad, which made an automated unlock helper type the PIN into the amount field. Harness hazard, not an app bug — but worth knowing for other streams.
- The app's numeric keypads expose no `EditText`, so "paste an amount with a currency symbol" is not expressible through the UI; covered instead via BIP21 `amount=` values.
- Auto-logout was raised from the 1-minute default to 24 hours for the interrupt tests (More › Security › Advanced Security) and was reset to the default automatically by the wallet wipe in T6. Locale, font scale, density, night mode and rotation were all restored to defaults at the end.

## Not run / blocked

- The **username request** screen for T9 could not be exercised: this wallet already owns `qa1s13939`, so the request flow is unreachable. Edit Profile (with a typed Display Name) was used as the closest analogue and restored correctly.
- The **rotation** leg of T1 is inapplicable (see contra-findings) rather than passed.
