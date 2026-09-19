## SRA notes
- 2026-09-19T11:41:27 emulator-5554 (dw-qa1) booted, rooted
SRA wallet A seed: palace hint east head chronic close length brand right comic excite extra
- 2026-09-19T11:47:36 faucet txid a0706d09e1f383216aa2d81697db2418b9e7a9495d860f98d9a442d8180999bd -> yMKPQKunBcnXBDc7tk7NZEswfeUNNynDPZ
- 2026-09-19T11:52:28 SR-20: chmod restored to 700
- 11:50 SR-20 run: chmod 500 files/datastore, Reset Wallet -> steps failed (EACCES) but wipe marked complete, marker gone, onboarding shown. Evidence SR-20/07,08,09,10.
- 11:55 restored same seed; restored wallet came up with cutoverCommitted=true inherited from wiped wallet (SR-20/17).
- 11:58-12:02 SR-36 runs 1-3: chmod 555 files/ -> "could not create the wallet-wipe marker" + "wipe started WITHOUT a recovery marker"; finish() then logged "destroying nothing" and NOTHING was wiped. Wallet intact after relaunch (balance 1 tDASH, same PIN). KEY FINDING.
- 12:03 CONTROL clean reset: marker created +0.15s, gone by +0.9s; full wipe < 1 s. shielded_tree_testnet.sqlite(+wal) survives a CLEAN wipe.
- 12:09-12:20 SR-21 attempts a1-a5 (rescan intent, bg/fg, stopservice+0.5s, net-off+stopservice, stop/start storm). Spinner max 15 s, always recovered. a5 hit "Another onDestroy() is already running cleanup, skipping duplicate cleanup" + "CRITICAL: Cleanup did not complete within 15 seconds" yet still finished.
- 12:23 SR-25: appended 60MB urandom -> 62,929,882 bytes -> guard verdict RISKY at soft limit 60,397,977 (largeHeap 576MB). Parse SUCCEEDED (211ms); autosave debounce raised to 60s. No OOM.
- 12:25 SR-38/26: truncate -s 2000000001 -> UNPARSEABLE, file preserved as wallet-protobuf-testnet.oversize.1789838718982, recovered from key backup, Toast "Your wallet was reset! It will take some time to recover." then a second Toast "java.io.FileNotFoundException". Funds returned (1 tDASH).
- 12:27 NEXT LAUNCH after that recovery -> ONBOARDING. Recovered wallet was never written to wallet-protobuf-testnet; key-backup still on disk, never consulted. NEW S1/S2.
- 12:38-12:42 SR-41: kill -STOP at +450ms for 21s -> "wallet load exceeded its 20000ms budget"; process reaped; NEXT launch safeMode=true, WALLET_LOAD_SKIPPED_SAFE_MODE, DEGRADED_UI_SHOWN. "Try Again" -> SAFE_MODE_RETRY_OK, counters cleared.
- 12:45 session end. Perms restored (files 700, datastore 700). Two .oversize files left as SR-26 evidence.
