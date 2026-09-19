# Shopping list — phase 1 finish + phase 2

Written 2026-09-19 after the first bring-up session. Ranked by value per dollar for *this* build,
not by general usefulness. Prices are rough US figures, check before ordering.

Read `ROADMAP.md` first: a phase starts only when the previous one's "done when" is met. Nothing
here is needed to *finish* phase 1 — phase 1 is blocked on measurement, not parts.

## 1. IR emitter upgrade — high-power LED + transistor driver (~$12)
**The single most valuable purchase.** Ends the range ceiling permanently.

| Part | Qty | Why |
|------|-----|-----|
| TSAL6200 (940 nm, ±17°, high radiant intensity) | 5 | Replaces the KY-005's generic LED. Narrow cone = more range on axis |
| 2N3904 / 2N2222 NPN (or 2N7000 MOSFET) | 10 | Switches the LED from 5 V instead of the 3.3 V GPIO |
| 47 Ω, 1 kΩ resistors | 10 each | 47 Ω series for ~75 mA pulsed; 1 kΩ base resistor |

Measured tonight with the bare LED at ~10 mA: **10/10 at 1 m, ~5/10 at 5 m** (TROUBLESHOOTING T12).
A transistor from 5 V gives 5–10× the current, which is the difference between "box must sit next
to the TV" and "box sits anywhere in the room". This is DECISIONS D5's "revisit when", and phase 7
lists it explicitly. Buy spares of everything: one of our two KY-005 modules was faulty out of the
bag and cost us hours (T12a).

## 2. IR receiver — TSOP38238 ×5 (~$8)
Turns guessing into measurement. Three pins, 3.3 V, one GPIO:
```
dtoverlay=gpio-ir,gpio_pin=17        # any free pin, NOT the transmitter's
ir-ctl -d /dev/lirc1 -r              # raw pulse/space
ir-keytable -t                       # decoded protocol + scancode
```
- **Ground truth on codes**: record the real LG remote and compare against what we send. Tonight we
  spent hours unsure whether `nec:0x0409` was wrong when the transmitter was simply dark.
- **Self-verification for phase 5**: the box confirms its own sends instead of toggling blind.
- Better than both of tonight's instruments (D10) — it counts our frames directly.

Check the parts drawer first: `NOTES.md` says an **Adafruit 5990** transceiver is already on the BOM.
Gotcha: adding a receiver can renumber the devices, so the transmitter may become `/dev/lirc1`.
`mute.py` hardcodes `lirc0` — that's the udev rule parked in `NOTES.md`.

## 3. Camera Module 3 Wide + Pi 5 FPC cable (~$45)
Phase 2's entire hardware requirement. **Do not order the camera without the cable.**
- Camera Module 3 **Wide** (~$35) — 120° FOV, right for a TV at couch distance. Standard (75°) works
  if the Pi sits further back
- **22-pin 0.5 mm → 15-pin 1 mm FPC camera cable**, 300 mm or 500 mm (~$6). The Pi 5 uses the 22-way
  mini connector; the camera ships with the 15-way cable. A *camera* cable, not a display cable

Hold this until `mute.py` passes its 20-run score — phase 2 can't start before phase 1 closes.

## 4. Pi 5 Active Cooler (~$5–10)
Phases 2–3 run the camera and network calls continuously, and phase 6 runs a VLM on-device. A
passively cooled Pi 5 throttles under sustained load, and throttling is the kind of fault that looks
like a software bug. `vcgencmd get_throttled` read `0x0` tonight, but tonight was idle.

## 5. Permanent mounting — proto HAT + a positionable arm (~$20)
The IR circuit is jumpers in a breadboard. Once the transistor driver goes in, it wants to be
soldered onto a proto HAT so a knocked wire can't reintroduce tonight's debugging. Add a small
gooseneck or mini tripod so the camera and the emitter can be aimed independently — the emitter
needs the TV's IR window, the camera needs the screen, and they are not the same direction.

---

## Deliberately not buying yet
| Item | Why not |
|------|---------|
| **Flipper Zero** (~$169–199) | Genuinely useful bench tool and a known-good strong transmitter, but a $2 TSOP38238 diagnoses the same things and stays in the loop for phase 5. Buy it because you want it, not because this project needs it |
| **AI HAT+** | ROADMAP phase 6: "only if the numbers demand it". Measure cloud inference first |
| **USB mic** | Phase 5. The receiver is a better verification instrument anyway |
| **Enclosure** | Phase 7. Dimensions aren't known until the driver circuit exists |

## If you only buy one thing
The **TSOP38238 multipack**. It's under $10, it ends an entire category of "is it the code or the
hardware?" debugging, and it's the only item here that would have shortened tonight.
