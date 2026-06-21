#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

PKG_DIR="${1:-luci-app-homeproxy}"

LOG() { echo "=== $* ==="; }

REQUIRE_FILE() {
	local FILE="$1"

	if [ ! -f "$FILE" ]; then
		LOG "ERROR: required HomeProxy file not found: $FILE"
		return 1
	fi
}

REQUIRE_PATTERN() {
	local FILE="$1"
	local PATTERN="$2"
	local DESC="$3"

	REQUIRE_FILE "$FILE"
	if ! grep -Eq "$PATTERN" "$FILE"; then
		LOG "ERROR: HomeProxy modern-mode verification failed ($DESC): $FILE"
		return 1
	fi
	LOG "VERIFIED: $DESC"
}

NODE_JS="$PKG_DIR/htdocs/luci-static/resources/view/homeproxy/node.js"
SERVER_JS="$PKG_DIR/htdocs/luci-static/resources/view/homeproxy/server.js"
HP_JS="$PKG_DIR/htdocs/luci-static/resources/homeproxy.js"
GEN_CLIENT_UC="$PKG_DIR/root/etc/homeproxy/scripts/generate_client.uc"
UPDATE_SUBS_UC="$PKG_DIR/root/etc/homeproxy/scripts/update_subscriptions.uc"
MENU_JSON="$PKG_DIR/root/usr/share/luci/menu.d/luci-app-homeproxy.json"

for file in "$NODE_JS" "$SERVER_JS" "$HP_JS" "$GEN_CLIENT_UC" "$UPDATE_SUBS_UC" "$MENU_JSON"; do
	REQUIRE_FILE "$file"
done

LOG "Patching HomeProxy for C8 modern client mode"

PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON_BIN" ]; then
	LOG "ERROR: python3/python is required to patch HomeProxy"
	exit 1
fi

"$PYTHON_BIN" - "$NODE_JS" "$SERVER_JS" "$HP_JS" "$GEN_CLIENT_UC" "$UPDATE_SUBS_UC" "$MENU_JSON" <<'PY'
from pathlib import Path
import re
import sys

node_js, server_js, hp_js, gen_client_uc, update_subs_uc, menu_json = map(Path, sys.argv[1:])

def replace_required(path, old, new):
    text = path.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'missing expected block in {path}: {old[:80]!r}')
    path.write_text(text.replace(old, new), encoding='utf-8')

def regex_required(path, pattern, repl, flags=0):
    text = path.read_text(encoding='utf-8')
    new, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'missing expected pattern in {path}: {pattern}')
    path.write_text(new, encoding='utf-8')

replace_required(
    hp_js,
    """\tshadowsocks_encrypt_methods: [
\t\t/* Stream */
\t\t'none',
\t\t/* AEAD */
\t\t'aes-128-gcm',
\t\t'aes-192-gcm',
\t\t'aes-256-gcm',
\t\t'chacha20-ietf-poly1305',
\t\t'xchacha20-ietf-poly1305',
\t\t/* AEAD 2022 */
\t\t'2022-blake3-aes-128-gcm',
\t\t'2022-blake3-aes-256-gcm',
\t\t'2022-blake3-chacha20-poly1305'
\t],""",
    """\tshadowsocks_encrypt_methods: [
\t\t/* AEAD */
\t\t'aes-128-gcm',
\t\t'aes-192-gcm',
\t\t'aes-256-gcm',
\t\t'chacha20-ietf-poly1305',
\t\t'xchacha20-ietf-poly1305',
\t\t/* AEAD 2022 */
\t\t'2022-blake3-aes-128-gcm',
\t\t'2022-blake3-aes-256-gcm',
\t\t'2022-blake3-chacha20-poly1305'
\t],"""
)

