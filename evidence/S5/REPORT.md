# QA report: S5 — DashPay / Platform (D0–D7 + SR-02 / SR-12)   (agent: S5, emulator-5562 / AVD dw-qa5, 2026-09-19)

Build under test: `fix-12.0.0-testnet3-release-signed.apk`, versionCode **12000000**, versionName 12.0.0, minSdk 29 / targetSdk 35. Clean install (no upgrade path in this stream).

Wallets used (throwaway testnet):
- **Wallet A** — created fresh, seed `[seed phrase redacted]`, funded 1 tDASH from the faucet, username **`qa5s5ebkdus2c6kkt9m7t`**, identity `FGk3cH3u7pF1Nyfs5E1rU4g9bdmPWgoEn41Uj61Gu6M4`. Reset and later restored from seed.
- **Wallet B** — created after the reset, seed `[seed phrase redacted]`, funded only by wallet A's invite, username **`qa5s5invyhjvrfb3nfy5d`**, identity `3vEUteE9Cmstx8ey249hPbxhK16PuoDDYmf7XV3DZpMQ`. Reset at the end.

Faucet: `qa-faucet.sh` is Cloudflare-blocked (error 1010, headless UA banned). Used the studio browser per the updated brief. 1 tDASH, txid `fab296d048314082e41283b4d612ce634e4c2723c1b0bd6ca86df61bf40595ac`, confirmed at the insight explorer.

## Summary table

| Test | Verdict | Key evidence file(s) | One-line finding |
|---|---|---|---|
| D0 Username eligibility gating | **PASS** | `D0/02-join-dashpay-no-funds.png`, `D0/06-join-dashpay-funded.png` | At 0 balance the Welcome screen shows "You need to have more than 0.03 Dash…" and Continue is `enabled=false`; after 1 tDASH the disclaimer is gone and Continue is enabled. |
| D0b Home entry point after funding | **FAIL (S4)** | `D0/01`, `D0/03-home-funded.png`, `D0/05-more-tab-funded.png` | The home-screen "Join DashPay" tile is shown at 0 balance but **disappears** once the wallet has a balance + a transaction; the entry survives only in More. |
| D1 Contested username attempt | **PASS** | `D1/20`…`D1/28`, `D1/26-confirm-cost.png` | `qatestvote` classified contested, warning + "what is username voting?" explainer, confirm sheet 0.25 DASH / $15.37 behind an "I accept" gate; **cancelled before paying**, balance unchanged. |
| D1b Criteria list | **PARTIAL (S4)** | `D1/10`…`D1/14` | All five negative cases classify correctly, but **failed rules do not sort to the top** — the list is a static LinearLayout. |
| D4 Non-contested username (shield first) | **PASS** | `D4/05`…`D4/21`, `D4/d4-shield.mp4`, `D4/d4-username.mp4`, `D4/22-platform-explorer-testnet.json` | Shield-all 1 → 0.997 shielded; `qa5s5ebkdus2c6kkt9m7t` created from the shielded pool for 0.03; verified on the testnet Platform explorer (`status: ok`, `contested: false`). |
| D5 Profile | **PASS** | `D5/07`, `D5/09-more-profile.png`, `D5/12-relaunch-more-profile.png`, `D5/13` | Display name, about-me and avatar (Public-URL / Gravatar path) saved and broadcast; visible in More; persisted across force-stop + relaunch. |
| D3 Contact requests | **PASS** | `D3/07`, `D3/08`, `D3/10-request-sent.png`, `D3/17-s1-contact-detail.png`, `D3/18` | Non-existent name → "There are no users that match…"; prefix `qa1` finds S1; request sent → "Pending Requests (1)"; **S1 accepted at 01:06 and paid 0.001 DASH at 01:10**; incoming request from wallet B accepted. |
| D2 Invites (sender) | **PASS** | `D2/03`…`D2/13`, `D2/d2-invite.mp4`, `invite-link.txt` | Privacy sheet → fee gate (contested 0.25 / non-contested 0.03) → paid 0.03 from the shielded pool → link + share sheet. |
| D2b Invites (receiver / regression) | **PASS with defect** | `D2b/10`…`D2b/29-explorer.json`, `D2b/d2b-claim-finish.mp4` | No "Loading Invite…" screen at all — validated `VALID` in **< 1 s**, far under the 90 s watchdog. Claim completed (`qa5s5invyhjvrfb3nfy5d`, verified on explorer). **Defect: the invite is forgotten across an app restart** (S3, workaround = re-open the link). |
| D6 Username voting UI | **PASS (empty)** | `D6/01`…`D6/08` | Tile opens, explainer + full filter sheet work; list is "Nothing here" under every filter — `DapiClient - getVotePolls(...)` returns no polls, i.e. no active contested names on testnet. No spend. |
| D7 DashPay in de-DE | **PASS with defects** | `D7/02`…`D7/15`, back to en-US verified | Home/contacts/add-contact/search/profile/invitations/username-request all localized. Three i18n defects (below). |
| SR-12 shielded stall notice | **NOT OBSERVED** | `SR/22`, `SR/23`, `logs/final/files/log/wallet.log` | The 40 s stalled notice never fired in any shielded flow; the internal-transfer screen is re-usable afterwards. The specific "bricked after notice" claim stays **unverified** because the precondition never occurred. |
| SR-02 invite cancel → fund loss | **NOT REPRODUCED** | `SR/14`…`SR/21`, `SR/invite2-link.txt` | After BACK-cancel the invite is recorded in Invitations History and re-shareable; the regenerated one-time spending key is byte-identical (`osk=46859d9b…4571`). No silent loss. |

