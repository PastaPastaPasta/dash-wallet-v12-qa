# SRE stream — running notes (host times, America/Chicago; device clock = host +5h)

- 11:37 Found emulator-5562 (dw-qa5) and emulator-5564 (dw-api31) NOT running. Started both headless.
  5562 = API 35 / Android 15. 5564 = API 31 / Android 12.
- 11:43 5562 had a pre-existing, fully SYNCED, cutover-committed wallet (65384bdf…). Log saved to
  SR-01/logs-preexisting/wallet.log, then uninstalled to get a behind-target filter cursor.
- 11:45 Fresh install FIX 12.0.0 (vc 12000000) on 5562.
- 11:47 Restored reference seed (job flower agree … fat), NO creation date selected (full scan). PIN 1234.
- 11:49 Home screen. Sync running.
- 11:50:01 iptables DROP on tcp/19999 only -> did NOT stall the cursor (it ran on to 1,350,000).
- 11:53:01 iptables/ip6tables `-m owner --uid-owner 10208 -j DROP` on OUTPUT -> packet-level cut, app keeps
  its sockets. Cursor froze.
- 11:54:34 (dev 16:54:34) LAST filter advance: filters 1555000/1556858 (1,858 short), phase=CONNECTING.
- 12:03:04 (dev 17:03:04) FILTER-STALL WATCHDOG FIRED. See SR-01/20-watchdog-fire-context.txt.
- 12:05:52 network restored (all iptables rules deleted, ping OK). Engine did NOT come back.
- 12:10 SR-40 API-35 unprivileged control run on 5562 (SetPinActivity). Also caused activity churn +
  PIN authentication in the app — and still did NOT revive the L1 engine.

## SR-40 (5564, API 31)
- 11:53 FIX + fresh wallet. Broadcast vs MainActivity: NO effect (MainActivity does not extend
  InteractionAwareActivity — only SetPinActivity, VerifySeedActivity, UpholdTransferActivity do).
- 11:55 Broadcast vs VerifySeedActivity from root: activity finished.
- 11:57 Broadcast vs VerifySeedActivity from UNPRIVILEGED uid 2000: activity finished. REPRODUCED.
- 12:01 First API-35 attempt used ROOT (uid 0) -> activity finished. CONFOUND: root/shell broadcasts carry
  FLAG_RECEIVER_FROM_SHELL and bypass the not-exported check. Redone properly at 12:10.
- 12:07 MASTER 11.9.0 on API 31, same unprivileged broadcast: activity finished => PRE-EXISTING.
- 12:10 API 35 control, same unprivileged uid 2000: SetPinActivity SURVIVES (T+5s and T+15s). Control passes.
