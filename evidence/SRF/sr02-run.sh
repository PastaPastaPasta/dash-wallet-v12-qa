#!/bin/zsh
# usage: sr02-run.sh <killDelaySeconds> <runLabel>
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh; S=emulator-5566; EV=$QA_EVIDENCE/SRF
PKG=hashengineering.darkcoin.wallet_test
D=$1; R=$2
OUT=$EV/SR-02; mkdir -p $OUT
log() { echo "$(date +%T) [run$R] $*" | tee -a $OUT/timeline.txt; }

# from the More screen: Invitations -> private -> non-contested -> confirm and pay
$APP $S tapon 'text="Invitations"' >/dev/null; sleep 6
$APP $S tapon 'text="Create a private invitation"' >/dev/null; sleep 6
$APP $S tapon 'text="Non-contested"' >/dev/null; sleep 2
$APP $S tapon 'text="Confirm and pay"' >/dev/null; sleep 5
$APP $S screenshot $OUT/r$R-01-confirm.png >/dev/null
adb -s $S shell input tap 797 2237; sleep 3     # Confirm
$APP $S screenshot $OUT/r$R-02-pin.png >/dev/null
adb -s $S shell input tap 208 1836; sleep 1.2
adb -s $S shell input tap 540 1836; sleep 1.2
adb -s $S shell input tap 872 1836; sleep 1.2
adb -s $S shell input tap 210 1968
log "PIN entered (T0); will force-stop at T+${D}s"
sleep $D
adb -s $S shell am force-stop $PKG
log "force-stopped at T+${D}s"
