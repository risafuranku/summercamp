#!/usr/bin/env python3
"""The radio going wrong at night: synthesised loops plus the ElevenLabs sources ruined
into something heard through a cheap set on a bad night.

    python tools/gen_radio_dread.py   -> godot/assets/sfx/radio_dread/*.wav

Synthesised (deterministic, fixed seeds):
  static.wav      12 s seamless shortwave static: band-limited hiss, slow fading, crackle
  carrier.wav      8 s seamless dead carrier: mains hum through a transmitter, no programme
  buzzer.wav     ~11 s seamless OK 76 buzz: one harsh second-long buzz every 1.9 s over the
                   carrier, fading in and out like a far transmitter
  tune_a/b/c.wav  turning the dial: a resonant sweep through noise, heterodyne chirps,
                   scraps of other stations

Processed from tools/audiogen/raw_radio/<id>.mp3 (tools/audiogen/radio_fetch.py):
  v_*, l_*, f_*   voices: band-limited, driven, fading, a little static under them
  s_*             what else is on the frequency (birds, a dog, breathing, a knock)

Everything is 22050 Hz / 16-bit mono, like the rest of the game's synth sounds. Decoding
the MP3 sources needs ffmpeg: on PATH, or `pip install imageio-ffmpeg`.
"""
import glob
import os
import shutil
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "godot", "assets", "sfx", "radio_dread")
RAW = os.path.join(ROOT, "tools", "audiogen", "raw_radio")


def save(name, x):
    x = np.clip(np.asarray(x, dtype=np.float64), -1.0, 1.0)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    print(name, "%.2fs" % (len(x) / SR))


def band(x, lo, hi, order=3):
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, hz, order=2):
    return signal.sosfilt(signal.butter(order, hz, btype="lowpass", fs=SR, output="sos"), x)


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def level(x, rms_db):
    """Scales to an RMS (measured where it is not silent) so clips sit with the songs
    (the radio's songs run about -17 dB RMS); peaks are soft-limited."""
    active = x[np.abs(x) > 0.003 * np.max(np.abs(x))]
    rms = np.sqrt(np.mean(active ** 2)) if len(active) else 1.0
    y = x * (10 ** (rms_db / 20.0) / max(rms, 1e-9))
    return np.tanh(y * 1.1) / np.tanh(1.1) if np.max(np.abs(y)) > 0.95 else y


def smooth_noise(rng, n, rate_hz):
    """A slow random curve in about -1..1 (rate_hz control points per second)."""
    pts = max(4, int(n / SR * rate_hz) + 4)
    ctrl = rng.uniform(-1.0, 1.0, pts)
    return np.interp(np.linspace(0, pts - 3, n), np.arange(pts), ctrl)


def qsb(rng, n, depth, rate_hz=0.35):
    """Shortwave fading: the signal swells and sinks as the ionosphere moves."""
    return 1.0 - depth * (0.5 + 0.5 * smooth_noise(rng, n, rate_hz))


def loop_seamless(x, fade_s=0.6):
    """Crossfades the tail into the head so the file loops without a click."""
    f = int(fade_s * SR)
    head, body, tail = x[:f], x[f:-f], x[-f:]
    ramp = np.linspace(0.0, 1.0, f)
    return np.concatenate([body, tail * (1.0 - ramp) + head * ramp])


def crackle(rng, n, per_sec, amp):
    out = np.zeros(n)
    count = int(n / SR * per_sec)
    for _ in range(count):
        at = rng.integers(0, n - 400)
        length = rng.integers(20, 300)
        out[at:at + length] += rng.normal(0, amp * rng.uniform(0.3, 1.0), length) * np.linspace(1, 0, length)
    return out


def hiss(rng, n):
    return band(rng.normal(0, 1, n), 260, 3600)


# ── synthesised ──────────────────────────────────────────────────────────────────


def gen_static():
    rng = np.random.default_rng(76)
    n = int(12.6 * SR)
    x = hiss(rng, n) * qsb(rng, n, 0.55, 0.3)
    # A second, rougher layer that comes and goes: the next station's splatter.
    splatter = band(rng.normal(0, 1, n), 600, 2200) * np.clip(smooth_noise(rng, n, 0.8), 0, 1) ** 2
    x = x + splatter * 0.6 + crackle(rng, n, 9, 3.0)
    save("static.wav", norm(loop_seamless(x), 0.7))


def gen_carrier():
    rng = np.random.default_rng(7601)
    n = int(8.6 * SR)
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 50 * t) + 0.6 * np.sin(2 * np.pi * 100 * t + 0.4) + 0.35 * np.sin(2 * np.pi * 150 * t + 1.1))
    hum = np.tanh(hum * 1.8) * 0.5
    x = hum * qsb(rng, n, 0.25, 0.2) + hiss(rng, n) * 0.08 + crackle(rng, n, 2, 1.0)
    save("carrier.wav", norm(loop_seamless(band(x, 80, 3000)), 0.45))


