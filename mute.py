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
