#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCK_FILE="$REPO_DIR/.github/proxy-locks.env"

LOG() { echo "=== $* ==="; }

GIT_REMOTE() {
	git -c http.proxy= -c https.proxy= "$@"
}

# sing-box: 1.14 已移除 go-json-experiment/json 依赖，Go 1.27 下可编译；
# 天花板放宽到 14，允许 rc/beta（如 v1.14.0-rc.1）
SING_BOX_MAX_MINOR=14

LATEST_SING_BOX_TAG="$(
	GIT_REMOTE ls-remote --tags --refs https://github.com/SagerNet/sing-box.git \
		| awk '{print $2}' \
		| sed 's#refs/tags/##' \
		| grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9\.]+)?$' \
		| awk -F. -v max="$SING_BOX_MAX_MINOR" '$2 <= max' \
		| sort -V \
		| tail -1
)"

if [ -z "$LATEST_SING_BOX_TAG" ]; then
	LOG "ERROR: failed to detect latest sing-box stable tag"
	exit 1
fi

TMP_TARBALL="$(mktemp)"
trap 'rm -f "$TMP_TARBALL"' EXIT

if ! curl -fsSL --retry 5 --retry-all-errors --http1.1 "https://codeload.github.com/SagerNet/sing-box/tar.gz/$LATEST_SING_BOX_TAG" -o "$TMP_TARBALL" 2>/dev/null; then
	python3 - "$LATEST_SING_BOX_TAG" "$TMP_TARBALL" <<'PY'
from pathlib import Path
import sys
import urllib.request

tag = sys.argv[1]
out = Path(sys.argv[2])
url = f"https://codeload.github.com/SagerNet/sing-box/tar.gz/{tag}"
with urllib.request.urlopen(url, timeout=30) as resp:
    out.write_bytes(resp.read())
PY
fi
LATEST_SING_BOX_HASH="$(sha256sum "$TMP_TARBALL" | awk '{print tolower($1)}')"
LATEST_SING_BOX_VERSION="${LATEST_SING_BOX_TAG#v}"
LATEST_SING_BOX_VERSION="${LATEST_SING_BOX_VERSION//-/_}"
LATEST_HOMEPROXY_COMMIT="$(
	GIT_REMOTE ls-remote --heads https://github.com/VIKINGYFY/packages.git main \
		| awk '{print $1}' \
		| head -1
)"

if [ -z "$LATEST_HOMEPROXY_COMMIT" ]; then
	LOG "ERROR: failed to detect latest HomeProxy master commit"
	exit 1
fi

mkdir -p "$(dirname "$LOCK_FILE")"
cat > "$LOCK_FILE" <<EOF
SING_BOX_TAG=$LATEST_SING_BOX_TAG
SING_BOX_VERSION=$LATEST_SING_BOX_VERSION
SING_BOX_HASH=$LATEST_SING_BOX_HASH
PKG_LOCK_homeproxy_BRANCH=main
PKG_LOCK_homeproxy_COMMIT=$LATEST_HOMEPROXY_COMMIT
EOF

LOG "Updated proxy locks"
LOG "sing-box: $LATEST_SING_BOX_TAG"
LOG "homeproxy: $LATEST_HOMEPROXY_COMMIT"
