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
# $4 — occurrence（可选，默认 1）：注入到第 N 个 esac 之前
INJECT_CASE() {
	local FILE="$1"
	local SNIPPET="$2"
	local MARKER="$3"
	local OCCURRENCE="${4:-1}"

	if [ ! -f "$FILE" ]; then
		LOG "SKIP (file not found): $FILE"
		return 0
	fi
	if [ ! -f "$SNIPPET" ]; then
		LOG "SKIP (snippet not found): $SNIPPET"
		return 0
	fi
	if grep -q "$MARKER" "$FILE"; then
		LOG "ALREADY PATCHED ($MARKER): $FILE"
	else
		SNIPPET_TMP="$(mktemp)"
		cat "$SNIPPET" > "$SNIPPET_TMP"

		if awk -v occ="$OCCURRENCE" '
			BEGIN { count = 0 }
			/^[[:space:]]*esac$/ {
				count++
				if (count == occ) {
					while ((getline line < "'"$SNIPPET_TMP"'") > 0)
						print line
					close("'"$SNIPPET_TMP"'")
				}
			}
			{ print }
		' "$FILE" > "$FILE.tmp"; then
			mv "$FILE.tmp" "$FILE"
			rm -f "$SNIPPET_TMP"
			LOG "PATCHED ($OCCURRENCE): $FILE"
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
shopt -s nullglob
if [ -d "$PATCHES_DIR" ]; then
	for DTS in "$PATCHES_DIR"/*.dts; do
		[ -f "$DTS" ] || continue
		cp -vf "$DTS" "$WRT_DIR/target/linux/mediatek/dts/"
	done
fi

# 安装 modem 管理文件（sendat + 脚本 + 配置 + 热插拔）
MODEM_SRC="$PATCHES_DIR/files"
MODEM_DST="$WRT_DIR/package/base-files/files"
if [ -d "$MODEM_SRC" ]; then
	LOG "Installing modem files from $MODEM_SRC to $MODEM_DST"
	mkdir -p "$MODEM_DST"
	for f in "$MODEM_SRC/"*; do
		[ -e "$f" ] || continue
		cp -rLvf "$f" "$MODEM_DST/"
	done
fi

# 追加设备定义到 filogic.mk（幂等检查）
for MK in "$PATCHES_DIR"/*.mk; do
	[ -f "$MK" ] || continue
	grep -q "nradio_wt9103" "$WRT_DIR/target/linux/mediatek/image/filogic.mk" 2>/dev/null || cat "$MK" >> "$WRT_DIR/target/linux/mediatek/image/filogic.mk"
done

# 注入 LED 行为定义
LED_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"
INJECT_CASE "$LED_FILE" "$PATCHES_DIR/01_leds.snippet" "nradio,wt9103"

# 注入 WiFi MAC 地址修复
MAC_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac"
INJECT_CASE "$MAC_FILE" "$PATCHES_DIR/11_fix_wifi_mac.snippet" "nradio,wt9103"

# 注入网络接口定义（第 1 个 esac — mediatek_setup_interfaces）
NET_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
INJECT_CASE "$NET_FILE" "$PATCHES_DIR/02_network_interfaces.snippet" "nradio,wt9103)" 1

# 注入 MAC 地址分配（第 2 个 esac — mediatek_setup_macs）
INJECT_CASE "$NET_FILE" "$PATCHES_DIR/02_network_macs.snippet" "mtd_get_mac_ascii bdinfo" 2

# 修复覆盖层脚本可执行权限
LOG "Fixing executable permissions for overlay files"
find "$MODEM_DST" -type f \( -name "*.sh" -o -name "sendat" -o -name "modeminit" -o -name "moimei" -o -name "mopdu" \) 2>/dev/null | while read f; do
	chmod +x "$f"
	LOG "+x $f"
done

LOG "Done"