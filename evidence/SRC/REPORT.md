# SRC — SR device-reproduction report (transparent Send path, FIX build)

**Note:** my harness blocked writing `$QA_EVIDENCE/SRC/REPORT.md` (subagents may not write report files), so the full report is below — please save it to that path. All evidence files, screenshots, videos, greps and `notes.md` are on disk under `/Users/dcg/workspace/dash-wallet-qa/evidence/SRC/`.

## Header

| | |
|---|---|
| Emulator | `emulator-5558`, AVD **dw-qa3**, Android 15 (API 35). The AVD was **not running** at task start — I started it myself with the same flags as the others. |
| APK under test | `fix-12.0.0-testnet3-release-signed.apk`, versionName 12.0.0, **versionCode 12000000** |
| Baseline | `master-11.9.0…` (vc 11090002) — **not installed**, see "Not done" |
| Engine | **cutover committed** all session (`BlockchainServiceImpl - cutover committed — holding the dashj L1 engine; SDK owns L1 this launch`), so every send took the SDK route |
| Seed (QA throwaway, created by me) | `result service coyote mass various shield plastic water subject vacant tree legend`, PIN 1234 (`setup/SEED.txt`) |
| Funding | 2 × 1 tDASH from faucet.thepasta.org: `057b1808…410b` → `yVuNuykoLNRt4X4WpmyvyF47LNqEKn83Df`; `c6fe82fd…7e41` → `yQJ66b2xF2EzXpiyYGYzQ8P8vP4RBp3Bic` |
| Destination | `yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52` (S1 throwaway) |
| Session | 11:40 → 12:52 CDT 2026-09-19 (app log timestamps are UTC = local + 5 h) |
| Session artifacts | `logcat.txt` (117k lines), `mem.csv` (66 samples, 452 MB PSS at end), `logs/files/log/wallet.log` (814 KB), `notes.md` |

All `wallet.log` quotes are from `/data/data/hashengineering.darkcoin.wallet_test/files/log/wallet.log`, pulled to `evidence/SRC/logs/files/log/wallet.log` and copied into each `SR-*/logs/`.

## Verdict table

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| **SR-19** memo + exchange rate dropped | **REPRODUCED** | BIP21 deeplink with `label=Bob&message=SR19memo`, sent 0.01; 4 further SDK sends | `SR-19/06-grep-memo-exchangerate.txt`, `SR-19/17-grep-txmetadata-all.txt`, `SR-19/05-txdetail-no-memo-no-fiat.png` | 5/5 sends stored `memo=`, `currencyCode=null`, `rate=null` **and `value=0`**. Control: a hand-typed note *is* stored |
| **SR-28** flat 0.0001 fee + affordability gate | **REPRODUCED** | Confirm-sheet fee vs on-chain fee; probed the typed-amount gate at 4 values | `SR-28/numbers.txt`, `SR-28/01-confirm-0.01-fee-shown.png`, `SR-28/03-explorer-tx-0.01.json`, `SR-28/13-typed-98994774.png` | 10 000 duffs shown vs 226 real = **44.2×**; typed amounts near the balance silently rewritten, **no error** |
| **SR-29** send-all fails first attempt | **REPRODUCED (twice)** | Two independent Send-Max flows 34 min apart | `SR-29/05-grep-sendall.txt`, `SR-29/11-grep-both-max.txt`, `SR-29/ANALYSIS.txt`, `SR-29/sr29-max1.mp4` | Reserve 339 vs real fee 384 → 45-duff shortfall, identical both runs |
| **SR-32** Max has no replay hold | **PARTIAL** | 2 reset+restore replays, header polled 6–15 s, Max read on Send screen | `CutoverUiDataService.kt:2400-2413`; `SR-32/timeline.txt`, `SR-32/08-max-after-auth.png` | Code confirmed (no `_l1Synced` term); visible divergence masked by SR-10 |
| **SR-10** hold-last-known inert | **REPRODUCED** | Reset + restore same seed ×2, header sampled through replay | `SR-10/restore2-timeline.txt`, `SR-10/02-grep-published-after-restore2.txt`, `SR-10/r01..r04-header.png` | Header **0** at 15/32/44/54 % while the wallet held 1 tDASH |
| **SR-16 / SR-17** drain guard / lock registry | **PARTIAL** (inert half confirmed) | 0.01 send → 0.005 on the unconfirmed change (+62 s) → Send-Max on it (+115 s) | `SR-16-17/07-grep-locks.txt` (**0 matches session-wide**), `SR-16-17/timeline.txt`, `sr1617.mp4` | No lock/pending error ever; guard never fired or logged |
| **SR-18** Coinbase estimateNetworkFee | **BLOCKED** | Buy & Sell → Coinbase → Link → explainer → OAuth | `SR-18/VERDICT.txt`, `SR-18/02-buysell.png`, `SR-18/05-oauth.png` | Build has **no Coinbase keys**; `TransferDashFragment` unreachable. 9 min spent |

