#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---repository}"
FAILURES=0

pass() {
	printf 'PASS: %s\n' "$1"
}

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	FAILURES=$((FAILURES + 1))
}

test_repository_shape() {
	local workflow="$REPO_ROOT/.github/workflows/c8-660-closed.yml"
	local legacy_workflow="$REPO_ROOT/.github/workflows/c8-660-closed-21.02.yml"
	local legacy_archive="$REPO_ROOT/archive/closed-24.10"
	local workflow_count

	workflow_count="$(find "$REPO_ROOT/.github/workflows" -maxdepth 1 -type f -iname '*closed*.yml' | wc -l)"
	workflow_count="${workflow_count//[[:space:]]/}"
	if [ "$workflow_count" = "1" ] && [ -f "$workflow" ]; then
		pass 'repository exposes exactly one version-neutral closed workflow'
	else
		fail "repository must expose only .github/workflows/c8-660-closed.yml (found $workflow_count closed workflows)"
	fi

	if [ ! -e "$legacy_workflow" ]; then
		pass '21.02 closed workflow is absent'
	else
		fail '21.02 closed workflow must be removed'
	fi

	if [ ! -e "$legacy_archive" ]; then
		pass 'retired 24.10 closed archive is absent'
	else
		fail 'retired 24.10 closed archive must be removed'
	fi

	if [ -f "$workflow" ]; then
		if python3 - "$workflow" <<'PY'
import sys
from pathlib import Path

import yaml


class WorkflowLoader(yaml.SafeLoader):
    pass


for first, mappings in list(WorkflowLoader.yaml_implicit_resolvers.items()):
    WorkflowLoader.yaml_implicit_resolvers[first] = [
        item for item in mappings if item[0] != "tag:yaml.org,2002:bool"
    ]

workflow_path = Path(sys.argv[1])
data = yaml.load(workflow_path.read_text(encoding="utf-8"), Loader=WorkflowLoader)
assert isinstance(data, dict), "workflow root must be a mapping"
assert isinstance(data.get("on"), dict), "workflow on key must be a mapping"
assert "workflow_dispatch" in data["on"], "workflow must be manually dispatchable"
env = data.get("env") or {}
assert env.get("WRT_REPO") == "https://github.com/chasey-dev/immortalwrt-mt798x-rebase"
assert str(env.get("WRT_BRANCH")) == "25.12"
assert env.get("WRT_REF") == "${{ inputs.wrt_ref || '2d0e93b1253660ae15d195786cd7fa913d70d42a' }}"
jobs = data.get("jobs") or {}
assert list(jobs) == ["build"], "closed workflow must expose exactly one build job"
PY
		then
			pass 'closed workflow parses with the pinned 25.12 source contract'
		else
			fail 'closed workflow must parse with the pinned 25.12 source contract'
		fi
	else
		fail 'closed workflow source contract cannot be parsed because the workflow is missing'
	fi
}

