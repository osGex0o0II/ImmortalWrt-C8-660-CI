#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
VIEW="$ROOT_DIR/patches/files/www/luci-static/resources/view/c8modem/sms-forward.js"
MENU_JSON="$ROOT_DIR/patches/files/usr/share/luci/menu.d/luci-app-c8modem.json"
ACL_JSON="$ROOT_DIR/patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json"

fail() {
	echo "ERROR: $*" >&2
	exit 1
}

require_file() {
	[ -f "$1" ] || fail "missing file: $1"
}

require_pattern() {
	local file="$1"
	local pattern="$2"
	local desc="$3"

	require_file "$file"
	grep -Eq "$pattern" "$file" || fail "missing $desc in $file"
	echo "OK: $desc"
}

reject_pattern() {
	local file="$1"
	local pattern="$2"
	local desc="$3"

	require_file "$file"
	if grep -Eq "$pattern" "$file"; then
		fail "unexpected $desc in $file"
	fi
	echo "OK: no $desc"
}

node --check "$VIEW" >/dev/null
echo "OK: C8 SMS forwarding LuCI JS parses"

require_pattern "$MENU_JSON" '"admin/modem/sms/forward"' "SMS forwarding menu"
require_pattern "$MENU_JSON" '"path"[[:space:]]*:[[:space:]]*"c8modem/sms-forward"' "SMS forwarding menu target"
require_pattern "$VIEW" 'withBusyButton' "action click guard"
require_pattern "$VIEW" 'sms_tool_timeout' "sms_tool timeout option"
require_pattern "$VIEW" 'forward_primary_channel' "primary channel selector"
require_pattern "$VIEW" 'forward_backup_channel' "backup channel selector"
require_pattern "$VIEW" 'test-channel' "per-channel test action"
require_pattern "$VIEW" 'clear-log' "log clear action"
require_pattern "$VIEW" 'handleSaveApply' "Save & Apply service restart"
require_pattern "$VIEW" '/etc/init\.d/c8-sms-forward' "forward service restart"

for required_acl in \
	'"/usr/bin/c8-sms-forward \*"' \
	'"/etc/init.d/c8-sms-forward \*"'
do
	require_pattern "$ACL_JSON" "$required_acl" "ACL $required_acl"
done

for rejected_acl in \
	'"/bin/sh' \
	'"/bin/sendat 2 \*"' \
	'"/usr/bin/cellscan.sh \*"' \
	'"/usr/bin/iwinfo \*"' \
	'"/usr/share/modem/rm520n.sh"'
do
	reject_pattern "$ACL_JSON" "$rejected_acl" "broad ACL $rejected_acl"
done

echo "OK: C8 SMS forwarding LuCI self-test passed"
