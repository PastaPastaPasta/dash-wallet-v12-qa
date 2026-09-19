2026-09-19T11:40:59
SRB stream start
faucet txid 73e97a1b7cadce0b87621a7a6a2405a7d0c2987014e75ed9c38a05b848666206 -> yhwrtTL9rpH2B8Er71psqZGFqpZiyGUrkC  2026-09-19T11:45:45
--- mainnet master installed 2026-09-19T11:45:51
downgrade start 2026-09-19T11:55:05
mainnet app uninstalled 2026-09-19T12:05:27
11:40 emulator dw-qa2 not running; launched on port 5556
11:41 SR-23/SR-39/SR-43 aapt badging captured (targetSdk 36->35, abi loss, minSdk 24->29)
11:42 FIX testnet installed, wallet created (PIN 1234)
11:45 faucet 1 tDASH -> yhwrtTL9rpH2B8Er71psqZGFqpZiyGUrkC tx 73e97a1b...
11:47 tax category -> Transfer-in ; 11:48 memo "SRB07 faucet memo"
11:49 self-send 0.1 (SR-42) ; 11:52 external send 0.2
11:54 db-before snapshot (user_version 22)
11:55 downgrade install -r -d to master 11.9.0 -> wallet opens, memo+tax GONE
11:57 re-upgrade to FIX -> metadata NOT restored
11:58-12:02 SR-08 mainnet: empty wallet on master prod -> upgrade to fix prod -> all 5 use_kotlin_sdk_* = true
12:05 mainnet app uninstalled
12:06-12:08 SR-27: master testnet, CoinJoin Intermediate enabled, mixing ran
12:08 upgrade to FIX -> CoinJoin row gone from Settings, coinjoin_mode=INTERMEDIATE orphaned on disk
12:12 monitors stopped, REPORT.md written
