# ImmortalWrt-NRadio-C8-660

[![Build](https://github.com/osGex0o0II/ImmortalWrt-C8-660-CI/actions/workflows/c8-660-open.yml/badge.svg)](https://github.com/osGex0o0II/ImmortalWrt-C8-660-CI/actions/workflows/c8-660-open.yml)

NRadio C8-660 (MediaTek MT7981B) 专用 ImmortalWrt 固件编译 CI。

## 硬件规格

| 项目 | 参数 |
|------|------|
| SoC | MediaTek MT7981B (2x Cortex-A53 @ 1.3GHz) |
| RAM | 512MB DDR4 |
| Flash | 512MB SPI-NAND |
| WiFi | MediaTek MT7976CN (AX3000, 2.4G + 5G, 2x2 MIMO) |
| 5G 模组 | Quectel RM520N-CN (Snapdragon X62) |
| 以太网 | 1x 2.5GbE + 3x 1GbE (MT7531 交换机) |
| 按键 | Reset, WPS |
| LED | Status, 5G, LAN, WiFi |

## 默认设置

| 项目 | 值 |
|------|-----|
| 登录地址 | 192.168.1.1 |
| 登录密码 | 由 `WRT_PW` secret 设置 |
| WiFi SSID | NRadio-xxxx（MAC 地址后四位） |
| WiFi 密码 | 由 `WRT_WORD` secret 设置，未设置则开放 |
| WiFi 加密 | 有密码时默认 WPA2/WPA3 Personal，未设置密码时开放 |
| 主题 | Aurora |
| 语言 | 简体中文 |

## 预装插件（第三方）

| 插件 | 说明 |
|------|------|
| luci-theme-aurora | Aurora 主题 |
| luci-app-c8modem | C8 蜂窝与短信工具（含短信接收/发送/转发） |
| luci-app-homeproxy | 代理管理界面（Open 默认；Closed 仅在配置中显式选择时加入） |

默认开源镜像保持 C8 蜂窝 CPE 与 HomeProxy/sing-box 代理基线，并预装 TTYD/Web 终端、UPnP、WOL 和 ZeroTier；不再预装 `luci-app-partexp` 和 LuCI 包管理页面。需要分区维护时，可通过 `Config/PRIVATE.txt` 或刷机后的命令行包管理器按需启用。

短信推送能力由 `luci-app-c8modem` 的 `modem/sms` 页面统一管理，内置 PushPlus、Telegram、Server 酱、WxPusher、企业微信和自定义 Webhook 通道；不再预装独立 `luci-app-wechatpush`，避免菜单、服务和配置互相冲突。

## 内核模块

fuse, nft-core/fullcone/offload/queue/socket/tproxy,
tun, usb-core, usb-net, usb-net-qmi-wwan-quectel,
usb-storage

## 系统工具

autocore, automount, blkid, cpufreq, curl, htop,
ip-full, lsblk, openssh-keygen, adb（RM520N 原生 IPv6/ADB 状态支持）等

## 编译变体

本项目保留两条构建线：Open 使用开源 mt76，Closed 使用固定上游提交的 MediaTek 专有无线与加速栈。旧闭源版本已移除，不再保留可运行入口。

| | 开源构建 (Open) | 闭源构建 (Closed) |
|--|--|--|
| **工作流** | `C8-660 Open (mt76)` | `C8-660 Closed (mt_wifi 7.6.7.3 + HNAT/WED)` |
| **文件** | `.github/workflows/c8-660-open.yml` | `.github/workflows/c8-660-closed.yml` |
| **源码** | immortalwrt/immortalwrt (`openwrt-25.12`) | chasey-dev/immortalwrt-mt798x-rebase (`25.12`) |
| **内核** | Linux 6.x (mainline) | Linux 6.12 |
| **WiFi 驱动** | mt76 (开源) | mt_wifi 7.6.7.3 (MediaTek 专有) |
| **硬件加速** | mt76 WED | HNAT + WARP/WED |
| **设备支持** | 通过 `patches/` 注入 | 通过闭源专用目标注入脚本安装 |
| **默认 IP** | 192.168.1.1 | 192.168.1.1 |
| **默认主题** | Aurora | Aurora |
| **固件前缀** | `immortalwrt-c8-660` | `immortalwrt-c8-660-closed` |

### 开源构建特点

- 基于 mainline 内核，长期维护性好
- mt76 开源驱动，社区支持
- Aurora 主题，现代化 UI
- 首次刷入需通过 U-Boot TFTP 模式
- WiFi 校准数据依赖 factory 分区 EEPROM

### 闭源构建特点

- 固定 `chasey-dev/immortalwrt-mt798x-rebase` 的 `25.12` 分支提交 `2d0e93b1253660ae15d195786cd7fa913d70d42a`
- Linux 6.12、mt_wifi 7.6.7.3、`kmod-mediatek_hnat`、`kmod-warp` 和 WARP/WED vendor 链
- `Scripts/InstallC8ClosedTarget.sh` 注入 C8-660 DTS、闭源镜像定义及 `eth1` HNAT 属性
- 构建后强制校验 `.config`、manifest 和 rootfs，拒绝 mt76/mac80211 无线栈混入
- HomeProxy 不作为 Closed 默认包；仅在私有配置显式选择时加入

## 编译信息（开源构建）

| 项目 | 值 |
|------|-----|
| 源码 | immortalwrt/immortalwrt |
| 分支 | openwrt-25.12 |
| 内核 | 6.x (mainline) |
| WiFi 驱动 | mt76 (开源) |
| 镜像格式 | UBI + FIT |
| 触发方式 | 手动 (workflow_dispatch) |

Open 构建默认使用 ImmortalWrt 稳定分支 `openwrt-25.12`。`workflow_dispatch` 仍保留 `wrt_branch` / `wrt_ref` 输入，便于手动对比 `master` snapshot 或固定到指定 commit；稳定发布不建议使用 `master` 作为默认底座。

## 已知风险与救砖

### 开源构建

本项目编译产物为 mainline 内核 (6.x)，与设备原厂 SDK 内核 (5.4) 引导链不兼容。本项目为**单系统固件**，首次刷入需通过 **U-Boot TFTP 恢复模式**，将整个 NAND 替换为 OpenWrt 单系统，**不可**直接在原厂 Web 升级，也不支持双系统切换。

### 闭源构建

Closed 已迁移到 Linux 6.12，不能按旧 SDK 固件的兼容性假设直接 Web 升级。默认 IP 为 192.168.1.1，固件文件名包含 `closed`，与 Open 产物互不通用；首次从原厂 NROS 刷入仍按 U-Boot TFTP 恢复流程处理。

刷机前**必须备份 FIP / bl2 分区**：

```
mtd read /tmp/bl2_backup.bin bl2
mtd read /tmp/fip_backup.bin fip
```

WiFi 校准数据依赖 factory/bdinfo 分区。刷机前还应记录原系统网络、无线和 RM520N 配置，确认 TFTP 救援链路可用。

本仓库当前的 RM520N 数据面是 RGMII/IPPT：模块把公网数据交给 SoC 的 `eth1`，USB 串口/QMI 包主要提供 AT、诊断及可选 USB/QMI 数据面支持。不要把安装了 `uqmi` 或 `kmod-usb-net-qmi-wwan` 当成 USB/QMI 已经承担 WAN 数据面的证据。

救砖资源：NRadio 官方技术支持 / 官方救援 TFTP 服务器。

## mainline 集成说明

ImmortalWrt 稳定分支 / OpenWrt mainline 当前**未集成 NRadio C8-660 设备支持**。本项目通过 `Scripts/Patches.sh` 在编译时自动注入以下补丁：

- `patches/mt7981b-nradio-c8-660.dts` — 完整设备树（基于 hanwckf -512m 改写）
- `patches/filogic-c8-660.mk` — 设备定义追加到 `filogic.mk`
- `patches/01_leds.snippet` — 注入 Status/5G/LAN/WiFi LED 行为
- `patches/11_fix_wifi_mac.snippet` — 注入从 `bdinfo` 分区读取 MAC 并修复 WiFi MAC

## 社区相关项目

- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) — SDK 5.4 + nmbm 内核，包含 C8-660（512M）原始 DTS 与 mt7981.mk
- [openwrt/openwrt PR #17093](https://github.com/openwrt/openwrt/pull/17093) — 官方 C8-668GL（eMMC 版，8GB 闪存，⚠ 非 C8-660 的 SPI-NAND 硬件，仅供参考）
- [newton-miku/luci-app-cellscan](https://github.com/newton-miku/luci-app-cellscan) — C8-660/668 专用基站扫描插件（可手动安装）
- [tltv1212/Nradio-Firmware-Selector](https://github.com/tltv1212/Nradio-Firmware-Selector) — NRadio 鲲鹏 C8 系列固件下载列表
- [duhaoyang520-collab/bl-mt7981](https://github.com/duhaoyang520-collab/bl-mt7981) — ATF / U-Boot 编译工具（救砖参考）

## 闭源构建专有包

Closed 25.12 使用以下 MTK 专有组件：

### MTK 专有组件

| 包名 | 说明 |
|------|------|
| kmod-mt_wifi | MediaTek 专有 WiFi 驱动 7.6.7.3 |
| kmod-conninfra | 连接基础设施模块 |
| kmod-warp | mt_wifi 到 WED/HNAT 的 WARP v2 加速层 |
| kmod-mediatek_hnat | MediaTek PPE 硬件 NAT |
| hnat-detect | 根据 fw4/netifd 拓扑配置 HNAT；外部 USB/WWAN 数据面时管理 `rxppd` |
| wifi-dats | WiFi DAT 校准数据文件 |
| mtwifi-cfg-ucode | 25.12 ucode WiFi 配置管理工具 |
| luci-app-mtwifi-cfg | LuCI WiFi 配置界面 |
| luci-app-turboacc-mtk | MTK HNAT/WARP 状态和配置界面 |
| luci-app-eqos-mtk | MTK QoS 流量控制 |

### HNAT/WED 实机验收

包、模块和 LuCI 页面存在只能证明镜像包含组件，不能证明流量进入 PPE。当前 C8-660 的默认 WAN 应由 netifd 解析到 `eth1`；只有实际切换为 `wwan0` 等外部 USB/QMI 数据面时，`hnat-detect` 才应创建 `rxppd` 并加入 LAN bridge。

```sh
ubus call network.interface.wan status | jsonfilter -e '@.l3_device'
ip link show rxppd 2>/dev/null || true
bridge link show | grep rxppd || true
logread | grep hnat-detect
cat /sys/kernel/debug/hnat/hnat_entry | grep -c BIND
```

分别从 LAN 和 WiFi 客户端持续访问 RM520N WAN，在流量前后重复最后一条命令；两条路径都必须出现 PPE `BIND` 数量增长。默认 `eth1` 路径下没有 `rxppd` 是正常现象；外部 USB/QMI 路径若没有 `rxppd`，应先检查 netifd 的真实 L3 设备名，再针对 `qmimux*`/`rmnet*` 做窄范围适配。HNAT 未绑定时 fw4 的软件转发应继续工作，只是吞吐和 CPU 占用会退化，不能以关闭软件回退来掩盖硬件加速失败。

## 高级特性

本项目在标准 ImmortalWrt 编译流程基础上，增加了以下优化：

| 特性 | 说明 | 配置位置 |
|------|------|----------|
| WED 硬件加速 | Open 使用 mt76 WED；Closed 使用 mt_wifi → WARP/WED → HNAT/PPE vendor 链 | `Config/OPEN.txt`, `Config/CLOSED.txt` |
| 硬件流卸载 | Open 使用 nftables flow offload；Closed 同时启用 MediaTek HNAT 并要求 PPE 实机验证 | `Scripts/Settings.sh`, `Scripts/ValidateC8ClosedBuild.sh` |
| Packet Steering | 启用 RPS 多核软中断分摊，降低单核瓶颈 | `Scripts/Settings.sh` |
| 网络栈调优 | TCP/UDP buffer 扩大 + NAPI 轮询参数优化 | `Scripts/Settings.sh` |
| C8 短信转发 | 内置多通道推送、主备通道、日志、测试按钮和 `sms_tool` 超时保护 | `patches/files/usr/bin/c8-sms-forward`, `patches/files/www/luci-static/resources/view/c8modem/` |
| 第三方包锁定 | 通过 `PKG_LOCK_<name>_COMMIT` 环境变量锁定包版本 | `Scripts/Packages.sh` |
| sing-box 版本锁定 | Open 默认 HomeProxy/sing-box 构建通过 `.github/proxy-locks.env` 回填 `sing-box` release | `.github/workflows/update-proxy-locks.yml`, `Scripts/ApplyProxyLocks.sh` |
| SHA256 脚本校验 | `init_build_environment.sh` 使用仓库 pin 文件校验，并由定时工作流跟随上游更新 | `.github/init_build_environment.sha256`, `.github/workflows/update-init-build-sha.yml` |
| 旧设备兼容 | `SUPPORTED_DEVICES nradio,wt9103` 支持旧 DTS 名称升级 | `patches/filogic-c8-660.mk` |
| CCache 加速 | 编译缓存自动持久化，增量编译时间 -50% | `.github/workflows` |
| 自定义扩展 | `Scripts/PRIVATE.sh` + `Config/PRIVATE.txt` 可选私有配置（gitignored） | `Scripts/`, `Config/` |

### 环境变量参考

| 变量 | 用途 | 示例 |
|------|------|------|
| `PKG_LOCK_aurora_COMMIT` | 锁定 luci-theme-aurora 版本 | `abc123def` |
| `PKG_LOCK_partexp_COMMIT` | 按需启用 luci-app-partexp 时锁定版本 | `deadbeef` |
| `PKG_LOCK_homeproxy_COMMIT` | 锁定默认 HomeProxy 版本（可由 `.github/proxy-locks.env` 刷新） | `e8b8ebc...` |
| `SING_BOX_VERSION` | 默认 sing-box 使用的稳定版版本号 | `1.13.14` |
| `SING_BOX_HASH` | 默认 sing-box 使用的 tarball SHA256 | `d18294...` |
| `INIT_BUILD_EXPECTED_SHA256` | 可选覆盖仓库 pin 文件，用于临时固定构建环境脚本哈希 | `sha256sum` 输出 |
| `WRT_WORD` (secret) | WiFi 密码（空=开放） | `MyPassword` |
| `WRT_PW` (secret) | root 登录密码，必填；为空时 CI 会拒绝构建 | `MyPassword` |

## 使用流程

1. GitHub Actions 手动触发对应工作流：
   - **开源构建**: `C8-660 Open (mt76)`（使用 mt76 开源驱动）
   - **闭源构建**: `C8-660 Closed (mt_wifi 7.6.7.3 + HNAT/WED)`（固定 25.12 源码提交）
2. 下载与所选变体一致的 `factory`（首次刷入）或 `sysupgrade`（同构建线升级）产物并校验 `sha256sums`
3. U-Boot TFTP 模式下刷入对应 `factory` 镜像（**首次刷机会替换整个 NAND，包括原厂 NROS**）
   - 按住 Reset 按钮上电，设备进入 TFTP 恢复模式
   - 通过网线连接电脑，设置 IP 为 `192.168.1.x` 段
   - 使用 TFTP 工具上传所选 Open/Closed 的 factory 镜像
4. 启动后浏览器访问 192.168.1.1

### 产物说明

| 文件 | 用途 |
|------|------|
| `immortalwrt-c8-660[-closed]-factory.bin` | 从原厂 NROS 首次刷入（U-Boot TFTP） |
| `immortalwrt-c8-660[-closed]-sysupgrade.bin` | 同构建线升级（LuCI → 系统 → 备份/升级） |
| `immortalwrt-c8-660[-closed]-initramfs.bin` | 内存启动镜像（进入 Shell 调试，不写入 Flash） |
| `mt7981[-ddr4]-bl2.bin` | MT7981 DDR4 BL2 引导（救砖/还原时配合 FIP 使用） |
| `immortalwrt-c8-660[-closed].manifest` | 固件包清单 |
| `sha256sums` | Release 实际文件名对应的 SHA256 校验和 |

### 环境说明

- CI 运行于 `ubuntu-latest` (GitHub Actions)，脚本针对 Linux (GNU sed/coreutils) 编写
- 本地调试需在 Linux 环境或 WSL 中进行，macOS 的 BSD sed 语法不兼容
- 第三方包可通过环境变量锁定版本，见 `Scripts/Packages.sh` 注释
- `init_build_environment.sh` 默认通过 `.github/init_build_environment.sha256` 校验完整性；`Update Init Build SHA` 工作流会定时跟随上游更新该 pin 文件
- 如需临时强制固定哈希，可设置 `INIT_BUILD_EXPECTED_SHA256` secret 覆盖仓库 pin

## 目录结构

- `.github/workflows/` — CI 工作流
   - `c8-660-open.yml` — 开源构建 (mt76 + mainline 6.x, ImmortalWrt openwrt-25.12 stable)
   - `c8-660-closed.yml` — 闭源构建 (Linux 6.12 + mt_wifi 7.6.7.3 + HNAT/WARP-WED)
- `Scripts/` — 编译自定义脚本（主题、插件、系统设置）
- `Config/` — 设备 Kconfig + 通用包配置 + 变体配置
  - `GENERAL.txt` — 开源构建通用包配置
  - `GENERAL-CLOSED.txt` — 闭源 25.12 通用包配置
  - `NRADIO-C8-660.txt` — 开源构建设备配置
  - `NRADIO-C8-660-CLOSED.txt` — 闭源构建设备配置
  - `OPEN.txt` — 开源构建标识
  - `CLOSED.txt` — 闭源构建 MTK 专有包配置
- `patches/` — 共享设备树、Open/Closed 各自的 filogic.mk 设备定义与 rootfs overlay

### 硬件参考

5G 模组 GPIO 控制、SIM 槽切换、LED 引脚映射等硬件细节见以下源文件：

- `patches/mt7981b-nradio-c8-660.dts` — 设备树（GPIO、LED、PHY、交换机定义）
- `patches/files/usr/share/modem/rm520n.sh` — 5G 模组初始化脚本（simsel、cpe-pwr/ sel0 控制逻辑）
- `patches/files/etc/config/modem` — 默认 SIM 选择配置

## 免责声明

本项目不包含 NRadio 闭源 SDK 组件及 5G 模组固件，仅为开源 OpenWrt/ImmortalWrt 编译自动化配置。刷机风险自担。
