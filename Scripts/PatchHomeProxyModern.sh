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
DEFAULTS_SH="$PKG_DIR/root/etc/uci-defaults/99-homeproxy-modern-defaults"

for file in "$NODE_JS" "$SERVER_JS" "$HP_JS" "$GEN_CLIENT_UC" "$UPDATE_SUBS_UC" "$MENU_JSON"; do
	REQUIRE_FILE "$file"
done

LOG "Patching HomeProxy for C8 modern client mode"

PYTHON_BIN=""
for CAND in python3 python; do
	CAND_PATH="$(command -v "$CAND" || true)"
	if [ -n "$CAND_PATH" ] && "$CAND_PATH" -c "" 2>/dev/null; then
		PYTHON_BIN="$CAND_PATH"
		break
	fi
done
if [ -z "$PYTHON_BIN" ]; then
	LOG "ERROR: python3/python is required to patch HomeProxy"
	exit 1
fi

"$PYTHON_BIN" - "$NODE_JS" "$SERVER_JS" "$HP_JS" "$GEN_CLIENT_UC" "$UPDATE_SUBS_UC" "$MENU_JSON" "$DEFAULTS_SH" <<'PY'
from pathlib import Path
import os
import re
import sys

node_js, server_js, hp_js, gen_client_uc, update_subs_uc, menu_json, defaults_sh = map(Path, sys.argv[1:])
for source_path in [node_js, server_js, hp_js, gen_client_uc, update_subs_uc, menu_json]:
    source_path.write_text(source_path.read_text(encoding='utf-8').replace('\r\n', '\n').replace('\r', '\n'), encoding='utf-8')

def version_ge(have, need):
    def parts(value):
        return [int(x) if x.isdigit() else 0 for x in re.split(r'[.+_-]', value)]
    have_parts = (parts(have) + [0, 0, 0, 0])[:4]
    need_parts = (parts(need) + [0, 0, 0, 0])[:4]
    return have_parts >= need_parts

def detect_sing_box_version():
    env_version = os.environ.get('SING_BOX_VERSION', '').strip()
    if env_version:
        return env_version
    workspace = os.environ.get('GITHUB_WORKSPACE', '').strip()
    if workspace:
        lock_file = Path(workspace) / '.github' / 'proxy-locks.env'
        if lock_file.is_file():
            match = re.search(r'^SING_BOX_VERSION=(.*)$', lock_file.read_text(encoding='utf-8'), flags=re.M)
            if match:
                return match.group(1).strip()
    for candidate in [
        Path('../feeds/packages/net/sing-box/Makefile'),
        Path('../package/feeds/packages/sing-box/Makefile'),
        Path('feeds/packages/net/sing-box/Makefile'),
    ]:
        if candidate.is_file():
            text = candidate.read_text(encoding='utf-8')
            match = re.search(r'^PKG_VERSION:=(.*)$', text, flags=re.M)
            if match:
                return match.group(1).strip()
    return '0.0.0'

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

def regex_optional(path, pattern, repl, flags=0):
    text = path.read_text(encoding='utf-8')
    new, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count:
        path.write_text(new, encoding='utf-8')
    return count

def text_replace_optional(path, old, new):
    text = path.read_text(encoding='utf-8')
    if old in text:
        path.write_text(text.replace(old, new), encoding='utf-8')
        return True
    return False

sing_box_version = detect_sing_box_version()

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
    r"\t\tcase 'socks':\n\t\tcase 'socks4':\n\t\tcase 'socks4a':\n\t\tcase '(?:socsk5|socks5)':\n\t\tcase 'socks5h':[\s\S]*?\n\t\t\tbreak;\n\t\tcase 'ss':",
    "\t\tcase 'socks':\n\t\tcase 'socks4':\n\t\tcase 'socks4a':\n\t\tcase 'socks5':\n\t\tcase 'socks5h':\n\t\t\treturn null;\n\t\tcase 'ss':"
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

gen_text = gen_client_uc.read_text(encoding='utf-8')
gen_text = re.sub(r'^\t+\tsniff: true,?\n', '', gen_text, flags=re.M)
gen_text = re.sub(r'^\t+\tsniff_override_destination: strToBool\(sniff_override\),?\n', '', gen_text, flags=re.M)
gen_text = re.sub(r'^\t+sniff: true,?\n', '', gen_text, flags=re.M)
gen_text = re.sub(r'^\t+sniff_override_destination: strToBool\(sniff_override\),?\n', '', gen_text, flags=re.M)
gen_text = re.sub(r',(\n\t+\}\);)', r'\1', gen_text)
gen_client_uc.write_text(gen_text, encoding='utf-8')

