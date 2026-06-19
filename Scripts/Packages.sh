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

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
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
		cd "$REPO_NAME" 2>/dev/null || cd "$PKG_NAME" 2>/dev/null || true
		git fetch --unshallow 2>/dev/null || true
		git checkout "$LOCKED_COMMIT" || echo "::warning::Failed to checkout $PKG_NAME commit $LOCKED_COMMIT"
		cd ..
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

# 主题
UPDATE_PACKAGE "luci-theme-aurora" "eamonxg/luci-theme-aurora" "master" "" "aurora" "" "aurora"
UPDATE_PACKAGE "luci-app-aurora-config" "eamonxg/luci-app-aurora-config" "master" "" "aurora-config" "" "aurora_config"

# 插件
UPDATE_PACKAGE "luci-app-partexp" "sirpdboy/luci-app-partexp" "main" "" "partexp" "luci-app-partexp" "partexp"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