## Numbers: shown fee vs real fee

| # | Send | txid | shown "Network fee" | real fee (insight) | size / in / out | ratio |
|---|---|---|---|---|---|---|
| 1 | 0.01 plain (BIP21 memo) | `aa659fc9…4ccc` | **0.0001** (10 000 duffs) | **0.00000226** (226) | 225 B, 1-in 2-out | **44.2×** |
| 2 | Send-Max #1 | `61dd9f06…9aef` | **0.0001** | **0.00000384** (384) | 191 B, 1-in 1-out | **26.0×** |
| 3 | 0.01 plain | `fcb3231e…f5a0` | 0.0001 | 0.00000226 | 225 B, 1-in 2-out | 44.2× |
| 4 | 0.005 (spends unconfirmed change) | `b6109773…bb0d` | 0.0001 | 0.00000226 | 226 B, 1-in 2-out | 44.2× |
| 5 | Send-Max #2 | `fd5d4dff…9db1` | **0.0001** | **0.00000384** | 191 B, 1-in 1-out | **26.0×** |

Raw: `SR-28/03-explorer-tx-0.01.json`, `SR-29/12-explorer-fees.txt`.

## Numbers: header vs Max across a replay (restore #2)

| local time | sync label | header | header fiat | Max | true balance | file |
|---|---|---|---|---|---|---|
| 12:36:37 | "Syncing balance" | `0` | `$ 0` | — | 1.00000000 | `SR-32/07-after-restore.png` |
| 12:36:49 | Syncing **15 %** | `0` | `$ 0` | — | 1.00000000 | `SR-10/r01-header.png` |
| 12:37:01 | Syncing **32 %** | `0` | `$ 0` | — | 1.00000000 | `SR-10/r02-header.png` |
| 12:37:10 | Syncing **44 %** | `0` | `$ 0` | — | 1.00000000 | `SR-10/r03-header.png` |
| 12:37:21 | Syncing **54 %** | `0` | `$ 0` | — | 1.00000000 | `SR-10/r04-header.png` |
| 12:40:46 | (gone) | `1` | — | — | 1.00000000 | `SR-10/r99-final.png` |

Restore #1, single sample: 12:26:06 header `0`, `Syncing 24 %`, true balance 1.0 (`SR-32/timeline.txt`). Once `l1Synced=true`, header `1` and Max `1` agree (`SR-32/08-max-after-auth.png`).

---

## Detail

### SR-19 — memo and exchange rate dropped on every SDK-routed send — REPRODUCED (S2)

`dash:yRjAzoyf…?amount=0.01&message=SR19memo&label=Bob` → `PaymentIntent.fromPaymentUri` (`common/src/main/java/org/dash/wallet/common/data/PaymentIntent.java:270`) maps BIP21 **`label=`** onto `PaymentIntent.memo`, so the intent carried memo `Bob`. After sending, the tx detail shows **"Private Note — Add Note"** (empty) and no fiat value.

```
16:57:02 [DefaultDispatcher-worker-7] WalletTransactionMetadataProvider - txmetadata: inserting
  TransactionMetadata(txId=aa659fc9ab82b67a6741e3e88db4fa1e3ef45de3360d33a77e9b0db872854ccc,
  timestamp=1789837021819, value=0, type=Sent, taxCategory=null, currencyCode=null, rate=null,
  memo=, service=null, customIconId=null)
```

All **five** sends produced the identical shape (`SR-19/17-grep-txmetadata-all.txt`). Control ruling out "the store is unused": I typed a note by hand on `fd5d4dff` and the store accepted it at once —
```
17:48:05 TxDisplayCacheService - metadata re-decorated 1 wrapperless row(s): fd5d4dff memo=11 chars
```
So the store works; the send funnel never supplies `sendRequest.memo` / `.exchangeRate` (set at `SendCoinsViewModel.kt:283-284`, discarded because `SendCoinsTaskRunner.kt:1179` routes to `sendViaSdkBridged(address, amount, …)` at `:437`, whose signature carries only address/amount/emptyWallet).