def buzz_tone(rng, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # Two detuned buzzers and a grinding 50 Hz amplitude modulation: ugly on purpose.
    f1 = 116.0 * (1.0 + 0.004 * smooth_noise(rng, n, 3))
    f2 = 119.5
    saw = signal.sawtooth(2 * np.pi * np.cumsum(f1) / SR)
    sq = signal.square(2 * np.pi * f2 * t, 0.42)
    grind = 0.7 + 0.3 * signal.square(2 * np.pi * 50 * t, 0.3)
    x = (saw * 0.6 + sq * 0.5) * grind
    x = np.tanh(band(x, 280, 2600) * 3.0)
    e = np.ones(n)
    a, r = int(0.012 * SR), int(0.03 * SR)
    e[:a] = np.linspace(0, 1, a)
    e[-r:] = np.linspace(1, 0, r)
    return x * e


def gen_buzzer():
    rng = np.random.default_rng(1976)
    period, buzz_len, count = 1.9, 1.05, 6
    n = int(period * count * SR) + int(0.6 * SR)
    x = np.zeros(n)
    for i in range(count + 1):
        at = int(i * period * SR)
        b = buzz_tone(rng, buzz_len + rng.uniform(-0.04, 0.04))
        end = min(n, at + len(b))
        x[at:end] += b[:end - at]
    carrier = hiss(rng, n) * 0.18 + crackle(rng, n, 4, 1.5)
    x = (x * 0.75 + carrier) * qsb(rng, n, 0.45, 0.25)
    save("buzzer.wav", level(loop_seamless(x, 0.3), -22.0))


def gen_tune(name, seed, seconds):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    noise = rng.normal(0, 1, n)
    # A resonant band sweeping as the dial turns, in uneven hand movements.
    centre = 400 + 2600 * (0.5 + 0.5 * smooth_noise(rng, n, 2.5))
    out = np.zeros(n)
    hop = 256
    for i in range(0, n, hop):
        c = centre[i]
        seg = noise[max(0, i - 512):i + hop]
        sos = signal.butter(2, [max(80, c * 0.8), min(SR / 2 - 100, c * 1.25)], btype="bandpass", fs=SR, output="sos")
        out[i:i + hop] = signal.sosfilt(sos, seg)[-min(hop, n - i):]
    # Heterodyne chirps: a carrier whistling past as the dial crosses it.
    t = np.arange(n) / SR
    for _ in range(rng.integers(2, 4)):
        at = rng.uniform(0.1, seconds - 0.5)
        length = rng.uniform(0.15, 0.4)
        mask = (t >= at) & (t < at + length)
        k = (t[mask] - at) / length
        f = np.interp(k, [0, 1], [rng.uniform(1800, 3200), rng.uniform(150, 400)])
        out[mask] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * k) * 0.5
    # Scraps of another station: formant-like bursts that never become words.
    for _ in range(rng.integers(1, 3)):
        at = int(rng.uniform(0.1, seconds - 0.6) * SR)
        length = int(rng.uniform(0.2, 0.5) * SR)
        burst = band(rng.normal(0, 1, length), 500, 1400) * np.abs(np.sin(np.linspace(0, rng.uniform(6, 14), length)))
        out[at:at + length] += burst * 0.7
    e = np.ones(n)
    f = int(0.05 * SR)
    e[:f] = np.linspace(0, 1, f)
    e[-f:] = np.linspace(1, 0, f)
    save(name, level(np.tanh(out * 1.5) * e, -22.0))


# ── processed sources ────────────────────────────────────────────────────────────


def ffmpeg():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        raise SystemExit("ffmpeg not found: put it on PATH or pip install imageio-ffmpeg")


def decode(path):
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def trim(x, threshold=0.02, pad_s=0.12):
    loud = np.where(np.abs(x) > threshold * np.max(np.abs(x)))[0]
    if len(loud) == 0:
        return x
    pad = int(pad_s * SR)
    return x[max(0, loud[0] - pad):min(len(x), loud[-1] + pad)]


def through_radio(x, seed, lo, hi, drive, static_amount, fade_depth):
    rng = np.random.default_rng(seed)
    x = trim(x)
    x = band(norm(x, 1.0), lo, hi, 4)
    x = np.tanh(norm(x, 1.0) * drive) / np.tanh(drive)
    n = len(x)
    x = x * qsb(rng, n, fade_depth, 0.6)
    x = x + hiss(rng, n) * static_amount + crackle(rng, n, 3, static_amount * 6)
    f = int(0.03 * SR)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def process_sources():
    files = sorted(glob.glob(os.path.join(RAW, "*.mp3")))
    if not files:
        print("no raw sources in", RAW, "- run tools/audiogen/radio_fetch.py first")
        return
    for i, path in enumerate(files):
        rid = os.path.splitext(os.path.basename(path))[0]
        x = decode(path)
        if rid.startswith("s_"):
            y = level(through_radio(x, 500 + i, 220, 3200, 1.6, 0.025, 0.35), -21.0)
        elif rid.startswith("f_"):
            y = level(through_radio(x, 500 + i, 380, 2600, 2.2, 0.03, 0.3), -19.0)
        else:
            y = level(through_radio(x, 500 + i, 320, 2700, 2.6, 0.035, 0.4), -19.0)
        save(rid + ".wav", y)


if __name__ == "__main__":
    gen_static()
    gen_carrier()
    gen_buzzer()
    gen_tune("tune_a.wav", 31, 2.2)
    gen_tune("tune_b.wav", 32, 1.4)
    gen_tune("tune_c.wav", 33, 3.0)
    process_sources()
