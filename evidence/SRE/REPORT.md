# QA stream SRE — device reproduction of SR-01 / SR-15 / SR-35 / SR-40

| | |
|---|---|
| Emulators | **emulator-5562** (`dw-qa5`, Android 15 / API 35) — SR-01/15/35; **emulator-5564** (`dw-api31`, Android 12 / API 31) — SR-40 |
| Build under test | `fix-12.0.0-testnet3-release-signed.apk`, versionName 12.0.0, **versionCode 12000000**, minSdk 29, targetSdk 35 |
| Baseline | `master-11.9.0-testnet3-release-signed.apk`, **versionCode 11090002** |
| Package / uid | `hashengineering.darkcoin.wallet_test`, app uid 10208 on 5562 |
| Seeds | 5562: reference seed `job flower agree lyrics industry note boost finger buddy dog exact fat` — **READ-ONLY, nothing sent, no username, no shield**. 5564: two throwaway on-device wallets. PIN 1234. |
| Start / end | 2026-09-19 11:37 → 12:30 host (America/Chicago) |
| Clock note | **5562's device clock runs host + 5 h** (host 11:54 = `wallet.log` 16:54). `wallet.log` quotes are device time; narrative is host time. 5564 matches host. |

## Summary table

| SR-id | Verdict | What I did | Decisive evidence | Notes |
|---|---|---|---|---|
| **SR-01** | **REPRODUCED (S1)** | Fresh-restored the reference seed on API 35, let the filter scan reach 99.3 %, froze the cursor **behind target** with `iptables -m owner --uid-owner 10208 -j DROP`, held 8 m 30 s → watchdog fired → restored the network and watched 20 more min. | `SR-01/20-watchdog-fire-context.txt`, `SR-01/timeline.txt`, `SR-01/26-revival-attempts.txt`, `SR-01/28-home-header-frozen-final.png`, `SR-01/logs-final/files/log/wallet.log` | Confirmed, and **worse than SR-01 described**: `stop()` itself fails, the restart is *declined*, the watchdog loop dies permanently. Only force-stop recovers. |
| **SR-15** | **PARTIAL** | Measured filter height at stop vs. next start. | `SR-15/01-rewalk.txt` | Watchdog path unmeasurable (it never starts anything). On the process-relaunch path: stop at **1,555,000**, resume at **1,532,170** → **22,830 blocks re-walked**, caught up in **19 s**. Not 155,000 here, but real. The stop-time WARN that was meant to quantify this printed `durable syncedHeight=unknown`. |
| **SR-35** | **REPRODUCED, differently — raise S3 → S2** | Held the stall 22 min past the first watchdog fire, counted watchdog lines. | `SR-35/07-no-exhausted.txt`, `SR-35/06-network-monitor.png` | `EXHAUSTED` is **unreachable**: **2** `filter-stall watchdog` lines, **0** `standing down` lines in the whole log. Restarts #2/#3 and the EXHAUSTED log can never happen. |
| **SR-40** | **REPRODUCED (API ≤ 32 only) — PRE-EXISTING** | `am broadcast -a InteractionAwareActivity.FORCE_FINISH_ACTION` from **unprivileged uid 2000** vs `VerifySeedActivity` on API 31, each with a 20 s no-broadcast baseline; then same on API 35 and on master 11.9.0. | `SR-40/11-api31-unprivileged-uid2000.txt`, `SR-40/18-api35-unprivileged-control.txt`, `SR-40/15-api31-MASTER-11.9.0.txt`, `SR-40/sr40-api31-unpriv.mp4` | API 31: activity **finished**. API 35, same sender: **survives**. Master on API 31: finished → pre-existing. **Impact statement needs correcting — see below.** |

---

## SR-01 — the watchdog stops the engine and can never restart it

**How the stall was produced (no code changes).** Fresh install; restored the reference seed with **no creation date** so the SDK scans the full chain. The scan ran `filters 5999 → 100000 → 395000 → 1070000 → 1350000 → 1525000` in ~4 min.

