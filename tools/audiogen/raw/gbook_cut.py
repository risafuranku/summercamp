#!/usr/bin/env python3
"""The gBook's recordings (rows in prompts_gbook.tsv) cut into what the machine plays, after
gen.py and normalize.py: the button's press and release apart, the keys' too, the power
switch without its lead-in, the spin-up without its last clunk; and the fan's hum as a loop
whose ends are in phase (an equal-power cross-fade of a 50 Hz hum cancels itself: a dip at
every repeat, so ambience_loop.py will not do). Set loop=true in fan.ogg.import after.

    python tools/audiogen/raw/gbook_cut.py
"""
import os
import subprocess

import imageio_ffmpeg
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "..", "..", "..", "godot", "assets", "sfx", "gbook") + os.sep
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100


def load(p):
    r = subprocess.run([FF, "-hide_banner", "-i", p, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)


def write(a, dest, *codec):
    pcm = (np.clip(a, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run([FF, "-hide_banner", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", *codec, dest], input=pcm, capture_output=True, check=True)
    print(os.path.basename(dest), "%.3fs peak %.2f" % (len(a) / SR, np.abs(a).max()))


def part(a, t0, t1, peak=None, fade=0.01):
    s = a[int(t0 * SR):int(t1 * SR)].copy()
    n = int(fade * SR)
    s[:n] *= np.linspace(0, 1, n)
    s[-n * 3:] *= np.linspace(1, 0, n * 3)
    if peak:
        s *= peak / max(1e-6, np.abs(s).max())
    return s


def cuts():
    click = load(D + "click.mp3")
    write(part(click, 0.09, 0.21, 0.62), D + "click_down.wav")
    write(part(click, 0.31, 0.47, 0.42), D + "click_up.wav")
    key = load(D + "key.mp3")
    write(part(key, 0.025, 0.17, 0.6), D + "key_down.wav")
    write(part(key, 0.235, 0.41, 0.36), D + "key_up.wav")
    write(part(load(D + "power.mp3"), 0.28, 1.0), D + "power.wav")
    spin = load(D + "spinup.mp3")
    write(part(spin, 0.0, int(np.argmax(np.abs(spin))) / SR - 0.05, None, 0.06), D + "spinup.wav")
    for f in ("click.mp3", "key.mp3", "power.mp3", "spinup.mp3"):
        os.remove(D + f)


def fan():
    x = load(os.path.join(HERE, "gbook_fan_raw.mp3"))
    a = int(0.5 * SR)
    fade = int(1.2 * SR)
    ref = x[a:a + fade]
    best, length = -2.0, 0
    for n in range(int(4.0 * SR), int(6.2 * SR), 8):
        seg = x[a + n:a + n + fade]
        if len(seg) < fade:
            break
        c = float(np.dot(ref, seg) / (np.linalg.norm(ref) * np.linalg.norm(seg) + 1e-9))
        if c > best:
            best, length = c, n
    out = x[a:a + length].copy()
    k = np.linspace(0.0, 1.0, fade)
    out[:fade] = x[a:a + fade] * k + x[a + length:a + length + fade] * (1.0 - k)
    # To the -23 LUFS of the rest (the gain ambience_loop.py measured on this hum).
    out *= 10 ** (23.9 / 20.0)
    out *= min(1.0, 0.8 / np.abs(out).max())
    write(out, D + "fan.ogg", "-c:a", "libvorbis", "-q:a", "4")


if __name__ == "__main__":
    if os.path.exists(D + "click.mp3"):
        cuts()
    fan()
