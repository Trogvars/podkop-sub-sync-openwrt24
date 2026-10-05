#!/bin/ash
set -e
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SRC="$ROOT/package/files"
SUB_URL=""; INTERVAL=""; INCLUDES=""; EXCLUDES=""; NO_START=0; WITH_XHTTP=0
usage(){ cat <<'EOF'
Usage: install-openwrt24.sh [options]
  --url URL        VPN subscription URL
  --interval SEC   Refresh interval in seconds (default 86400)
  --include CC     Keep only this country; repeatable: --include RU --include KZ
  --exclude CC     Exclude country; repeatable: --exclude RU --exclude UZ
  --with-xhttp     Install/check sing-box-extended + Podkop XHTTP patch and enable XHTTP
  --no-start       Install and enable, but do not start
EOF
}
while [ "$#" -gt 0 ]; do
  case "$1" in
    --url) SUB_URL="$2"; shift 2;;
    --interval) INTERVAL="$2"; shift 2;;
    --include) INCLUDES="${INCLUDES}${INCLUDES:+ }$2"; shift 2;;
    --exclude) EXCLUDES="${EXCLUDES}${EXCLUDES:+ }$2"; shift 2;;
    --with-xhttp) WITH_XHTTP=1; shift;;
    --no-start) NO_START=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 2;;
  esac
done
[ "$(id -u)" = 0 ] || { echo "ERROR: run as root"; exit 1; }
command -v opkg >/dev/null 2>&1 || { echo "ERROR: opkg not found; OpenWrt 24.x required"; exit 1; }
[ -f /etc/config/podkop ] || { echo "ERROR: /etc/config/podkop not found"; exit 1; }
command -v sing-box >/dev/null 2>&1 || { echo "ERROR: sing-box not found"; exit 1; }
[ -r /usr/lib/podkop/sing_box_config_facade.sh ] || { echo "ERROR: Podkop libraries not found"; exit 1; }

echo "Updating opkg lists..."
opkg update
for p in curl jq ca-bundle; do
  opkg status "$p" 2>/dev/null | grep -q '^Status: .* installed' || opkg install "$p"
done
SB_EXT_URL="https://raw.githubusercontent.com/EikeiDev/OpenWRT-sing-box-extended/refs/heads/main/install.sh"
PODKOP_XHTTP_PATCH_URL="https://raw.githubusercontent.com/moix89/podkop-xhttp-patch/main/install.sh"

fetch_script(){
  url="$1"; dst="$2"
  if command -v wget >/dev/null 2>&1; then
    wget -O "$dst" "$url"
  else
    curl -fsSL "$url" -o "$dst"
  fi
}

ensure_xhttp_stack(){
  if ! sing-box version 2>/dev/null | grep -qi extended; then
    echo "XHTTP: sing-box-extended is required."
    [ -r /dev/tty ] || {
      echo "ERROR: sing-box-extended installer is interactive and no TTY is available."
      echo "Run manually: wget -O /tmp/sb-ext.sh $SB_EXT_URL && sh /tmp/sb-ext.sh"
      exit 1
    }
    fetch_script "$SB_EXT_URL" /tmp/sb-ext.sh
    chmod 700 /tmp/sb-ext.sh
    echo "Starting interactive sing-box-extended installer..."
    sh /tmp/sb-ext.sh </dev/tty >/dev/tty 2>&1
  fi

  sing-box version 2>/dev/null | grep -qi extended || {
    echo "ERROR: sing-box-extended is still not active."
    exit 1
  }

  if ! grep -q '^[[:space:]]*xhttp)' /usr/lib/podkop/sing_box_config_facade.sh; then
    echo "XHTTP: installing Podkop XHTTP patch..."
    fetch_script "$PODKOP_XHTTP_PATCH_URL" /tmp/podkop-xhttp-patch.sh
    chmod 700 /tmp/podkop-xhttp-patch.sh
    sh /tmp/podkop-xhttp-patch.sh
  fi

  grep -q '^[[:space:]]*xhttp)' /usr/lib/podkop/sing_box_config_facade.sh || {
    echo "ERROR: Podkop XHTTP parser patch was not detected after installation."
    exit 1
  }

  echo "XHTTP prerequisites OK:"
  sing-box version | head -n 1
  echo "Podkop XHTTP parser: enabled"
}

BACKUP="/root/podkop-sub-sync-openwrt24-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in /usr/bin/podkop-sub-sync /usr/bin/podkop-sub-precheck /usr/bin/podkop-sub-sync-daemon /etc/init.d/podkop-sub-sync; do
  [ -f "$f" ] && cp "$f" "$BACKUP/$(basename "$f")"
done

mkdir -p /usr/bin /etc/init.d /etc/config
cp "$SRC/usr/bin/podkop-sub-sync" /usr/bin/podkop-sub-sync
cp "$SRC/usr/bin/podkop-sub-precheck" /usr/bin/podkop-sub-precheck
cp "$SRC/usr/bin/podkop-sub-sync-daemon" /usr/bin/podkop-sub-sync-daemon
cp "$SRC/etc/init.d/podkop-sub-sync" /etc/init.d/podkop-sub-sync
chmod 755 /usr/bin/podkop-sub-sync /usr/bin/podkop-sub-precheck /usr/bin/podkop-sub-sync-daemon /etc/init.d/podkop-sub-sync

if [ ! -f /etc/config/podkop-sub-sync ]; then
  cp "$SRC/etc/config/podkop-sub-sync" /etc/config/podkop-sub-sync
  chmod 600 /etc/config/podkop-sub-sync
else
  echo "Preserving existing /etc/config/podkop-sub-sync"
fi

[ -n "$SUB_URL" ] && { uci set podkop-sub-sync.main.url="$SUB_URL"; uci set podkop-sub-sync.main.enabled='1'; }
[ -n "$INTERVAL" ] && uci set podkop-sub-sync.main.interval="$INTERVAL"
if [ -n "$INCLUDES" ]; then
  uci -q delete podkop-sub-sync.main.include_country || true
  for cc in $INCLUDES; do
    cc="$(echo "$cc" | tr '[:lower:]' '[:upper:]')"
    case "$cc" in [A-Z][A-Z]) ;; *) echo "ERROR: invalid include country $cc"; exit 2;; esac
    uci add_list podkop-sub-sync.main.include_country="$cc"
  done
fi
if [ -n "$EXCLUDES" ]; then
  uci -q delete podkop-sub-sync.main.exclude_country || true
  for cc in $EXCLUDES; do
    cc="$(echo "$cc" | tr '[:lower:]' '[:upper:]')"
    uci add_list podkop-sub-sync.main.exclude_country="$cc"
  done
fi
[ "$WITH_XHTTP" = 1 ] && uci set podkop-sub-sync.main.allow_xhttp='1'
uci commit podkop-sub-sync

if [ "$(uci -q get podkop-sub-sync.main.allow_xhttp || echo 0)" = 1 ]; then
  ensure_xhttp_stack
fi

/bin/ash -n /usr/bin/podkop-sub-sync
/bin/ash -n /usr/bin/podkop-sub-precheck
/bin/ash -n /usr/bin/podkop-sub-sync-daemon
/bin/ash -n /etc/init.d/podkop-sub-sync

/etc/init.d/podkop-sub-sync enable
if [ "$NO_START" = 0 ] && [ "$(uci -q get podkop-sub-sync.main.enabled)" = 1 ]; then
  /etc/init.d/podkop-sub-sync stop >/dev/null 2>&1 || true
  /etc/init.d/podkop-sub-sync start
fi

echo "Installed OpenWrt 24.x version. Backup: $BACKUP"
