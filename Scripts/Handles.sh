#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#修改aurora菜单式样
AURORA_DIR=$(find . -maxdepth 1 -type d -iname "*luci-app-aurora-config*" 2>/dev/null | head -1)
if [ -n "$AURORA_DIR" ]; then
	echo " " && cd "$AURORA_DIR/"

	TEMPLATE_FILES=$(find ./root/usr/share/aurora/ -type f -name "*.template" 2>/dev/null || true)
	if [ -n "$TEMPLATE_FILES" ]; then
		sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" "$TEMPLATE_FILES"
	fi

	cd "$PKG_PATH" && echo "theme-aurora has been fixed!"
fi
