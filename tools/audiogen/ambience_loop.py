#!/usr/bin/env python3
"""A generated ambience clip (wind, leaves, rain) made into a seamless loop: its last
`fade` seconds cross-faded (equal power) into its start, the rest kept, written as OGG
(MP3's encoder delay leaves a gap at the top of every repeat).

    python tools/audiogen/ambience_loop.py <src.mp3|wav> <dest.ogg relative to godot/> [fade=2.0] [--trim] [--lufs=-23]

--trim: the silence at its start and end cut off first (ElevenLabs pads some clips with
half a second of it: a gap in every repeat even when cross-faded). --lufs: brought to
that integrated loudness (linear gain, as normalize.py; the true peak kept under -2 dBTP),
else as loud as it came.

Then set loop=true in the OGG's .import: Godot imports it unlooped, and a loop set on the
stream in code does not travel to a co-op client (it plays a mirrored sound by its path,
once). A loop file is only a loop: one-shots of the same sound stay their own file.
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
RATE = 44100


def decode(src: str) -> np.ndarray:
    raw = subprocess.run([FF, "-v", "error", "-i", src, "-f", "s16le", "-ac", "2", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).reshape(-1, 2).astype(np.float32) / 32768.0


def trim(a: np.ndarray, db: float = -60.0) -> np.ndarray:
    loud = np.nonzero(np.abs(a).max(axis=1) > 10 ** (db / 20.0))[0]
    return a[loud[0]:loud[-1] + 1] if loud.size else a


def main() -> None:
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    opts = dict((x[2:].split("=", 1) + [""])[:2] for x in sys.argv[1:] if x.startswith("--"))
    src, dest = args[0], args[1]
    fade = float(args[2]) if len(args) > 2 else 2.0
    a = decode(src)
    if "trim" in opts:
        a = trim(a)
    n = int(fade * RATE)
    if len(a) < n * 3:
        sys.exit("clip too short for a %.1f s cross-fade" % fade)
    t = np.linspace(0.0, 1.0, n)[:, None]
    head, body, tail = a[:n], a[n:-n], a[-n:]
    # The tail fades out over the head fading in: the loop's end runs into its start.
    seam = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    out = np.concatenate([body, seam])
    tmp = os.path.join(HERE, "_loop_tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(out, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes())
    gain = 0.0
    if opts.get("lufs"):
        lufs = float(opts["lufs"])
        m = normalize.measure(tmp, lufs, -2)
        gain = min(lufs - float(m["input_i"]), -2.0 - float(m["input_tp"]))
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run([FF, "-v", "error", "-y", "-i", tmp, "-af", "volume=%.2fdB" % gain, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)
    print(dest, "%.1f s" % (len(out) / RATE), "gain %.1f dB" % gain if gain else "")


if __name__ == "__main__":
    main()
