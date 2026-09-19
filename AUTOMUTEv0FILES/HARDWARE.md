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
Pi GPIO12 (PHYSICAL PIN 32) ──[ 150–220 Ω ]── KY-005  S
Pi GND    (physical pin 6)  ─────────────────  KY-005  -

!! GPIO12 is physical pin 32. Physical pin 12 is GPIO18 and does NOT work here (T11/D9).
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
dtoverlay=pwm-ir-tx,gpio_pin=12,func=4
```

Requires sudo to edit and a reboot to take effect. **Ask the human first and
explain the edit.**

---

## Bench state

Each person keeps their own section current. This is the file that stops the
other person's Claude from re-running setup that's already done, or assuming
setup that isn't.

### Bench A — James

*Updated 2026-09-19 01:10 by Claude. Name in the heading left as-is — correct it if wrong.*

**Status: overlay + pin VERIFIED THROUGH A REBOOT. IR emits. Reliability REGRESSED and
DoD #1/#2 still NOT passed.** VOL+, VOL-, MUTE all confirmed working as codes (2026-09-19
~00:10), but see the 01:05 session results below before assuming phase 1 is done.

- Pi 5 8 GB, Raspberry Pi OS 64-bit, kernel 6.12.20+rpt-rpi-2712
- KY-005 on **GPIO12 = physical pin 32** through a resistor — value **not recorded, write it in** —
  wiring: `[x] done  [x] verified with phone camera`
  - Moved from physical pin 12 (GPIO18) to physical pin 32 (GPIO12) on 2026-09-19 ~00:05. That
    move is what made the transmitter work — see TROUBLESHOOTING T11 and DECISIONS D9.
  - Pin 32 → resistor → `S`; pin 6 (GND) → `-`; middle pin empty (not connected to the LED, and
    not a receiver — this build has no receiver).
  - Earlier state was a bare wire with no resistor; four NEC frames went out that way at 22:28
    on 2026-09-18. No damage apparent: the pin drives normally and the LED is bright.
- `config.txt`: `dtoverlay=pwm-ir-tx,gpio_pin=12,func=4` under `[all]`, with a comment warning
  about the pin-12/GPIO12 collision. Backups: `config.txt.automute.bak`, `…bak.0009`.
  **REBOOTED INTO AND VERIFIED 2026-09-19 01:05.** After a real reboot (boot 01:01:51),
  `pinctrl get 12` reads `a0 pd | lo // GPIO12 = PWM0_CHAN0` — set by the overlay this time,
  not by a live `pinctrl set`. `pinctrl get 18` reads `none`, so the old pin is released.
  **`func=4` does translate correctly on Pi 5 firmware** — that open question is closed, no
  adjustment needed. The mux also survived ~50 sends unchanged.
- `/dev/lirc0`: present, rc2 = "PWM IR Transmitter" / `pwm-ir-tx`, `ir-ctl -f` = can send raw IR,
  cannot receive. dmesg still carries "TX will not be accurate as PWM device might sleep" — the
  RP1 sleeping path, and NEC works through it fine in practice.
- TV: **LG 65UQ7570PUJ**, IR window bottom-centre of the bezel under the logo.
- **Codes confirmed working (2026-09-19, ~20–30 cm, straight on):**
  `nec:0x0402` VOL+ · `nec:0x0403` VOL− · `nec:0x0409` MUTE (single press, mute icon shown).
  The published LG NEC device-4 table was right from the start; the emitter was the problem.
- `python3 mute.py`: 0.102 s (`real`, second run) — definition of done #3 passes.
- **The first KY-005 was faulty.** It lit fine on the DC test but dropped most frames: 7/20 and
  8/20 at 20–30 cm, and 2/10 at *three inches* — far too close for range to explain. A second
  KY-005 took the same test to 10/10. Keep the good one; bin or label the bad one.
  (TROUBLESHOOTING T12a. "The LED lights" ≠ "the LED transmits a clean frame".)
- **Range envelope, measured with the volume instrument** (second module, bare LED ~10 mA):
  **10/10 at 3 in · 10/10 at 1 m · ~5/10 at 5 m.** Reliable at the phase-1 metre, about half by
  5 m — exactly what D5 predicted. A box beside the TV is fine; anywhere else wants the
  transistor driver (docs/SHOPPING.md item 1).
- **Back-to-back VOL vs MUTE — RAN 2026-09-19 01:05 at 1 m. INCONCLUSIVE, and here is why.**
  Identical position, nothing moved between the two runs, all 20 sends accepted by the driver
  with zero send errors and the pin still on PWM0_CHAN0 afterward.

  | Run | Instrument | Result |
  |-----|-----------|--------|
  | 10 × `nec:0x0402` VOL+ | volume delta 20 → 28 (objective) | **8/10** |
  | 10 × `nec:0x0409` MUTE | observed by eye, sequence NOT recorded | **~5/10 (soft)** |

  **The control moved.** Last session the same module at the same 1 m gave **10/10** on VOL+;
  tonight it gave 8/10. That is the headline finding. The back-to-back was designed to hold VOL
  at 10/10 so any MUTE shortfall would be mute-specific — with the control itself down to 8/10,
  ~5/10 on mute is consistent with plain link-margin loss and **does not confirm or clear a
  mute-specific fault**. The original question is still open.
  - The MUTE half was run as 10 presses 4 s apart with the state (M/U) to be written down after
    each, so misses would be individually localised (fixes T12b's ambiguity). **The sequence was
    not actually recorded** — the result is a recollection of "maybe 5", not data. Re-run it and
    write the letters down; without them this row stays soft.
  - Untested causes for the VOL+ regression, cheapest first: **aim/angle** (never characterised,
    cone is ~±20°, and the rig was repositioned since the 10/10 run), then **module degradation
    or the bad KY-005 having been swapped back in by mistake** (T12a — label the good one),
    then ambient IR.
- **Emission itself is not in doubt.** T11 strobe at 01:05: 27 bursts, 0 failures, clear purple
  blinking on the phone camera. The modulated path genuinely works — this is a margin problem,
  not a repeat of the dark-LED T11 failure.
- **DoD status: #3 passes (0.102 s). #4 passes (strobe visible). #1 and #2 NOT passed** — 8/10
  on the objective instrument is below the ≥18/20 bar, before mute is even considered.
- Angle was never characterised, only distance. The cone is ~±20°; worth one sweep.

Next session, in order — the reboot/pin/strobe steps are all DONE and need not be repeated
unless `config.txt` changes:
1. **Chase the VOL+ regression (8/10 at 1 m, was 10/10).** It gates everything else; there is no
   point counting mute until the objective instrument is back at 10/10.
   a. Confirm which KY-005 is fitted — the good one, or the faulty one from T12a. Label them.
   b. One angle sweep at 1 m (0°, ±10°, ±20°) with the volume instrument. Aim was never
      characterised and the rig moved since the 10/10 run; this is the cheapest suspect.
2. Once VOL+ is back to 10/10 at 1 m, re-run the back-to-back — **and write the M/U sequence
   down this time**, 10 letters, one per press.
3. Only then: 20 runs of `mute.py`, need ≥ 18 (DoD #2).
4. Results log.

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
