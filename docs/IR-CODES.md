# IR codes — how to say "mute" in the TV's dialect

`ir-ctl -S <protocol>:<scancode>` builds the whole frame for you: carrier frequency, leader,
bit timing. The only things you have to get right are **PROTOCOL**, **SCANCODE** and **how
many frames make one key press** (§4).

## 1. The trap: web hex ≠ Linux scancode
Codes on the web (Arduino-IRremote lists, LIRC `.lircd.conf` files, most forum posts) are the
32 bits *as transmitted*, e.g. LG mute `0x20DF906F`. Linux rc-core — and therefore `ir-ctl` —
wants the compact `address:command` scancode instead. `ir-ctl -S nec:0x20df906f` is **wrong**
(rejected as too large, or silently treated as a different NEC variant).

### Conversion recipe (NEC family: LG, Samsung, Vizio, Toshiba, Hisense, TCL…)
1. Split the 32-bit web hex into four bytes: `20 DF 90 6F`.
2. Bit-reverse each byte (NEC sends LSB first; Arduino/LIRC print MSB first):
   `20→04  DF→FB  90→09  6F→F6` → `[addr, addr', cmd, cmd'] = [04, FB, 09, F6]`.
3. Check the inverses: `FB == ~04` ✓ and `F6 == ~09` ✓.
   - both hold → plain NEC:        `nec:0x{addr}{cmd}`           → `nec:0x0409`
   - only `cmd'` holds → extended:  `necx:0x{addr}{addr'}{cmd}`   → Samsung `necx:0x07070f`
   - neither → not a normal NEC TV code. Stop, find a better source, or go raw (§5).

From **irdb** (`protocol, device, subdevice, function`, decimal): NEC1/NEC2 with subdevice −1 →
`nec:` with `(device<<8)|function`; with a subdevice, or protocol Samsung32/NECx2 → `necx:` with
`(device<<16)|(subdevice<<8)|function`. Sony12 → `sony12:` with `(device<<16)|function`.

Check with the stdlib (also handy inside Claude Code):
```python
def rev8(b): return int(f"{b:08b}"[::-1], 2)
def web_to_linux(h):
    a, ai, c, ci = (rev8((h >> s) & 0xFF) for s in (24, 16, 8, 0))
    if ci != c ^ 0xFF: return "not a standard NEC code"
    return f"nec:0x{a:02x}{c:02x}" if ai == a ^ 0xFF else f"necx:0x{a:02x}{ai:02x}{c:02x}"
print(web_to_linux(0x20DF906F))   # nec:0x0409
print(web_to_linux(0xE0E0F00F))   # necx:0x07070f
```

## 2. Linux scancode layouts (what `ir-ctl -S` expects)
| protocol | scancode layout | example |
|----------|-----------------|---------|
| `nec`    | `0xAACC` — address(8) command(8) | `nec:0x0409` |
| `necx`   | `0xAAaaCC` — address(8) address2(8) command(8); Samsung32 and "extended NEC" | `necx:0x07070f` |
| `sony12` | `(device<<16) \| function` — device 5 bits, function 7 bits | `sony12:0x10014` = device 1, function 0x14 |
| `sony15` / `sony20` | same idea; `sony20` puts a subdevice in bits 8–15 | rarely needed for TVs |
| `rc5`    | `0xAACC` — address(5) command(6) | `rc5:0x0d` = Philips TV (address 0) mute |
| `rc6_0`  | `0xAACC` — address(8) command(8) | `rc6_0:0x0d` |
| `sharp`  | `0xAACC` — address(5) command(8) | `sharp:0x0117` |

`ir-ctl` protocol names: `rc5 rc5x_20 rc5_sz jvc sony12 sony15 sony20 nec necx nec32 sanyo rc6_0
rc6_6a_20 rc6_6a_24 rc6_6a_32 rc6_mce sharp imon rc_mm_12 rc_mm_24 rc_mm_32`.
Not on the list: Panasonic/Kaseikyo → Panasonic TVs need a raw frame (§5). Avoid `nec32` for TVs.

## 3. Brand table
Confidence: ●●● well established · ●●○ likely, verify · ●○○ look it up (§6).
Always fire **VOL+ before MUTE**: visible, harmless, and it proves the TV hears the LED at all.
Don't test with POWER: it's a toggle too, and a TV takes a minute to come back.

| Brand | Protocol | address | VOL+ | MUTE | `ir-ctl` MUTE (VOL+) | frames/press | conf |
|-------|----------|---------|------|------|----------------------|--------------|------|
| LG | NEC | 0x04 | 0x02 | 0x09 | `nec:0x0409` (`nec:0x0402`) | 1 | ●●● |
| Vizio | NEC | 0x04 | 0x02 | 0x09 | `nec:0x0409` (`nec:0x0402`) — shares LG's code set | 1 | ●●○ |
| Samsung | Samsung32 (`necx`) | 0x0707 | 0x07 | 0x0f | `necx:0x07070f` (`necx:0x070707`) | 1 | ●●● (leader note ↓) |
| Sony (Bravia) | SIRC-12 (`sony12`) | device 1 | 0x12 | 0x14 | `sony12:0x10014` (`sony12:0x10012`) | **3**, gap 25 ms | ●●● |
| Toshiba | NEC | 0x40 | 0x1a | 0x10 | `nec:0x4010` (`nec:0x401a`) | 1 | ●●○ |
| Philips, older | RC5 | 0 | 0x10 | 0x0d | `rc5:0x0d` (`rc5:0x10`) | 1 | ●●○ |
| Philips, newer | RC6 mode 0 | 0 | 0x10 | 0x0d | `rc6_0:0x0d` (`rc6_0:0x10`) | 1 | ●○○ |
| Sharp (Aquos) | Sharp | 1 | 0x14 | 0x17 | `sharp:0x0117` (`sharp:0x0114`) | 1 | ●○○ |
| Hisense, TCL / Roku TV, Insignia, Panasonic, others | varies | — | — | — | look it up (§6) and convert (§1) | | ●○○ |

