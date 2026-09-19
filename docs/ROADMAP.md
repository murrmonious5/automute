# Roadmap — the shape of later phases, so phase 1 doesn't box us in

Rules: a phase starts only when the previous one's "done when" is met and committed. Nothing below
phase 1 is built during phase 1 — `/park` the idea instead.

| # | Phase | Done when | Not before |
|---|-------|-----------|------------|
| 0 | Bench | Pi boots, screen works, LED wired | — |
| 1 | **Mute from a script** (now) | BRINGUP §9: ≥ 18/20 at ~1 m, `< 200 ms`, camera flicker | — |
| 2 | See the TV | Camera Module 3 saves a frame of the screen every ~1 s; crop and exposure fixed; an hour recorded without drift | 1 |
| 3 | Ad / not-ad, in the cloud | frames → Claude API → label + confidence; ≥ 90 % agreement with a hand-labelled hour; cost per TV-hour known | 2 |
| 4 | Decide and act | hysteresis state machine (N ad frames → `mute()`, M content frames → `mute()` again), cooldown, manual override, every transition logged with its frame; one evening with no wrong mutes | 3 |
| 5 | Know the state | confirm a mute actually happened (USB mic level and/or HDMI-CEC audio status); auto-correct toggle desync | 4 |
| 6 | On-device | SmolVLM / Moondream / fine-tuned CLIP running locally, measured against phase 3; AI HAT+ only if the numbers demand it | 5 |
| 7 | Product | enclosure, LED driver for range (or CEC/network backend), zero-terminal setup, second TV | 6 |

## Interfaces to protect now
- `mute()` in `mute.py`, zero arguments, returns `None`. Phase 4 imports it. Don't rename it.
- Configuration (device, scancode, frames) stays as constants at the top of `mute.py` until phase 4,
  when it moves to a config file. Not before.

## Explicitly not doing
- No daemon / systemd unit until phase 4.
- No IR receiver work unless code lookup fails twice (DECISIONS D4).
- No separate "unmute": over IR it's the same key.
