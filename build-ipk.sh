#!/bin/sh
set -e
[ "$#" -eq 1 ] || { echo "Usage: $0 /path/to/openwrt-sdk-24.x"; exit 2; }
SDK="$(CDPATH= cd -- "$1" && pwd)"
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
[ -f "$SDK/rules.mk" ] || { echo "ERROR: not an OpenWrt SDK: $SDK"; exit 1; }
DEST="$SDK/package/podkop-sub-sync"
rm -rf "$DEST"; mkdir -p "$DEST"; cp -a "$HERE/package/." "$DEST/"
cd "$SDK"
./scripts/feeds update -a
./scripts/feeds install -a
if ! grep -q '^CONFIG_PACKAGE_podkop-sub-sync=' .config 2>/dev/null; then echo 'CONFIG_PACKAGE_podkop-sub-sync=m' >> .config; fi
make defconfig
make package/podkop-sub-sync/{clean,compile} V=s
find bin -type f -name 'podkop-sub-sync_*.ipk' -print
