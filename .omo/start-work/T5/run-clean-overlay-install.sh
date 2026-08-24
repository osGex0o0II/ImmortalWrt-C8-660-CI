#!/bin/bash
set -euo pipefail

cd /mnt/d/Code/Git/ImmortalWrt-C8-660-SMS-Refactor

tmp="$(mktemp -d)"
case "$tmp" in
	/tmp/tmp.*) ;;
	*) printf 'unsafe temp path: %s\n' "$tmp" >&2; exit 70 ;;
esac
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT

wrt="$tmp/wrt"
installed="$wrt/package/base-files/files"
[ ! -e "$wrt" ]

printf '$ bash Scripts/InstallC8Overlay.sh <new-temp-wrt>\n'
bash Scripts/InstallC8Overlay.sh "$wrt"
printf 'installer_exit=0\n'

test -f "$installed/usr/share/rpcd/ucode/c8.sms_forward.uc"
test -f "$installed/usr/share/rpcd/acl.d/luci-app-c8modem.json"
test -f "$installed/etc/init.d/c8-sms-forward"
printf 'installed_required_files=present\n'

node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs \
	"$installed/usr/share/rpcd/ucode/c8.sms_forward.uc" \
	Scripts/fixtures/c8-sms-forward-rpc/contract.json
printf 'installed_facade_analyzer=accepted\n'