- **What did NOT work:** `iptables -A OUTPUT -p tcp --dport 19999 -j DROP` at 11:50:01 — the cursor kept climbing 395,000 → 1,350,000. Record this for the next agent.
- **What did work** (11:53:01) — leaves every socket ESTABLISHED and does not flip Android's connectivity state:
  ```
  iptables  -I OUTPUT 1 -m owner --uid-owner 10208 -j DROP
  ip6tables -I OUTPUT 1 -m owner --uid-owner 10208 -j DROP
  ```
- Last advance: `16:54:34 … L1Shadow phase=CONNECTING 100.0% headers 1556859/1556859 filters 1555000/1556858 wallet 1555000` — **1,858 blocks short**, exactly the 99 %-forever shape.

**The watchdog fired and self-destructed.** Host 12:03:04 / device 17:03:04, verbatim from `SR-01/logs-final/files/log/wallet.log` lines 3347-3358:

```
17:03:04 L1ShadowSyncService - L1Shadow filter-stall watchdog: the filter cursor has sat at 1555000 of 1556858 (1858 blocks short) for over 10 minutes while the engine is running — restarting the SPV engine. Known shape (MO-1022): every filter stored, a few matched blocks never delivered, the download coordinator out of retries.
17:03:04 L1ShadowSyncService - failed to stop the shadow SPV client
kotlinx.coroutines.JobCancellationException: StandaloneCoroutine was cancelled
17:03:04 L1ShadowSyncService - L1Shadow wallet-event tap cancelled (StandaloneCoroutine was cancelled)
17:03:04 L1ShadowSyncService - L1Shadow progress monitor cancelled (StandaloneCoroutine was cancelled)
17:03:04 L1ShadowSyncService - L1Shadow parity probe loop cancelled (StandaloneCoroutine was cancelled)
17:03:04 L1ShadowSyncService - L1ShadowLifecycle watermark at stop: durable syncedHeight=unknown committed cursor=1555000 filter=1555000
17:03:04 L1ShadowSyncService - L1ShadowLifecycle STOPPED after 15m0s up; all four loops torn down (progress monitor, parity probe, watchdog, wallet-event tap); teardown #1 this process. Nothing runs until the next startIfEnabled().
17:03:04 L1ShadowSyncService - failed to read USE_KOTLIN_SDK_L1_SHADOW; treating as off
kotlinx.coroutines.JobCancellationException: StandaloneCoroutine was cancelled
17:03:04 L1ShadowSyncService - L1Shadow filter-stall watchdog: engine restart declined to start (was stuck at 1555000)
17:03:04 L1ShadowSyncService - L1Shadow probe watchdog cancelled (StandaloneCoroutine was cancelled)
```

Three independent confirmations, all caused by `watchdogJob?.cancel()` in `stop()` (`wt-fix/wallet/src/de/schildbach/wallet/service/platform/sdk/L1ShadowSyncService.kt:2320-2333`) cancelling the very coroutine `checkFilterStall()` (`:2778-2814`, driven by `watchdogLoop()` `:2713-2724`) is running on:

1. **`failed to stop the shadow SPV client`** — `source.stopSpv()` threw on the cancelled coroutine, so the native SPV client was *not* cleanly torn down even though the service marked itself STOPPED.
2. **`failed to read USE_KOTLIN_SDK_L1_SHADOW; treating as off`** — the restart *did* reach `startIfEnabled()`, but its first statement is `isEnabled()` (`:3396-3401`):
   ```kotlin
   private suspend fun isEnabled(): Boolean = try {
       dashPayConfig.get(DashPayConfig.USE_KOTLIN_SDK_L1_SHADOW) == true
   } catch (e: Exception) {
       log.warn("failed to read USE_KOTLIN_SDK_L1_SHADOW; treating as off", e)
       false
   }
   ```
   `CancellationException` **is** an `Exception`, so the cancellation is swallowed and becomes *"the feature is off"* → `startIfEnabled()` returns `false` → `"declined to start"`.
3. **`L1Shadow probe watchdog cancelled`** — the loop itself is gone.

