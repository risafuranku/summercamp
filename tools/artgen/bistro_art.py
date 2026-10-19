#!/usr/bin/env python3
"""The bistro's art (scripts/bistro/): Grok renders in tools/artgen/out/<id>/raw.png
(rows in prompts_bistro.tsv, written by bistro_prompts.py) into the game's files.

    python tools/artgen/bistro_art.py [name ...]     (all when no names are given)

- station screens: 16:9 paintings to 640x360 (assets/textury/bistro/st_*.png);
- sprites over them: keyed off the magenta with the magenta-tinted rim taken too (a
  fried slice came out with a red edge otherwise), box-downsampled to a height, snapped
  to the palette;
- sheets: a row of things on magenta cut apart (split_sheet.py's finder), each to its
  own height;
- the rooms' things: the same, into assets/textury/camp/ (interior_kit's cutouts).
A missing render is skipped with a note.
"""
import colorsys
import os
import random
import sys

from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
B = "assets/textury/bistro/"
CAMP = "assets/textury/camp/"
UI = "assets/textury/ui/"

# The station screens are 320x180 Build-engine textures (playtest 19. 10.: "less like AI
# pixel art, more like imperfect human Build-engine textures"), drawn two screen-canvas
# pixels to one (scripts/bistro/station_view.gd PIX): the things on them are made at that
# size too.
PANELS = [
    ("bt_stove", "st_stove"), ("bt_pass", "st_pass"), ("bt_pot", "st_pot"), ("bt_sink", "st_sink"),
    ("bt_potatoes", "st_potatoes"), ("bt_breading", "st_breading"), ("bt_machine", "st_machine"),
]
PANEL_W = 320
# The things over them in the game's 256 colours too (a 1996 artist had one palette).
SNAP_STATIONS = True
# (render id, height, file under godot/)
SPRITES = [
    ("cu_smoke", 15, B + "smoke.png"), ("cu_oil_spit", 7, B + "oil_spit.png"),
    ("cu_ticket_tall", 54, B + "ticket.png"), ("cu_ticket_tall_old", 54, B + "ticket_old.png"),
    # The rooms' tables: plates at the room's pixel (service_life.gd).
    ("spr_plate", 24, B + "table_plate.png"), ("spr_goulash", 14, B + "table_goulash.png"),
    ("spr_cheese", 12, B + "table_cheese.png"), ("spr_fries", 11, B + "table_fries.png"),
    ("spr_dumpling", 7, B + "table_dumpling.png"),
]
# (render id, [(name, [(height, file under godot/), ...]) left to right], gap)
SHEETS = [
    ("bts_fry", [("raw", [(30, B + "slice_raw.png"), (19, B + "slice_raw_small.png")]),
                 ("golden", [(30, B + "slice_golden.png"), (19, B + "slice_golden_small.png")]),
                 ("burnt", [(30, B + "slice_burnt.png")]),
                 ("basket", [(35, B + "basket_empty.png")]), ("basket_raw", [(35, B + "basket_raw.png")]),
                 ("basket_gold", [(35, B + "basket_gold.png")])], 14),
    ("bts_plate", [("plate", [(60, B + "plate_top.png")]), ("goulash", [(29, B + "food_goulash.png")]),
                   ("dumpling", [(13, B + "food_dumpling.png"), (8, B + "dumpling_slice.png")]),
                   ("cheese", [(25, B + "food_cheese.png")]),
                   ("fries", [(25, B + "food_fries.png"), (15, B + "chips_rack.png")]),
                   ("tartar", [(13, B + "food_tartar.png")]), ("onion", [(9, B + "food_onion.png")]),
                   ("dirty", [(60, B + "plate_dirty.png")])], 14),
    ("bts_cellar", [("potato", [(10, B + "potato_raw.png")]), ("peeled", [(10, B + "potato_peeled.png")]),
                    ("heap", [(13, B + "chips_heap.png"), (16, B + "chips_bucket.png")]), ("loaf", [(44, B + "loaf.png")]),
                    ("plain", [(30, B + "cheese_plain.png")]), ("floured", [(30, B + "cheese_floured.png")]),
                    ("egged", [(30, B + "cheese_egged.png")])], 14),
    ("bts_misc", [("breaded", [(30, B + "cheese_breaded.png")]),
                  ("patchy", [(30, B + "cheese_patchy.png"), (30, B + "slice_bad.png"), (19, B + "slice_bad_small.png")]),
                  ("stack", [(32, B + "plates_stack.png")]), ("sponge", [(13, B + "sponge.png")]),
                  ("spoon", [(60, B + "spoon.png")]), ("star", [(9, B + "star.png")]), ("star_dim", [(9, B + "star_dim.png")])], 14),
    ("bsh_plates", [("clean", []), ("dirty", []), ("stack", []), ("sponge", []), ("bubbles", [(8, B + "bubbles.png")])], 14),
    ("bsh_marks", [("stir", [(18, UI + "mark_pot.png")]), ("pan", []), ("plates", [(18, UI + "mark_wash2.png")]),
                   ("potato", [(16, UI + "mark_potato.png")]), ("slice", [(14, UI + "mark_slice.png")]),
                   ("dumpling", [(14, UI + "mark_dumpling.png")]), ("bell", [(16, UI + "mark_bell.png")]),
                   ("ticket", [(16, UI + "mark_ticket.png")])], 14),
    ("bsh_dining", [("cakes", [(46, CAMP + "bistro_cakes.png")]), ("tap", [(40, CAMP + "bistro_tap.png")]),
                    ("flypaper", [(46, CAMP + "bistro_flypaper.png")]), ("tv", [(46, CAMP + "bistro_tv.png")]),
                    ("vase", [(26, CAMP + "bistro_vase.png")]), ("cruet", [(14, CAMP + "bistro_cruet.png")]),
                    ("coatstand", [(120, CAMP + "bistro_coatstand.png")])], 14),
    ("bsh_kitchen", [("ladles", [(46, CAMP + "bistro_ladles.png")]), ("knives", [(22, CAMP + "bistro_knives.png")]),
                     ("zapper", [(26, CAMP + "bistro_zapper.png")]), ("dirty", [(40, CAMP + "bistro_dirtyplates.png")]),
                     ("platerack", [(50, CAMP + "bistro_platerack.png")]), ("flour", [(50, CAMP + "bistro_flour.png")]),
                     ("stockpot", [(34, CAMP + "bistro_stockpot.png")])], 14),
    ("bsh_cellar", [("peeler", [(100, CAMP + "bistro_peeler.png")]), ("cutter", [(46, CAMP + "bistro_cutter.png")]),
                    ("jars", [(40, CAMP + "bistro_jars.png")]), ("cobweb", [(46, CAMP + "bistro_cobweb.png")]),
                    ("rat", [(16, CAMP + "bistro_rat.png")]), ("trap", [(9, CAMP + "bistro_trap.png")]),
                    ("bulb", [])], 14),
]
# Textures (render id, size, file).
TEXTURES = [
    ("tex_steel_brushed", 128, CAMP + "steel_brushed.png"),
    ("tex_kitchen_tiles", 128, CAMP + "kitchen_tiles.png"),
]


