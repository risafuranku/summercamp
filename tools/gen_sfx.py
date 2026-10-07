#!/usr/bin/env python3
"""Synthesise the enemy sound effects that have no recorded source.

Everything is built from oscillators and filtered noise at 22050 Hz / 16-bit mono, so
it sits with the game's lo-fi samples. Deterministic (fixed seeds).

    python tools/gen_sfx.py      -> godot/assets/sfx/npc/*.wav

  shutter.wav       mechanical camera shutter: two clicks and a short wind-on rattle
  flash_whine.wav   photo-flash capacitor charging: a rising whine that cuts off
  static_loop.wav   seamless loop of hiss with a slow, uneven amplitude crawl
  hum_loop.wav      seamless loop: a low, slightly detuned humming voice, no melody
  thump.wav         one heavy footfall on dirt with a wooden creak tail
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "npc")


def save(name, x):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32000).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, "%.2fs" % (len(x) / SR))


def env(n, attack, release):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, cutoff):
    # one-pole
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def click(rng, length=0.012, bright=4000):
    n = int(length * SR)
    noise = rng.standard_normal(n)
    return highpass(noise, bright) * np.exp(-np.linspace(0, 8, n))


def shutter():
    rng = np.random.default_rng(3)
    out = np.zeros(int(0.42 * SR))
    c1 = click(rng, 0.014, 2500) * 0.9
    c2 = click(rng, 0.018, 1800) * 0.7
    out[: len(c1)] += c1
    o2 = int(0.055 * SR)
    out[o2: o2 + len(c2)] += c2
    # wind-on rattle: a train of tiny clicks
    t0 = int(0.12 * SR)
    for k in range(9):
        c = click(rng, 0.006, 3000) * (0.35 - k * 0.03)
        p = t0 + int(k * 0.022 * SR)
        out[p: p + len(c)] += c
    return out * 0.9


def flash_whine():
    n = int(1.25 * SR)
    t = np.arange(n) / SR
    f = 1800 + 6200 * (t / t[-1]) ** 1.6
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) * 0.22 + np.sin(phase * 2.01) * 0.05
    x *= env(n, 0.08, 0.004)
    return x


def static_loop():
    rng = np.random.default_rng(11)
    n = int(4.0 * SR)
    noise = rng.standard_normal(n)
    hiss = highpass(lowpass(noise, 6000), 900)
    t = np.arange(n) / SR
    crawl = 0.55 + 0.3 * np.sin(2 * np.pi * t / 4.0) + 0.15 * np.sin(2 * np.pi * 3 * t / 4.0 + 1.3)
    # sparse crackles
    for _ in range(40):
        p = rng.integers(0, n - 200)
        hiss[p: p + 60] += rng.standard_normal(60) * 2.5
    x = hiss * crawl * 0.18
    # crossfade the ends for a seamless loop
    f = int(0.2 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return x[: n - f]


def hum_loop():
    n = int(6.0 * SR)
    t = np.arange(n) / SR
    base = 138.0
    drift = 1.0 + 0.012 * np.sin(2 * np.pi * t / 6.0)
    voice = np.zeros(n)
    for h, amp in [(1, 1.0), (2, 0.45), (3, 0.22), (4, 0.12), (5, 0.06)]:
        voice += amp * np.sin(2 * np.pi * base * h * np.cumsum(drift) / SR)
        voice += amp * 0.6 * np.sin(2 * np.pi * (base * 1.007) * h * np.cumsum(drift) / SR)
    breath = lowpass(np.random.default_rng(5).standard_normal(n), 900) * 0.25
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * t / 3.0 - 1.2) ** 2
    x = lowpass(voice * 0.12 + breath * 0.3, 1400) * swell
    f = int(0.3 * SR)
    x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f)
    return x[: n - f] * 0.9


def thump():
    rng = np.random.default_rng(7)
    n = int(1.1 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t * 9)
    dirt = lowpass(rng.standard_normal(n), 700) * np.exp(-t * 14) * 0.6
    creak = np.zeros(n)
    s = int(0.18 * SR)
    m = n - s
    ct = np.arange(m) / SR
    cf = 310 + 40 * np.sin(2 * np.pi * 2.3 * ct)
    creak[s:] = np.sign(np.sin(2 * np.pi * np.cumsum(cf) / SR)) * np.exp(-ct * 3) * 0.08
    creak = lowpass(creak, 1800)
    return (body * 0.9 + dirt + creak) * 0.8


if __name__ == "__main__":
    save("shutter.wav", shutter())
    save("flash_whine.wav", flash_whine())
    save("static_loop.wav", static_loop())
    save("hum_loop.wav", hum_loop())
    save("thump.wav", thump())