test_target_injection() {
	local installer="$REPO_ROOT/Scripts/InstallC8ClosedTarget.sh"
	local fixture
	local installed_dts
	local installed_mk
	local first_hashes
	local second_hashes
	local required_package
	local forbidden_package

	fixture="$(mktemp -d)"
	installed_dts="$fixture/target/linux/mediatek/dts/mt7981b-nradio-c8-660.dts"
	installed_mk="$fixture/target/linux/mediatek/image/filogic.mk"
	mkdir -p "$(dirname "$installed_dts")" "$(dirname "$installed_mk")"
	printf '%s\n' '# filogic fixture' > "$installed_mk"

	if [ ! -f "$installer" ]; then
		fail 'closed target installer must exist'
		rm -rf "$fixture"
		return
	fi

	if ! bash "$installer" "$fixture"; then
		fail 'closed target installer must accept a minimal upstream tree'
		rm -rf "$fixture"
		return
	fi

	if [ -s "$installed_dts" ] && [ -s "$installed_mk" ]; then
		pass 'closed target installer creates DTS and image definition'
	else
		fail 'closed target installer must create DTS and image definition'
	fi

	if [ "$(grep -c '^&hnat {' "$installed_dts" 2>/dev/null || true)" = "1" ]; then
		pass 'installed DTS contains exactly one closed HNAT node'
	else
		fail 'installed DTS must contain exactly one closed HNAT node'
	fi

	if [ "$(grep -c '^define Device/nradio_wt9103$' "$installed_mk" 2>/dev/null || true)" = "1" ]; then
		pass 'installed image file contains exactly one C8-660 definition'
	else
		fail 'installed image file must contain exactly one C8-660 definition'
	fi

	for required_package in \
		kmod-mt_wifi \
		kmod-conninfra \
		kmod-mediatek_hnat \
		kmod-warp \
		hnat-detect \
		mtwifi-cfg-ucode \
		miniupnpd-nftables
	do
		if grep -Fq "$required_package" "$installed_mk"; then
			pass "installed image selects $required_package"
		else
			fail "installed image must select $required_package"
		fi
	done

	for forbidden_package in kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
	do
		if grep -Fq "$forbidden_package" "$installed_mk"; then
			fail "installed closed image must not select $forbidden_package"
		else
			pass "installed closed image excludes $forbidden_package"
		fi
		done
	if grep -Eq '(^|[[:space:]])mtwifi-cfg([[:space:]\\]|$)' "$installed_mk"; then
		fail 'installed closed image must not select legacy mtwifi-cfg'
	else
		pass 'installed closed image excludes legacy mtwifi-cfg'
	fi
	if grep -Eq '(^|[[:space:]])miniupnpd([[:space:]\\]|$)' "$installed_mk"; then
		fail 'installed closed image must select the explicit nftables miniupnpd variant'
	else
		pass 'installed closed image excludes ambiguous miniupnpd virtual package'
	fi

	first_hashes="$(sha256sum "$installed_dts" "$installed_mk")"
	if ! bash "$installer" "$fixture"; then
		fail 'closed target installer second run must succeed'
		rm -rf "$fixture"
		return
	fi
	second_hashes="$(sha256sum "$installed_dts" "$installed_mk")"
	if [ "$first_hashes" = "$second_hashes" ]; then
		pass 'closed target installer is idempotent'
	else
		fail 'closed target installer must leave identical files on a second run'
	fi

	rm -rf "$fixture"
}

