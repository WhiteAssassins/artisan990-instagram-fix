#!/system/bin/sh
SKIPUNZIP=0
PLATFORM="$(getprop ro.board.platform)"
case "$PLATFORM" in
  universal990|exynos990) ;;
  *) abort "! This module is only for Exynos 990 (found: $PLATFORM)" ;;
esac
RRO=/product/overlay/framework-res__c1sxxx__auto_generated_rro_product.apk
ORIG_SHA=390d66476e3fc5114b5fb7356a520262de1da168e7594a457d3634e7b05a038f
PATCHED_SHA=afe759631159e7f077a6899fa0781c90dd47db045ad394f8bf29871b219fd25c
CUR_SHA="$(sha256sum "$RRO" 2>/dev/null | cut -d' ' -f1)"
if [ "$CUR_SHA" = "$ORIG_SHA" ] || [ "$CUR_SHA" = "$PATCHED_SHA" ]; then
  ui_print "- Afterimage compensation fix: compatible overlay found"
else
  ui_print "! Afterimage compensation fix: overlay differs from ArtisanROM 4.0.2 c1s, it will be skipped"
fi
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/apps.txt" 0 0 0644
set_perm "$MODPATH/overlay/rro_product_noafc.apk" 0 0 0644 u:object_r:system_file:s0
ui_print "- Blur will be disabled only while these apps are open:"
for p in $(cat "$MODPATH/apps.txt"); do ui_print "    $p"; done
ui_print "- Reboot to apply. Disable/remove this module to revert."
