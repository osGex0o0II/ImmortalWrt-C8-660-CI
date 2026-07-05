#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
SCRIPT="$ROOT_DIR/patches/files/usr/bin/c8-sms-forward"
TMP_DIR="$(mktemp -d)"
BIN_DIR="$TMP_DIR/bin"

cleanup() {
	rm -rf "$TMP_DIR"
	rm -rf /tmp/c8-sms-forward /tmp/c8-sms-forward.log
}
trap cleanup EXIT

fail() {
	echo "ERROR: $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

expect_rc() {
	local expected="$1"
	local name="$2"
	shift 2

	set +e
	"$@"
	local rc=$?
	set -e

	if [ "$rc" -ne "$expected" ]; then
		fail "$name returned $rc, expected $expected"
	fi
	echo "OK: $name returned $expected"
}

require_cmd jq
require_cmd bash
[ -x "$SCRIPT" ] || chmod +x "$SCRIPT"

mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/uci" <<'EOF'
#!/bin/sh
if [ "$1" = "-q" ]; then shift; fi
cmd="$1"
shift

case "$cmd:$1" in
	get:sms_tool.general.storage) echo ME ;;
	get:sms_tool.general.readport) echo /dev/ttyUSB2 ;;
	get:sms_tool.general.forward_enable) echo "${FAKE_FORWARD_ENABLE:-0}" ;;
	get:sms_tool.general.forward_complete_only) echo 1 ;;
	get:sms_tool.general.forward_delete_after) echo 0 ;;
	get:sms_tool.general.forward_primary_channel) echo ops_pushplus ;;
	get:sms_tool.general.forward_backup_enable) echo 0 ;;
	get:sms_tool.general.forward_backup_channel) echo backup_telegram ;;
	get:sms_tool.general.forward_retry_count) echo 0 ;;
	get:sms_tool.general.forward_retry_delay) echo 0 ;;
	get:sms_tool.general.sms_tool_timeout) echo "${FAKE_SMS_TIMEOUT:-2}" ;;
	get:sms_tool.ops_pushplus) echo forward_channel ;;
	get:sms_tool.backup_telegram) echo forward_channel ;;
	get:sms_tool.ops_pushplus.name) echo "Ops PushPlus" ;;
	get:sms_tool.backup_telegram.name) echo "Backup Telegram" ;;
	get:sms_tool.ops_pushplus.type) echo pushplus ;;
	get:sms_tool.backup_telegram.type) echo telegram ;;
	get:sms_tool.ops_pushplus.enabled) echo "${FAKE_CHANNEL_ENABLED:-0}" ;;
	get:sms_tool.backup_telegram.enabled) echo 0 ;;
	get:sms_tool.ops_pushplus.token) echo "${FAKE_PUSHPLUS_TOKEN:-}" ;;
	show:sms_tool)
		printf '%s\n' \
			'sms_tool.ops_pushplus=forward_channel' \
			'sms_tool.backup_telegram=forward_channel'
		;;
	*) exit 1 ;;
esac
EOF

cat > "$BIN_DIR/sms_tool" <<'EOF'
#!/bin/sh
case "${FAKE_SMS_MODE:-ok}" in
	hang) sleep 30 ;;
	fail)
		echo 'sms tool failure' >&2
		exit 7
		;;
	ok)
		printf '%s\n' '{"msg":[{"index":"1","sender":"+10086","timestamp":"2026-07-05 12:00","content":"hello from c8 sms test","part":1,"total":1}]}'
		;;
esac
EOF

cat > "$BIN_DIR/curl" <<'EOF'
#!/bin/sh
printf '%s\n' '{"code":200,"msg":"ok"}'
exit "${FAKE_CURL_EXIT:-0}"
EOF

chmod +x "$BIN_DIR/uci" "$BIN_DIR/sms_tool" "$BIN_DIR/curl"
export PATH="$BIN_DIR:$PATH"
export SMS_TOOL_BIN="$BIN_DIR/sms_tool"

rm -rf /tmp/c8-sms-forward /tmp/c8-sms-forward.log

STATUS_JSON="$("$SCRIPT" status)"
printf '%s' "$STATUS_JSON" | jq -e '.sms_tool_timeout == 5 and .channel_count == 2' >/dev/null || \
	fail "status JSON does not expose clamped sms_tool_timeout and channels"
echo "OK: status JSON exposes SMS timeout and channels"

expect_rc 0 "disabled scan" env FAKE_FORWARD_ENABLE=0 "$SCRIPT" once
expect_rc 1 "missing channel scan" env FAKE_FORWARD_ENABLE=1 FAKE_CHANNEL_ENABLED=0 "$SCRIPT" once
grep -q 'channel disabled or missing' /tmp/c8-sms-forward.log || fail "missing channel failure was not logged"

expect_rc 1 "sms_tool timeout scan" env FAKE_FORWARD_ENABLE=1 FAKE_CHANNEL_ENABLED=1 FAKE_PUSHPLUS_TOKEN=token FAKE_SMS_MODE=hang "$SCRIPT" once
grep -q 'sms_tool timeout after 5s' /tmp/c8-sms-forward.log || fail "sms_tool timeout was not logged"

rm -f /tmp/c8-sms-forward/sent.keys
expect_rc 0 "successful scan" env FAKE_FORWARD_ENABLE=1 FAKE_CHANNEL_ENABLED=1 FAKE_PUSHPLUS_TOKEN=token FAKE_SMS_MODE=ok "$SCRIPT" once
grep -q 'forwarded sms sender=' /tmp/c8-sms-forward.log || fail "successful forwarding was not logged"
test -s /tmp/c8-sms-forward/sent.keys || fail "successful forwarding did not mark sent state"

echo "OK: C8 SMS forwarding self-test passed"
