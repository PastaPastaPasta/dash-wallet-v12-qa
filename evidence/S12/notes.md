# S12 notes (emulator-5558, AVD dw-qa3)

## Static pre-read (before touching the device)
- `wt-fix` `wallet/src/de/schildbach/wallet/service/platform/sdk/CoinJoinFundsMigrationService.kt:118`
  `const val MIXED_FUNDS_PROMPT_HARD_SUPPRESSED = true` — TEMPORARY kill switch.
  `shouldPrompt()` returns false immediately (line 425) and `MixedFundsMigrationDialogFragment.showOnce`
  returns early too, so NO code path can show the mixed-funds sheet in the build under test.
  Comment (Brian, 2026-08-11) says the COMBINE drain produced a committed-but-never-propagated mainnet
  tx 0a884b1d… (~75.6 DASH stuck on a permanent "Sending" row).
  => CJ1's UI expectations (keep-spendable / move-to-shielded / in-progress / failure) are UNREACHABLE
     in this APK. Will verify empirically and then focus on: are the ex-CoinJoin coins counted + spendable?
2026-09-19T02:02:36
S12 CJ1 wallet seed: [seed phrase redacted]

## CJ1 (master 11.9.0 baseline)
- 02:02 installed master-11.9.0-testnet3-release-signed.apk (versionCode 11090002) after uninstalling prior install
- 02:03-02:07 created wallet, PIN 1234, seed verified. Receive address yVYBPPn2zy1KKRUD88wywwXHnKEo7X83H4
- 02:07 faucet 1 tDASH -> txid 10e3b5b8dca0702ca350d5f263e5b31c84c678f63d541a5a2b0ee7c1a96cf054
- Orchestrator course-correction received: mixing window shortened to 15 min; focus post-upgrade on
  balance parity / spendability / logs / settings row / prefs, since the prompt is hard-suppressed.
