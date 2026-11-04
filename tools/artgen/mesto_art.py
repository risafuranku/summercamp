#!/usr/bin/env python3
"""Liblice's motel and chapel (prompts_mesto.tsv, the user's 3. 11. answers): Grok's
renders into the game. Missing renders are skipped, so it can run while the queue works.

    python tools/artgen/mesto_art.py            # everything there is
    python tools/artgen/mesto_art.py doors      # only the room doors' numbers

Rows: (artgen id, mode, size, file under godot/assets/textury/). Modes are process.py's
(texture, panel, sprite) and:
  sheet    items in a row on magenta, cut left to right: size is a list of
           (file, height px) in that order;
  retable  the altar picture cut in two: the retable over the table (the wall) and the
           table's front (its own box), at `size` px wide.
The room doors get their numbers painted on the blank plate of face_motel_door_out
(town/motel_door_<n>.png), black on the aluminium, in game pixels.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402
import split_sheet  # noqa: E402

TEX = os.path.join(HERE, "..", "..", "godot", "assets", "textury")
OUT = os.path.join(HERE, "out")

ROWS = [
    # The motel, outside.
    ("tex_motel_plaster", "texture", 128, "town/motel_plaster.png"),
    ("face_motel_door_out", "panel", 64, "town/motel_door_out.png"),
    ("spr_motel_window", "sprite", 88, "town/motel_window.png"),
    ("face_motel_rail", "panelcrop", (192, 0.255, 0.635), "town/motel_rail.png"),
    ("face_motel_lobby_door", "panel", 64, "town/motel_lobby_door.png"),
    # The rooms.
    ("face_motel4_wall", "panel", 192, "camp/motel4_wall.png"),
    ("tex_motel_bedspread", "texture", 128, "camp/motel_bedspread.png"),
    ("face_motel_wardrobe", "panel", 80, "camp/motel_wardrobe.png"),
    ("face_motel_door_in", "panel", 64, "camp/motel_door_in.png"),
    ("spr_motel_basin2", "sprite", 100, "camp/motel_basin.png"),
    ("spr_motel_radiator", "sprite", 40, "camp/motel_radiator.png"),
    ("spr_motel_table", "sprite", 72, "camp/motel_table.png"),
    ("tex_motel_curtain", "texture", 128, "camp/motel_curtain.png"),
    ("spr_motel_key", "sprite", 28, "camp/motel_key.png"),
    ("spr_motel_key", "sprite", 16, "items/key_motel.png"),
    # The reception.
    ("face_motel_counter", "panel", 192, "camp/motel_counter.png"),
    ("face_motel_keyboard", "panel", 128, "camp/motel_keyboard.png"),
    ("sheet_motel_desk", "sheet", [("camp/motel_bell.png", 16), ("camp/motel_ashtray.png", 12), ("camp/motel_guestbook.png", 26)], None),
    # The chapel.
    ("face_chapel_retable", "retable", 160, None),
    ("tex_chapel_vault", "texture", 128, "camp/chapel_vault.png"),
    ("tex_chapel_lime", "texture", 128, "camp/chapel_lime.png"),
    ("face_chapel_plinth", "panel", 192, "camp/chapel_plinth.png"),
    ("spr_pew_end", "sprite", 64, "camp/pew_end.png"),
    ("face_pew_back", "panel", 160, "camp/pew_back.png"),
    ("tex_pew_wood", "texture", 128, "camp/pew_wood.png"),
    ("spr_chapel_door_in", "sprite", 168, "camp/chapel_door_in.png"),
    ("spr_chapel_oval_window", "sprite", 72, "camp/chapel_oval.png"),
    ("spr_communion_rail", "sprite", 52, "camp/communion_rail.png"),
    ("spr_harmonium", "sprite", 76, "camp/harmonium.png"),
    ("sheet_chapel_small", "sheet", [("camp/holy_water.png", 30), ("camp/collection_box.png", 64), ("camp/wall_console.png", 24)], None),
    ("spr_votive_stand", "sprite", 72, "camp/votive_stand.png"),
    ("spr_bell_rope", "sprite", 200, "camp/bell_rope.png"),
    ("sheet_stations", "sheet", [("camp/station_%d.png" % i, 40) for i in range(1, 7)], None),
    ("npc_hruba_kneel", "sprite", 84, "npc/town_hruba_kneel.png"),
    ("sheet_votive_flames", "sheet", [("camp/votive_flame_%d.png" % i, 14) for i in range(4)], None),
    # The Jednota's shop windows.
    ("spr_jednota_display_a", "sprite", 40, "camp/jednota_display_a.png"),
    ("spr_jednota_display_b", "sprite", 40, "camp/jednota_display_b.png"),
    # The chapel damp, dusty and bigger (the user, 4. 11.).
    ("face_chapel_damp_wall2", "panel", 192, "camp/chapel_damp_wall2.png"),
    ("tex_chapel_vault_damp", "texture", 128, "camp/chapel_vault_damp.png"),
    ("sheet_chapel_decay", "sheet", [("camp/decay_stain.png", 56), ("camp/decay_mould.png", 48), ("camp/decay_bricks.png", 48), ("camp/decay_crack.png", 56)], None),
    ("sheet_chapel_floor", "sheet", [("camp/floor_puddle.png", 28), ("camp/floor_plaster.png", 24), ("camp/floor_leaves.png", 22), ("camp/floor_moss.png", 26)], None),
    ("spr_chapel_dead_flowers", "sprite", 48, "camp/dead_flowers.png"),
    ("spr_dust_sheet_figure", "sprite", 96, "camp/dust_sheet_figure.png"),
    ("spr_confessional", "sprite", 112, "camp/confessional.png"),
    ("spr_chapel_chandelier", "sprite", 72, "camp/chapel_chandelier.png"),
    ("face_choir_loft", "panel", 192, "camp/choir_loft.png"),
    ("spr_cobweb_strands", "sprite", 80, "camp/cobweb_strands.png"),
    ("spr_saint_turned", "sprite", 112, "camp/saint_statue_turned.png"),
    # Number four for the night.
    ("face_motel_painting_a", "panel", 96, "camp/motel_painting_0.png"),
    ("face_motel_painting_b", "panel", 96, "camp/motel_painting_1.png"),
    ("face_motel_painting_c", "panel", 96, "camp/motel_painting_2.png"),
    ("face_motel_nightstand", "panel", 40, "camp/motel_nightstand.png"),
    ("sheet_motel_nightstand_things", "sheet", [("camp/clock_radio.png", 18), ("camp/phone_on.png", 18), ("camp/phone_off.png", 14), ("camp/water_glass.png", 10)], None),
    ("tex_motel_bath_tiles", "texture", 128, "camp/motel_bath_tiles.png"),
    ("spr_motel_shower_curtain", "sprite", 96, "camp/shower_curtain.png"),
    ("spr_motel_toilet", "sprite", 72, "camp/motel_toilet.png"),
    ("spr_motel_mirror_cabinet", "sprite", 52, "camp/mirror_cabinet.png"),
    ("spr_motel_bath_basin", "sprite", 64, "camp/bath_basin.png"),
    ("face_motel_bath_door", "panel", 64, "camp/motel_bath_door.png"),
    ("sheet_motel_stains", "sheet", [("camp/ceiling_stain_0.png", 40), ("camp/ceiling_stain_1.png", 48), ("camp/carpet_stain.png", 32), ("camp/wet_footprints.png", 24)], None),
    ("face_motel_wardrobe_open", "panel", 80, "camp/motel_wardrobe_open.png"),
    ("sheet_door_chain", "sheet", [("camp/chain_loose.png", 24), ("camp/chain_hooked.png", 16)], None),
    # The one-star motel (the user, 4. 11.: "like Hotel Hell").
    ("tex_motel_bedspread_dirty", "texture", 128, "camp/motel_bedspread_dirty.png"),
    ("tex_motel_carpet_dirty", "texture", 128, "camp/motel_carpet_dirty.png"),
    ("tex_motel_wall_dirty", "texture", 128, "camp/motel_wall_dirty.png"),
    ("tex_motel_pillow_dirty", "texture", 64, "camp/motel_pillow_dirty.png"),
    ("sheet_motel_grime", "sheet", [("camp/ashtray_full.png", 14), ("camp/rum_bottle.png", 10), ("camp/tissue.png", 8), ("camp/roach_dead.png", 8)], None),
    ("sheet_cockroach", "sheet", [("camp/roach_0.png", 12), ("camp/roach_1.png", 12), ("camp/roach_side.png", 8)], None),
    ("sheet_motel_bath_grime", "sheet", [("camp/hair_clump.png", 12), ("camp/razor.png", 8), ("camp/mould_grout.png", 24), ("camp/soap_hair.png", 10)], None),
    ("spr_plastic_bowl", "sprite", 20, "camp/plastic_bowl.png"),
    ("sheet_lobby_grime", "sheet", [("camp/flypaper.png", 48), ("camp/fly_zapper.png", 28), ("camp/desk_fan.png", 28)], None),
    ("spr_mirror_crack", "sprite", 64, "camp/mirror_crack.png"),
    # The rooms he lets, each its own (the user, 4. 11.: "like in some RPG").
    ("tex_motel_panel_wood", "texture", 128, "camp/motel_panel_wood.png"),
    ("tex_motel_blanket_wool", "texture", 128, "camp/motel_blanket_wool.png"),
    ("spr_stuffed_owl", "sprite", 44, "camp/stuffed_owl.png"),
    ("spr_stuffed_owl_turned", "sprite", 44, "camp/stuffed_owl_turned.png"),
    ("face_tiled_stove", "panel", 96, "camp/tiled_stove.png"),
    ("sheet_stove_fire", "sheet", [("camp/stove_fire_%d.png" % i, 24) for i in range(3)], None),
    ("spr_cuckoo_clock", "sprite", 52, "camp/cuckoo_clock.png"),
    ("spr_cuckoo_bird", "sprite", 16, "camp/cuckoo_bird.png"),
    ("spr_gun_cabinet", "sprite", 144, "camp/gun_cabinet.png"),
    ("tex_motel_floral_wall", "texture", 128, "camp/motel_floral_wall.png"),
    ("tex_satin_spread", "texture", 128, "camp/satin_spread.png"),
    ("sheet_dirty_dishes", "sheet", [("camp/dishes_plates.png", 20), ("camp/dishes_mug.png", 14), ("camp/dishes_pan.png", 14)], None),
    ("spr_gbook_desk", "sprite", 32, "camp/gbook_desk.png"),
    ("sheet_rm_small", "sheet", [("camp/tube_radio.png", 32), ("camp/vcr.png", 18), ("camp/hot_plate.png", 20), ("camp/portable_radio.png", 22)], None),
    ("sheet_rm_furniture", "sheet", [("camp/radiogram.png", 60), ("camp/minibar.png", 68), ("camp/minibar_open.png", 68), ("camp/armchair.png", 76)], None),
    ("sheet_rm_things", "sheet", [("camp/aquarium.png", 40), ("camp/newspaper_stack.png", 36), ("camp/suitcase.png", 32), ("camp/suitcase_open.png", 40)], None),
    ("sheet_rm_wide", "sheet", [("camp/boar_rug.png", 72), ("camp/clothesline.png", 72)], None),
    ("sheet_rm_pictures", "sheet", [("camp/wedding_photo.png", 88), ("camp/district_map.png", 112), ("camp/crossed_calendar.png", 84)], None),
    # The Benzina (polish, 4. 11. evening).
    ("tex_pump_side", "texture", 64, "town/pump_side.png"),
    ("sheet_benzina", "sheet", [("town/oil_rack.png", 48), ("town/air_post.png", 64), ("town/bin_towels.png", 48), ("town/tyres.png", 32)], None),
    # The chapel at night: the altar's candlesticks, the eternal light, the grave lanterns, the stubs.
    ("sheet_chapel_night", "sheet", [("camp/altar_candlestick.png", 64), ("camp/sanctuary_lamp.png", 64), ("camp/grave_lantern.png", 24), ("camp/candle_stubs.png", 20)], None),
    # The corridor, the car park.
    ("sheet_rm_corridor", "sheet", [("camp/fire_extinguisher.png", 44), ("camp/wall_lamp.png", 24), ("camp/cleaning_cart.png", 76)], None),
    ("sheet_rm_hall", "sheet", [("camp/hall_tray.png", 24), ("camp/hall_plant.png", 64), ("camp/hall_shoes.png", 18), ("camp/hall_phone.png", 48), ("camp/hall_rubbish.png", 34)], None),
    ("sheet_rm_yard", "sheet", [("town/sodium_lamp.png", 160), ("town/parked_car_a.png", 56), ("town/parked_car_b.png", 56), ("town/dumpster.png", 56)], None),
    ("tex_corridor_carpet", "texture", 128, "camp/corridor_carpet.png"),
]

# Textures coloured anew after processing: their dark, middle and light.
RECOLOUR = {"camp/motel_panel_wood.png": ((30, 21, 12), (98, 78, 44), (172, 146, 98))}

# The Jednota's front: its window panes and the door's glass cut out (jednota_view.gd
# PANES, DOOR_GLASS: the same rectangles, picture px x0, y0, x1, y1).
JEDNOTA_HOLES = [(38, 58, 93, 120), (98, 58, 150, 120), (232, 58, 288, 120), (293, 58, 346, 120),
                 (159, 59, 190, 134), (193, 59, 224, 134)]

# The blank plate on face_motel_door_out (fractions of the raw picture): x0, y0, x1, y1.
PLATE = (0.392, 0.236, 0.608, 0.293)
# The numbers' 3 x 5 pixel glyphs, painted at two game pixels a stroke.
DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return p if os.path.exists(p) else None


def save(img, dest):
    path = os.path.join(TEX, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("%s %s" % (dest, img.size))


def keyed_item(crop, height):
    """A cut item (RGBA, keyed) to `height` px, premultiplied box filter, palette."""
    bbox = crop.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    if bbox:
        crop = crop.crop(bbox)
    w = max(1, round(crop.width * height / crop.height))
    r, g, b, a = crop.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", crop.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, height), Image.Resampling.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return process.snap(small, True)


def do_sheet(art_id, parts, gap=14):
    src = raw(art_id)
    if src is None:
        return
    img = process.key_out(Image.open(src))
    boxes, labels, sw = split_sheet.items(img, gap)
    boxes.sort(key=lambda b: b[0])
    if len(boxes) < len(parts):
        print("%s: %d items found, %d wanted; skipped" % (art_id, len(boxes), len(parts)))
        return
    # The biggest ones if Grok drew crumbs.
    if len(boxes) > len(parts):
        boxes = sorted(boxes, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:len(parts)]
        boxes.sort(key=lambda b: b[0])
    for (dest, h), box in zip(parts, boxes):
        item = keyed_item(split_sheet.own(img, box, labels[box], sw), h)
        if dest in DESPILL:
            item = despill(item)
        save(item, dest)


# Drawn on a darker pink than the key: what is left of it on their edges taken out (blue
# no higher than green where both red and blue stand over green).
DESPILL = {"camp/altar_candlestick.png", "camp/sanctuary_lamp.png", "camp/grave_lantern.png", "camp/candle_stubs.png"}


def despill(img):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0 and b > g and r > g:
                px[x, y] = (r, g, g, a)
    return img


def panel_img(img, width):
    height = max(1, round(img.height * width / img.width))
    return process.snap(img.resize((width, height), Image.Resampling.BOX), False)


def do_retable(art_id, width):
    """The altar render: the retable down to the table's top, the table's front below it."""
    src = raw(art_id)
    if src is None:
        return
    img = Image.open(src).convert("RGB")
    w, h = img.size
    # The cloth's top edge and the step's top (measured on the render, 864 x 1152).
    top = round(h * 0.632)
    step = round(h * 0.885)
    save(panel_img(img.crop((0, 0, w, top)), width), "camp/chapel_retable.png")
    save(panel_img(img.crop((0, top, w, step)), width), "camp/chapel_altar_front.png")


def jednota_glass():
    src = os.path.join(TEX, "town", "lib_jednota_front.png")
    if not os.path.exists(src):
        return
    img = Image.open(src).convert("RGBA")
    px = img.load()
    for x0, y0, x1, y1 in JEDNOTA_HOLES:
        for y in range(y0, y1):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0, 0)
    save(img, "town/lib_jednota_front_glass.png")


# The pub's front: its four windows cut out (pub_view.gd PANES).
PUB_HOLES = [(22, 83, 58, 127), (93, 83, 129, 127), (237, 83, 273, 127), (308, 83, 344, 127)]


def pub_glass():
    src = os.path.join(TEX, "town", "lib_pub_front.png")
    if not os.path.exists(src):
        return
    img = Image.open(src).convert("RGBA")
    px = img.load()
    for x0, y0, x1, y1 in PUB_HOLES:
        for y in range(y0, y1):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0, 0)
    save(img, "town/lib_pub_front_glass.png")


# The kiosk's front: its window and the door's glass cut out (kiosk_view.gd).
KIOSK_HOLES = [(22, 42, 154, 103), (183, 47, 218, 133)]


def kiosk_glass():
    src = os.path.join(TEX, "town", "kiosk_front.png")
    if not os.path.exists(src):
        return
    img = Image.open(src).convert("RGBA")
    px = img.load()
    for x0, y0, x1, y1 in KIOSK_HOLES:
        for y in range(y0, y1):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0, 0)
    save(img, "town/kiosk_front_glass.png")


def decal_clean():
    """Grok drew the stains on their own ceiling and carpet: what is not the stain made see-
    through (the ceiling's near-white, the carpet round the dark stain, the carpet round
    the grey wet feet), so they lie on the room's own."""
    import colorsys
    rules = {
        "camp/ceiling_stain_0.png": lambda r, g, b, s, v: (v > 0.66 and s < 0.3) or (v > 0.4 and s < 0.18),
        "camp/ceiling_stain_1.png": lambda r, g, b, s, v: (v > 0.66 and s < 0.3) or (v > 0.4 and s < 0.18),
        "camp/carpet_stain.png": lambda r, g, b, s, v: v > 0.24,
        "camp/wet_footprints.png": lambda r, g, b, s, v: s > 0.32,
    }
    for dest, cut in rules.items():
        path = os.path.join(TEX, dest)
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                # The patch's own frame (the carpet's edge Grok drew round it).
                if dest == "camp/carpet_stain.png" and min(x, y, img.width - 1 - x, img.height - 1 - y) < 3:
                    px[x, y] = (r, g, b, 0)
                    continue
                h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                if cut(r, g, b, s, v):
                    px[x, y] = (r, g, b, 0)
        img.save(path)
        print("%s cleaned" % dest)


