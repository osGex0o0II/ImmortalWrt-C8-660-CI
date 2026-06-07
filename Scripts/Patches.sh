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
			log "PATCHED: $FILE"
		else
			rm -f "$FILE.tmp" "$SNIPPET_TMP"
			log "FAILED: $FILE"
			return 1
		fi
	fi

	log "DIAGNOSTIC tail of $FILE:"
	tail -15 "$FILE" | sed 's/^/    /'
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
	grep -q "nradio_c8-660" "$WRT_DIR/target/linux/mediatek/image/filogic.mk" 2>/dev/null || cat "$MK" >> "$WRT_DIR/target/linux/mediatek/image/filogic.mk"
done

LED_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/board.d/01_leds"
inject_case "$LED_FILE" "$PATCHES_DIR/01_leds.snippet" "nradio,wt9103"

MAC_FILE="$WRT_DIR/target/linux/mediatek/filogic/base-files/etc/hotplug.d/ieee80211/11_fix_wifi_mac"
inject_case "$MAC_FILE" "$PATCHES_DIR/11_fix_wifi_mac.snippet" "nradio,wt9103"

log "Done"