### SR-28 — flat 0.0001 fee, shown *and* used as the gate — REPRODUCED (S3, arguably S2)

`SEND_ALL_FEE_RESERVE_DUFFS = 10_000L` (`SdkL1SendService.kt:216`) does both jobs.

(a) Display: confirm sheet `Network fee 0.0001`, `Total 0.0101`; tx paid 226 duffs. Post-cutover the dry-run never runs `completeTx`, so `SendCoinsFragment.kt:295` (`dryRunRequest.tx.fee ?: viewModel.dryRunFeeEstimate`) always falls back to the constant.

(b) Gate. Spendable (Max) was **0.98999774**:

| typed | shown ~1 s later |
|---|---|
| `0.98994774` (bal − 0.00005) | **0.98989774** |
| `0.9899` | **0.98989774** |
| `0.98999774` (exact balance) | **0.98989774** |
| `0.9899999` | **0.98989774** |

Everything above `balance − 10 000 duffs` collapses to exactly `balance − 10 000 duffs`, with **no error text, dialog or toast** — the Send button stays enabled on the reduced number. Mechanism: `SendCoinsViewModel.kt:519` `throw InsufficientMoneyException(amount.add(feeReserve).subtract(maxOutput))` feeding `:345-346` `val adjusted = currentAmount.subtract(missing)`. Stranded per typed send: 10 000 − 226 = **9 774 duffs** (43× the real fee). The Max button is exempt (fills the full balance, routes as a drain).

### SR-29 — every send-max fails its first attempt — REPRODUCED twice (S3)

Run 1, 12:11 local, one 98 999 774-duff UTXO:
```
17:11:47 SendCoinsTaskRunner - cutover committed: routing the SendRequest payment via the SDK bridge (98999774 duffs to yRjAzoyf…, send-all)
17:11:47 SdkL1SendService - SDK l1SendAll: floor 98999435 duffs not deliverable at fee; retrying engine-authoritatively
org.dashfoundation.dashsdk.errors.DashSdkError$PlatformWallet$CoreInsufficientFunds: insufficient unreserved
  Core funds across the pooled funding sources [BIP44, BIP32, AllDashpayReceivingFunds]:
  available Some(98999774), required Some(98999819)
        at …DashSdkL1SendSource$sendAllToAddress$2.invokeSuspend(SdkL1SendService.kt:808)
17:11:48 SdkL1SendService - SDK l1SendAll: broadcast 98999774 duffs to yRjAzoyf…, txid 61dd9f06…9aef
```
Run 2, 12:45 local, after a full reset+restore and two fresh sends — a completely independent UTXO:
```
17:45:43 SendCoinsTaskRunner - cutover committed: routing the SendRequest payment via the SDK bridge (98499548 duffs to yRjAzoyf…, send-all)
17:45:43 SdkL1SendService - SDK l1SendAll: floor 98499209 duffs not deliverable at fee; retrying engine-authoritatively
17:45:44 SdkL1SendService - SDK l1SendAll: broadcast 98499548 duffs to yRjAzoyf…, txid fd5d4dff…9db1
```
Identical arithmetic both times:
- reserve = balance − floor = **339 duffs** = `sendAllFeeReserveDuffs(1)` = `(10 + 148 + 68) × 3/2` = 226 B × **1.5 duffs/B** (`SdkL1SendService.kt:225-234`)
- real fee = **384 duffs** over 191 B = **2 duffs/B** (insight)
- `required − available` = 98 999 819 − 98 999 774 = **45** = 384 − 339

The floor is short by 25 % of the fee on every send-max, independent of amount. It only completes because `SdkL1SendService.kt:1360-1374` catches the throwable, classifies it with `isSendAllShortfall()` (`:342-348`, legacy arm matching `message.startsWith("transaction build failed") && message.contains("Insufficient funds")`) and retries with floor = 1. Any change to the SDK's error type or wording turns every Send-Max into a hard failure.

### SR-32 — Send-Max has no replay hold — PARTIAL

