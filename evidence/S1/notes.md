# S1 QA notes (emulator-5554 / dw-qa1)

2026-09-19T00:09:32 start of session
2026-09-19T00:09:42 installed fix-12.0.0 (versionCode 12000000) on emulator-5554; logcat+memlog started

## A1 step 1 - wallet creation
- 12-word security level chosen, PIN 1234 set (entered + confirmed).
- RECOVERY PHRASE (throwaway testnet wallet):
  `[seed phrase redacted]`
- NOTE: screenshot of the recovery-phrase screen is BLACK (FLAG_SECURE) -> expected/correct security
  behaviour; the words were captured from the uiautomator dump instead
  (evidence: A1/01-onboarding/07-recovery-phrase.png is black by design, text recorded here).
2026-09-19T00:11:51 recovery phrase recorded
2026-09-19T00:14:25 reached home screen, balance 0
2026-09-19T00:14:48 receive address #1: yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52

## A1 step 2 - faucet
- qa-faucet.sh FAILED: Cloudflare 1010 "browser_signature_banned" for the headless Playwright UA
  (environment issue, not a product defect). Used the studio browser (real Chromium) on
  https://faucet.thepasta.org instead; ONE request only.
- Faucet txid: 7efffea3f48e144dbe6f13ae0eb491c67d1018a9e890bd11fa47e8b68abed4d2  (1 tDASH -> yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52)
2026-09-19T00:15:33 faucet sent 1 tDASH

## A1 step 2 results
- Received 1.00 tDASH, txid 7efffea3f48e144dbe6f13ae0eb491c67d1018a9e890bd11fa47e8b68abed4d2
- wallet.log 05:15:24 Detected(...) then InstantLocked(...) -> "display row flipped pre-block" (instant receive worked)
- Explorer confirms balance 1, 1 tx (A1/02-receive/07-insight-addr.json)
- Home balance: 1 tDASH / $61.03 (A1/02-receive/04-home-after-faucet.png)
- SUSPICIOUS log 05:18:23 (when tx detail sheet was opened):
  "WalletTransactionMetadataProvider - txmetadata for 7efffea3... DROPPED - no wallet tx and no fallback row;
   any platform metadata for this transaction will not be displayed"  -> re-check under C5
- Also at 05:11:17: "cutover UI active but the engine wallet-event tap is not running ... instant receives degrade"
  (transient at startup; tap was running by 05:15)

## A1 step 3 - shield (max) 00:19-00:22
- Entry point is NOT in More (the More "Shielded" card is display-only, tapping does nothing).
  Real entry: Payments tab -> "Internal" tab -> "Shielded balance"  (PaymentsInternalFragment ->
  ShieldedBalanceActivity). Evidence A1/03-shield/02..04.
- Explainer sheet "Transfers take different times" shown once (05-shielded-balance-screen.png).
- Max -> "You will transfer ~ 1.00"; Confirm sheet shows only "Total 1.00 D" - NO fee line at all
  (08-confirm.png).
- PIN -> transfer completed in ~8 s (no "stalled" notice appeared).
- RESULT (15-shielded-screen-after.png):
    transparent (Dash Wallet) = 0.00000737   <-- dust left by "Max"
    shielded                  = 0.99786148
    total                     = 0.99786885  (started 1.00000000, total cost 0.00213115)
- tx row: "Shielded  -0.99999263", detail: network fee 0.00000263, sent to
  yTzpYDy771R7Q4aNrBJqCQTKdPAFFVJov1 with OP RETURN (asset lock). (14-shield-tx-detail.png)
  => the shielded-side (platform) cost of 0.00212852 is disclosed NOWHERE in the UI.
- wallet.log 05:21:58: "shielded shieldFromWallet rejected pre-broadcast (no lock tracked)" +
  ShieldedTransferExecutor "max shield auto-adjusting for L1 asset-lock fee: requested 1,
  reserve 1000 duffs (1 UTXOs), retrying once with 0.99999"  -> first attempt fails, auto-retry
  succeeds (user-invisible, but it logs a full stack trace).
- video: A1/03-shield/s1-shield-1.mp4
USERNAME=qa1s13939

## A1 step 4 - username 00:24-00:27
- Flow: Home -> Join DashPay -> Welcome -> payment option (Shielded balance) -> voting explainer ->
  Create your username -> Confirm sheet (0.03 D / $1.84 "from shielded balance") -> I accept -> PIN.
