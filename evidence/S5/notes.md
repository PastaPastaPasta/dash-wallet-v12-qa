# S5 journal — DashPay / Platform (emulator-5562, AVD dw-qa5)
2026-09-19T00:11:24 start: logcat + memlog started (pids 70813 / 70889)
2026-09-19T00:14:00 WALLET-A seed (throwaway testnet): [seed phrase redacted]
2026-09-19T00:17:29 D0 pre-funds: Welcome to Dash Pay shows "You need to have more than 0.03 Dash to create a username." and Continue is enabled=false. Evidence D0/02-join-dashpay-no-funds.png
2026-09-19T00:17:49 S5 receive address: yUVKHm4rtD55mQLJP2bPsMU5YZwdEabi8r
2026-09-19T00:19:01 faucet: 1 tDASH sent to yUVKHm4rtD55mQLJP2bPsMU5YZwdEabi8r txid fab296d048314082e41283b4d612ce634e4c2723c1b0bd6ca86df61bf40595ac (via studio browser; qa-faucet.sh blocked by Cloudflare 1010)
2026-09-19T00:20:48 funds arrived: 1 tDASH, home balance shows 1 / $61.06. insight confirms balance 1.0
2026-09-19T00:21:43 D0 post-funds: disclaimer removed, Continue enabled=true. Evidence D0/06-join-dashpay-funded.png
2026-09-19T00:21:43 OBSERVATION: home-screen "Join DashPay" tile present at 0 balance (D0/01,02) but ABSENT once balance=1 and a tx exists (D0/03,04). Entry still present in More tab (D0/05).
2026-09-19T00:27:44 D1 contested flow done, CANCELLED before paying. Evidence D1/20..28.
  - qatestvote classified contested (warning + "+ what is username voting?"), confirm sheet 0.25 DASH / $15.37, I accept gate works, Cancel returns to input.
  - Criteria validation: ab=too short FAIL, qa_test=invalid char FAIL, 34-char FAIL, -qatest FAIL, QAtestUpper PASS(contested).
  - NOTE: failed criteria do NOT sort to top; requirements_stack is a static LinearLayout (wallet/res/layout/fragment_request_username.xml:111).
  - NOTE: "notify you of the results on Sep 19, 2026" = today, but that is CORRECT on testnet: UsernameRequest.VOTING_PERIOD_MILLIS = 90 minutes on non-mainnet (wallet/src/de/schildbach/wallet/database/entity/UsernameRequest.kt:43). Medium date format hides the time. Not a defect.
  - Typo on identity-verification screen: "paste the link bellow" (should be "below").
2026-09-19T00:29:19 NOTE: the More screen 'Shielded' balance card is NOT clickable (uiautomator clickable=false, no shield entry point there). Shield is reached via Join DashPay -> Continue -> 'Shield your funds first'.
2026-09-19T00:31:49 D4 shield done: Dash Wallet 0.000 / Shielded 0.997 (fee ~0.003). Evidence D4/05..10. Chosen non-contested username: qa5s5ebkdus2c6kkt9m7t (len 21)
2026-09-19T00:34:56 D4 SUCCESS: username qa5s5ebkdus2c6kkt9m7t registered, 'Hello ... Your account is ready'. Shielded 0.997 -> 0.967 (0.03 fee). Evidence D4/11..21 + d4-username.mp4
D4 verified on Platform explorer (TESTNET host): https://testnet.platform-explorer.pshenmic.dev/dpns/identity?dpns=qa5s5ebkdus2c6kkt9m7t
  identity FGk3cH3u7pF1Nyfs5E1rU4g9bdmPWgoEn41Uj61Gu6M4, alias qa5s5ebkdus2c6kkt9m7t.dash, status ok, contested false.
  ENV NOTE: QA-PLAN points at https://platform-explorer.pshenmic.dev which is MAINNET (core height 2.5M); testnet needs the testnet. subdomain.
D5 PASS: display name "QA Stream Five", about me, avatar via Public URL (Gravatar URL) set, saved (wallet.log 05:39:37 "PlatformDocumentBroadcastService - broadcast profile"), visible in More, persisted across force-stop + relaunch (D5/12,13).
2026-09-19T00:44:13 D3: contact request sent to qa1s13939, UI shows 'Request sent' + activity 'Contact request sent'.
D3 watchlist log (logs/grep-watchlist-1.txt):
  05:44:50 SdkWalletBinder - "DashPay contact coverage OK on 65384bdf…: scan at 1556565 is at or below the earliest received contact height 1556565 (1 contact request(s))" -> coverage recomputed correctly after the request.
  DEFECT(S4, log noise): "DashPay receival-account coverage ... dark=0 — a dark contact's receiving addresses are in no watched script set (permanently-dark candidate ...)" is emitted every ~60s with the alarming explanatory tail even when dark=0. Source: wallet/src/de/schildbach/wallet/service/platform/sdk/SdkWalletBinder.kt:961-980 (logReceivalCoverageDiagnostics appends the sentence unconditionally).
  05:13:30 SdkWalletBinder - "address-window heal v2 applied on 65384bdf…: gaps widened, backfill coverage invalidated" (informational).
D2 invite created (private, non-contested 0.03 from shielded). Link saved to evidence/S5/invite-link.txt (+ invite-link-https.txt). Evidence D2/03..13 + d2-invite.mp4.
D6 Username Voting: opens, default-filter explainer, filter sheet works (Group by / Sort by / Type / Only duplicates / Only requests with links / Reset). List is "Nothing here" with every filter; wallet.log 05:50:47 "DapiClient - getVotePolls(...)" returns no polls -> no active contested names on testnet in the window. Evidence D6/01..08.
D7 de-DE: home, contacts, add-contact, search, edit-profile, invitations all localized (D7/02..08).
  DEFECT(S4 i18n): contacts list header "Pending Requests (1)" stays English in de-DE. String contacts_pending_sent_requests_count exists ONLY in wallet/res/values/strings-dashpay.xml:140 (no values-*/ translation) — new string on this branch.
