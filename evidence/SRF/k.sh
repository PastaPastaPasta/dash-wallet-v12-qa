#!/bin/zsh
# SRF keypad helper for the shielded Internal-transfer / Send screens (1080x2400)
source ~/workspace/dash-wallet-qa/env.sh
S=emulator-5566
t() { adb -s $S shell input tap $1 $2; sleep 0.45; }
case "$1" in
  1) t 212 1567;; 2) t 540 1567;; 3) t 868 1567;;
  4) t 212 1726;; 5) t 540 1726;; 6) t 868 1726;;
  7) t 212 1885;; 8) t 540 1885;; 9) t 868 1885;;
  .) t 212 2045;; 0) t 540 2045;; del) t 868 2045;;
  max) t 106 554;; cont) t 540 2221;; rev) t 540 874;;
  cur) t 559 613;; back) t 110 211;; info) t 968 211;;
  clear) for i in $(seq 1 14); do adb -s $S shell input tap 868 2045; done;;
  type) shift; for c in $(echo "$1" | grep -o .); do $0 $c; done;;
esac