replace_required(
    node_js,
    """\to = s.option(form.ListValue, 'type', _('Type'));
\to.value('direct', _('Direct'));
\to.value('anytls', _('AnyTLS'));
\to.value('http', _('HTTP'));
\tif (features.with_quic) {
\t\to.value('hysteria', _('Hysteria'));
\t\to.value('hysteria2', _('Hysteria2'));
\t}
\to.value('shadowsocks', _('Shadowsocks'));
\to.value('shadowtls', _('ShadowTLS'));
\to.value('socks', _('Socks'));
\to.value('ssh', _('SSH'));
\to.value('trojan', _('Trojan'));
\tif (features.with_quic)
\t\to.value('tuic', _('Tuic'));
\tif (features.with_wireguard && features.with_gvisor)
\t\to.value('wireguard', _('WireGuard'));
\to.value('vless', _('VLESS'));
\to.value('vmess', _('VMess'));
\to.rmempty = false;""",
    """\to = s.option(form.ListValue, 'type', _('Type'));
\to.value('direct', _('Direct'));
\to.value('anytls', _('AnyTLS'));
\tif (features.with_quic)
\t\to.value('hysteria2', _('Hysteria2'));
\to.value('shadowsocks', _('Shadowsocks'));
\to.value('trojan', _('Trojan'));
\tif (features.with_quic)
\t\to.value('tuic', _('Tuic'));
\tif (features.with_wireguard && features.with_gvisor)
\t\to.value('wireguard', _('WireGuard'));
\to.value('vless', _('VLESS'));
\to.rmempty = false;"""
)

replace_required(
    node_js,
    """\t/* Stream ciphers */
\to.value('aes-128-ctr');
\to.value('aes-192-ctr');
\to.value('aes-256-ctr');
\to.value('aes-128-cfb');
\to.value('aes-192-cfb');
\to.value('aes-256-cfb');
\to.value('chacha20');
\to.value('chacha20-ietf');
\to.value('rc4-md5');\n""",
    ""
)

replace_required(
    node_js,
    """\t\t\t\tif (type === 'shadowsocks') {
\t\t\t\t\tlet encmode = this.section.formvalue(section_id, 'shadowsocks_encrypt_method');
\t\t\t\t\tif (encmode === 'none')
\t\t\t\t\t\treturn true;
\t\t\t\t}
\t\t\t\tif (!value)""",
    """\t\t\t\tif (!value)"""
)

regex_required(
    node_js,
    r"\t\tcase 'http':\n\t\tcase 'https':[\s\S]*?\n\t\t\tbreak;\n\t\tcase 'hysteria':",
    "\t\tcase 'http':\n\t\tcase 'https':\n\t\t\treturn null;\n\t\tcase 'hysteria':"
)

regex_required(
    node_js,
    r"\t\tcase 'socks':\n\t\tcase 'socks4':\n\t\tcase 'socks4a':\n\t\tcase 'socsk5':\n\t\tcase 'socks5h':[\s\S]*?\n\t\t\tbreak;\n\t\tcase 'ss':",
    "\t\tcase 'socks':\n\t\tcase 'socks4':\n\t\tcase 'socks4a':\n\t\tcase 'socsk5':\n\t\tcase 'socks5h':\n\t\t\treturn null;\n\t\tcase 'ss':"
)

regex_required(
    node_js,
    r"\t\tcase 'vmess':[\s\S]*?\n\t\t}\n\t}\n\n\tif \(config\) \{",
    "\t\tcase 'vmess':\n\t\t\treturn null;\n\t\t}\n\t}\n\n\tif (config) {"
)

replace_required(
    node_js,
    """\t\t\t} catch(e) {
\t\t\t\t/* Legacy format https://github.com/shadowsocks/shadowsocks-org/commit/78ca46cd6859a4e9475953ed34a2d301454f579e */
\t\t\t\turi = uri[1].split('@');
\t\t\t\tif (uri.length < 2)
\t\t\t\t\treturn null;
\t\t\t\telse if (uri.length > 2)
\t\t\t\t\turi = [ uri.slice(0, -1).join('@'), uri.slice(-1).toString() ];

\t\t\t\tconfig = {
\t\t\t\t\ttype: 'shadowsocks',
\t\t\t\t\taddress: uri[1].split(':')[0],
\t\t\t\t\tport: uri[1].split(':')[1],
\t\t\t\t\tshadowsocks_encrypt_method: uri[0].split(':')[0],
\t\t\t\t\tpassword: uri[0].split(':').slice(1).join(':')
\t\t\t\t};
\t\t\t}

\t\t\tbreak;""",
    """\t\t\t} catch(e) {
\t\t\t\treturn null;
\t\t\t}

\t\t\tbreak;"""
)

