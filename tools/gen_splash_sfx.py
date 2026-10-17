#!/usr/bin/env python3
"""Synthesise the sounds of the studio splash: the UNDO LABS neon on the cabin wall.

Same recipe as tools/gen_sfx.py: oscillators and filtered noise at 22050 Hz / 16-bit
mono, deterministic. The power cut itself is the game's own power_out.mp3 and the
night is cricketi.mp3; only the neon is made here.

    python tools/gen_splash_sfx.py   -> godot/assets/sfx/splash/*.wav

  neon_hum.wav      seamless 2 s loop: the ballast's 100 Hz hum, a little clipped, and
                    the gas sizzle pulsing with the mains
  neon_tick_1..3    the starter: a dry click and a short zap (one per blink of a tube)
  neon_strike.wav   a tube catching: a pop, a swell of buzz that settles into the hum
  neon_sputter.wav  a bad tube dropping out: irregular crackle
  moth_tap.wav      a moth bumping into the glass
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "splash")


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


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return lowpass(highpass(x, low), high)


def buzz(n, t0=0.0, seed=1, drive=2.2):
    """The ballast: 100 Hz (twice the 50 Hz mains) with odd/even harmonics, soft-clipped,
    plus sizzle that pulses with each half-cycle of the mains."""
    t = t0 + np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 100 * t) * 0.55
        + np.sin(2 * np.pi * 200 * t + 0.4) * 0.30
        + np.sin(2 * np.pi * 300 * t + 1.1) * 0.18
        + np.sin(2 * np.pi * 400 * t + 2.0) * 0.10
        + np.sin(2 * np.pi * 600 * t + 0.7) * 0.05)
    hum = np.tanh(hum * drive) / np.tanh(drive)
    rng = np.random.default_rng(seed)
    sizzle = bandpass(rng.standard_normal(n), 2600, 7500)
    pulse = np.abs(np.sin(2 * np.pi * 50 * t)) ** 6
    return hum * 0.16 + sizzle * pulse * 0.11


def click(rng, length=0.008, bright=3200):
    n = int(length * SR)
    return highpass(rng.standard_normal(n), bright) * np.exp(-np.linspace(0, 9, n))


def neon_hum_loop():
    n = int(2.0 * SR)
    rng = np.random.default_rng(4)
    t = np.arange(n) / SR
    # sizzle from one 2 s noise buffer band-limited in the FFT, so it is circular too
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec[(freqs < 2600) | (freqs > 7500)] = 0
    sizzle = np.fft.irfft(spec, n)
    sizzle /= np.max(np.abs(sizzle)) + 1e-9
    pulse = np.abs(np.sin(2 * np.pi * 50 * t)) ** 6
    core = (np.sin(2 * np.pi * 100 * t) * 0.55
        + np.sin(2 * np.pi * 200 * t + 0.4) * 0.30
        + np.sin(2 * np.pi * 300 * t + 1.1) * 0.18
        + np.sin(2 * np.pi * 400 * t + 2.0) * 0.10
        + np.sin(2 * np.pi * 600 * t + 0.7) * 0.05)
    core = np.tanh(core * 2.2) / np.tanh(2.2)
    # a slow, uneven waver of the gas (periodic in 2 s too)
    waver = 1.0 + 0.06 * np.sin(2 * np.pi * 0.5 * t) + 0.04 * np.sin(2 * np.pi * 1.5 * t + 1.0)
    return (core * 0.16 + sizzle * pulse * 0.30 * waver) * 0.95


def neon_tick(seed):
    rng = np.random.default_rng(seed)
    n = int(0.16 * SR)
    out = np.zeros(n)
    c = click(rng, 0.006, 2800) * 0.8
    out[: len(c)] += c
    # the zap: a short burst of buzz, a few ms after the click
    z0 = int(rng.uniform(0.004, 0.012) * SR)
    zn = int(rng.uniform(0.035, 0.07) * SR)
    z = buzz(zn, seed=seed + 10, drive=4.0) * 3.2
    z *= np.exp(-np.linspace(0, 4, zn))
    z[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    out[z0: z0 + zn] += z
    # a second, smaller click as the starter opens
    p = z0 + zn - int(0.004 * SR)
    c2 = click(rng, 0.004, 3600) * 0.35
    out[p: p + len(c2)] += c2
    return out * 0.85


def neon_strike():
    rng = np.random.default_rng(21)
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    pop = lowpass(rng.standard_normal(int(0.03 * SR)), 1800) * np.exp(-np.linspace(0, 6, int(0.03 * SR)))
    out[: len(pop)] += pop * 1.4
    b = buzz(n, seed=22, drive=3.0)
    swell = np.minimum(1.0, t / 0.03) * (0.55 + 1.6 * np.exp(-t / 0.09))
    fade = np.ones(n)
    fade[-int(0.2 * SR):] = np.linspace(1, 0, int(0.2 * SR))
    out += b * swell * fade * 1.6
    return out * 0.8


def neon_sputter():
    rng = np.random.default_rng(31)
    n = int(0.5 * SR)
    out = np.zeros(n)
    p = 0
    while p < n - int(0.03 * SR):
        zn = int(rng.uniform(0.008, 0.04) * SR)
        z = buzz(zn, seed=int(rng.integers(100, 999)), drive=5.0) * rng.uniform(1.5, 3.0)
        z *= np.exp(-np.linspace(0, rng.uniform(1, 5), zn))
        out[p: p + zn] += z
        c = click(rng, 0.003, 3000) * rng.uniform(0.2, 0.6)
        out[p: p + len(c)] += c
        p += zn + int(rng.uniform(0.004, 0.06) * SR)
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return out * 0.7


def moth_tap(seed):
    rng = np.random.default_rng(seed)
    n = int(0.05 * SR)
    out = np.zeros(n)
    for k in range(int(rng.integers(1, 3))):
        c = bandpass(rng.standard_normal(int(0.004 * SR)), 1800, 6000) * np.exp(-np.linspace(0, 7, int(0.004 * SR)))
        p = int(k * rng.uniform(0.012, 0.02) * SR)
        out[p: p + len(c)] += c * (0.5 if k else 1.0)
    return out * 0.5


def main():
    save("neon_hum.wav", neon_hum_loop())
    for i in range(1, 4):
        save("neon_tick_%d.wav" % i, neon_tick(i * 7))
    save("neon_strike.wav", neon_strike())
    save("neon_sputter.wav", neon_sputter())
    save("moth_tap.wav", moth_tap(41))


if __name__ == "__main__":
    main()
