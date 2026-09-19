#!/bin/zsh
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566; EV=$QA_EVIDENCE/SRF; K=$EV/k.sh
OUT=$EV/SR-12
PKG=hashengineering.darkcoin.wallet_test
mkdir -p $OUT
log() { echo "$(date +%T) $*" | tee -a $OUT/timeline.txt; }
pin() { for b in 1 2 3 4; do $APP $S tapon "resource-id=\"$PKG:id/btn_$b\"" >/dev/null 2>&1; sleep 0.4; done; }

# Confirm sheet is expected to be on screen already
adb -s $S shell input tap 790 2221; sleep 3
$APP $S screenshot $OUT/03-pin.png >/dev/null
pin
log "PIN tapped (T0)"
T0=$(date +%s)

sleep 2
adb -s $S shell "iptables -A OUTPUT -p tcp --dport 1443 -j DROP" >/dev/null 2>&1
adb -s $S shell "iptables -A OUTPUT -p tcp --dport 443  -j DROP" >/dev/null 2>&1
adb -s $S emu network speed gsm  >/dev/null 2>&1
adb -s $S emu network delay gprs >/dev/null 2>&1
log "T+2s: iptables DROP tcp/443+1443, emu speed gsm / delay gprs"

for t in 5 10 20 30 36 41 45 50 60 75 90 110 130; do
  while [[ $(( $(date +%s) - T0 )) -lt $t ]]; do sleep 1; done
  $APP $S screenshot $OUT/t$(printf %03d $t).png >/dev/null
  txt=$($APP $S ui 45 2>/dev/null | grep -E 'text=' | tr '\n' ' ')
  log "T+${t}s: $txt"
done
