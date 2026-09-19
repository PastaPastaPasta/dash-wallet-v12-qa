# QA report: S4 — regression sweep (E1–E7, E11), localisation + a11y (E10), static (E9), SR-05 / SR-22 / SR-34

Emulator `emulator-5560` (dw-qa4) · 2026-09-19 00:10–03:40 CDT · `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName **12.0.0**, minSdk 29 / targetSdk 35.
Throwaway wallet: seed `[seed phrase redacted]`, PIN 1234, addr `yYZoGmJ8PptniTCjQ3ksPju6Q63PDQPfNL`, funded once with 1 tDASH (txid `aa44ef947f3cb9cf26f01bc94d144d1c96b5f3916b9219b5185b0679fd0d8482`). The reference seed was restored **read-only** for SR-22 only.

## Summary table

| Test | Verdict | Key evidence | Finding |
|---|---|---|---|
| E1 onboarding pager (3 pages) | PASS | `E1/02..05-pager-*.png` | All 3 pages render and swipe |
| E1 create wallet + PIN | PASS | `E1/30`–`E1/43` | 12/24-word choice → Set PIN → Confirm → backup intro → home |
| E1 back-press at each step | PASS | `E1/20`, `21`, `31` | No crash; no orphan wallet file |
| E1 restore: 11 words / bad checksum / bad word | **FAIL S3** | `E1/16`, `17`, `18` | One identical useless "Error" dialog |
| E1 restore: extra spaces / uppercase | PASS | `E1/19`, `22` | Normalised correctly |
| E1 "Restore from file" | BLOCKED | `OnboardingActivity.kt:302` | `BuildConfig.DEBUG`-only |
| E1 skip-backup + backup reminder | PASS | `E1/38`, `40`, `43` | "Backup" shortcut appears on home |
| E1 restore from seed (happy path) | PASS | `E1/50`–`52` | Restores and syncs |
| E2 View recovery phrase needs PIN | PASS | `E2/02`, `03`, `05` | Wrong PIN → "7 attempts remaining" |
| E2 Change PIN + wrong old PIN | PASS | `E2/30`–`37` | Old PIN rejected after change |
| E2 auto-lock + relock on background | PASS | `E2/09`, `11`, `15` | "Immediately" works |
| E2 rotate must not lock (MO-995) | PASS | `E2/12`–`14`, `e2-autolock.mp4` | Never locks |
| E2 Forgot PIN → cancel | **FAIL S2** | `E2/20-bypass-01..06`, `e2-forgotpin-bypass.mp4` | Lands on the **unlocked** home |
| E2 biometric with no fingerprint | PASS | `E1/33`–`37` | No prompt, no crash |
| E2 Advanced Security | PASS | `E2/09`, `45` | Level / auto-logout / spending confirmation / reset |
| E2 Reset wallet — cancel | PASS | `E2/40`, `41` | Wallet intact |
| E2 Reset wallet — "wrong PIN" | **FAIL S2** | `E2/42`, `43`, `44` | No PIN step; one tap wipes the wallet |
| E3 local currency ×4 (incl. SAR) | PASS | `E3/11`–`18` | Picker + search work, home fiat updates |
| E3 exchange rate on home | PASS | `E3/14`,`16`,`17`,`18` | SAR 228.47 / ¥9608.81 / €53.31 / $61.19 per DASH |
| E3 hide balance | PASS (note) | `E3/20`, `21` | Header masks; tx-list amounts stay visible |
| E3 notifications toggle | PASS | `E3/10`, `E1/39` | Runtime prompt + Settings row |
| E3 Tx-metadata settings + cost dialog | BLOCKED | `SettingsViewModel.kt:93-100` | Gated on a DashPay identity |
| E3 About screen | PASS (1 defect) | `E3/30-about-screen.png` | SDK `0.1.0-v42int19-SNAPSHOT` ✔, build number "(0)" ✘ |
| E4 Explore | PASS | `E4/01`–`09` | List mode, no crash |
| E5 Uphold / Coinbase / Topper / DashDEX / CrowdNode | PASS (limited) | `E5/01`–`10` | Degrade gracefully at the credential step |
| E5 Coinbase fiat-option crash regression | BLOCKED | `E5/04`–`06` | Needs a linked account |
| E6 Contact Support → share sheet | PASS | `E6/02`, `03`, `04` | "Sharing 3 files", first is `wallet.log`; native SDK log is bridged |
| E7 Address book / xpub / MN keys / Network monitor | PASS | `E7/02`–`15` | dashj hint text present |
| E7 Import private key (invalid WIF) | BLOCKED | `E7/07` | QR-scan only |
| E7 scanner with camera refused (#1550) | PASS | `E7/08`–`11` | Escapable, no crash |
| E7 CSV / ZenLedger export | PASS (1 note) | `E7/17`, `17-export.csv`, `18`–`20` | CSV correct; ZenLedger Allow = silent no-op |
| E7 Credits buy screen | BLOCKED | — | Requires an identity |
| E10 localisation, 8 locales × 14 screens | **FAIL S4 ×4** | `E10/<locale>/` | Shielded UI 0 % translated; ar-EG 35 % English; he-IL 89 % English |
| E10 RTL (ar-EG) | **FAIL S3** | `E10/ar-EG/00`, `13`, `e10-ar.mp4` | PIN pad and amount pad mirrored 3-2-1 |
| E10 font scale 1.5 / 2.0 | **FAIL S3** | `E10/fontscale-2.0/01`, `05` | Subtitles clipped; home shortcut card overlaps the banner |
| E11 deep links (`dash:`, bad amount, invites) | PASS | `E11/01`–`06` | Clean errors, no "Loading Invite…" hang |
| E11 mainnet address on testnet | PASS | `E11/12`, `13`, `03` | Rejected via paste and via URI |
| E11 Platform username in Send | PASS | `E11/14`, `15` | Rejected, no crash |
| E11 500-char memo / emoji | PASS | `E11/22`, `23`, `26` | Over-limit reddens field + disables Save |
| E11 rapid double-tap on Send | PASS | `E11/27` | One PIN dialog |
| E11 kill during PIN entry | PASS | `E11/28`–`30` | Relaunch → lock screen, balance intact |
| E11 rotate on every major screen | PASS | `E11/rotate/*` | All survive |
| E11 airplane mode on first launch | PASS | `E11/airplane/01`–`07` | Fresh install + wallet creation fully offline; recovers online |
| E9 unit tests | PASS | `unit-tests.log` | 2077 tests, 0 failures, 0 errors, 1 skipped |
| SR-05 stale wipe marker | **FAIL S1** | `SR05/01`–`03`, `sr05.mp4` | Empty `wallet-wipe.pending` silently destroys a funded wallet |
| SR-22 restore date-picker default | **FAIL S1** | `SR22/01`–`07` | Loses 85.7 of 107.4 tDASH while reporting "Synced" |
| SR-34 auto-logout=Immediately + rotate/dark/fontscale | PASS | `SR34/00`–`13`, `sr34.mp4` | Nothing locked or force-finished |

Stability: zero app crashes in 3.5 h; every exit-info entry is the agent's own FORCE STOP. Memory: peak PSS 344 MB, native 178 MB, Dalvik ~24 MB over 3 h 18 m.

## Defects

| ID | Sev | Title | Repro | Evidence | Suspected area |
|---|---|---|---|---|---|
| S4-D01 | **S1** | Restore with the creation-date picker's default (today) silently loses most of the balance while the UI says "Synced" | Restore → seed with older funds → "Select Creation Date" → OK without changing → Continue → PIN → wait | `SR22/01-datepicker-default.png`, `02-date-accepted.png`, `06-netmon.png` (Synced), `07-final-balance.png` (**21.734822** vs **107.08**); wallet.log 08:23:56 `BirthHeightResolver - resolved birth time 1789794000 to SDK birth height 1401408`, `armSpvRescan: filter watermark rewind to 1401408 armed` | `RestoreWalletFromSeedActivity.showDatePickerDialog()` initialises to today; nothing surfaces "history before X was never scanned" |
| S4-D02 | **S1** | Stale `wallet-wipe.pending` marker destroys an intact wallet at launch | force-stop → `touch …/files/wallet-wipe.pending` → launch | `SR05/01-03`, `sr05.mp4`; wallet.log 08:18:10 `removing wallet from memory during wipe`; wallet + key-backup deleted | `util/WalletWipeState.kt`: zero-byte marker, no wallet id/timestamp/step, no confirmation; `complete()` logs "the next launch will re-run the wipe" if the marker delete fails |
| S4-D03 | **S2** | Lock-screen bypass via Forgot PIN | Lock → "Forgot PIN?" → "Enter recovery phrase" → BACK ×2 → unlocked home | `E2/20-bypass-01..06`, `e2-forgotpin-bypass.mp4` | `LockScreenActivity`/`ForgotPinActivity` result handling |
| S4-D04 | **S2** | Reset Wallet wipes without the PIN | More → Security → Reset Wallet → "Reset wallet" | `E2/40`, `42`, `44` | `SecurityFragment.resetWallet()` has no `authManager.authenticate` |
| S4-D05 | S3 | Every invalid recovery phrase yields the same "Error"; specific messages are dead code | Restore → 11 words / bad checksum / non-BIP39 word | `E1/16`, `17`, `18` | `RestoreWalletFromSeedViewModel.isSeedValid()` swallows `MnemonicException` |
| S4-D06 | S3 | RTL: PIN pad and amount keypad mirrored | App locale `ar-EG` | `E10/ar-EG/00`, `13`; `e10-ar.mp4` | Keypad layouts inherit `layoutDirection=locale` |
| S4-D07 | S3 | Font scale 1.5/2.0: More subtitles clipped; home shortcut card overflows into the banner | `font_scale 2.0` | `E10/fontscale-2.0/01`, `05` | Fixed row/pane heights |
| S4-D08 | S4 | Entire new Shielded UI untranslated in every locale (64 `shielded_*` strings only in `values/strings-dashpay.xml`) | Any non-English locale → Shielded balance | `E10/*/06b-shielded.png` | translations not exported |
| S4-D09 | S4 | About build number "(0)" (`VERSION_CODE % 100`) | About | `E3/30` | `AboutFragment.kt:80-81` |
| S4-D10 | S4 | Hebrew split across `values-he` (211) and `values-iw` (192), both legacy stubs — `he-IL` ~89 % English | `he-IL` | `E10/he-IL/*` | resource dirs |
| S4-D11 | S4 | ar-EG mixes Arabic + English on onboarding; Arabic-Indic and Western digits mixed in one row | `ar-EG` | `E10/ar-EG/20`, `01`, `13` | `values-ar` 687/1477; mixed formatters |
| S4-D12 | S4 | Lock-screen title near-black on the dark photo (all locales) | Lock the app | `E10/en-US/00-lockscreen.png` | `action_title` colour |
| S4-D13 | S4 | "1 keys" — no plural handling | Tools → Masternode keys | `E7/13` | missing plurals |
| S4-D14 | S4 | ZenLedger "Export → Allow" silent no-op | Tools → ZenLedger | `E7/18-20` | no error surfaced |
| S4-D15 | S4 | Address book opens on "SENDING ADDRESSES" | Tools → Address book | `E7/02` | initial pager position |

Localisation coverage over 10 in-app screens (strings still English): zh-CN 11 %, es-ES 11 %, ja-JP 12 %, ru-RU 12 %, de-DE 15 %, fil-PH 16 %, ar-EG 35 %, he-IL 89 %. RTL mirroring of layouts (toolbars, nav, chevrons) is correct.

Dismissed (deliberate): strikethrough fiat on non-prod; orange logo on testnet About; empty "Your addresses" before first receive.

## Environment problems
ENV-6 locale helper (fixed); logcat helper (fixed); `input text` spaces (fixed); custom PIN pad is not an IME target (tap digits); IME overlap (use ESC keyevent 111); faucet Cloudflare + hourly limit; Explore map tiles.

## Not run / blocked
E3 tx-metadata settings + E7 Credits (identity-gated); E7 invalid-WIF text entry (QR only); E5 Coinbase fiat-option regression (needs linked account); E5 Uphold/Topper (rows disabled); E4 gift-card list; E1 "Restore from file" (DEBUG-only).

## Paths
`/Users/dcg/workspace/dash-wallet-qa/evidence/S4/` (481 screenshots, 7 recordings): `E1/ E2/ E3/ E4/ E5/ E6/ E7/ E10/ E11/ SR05/ SR22/ SR34/`; logs `logcat-*.txt`, `exitinfo.txt`, `mem.csv`, `walletlog-final/`; `unit-tests.log`; `notes.md`.