## Per-test detail (condensed)

### D0 — eligibility gating
Zero-balance Welcome-to-DashPay shows `balance_requirement_disclaimer` = "You need to have more than 0.03 Dash to create a username." and `welcome_dashpay_continue_btn enabled="false"`. After the faucet tDASH arrived (home `1` / `$61.06`, insight `balance:1`), the disclaimer is gone and the button is `enabled="true"`.
Regression noticed while doing this: the home-screen `join_dashpay_btn` tile visible at 0 balance (`D0/01`, `D0/02`) is **absent** from the home screen once the wallet has a balance and one transaction (`D0/03`, `D0/04`) — the same entry is still in More (`D0/05`). On the fresh wallet B it appeared again at 0 balance (`D2b/11`), so the tile is tied to the empty-history state, not to eligibility.

### D1 — contested attempt (cancelled, no spend)
`qatestvote` (10 lowercase letters) → warning triangle "The Dash network will vote on this username. We will notify you of the results on Sep 19, 2026." + "+ what is username voting?" expander (full explainer screen, `D1/21`). Request Username → "Verify your identity to enhance your chances…" dialog (Verify / skip); the Verify screen offers a copy-text + paste-link proof flow (`D1/24`). Skipping reaches the confirm sheet: **0.25 DASH / $15.37**, `I accept` checkbox gating `confirm_btn` (`D1/26`, `D1/27`). **Cancel** returns to the input with the name intact; More still showed `1.000 Đ` afterwards — nothing spent.
Note on the date: "Sep 19, 2026" is today, but that is **correct on testnet** — `UsernameRequest.VOTING_PERIOD_MILLIS` is 90 minutes off mainnet (`wallet/src/de/schildbach/wallet/database/entity/UsernameRequest.kt:43`) and the medium date format hides the time. Not a defect.

Criteria matrix (all screenshots in `D1/`):

| Input | Length rule | Chars rule | Request button | Correct? |
|---|---|---|---|---|
| `ab` | FAIL (red) | ok | disabled | yes |
| `qa_test` | ok | FAIL (red) | disabled | yes |
| `qatestlongusernamethatiswaytoolong` (34) | FAIL (red) | ok | disabled | yes (field itself has no maxLength) |
| `QAtestUpper` | ok | ok | **enabled**, flagged contested | yes (DPNS allows uppercase labels) |
| `-qatest` | ok | FAIL (red) | disabled | yes (rule label is imprecise — hyphens *are* allowed, just not leading) |

