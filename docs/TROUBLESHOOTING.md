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
7. **DC-on test — the decisive one. Do this before touching the wiring.** A real send is easy for a
   camera to miss: a NEC frame is only ~67 ms, and inside it the LED is lit just for the on-third of
   each 38 kHz carrier cycle, so at 30 fps it lands in one or two dim frames. Steady DC removes the
   modulation and makes the LED unmistakable:
   ```
   $ pinctrl set 18 op dh     # LED on solid. ~13 mA through the 150–220 Ω resistor; fine for minutes
   $ pinctrl get 18           # expect  18: op dh pd | hi // GPIO18 = output
   $ pinctrl set 18 a3        # ALWAYS restore: a3 = PWM0_CHAN2, the function pwm-ir-tx needs
   ```
   Blinking it also exposes a marginal contact — flex the jumpers while it runs and watch for a
   missing or dim flash:
   ```
   $ for i in $(seq 10); do pinctrl set 18 op dh; sleep 0.75; pinctrl set 18 op dl; sleep 0.75; done; pinctrl set 18 a3
   ```
   Steady purple → LED, resistor, polarity and pin number are all good, and the camera was the
   problem, not the rig: go to BRINGUP step 6 and let the TV be the judge. Nothing on two different
   cameras → the LED really isn't lighting; back to items 3 and 4.
   No sudo, no reboot — this only changes the pinmux, unlike `dtoverlay -r` (T10).
   **Don't run it alongside another background job that ends in `pinctrl set 18 a3`**: the job's
   cleanup yanks the pin mid-test and reads as a dropped blink. Seen on this bench 2026-09-18.

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

## T11. Everything says OK, `ir-ctl` exits 0, but the LED never emits (Pi 5)
**This one cost us an entire evening. Read it before debugging anything else on a Pi 5.**

Symptom: `/dev/lirc0` present, `ir-keytable` happy, `ir-ctl -f` says "can send raw IR",
`pinctrl get 18` shows `PWM0_CHAN2`, every send returns exit 0 — and the LED emits nothing.
DC light works (`pinctrl set 18 op dh` → bright purple on a phone camera), so the LED, the
resistor and the wiring are all fine. Only the modulated path is dead.

Cause: **`pwm-ir-tx` hardcodes PWM channel 0, and the overlay has no parameter to change it.**
```
$ dtc -I dtb -O dts /boot/firmware/overlays/pwm-ir-tx.dtbo | grep -A3 pwm-ir-transmitter
    pwms = <0xffffffff 0x00 0x64 0x00>;      # <&pwm CHANNEL=0 period=100 flags=0>
$ grep -A8 "^Name:   pwm-ir-tx" /boot/firmware/overlays/README
    Legal pin,function combinations are:  12,4(Alt0) 18,2(Alt5) 40,4(Alt0) 52,5(Alt1)
    Params: gpio_pin, func                   # no channel parameter
```
On a Pi 4, GPIO18 *is* PWM channel 0, so `gpio_pin=18` works and every guide on the web says
to use it. On the Pi 5 the RP1 maps the channels differently:

| GPIO | physical pin | RP1 PWM channel |
|------|--------------|-----------------|
| 12   | **32**       | PWM0_CHAN0 ← what the driver drives |
| 13   | 33           | PWM0_CHAN1 |
| 18   | 12           | PWM0_CHAN2 |
| 19   | 35           | PWM0_CHAN3 |

So `gpio_pin=18` on a Pi 5 muxes GPIO18 to **channel 2** while the driver keeps transmitting on
**channel 0**. Pin and driver are on different channels; nothing is wrong enough to raise an
error anywhere, and every layer reports success into a pin nobody is driving.

Fix: **use GPIO12 (physical pin 32), not GPIO18.**
```
dtoverlay=pwm-ir-tx,gpio_pin=12,func=4      # /boot/firmware/config.txt, then reboot
```
Move the resistor'd signal wire from physical pin 12 to physical pin 32. GND stays on pin 6.
Mind the naming collision: **GPIO12 is physical pin 32; physical pin 12 is GPIO18.**

Keeping GPIO18 is possible but not worth it: decompile the overlay, change the channel to 2,
recompile and maintain a local `.dtbo` that a firmware update can silently supersede.

### How to prove which layer is broken, without any extra hardware
1. **DC light** — `pinctrl set 18 op dh` … `pinctrl set 18 a3`. Tests LED + resistor + wiring only.
2. **Carrier on a chosen channel** — bypasses the driver, tests pin ↔ channel mapping:
   ```
   $ C=/sys/class/pwm/pwmchip0; echo 2 > $C/export; sleep 1     # udev needs a moment for group perms
   $ echo 26315 > $C/pwm2/period; echo 13157 > $C/pwm2/duty_cycle   # 38 kHz, 50 %
   $ echo 1 > $C/pwm2/enable      # camera: steady purple, ~half DC brightness
   $ echo 0 > $C/pwm2/enable; echo 2 > $C/unexport
   ```
   No sudo needed — the `gpio` group owns the exported channel.
3. **Live re-mux, no reboot** — `pinctrl set 12 a0` points GPIO12 at PWM0_CHAN0 so the real
   driver path can be tested before committing to `config.txt`. `pinctrl funcs <n>` lists the
   alt functions; count from the entry *after* the plain-GPIO one (`a0` is the second item).
4. **A camera-visible strobe** — an IR frame is too brief and too low-duty for a phone camera, so
   "no flicker" proves nothing (T4). This does:
   ```
   $ printf 'carrier 38000\n' > strobe.txt
   $ for i in $(seq 15); do printf 'pulse 20000\nspace 10000\n' >> strobe.txt; done
   $ sed -i '$ d' strobe.txt          # must end on a pulse
   $ while :; do ir-ctl -d /dev/lirc0 -D 50 -s strobe.txt; sleep 0.1; done
   ```
   Driver limit: bursts over ~500 ms are rejected with `failed to send: Invalid argument`
   (15 pulse/space pairs OK, 20 fails). Files must end with a pulse, not a space.
   `duty_cycle` is not a valid keyword inside the file — use `-D`.

Note `ir-ctl`'s own warning: "most lirc settings have global state." Carrier and duty cycle
persist on the device between invocations, so set `-c 38000 -D 50` explicitly when in doubt.

