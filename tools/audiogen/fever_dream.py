#!/usr/bin/env python3
"""What gets into your head when you run for your life (the user 5. 11.: "no flashing faces:
when you are already running, ringing in the ears, voices, bangs, a schizo fever dream";
then "more effects, reverbs: it sounds too little like hearing things, too much like
playing a recording"). scripts/audio/fever_dream.gd plays these, more of them the worse it
is. Nothing here starts: it comes up out of its own echo and goes back into it; no dry
word, no room you could point at; each file drifts from ear to ear by itself.

    ring.ogg        the ears: two high tones and a narrow hiss beating, a seamless loop
    voice_NN.ogg    splinters of the night's own voices (the radio's dread, the hells, the
                    second voice, the illusions), four ways gone: a word stretched to a
                    breath, backwards up out of its echo, a syllable caught and falling
                    away down a long stair of repeats, two whispers rubbing together
    thud_NN.ogg     blows you feel more than hear, far down a very big dark
    sm_call_far     (assets/sfx/npc/) the Silent Man's one call, from the raw take in
                    raw/sm_lure_a.mp3: a long way off over the field, the tree line
                    answering it

    python tools/audiogen/fever_dream.py

Seeded: the same files every run. Levelled by RMS here.
"""
import os
import subprocess

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


def load(path):
    raw = subprocess.run([FF, "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def sfx(rel):
    return load(os.path.join(GODOT, "assets", "sfx", rel))


def write(path, left, right=None):
    """Mono, or a stereo pair."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if right is None:
        data, ch = np.clip(left, -1.0, 1.0), 1
    else:
        n = min(len(left), len(right))
        data, ch = np.clip(np.stack([left[:n], right[:n]], axis=1).reshape(-1), -1.0, 1.0), 2
    pcm = (data * 32767.0).astype("<i2").tobytes()
    subprocess.run([FF, "-v", "quiet", "-y", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path], input=pcm, check=True)


def rms_db(x):
    return 20.0 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)


def level(pair, db):
    """Both channels by the same gain, the loudest half second brought to `db`."""
    both = pair[0] + pair[1]
    w = SR // 2
    peak_rms = max(np.sqrt(np.mean(both[i:i + w] ** 2)) * 0.5 for i in range(0, max(1, len(both) - w), w // 2))
    g = 10.0 ** (db / 20.0) / (peak_rms + 1e-9)
    top = max(np.max(np.abs(pair[0])), np.max(np.abs(pair[1]))) * g
    if top > 0.97:
        g *= 0.97 / top
    return pair[0] * g, pair[1] * g


def fade(x, a, b):
    """In over `a` seconds, out over `b`, on a curve (no start you could hear)."""
    x = x.copy()
    na, nb = min(int(SR * a), len(x) // 2), min(int(SR * b), len(x) // 2)
    if na > 0:
        x[:na] *= np.sin(np.linspace(0.0, np.pi / 2.0, na)) ** 2
    if nb > 0:
        x[-nb:] *= np.cos(np.linspace(0.0, np.pi / 2.0, nb)) ** 2
    return x


def band(x, lo, hi):
    sos = signal.butter(3, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x, hz):
    return signal.sosfilt(signal.butter(2, hz, btype="low", fs=SR, output="sos"), x)


def repitch(x, k):
    n = int(len(x) / k)
    return np.interp(np.linspace(0.0, len(x) - 1.0, n), np.arange(len(x)), x)


def impulse(seconds, bright=3200.0, taps=()):
    """A big dark space, one ear's: the top dies first, `taps` (seconds, gain) answer early."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    noise = RNG.standard_normal(n)
    h = band(noise, 70.0, 480.0) * np.exp(-t * 6.9 / seconds)
    mid = min(1500.0, bright)
    h = h + 0.75 * band(noise, 480.0, mid) * np.exp(-t * 6.9 / (seconds * 0.6))
    if bright > mid:
        h = h + 0.35 * band(noise, mid, bright) * np.exp(-t * 6.9 / (seconds * 0.3))
    h /= np.sqrt(np.sum(h ** 2)) + 1e-9
    for at, g in taps:
        i = int(SR * (at + RNG.uniform(-0.012, 0.012)))
        if i < n:
            h[i] += g
    return h


def wet(x, h):
    return signal.fftconvolve(x, h)


def smear(x, stretch, win=4096):
    """A sound stretched by throwing its phases away: the word gone, its breath left."""
    w = np.hanning(win)
    hop_out = win // 4
    hop_in = hop_out / stretch
    n = int(len(x) * stretch) + win
    out = np.zeros(n)
    pos = 0.0
    at = 0
    while pos + win < len(x) and at + win < n:
        f = np.fft.rfft(x[int(pos):int(pos) + win] * w)
        f = np.abs(f) * np.exp(1j * RNG.uniform(0.0, 2.0 * np.pi, len(f)))
        out[at:at + win] += np.fft.irfft(f) * w
        pos += hop_in
        at += hop_out
    return out[:at + win]


def echoes(x, delay, feedback, turns):
    """Down a long stair: each repeat darker than the one before."""
    d = int(SR * delay)
    out = np.zeros(len(x) + d * turns)
    g = 1.0
    y = x
    for i in range(turns):
        out[i * d:i * d + len(y)] += y * g
        g *= feedback
        y = low(y, 2600.0 - 220.0 * i if 2600.0 - 220.0 * i > 500.0 else 500.0)
    return out


def drift(a, b, rate):
    """From ear to ear, slowly: a pair panned by a sine, nowhere to point at."""
    n = min(len(a), len(b))
    t = np.arange(n) / SR
    p = 0.5 + 0.5 * np.sin(2.0 * np.pi * rate * t + RNG.uniform(0.0, 6.28))
    return a[:n] * np.sqrt(1.0 - 0.8 * p), b[:n] * np.sqrt(0.2 + 0.8 * p)


def loudest(x, seconds):
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


def voice(x, how):
    """One splinter, a stereo pair, up out of its echo and back into it."""
    hall = RNG.uniform(2.6, 4.6)
    hl, hr = impulse(hall), impulse(hall)
    if how == 0:
        # A word stretched to a breath, the word itself a long way under it.
        ghost = smear(x, RNG.uniform(3.5, 6.0))
        mid = len(ghost) // 3
        under = np.zeros(len(ghost))
        n = min(len(x), len(ghost) - mid)
        under[mid:mid + n] = x[:n] * 0.28
        dry = ghost * 0.8 + under
        wet_share = 0.72
    elif how == 1:
        # Backwards up out of its own echo, cut off where the word would begin.
        short = impulse(1.8, 2600.0)
        dry = signal.fftconvolve(x[::-1], short)
        dry = dry / (np.max(np.abs(dry)) + 1e-9)
        dry = dry * np.linspace(0.15, 1.0, len(dry)) ** 2
        wet_share = 0.45
    elif how == 2:
        # A syllable caught and falling away.
        g = min(len(x), int(SR * RNG.uniform(0.09, 0.2)))
        a = int(RNG.integers(0, max(1, len(x) - g)))
        grain = fade(x[a:a + g], 0.012, 0.03)
        dry = echoes(grain, RNG.uniform(0.13, 0.27), RNG.uniform(0.72, 0.84), 14)
        wet_share = 0.62
    else:
        # Two whispers rubbing together: the same thing a shade apart, a slow comb through it.
        a = repitch(x, 0.97)
        b = repitch(x, 1.03)
        n = min(len(a), len(b))
        t = np.arange(n) / SR
        dry = a[:n] + np.roll(b[:n], int(SR * 0.014))
        dry = dry * (0.7 + 0.3 * np.sin(2.0 * np.pi * RNG.uniform(3.0, 7.0) * t))
        wet_share = 0.66
    # Through the skull: no top, no bottom.
    dry = band(dry, 220.0, 3100.0)
    dry = dry / (np.max(np.abs(dry)) + 1e-9)
    left, right = wet(dry, hl), wet(dry, hr)
    gain = np.max(np.abs(left)) + 1e-9
    n = len(left)
    pad = np.zeros(n)
    pad[:len(dry)] = dry * (1.0 - wet_share)
    left, right = pad + left / gain * wet_share, pad + right / gain * wet_share
    left, right = drift(left, right, RNG.uniform(0.12, 0.45))
    # What is left of it after five seconds is nothing anybody needs.
    n = min(len(left), int(SR * RNG.uniform(4.5, 7.0)))
    a_in = RNG.uniform(0.5, 1.1) if how != 1 else 1.4
    return fade(left[:n], a_in, 1.6), fade(right[:n], a_in, 1.6)


def voices(n):
    src = [sfx(s) for s in SOURCES]
    src = [s for s in src if len(s) > SR // 3]
    for i in range(n):
        x = loudest(src[i % len(src)], RNG.uniform(0.5, 1.15))
        x = repitch(x, RNG.choice([0.56, 0.63, 0.71, 0.84, 1.19]))
        left, right = voice(x, i % 4)
        left, right = level((left, right), -24.0)
        write(os.path.join(OUT, "voice_%02d.ogg" % (i + 1)), left, right)


def thuds(n):
    for i in range(n):
        ln = RNG.uniform(0.34, 0.6)
        t = np.arange(int(SR * ln)) / SR
        f0 = RNG.uniform(58.0, 88.0)
        drop = f0 * np.exp(-t * RNG.uniform(5.0, 11.0)) + 32.0
        body = np.sin(2.0 * np.pi * np.cumsum(drop) / SR) * np.exp(-t * RNG.uniform(7.0, 13.0))
        crack = low(RNG.standard_normal(len(t)), 900.0) * np.exp(-t * 60.0) * 0.5
        ring = np.zeros_like(t)
        if i % 2 == 1:
            for f in (311.0, 487.0, 743.0):
                ring += np.sin(2.0 * np.pi * f * RNG.uniform(0.9, 1.1) * t)
            ring *= np.exp(-t * 12.0) * 0.08
        x = np.tanh((body + crack + ring) * 2.0)
        hall = RNG.uniform(3.2, 5.0)
        hl, hr = impulse(hall, 1100.0), impulse(hall, 1100.0)
        left, right = wet(x, hl), wet(x, hr)
        g = np.max(np.abs(left)) + 1e-9
        left, right = left / g, right / g
        pad = np.zeros(len(left))
        pad[:len(x)] = x * 0.3
        left, right = left * 0.8 + pad, right * 0.8 + pad
        # Every third one comes at you first: the blow's echo backwards, then the blow.
        if i % 3 == 2:
            swell = (left[::-1])[-int(SR * 1.6):]
            left = np.concatenate([swell * 0.5, left])
            right = np.concatenate([(right[::-1])[-int(SR * 1.6):] * 0.5, right])
        n = min(len(left), int(SR * 5.5))
        left, right = level((fade(left[:n], 0.01, 1.8), fade(right[:n], 0.01, 1.8)), -18.0)
        write(os.path.join(OUT, "thud_%02d.ogg" % (i + 1)), left, right)


def ring():
    """Eight seconds, every tone a whole number of cycles, so it loops without a seam."""
    n = SR * 8
    t = np.arange(n) / SR
    pair = []
    for ch in range(2):
        a = np.sin(2.0 * np.pi * (4100.0 + ch * 3.0) * t + 1.2 * np.sin(2.0 * np.pi * 0.25 * t + ch))
        b = np.sin(2.0 * np.pi * (6275.0 - ch * 2.0) * t + 0.8 * np.sin(2.0 * np.pi * 0.375 * t))
        beat = 0.6 + 0.4 * np.sin(2.0 * np.pi * 0.75 * t + ch * 1.4)
        # The hiss: filtered on a doubled copy, so the loop's end meets its start.
        noise = RNG.standard_normal(n)
        sos = signal.butter(2, [2800.0, 3600.0], btype="band", fs=SR, output="sos")
        hiss = signal.sosfilt(sos, np.concatenate([noise, noise]))[n:]
        hiss /= np.max(np.abs(hiss)) + 1e-9
        pair.append((a * 0.5 + b * 0.32) * beat + hiss * 0.22 * (0.7 + 0.3 * np.sin(2.0 * np.pi * 0.125 * t)))
    left, right = level((pair[0], pair[1]), -22.0)
    write(os.path.join(OUT, "ring.ogg"), left, right)


def far_call():
    """The Silent Man's call a long way off: thin, no top, mostly the field's own answer."""
    x = load(os.path.join(HERE, "raw", "sm_lure_a.mp3"))
    x = band(x, 170.0, 1700.0)
    taps = ((0.21, 0.5), (0.37, 0.34), (0.61, 0.24), (0.97, 0.13))
    hl, hr = impulse(3.4, 1500.0, taps), impulse(3.4, 1500.0, taps)
    left, right = wet(x, hl), wet(x, hr)
    g = np.max(np.abs(left)) + 1e-9
    pad = np.zeros(len(left))
    pad[:len(x)] = x / (np.max(np.abs(x)) + 1e-9) * 0.3
    left, right = left / g * 0.85 + pad, right / g * 0.85 + pad
    n = min(len(left), int(SR * 9.0))
    left, right = level((fade(left[:n], 0.25, 2.2), fade(right[:n], 0.25, 2.2)), -21.0)
    write(os.path.join(GODOT, "assets", "sfx", "npc", "sm_call_far.ogg"), left, right)


def main():
    voices(12)
    thuds(6)
    ring()
    far_call()
    print("wrote", len(os.listdir(OUT)), "files in", os.path.relpath(OUT, GODOT))


if __name__ == "__main__":
    main()
