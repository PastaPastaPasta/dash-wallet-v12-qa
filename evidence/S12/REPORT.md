# QA report: S12 — CJ1 / BC1 / NM1   (agent: S12, emulator-5558 / AVD dw-qa3, 2026-09-19)

Builds: `apks/master-11.9.0-testnet3-release-signed.apk` (versionCode 11090002) and
`apks/fix-12.0.0-testnet3-release-signed.apk` (versionCode 12000000).
Wallet seed (throwaway): `gospel tip talent possible practice leave vicious come swing luggage ice sand`.
Faucet: 1 tDASH, txid `10e3b5b8dca0702ca350d5f263e5b31c84c678f63d541a5a2b0ee7c1a96cf054` (one request, as briefed).

## Summary table
| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| CJ1 mixed-funds migration UI | **BLOCKED (by design)** | `wt-fix/wallet/src/de/schildbach/wallet/service/platform/sdk/CoinJoinFundsMigrationService.kt:118,425`; `S12/CJ1/post-upgrade/04-home-after-explainer.png` | `MIXED_FUNDS_PROMPT_HARD_SUPPRESSED = true` — the sheet cannot be shown by any code path, so keep-spendable / move-to-shielded / in-progress / failure / unconfirmed are all unreachable in this APK |
| CJ1 funds after upgrade | **FAIL (S1)** | `S12/CJ1/post-upgrade/12-amount-0.001.png`, `13-send-balance-unhidden.png`, `21-shield-result.png`, `insufficient-funds-log.txt`, `shield-failure-log.txt`, `cj1-send.mp4`, `cj1-shield.mp4` | The whole balance (0.99997138 tDASH) sits in the CoinJoin account after the upgrade; the header shows it but Send, Send-Max and Shield all see **0** — funds stranded with no in-app way out (D-068) |
| CJ1 escape hatches | **1 of 5 works** | `S12/CJ1/escape-hatches/*`, `S12/CJ1/restore/*` | Only downgrading to master 11.9.0 + restoring the seed recovers spendability (real send proven on chain) |
| BC1 buy credits / identity top-up | **PASS (with 4 defects)** | `S12/BC1/26..51*.png`, `explorer-identity-final.json`, `bc1-credits.mp4` | Username + 2 x 0.001 DASH top-up both landed; explorer credit balance rose 2,562,746,440 -> 2,746,680,400 |
| NM1 network monitor | **PASS** | `S12/NM1/02,03,05,06,07,08*.png` | dashj OFF = summary + "turn on dashj sync to view peers"; dashj ON = peers/blocks lists; replay state captured at 54% |

---

## Per-test detail

### CJ1 — CoinJoin mixed-funds migration on upgrade (catalogue #15)

**Static pre-read (before touching the device).**
`wt-fix/wallet/src/de/schildbach/wallet/service/platform/sdk/CoinJoinFundsMigrationService.kt:118`
`const val MIXED_FUNDS_PROMPT_HARD_SUPPRESSED = true`, and line 425
`if (MIXED_FUNDS_PROMPT_HARD_SUPPRESSED) return false` at the top of `shouldPrompt()`, plus the same guard
inside `MixedFundsMigrationDialogFragment.showOnce()`. The in-code note (Brian, 2026-08-11) says the COMBINE
drain produced a committed-but-never-propagated mainnet tx `0a884b1d...` (~75.6 DASH stuck on a permanent
"Sending" row). The whole `ui/migration/` surface is dead code in this build. Absence of the prompt is
therefore NOT a defect — but what the suppression leaves behind is (see D-068).

**Steps (wall clock, local).**
1. 02:02 uninstall, install master 11.9.0, create wallet, PIN 1234, seed verified.
2. 02:07 receive address `yVYBPPn2zy1KKRUD88wywwXHnKEo7X83H4`; faucet 1 tDASH; confirmed (insight balance 1).
3. 02:11:44 More > Settings > CoinJoin > Continue > **Intermediate** > Start Mixing. Foreground 21 min.
4. 02:34:49 kill, `install -r` fix 12.0.0 (true in-place upgrade), relaunch (video `post-upgrade/cj1-upgrade.mp4`).
5. 02:36-03:05 post-upgrade probes; 03:05-03:12 reset + restore on fix; 03:12-03:50 downgrade + restore on master.

