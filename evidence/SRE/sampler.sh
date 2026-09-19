#!/bin/zsh
# SRE watchdog sampler: every 60s append the latest L1Shadow progress + any watchdog lines
source ~/workspace/dash-wallet-qa/env.sh
S=emulator-5562
PKG=hashengineering.darkcoin.wallet_test
OUT=$QA_EVIDENCE/SRE/SR-01/timeline.txt
SHOT=$QA_EVIDENCE/SRE/SR-01/shots
mkdir -p "$SHOT"
adb -s $S root >/dev/null 2>&1
while true; do
  TS=$(date +%FT%T)
  PROG=$(adb -s $S shell "grep -E 'L1Shadow phase=' /data/data/$PKG/files/log/wallet.log | tail -1" 2>/dev/null | tr -d '\r')
  WD=$(adb -s $S shell "grep -cE 'filter-stall watchdog' /data/data/$PKG/files/log/wallet.log" 2>/dev/null | tr -d '\r')
  ALIVE=$(adb -s $S shell "pidof $PKG" 2>/dev/null | tr -d '\r')
  echo "$TS | pid=$ALIVE | wd_lines=$WD | $PROG" >> "$OUT"
  adb -s $S exec-out screencap -p > "$SHOT/hdr-$(date +%H%M%S).png" 2>/dev/null
  sleep 60
done
