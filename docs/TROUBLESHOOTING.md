# Troubleshooting — symptom → check → fix

Work top-down: each section assumes the ones above it pass. Anything with `sudo`: ask first.
`/bringup-status` gathers most of the evidence below in one go.

## T1. No `/dev/lirc0` after the reboot
- `grep -n ir-tx /boot/firmware/config.txt` → line present, spelled exactly `dtoverlay=pwm-ir-tx,gpio_pin=18`,
  and in the `[all]` section (not under `[pi4]`, `[cm4]`, `[cm5]`)? Edited `/boot/firmware/config.txt`,
  not `/boot/config.txt`?
- `ls /boot/firmware/overlays/ | grep ir-tx` → `pwm-ir-tx.dtbo` present?
- `dmesg | grep -i -E 'overlay|pwm|lirc|rc'` (sudo if refused) → "Failed to apply overlay", "probe … failed",
  "EPROBE_DEFER", "could not get pwm"?
- `sudo vclog --msg | grep -i dt` (Pi 5's replacement for `vcdbg`) → firmware-side overlay errors.
- Did the reboot actually happen?
Fix the line, reboot, re-check.

## T2. `/dev/lirc0` exists but `ir-ctl -f` says "Device cannot send"
Another overlay (`gpio-ir`, `gpio-ir-recv`) grabbed rc0. `ir-keytable` lists every rc device — ours is
"PWM IR Transmitter". Use `-d /dev/lirc1` for now; later give it a stable name with a udev rule (NOTES.md).

## T3. `ir-ctl: cannot open /dev/lirc0: Permission denied`
`ls -l /dev/lirc0` → group `video`? `id` → are you in it? `sudo usermod -aG video $USER` (sudo), then log
out and back in. Don't run `mute.py` with sudo as a workaround — a future service would inherit the habit.

## T4. Sends "succeed" but the phone camera sees nothing
1. `pinctrl get 18` → must show a PWM function. `op` / `no` / `ip` means the overlay didn't take the pin → T1.
2. `ir-ctl -d /dev/lirc0 -v -S rc5:0x1e01` → prints a pulse/space list and exits 0? If it errors, read the error.
3. LED polarity: swap `S` and `-` at the module (no damage either way with the resistor in place).
   Re-count the header: pin 12 is the 6th pin from the left on the outer row, pin 6 the 3rd.
4. Camera: front camera, dark room, 5–10 cm. Some phones filter IR completely — try another phone or a
   cheap webcam.
5. Loop the send (10 × with `sleep 0.2`) so the flicker lasts seconds instead of 67 ms.
6. dmesg "TX will not be accurate as PWM device might sleep" is a precision note, not the cause — the LED
   still lights on that path.

## T5. LED blinks, TV ignores everything
- **Aim**: at the TV's IR window (dark dot on the bottom bezel), ≤ 1 m, direct line of sight, LED *axis*
  pointed at it — bare LEDs radiate in a ~±20° cone. Try 30 cm to rule range out.
- **Format**: Linux scancode, not web hex (IR-CODES §1). VOL+ before MUTE.
- **Protocol family**: LG/Vizio `nec` → Samsung `necx` → raw Samsung32 (IR-CODES §5) → Sony `sony12` × 3 →
  Philips `rc5` → `rc6_0`. One family at a time, one send per 3 s, 3 candidates max before re-checking the source.
- **Carrier**: `-S` sets it per protocol. For raw files, include `carrier 38000` (Sony 40000, RC5 36000).
- **Room**: direct sunlight, plasma screens and some LED strips swamp a 10 mA LED. Try in the evening.
- If it works at 30 cm but not at 1 m, it's the LED, not the code: go to 150 Ω, then park the transistor
  driver (NOTES.md). Don't "fix" range in software.

## T6. Works sometimes (e.g. 12/20)
- Aim and distance first (T5 last bullet).
- Precision: is the dmesg "might sleep" message there? Then `pwm-ir-tx` is on its sleeping path; NEC
  tolerates ±25 % but long frames can still fail. Check `uname -r` and `sudo apt full-upgrade` (sudo);
  try `-D 33` (duty cycle) on the `ir-ctl` line; otherwise accept the 18/20 bar and fix range in hardware.
- Double-sending: `ir-ctl -v` must show one frame per `-S` (three for Sony).
- Power: `dmesg | grep -i under-voltage` → use the official 27 W supply.

## T7. Mute turns on and straight back off
Two presses were sent: a retry loop, two `-S` for a non-Sony protocol, `mute.py` run twice, or a shell
loop without `sleep`. Fix the caller. `mute()` is one press — see DECISIONS D6.

## T8. `time python3 mute.py` over 200 ms
Sony with the default 125 ms gap → `--gap 25000`. Imports beyond `subprocess`? Remove them. First run
after boot loads caches → time the second run.

## T9. Worked yesterday, not today
Kernel update → `/bringup-status`. Pi under-voltage in dmesg. TV in a standby/eco state that ignores IR
until a real remote wakes it. `/dev/lirc0` renumbered because a new rc device appeared (T2).

## T10. `sudo dtoverlay -r pwm-ir-tx` segfaults and wedges IR until reboot
Don't run it. On the Pi 5 (kernel 6.12.20+rpt-rpi-2712) removing the overlay at runtime
null-derefs in the RP1 PWM driver's teardown:
```
Unable to handle kernel NULL pointer dereference
pc : rp1_pwm_remove+0x1c/0x48
  of_overlay_remove / configfs_rmdir
```
Aftermath: `/dev/lirc0` and `rc2` disappear, `dtoverlay -l` still lists the overlay, and the
next `dtoverlay` call blocks forever in **D state** (unkillable — it holds a configfs lock).
Only a reboot clears it. The rest of the system is unaffected.

Adding the overlay at runtime is fine; only removal is broken. To change `gpio_pin=`, edit
`/boot/firmware/config.txt` and reboot rather than reloading live.
