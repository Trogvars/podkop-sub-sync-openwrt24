#!/bin/ash
set -e

# ------------------------------------------------------------
# podkop-sub-sync OpenWrt 24.x bootstrap installer
#
# Before publishing, set your real repository here:
#   REPO="OWNER/podkop-sub-sync-openwrt24"
#
# Example one-line install:
#   wget -qO- https://raw.githubusercontent.com/OWNER/podkop-sub-sync-openwrt24/main/install.sh \
#     | sh -s -- --url 'https://example/sub/xxx' --interval 86400 --exclude RU
# ------------------------------------------------------------

REPO="${PODKOP_SYNC_REPO:-Trogvars/podkop-sub-sync-openwrt24}"
BRANCH="${PODKOP_SYNC_BRANCH:-main}"

log()
{
    echo "[podkop-sub-sync] $*"
}

die()
{
    log "ERROR: $*"
    exit 1
}

usage()
{
    cat <<'EOF'
Usage:
  install.sh [options]

Options:
  --url URL          subscription URL
  --interval SEC     update interval in seconds
  --exclude CC       exclude country; may be repeated
  --no-start         install and enable service, but do not start it
  --branch NAME      GitHub branch/tag to download (default: main)
  -h, --help         show this help

Examples:
  wget -qO- RAW_URL | sh -s -- \
      --url 'https://example/sub/xxx' \
      --interval 86400 \
      --exclude RU

  wget -qO- RAW_URL | sh -s -- \
      --url 'https://example/sub/xxx' \
      --exclude RU \
      --exclude UZ
EOF
}

# Keep the original installer arguments so we can forward them later.
FORWARD_ARGS=""

append_arg()
{
    # Shell-safe single-quote escaping for eval below.
    escaped="$(printf "%s" "$1" | sed "s/'/'\\\\''/g")"
    FORWARD_ARGS="${FORWARD_ARGS} '${escaped}'"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --url|--interval|--exclude)
            [ "$#" -ge 2 ] || die "missing value for $1"
            append_arg "$1"
            append_arg "$2"
            shift 2
            ;;
        --no-start)
            append_arg "$1"
            shift
            ;;
        --branch)
            [ "$#" -ge 2 ] || die "missing value for --branch"
            BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

[ "$(id -u)" = "0" ] || die "run as root"

command -v wget >/dev/null 2>&1 || die "wget not found"
command -v tar >/dev/null 2>&1 || die "tar not found"
command -v opkg >/dev/null 2>&1 || die "opkg not found; this bootstrap is for OpenWrt 24.x"

[ -r /etc/openwrt_release ] || die "/etc/openwrt_release not found"

. /etc/openwrt_release

case "${DISTRIB_RELEASE:-}" in
    24.*)
        ;;
    *)
        log "WARNING: detected OpenWrt release '${DISTRIB_RELEASE:-unknown}', expected 24.x"
        ;;
esac

case "$REPO" in
    OWNER/*)
        die "GitHub repository is not configured in install.sh (REPO=$REPO)"
        ;;
esac

TMP="$(mktemp -d /tmp/podkop-sub-sync-install.XXXXXX)" ||
    die "cannot create temporary directory"

cleanup()
{
    rm -rf "$TMP"
}

trap cleanup EXIT INT TERM

ARCHIVE="$TMP/source.tar.gz"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

log "OpenWrt: ${DISTRIB_RELEASE:-unknown}"
log "Repository: ${REPO}"
log "Branch: ${BRANCH}"
log "Downloading project..."

wget -O "$ARCHIVE" "$ARCHIVE_URL" ||
    die "download failed: $ARCHIVE_URL"

log "Extracting..."

tar -xzf "$ARCHIVE" -C "$TMP" ||
    die "cannot extract GitHub archive"

PROJECT_DIR=""

for d in "$TMP"/*; do
    [ -d "$d" ] || continue
    [ -f "$d/install-openwrt24.sh" ] || continue
    PROJECT_DIR="$d"
    break
done

[ -n "$PROJECT_DIR" ] ||
    die "install-openwrt24.sh not found in downloaded repository"

INSTALLER="$PROJECT_DIR/install-openwrt24.sh"
chmod 755 "$INSTALLER"

log "Starting OpenWrt 24.x installer..."

if [ -n "$FORWARD_ARGS" ]; then
    eval "\"$INSTALLER\" $FORWARD_ARGS"
else
    "$INSTALLER"
fi

log "Installation completed."
