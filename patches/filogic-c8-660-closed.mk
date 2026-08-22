# NRadio C8-660 (WT9103) MT7981B 512MB SPI-NAND
# Closed mt_wifi 7.6.7.3 + HNAT + WARP/WED image definition
define Device/nradio_wt9103
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := WT9103
  DEVICE_DTS := mt7981b-nradio-c8-660
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES := nradio,wt9103
  DEVICE_PACKAGES := kmod-mt_wifi kmod-conninfra kmod-mediatek_hnat \
	kmod-warp hnat-detect mtwifi-cfg-ucode luci-app-mtwifi-cfg \
	luci-i18n-mtwifi-cfg-zh-cn luci-app-turboacc-mtk \
	luci-i18n-turboacc-mtk-zh-cn \
	kmod-usb-serial-option kmod-usb-serial-wwan kmod-usb-net-cdc-ether \
	kmod-usb-net-qmi-wwan kmod-usb-wdm kmod-usb-net-cdc-ncm \
	kmod-usb-net-huawei-cdc-ncm kmod-usb3 automount \
	uqmi luci-proto-qmi sms-tool \
	comgt comgt-ncm chat usb-modeswitch \
	ttyd luci-app-ttyd \
	miniupnpd-nftables luci-app-upnp \
	zerotier luci-app-zerotier \
	etherwake luci-app-wol \
	luci-proto-3g ethtool irqbalance adb nano unzip wget-ssl
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
