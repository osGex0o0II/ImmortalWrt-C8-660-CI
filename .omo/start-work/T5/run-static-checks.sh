#!/bin/bash
set -euo pipefail

cd /mnt/d/Code/Git/ImmortalWrt-C8-660-SMS-Refactor

run() {
	printf '$'
	printf ' %q' "$@"
	printf '\n'
	"$@"
	printf 'exit=0\n'
}

run bash -n Scripts/InstallC8Overlay.sh
run sh -n patches/files/etc/init.d/c8-sms-forward
run node --check Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs
run jq -e . patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json
run jq -e . Scripts/fixtures/c8-sms-forward-rpc/contract.json
run node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc Scripts/fixtures/c8-sms-forward-rpc/contract.json
run cmp -s patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc

if command -v ucode >/dev/null 2>&1; then
	printf 'ucode=present\n'
else
	printf 'ucode=absent; target compile/runtime validation deferred to T9\n'
fi