### D4 — shield then non-contested username
Shield entry point is **not** the More "Shielded" card (that card is `clickable=false`); it is Join DashPay → Continue → "Shield your funds first". Max-shield: `1` → `0.997` shielded (fee ~0.003), ~15 s. wallet.log shows the max path self-healing: `05:31:17 DashSDKException: asset lock coin selection is short: available 100000000 duffs, required 100000229 duffs` immediately followed by `ShieldedTransferExecutor - max shield auto-adjusting for L1 asset-lock fee: … retrying once with 0.99999` — invisible to the user, no error shown.
With a shielded balance present the flow gains a payment-option chooser (Shielded balance / Dash balance). Confirm sheet: **0.03 DASH / $1.84 "from shielded balance"**. After PIN, "Hello qa5s5ebkdus2c6kkt9m7t, Your account is ready" within ~15 s; shielded 0.997 → 0.967.
`05:34:14 SdkShieldedUsernameCreation - shielded-funded identity created at index 0 (FGk3cH3u…) — 0.03 denomination, contested=false`.
Explorer (**testnet host**): `{"identifier":"FGk3cH3u7pF1Nyfs5E1rU4g9bdmPWgoEn41Uj61Gu6M4","alias":"qa5s5ebkdus2c6kkt9m7t.dash","status":{"status":"ok","contested":false}}`.
`S5 qa5s5ebkdus2c6kkt9m7t` appended to `$QA_EVIDENCE/shared/usernames.txt`.

### D5 — profile
Display name "QA Stream Five", about-me 46/140, avatar set through **Public URL** (gravatar URL) → crop screen → Select. Save produced `05:39:37 PlatformDocumentBroadcastService - broadcast profile` then `profile broadcast via Kotlin SDK; reconciling from platform`. More shows avatar + display name + username. Survives `am force-stop` + relaunch, and after the later seed restore the profile came back intact (`SR/08`).

### D3 — contact requests
Search for `zzznotarealuser999` → "There are no users that match "zzznotarealuser999"" (`D3/07`). Prefix `qa1` → `qa1s13939` (`D3/08`). Profile sheet → "Send request" → "Request sent" + activity row "Contact request sent"; contacts tab shows **"Pending Requests (1)"** (`D3/12`). `$QA_EVIDENCE/shared/contact-request-sent.txt` written at 05:44:13Z and updated on acceptance.
Coverage recomputed correctly right after the request: `05:44:50 SdkWalletBinder - DashPay contact coverage OK on 65384bdf…: scan at 1556565 is at or below the earliest received contact height 1556565 (1 contact request(s))`.
S1 accepted while wallet A was being restored: contact activity now reads "Contact request sent 12:43 AM" → "qa1s13939 has accepted your contact request 1:06 AM" → "Received 0.001 DASH 1:10 AM" (`D3/17`). The incoming request auto-sent by the invited wallet B was accepted from the contacts tab (`D3/18`); both contacts now under "My Contacts".

### D2 / D2b — invites
Sender: privacy sheet → fee gate (Contested 0.25 / Non-contested 0.03) → confirm 0.03 / $1.83 → PIN → "Invitation Created Successfully" with Preview / Tag / Copy link / Send Invitation. Share sheet carries the AppsFlyer https link. Links saved to `invite-link.txt` and `invite-link-https.txt`.
Receiver (fresh wallet B, 0 balance): `06:05:35 InviteHandlerActivity - the invite will be forwarded…` → `TopUpRepositoryImpl - validateInvitation: shielded invite — deferring funds check to claim` → `isValid=true, validationState=VALID` **in the same second**. **No "Loading Invite…" screen appeared at all**, so the 90 s watchdog was never approached. The invite surfaces as the home "Join DashPay" card with Create enabled at 0 balance; the username screen switches to invite mode ("You can only create a non-contested username using this invitation", criteria 20–23 chars / numbers 2–9). Claim completed in ~20 s after PIN; explorer confirms `qa5s5invyhjvrfb3nfy5d.dash` → `3vEUteE9Cmstx8ey249hPbxhK16PuoDDYmf7XV3DZpMQ`.
Inviter identity is **not** shown on a dedicated "you have been invited by…" accept screen in this build — only the generic Join DashPay card. The inviter display-name is carried in the link and rendered in the sender-side Preview sheet.

