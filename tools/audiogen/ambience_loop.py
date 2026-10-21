#!/usr/bin/env python3
"""A generated ambience clip (wind, leaves, rain) made into a seamless loop: its last
`fade` seconds cross-faded (equal power) into its start, the rest kept, written as OGG
(MP3's encoder delay leaves a gap at the top of every repeat).

    python tools/audiogen/ambience_loop.py <src.mp3|wav> <dest.ogg relative to godot/> [fade=2.0]
"""
import os
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
FF = imageio_ffmpeg.get_ffmpeg_exe()
RATE = 44100


def decode(src: str) -> np.ndarray:
    raw = subprocess.run([FF, "-v", "error", "-i", src, "-f", "s16le", "-ac", "2", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).reshape(-1, 2).astype(np.float32) / 32768.0


def main() -> None:
    src, dest = sys.argv[1], sys.argv[2]
    fade = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0
    a = decode(src)
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
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run([FF, "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", path], check=True)
    os.remove(tmp)
    print(dest, "%.1f s" % (len(out) / RATE))


if __name__ == "__main__":
    main()
