#!/usr/bin/env python3
"""A generated music clip made into a loop that does not click: a whole number of bars
cut from the first strong beat after its soft start, the end cross-faded into what led
up to that beat, brought to -23 LUFS (linear gain, as normalize.py) and written as OGG
(MP3's encoder delay leaves a gap at the top of every repeat).

    python tools/audiogen/loop_cut.py <src.mp3|wav> <dest.ogg relative to godot/> [bars=16]

The bar is found by autocorrelating the clip's onsets (a bar of four beats between 1.1
and 1.32 s: 100-ish bpm tycoon music); change BAR_RANGE for other tempi.
"""
import os
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
sys.path.insert(0, HERE)
import normalize  # noqa: E402

FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100
BAR_RANGE = (1.1, 1.32)
XFADE = 0.06


def main(src, dest, bars=16):
    raw = subprocess.run([FF, "-v", "quiet", "-i", src, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32).reshape(-1, 2) / 32768.0
    mono = x.mean(axis=1)
    hop, win = 256, 1024
    spec = np.array([np.abs(np.fft.rfft(mono[i:i + win] * np.hanning(win))) for i in range(0, len(mono) - win, hop)])
    flux = np.maximum(0, np.diff(spec, axis=0)).sum(axis=1)
    f = flux - flux.mean()
    ac = np.correlate(f, f, "full")[len(f) - 1:]
    lags = np.arange(len(ac)) * hop / SR

    def peak(lo, hi):
        m = (lags > lo) & (lags < hi)
        return lags[np.argmax(np.where(m, ac, -1e18))]

    bar = peak(*BAR_RANGE)
    length = bars * bar
    if length + 0.2 < len(mono) / SR:
        length = peak(length - 0.15, length + 0.15)
    onsets = [(i + 1) * hop / SR for i in range(len(flux)) if (i + 1) * hop / SR > 0.25 and flux[i] > np.percentile(flux, 90)]
    n0 = int(round(onsets[0] * SR))
    n = min(int(round(length * SR)), len(x) - n0 - 1)
    seg = x[n0:n0 + n].copy()
    xf = int(XFADE * SR)
    fade = np.linspace(0, 1, xf)[:, None]
    seg[-xf:] = seg[-xf:] * (1 - fade) + x[n0 - xf:n0] * fade
    tmp = os.path.join(os.environ.get("TEMP", "/tmp"), "loop_cut.wav")
    w = wave.open(tmp, "wb")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((np.clip(seg, -1, 1) * 32767).astype(np.int16).tobytes())
    w.close()
    m = normalize.measure(tmp, -23, -2)
    gain = min(-23.0 - float(m["input_i"]), -2.0 - float(m["input_tp"]))
    out = os.path.join(GODOT, dest)
    subprocess.run([FF, "-v", "quiet", "-y", "-i", tmp, "-af", "volume=%.2fdB" % gain, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    print("%s: bar %.4f s, %d bars = %.3f s from %.3f s, gain %.2f dB" % (dest, bar, bars, n / SR, n0 / SR, gain))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 16)