### D6 — voting UI
More > Username Voting → default-filter explainer → list. Filter sheet has Group by (None / Voting ends soonest / latest), Sort by (Request date x2, Votes x2), Type (All / I have approved / I have not approved / Has blocked votes), plus "Only duplicates" and "Only requests with links" checkboxes and Reset. With every combination the list is "Nothing here"; `DapiClient - getVotePolls(...)` returns nothing, i.e. no active contested names on testnet in the window. No vote cast, nothing spent.

### D7 — de-DE
Captured: home, contacts list, add-contact, search results, edit profile, invitations history, and the **username request screen** ("Benutzernamen erstellen", localized criteria). Restored to `en-US` afterwards and re-verified.

## Defects found

| ID | Sev | Title | Repro | Evidence | Suspected area |
|---|---|---|---|---|---|
| S5-1 | **S3** | Invite is forgotten after an app restart; the Create entry goes disabled and a re-open first errors | Fresh wallet, open a `dashpay://invite?…` link (Create becomes enabled at 0 balance) → `am force-stop` → relaunch → home "Join DashPay" card's **Create is `enabled=false`**; re-opening the link immediately shows "Invitation Error / DashPay is currently processing an invite."; a second re-open recovers (Create enabled again) | `D2b/20-after-create2.png`, `D2b/22-invitation-error-dialog.png`, `D2b/23-after-reopen.png` | invite persistence / `InviteHandlerViewModel`, `HistoryHeaderAdapter` invite state |
| S5-2 | **S2** | App self-reports unrepaired DashPay contact-coverage debt after a seed restore | Restore a wallet that has established DashPay contacts → wallet.log emits, once a minute and indefinitely: `DashPay contact coverage DEBT on 65384bdf…: the filter scan is at 1556585 but the earliest received contact request sits at core height 1556575 (10 blocks below, 3 contact request(s)). Payments to those chains were scanned past. This is reported, not repaired — see §17 of the upgrade memory and sync plan` | `logs/grep-watchlist-final.txt` (30 occurrences, 06:22:59 → 06:31:18), `logs/final/files/log/wallet.log` | `SdkWalletBinder` contact-coverage / filter-scan watermark vs DIP-15 chain birth height. No payment was actually lost in this run (the 0.001 DASH from `qa1s13939` is visible), but the code states it does not repair the window. |
| S5-3 | **S4** | Home "Join DashPay" tile disappears exactly when the user becomes eligible | Fresh wallet → home shows the tile at 0 balance → fund the wallet → the tile is gone from home (entry survives only in More) | `D0/01-home-zero-balance.png` vs `D0/03-home-funded.png`, `D0/04-home-funded-scrolled.png`, `D0/05-more-tab-funded.png` | home history header / `join_dashpay_btn` visibility rule |
| S5-4 | **S4** | Failed username criteria do not sort to the top | Type `qa_test` on the create-username screen: the failing "Letters, numbers and hyphens only" rule stays in second position; same for every other failing case | `D1/11-criteria-invalid-chars-underscore.png`, `D1/12`, `D1/14` | `wallet/res/layout/fragment_request_username.xml:111` `requirements_stack` is a static LinearLayout; no reorder logic in `RequestUsernameFragment` |
| S5-5 | **S4** | Misleading always-on "permanently-dark contact" log tail | Any session with DashPay bound: `DashPay receival-account coverage on …: channelsWePublished=0, receivalAccounts=0, dark=0 — a dark contact's receiving addresses are in no watched script set (permanently-dark candidate under the SDK's re-enqueue asymmetry)` is emitted every ~60 s **even when `dark=0`** | `logs/grep-watchlist-1.txt` | `wallet/src/de/schildbach/wallet/service/platform/sdk/SdkWalletBinder.kt:971-978` — the explanatory sentence is appended unconditionally in `logReceivalCoverageDiagnostics` |
| S5-6 | **S4** | i18n: "Pending Requests (%d)" never translated | Set locale de-DE → contacts tab with a sent request shows English "Pending Requests (1)" among German strings | `D7/03-de-contacts.png` | `contacts_pending_sent_requests_count` exists only in `wallet/res/values/strings-dashpay.xml:140`, no `values-*/` variant (new string on this branch) |
| S5-7 | **S4** | i18n typo (pre-existing): "DashPay beitreiten" | de-DE, home Join DashPay card / shortcut | `D7/12-de-invite-card.png` | `wallet/res/values-de/strings-dashpay.xml:158` (`upgrade_to_evolution_title`) and `values-de/strings-extra.xml:31` (`shortcut_action_join_dashpay`) — should be "beitreten". Also `D7/15`: "Der Nutzername muss **eine** dieser Kriterien entsprechen" → "einem". |
| S5-8 | **S4** | Copy typo on the identity-verification screen | Contested name → Request Username → Verify | `D1/24-verify-identity-screen.png` | "…and paste the link **bellow**" → "below" |
| S5-9 | **S4** | Invitation privacy sheet's Private/Standard fee table shows identical columns | Contacts → Invite someone | `D2/03-invite-screen.png` | Non-contested 0.03/0.03 and Contested 0.25/0.25 — the comparison table conveys no difference |
| S5-10 | **S4** | Wrong resource ids reused on the "Select Security Level" onboarding screen | Create new wallet → security level screen | `setup/02-after-create-new.png` + uiautomator dump | The 24-word option's TextViews are `non_contested_name_title` / `non_contested_name_description` (copied from the username layout). Cosmetic/dev-hygiene only. |

