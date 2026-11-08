#!/usr/bin/env bash
# Rebuild module/overlay/rro_product_noafc.apk from the device's original overlay.
# Requires: adb (with root via KernelSU), Android SDK build-tools (aapt2, zipalign, apksigner), python3, keytool.
set -euo pipefail
BT="${ANDROID_BUILD_TOOLS:-$HOME/Library/Android/sdk/build-tools/36.0.0}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../module/overlay/rro_product_noafc.apk"
WORK="$(mktemp -d)"
RRO=/product/overlay/framework-res__c1sxxx__auto_generated_rro_product.apk

adb shell "su -c 'cp $RRO /data/local/tmp/rro_orig.apk && chmod 644 /data/local/tmp/rro_orig.apk'"
adb pull /data/local/tmp/rro_orig.apk "$WORK/orig.apk" >/dev/null
adb shell "su -c 'rm -f /data/local/tmp/rro_orig.apk'"

# Find the resource id of integer/config_AFC_type
LINE="$("$BT/aapt2" dump resources "$WORK/orig.apk" | grep -A1 'integer/config_AFC_type')"
echo "$LINE"
RES_ID="$(echo "$LINE" | grep -oE '0x7f[0-9a-f]{6}' | head -1)"
TYPE_ID="${RES_ID:4:2}"; ENTRY=$((16#${RES_ID:6:4}))
OLD="$(echo "$LINE" | tail -1 | grep -oE '[0-9]+$')"

(cd "$WORK" && unzip -q orig.apk resources.arsc)
python3 -I "$HERE/patch_arsc.py" "$WORK/resources.arsc" "$WORK/resources.patched.arsc" "$TYPE_ID" "$ENTRY" "$OLD" 0
python3 -I "$HERE/rebuild_apk.py" "$WORK/orig.apk" "$WORK/resources.patched.arsc" "$WORK/unsigned.apk"
"$BT/zipalign" -p -f 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"

KS="${KEYSTORE:-$HERE/../.signing/overlay.keystore}"
if [ ! -f "$KS" ]; then
  mkdir -p "$(dirname "$KS")"
  keytool -genkeypair -keystore "$KS" -storepass android -keypass android -alias overlay \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=artisan990-instagram-fix" >/dev/null 2>&1
fi
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android --out "$OUT" "$WORK/aligned.apk"

"$BT/aapt2" dump resources "$WORK/orig.apk" > "$WORK/a.txt"
"$BT/aapt2" dump resources "$OUT" > "$WORK/b.txt"
echo "Resource diff (should only be config_AFC_type):"
diff "$WORK/a.txt" "$WORK/b.txt" || true
echo "Original sha256: $(shasum -a 256 "$WORK/orig.apk" | cut -d' ' -f1)"
echo "Patched  sha256: $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
echo "Update ORIG_SHA / PATCHED_SHA in module/customize.sh and module/post-fs-data.sh if they changed."
