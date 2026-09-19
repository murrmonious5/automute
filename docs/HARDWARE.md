# Hardware — phase 1

## On the bench
| Part | Notes |
|------|-------|
| Raspberry Pi 5 (8 GB), CanaKit | Raspberry Pi OS 64-bit (Bookworm). GPIO lives on the **RP1** I/O chip behind PCIe, not on the SoC — the reason bit-banged IR is unreliable here and why we let hardware PWM do the carrier. |
| Hosyond 7" HDMI touchscreen | Debug display only. HDMI + USB; touches no GPIO. Not part of the product. |
| KY-005 IR transmitter module | A bare 940 nm IR LED on a breakout. No driver transistor, no series resistor, no receiver. |
| 150–220 Ω resistor | Mandatory. See the math below. |

## KY-005 pinout
Three pins, board upright with the LED at the top:
```
  S   = signal = LED anode (+)   →  resistor  →  GPIO18
 mid  = not connected to the LED on most boards (sometimes printed "+"/"5V") → leave empty
  -   = LED cathode              →  GND
```
Reversed polarity = no light, no damage (the resistor is doing its job). If labels are missing,
the anode is the leg that is NOT on the `-` side.

## Wiring
```
Pi 5 40-pin header, board seen from above, header along the top edge, USB ports to the right.
Pin 1 (3V3) is the bottom-left pin (square solder pad). Even pins are the top (outer) row.

 outer row →   2   4   6 … 12 … 32  34  36  38  40    pin 6 = GND · pin 32 = GPIO12
 inner row →   1   3   5 … 11 … 31  33  35  37  39    pin 1 = 3V3

 pin 6  (GND)     ───────────────────────  KY-005 "-"
 pin 32 (GPIO12)  ── 150–220 Ω resistor ──  KY-005 "S"
```
**GPIO12 is physical pin 32. Physical pin 12 is GPIO18 — a different hole, and the wrong one.**
Pin 32 is the 16th pin from the left on the outer row, or the 5th from the right end
(40, 38, 36, 34, 32). Pin 6 is the 3rd from the left. `pinout` (installed with Raspberry Pi OS
Desktop) prints this header map for the exact board if you want to double-check.

Why GPIO12 and not the GPIO18 every web guide names: `pwm-ir-tx` hardcodes PWM channel 0, and on
the Pi 5's RP1 that channel comes out on GPIO12. GPIO18 is channel 2, so the driver transmits into
nothing while reporting success. Full story and diagnosis: TROUBLESHOOTING T11.

**Never drive the LED straight from the GPIO.** A 3.3 V pin into a ~1.3 V LED with no resistor is
a short circuit through the RP1's output driver.

## Resistor math (why 150–220 Ω)
GPIO high ≈ 3.3 V, IR LED forward voltage ≈ 1.2–1.4 V at 940 nm.
I = (3.3 − 1.3) / R → 150 Ω ≈ 13 mA, 220 Ω ≈ 9 mA peak, during the "on" half of each 38 kHz
carrier cycle (average is about half that). That is a weak IR source: expect ~1 m of range with
direct aim, which is why the acceptance bar is 18/20 and not 20/20. RP1 GPIO drive strength is
configurable and the safe continuous figure isn't something to assume; ~10 mA pulsed is
conservative. More range = transistor driver from 5 V, parked in NOTES.md.

## Pi 5 / RP1 specifics
Verified on bench 2026-09-19:
- **The RP1 PWM channel map is the thing that matters.** Two chips, `pwmchip0` (1f00098000.pwm)
  and `pwmchip1` (1f0009c000.pwm), four channels each. On `pwmchip0`:
  GPIO12 = CHAN0 (pin 32) · GPIO13 = CHAN1 (pin 33) · GPIO18 = CHAN2 (pin 12) · GPIO19 = CHAN3 (pin 35).
  `pwm-ir-tx` always drives CHAN0, so **GPIO12 is the only sane pin for it on a Pi 5** (T11).
- `pinctrl` replaces `raspi-gpio` on the Pi 5: `pinctrl get 12` → `a0 pd | lo // GPIO12 = PWM0_CHAN0`.
  `pinctrl funcs 12` lists the alt functions; `a0` is the second entry (the first is plain GPIO).
- The pinmux can be changed live — `pinctrl set 12 a0` — which lets you test a pin change before
  editing `config.txt` or rebooting. `pinctrl set <n> op dh` drives DC for a camera check.
- sysfs PWM works without sudo (the `gpio` group owns exported channels, after a ~1 s udev delay),
  which is how you test a pin ↔ channel pairing without involving the driver at all.
- The config file is `/boot/firmware/config.txt` on Bookworm.
- Pi 5 has no analog audio jack, so the old "PWM audio fights `pwm-ir-tx`" advice doesn't apply.
  Still make sure nothing else claims the pin (`dtoverlay=pwm`, `i2s`, HATs).

Answered on bench (kernel 6.12.20+rpt-rpi-2712, 2026-09-18):
- `pinctrl get 18` reports `a3 pd | lo // GPIO18 = PWM0_CHAN2` when `gpio_pin=18` is live —
  correct-looking, and useless: the driver is on CHAN0. This is exactly what made T11 so slow to find.
- This kernel does **not** give `pwm-ir-tx` its precise hrtimer path. dmesg says
  `TX will not be accurate as PWM device might sleep` — the sleeping fallback. NEC tolerates
  it; suspect it first if sends are flaky (TROUBLESHOOTING T6).
- The overlay can be applied at runtime (`sudo dtoverlay pwm-ir-tx gpio_pin=12 func=4`) without a
  reboot. It can **not** be removed at runtime — see TROUBLESHOOTING T10.

## Parked hardware ideas
See NOTES.md: transistor driver, IR receiver (TSOP38238 / Adafruit 5990) to record the real
remote, stable `/dev/lirc-tx` udev name, AI HAT+, enclosure.
