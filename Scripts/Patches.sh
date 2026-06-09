#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
#
# 补丁注入脚本 — 使用标准补丁文件应用修改
# 操作: DTS 复制 → git apply 设备定义/LED/WiFi MAC 补丁
set -euo pipefail

WRT_DIR="${1:-./wrt}"
PATCHES_DIR="$GITHUB_WORKSPACE/patches"

LOG() { echo "=== $* ==="; }

APPLY_PATCH() {
	local PATCH_FILE="$1"
	local DESCRIPTION="$2"

	if [ ! -f "$PATCH_FILE" ]; then
		LOG "SKIP (patch not found): $PATCH_FILE"
		return 0
	fi

	LOG "Applying: $DESCRIPTION"
	cd "$WRT_DIR"
	if git apply --check "$PATCH_FILE" 2>/dev/null; then
		git apply "$PATCH_FILE"
		LOG "PATCHED: $DESCRIPTION"
	elif grep -q "$(basename "$PATCH_FILE" .patch)" "$WRT_DIR/target/linux/mediatek/image/filogic.mk" 2>/dev/null; then
		LOG "ALREADY PATCHED: $DESCRIPTION"
	else
		LOG "FAILED: $DESCRIPTION"
		git apply --verbose "$PATCH_FILE"
		return 1
	fi
}

LOG "Apply Patches"

# 复制设备树文件
if [ -d "$PATCHES_DIR" ]; then
	for DTS in "$PATCHES_DIR"/*.dts; do
		[ -f "$DTS" ] || continue
		cp -vf "$DTS" "$WRT_DIR/target/linux/mediatek/dts/"
	done
fi

# 应用标准补丁文件
APPLY_PATCH "$PATCHES_DIR/filogic-c8-660.patch" "Device definition (filogic.mk)"
APPLY_PATCH "$PATCHES_DIR/01_leds.patch" "LED definitions (01_leds)"
APPLY_PATCH "$PATCHES_DIR/11_fix_wifi_mac.patch" "WiFi MAC fix (11_fix_wifi_mac)"

LOG "Done"