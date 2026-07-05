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
| luci-app-partexp | 分区扩容 |
| luci-app-homeproxy | 开源构建的现代代理平台（sing-box 后端，默认安装不预配置节点） |
| luci-app-c8modem | C8 蜂窝与短信工具（含短信接收/发送/转发） |

短信推送能力由 `luci-app-c8modem` 的 `modem/sms` 页面统一管理，内置 PushPlus、Telegram、Server 酱、WxPusher、企业微信和自定义 Webhook 通道；不再预装独立 `luci-app-wechatpush`，避免菜单、服务和配置互相冲突。

## 内核模块

fuse, mtd-rw, nf-nat6, nft-core/fullcone/offload/queue/socket/tproxy,
tun, usb-core, usb-net, usb-net-qmi-wwan-quectel,
usb-storage/extras/uas

## 系统工具

autocore, automount, blkid, cpufreq, curl, htop,
ip-full, lsblk, openssh-keygen/sftp-server, htop 等

## 编译变体

本项目保留两条 active 构建线：开源 mt76 主线，以及闭源 21.02 experimental/legacy 线。闭源 24.10 已归档，仅保留历史参考，不再作为 active GitHub Actions 工作流维护。

| | 开源构建 (Open) | 闭源构建 (Closed) |
|--|--|--|
| **工作流** | `C8-660 Open (mt76)` | `C8-660 Closed 21.02 (mt_wifi 5.4)` |
| **源码** | immortalwrt/immortalwrt (master) | hanwckf/immortalwrt-mt798x (openwrt-21.02) |
| **内核** | 6.x (mainline) | 5.4 (SDK) |
| **WiFi 驱动** | mt76 (开源) | mt_wifi (MediaTek 专有 v7.6.6.1) |
| **硬件加速** | WED (mt76) | WARP/HNAT 暂停启用 |
| **设备支持** | 通过 patches/ 注入 | 已内置在源码中 |
| **默认 IP** | 192.168.1.1 | 192.168.1.1 |
| **默认主题** | Aurora | Aurora |
| **固件前缀** | `immortalwrt-c8-660` | `immortalwrt-c8-660-closed` |

### 开源构建特点

- 基于 mainline 内核，长期维护性好
- mt76 开源驱动，社区支持
- Aurora 主题，现代化 UI
- 首次刷入需通过 U-Boot TFTP 模式
- WiFi 校准数据依赖 factory 分区 EEPROM

### 闭源构建特点 (V12 克隆)

- 基于 MTK SDK 5.4 内核，与原厂固件兼容性更好
- mt_wifi 专有驱动 (v7.6.6.1)，支持 MTK 完整功能集
- 克隆 V12 系统配置，包含所有 V12 特有组件
- 默认 IP 192.168.1.1，Aurora 主题
- 已内置 C8-660 设备支持，无需额外 DTS 注入
- 当前作为 experimental/legacy 构建维护；24.10 闭源线因未知面更大、设备支持需额外注入，已移动到 `archive/closed-24.10/`

## 编译信息（开源构建）

| 项目 | 值 |
|------|-----|
| 源码 | immortalwrt/immortalwrt |
| 分支 | master |
| 内核 | 6.x (mainline) |
| WiFi 驱动 | mt76 (开源) |
| 镜像格式 | UBI + FIT |
| 触发方式 | 手动 (workflow_dispatch) |

## 已知风险与救砖

### 开源构建

本项目编译产物为 mainline 内核 (6.x)，与设备原厂 SDK 内核 (5.4) 引导链不兼容。本项目为**单系统固件**，首次刷入需通过 **U-Boot TFTP 恢复模式**，将整个 NAND 替换为 OpenWrt 单系统，**不可**直接在原厂 Web 升级，也不支持双系统切换。

### 闭源构建 (V12 克隆)

闭源构建基于 MTK SDK 5.4 内核，目标是尽量贴近 V12/MTK 专有驱动基线。默认 IP 为 192.168.1.1，使用 Aurora 主题。首次从原厂 NROS 刷入仍建议通过 U-Boot TFTP 模式。闭源构建固件文件名包含 `closed` 前缀，与开源版本互不通用。

刷机前**必须备份 FIP / bl2 分区**：

```
mtd read /tmp/bl2_backup.bin bl2
mtd read /tmp/fip_backup.bin fip
```

WiFi 校准数据依赖 factory 分区 EEPROM，mt76 驱动偏移可能与原厂不同，若 5G 信号弱或无连接，需在 DTS 中调整 `mediatek,mtd-eeprom` 偏移。

5G 模组（RM520N-CN）默认即插即用（QMI 模式），无需手动切换。

救砖资源：NRadio 官方技术支持 / 官方救援 TFTP 服务器。

## mainline 集成说明

ImmortalWrt master / OpenWrt mainline 当前**未集成 NRadio C8-660 设备支持**。本项目通过 `Scripts/Patches.sh` 在编译时自动注入以下补丁：

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

