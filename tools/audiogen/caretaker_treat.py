#!/usr/bin/env python3
"""The Caretaker's treatment, done offline: a song of the radio's remembered three ways, each
further gone (the user 5. 11.: "the caretaker songs, played normally on the radio too,
treated, treated more... and try the treatment on other songs of the game that fit").

    python tools/audiogen/caretaker_treat.py              # the whole batch below
    python tools/audiogen/caretaker_treat.py <src> <name> <stage> [...]

Stages (each written as the radio's other songs are: 8 kHz, 32 kbps, to the songs' loudness,
into godot/assets/sfx/radio/<prefix>_care_<name>.mp3; the prefix is the radio's tier):
  night   "a burning memory": the song from its start, but a phrase comes round twice or
          three times before it goes on, the tape a little slow and wavering, a ballroom
          round it, the surface of the record under it.
  teror   "the long decline": one bar, round and round, each turn slower and further off,
          the needle jumping to somewhere else in the song, gaps with only the hall in
          them, the song remembered once more under itself, dropouts.
  peklo   "post-awareness": the song stretched into a drone sinking in an enormous hall,
          splinters of it out of order, backwards, too fast or too slow, cut off dead; a
          needle stuck on a quarter of a second, speeding and dragging; at the end the
          tape running down into the surface of the record and nothing.
The radio's tiers (building_interior.gd): night_* only at night, teror_* only when the
night presses, peklo_* only at the worst.
"""
import os
import re
import subprocess
import sys

import imageio_ffmpeg
import librosa
import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt, sosfiltfilt

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
RADIO = os.path.join(REPO, "godot", "assets", "sfx", "radio")
OST = os.path.join(REPO, "ost")
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 22050
# The radio's songs' loudness (the median of them, radio_new_songs 4. 11.), a little under it
# the further gone.
LUFS = {"night": -14.8, "teror": -15.6, "peklo": -16.4}

# source (under ost/), name, stages
BATCH = [
    ("plesvalcik_song_hq.mp3", "valcik", ["night", "teror", "peklo"]),
    ("plesfoxtrot_song_hq.mp3", "foxtrot", ["night", "teror", "peklo"]),
    ("plestango_song_hq.mp3", "tango", ["night", "teror", "peklo"]),
    ("night_motif_hq.mp3", "motif", ["teror", "peklo"]),
    ("night_tancovacka2_hq.mp3", "tancovacka", ["night", "teror"]),
    ("goodvibes_song_hq.mp3", "goodvibes", ["teror"]),
]


