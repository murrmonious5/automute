# Next steps — closing out phase 1

Written 2026-09-18 after a full read of the repo.

## The framing

AutoMute is a remote control with the human taken out and a script put in.

A normal remote is open-loop: it fires a frame and hopes. That's fine for fifty
years of remotes because *you* are the feedback — you press mute, look at the
screen, press again if nothing happened. Take the human out and nothing closes
the loop. Every hard problem on the roadmap (toggle desync, phase 4 not being
able to meet its own acceptance bar, no way to know the TV's state) is a symptom
of that one thing.

The cheapest first move toward closing it is an IR **receiver**. We don't have one.

A receiver does three jobs — only two of them are about feedback:

1. **Record instead of look up.** Point the LG remote at it, `ir-ctl -r`, get the
   real frame. Retires the guess-and-convert path in DECISIONS D4 and the web-hex
   trap in IR-CODES §1.
2. **Hear our own transmitter.** It sits inches from the LED, so every send comes
   back. The 18/20 test becomes a script instead of a person counting, and a miss
   becomes attributable: frame malformed vs. frame never left vs. TV didn't react.
   This is the oracle the bench currently doesn't have.
3. **Hear the human's remote.** Someone grabs the LG remote and hits mute — the
   box sees the frame and updates its belief. Nothing in the phase 5 plan catches
   this, because a mic and HDMI-CEC both watch the TV, not the room.

Honest limit: a receiver tells us **what was transmitted, never what the TV did**.
Clean frame + TV ignores it = still blind. Absolute state readback is still CEC or
the webOS network API. But jobs 2 and 3 remove most of the ways a blind toggle goes
wrong, for about $2.

---

## Steps, in order

### 1. Order the receiver today
Ships slower than anything else here can be done.

- TSOP38238 (~$2 — Amazon / Adafruit / Digi-Key), or the Adafruit 5990 already on
  the parts list in NOTES.md.
- Grab a couple of spare KY-005 modules while ordering.

Nothing else needs to be bought. (Camera parts are deliberately out of scope.)

### 2. Finish proving phase 1 with what's on the bench
VOL+ works. There is no record of MUTE ever working, and the results table in
`docs/BRINGUP.md` §9 is empty.

Run the test the runbook already defines, from ~1 m with clear line of sight:

```bash
for i in $(seq 20); do echo "run $i"; python3 mute.py; sleep 3; done
```

Watch the TV and count how many of the 20 actually toggled the mute icon.
**Pass is 18 or better.** Then:

```bash
time python3 mute.py    # run twice, take the second; want real well under 0.200s
```

Write both results into the empty table at the bottom of `docs/BRINGUP.md` and
commit. Until that table has a row, phase 2 can't start by our own gating rule —
and more practically, a future problem can't be told apart from a pre-existing one.

### 3. Fix the misleading line in CLAUDE.md
`CLAUDE.md` tells Claude that LG's code looks like `nec:0x20df906f`. That is the
web-hex form that `docs/IR-CODES.md` §1 explicitly says gets rejected or silently
misparsed. The working code correctly uses `nec:0x0409`. The Samsung entry in the
same paragraph (`necx:0x707f` addr) is also garbled — correct form is
`necx:0x07070f`.

Any future session that trusts CLAUDE.md over the docs will chase a phantom bug.
Ten-minute fix.

### 4. Delete AUTOMUTEv0FILES/
It's a stale copy of the same doc set, and the most recent commit edited **both**
copies. Two sources of truth is how we end up following instructions we already
replaced.

```bash
git tag v0            # optional; the history has it either way
git rm -r AUTOMUTEv0FILES/
```

Note: `check_ir.sh` currently lives *only* in that folder. It's a useful read-only
diagnostic — move it to the root or into `docs/` before deleting, or accept that
the `/bringup-status` command meant to replace it doesn't exist yet either.

### 5. When the receiver arrives — three things in one sitting
1. Wire it to **GPIO23 (physical pin 16)**, add `dtoverlay=gpio-ir,gpio_pin=23` to
   `/boot/firmware/config.txt`, reboot. Keep it on a different pin from the
   transmitter on GPIO18.
2. Add the udev rule giving the transmitter a stable name (`/dev/lirc-tx`), parked
   in NOTES.md. Two rc devices now exist and the numbering can swap — see
   TROUBLESHOOTING T2. This is the sitting where that stops being optional.
3. Point the LG remote at the receiver, press mute, capture the real frame with
   `ir-ctl -r`, and compare it to what we send. If they match, the code is
   confirmed correct for good.

### 6. Rerun the 20-run test with the receiver listening
The Pi counts its own sends instead of a human counting toggles, and a failure says
*where* it failed. That's the whole point: we stop being the feedback loop.

**Design consequence to build in now, not retrofit:** once the receiver is live the
box hears its own sends, so any "did the human press mute?" logic must gate out
frames we just transmitted. A timestamp window around each `mute()` call is enough.
Cheap now, annoying inside a state machine later.

---

## Explicitly waiting behind all of this
Camera and sensing (phase 2), cloud detection (phase 3), the state machine
(phase 4), enclosure and range upgrades (phase 7). Park ideas in NOTES.md.

## Other gaps found but not scheduled here
- No thermal plan for the Pi 5 (no fan/heatsink on any BOM) — matters from phase 6.
- LED is on jumper wires with no fixture; aim is the dominant variable in the 18/20
  test, so a bad score may be aim drift rather than a hardware finding.
- `.claude/` doesn't exist, but `/park`, `/find-code`, `/bringup-status` and
  `/test-mute` are referenced in four docs.
- `mute.py` exists three times (root, v0 folder, IR-CODES §7) and will drift.
- `mute.py` has no error handling — phase 4 will import it and get a raw
  `CalledProcessError` mid-state-machine.
- `tv_details.md` sits at root and duplicates the LG row of IR-CODES §3.
- HDMI-CEC feasibility is untested, and it's the stateful alternative to a blind
  toggle — worth 20 minutes with `cec-ctl` before investing further in IR-only.