if "inbound: ['mixed-in', 'redirect-in', 'tproxy-in', 'tun-in']" not in gen_client_uc.read_text(encoding='utf-8'):
    regex_required(
        gen_client_uc,
        r"\n\t\t/\*\n\t\t \* leave for sing-box 1\.13\.0\n\t\t \* \{\n\t\t \* \taction: 'sniff'\n\t\t \* \}\n\t\t \*/",
        ""
    )
    regex_required(
        gen_client_uc,
        r"(\t\t\{\n\t\t\tinbound: 'dns-in',\n\t\t\taction: 'hijack-dns'\n\t\t\})",
        "\\1,\n\t\t{\n\t\t\tinbound: ['mixed-in', 'redirect-in', 'tproxy-in', 'tun-in'],\n\t\t\taction: 'sniff'\n\t\t}"
    )

text_replace_optional(
    gen_client_uc,
    "const main_urltest_nodes = uci.get(uciconfig, ucimain, 'main_urltest_nodes') || [];",
    "const main_urltest_nodes = filter(uci.get(uciconfig, ucimain, 'main_urltest_nodes') || [], (k) => !isEmpty(uci.get_all(uciconfig, k)?.type));"
)
text_replace_optional(
    gen_client_uc,
    "const main_udp_urltest_nodes = uci.get(uciconfig, ucimain, 'main_udp_urltest_nodes') || [];",
    "const main_udp_urltest_nodes = filter(uci.get(uciconfig, ucimain, 'main_udp_urltest_nodes') || [], (k) => !isEmpty(uci.get_all(uciconfig, k)?.type));"
)
if "const cfg_urltest_nodes = filter(cfg.urltest_nodes || []" not in gen_client_uc.read_text(encoding='utf-8'):
    regex_required(
        gen_client_uc,
        r"(\t\tif \(cfg\.node === 'urltest'\) \{\n)",
        "\\1\t\t\tconst cfg_urltest_nodes = filter(cfg.urltest_nodes || [], (k) => !isEmpty(uci.get_all(uciconfig, k)?.type));\n"
    )
    text_replace_optional(gen_client_uc, "outbounds: map(cfg.urltest_nodes", "outbounds: map(cfg_urltest_nodes")
    text_replace_optional(gen_client_uc, "filter(cfg.urltest_nodes, (l) =>", "filter(cfg_urltest_nodes, (l) =>")

if version_ge(sing_box_version, '1.14.0'):
    if "default_http_client: 'direct-http'" not in gen_client_uc.read_text(encoding='utf-8'):
        if "config.route = {" in gen_client_uc.read_text(encoding='utf-8'):
            regex_required(gen_client_uc, r"(config\.route = \{\n)", "\\1\tdefault_http_client: 'direct-http',\n")
        else:
            regex_required(gen_client_uc, r"(\troute:\s*\{\n)", "\\1\t\tdefault_http_client: 'direct-http',\n")
    if "tag: 'direct-http'" not in gen_client_uc.read_text(encoding='utf-8'):
        current_gen = gen_client_uc.read_text(encoding='utf-8')
        if "config.http_clients = [" in current_gen or "http_clients: [" in current_gen:
            raise SystemExit("HomeProxy HTTP clients exist but direct-http is missing")
        if "const config = {};" in current_gen:
            replace_required(
                gen_client_uc,
                "const config = {};",
                "const config = {};\n\nconfig.http_clients = [\n\t{\n\t\ttag: 'direct-http',\n\t\tdetour: 'direct-out'\n\t}\n];"
            )
        else:
            regex_required(
                gen_client_uc,
                r"(\n\toutbounds:\s*\[)",
                ",\n\thttp_clients: [\n\t\t{\n\t\t\ttag: 'direct-http',\n\t\t\tdetour: 'direct-out'\n\t\t}\n\t],\\1"
            )
    gen_text = gen_client_uc.read_text(encoding='utf-8')
    gen_text = gen_text.replace("download_detour: 'main-out'", "http_client: 'direct-http'")
    gen_text = gen_text.replace("download_detour: 'direct-out'", "http_client: 'direct-http'")
    gen_text = gen_text.replace(
        "download_detour: get_outbound(cfg.outbound)",
        "http_client: cfg.type === 'remote' ? (isEmpty(cfg.outbound) ? 'direct-http' : { detour: get_outbound(cfg.outbound) }) : null"
    )
    gen_client_uc.write_text(gen_text, encoding='utf-8')
