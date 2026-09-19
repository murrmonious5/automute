# AutoMute

Mute the TV when a commercial comes on. Camera watches the screen, something
decides "ad / not ad", an IR blaster fires the mute code.

**Phase 1 (current): make the TV mute from a Python script.** No camera, no
detection, no state machine. `python3 mute.py` → TV goes silent. That's the
whole milestone. Everything later calls the same `mute()` function.

## Repo map

| File | What it's for |
|---|---|
| `CLAUDE.md` | Instructions for Claude Code. Read this first if you're an agent. |
| `README.md` | You are here. Human orientation. |
| `HARDWARE.md` | Parts, wiring, and **per-bench state** — who has what, what's already configured |
| `IR_CODES.md` | How to find and encode your TV's mute code. Includes the `ir-ctl` scancode math. |
| `TROUBLESHOOTING.md` | Symptom → check. Start here when nothing happens. |
| `check_ir.sh` | Read-only bench dump. No sudo, no writes. Run it before doing anything else. |
| `mute.py` | The canonical interface. Keep it tiny. |
| `NOTES.md` | Parking lot for later-phase ideas. Nothing here gets built yet. |

## First five minutes on a new bench

```bash
git clone <repo> && cd automute
bash check_ir.sh
```

`check_ir.sh` prints the Pi model, whether the `pwm-ir-tx` overlay is live,
whether `/dev/lirc0` exists, and whether `ir-ctl` can talk to it. Paste that
output into your Claude session before asking it to do anything — it removes
most of the guessing.

Then add your bench to `HARDWARE.md` (Pi revision, TV brand/model, whether
you've edited `config.txt` yet) and commit that. The next person's agent reads
it.

## Two benches, one repo

We're each on our own Pi with our own TV. That means:

- **The mute code is not shared.** `mute.py` has one protocol/scancode at the
  top; if our TVs differ, whoever changes it should say so in the commit
  message, and we should move it to a config file before it becomes annoying.
- **`/boot/firmware/config.txt` is not in the repo** and never will be. It's
  machine state. `HARDWARE.md` records whether each bench has been edited.
- **Don't assume the other bench is wired.** `check_ir.sh` tells you about
  *your* Pi only.

## Ground rules that survive the handoff

- Nothing touches `sudo` + `config.txt` + reboot without the human saying yes
  first, with an explanation of what the edit does.
- One small step, then a check. This is bring-up, not a build.
- Pi 5 / RP1 behaviour differs from older Pis in ways that aren't always
  documented. If you're unsure, say so and test — don't assert.
