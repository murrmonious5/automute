# TV details

## The TV
- Brand: LG
- Model: 65UQ7570PUJ (65" UQ7570 series, 2022)
- Platform: webOS 22, a5 Gen5 AI processor
- IR receiver: bottom center of the frame, near the LG logo

## Remote
- Stock remote for this series is a basic IR remote (replacement part AKB76040303)
- If using a Magic Remote (AN-MR22GA): it sends IR when the TV is off and
  switches to Bluetooth when the TV is on. The TV still accepts IR either way.

## IR codes (LG NEC, device 0x04)
All sent once per press. Mute is a toggle.

**Verified against the actual TV 2026-09-19 ~00:10** — VOL+, VOL− and MUTE all confirmed at
20–30 cm with the emitter on GPIO12 (physical pin 32). These codes were correct from the first
attempt; hours of apparent "wrong code" symptoms were a dead transmitter (TROUBLESHOOTING T11).

| Key   | rc-core (ir-ctl) | 32-bit hex (web/Arduino) |
|-------|------------------|--------------------------|
| Mute  | nec:0x0409       | 0x20DF906F               |
| Vol+  | nec:0x0402       | 0x20DF40BF               |
| Vol-  | nec:0x0403       | 0x20DFC03F               |
| Power | nec:0x0408       | 0x20DF10EF               |

Conversion: the 32-bit form is LSB-first. Bit-reverse byte 1 for the address
(0x20 -> 0x04) and byte 3 for the command (0x90 -> 0x09).

## Test commands (on the Pi, after pwm-ir-tx is enabled on GPIO12 / physical pin 32)
    ir-ctl -d /dev/lirc0 -S nec:0x0402   # vol up, test this first
    ir-ctl -d /dev/lirc0 -S nec:0x0409   # mute

## Sources
- LG product page: https://www.lg.com/us/tvs/lg-65uq7570pu-4k-uhd-tv
- LG IR table (captured codes): https://gist.github.com/TheGroundZero/74035123938ecb13c8864ff1e65dc4d3
