##############################################
# OpenWrt Makefile for Doodle3D WifiBox firmware
##############################################
include $(TOPDIR)/rules.mk

#NOTE: this hack is required to get files included inside a define block, see this link:
#http://stackoverflow.com/questions/3524726/how-to-make-eval-shell-work-in-gnu-make
#The '¤' character must not appear in included scripts.
define newline


endef
IncludeWithNewlines = $(subst ¤,$(newline),$(shell cat $1 | tr '\n' '¤'))


# Name and release number of this package
PKG_NAME := wifibox
PKG_VERSION := 0.1.1
PKG_RELEASE := 8

# This specifies the directory where we're going to build the program.  
# The root build directory, $(BUILD_DIR), is by default the build_mipsel 
# directory in your OpenWrt SDK directory
PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/wifibox
	SECTION:=mods
	CATEGORY:=Doodle3D
	MENU:=1
#	DEFAULT:=y
	TITLE:=Doodle3D WifiBox firmware
	URL:=http://www.doodle3d.com/wifibox
	DEPENDS:=+lua +luafilesystem +libuci-lua +libiwinfo-lua +uhttpd +uhttpd-mod-lua +doodle3d-client +print3d
endef

define Package/wifibox/description
	Doodle3D WifiBox firmware
	Web interface to draw doodles and print them with ease.
	Automatically connects to known network or provide one to connect with.
	Intended to be used on TP-Link WR703n or MR3020.
endef

define Package/wifibox/config
	source "$(SOURCE)/Config.in"
endef

# Specify what needs to be done to prepare for building the package.
# In our case, we need to copy the source files to the build directory.
# This is NOT the default.  The default uses the PKG_SOURCE_URL and the
# PKG_SOURCE which is not defined here to download the source from the web.
# In order to just build a simple program that we have just written, it is
# much easier to do it this way.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) -r ./src/* $(PKG_BUILD_DIR)/
	$(CP) -r ./ReleaseNotes.md $(PKG_BUILD_DIR)/
endef

define Build/Configure
#	no configuration necessary
endef

define Build/Compile directives
#	no compilation necessary (although possible with luac?)
endef

# The $(1) variable represents the root directory on the router running 
# OpenWrt. The $(INSTALL_DIR) variable contains a command to prepare the install 
# directory if it does not already exist.  Likewise $(INSTALL_BIN) contains the 
# command to copy the binary file from its current location (in our case the build
# directory) to the install directory.

WIFIBOX_BASE_DIR := $(PKG_BUILD_DIR)
TGT_LUA_DIR_SUFFIX := usr/share/lua/wifibox

define Package/wifibox/install
### create required directories (autowifi)
	
#	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)
	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/network
#	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/rest
	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/rest/api
	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/script
	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/util
	$(INSTALL_DIR) $(1)/bin
	#$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/root/
	$(INSTALL_DIR) $(1)/root/sketches
	#$(INSTALL_DIR) $(1)/www
	$(INSTALL_DIR) $(1)/www/cgi-bin
	
### create all files in /usr/share/lua/autowifi (autowifi)
	
	$(CP) $(WIFIBOX_BASE_DIR)/opkg.conf $(1)/$(TGT_LUA_DIR_SUFFIX)/
	$(CP) $(WIFIBOX_BASE_DIR)/*.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/
	$(CP) $(WIFIBOX_BASE_DIR)/network/*.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/network/
	$(CP) $(WIFIBOX_BASE_DIR)/rest/*.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/rest/
	$(CP) $(WIFIBOX_BASE_DIR)/rest/api/*.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/rest/api/
	$(CP) $(WIFIBOX_BASE_DIR)/util/*.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/util/
	
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/d3d-updater.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/script
	$(LN) -s /$(TGT_LUA_DIR_SUFFIX)/script/d3d-updater.lua $(1)/bin/d3d-updater
	$(CP) $(WIFIBOX_BASE_DIR)/script/loglite-filters.lua $(1)/root/
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/loglite.lua $(1)/$(TGT_LUA_DIR_SUFFIX)/script
	$(LN) -s /$(TGT_LUA_DIR_SUFFIX)/script/loglite.lua $(1)/bin/loglite
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/wifibox_init $(1)/etc/init.d/wifibox
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/dhcpcheck_init $(1)/etc/init.d/dhcpcheck
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/d3dapi $(1)/$(TGT_LUA_DIR_SUFFIX)/script
	$(INSTALL_BIN) $(WIFIBOX_BASE_DIR)/script/signin.sh $(1)/$(TGT_LUA_DIR_SUFFIX)/script
	
	$(CP) $(WIFIBOX_BASE_DIR)/script/wifibox.uci.config $(1)/etc/config/wifibox  # copy base configuration to uci config dir
	$(CP) $(WIFIBOX_BASE_DIR)/FIRMWARE-VERSION $(1)/etc/wifibox-version

	echo "<html><body><pre><code>" > $(1)/www/ReleaseNotes.html
	cat $(WIFIBOX_BASE_DIR)/ReleaseNotes.md >> $(1)/www/ReleaseNotes.html
	echo "</code></pre></body></html>" >> $(1)/www/ReleaseNotes.html
	
ifeq ($(CONFIG_WIFIBOX_DEVEL_PACKAGE),y)
#	$(INSTALL_DIR) $(1)/$(TGT_LUA_DIR_SUFFIX)/test
#	$(CP) $(WIFIBOX_BASE_DIR)/test/* $(1)/$(TGT_LUA_DIR_SUFFIX)/test/
#	$(LN) -s /$(TGT_LUA_DIR_SUFFIX)/test $(1)/www/
endif
	
	
### create links elsewhere in the system (autowifi)
	$(LN) -s /$(TGT_LUA_DIR_SUFFIX)/script/d3dapi $(1)/www/cgi-bin
	$(LN) -s /root/sketches $(1)/www/
endef

define Package/wifibox/postinst
$(call IncludeWithNewlines,post-install.sh)
endef

define Package/wifibox/prerm
$(call IncludeWithNewlines,pre-remove.sh)
endef

define Package/wifibox/postrm
$(call IncludeWithNewlines,post-remove.sh)
endef

$(eval $(call BuildPackage,wifibox))
