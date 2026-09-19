# Finding and encoding the TV's mute code

We have no IR receiver, so we can't record the real remote. The code has to be
looked up by brand and verified by pointing at the TV and watching it mute.

## The format `ir-ctl` actually wants

```
ir-ctl -d /dev/lirc0 -S <protocol>:<scancode>
```

The scancode is **not** the 32-bit raw frame you'll find on remote-code
websites. Those sites quote the full NEC frame including the inverted check
bytes, e.g. LG mute as `0x20DF906F`. `ir-ctl` wants the *decoded* scancode and
rebuilds the check bytes itself.

Scancode widths by protocol:

| Protocol keyword | Scancode | Layout |
|---|---|---|
| `nec` | 16-bit | `addr << 8 \| cmd` |
| `necx` | 24-bit | `addr16 << 8 \| cmd` (extended address) |
| `nec32` | 32-bit | full, no inversion assumed |
| `sony12` | 12-bit | `device << 7 \| cmd` |
| `sony15` | 15-bit | `device << 7 \| cmd` |
| `rc5` | 13-bit | `addr << 6 \| cmd` |

Pass the wrong width and `ir-ctl` will either reject it or silently encode
something the TV ignores. That failure looks identical to broken hardware,
which is why this page exists.

## Converting a raw NEC frame to a scancode

NEC transmits **LSB first**, so each byte of the raw frame is bit-reversed
relative to the logical value. Worked example, LG mute `0x20DF906F`:

```
0x20DF906F
  ├ 0x20 → reverse bits → 0x04   address
  ├ 0xDF → reverse bits → 0xFB   = ~0x04  (check byte, ir-ctl regenerates it)
  ├ 0x90 → reverse bits → 0x09   command
  └ 0x6F → reverse bits → 0xF6   = ~0x09  (check byte)

→ address 0x04, command 0x09  →  nec:0x0409
```

Quick check in Python:

```python
rev = lambda b: int(f"{b:08b}"[::-1], 2)
raw = 0x20DF906F
a, ai, c, ci = (raw >> 24) & 0xFF, (raw >> 16) & 0xFF, (raw >> 8) & 0xFF, raw & 0xFF
addr, cmd = rev(a), rev(c)
assert rev(ai) == (~addr & 0xFF) and rev(ci) == (~cmd & 0xFF), "not plain NEC — try necx/nec32"
print(f"nec:0x{addr:02x}{cmd:02x}")
```

If that assertion fails, the frame isn't plain 8-bit NEC — it's extended
(`necx`, 16-bit address, only the command byte is inverted) or something else
entirely. Samsung is the common `necx` case.

## Starting points by brand

Confidence column matters. "Derived" means decoded from a widely-quoted raw
frame using the method above; it's still unverified until it mutes a real TV.

| Brand | Try first | Confidence | Notes |
|---|---|---|---|
| LG | `nec:0x0409` | Derived from `0x20DF906F` | Most LG TVs, incl. recent WebOS |
| Samsung | `necx:0x07070f` | Derived from `0xE0E0F00F` | Extended addr `0x0707`, cmd `0x0F` |
| Sony | `sony12:0x94` | Derived (device 1, cmd `0x14`) | **Must be sent 3× in a row.** Try `sony15` if 12 fails |
| Vizio | `nec:0x0409` then `nec:0x2040` | Unverified | Vizio overlaps with LG on some models |
| TCL / Roku TV | — | Unknown | Look it up on-device, see below |
| Hisense | — | Unknown | Look it up on-device, see below |

Don't let an agent invent a row for a brand that isn't here. Use the lookup
procedure instead.

## Looking it up on the Pi itself

`v4l-utils` ships the kernel's remote keymaps, which are real scancodes rather
than forum guesses:

```bash
ls /lib/udev/rc_keymaps/                      # all shipped keymaps
grep -ril "KEY_MUTE" /lib/udev/rc_keymaps/    # every keymap with a mute key
grep -i -A2 -B2 "KEY_MUTE" /lib/udev/rc_keymaps/<brand>*.toml
```

Each keymap declares its protocol at the top and lists `scancode = "KEY_NAME"`
pairs. That scancode goes straight into `ir-ctl -S` with the declared protocol.
This is the source of truth to prefer over any website.

`ir-keytable` also lists which protocols the kernel has loaded.

## Test procedure

1. Confirm the LED is physically firing: point a phone camera at it while
   sending. Most phone sensors see 940 nm as a faint purple/white flicker.
   **No flicker = electrical or overlay problem, not a wrong code.** Go to
   `TROUBLESHOOTING.md` before trying more codes.
2. Stand ~1 m away, clear line of sight, aim at the TV's IR window.
3. Send. If nothing, try the brand's other protocol before touching hardware.
4. Remember mute is a *toggle* on almost every TV — if it fires twice you see
   nothing. Send once, look, then send again.

## Verified codes

Append here the moment something works. Include the TV so the other bench knows
whether it applies to them.

| Date | TV (brand / model) | Protocol:scancode | Repeats | Bench |
|---|---|---|---|---|
| | | | | |
