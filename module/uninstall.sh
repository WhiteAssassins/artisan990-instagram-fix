#!/system/bin/sh
MODDIR=${0%/*}
settings put global accessibility_reduce_transparency 0
if [ -f "$MODDIR/anim.saved" ]; then
  while read -r ns k v; do
    [ -z "$v" ] && { v=$k; k=$ns; ns=global; }  # v2.1 format
    case "$v" in ''|null) settings delete $ns "$k" ;; *) settings put $ns "$k" "$v" ;; esac
  done < "$MODDIR/anim.saved"
fi