regex_required(
    node_js,
    r"\to = s\.option\(form\.Value, 'vmess_alterid'[\s\S]*?\n\to\.modalonly = true;\n\t/\* VMess config end \*/",
    "\t/* VMess config end */"
)

replace_required(
    server_js,
    """\t\to = s.option(form.Flag, 'enabled', _('Enable'));
\t\to.default = o.enabled;""",
    """\t\to = s.option(form.Flag, 'enabled', _('Enable'));
\t\to.readonly = true;
\t\to.default = o.disabled;"""
)

regex_required(
    server_js,
    r"\t\to = s\.option\(form\.ListValue, 'type', _\('Type'\)\);[\s\S]*?\n\t\to\.rmempty = false;",
    "\t\to = s.option(form.ListValue, 'type', _('Type'));\n\t\to.value('anytls', _('AnyTLS'));\n\t\to.value('hysteria2', _('Hysteria2'));\n\t\to.value('shadowsocks', _('Shadowsocks'));\n\t\to.value('trojan', _('Trojan'));\n\t\tif (features.with_quic)\n\t\t\to.value('tuic', _('Tuic'));\n\t\to.value('vless', _('VLESS'));\n\t\to.rmempty = false;"
)

replace_required(
    menu_json,
    """,
\t\"admin/services/homeproxy/server\": {
\t\t\"title\": \"Server Settings\",
\t\t\"order\": 20,
\t\t\"action\": {
\t\t\t\"type\": \"view\",
\t\t\t\"path\": \"homeproxy/server\"
\t\t}
\t}""",
    ""
)

insert_after = """const log_level = uci.get(uciconfig, ucimain, 'log_level') || 'warn';\n/* UCI config end */"""
modern_guard = """const modern_node_types = [ 'direct', 'anytls', 'hysteria2', 'shadowsocks', 'trojan', 'tuic', 'wireguard', 'vless' ];\nconst modern_shadowsocks_methods = [\n\t'aes-128-gcm',\n\t'aes-192-gcm',\n\t'aes-256-gcm',\n\t'chacha20-ietf-poly1305',\n\t'xchacha20-ietf-poly1305',\n\t'2022-blake3-aes-128-gcm',\n\t'2022-blake3-aes-256-gcm',\n\t'2022-blake3-chacha20-poly1305'\n];\n\nfunction is_modern_node(node) {\n\tif (type(node) !== 'object' || isEmpty(node) || !(node.type in modern_node_types))\n\t\treturn false;\n\tif (node.type === 'shadowsocks' && !(node.shadowsocks_encrypt_method in modern_shadowsocks_methods))\n\t\treturn false;\n\treturn true;\n}\n\n""" + insert_after
replace_required(gen_client_uc, insert_after, modern_guard)

replace_required(
    gen_client_uc,
    """function generate_endpoint(node) {
\tif (type(node) !== 'object' || isEmpty(node))
\t\treturn null;""",
    """function generate_endpoint(node) {
\tif (!is_modern_node(node))
\t\treturn null;"""
)

replace_required(
    gen_client_uc,
    """function generate_outbound(node) {
\tif (type(node) !== 'object' || isEmpty(node))
\t\treturn null;""",
    """function generate_outbound(node) {
\tif (!is_modern_node(node))
\t\treturn null;"""
)

replace_required(
    gen_client_uc,
    """\t} else {
\t\tconst main_node_cfg = uci.get_all(uciconfig, main_node) || {};
\t\tif (main_node_cfg.type === 'wireguard') {""",
    """\t} else {
\t\tconst main_node_cfg = uci.get_all(uciconfig, main_node) || {};
\t\tif (!is_modern_node(main_node_cfg))
\t\t\tdie(`Unsupported HomeProxy node type: ${main_node_cfg.type || 'empty'}\\n`);
\t\tif (main_node_cfg.type === 'wireguard') {"""
)

