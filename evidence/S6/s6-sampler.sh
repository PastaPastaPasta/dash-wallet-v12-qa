#!/bin/zsh
# S6 sampler: every N seconds, append key wallet.log lines + a home screenshot for the prod (mainnet) package.
# usage: s6-sampler.sh <testdir> <interval-seconds> <count>
source ~/workspace/dash-wallet-qa/env.sh
S=emulator-5564
PKG=hashengineering.darkcoin.wallet
TD=$1; IV=${2:-150}; N=${3:-40}
mkdir -p "$TD"
OUT=$TD/sync-samples.txt
adb -s $S root >/dev/null 2>&1
prev=""
for i in $(seq 1 $N); do
  ts=$(date +%FT%T)
  cur=$(adb -s $S shell "grep -aE 'percent|cutover state|L1 shadow SPV started|filter-stall|idling detected|restart|MEM pss|syncedHeight|OutOfMemory|FATAL|starting peergroup' /data/data/$PKG/files/log/wallet.log" 2>/dev/null | tail -6 | tr -d '\r')
  echo "===== $ts sample $i =====" >> $OUT
  echo "$cur" >> $OUT
  if [[ "$cur" != "$prev" ]]; then
    adb -s $S exec-out screencap -p > "$TD/sync-$(date +%H%M%S).png" 2>/dev/null
    prev="$cur"
  fi
  sleep $IV
done
echo "sampler done $(date +%FT%T)" >> $OUT