Other keys at the same address, for reference only: LG power 0x08, vol− 0x03 · Samsung power 0x02,
vol− 0x0b · Sony power 0x15, vol− 0x13 · Toshiba power 0x12, vol− 0x1e · Philips RC5 standby 0x0c,
vol− 0x11.

**Samsung leader note.** Samsung32 uses a 4.5 ms / 4.5 ms leader; `ir-ctl`'s `necx` encoder sends
the NEC 9 ms / 4.5 ms leader. Most Samsung sets accept it. If yours doesn't react to `necx:` at
all (and VOL+ `necx:0x070707` also fails), send the exact frame raw (§5) before blaming hardware.

## 4. Frames per key press — get this right, mute is a toggle
| protocol | one press = | notes |
|----------|-------------|-------|
| NEC / `necx` (LG, Samsung, Vizio, Toshiba…) | **1 frame** | A second full frame is a second press → un-mute. A held button on a real remote sends short *repeat* frames; `ir-ctl -S` doesn't and you don't need them. |
| Sony SIRC | **3 identical frames**, ~45 ms period | Sony receivers need ≥ 2, the standard is 3. `ir-ctl -d /dev/lirc0 -S sony12:0x10014 -S sony12:0x10014 -S sony12:0x10014 --gap 25000` (frame ≈ 20 ms + 25 ms gap ≈ 45 ms). The default 125 ms gap usually still works but blows the 200 ms budget. |
| RC5 / RC6 | **1 frame** | Real remotes flip a toggle bit per press; `ir-ctl` sends a fixed value. Presses seconds apart are fine (the receiver times out between them); two within ~100 ms look like one held key. |

Consequences for code: `mute()` is one press. No retry loops. A miss is a finding, not a reason
to send again.

## 5. Raw fallback (`ir-ctl -s FILE`)
`ir-ctl -s` sends a text file of alternating `pulse` / `space` lines in microseconds, with an
optional `carrier` line (mode2 format). A file may also contain `scancode nec:0x0409` lines,
which `ir-ctl` encodes for you — a tidy way to keep named codes on disk.

Exact-timing Samsung32 frame generator (addr 07 07, cmd 0F, ~cmd F0, LSB first; bit 0 = 560/560,
bit 1 = 560/1690; leader 4500/4500; trailer pulse 560):
```python
def samsung32(addr=0x07, cmd=0x0F):
    bits = []
    for byte in (addr, addr, cmd, cmd ^ 0xFF):
        bits += [(byte >> i) & 1 for i in range(8)]
    out = ["carrier 38000", "pulse 4500", "space 4500"]
    for b in bits:
        out += ["pulse 560", "space 1690" if b else "space 560"]
    out.append("pulse 560")                       # frames must end on a pulse
    return "\n".join(out) + "\n"
open("samsung-mute.txt", "w").write(samsung32())   # cmd=0x07 for VOL+
```
Then `ir-ctl -d /dev/lirc0 -s samsung-mute.txt`. Carriers: NEC/Samsung 38000, Sony 40000, RC5 36000.

## 6. Where to verify a code
- **irdb** — `github.com/probonopd/irdb`, CSV per brand/device: `protocol, device, subdevice, function` (decimal). Best source: it gives address and command explicitly.
- **LIRC remotes database** — `.lircd.conf` files; `pre_data` + key code = the 32-bit web hex → convert (§1).
- **Kernel keymaps on the Pi** — `/lib/udev/rc_keymaps/*.toml` (from the `ir-keytable` package): a few TV maps already in Linux scancode form.
- **Arduino-IRremote "known codes"** — web hex → convert (§1).
When two sources disagree, prefer the one that states address + command; test VOL+ from each.

## 7. `mute.py` template (phase-1 deliverable)
```python
#!/usr/bin/env python3
"""AutoMute phase 1 — toggle the TV's mute over IR.

Usage: python3 mute.py
The kernel (rc-core + pwm-ir-tx) generates the 38 kHz carrier and the pulse timing;
this file only tells it which key to send. Codes: docs/IR-CODES.md.
"""
import subprocess

LIRC_DEV = "/dev/lirc0"
SCANCODE = "nec:0x0409"   # LG mute. Samsung: "necx:0x07070f". Sony: "sony12:0x10014" with FRAMES = 3.
FRAMES = 1                # frames per key press: 1 for NEC/Samsung/RC5, 3 for Sony
GAP_US = 25000            # gap between frames when FRAMES > 1 (Sony wants ~45 ms period)


def mute() -> None:
    """Send exactly one MUTE key press. Mute is a toggle: never call this to 'retry'."""
    cmd = ["ir-ctl", "-d", LIRC_DEV, "--gap", str(GAP_US)]
    for _ in range(FRAMES):
        cmd += ["-S", SCANCODE]
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    mute()
```
Budget: ~40 ms Python start + ~10 ms `ir-ctl` + ~70 ms NEC frame ≈ 120 ms → under the 200 ms bar.