def doors():
    """town/motel_door_<n>.png: the door with its number on the plate."""
    base = os.path.join(TEX, "town", "motel_door_out.png")
    if not os.path.exists(base):
        return
    door = Image.open(base).convert("RGB")
    w, h = door.size
    x0, y0, x1, y1 = round(PLATE[0] * w), round(PLATE[1] * h), round(PLATE[2] * w), round(PLATE[3] * h)
    ink = (24, 22, 20)
    for n in range(1, 13):
        img = door.copy()
        d = ImageDraw.Draw(img)
        text = str(n)
        gw = len(text) * 4 - 1
        ox = x0 + (x1 - x0 - gw) // 2
        oy = y0 + (y1 - y0 - 5) // 2
        for i, ch in enumerate(text):
            for gy, row in enumerate(DIGITS[ch]):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        d.point((ox + i * 4 + gx, oy + gy), fill=ink)
        save(img, "town/motel_door_%d.png" % n)


def signs():
    """The motel's own lettering through lettering.py's kit: RECEPCE painted over its door,
    the stairs' sign up to the rooms."""
    import lettering
    lettering.SIGNS["recepce"] = dict(text="RECEPCE", font=(lettering.BAHN[0], b"SemiBold Condensed"), cap=0.2,
                                      style="raised", face=(226, 222, 210), side=(120, 118, 110), track=0.08, rust=0.4, seed=21)
    lettering.make("recepce")


