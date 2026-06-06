#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

WRT_DIR="${1:-./wrt}"
PATCHES_DIR="$GITHUB_WORKSPACE/patches"

log() { echo "=== $* ==="; }

inject_case() {
	local FILE="$1"
	local SNIPPET="$2"
	local MARKER="$3"

	if [ ! -f "$FILE" ]; then
		log "SKIP (file not found): $FILE"
		return 0
	fi
	if [ ! -f "$SNIPPET" ]; then
		log "SKIP (snippet not found): $SNIPPET"
		return 0
	fi
	if grep -q "$MARKER" "$FILE"; then
		log "ALREADY PATCHED: $FILE"
		return 0
	fi

	local SNIPPET_CONTENT
	SNIPPET_CONTENT="$(cat "$SNIPPET")"

	awk -v snippet="$SNIPPET_CONTENT" '
		/^esac$/ && !done {
			print snippet
			done = 1
		}
		{ print }
	' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

	log "PATCHED: $FILE"
}

log "Apply Patches"

if [ -d "$PATCHES_DIR" ]; then
	for DTS in "$PATCHES_DIR"/*.dts; do
		[ -f "$DTS" ] || continue
		cp -vf "$DTS" "$WRT_DIR/target/linux/mediatek/dts/"
	done
fi

for MK in "$PATCHES_DIR"/*.mk; do
	[ -f "$MK" ] || continue
	cat "$MK" >> "$WRT_DIR/target/linux/mediatek/image/filogic.mk"
done

LED_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"
inject_case "$LED_FILE" "$PATCHES_DIR/01_leds.snippet" "nradio,wt9103"

MAC_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac"
inject_case "$MAC_FILE" "$PATCHES_DIR/11_fix_wifi_mac.snippet" "nradio,wt9103"

log "Done"
