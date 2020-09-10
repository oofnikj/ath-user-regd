# ath-user-regd

Use DKMS to patch in-tree Atheros wireless driver with OpenWrt `ATH_USR_REGD` for 802.11ac in AP mode

The [OpenWrt](https://openwrt.org/) project provides some patches to the Linux kernel drivers for Atheros wireless chipsets that enable us to broadcast on 5GHz, something that is usually not possible due to regulatory domain limitations that are hard-coded into most desktop and laptop WiFi modules.

DISCLAIMER
---
**I accept no responsibility regarding the legality of using this code. The onus is on YOU to determine on which radio channels you may or may not broadcast radio frequency radiation in your country or region.**

---

## Installation

First you must download the Linux kernel source and extract it into `./src/linux`. A helper target is available that tries to do this for you:
```sh
$ make download-src
```

Next, install the DKMS module so that the patched module source gets re-compiled on each kernel update:
```sh
$ sudo make dkms-install
```

To completely remove the patched module from your system and restore the original:
```sh
sudo make dkms-remove
```

If you are using a rolling release distribution, from time to time you may need to remove and re-install the DKMS script for the latest kernel.