def main():
    only = sys.argv[1:]
    if only == ["signs"]:
        signs()
        return
    if only == ["doors"]:
        doors()
        return
    for art_id, mode, size, dest in ROWS:
        if only and art_id not in only:
            continue
        if mode == "sheet":
            # The Stations stand close together: a narrower gap tells them apart.
            do_sheet(art_id, size, 4 if art_id in ("sheet_stations", "sheet_rm_things", "sheet_rm_yard") else 14)
            continue
        if mode == "retable":
            do_retable(art_id, size)
            continue
        if mode == "panelcrop":
            # A band of the picture (the rail without the wall over and under it).
            src = raw(art_id)
            if src is not None:
                img = Image.open(src).convert("RGB")
                band = img.crop((0, round(img.height * size[1]), img.width, round(img.height * size[2])))
                save(panel_img(band, size[0]), dest)
            continue
        src = raw(art_id)
        if src is None:
            continue
        if mode == "sprite":
            out = process.sprite(src, size)
        elif mode == "panel":
            out = process.panel(src, size)
        else:
            out = process.texture(src, size)
        if dest in RECOLOUR:
            # Grok's pine came near black and red: the panelling has to read as old pine by
            # a bedside lamp, the grain kept, the colours laid over it again.
            lo, mid, hi = RECOLOUR[dest]
            grey = ImageOps.autocontrast(out.convert("L"), cutoff=1)
            out = ImageOps.colorize(grey, black=lo, mid=mid, white=hi)
        save(out, dest)
    doors()
    jednota_glass()
    pub_glass()
    kiosk_glass()
    decal_clean()
    if not only:
        signs()


if __name__ == "__main__":
    main()
