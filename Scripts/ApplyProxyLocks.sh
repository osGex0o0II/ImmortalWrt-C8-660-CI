#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

WRT_DIR="${1:-./wrt}"
REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCK_FILE="$REPO_DIR/.github/proxy-locks.env"
SING_BOX_MAKEFILE="$(
	find "$WRT_DIR/package/feeds" "$WRT_DIR/feeds" -path '*/sing-box/Makefile' -print -quit 2>/dev/null || true
)"

LOG() { echo "=== $* ==="; }

if [ ! -f "$LOCK_FILE" ]; then
	LOG "ERROR: proxy lock file not found: $LOCK_FILE"
	exit 1
fi

validate_lock() {
	local key="$1"
	local value="$2"
	case "$key" in
		SING_BOX_TAG)
			[[ "$value" =~ ^v[0-9]+(\.[0-9]+){1,3}$ ]]
			;;
		SING_BOX_VERSION)
			[[ "$value" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]
			;;
		SING_BOX_HASH)
			[[ "$value" =~ ^[0-9a-f]{64}$ ]]
			;;
		PKG_LOCK_homeproxy_BRANCH)
			[[ "$value" =~ ^[A-Za-z0-9._/-]+$ ]]
			;;
		PKG_LOCK_homeproxy_COMMIT)
			[[ "$value" =~ ^[0-9a-f]{40}$ ]]
			;;
		*)
			return 1
			;;
	esac
}

while IFS='=' read -r KEY VALUE; do
	[ -n "$KEY" ] || continue
	case "$KEY" in \#*) continue ;; esac
	VALUE="${VALUE%$'\r'}"
	if ! validate_lock "$KEY" "$VALUE"; then
		LOG "ERROR: invalid proxy lock entry: $KEY"
		exit 1
	fi
	printf -v "$KEY" '%s' "$VALUE"
done < "$LOCK_FILE"

if [ -z "$SING_BOX_MAKEFILE" ] || [ ! -f "$SING_BOX_MAKEFILE" ]; then
	LOG "ERROR: sing-box Makefile not found: $SING_BOX_MAKEFILE"
	exit 1
fi

if [ -z "${SING_BOX_VERSION:-}" ] || [ -z "${SING_BOX_HASH:-}" ]; then
	LOG "ERROR: SING_BOX_VERSION or SING_BOX_HASH missing from lock file"
	exit 1
fi

CURRENT_SING_BOX_VERSION="$(sed -n 's/^PKG_VERSION:=//p' "$SING_BOX_MAKEFILE" | head -1 | tr -d '\r')"
CURRENT_SING_BOX_HASH="$(sed -n 's/^PKG_HASH:=//p' "$SING_BOX_MAKEFILE" | head -1 | tr -d '\r')"

if [ "$CURRENT_SING_BOX_VERSION" = "$SING_BOX_VERSION" ] && [ "$CURRENT_SING_BOX_HASH" = "$SING_BOX_HASH" ]; then
	LOG "sing-box already pinned to $SING_BOX_VERSION"
	exit 0
fi

PYTHON_BIN=""
for CAND in python3 python; do
	CAND_PATH="$(command -v "$CAND" || true)"
	if [ -n "$CAND_PATH" ] && "$CAND_PATH" -c "" 2>/dev/null; then
		PYTHON_BIN="$CAND_PATH"
		break
	fi
done
if [ -z "$PYTHON_BIN" ]; then
	LOG "ERROR: python3/python is required to apply sing-box lock"
	exit 1
fi

"$PYTHON_BIN" - "$SING_BOX_MAKEFILE" "$SING_BOX_VERSION" "$SING_BOX_HASH" <<'PY'
from pathlib import Path
import re
import sys

makefile = Path(sys.argv[1])
version = sys.argv[2]
pkg_hash = sys.argv[3]
text = makefile.read_text(encoding='utf-8')
current_version = re.search(r'^PKG_VERSION:=(.*)$', text, flags=re.M)
current_hash = re.search(r'^PKG_HASH:=(.*)$', text, flags=re.M)
if current_version and current_hash:
    if current_version.group(1).strip() == version and current_hash.group(1).strip() == pkg_hash:
        print('unchanged')
        raise SystemExit(0)
text, count_version = re.subn(r'^PKG_VERSION:=.*$', f'PKG_VERSION:={version}', text, count=1, flags=re.M)
text, count_hash = re.subn(r'^PKG_HASH:=.*$', f'PKG_HASH:={pkg_hash}', text, count=1, flags=re.M)
if count_version != 1 or count_hash != 1:
    raise SystemExit('failed to update sing-box Makefile')
makefile.write_text(text, encoding='utf-8')
PY
LOG "Applied sing-box lock"
LOG "sing-box version: $SING_BOX_VERSION"
LOG "sing-box hash: $SING_BOX_HASH"
