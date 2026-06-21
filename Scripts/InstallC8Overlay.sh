#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

WRT_DIR="${1:-./wrt}"
REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
OVERLAY_SRC="$REPO_DIR/patches/files"
OVERLAY_DST="$WRT_DIR/package/base-files/files"

LOG() { echo "=== $* ==="; }

REQUIRE_FILE() {
	local FILE="$1"

	if [ ! -f "$FILE" ]; then
		LOG "ERROR: required overlay file not found: $FILE"
		return 1
	fi
}

REQUIRE_PATTERN() {
	local FILE="$1"
	local PATTERN="$2"
	local DESC="$3"

	REQUIRE_FILE "$FILE"
	if ! grep -Eq "$PATTERN" "$FILE"; then
		LOG "ERROR: overlay verification failed ($DESC): $FILE"
		return 1
	fi
	LOG "VERIFIED: $DESC"
}

if [ ! -d "$OVERLAY_SRC" ]; then
	LOG "ERROR: overlay source directory not found: $OVERLAY_SRC"
	exit 1
fi

LOG "Installing C8 overlay from $OVERLAY_SRC to $OVERLAY_DST"
mkdir -p "$OVERLAY_DST"
for f in "$OVERLAY_SRC/"*; do
	[ -e "$f" ] || continue
	cp -rLf "$f" "$OVERLAY_DST/"
done

# Local worktrees may retain empty legacy LuCI directories even though Git does
# not track them. Keep the generated rootfs overlay free of old Lua UI remnants.
find "$OVERLAY_DST/usr/lib/lua/luci" -depth -type d -empty -delete 2>/dev/null || true
rmdir "$OVERLAY_DST/usr/lib/lua" "$OVERLAY_DST/usr/lib" 2>/dev/null || true
if find "$OVERLAY_DST/usr/lib/lua/luci" -type f 2>/dev/null | grep -q .; then
	LOG "ERROR: legacy LuCI Lua files are present in the C8 overlay"
	find "$OVERLAY_DST/usr/lib/lua/luci" -type f 2>/dev/null | sed 's/^/    /'
	exit 1
fi

REQUIRED_OVERLAY_FILES="
bin/sendat
etc/config/modem
etc/config/sms_tool
etc/init.d/c8-sms-forward
etc/init.d/modeminit
etc/uci-defaults/99-v12-defaults.sh
sbin/set_sms_ports.sh
usr/bin/c8-sms-forward
usr/bin/cellscan.sh
usr/bin/rsrp2rssi
usr/share/luci/menu.d/luci-app-c8modem.json
usr/share/rpcd/acl.d/luci-app-c8modem.json
usr/share/modem/atcmd.sh
usr/share/modem/autofreqlock.sh
usr/share/modem/delatcmd.sh
usr/share/modem/enableipv6.sh
usr/share/modem/ipcheck.sh
usr/share/modem/luci-reinit.sh
usr/share/modem/moimei
usr/share/modem/mopdu
usr/share/modem/netmodeled.sh
usr/share/modem/Quectel
usr/share/modem/rm520n.sh
usr/share/modem/zinfo.sh
www/luci-static/resources/view/c8modem/at.js
www/luci-static/resources/view/c8modem/cellscan.js
www/luci-static/resources/view/c8modem/settings.js
www/luci-static/resources/view/c8modem/signal.js
www/luci-static/resources/view/c8modem/sms-forward.js
www/luci-static/resources/view/c8modem/sms-read.js
www/luci-static/resources/view/c8modem/sms-send.js
www/luci-static/resources/view/c8modem/sms-settings.js
www/luci-static/resources/view/c8modem/status.js
"

for rel in $REQUIRED_OVERLAY_FILES; do
	REQUIRE_FILE "$OVERLAY_DST/$rel"
done

REQUIRE_PATTERN "$OVERLAY_DST/usr/share/luci/menu.d/luci-app-c8modem.json" '"admin/modem/sms/forward"' "C8 SMS forwarding menu"
REQUIRE_PATTERN "$OVERLAY_DST/usr/share/luci/menu.d/luci-app-c8modem.json" '"admin/modem/cellscan"' "C8 base station scan menu"
REQUIRE_PATTERN "$OVERLAY_DST/usr/share/rpcd/acl.d/luci-app-c8modem.json" '"/usr/bin/c8-sms-forward \*"' "C8 SMS forwarding RPC permission"
REQUIRE_PATTERN "$OVERLAY_DST/usr/share/rpcd/acl.d/luci-app-c8modem.json" '"/usr/bin/cellscan.sh \*"' "C8 base station scan RPC permission"
REQUIRE_PATTERN "$OVERLAY_DST/etc/config/modem" "option simsel '0'" "external SIM default"
REQUIRE_PATTERN "$OVERLAY_DST/etc/config/sms_tool" "config forward_channel" "SMS forwarding channel config"
REQUIRE_PATTERN "$OVERLAY_DST/www/luci-static/resources/view/c8modem/sms-forward.js" "forward_primary_channel" "SMS primary/backup channel UI"

LOG "Fixing executable permissions for C8 overlay files"
find "$OVERLAY_DST" -type f \( \
	-name "*.sh" -o \
	-name "sendat" -o \
	-name "modeminit" -o \
	-name "c8-sms-forward" -o \
	-name "cellscan.sh" -o \
	-name "moimei" -o \
	-name "mopdu" -o \
	-name "rsrp2rssi" \
	\) 2>/dev/null | while IFS= read -r f; do
	chmod +x "$f"
	LOG "+x $f"
done

LOG "C8 overlay installed and verified"