replace_required(
    gen_client_uc,
    """\t} else if (dedicated_udp_node) {
\t\tconst main_udp_node_cfg = uci.get_all(uciconfig, main_udp_node) || {};
\t\tif (main_udp_node_cfg.type === 'wireguard') {""",
    """\t} else if (dedicated_udp_node) {
\t\tconst main_udp_node_cfg = uci.get_all(uciconfig, main_udp_node) || {};
\t\tif (!is_modern_node(main_udp_node_cfg))
\t\t\tdie(`Unsupported HomeProxy UDP node type: ${main_udp_node_cfg.type || 'empty'}\\n`);
\t\tif (main_udp_node_cfg.type === 'wireguard') {"""
)

replace_required(
    gen_client_uc,
    """\tfor (let i in urltest_nodes) {
\t\tconst urltest_node = uci.get_all(uciconfig, i) || {};
\t\tif (urltest_node.type === 'wireguard') {""",
    """\tfor (let i in urltest_nodes) {
\t\tconst urltest_node = uci.get_all(uciconfig, i) || {};
\t\tif (!is_modern_node(urltest_node))
\t\t\tcontinue;
\t\tif (urltest_node.type === 'wireguard') {"""
)

replace_required(
    gen_client_uc,
    """\t\t} else {
\t\t\tconst outbound = uci.get_all(uciconfig, cfg.node) || {};
\t\t\tif (outbound.type === 'wireguard') {""",
    """\t\t} else {
\t\t\tconst outbound = uci.get_all(uciconfig, cfg.node) || {};
\t\t\tif (!is_modern_node(outbound))
\t\t\t\treturn;
\t\t\tif (outbound.type === 'wireguard') {"""
)

replace_required(
    gen_client_uc,
    """\tfor (let i in filter(urltest_nodes, (l) => !~index(routing_nodes, l))) {
\t\tconst urltest_node = uci.get_all(uciconfig, i) || {};
\t\tif (urltest_node.type === 'wireguard')""",
    """\tfor (let i in filter(urltest_nodes, (l) => !~index(routing_nodes, l))) {
\t\tconst urltest_node = uci.get_all(uciconfig, i) || {};
\t\tif (!is_modern_node(urltest_node))
\t\t\tcontinue;
\t\tif (urltest_node.type === 'wireguard')"""
)

subs_insert = """const ubus = connect();\nconst sing_features = ubus.call('luci.homeproxy', 'singbox_get_features', {}) || {};\n/* Common var end */"""
subs_guard = """const ubus = connect();\nconst sing_features = ubus.call('luci.homeproxy', 'singbox_get_features', {}) || {};\n\nconst modern_node_types = [ 'anytls', 'hysteria2', 'shadowsocks', 'trojan', 'tuic', 'vless' ];\nconst modern_shadowsocks_methods = [\n\t'aes-128-gcm',\n\t'aes-192-gcm',\n\t'aes-256-gcm',\n\t'chacha20-ietf-poly1305',\n\t'xchacha20-ietf-poly1305',\n\t'2022-blake3-aes-128-gcm',\n\t'2022-blake3-aes-256-gcm',\n\t'2022-blake3-chacha20-poly1305'\n];\n\nfunction modern_check(config) {\n\tif (isEmpty(config) || !(config.type in modern_node_types))\n\t\treturn null;\n\tif (config.type === 'shadowsocks' && !(config.shadowsocks_encrypt_method in modern_shadowsocks_methods))\n\t\treturn null;\n\treturn config;\n}\n/* Common var end */"""
replace_required(update_subs_uc, subs_insert, subs_guard)

