#!/usr/bin/env python3
"""The reception desk close-up's art (scripts/reception/checkin_desk.gd) from the Grok
renders, at the sizes the 480x270 desk draws them, snapped to the game palette:

    python tools/artgen/desk_art.py
-> godot/assets/textury/desk/desk_top.png, desk_view.png, register.png, booking.png,
   id_card.png, key_rack.png, key_fob.png, stamp.png, bell.png
   and godot/assets/textury/camp/key_rack.png for the board on the office wall.
"""
import os

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "desk")
CAMP = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "camp")


def raw(art_id):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    return Image.open(path) if os.path.exists(path) else None


def flat(art_id, size, name):
    img = raw(art_id)
    if img is None:
        print("missing", art_id)
        return
    img = img.convert("RGB").resize(size, Image.Resampling.BOX)
    process.snap(img, False).save(os.path.join(OUT, name))
    print(name, size)


def cut(art_id, size, name):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    if not os.path.exists(path):
        print("missing", art_id)
        return
    img = process.key_out(Image.open(path))
    bbox = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    img = img.crop(bbox)
    # Fit inside `size`, centred, on transparent.
    k = min(size[0] / img.width, size[1] / img.height)
    small = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.Resampling.BOX)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(small, ((size[0] - small.width) // 2, (size[1] - small.height) // 2))
    process.snap(canvas, True).save(os.path.join(OUT, name))
    print(name, size)


def card():
    img = raw("doc_id")
    if img is None:
        print("missing doc_id")
        return
    img = img.convert("RGB")
    # The card fills the frame; trim a sliver of edge and fit 108x70.
    w, h = img.size
    img = img.crop((int(w * 0.02), int(h * 0.03), int(w * 0.98), int(h * 0.97)))
    process.snap(img.resize((108, 70), Image.Resampling.BOX), False).save(os.path.join(OUT, "id_card.png"))
    print("id_card.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    flat("desk_top", (480, 270), "desk_top.png")
    flat("desk_view", (480, 270), "desk_view.png")
    flat("doc_register", (226, 150), "register.png")
    flat("doc_booking", (88, 118), "booking.png")
    flat("key_rack", (178, 100), "key_rack.png")
    cut("key_fob", (20, 20), "key_fob.png")
    cut("desk_stamp", (42, 38), "stamp.png")
    cut("desk_bell", (48, 40), "bell.png")
    card()
    # The same board, bigger, for the wall of the office.
    rack = raw("key_rack")
    if rack is not None:
        process.snap(rack.convert("RGB").resize((256, 144), Image.Resampling.BOX), False).save(os.path.join(CAMP, "key_rack.png"))
        print("camp/key_rack.png")


if __name__ == "__main__":
    main()