- 02:11:44 CoinJoin enabled (Intermediate) on master. Mixing ran ~21 min.
  * 4 CoinJoin txs broadcast: 3c229f43… (create-denominations: 29x0.00100001, 17x0.0100001, 8x0.100001,
    0.0004 collateral, 0.00056938 change), 0a2cacdc…, 8d969085…, b46be97f…
  * Progress never left 0% ("0.0000 of 1.0000", getMixingProgress 0.0 / 53). All mixing sessions ended
    POOL_STATE_ERROR "Session not complete!" / TIMEOUT against testnet MNs 68.67.122.*.
  * So: CoinJoin ACCOUNT (m/9') populated with ~0.999 tDASH of denominations at 0 rounds; 0 fully-mixed.
  * Master home: 0.999971 tDASH, "Mixing · 0%", history group row "Mixing Transactions / 4 transactions / -0.000029".
  * Persisted: files/datastore/coinjoin.preferences_pb -> coinjoin_mode=INTERMEDIATE, first_time_info_shown,
    last_mixing_progress. NOTHING coinjoin/privacy-related in shared_prefs main xml.
  * Stop-mixing confirm dialog captured ("Any funds that have been mixed will be combined with your unmixed funds")
    then CANCELLED deliberately: upgrading with CoinJoin still ENABLED is the state the migration detector cares about
    and avoids any chance of the app draining the m/9' bucket before the upgrade.

## CJ1 post-upgrade (fix 12.0.0, versionCode 12000000)
- 02:34:49 kill, `install -r` fix APK, relaunch (video post-upgrade/cj1-upgrade.mp4)
- Unlock -> cutover explainer "A one-time sync is needed" -> Got it. NO mixed-funds sheet (expected: hard-suppressed).
- Balance parity: home 0.999971 both sides; log `WalletBalanceFacts: total=99997138 accounts={bip44:0, bip32:0, coinjoin:99997138,...}`
  => ALL of it is in the CoinJoin account, correctly detected by the SDK.
- History: "Mixing Transactions / 4 transactions / -0.000029" group row survives the upgrade; fix build re-classifies them
  (CoinJoinMixingTxSet: 3c229f43 CreateDenomination, 0a2cacdc/8d969085/b46be97f MakeCollateralInputs). Renders sanely.
- Settings on fix: CoinJoin row GONE (Local currency / Rescan / About / Notifications / Battery only).
- **S1 FUNDS STRANDED**: Send -> address -> amount 0.001 shows "Insufficient funds", Send disabled,
  on-screen "Balance: DASH 0.00 ~ $ 0.00", "Max" fills 0.
  wallet.log 07:38:57 `SendCoinsFragment - dryRunException: org.bitcoinj.core.InsufficientMoneyException:
  Insufficient money, missing 0.0011 DASH`. So the send engine sees ZERO spendable while the header shows 0.999971.
  With the migration prompt hard-suppressed there is no in-app way to move the coins out.
- SR-27: `files/datastore/coinjoin.preferences_pb` still contains `coinjoin_mode=INTERMEDIATE`,
  `first_time_info_shown`, `last_mixing_progress` AFTER the upgrade - orphaned, never read, never cleared.
  `dashpay.preferences_pb` has no `mixed_funds_migration_done`/`_in_flight` key (prompt never ran).

## CJ1 escape hatches (evidence in CJ1/escape-hatches/)
1. Send -> Max: FAILS. "Balance: DASH 0.00 ~ $ 0.00", Max fills 0. (01-send-max.png)
2. Shield (Payments > Internal > Shielded balance) -> Max (0.99997138 offered, "From Dash Wallet 0.99997138"):
   FAILS at PIN -> "This transfer was not sent / Nothing left your balance."
   log 07:46:58 `AssetLockInsufficientFunds: asset lock coin selection is short: available 0 duffs, required 99979074 duffs`
   (02..04-shield-max*.png)
3. Tools > dashj sync (diagnostic) ON ("Start sync from date"), dashj reached "dashj 100% - matches SDK",
   then retried Send -> still "Balance: DASH 0.00", Max 0. FAILS. (06..09*.png)
4. Reset wallet + restore the SAME seed on the fix build: balance returns as 0.999971,
   `accounts={bip44:0, bip32:0, coinjoin:99997138}` again, Send still "DASH 0.00" / Max 0. FAILS.
   (restore/08,10*.png). Also re-confirms D-003/SR-03: Receive hands out the already-used index-0
   address yVYBPPn2… after a restore on the fix build.
5. Downgrade escape: uninstall fix, install master 11.9.0, restore the same seed -> in progress.
5. **Downgrade escape WORKS**: uninstall fix -> install master 11.9.0 -> restore the same seed (full SPV
   replay ~35 min, progress 0->99). Master Send screen shows "Balance: DASH 0.99988303 ~ $60.66", Max fills
   0.99988303, and a real 0.001 self-send SUCCEEDED:
   txid fadea2817fce263559e1acf96d8f04ab634a3609ad2f1e0cdd92993cc9215ec9,
   IN yXRYQgkWnCrAzmcM2muLphFsBrtk3kEG86 0.100001 (a CoinJoin denomination) -> OUT 0.001 + 0.09899873 change,
   fee 0.00000227 (evidence 15..23*.png + cj1-master-send.mp4).
   => The ONLY working escape from D-068 is downgrading to 11.9.0. Nothing in the 12.0.0 UI can reach the coins.

## D-068 root-cause confirmation (bonus)
Back on master (still restored), sent MAX (0.99987927) from the CoinJoin denominations to the wallet's own
BIP44 address yby8Md13kUKFZ6GMPUm5JWRBpnBNaS5CXQ (escape-hatches/24..26*.png), let it confirm, then upgraded
in place to the fix build again. After the upgrade:
  `WalletBalanceFacts: total=99987927 accounts={bip44:99987927, bip32:0, coinjoin:0}` and the funds behave normally.
=> the stranding is specific to coins sitting in the CoinJoin (m/9') account at the cutover; the same wallet
   with the same coins in bip44 upgrades cleanly.

## BC1 (fix build, same wallet, 0.999879 tDASH in bip44)

## BC1 result (04:16)
- shield 0.8 OK -> Dash Wallet 0.199 / Shielded 0.797
- username qa12s12mixedfunds4821 (21 chars, non-contested) registered in <10 s; identity
  GDpXqZCFyoo3hhBwfmkNdJSBcCDpkpEpsvodLzw8o1fi; alias qa12s12mixedfunds4821.dash status ok contested false
- top-up #1: auto-lock cancelled it (D-070); retry -> ambiguous "may have gone through"
  (Dapi client error: no available addresses to use) -> drain worker recovered 91 s later (D-071)
- top-up #2: clean, "top-up of 100000 duffs credited; new balance 2746680400"
- explorer: 2562746440 -> 2654713420 -> 2746680400 credits; topups 3.0e9 -> 3.2e9; txs 2 -> 4
- history row "Topup Fee -0.001003", detail "Platform Credits", fee 0.00000263
- Tools > Credits row shows no balance at all (D-072); Buy Credits identity balance stale until relaunch (D-073)

## NM1 (04:1x) - PASS, see REPORT.md
## Captures stopped 04:17. Peak PSS 508777 KB. No crash/ANR/OOM (exit-info: all FORCE STOP by me).