test_build_validator() {
	local validator="$REPO_ROOT/Scripts/ValidateC8ClosedBuild.sh"
	local fixture

	fixture="$(mktemp -d)"

	if [ ! -f "$validator" ]; then
		fail 'closed build validator must exist'
		rm -rf "$fixture"
		return
	fi

	cat > "$fixture/good.config" <<'GOOD_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_nradio_wt9103=y
CONFIG_PACKAGE_kmod-mt_wifi=y
CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y
CONFIG_MTK_MT_WIFI_MT7981_20260601=y
CONFIG_PACKAGE_kmod-conninfra=y
CONFIG_MTK_CONNINFRA_APSOC=y
CONFIG_MTK_CONNINFRA_APSOC_MT7981=y
CONFIG_CONNINFRA_EMI_SUPPORT=y
CONFIG_CONNINFRA_AUTO_UP=y
CONFIG_PACKAGE_kmod-mediatek_hnat=y
CONFIG_PACKAGE_kmod-warp=y
CONFIG_PACKAGE_hnat-detect=y
CONFIG_MTK_FAST_NAT_SUPPORT=y
CONFIG_MTK_WLAN_HOOK=y
CONFIG_MTK_WHNAT_SUPPORT=m
CONFIG_MTK_WARP_V2=y
CONFIG_WARP_CHIPSET="mt7981"
CONFIG_WARP_VERSION=2
CONFIG_WED_HW_RRO_SUPPORT=y
GOOD_CONFIG

	cat > "$fixture/bad.config" <<'BAD_CONFIG'
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_nradio_wt9103=y
CONFIG_PACKAGE_kmod-mt_wifi=y
CONFIG_MTK_MT_WIFI_DRIVER_VERSION_7673=y
CONFIG_MTK_MT_WIFI_MT7981_20260601=y
CONFIG_PACKAGE_kmod-conninfra=y
CONFIG_PACKAGE_kmod-mediatek_hnat=y
CONFIG_PACKAGE_kmod-warp=y
CONFIG_PACKAGE_hnat-detect=y
CONFIG_MTK_FAST_NAT_SUPPORT=y
CONFIG_MTK_WLAN_HOOK=y
CONFIG_MTK_WHNAT_SUPPORT=m
CONFIG_MTK_WARP_V2=y
CONFIG_WARP_CHIPSET="mt7981"
CONFIG_WARP_VERSION=2
CONFIG_PACKAGE_kmod-mt7915e=y
BAD_CONFIG

	grep -Fvx 'CONFIG_MTK_WLAN_HOOK=y' "$fixture/good.config" > "$fixture/missing-hook.config"
	grep -Fvx 'CONFIG_MTK_CONNINFRA_APSOC=y' "$fixture/good.config" > "$fixture/missing-conninfra-gate.config"

	cat > "$fixture/good.manifest" <<'GOOD_MANIFEST'
kmod-mt_wifi - 7.6.7.3
kmod-conninfra - 1
kmod-mediatek_hnat - 1
kmod-warp - 20250408
hnat-detect - 1
mtwifi-cfg-ucode - 3
luci-app-mtwifi-cfg - 1
uqmi - 1
kmod-usb-net-qmi-wwan - 1
GOOD_MANIFEST

	cat > "$fixture/bad.manifest" <<'BAD_MANIFEST'
kmod-mt_wifi - 7.6.7.3
kmod-conninfra - 1
kmod-mediatek_hnat - 1
hnat-detect - 1
mtwifi-cfg-ucode - 3
luci-app-mtwifi-cfg - 1
uqmi - 1
kmod-usb-net-qmi-wwan - 1
kmod-mt7915e - 6.12
BAD_MANIFEST

	cat > "$fixture/wrong-version.manifest" <<'WRONG_VERSION_MANIFEST'
kmod-mt_wifi - 7.6.7.2
kmod-conninfra - 1
kmod-mediatek_hnat - 1
kmod-warp - 20250408
hnat-detect - 1
mtwifi-cfg-ucode - 3
luci-app-mtwifi-cfg - 1
uqmi - 1
kmod-usb-net-qmi-wwan - 1
WRONG_VERSION_MANIFEST

	cat > "$fixture/good.rootfs" <<'GOOD_ROOTFS'
squashfs-root/lib/modules/6.12.58/mt_wifi.ko
squashfs-root/lib/modules/6.12.58/mtk_warp_proxy.ko
squashfs-root/lib/modules/6.12.58/mtk_warp.ko
squashfs-root/lib/modules/6.12.58/mtkhnat.ko
squashfs-root/lib/modules/6.12.58/conninfra.ko
squashfs-root/lib/firmware/7981_WOCPU0_RAM_CODE_release.bin
squashfs-root/usr/share/ucode/hnat/detect.uc
squashfs-root/sbin/uqmi
squashfs-root/usr/share/modem/rm520n.sh
GOOD_ROOTFS

	cat > "$fixture/bad.rootfs" <<'BAD_ROOTFS'
squashfs-root/lib/modules/6.12.58/mt_wifi.ko
squashfs-root/lib/modules/6.12.58/mtk_warp.ko
squashfs-root/lib/modules/6.12.58/mtkhnat.ko
squashfs-root/lib/modules/6.12.58/conninfra.ko
squashfs-root/lib/modules/6.12.58/mt7915e.ko
squashfs-root/lib/firmware/7981_WOCPU0_RAM_CODE_release.bin
squashfs-root/usr/share/ucode/hnat/detect.uc
squashfs-root/usr/bin/uqmi
squashfs-root/usr/share/modem/rm520n.sh
BAD_ROOTFS

	if bash "$validator" config "$fixture/good.config"; then
		pass 'validator accepts the complete closed Kconfig contract'
	else
		fail 'validator must accept the complete closed Kconfig contract'
	fi
	if bash "$validator" config "$fixture/bad.config" >/dev/null 2>&1; then
		fail 'validator must reject missing WED and present mt76 Kconfig'
	else
		pass 'validator rejects missing WED and present mt76 Kconfig'
	fi
	if bash "$validator" config "$fixture/missing-hook.config" >/dev/null 2>&1; then
		fail 'validator must reject a closed config without the WLAN hook required by WHNAT'
	else
		pass 'validator rejects missing WLAN hook dependency'
	fi
	if bash "$validator" config "$fixture/missing-conninfra-gate.config" >/dev/null 2>&1; then
		fail 'validator must reject a closed config without the conninfra APSOC gate required by modpost'
	else
		pass 'validator rejects missing conninfra APSOC gate dependency'
	fi

	if bash "$validator" manifest "$fixture/good.manifest"; then
		pass 'validator accepts the complete closed package manifest'
	else
		fail 'validator must accept the complete closed package manifest'
	fi
	if bash "$validator" manifest "$fixture/bad.manifest" >/dev/null 2>&1; then
		fail 'validator must reject a manifest without WARP and with mt76'
	else
		pass 'validator rejects a manifest without WARP and with mt76'
	fi
	if bash "$validator" manifest "$fixture/wrong-version.manifest" >/dev/null 2>&1; then
		fail 'validator must reject mt_wifi versions other than 7.6.7.3'
	else
		pass 'validator rejects an unexpected mt_wifi version'
	fi

	if bash "$validator" rootfs "$fixture/good.rootfs"; then
		pass 'validator accepts the complete closed rootfs module chain'
	else
		fail 'validator must accept the complete closed rootfs module chain'
	fi
	if bash "$validator" rootfs "$fixture/bad.rootfs" >/dev/null 2>&1; then
		fail 'validator must reject a rootfs without WARP proxy and with mt76'
	else
		pass 'validator rejects a rootfs without WARP proxy and with mt76'
	fi

	rm -rf "$fixture"
}

