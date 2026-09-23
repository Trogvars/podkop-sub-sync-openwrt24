# podkop-sub-sync-openwrt24

Separate OpenWrt 24.x / opkg / IPK edition of Podkop subscription sync.

## Key differences from OpenWrt 25.x

- Uses `opkg` and builds `.ipk` packages.
- Does **not** use `curl --compressed`.
- Subscription requests send `Accept-Encoding: identity` instead.
- If a server still returns raw gzip, the updater detects it with `gzip -t` and decompresses it itself.
- Package is `PKGARCH:=all`.
- Podkop and sing-box are runtime prerequisites, but are intentionally not hard SDK dependencies because they may come from a third-party feed.

OpenWrt build logic emits `.ipk` when `CONFIG_USE_APK` is not enabled; OpenWrt 24.10 uses opkg at runtime.

## Direct installation on a 24.x router

```sh
chmod +x install-openwrt24.sh
./install-openwrt24.sh \
  --url 'https://example/sub/...' \
  --interval 86400 \
  --exclude RU
```

## Build IPK with OpenWrt 24.x SDK

```sh
./build-ipk.sh /opt/openwrt-sdk-24.10.x-...
```

Or manually copy `package/` into the SDK as `package/podkop-sub-sync` and run:

```sh
make defconfig
make package/podkop-sub-sync/{clean,compile} V=s
find bin -name 'podkop-sub-sync_*.ipk'
```

## Install the IPK

```sh
opkg install ./podkop-sub-sync_1.0.0-1_all.ipk
```

Then configure:

```sh
uci set podkop-sub-sync.main.url='https://...'
uci set podkop-sub-sync.main.enabled='1'
uci add_list podkop-sub-sync.main.exclude_country='RU'
uci commit podkop-sub-sync
/etc/init.d/podkop-sub-sync enable
/etc/init.d/podkop-sub-sync start
```

## Verify

```sh
ubus call service list '{"name":"podkop-sub-sync"}'
logread | grep podkop-sub-sync | tail -100
```