**Mixing result (master).** 4 CoinJoin transactions broadcast:
`3c229f43...` = CreateDenomination (1 input -> 56 outputs: 29 x 0.00100001, 17 x 0.0100001, 8 x 0.100001,
0.0004 collateral, 0.00056938 change), plus `0a2cacdc...`, `8d969085...`, `b46be97f...` = MakeCollateralInputs.
Mixing progress never left 0% — `CoinJoinExtension - getMixingProgress: 0.0 = 0.0 / 53` and every session ended
`POOL_STATE_ERROR "Session not complete!" / TIMEOUT` against testnet MNs `68.67.122.*`.
So: the CoinJoin (m/9') account was populated with ~0.9999 tDASH of denominations at 0 mixing rounds; zero
fully-mixed coins. Master home: `0.999971`, "Mixing . 0%", history group row
"Mixing Transactions / 4 transactions / -0.000029" (`pre-upgrade/32-master-balance-breakdown.png`).
The stop-mixing confirm dialog was captured (`34-stop-mixing-confirm-dialog.png`: "Any funds that have been
mixed will be combined with your unmixed funds") and deliberately CANCELLED, so the upgrade happened with
CoinJoin still enabled — the state the migration detector is written for.

**Post-upgrade observations (fix 12.0.0).**
- Unlock -> cutover explainer "A one-time sync is needed" -> "Got it". **No mixed-funds sheet** (expected).
- Balance parity exact: master `0.999971`, fix `0.999971`, and
  `wallet.log 07:35:23 L1ShadowSyncService - WalletBalanceFacts: total=99997138 accounts={bip44:0, bip32:0, coinjoin:99997138, ...}`.
  The SDK detector source does see the coins.
- The dashj-side source does not: `CoinJoinMixingTxSet - coinjoin grouping 3c229f43... as CreateDenomination (... dashjCoinJoinBalance=0)`.
- No `mixed funds detected by ...` line anywhere (the probe never runs, because `shouldPrompt()` short-circuits).
- History renders sanely: the "Mixing Transactions / 4 transactions / -0.000029" group row survives the upgrade
  and the fix build re-classifies members correctly (1 CreateDenomination, 3 MakeCollateralInputs). No "Sent D 0"
  rows (D-020 not reproduced here).
- Settings on the fix build no longer has a CoinJoin row (`post-upgrade/06-settings-fix-no-coinjoin.png`).
- **SR-27 check.** Before: `files/datastore/coinjoin.preferences_pb` = `coinjoin_mode=INTERMEDIATE`,
  `first_time_info_shown`, `last_mixing_progress`; nothing CoinJoin/privacy-related in
  `shared_prefs/..._preferences.xml`. After the upgrade the file is identical — the persisted mode is neither
  read, migrated nor cleared, simply orphaned. `dashpay.preferences_pb` contains `cutover_state CUT_OVER` but
  NO `mixed_funds_migration_done` / `mixed_funds_migration_in_flight` key, confirming the migration never ran.
  (`post-upgrade/coinjoin-datastore-fix-after.bin`, `main-prefs-fix-after.xml`.)

**Assertions.**
| Assertion | Expected | Actual |
|---|---|---|
| Mixed-funds prompt appears after upgrade | prompt (catalogue #15) | none — hard-suppressed at `CoinJoinFundsMigrationService.kt:118` |
| Balance counted after upgrade | 0.99997138 | 0.99997138 OK (`accounts={coinjoin:99997138}`) |
| Ex-CoinJoin coins spendable | 0.001 send succeeds | "Insufficient funds", Send disabled, on-screen "Balance: DASH 0.00", Max = 0 **FAIL** |
| Ex-CoinJoin coins shieldable | shield succeeds | "This transfer was not sent" **FAIL** |
| Settings CoinJoin row removed | removed | removed OK |
| Persisted CoinJoin mode handled | migrated or cleared | orphaned `coinjoin_mode=INTERMEDIATE` **FAIL** (SR-27 confirmed) |
| Prompt reappears on relaunch | n/a | no prompt, home renders normally (`22-relaunch-no-migration-prompt.png`) OK |

**Log excerpts.**
```
07:38:57 [main] SendCoinsFragment - dryRunException:
org.bitcoinj.core.InsufficientMoneyException: Insufficient money,  missing 0.0011 DASH
07:46:58 [DefaultDispatcher-worker-2] ShieldedBalanceServiceImpl - shielded shieldFromWallet rejected pre-broadcast (no lock tracked)
org.dashfoundation.dashsdk.errors.DashSdkError$PlatformWallet$AssetLockInsufficientFunds:
  asset lock coin selection is short: available 0 duffs, required 99979074 duffs
07:46:58 [DefaultDispatcher-worker-2] ShieldedTransferExecutor - shielded transfer not sent: pre-broadcast asset-lock coin-selection failure
```

**Escape-hatch matrix** (same wallet; evidence in `S12/CJ1/escape-hatches/` and `S12/CJ1/restore/`):

| # | Escape a stuck user might try | Result | Evidence |
|---|---|---|---|
| 1 | Send > **Max** / send-all to own address | **FAILS** — Max fills 0, "Balance: DASH 0.00" | `escape-hatches/01-send-max.png` |
| 2 | Payments > Internal > Shielded balance > **Max** (screen offers 0.99997138, "From Dash Wallet 0.99997138") | **FAILS** at PIN — "This transfer was not sent / Nothing left your balance"; `AssetLockInsufficientFunds: available 0 duffs, required 99979074` | `escape-hatches/02,03,04*.png` |
| 3 | Tools > **dashj sync (diagnostic)** ON (-> "dashj 100% - matches SDK"), retry send | **FAILS** — still "Balance: DASH 0.00", Max 0 | `escape-hatches/06,06a,07,08,09*.png` |
| 4 | **Reset + restore the same seed on the fix build** | **FAILS** — balance returns, `accounts={bip44:0, bip32:0, coinjoin:99997138}` again, Send still 0.00 | `restore/08-home-after-restore.png`, `restore/10-send-max-after-restore.png` |
| 5 | **Downgrade**: uninstall fix, install master 11.9.0, restore seed | **WORKS** — "Balance: DASH 0.99988303", Max 0.99988303, real 0.001 self-send broadcast and confirmed: txid `fadea2817fce263559e1acf96d8f04ab634a3609ad2f1e0cdd92993cc9215ec9`, IN `yXRYQgkWnCrAzmcM2muLphFsBrtk3kEG86 0.100001` (a CoinJoin denomination) -> OUT 0.001 + 0.09899873 change, fee 0.00000227 | `escape-hatches/15..23*.png`, `cj1-master-send.mp4` |

**Root-cause confirmation (bonus).** Still on master, sent MAX (0.99987927) from the denominations to the
wallet's own BIP44 address `yby8Md13kUKFZ6GMPUm5JWRBpnBNaS5CXQ`, let it confirm, then upgraded in place to the
fix build again. After that upgrade the log reads
`WalletBalanceFacts: total=99987927 accounts={bip44:99987927, bip32:0, coinjoin:0}` and everything (send,
shield, top-up) behaves normally for the rest of the session. The stranding is specific to coins sitting in the
CoinJoin (m/9') account at the cutover, not to the wallet or the amount.
(`escape-hatches/24,25,26*.png`, then `BC1/03-home.png`.)

**Memory:** peak `TOTAL PSS 508777 KB` over 135 samples (`S12/mem.csv`); no LMK, no OOM.
`dumpsys activity exit-info` shows only `reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)` — every process
death was my own force-stop. No crash, no ANR. Logcat: `S12/logcat.txt` (39.9 MB).

**Verdict:** migration UI **BLOCKED** (suppressed by design, file:line recorded); funds behaviour **FAIL (S1)**.

---

### BC1 — Buy credits / identity top-up (catalogue #12)

Run on the same wallet after CJ1's consolidation, so no second faucet request was needed
(balance 0.99987927 tDASH in bip44).

**Steps.**
1. 03:53 Payments > Internal > Shielded balance -> shield **0.8** -> Confirm -> PIN -> success.
   More shows "Dash Wallet 0.199 D / Shielded 0.797 D" (`BC1/04..07*.png`, `bc1-shield.mp4`).
2. 03:55 More > Join DashPay -> Continue -> payment option **Shielded balance** -> voting info -> username
   `qa12s12mixedfunds4821` (21 chars, non-contested) -> "Username is available" -> Confirm (0.03 from shielded;
   the "I accept" label is not tappable, only the checkbox square — D-006 reproduced) -> PIN.
3. 03:56:31 `BlockchainIdentityData - creation: BlockchainIdentityData(DONE, qa12s12mixedfunds4821, CONFIRMED, ..., GDpXqZCFyoo3hhBwfmkNdJSBcCDpkpEpsvodLzw8o1fi)`.
   Home shows "Hello qa12s12mixedfunds4821, Your account is ready".
4. 03:56:40-03:57:40 network off for 60 s -> home shows "Unable to connect to the Dash network / Check your
   connection" (`BC1/19-home-netoff-identity.png`). The intermediate identity progress strings
   (`identity_processing_waiting_confirmation`, `..._network_catching_up`) could NOT be observed: registration
   completed in under 10 s, before the toggle. Recorded as not-observed, not as a pass.
5. 04:01 Tools > **Credits > Buy** -> 0.001 DASH (the floor: a smaller value clamps back to 0.001 with no
   message) -> Send -> PIN -> Confirm.
   * Attempt 1: the 60 s auto-lock fired on the confirm sheet and silently cancelled the top-up — after
     unlocking, back on Buy Credits with the amount still filled and nothing spent.
   * Attempt 2: confirm sheet -> asset-lock tx broadcast -> `09:03:49 BuyCreditsFragment - SDK top-up failed
     (ambiguous=true): SDK error: Dapi client error: no available addresses to use`; UI showed "Your top-up may
     have gone through. Please don't try again - check your credit balance in a few minutes." The recovery
     worker won 91 s later: `09:05:20 SdkTopUpRecoveryService - drain: resumed top-up lock fee3034f...:0 - new
     credit balance 2654713420`.
   * Attempt 3 (clean): `09:14:25 PerformTopUpWorker - top-up of 100000 duffs credited; new balance 2746680400`.
   * A deliberate attempt with the network off was refused pre-broadcast with no funds moved:
     `09:11:07 PerformTopUpWorker - top-up not sent: pre-broadcast: SPV client not started`.
6. History row created: "Topup Fee -0.001003"; detail sheet shows "Sent from yZttKKDqz34Gw33k8jcq6wSxMeaLPXUzWM /
   Sent to ybeiJXuZU5QGynbCEquMiAUALBJh43JdRb / Platform Credits / Network fee 0.00000263"
   (`BC1/39-history-rows.png`, `40-topup-tx-detail.png`).

**Explorer verification** (`https://testnet.platform-explorer.pshenmic.dev/identity/GDpXqZCFyoo3hhBwfmkNdJSBcCDpkpEpsvodLzw8o1fi`,
saved to `BC1/explorer-identity-final.json`):

| moment | credit balance | totalTopUpsAmount | totalTxs |
|---|---|---|---|
| after username registration | 2562746440 | 3000000000 | 2 |
| after top-up #1 (recovered) | 2654713420 | 3100000000 | 3 |
| after top-up #2 | 2746680400 | 3200000000 | 4 |

alias `qa12s12mixedfunds4821.dash`, `status: ok`, `contested: false`. In-app "Current Identity Balance:
0.0274668 DASH" matches 2746680400 credits exactly.

**Verdict: PASS** — the money moved, the credits landed, on-chain/Platform state matches the UI.
Four defects below, none fund-losing.

---

### NM1 — Network monitor on the upgraded wallet

| state | screen | evidence |
|---|---|---|
| dashj toggle **OFF**, synced | "Synced / Connected to the Dash network", Block headers 1,556,620, Block filters 1,556,620, Masternode list height 1,556,620, ChainLock height 1,556,620, plus "The wallet engine does not report individual peer connections." and "Peer and block lists come from the dashj diagnostic engine. Turn on dashj sync in Tools to view them." | `NM1/02-network-monitor-peers.png`, `03-network-monitor-scrolled.png` |
| dashj **OFF**, mid-replay (during reset+restore) | "Downloading filter headers **54%**", Block headers 1,556,626, **Block filters 150,999 / 1,556,626**, ChainLock 1,556,625 | `NM1/07-network-monitor-during-replay.png` |
| after 100% | back to "Synced", all four heights 1,556,626 | `NM1/08-network-monitor-replay-2.png` |
| dashj **ON** (bonus) | same summary plus a live **Peers** list (`68.67.122.58 / .2 / .32`, `/Dash Core:23.1.8.../ protocol: 70240`, RTT 64-68 ms) and a **Blocks** list | `NM1/05-network-monitor-dashj-on.png`, `06-...-blocks.png`, `04-tools-dashj-on-100pct.png` |

**Verdict: PASS.** One cosmetic inconsistency logged (D-069).

---

## Defects found

| ID | Sev | Title | Repro steps | Evidence | Suspected area |
|---|---|---|---|---|---|
| **D-068** (confirmed + extended) | **S1** | Ex-CoinJoin funds are counted but completely unspendable after the 11.9.0 -> 12.0.0 upgrade, and the one UI that could rescue them is hard-suppressed | 1. master 11.9.0, fund 1 tDASH; 2. Settings > CoinJoin > Intermediate > Start Mixing until a CreateDenomination tx exists; 3. `install -r` fix 12.0.0, unlock; 4. Send 0.001 to own address | `S12/CJ1/post-upgrade/12,13,14*.png`, `21-shield-result.png`, `insufficient-funds-log.txt`, `shield-failure-log.txt`, `cj1-send.mp4`, `cj1-shield.mp4` | `CoinJoinFundsMigrationService.kt:118/425` (`MIXED_FUNDS_PROMPT_HARD_SUPPRESSED`) + SDK coin selection ignoring `AccountType::CoinJoin` for spends and asset locks |
| D-068a | S3 | Send says "Balance: DASH 0.00" while the shield screen simultaneously says "From Dash Wallet 0.99997138" for the same funds, then fails at PIN — the user is invited into a transfer that provably cannot work | as D-068, then Payments > Internal > Shielded balance | `CJ1/escape-hatches/02-shield-max.png` vs `01-send-max.png`, `04-shield-max-result.png` | shielded transfer VM reads the total balance, not the asset-lock-selectable balance |
| D-068b | S4 | Persisted `coinjoin_mode=INTERMEDIATE` survives the upgrade in `files/datastore/coinjoin.preferences_pb`, orphaned — never read, never migrated, never cleared (confirms SR-27) | dump the datastore before and after `install -r` | `CJ1/pre-upgrade/coinjoin-datastore-master-mixing-on.bin` vs `CJ1/post-upgrade/coinjoin-datastore-fix-after.bin` | CoinJoin removal commit left `CoinJoinConfig`'s datastore behind |
| **D-069** | S4 | Network monitor shows "Downloading filter headers 54%" while the "Block filters" row reads 150,999 / 1,556,626 (~10%) — headline percentage and counter disagree by ~44 points | Tools > Network monitor during a post-restore replay | `S12/NM1/07-network-monitor-during-replay.png` | network-monitor progress binding |
| **D-070** | S3 | The 60 s auto-lock fires on the Buy-Credits confirm sheet and silently cancels the top-up — no error, no "cancelled" message, user dropped back on the amount screen | Tools > Credits > Buy -> 0.001 -> Send -> PIN -> wait ~60 s on the confirm sheet | `S12/BC1/31-buy-progress-1.png`, `33-after-unlock-buy.png` | `AutoLogout` vs `BuyCreditsFragment` confirm dialog (pairs with D-001) |
| **D-071** | S3 | A top-up that hits `Dapi client error: no available addresses to use` broadcasts the asset lock anyway and tells the user "Your top-up may have gone through. Please don't try again" — funds locked on L1 with no in-UI progress until a background worker recovers it 91 s later | Tools > Credits > Buy -> 0.001 -> Send -> PIN -> Confirm when DAPI has no reachable address (reproduced right after a network off/on cycle) | `S12/BC1/34-topup-unconfirmed-message.png`; log `09:03:49` ... `09:05:20`; asset lock `fee3034fcb25bf0cbc2a78a8cffbc30acfc4e708aa34e5a0ae50316041cdb316` (type 8, 0.001 locked) | `PerformTopUpWorker` / `SdkTopUpRecoveryService`; recovery works, but the user-facing window is an unbounded "may have" |
| **D-072** | S4 | Tools > **Credits** row never shows a credit balance — only the title, an info icon and a "Buy" link — even with 2.7G credits on the identity | More > Tools, look at the Credits row | `S12/BC1/23-tools-credits.png`, `50-tools-after-success.png` | `tools_credits_title` row has no balance binding |
| **D-073** | S4 | "Current Identity Balance" on the Buy Credits screen is stale after a successful top-up (still 0.02562746 when the identity is already at 0.02654713); only a relaunch refreshes it | buy credits, then reopen Buy Credits without killing the app | `S12/BC1/36-buy-credits-after-success.png` vs `42-buy-credits-balance-refreshed.png` | Buy-credits VM does not re-read the identity balance after a credited top-up |
| D-074 | S4 | Buy Credits amount field silently clamps below-minimum input back to 0.001 with no message | Tools > Credits > Buy, try to type 0.0001 | `S12/BC1/29-buy-below-min.png` | same pattern as D-032 |

**Existing defects re-confirmed on this stream**
- **D-001** (auto-lock after 60 s) — hit repeatedly; see D-070 for a functional consequence.
- **D-003 / SR-03** — after reset + restore on the fix build the Receive tab hands out the already-used index-0
  address `yVYBPPn2zy1KKRUD88wywwXHnKEo7X83H4` again (`CJ1/restore/09-receive-after-restore.png`). The wallet
  created on master then upgraded DID rotate (`yiejB3PxsnjX14qHQfiC3tbkPw37fi14Gz`), matching S7.
- **D-006** — "I accept" text label not tappable on the username confirm sheet; only the checkbox square works.
- **D-024** — `dashpay.preferences_pb` holds `cutover_state CUT_OVER`, never SETTLED.
- **D-020** NOT reproduced: the mixing txs render as a sensible "Mixing Transactions / 4 transactions" group.

## Environment problems (not product defects)
- **ENV-6 (new):** testnet CoinJoin mixing does not complete. Over 21 min every session ended
  `POOL_STATE_ERROR "Session not complete!"` / `TIMEOUT` against `68.67.122.*`; `getMixingProgress` stayed
  `0.0 / 53`. Denominations ARE created, so the m/9' bucket is reachable, but fully-mixed coins are not
  obtainable on this testnet today. CJ1 was exercised with denominated-but-0-round coins.
- **ENV-4** re-confirmed: `adb root` inside the helper subcommands restarts adbd; `logcat-start` survived here
  only because root was already active.
- Faucet used exactly once (web UI, per the brief's update). No 429.
- The lock-screen keypad shifts ~65 px down once a "Wrong PIN!" line appears, so cached tap coordinates mis-hit
  and burned 3 PIN attempts (one 1-minute "Wallet disabled" lockout). Tooling issue, not a product bug.

## Not run / blocked, with reason
- **Mixed-funds migration UI paths** (dismiss/back, keep-spendable, move-to-shielded, in-progress, failure +
  restart, unconfirmed, re-trigger, "done" latch): unreachable — `MIXED_FUNDS_PROMPT_HARD_SUPPRESSED = true`
  at `CoinJoinFundsMigrationService.kt:118` gates both `shouldPrompt()` and `showOnce()`.
- **Fully-mixed (round > 0) coins at the cutover**: not obtainable — see ENV-6. The tested state is the CoinJoin
  account holding denominations at 0 rounds, which is what both detector sources read.
- **`identity_processing_waiting_confirmation` / `identity_..._network_catching_up`**: not observed — username
  registration completed in under 10 s, before the 60 s airplane-mode window could be applied. The offline
  banner and the offline top-up refusal (`pre-broadcast: SPV client not started`) were captured instead.
