# Decisions

Short records of the choices that shape the code. Format: context → decision → consequences → revisit when.

## D1 — The kernel makes the IR signal, not Python
Context: IR needs a 38 kHz carrier and pulse edges accurate to ~100 µs. User space on Linux can't promise
that, and on the Pi 5 every GPIO write crosses PCIe to the RP1 chip, adding latency and jitter.
Decision: use rc-core (`/dev/lirc0`) and let a kernel driver own the timing.
Consequences: one config.txt line, one reboot, and `ir-ctl` does the rest. No IR libraries in Python.
Revisit when: never, for IR.

## D2 — `pwm-ir-tx`, not `gpio-ir-tx`
Context: `gpio-ir-tx` bit-bangs the carrier from a kernel thread; users report it failing outright on
newer boards and it burns CPU. `pwm-ir-tx` lets hardware PWM make the carrier and only gates it; since
Linux 6.8 it drives edges from an hrtimer (backported to Raspberry Pi's 6.6 kernels).
Decision: `dtoverlay=pwm-ir-tx,gpio_pin=12,func=4` (GPIO12 = physical pin 32; see D9 — GPIO18
looks right and silently does not work on a Pi 5).
Consequences: ties us to a PWM-capable pin on PWM channel 0, which on the Pi 5 means GPIO12. Open question on Pi 5: whether the RP1 PWM driver
can be used from atomic context; dmesg says ("TX will not be accurate as PWM device might sleep" = the
driver fell back to its sleeping path). NEC-family protocols are tolerant either way.
Revisit when: sends are flaky with good aim — check kernel version and dmesg before anything else.

## D3 — `ir-ctl` CLI, not LIRC ioctls from Python
Context: `ir-ctl` already encodes every protocol we care about and sets the carrier per protocol.
Decision: `mute()` shells out. ~10 ms of process overhead is nothing next to a 67 ms NEC frame.
Consequences: `v4l-utils` is a runtime dependency. Budget ≈ 40 ms Python + 10 ms ir-ctl + 70 ms frame.
Revisit when: a long-running daemon (phase 4) wants to avoid fork cost — it can still call `ir-ctl`.

## D4 — Look codes up; don't record them (yet)
Context: the KY-005 has no receiver, so we can't capture the real remote.
Decision: brand → table / irdb / LIRC db → convert to Linux scancode (IR-CODES §1) → VOL+ then MUTE.
Consequences: care needed converting web hex; some brands (Panasonic) need raw frames.
Revisit when: two well-sourced candidates fail → buy a receiver (TSOP38238 / Adafruit 5990) and record.

## D5 — Bare LED + resistor tonight; driver transistor later
Context: ~10 mA from a 3.3 V GPIO ≈ 1 m of range. A transistor from 5 V gives 5–10× the current.
Decision: accept 1 m and an 18/20 bar for phase 1. The resistor is non-negotiable.
Consequences: aim and distance matter during tests; misses at 1 m are hardware findings.
Revisit when: the box has to live anywhere but right next to the TV.

## D6 — `mute()` is exactly one key press, and it's a toggle
Context: TVs expose MUTE over IR as a toggle. A "retry" un-mutes. A missed frame means the box's belief
about the TV's state is wrong.
Decision: one frame per call (three for Sony, which is one press by that protocol's rules). No retries.
No state tracking in phase 1.
Consequences: phase 1 cannot know whether the TV is muted. That's phase 5 (mic level / HDMI-CEC status).
Revisit when: phase 5.

## D7 — IR first; HDMI-CEC and network APIs later
Context: CEC and TV network APIs are stateful (set mute, read status) and need no line of sight — better
long term. But they're per-brand, need pairing, and CEC needs the Pi on an HDMI input.
Decision: IR is the universal fallback and the fastest path to a working demo.
Consequences: keep `mute()` the only entry point so the backend can be swapped underneath it.
Revisit when: phase 5/6.

## D8 — Phase gating
Decision: nothing beyond phase 1 gets built tonight. Ideas go to NOTES.md via `/park`.
Revisit when: the definition of done is met and committed.

## D9 — GPIO12 (physical pin 32), not GPIO18, for the IR LED on a Pi 5
Context: `pwm-ir-tx`'s device tree hardcodes `pwms = <&pwm 0 100 0>` — PWM channel 0 — and exposes
only `gpio_pin` and `func` as parameters. On a Pi 4, GPIO18 is channel 0. On the Pi 5's RP1,
GPIO12 is channel 0 and GPIO18 is channel 2.
Decision: wire the LED to GPIO12 / physical pin 32 and load
`dtoverlay=pwm-ir-tx,gpio_pin=12,func=4`.
Consequences: we diverge from every web guide, which assumes Pi 4 and says GPIO18. The failure
mode when you follow them is silent: `/dev/lirc0` appears, `pinctrl` shows a PWM function,
`ir-ctl` exits 0, and nothing is emitted. Cost us an evening (TROUBLESHOOTING T11).
Rejected alternative: patch the overlay to channel 2 and keep GPIO18 — a local `.dtbo` to compile
and maintain, which a firmware update can supersede without warning. One jumper is cheaper.
Revisit when: the pin is needed for something else, or an upstream overlay gains a channel param.

## D10 — Measure IR reliability with VOL±, never by counting mute toggles
Context: mute has no on-screen number, its icon is brief, and on quiet content a toggle is
inaudible. Two measurements of the same emitter at the same distance disagreed 10/10 vs 5/20
purely because of the instrument (TROUBLESHOOTING T12).
Decision: all hit-rate and range measurements use N × VOL+ (or VOL−) and the volume delta.
Mute gets a single press to confirm it works, and nothing more.
Consequences: the definition of done still counts mute toggles (BRINGUP §9), so treat a failing
score as suspect until VOL± from the same position agrees with it.
Revisit when: a receiver is on the bench and can count our own frames directly, which beats
both instruments.

