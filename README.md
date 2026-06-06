# ImmortalWrt-NRadio-C8-660

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
| LED | Power, 5G, 4G, WiFi |

## 默认设置

| 项目 | 值 |
|------|-----|
| 登录地址 | 192.168.1.1 |
| 登录密码 | password |
| WiFi SSID | NRadio-WiFi |
| WiFi 密码 | password |
| WiFi 加密 | WPA2-PSK (CCMP) |
| 主题 | Aurora |
| 语言 | 简体中文 |

## 预装插件（第三方）

| 插件 | 说明 |
|------|------|
| luci-theme-aurora | Aurora 主题 |
| luci-app-aurora-config | Aurora 主题配置 |
| luci-app-partexp | 分区扩容 |

## 内核模块

bonding, fuse, mtd-rw, nf-nat6, nft-core/fullcone/offload/queue/socket/tproxy,
tun, veth, wireguard, usb-core, usb-net, usb-net-qmi-wwan-quectel,
usb-storage/extras/uas

## 系统工具

autocore, automount, blkid, cfdisk, cpufreq, curl, htop, iperf3,
ip-full, lsblk, openssh-keygen/sftp-server, wireguard-tools 等

## 编译信息

| 项目 | 值 |
|------|-----|
| 源码 | immortalwrt/immortalwrt |
| 分支 | master |
| 内核 | 6.x (mainline) |
| WiFi 驱动 | mt76 (开源) |
| 镜像格式 | UBI + FIT |
| 触发方式 | 手动 (workflow_dispatch) |

## 已知风险与救砖

本项目编译产物为 mainline 内核 (6.x)，与设备原厂 SDK 内核 (5.4) 引导链不兼容。首次刷入需通过 **U-Boot TFTP 恢复模式** 或 **官方双系统切换**，不可直接在原厂 Web 升级。

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
- `patches/01_leds.snippet` — 注入 5G/WiFi/电源 LED 行为
- `patches/11_fix_wifi_mac.snippet` — 注入从 `bdinfo` 分区读取 MAC 并修复 WiFi MAC

## 社区相关项目

- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) — SDK 5.4 + nmbm 内核，包含 C8-660（512M）原始 DTS 与 mt7981.mk
- [openwrt/openwrt PR #17093](https://github.com/openwrt/openwrt/pull/17093) — 官方 C8-668GL 支持（eMMC 板，仅供参考）
- [newton-miku/luci-app-cellscan](https://github.com/newton-miku/luci-app-cellscan) — C8-660/668 专用基站扫描插件（已预装）
- [tltv1212/Nradio-Firmware-Selector](https://github.com/tltv1212/Nradio-Firmware-Selector) — NRadio 鲲鹏 C8 系列固件下载列表
- [duhaoyang520-collab/bl-mt7981](https://github.com/duhaoyang520-collab/bl-mt7981) — ATF / U-Boot 编译工具（救砖参考）

## 使用流程

1. GitHub Actions 触发 `ImmortalWrt NRadio C8-660` 工作流
2. 下载产物 `factory.bin`（首次刷入）或 `sysupgrade.itb`（同主版本升级）
3. U-Boot TFTP 模式下刷入 `factory.bin`
4. 启动后浏览器访问 192.168.1.1

## 目录结构

- `.github/workflows/` — CI 工作流（单文件自包含）
- `Scripts/` — 编译自定义脚本（主题、插件、系统设置）
- `Config/` — 设备 Kconfig + 通用包配置
- `patches/` — 设备树 (DTS) + filogic.mk 设备定义

## 免责声明

本项目不包含 NRadio 闭源 SDK 组件及 5G 模组固件，仅为开源 OpenWrt/ImmortalWrt 编译自动化配置。刷机风险自担。