def despilled(art_id):
    """The render with every magenta-tinted pixel turned to the key (so no red or pink rim
    is left on a slice's edge when it is keyed and shrunk)."""
    src = os.path.join(OUT, art_id, "raw.png")
    img = Image.open(src).convert("RGB")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y]
            if r - g > 50 and b - g > 35:
                px[x, y] = (255, 0, 255)
    path = os.path.join(OUT, art_id, "raw_despilled.png")
    img.save(path)
    return path


def _rim(im):
    """Pink or red edge pixels left by the key go (two passes)."""
    px = im.load()
    w, h = im.size
    for _ in range(2):
        drop = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                hh *= 360.0
                if not (s > 0.3 and v > 0.25 and (hh >= 285.0 or hh <= 6.0) and r > g + 50):
                    continue
                if any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    drop.append((x, y))
        for x, y in drop:
            px[x, y] = (0, 0, 0, 0)
    return im


def _shrink(img, height, snap):
    """Box-downsampled to `height` (premultiplied, so the clear pixels do not darken the
    edge). The station screens' things keep their own colours (the palette has no deep
    orange: a golden slice came out red); the rooms' things are snapped to it."""
    # `height` is the longer side (a slice lies flat, a spoon lies along).
    k = height / float(max(img.width, img.height))
    w = max(1, round(img.width * k))
    height = max(1, round(img.height * k))
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, height), Image.Resampling.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    if snap:
        return process.snap(buildify(small, 6), True)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
    return small