So SR-01's predicted *outcome* is exactly right; the precise mechanism is that `stop()` poisons the coroutine and `isEnabled()`'s broad catch converts the poison into a silent, INFO-level "declined to start". Nothing in the log says the wallet just lost its sync engine for the process lifetime.

**After the network came back — nothing.** Restored 12:05:52 (all rules deleted, `ping` OK, the red banner disappeared). **Zero** `L1Shadow`/`L1 shadow` lines between 17:03:04 and the force-stop at 12:22 — 19 minutes, healthy network for the last 16.

| Revival attempt | Host time | Restarted? |
|---|---|---|
| Auto-logout → lock screen → PIN unlock | 12:15–12:16 | No |
| Settings › Security › Change PIN (`SetPinActivity`), full PIN re-auth | 12:10, 12:19 | No |
| HOME (background) 20 s → foreground | 12:16:26 | No |
| Screen off 15 s → on → PIN unlock | 12:17:13 | No |
| Tools › Network monitor / Settings / About browsing | 12:20–12:21 | No |
| **`am force-stop` + relaunch + PIN** | **12:22–12:25** | **Yes** — `17:24:36 L1 shadow SPV started …`; `17:24:55 phase=SYNCED 100.0% … 1556870/1556870` |

### Minute-by-minute watchdog timeline
Sampled every 60 s into `SR-01/timeline.txt`, one screenshot per sample in `SR-01/shots/` (37 + 37).

| Host time | filters / target | Event |
|---|---|---|
| 11:50:01 | 395,000 / 1,556,857 | DROP tcp/19999 applied — **no stall**, cursor keeps climbing |
| 11:52:02 | 1,070,000 / 1,556,858 | still climbing |
| 11:53:01 | — | **per-uid DROP applied (10208)** |
| 11:53:03 | 1,525,000 / 1,556,858 | 99.3 % |
| 11:54:34 | **1,555,000 / 1,556,858** | **last advance — 1,858 short. Stall clock starts.** |
| 11:55–12:02 | 1,555,000 / 1,556,858 | frozen (8 samples) |
| **12:03:09** | 1,555,000 / 1,556,858 | **watchdog fires** → `STOPPED` → `engine restart declined to start` |
| 12:04–12:05 | 1,555,000 / 1,556,858 | frozen, no engine |
| **12:05:52** | — | **network fully restored** |
| 12:06–12:08 | 1,555,000 / 1,556,858 | no restart, no watchdog tick |
| 12:09–12:10 | (blank) | `adb unroot` window for the SR-40 API-35 control; app untouched, log empty in this window too |
| 12:11–12:16 | 1,555,000 / 1,556,858 | bg/fg, lock/unlock, PIN auth all fail to revive |
| 12:17–12:24 | 1,555,000 / 1,556,858 | still dead, 18 min after network returned |
| 12:22:11 | — | **force-stop + relaunch** |
| 12:25:22 | **1,556,870 / 1,556,870** | SYNCED |

**What the user sees** (`SR-01/28-home-header-frozen-final.png`, 12:21, network healthy for 15 min): a normal-looking wallet with **no error banner**, showing **"Syncing balance"**, **"Syncing…"**, and **107.081735 tDASH**, frozen forever. No warning, no in-app control that restarts the engine. The only escape is knowing to force-stop from Android Settings. **S1.**

## SR-15 — cost of a restart

From `SR-15/01-rewalk.txt`:
```
17:03:04 L1ShadowLifecycle watermark at stop: durable syncedHeight=unknown committed cursor=1555000 filter=1555000
17:24:36 L1 shadow SPV started for SDK wallet b7118ed5… (dataDir=…/l1_shadow_spv/testnet, default peer discovery)
17:24:36 L1Shadow phase=CONNECTING 99.5% headers 1556868/1556865 filters 1532170/1556868 wallet 1556868
17:24:55 L1Shadow phase=SYNCED 100.0% headers 1556870/1556870 filters 1556870/1556870 wallet 1556870
```
Re-walk **22,830 blocks** (1,555,000 → 1,532,170), caught up in **19 s** on a warm store. Real, but an order of magnitude below SR-15's 155,000 on this wallet. Supporting point for SR-15's diagnostic complaint: the watermark line printed `durable syncedHeight=unknown` because `sdkWalletSyncedHeight()` was also called on the cancelled coroutine — **the one diagnostic meant to quantify this cost is silently disabled by the SR-01 bug.**

