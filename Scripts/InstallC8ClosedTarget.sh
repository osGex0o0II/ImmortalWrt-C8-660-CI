#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
	printf 'Usage: %s <upstream-root>\n' "$0" >&2
	exit 2
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_ROOT="$(CDPATH= cd -- "$1" && pwd)"

DTS_SOURCE="$REPO_ROOT/patches/mt7981b-nradio-c8-660.dts"
IMAGE_SOURCE="$REPO_ROOT/patches/filogic-c8-660-closed.mk"
DTS_DEST="$UPSTREAM_ROOT/target/linux/mediatek/dts/mt7981b-nradio-c8-660.dts"
IMAGE_DEST="$UPSTREAM_ROOT/target/linux/mediatek/image/filogic.mk"
IMAGE_MARKER='# BEGIN C8-660 CLOSED TARGET'

for source_file in "$DTS_SOURCE" "$IMAGE_SOURCE"; do
	if [ ! -s "$source_file" ]; then
		printf 'ERROR: required C8 source file missing: %s\n' "$source_file" >&2
		exit 1
	fi
done

if [ ! -d "$(dirname "$DTS_DEST")" ]; then
	printf 'ERROR: upstream MediaTek DTS directory missing: %s\n' "$(dirname "$DTS_DEST")" >&2
	exit 1
fi

if [ ! -f "$IMAGE_DEST" ]; then
	printf 'ERROR: upstream filogic image file missing: %s\n' "$IMAGE_DEST" >&2
	exit 1
fi

cp -f "$DTS_SOURCE" "$DTS_DEST"

if grep -q '^&hnat {' "$DTS_DEST"; then
	printf 'ERROR: shared C8 DTS unexpectedly contains a closed HNAT node\n' >&2
	exit 1
fi

cat >> "$DTS_DEST" <<'DTS_HNAT'

&hnat {
	mtketh-wan = "eth1";
	mtketh-lan = "lan";
	mtketh-max-gmac = <2>;
	status = "okay";
};
DTS_HNAT

if grep -Fq "$IMAGE_MARKER" "$IMAGE_DEST"; then
	printf 'C8-660 closed image definition already installed\n'
elif grep -q '^define Device/nradio_wt9103$' "$IMAGE_DEST"; then
	printf 'ERROR: upstream already defines Device/nradio_wt9103 without the C8 closed marker\n' >&2
	exit 1
else
	{
		printf '\n%s\n' "$IMAGE_MARKER"
		cat "$IMAGE_SOURCE"
		printf '%s\n' '# END C8-660 CLOSED TARGET'
	} >> "$IMAGE_DEST"
	printf 'Installed C8-660 closed image definition\n'
fi

printf 'Installed C8-660 closed DTS: %s\n' "$DTS_DEST"