test_workflow_contract() {
	local workflow="$REPO_ROOT/.github/workflows/c8-660-closed.yml"
	local legacy_workflow="$REPO_ROOT/.github/workflows/c8-660-closed-21.02.yml"
	local closed_count

	closed_count="$(find "$REPO_ROOT/.github/workflows" -maxdepth 1 -type f -iname '*closed*.yml' | wc -l)"
	closed_count="${closed_count//[[:space:]]/}"
	if [ "$closed_count" = "1" ] && [ -f "$workflow" ]; then
		pass 'workflow migration leaves one version-neutral closed entry'
	else
		fail "workflow migration must leave only c8-660-closed.yml (found $closed_count)"
	fi
	if [ -e "$legacy_workflow" ]; then
		fail 'workflow migration must remove the 21.02 entry'
	else
		pass 'workflow migration removes the 21.02 entry'
	fi
	if grep -Fq '[[ "${WRT_CONFIG:-}" != *CLOSED* ]] && grep' "$REPO_ROOT/Scripts/Packages.sh"; then
		fail 'closed package routing must allow explicitly selected HomeProxy'
	else
		pass 'closed package routing does not force-disable explicitly selected HomeProxy'
	fi

	if [ ! -f "$workflow" ]; then
		fail 'closed 25.12 workflow must exist before its behavior can be validated'
		return
	fi

	if python3 - "$workflow" <<'PY'
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


class WorkflowLoader(yaml.SafeLoader):
    pass


for first, mappings in list(WorkflowLoader.yaml_implicit_resolvers.items()):
    WorkflowLoader.yaml_implicit_resolvers[first] = [
        item for item in mappings if item[0] != "tag:yaml.org,2002:bool"
    ]


path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
data = yaml.load(text, Loader=WorkflowLoader)
assert isinstance(data, dict), "workflow root must be a mapping"
assert set((data.get("jobs") or {}).keys()) == {"build"}, "expected exactly one build job"
dispatch = (data.get("on") or {}).get("workflow_dispatch")
assert isinstance(dispatch, dict), "workflow_dispatch must define inputs"
inputs = dispatch.get("inputs") or {}
for name in ("wrt_ref", "publish_release", "enable_cache", "keep_releases"):
    assert name in inputs, f"missing workflow input: {name}"

env = data.get("env") or {}
expected_env = {
    "WRT_CONFIG": "NRADIO-C8-660-CLOSED",
    "WRT_REPO": "https://github.com/chasey-dev/immortalwrt-mt798x-rebase",
    "WRT_BRANCH": "25.12",
    "WRT_REF": "${{ inputs.wrt_ref || '2d0e93b1253660ae15d195786cd7fa913d70d42a' }}",
    "WRT_WIFI": "mt_wifi-7.6.7.3-hnat-wed",
}
for key, value in expected_env.items():
    assert str(env.get(key)) == value, f"unexpected {key}: {env.get(key)!r}"

steps = data["jobs"]["build"].get("steps") or []
checkout = next((step for step in steps if str(step.get("uses", "")).startswith("actions/checkout@")), None)
assert checkout is not None, "missing actions/checkout"
assert checkout.get("with", {}).get("persist-credentials") in (False, "false"), "checkout credentials must be disabled"

step_names = [step.get("name") for step in steps]
assert "Preflight Closed Firmware" in step_names, "missing closed firmware preflight step"
assert step_names.index("Preflight Closed Firmware") < step_names.index("Configure Closed Firmware"), (
    "closed firmware preflight must run before configuration"
)
preflight = next(step for step in steps if step.get("name") == "Preflight Closed Firmware")
preflight_run = str(preflight.get("run", ""))
assert 'Scripts/PreflightC8Closed25.sh" ./wrt/' in preflight_run, "preflight is missing its runner"
preflight_script = (path.parents[2] / "Scripts" / "PreflightC8Closed25.sh").read_text(encoding="utf-8")
for fragment in ('make defconfig', 'Scripts/ValidateC8ClosedBuild.sh" config .config'):
    assert fragment in preflight_script, f"preflight is missing: {fragment}"

packages = next((step for step in steps if step.get("name") == "Install Custom Packages"), None)
assert packages is not None, "missing custom package installation step"
with tempfile.TemporaryDirectory() as fixture:
    fixture_path = Path(fixture)
    (fixture_path / "Scripts").mkdir()
    (fixture_path / "wrt/package").mkdir(parents=True)
    marker = fixture_path / "packages-ran"
    for script_name in ("Packages.sh", "Handles.sh"):
        script = fixture_path / "Scripts" / script_name
        script.write_text(f'printf "%s\\n" "{script_name}" >> "$PACKAGE_MARKER"\n', encoding="utf-8")
        script.chmod(0o644)
    package_env = os.environ.copy()
    package_env.update(GITHUB_WORKSPACE=str(fixture_path), PACKAGE_MARKER=str(marker))
    package_result = subprocess.run(
        ["bash", "-c", str(packages.get("run", ""))],
        cwd=fixture_path,
        env=package_env,
        capture_output=True,
        text=True,
    )
    assert package_result.returncode == 0, (
        "custom package step must run repository scripts without executable bits:\n"
        f"{package_result.stdout}{package_result.stderr}"
    )
    assert marker.read_text(encoding="utf-8").splitlines() == ["Packages.sh", "Handles.sh"]

runs = "\n".join(str(step.get("run", "")) for step in steps)
required_run_fragments = (
    'git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" ./wrt/',
    'git fetch --depth=1 origin "$WRT_REF"',
    'git checkout --detach',
    'git rev-parse HEAD',
    'Scripts/InstallC8ClosedTarget.sh',
    'Config/NRADIO-C8-660-CLOSED.txt',
    'Config/CLOSED.txt',
    'Config/GENERAL-CLOSED.txt',
    'Scripts/ValidateC8ClosedBuild.sh" config',
    'Scripts/ValidateC8ClosedBuild.sh" manifest',
    'Scripts/ValidateC8ClosedBuild.sh" rootfs',
    'sha256sum',
    'WRT_HASH',
)
for fragment in required_run_fragments:
    assert fragment in runs, f"missing workflow behavior: {fragment}"

assert 'MT_WIFI_DRIVER_VERSION_7661' not in text, "legacy 7.6.6.1 selector remains"
assert 'warp_enable=\"n\"' not in text, "legacy WARP disable remains"
assert not re.search(r'CONFIG_(?:PACKAGE_kmod-warp|MTK_WARP_V2)=n', text), "workflow disables WARP"

package_step = next((step for step in steps if step.get("name") == "Package Firmware"), None)
assert package_step is not None, "missing unique artifact packaging step"
package_run = str(package_step.get("run", ""))
for artifact in ("factory", "sysupgrade", "initramfs", "bl2"):
    assert f"select_one {artifact}" in package_run, f"missing unique {artifact} selection"
assert "SOURCE_COMMIT=$WRT_HASH_FULL" in package_run, "artifact metadata lacks full source commit"
assert "sha256sum ./*" not in package_run, "checksum generation must not include sha256sums itself"
for artifact_name in (
    "immortalwrt-c8-660-closed-factory.bin",
    "immortalwrt-c8-660-closed-sysupgrade.bin",
    "immortalwrt-c8-660-closed-initramfs.bin",
    "mt7981-ddr4-bl2.bin",
    "immortalwrt-c8-660-closed.manifest",
    "build-metadata.txt",
):
    assert package_run.count(artifact_name) >= 2, f"checksum input missing: {artifact_name}"

release = next((step for step in steps if str(step.get("uses", "")).startswith("softprops/action-gh-release@")), None)
assert release is not None, "missing release step"
assert "${{env.WRT_HASH_FULL}}" in str(release.get("with", {}).get("body", "")), "release metadata lacks full source hash"
PY
	then
		pass 'closed workflow enforces pinned source, vendor acceleration, validation, and unique artifacts'
	else
		fail 'closed workflow must enforce the complete 25.12 build contract'
	fi
}

