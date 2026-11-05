#!/usr/bin/env python3
"""What gets into your head when you run for your life (the user 5. 11.: "no flashing faces:
when you are already running, ringing in the ears, voices, bangs, a schizo fever dream").
scripts/audio/fever_dream.gd plays these, a side at a time, more of them the worse it is:

    ring.ogg        the ears: two high tones and a narrow hiss beating, a seamless loop
    voice_NN.ogg    splinters of the night's own voices (the radio's dread, the hells, the
                    second voice, the illusions): cut, backwards, pitched, stuttered
    thud_NN.ogg     blows you feel more than hear: a door in the skull, a body on boards

    python tools/audiogen/fever_dream.py

Then `python tools/audiogen/normalize.py 'assets/sfx/fever/*.ogg' --lufs -20` is not needed:
this writes them levelled by RMS itself. Seeded: the same files every run.
"""
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
OUT = os.path.join(GODOT, "assets", "sfx", "fever")
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100
RNG = np.random.default_rng(1905)

SOURCES = ["radio_dread/f_count.wav", "radio_dread/f_count2.wav", "radio_dread/f_dobrou.wav", "radio_dread/f_nedychejte.wav",
           "radio_dread/f_neotvirej.wav", "radio_dread/f_vidime.wav", "radio_dread/s_laugh.mp3", "radio_dread/s_kids.wav",
           "radio_dread/s_breath.wav", "radio_dread/h_01.mp3", "radio_dread/h_04.mp3", "radio_dread/h_07.mp3", "radio_dread/h_10.mp3",
           "radio_dread/h_13.mp3", "npc/sm_second_voice.mp3", "npc/silent_whisper.mp3", "night/illusion_2.ogg", "night/illusion_5.ogg"]


def load(rel):
    path = os.path.join(GODOT, "assets", "sfx", rel)
    raw = subprocess.run([FF, "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype("<i2").tobytes()
    path = os.path.join(OUT, name)
    subprocess.run([FF, "-v", "quiet", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path], input=pcm, check=True)


def level(x, rms_db):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10.0 ** (rms_db / 20.0) / rms)
    peak = np.max(np.abs(y))
    return y / peak * 0.97 if peak > 0.97 else y


def edge(x, ms=8.0):
    n = min(int(SR * ms / 1000.0), len(x) // 2)
    w = np.linspace(0.0, 1.0, n)
    x = x.copy()
    x[:n] *= w
    x[-n:] *= w[::-1]
    return x


def band(x, lo, hi):
    sos = signal.butter(3, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def repitch(x, k):
    n = int(len(x) / k)
    return np.interp(np.linspace(0.0, len(x) - 1.0, n), np.arange(len(x)), x)


def tail(x, seconds, wet):
    """A dark room in the head: decaying noise for an impulse response."""
    n = int(SR * seconds)
    ir = RNG.standard_normal(n) * np.exp(-np.linspace(0.0, 7.0, n))
    ir = band(ir, 180.0, 3200.0)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    w = signal.fftconvolve(np.concatenate([x, np.zeros(n)]), ir)[: len(x) + n]
    d = np.concatenate([x, np.zeros(n)])
    return d * (1.0 - wet) + w * wet


def loudest(x, seconds):
    """Where in `x` a piece of `seconds` is loudest of a few tries: not a gap."""
    n = int(SR * seconds)
    if len(x) <= n:
        return x
    best = None
    for _ in range(14):
        a = int(RNG.integers(0, len(x) - n))
        piece = x[a:a + n]
        e = np.mean(piece ** 2)
        if best is None or e > best[0]:
            best = (e, piece)
    return best[1]


def stutter(x):
    """A grain caught and repeated, as a thought is."""
    g = int(SR * RNG.uniform(0.05, 0.11))
    a = int(RNG.integers(0, max(1, len(x) - g)))
    grain = edge(x[a:a + g], 4.0)
    return np.concatenate([x[:a]] + [grain] * int(RNG.integers(3, 7)) + [x[a:]])


def voices(n):
    src = [load(s) for s in SOURCES]
    src = [s for s in src if len(s) > SR // 3]
    for i in range(n):
        x = loudest(src[i % len(src)], RNG.uniform(0.45, 1.3))
        k = RNG.choice([0.62, 0.71, 0.84, 1.19, 1.34])
        x = repitch(x, k)
        if i % 3 == 1:
            x = x[::-1]
        if i % 2 == 0:
            x = stutter(x)
        # Through the skull: no top, no bottom, a slow beat in it.
        x = band(x, 260.0, 3400.0)
        t = np.arange(len(x)) / SR
        x = x * (0.72 + 0.28 * np.sin(2.0 * np.pi * RNG.uniform(5.0, 17.0) * t))
        x = tail(edge(x), RNG.uniform(0.35, 0.8), 0.32)
        write("voice_%02d.ogg" % (i + 1), edge(level(x, -19.0), 12.0))


def thuds(n):
    for i in range(n):
        ln = RNG.uniform(0.32, 0.6)
        t = np.arange(int(SR * ln)) / SR
        f0 = RNG.uniform(62.0, 96.0)
        drop = f0 * np.exp(-t * RNG.uniform(5.0, 11.0)) + 34.0
        body = np.sin(2.0 * np.pi * np.cumsum(drop) / SR) * np.exp(-t * RNG.uniform(7.0, 13.0))
        crack = band(RNG.standard_normal(len(t)), 500.0, 3000.0) * np.exp(-t * 90.0) * 0.55
        # Every other one has iron in it: a few partials that do not belong together.
        ring = np.zeros_like(t)
        if i % 2 == 1:
            for f in (311.0, 487.0, 743.0, 1129.0):
                ring += np.sin(2.0 * np.pi * f * RNG.uniform(0.9, 1.1) * t)
            ring *= np.exp(-t * 16.0) * 0.1
        x = tail(body + crack + ring, RNG.uniform(0.3, 0.7), 0.25)
        write("thud_%02d.ogg" % (i + 1), edge(level(np.tanh(x * 2.2), -15.0), 6.0))


def ring():
    """Eight seconds, every tone a whole number of cycles, so it loops without a seam."""
    n = SR * 8
    t = np.arange(n) / SR
    a = np.sin(2.0 * np.pi * 4100.0 * t + 1.2 * np.sin(2.0 * np.pi * 0.25 * t))
    b = np.sin(2.0 * np.pi * 6275.0 * t + 0.8 * np.sin(2.0 * np.pi * 0.375 * t))
    beat = 0.6 + 0.4 * np.sin(2.0 * np.pi * 0.75 * t)
    # The hiss: noise, filtered round the loop's end by doing it on a wrapped copy.
    noise = RNG.standard_normal(n)
    sos = signal.butter(2, [2800.0, 3600.0], btype="band", fs=SR, output="sos")
    hiss = signal.sosfilt(sos, np.concatenate([noise, noise]))[n:]
    hiss /= np.max(np.abs(hiss)) + 1e-9
    x = (a * 0.5 + b * 0.32) * beat + hiss * 0.22 * (0.7 + 0.3 * np.sin(2.0 * np.pi * 0.125 * t))
    write("ring.ogg", level(x, -22.0))


def main():
    voices(12)
    thuds(6)
    ring()
    print("wrote", len(os.listdir(OUT)), "files in", os.path.relpath(OUT, GODOT))


if __name__ == "__main__":
    main()
