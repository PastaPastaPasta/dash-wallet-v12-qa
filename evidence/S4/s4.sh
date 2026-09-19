#!/bin/zsh
# S4 helper: source this. Usage: sh <test> <name>   -> screenshot + ui dump
source ~/workspace/dash-wallet-qa/env.sh
export S=emulator-5560
export APP=$QA_ROOT/bin/qa-app.sh
export E=$QA_EVIDENCE/S4
shot() { # shot <subdir> <name>
  mkdir -p $E/$1; $APP $S screenshot $E/$1/$2.png >/dev/null; echo "$E/$1/$2.png"
}
sh2() { # shot + ui
  shot $1 $2; $APP $S ui ${3:-60}
}
t() { $APP $S tapon "$1"; }
# adb input text drops spaces (qa-app.sh `text` passes an unquoted arg); use %s
typetext() { adb -s $S shell input text "'$(printf '%s' "$1" | sed 's/ /%s/g')'"; }
clearinput() { adb -s $S shell input keyevent KEYCODE_MOVE_END; for i in $(seq 1 150); do adb -s $S shell input keyevent 67; done; }
# PIN pad is a custom view; `input text` does nothing. Tap the digit buttons.
pin() { for d in $(echo "${1:-1234}" | grep -o .); do $APP $S tapon "resource-id=\"hashengineering.darkcoin.wallet_test:id/btn_$d\"" >/dev/null; sleep 0.4; done; echo "pin $1 entered"; }
launchapp() { adb -s $S shell am start -n hashengineering.darkcoin.wallet_test/de.schildbach.wallet.ui.OnboardingActivity >/dev/null 2>&1; }
