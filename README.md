# luckfox-pico

Linux systems for LuckFox Pico series, including
Pico Mini b, Pico Plus and Pico Pro Max (all models with SPI flash).

Currently only [Alpine Linux](https://alpinelinux.org/) is available.

## Downloads

Check out
[Github Release](https://github.com/Junyih/luckfox-pico/releases)
for latest Alpine Linux images.

Only verified on pico-plus

## Flashing

See
[the official docs](https://wiki.luckfox.com/Luckfox-Pico-Plus-Mini/Flash-image/)
for instructions on flashing `update.img` to your Pico board.

For example, to flash a Pico Plus board,
connect the board to your computer while pressing _BOOT_ key, then execute

Linux:
```bash
sudo ./upgrade_tool uf pico-plus-alpine.img
```

Windows:
```bash
./upgrade_tool.exe uf pico-plus-alpine.img
```


## Setting Up

The default username/password is `root:luckfox`.

UART serial debug port is enabled,
and `sshd` server is installed and enabled as well.
Eth0 for pico-plus and pico-pro-max is enabled with DHCP

To connect to it via ethernet, simply do
```bash
ssh root@<ip_of_pico_board>
```

The USB gadget (RNDIS) interface `usb0` has static IP `172.32.0.2/24`.


## Customization

Just fork this repo and trigger Github Actions after you made your changes!

For example,
* To add software packages, edit `bootstrap.sh`.
* To change files in the system image, edit `overlay/`.
