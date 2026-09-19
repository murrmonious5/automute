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

*Updated 2026-09-18 23:27 by Claude. Name in the heading left as-is — correct it if wrong.*

- Pi 5 8 GB, Raspberry Pi OS 64-bit, kernel 6.12.20+rpt-rpi-2712
- KY-005 on GPIO18 through a resistor — value **not recorded, write it in here** —
  wiring: `[ ] not yet  [x] done  [x] verified with phone camera`
  - Resistor confirmed in the signal line 2026-09-18 ~23:10, before any of that evening's sends.
    It was previously a bare wire and four NEC frames went out in that state at 22:28. Since the
    resistor went in, GPIO18 reads back its PWM function normally, the LED lights, and the TV
    responds — no damage apparent.
  - Pin 12 → resistor → `S`; pin 6 → `-`; middle pin empty (it is not connected to the LED, and it
    is not a receiver — this build has no receiver at all).
- `config.txt` overlay added: `[ ] no  [ ] yes, not rebooted  [x] yes, rebooted`
  - Line is `dtoverlay=pwm-ir-tx,gpio_pin=18` under `[all]`. Replaced a stale
    `dtoverlay=gpio-ir-tx,gpio_pin=15` (wrong driver AND wrong pin). Backup: `config.txt.automute.bak`.
- `/dev/lirc0` present: `[ ] no  [x] yes` — the reboot cleared the T10 wedge and it came back clean.
  Verified 2026-09-18 23:10: rc2 = "PWM IR Transmitter" / `pwm-ir-tx`, `pinctrl get 18` =
  `a3 // PWM0_CHAN2`, `ir-ctl -f` = can send raw IR + scancode encoder + set carrier, cannot receive.
  ~500 frames sent across the evening's test bursts, exit 0 on every one.
  dmesg still shows "TX will not be accurate as PWM device might sleep" — the RP1 sleeping path.
  NEC decodes fine through it in practice (TROUBLESHOOTING T6).
- LED verified by eye: **yes** — phone camera, DC-on test (TROUBLESHOOTING T4 item 7), bright purple,
  and a 10-cycle blink came through clean. The modulated IR bursts were invisible on the same camera,
  which cost us a round of debugging: treat "no flicker on a send" as meaningless, not as a fault.
- TV brand/model: **LG 65UQ7570PUJ** (see `tv_details.md`); IR window bottom-centre of the bezel,
  under the LG logo.
- **VOL+ `nec:0x0402` confirmed working against the TV**, 2026-09-18 ~23:15 — so the LG NEC device-4
  code set is correct for this TV. VOL− is `nec:0x0403`; range sweeps were sent as +/− pairs in even
  numbers so the volume ends where it started.
- Working mute code: `nec:0x0409` — **not yet sent at the TV.** Same protocol and address as the VOL+
  that works, so it should land, but it is unproven until someone watches the mute icon appear.
- Range envelope: **not measured.** Record the distance and angle where the TV stops responding next
  session — that number decides whether phase 2 needs the transistor driver (NOTES.md).

Next step when picking this up: BRINGUP step 7 — one MUTE press from a spot where VOL+ answers
(never twice "to be sure"; it is a toggle), then step 9's 20 runs at ≥ 18/20, and fill in the
results log at the bottom of BRINGUP.md.

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
