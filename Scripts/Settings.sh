#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

#移除luci-app-attendedsysupgrade
ATTENDED_MAKEFILE=$(find ./feeds/luci/collections/ -type f -name "Makefile" 2>/dev/null | head -1)
if [ -n "$ATTENDED_MAKEFILE" ]; then
	sed -i "/attendedsysupgrade/d" "$ATTENDED_MAKEFILE"
	#修改默认主题
	sed -i "s|luci-theme-bootstrap|luci-theme-$WRT_THEME|g" "$ATTENDED_MAKEFILE"
fi

#修改immortalwrt.lan关联IP
FLASH_JS=$(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" 2>/dev/null | head -1)
if [ -n "$FLASH_JS" ]; then
	if grep -q "192\.168\.[0-9]*\.[0-9]*" "$FLASH_JS"; then
		sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$FLASH_JS"
	else
		echo "WARNING: flash.js default IP pattern not found — upstream may have changed" >&2
	fi
fi

#添加编译日期标识
STATUS_JS=$(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" 2>/dev/null | head -1)
if [ -n "$STATUS_JS" ]; then
	sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" "$STATUS_JS"
fi

WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	if [ -n "$WRT_WORD" ]; then
		sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
	else
		sed -i "s/BASE_WORD='.*'/BASE_WORD=''/g" $WIFI_SH
	fi
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	if [ -n "$WRT_WORD" ]; then
		sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
		sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
	else
		sed -i "/key=/d" $WIFI_UC
		sed -i "s/encryption='.*'/encryption='none'/g" $WIFI_UC
	fi
else
	echo "WARNING: No WiFi config file found (set-wireless.sh or mac80211.uc) — WiFi defaults NOT set." >&2
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
	#修改默认IP地址
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
	#修改默认主机名
	sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
else
	echo "WARNING: $CFG_FILE not found — IP/hostname defaults NOT set." >&2
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
# luci-theme and luci-app-theme-config already set in GENERAL.txt

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

# === mt76 WiFi 性能优化 ===

# WED 启用（硬件 WiFi offload，MT7981 + MT7915E 支持）
if [ -d "./package/kernel/mt76" ]; then
	MT76_DIR=$(find ./package/kernel/mt76 -type d -name "mt7915e" 2>/dev/null | head -1)
	if [ -n "$MT76_DIR" ]; then
		echo "options mt7915e wed_enable=Y" > "$MT76_DIR/mt7915e.conf"
		echo "mt76 WED enabled (hardware offload)"
	fi
fi

# 网络栈 buffer 优化
mkdir -p ./package/base-files/files/etc/sysctl.d
cat > ./package/base-files/files/etc/sysctl.d/90-wifi-tune.conf << 'SYSCTL'
# mt76 WiFi 网络栈优化
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_max=4194304
net.core.netdev_budget=600
net.core.netdev_budget_usecs=8000
SYSCTL
echo "Network stack tuning applied"