else:
    gen_text = gen_client_uc.read_text(encoding='utf-8')
    gen_text = gen_text.replace("download_detour: 'main-out'", "download_detour: 'direct-out'")
    gen_client_uc.write_text(gen_text, encoding='utf-8')

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

if "function is_placeholder_subscription_node(config)" not in update_subs_uc.read_text(encoding='utf-8'):
    replace_required(
        update_subs_uc,
        "/* String helper end */",
        """function is_placeholder_subscription_node(config) {
\tconst label = config.label || '';
\tconst address = config.address || '';

\tif (address === 'localhost' || address === '0.0.0.0' || address === '::' || address === '::1' || match(address, /^127\\./))
\t\treturn true;

\tif (match(label, /v2rayN|old client|client too old|update client/))
\t\treturn true;

\treturn false;
}

/* String helper end */"""
    )

if "Skipping placeholder subscription node" not in update_subs_uc.read_text(encoding='utf-8'):
    replace_required(
        update_subs_uc,
        """\t\tif (!validation('host', config.address) || !validation('port', config.port)) {""",
        """\t\tif (is_placeholder_subscription_node(config)) {
\t\t\tlog(sprintf('Skipping placeholder subscription node: %s.', config.label || config.address || 'NULL'));
\t\t\treturn null;
\t\t}

\t\tif (!validation('host', config.address) || !validation('port', config.port)) {"""
    )

if "No main node is selected, switching to the first node." not in update_subs_uc.read_text(encoding='utf-8'):
    replace_required(
        update_subs_uc,
        "\tlet need_restart = (via_proxy !== '1');",
        """\tlet need_restart = (via_proxy !== '1');
\tconst first_subscription_server = uci.get_first(uciconfig, ucinode);
\tif (routing_mode !== 'custom' && isEmpty(main_node) && first_subscription_server) {
\t\tuci.set(uciconfig, ucimain, 'main_node', first_subscription_server);
\t\tuci.set(uciconfig, ucimain, 'main_udp_node', 'same');
\t\tuci.commit(uciconfig);
\t\tmain_node = first_subscription_server;
\t\tmain_udp_node = 'same';
\t\tneed_restart = true;

\t\tlog('No main node is selected, switching to the first node.');
\t}"""
    )

defaults_sh.parent.mkdir(parents=True, exist_ok=True)
defaults_sh.write_text("""#!/bin/sh
uci -q set homeproxy.subscription.user_agent='v2ray'
uci -q set homeproxy.subscription.allow_insecure='0'
uci -q commit homeproxy
exit 0
""", encoding='utf-8')
defaults_sh.chmod(0o755)
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
REQUIRE_PATTERN "$GEN_CLIENT_UC" "inbound: \\['mixed-in', 'redirect-in', 'tproxy-in', 'tun-in'\\]" "sing-box route sniff action is used"
REQUIRE_PATTERN "$GEN_CLIENT_UC" "const main_urltest_nodes = filter\\(uci.get\\(uciconfig, ucimain, 'main_urltest_nodes'\\)" "stale main urltest nodes are filtered"
REQUIRE_PATTERN "$GEN_CLIENT_UC" "const main_udp_urltest_nodes = filter\\(uci.get\\(uciconfig, ucimain, 'main_udp_urltest_nodes'\\)" "stale UDP urltest nodes are filtered"
REQUIRE_PATTERN "$GEN_CLIENT_UC" "const cfg_urltest_nodes = filter\\(cfg.urltest_nodes \\|\\| \\[\\]" "stale custom urltest nodes are filtered"
REQUIRE_PATTERN "$GEN_CLIENT_UC" "!is_modern_node\\(urltest_node\\)" "standalone urltest outbound nodes are filtered"
REQUIRE_PATTERN "$UPDATE_SUBS_UC" "function is_placeholder_subscription_node" "placeholder subscription nodes are filtered"
REQUIRE_PATTERN "$UPDATE_SUBS_UC" "No main node is selected, switching to the first node" "first subscription node fallback is enabled"
REQUIRE_PATTERN "$DEFAULTS_SH" "homeproxy\\.subscription\\.user_agent='v2ray'" "HomeProxy subscription user-agent default is set"
REQUIRE_PATTERN "$DEFAULTS_SH" "homeproxy\\.subscription\\.allow_insecure='0'" "HomeProxy subscription TLS verification default is set"

