# NOTES — parking lot for later phases

Rules: append-only, one idea per line, dated, prefixed with an area
(Sensing, Detection, State machine, Actuation, Verification, Hardware, Product, Ops).
Nothing here gets built during phase 1. `/park <idea>` appends for you.

## Parked
- 2026-09-18 — Actuation: HDMI-CEC (`cec-ctl`) instead of IR — CEC can *set* mute and report audio status, so we'd know the state instead of toggling blind. Needs the Pi on an HDMI input.
- 2026-09-18 — Actuation: TV network APIs as another backend (LG webOS websocket, Samsung Tizen REST, Sony IRCC/Bravia REST). Stateful, no line of sight, per-brand pairing.
- 2026-09-18 — Hardware: range upgrade — NPN/MOSFET driver from 5 V (e.g. 2N2222 or 2N7000, ~47 Ω series) for 50–100 mA pulsed; or two LEDs in series. Bare LED at ~10 mA is a ~1 m device.
- 2026-09-18 — Hardware: an IR receiver (TSOP38238, or the Adafruit 5990 transceiver already on the BOM) lets us record the real remote with `ir-ctl -r` instead of looking codes up, and lets the box verify its own sends.
- 2026-09-18 — Sensing: Pi Camera Module 3 pointed at the screen; ~1 fps crops; fixed exposure so ad/content brightness swings don't confuse the classifier.
- 2026-09-18 — Detection (tier 1 heuristics): black-frame boundaries, corner-logo ("bug") presence, cut rate, loudness jump, aspect ratio changes.
- 2026-09-18 — Detection (tier 2): Claude API on frames first (cheap to try, easy to measure), then SmolVLM / Moondream on device, then CLIP embeddings fine-tuned per channel.
- 2026-09-18 — State machine: hysteresis (N consecutive ad frames → mute, M content frames → unmute), cooldown, manual override button, log every transition with the frame that caused it.
- 2026-09-18 — Verification: USB mic level check after `mute()` to confirm the toggle took; auto-correct desync.
- 2026-09-18 — Hardware: Pi AI HAT+ and enclosure — only after on-device detection is measured and actually needed.
- 2026-09-18 — Ops: a udev rule giving the transmitter a stable name (`/dev/lirc-tx`) once a receiver is added, so `/dev/lirc0` can't flip.
