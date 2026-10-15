#!/bin/sh
set -eu

. ./overlay/etc/init.d/00_eth_mac

reject() { if "$@"; then printf 'Unexpected acceptance: %s\n' "$*"; exit 1; fi; }

# Build a synthetic factory OTP dump the size of the rv1106/rv1103 region
# (0x80 bytes): cpu code, the otp_id cell with the ASCII lot code "TK2T09",
# the per-chip serial at 0x17..0x19 and the calibration fuse at 0x1a.
make_otp() {
	file="$1"
	serial_hi="$2"
	serial_lo="$3"
	calibration="$4"
	printf '\122\126\021\003\002\000\376\047\010\000\124\113\062\124\060\071\000\000\000\000\000\000\000' > "$file"
	printf "$(printf '\\%03o\\%03o' "$serial_hi" "$serial_lo")\021$(printf '\\%03o' "$calibration")" >> "$file"
	dd if=/dev/zero of="$file" bs=1 count=100 seek=28 conv=notrunc 2>/dev/null
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# otp_id cell (0x0a..0x19) as dumped from a real board: ASCII lot code "TK2T09"
# followed by the per-chip serial 01 35 11.
make_otp "$work/otp.bin" 1 53 21
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

# A different serial gives a different MAC.
make_otp "$work/otp-other.bin" 2 38 21
OTP_DEVICE="$work/otp-other.bin"
other=$(otp_mac)
[ "$other" != "$first" ] || { printf 'Same MAC for different OTP ids: %s\n' "$first"; exit 1; }

# A byte outside the otp_id cell changes the MAC too, which is what the
# whole-region read buys over hashing the 16-byte cell alone.
make_otp "$work/otp-cal.bin" 1 53 22
OTP_DEVICE="$work/otp-cal.bin"
other=$(otp_mac)
[ "$other" != "$first" ] || { printf 'Calibration fuse outside otp_id ignored: %s\n' "$first"; exit 1; }

# Unfused OTP has no per-board entropy: otp_mac must refuse it.
OTP_DEVICE="$work/otp-zero.bin"
reject otp_mac
OTP_DEVICE="$work/missing.bin"
reject otp_mac
dd if=/dev/zero of="$work/otp-short.bin" bs=1 count=8 2>/dev/null
OTP_DEVICE="$work/otp-short.bin"
reject otp_mac

# A whole production batch whose per-chip serial is unfused: every board has
# the same lot code and nothing else inside the otp_id cell, so hashing that
# cell alone would give one MAC for the entire batch. The calibration fuse
# outside the cell has to be enough to keep the boards apart.
macs="$work/batch-macs"
: > "$macs"
boards=0

calibration=0
while [ "$calibration" -lt 256 ]; do
	make_otp "$work/board.bin" 0 0 "$calibration"
	OTP_DEVICE="$work/board.bin"
	mac=$(otp_mac)
	is_mac "$mac" || { printf 'Lot-only board produced an invalid MAC: %s\n' "$mac"; exit 1; }
	printf '%s\n' "$mac" >> "$macs"
	boards=$((boards + 1))
	calibration=$((calibration + 1))
done
unique=$(sort -u "$macs" | wc -l)
[ "$unique" -eq "$boards" ] || { printf 'Batch of %d lot-only boards produced only %d MACs\n' "$boards" "$unique"; exit 1; }

# Boards from the same lot with fused serials must not collide either.
serial=1
while [ "$serial" -lt 1025 ]; do
	make_otp "$work/board.bin" $((serial / 256)) $((serial % 256)) 21
	OTP_DEVICE="$work/board.bin"
	mac=$(otp_mac)
	is_mac "$mac" || { printf 'Board %d produced an invalid MAC: %s\n' "$serial" "$mac"; exit 1; }
	printf '%s\n' "$mac" >> "$macs"
	boards=$((boards + 1))
	serial=$((serial + 1))
done
unique=$(sort -u "$macs" | wc -l)
[ "$unique" -eq "$boards" ] || { printf 'Batch of %d boards produced only %d MACs\n' "$boards" "$unique"; exit 1; }

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
