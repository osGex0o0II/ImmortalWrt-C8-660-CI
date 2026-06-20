#!/bin/sh
# C8-660 默认配置
# 克隆 V12 系统的 NTP、时区等设置，并修正 Open/mt76 与 V12/mtwifi 的差异。

. /lib/functions.sh
. /lib/functions/system.sh

# 设置时区
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'

# 设置 NTP 服务器 (V12 风格)
uci delete system.ntp 2>/dev/null
uci set system.ntp=timeserver
uci set system.ntp.enabled='1'
uci set system.ntp.enable_server='0'
uci add_list system.ntp.server='ntp.tencent.com'
uci add_list system.ntp.server='ntp1.aliyun.com'
uci add_list system.ntp.server='ntp.ntsc.ac.cn'
uci add_list system.ntp.server='cn.ntp.org.cn'

# 设置 LED (V12 风格)
uci delete system.led_power 2>/dev/null
uci set system.led_power=led
uci set system.led_power.name='POWER'
uci set system.led_power.sysfs='hc:blue:status'
uci set system.led_power.default='1'

wifi_led_dev="phy1-ap0"
[ -e /sys/class/net/rax0 ] && wifi_led_dev="rax0"
[ -e /sys/class/net/phy1-ap0 ] && wifi_led_dev="phy1-ap0"
[ -e /sys/class/net/phy0-ap0 ] && [ ! -e /sys/class/net/phy1-ap0 ] && wifi_led_dev="phy0-ap0"

uci delete system.led_wifi 2>/dev/null
uci set system.led_wifi=led
uci set system.led_wifi.name='WIFI'
uci set system.led_wifi.sysfs='hc:blue:wifi'
uci set system.led_wifi.trigger='netdev'
uci set system.led_wifi.mode='link rx tx'
uci set system.led_wifi.dev="$wifi_led_dev"

# 设置 LuCI 主题为 Aurora
uci set luci.main.mediaurlbase='/luci-static/aurora'

# 设置防火墙 flow offloading (V12 风格)
uci set firewall.@defaults[0].fullcone='0'

# Open/mt76 上游默认会把 nradio,wt9103 的 WAN 写成不存在的 wan 设备；
# C8-660 的 5G 模块 RGMII 数据口实际是 eth1。
uci -q set network.wan.device='eth1'
uci -q set network.wan6.device='eth1'
base_mac="$(mtd_get_mac_ascii bdinfo fac_mac 2>/dev/null)"
case "$base_mac" in
	[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f])
		wan_mac="$(macaddr_add "$base_mac" 1)"
		uci -q set network.wan.macaddr="$wan_mac"
		uci -q set network.wan6.macaddr="$wan_mac"
	;;
esac
for section in $(uci -q show network | sed -n "s/^\(network\.[^.]*\)=device$/\1/p"); do
	[ "$(uci -q get "$section.name")" = "wan" ] && uci -q delete "$section"
done

# 补齐模块设置高级功能使用的 RM520N 默认项；升级保留用户已有值。
uci -q get modem.@ndis[0].nrmode >/dev/null || uci -q set modem.@ndis[0].nrmode='0'
uci -q get modem.@ndis[0].bandlist_sa >/dev/null || uci -q set modem.@ndis[0].bandlist_sa='0'
uci -q get modem.@ndis[0].bandlist_nsa >/dev/null || uci -q set modem.@ndis[0].bandlist_nsa='0'
uci -q get modem.@ndis[0].earfcn >/dev/null || uci -q set modem.@ndis[0].earfcn='0'
uci -q get modem.@ndis[0].cellid >/dev/null || uci -q set modem.@ndis[0].cellid='0'
uci -q get modem.@ndis[0].freqlock >/dev/null || uci -q set modem.@ndis[0].freqlock='0'
uci -q get modem.@ndis[0].autofreqlock >/dev/null || uci -q set modem.@ndis[0].autofreqlock='0'
uci -q get modem.@ndis[0].enable_native_ipv6 >/dev/null || uci -q set modem.@ndis[0].enable_native_ipv6='0'
uci -q get modem.@ndis[0].adbunlockkey >/dev/null || uci -q set modem.@ndis[0].adbunlockkey='0'

# 提交更改
uci commit system
uci commit luci
uci commit firewall
uci commit network
uci commit modem

exit 0
