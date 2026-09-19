#!/bin/zsh
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566; EV=$QA_EVIDENCE/SRF
OUT=$EV/SR-13; mkdir -p $OUT
log() { echo "$(date +%T) $*" | tee -a $OUT/timeline.txt; }

adb -s $S shell input tap 790 2221; sleep 3        # Confirm on the sheet
$APP $S screenshot $OUT/10-pin.png >/dev/null
adb -s $S shell input tap 208 1836; sleep 1.2
adb -s $S shell input tap 540 1836; sleep 1.2
adb -s $S shell input tap 872 1836; sleep 1.2
adb -s $S shell input tap 210 1968
log "PIN entered (T0)"
T0=$(date +%s)
sleep 3
$APP $S screenshot $OUT/11-t3-before-back.png >/dev/null
adb -s $S shell input keyevent KEYCODE_BACK
log "T+3s: pressed BACK (leaving the screen -> VM clear)"
sleep 2
$APP $S screenshot $OUT/12-after-back.png >/dev/null
log "T+5s: $($APP $S ui 30 2>/dev/null | grep -E 'text=' | tr '\n' ' ')"
for t in 20 40 65; do
  while [[ $(( $(date +%s) - T0 )) -lt $t ]]; do sleep 2; done
  $APP $S screenshot $OUT/b$(printf %03d $t).png >/dev/null
  log "T+${t}s: $($APP $S ui 30 2>/dev/null | grep -E 'text=' | tr '\n' ' ')"
done
