#!/bin/ash
set -e

BRANCH="${PODKOP_SYNC_BRANCH:-main}"

[ -r /etc/openwrt_release ] || {
  echo "ERROR: /etc/openwrt_release not found; OpenWrt is required"
  exit 1
}

. /etc/openwrt_release
OPENWRT_VERSION="${DISTRIB_RELEASE:-}"

if [ -z "$OPENWRT_VERSION" ] && [ -r /etc/os-release ]; then
  OPENWRT_VERSION="$(grep '^VERSION_ID=' /etc/os-release | head -n 1 | cut -d= -f2 | tr -d '"')"
fi

case "$OPENWRT_VERSION" in
  24.*)
    REPO="Trogvars/podkop-sub-sync-openwrt24"
    INSTALLER_NAME="install-openwrt24.sh"
    FAMILY="24.x (opkg/IPK)"
    ;;
  25.*)
    REPO="Trogvars/podkop-sub-sync-openwrt25"
    INSTALLER_NAME="install-podkop-sub-sync.sh"
    FAMILY="25.x (apk/APK)"
    ;;
  *)
    echo "ERROR: unsupported OpenWrt version: ${OPENWRT_VERSION:-unknown}"
    echo "Supported versions: OpenWrt 24.x and 25.x"
    exit 1
    ;;
esac

echo "[podkop-sub-sync] Detected OpenWrt ${OPENWRT_VERSION} -> ${FAMILY}"
echo "[podkop-sub-sync] Selected repository: ${REPO}"

TMP="$(mktemp -d /tmp/podkop-sub-sync-install.XXXXXX)" || exit 1
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
echo "[podkop-sub-sync] Downloading ${REPO}@${BRANCH}..."
wget -qO "$TMP/src.tar.gz" "$URL" || { echo "ERROR: failed to download $URL"; exit 1; }
tar -xzf "$TMP/src.tar.gz" -C "$TMP" || { echo "ERROR: failed to unpack source archive"; exit 1; }

INSTALLER="$(find "$TMP" -type f -name "$INSTALLER_NAME" | head -n 1)"
[ -n "$INSTALLER" ] || { echo "ERROR: $INSTALLER_NAME not found in downloaded project"; exit 1; }
chmod 755 "$INSTALLER"
exec "$INSTALLER" "$@"
