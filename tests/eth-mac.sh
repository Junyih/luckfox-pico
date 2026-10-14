#!/bin/sh
set -eu

. ./overlay/etc/init.d/00_eth_mac

reject() { if "$@"; then printf 'Unexpected acceptance: %s\n' "$*"; exit 1; fi; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# otp_id cell (0x0a..0x19) as dumped from a real board: ASCII lot code "TK2T09"
# followed by the per-chip serial 01 35 11.
printf '\122\126\021\003\002\000\376\047\010\000\124\113\062\124\060\071\000\000\000\000\000\000\000\001\065\021\025\040' > "$work/otp.bin"
dd if=/dev/zero of="$work/otp-zero.bin" bs=1 count=64 2>/dev/null

OTP_DEVICE="$work/otp.bin"
MAC_FILE="$work/eth-mac"

reject is_mac garbage
reject is_mac '02:2D:FD:36:A6:E5'
reject is_mac '02:2d:fd:36:a6'
is_mac '02:2d:fd:36:a6:e5'

first=$(otp_mac)
second=$(otp_mac)
[ "$first" = "$second" ] || { printf 'OTP MAC is not deterministic: %s vs %s\n' "$first" "$second"; exit 1; }
is_mac "$first"

# The whole cell is hashed, so a different serial gives a different MAC.
printf '\122\126\021\003\002\000\376\047\010\000\124\113\062\124\060\071\000\000\000\000\000\000\000\002\046\042\025\040' > "$work/otp-other.bin"
OTP_DEVICE="$work/otp-other.bin"
other=$(otp_mac)
[ "$other" != "$first" ] || { printf 'Same MAC for different OTP ids: %s\n' "$first"; exit 1; }

# Unfused OTP has no per-board entropy: otp_mac must refuse it.
OTP_DEVICE="$work/otp-zero.bin"
reject otp_mac
OTP_DEVICE="$work/missing.bin"
reject otp_mac

# Random fallback is valid and differs between calls.
one=$(random_mac)
two=$(random_mac)
is_mac "$one"
is_mac "$two"
[ "$one" != "$two" ] || { printf 'random_mac repeated %s\n' "$one"; exit 1; }

store_mac "$one"
[ "$(cat "$MAC_FILE")" = "$one" ] || { printf 'MAC was not stored\n'; exit 1; }
store_mac "$one"
[ "$(cat "$MAC_FILE")" = "$one" ] || { printf 'MAC was lost on repeat store\n'; exit 1; }

mkdir "$work/readonly"
chmod 555 "$work/readonly"
MAC_FILE="$work/readonly/eth-mac"
reject store_mac "$one"
reject test -e "$work/readonly/eth-mac.tmp"
