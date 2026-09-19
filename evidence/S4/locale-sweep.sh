#!/bin/zsh
# usage: locale-sweep.sh <tag>
source /Users/dcg/workspace/dash-wallet-qa/evidence/S4/s4.sh
TAG=$1
D=$E/E10/$TAG
# per-app locale override: setprop persist.sys.locale does NOT work on API 35
adb -s $S shell "cmd locale set-app-locales hashengineering.darkcoin.wallet_test --user 0 --locales $TAG" >/dev/null 2>&1
sleep 2
mkdir -p $D
P=hashengineering.darkcoin.wallet_test
shotd() { $APP $S screenshot $D/$1.png >/dev/null; $APP $S ui 90 > $D/$1.txt 2>/dev/null; echo "  $1"; }
tapid() { $APP $S tapon "resource-id=\"$P:id/$1\"" >/dev/null 2>&1; }
goHome() {
  adb -s $S shell am force-stop $P; sleep 2
  adb -s $S shell am start -n $P/de.schildbach.wallet.ui.OnboardingActivity >/dev/null 2>&1; sleep 11
  for d in 1 2 3 4; do $APP $S tapon "resource-id=\"$P:id/btn_$d\"" >/dev/null 2>&1; sleep 0.4; done
  sleep 7; tapid walletFragment; sleep 3
}

adb -s $S shell am force-stop $P; sleep 2
adb -s $S shell am start -n $P/de.schildbach.wallet.ui.OnboardingActivity >/dev/null 2>&1; sleep 11
shotd 00-lockscreen
for d in 1 2 3 4; do $APP $S tapon "resource-id=\"$P:id/btn_$d\"" >/dev/null 2>&1; sleep 0.4; done
sleep 7
tapid walletFragment; sleep 3; shotd 01-home

tapid paymentsFragment; sleep 4; shotd 02-receive
$APP $S swipe 900 900 150 900 300 >/dev/null; sleep 1; $APP $S swipe 900 900 150 900 300 >/dev/null; sleep 3; shotd 03-send-tab
tapid send_btn; sleep 4; shotd 04-send-to-address

goHome
tapid moreFragment; sleep 3; shotd 05-more
tapid join_dashpay_container; sleep 8; shotd 07-username-request

goHome
adb -s $S shell am start -n $P/de.schildbach.wallet.ui.shielded.ShieldedBalanceActivity >/dev/null 2>&1; sleep 7
shotd 06a-shielded-explainer
$APP $S tap 540 2100 >/dev/null; sleep 4; shotd 06b-shielded

goHome
tapid moreFragment; sleep 3
tapid security; sleep 4; shotd 08-security

goHome
tapid moreFragment; sleep 3
tapid settings; sleep 4; shotd 09-settings
$APP $S tap 540 857 >/dev/null; sleep 5; shotd 10-about
$APP $S swipe 540 1900 540 1100 400 >/dev/null; sleep 3; shotd 11-about-scrolled
# Contact Support = last full-width clickable row on the About screen (locale independent)
xy=$($APP $S dump 'clickable="true"' 30 | grep -oE 'bounds="\[(39|69),[0-9]+\]\[(1011|1041),[0-9]+\]"' | tail -1 | sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}')
[[ -n "$xy" ]] && adb -s $S shell input tap $xy
sleep 6; shotd 12-contact-support
echo "done $TAG -> $D"
