#!/usr/bin/env python3
"""The staffroom's renders (rows in prompts_staff.tsv, written by staff_prompts.py) from
tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/staff_art.py [id ...]     (all when none are given)

- textures, faces and sprites into assets/textury/camp/ (and ui/, builder/, closeup/);
- the laptop close-up (cu_laptop): 480x270 on the palette, its screen (the flat magenta)
  painted black, the screen's four corners measured on the render into
  assets/textury/closeup/laptop_screen.json (shares of the picture: tl, tr, br, bl);
- the hands' sheets (stp_<slug>): sitting, lying, sweeping, cut apart and scaled alike
  so that lying they are as long as they stand tall (128 px), into
  assets/textury/npc/staff/<slug>_sit.png, _lie.png, _sweep.png, the rim defringed.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import defringe  # noqa: E402
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")

# (id, mode, size, dest relative to godot/)
ROWS = [
    ("tex_staff_plaster", "texture", 128, "assets/textury/camp/staff_plaster.png"),
    ("tex_staff_tarpaper", "texture", 128, "assets/textury/camp/staff_tarpaper.png"),
    ("tex_staff_plinth", "texture", 128, "assets/textury/camp/staff_plinth.png"),
    ("face_staff_door", "panel", 64, "assets/textury/camp/staff_door.png"),
    ("face_staff_steel_door", "panel", 64, "assets/textury/camp/staff_steel_door.png"),
    ("iso_staffroom", "sprite", 170, "assets/textury/builder/iso_staffroom.png"),
    ("tex_staff_wall_in", "texture", 128, "assets/textury/camp/staff_wall_in.png"),
    ("tex_staff_lino", "texture", 128, "assets/textury/camp/staff_lino.png"),
    ("tex_sofa_cord", "texture", 96, "assets/textury/camp/sofa_cord.png"),
    ("tex_formica", "texture", 96, "assets/textury/camp/staff_formica.png"),
    ("face_staff_fridge", "panel", 64, "assets/textury/camp/staff_fridge.png"),
    ("spr_coffee_maker", "sprite", 40, "assets/textury/camp/coffee_maker.png"),
    ("face_staff_tv", "panel", 96, "assets/textury/camp/staff_tv.png"),
    ("face_tvshow_testcard", "panel", 96, "assets/textury/camp/tvshow_testcard.png"),
    ("face_tvshow_forest", "panel", 96, "assets/textury/camp/tvshow_forest.png"),
    ("face_tvshow_weather", "panel", 96, "assets/textury/camp/tvshow_weather.png"),
    ("face_bozp_poster", "panel", 56, "assets/textury/camp/bozp_poster.png"),
    ("face_laptop_keys", "panel", 96, "assets/textury/camp/laptop_keys.png"),
    ("face_laptop_lid", "panel", 64, "assets/textury/camp/laptop_lid.png"),
    ("tex_kotelna_wall", "texture", 128, "assets/textury/camp/kotelna_wall.png"),
    ("tex_kotelna_floor", "texture", 128, "assets/textury/camp/kotelna_floor.png"),
    ("face_kotel", "panel", 72, "assets/textury/camp/kotel.png"),
    ("face_locker", "panel", 48, "assets/textury/camp/staff_locker.png"),
    ("face_locker_open", "panel", 48, "assets/textury/camp/staff_locker_open.png"),
    ("tex_mattress_stain", "texture", 96, "assets/textury/camp/mattress_stain.png"),
    ("spr_coal_pile", "sprite", 44, "assets/textury/camp/coal_pile.png"),
    ("card_locker", "sprite", 60, "assets/textury/closeup/parts/card_locker.png"),
    ("card_mattress", "sprite", 40, "assets/textury/closeup/parts/card_mattress.png"),
    ("spr_hud_post", "sprite", 7, "assets/textury/ui/post_van.png"),
    ("spr_hud_parcel", "sprite", 9, "assets/textury/ui/post_parcel.png"),
    ("card_armchair", "sprite", 44, "assets/textury/closeup/parts/card_armchair.png"),
    ("tex_armchair", "texture", 96, "assets/textury/camp/armchair_fabric.png"),
    ("spr_icon_staff", "sprite", 32, "assets/textury/os98/icons/staff_app.png"),
    ("spr_icon_staff", "sprite", 16, "assets/textury/os98/icons/staff_app_16.png"),
]
HANDS = ["dvorakova", "hanka", "zdenka", "ivan", "mirek", "marta", "jaromir"]
LIE_LEN = 124


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return p if os.path.exists(p) else None


def laptop():
    src = raw("cu_laptop")
    if src is None:
        print("skip (no render) cu_laptop")
        return
    img = Image.open(src).convert("RGB")
    w, h = img.size
    px = img.load()
    pts = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if process.is_key(r, g, b):
                pts.append((x, y))
    if not pts:
        print("FAIL laptop: no screen")
        return
    tl = min(pts, key=lambda p: p[0] + p[1])
    br = max(pts, key=lambda p: p[0] + p[1])
    tr = max(pts, key=lambda p: p[0] - p[1])
    bl = min(pts, key=lambda p: p[0] - p[1])
    for x, y in pts:
        px[x, y] = (6, 8, 8)
    small = img.resize((480, 270), Image.Resampling.BOX)
    out = process.snap(small, False)
    dest = os.path.join(GODOT, "assets/textury/closeup/laptop.png")
    out.save(dest)
    corners = [[c[0] / w, c[1] / h] for c in (tl, tr, br, bl)]
    with open(os.path.join(GODOT, "assets/textury/closeup/laptop_screen.json"), "w", encoding="utf-8") as f:
        json.dump({"corners": corners}, f)
    print("laptop", out.size, corners)


def hand(slug):
    src = raw("stp_" + slug)
    if src is None:
        print("skip (no render)", slug)
        return
    img = process.key_out(Image.open(src))
    boxes, labels, w = split_sheet.items(img, 14)
    parts = [split_sheet.own(img, b, labels[b], w) for b in boxes]
    parts = [p for p in parts if max(p.width, p.height) > img.height * 0.25]
    if len(parts) != 3:
        print("FAIL", slug, "found", len(parts), "figures")
        return
    sit, lie, sweep = parts
    scale = LIE_LEN / float(lie.width)
    for name, part in (("sit", sit), ("lie", lie), ("sweep", sweep)):
        small = split_sheet.shrink(part, scale)
        path = os.path.join(GODOT, "assets/textury/npc/staff", "%s_%s.png" % (slug, name))
        small.save(path)
        print(slug, name, small.size, defringe.figure(path, []))


def main():
    want = set(sys.argv[1:])
    for art_id, mode, size, dest in ROWS:
        if want and art_id not in want:
            continue
        src = raw(art_id)
        if src is None:
            print("skip (no render)", art_id)
            continue
        if mode == "sprite":
            out = process.sprite(src, size)
        elif mode == "panel":
            out = process.panel(src, size)
        else:
            out = process.texture(src, size)
        path = os.path.join(GODOT, dest)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if "/os98/icons/" in dest:
            # Square like the other icons, the picture in the middle.
            sq = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            sq.paste(out, ((size - out.width) // 2, (size - out.height) // 2))
            out = sq
        out.save(path)
        print(art_id, "->", dest, out.size)
    if not want or "cu_laptop" in want:
        laptop()
    for slug in HANDS:
        if not want or ("stp_" + slug) in want:
            hand(slug)


if __name__ == "__main__":
    main()