Verbatim from `CutoverUiDataService.kt`:
```kotlin
fun overlayTotalBalance(dashjBalance: Flow<Coin>): Flow<Coin> =
    combine(_sdkTotalBalance, _l1Synced, _lastKnownTotalBalance, dashjBalance) { sdk, synced, lastKnown, dashj ->
        when {
            sdk == null -> dashj
            synced -> sdk
            lastKnown != null && lastKnown.isPositive -> lastKnown
            else -> sdk
        }
    }

fun overlayMaxSendableBalance(dashjBalance: Flow<Coin>): Flow<Coin> =
    combine(_sdkMaxSendable, _sdkTotalBalance, dashjBalance) { maxSendable, total, dashj ->
        maxSendable ?: total ?: dashj
    }
```
`overlayMaxSendableBalance` has **no `_l1Synced` term at all** — the Max feed is unconditionally the live (possibly partial) SDK figure. On device I could not make the divergence visible, and the reason is itself a finding: the header only holds when `lastKnown` is **positive**, and on a reset+restored wallet `lastKnown` is `0`, so the header falls through to the same partial. Both read `0`, then both read `1`. Producing the divergence needs a positive persisted `LAST_TOTAL_BALANCE` **and** an `l1Synced=false` window, i.e. an upgraded long-lived wallet.

Harness note: the **Max button re-triggers the reveal-balance PIN prompt** for every new `SendCoinsActivity` even with *Autohide Balance* OFF, which makes sub-15 s header/Max sampling impossible without an auth in between.

### SR-10 — hold-last-known inert on a created/restored wallet — REPRODUCED (S2)

Security → Reset Wallet → Restore with the same seed, wallet holding exactly 1.00000000 tDASH. Done twice.
```
12:36:49 HEADER="0" FIAT="$ 0" SYNC="Syncing balance" "Syncing 15%"
12:37:01 HEADER="0" FIAT="$ 0" SYNC="Syncing balance" "Syncing 32%"
12:37:10 HEADER="0" FIAT="$ 0" SYNC="Syncing balance" "Syncing 44%"
12:37:21 HEADER="0" FIAT="$ 0" SYNC="Syncing balance" "Syncing 54%"
12:40:46 HEADER="1"  (sync label gone)
```
Why:
```
17:36:25 CutoverUiDataService - SDK balance published: 0 duffs (was none) | l1Synced=false rescanArmedHold=false
         dashPayBackfill(armed=false,replaying=false) deferredContactBuilds=0 (unchangedReads=3)
         persistedAsLastKnown=false lastKnown=0
17:39:12 CutoverUiDataService - SDK balance published: 100000000 duffs (was 0) | l1Synced=false rescanArmedHold=true
         … persistedAsLastKnown=false lastKnown=0
```
`lastKnown=0` is not positive → `else -> sdk` → live partial. And `persistedAsLastKnown=false` held for the whole post-restore lifetime, because `persist = synced && !armedRescanHold && backfillStatus.settled && buildsSettled` (`CutoverUiDataService.kt:2769`) and `rescanArmedHold` was still `true` 15 min after the restore — so the restored wallet never arms the hold for its *next* launch either. Same shape right after wallet creation (`16:45:31 … 0 duffs (was none) … lastKnown=none`).

User impact: after restoring a funded wallet the header reads **0 / $0** for the whole scan, then jumps — exactly the "reads as fund loss" the hold was written to prevent, inert precisely on the wallets where it matters first.

### SR-16 / SR-17 — drain guard inert, lock registry with no release — PARTIAL

```
12:42:56  send 0.01  -> fcb3231e…f5a0, change 0.98999548 to ySexs4Je… (UNCONFIRMED)
12:43:xx  (+62 s)  send 0.005 spending that unconfirmed change -> b6109773…bb0d   SUCCEEDED
12:45:43  (+115 s) Send-Max over the still-unconfirmed change  -> fd5d4dff…9db1   SUCCEEDED
```
No "pending outputs" / "locked" / "wait for confirmation" error at any point, and a session-wide grep for `drain guard|hasAnyLocks|SeamOutputLock|locked outputs|seam-locked` over the whole 814 KB `wallet.log` returns **zero matches**. The guard neither blocked nor logged.

Consistent with SR-16: the dashj half is `wallet == null || wallet.calculateAllSpendCandidates(true, true).any { wallet.isLockedOutput(it.outPointFor) }` (`SdkL1SendService.kt:1148-1157`) evaluated against the **held** dashj wallet (empty candidate set post-cutover), and the seam half is `seamOutputLockRegistry.hasAnyLocks()` (`:1546`) over a registry whose only mutator is `lockOutput` — `SeamOutputLockRegistry.kt` exposes `lockOutput`, `hasAnyLocks`, `isLocked` and **no unlock/release/clear of any kind**, confirming SR-17's "no release API" at code level. The false-positive half was unexercisable: nothing in a plain transparent wallet produces a seam lock (needs a CrowdNode deposit).

