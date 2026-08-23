#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
set -euo pipefail

#安装和更新软件包
# 环境变量锁定支持:
#   PKG_LOCK_<name>_COMMIT   — 锁定到指定 commit SHA
#   PKG_LOCK_<name>_BRANCH   — 覆盖默认分支
# 示例: PKG_LOCK_aurora_COMMIT=abc123def
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=${4:-}
	local PKG_LIST=("$PKG_NAME" ${5:-})  # 第5个参数为自定义名称列表
	local PKG_SUBDIR=${6:-}
	local PKG_LOCK_ALIAS=${7:-}
	local REPO_NAME=${PKG_REPO#*/}

	# 检查是否有环境变量覆盖
	local LOCK_VAR="PKG_LOCK_${PKG_NAME//-/_}_COMMIT"
	local BRANCH_VAR="PKG_LOCK_${PKG_NAME//-/_}_BRANCH"
	local LOCKED_COMMIT="${!LOCK_VAR:-}"
	local LOCKED_BRANCH="${!BRANCH_VAR:-$PKG_BRANCH}"
	if [ -n "$PKG_LOCK_ALIAS" ]; then
		local ALIAS_LOCK_VAR="PKG_LOCK_${PKG_LOCK_ALIAS//-/_}_COMMIT"
		local ALIAS_BRANCH_VAR="PKG_LOCK_${PKG_LOCK_ALIAS//-/_}_BRANCH"
		LOCKED_COMMIT="${LOCKED_COMMIT:-${!ALIAS_LOCK_VAR:-}}"
		LOCKED_BRANCH="${!BRANCH_VAR:-${!ALIAS_BRANCH_VAR:-$PKG_BRANCH}}"
	fi

	echo " "
	echo "Package: $PKG_NAME (repo: $PKG_REPO, branch: $LOCKED_BRANCH)"

	local CLEAN_NAMES=("$PKG_NAME" "$REPO_NAME" "${PKG_LIST[@]}")
	local SEEN_CLEAN_NAMES=" "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${CLEAN_NAMES[@]}"; do
		[ -n "$NAME" ] || continue
		case "$SEEN_CLEAN_NAMES" in
			*" $NAME "*) continue ;;
		esac
		SEEN_CLEAN_NAMES="$SEEN_CLEAN_NAMES$NAME "
		if [ -d "$NAME" ]; then
			rm -rf "$NAME"
			echo "Delete package directory: $NAME"
		fi

		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found: $NAME"
		fi
	done

	# 克隆 GitHub 仓库（含重试）
	for i in 1 2 3; do
		git clone --depth=1 --single-branch --branch "$LOCKED_BRANCH" "https://github.com/$PKG_REPO.git" && break || sleep 10
	done
	if [ ! -d "$REPO_NAME" ] && [ ! -d "$PKG_NAME" ]; then
		echo "::error::Failed to clone $PKG_REPO after 3 attempts"
		return 1
	fi

	# 如果设置了锁定 commit，checkout 到该 commit
	if [ -n "$LOCKED_COMMIT" ]; then
		local CLONE_DIR="$REPO_NAME"
		[ -d "$CLONE_DIR/.git" ] || CLONE_DIR="$PKG_NAME"
		if [ ! -d "$CLONE_DIR/.git" ]; then
			echo "::error::Cannot locate git checkout for locked package $PKG_NAME"
			return 1
		fi
		(
			cd "$CLONE_DIR"
			git fetch --unshallow 2>/dev/null || git fetch --all --tags
			git checkout "$LOCKED_COMMIT"
		) || {
			echo "::error::Failed to checkout $PKG_NAME commit $LOCKED_COMMIT"
			return 1
		}
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi

	if [ -n "$PKG_SUBDIR" ]; then
		local CLONE_DIR="$REPO_NAME"
		[ -d "$CLONE_DIR" ] || CLONE_DIR="$PKG_NAME"
		if [ ! -d "$CLONE_DIR/$PKG_SUBDIR" ]; then
			echo "::error::Expected package subdirectory not found: $CLONE_DIR/$PKG_SUBDIR"
			return 1
		fi
		local TMP_DIR
		TMP_DIR="$(mktemp -d)"
		mv "$CLONE_DIR/$PKG_SUBDIR" "$TMP_DIR/$PKG_NAME"
		rm -rf "$CLONE_DIR"
		mv "$TMP_DIR/$PKG_NAME" "$PKG_NAME"
		rm -rf "$TMP_DIR"
	fi

	if [ ! -f "$PKG_NAME/Makefile" ]; then
		echo "::error::Package Makefile not found for $PKG_NAME"
		find "$PKG_NAME" -maxdepth 3 -type f -name Makefile 2>/dev/null || true
		return 1
	fi
	if ! grep -q "include .*\$(TOPDIR)/feeds/luci/luci.mk" "$PKG_NAME/Makefile"; then
		echo "::warning::$PKG_NAME Makefile is not a standard LuCI package"
	fi
	echo "Package ready: $PKG_NAME"
}

