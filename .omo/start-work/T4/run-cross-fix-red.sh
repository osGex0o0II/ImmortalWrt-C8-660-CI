#!/bin/bash
set -u

repo=/mnt/d/Code/Git/ImmortalWrt-C8-660-SMS-Refactor
evidence=/mnt/d/Code/Git/ImmortalWrt-C8-660-CI/.omo/start-work/T4
cd "$repo"

tmp="$(mktemp -d)"
case "$tmp" in
	/tmp/tmp.*) ;;
	*) printf 'unsafe temp path: %s\n' "$tmp" >&2; exit 70 ;;
esac
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT

red=0
sed -f Scripts/fixtures/c8-sms-forward-rpc/fake-direct-wrapper.sed \
	Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc > "$tmp/direct-wrapper.uc"
node Scripts/fixtures/c8-sms-forward-rpc/analyze-facade.mjs \
	"$tmp/direct-wrapper.uc" Scripts/fixtures/c8-sms-forward-rpc/contract.json \
	> "$evidence/cross-fix-old-analyzer-direct-wrapper.out" \
	2> "$evidence/cross-fix-old-analyzer-direct-wrapper.err"
analyzer_rc=$?
printf 'old_analyzer_direct_wrapper_exit=%s\n' "$analyzer_rc"
if [ "$analyzer_rc" -eq 0 ]; then
	printf 'RED: old analyzer accepted direct rpcd wrapper handling\n'
	red=$((red + 1))
fi

for source in \
	Scripts/fixtures/c8-sms-forward-rpc/canonical-facade.uc \
	patches/files/usr/share/rpcd/ucode/c8.sms_forward.uc
do
	if grep -Eq '\bdie[[:space:]]*\(' "$source"; then
		printf 'RED: reachable die found source=%s\n' "$source"
		red=$((red + 1))
	else
		printf 'unexpected: no die found source=%s\n' "$source"
	fi
done

for spec in read:read write:write; do
	section="${spec%%:*}"
	permission="${spec##*:}"
	workspace="$tmp/repo-$section"
	wrt="$tmp/wrt-$section"
	mkdir -p "$workspace/patches"
	cp -a patches/files "$workspace/patches/files"
	acl="$workspace/patches/files/usr/share/rpcd/acl.d/luci-app-c8modem.json"
	jq --arg section "$section" '."luci-app-c8modem"[$section].ubus.file = ["exec"]' \
		"$acl" > "$tmp/acl-$section.json"
	mv "$tmp/acl-$section.json" "$acl"
	set +e
	timeout --kill-after=2s 30s env GITHUB_WORKSPACE="$workspace" \
		bash Scripts/InstallC8Overlay.sh "$wrt" \
		> "$evidence/cross-fix-old-installer-$section.out" \
		2> "$evidence/cross-fix-old-installer-$section.err"
	installer_rc=$?
	set -e
	printf 'old_installer_missing_%s_%s_exit=%s\n' "$section" "$permission" "$installer_rc"
	if [ "$installer_rc" -eq 0 ]; then
		printf 'RED: old installer accepted missing %s file ubus %s\n' "$section" "$permission"
		red=$((red + 1))
	fi
done

printf 'RED_SUMMARY: observed=%s expected=5\n' "$red"
[ "$red" -eq 5 ] || exit 2
exit 1
