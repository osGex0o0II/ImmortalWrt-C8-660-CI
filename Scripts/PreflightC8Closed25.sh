#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
	printf 'Usage: %s <upstream-root>\n' "$0" >&2
	exit 2
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_ROOT="$(CDPATH= cd -- "$1" && pwd)"

require_file() {
	local path="$1"
	[ -s "$path" ] || {
		printf 'ERROR: preflight file is missing or empty: %s\n' "$path" >&2
		exit 1
	}
}

require_pattern() {
	local path="$1"
	local pattern="$2"
	local description="$3"
	grep -Fq "$pattern" "$path" || {
		printf 'ERROR: preflight missing %s (%s)\n' "$description" "$pattern" >&2
		exit 1
	}
}

for config in \
	"$REPO_ROOT/Config/NRADIO-C8-660-CLOSED.txt" \
	"$REPO_ROOT/Config/CLOSED.txt" \
	"$REPO_ROOT/Config/GENERAL-CLOSED.txt"
do
	require_file "$config"
done

wifi_config="$UPSTREAM_ROOT/package/mtk/drivers/mt_wifi/config.in"
warp_config="$UPSTREAM_ROOT/package/mtk/drivers/warp/config.in"
for source in \
	"$wifi_config" \
	"$warp_config" \
	"$UPSTREAM_ROOT/package/mtk/drivers/mt_wifi/Makefile" \
	"$UPSTREAM_ROOT/package/mtk/drivers/warp/Makefile" \
	"$UPSTREAM_ROOT/package/mtk/drivers/conninfra/Makefile" \
	"$UPSTREAM_ROOT/package/mtk/applications/hnat-detect/Makefile" \
	"$UPSTREAM_ROOT/target/linux/mediatek/files-6.12/drivers/net/ethernet/mediatek/mtk_hnat/Makefile"
do
	require_file "$source"
done

require_pattern "$wifi_config" 'config MTK_WLAN_HOOK' 'WLAN hook Kconfig symbol'
require_pattern "$wifi_config" 'depends on MTK_WLAN_HOOK' 'WHNAT WLAN hook dependency'
require_pattern "$wifi_config" 'config MTK_WHNAT_SUPPORT' 'WHNAT Kconfig symbol'
require_pattern "$wifi_config" 'config MTK_WARP_V2' 'WARP v2 Kconfig symbol'
require_pattern "$warp_config" 'config WED_HW_RRO_SUPPORT' 'WED RRO Kconfig symbol'
require_pattern "$REPO_ROOT/Config/CLOSED.txt" 'CONFIG_MTK_WLAN_HOOK=y' 'closed WLAN hook selection'

cd "$UPSTREAM_ROOT"
cat \
	"$REPO_ROOT/Config/NRADIO-C8-660-CLOSED.txt" \
	"$REPO_ROOT/Config/CLOSED.txt" \
	"$REPO_ROOT/Config/GENERAL-CLOSED.txt" \
	> .config
printf '%s\n' 'CONFIG_PACKAGE_luci=y' 'CONFIG_LUCI_LANG_zh_Hans=y' >> .config

printf 'Preflight: normalizing closed Kconfig\n'
make defconfig -j"$(nproc)"
bash "$REPO_ROOT/Scripts/ValidateC8ClosedBuild.sh" config .config
grep -Fxq 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_nradio_wt9103=y' .config
printf 'Preflight: closed Kconfig and source dependency checks passed\n'
