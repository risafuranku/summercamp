#!/usr/bin/env python3
"""The office telephone's own sounds, synthesised (22050 Hz / 16-bit mono, like
tools/gen_sfx.py). Czech exchange tones of the 1990s: everything on 425 Hz.

    python tools/gen_phone_sfx.py   -> godot/assets/sfx/phone/*.wav

  dialtone.wav    the continuous dial tone (seamless loop, 2 s)
  dtmf_<k>.wav    a key: its two DTMF frequencies, 0.13 s (k = 0-9, star, hash)
  ringback.wav    one ring heard down the line: 1 s tone, 4 s quiet
  busy.wav        engaged: 0.33 s on, 0.33 s off (seamless loop)
  dead.wav        the line gone: slow 425 Hz beeps after a hang-up (seamless loop)
  sit.wav         "not in service": three rising tones
  lift.wav        the handset off the cradle: a plastic clack and the hook switch
  hangup.wav      the handset dropped back: a heavier clack and a bell tick
  ring.wav        the office phone's own bell: one double ring (for omens/incoming)
  line_hiss.wav   a seamless loop of line noise under a call
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "phone")
rng = np.random.default_rng(7)


def save(name, x):
    x = np.clip(x, -1.0, 1.0)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    print(name, "%.2fs" % (len(x) / SR))


def t(sec):
    return np.arange(int(sec * SR)) / SR


def tone(freq, sec, amp=0.3):
    return amp * np.sin(2 * np.pi * freq * t(sec))


def ramp(x, a=0.004, r=0.004):
    n = len(x)
    e = np.ones(n)
    ai, ri = max(1, int(a * SR)), max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, ai)
    e[-ri:] *= np.linspace(1, 0, ri)
    return x * e


def band(x):
    """A telephone line: roughly 300-3400 Hz, a little crushed."""
    # crude: high-pass by differencing a low-passed copy, then soft clip
    lp = np.copy(x)
    a = np.exp(-2 * np.pi * 3400 / SR)
    for i in range(1, len(lp)):
        lp[i] = (1 - a) * lp[i] + a * lp[i - 1]
    hp = np.copy(lp)
    b = np.exp(-2 * np.pi * 300 / SR)
    low = 0.0
    for i in range(len(hp)):
        low = (1 - b) * hp[i] + b * low
        hp[i] = hp[i] - low
    return np.tanh(hp * 1.6) / 1.6


def hiss(sec, amp):
    return band(rng.normal(0, amp, int(sec * SR)))


# The loop lengths are whole periods of 425 Hz (425 * 2 s = 850 cycles).
save("dialtone.wav", band(tone(425, 2.0, 0.32)) + hiss(2.0, 0.004))

DTMF = {"1": (697, 1209), "2": (697, 1336), "3": (697, 1477), "4": (770, 1209), "5": (770, 1336),
        "6": (770, 1477), "7": (852, 1209), "8": (852, 1336), "9": (852, 1477), "star": (941, 1209),
        "0": (941, 1336), "hash": (941, 1477)}
for k, (lo, hi) in DTMF.items():
    save("dtmf_%s.wav" % k, band(ramp(tone(lo, 0.13, 0.2) + tone(hi, 0.13, 0.17))))

ring = np.concatenate([ramp(tone(425, 1.0, 0.26), 0.01, 0.01), np.zeros(int(4.0 * SR))])
save("ringback.wav", band(ring) + hiss(5.0, 0.004))
busy = np.concatenate([ramp(tone(425, 0.33, 0.3), 0.005, 0.005), np.zeros(int(0.33 * SR))])
save("busy.wav", band(busy))
dead = np.concatenate([ramp(tone(425, 0.17, 0.22), 0.005, 0.005), np.zeros(int(0.53 * SR))])
save("dead.wav", band(dead))
sit = np.concatenate([ramp(tone(f, 0.33, 0.24), 0.006, 0.006) for f in (950, 1400, 1800)] + [np.zeros(int(0.4 * SR))])
save("sit.wav", band(sit))


def clack(sec, body_hz, amp, decay):
    n = int(sec * SR)
    x = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (decay * SR))
    x += 0.6 * np.sin(2 * np.pi * body_hz * t(sec)) * np.exp(-np.arange(n) / (decay * 2.0 * SR))
    return amp * x


lift = np.concatenate([clack(0.06, 420, 0.5, 0.008), np.zeros(int(0.05 * SR)), clack(0.05, 900, 0.25, 0.004)])
save("lift.wav", lift)
hang = np.concatenate([clack(0.09, 300, 0.7, 0.012), np.zeros(int(0.03 * SR))])
bell_tick = 0.08 * np.sin(2 * np.pi * 1800 * t(0.25)) * np.exp(-t(0.25) * 18)
hang = np.concatenate([hang, bell_tick])
save("hangup.wav", hang)


def bell(sec):
    # A mechanical bell: a hammer at ~20 Hz on two detuned metal partials.
    x = np.zeros(int(sec * SR))
    for i in range(int(sec * 20)):
        s = int(i / 20 * SR)
        n = min(len(x) - s, int(0.12 * SR))
        if n <= 0:
            break
        tt = np.arange(n) / SR
        strike = (np.sin(2 * np.pi * 1180 * tt) + 0.7 * np.sin(2 * np.pi * 1630 * tt) + 0.3 * np.sin(2 * np.pi * 2400 * tt)) * np.exp(-tt * 30)
        x[s:s + n] += 0.12 * strike
    return np.tanh(x * 2.0) / 2.0


double = np.concatenate([bell(0.4), np.zeros(int(0.2 * SR)), bell(0.4), np.zeros(int(2.0 * SR))])
save("ring.wav", double)
save("line_hiss.wav", hiss(3.0, 0.012))