- Username: qa1s13939 (contains digits 2-9 => non-contested; app explainer confirms the rule).
- "Username is available" shown live (07-username-typed.png).
- Registration completed in ~30 s: home shows "Hello qa1s13939, Your account is ready"
  (13-home-username-ready.png). wallet.log 05:26:58
  BlockchainIdentityData(DONE, qa1s13939, CONFIRMED, ..., DYjxDk3kTzf2PXAK3LfGj2cWitnyLKhx1y8u3626hbMm)
- Identity: DYjxDk3kTzf2PXAK3LfGj2cWitnyLKhx1y8u3626hbMm
- VERIFIED on https://testnet.platform-explorer.pshenmic.dev :
  alias qa1s13939.dash status ok contested=false, totalTopUpsAmount 3000000000 credits (=0.03 DASH)
  (A1/04-username/14-explorer-identity.json, 15-explorer-dpns.json)
  NOTE: the brief's URL platform-explorer.pshenmic.dev is MAINNET; testnet is the testnet. subdomain.
- DEFECT CANDIDATE: the "Welcome to Dash Pay" screen says "You have 0.00000737 Dash. Some usernames
  cost up to 0.25 Dash." -- it reports only the TRANSPARENT balance and ignores the 0.99786148
  shielded balance that actually funds the username (02-welcome-balance-note.png).
- MINOR: the "I accept" label is not clickable, only the checkbox square itself is (09/10).
- video: A1/04-username/s1-username-1.mp4
- written to shared/usernames.txt

## A1 step 5 - reference state before reset (00:30)
- transparent (Dash Wallet) = 0.00000737   (A1/05-before-reset/02-exact-balances.png)
- shielded                  = 0.96786148   (exactly 0.03 less than after shielding -> username fee)
- username qa1s13939 shown on More + home ("Hello qa1s13939, Your account is ready")
- tx list = exactly 2 rows: "Shielded -0.999993 12:21 AM" and "Received +1 12:15 AM"
  (A1/05-before-reset/04-txlist-scrolled.png). The 0.03 username payment from the shielded pool
  produces NO history row.
- wallet.log pulled: A1/05-before-reset/wallet.log

## A1 step 6 - reset (00:32)
- More > Security > Reset Wallet -> "Are you sure..." dialog -> Cancel works, returns to Security
  (A1/08-negative/01-reset-cancelled.png).
- Second attempt -> "Reset wallet" -> a SECOND dialog "Do you want to reset wallet without saving
  your metadata to the network?" (A1/06-reset-restore/04-metadata-dialog.png).
- *** DEFECT: choosing "Save data and reset wallet" wiped the wallet IMMEDIATELY with NO PIN
  prompt at all. The whole reset path never asks for the PIN. (recording s1-reset-1.mp4,
  screenshots 03-reset-dialog / 04-metadata-dialog / 05-after-save-data.png = onboarding screen)
  -> the "wrong PIN on reset" negative check could NOT be performed: there is no PIN step.
- wallet.log 05:32:40 PublishTransactionMetadataWorker - publish txmetadata successful:
  TxMetadataSaveInfo(itemsSaved=0, itemsToSave=0)  (nothing actually saved)
- wipe itself is clean: 05:32:42 L1ShadowSyncService wallet-wipe SDK cleanup ... deleted SPV dataDir
  (21 files), SdkWalletBinder reset, databases cleared (isWalletWipe = true), OnboardingActivity
  "reset finished - re-running the onboarding routing". No crash.
2026-09-19T00:37:56 submitting real restore phrase

## A1 step 8 - negative restore checks (00:35-00:40)
NOTE: `adb shell input text` needs %s for spaces; first pass only entered one word. Re-ran all three
correctly (field content verified with a uiautomator dump each time).
- malformed word ("swampx ..."): Error dialog, no crash   A1/08-negative/10-neg1-malformed-word.txt
- 11 words:                      Error dialog, no crash   A1/08-negative/11-neg2-eleven-words.txt
- bad checksum ("... abandon"):  Error dialog, no crash   A1/08-negative/12-neg3-bad-checksum.txt
- ALL THREE produce the identical, unhelpful string:
  "Wallet could not be restored:\n\nError\n\nBad recovery phrase?"  -- the middle line is a literal
  placeholder "Error", not a reason; the user is never told which word/what is wrong.
- back-press from the restore screen -> onboarding; again -> launcher. Process survives every time
  (same pid 6111, `procstat`). No crash.
- NOTE: the Recover Wallet screen is FLAG_SECURE, so its screenshots are black by design.

## A1 step 6b - restore (00:41)
- Restore wallet -> phrase -> Set PIN 1234 (x2) -> notifications dialog -> home "Syncing 6%"

