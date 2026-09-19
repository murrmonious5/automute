#!/usr/bin/env bash
# AutoMute bench check — READ ONLY.
# Runs no sudo, writes nothing, reboots nothing. Safe to run at any time.
# Paste the output into a Claude session before asking it to change anything.

set -uo pipefail

hr() { printf '\n── %s %s\n' "$1" "$(printf '─%.0s' $(seq $((60 - ${#1}))))"; }
try() { "$@" 2>&1 || echo "  (command failed or unavailable: $*)"; }

echo "AutoMute bench check — $(date -Is)"

hr "Board and OS"
try cat /proc/device-tree/model; echo
try grep PRETTY_NAME /etc/os-release
try uname -srm

hr "Boot config: IR overlay"
CFG=/boot/firmware/config.txt
[ -f "$CFG" ] || CFG=/boot/config.txt
echo "config file: $CFG"
if [ -f "$CFG" ]; then
  if grep -n "ir-tx" "$CFG"; then
    echo "  ^ overlay line(s) found"
  else
    echo "  NO ir-tx overlay line found — see TROUBLESHOOTING.md §1"
  fi
  echo "  (conditional sections present in this file:)"
  grep -n "^\[" "$CFG" | sed 's/^/    /'
else
  echo "  config.txt not found at either path (?)"
fi

hr "lirc device nodes"
if ls -l /dev/lirc* 2>/dev/null; then :; else
  echo "  none — overlay not loaded or not rebooted. TROUBLESHOOTING.md §1"
fi
echo "  current user groups: $(id -nG)"

hr "Kernel modules"
try lsmod | grep -E "pwm_ir_tx|gpio_ir_tx|rc_core|lirc" || echo "  no IR modules loaded"

hr "ir-ctl device features"
if command -v ir-ctl >/dev/null; then
  if [ -e /dev/lirc0 ]; then
    try ir-ctl -d /dev/lirc0 --features
  else
    echo "  skipped, /dev/lirc0 missing"
  fi
else
  echo "  ir-ctl NOT INSTALLED — sudo apt install v4l-utils (ask first)"
fi

hr "ir-keytable"
if command -v ir-keytable >/dev/null; then
  try ir-keytable
else
  echo "  ir-keytable not installed (part of v4l-utils)"
fi

hr "GPIO18 pin function"
if command -v pinctrl >/dev/null; then
  try pinctrl get 18
  echo "  expect an alt/PWM function when the overlay is active,"
  echo "  not plain 'ip' (input) or 'op' (output)."
elif command -v raspi-gpio >/dev/null; then
  try raspi-gpio get 18
else
  echo "  neither pinctrl nor raspi-gpio available"
fi

hr "Kernel log (IR-related)"
if dmesg >/dev/null 2>&1; then
  dmesg | grep -i -E "pwm|lirc|rc_core|ir-tx|rc-core" | tail -30 || echo "  nothing matched"
else
  echo "  dmesg restricted for this user; try: sudo dmesg | grep -i -E 'pwm|lirc|rc'"
fi

hr "Power / thermal"
try vcgencmd get_throttled
echo "  0x0 is healthy; anything else means undervoltage or throttling has occurred"

hr "Available kernel remote keymaps"
if [ -d /lib/udev/rc_keymaps ]; then
  echo "  $(ls /lib/udev/rc_keymaps | wc -l) keymaps in /lib/udev/rc_keymaps/"
  echo "  find your TV:  grep -ril KEY_MUTE /lib/udev/rc_keymaps/"
else
  echo "  /lib/udev/rc_keymaps not present (install v4l-utils)"
fi

hr "Done"
echo "Nothing above was modified. See TROUBLESHOOTING.md for what to do next."
