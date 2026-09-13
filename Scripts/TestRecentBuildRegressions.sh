#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
FAILURES=0

pass() {
	printf 'PASS: %s\n' "$1"
}

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	FAILURES=$((FAILURES + 1))
}

test_homeproxy_anchor() {
	local script="$REPO_ROOT/Scripts/PatchHomeProxyModern.sh"

	if python3 - "$script" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
old_anchor = "insert_after = \"\"\"const log_level = uci.get(uciconfig, ucimain, 'log_level') || 'warn';\\n/* UCI config end */\"\"\""
new_anchor = "insert_after = \"const log_level = uci.get(uciconfig, ucimain, 'log_level') || 'warn';\""
assert old_anchor not in text, "HomeProxy patch must not require the UCI end marker to be adjacent"
assert new_anchor in text, "HomeProxy patch must define a standalone log_level anchor"
assert "replace_required(gen_client_uc, insert_after, modern_guard)" in text
PY
	then
		pass 'HomeProxy patch anchors modern guard after log_level independently of later UCI variables'
	else
		fail 'HomeProxy patch must use an independent log_level anchor'
	fi
}

test_update_workflow_lease() {
	local workflow
	for workflow in \
		"$REPO_ROOT/.github/workflows/update-proxy-locks.yml" \
		"$REPO_ROOT/.github/workflows/update-init-build-sha.yml"
	do
		if python3 - "$workflow" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    'REMOTE_REF="refs/heads/$BRANCH"',
    'EXPECTED="$(git ls-remote origin "$REMOTE_REF" | awk \'{print $1}\')"',
    'git push --force-with-lease="$REMOTE_REF:$EXPECTED" origin "HEAD:$REMOTE_REF"',
    "concurrency:\n  group:",
    "  cancel-in-progress: false",
]
for fragment in required:
    assert fragment in text, f"missing workflow safeguard: {fragment}"
assert 'git push --force-with-lease origin "$BRANCH"' not in text
PY
		then
			pass "$(basename "$workflow") uses an explicit remote lease and concurrency"
		else
			fail "$(basename "$workflow") must use an explicit remote lease and concurrency"
		fi
	done
}

test_proxy_version_alignment() {
	if python3 - "$REPO_ROOT/.github/proxy-locks.env" "$REPO_ROOT/Scripts/RefreshProxyLocks.sh" "$REPO_ROOT/Scripts/PatchHomeProxyModern.sh" "$REPO_ROOT/.github/workflows/c8-660-open.yml" <<'PY'
import re
import sys
from pathlib import Path

lock, refresh, patch, workflow = [Path(item).read_text(encoding="utf-8") for item in sys.argv[1:]]
version = re.search(r"^SING_BOX_VERSION=(\d+)\.(\d+)", lock, re.M)
assert version and (int(version.group(1)), int(version.group(2))) >= (1, 14), \
    "HomeProxy requires sing-box 1.14 or newer"
assert "SING_BOX_MAX_MINOR=14" in refresh
assert 'HTTP_CLIENT_USES="$(awk' in patch and '" -lt 1' in patch
assert 'HTTP_CLIENT_USES="$(printf' in workflow and '" -lt 1' in workflow
PY
	then
		pass 'HomeProxy and sing-box locks share the required 1.14 compatibility line'
	else
		fail 'HomeProxy and sing-box locks must share the required 1.14 compatibility line'
	fi
}

test_homeproxy_anchor
test_update_workflow_lease
test_proxy_version_alignment

if [ "$FAILURES" -eq 0 ]; then
	printf 'OK: recent build regression tests passed\n'
else
	printf 'ERROR: %s regression test(s) failed\n' "$FAILURES" >&2
fi

exit "$FAILURES"
