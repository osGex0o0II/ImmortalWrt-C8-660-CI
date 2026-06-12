#!/bin/sh
# V12 默认配置 — 闭源构建专用
# 克隆 V12 系统的 NTP、时区等设置

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

uci delete system.led_wifi 2>/dev/null
uci set system.led_wifi=led
uci set system.led_wifi.name='WIFI'
uci set system.led_wifi.sysfs='hc:blue:wifi'
uci set system.led_wifi.trigger='netdev'
uci set system.led_wifi.mode='link rx tx'
uci set system.led_wifi.dev='rax0'

# 设置 LuCI 主题为 Aurora
uci set luci.main.mediaurlbase='/luci-static/aurora'

# 设置防火墙 flow offloading (V12 风格)
uci set firewall.@defaults[0].fullcone='0'

# 提交更改
uci commit system
uci commit luci
uci commit firewall

exit 0
