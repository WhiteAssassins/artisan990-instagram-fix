#!/system/bin/sh
# Per-app blur off: listens for activity-resume events (no polling) and
# enables Samsung "Reduce transparency and blur" only while a listed app
# is in the foreground.
MODDIR=${0%/*}
APPS="$MODDIR/apps.txt"
KEY=accessibility_reduce_transparency

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done

set_for_pkg() {
  if [ -n "$1" ] && grep -qxF "$1" "$APPS"; then want=1; else want=0; fi
  if [ "$want" != "$STATE" ]; then
    settings put global $KEY $want
    STATE=$want
  fi
}

while true; do
  STATE="$(settings get global $KEY)"
  # Current foreground app, once, then follow new events only.
  cur="$(dumpsys activity activities 2>/dev/null | grep -m1 -E 'topResumedActivity|mResumedActivity' | grep -oE '[a-zA-Z0-9_.]+/' | head -1)"
  set_for_pkg "${cur%/}"
  since="$(date '+%m-%d %H:%M:%S.000')"
  logcat -b events -v raw -T "$since" -s wm_set_resumed_activity 2>/dev/null |
  while read -r line; do
    case "$line" in \[*) ;; *) continue ;; esac
    pkg="${line#*,}"; pkg="${pkg%%/*}"
    set_for_pkg "$pkg"
  done
  sleep 2
done
