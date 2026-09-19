These 7 locale folders were captured with `qa-app.sh <serial> locale <bcp47>` (setprop persist.sys.locale
+ zygote restart). On this API-35 AVD that does NOT change the effective locale:
  getprop persist.sys.locale  -> fil-PH
  settings get system system_locales -> en-US
and the system Settings app + launcher also stayed English. Every screenshot here is therefore en-US and
proves only the tooling bug, not app behaviour. The real sweep is in ../<locale>/, captured with
  cmd locale set-app-locales hashengineering.darkcoin.wallet_test --user 0 --locales <bcp47>
