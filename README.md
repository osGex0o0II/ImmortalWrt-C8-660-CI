# ImmortalWrt-C8-660-CI

NRadio C8-660 (MediaTek MT7981) 专用 ImmortalWrt 固件编译 CI。

基于 [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) master 分支编译。

## 使用方式

在 Actions 页面手动触发 `ImmortalWrt NRadio C8-660` 工作流即可编译。

## 目录结构

- `.github/workflows/` — CI 工作流（自包含单文件）
- `Scripts/` — 编译自定义脚本（主题、插件、系统设置）
- `Config/` — 设备 Kconfig + 通用包配置
- `patches/` — 设备树 (DTS) + filogic.mk 设备定义

## 参考

- ImmortalWrt 官网: https://immortalwrt.org
- NRadio 官网: https://www.nradiowifi.com
