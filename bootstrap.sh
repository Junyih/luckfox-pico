#!/bin/sh
set -e

# Install base
apk update
apk add openrc
rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot
rc-update add networking default
rc-update add local default

# Install TTY
apk add agetty

# Setting up shell
apk add shadow
apk add bash bash-completion
chsh -s /bin/bash
echo -e "luckfox\nluckfox" | passwd
apk del -r shadow

# Install SSH
apk add openssh
rc-update add sshd default

# Extra stuff
apk add mtd-utils-ubi
apk add bottom
apk add wget
apk add nano
apk add mc
apk add chrony
apk add usbutils
apk add dialog tzdata
apk add iproute2 lsblk findmnt mount umount cifs-utils nfs-utils libgpiod openssh-keygen chrony-openrc busybox-openrc

# Netfilter userspace (iptables-legacy needs both packages on Alpine >= 3.22)
apk add iptables iptables-legacy

# NTP time sync
rc-update add chronyd default

# ============================================================
# Install ZeroTier One from Alpine v3.17 ARMv7 packages
# Target: Luckfox Pico Plus / Alpine 3.24 / armv7
# ============================================================

set -e

echo "=== ZeroTier: checking architecture ==="
ARCH="$(apk --print-arch)"
echo "Alpine architecture: $ARCH"

if [ "$ARCH" != "armv7" ]; then
    echo "ERROR: Expected armv7, got $ARCH"
    exit 1
fi

ZT_DIR="/tmp/zerotier-apks"
ZT_BASE="https://dl-cdn.alpinelinux.org/alpine/v3.17/community/armv7"

mkdir -p "$ZT_DIR"

echo "=== ZeroTier: downloading APK packages ==="

wget -O "$ZT_DIR/zerotier-one.apk" \
    "$ZT_BASE/zerotier-one-1.10.2-r0.apk"

wget -O "$ZT_DIR/zerotier-one-openrc.apk" \
    "$ZT_BASE/zerotier-one-openrc-1.10.2-r0.apk"

test -s "$ZT_DIR/zerotier-one.apk"
test -s "$ZT_DIR/zerotier-one-openrc.apk"

echo "=== ZeroTier: inspecting package metadata ==="

apk info --allow-untrusted --contents \
    "$ZT_DIR/zerotier-one.apk" || true

echo "=== ZeroTier: installing packages ==="

apk add --allow-untrusted \
    "$ZT_DIR/zerotier-one.apk" \
    "$ZT_DIR/zerotier-one-openrc.apk"

echo "=== ZeroTier: verifying installation ==="

if ! command -v zerotier-one >/dev/null 2>&1; then
    echo "ERROR: zerotier-one binary not found"
    exit 1
fi

if ! command -v zerotier-cli >/dev/null 2>&1; then
    echo "ERROR: zerotier-cli binary not found"
    exit 1
fi

if [ ! -x /etc/init.d/zerotier-one ]; then
    echo "ERROR: OpenRC service /etc/init.d/zerotier-one not found"
    echo "Inspect the installed APK contents and service filename."
    exit 1
fi

echo "ZeroTier daemon: $(command -v zerotier-one)"
echo "ZeroTier CLI:    $(command -v zerotier-cli)"
echo "OpenRC service:  /etc/init.d/zerotier-one"

echo "=== ZeroTier: installed package information ==="
apk info | grep -i zerotier || true

# ZeroTier is left out of the runlevels on purpose: the init script is
# installed, but autostart is enabled per device with enable-vpn.sh.

echo "=== ZeroTier installation checks passed ==="

rm -rf "$ZT_DIR"





# Clear apk cache
rm -rf /var/cache/apk/*

# Packaging rootfs
for d in bin etc lib sbin usr var; do cp -a "$d" /extrootfs/; done
for dir in dev proc root run sys var oem userdata; do mkdir -p /extrootfs/${dir}; done
mkdir -p /extrootfs/var/empty
chown root:root /extrootfs/var/empty
chmod 755 /extrootfs/var/empty
mkdir -p /extrootfs/tmp
chmod 1777 /extrootfs/tmp