## SR-35 — the EXHAUSTED stand-down is unreachable

After 22 min of continuous stall past the first fire (`SR-35/07-no-exhausted.txt`):
```
grep -c 'filter-stall watchdog' wallet.log  ->  2
grep -c 'standing down'         wallet.log  ->  0
```
The two hits are the single RESTART line and the single "declined to start" line. `watchdogLoop()` never ticks again, so `FilterStallWatchdogDecider.onCheck` is never called a second time, `FILTER_STALL_MAX_RESTARTS = 3` can never be consumed, and the EXHAUSTED branch (`:2806-2814`) is **dead code on this path**.

UI surface: home header says only "Syncing balance" / "Syncing…". `Tools › Network monitor` (`SR-35/06-network-monitor.png`) is the only place that admits it — **"Not started"**, **"Network engine not started"**, **99 %**, `Block filters —` — buried three levels deep in diagnostics with no restart action. **Raise S3 → S2**: the give-up path doesn't merely go unsurfaced, it doesn't run at all, which is what makes SR-01 permanent.

## SR-40 — exported force-finish receiver on API ≤ 32

**Correction to the impact statement.** The SR row says "any app can force-finish *the wallet activity*". The receiver is registered in `InteractionAwareActivity.onCreate` (`wt-fix/common/src/main/java/org/dash/wallet/common/InteractionAwareActivity.java:36-42`) and only **three** activities extend it:
- `wallet/src/de/schildbach/wallet/ui/SetPinActivity.kt:54`
- `wallet/src/de/schildbach/wallet/ui/verify/VerifySeedActivity.kt:35`
- `integrations/uphold/src/main/java/org/dash/wallet/integrations/uphold/ui/UpholdTransferActivity.kt:55`

`MainActivity` does **not** (`MainActivity : AbstractBindServiceActivity` → … → `LockScreenActivity : SecureActivity`, a *sibling* of `InteractionAwareActivity`). Verified on device: broadcasting with the home screen resumed did nothing (`SR-40/06-broadcast-home.txt`). **The home screen, the Send screen and the lock screen are not affected.** The reachable targets are the set-PIN screen, the recovery-phrase screen and the Uphold transfer screen — narrower than stated, but those are the three security/money-sensitive flows.

**API 31 — reproduced from an unprivileged uid** (`SR-40/11-api31-unprivileged-uid2000.txt`, video `SR-40/sr40-api31-unpriv.mp4`):
```
uid=2000(shell) gid=2000(shell) … context=u:r:shell:s0
=== BEFORE ===  mResumedActivity: …/de.schildbach.wallet.ui.verify.VerifySeedActivity t13
                  * Hist #1: …VerifySeedActivity t13
                  * Hist #0: …MainActivity t13
=== am broadcast -a InteractionAwareActivity.FORCE_FINISH_ACTION ===
Broadcasting: Intent { act=InteractionAwareActivity.FORCE_FINISH_ACTION flg=0x400000 }
Broadcast completed: result=0
=== AFTER ===   mResumedActivity: …/de.schildbach.wallet.ui.main.MainActivity t13
                  * Hist #0: …MainActivity t13
```
Every run first waited 20 s with **no** broadcast and confirmed the activity was still resumed, excluding auto-logout.

**API 35 — control passes, same sender** (`SR-40/18-api35-unprivileged-control.txt`): `SetPinActivity` still resumed at T+5 s and T+15 s after the broadcast. The platform enforces `RECEIVER_NOT_EXPORTED` from API 33, so the API-26 gate is the only thing missing on 29–32.

