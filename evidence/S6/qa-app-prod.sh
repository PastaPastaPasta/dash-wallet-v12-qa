#!/bin/zsh
# qa-app.sh <serial> install <apk> | reinstall <apk> | launch | kill | uninstall | version | pull-logs <outdir> | mem [tag] | screenshot <out.png> | logcat-start <outfile> | logcat-stop
source ~/workspace/dash-wallet-qa/env.sh
S=$1; cmd=$2; shift 2
PKG=hashengineering.darkcoin.wallet
A() { adb -s "$S" "$@"; }
case "$cmd" in
  install)    A install "$1" ;;
  reinstall)  A install -r "$1" ;;          # in-place upgrade, keeps app data (the "upgrade" path)
  uninstall)  A uninstall $PKG ;;
  launch)     A shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; echo launched ;;
  kill)       A shell am force-stop $PKG; echo killed ;;
  version)    A shell dumpsys package $PKG | grep -E 'versionCode|versionName' | head -2 ;;
  pull-logs)  out=${1:-$QA_EVIDENCE/logs-$(date +%H%M%S)}; mkdir -p "$out"
              # testnet flavour wallet dir is world-readable in debug; on release use run-as (app is debuggable? no) -> fall back to tar via run-as or root
              A shell "run-as $PKG tar -cf - files/log 2>/dev/null" > "$out/applog.tar" 2>/dev/null
              if [[ ! -s "$out/applog.tar" ]]; then A root >/dev/null 2>&1; sleep 2; A shell "tar -cf - -C /data/data/$PKG files/log 2>/dev/null" > "$out/applog.tar"; fi
              (cd "$out" && tar -xf applog.tar 2>/dev/null && rm -f applog.tar); ls -la "$out"/files/log 2>/dev/null || echo "no app log pulled"; echo "logs in $out" ;;
  mem)        tag=${1:-mem}; echo "$(date +%FT%T) $tag $(A shell dumpsys meminfo $PKG 2>/dev/null | grep -E 'TOTAL PSS|Native Heap|Dalvik Heap|TOTAL:' | tr -s ' ' | tr '\n' '|')" ;;
  screenshot) A exec-out screencap -p > "$1"; echo "$1" ;;
  logcat-start) A logcat -c; ( adb -s "$S" logcat -v threadtime > "$1" 2>&1 ) & echo $! > "$1.pid"; echo "logcat -> $1 (pid $(cat $1.pid))" ;;
  logcat-stop)  [[ -f "$1.pid" ]] && { pkill -P $(cat "$1.pid") 2>/dev/null; kill $(cat "$1.pid") 2>/dev/null; }; echo stopped ;;
  ui)         A exec-out uiautomator dump /dev/tty 2>/dev/null | sed 's/></>\n</g' | grep -oE '(text|content-desc|resource-id)="[^"]+"' | grep -v '=""' | head -${1:-80} ;;
  tap)        A shell input tap $1 $2 ;;
  text)       A shell input text "$1" ;;
  key)        A shell input keyevent $1 ;;
  procstat)   A shell "ps -A | grep -E 'PID|$PKG'" ;;
  oom)        A shell "logcat -d -b crash 2>/dev/null | tail -50; dumpsys activity exit-info $PKG 2>/dev/null | head -60" ;;
  wallet-log)  # tail the app's own wallet.log (needs root on the emulator)
              A root >/dev/null 2>&1; sleep 1; A shell "tail -n ${1:-200} /data/data/$PKG/files/log/wallet.log" ;;
  grep-log)   A root >/dev/null 2>&1; sleep 1; A shell "grep -E '$1' /data/data/$PKG/files/log/wallet.log" | tail -n ${2:-100} ;;
  prefs)      A root >/dev/null 2>&1; sleep 1; A shell "ls /data/data/$PKG/shared_prefs; cat /data/data/$PKG/shared_prefs/${1:-*}.xml" 2>/dev/null | head -${2:-120} ;;
  files)      A root >/dev/null 2>&1; sleep 1; A shell "ls -la /data/data/$PKG/files /data/data/$PKG/files/log /data/data/$PKG/databases" 2>/dev/null ;;
  memlog)     # append a MEM sample line every N seconds to a file until stopped: memlog <outfile> [interval]
              out=$1; iv=${2:-60}; ( while true; do echo "$(date +%FT%T) $(A shell dumpsys meminfo $PKG 2>/dev/null | grep -E 'TOTAL PSS|Native Heap|Dalvik Heap' | tr -s ' ' | tr '\n' '|')" >> "$out"; sleep $iv; done ) & echo $! > "$out.pid"; echo "memlog -> $out (pid $(cat $out.pid))" ;;
  memlog-stop) [[ -f "$1.pid" ]] && kill $(cat "$1.pid") 2>/dev/null; echo stopped ;;
  lowmem)     # apply memory pressure: trim level to the app process
              A shell am send-trim-memory $PKG ${1:-RUNNING_CRITICAL} ;;
  bg)         A shell input keyevent KEYCODE_HOME; echo backgrounded ;;
  fg)         "$0" $S launch ;;
  lock)       A shell input keyevent 26; echo "screen off" ;;
  unlock)     A shell input keyevent KEYCODE_WAKEUP; sleep 1; A shell input keyevent 82; echo "woken/unlocked (no PIN set)" ;;
  net)        # net off|on  (airplane mode)
              if [[ "$1" == off ]]; then A shell svc wifi disable; A shell svc data disable; else A shell svc wifi enable; A shell svc data enable; fi; echo "network $1" ;;
  swipe)      A shell input swipe $1 $2 $3 $4 ${5:-300} ;;
  dump)       A exec-out uiautomator dump /dev/tty 2>/dev/null | sed 's/></>\n</g' | grep -E "$1" | head -${2:-40} ;;
  bounds)     # bounds "<text or resource-id substring>" -> prints center x y of first match
              A exec-out uiautomator dump /dev/tty 2>/dev/null | sed 's/></>\n</g' | grep -E "$1" | head -1 | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | sed -E 's/bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"/\1 \2 \3 \4/' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}' ;;
  tapon)      # tapon "<text or resource-id substring>"
              xy=$("$0" $S bounds "$1"); [[ -n "$xy" ]] && { A shell input tap $xy; echo "tapped '$1' at $xy"; } || { echo "no match for '$1'"; exit 1; } ;;
  rec-start)  # rec-start <name>  -> records screen to /sdcard/<name>.mp4 (max 180s per clip; call rec-stop then rec-pull)
              A shell "screenrecord --time-limit 180 --bit-rate 4000000 /sdcard/$1.mp4" >/dev/null 2>&1 & echo $! > /tmp/rec-$S-$1.pid; echo "recording $1 (pid $(cat /tmp/rec-$S-$1.pid))" ;;
  rec-stop)   A shell pkill -INT screenrecord >/dev/null 2>&1; sleep 2; echo "recording stopped" ;;
  rec-pull)   # rec-pull <name> <outdir>
              mkdir -p "$2"; A pull /sdcard/$1.mp4 "$2/$1.mp4" >/dev/null && A shell rm -f /sdcard/$1.mp4 && echo "$2/$1.mp4" ;;
  locale)     # locale <bcp47 e.g. de-DE | ja-JP | ar-EG | en-US>  (root emulator; restarts zygote, app must be relaunched)
              A root >/dev/null 2>&1; sleep 1; A shell "setprop persist.sys.locale $1; setprop ctl.restart zygote"; sleep 25; "$0" $S wait-boot; echo "locale now: $(A shell getprop persist.sys.locale)" ;;
  wait-boot)  for i in $(seq 1 60); do [[ "$(A shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && [[ -n "$(A shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus)" ]] && { echo booted; exit 0; }; sleep 3; done; echo "not booted"; exit 1 ;;
  fontscale)  A shell settings put system font_scale ${1:-1.3}; echo "font_scale=$1" ;;
  rotate)     # rotate 0|1|2|3
              A shell settings put system accelerometer_rotation 0; A shell settings put system user_rotation ${1:-1}; echo "rotation=$1" ;;
  setpin)     A shell locksettings set-pin ${1:-1234}; echo "device pin set" ;;
  clearpin)   A shell locksettings clear --old ${1:-1234}; echo "device pin cleared" ;;
  unlockpin)  A shell input keyevent KEYCODE_WAKEUP; sleep 1; A shell input keyevent 82; sleep 1; A shell input text ${1:-1234}; A shell input keyevent 66; echo unlocked ;;
  deeplink)   A shell am start -a android.intent.action.VIEW -d "$1" ;;
  exitinfo)   A shell dumpsys activity exit-info $PKG | head -80 ;;
  clip)       A shell "am broadcast -a clipper.set -e text '$1'" >/dev/null 2>&1; A shell "input keyevent KEYCODE_PASTE" >/dev/null 2>&1; echo "typed via input text instead:"; A shell input text "$1" ;;
esac