## A1 step 7 - after restore (00:43-00:47)  === ASSERTIONS ===
Restore sync: submit 00:38 -> "Syncing 6%" -> "Syncing 55%" (30 s) -> complete by ~00:43 (~5 min).
| item | before reset (step 5) | after restore (step 7) | verdict |
|---|---|---|---|
| transparent | 0.00000737 | 0.00000737 | MATCH |
| shielded    | 0.96786148 | 0.96786148 | MATCH |
| username    | qa1s13939 (More + avatar) | qa1s13939 (More + avatar) | MATCH |
| tx list     | 2 rows: Shielded -0.999993, Received +1 | same 2 rows, same amounts | MATCH |
| tx time     | Shielded row "12:21 AM" | Shielded row "12:30 AM" | DIFFERS |
- The time difference is explained: insight says the shield tx 370807cc... was mined at
  2026-09-19T00:30:27 (A1/07-after-restore/04-insight-shieldtx.txt). Pre-reset the row showed the
  first-seen/broadcast time (00:21), post-restore it shows the block time (00:30). Amounts, fees,
  balances and ordering are identical. Recorded as a defect (display-source inconsistency), S4.
- Evidence: A1/07-after-restore/03-home.png, 05-more.png, 06-exact-balances.png,
  wallet.log in A1/07-after-restore/files/log/, video s1-restore-2.mp4
2026-09-19T00:47:41 A1 complete, starting Tier C

## C4 - unshield 0.01 (00:48-00:52)
- Payments > Internal > Shielded balance > reverse arrow -> From Shielded 0.96786148 / To Dash Wallet.
- Amount 0.01; confirm sheet: "Total 0.01 D" + notice "Up to 10 minutes to spend" (C4/03-confirm.png).
  Again NO fee line.
- PIN -> shielded immediately 0.955; transparent credited ~4 min later (00:52).
- Home row: "Unshielded +0.01  12:52 AM" -> NOT stuck on "Received" in the list. GOOD.
- BUT the tx DETAIL sheet for that row says "Amount Received / +0.01 / Received at
  yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52 / Tax Category: Income" (C4/07-unshield-tx-detail.png):
  the detail treats an internal unshield as an external receive and marks it taxable Income.
- Also: the unshield landed on the SAME address as the original faucet receive
  (yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52) -> receive address did not rotate after use (see C3).
- video C4/s1-c4-unshield.mp4

## C5 - tx detail memo + tax category (00:55-00:58)
- Added Private Note "S1 memo test" (25-char limit, counter shown) and toggled Tax Category
  Income -> Transfer-in on the unshield tx.
- force-stop + relaunch + PIN -> both persisted (C5/05-after-relaunch-detail.png). No stuck "Loading".
- PASS
ADDR2=ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9

## C3 - receive (00:57-01:00)
- QR renders correctly with the Dash logo overlay (C3/01-receive.png).
- Username qa1s13939 shown alongside the address. Copy buttons present.
- "Specify Amount" -> keypad (USD/DASH toggle) -> receive screen with amount 0.00082369 / $0.05 and
  a FRESH address ygUWAkqbnKURkJ1mMEEh5FPKAfQmMdSUH9 (C3/05-receive-with-amount.png).
- *** DEFECT: the plain Receive tab does NOT rotate its address after use. It still offers
  yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52, which per insight already has 3 txs / 1.01 received
  (C3/02-insight-addr-reused.json), and the 0.01 unshield was delivered to that same address.
  The "Specify Amount" path does hand out a fresh address, so it is the Receive tab specifically.
2026-09-19T01:02:12 retry send after SendEngineNotSyncedException

## C1 - send 0.001 to own fresh address (01:00-01:05)  === D-029 detail ===
Sequence and timings (wall clock / wallet.log clock is +5h):
- 00:57  last user action before the attempt (receive/specify-amount screens).
- 01:01:00 (log 06:01:00) BlockchainServiceImpl "serviceJob cancelled after 4 minutes" and
  L1ShadowSyncService "L1ShadowLifecycle STOPPED after 4m7s up; all four loops torn down ...
  Nothing runs until the next startIfEnabled()."  The app was FOREGROUND and idle the whole time.
- 01:01:26 first Send attempt (0.001 to my own address ygUWAkqb...). UI showed NO sync banner: the
  home header read a plain balance, the send screen read "Balance: DASH 0.01000737 ~ $0.61", and
  immediately before the teardown the log said phase=SYNCED 100.0% headers 1556573/1556573
  filters 1556573/1556573 (05:57:29). So from the user's point of view the wallet was fully synced.
