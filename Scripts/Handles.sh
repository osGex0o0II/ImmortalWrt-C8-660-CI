#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
HP_DIR=$(find . -maxdepth 1 -type d -iname "*homeproxy*" 2>/dev/null | head -1)
if [ -n "$HP_DIR" ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="$HP_DIR/root/etc/homeproxy"

	rm -rf ./"$HP_PATH"/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*" || echo "0")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../"$HP_PATH"/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd "$PKG_PATH" && echo "homeproxy date has been updated!"
fi

#修改aurora菜单式样
AURORA_DIR=$(find . -maxdepth 1 -type d -iname "*luci-app-aurora-config*" 2>/dev/null | head -1)
if [ -n "$AURORA_DIR" ]; then
	echo " " && cd "$AURORA_DIR/"

	TEMPLATE_FILES=$(find ./root/usr/share/aurora/ -type f -name "*.template" 2>/dev/null || true)
	if [ -n "$TEMPLATE_FILES" ]; then
		sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $TEMPLATE_FILES
	fi

	cd "$PKG_PATH" && echo "theme-aurora has been fixed!"
fi