## Memory / stability
From `mem.csv` (81 samples, 60 s interval, whole session): **peak TOTAL PSS 614,031 KB**, peak native heap 453,388 KB, peak Dalvik heap 42,062 KB; last sample PSS 456,397 KB / native 292,612 KB. No LMK or OOM (`logs/oom-exitinfo.txt`, 0 matches; `PROCESS EXIT REASON: none recorded` on each relaunch). Zero `FATAL`, `OutOfMemoryError`, `OverlappingFileLockException` in either wallet.log pull. Exceptions seen: 6 x `FirebaseException` (stub `google-services.json`, expected), 1 x handled `DashSDKException` (the self-healed max-shield), 2 x `CancellationException`, 2 x `ChildCancelledException`.
DIP-15: `KeyChainGroup - Activating a new HD chain: FriendKeyChain{P2PKH, accountPath=[9H, 1H, 15H, …], lookaheadSize=100, lookaheadThreshold=33}` — **lookahead is 100, not 20**, so the upstream "20 addresses" cap is not reproduced on this build. `FriendKeyChainLookahead` restored 1 chain / 131 keys from `wallet-protobuf-testnet.friendlookahead` in 7 ms.
`SdkBindRetryService - SDK bind established — clearing the pending state (no blocker recorded in this process)` on every launch; no bind blockers.

## Environment problems (not product defects)
- `$QA_ROOT/bin/qa-faucet.sh` is dead: Cloudflare error 1010 "browser_signature_banned" for the headless Playwright UA. Used the studio browser instead (per the updated AGENT-BRIEF).
- `QA-PLAN.md` points Platform verification at `https://platform-explorer.pshenmic.dev`, which is **mainnet** (core height ~2.54 M). Testnet DPNS lookups need `https://testnet.platform-explorer.pshenmic.dev` (core height ~1.556 M).
- `qa-app.sh <serial> deeplink '<url>'` does not quote the URL for the remote shell, so any `&` splits the command and only a truncated intent is delivered. Use `adb -s <serial> shell "am start -a android.intent.action.VIEW -d '<url>'"`.
- `qa-app.sh <serial> text 'two words'` loses everything after the first space for the same reason; use `input text 'a%sb'`.
- `adb shell service call clipboard` is not usable to read the clipboard on this image; invite links were recovered from `wallet.log` (`TopUpRepositoryImpl - AppsFlyer af_dp : …`).

## Not run / blocked
- **SR-12 post-notice behaviour**: the 40 s shielded "stalled" notice never fired (all shielded operations finished in 15-25 s), so whether the transfer screen is bricked *after* the notice is **unverified**. Everything observable was healthy: the internal-transfer screen re-opens and is usable after three separate shielded spends.
- **D1 contested completion**: deliberately cancelled before paying, per the task (no 0.25 locked for voting).
- **D6 vote screen / end times**: no contested names exist on testnet right now (`getVotePolls` empty), so the per-name vote screen and end-time rendering could not be exercised.
- **Avatar "Select from Gallery" / "Take a Photo"**: not exercised (emulator gallery is empty, no camera); the Public-URL path was used instead.
