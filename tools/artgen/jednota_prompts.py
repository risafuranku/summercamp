#!/usr/bin/env python3
"""The camp's Jednota (agent C, phase 4; DESIGN.md §7b "The Jednota"): its Grok rows into
tools/artgen/prompts_jednota.tsv (gen.sh reads prompts_*.tsv), processed by jednota_art.py.

    python tools/artgen/jednota_prompts.py

- jd_iso, jd_isoback: the Builder's isometric sprite of the new, bigger building, front
  and back (the back's reference is the processed front);
- jd_front, jd_side, jd_backwall: the building's faces for its Build model in the camp;
- jd_till, jd_store, jd_rack: the three stations' Build pictures (the till from above,
  the storeroom's packing table from above, the shop's rack straight on);
- jds_goods, jds_store, jds_till: sprite sheets (the ten goods; the boxes and the cage
  trolley; the money, the basket and the bag).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "prompts_jednota.tsv")

ISO = ("An isometric building sprite for a late-1990s camp tycoon game in the style of the reference image: 2:1 isometric "
       "pixel art seen from the south-west, the same pixel size, palette, weathered textures and soft top-left light as the "
       "reference, a small dark shadow on the ground under it. The object stands alone on a flat pure magenta (#FF00FF) "
       "background, no ground tile, no text, no border. ")
BUILD = ("Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, Redneck Rampage): a digitized "
         "photograph crudely retouched by hand by a 1996 game artist, flat even lighting, no glow, no bloom, no depth of field, "
         "no soft shadows, chunky pixels, a limited muddy palette, low saturation, slightly grimy and imperfect, hard edges, no "
         "readable text, no logos, no border, no watermark, no people, no hands. ")
FLAT = "A flat orthographic straight-on view, no perspective, filling the whole 16:9 canvas edge to edge: "
ABOVE = "Seen from straight above, a flat orthographic top-down view, no perspective, filling the whole 16:9 canvas edge to edge: "
SHEET = ("Pixel-art sprites in the style of 1990s Build-engine games (Duke Nukem 3D, Redneck Rampage): digitized and crudely "
         "retouched by hand, flat even lighting, chunky pixels, a limited muddy palette, low saturation, seen straight on from "
         "the front. A sprite sheet: %d separate objects in one row from left to right, each one whole, all at the same scale, "
         "with wide gaps of background between them so none touch. The background must be flat solid pure magenta #FF00FF "
         "everywhere, no cast shadows, no table, no text, no labels, no letters, no border, no watermark. Every object is drawn "
         "big and simple so it still reads when it is shrunk to sixteen pixels tall: plain shapes, bold dark outlines, flat fills "
         "of two or three colours. ")
RRTX = "assets/textury/redneck/RRTX0020.png"

ROWS = [
    ("jd_iso", "1:1", "assets/textury/builder/iso_jednota.png", ISO +
     "The object: a big 1970s Czechoslovak village self-service grocery shop (Jednota samoobsluha), three times the size of "
     "the reference building: a long single-storey building with a flat roof and a thin concrete edge, a long band of big "
     "shop windows showing green shelves of goods inside, a glass double door in the middle under a small flat canopy, a long "
     "red sign board along the top of the facade without letters, grey-beige plaster with rain stains and a crack, crates of "
     "empty bottles stacked by the wall, a bicycle, a wooden bench and a red ice-cream freezer by the door."),
    ("jd_isoback", "1:1", "assets/textury/builder/iso_jednota.png", ISO.replace("in the style of the reference image", "of exactly the building in the reference image") +
     "The same building seen from behind: turned round, the same view angle and size, its long back wall now facing down to "
     "the left where the front was, plain grey-beige plaster with rain stains, a wide grey steel delivery door with a small "
     "concrete step, a brown wooden staff door with a little brass bell beside it, one small barred window, flattened "
     "cardboard boxes leaning on the wall; the short side wall on the right, plaster with a rusty drainpipe; the same flat "
     "roof with its thin concrete edge. No sign board, no shop windows, no canopy on this side."),
    ("jd_front", "16:9", RRTX, BUILD + FLAT +
     "The front facade of a 1970s Czechoslovak village self-service grocery shop (Jednota): a long band of big shop windows "
     "with green metal shelves of bread, bottles and tins seen through the glass, a glass double door with a steel frame in "
     "the middle, a plain empty red sign board along the top, grey-beige plaster with rain streaks under the window sills, a "
     "dark plinth along the bottom. No sky, no ground, no roof, only the wall."),
    ("jd_side", "16:9", RRTX, BUILD + FLAT +
     "The side wall of the same 1970s Czechoslovak village grocery: grey-beige plaster with rain streaks and a long crack, a "
     "narrow high strip window with frosted glass, a rusty drainpipe down one end, a faded enamel sign plate, a dark plinth "
     "along the bottom. No sky, no ground, no roof, only the wall."),
    ("jd_backwall", "16:9", RRTX, BUILD + FLAT +
     "The back wall of the same 1970s Czechoslovak village grocery: grey-beige plaster with stains, a wide grey steel "
     "delivery door with a small step, a staff door with a bell, a small barred window, a dark plinth along the bottom, "
     "stacked flattened cardboard by the door. No sky, no ground, no roof, only the wall."),
    ("jd_till", "16:9", RRTX, BUILD + ABOVE +
     "The cashier's counter of a 1980s Czechoslovak village self-service shop: a worn grey laminate counter top, at the "
     "right end a heavy old mechanical cash register with its keys and an open empty money drawer with compartments, a small "
     "rubber change mat in the middle, a red plastic shopping basket stand at the left end, a little steel scale. Nothing on "
     "the counter: no goods, no money, no hands."),
    ("jd_store", "16:9", RRTX, BUILD + ABOVE +
     "The packing table in the storeroom of a 1980s Czechoslovak village shop: a long worn steel table on a concrete floor, a "
     "box cutter, a roll of price labels and a hand price gun, a clipboard with a delivery note, a wooden pallet at the left "
     "end of the floor, empty. Nothing else: no boxes, no goods, no hands."),
    ("jd_rack", "16:9", RRTX, BUILD + FLAT +
     "A long empty green metal grocery shelf rack of a 1980s Czechoslovak self-service shop, seen straight from the front: "
     "four shelves one above the other, white price-label strips along each shelf edge, the back panel perforated, a little "
     "rust and scuffs. The shelves are completely empty: no goods."),
    ("jds_goods", "16:9", RRTX, SHEET % 10 +
     "The objects, left to right: a round brown loaf of rye bread; three long crescent bread rolls in a paper bag; a long "
     "red salami; a glass bottle of milk with a green foil cap; a glass jar of pickled gherkins; a brown glass beer bottle "
     "with a green label; a chocolate ice cream bar on a stick; a chocolate bar in a red wrapper; a head of green cabbage; a "
     "white bar of soap in a blue paper wrapper."),
    ("jds_store", "16:9", RRTX, SHEET % 4 +
     "The objects, left to right: a closed brown cardboard box with packing tape; the same box opened at the top; a tall "
     "steel roll cage trolley with wheels, empty; a wooden pallet seen from the front."),
    ("jds_till", "16:9", RRTX, SHEET % 7 +
     "The objects, left to right: a small silver coin; a bigger golden coin; a green paper banknote; a blue paper banknote; a "
     "red paper banknote; a red plastic shopping basket, empty; a brown paper shopping bag, folded open."),
]


def main():
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        for r in ROWS:
            f.write("\t".join(r) + "\n")
    print("wrote", OUT, len(ROWS), "rows")


if __name__ == "__main__":
    main()
