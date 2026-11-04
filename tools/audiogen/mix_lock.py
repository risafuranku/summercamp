#!/usr/bin/env python3
"""The sound of finding the Girl (nightmare_fx.lock): a set catching its picture, hit in the
chest. Two ElevenLabs takes laid together at their first instant, a selector's clack over a
relay's thud (raw/girl_lock_a.mp3, _b.mp3: rows in prompts_holka.tsv), a falling sub under them
for the chest, and nothing before the hit: a WAV, as an MP3's encoder delay would put 50 ms of
silence in front of it.

    python tools/audiogen/mix_lock.py
"""
import os
import subprocess
import wave

import imageio_ffmpeg
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "npc", "girl_lock.wav")
RATE = 44100
LEN = 0.62
FF = imageio_ffmpeg.get_ffmpeg_exe()


def pcm(path):
    r = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).copy()


def from_hit(x):
    """`x` from 4 ms before it first gets to a tenth of its peak."""
    env = np.abs(x)
    w = int(RATE * 0.002)
    sm = np.convolve(env, np.ones(w) / w, mode="same")
    i = int(np.argmax(sm > sm.max() * 0.1))
    return x[max(0, i - int(RATE * 0.004)):]


def fit(x, n):
    out = np.zeros(n, dtype=np.float64)
    m = min(n, len(x))
    out[:m] = x[:m]
    return out


def main():
    n = int(RATE * LEN)
    t = np.arange(n) / RATE
    clack = fit(from_hit(pcm(os.path.join(HERE, "raw", "girl_lock_a.mp3"))), n)
    thud = fit(from_hit(pcm(os.path.join(HERE, "raw", "girl_lock_b.mp3"))), n)
    clack /= np.abs(clack).max()
    thud /= np.abs(thud).max()
    # The chest: a sine falling from 72 to 44 Hz, gone in a quarter of a second.
    f = 44.0 + 28.0 * np.exp(-t * 18.0)
    sub = np.sin(2.0 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 11.0)
    # The clack's bite brought up (small speakers have nothing under 150 Hz): a first-order
    # high-pass at 500 Hz of it laid over the rest.
    a = np.exp(-2.0 * np.pi * 500.0 / RATE)
    low = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc = (1.0 - a) * clack[i] + a * acc
        low[i] = acc
    bite = clack - low
    bite /= np.abs(bite).max()
    # The set's own wood and metal, for what a laptop can play: the K, a hard tick of two
    # partials and a spit of noise, and 8 ms on the LONK, the cabinet ringing, dying fast.
    rng = np.random.default_rng(5)
    k = (np.sin(2.0 * np.pi * 1180.0 * t) + 0.7 * np.sin(2.0 * np.pi * 2730.0 * t)) * np.exp(-t / 0.012)
    k += rng.normal(0.0, 0.5, n) * np.exp(-t / 0.003)
    t2 = np.clip(t - 0.008, 0.0, None)
    gate = (t >= 0.008).astype(np.float64)
    lonk = (np.sin(2.0 * np.pi * 430.0 * t2) * np.exp(-t2 / 0.055) + 0.6 * np.sin(2.0 * np.pi * 655.0 * t2) * np.exp(-t2 / 0.035)) * gate
    mix = k * 0.55 + lonk * 0.8 + clack * 0.5 + bite * 0.4 + thud * 0.5 + sub * 0.25
    mix = np.tanh(mix * 1.1)
    fade = np.clip((LEN - t) / 0.12, 0.0, 1.0)
    mix *= fade
    mix *= 10.0 ** (-2.0 / 20.0) / np.abs(mix).max()
    data = (mix * 32767.0).astype("<i2").tobytes()
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("girl_lock.wav", round(LEN, 2), "s")


if __name__ == "__main__":
    main()
