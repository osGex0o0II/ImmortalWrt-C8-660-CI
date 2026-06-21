#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail

WRT_DIR="${1:-./wrt}"
WIRELESS_JS="$(find "$WRT_DIR" -path "*/resources/view/network/wireless.js" -print -quit 2>/dev/null || true)"

if [ -z "$WIRELESS_JS" ] || [ ! -f "$WIRELESS_JS" ]; then
	echo "ERROR: LuCI wireless.js not found" >&2
	exit 1
fi

python3 - "$WIRELESS_JS" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()

cipher_anchor = "ss.taboption('encryption', form.ListValue, 'cipher'"
cipher_pos = text.find(cipher_anchor)
if cipher_pos < 0:
    raise SystemExit(f"ERROR: cipher anchor not found in {path}")

cipher_values_start = text.find("o.value('auto'", cipher_pos)
cipher_values_end = text.find("o.write =", cipher_values_start)
if cipher_values_start < 0 or cipher_values_end < 0:
    raise SystemExit(f"ERROR: cipher option block not found in {path}")

cipher_replacement = """o.value('auto', _('auto'));
\t\t\t\to.value('ccmp', _('AES (CCMP)'));
\t\t\t\t"""
text = text[:cipher_values_start] + cipher_replacement + text[cipher_values_end:]

start = text.find("crypto_modes.sort(function(a, b) { return b[2] - a[2]; });")
if start < 0:
    start = text.find("crypto_modes.sort(function(a,b){return b[2]-a[2];});")
if start < 0:
    raise SystemExit(f"ERROR: crypto_modes sort anchor not found in {path}")

end_marker = "				// QR Code"
end = text.find(end_marker, start)
if end < 0:
    end_marker = "// QR Code"
    end = text.find(end_marker, start)
if end < 0:
    raise SystemExit(f"ERROR: QR Code anchor not found in {path}")

replacement = """const c8_crypto_modes = [], c8_crypto_map = {};
\t\t\t\tcrypto_modes.forEach(function(mode) { c8_crypto_map[mode[0]] = mode; });
\t\t\t\t[
\t\t\t\t\t['psk2', 'WPA2-PSK (AES)', 35],
\t\t\t\t\t['sae-mixed', 'WPA2/WPA3-Personal', 34],
\t\t\t\t\t['sae', 'WPA3-Personal', 33],
\t\t\t\t\t['none', _('No Encryption'), 0]
\t\t\t\t].forEach(function(mode) {
\t\t\t\t\tif (c8_crypto_map[mode[0]])
\t\t\t\t\t\tc8_crypto_modes.push(mode);
\t\t\t\t});
\t\t\t\tcrypto_modes.length = 0;
\t\t\t\tcrypto_modes.push.apply(crypto_modes, c8_crypto_modes);

\t\t\t\tcrypto_modes.sort(function(a, b) { return b[2] - a[2]; });

\t\t\t\tcrypto_modes.forEach(crypto_mode => {
\t\t\t\t\tencr.value(crypto_mode[0], crypto_mode[1]);
\t\t\t\t});

"""

text = text[:start] + replacement + text[end:]
path.write_text(text)
print(f"Patched wireless security options: {path}")
PY

if ! grep -q "WPA2/WPA3-Personal" "$WIRELESS_JS"; then
	echo "ERROR: wireless security simplification marker missing" >&2
	exit 1
fi

echo "LuCI wireless security options simplified"
