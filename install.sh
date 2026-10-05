#!/bin/ash
set -e
REPO="Trogvars/podkop-sub-sync-openwrt24"
BRANCH="${PODKOP_SYNC_BRANCH:-main}"
TMP="$(mktemp -d /tmp/podkop-sub-sync-install.XXXXXX)" || exit 1
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM
URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
echo "[podkop-sub-sync] Downloading ${REPO}@${BRANCH}..."
wget -qO "$TMP/src.tar.gz" "$URL"
tar -xzf "$TMP/src.tar.gz" -C "$TMP"
INSTALLER="$(find "$TMP" -type f -name install-openwrt24.sh | head -n 1)"
[ -n "$INSTALLER" ] || { echo "ERROR: install-openwrt24.sh not found"; exit 1; }
chmod 755 "$INSTALLER"
exec "$INSTALLER" "$@"
