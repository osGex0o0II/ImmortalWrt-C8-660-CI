#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
#
# 补丁注入脚本 — 将 C8-660 设备支持注入 ImmortalWrt mainline
# 操作: DTS 复制 → filogic.mk 追加 → LED case 注入 → WiFi MAC 修复
set -euo pipefail

WRT_DIR="${1:-./wrt}"
PATCHES_DIR="$GITHUB_WORKSPACE/patches"

LOG() { echo "=== $* ==="; }

# 向 case 语句中注入 snippet（esac 之前）
INJECT_CASE() {
	local FILE="$1"
	local SNIPPET="$2"
	local MARKER="$3"

	if [ ! -f "$FILE" ]; then
		LOG "SKIP (file not found): $FILE"
		return 0
	fi
	if [ ! -f "$SNIPPET" ]; then
		LOG "SKIP (snippet not found): $SNIPPET"
		return 0
	fi
	if grep -q "$MARKER" "$FILE"; then
		LOG "ALREADY PATCHED: $FILE"
	else
		SNIPPET_TMP="$(mktemp)"
		cat "$SNIPPET" > "$SNIPPET_TMP"

		if awk '
			/^esac$/ && !done {
				while ((getline line < snippet_file) > 0)
					print line
				close(snippet_file)
				done = 1
			}
			{ print }
		' snippet_file="$SNIPPET_TMP" "$FILE" > "$FILE.tmp"; then
			mv "$FILE.tmp" "$FILE"
			rm -f "$SNIPPET_TMP"
			LOG "PATCHED: $FILE"
		else
			rm -f "$FILE.tmp" "$SNIPPET_TMP"
			LOG "FAILED: $FILE"
			return 1
		fi
	fi

	LOG "DIAGNOSTIC tail of $FILE:"
	tail -15 "$FILE" | sed 's/^/    /'
}

LOG "Apply Patches"

# 复制设备树文件
if [ -d "$PATCHES_DIR" ]; then
	for DTS in "$PATCHES_DIR"/*.dts; do
		[ -f "$DTS" ] || continue
		cp -vf "$DTS" "$WRT_DIR/target/linux/mediatek/dts/"
	done
fi

# 追加设备定义到 filogic.mk（幂等检查）
for MK in "$PATCHES_DIR"/*.mk; do
	[ -f "$MK" ] || continue
	grep -q "nradio_c8-660" "$WRT_DIR/target/linux/mediatek/image/filogic.mk" 2>/dev/null || cat "$MK" >> "$WRT_DIR/target/linux/mediatek/image/filogic.mk"
done

# 注入 LED 行为定义
LED_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"
INJECT_CASE "$LED_FILE" "$PATCHES_DIR/01_leds.snippet" "nradio,wt9103"

# 注入 WiFi MAC 地址修复
MAC_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac"
INJECT_CASE "$MAC_FILE" "$PATCHES_DIR/11_fix_wifi_mac.snippet" "nradio,wt9103"

LOG "Done"
