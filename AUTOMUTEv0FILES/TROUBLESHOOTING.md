# Troubleshooting

Work top to bottom. The point is to separate "the code is wrong" from "nothing
is transmitting", because they look identical from the couch.

Run `bash check_ir.sh` first — it answers most of §1–§3 in one shot.

---

## 1. `/dev/lirc0` doesn't exist

The overlay isn't loaded.

```bash
grep -n "ir-tx" /boot/firmware/config.txt      # is the line there?
dmesg | grep -i -E "pwm|lirc|rc_core|ir-tx"    # did it fail to probe?
lsmod | grep -E "pwm_ir_tx|rc_core"
```

Causes, in order of likelihood:

- **Line added but not rebooted.** Device tree overlays only apply at boot.
- **Typo in the overlay line.** It's `dtoverlay=pwm-ir-tx,gpio_pin=18` —
  comma between overlay and parameter, no spaces.
- **Edited the wrong file.** On Raspberry Pi OS Bookworm it's
  `/boot/firmware/config.txt`. `/boot/config.txt` is the old path and may exist
  as a stale leftover that nothing reads.
- **Line landed under a `[cm4]`/`[pi4]` conditional section** near the bottom of
  the file and is being skipped. Put it under `[all]`.
- **Firmware too old for `pwm-ir-tx` on Pi 5.** `sudo rpi-eeprom-update` and
  `sudo apt full-upgrade`. Ask before running either.

## 2. `/dev/lirc0` exists but `ir-ctl` errors

```bash
ir-ctl -d /dev/lirc0 --features
```

- **`Permission denied`** — the lirc node is usually `root:video` mode 0660.
  Check with `ls -l /dev/lirc0` and `groups`. Either add the user to the right
  group (`sudo usermod -aG video $USER`, then log out and back in) or prefix
  with `sudo` for now. Note which you did in `HARDWARE.md`.
- **Features list says receive-only / no send** — wrong overlay. `pwm-ir-tx` is
  transmit-only and that's correct for us; if it reports receive, something else
  claimed the device.
- **`invalid scancode`** — wrong width for the protocol. See the table in
  `IR_CODES.md`. This is the single most common mistake.

## 3. `ir-ctl` succeeds, TV does nothing

Check the LED is actually emitting before chasing codes.

**Phone camera test:** point a phone camera at the KY-005 LED and send in a
loop:

```bash
for i in $(seq 20); do ir-ctl -d /dev/lirc0 -S nec:0x0409; sleep 0.2; done
```

You should see a faint purple/white flicker. (iPhone rear cameras filter IR
fairly hard — use the front camera, or any cheap Android.)

### No flicker

Transmission isn't reaching the LED.

```bash
pinctrl get 18        # Pi 5; expect an alt function (PWM), not "ip" or "op"
```

- Pin shows as plain input/output → overlay isn't controlling GPIO18. Back to §1.
- LED wired backwards. `S` goes to the resistor/GPIO side, `-` to ground. The
  longer leg is the anode if you're looking at a bare LED.
- Cold solder joint or a breadboard rail that isn't connected where you think.
  Swap in a known-good LED if you have one.
- Resistor value way too high (a 10 kΩ grabbed by mistake will produce nothing
  visible).

### Flicker, but the TV ignores it

Now it's a code or aim problem.

- **Aim and distance.** Bare LED at 3.3 V is ~1 m, line of sight, and it's
  directional. Get closer and aim at the TV's IR window, usually bottom-centre
  or bottom-right of the bezel.
- **Wrong protocol for the brand.** Try the alternates in `IR_CODES.md` before
  assuming hardware.
- **Sony not repeated.** SIRC requires the frame 3× with ~45 ms between. One
  frame gets discarded.
- **Mute is a toggle.** If you sent it an even number of times you're back where
  you started. Watch the TV's on-screen mute indicator, not the sound.
- **TV's IR receiver is disabled.** Some sets have an "IR blaster / remote lock"
  setting, and a soundbar or HDMI-CEC setup can swallow volume commands.

## 4. It works, then stops

- Overheating LED from no/low resistor — check it isn't warm.
- Another process holding `/dev/lirc0`. `sudo fuser -v /dev/lirc0`.
- Power supply sag if other things were plugged in. `vcgencmd get_throttled`
  (non-zero = undervoltage or thermal events).

## 5. `mute.py` is slow

Budget is <200 ms. Each `ir-ctl` spawn is ~10–20 ms, the frame itself ~70 ms for
NEC. If it's way over, `time` the `ir-ctl` call directly to see whether the
overhead is Python startup or the send.

---

## What not to do

- Don't reimplement the LIRC ioctl interface in Python. `ir-ctl` is fine until
  proven otherwise.
- Don't bit-bang GPIO to make the carrier. It will half-work and waste a night.
- Don't start editing `config.txt` or rebooting without asking the human first.
- Don't conclude "hardware is broken" until the phone camera test has failed.
