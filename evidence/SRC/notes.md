## SRC notes
- 2026-09-19T11:42:04 emulator-5558 (dw-qa3) booted+rooted; started by me (was not running)
- 2026-09-19T11:43:55 found stale wallet 'qa12s12mixedfunds4821' bal 0.197871 on dw-qa3 (screenshot setup/04-home.png); uninstalling for a clean transparent-send wallet
- 2026-09-19T11:46:05 created fresh wallet, PIN 1234, seed saved to setup/SEED.txt
- 2026-09-19T11:50:07 SR-18 BLOCKED (no Coinbase keys in build; OAuth opens Chrome)
- 2026-09-19T11:50:17 faucet sent 1 tDASH to yVuNuykoLNRt4X4WpmyvyF47LNqEKn83Df txid=057b1808741470e8f084aeee2fa377934366d9d06e80477cd2f1ff8a3574410b
- 2026-09-19T11:55:58 SR-19: deeplink dash:yRjAzoyfZ7DpzLFmVGiLispLjUaYKRnL52?amount=0.01&message=SR19memo&label=Bob
- 2026-09-19T12:08:49 WARNING: app auto-locks; a digit-trace leaked into the PIN pad => 'Wrong PIN! 6 attempts remaining'. Recovered.
- 2026-09-19T12:10:51 SR-28 REPRODUCED; numbers in SR-28/numbers.txt
- 2026-09-19T12:16:46 faucet #2: 1 tDASH to yQJ66b2xF2EzXpiyYGYzQ8P8vP4RBp3Bic txid=c6fe82fdebc597c9061c11afeb64ba40df841f5de11a77e0ef24eb7404f97e41
- 2026-09-19T12:52 SESSION END. Verdicts: SR-19 REPRODUCED, SR-28 REPRODUCED, SR-29 REPRODUCED x2,
  SR-32 PARTIAL (code confirmed, divergence masked by SR-10), SR-10 REPRODUCED, SR-16/17 PARTIAL
  (inert half confirmed, 0 guard log lines all session), SR-18 BLOCKED (no Coinbase keys in build).
  Per-item evidence: SR-28/numbers.txt, SR-29/ANALYSIS.txt, SR-18/VERDICT.txt, SR-10/restore2-timeline.txt,
  SR-19/06+17+19 greps, SR-16-17/07-grep-locks.txt (0 matches), SR-29/12-explorer-fees.txt.
  NOTE: the harness blocked me from writing REPORT.md; the full report was returned to the orchestrator as text.