### SR-18 — BLOCKED

Buy & Sell shows *"Keys are missing for these services. See CONFIGURATION FOR UPHOLD AND COINBASE in README.md"*. Coinbase → "Link Coinbase Account" → auth-limit explainer → "I got it" hands off to Chrome for OAuth (`mCurrentFocus=com.android.chrome/…FirstRunActivity`). `TransferDashFragment` — the caller of `estimateNetworkFee` — needs a linked account. 9 minutes spent.

---

## New defects found along the way

| id | Sev | Defect | Repro | Evidence |
|---|---|---|---|---|
| SRC-N1 | **S2** | **Every SDK-routed send is stored with `value=0` in the tx metadata store** — the amount is lost too, independent of SR-19. Anything reading `TransactionMetadata.value` (tax categorisation, CSV/ZenLedger pipeline, Platform tx-metadata sync) sees 0 for all 5 sends. | any transparent send on FIX; grep `txmetadata: inserting` | `SR-19/17-grep-txmetadata-all.txt` (5/5 rows) |
| SRC-N2 | **S2** | **Typed send amount silently reduced with no message.** Any amount within 10 000 duffs of the spendable balance is rewritten down to `balance − 0.0001` while the user watches; Send stays enabled, no error/toast/dialog. Typing "0.9899" sends 0.98989774. | Send → type any value in `(balance − 0.0001, balance]` | `SR-28/13-typed-98994774.png`, `SR-28/numbers.txt` |
| SRC-N3 | **S3** | **CSV export writes an empty Fee column** (and has no memo/fiat columns) even though both fees are known on-chain. | Tools → CSV export | `SR-19/16-csv-export.csv` |
| SRC-N4 | **S3** | **Plain-send tx detail shows no Network fee row and no fiat; drain tx detail shows both.** User cannot see what a normal send cost. | compare the two detail sheets | `SR-19/05-…png` vs `SR-29/10-max2-result.png` |
| SRC-N5 | **S3** | **"Sent to" lists the change address as a recipient** alongside the real payee. | any send with change | `SR-19/05-txdetail-no-memo-no-fiat.png` |
| SRC-N6 | **S4** | **Max re-prompts for the PIN on every new Send screen even with Autohide Balance OFF** (it triggers the reveal-balance auth path). | Autohide off; deeplink to Send; tap Max | `setup/23-autohide.png`, `SR-32/08-max-after-auth.png` |

## Environment problems

- **emulator-5558 (dw-qa3) was not running** at task start (only 5554/5556 were up). I started it with the same flags and did not touch the others.
- **dw-qa3 carried a stale wallet** from an earlier session — username `qa12s12mixedfunds4821`, 0.197871 tDASH, DashPay identity, mixed funds (`setup/04-home.png`). Mixed/CoinJoin funds would confound every item on my list, so I uninstalled and started clean; that 0.197871 tDASH is now orphaned on that seed.
- **App auto-lock is aggressive** (~60–90 s idle). A scripted digit burst once landed on the lock screen → *"Wrong PIN! 6 attempts remaining"* (`SR-28/12-trace.png`), recovered immediately. Automation must re-check for the lock screen before every input burst.
- **Faucet**: one request per address per UTC day plus an hourly cap requiring a Cap proof-of-work. Playwright `browser_click` cannot reach the Cap trigger (shadow root behind an overlay); `browser_evaluate` with a shadow-root walk works — `root.querySelector('.captcha-trigger,[part="trigger"]').click()`.

## Not done / limits

- **No MASTER (11.9.0) comparison.** By the end the wallet was drained by the SR-16/17 + SR-29 sequence and both faucet-eligible addresses had hit the per-day limit, so a like-for-like baseline send was not fundable. SR-19 is instead evidenced in-build via the manual-note control.
- SR-32's user-visible header/Max divergence — needs a wallet with a positive persisted `LAST_TOTAL_BALANCE` plus an `l1Synced=false` window.
- SR-17's "one lock refuses every send-all until process restart" — no lock producer exists in a plain transparent wallet.