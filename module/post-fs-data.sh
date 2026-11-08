#!/system/bin/sh
MODDIR=${0%/*}
# Afterimage compensation off (config_AFC_type 5 -> 0) in the c1s product RRO.
# Only if the original file is exactly the one this patch was built from.
RRO=/product/overlay/framework-res__c1sxxx__auto_generated_rro_product.apk
ORIG_SHA=390d66476e3fc5114b5fb7356a520262de1da168e7594a457d3634e7b05a038f
NEW="$MODDIR/overlay/rro_product_noafc.apk"
if [ -f "$RRO" ] && [ -f "$NEW" ] && [ "$(sha256sum "$RRO" | cut -d' ' -f1)" = "$ORIG_SHA" ]; then
  mount -o bind "$NEW" "$RRO"
fi
