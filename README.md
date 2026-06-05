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
| homeproxy | 科学上网代理（预置 Loyalsoldier/surge-rules） |
| luci-app-mosdns | DNS 分流 |
| luci-app-diskman | 磁盘管理 |
| luci-app-partexp | 分区扩容 |
| luci-app-tailscale | Tailscale VPN |
| sing-box | 代理内核（版本自动更新） |

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
