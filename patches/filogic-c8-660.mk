# NRadio C8-660 (WT9103) MT7981B 512MB SPI-NAND
# Device definition for ImmortalWrt filogic target
# Hardware: MT7981B + MT7531 switch + 2x RTL8221B + MT7976CN WiFi
# SPI-NAND: BLOCKSIZE 128k / PAGESIZE 2048
# Kernel in UBI volume (KERNEL_IN_UBI)
define Device/nradio_wt9103
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := WT9103
  DEVICE_DTS := mt7981b-nradio-c8-660
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES := nradio,wt9103
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware \
	kmod-usb-serial-option kmod-usb-serial-wwan kmod-usb-net-cdc-ether \
	kmod-usb-net-qmi-wwan kmod-usb-wdm kmod-usb-net-cdc-ncm \
	kmod-usb-net-huawei-cdc-ncm kmod-usb3 automount \
	uqmi luci-proto-qmi sms-tool \
	comgt comgt-ncm chat usb-modeswitch \
	kmod-wireguard wireguard-tools luci-proto-wireguard \
	ttyd luci-app-ttyd \
	nlbwmon luci-app-nlbwmon \
	miniupnpd luci-app-upnp \
	socat \
	etherwake luci-app-wol \
	luci-proto-3g \
	tcpdump ethtool \
	irqbalance \
	nano unzip wget-ssl
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 131072k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_wt9103
