# PR-sr05-wipe-marker QA notes (emulator-5562, Android 15 / API 35, AVD dw-qa5)
- Serial emulator-5562 booted for this task (was not running); other serials untouched.
- Base APK: base-12000014-5f8c0a8ef.apk (versionCode 12000014, versionName 12.0.0-upgrade)
- Candidate APK: sr05-32c0bd0b2.apk (same versionCode)
- BASE wallet seed (QA throwaway): rigid genuine settle camp unlock kingdom donor deny enlist portion virtual taxi
faucet txid 9a3b6f2983b59c13aa4a12e6c87b0b344646a38df3877c9077838313121c6e23 -> yZ1xjAn1c2aQ1jQDiLnZp4wBKvx1suKiYo (base wallet)
BASE session wallet.log lines=    2991 WARN=0 ERROR=0
- 16:16 BASE SR-05 reproduced (bare marker destroyed funded wallet)
- 16:21 BASE SR-20 reproduced (marker cleared, datastore byte-identical)
- 16:25 BASE SR-36/D-107 reproduced (destroying nothing; wallet unlocks with old PIN)
- 16:27 BASE B baseline ok
- 16:29 candidate installed, funded seed restored (1 tDASH)
- 16:34 AFTER SR-05: marker renamed aside, wallet intact
- 16:39 identity guard: "started on a different wallet file"
- 16:40 SR-20 fixed: 13 failed steps, marker kept; repair launch finishes wipe
- 16:44 SR-36 fixed: destroys anyway, 2 failed steps [wallet-file, key-backup-file]
- 16:52-17:03 adversarial markers (48h, future, wrong versionCode, .writing litter), kill offsets 0.08/0.2/0.5s
- 17:11 plain reset + restore end-to-end ok; 17:19 stray wipe intent destroys nothing
- unit tests: 23 passed
