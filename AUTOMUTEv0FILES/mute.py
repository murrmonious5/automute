#!/usr/bin/env python3
"""AutoMute phase 1 — send the TV's mute command over IR.

This is the interface every later phase calls. Detection code should import
mute() and nothing else. Keep this file small; the kernel does the hard part.

Usage:
    python3 mute.py          # send once
    python3 mute.py -n 3     # send three times (for debugging toggles)
"""

import subprocess
import sys
import time

# --- bench config -----------------------------------------------------------
# See IR_CODES.md for how to derive these. The scancode is the DECODED value,
# not the raw 32-bit frame from a remote-code website.
LIRC_DEVICE = "/dev/lirc0"
PROTOCOL = "nec"        # nec | necx | nec32 | sony12 | sony15 | rc5 ...
SCANCODE = "0x0409"     # LG mute (address 0x04, command 0x09) — CHANGE FOR YOUR TV
REPEATS = 1             # Sony/SIRC needs 3; NEC needs 1
REPEAT_GAP_S = 0.045    # SIRC frame period
# ----------------------------------------------------------------------------


def mute() -> bool:
    """Send one mute command. Returns True if ir-ctl reported success.

    Note this is a *toggle* on essentially every TV — calling it twice is a
    no-op from the viewer's perspective.
    """
    cmd = ["ir-ctl", "-d", LIRC_DEVICE, "-S", f"{PROTOCOL}:{SCANCODE}"]
    for i in range(REPEATS):
        if i:
            time.sleep(REPEAT_GAP_S)
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"ir-ctl failed: {result.stderr.strip()}", file=sys.stderr)
            return False
    return True


if __name__ == "__main__":
    count = 1
    if len(sys.argv) == 3 and sys.argv[1] in ("-n", "--count"):
        count = int(sys.argv[2])

    ok = True
    for i in range(count):
        if i:
            time.sleep(0.5)
        ok = mute() and ok
    sys.exit(0 if ok else 1)