Wallet A log pulled: evidence/S5/logs/walletA/files/log/wallet.log. 0 FATAL / OutOfMemoryError / OverlappingFileLockException.
  Notable: 05:31:17 "DashSDKException: asset lock coin selection is short: available 100000000 duffs, required 100000229 duffs" then "ShieldedTransferExecutor - max shield auto-adjusting for L1 asset-lock fee: ... retrying once with 0.99999" -> Max-shield self-heals, user saw no error.
  "SdkBindRetryService - SDK bind established" on every launch; no bind blockers.
D3 final state at 06:00: still "Contact Request Pending" (S1 had not accepted).
2026-09-19T01:03:15 WALLET-B seed (throwaway): [seed phrase redacted]
2026-09-19T01:05:13 opening invite deeplink on wallet B
D7 German username-request screen captured (D7/15-de-username-request.png): "Benutzernamen erstellen", criteria localized.
  DEFECT(S4 i18n typo, pre-existing): "DashPay beitreiten" should be "beitreten" — wallet/res/values-de/strings-dashpay.xml:158 (upgrade_to_evolution_title) and values-de/strings-extra.xml:31 (shortcut_action_join_dashpay).
  DEFECT(S4 grammar, de): "Der Nutzername muss eine dieser Kriterien entsprechen" (should be "einem dieser Kriterien").
D2 receiving side (wallet B, seed "[seed phrase redacted]"):
  - deeplink opened via `am start -a VIEW -d '<dashpay://invite?...>'` (NOTE: qa-app.sh `deeplink` does NOT quote for the remote shell, so & splits the URL — must use adb shell with the URL single-quoted).
  - No "Loading Invite…" screen at all; wallet.log 06:05:35 InviteHandlerActivity -> validateInvitation -> isValid=true VALID within the same second (<1 s, far under the 90 s watchdog).
  - The invite is surfaced as the home "Join DashPay" header card with Create ENABLED at 0 balance; username screen correctly restricts to non-contested ("You can only create a non-contested username using this invitation", criteria 20-23 chars / numbers 2-9).
  - DEFECT (S3): after force-stop + relaunch the invite is forgotten — Create becomes enabled=false (D2b/20) and re-opening the link too soon shows "Invitation Error / DashPay is currently processing an invite." (D2b/22). Re-opening the link again recovers (Create enabled=true, D2b/23). Workaround exists.
  - Claim completed: username qa5s5invyhjvrfb3nfy5d, "Hello ... Your account is ready" ~20 s after PIN. Verified on testnet explorer: identity 3vEUteE9Cmstx8ey249hPbxhK16PuoDDYmf7XV3DZpMQ (D2b/29-explorer.json). No hang > 90 s anywhere.
  - Inviter identity is NOT shown on a dedicated invite screen in this build (no "You have been invited by ..." accept screen); only the generic Join DashPay card. Inviter display-name is in the link and in the Preview Invitation sheet on the sender side.

=== SR items (orchestrator request) ===
SR-12 (shielded "stalled" 40 s notice): NOT OBSERVED in any flow. Shield-all ~15 s, username ~15 s, invite #1 ~20 s, invite #2 ~25 s, invited-username claim ~20 s. grep of both wallet.log pulls for stall|watchdog|taking longer shows no shielded stall notice (only L1Shadow probe watchdog teardown lines). The internal-transfer screen was re-entered afterwards and is fully usable (SR/22, SR/23). Claim of a permanently bricked screen NOT reproduced (but the notice never fired, so the specific post-notice path is UNVERIFIED).
SR-02 (invite cancelled before share -> silent fund loss): NOT REPRODUCED. Invite #2 created from the shielded pool (0.03), link captured from wallet.log, then BACK pressed twice with no share/copy. Shielded 0.935 -> 0.903 (0.03 + ~0.002 fee). The invite IS recorded: Invitations History shows "Invitation 1 / Sep 19, 01:25 am" (SR/19, SR/20) with a detail screen offering "Copy Invitation Link" and "Send again" (SR/21). The regenerated link's one-time spending key is byte-identical to the one captured at creation (osk=46859d9b...4571) -> the key is persisted, not discarded. No fund loss.
  Observation: the first invite (created before the reset, claimed by wallet B) does NOT appear in the restored wallet's Invitations History. Reset was done with "Reset wallet without saving" so local metadata loss is expected; noting it as an observation only.

=== Final health ===
mem.csv 81 samples. Peak TOTAL PSS 614,031 KB; peak native heap 453,388 KB; peak Dalvik heap 42,062 KB. No LMK/OOM (logs/oom-exitinfo.txt, 0 matches). 0 FATAL / OutOfMemoryError / OverlappingFileLockException in either wallet.log pull.
DIP-15: FriendKeyChain chains activated with lookaheadSize=100 (not 20) — the "20 addresses" cap is not observed on this build.
CONTACT COVERAGE DEBT (watchlist hit, reported by the app itself, 30x): "DashPay contact coverage DEBT on 65384bdf…: the filter scan is at 1556585 but the earliest received contact request sits at core height 1556575 (10 blocks below, 3 contact request(s)). Payments to those chains were scanned past. This is reported, not repaired — see §17 of the upgrade memory and sync plan". Appears continuously after the wallet-A restore. In this run no payment was actually lost (the 0.001 DASH from qa1s13939 is visible), but the app states it does not repair the gap.
