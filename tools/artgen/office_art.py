#!/usr/bin/env python3
"""The interiors (the reception, the store, the Jednota, the pub, the bus) and the
village's things: Grok renders into the game.

    python tools/artgen/office_art.py

Every row below is (artgen id, mode, size, file in godot/assets/textury/camp/, or
under godot/assets/textury/ when it has a folder: "town/bin.png"). Missing
renders are skipped. Sprites on the darker magenta some renders come on are re-keyed
first. The stove's embers get a mask (stove_glow.png: the orange of the fire window,
the rest black) for office_dressing.gd to light at night.
"""
import os
import sys

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
    # The Jednota.
    ("tex_shop_floor", "texture", 128, "shop_floor.png"),
    ("tex_shop_wall", "texture", 128, "shop_wall.png"),
    ("face_shop_shelf_cigs", "panel", 192, "shop_shelf_cigs.png"),
    ("face_shop_shelf_goods", "panel", 192, "shop_shelf_goods.png"),
    ("face_shop_bread", "panel", 80, "shop_bread.png"),
    ("face_shop_fridge", "panel", 80, "shop_fridge.png"),
    ("face_shop_counter", "panel", 192, "shop_counter.png"),
    ("spr_shop_till", "sprite", 64, "shop_till.png"),
    ("spr_shop_scales", "sprite", 56, "shop_scales.png"),
    ("spr_beer_crate_full", "sprite", 64, "beer_crate_full.png"),
    ("spr_card_box", "sprite", 40, "card_box.png"),
    ("spr_shop_baskets", "sprite", 64, "shop_baskets.png"),
    ("spr_shop_freezer", "sprite", 80, "shop_freezer.png"),
    ("face_shop_poster", "panel", 72, "shop_poster.png"),
    # The pub.
    ("tex_pub_floor", "texture", 128, "pub_floor.png"),
    ("tex_pub_wall", "texture", 128, "pub_wall.png"),
    ("tex_pub_wainscot", "texture", 128, "pub_wainscot.png"),
    ("face_pub_backbar", "panel", 224, "pub_backbar.png"),
    ("face_pub_bar", "panel", 192, "pub_bar.png"),
    ("spr_pub_taps", "sprite", 56, "pub_taps.png"),
    ("face_fruit_machine", "panel", 64, "fruit_machine.png"),
    ("spr_mug_full", "sprite", 32, "mug_full.png"),
    ("spr_mug_empty", "sprite", 32, "mug_empty.png"),
    ("spr_antlers", "sprite", 56, "antlers.png"),
    ("spr_dartboard", "sprite", 56, "dartboard.png"),
    ("face_pub_sign", "panel", 80, "pub_sign.png"),
    ("spr_regular_cap", "sprite", 128, "regular_cap.png"),
    ("spr_regular_track", "sprite", 144, "regular_track.png"),
    ("spr_pub_lamp", "sprite", 48, "pub_lamp.png"),
    ("spr_ashtray", "sprite", 24, "ashtray.png"),
    ("tex_tablecloth", "texture", 64, "tablecloth.png"),
    # The village.
    ("tex_sidewalk", "texture", 128, "town/sidewalk.png"),
    ("tex_dirt_path", "texture", 128, "town/dirt_path.png"),
    ("tex_village_grass", "texture", 128, "town/village_grass.png"),
    ("tex_garden_soil", "texture", 128, "town/garden_soil.png"),
    ("tex_plaster_yellow", "texture", 128, "town/plaster_yellow.png"),
    ("tex_plaster_pink", "texture", 128, "town/plaster_pink.png"),
    ("tex_roof_eternit", "texture", 128, "town/roof_eternit.png"),
    ("spr_fence_picket", "sprite", 64, "town/fence_picket.png"),
    ("spr_fence_mesh", "sprite", 64, "town/fence_mesh.png"),
    ("spr_street_bin", "sprite", 64, "town/street_bin.png"),
    ("spr_post_box", "sprite", 48, "town/post_box.png"),
    ("spr_phone_booth", "sprite", 128, "town/phone_booth.png"),
    ("spr_village_radio", "sprite", 160, "town/village_radio.png"),
    ("spr_noticeboard", "sprite", 80, "town/noticeboard.png"),
    ("spr_woodpile", "sprite", 80, "town/woodpile.png"),
    ("spr_laundry", "sprite", 80, "town/laundry.png"),
    ("spr_hen", "sprite", 32, "town/hen.png"),
    ("spr_hen_peck", "sprite", 32, "town/hen_peck.png"),
    ("spr_dog_kennel", "sprite", 64, "town/dog_kennel.png"),
    ("spr_dog_bark", "sprite", 56, "town/dog_bark.png"),
    ("spr_cat", "sprite", 40, "town/cat.png"),
    ("spr_gnome", "sprite", 40, "town/gnome.png"),
    ("spr_wheelbarrow", "sprite", 48, "town/wheelbarrow.png"),
    ("spr_shrine", "sprite", 128, "town/shrine.png"),
    ("spr_pub_sign", "sprite", 64, "town/pub_sign.png"),
    ("spr_flower_box", "sprite", 40, "town/flower_box.png"),
    ("face_window_shutter", "panel", 72, "town/window_shutter.png"),
    ("face_window_flowers", "panel", 64, "town/window_flowers.png"),
    ("face_house_door2", "panel", 56, "town/house_door2.png"),
    ("face_garage_door", "panel", 96, "town/garage_door.png"),
    ("face_car_side", "panel", 160, "town/car_side.png"),
    ("face_car_front", "panel", 80, "town/car_front.png"),
    ("face_car_back", "panel", 80, "town/car_back.png"),
    # The bus.
    ("face_bus_dash", "panel", 192, "town/bus_dash.png"),
    ("face_bus_door_in", "panel", 56, "town/bus_door_in.png"),
    ("spr_bus_driver_back", "sprite", 112, "town/bus_driver_back.png"),
    ("spr_bus_mascot", "sprite", 40, "town/bus_mascot.png"),
    ("spr_no_smoking", "sprite", 32, "town/no_smoking.png"),
    ("spr_bus_litter", "sprite", 48, "town/bus_litter.png"),
    ("tex_bus_curtain", "texture", 64, "town/bus_curtain.png"),
    ("tex_bus_rack", "panel", 160, "town/bus_rack.png"),
    # The camp: clean enamel, the forest floor's things.
    ("tex_enamel_white2", "texture", 128, "enamel_white.png"),
    ("spr_fern", "sprite", 64, "world/fern.png"),
    ("spr_fly_agaric", "sprite", 40, "world/fly_agaric.png"),
    ("spr_boletus", "sprite", 40, "world/boletus.png"),
    ("spr_stump", "sprite", 56, "world/stump.png"),
    ("spr_rock_moss", "sprite", 56, "world/rock_moss.png"),
    ("spr_molehill", "sprite", 40, "world/molehill.png"),
    ("spr_nettles", "sprite", 72, "world/nettles.png"),
    ("spr_leaf_pile", "sprite", 40, "world/leaf_pile.png"),
    ("spr_branch", "sprite", 40, "world/branch.png"),
    ("spr_anthill", "sprite", 56, "world/anthill.png"),
    ("spr_blueberry", "sprite", 48, "world/blueberry.png"),
    ("spr_thistle", "sprite", 64, "world/thistle.png"),
    # The chapel, the kiosk, the motel.
    ("tex_chapel_floor", "texture", 128, "chapel_floor.png"),
    ("tex_chapel_wall", "texture", 128, "chapel_wall.png"),
    ("face_chapel_pews", "panel", 192, "chapel_pews.png"),
    ("face_chapel_altar", "panel", 160, "chapel_altar.png"),
    ("face_stained_window", "panel", 56, "stained_window.png"),
    ("spr_candles_rack", "sprite", 64, "candles_rack.png"),
    ("spr_saint_statue", "sprite", 112, "saint_statue.png"),
    ("spr_crucifix", "sprite", 64, "crucifix.png"),
    ("face_kiosk_shelves", "panel", 192, "kiosk_shelves.png"),
    ("face_kiosk_counter", "panel", 192, "kiosk_counter.png"),
    ("spr_pin_up_calendar", "sprite", 72, "kiosk_calendar.png"),
    ("face_motel_desk", "panel", 192, "motel_desk.png"),
    ("spr_vending_machine", "sprite", 128, "vending_machine.png"),
    ("tex_motel_carpet", "texture", 128, "motel_carpet.png"),
    ("tex_motel_wall", "texture", 128, "motel_wall.png"),
    ("spr_plastic_plant", "sprite", 72, "plastic_plant.png"),
    ("npc_town_lojzova", "sprite", 128, "npc/town_lojzova.png"),
    ("tex_bus_wall2", "texture", 128, "town/bus_wall.png"),
    ("tex_bus_ceiling2", "texture", 128, "town/bus_ceiling.png"),
    ("spr_owl", "sprite", 48, "world/owl.png"),
    ("spr_owl_eyes", "sprite", 16, "world/owl_eyes.png"),
]
TEXTURY = os.path.join(HERE, "..", "..", "godot", "assets", "textury")


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


