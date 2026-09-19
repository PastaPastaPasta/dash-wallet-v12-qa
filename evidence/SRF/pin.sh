#!/bin/zsh
# SRF: enter PIN 1234 on whichever keypad is on screen (auto-detects bounds)
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566
PKG=hashengineering.darkcoin.wallet_test
for b in 1 2 3 4; do
  xy=$($APP $S bounds "resource-id=\"$PKG:id/btn_$b\"")
  [[ -z "$xy" ]] && { echo "no keypad"; exit 1; }
  adb -s $S shell input tap $xy
  sleep 1.2
done
