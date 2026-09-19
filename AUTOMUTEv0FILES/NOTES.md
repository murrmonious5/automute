# NOTES — parking lot

Ideas land here so they stop competing with phase 1. **Nothing in this file
gets built yet.** If an agent finds itself implementing something from this
page, it has wandered off task.

Format: one line, plus why it's deferred.

## Actuation

- **NPN transistor driver off 5 V** for the IR LED. Fixes the ~1 m range limit.
  Deferred: range isn't the blocker until the thing lives near the TV rather
  than on the bench.
- **HDMI-CEC instead of IR.** CEC has an explicit "set mute" vs "toggle mute",
  which kills the whole class of "did it fire twice?" bugs. Deferred: needs the
  Pi on the TV's HDMI input, which conflicts with the debug display.
- **TV vendor network API** (LG WebOS, Samsung, Roku ECP). Same non-toggle
  advantage, no line of sight needed. Deferred: brand-specific, and IR is the
  universal fallback we need anyway.

## Sensing

- **Pi Camera Module 3** pointed at the screen. Framing/mounting is its own
  small problem.
- **USB microphone** as a verification channel — confirm the TV actually went
  quiet rather than assuming the IR landed. Closes the loop, probably the single
  highest-value addition after detection works.

## Detection

- **Tiered approach**: cheap heuristics first (cut rate, logo presence, aspect
  ratio, audio loudness), escalate to a model only when the heuristic is
  uncertain.
- **Cloud validation first**: prove the detection loop with Claude Haiku on
  sampled frames before committing to on-device inference. Optimising an
  approach that doesn't work yet is the classic trap here.
- **On-device small VLM**: SmolVLM or Moondream once the cloud version proves
  the concept and the latency budget is understood.
- **CLIP embeddings fine-tuned per channel** as the long-term cheap classifier.
- **Hysteresis state machine** around whatever the classifier says. A single
  frame must never trigger a mute; ads and content both have ambiguous frames.
  Unmute needs to be faster and more eager than mute — a late unmute is much
  more annoying than a late mute.

## Hardware expansion

- **Pi AI HAT+** for on-device inference. Deferred until detection is proven and
  we know whether we're even compute-bound.
- **Enclosure** — the small unobtrusive black square. Deferred: dimensions
  depend on what's inside, which isn't settled.

## Open questions

- Latency budget end to end. How many hundred ms between "ad starts" and "muted"
  before it stops feeling magic?
- What happens when someone mutes manually? The device shouldn't fight the human.
- Per-channel calibration: does it need to know what's on, or can it stay
  channel-agnostic?