**Methodology warning.** My first API-35 attempt used a **rooted** shell (uid 0) and the activity *did* finish (`SR-40/13-api35-control.txt`). Shell/root broadcasts carry `FLAG_RECEIVER_FROM_SHELL` (`flg=0x400000`) and bypass the not-exported check, producing a **false positive on every API level**. `adb unroot` first; the dumpsys record shows `caller=null null pid=6425 uid=0`.

**Master 11.9.0 — pre-existing** (`SR-40/15-api31-MASTER-11.9.0.txt`): identical result on API 31 with the same unprivileged sender. `wt-master/…/InteractionAwareActivity.java` has the same `SDK_INT >= Build.VERSION_CODES.O` gate. **Not a 12.0.0 regression.**

Severity **S3**. minSdk is 29, so API 29–32 is in scope. A permissionless installed app can repeatedly dismiss the recovery-phrase backup screen, the set/change-PIN screen and the Uphold transfer screen — denial of the backup and PIN-change flows plus a way to interrupt an Uphold transfer at a chosen moment. No data disclosure. Fix is a one-line gate change to `Build.VERSION_CODES.TIRAMISU` (33).

## New findings

| ID | Sev | Finding | Evidence |
|---|---|---|---|
| SRE-N1 | **S2** | `isEnabled()` (`L1ShadowSyncService.kt:3396-3401`) catches `Exception`, which includes `CancellationException`, converting a cancelled coroutine into **"the L1 SDK engine feature is off"**. Proximate cause of SR-01's "declined to start". Fix: rethrow `CancellationException` (the codebase already does this correctly in `startIfEnabled`'s outer catch and in `watchdogLoop`). | `SR-01/20-watchdog-fire-context.txt` |
| SRE-N2 | **S2** | `stop()` logs `failed to stop the shadow SPV client` + `JobCancellationException` — the native Rust SPV client's teardown was skipped while the service marked itself STOPPED, so lifecycle state diverges from reality. | same file, lines 3348-3349 |
| SRE-N3 | S3 | Reference wallet settles at **107.081735 tDASH** after a full fresh restore and confirmed `phase=SYNCED 100.0%`, not the **107.43173749** in the brief. Difference 0.35000249 matches a visible "Sent −0.350002 / 05 September" row. Possibly a stale expected value rather than an app defect — flagging for another stream to reconcile. I did not spend from this wallet. | `SR-01/29-after-forcestop-synced.png` |
| SRE-N4 | S4 | History content **changes** between the stalled and synced renders: 12:21 shows "15 August: Sent −0.012302 / Received +0.001", 12:26 shows "Received +0.987708" for the same date. Probably input merging, but the intermediate render is misleading. | `SR-01/28-…png` vs `SR-01/29-…png` |
| SRE-N5 | info | **Contradicts D-070:** offline *is* surfaced while the engine runs — a red "Unable to connect to the Dash network / Check your connection" banner appeared during the cut. But once the watchdog kills the engine the banner **disappears** (network is back) and the permanently-dead state looks perfectly healthy. That is what makes SR-01 invisible to users. | `SR-01/15-home-stalled.png` |

## Environment problems / harness notes

- **Both assigned emulators were not running at hand-off** (`dw-qa5`, `dw-api31` absent from `adb devices`); I started them headless myself.
- `$APP <serial> text 1234` does not drive the app's PIN pad — tap digits by resource-id (matches SRB's 12:15 note).
- `$APP <serial> launch` (monkey) frequently fails to start the app; `am start -n <pkg>/de.schildbach.wallet.ui.OnboardingActivity` works.
- Piping `adb shell dumpsys activity activities` into a host-side `grep` truncates with "Broken pipe" on API 35 — run the `grep` **inside** the `adb shell` string.
- `iptables -m owner --uid-owner <uid> -j DROP` is the reliable way to freeze the SDK SPV engine while leaving Android's connectivity state untouched. Blocking tcp/19999 alone does **not** stall it.
- 5562 left rooted, iptables/ip6tables clean, app synced. 5564 currently has master 11.9.0 installed with a throwaway wallet.