test_documentation_contract() {
	local readme="$REPO_ROOT/README.md"
	local required
	local forbidden

	if [ -e "$REPO_ROOT/archive/closed-24.10" ]; then
		fail 'retired closed archive must be deleted, not retained as a runnable recipe'
	else
		pass 'retired closed archive is absent'
	fi

	for required in \
		'.github/workflows/c8-660-closed.yml' \
		'chasey-dev/immortalwrt-mt798x-rebase' \
		'25.12' \
		'Linux 6.12' \
		'mt_wifi 7.6.7.3' \
		'HNAT' \
		'WARP/WED' \
		'RGMII/IPPT' \
		'eth1' \
		'USB/QMI' \
		'hnat-detect' \
		'rxppd' \
		'/sys/kernel/debug/hnat/hnat_entry' \
		'grep -c BIND' \
		'软件转发'
	do
		if grep -Fq "$required" "$readme"; then
			pass "README documents $required"
		else
			fail "README must document $required"
		fi
	done

	for forbidden in \
		'C8-660 Closed 21.02' \
		'c8-660-closed-21.02.yml' \
		'archive/closed-24.10' \
		'mt_wifi (MediaTek 专有 v7.6.6.1)' \
		'WARP/HNAT 暂停启用'
	do
		if grep -Fq "$forbidden" "$readme"; then
			fail "README must remove legacy closed claim: $forbidden"
		else
			pass "README excludes legacy closed claim: $forbidden"
		fi
	done
}

case "$MODE" in
	--repository)
		test_repository_shape
		;;
	--target)
		test_target_injection
		;;
	--validator)
		test_build_validator
		;;
	--workflow)
		test_workflow_contract
		;;
	--docs)
		test_documentation_contract
		;;
	--all)
		test_repository_shape
		test_target_injection
		test_build_validator
		test_workflow_contract
		test_documentation_contract
		;;
	*)
		printf 'Unknown mode: %s\n' "$MODE" >&2
		exit 2
		;;
esac

if [ "$FAILURES" -ne 0 ]; then
	printf '%s closed migration test(s) failed\n' "$FAILURES" >&2
	exit 1
fi

printf 'All requested closed migration tests passed\n'
