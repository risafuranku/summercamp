#!/usr/bin/env python3
"""Little sounds made here, no API (the ElevenLabs key can only speak):
  - the walkie-talkie's and the megaphone's (scripts/coop/voice.gd): the squelch going on
    and off (a click, a burst of hiss, the roger beep), the megaphone's switch and its
    feedback whine -> godot/assets/sfx/radio/{radio_on,radio_off,megaphone_on,megaphone_off}.wav;
  - the orange validator's cvak on the 380 (scripts/town/punch_closeup.gd): the solenoid's
    hard metal click, the thunk, the paper punched, the spring letting go
    -> godot/assets/sfx/bus/ticket_punch.wav.

    python tools/audiogen/synth_sfx.py
"""
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "radio")
SR = 22050
rng = np.random.default_rng(380)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.linspace(1, 0, r)
    return e


def band(x, lo, hi):
    """A crude band-pass: FFT, keep lo..hi Hz."""
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f[(freqs < lo) | (freqs > hi)] = 0
    return np.fft.irfft(f, len(x))


def click(sec=0.012, amp=0.6):
    n = int(SR * sec)
    return amp * rng.uniform(-1, 1, n) * np.linspace(1, 0, n) ** 3


def hiss(sec, amp, lo=900, hi=5200):
    x = band(rng.uniform(-1, 1, int(SR * sec)), lo, hi)
    x /= np.max(np.abs(x)) + 1e-9
    return amp * x * env(len(x), 0.004, sec * 0.6)


def tone(freq, sec, amp):
    return amp * np.sin(2 * np.pi * freq * t(sec)) * env(int(SR * sec), 0.004, 0.02)


def save(name, x, out=OUT):
    os.makedirs(out, exist_ok=True)
    x = np.clip(x, -1, 1)
    with wave.open(os.path.join(out, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    print("wrote", name, round(len(x) / SR, 2), "s")


def main():
    gap = np.zeros(int(SR * 0.01))
    save("radio_on.wav", np.concatenate([click(), gap, hiss(0.16, 0.35)]))
    save("radio_off.wav", np.concatenate([tone(1250, 0.07, 0.3), np.zeros(int(SR * 0.03)), tone(980, 0.06, 0.25),
                                          hiss(0.22, 0.45), click(0.01, 0.4)]))
    # The megaphone: its switch, and the horn howling for a moment as it opens.
    whine_t = t(0.32)
    whine = 0.22 * np.sin(2 * np.pi * (2300 + 60 * np.sin(2 * np.pi * 7 * whine_t)) * whine_t)
    whine *= env(len(whine), 0.08, 0.16)
    save("megaphone_on.wav", np.concatenate([click(0.015, 0.7), whine + hiss(0.32, 0.08, 1500, 4000)]))
    save("megaphone_off.wav", np.concatenate([click(0.015, 0.6), hiss(0.12, 0.12, 800, 3000)]))
    punch()


def ring(freq, sec, amp, decay):
    tt = t(sec)
    return amp * np.sin(2 * np.pi * freq * tt) * np.exp(-tt * decay)


def punch():
    """The validator: cvak, and the spring back."""
    x = np.zeros(int(SR * 0.42))

    def put(sound, at_sec):
        at = int(SR * at_sec)
        x[at:at + len(sound)] += sound[:max(0, len(x) - at)]

    # The hammer: a hard broadband click with a metal ring, the body's low thunk.
    put(click(0.006, 0.9), 0.0)
    put(ring(3150, 0.09, 0.35, 70), 0.0)
    put(ring(4700, 0.05, 0.18, 110), 0.0)
    put(ring(170, 0.12, 0.6, 38), 0.0)
    put(ring(95, 0.14, 0.3, 30), 0.0)
    # The card punched through: a short dry crunch.
    put(hiss(0.035, 0.28, 1800, 7000), 0.004)
    # The hammer let go: a smaller click and a tinny spring.
    put(click(0.004, 0.45), 0.16)
    put(ring(2600, 0.06, 0.16, 90), 0.16)
    put(ring(5200, 0.04, 0.06, 140), 0.16)
    save("ticket_punch.wav", x * 0.9, os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "bus"))


if __name__ == "__main__":
    main()
