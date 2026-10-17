#!/usr/bin/env python3
"""The reception office, its back room and the store: Grok renders into the game.

    python tools/artgen/office_art.py

Every row below is (artgen id, mode, size, file in godot/assets/textury/camp/). Missing
renders are skipped. Sprites on the darker magenta some renders come on are re-keyed
first. The stove's embers get a mask (stove_glow.png: the orange of the fire window,
the rest black) for office_dressing.gd to light at night.
"""
import os

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
CAMP = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "camp")

ROWS = [
    ("tex_knotty_pine2", "texture", 128, "knotty_pine.png"),
    ("tex_ceiling_pine", "texture", 128, "ceiling_pine.png"),
    ("tex_wallpaper_70s2", "texture", 128, "wallpaper_70s.png"),
    ("tex_door_interior", "panel", 72, "door_interior.png"),
    ("tex_rug_runner", "sprite", 128, "rug_runner.png"),
    ("tex_rug_rag", "sprite", 96, "rug_rag.png"),
    ("face_stove", "panel", 64, "stove.png"),
    ("spr_wall_clock", "sprite", 64, "wall_clock.png"),
    ("face_calendar", "panel", 72, "calendar.png"),
    ("face_certificate", "panel", 72, "certificate.png"),
    ("spr_extinguisher", "sprite", 96, "extinguisher.png"),
    ("spr_plant_dry", "sprite", 64, "plant_dry.png"),
    ("spr_ceiling_lamp", "sprite", 64, "ceiling_lamp.png"),
    ("face_shelf_linen", "panel", 96, "shelf_linen.png"),
    ("face_shelf_stuff", "panel", 96, "shelf_stuff.png"),
    ("face_boiler", "panel", 64, "boiler.png"),
    ("face_fusebox", "panel", 72, "fusebox.png"),
    ("spr_mop_bucket", "sprite", 96, "mop_bucket.png"),
    ("spr_gas_bottle", "sprite", 80, "gas_bottle.png"),
    ("spr_lost_found", "sprite", 72, "lost_found.png"),
    ("spr_bulb_cord", "sprite", 64, "bulb_cord.png"),
    ("face_bookshelf", "panel", 96, "bookshelf.png"),
    ("face_photo_family", "panel", 56, "photo_family.png"),
    ("spr_slippers", "sprite", 48, "slippers.png"),
    ("spr_chair_clothes", "sprite", 112, "chair_clothes.png"),
    ("spr_coat_hook", "sprite", 112, "coat_hook.png"),
    ("spr_doormat", "sprite", 64, "doormat.png"),
]


def rekeyed(art_id):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    img = Image.open(path).convert("RGB")
    px = img.load()
    r, g, b = px[2, 2]
    if g < 70 and r > 120 and b > 90 and abs(r - b) < 100 and not (r > 240 and b > 240):
        for y in range(img.height):
            for x in range(img.width):
                r, g, b = px[x, y]
                if r > 120 and g < 70 and b > 90 and abs(r - b) < 100:
                    px[x, y] = (255, 0, 255)
        path = os.path.join(HERE, "out", art_id, "raw_keyed.png")
        img.save(path)
    return path


def stove_glow():
    """The embers from the render (the palette mutes them): bright orange there, scaled
    to the face's size, white where at least a quarter of a block glowed."""
    raw = os.path.join(HERE, "out", "face_stove", "raw.png")
    face = os.path.join(CAMP, "stove.png")
    if not (os.path.exists(raw) and os.path.exists(face)):
        return
    src = Image.open(raw).convert("RGB")
    m = Image.new("L", src.size, 0)
    sp = src.load()
    mp = m.load()
    # Only inside the fire door's little window (the rust elsewhere is orange too).
    for y in range(int(src.height * 0.33), int(src.height * 0.47)):
        for x in range(int(src.width * 0.3), int(src.width * 0.7)):
            r, g, b = sp[x, y]
            if r >= 95 and r > 1.5 * g and r - b > 70:
                mp[x, y] = 255
    size = Image.open(face).size
    small = m.resize(size, Image.BOX).point(lambda v: 255 if v > 64 else 0)
    out = Image.merge("RGB", (small, small, small))
    out.save(os.path.join(CAMP, "stove_glow.png"))
    print("stove_glow.png", sum(1 for v in small.getdata() if v), "px")


def main():
    for art_id, mode, size, name in ROWS:
        raw = os.path.join(HERE, "out", art_id, "raw.png")
        if not os.path.exists(raw):
            print("missing", art_id)
            continue
        if mode == "sprite":
            out = process.sprite(rekeyed(art_id), size)
        elif mode == "panel":
            out = process.panel(raw, size)
        else:
            out = process.texture(raw, size)
        out.save(os.path.join(CAMP, name))
        print(name, out.size)
    stove_glow()


if __name__ == "__main__":
    main()
