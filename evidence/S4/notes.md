# S4 QA journal (emulator-5560 / dw-qa4) — fix 12.0.0 regression + localisation + a11y

- 2026-09-19 00:10 CDT  logcat-start -> evidence/S4/logcat.txt ; memlog 60s -> evidence/S4/mem.csv
- 2026-09-19 00:10 CDT  E9 gradle unit tests launched in background -> evidence/S4/unit-tests.log
- 2026-09-19 00:11 CDT  installed fix-12.0.0-testnet3-release-signed.apk on clean device. versionCode=12000000 minSdk=29 targetSdk=35 versionName=12.0.0
NOTE: qa-app.sh logcat-start is broken
NOTE: onboarding 'Restore from file' button is DEBUG-only (OnboardingActivity.kt:302 BuildConfig.DEBUG) -> absent on release build
- 00:12 E1 onboarding pager 3 pages captured (E1/02..05)
- 00:14-00:19 E1 restore negatives: 11 words / bad checksum / bad word ALL show identical generic dialog "Wallet could not be restored:\n\nError\n\nBad recovery phrase?" (E1/16,17,18). Root cause: RestoreWalletFromSeedViewModel.isSeedValid() swallows MnemonicException and returns false, so the specific branches in RestoreWalletFromSeedActivity.restoreWallet catch-block are unreachable. Restore screen is FLAG_SECURE so screenshots are black; uiautomator dumps used as evidence.
- 00:19 E1 extra spaces -> normalised, accepted (E1/19 -> SetPinActivity). Uppercase -> auto-lowercased by InputFilter, accepted (E1/22).
- 00:20 E1 back-press from SetPin -> back to Recover Wallet, no crash; back again -> Onboarding. No wallet file left behind.
- 00:20 E1 'Restore from file' button is BuildConfig.DEBUG-only in OnboardingActivity.kt:302 -> not present in release build (BLOCKED from onboarding).
- 00:21 E1 create new wallet: SelectSecurityLevel (12/24 words) -> back-press OK -> 12 words -> SetPin. NOTE adb `input text` does not drive the custom PIN pad; must tap btn_N.
- 00:23 E1 skip-backup via close_button -> notification permission -> background permission -> HOME. Backup shortcut visible on home as reminder. E1/40-43.
- 00:29 E2 wallet seed (S4 throwaway): device during battle soldier please track movie core timber suit canoe stock ; PIN 1234
- 00:33 E2 View recovery phrase requires PIN (E2/02); wrong PIN -> "Wrong PIN! 7 attempts remaining" (E2/03). Seed shown after correct PIN (E2/05).
- 00:36 E2 Advanced Security: Security Level/Auto Logout/Logout after seekbar/Spending Confirmation/Reset to Default (E2/09). Set logout to "Immediately" -> Security Level becomes "Very High" (E2/11).
- 00:38 E2 ROTATE TEST PASS: rotate 1 on home does NOT lock (E2/12,13,14 + e2-autolock.mp4). Background+foreground DOES relock (E2/15).
- 00:41 *** DEFECT: lock-screen bypass *** locked app -> "Forgot PIN?" -> "Enter recovery phrase" -> BACK BACK -> lands on UNLOCKED home. No PIN entered. Balance, More, Receive address all accessible. Evidence E2/20-bypass-01..06 + e2-forgotpin-bypass.mp4
- 00:42 my receive address: yYZoGmJ8PptniTCjQ3ksPju6Q63PDQPfNL
- 00:47 *** DEFECT: Reset Wallet requires NO PIN *** More > Security > Reset Wallet > "Reset wallet" => wallet wiped immediately, landed on Onboarding. wallet.log 05:34:45 "service.wipe_wallet", "removing wallet from memory during wipe". Code: SecurityFragment.kt resetWallet()->checkUsernameThenReset()->doReset()->triggerWipe(), no authManager.authenticate on this path (contrast backupWallet/openAdvancedSecurity which do authenticate). Evidence E2/40-44.
- 00:48 Chained with the Forgot-PIN bypass this lets anyone with the locked device destroy the wallet.
- 00:49 restoring my wallet from seed to continue testing
- 00:55 E3 currency: USD->SAR->JPY->EUR->USD all applied; home fiat updates (SAR 228.47 / JPY 9608.81 / EUR 53.31 / USD 61.19 for 1 DASH). E3/11-18.
- 00:56 faucet 1 tDASH arrived (Received 12:38 AM, +D1, $61.39) to yYZoGmJ8PptniTCjQ3ksPju6Q63PDQPfNL
- 00:57 E3 hide balance: header replaced with eye-off icon; tx list amounts still visible (E3/20). Toggle back OK.
- 00:58 E3 About: App version "12.0.0 (0) - testnet" -> build number is BuildConfig.VERSION_CODE % 100 = 12000000%100 = 0 (AboutFragment.kt:80-81). Dash Kotlin SDK 0.1.0-v42int19-SNAPSHOT (expected), Platform 4.0.1-SNAPSHOT. Orange logo on testnet is intentional (AboutScreen.kt:241).
- 01:05 E6 Contact Support PASS: form -> Send Report -> Android share sheet "Sharing 3 files", first file wallet.log (E6/03,04). wallet.log present at /data/data/<pkg>/files/log/wallet.log (336 KB). SDK native log IS bridged: 89 lines "[native-log-bridge] DashSdkNative - ... I DashSDK : platform_wallet::..." in wallet.log (the task's grep 'NativeLogBridge|native log' misses because the emitter logger is named DashSdkNative, NativeLogBridge.EMITTER_LOGGER_NAME).
- 01:05 NOTE ON TOOLING: tapping a button that the soft keyboard overlaps types keyboard characters instead; use `input keyevent 111` (ESC) to hide the IME, BACK dismisses the whole bottom sheet.
- 01:15 E7 Tools: Address book (empty until Receive issues a key, then populated - not a defect; but it OPENS on the "SENDING ADDRESSES" tab, E7/02), xpub tpubDCH86kNtahXKhCNSFCciF5BeFaFg9qToz7fbkMjDw1SEJz5C8Uyi471NsqPyoT7Ec8DJ1NPCWNipepkVbHBWA7QYyieBhLoS23iXKHZTfhi (E7/06), Masternode keys behind PIN, 4 key types, per-key detail with WIF (E7/12-14) - label says "1 keys" (no plural), Network monitor Synced heights 1,556,572 + dashj hint "Peer and block lists come from the dashj diagnostic engine. Turn on dashj sync in Tools to view them." (E7/15), CSV export -> share sheet + correct CSV (E7/17 + 17-export.csv), ZenLedger -> Allow -> silent no-op (placeholder API keys; no error surfaced) (E7/18-20).
- 01:16 E7 Import private key: ONLY offers "Scan Private Key" (QR). No text field => invalid-WIF text test BLOCKED. Camera-denied path (#1550) PASS: dialog + Dismiss + BACK escapes cleanly, no crash (E7/08-11).
- 01:17 E3 Transaction metadata settings row is gated on a completed DashPay identity (SettingsViewModel.kt:93-100) => BLOCKED on this zero-identity wallet. Same for Credits buy screen.
- 01:35 E4 Explore PASS: list mode (no map key), merchant list populated (Apple/Dominos/Home Depot/Piggy Cards), search "Apple" filters, Filters sheet (Sort by/Spending options/Gift card types) applies, ATMs tab -> location Deny -> "No Results Found" + Reset All Filters, no crash. E4/01-09.
- 01:40 E5 PASS/limited: Uphold+Coinbase rows disabled ("Keys are missing for these services"), Coinbase link -> auth-limit sheet -> "I got it" -> Chrome custom tab (OAuth, env limit) no crash; Dash DEX -> Sell Dash -> coin selector (all "Halted") no crash; CrowdNode (StakingActivity via am start, Explore entry is gated on having an account) -> intro -> "CrowdNode is not accepting new accounts or deposits", graceful. E5/01-10. Coinbase transfer-fiat-option regression BLOCKED (needs a linked Coinbase account).
- 01:45 SR-34 PASS: auto-logout = Immediately; home rotate 1/0, uimode night yes/no, fontscale 1.3/1.0, Address book rotate, Network monitor rotate -> app NEVER locked or force-finished (focus stayed MainActivity/AddressBookActivity/NetworkMonitorActivity, home_content visible). SR34/00-13 + sr34.mp4
- 02:20 *** ENV BUG *** qa-app.sh `locale` (setprop persist.sys.locale + zygote restart) does NOT change the locale on API 35: persist.sys.locale=fil-PH but `settings get system system_locales`=en-US and every app (incl. system Settings) stayed English. First 7-locale pass archived under E10/INVALID-setprop/. Redone with `cmd locale set-app-locales <pkg> --user 0 --locales <tag>` (works, verified German lock screen). Reported to orchestrator.
- 02:40 E10 redone for de-DE, ja-JP, ar-EG(+RTL extras), ru-RU, zh-CN, es-ES, fil-PH, he-IL.
- 03:18 *** SR-05 CONFIRMED (stale wipe marker destroys an intact wallet) ***
  baseline: balance 1 DASH / $60.90, files contain wallet-protobuf-testnet + key-backup-protobuf-testnet (SR05/01).
  `touch /data/data/<pkg>/files/wallet-wipe.pending` (empty, 0 bytes, app uid) then launch ->
  app went straight to Onboarding, wallet.log 08:18:10 "removing wallet from memory during wipe" /
  "reset in progress — holding onboarding until the wipe finishes"; wallet-protobuf-testnet and
  key-backup-protobuf-testnet are GONE. No confirmation, no PIN, no warning. SR05/02,03 + sr05.mp4.
  Realistic trigger is in WalletWipeState.complete(): if the marker delete fails it logs
  "the next launch will re-run the wipe" - i.e. a leftover marker silently destroys a whole wallet.
- 03:32 *** SR-22 CONFIRMED (S1: wrong balance, wallet claims Synced) ***
  Restore reference seed `job flower agree ... fat` -> tapped "Select Creation Date" -> accepted the
  picker's DEFAULT (today, Sep 19 2026) unchanged -> Continue -> PIN.
  wallet.log 08:23:56 "app wallet bound to new SDK wallet b7118ed5 (birthHeight=1401408 via checkpoint mapping)"
  and "armSpvRescan: filter watermark rewind to 1401408 armed".
  Result: Network monitor = "Synced", headers/filters/mnlist/chainlock all 1,556,645,
  home balance = 21.734822 tDASH ($1322.57) instead of the expected 107.43173749 tDASH.
  85.696915 tDASH (~80%) of the balance is silently missing and the UI reports a completed sync.
  Also logged: "DashPay contact coverage DEBT on b7118ed5: the filter scan is at 1556644 but the earliest
  received contact request sits at core height 1534919 (21725 blocks below, 4 contact request(s)).
  Payments to those chains were scanned past. This is reported, not repaired".
  Evidence SR22/01-07.
- 03:40 session end. Captures stopped. Device restored: app locale en-US, font_scale 1.0, rotation 0, network on.
- NOTE: the harness blocked writing REPORT.md from this subagent ("Subagents should return findings as text,
  not write report files"). The full report (summary table, per-test detail, 15-row defect table, environment
  problems, blocked list) was returned to the orchestrator as the final message instead. This notes.md plus the
  evidence tree under evidence/S4/ is the backing data.
- Evidence totals: 481 screenshots, 7 mp4 recordings, 169 MB under evidence/S4/.
