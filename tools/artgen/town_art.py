#!/usr/bin/env python3
"""The art of the way out of the camp and of Lesna (scripts/town/) from the Grok renders,
snapped to the game palette:

    python tools/artgen/town_art.py

-> godot/assets/textury/town/
   stop_concrete, stop_sign, timetable_case, forest_floor   the bus stop and the road
   bus_side_doors, bus_side, bus_front, bus_back             the Karosa (see bus_sides)
   bus_seat, bus_floor, bus_wall, bus_ceiling, ticket_machine   inside it
   closeup_timetable, closeup_ticket_machine                 320x240 close-ups
   village_plaster, roof_tiles, asphalt, cobbles              Lesna's walls, roofs, ground
   shop_front, pub_front, motel_front, kiosk_front,           facades (the art's aspect kept)
   fuel_pump, house_window, house_door
-> godot/assets/textury/npc/town_<who>.png                    Lesna's people (128 px tall)
-> godot/assets/textury/hands/<cig|cig_mouth|beer|beer_drink|nozzle>.png
Missing renders are skipped (printed).
"""
import os

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "town")


def raw(art_id):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    if not os.path.exists(path):
        print("missing", art_id)
        return None
    return Image.open(path).convert("RGB")


def save(img, name, keep_alpha=False):
    process.snap(img, keep_alpha).save(os.path.join(OUT, name))
    print(name, img.size)


def square(art_id, size, name):
    img = raw(art_id)
    if img is None:
        return
    s = min(img.size)
    img = img.crop(((img.width - s) // 2, (img.height - s) // 2, (img.width - s) // 2 + s, (img.height - s) // 2 + s))
    save(img.resize((size, size), Image.Resampling.BOX), name)


def picture(art_id, size, name):
    img = raw(art_id)
    if img is None:
        return
    # Fill the frame (crop the long side), then down to the close-up's size.
    k = max(size[0] / img.width, size[1] / img.height)
    img = img.resize((round(img.width * k), round(img.height * k)), Image.Resampling.BOX)
    left = (img.width - size[0]) // 2
    top = (img.height - size[1]) // 2
    save(img.crop((left, top, left + size[0], top + size[1])), name)


def panel(art_id, width, name):
    img = raw(art_id)
    if img is None:
        return
    save(img.resize((width, max(1, round(img.height * width / img.width))), Image.Resampling.BOX), name)


def sprite(art_id, height, dest):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    if not os.path.exists(path):
        print("missing", art_id)
        return
    # Some renders come on a darker magenta (180, 5, 136) the keyer misses: push it to
    # pure magenta first.
    img = Image.open(path).convert("RGB")
    px = img.load()
    if px[2, 2][1] < 70 and px[2, 2][0] > 120 and px[2, 2][2] > 90 and px[2, 2][2] < 150:
        for y in range(img.height):
            for x in range(img.width):
                r, g, b = px[x, y]
                if r > 120 and g < 70 and b > 90 and abs(r - b) < 80:
                    px[x, y] = (255, 0, 255)
        path = os.path.join(HERE, "out", art_id, "raw_keyed.png")
        img.save(path)
    out = process.sprite(path, height)
    out.save(os.path.join(HERE, "..", "..", "godot", dest))
    print(dest, out.size)


def bus_sides():
    """The render is a short bus (4 windows, 2 doors, the front at the left, on white).
    Cut it into its bays and lay them out as a 10 m Karosa: the front with its wheel
    arch and the front door, three window bays, the middle door, two more, the back
    with its arch. The door side is that, mirrored (the doors are on the bus's right);
    the other side has windows where the doors were."""
    img = raw("tex_bus_side")
    if img is None:
        return
    px = img.load()

    def bg(p):
        return p[0] > 235 and p[1] > 235 and p[2] > 235

    rows = [y for y in range(img.height) if sum(1 for x in range(0, img.width, 4) if not bg(px[x, y])) > 20]
    cols = [x for x in range(img.width) if sum(1 for y in range(0, img.height, 4) if not bg(px[x, y])) > 10]
    img = img.crop((cols[0], rows[0], cols[-1] + 1, rows[-1] + 1))
    w = img.width
    k = w / 1270.0

    def cut(a, b):
        return img.crop((round(a * k), 0, round(b * k), img.height))

    front, win_a, door1, win_b, door2, rear = cut(0, 285), cut(285, 285), cut(285, 430), cut(430, 665), cut(665, 810), cut(810, 1270)
    del win_a

    def strip(parts):
        out = Image.new("RGB", (sum(p.width for p in parts), img.height))
        x = 0
        for p in parts:
            out.paste(p, (x, 0))
            x += p.width
        return out

    doors = strip([front, door1, win_b, win_b, win_b, door2, win_b, win_b, rear])
    plain = strip([front, win_b.crop((0, 0, door1.width, img.height)), win_b, win_b, win_b, win_b.crop((0, 0, door2.width, img.height)), win_b, win_b, rear])
    size = (640, round(640 * img.height / doors.width))
    save(doors.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize(size, Image.Resampling.BOX), "bus_side_doors.png")
    save(plain.resize(size, Image.Resampling.BOX), "bus_side.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    square("tex_stop_concrete", 128, "stop_concrete.png")
    square("tex_stop_sign", 128, "stop_sign.png")
    square("tex_timetable_case", 128, "timetable_case.png")
    square("tex_forest_floor", 128, "forest_floor.png")
    bus_sides()
    square("tex_bus_front", 256, "bus_front.png")
    square("tex_bus_back", 256, "bus_back.png")
    square("tex_bus_seat", 128, "bus_seat.png")
    square("tex_bus_floor", 128, "bus_floor.png")
    square("tex_bus_wall", 128, "bus_wall.png")
    square("tex_bus_ceiling", 128, "bus_ceiling.png")
    square("tex_ticket_machine", 128, "ticket_machine.png")
    picture("closeup_timetable", (320, 240), "closeup_timetable.png")
    picture("closeup_ticket_machine", (320, 240), "closeup_ticket_machine.png")
    picture("closeup_shop_counter", (320, 240), "closeup_shop.png")
    picture("closeup_pub_bar", (320, 240), "closeup_pub.png")
    picture("closeup_pump", (320, 240), "closeup_pump.png")
    square("tex_field_stubble", 128, "field_stubble.png")
    square("tex_field_plough", 128, "field_plough.png")
    square("tex_village_plaster", 128, "village_plaster.png")
    square("tex_roof_tiles", 128, "roof_tiles.png")
    square("tex_asphalt", 128, "asphalt.png")
    square("tex_cobbles", 128, "cobbles.png")
    for face, width in [("shop_front", 256), ("pub_front", 256), ("motel_front", 256), ("kiosk_front", 256), ("fuel_pump", 96), ("house_door", 64)]:
        panel("face_" + face, width, face + ".png")
    square("face_house_window", 96, "house_window.png")
    for who in ["babicka", "tracksuit", "shopgirl", "landlord", "pumpar", "motel", "policeman", "driver", "kid"]:
        sprite("npc_" + who, 128, "assets/textury/npc/town_%s.png" % who)
    for hand in ["cig", "cig_mouth", "beer", "beer_drink", "nozzle"]:
        sprite("hand_" + hand, 190, "assets/textury/hands/%s.png" % hand)


if __name__ == "__main__":
    main()
