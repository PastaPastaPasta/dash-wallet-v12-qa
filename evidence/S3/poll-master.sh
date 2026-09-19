#!/bin/zsh
source ~/workspace/dash-wallet-qa/env.sh
APP=$QA_ROOT/bin/qa-app.sh
S=emulator-5558
DIR=$QA_EVIDENCE/S3/A3/01-master-sync
LOG=$DIR/poll.log
N=${1:-12}
unlock_app() {
  adb -s $S shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
  adb -s $S exec-out uiautomator dump /dev/tty 2>/dev/null > /tmp/s3-poll-ui.xml
  if grep -q 'id/lock_screen' /tmp/s3-poll-ui.xml; then
    for d in 1 2 3 4; do
      xy=$(sed 's/></>\n</g' /tmp/s3-poll-ui.xml | grep "id/btn_$d\"" | head -1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}')
      [[ -n "$xy" ]] && adb -s $S shell input tap $xy
      sleep 0.4
    done
    sleep 4
  fi
}
for i in $(seq 1 $N); do
  ts=$(date +%FT%T)
  nn=$(printf "%02d" $i)
  unlock_app
  $APP $S screenshot $DIR/poll-$nn-t$((i*5))min.png >/dev/null 2>&1
  adb -s $S exec-out uiautomator dump /dev/tty 2>/dev/null > /tmp/s3-poll-ui.xml
  pct=$(sed 's/></>\n</g' /tmp/s3-poll-ui.xml | grep 'id/syncing"' | grep -oE 'text="[^"]*"' | head -1)
  bal=$(sed 's/></>\n</g' /tmp/s3-poll-ui.xml | grep 'id/wallet_balance_dash"' | grep -oE 'text="[^"]*"' | head -1)
  chain=$($APP $S grep-log 'chain/common height' 1 2>/dev/null | tail -1)
  prog=$($APP $S grep-log 'BlockchainServiceImpl - progress' 1 2>/dev/null | tail -1)
  dl=$($APP $S grep-log 'DownloadProgressTracker - Chain download' 2 2>/dev/null | tail -2)
  mem=$($APP $S mem "master-t$((i*5))min" 2>/dev/null)
  {
    echo "===== poll $nn  host=$ts ====="
    echo "UI syncing: $pct   balance: $bal"
    echo "chain: $chain"
    echo "prog:  $prog"
    echo "dl:    $dl"
    echo "mem:   $mem"
    echo "--- grep percent|peergroup|block|MEM|FATAL (20) ---"
    $APP $S grep-log 'percent|peergroup|PeerGroup|block|MEM |FATAL' 20 2>/dev/null
    echo
  } >> $LOG
  sleep 300
done
echo "POLL-DONE $(date +%FT%T)" >> $LOG
