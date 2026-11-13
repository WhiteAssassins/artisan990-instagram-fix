#!/system/bin/sh
# Per-app tweaks: listens for activity-resume events (no polling). While a
# listed app is in the foreground it:
#  - enables Samsung "Reduce transparency and blur"
#  - sets window/transition animation scale to 0, so closing a screen over an
#    HDR video doesn't squeeze the video layer into a thin strip that the
#    display hardware rejects (GPU fallback -> SurfaceFlinger abort)
#  - switches notification pop-ups from "Brief" (edge lighting window, which
#    has its own blur that ignores reduce transparency) to "Detailed"
# Your own values are saved and restored when you leave the app.
MODDIR=${0%/*}
APPS="$MODDIR/apps.txt"
SAVED="$MODDIR/anim.saved"
KEY=accessibility_reduce_transparency
# "namespace key value-while-in-app"
OVERRIDES="global:window_animation_scale:0 global:transition_animation_scale:0 system:edge_lighting:0"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done

anim_off() {
  if [ ! -f "$SAVED" ]; then
    : > "$SAVED.tmp"
    for o in $OVERRIDES; do
      ns=${o%%:*}; k=${o#*:}; k=${k%%:*}
      echo "$ns $k $(settings get $ns $k)" >> "$SAVED.tmp"
    done
    mv "$SAVED.tmp" "$SAVED"
  fi
  for o in $OVERRIDES; do
    ns=${o%%:*}; k=${o#*:}; v=${k#*:}; k=${k%%:*}
    settings put $ns $k $v
  done
}

anim_restore() {
  [ -f "$SAVED" ] || return 0
  while read -r ns k v; do
    [ -z "$v" ] && { v=$k; k=$ns; ns=global; }  # v2.1 format
    case "$v" in ''|null) settings delete $ns "$k" >/dev/null ;; *) settings put $ns "$k" "$v" ;; esac
  done < "$SAVED"
  rm -f "$SAVED"
}

set_for_pkg() {
  if [ -n "$1" ] && grep -qxF "$1" "$APPS"; then want=1; else want=0; fi
  if [ "$want" != "$STATE" ]; then
    settings put global $KEY $want
    if [ "$want" = 1 ]; then anim_off; else anim_restore; fi
    STATE=$want
  fi
}

while true; do
  # Start from a clean state (also undoes a leftover from a crash while in the app).
  anim_restore
  STATE=0
  settings put global $KEY 0
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
