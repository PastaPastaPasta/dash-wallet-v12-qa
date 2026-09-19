#!/bin/zsh
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566; EV=$QA_EVIDENCE/SRF; K=$EV/k.sh
OUT=$EV/SR-12
mkdir -p $OUT
log() { echo "$(date +%T) $*" | tee -a $OUT/timeline.txt; }

# Continue -> Confirm sheet
$K cont; sleep 3
$APP $S screenshot $OUT/02-confirm-sheet.png >/dev/null
# Confirm button bottom-right of the sheet
adb -s $S shell input tap 790 2221; sleep 3
$APP $S screenshot $OUT/03-pin.png >/dev/null
# PIN
adb -s $S shell input text 1234
log "PIN entered (T0)"
T0=$(date +%s)

# throttle at T0+5s
sleep 5
adb -s $S emu network speed gsm  >/dev/null 2>&1
adb -s $S emu network delay gprs >/dev/null 2>&1
log "network throttled: speed gsm, delay gprs (T0+5)"
adb -s $S shell "iptables -A OUTPUT -p tcp --dport 1443 -j DROP" >/dev/null 2>&1
adb -s $S shell "iptables -A OUTPUT -p tcp --dport 443 -j DROP" >/dev/null 2>&1
log "iptables DROP on tcp/1443 and tcp/443 (T0+5)"

for t in 10 20 30 38 42 50 60 75 90 120; do
  while [[ $(( $(date +%s) - T0 )) -lt $t ]]; do sleep 1; done
  $APP $S screenshot $OUT/t$(printf %03d $t).png >/dev/null
  txt=$($APP $S ui 40 2>/dev/null | grep -E 'text=' | tr '\n' ' ')
  log "T+${t}s: $txt"
done
