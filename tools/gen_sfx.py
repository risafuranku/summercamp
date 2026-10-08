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

    -> godot/assets/sfx/uncanny/*.wav  (the radio station that does not exist)

  station_intro.wav  tuning noise into a carrier hum, a music-box phrase played twice
  station_pip.wav    one 1 kHz pip and its pause (the radio strings N of these)
  station_pip5.wav   the same pip with a longer pause: every fifth, like tally marks
  station_outro.wav  the phrase once more without its last note, then tuning noise
    -> godot/assets/sfx/ui/*.wav

  pager.wav          the belt pager: two short beeps from a tiny speaker (new mail)
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "npc")
OUT_UNCANNY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "uncanny")
OUT_UI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "ui")


def save(name, x, out=OUT):
    x = np.clip(x, -1.0, 1.0)
    data = (x * 32000).astype(np.int16)
    os.makedirs(out, exist_ok=True)
    with wave.open(os.path.join(out, name), "wb") as w:
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


# ── the station ──────────────────────────────────────────────────────────────

# A minor, a nursery-rhyme shape that does not resolve the way you expect.
PHRASE = [659.26, 523.25, 587.33, 493.88, 523.25, 440.00]
NOTE_GAP = 0.46


def carrier(seconds, seed):
    """The sound of a station with nobody talking: low hum and a little hiss."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    hum = np.sin(2 * np.pi * 50 * t) * 0.05 + np.sin(2 * np.pi * 100 * t) * 0.025
    hiss = highpass(np.random.default_rng(seed).standard_normal(n), 2500) * 0.012
    return hum + hiss


def tuning(seconds, seed, into_station):
    """Dial noise with a heterodyne whistle sweeping onto (or off) the frequency."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    noise = lowpass(np.random.default_rng(seed).standard_normal(n), 3800) * 0.22
    u = t / t[-1]
    f = 2400 - 2100 * u if into_station else 300 + 2100 * u
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.06
    level = (1.0 - u) if into_station else u
    return (noise + whistle) * (0.25 + 0.75 * level) * env(n, 0.03, 0.05)


def bell(freq, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t * 4.5)
    x += 0.35 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 9)
    x += 0.18 * np.sin(2 * np.pi * freq * 5.40 * t) * np.exp(-t * 15)
    return x * env(n, 0.002, 0.02) * 0.32


def phrase(drop_last=False):
    notes = PHRASE[:-1] if drop_last else PHRASE
    total = int((len(PHRASE) * NOTE_GAP + 1.2) * SR)
    out = np.zeros(total)
    for i, f in enumerate(notes):
        b = bell(f, 1.4)
        p = int(i * NOTE_GAP * SR)
        out[p: p + len(b)] += b[: max(0, min(len(b), total - p))]
    return out


def pip(pause):
    tone = int(0.16 * SR)
    t = np.arange(tone) / SR
    x = np.sin(2 * np.pi * 1000 * t) * 0.3 * env(tone, 0.005, 0.005)
    return np.concatenate([x, np.zeros(int(pause * SR))]) + carrier(0.16 + pause, 21)


def station_intro():
    return np.concatenate([
        tuning(1.5, 31, True),
        carrier(0.7, 32),
        phrase() + carrier(len(PHRASE) * NOTE_GAP + 1.2, 33),
        phrase() + carrier(len(PHRASE) * NOTE_GAP + 1.2, 34),
        carrier(1.4, 35),
    ])


def station_outro():
    return np.concatenate([
        carrier(1.6, 41),
        phrase(drop_last=True) + carrier(len(PHRASE) * NOTE_GAP + 1.2, 42),
        carrier(0.9, 43),
        tuning(1.3, 44, False),
    ])


def pager():
    beep = int(0.09 * SR)
    t = np.arange(beep) / SR
    tone = np.sign(np.sin(2 * np.pi * 2900 * t)) * 0.18 * env(beep, 0.002, 0.004)
    tone = lowpass(tone, 5000)
    gap = np.zeros(int(0.07 * SR))
    return np.concatenate([tone, gap, tone, np.zeros(int(0.1 * SR))])


if __name__ == "__main__":
    save("pager.wav", pager(), OUT_UI)
    save("station_intro.wav", station_intro(), OUT_UNCANNY)
    save("station_pip.wav", pip(0.46), OUT_UNCANNY)
    save("station_pip5.wav", pip(1.10), OUT_UNCANNY)
    save("station_outro.wav", station_outro(), OUT_UNCANNY)
    save("shutter.wav", shutter())
    save("flash_whine.wav", flash_whine())
    save("static_loop.wav", static_loop())
    save("hum_loop.wav", hum_loop())
    save("thump.wav", thump())
