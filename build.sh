#!/usr/bin/env bash
# Package the KernelSU module zip into dist/
set -euo pipefail
cd "$(dirname "$0")/module"
VER="$(grep '^version=' module.prop | cut -d= -f2)"
mkdir -p ../dist
rm -f "../dist/artisan990-instagram-fix-$VER.zip"
zip -r "../dist/artisan990-instagram-fix-$VER.zip" module.prop apps.txt customize.sh post-fs-data.sh service.sh uninstall.sh overlay/rro_product_noafc.apk >/dev/null
echo "dist/artisan990-instagram-fix-$VER.zip"
