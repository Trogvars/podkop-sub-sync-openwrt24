include $(TOPDIR)/rules.mk

PKG_NAME:=podkop-sub-sync
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Andy Shu
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/podkop-sub-sync
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Podkop subscription sync (OpenWrt 24.x)
  PKGARCH:=all
  DEPENDS:=+curl +jq +ca-bundle
endef

define Package/podkop-sub-sync/description
Synchronizes VPN subscription links with Podkop URLTest on OpenWrt 24.x.
Supports VLESS, Trojan and Shadowsocks, country filtering, XHTTP filtering,
and real proxy availability prechecks. Podkop and sing-box must already be installed.
endef

define Package/podkop-sub-sync/conffiles
/etc/config/podkop-sub-sync
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/podkop-sub-sync/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/podkop-sub-sync $(1)/usr/bin/podkop-sub-sync
	$(INSTALL_BIN) ./files/usr/bin/podkop-sub-precheck $(1)/usr/bin/podkop-sub-precheck
	$(INSTALL_BIN) ./files/usr/bin/podkop-sub-sync-daemon $(1)/usr/bin/podkop-sub-sync-daemon

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/podkop-sub-sync $(1)/etc/init.d/podkop-sub-sync

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/podkop-sub-sync $(1)/etc/config/podkop-sub-sync
endef

$(eval $(call BuildPackage,podkop-sub-sync))
