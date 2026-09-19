#!/bin/zsh
# S3 A3 step 4-5: launch the fix build after the in-place upgrade and capture
# the first 180 s densely (screenshot every 5 s + UI dump), while screenrecord runs.
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh
S=emulator-5558
DIR=$QA_EVIDENCE/S3/A3/03-upgrade-launch
mkdir -p $DIR
LOG=$DIR/launch-capture.log
echo "LAUNCH at $(date +%FT%T)" > $LOG
$APP $S launch >> $LOG 2>&1
for i in $(seq 1 36); do
  nn=$(printf "%02d" $i)
  $APP $S screenshot $DIR/launch-$nn-t$((i*5))s.png >/dev/null 2>&1
  adb -s $S exec-out uiautomator dump /dev/tty 2>/dev/null > $DIR/ui-$nn.xml
  txt=$(sed 's/></>\n</g' $DIR/ui-$nn.xml | grep -oE 'text="[^"]+"' | tr '\n' ' ')
  echo "[t=$((i*5))s $(date +%T)] $txt" >> $LOG
  sleep 3
done
echo "CAPTURE-DONE $(date +%FT%T)" >> $LOG