- The send failed with a modal: "Problem sending coins! Currently payments are not possible because
  the wallet is not fully synced with the network" (C1/08-after-confirm.png).
  wallet.log:  SdkL1SendService - SDK l1Send not attempted (L1 funding gate closed: SDK L1 engine
  not running); using dashj  ->  de.schildbach.wallet.payments.SendEngineNotSyncedException:
  cutover committed but the SDK engine cannot fund a send yet (SendCoinsTaskRunner.kt:172/451)
- RETRY #1 at 01:02:40, ~74 s later, same screen, same amount: FAILED IDENTICALLY (same modal, same
  exception at 06:02:40). Re-entering the flow does not restart the engine.
  (C1/09-send-blocked-log.txt, C1/11-after-retry-confirm.png)
- RECOVERY: only a force-stop + relaunch fixed it. After relaunch, 06:03:14 "L1 shadow SPV started"
  then phase=SYNCED, and the identical send succeeded at 06:05:00.
  => user-visible impact: after ~4 minutes idle, sending is impossible and the app blames "not
  fully synced" while showing a synced UI; the only workaround is to kill and reopen the app.
- Successful send: txid bd9fc16db9a662e2f593d3e83403f04fdd558e6c737df6748b8e9f8722ffcc50,
  InstantLocked within 1 s of broadcast (log 06:05:00). Home row "Internal -0.000002 1:05 AM"
  (correct sign + correctly classified internal, not a receive). Balance 0.01000737 -> 0.01000511.
  NOTE also logged: "peergroup not available, not broadcasting transaction" from BlockchainServiceImpl
  (harmless - the SDK had already broadcast it) .

## SR-28 - confirm-dialog fee vs actual fee
- Send confirm dialog: "Network fee 0.0001", "Total 0.0011"   (C1/07-after-pin.png, 12-retry2-confirm.png)
- Actual on-chain fee (insight, 225-byte tx): 0.00000226   (C1/17-insight-sendtx.txt)
- Post-send detail sheet shows only "Amount Sent -0.00000226" and has NO "Sent to" row and NO
  "Network fee" row at all (C1/13-after-retry2.png), so the user cannot reconcile it.
  => the quoted fee is ~44x the fee actually paid. CONFIRMED.
- Also on that sheet: Tax Category defaults to "Income" for an OUTGOING transaction, contradicting
  the app's own explainer "Outgoing transactions by default will be marked as Expense"
  (C1/15-tax-explainer.png).

## D3 - contact request from S5 (01:07-01:08)
- Notification bell -> "qa5s5ebkdus2c6kkt9m7t has sent you a contact request  Sep 19, 00:43 am"
  The request was there IMMEDIATELY on first open of the bell (no waiting), and it had already
  survived my reset+restore (00:32-00:43). (D3/01-notifications.png)
- Accept -> "You have accepted the contact request from qa5s5ebkdus2c6kkt9m7t" (D3/02-after-accept.png)
- Send > Send to a Contact -> contact "QA Stream Five / qa5s5ebkdus2c6kkt9m7t" listed
  (D3/03-send-to-contact.png) -> 0.001 -> confirm "Send to QA Stream Five", fee 0.0001 -> PIN
- Result sheet: "Amount Sent -0.00100737 / Sent from ygUWAkqb... / Sent to QA Stream Five
  qa5s5ebkdus2c6kkt9m7t / Tax Category Expense" (D3/07-after-send.png) -- correct Expense default
  here, unlike the plain address send which defaulted to Income.
- Home row shows "QA Stream Five  -0.001007  1:08 AM" (name, not an address). D3/08-home-txrow.png
- shared/contact-accepted.txt written. video D3/s1-d3-contact.mp4

## SR-30 - "Max" on the shielded -> Dash Wallet direction (01:09-01:15)  CONFIRMED (with caveat)
- Max filled the FULL shielded balance 0.95510957 with no fee reserve; confirm sheet said
  "Total 0.95510957 D" (SR30/01, SR30/02).
- wallet.log 06:10:44:
  ShieldedBalanceServiceImpl - shielded withdrawToCore rejected pre-broadcast (notes released)
  DashSdkError$PlatformWallet$WalletOperation: shielded withdraw failed: Insufficient shielded
  balance: available 95510957600, required 95786148200
  ShieldedTransferExecutor - max withdraw auto-adjusting for shielded fee: requested 0.95510957,
  deficit 275190600 credits, retrying once with 0.95235766
  => the amount Max offers can NEVER succeed as-is; it always fails once and is rescued by a single
  silent auto-retry. Same pattern as the shield direction (05:21:58 "no lock tracked" + retry).
- Net effect for the user: it works, but silently transfers ~0.00275 less than the amount shown and
  confirmed, and the failure/retry is invisible except in the log.