CONFIG_FILES=(
	"$GITHUB_WORKSPACE/Config/${WRT_CONFIG:-}.txt"
	"$GITHUB_WORKSPACE/Config/PRIVATE.txt"
)
if [[ "${WRT_CONFIG:-}" == *CLOSED* ]]; then
	CONFIG_FILES+=(
		"$GITHUB_WORKSPACE/Config/CLOSED.txt"
		"$GITHUB_WORKSPACE/Config/GENERAL-CLOSED.txt"
	)
else
	CONFIG_FILES+=(
		"$GITHUB_WORKSPACE/Config/OPEN.txt"
		"$GITHUB_WORKSPACE/Config/GENERAL.txt"
	)
fi

# 主题
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "" "aurora" "" "aurora"
if grep -qs '^CONFIG_PACKAGE_luci-app-aurora-config=y$' "${CONFIG_FILES[@]}"; then
	UPDATE_PACKAGE "luci-app-aurora-config" "eamonxg/luci-app-aurora-config" "master" "" "aurora-config" "" "aurora_config"
fi

# 插件
if grep -qs '^CONFIG_PACKAGE_luci-app-partexp=y$' "${CONFIG_FILES[@]}"; then
	UPDATE_PACKAGE "luci-app-partexp" "sirpdboy/luci-app-partexp" "main" "" "partexp" "luci-app-partexp" "partexp"
fi
if grep -qs '^CONFIG_PACKAGE_luci-app-homeproxy=y$' "${CONFIG_FILES[@]}"; then
	UPDATE_PACKAGE "luci-app-homeproxy" "immortalwrt/homeproxy" "master" "name" "homeproxy" "" "homeproxy"
	bash "$GITHUB_WORKSPACE/Scripts/PatchHomeProxyModern.sh" "luci-app-homeproxy"
fi

# WOL Ultra（VIKINGYFY/packages 为多包仓库：UPDATE_PACKAGE 会按仓库名
# "packages" 在 feeds 里模糊匹配删除，误伤 feeds/packages，故用专用提取块）
if grep -qs '^CONFIG_PACKAGE_luci-app-wolultra=y$' "${CONFIG_FILES[@]}"; then
	WOLULTRA_LOCK="${PKG_LOCK_luci_app_wolultra_COMMIT:-}"
	WOLULTRA_BRANCH="${PKG_LOCK_luci_app_wolultra_BRANCH:-main}"
	echo " "
	echo "Package: luci-app-wolultra (repo: VIKINGYFY/packages, branch: $WOLULTRA_BRANCH)"
	rm -rf ../feeds/luci/applications/luci-app-wolultra luci-app-wolultra vikingyfy-packages-tmp
	WOLULTRA_CLONED=""
	for i in 1 2 3; do
		if git clone --depth=1 --single-branch --branch "$WOLULTRA_BRANCH" \
			"https://github.com/VIKINGYFY/packages.git" vikingyfy-packages-tmp; then
			WOLULTRA_CLONED=1
			break
		fi
		sleep 10
	done
	if [ -z "$WOLULTRA_CLONED" ]; then
		echo "::error::Failed to clone VIKINGYFY/packages after 3 attempts"
		exit 1
	fi
	if [ -n "$WOLULTRA_LOCK" ]; then
		(
			cd vikingyfy-packages-tmp
			git fetch --unshallow 2>/dev/null || git fetch --all --tags
			git checkout "$WOLULTRA_LOCK"
		) || {
			echo "::error::Failed to checkout luci-app-wolultra commit $WOLULTRA_LOCK"
			exit 1
		}
	fi
	if [ ! -f vikingyfy-packages-tmp/luci-app-wolultra/Makefile ]; then
		echo "::error::luci-app-wolultra not found in VIKINGYFY/packages"
		exit 1
	fi
	mv vikingyfy-packages-tmp/luci-app-wolultra ./luci-app-wolultra
	rm -rf vikingyfy-packages-tmp
	echo "Package ready: luci-app-wolultra"
fi

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