## 闭源构建专有包 (V12 克隆)

闭源构建克隆了 V12 系统配置，包含以下 MTK 专有组件和 V12 特有包：

### MTK 专有组件

| 包名 | 说明 |
|------|------|
| kmod-mt_wifi | MediaTek 专有 WiFi 驱动 (v7.6.6.1) |
| kmod-conninfra | 连接基础设施模块 |
| kmod-warp | WiFi 硬件加速引擎 (WARP v2，当前闭源 21.02 基线暂停启用) |
| kmod-mediatek_hnat | MediaTek 硬件 NAT（当前闭源 21.02 基线暂停启用） |
| wifi-dats | WiFi DAT 校准数据文件 |
| mtwifi-cfg | WiFi 配置管理工具 |
| luci-app-mtwifi-cfg | LuCI WiFi 配置界面 |
| luci-app-turboacc-mtk | MTK 网络加速 (HNAT/WARP，当前闭源 21.02 基线暂停启用) |
| luci-app-eqos-mtk | MTK QoS 流量控制 |
| mtk-smp | MediaTek SMP 多核优化 |
| mtkhqos_util | MediaTek HQoS 工具 |
| mii_mgr | MediaTek MII 管理器 |
| regs | MediaTek 寄存器工具 |

### V12 特有插件

| 包名 | 说明 |
|------|------|
| luci-app-cpu-status | CPU 状态监控 |
| luci-app-ledtrig-rssi | RSSI LED 触发器 |
| luci-app-ledtrig-switch | 开关 LED 触发器 |
| luci-app-ledtrig-usbport | USB 端口 LED 触发器 |
| luci-app-ser2net | 串口转网络 |
| luci-app-socat | 多功能网络工具 |
| luci-app-sms-tool | 短信工具 |
| luci-app-zmodem | ZModem 传输 |
| luci-app-log | 系统日志 |
| autocore-arm | 自动核心工具 |
| mhz | CPU 频率检测 |
| sendat | AT 命令工具 |
| sms-tool | 短信收发工具 |

### V12 网络加速

| 包名 | 说明 |
|------|------|
| kmod-shortcut-fe | Shortcut Forwarding Engine |
| kmod-shortcut-fe-cm | SFE Connection Manager |
| kmod-oaf | Open Application Firewall |
| kmod-pf-ring | PF_RING 高性能抓包 |

## 高级特性

本项目在标准 ImmortalWrt 编译流程基础上，增加了以下优化：

| 特性 | 说明 | 配置位置 |
|------|------|----------|
| WED 硬件加速 | MT7981 内置 WiFi→Ethernet 硬件 offload，降低 CPU 占用并提升 5G CPE 转发吞吐 | `Scripts/Settings.sh` |
| 硬件流卸载 | 启用 MediaTek 硬件 flow offloading，优先服务 5G CPE 吞吐场景 | `Scripts/Settings.sh` |
| Packet Steering | 启用 RPS 多核软中断分摊，降低单核瓶颈 | `Scripts/Settings.sh` |
| 网络栈调优 | TCP/UDP buffer 扩大 + NAPI 轮询参数优化 | `Scripts/Settings.sh` |
| C8 短信转发 | 内置多通道推送、主备通道、日志、测试按钮和 `sms_tool` 超时保护 | `patches/files/usr/bin/c8-sms-forward`, `patches/files/www/luci-static/resources/view/c8modem/` |
| 第三方包锁定 | 通过 `PKG_LOCK_<name>_COMMIT` 环境变量锁定包版本 | `Scripts/Packages.sh` |
| sing-box 版本锁定 | 通过 `.github/proxy-locks.env` 自动刷新并在构建时回填 `sing-box` release | `.github/workflows/update-proxy-locks.yml`, `Scripts/ApplyProxyLocks.sh` |
| SHA256 脚本校验 | `init_build_environment.sh` 使用仓库 pin 文件校验，并由定时工作流跟随上游更新 | `.github/init_build_environment.sha256`, `.github/workflows/update-init-build-sha.yml` |
| 旧设备兼容 | `SUPPORTED_DEVICES nradio,wt9103` 支持旧 DTS 名称升级 | `patches/filogic-c8-660.mk` |
| CCache 加速 | 编译缓存自动持久化，增量编译时间 -50% | `.github/workflows` |
| 自定义扩展 | `Scripts/PRIVATE.sh` + `Config/PRIVATE.txt` 可选私有配置（gitignored） | `Scripts/`, `Config/` |

### 环境变量参考