def buildify(img, grit, seed=7):
    """What makes it read as a 1996 texture and not a smooth render: sharpened after the
    shrink (crunchy edges) and a grain of noise on every pixel (the scanned-and-retouched
    grit), before the palette."""
    alpha = img.getchannel("A") if img.mode == "RGBA" else None
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1, percent=80, threshold=1))
    rnd = random.Random(seed)
    px = rgb.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = px[x, y]
            n = rnd.randint(-grit, grit)
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    if alpha is not None:
        rgb = rgb.convert("RGBA")
        rgb.putalpha(alpha)
    return rgb


# The fried slices came out standing up: laid on their side for the pan and the trays.
LAY_FLAT = ("slice_raw", "slice_golden", "slice_burnt", "slice_bad")


def _save(im, dest):
    if os.path.basename(dest).startswith(LAY_FLAT) and im.height > im.width:
        im = im.transpose(Image.Transpose.ROTATE_90)
    path = os.path.join(process.GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("  %s %s" % (dest, im.size))


def _have(art_id):
    ok = os.path.exists(os.path.join(OUT, art_id, "raw.png"))
    if not ok:
        print("  (no render yet: %s)" % art_id)
    return ok


def do_panels(want):
    for art_id, name in PANELS:
        if (want and name not in want and art_id not in want) or not _have(art_id):
            continue
        src = Image.open(os.path.join(OUT, art_id, "raw.png")).convert("RGB")
        small = src.resize((PANEL_W, round(src.height * PANEL_W / src.width)), Image.Resampling.BOX)
        _save(process.snap(buildify(small, 12), False), B + name + ".png")


def do_sprites(want):
    for art_id, h, dest in SPRITES:
        if (want and art_id not in want and os.path.basename(dest)[:-4] not in want) or not _have(art_id):
            continue
        img = process.key_out(Image.open(despilled(art_id)))
        img = img.crop(img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
        _save(_rim(_shrink(img, h, SNAP_STATIONS or not dest.startswith(B))), dest)


def do_sheets(want):
    for art_id, items, gap in SHEETS:
        if (want and art_id not in want) or not _have(art_id):
            continue
        img = process.key_out(Image.open(despilled(art_id)))
        boxes, labels, w = split_sheet.items(img, gap)
        if len(boxes) != len(items):
            print("  %s: found %d things, want %d (see out/%s/_cut.png)" % (art_id, len(boxes), len(items), art_id))
            from PIL import ImageDraw
            check = img.copy()
            d = ImageDraw.Draw(check)
            for i, b in enumerate(boxes):
                d.rectangle(b, outline=(0, 255, 0, 255))
                d.text((b[0], max(0, b[1] - 12)), str(i), fill=(0, 255, 0, 255))
            check.save(os.path.join(OUT, art_id, "_cut.png"))
            continue
        for (name, outs), b in zip(items, boxes):
            one = split_sheet.own(img, b, labels[b], w)
            for h, dest in outs:
                _save(_rim(_shrink(one, h, SNAP_STATIONS or not dest.startswith(B))), dest)


def keyed_texture(art_id, size, dest):
    """A see-through texture (the chain-link): keyed off the magenta, shrunk, snapped."""
    img = process.key_out(Image.open(os.path.join(OUT, art_id, "raw.png")))
    s = min(img.size)
    img = img.crop(((img.width - s) // 2, (img.height - s) // 2, (img.width - s) // 2 + s, (img.height - s) // 2 + s))
    _save(_shrink(img, size, True), dest)


def do_textures(want):
    if (not want or "tex_chainlink" in want) and _have("tex_chainlink"):
        keyed_texture("tex_chainlink", 64, CAMP + "chainlink.png")
    for art_id, size, dest in TEXTURES:
        if (want and art_id not in want) or not _have(art_id):
            continue
        _save(process.texture(os.path.join(OUT, art_id, "raw.png"), size), dest)


def main():
    want = set(sys.argv[1:])
    do_panels(want)
    do_sprites(want)
    do_sheets(want)
    do_textures(want)


if __name__ == "__main__":
    main()
