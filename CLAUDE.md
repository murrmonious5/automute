# AutoMute — phase 1: mute the TV from a Python script

## What we're building tonight
A Raspberry Pi 5 that mutes a TV over infrared when `python3 mute.py` is run.
Nothing else. No camera, no detection, no state machine. Those come later and
will call the same `mute()` function.

## Repo map — read the one you need, not all of them
| Need | Read |
|------|------|
| The next step and how to check it | `docs/BRINGUP.md` |
| Pins, wiring, resistor, KY-005 facts, Pi 5 / RP1 notes | `docs/HARDWARE.md` |
| The TV's `protocol:scancode`, code conversion, raw fallback, `mute.py` template | `docs/IR-CODES.md` |
| Something doesn't work | `docs/TROUBLESHOOTING.md` |
| Why we chose X over Y | `docs/DECISIONS.md` |
| What's out of scope and what later phases look like | `docs/ROADMAP.md`, `NOTES.md` |

Slash commands: `/bringup-status` (read-only health check), `/find-code <brand> [model]`,
`/test-mute` (definition-of-done run), `/park <idea>` (append to NOTES.md).

## Hardware on the bench
- Raspberry Pi 5 (8 GB), Raspberry Pi OS 64-bit (Debian 12 based), CanaKit.
- Hosyond 7" HDMI touchscreen (debug display only; not part of the design).
- KY-005 IR transmitter module. This is a BARE 940 nm IR LED with no driver
  transistor and no receiver. Pins: `S` (signal/anode), middle (unused), `-` (GND).
  It needs a series resistor. We do NOT have an IR receiver, so the remote's
  code cannot be recorded; it must be looked up by TV brand.

## Wiring (already done or being done by hand)
- **GPIO12 = PHYSICAL PIN 32** → 150–220 Ω resistor → KY-005 `S`
  (NOT physical pin 12, which is GPIO18 — that pin cannot work with this driver, see below)
- KY-005 `-` → GND (physical pin 6)
- Do not suggest driving the LED without a resistor.
- Optional later upgrade for range: NPN transistor driver from 5 V. Not tonight.
- To prove the LED optically, drive the pin to steady DC (`pinctrl set 12 op dh`, then always
  `pinctrl set 12 a0` to restore) — an actual IR send is usually invisible to a phone camera, so
  "no flicker" is not evidence of a dead LED. Details and a blink loop: TROUBLESHOOTING T4 item 7.

## Software design (do it this way)
- Let the Linux kernel generate the 38 kHz carrier and pulse timings via
  rc-core. Python must NOT bit-bang GPIO for IR; user-space timing is too loose.
- Enable the transmitter with `dtoverlay=pwm-ir-tx,gpio_pin=12,func=4` in
  `/boot/firmware/config.txt` (needs sudo, then reboot). Use `pwm-ir-tx`,
  not `gpio-ir-tx`, on the Pi 5 — the bit-banged driver has timing problems
  through the RP1 I/O chip.
- **GPIO12, never GPIO18, on a Pi 5.** `pwm-ir-tx` hardcodes PWM channel 0 and has no
  parameter to change it. On the RP1, channel 0 is GPIO12; GPIO18 is channel 2. With
  `gpio_pin=18` the pin muxes correctly, the driver transmits on a different channel,
  every layer reports success and the LED stays dark. Verified on this bench 2026-09-19;
  full diagnosis in TROUBLESHOOTING T11. Web guides all say GPIO18 — they mean the Pi 4.
- A green `/dev/lirc0` proves nothing about emission: check `pinctrl get 12` reads
  **PWM0_CHAN0**, and confirm light with the T11 strobe before trusting any send.
- After reboot, `ir-keytable` should list a "PWM IR Transmitter" and
  `/dev/lirc0` should exist. If it doesn't, check `dmesg | grep -i -E "pwm|lirc|rc"`.
- Send codes with `ir-ctl` from `v4l-utils`:
  `ir-ctl -d /dev/lirc0 -S <protocol>:<scancode>`
  Scancodes are in Linux rc-core format (`docs/IR-CODES.md` §1), NOT the 32-bit
  hex found on Arduino/LIRC pages. Sony (SIRC) needs the frame sent 3 times
  (`-S x -S x -S x --gap 25000`); everything else exactly once — mute is a toggle.
- `mute.py` should expose `mute()` that shells out to `ir-ctl`. Keep it tiny.
  Do not reimplement the LIRC ioctl interface unless `ir-ctl` proves inadequate.

## Finding the TV's mute code
Ask the user for the TV brand/model, then determine protocol + scancode
(`/find-code`; table in `docs/IR-CODES.md`). Test VOL+ first — visible and
harmless — then MUTE. Common:
- LG → `nec:0x0409` (address 0x04, mute 0x09; the same key appears on the web as `0x20DF906F`)
- Samsung → `necx:0x07070f` (address 0x0707, mute 0x0f; raw Samsung32 fallback in IR-CODES §5)
- Sony → `sony12:0x10014` (device 1, mute 0x14), 3 frames per press
- Vizio → same code set as LG (both NEC device 4); verify
Verify against a known table (irdb, the LIRC remotes database, kernel
`rc_keymaps`) rather than guessing. If the first code doesn't work, try the
brand's other common protocols before touching hardware.

## Definition of done
1. `python3 mute.py` toggles mute on the TV from ~1 m with clear line of sight.
2. 20 runs with a 3 s gap → at least 18 successes (bare LED; range is limited).
3. `time python3 mute.py` well under 200 ms.
4. Phone camera test: the KY-005 LED shows a faint purple flicker while sending.

## Ground rules
- Ask before running anything with `sudo` that edits `/boot/firmware/config.txt`
  or reboots the Pi; explain what it changes first. (`.claude/settings.json`
  also forces a prompt on every `sudo`.)
- Prefer one small step and a check over a big script. This is a bring-up.
- If something is uncertain about the Pi 5 / RP1 specifically, say so and test
  rather than assert.
- Later phases (camera, Claude API classifier, SmolVLM on device, mic feedback,
  HDMI-CEC instead of IR) are out of scope tonight. Note ideas in `NOTES.md`
  (`/park`), don't build them.
- Commit after each step that passes its check; one-line message, present tense.
