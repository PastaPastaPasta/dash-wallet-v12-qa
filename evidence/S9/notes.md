S9 start 2026-09-19T01:29:55
S9 wallet seed: [seed phrase redacted]
01:35 X1: wallet created (seed abstract fork speak manual talk cream seed penalty edit recipe profit evolve), PIN 1234.
  recv addr #1 yYxUzAE8SNndkcnWyt1RRXEUvbHVV12Bdk ; faucet txid afcfb69ab343b09c09d2bce10e880964279112da1a92e8622ef6ea2354daf267 (1 tDASH)
01:48 X1 cycle 1: fg-idle 3min (3 auto-locks) + bg 3min + fg + unlock + send 0.001 self -> SEND SUCCEEDED
  txid 645fbe3ca203b11dc70a04429992dd93fa058dc0d5fb0f33575c72ae80f918d7 ; NO "idling detected" line occurred in the whole window.
  Confirm sheet showed network fee 0.0001 but actual fee = 226 duffs (0.00000226) -> SR-28 confirmed.
  Success detail sheet shows "Sent to ybhMKMNdRvuKiMrNgmQ13RnGmAMXErLchg" = the CHANGE address, amount -0.00000226 (net) not 0.001.
02:04 X1 cycle 2 (natural fg3min+bg3min): NO idling detected -> send not attempted (idle suppressed by IDLE_TRANSACTION_TIMEOUT_MIN=9 window after the faucet/self-send tx events).
02:04 X1 cycle 3 (orchestrator variant: Network monitor left untouched 5.5 min):
  06:58:00 idling detected, stopping service ; 06:58:14 onDestroy ; L1ShadowLifecycle STOPPED after 24m24s up (teardown #1) ; 06:58:15 RESUMING after 0s down
  07:01:00 idling detected, stopping service ; 07:04:35 onDestroy on leaving Network monitor ; STOPPED (teardown #2) ; 07:04:36 RESUMING after 0s down
  Send 0.001 right after: SUCCEEDED, txid 31bc6adc0655d87c001b65c9e95dc5473ed753d6d37e668eb97d74efaf95c6ec. NO SendEngineNotSynced.
02:17 X1 cycle 4 (bg 9 min until teardown #3 with NO resume, then fg+send):
  07:16:00 idling detected, stopping service; onDestroy; STOPPED after 11m24s up (teardown #3) — no RESUMING while backgrounded
  fg at ~07:16:07 -> 07:16:20 L1ShadowLifecycle RESUMING after 19s down
  send 0.001 at 07:17:27 SUCCEEDED txid f31d78d048051dc13a2aca824fd614177dc794abbe301738cd854d333daf1ebe
  => D-031 did NOT reproduce; the engine restarts on foreground. Remaining exposure = the ~13-19 s restart window.
02:33 X1 cycle 5 (race attempt, dash: deeplink fired seconds after teardown #4 @07:32:00):
  07:32:20 RESUMING after 19s down; send at 07:33:11 broadcast OK (txid 1c3cff5d3cb51057a5da9a1c545a1e256bb94445075e30eae8d5d669fafb4ebc)
  (amount 112370 duffs, not 100000 — my blind taps appended digits to the prefilled deeplink amount; not a product issue)
  X1 VERDICT: D-031 NOT REPRODUCED on this build. 4 teardowns observed, engine restarted 0s/0s/19s/19s later, all 5 sends succeeded.
02:41 X3: cold launch with wifi+data OFF -> home header briefly showed WRONG balance 1.996984 (~2x) for >30s, then settled to 0.999991 with "Syncing balance".
  Network monitor with NO network (cold start, 5 min): still "Synced / Connected to the Dash network", heights frozen at 1,556,608. Never shows sync_status_unable_to_connect.
  net on 07:41:35 -> phase MASTERNODES 07:41:37 (2s) -> SYNCED 07:41:41 (6s). Reconnect is fast.
02:49 X2: airplane ON while running+synced, 4 min on Network monitor: still "Synced / Connected to the Dash network", heights frozen 1,556,616. Same defect.
02:52-02:57 X5 results:
  chmod 000 wallet-protobuf-testnet -> launch OK, breadcrumb 96 WALLET_RECOVERED_FROM_BACKUP +1986ms, "wallet restored from backup: 'key-backup-protobuf-testnet'", balance correct 0.999991, no safe-mode screen. Autosave then throws FileNotFoundException EACCES every save (silently).
  chmod 600 + chown restore -> wallet intact, balance 0.999991.
  truncate to 89191/178383 bytes -> launch OK, restored from backup in 524 ms, balance correct.
  forced safe mode (breadcrumbs=INCOMPLETE_PRE_MILESTONE + failures=1): breadcrumb 91 WALLET_LOAD_SKIPPED_SAFE_MODE; screen shows the ACRA "Previous crash detected" sheet FIRST; only after Cancel does safe_mode_startup_message + Try Again/Report/Close appear. Try Again -> 98 SAFE_MODE_RETRY -> 99 SAFE_MODE_RETRY_OK, wallet intact.
03:16 X7: username qa9s9zkrmvtpqwxnb3d7 registered (identity DHP9CGTqKAcMt83ryjDosYGEGD3sKzxe9wW9SocKvco5, CONFIRMED) paid 0.03 from shielded.
  Shield 0.99999096 -> shielded 0.997 (fee ~0.003).
  FINDING: shield screen stuck on "Shielded balance is syncing — transfers will be available shortly" for >8 min; only a kill+relaunch cleared it.
  FINDING: Join DashPay warning "You have 0.00001225 Dash. Some usernames cost up to 0.25 Dash." reads only the TRANSPARENT balance, ignoring 0.997 shielded.
03:22 X7 contact requests:
  Without an identity there is NO Contacts UI at all (bottom nav has 3 items; home offers "Join DashPay"); searching for qa1s13939 is impossible -> the "send a request without an identity" case cannot be reached.
  AIRPLANE MODE + "Send request": button is completely inert — no spinner, no toast, no send_contact_request_error_* dialog. Tapped twice, 30 s, nothing. (log only shows DAPI "tcp connect error" from the background sync)
  Network back on -> "Send request" -> "Request sent", Activity row "Contact request sent 3:22 AM", Contacts shows "Pending Requests (1)".
  Non-existent name zzzznotarealuser9999 -> clean empty state "There are no users that match "zzzznotarealuser9999"".
  Username creation wrote NO transaction-history row (confirms D-007/SR-11).
