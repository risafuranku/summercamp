#!/usr/bin/env python3
"""Cuts a film made with Godot's --write-movie (MJPEG .avi) down to the work between its marks
(tools/movie_driver.gd writes <movie>.marks beside it: "start N", "end M" in frames), and
writes beside it <movie>_cut.avi (the same MJPEG frames, nothing re-encoded) and
<movie>.webp (a small animated preview, 640 wide, 15 frames a second).

    python tools/movie_cut.py OUT/till.avi [--fps 30]

No ffmpeg: the frames are the JPEGs in the AVI's 00dc chunks, written back into a minimal
RIFF AVI (avih, strh, strf, movi, idx1).
"""
import io
import os
import struct
import sys

from PIL import Image


def frames_of(path):
    """The JPEG frames of an MJPEG AVI, in order."""
    data = open(path, "rb").read()
    out = []
    # Walk the movi list chunk by chunk: the video frames are 00db or 00dc (Godot writes
    # 00db), the sound 01wb.
    i = data.find(b"movi")
    if i < 0:
        return out
    i += 4
    while i < len(data) - 8:
        cid = data[i:i + 4]
        size = struct.unpack("<I", data[i + 4:i + 8])[0]
        if cid in (b"00db", b"00dc"):
            chunk = data[i + 8:i + 8 + size]
            if chunk[:2] == b"\xff\xd8":
                out.append(chunk)
        elif cid == b"idx1":
            break
        i += 8 + size + (size & 1)
    return out


def marks_of(path):
    marks = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            parts = line.split()
            if len(parts) == 2:
                marks[parts[0]] = int(parts[1])
    return marks


def write_avi(path, frames, fps):
    first = Image.open(io.BytesIO(frames[0]))
    w, h = first.size
    n = len(frames)
    movi = io.BytesIO()
    idx = io.BytesIO()
    offset = 4
    for f in frames:
        pad = len(f) & 1
        movi.write(b"00dc" + struct.pack("<I", len(f)) + f + (b"\0" if pad else b""))
        idx.write(b"00dc" + struct.pack("<III", 0x10, offset, len(f)))
        offset += 8 + len(f) + pad
    movi_data = b"movi" + movi.getvalue()
    biggest = max(len(f) for f in frames)
    avih = struct.pack("<IIIIIIIIII4I", int(1000000 / fps), biggest * fps, 0, 0x10, n, 0, 1, biggest, w, h, 0, 0, 0, 0)
    strh = struct.pack("<4s4sIHHIIIIIIIIhhhh", b"vids", b"MJPG", 0, 0, 0, 0, 1, fps, 0, n, biggest, 0xFFFFFFFF, 0, 0, 0, w, h)
    strf = struct.pack("<IiiHH4sIiiII", 40, w, h, 1, 24, b"MJPG", w * h * 3, 0, 0, 0, 0)

    def chunk(cid, payload):
        return cid + struct.pack("<I", len(payload)) + payload + (b"\0" if len(payload) & 1 else b"")

    def lst(kind, payload):
        return b"LIST" + struct.pack("<I", len(payload) + 4) + kind + payload

    strl = lst(b"strl", chunk(b"strh", strh) + chunk(b"strf", strf))
    hdrl = lst(b"hdrl", chunk(b"avih", avih) + strl)
    body = b"AVI " + hdrl + b"LIST" + struct.pack("<I", len(movi_data)) + movi_data + chunk(b"idx1", idx.getvalue())
    with open(path, "wb") as fh:
        fh.write(b"RIFF" + struct.pack("<I", len(body)) + body)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = sys.argv[1]
    fps = int(sys.argv[sys.argv.index("--fps") + 1]) if "--fps" in sys.argv else 30
    base = os.path.splitext(src)[0]
    frames = frames_of(src)
    marks = marks_of(base + ".marks")
    a = max(0, min(len(frames) - 1, marks.get("start", 0)))
    b = max(a + 1, min(len(frames), marks.get("end", len(frames))))
    cut = frames[a:b]
    write_avi(base + "_cut.avi", cut, fps)
    step = max(1, fps // 15)
    pics = []
    for f in cut[::step]:
        im = Image.open(io.BytesIO(f)).convert("RGB")
        pics.append(im.resize((640, round(im.height * 640 / im.width)), Image.Resampling.BOX))
    if pics:
        pics[0].save(base + ".webp", save_all=True, append_images=pics[1:], duration=int(1000 / (fps / step)), loop=0, quality=70)
    print("%s: %d frames, kept %d..%d (%d, %.1f s) -> %s_cut.avi, %s.webp" % (src, len(frames), a, b, len(cut), len(cut) / fps, base, base))
    return 0


if __name__ == "__main__":
    sys.exit(main())
