#!/bin/zsh
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566; EV=$QA_EVIDENCE/SRF
OUT=$EV/SR-14; mkdir -p $OUT
log() { echo "$(date +%T) $*" | tee -a $OUT/timeline.txt; }

adb -s $S shell input tap 797 2237; sleep 3            # Confirm
$APP $S screenshot $OUT/09-pin.png >/dev/null
adb -s $S shell input tap 208 1836; sleep 1.2
adb -s $S shell input tap 540 1836; sleep 1.2
adb -s $S shell input tap 872 1836; sleep 1.2
adb -s $S shell input tap 210 1968
log "PIN entered (T0)"
T0=$(date +%s)
sleep 3
adb -s $S shell svc wifi disable; adb -s $S shell svc data disable
log "T+3s: network OFF (wifi+data disabled)"

for t in 15 30 60 120 180; do
  while [[ $(( $(date +%s) - T0 )) -lt $t ]]; do sleep 2; done
  $APP $S screenshot $OUT/n$(printf %03d $t).png >/dev/null
  log "T+${t}s: $($APP $S ui 40 2>/dev/null | grep -E 'text=' | tr '\n' ' ')"
done
