# AutoMute

A small black box that watches your TV and mutes the commercials.

**Status: phase 1 — make the Pi mute the TV over IR from `python3 mute.py`.**
Nothing is watching anything yet.

## How it will work

```
camera → "is this an ad?" → state machine → mute() → IR blaster → TV
```

Only the last two arrows exist right now. See `docs/ROADMAP.md` for the rest.

## Hardware (phase 1)
- Raspberry Pi 5 (8 GB), Raspberry Pi OS 64-bit (Bookworm)
- KY-005 IR transmitter module (a bare 940 nm LED) on GPIO18 through a 150–220 Ω resistor
- A TV with an IR remote

## Run it
```bash
sudo apt install v4l-utils ir-keytable   # ir-ctl and friends
# enable the kernel IR transmitter and reboot — docs/BRINGUP.md §2
python3 mute.py                          # toggles mute
```

## What's in here
- `mute.py` — the whole phase-1 deliverable: `mute()` sends the TV's mute key through the kernel's rc-core IR transmitter
- `docs/` — bring-up runbook, wiring, IR code table, troubleshooting, decisions, roadmap
- `CLAUDE.md` + `.claude/` — context, rules and slash commands for Claude Code
- `NOTES.md` — ideas parked for later phases