| 变量 | 用途 | 示例 |
|------|------|------|
| `PKG_LOCK_aurora_COMMIT` | 锁定 luci-theme-aurora 版本 | `abc123def` |
| `PKG_LOCK_partexp_COMMIT` | 锁定 luci-app-partexp 版本 | `deadbeef` |
| `PKG_LOCK_homeproxy_COMMIT` | 锁定 HomeProxy 版本（由 `.github/proxy-locks.env` 自动刷新，当前跟随 `master`） | `e8b8ebc...` |
| `SING_BOX_VERSION` | sing-box 稳定版版本号（由 `.github/proxy-locks.env` 自动刷新） | `1.13.14` |
| `SING_BOX_HASH` | sing-box 稳定版 tarball SHA256（由 `.github/proxy-locks.env` 自动刷新） | `d18294...` |
| `INIT_BUILD_EXPECTED_SHA256` | 可选覆盖仓库 pin 文件，用于临时固定构建环境脚本哈希 | `sha256sum` 输出 |
| `WRT_WORD` (secret) | WiFi 密码（空=开放） | `MyPassword` |
| `WRT_PW` (secret) | root 登录密码，必填；为空时 CI 会拒绝构建 | `MyPassword` |

手动验证构建时也可使用 workflow 的 `wrt_pw` 输入临时覆盖 root 密码；正式构建建议使用 `WRT_PW` secret。

## 使用流程

1. GitHub Actions 手动触发对应工作流：
   - **开源构建**: `C8-660 Open (mt76)`（使用 mt76 开源驱动）
   - **闭源构建**: `C8-660 Closed 21.02 (mt_wifi 5.4)`（experimental/legacy，使用 mt_wifi 专有驱动）
2. 下载产物 `factory.bin`（首次刷入）或 `sysupgrade.bin`（同主版本升级）
3. U-Boot TFTP 模式下刷入 `factory.bin`（**首次刷机会替换整个 NAND，包括原厂 NROS**）
   - 按住 Reset 按钮上电，设备进入 TFTP 恢复模式
   - 通过网线连接电脑，设置 IP 为 `192.168.1.x` 段
   - 使用 TFTP 工具上传 `factory.bin`
4. 启动后浏览器访问 192.168.1.1

### 产物说明

| 文件 | 用途 |
|------|------|
| `factory.bin` | 从原厂 NROS 首次刷入（U-Boot TFTP） |
| `sysupgrade.bin` | 同版本 OpenWrt 升级（LuCI → 系统 → 备份/升级） |
| `initramfs.bin` | 内存启动镜像（进入 Shell 调试，不写入 Flash） |
| `mt7981-bl2.bin` | BL2 引导（救砖/还原时配合 FIP 使用） |
| `sha256sums` | 所有镜像的 SHA256 校验和 |

### 环境说明

- CI 运行于 `ubuntu-latest` (GitHub Actions)，脚本针对 Linux (GNU sed/coreutils) 编写
- 本地调试需在 Linux 环境或 WSL 中进行，macOS 的 BSD sed 语法不兼容
- 第三方包可通过环境变量锁定版本，见 `Scripts/Packages.sh` 注释
- `init_build_environment.sh` 默认通过 `.github/init_build_environment.sha256` 校验完整性；`Update Init Build SHA` 工作流会定时跟随上游更新该 pin 文件
- 如需临时强制固定哈希，可设置 `INIT_BUILD_EXPECTED_SHA256` secret 覆盖仓库 pin

## 目录结构

- `.github/workflows/` — CI 工作流
   - `c8-660-open.yml` — 开源构建 (mt76 + mainline 6.x, ImmortalWrt master)
   - `c8-660-closed-21.02.yml` — 闭源构建 (mt_wifi + SDK 5.4, hanwckf/immortalwrt-mt798x)
- `archive/closed-24.10/` — 已归档的闭源 24.10 实验线，仅保留参考，不作为 active workflow
- `Scripts/` — 编译自定义脚本（主题、插件、系统设置）
- `Config/` — 设备 Kconfig + 通用包配置 + 变体配置
  - `GENERAL.txt` — 开源构建通用包配置
  - `GENERAL-CLOSED.txt` — 闭源 21.02 通用包配置
  - `NRADIO-C8-660.txt` — 开源构建设备配置
  - `NRADIO-C8-660-CLOSED.txt` — 闭源构建设备配置
  - `OPEN.txt` — 开源构建标识
  - `CLOSED.txt` — 闭源构建 MTK 专有包配置
- `patches/` — 开源构建设备树 (DTS) + filogic.mk 设备定义

### 硬件参考

5G 模组 GPIO 控制、SIM 槽切换、LED 引脚映射等硬件细节见以下源文件：

- `patches/mt7981b-nradio-c8-660.dts` — 设备树（GPIO、LED、PHY、交换机定义）
- `patches/files/usr/share/modem/rm520n.sh` — 5G 模组初始化脚本（simsel、cpe-pwr/ sel0 控制逻辑）
- `patches/files/etc/config/modem` — 默认 SIM 选择配置

## 免责声明

本项目不包含 NRadio 闭源 SDK 组件及 5G 模组固件，仅为开源 OpenWrt/ImmortalWrt 编译自动化配置。刷机风险自担。