def key_white(names):
    """Faces rendered on a pale sky (the cars): flood the near-white in from the edges."""
    from collections import deque
    for n in names:
        path = os.path.join(TEXTURY, n)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        px = im.load()
        w, h = im.size
        q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
        seen = set()
        while q:
            x, y = q.popleft()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            r, g, b, a = px[x, y]
            if not (r > 170 and g > 165 and b > 150 and max(r, g, b) - min(r, g, b) < 45):
                continue
            px[x, y] = (0, 0, 0, 0)
            q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
        im.save(path)


def main():
    for art_id, mode, size, name in ROWS:
        raw = os.path.join(HERE, "out", art_id, "raw.png")
        if not os.path.exists(raw):
            print("missing", art_id)
            continue
        # Already done from this render (--all redoes everything).
        dest = os.path.join(TEXTURY, name) if "/" in name else os.path.join(CAMP, name)
        if os.path.exists(dest) and os.path.getmtime(dest) > os.path.getmtime(raw) and "--all" not in sys.argv:
            continue
        if mode == "sprite":
            out = process.sprite(rekeyed(art_id), size)
        elif mode == "panel":
            out = process.panel(raw, size)
        else:
            out = process.texture(raw, size)
        out.save(dest)
        print(name, out.size)
    stove_glow()
    key_white(["town/car_side.png", "town/car_front.png", "town/car_back.png"])


if __name__ == "__main__":
    main()
