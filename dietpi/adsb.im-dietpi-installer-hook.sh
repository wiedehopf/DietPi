#!/bin/bash


# 58 tailscale
# 201 zerotier
# 162 docker
# 134 docker-compose-plugin

/boot/dietpi/dietpi-software install 58 201 162 134
cat /boot/dietpi/.installed

# disable and mask tailscale / zerotier
systemctl disable zerotier-one.service tailscaled.service
systemctl mask zerotier-one tailscaled

# Disable telemetry for tailscale but only if it's not already there
if ! grep -q -- "^FLAGS=\"--no-logs-no-support" /etc/default/tailscaled ; then
	sed -i 's/FLAGS=\"/FLAGS=\"--no-logs-no-support /' /etc/default/tailscaled
fi

ADD_PKGS=()
# on pi4/5, on boot dietpi-software will do stuff for the rpi-eerpom which needs extra packages
# to avoid installing them on first bootk, install them here during build
[[ $G_HW_MODEL == [45] ]] && ADD_PKGS=(binutils binutils-aarch64-linux-gnu binutils-common libbinutils libctf-nobfd0 libctf0 libgprofng0 libjansson4 libpci3 pci.ids pciutils python3-pycryptodome rpi-eeprom)
# install various adsb.im dependencies
apt-get install -y --no-install-recommends acpid jq zstd netcat-openbsd python3 python3-flask python3-requests git librtlsdr0 rtl-sdr hostapd isc-dhcp-server less avahi-utils "${ADD_PKGS[@]}"

# configure the power button to perform a clean shutdown
cat > /etc/acpi/events/power_button <<EOF
event=button/power PBTN 00000080 00000000
action=/usr/sbin/poweroff
EOF

# more stuff for the adsb.im image:
BLOCKED_MODULES=("rtl2832_sdr")
BLOCKED_MODULES+=("dvb_usb_rtl2832u")
BLOCKED_MODULES+=("dvb_usb_rtl28xxu")
BLOCKED_MODULES+=("dvb_usb_v2")
BLOCKED_MODULES+=("r820t")
BLOCKED_MODULES+=("rtl2830")
BLOCKED_MODULES+=("rtl2832")
BLOCKED_MODULES+=("rtl2838")
BLOCKED_MODULES+=("dvb_core")
echo -n "Getting the latest UDEV rules... "
mkdir -p /etc/udev/rules.d /etc/udev/hwdb.d
# First install the UDEV rules for RTL-SDR dongles
curl -sL -o /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules
curl -sL -o /etc/udev/rules.d/dump978-fa.rules https://raw.githubusercontent.com/flightaware/dump978/master/debian/dump978-fa.udev
# Now install the UDEV rules for SDRPlay devices
curl -sL -o /etc/udev/rules.d/66-mirics.rules https://raw.githubusercontent.com/sdr-enthusiasts/install-libsdrplay/main/66-mirics.rules
curl -sL -o /etc/udev/hwdb.d/20-sdrplay.hwdb https://raw.githubusercontent.com/sdr-enthusiasts/install-libsdrplay/main/20-sdrplay.hwdb
# Next, exclude the drivers so the dongles stay accessible
echo -n "blacklisting kernel modules "
for module in "${BLOCKED_MODULES[@]}"
do
	echo blacklist "$module" >>/etc/modprobe.d/exclusions-rtl2832.conf
	echo install "$module" /bin/false >>/etc/modprobe.d/exclusions-rtl2832.conf
done

# remove pycache, this isn't cleaned by the dietpi-installer cleanups and will save a couple MB
find /usr | grep -E "/__pycache__$" | xargs rm -rf || true
