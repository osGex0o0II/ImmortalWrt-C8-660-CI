define Device/nradio_c8-660
  DEVICE_VENDOR := NRadio
  DEVICE_MODEL := C8-660
  DEVICE_DTS := mt7981b-nradio-c8-660
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware \
	kmod-usb-serial-option kmod-usb-net-cdc-ether kmod-usb-net-qmi-wwan \
	kmod-usb3 automount
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 131072k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += nradio_c8-660