def decode(path):
    raw = subprocess.run([FF, "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0


def rms(y):
    return float(np.sqrt(np.mean(y * y) + 1e-12))


def band(y, lo, hi):
    return sosfiltfilt(butter(2, [lo, hi], btype="band", fs=SR, output="sos"), y)


def lowpass(y, hz, order=2):
    return sosfilt(butter(order, hz, btype="low", fs=SR, output="sos"), y)


def highpass(y, hz, order=2):
    return sosfilt(butter(order, hz, btype="high", fs=SR, output="sos"), y)


def fade(y, a_s, b_s):
    y = y.copy()
    a, b = int(a_s * SR), int(b_s * SR)
    if a > 0:
        y[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if b > 0:
        y[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    return y


def stitch(parts, xf_s):
    """Parts one after another, each run into the next (equal power over xf_s)."""
    xf = int(xf_s * SR)
    out = np.zeros(0)
    for p in parts:
        if len(p) == 0:
            continue
        if len(out) < xf or len(p) < xf:
            out = np.concatenate([out, p])
            continue
        t = np.linspace(0, np.pi / 2, xf)
        seam = out[-xf:] * np.cos(t) + p[:xf] * np.sin(t)
        out = np.concatenate([out[:-xf], seam, p[xf:]])
    return out


def speed(y, k):
    """Played at k times its speed (pitch with it, as a turntable)."""
    if abs(k - 1.0) < 1e-4 or len(y) < 4:
        return y
    n = max(2, int(len(y) / k))
    return np.interp(np.arange(n) * k, np.arange(len(y)), y)


def tape(y, slow, wow, flutter, rng, sag_to=None):
    """A worn tape (or a warped record): slow, wavering, and if sag_to, running down."""
    n = int(len(y) / slow)
    t = np.arange(n) / SR
    ph = rng.uniform(0, 2 * np.pi, 4)
    walk = np.cumsum(rng.standard_normal(n // 2205 + 2))
    walk = np.interp(np.arange(n), np.linspace(0, n, len(walk)), walk - walk.mean())
    walk = walk / (np.abs(walk).max() + 1e-9)
    mod = wow * (0.65 * np.sin(2 * np.pi * 0.53 * t + ph[0]) + 0.35 * np.sin(2 * np.pi * 0.19 * t + ph[1]) + 0.5 * walk) \
        + flutter * np.sin(2 * np.pi * 6.3 * t + ph[2])
    rate = slow * (1.0 + mod)
    if sag_to is not None:
        k = np.clip((t - t[-1] * 0.82) / (t[-1] * 0.18), 0, 1)
        rate *= 1.0 - (1.0 - sag_to) * k * k
    pos = np.cumsum(rate) - rate[0]
    pos = pos[pos < len(y) - 1]
    return np.interp(pos, np.arange(len(y)), y)


def shellac(y, lo, hi, drive):
    """Through the horn of a gramophone and the radio: the band, a little saturated."""
    y = band(y, lo, hi)
    g = rms(y)
    return np.tanh(y / (g * 4.0) * drive) * g * 4.0 / max(drive, 1e-3)


def hall_ir(rt60, pre_s, rng, bright):
    n = int(rt60 * 1.15 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    lo = lowpass(noise, 650.0)
    mid = band(noise, 650.0, 2300.0)
    hi = highpass(noise, 2300.0)
    ir = lo * np.exp(-6.91 * t / rt60) + mid * np.exp(-6.91 * t / (0.72 * rt60)) + bright * hi * np.exp(-6.91 * t / (0.42 * rt60))
    # The hall's first answers off its walls.
    for _ in range(9):
        k = int(rng.uniform(0.012, 0.09) * SR)
        if k < n:
            ir[k] += rng.uniform(0.6, 2.0) * (1 if rng.random() < 0.5 else -1) * np.abs(ir).max()
    ir = np.concatenate([np.zeros(int(pre_s * SR)), ir])
    return ir / np.sqrt(np.sum(ir * ir))


def hall(y, rt60, wet, dry, rng, pre_s=0.03, bright=0.45):
    ir = hall_ir(rt60, pre_s, rng, bright)
    w = fftconvolve(y, ir)
    w *= rms(y) / (rms(w[:len(y)]) + 1e-12)
    out = w * wet
    out[:len(y)] += y * dry
    return out


def surface(n, rng, hiss_db, crackle_per_s, crackle_db):
    """The record's surface: hiss, crackle, the thump once a turn (78 rpm)."""
    hiss = lowpass(highpass(rng.standard_normal(n), 300.0), 3200.0) * 10 ** (hiss_db / 20.0)
    clicks = np.zeros(n)
    count = int(n / SR * crackle_per_s)
    at = rng.integers(0, n, count)
    clicks[at] = rng.standard_normal(count) * rng.uniform(0.2, 1.0, count) ** 3
    clicks = highpass(lowpass(clicks, 4000.0), 900.0)
    clicks *= 10 ** (crackle_db / 20.0) / (np.abs(clicks).max() + 1e-9)
    turn = np.zeros(n)
    turn[::int(SR * 60 / 78)] = 1.0
    turn = lowpass(turn, 60.0) * 10 ** ((crackle_db - 12.0) / 20.0) * 20.0
    return hiss + clicks + turn


def meter(y, beats):
    """3 (a waltz) or 4, from how the hits come round."""
    env = librosa.onset.onset_strength(y=y, sr=SR, hop_length=256)
    if len(beats) < 8:
        return 4
    per = float(np.median(np.diff(beats))) / 256.0
    ac = librosa.autocorrelate(env - env.mean(), max_size=int(per * 9))
    ac /= ac[0] + 1e-9
    a3 = np.interp(per * 3, np.arange(len(ac)), ac)
    a4 = np.interp(per * 4, np.arange(len(ac)), ac)
    return 3 if a3 > a4 else 4


def beat_grid(y):
    tempo, b = librosa.beat.beat_track(y=y, sr=SR, units="samples", hop_length=256)
    b = np.asarray(b, dtype=int)
    if len(b) < 16:
        step = int(SR * 0.6)
        b = np.arange(0, len(y) - step, step)
    return b, meter(y, b)


def seg(y, beats, i, count):
    i = max(0, min(i, len(beats) - count - 1))
    return y[beats[i]:beats[i + count]]


def dropouts(y, rng, count, depth_db):
    y = y.copy()
    for _ in range(count):
        a = int(rng.uniform(0.1, 0.9) * len(y))
        n = int(rng.uniform(0.12, 0.45) * SR)
        env = np.ones(n) * 10 ** (depth_db / 20.0)
        r = int(0.01 * SR)
        env[:r] = np.linspace(1, env[r], r)
        env[-r:] = np.linspace(env[-r - 1], 1, r)
        y[a:a + n] *= env[:len(y[a:a + n])]
    return y


def paulstretch(y, stretch, rng, win_s=0.3):
    win = int(win_s * SR) // 2 * 2
    w = np.hanning(win)
    hop_out = win // 4
    hop_in = hop_out / stretch
    n_frames = int((len(y) - win) / hop_in)
    out = np.zeros(n_frames * hop_out + win)
    for f in range(max(0, n_frames)):
        a = int(f * hop_in)
        fr = y[a:a + win] * w
        mag = np.abs(np.fft.rfft(fr))
        ph = rng.uniform(0, 2 * np.pi, len(mag))
        out[f * hop_out:f * hop_out + win] += np.fft.irfft(mag * np.exp(1j * ph), win) * w
    return out


# ── the stages ──────────────────────────────────────────────────────────────────────

def stage_night(y, rng):
    beats, m = beat_grid(y)
    bar = m * 2
    parts = []
    i = 0
    total = 0
    while i + bar < len(beats) - 1 and total < 78 * SR:
        s = seg(y, beats, i, bar)
        turns = int(rng.choice([1, 2, 2, 2, 3]))
        for r in range(turns):
            parts.append(s * (0.93 ** r))
            total += len(s)
        # Now and then the memory goes back a phrase.
        i += bar if rng.random() > 0.18 else 0
        i += bar if rng.random() < 0.08 else 0
    x = stitch(parts, 0.035)
    x = tape(x, 0.966, 0.0036, 0.0012, rng)
    x = shellac(x, 170.0, 3700.0, 1.3)
    x = hall(x, 2.6, 0.32, 0.86, rng, 0.035, 0.5)
    x += surface(len(x), rng, -44.0, 5.0, -30.0) * rms(x) / 0.1
    return fade(x[:int(82 * SR)], 0.4, 6.0)


def stage_teror(y, rng):
    beats, m = beat_grid(y)
    bars = [m, m, m * 2]
    parts = []
    total = 0
    heard = []
    slow = 1.0
    while total < 84 * SR:
        if heard and rng.random() < 0.3:
            i = int(rng.choice(heard))
        else:
            i = int(rng.integers(0, max(1, len(beats) - m * 2 - 2)))
            heard.append(i)
        s = seg(y, beats, i, int(rng.choice(bars)))
        turns = int(rng.integers(3, 7))
        g = 1.0
        for r in range(turns):
            parts.append(speed(s, slow) * g)
            total += len(parts[-1])
            g *= 0.91
            slow *= 0.994
        if rng.random() < 0.35:
            gap = np.zeros(int(rng.uniform(0.8, 2.6) * SR))
            parts.append(gap)
            total += len(gap)
        slow = max(slow, 0.86)
    x = stitch(parts, 0.06)
    # The song again under itself, slower, from somewhere else.
    ghost_parts = []
    while sum(len(p) for p in ghost_parts) < len(x):
        s = seg(y, beats, int(rng.integers(0, max(1, len(beats) - m - 2))), m * 2)
        ghost_parts += [speed(s, 0.82)] * int(rng.integers(2, 4))
    ghost = stitch(ghost_parts, 0.08)[:len(x)]
    ghost = hall(ghost, 7.0, 1.0, 0.0, rng, 0.08, 0.2)[:len(x)]
    x = x + ghost * 0.22
    x = tape(x, 0.93, 0.008, 0.0026, rng)
    x = shellac(x, 210.0, 3100.0, 1.6)
    x = dropouts(x, rng, int(rng.integers(2, 5)), -16.0)
    x = hall(x, 5.6, 0.58, 0.52, rng, 0.05, 0.35)
    x += surface(len(x), rng, -40.0, 9.0, -26.0) * rms(x) / 0.1
    return fade(x[:int(88 * SR)], 1.6, 9.0)


def stage_peklo(y, rng, hell=None):
    beats, m = beat_grid(y)
    n = int(76 * SR)
    # The drone: three phrases stretched eightfold, slowed, one into the next.
    drones = []
    for _ in range(3):
        s = seg(y, beats, int(rng.integers(0, max(1, len(beats) - m * 2 - 2))), m * 2)
        drones.append(speed(paulstretch(s, 8.0, rng), 0.8))
    drone = stitch(drones, 4.0)
    drone = np.resize(drone, n) if len(drone) < n else drone[:n]
    drone = hall(lowpass(drone, 2200.0), 9.0, 0.9, 0.25, rng, 0.12, 0.2)[:n]
    drone *= 0.5 * rms(y) / (rms(drone) + 1e-12)
    out = drone.copy()
    # Splinters: in bursts, out of order, backwards, the wrong speed, cut off dead.
    t = rng.uniform(2.0, 5.0)
    while t < 66.0:
        burst = int(rng.integers(2, 9))
        for _ in range(burst):
            a = int(rng.integers(0, len(y) - SR * 2))
            ln = int(rng.uniform(0.12, 1.4) * SR)
            s = y[a:a + ln]
            if rng.random() < 0.28:
                s = s[::-1]
            s = speed(s, float(rng.choice([0.55, 0.7, 0.85, 1.0, 1.0, 1.08])))
            if rng.random() < 0.5:
                s = fade(s, 0.003, 0.003)
            else:
                s = fade(s, 0.02, min(0.15, len(s) / SR / 3))
            at = int(t * SR)
            out[at:at + len(s)] += s[:len(out[at:at + len(s)])] * rng.uniform(0.5, 1.0)
            t += len(s) / SR * rng.uniform(0.4, 1.3)
        t += rng.uniform(1.5, 6.0)
    # The needle stuck on a quarter of a second, speeding up and dragging, then nothing.
    a = int(rng.integers(0, len(y) - SR))
    grain = fade(y[a:a + int(0.33 * SR)], 0.004, 0.004)
    turns = []
    for k in range(int(rng.integers(14, 26))):
        turns.append(speed(grain, 1.0 + 0.6 * np.sin(k / 5.0)))
    stuck = stitch(turns, 0.006)
    at = int(rng.uniform(30.0, 48.0) * SR)
    out[at:at + len(stuck)] += stuck[:len(out[at:at + len(stuck)])] * 0.9
    out[at + len(stuck):at + len(stuck) + int(2.6 * SR)] *= 0.04
    if hell is not None:
        # The worst night's own noise, far off in the same hall, once or twice.
        for _ in range(int(rng.integers(1, 3))):
            a = int(rng.integers(0, len(hell) - 4 * SR))
            s = hall(speed(hell[a:a + int(rng.uniform(1.5, 3.5) * SR)], 0.78), 6.0, 1.0, 0.0, rng, 0.1, 0.2)
            s = fade(s, 0.4, 1.5) * 0.35 * rms(y) / (rms(s) + 1e-12)
            at = int(rng.uniform(10.0, 60.0) * SR)
            out[at:at + len(s)] += s[:len(out[at:at + len(s)])]
    x = tape(out, 0.97, 0.012, 0.004, rng, sag_to=0.45)
    x = shellac(x, 160.0, 3000.0, 1.8)
    x = hall(x, 4.0, 0.4, 0.7, rng, 0.04, 0.3)
    end = np.zeros(int(3.5 * SR))
    x = np.concatenate([fade(x, 2.5, 7.0), end])
    x += surface(len(x), rng, -38.0, 14.0, -22.0) * rms(x[: -len(end)]) / 0.1
    return fade(x, 0.0, 1.2)


def lufs(path):
    r = subprocess.run([FF, "-hide_banner", "-i", path, "-af", "ebur128=framelog=quiet:peak=true", "-f", "null", "-"],
                       capture_output=True, text=True, errors="replace")
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    p = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", r.stderr)
    return float(i[-1]), float(p[-1]) if p else 0.0


def write_radio(x, dest, target):
    """As the radio's songs: 8 kHz, 32 kbps, to `target` LUFS under a limiter."""
    wav = dest[:-4] + "_tmp.wav"
    import soundfile
    soundfile.write(wav, (x / (np.abs(x).max() + 1e-9) * 0.7).astype(np.float32), SR, subtype="PCM_16")
    gain = 0.0
    for _ in range(4):
        subprocess.run([FF, "-y", "-hide_banner", "-loglevel", "error", "-i", wav, "-af",
                        "volume=%.2fdB,alimiter=limit=0.89:level=disabled" % gain,
                        "-ar", "8000", "-ac", "2", "-b:a", "32k", dest], check=True)
        lv, pk = lufs(dest)
        if abs(lv - target) < 0.3:
            break
        gain += target - lv
    os.remove(wav)
    return lv, pk


def treat(src, name, stages, hell=None):
    y = decode(src)
    y = y / (np.abs(y).max() + 1e-9) * 0.8
    for st in stages:
        rng = np.random.default_rng(sum(map(ord, name + st)) * 7919)
        x = {"night": stage_night, "teror": stage_teror}[st](y, rng) if st != "peklo" else stage_peklo(y, rng, hell)
        dest = os.path.join(RADIO, "%s_care_%s.mp3" % (st, name))
        lv, pk = write_radio(x, dest, LUFS[st])
        print("%-28s %5.1f s  %.1f LUFS  peak %.1f" % (os.path.basename(dest), len(x) / SR, lv, pk))


def main():
    hell_path = os.path.join(OST, "peklo_valcik_hq.mp3")
    hell = decode(hell_path) if os.path.exists(hell_path) else None
    if len(sys.argv) > 3:
        treat(sys.argv[1], sys.argv[2], sys.argv[3:], hell)
        return
    for src, name, stages in BATCH:
        treat(os.path.join(OST, src), name, stages, hell)


if __name__ == "__main__":
    main()
