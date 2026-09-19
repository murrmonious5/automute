# Hardware

## Parts (phase 1)

- **Raspberry Pi 5, 8 GB**, Raspberry Pi OS 64-bit (Debian 12 base), CanaKit power supply.
- **KY-005 IR transmitter module.** Important: this is a bare 940 nm IR LED on a
  breakout. No driver transistor, no current limiting on the board, **no
  receiver**. Pins are `S` (signal → LED anode), middle pin (not connected on
  most clones), `-` (cathode → GND).
- **Hosyond 7" HDMI touchscreen** — debug display only. Not part of the product.
- Resistor, 150–220 Ω, 1/4 W.

## Wiring

```
Pi GPIO18 (physical pin 12) ──[ 150–220 Ω ]── KY-005  S
Pi GND    (physical pin 6)  ─────────────────  KY-005  -
```

Notes an agent should not talk anyone out of:

- **The resistor is not optional.** GPIO pins on the Pi 5 source ~16 mA max and
  a bare IR LED at 3.3 V with no limiting will pull past that. Never suggest
  wiring `S` straight to GPIO18.
- **GPIO18 specifically**, because it's a hardware PWM pin and the `pwm-ir-tx`
  overlay needs one. Moving the LED to another GPIO means the overlay's
  `gpio_pin=` parameter has to match *and* that pin has to be PWM-capable.
- Range with a bare LED at 3.3 V is roughly a metre with line of sight. That is
  expected, not a bug. The fix is a transistor driver off 5 V — see `NOTES.md`,
  not tonight.

## Why `pwm-ir-tx` and not `gpio-ir-tx`

The kernel's rc-core generates the 38 kHz carrier and the pulse/space timings.
`pwm-ir-tx` does it with the hardware PWM block; `gpio-ir-tx` bit-bangs it from
the CPU. On the Pi 5, GPIO goes through the RP1 southbridge and the bit-banged
driver has had timing problems there. Use the PWM one.

Python must **never** bit-bang IR directly. User-space timing jitter on a
non-realtime kernel is far looser than the ~±10 µs that IR protocols want.

Overlay line in `/boot/firmware/config.txt`:

```
dtoverlay=pwm-ir-tx,gpio_pin=18
```

Requires sudo to edit and a reboot to take effect. **Ask the human first and
explain the edit.**

---

## Bench state

Each person keeps their own section current. This is the file that stops the
other person's Claude from re-running setup that's already done, or assuming
setup that isn't.

### Bench A — James

*Updated 2026-09-18 22:xx by Claude. Name in the heading left as-is — correct it if wrong.*

- Pi 5 8 GB, Raspberry Pi OS 64-bit, kernel 6.12.20+rpt-rpi-2712
- KY-005 on GPIO18 through a **NO** Ω resistor — wiring: `[ ] not yet  [x] done  [ ] verified with phone camera`
  - **DO NOT SEND IR.** Signal runs pin 12 → `S` bare, ground pin 6 → `-`. No series resistor.
    Four NEC frames were sent in this state by accident (22:28) before it was known; GPIO18
    should be re-checked. Get any 100 Ω–1 kΩ resistor in the signal line before any further send.
- `config.txt` overlay added: `[ ] no  [ ] yes, not rebooted  [x] yes, rebooted`
  - Line is `dtoverlay=pwm-ir-tx,gpio_pin=18` under `[all]`. Replaced a stale
    `dtoverlay=gpio-ir-tx,gpio_pin=15` (wrong driver AND wrong pin — GPIO15 is physical pin 10,
    adjacent to pin 12, so check the wire is really on 12). Backup: `config.txt.automute.bak`.
- `/dev/lirc0` present: `[ ] no  [x] yes` — verified live as `pwm-ir-tx` / "PWM IR Transmitter",
  `pinctrl get 18` = `PWM0_CHAN2`, send exit 0 in 69 ms, `python3 mute.py` in 99 ms (DoD #3 pass).
  **Was wedged by `dtoverlay -r` (TROUBLESHOOTING T10) — a reboot is required to restore it.**
- TV brand/model: **LG 65UQ7570PUJ** (see `tv_details.md`); IR window bottom-centre near the logo
- Working mute code: **`nec:0x0409` — UNVERIFIED against the TV.** VOL+ test code `nec:0x0402`.

Next step when picking this up: reboot done? → verify `/dev/lirc0` + `pinctrl get 18`, then
BRINGUP step 4 (phone-camera burst) **only once a resistor is fitted**.

### Bench B — (buddy)

- Pi model / OS:
- IR hardware (KY-005? something with a driver transistor?):
- Wiring done:
- `config.txt` overlay added:
- `/dev/lirc0` present:
- TV brand/model:
- Working mute code:

> If you're an agent reading this and a bench section is blank or stale, run
> `bash check_ir.sh` and ask the human to confirm before acting on it. Do not
> infer bench state from git history.