if grep -Fq "sniff_override_destination: strToBool(sniff_override)" "$GEN_CLIENT_UC" || grep -Fq "sniff: true" "$GEN_CLIENT_UC"; then
	LOG "ERROR: legacy sing-box inbound sniff fields are still present"
	exit 1
fi

DETECTED_SING_BOX_VERSION="${SING_BOX_VERSION:-}"
if [ -z "$DETECTED_SING_BOX_VERSION" ] && [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/.github/proxy-locks.env" ]; then
	DETECTED_SING_BOX_VERSION="$(sed -n 's/^SING_BOX_VERSION=//p' "$GITHUB_WORKSPACE/.github/proxy-locks.env" | head -1 | tr -d '\r')"
fi
if [ -z "$DETECTED_SING_BOX_VERSION" ]; then
	SING_BOX_MAKEFILE="$(find feeds package/feeds ../feeds ../package/feeds -path '*/sing-box/Makefile' -print -quit 2>/dev/null || true)"
	if [ -n "$SING_BOX_MAKEFILE" ]; then
		DETECTED_SING_BOX_VERSION="$(sed -n 's/^PKG_VERSION:=//p' "$SING_BOX_MAKEFILE" | head -1 | tr -d '\r')"
	fi
fi
DETECTED_SING_BOX_VERSION="${DETECTED_SING_BOX_VERSION:-0.0.0}"
VERSION_GE() {
	awk -v have="$1" -v need="$2" '
		function splitver(v, a) { split(v, a, /[.+_-]/) }
		BEGIN {
			splitver(have, h); splitver(need, n)
			for (i = 1; i <= 4; i++) {
				hv = (h[i] == "" ? 0 : h[i] + 0)
				nv = (n[i] == "" ? 0 : n[i] + 0)
				if (hv > nv) exit 0
				if (hv < nv) exit 1
			}
			exit 0
		}'
}
if VERSION_GE "$DETECTED_SING_BOX_VERSION" "1.14.0"; then
	REQUIRE_PATTERN "$GEN_CLIENT_UC" "default_http_client: 'direct-http'" "sing-box 1.14 default HTTP client is configured"
	REQUIRE_PATTERN "$GEN_CLIENT_UC" "tag: 'direct-http'" "sing-box 1.14 direct HTTP client is defined"
	HTTP_CLIENT_DEFS="$(awk 'index($0, "config.http_clients = [") || index($0, "http_clients: [") { count++ } END { print count + 0 }' "$GEN_CLIENT_UC")"
	if [ "$HTTP_CLIENT_DEFS" -ne 1 ]; then
		LOG "ERROR: unexpected HomeProxy HTTP client definition count for sing-box ${DETECTED_SING_BOX_VERSION}: ${HTTP_CLIENT_DEFS}"
		exit 1
	fi
	HTTP_CLIENT_USES="$(awk 'index($0, "http_client: '\''direct-http'\''") { count++ } END { print count + 0 }' "$GEN_CLIENT_UC")"
	if [ "$HTTP_CLIENT_USES" -lt 3 ]; then
		LOG "ERROR: HomeProxy rule-set downloads do not consistently use direct HTTP client"
		exit 1
	fi
	if grep -Fq "download_detour:" "$GEN_CLIENT_UC"; then
		LOG "ERROR: deprecated rule-set download_detour is still present for sing-box ${DETECTED_SING_BOX_VERSION}"
		exit 1
	fi
else
	DIRECT_DETOURS="$(awk 'index($0, "download_detour: '\''direct-out'\''") { count++ } END { print count + 0 }' "$GEN_CLIENT_UC")"
	if [ "$DIRECT_DETOURS" -lt 3 ]; then
		LOG "ERROR: HomeProxy rule-set bootstrap downloads are not consistently forced to direct-out"
		exit 1
	fi
	if grep -Fq "download_detour: 'main-out'" "$GEN_CLIENT_UC"; then
		LOG "ERROR: rule-set bootstrap downloads still depend on main-out"
		exit 1
	fi
fi

LOG "HomeProxy modern client mode patched"
