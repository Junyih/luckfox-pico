#!/bin/bash
# enable-zerotier-vpn.sh - run on a Luckfox Pico board (Alpine) to turn on:
#   1. ZeroTier daemon at boot
#   2. IPv4 forwarding
#   3. Masquerade for forwarded traffic leaving eth0
#
# Run as root on the device. Idempotent: safe to run more than once.
# This script is intentionally not part of the firmware build.

set -e

if [ "$(id -u)" -ne 0 ]; then
	echo "must run as root" >&2
	exit 1
fi

IPT="$(command -v iptables-legacy || command -v iptables)"
if [ -z "$IPT" ]; then
	echo "no iptables binary found (apk add iptables iptables-legacy)" >&2
	exit 1
fi

# 1. ZeroTier at boot
if [ -x /etc/init.d/zerotier-one ]; then
	rc-update add zerotier-one default
else
	echo "warning: /etc/init.d/zerotier-one missing, skipping" >&2
fi

# 2. IPv4 forwarding
grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null || \
	echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
rc-update add sysctl boot
sysctl -w net.ipv4.ip_forward=1

# 3. Masquerade on eth0
cat > /etc/init.d/90_nat <<'EOF'
#!/sbin/openrc-run

description = "NAT masquerade for forwarded traffic leaving eth0"

depend() {
	need net
	after netmount
}

start() {
	ipt="$(command -v iptables-legacy || command -v iptables)"
	"$ipt" -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
		"$ipt" -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}
EOF
chmod 755 /etc/init.d/90_nat
rc-update add 90_nat default

# Apply now so a reboot is not required
"$IPT" -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
	"$IPT" -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo "enabled: zerotier-one, sysctl (net.ipv4.ip_forward), 90_nat"
echo "runlevels:"
rc-update show default 2>/dev/null | sed 's/^/  /'
