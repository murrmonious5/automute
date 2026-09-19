# Bring-up runbook — phase 1

One step, one check. Don't skip checks; don't batch steps. Anything marked **(sudo)**
is ask-before-run: say what it changes, wait for a yes.

`$` = run as the normal user · **expect** = what success looks like · ↪ = where to go if not.
`/bringup-status` collects steps 0 and 3 in one shot.

## 0. Baseline (read-only)
```
$ cat /proc/device-tree/model        expect  Raspberry Pi 5 Model B Rev …
$ uname -r                           expect  6.12.x or newer (6.6.x is probably fine, see below)
$ which ir-ctl ir-keytable pinctrl   expect  three paths (ir-ctl/ir-keytable arrive in step 1)
$ id                                 expect  groups include "video" (owner group of /dev/lirc0)
$ ls -l /dev/lirc0                   expect  "No such file" until step 2 — that's normal
```
Why the kernel version matters: `pwm-ir-tx` gained precise hrtimer-driven edges in Linux 6.8
(backported to Raspberry Pi's 6.6 line). Older kernels made it flaky. Below 6.6 → stop and
`sudo apt update && sudo apt full-upgrade` first **(sudo)**, then reboot.

## 1. Tools **(sudo)**
```
$ sudo apt install -y v4l-utils ir-keytable
$ ir-ctl --version
```
`v4l-utils` ships `ir-ctl`; `ir-keytable` is a separate Debian package.

## 2. Enable the transmitter **(sudo, then reboot)**
First make sure nothing else claims GPIO12 or an IR overlay:
```
$ grep -n -E '^dtoverlay=(pwm|gpio)-ir|^dtoverlay=pwm|^dtoverlay=i2s' /boot/firmware/config.txt
```
**expect** no output. Then append to the very END of `/boot/firmware/config.txt` — after the
`[all]` line, never under `[pi4]` / `[cm4]` / `[cm5]`:
```
# AutoMute: kernel IR transmitter on GPIO12 = PHYSICAL PIN 32 (not pin 12!)
dtoverlay=pwm-ir-tx,gpio_pin=12,func=4
```
**Use GPIO12, not the GPIO18 every web guide gives you.** `pwm-ir-tx` hardcodes PWM channel 0;
on the Pi 5's RP1 that is GPIO12. With `gpio_pin=18` the pin muxes to channel 2, the driver keeps
driving channel 0, and every send succeeds while emitting nothing. This is TROUBLESHOOTING T11 and
it is the single most expensive trap in this build.
e.g. `printf '\n# AutoMute: kernel IR transmitter on GPIO12 (physical pin 32)\ndtoverlay=pwm-ir-tx,gpio_pin=12,func=4\n' | sudo tee -a /boot/firmware/config.txt`
then `sudo reboot`. (Bookworm's config file is `/boot/firmware/config.txt`; `/boot/config.txt` is a decoy.)

## 3. Verify the device (read-only)
```
$ ls -l /dev/lirc0                   expect  crw-rw---- 1 root video … /dev/lirc0
$ ir-keytable                        expect  Found /sys/class/rc/rc0/ … Name: PWM IR Transmitter … Driver: pwm-ir-tx … LIRC device: /dev/lirc0
$ ir-ctl -d /dev/lirc0 -f            expect  "Device cannot receive" · "Device can send raw IR" · "Set carrier" (duty cycle too)
$ pinctrl get 12                     expect  a0 pd | lo // GPIO12 = PWM0_CHAN0 — CHAN0 specifically,
                                             not just "a PWM function"; CHAN2 means the wrong pin (T11)
$ dmesg | grep -i -E 'pwm-ir|lirc|rc rc'      (if refused: sudo dmesg … — ask first)
```
Two acceptable dmesg outcomes:
- rc0 / lirc0 registered, nothing else → the driver is on its precise (hrtimer) path. Best case.
- also `pwm-ir-tx … TX will not be accurate as PWM device might sleep` → the RP1 PWM driver on
  this kernel can't be driven from atomic context, so the driver fell back to its older sleeping
  path. NEC / Samsung / Sony have generous timing tolerances; proceed, but remember this if sends
  are flaky (TROUBLESHOOTING T6). This is a Pi 5 / RP1-specific unknown — test, don't assume.

↪ anything missing: TROUBLESHOOTING T1–T3.

## 4. Prove the LED lights (phone camera)
Point a phone camera at the KY-005 — the **front** camera works best; many rear cameras have strong
IR-cut filters. Dim the room, 5–10 cm away. Send something no TV listens to:
```
$ for i in $(seq 10); do ir-ctl -d /dev/lirc0 -S rc5:0x1e01; sleep 0.2; done     # Hauppauge PC-tuner remote, key "1"
```
**expect** a faint purple/white flicker for ~3 s. `ir-ctl -v -S rc5:0x1e01` prints the exact
pulse/space list being sent, which is worth seeing once.
↪ no flicker: TROUBLESHOOTING T4.

**No flicker does not mean a dead LED.** This burst is often invisible to a phone camera (67 ms
frames, one-third duty). Prove the LED with steady DC light before suspecting the wiring:
```
$ pinctrl set 18 op dh     # LED on solid — look now
$ pinctrl set 18 a3        # restore the PWM function when done
```
Verified on bench 2026-09-18: the modulated burst showed nothing, DC-on showed bright purple on the
same phone. Full version, including a blink loop for loose jumpers: TROUBLESHOOTING T4 item 7.

## 5. Identify the TV, pick two codes
Ask for brand + model. `/find-code <brand> <model>` → IR-CODES.md gives a VOL+ test code and
MUTE candidates in `ir-ctl` form. VOL+ first: it's visible, harmless and proves the TV hears us.

## 6. First contact: VOL+
From ~1 m, LED axis pointed at the TV's IR window (usually a dark dot on the bottom bezel —
find it in the manual or by looking for the remote's "sweet spot"):
```
$ ir-ctl -d /dev/lirc0 -S <VOL+ code>
```
**expect** the volume bar ticks up one step. One send, wait 3 s, look. At most 3 candidates,
then ↪ TROUBLESHOOTING T5.

## 7. MUTE
```
$ ir-ctl -d /dev/lirc0 -S <MUTE code>                                  # Sony: -S c -S c -S c --gap 25000
```
**expect** the mute icon. Wait 3 s, send once more → un-mutes. Never send twice "to make sure":
the second frame is a second press and un-mutes (IR-CODES §4).

## 8. mute.py
Write `mute.py` from the template in IR-CODES §7 with the winning `SCANCODE` (and `FRAMES = 3`
for Sony). `python3 mute.py` → toggles. Commit.

## 9. Definition of done (`/test-mute`)
1. From ~1 m: `for i in $(seq 20); do echo "run $i"; python3 mute.py; sleep 3; done` — a human counts
   toggles. Pass ≥ 18/20. (20 is even → the TV ends where it started.)
2. `time python3 mute.py` → `real` well under 0.200 s (run twice, take the second).
3. Camera flicker visible during a send.
Log the result below and commit.

## Results log
| date | TV (brand/model) | code | frames | 20-run score | `real` time | notes |
|------|------------------|------|--------|--------------|-------------|-------|
| 2026-09-19 | LG 65UQ7570PUJ | `nec:0x0409` | 1 | not yet run | 0.102 s | First contact after moving the LED from GPIO18 (pin 12) to GPIO12 (pin 32) — T11. VOL+/VOL−/MUTE all confirmed at 20–30 cm, single MUTE press showed the icon. 20-run score and range envelope still to do. |
| 2026-09-19 | LG 65UQ7570PUJ | `nec:0x0409` | 1 | 7/20, 8/20 @ 20–30 cm; 2/10 @ 3 in | 0.102 s | **Faulty KY-005.** Missing at 3 inches ruled out range; module swap fixed it (T12a). |
| 2026-09-19 | LG 65UQ7570PUJ | `nec:0x0402/3` | 1 | 10/10 @ 3 in · 10/10 @ 1 m · ~5/10 @ 5 m | — | Second KY-005, measured with the volume instrument (T12b). This is the real range envelope. |
| 2026-09-19 | LG 65UQ7570PUJ | `nec:0x0409` | 1 | 5/20 @ 1 m · 3/6 @ 2 m | — | Mute-toggle counts, same emitter and distance as the 10/10 above. Instrument disagreement unresolved — see D10. DoD #1/#2 NOT passed. |

