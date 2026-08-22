#!/usr/bin/env bash
set -u

if [ "$#" -ne 2 ]; then
	printf 'Usage: %s <config|manifest|rootfs> <file>\n' "$0" >&2
	exit 2
fi

MODE="$1"
INPUT="$2"
FAILURES=0

if [ ! -s "$INPUT" ]; then
	printf 'ERROR: validation input is missing or empty: %s\n' "$INPUT" >&2
	exit 1
fi

pass() { printf 'OK: %s\n' "$1"; }
fail() { printf 'ERROR: %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

require_fixed_line() {
	if grep -Fqx "$1" "$INPUT"; then pass "$2"; else fail "missing $2 ($1)"; fi
}

reject_fixed_line() {
	if grep -Fqx "$1" "$INPUT"; then fail "unexpected $2 ($1)"; else pass "no $2"; fi
}

require_package() {
	if grep -Eq "^${1}[[:space:]]+-[[:space:]]+" "$INPUT"; then pass "manifest package $1"; else fail "missing manifest package $1"; fi
}

reject_package() {
	if grep -Eq "^${1}[[:space:]]+-[[:space:]]+" "$INPUT"; then fail "unexpected manifest package $1"; else pass "manifest excludes $1"; fi
}

require_path() {
	if grep -Eq "$1" "$INPUT"; then pass "$2"; else fail "missing $2"; fi
}

reject_path() {
	if grep -Eq "$1" "$INPUT"; then fail "unexpected $2"; else pass "no $2"; fi
}

validate_config() {
	local line
	local required=(
		'CONFIG_TARGET_mediatek=y'
		'CONFIG_TARGET_mediatek_filogic=y'
		'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_nradio_wt9103=y'
		'CONFIG_PACKAGE_kmod-mt_wifi=y'
		'CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y'
		'CONFIG_MTK_MT_WIFI_MT7981_20260601=y'
		'CONFIG_PACKAGE_kmod-conninfra=y'
		'CONFIG_PACKAGE_kmod-mediatek_hnat=y'
		'CONFIG_PACKAGE_kmod-warp=y'
		'CONFIG_PACKAGE_hnat-detect=y'
		'CONFIG_MTK_FAST_NAT_SUPPORT=y'
		'CONFIG_MTK_WHNAT_SUPPORT=m'
		'CONFIG_MTK_WARP_V2=y'
		'CONFIG_WARP_CHIPSET="mt7981"'
		'CONFIG_WARP_VERSION=2'
		'CONFIG_WED_HW_RRO_SUPPORT=y'
	)
	local forbidden=(
		'CONFIG_PACKAGE_kmod-mt7915e=y'
		'CONFIG_PACKAGE_kmod-mt76=y'
		'CONFIG_PACKAGE_kmod-mt76-core=y'
		'CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7661=y'
		'CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7672=y'
	)

	for line in "${required[@]}"; do require_fixed_line "$line" "closed config $line"; done
	for line in "${forbidden[@]}"; do reject_fixed_line "$line" "closed config $line"; done
	if grep -Eq '^CONFIG_PACKAGE_kmod-mt76[^=]*=y$' "$INPUT"; then
		fail 'mt76 package enabled in closed config'
	else
		pass 'closed config excludes all mt76 packages'
	fi
}

validate_manifest() {
	local package
	for package in kmod-mt_wifi kmod-conninfra kmod-mediatek_hnat kmod-warp \
		hnat-detect mtwifi-cfg-ucode luci-app-mtwifi-cfg uqmi kmod-usb-net-qmi-wwan
	do
		require_package "$package"
	done
	if grep -Eq '^kmod-mt_wifi[[:space:]]+-[[:space:]]+[^[:space:]]*7\.6\.7\.3([^0-9.]|$)' "$INPUT"; then
		pass 'manifest mt_wifi version 7.6.7.3'
	else
		fail 'manifest mt_wifi version is not 7.6.7.3'
	fi
	for package in kmod-mt7915e kmod-mt76 kmod-mt76-core mtwifi-cfg; do reject_package "$package"; done
}

validate_rootfs() {
	require_path '/mt_wifi\.ko([[:space:]]|$)' 'mt_wifi kernel module'
	require_path '/mtk_warp_proxy\.ko([[:space:]]|$)' 'mt_wifi WARP proxy module'
	require_path '/mtk_warp\.ko([[:space:]]|$)' 'WARP kernel module'
	require_path '/mtkhnat\.ko([[:space:]]|$)' 'MediaTek HNAT kernel module'
	require_path '/conninfra\.ko([[:space:]]|$)' 'conninfra kernel module'
	require_path '/7981_WOCPU[^/[:space:]]*_RAM_CODE_release\.bin([[:space:]]|$)' 'MT7981 WO firmware'
	require_path '/usr/share/ucode/hnat/detect\.uc([[:space:]]|$)' 'HNAT external-interface detector'
	require_path '/sbin/uqmi([[:space:]]|$)' 'uqmi client'
	require_path '/usr/share/modem/rm520n\.sh([[:space:]]|$)' 'RM520N modem integration'
	reject_path '/mt7915e\.ko([[:space:]]|$)' 'mt7915e module'
	reject_path '/mt76\.ko([[:space:]]|$)' 'mt76 core module'
	reject_path '/mt76-connac-lib\.ko([[:space:]]|$)' 'mt76 connac module'
	reject_path '/mac80211\.ko([[:space:]]|$)' 'mac80211 module'
}

case "$MODE" in
	config) validate_config ;;
	manifest) validate_manifest ;;
	rootfs) validate_rootfs ;;
	*) printf 'ERROR: unknown validation mode: %s\n' "$MODE" >&2; exit 2 ;;
esac

if [ "$FAILURES" -ne 0 ]; then
	printf 'ERROR: %s closed build validation check(s) failed\n' "$FAILURES" >&2
	exit 1
fi

printf 'Closed build %s validation passed\n' "$MODE"
