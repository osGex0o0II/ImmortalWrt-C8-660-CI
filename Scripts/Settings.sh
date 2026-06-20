#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

# 移除 luci-app-attendedsysupgrade 并修改默认主题
ATTENDED_MAKEFILE="./feeds/luci/collections/luci/Makefile"
if [ -f "$ATTENDED_MAKEFILE" ]; then
	sed -i "/attendedsysupgrade/d" "$ATTENDED_MAKEFILE"
	sed -i "s|luci-theme-bootstrap|luci-theme-$WRT_THEME|g" "$ATTENDED_MAKEFILE"
else
	echo "WARNING: $ATTENDED_MAKEFILE not found — attendedsysupgrade/theme not modified" >&2
fi

# 修改 immortalwrt.lan 关联 IP
FLASH_JS="./feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/flash.js"
if [ -f "$FLASH_JS" ]; then
	if grep -q "192\.168\.[0-9]*\.[0-9]*" "$FLASH_JS"; then
		sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$FLASH_JS"
	else
		echo "WARNING: flash.js default IP pattern not found — upstream may have changed" >&2
	fi
else
	echo "WARNING: $FLASH_JS not found — IP not modified" >&2
fi

# 添加编译日期标识
STATUS_JS="./feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/10_system.js"
if [ -f "$STATUS_JS" ]; then
	sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" "$STATUS_JS"
else
	echo "WARNING: $STATUS_JS not found — build date not added" >&2
fi

# 修改 WiFi 默认配置
WIFI_SH="./target/linux/mediatek/filogic/base-files/etc/uci-defaults/99_set-wireless.sh"
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	# 修改 WiFi 名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$WIFI_SH"
	if [ -n "$WRT_WORD" ]; then
		sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$WIFI_SH"
	else
		sed -i "s/BASE_WORD='.*'/BASE_WORD=''/g" "$WIFI_SH"
	fi
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" "$WIFI_UC"
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" "$WIFI_UC"
	if [ -n "$WRT_WORD" ]; then
		sed -i "s/key='.*'/key='$WRT_WORD'/g" "$WIFI_UC"
		sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" "$WIFI_UC"
	else
		sed -i "/key=/d" "$WIFI_UC"
		sed -i "s/encryption='.*'/encryption='none'/g" "$WIFI_UC"
	fi
else
	echo "ERROR: No WiFi config file found (set-wireless.sh or mac80211.uc) — WiFi defaults NOT set." >&2
	exit 1
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
	#修改默认IP地址
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
	#修改默认主机名
	sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
else
	echo "ERROR: $CFG_FILE not found — IP/hostname defaults NOT set." >&2
	exit 1
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
# luci-theme is set in OPEN.txt for the mt76 build.

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

# === mt76 WiFi 性能优化 ===

# WED 启用由 ImmortalWrt mt76 包在 filogic 目标中通过 mt7915e 模块参数提供。
# 不在 base-files 中注入 /etc/modules.conf，避免覆盖 ubox 拥有的 conffile。
MT76_MAKEFILE="./package/kernel/mt76/Makefile"
if [ "${ENABLE_WED:-true}" = "true" ]; then
	if grep -q '^[[:space:]]*MODPARAMS\.mt7915e:=wed_enable=Y$' "$MT76_MAKEFILE"; then
		echo "mt76 WED enabled by upstream mt7915e module parameters"
	else
		echo "WARNING: upstream mt76 WED module parameter not found for mt7915e" >&2
	fi
elif [ "${ENABLE_WED:-true}" != "true" ]; then
	if [ -f "$MT76_MAKEFILE" ]; then
		sed -i '/^[[:space:]]*MODPARAMS\.mt7915e:=wed_enable=Y$/d' "$MT76_MAKEFILE"
		echo "mt76 WED disabled in upstream mt76 module parameters"
	else
		echo "WARNING: $MT76_MAKEFILE not found — WED module parameters not modified" >&2
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

# === 启用 Packet Steering (RPS，多核软中断分摊) ===
mkdir -p ./package/base-files/files/etc/uci-defaults
cat > ./package/base-files/files/etc/uci-defaults/99-enable-packet-steering << 'PACKET_STEERING'
#!/bin/sh
uci -q set network.@globals[0].packet_steering='1'
uci -q commit network
exit 0
PACKET_STEERING
chmod +x ./package/base-files/files/etc/uci-defaults/99-enable-packet-steering
echo "Packet steering enabled by default"

# === 启用防火墙流卸载 (Flow Offloading) ===
FW_CONF="./package/network/config/firewall/files/firewall.config"
if [ "${ENABLE_FLOW_OFFLOADING:-true}" = "true" ] && [ -f "$FW_CONF" ]; then
	sed -i "s/option flow_offloading '0'/option flow_offloading '1'/g" "$FW_CONF"
	sed -i "s/option flow_offloading_hw '0'/option flow_offloading_hw '1'/g" "$FW_CONF"
	echo "Firewall flow offloading enabled"
elif [ "${ENABLE_FLOW_OFFLOADING:-true}" != "true" ]; then
	echo "Firewall flow offloading disabled by workflow input"
else
	echo "WARNING: $FW_CONF not found — flow offloading not set" >&2
fi

# === BBR 默认拥塞控制 + 更多 sysctl 优化 ===
cat >> ./package/base-files/files/etc/sysctl.d/90-wifi-tune.conf << 'BBR'

# BBR TCP 拥塞控制
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# TCP 快速打开
net.ipv4.tcp_fastopen=3

# 连接跟踪优化
net.netfilter.nf_conntrack_max=65536
net.netfilter.nf_conntrack_buckets=8192

# IRQ 均衡辅助
net.core.rps_sock_flow_entries=32768
BBR
echo "BBR + sysctl optimizations applied"