- Final: Dash Wallet 0.961, Shielded 0.000 (SR30/04-after-wait.png). Arrival took ~4 min.
- video SR30/s1-sr30-max.mp4

## C6 - payment URI (01:16)
- `dash:yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52?amount=0.001` -> Send screen pre-filled with the address
  and amount 0.001 / $0.06 (C6/01-deeplink-prefilled.png). PASS
- `dash:NOTAVALIDADDRESS123?amount=0.001` -> "Invalid Dash URI: ..." dialog, no crash
  (C6/02-invalid-uri.png). PASS

## C7 - Tools (01:17-01:22)
- Tools list: Address book, Import private key, Network monitor, Extended public key (BIP44),
  Masternode keys, CSV export, Credits, ZenLedger, "dashj sync (diagnostic)" toggle. (C7/01-tools.png)
- Address book: opens, "YOUR ADDRESSES"/"SENDING ADDRESSES" tabs, "No entries in address book".
  (C7/02-address-book.png)  Note: it does not list the wallet's own used addresses.
- Extended public key (BIP44): shows
  tpubDCogyfuWnNo3aGvXQKdvngB5BJfgYCAnnrkFAiWvCJYP267nrH8PXJxDPiE1T6KnR1qkPv5DBxzPzoZETqA1ReSa1GDZbVpN3HQxwnTaPcD
  + "Share key". Correct testnet tpub prefix. (C7/03-xpub.png)  PASS
- CSV export: "Export transactions" -> share sheet with dash-wallet-transactions-2026-09-19.csv.
  File pulled to C7/06-export.csv. Contains 5 rows. ISSUES:
    * the internal self-send bd9fc16db9a662e2f593d3e83403f04fdd558e6c737df6748b8e9f8722ffcc50
      ("Internal -0.000002" in the app) is MISSING from the export;
    * the Fee / Fee Currency columns are EMPTY on every row;
    * the max-unshield 0.95235766 from my OWN shielded pool is exported as "Income".
  The manually set "Transfer-in" category on the 0.01 unshield did carry through correctly.
- Import private key: only "Scan Private Key" (camera). There is NO paste / manual-entry field, so a
  WIF cannot be imported without a QR. BLOCKED on the emulator (no camera source able to present a
  QR; restarting the AVD with a virtual-scene poster is out of scope). (C7/07, C7/08, C7/09)
  Error handling partially covered: feeding the generated testnet WIF as a URI
  (`dash:cW12Zk...`) -> "Invalid Dash URI" dialog, no crash (C7/10-wif-as-uri.png).

## C2 / SR-29 - send-all & drain (01:22-01:26)
(a) Send-all to an address (my own ygzkrgSc...):
  - Max filled 0.9613554 (whole balance); confirm sheet "Network fee 0.0001, Total 0.9613554".
  - wallet.log: SendCoinsViewModel "executeDryRun finished (cutover-aware: SDK send-all / drain)"
    then SendCoinsTaskRunner "routing the SendRequest payment via the SDK bridge (96135540 duffs
    to ygzkrgSc..., send-all)" then SdkL1SendService "l1SendAll: broadcast 96135540 duffs ...
    txid 9981b17d1f064f1404de5c2bd766a2cd96f9ccade68a42a39c089ad10ff87bd5".
  - SR-29: NO failed first attempt and NO retry. Single broadcast, succeeded. Claim NOT reproduced
    for the transparent send-all path. (C2/05-sendall-log.txt)
  - Actual cost 0.0000068 (680 duffs) vs the 0.0001 quoted -> same SR-28 fee-quote mismatch.
  - Every transparent UTXO was consumed; no dust left behind on the source addresses.
(b) True drain, transparent -> shielded with "Max":
  - Max offered 0.9613486 (the whole balance, no reserve).
  - wallet.log 06:25:17: ShieldedBalanceServiceImpl "shielded shieldFromWallet rejected
    pre-broadcast (no lock tracked)" + ShieldedTransferExecutor "max shield auto-adjusting for L1
    asset-lock fee: requested 0.9613486, reserve 1488 duffs (3 UTXOs), retrying once with 0.96133372"
  - RESULT: transparent = 0.00001225 (1225 duffs of DUST), shielded = 0.95920521.
    The transparent balance does NOT drain to zero; the reserve (1488 duffs for 3 inputs) is much
    larger than the fee actually paid, and the remainder is stranded. Same as the first shield
    (737 duffs stranded). (C2/07, C2/08, C2/09-home-drained.png, C2/10-exact-after-drain.png,
    C2/11-drain-log.txt)
  - videos C2/s1-c2-sendall.mp4, C2/s1-c2-drain.mp4