replace_required(
    update_subs_uc,
    """\t\tcase 'http':
\t\tcase 'https':
\t\t\turl = parseURL('http://' + uri[1]) || {};

\t\t\tconfig = {
\t\t\t\tlabel: url.hash ? urldecode(url.hash) : null,
\t\t\t\ttype: 'http',
\t\t\t\taddress: url.hostname,
\t\t\t\tport: url.port,
\t\t\t\tusername: url.username ? urldecode(url.username) : null,
\t\t\t\tpassword: url.password ? urldecode(url.password) : null,
\t\t\t\ttls: (uri[0] === 'https') ? '1' : '0'
\t\t\t};

\t\t\tbreak;
\t\tcase 'hysteria':""",
    """\t\tcase 'http':
\t\tcase 'https':
\t\t\treturn null;
\t\tcase 'hysteria':"""
)

replace_required(
    update_subs_uc,
    """\t\tcase 'socks':
\t\tcase 'socks4':
\t\tcase 'socks4a':
\t\tcase 'socsk5':
\t\tcase 'socks5h':
\t\t\turl = parseURL('http://' + uri[1]) || {};

\t\t\tconfig = {
\t\t\t\tlabel: url.hash ? urldecode(url.hash) : null,
\t\t\t\ttype: 'socks',
\t\t\t\taddress: url.hostname,
\t\t\t\tport: url.port,
\t\t\t\tusername: url.username ? urldecode(url.username) : null,
\t\t\t\tpassword: url.password ? urldecode(url.password) : null,
\t\t\t\tsocks_version: (match(uri[0], /4/)) ? '4' : '5'
\t\t\t};

\t\t\tbreak;
\t\tcase 'ss':""",
    """\t\tcase 'socks':
\t\tcase 'socks4':
\t\tcase 'socks4a':
\t\tcase 'socsk5':
\t\tcase 'socks5h':
\t\t\treturn null;
\t\tcase 'ss':"""
)

regex_required(
    update_subs_uc,
    r"\t\tcase 'vmess':[\s\S]*?\n\t\t}\n\t}\n\n\tif \(!isEmpty\(config\)\) \{",
    "\t\tcase 'vmess':\n\t\t\treturn null;\n\t\t}\n\t}\n\n\tconfig = modern_check(config);\n\tif (!isEmpty(config)) {"
)
PY

REQUIRE_PATTERN "$NODE_JS" "o.value\\('hysteria2'" "Hysteria2 remains available"
REQUIRE_PATTERN "$NODE_JS" "o.value\\('vless'" "VLESS remains available"
REQUIRE_PATTERN "$NODE_JS" "case 'vmess':[[:space:]]*$" "VMess import is rejected"
REQUIRE_PATTERN "$NODE_JS" "hp.shadowsocks_encrypt_methods" "node page uses shared Shadowsocks method list"
REQUIRE_PATTERN "$HP_JS" "2022-blake3-chacha20-poly1305" "modern Shadowsocks methods remain available"

if grep -Eq "o.value\\('vmess'|o.value\\('shadowtls'|o.value\\('ssh'|o.value\\('socks'|o.value\\('hysteria'," "$NODE_JS"; then
	LOG "ERROR: legacy HomeProxy client node type is still exposed"
	grep -nE "o.value\\('vmess'|o.value\\('shadowtls'|o.value\\('ssh'|o.value\\('socks'|o.value\\('hysteria'," "$NODE_JS" || true
	exit 1
fi

if grep -Eq "aes-128-ctr|aes-192-ctr|aes-256-ctr|aes-128-cfb|aes-192-cfb|aes-256-cfb|chacha20'|chacha20-ietf'|rc4-md5" "$NODE_JS" "$HP_JS"; then
	LOG "ERROR: legacy Shadowsocks method is still exposed"
	grep -nE "aes-128-ctr|aes-192-ctr|aes-256-ctr|aes-128-cfb|aes-192-cfb|aes-256-cfb|chacha20'|chacha20-ietf'|rc4-md5" "$NODE_JS" "$HP_JS" || true
	exit 1
fi

REQUIRE_PATTERN "$GEN_CLIENT_UC" "modern_node_types" "generated sing-box config filters legacy node types"
REQUIRE_PATTERN "$UPDATE_SUBS_UC" "modern_check" "subscription import filters legacy node types"

LOG "HomeProxy modern client mode patched"
