#!/usr/bin/env python3
"""Writes tools/artgen/prompts_pubcorn.tsv: the pub's and the corn stand's station screens
(the flat Build-engine textures their stations are played on, scripts/pub/ and
scripts/corn/) and the sheets of things drawn over them, and the pub's room props.

    python tools/artgen/pub_corn_prompts.py

gen.sh reads prompts.tsv and every prompts_*.tsv beside it. The look is the bistro's
latest (playtest 19. 10.: "less like AI pixel art, more like imperfect human Build-engine
textures"): tools/artgen/bistro_prompts.py BT_*.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REF_BT = "assets/textury/redneck/RRTX0020.png"
REF_MARK = "assets/textury/ui/mark_tap.png"
REF_ROOM = "assets/textury/camp/bistro_cakes.png"

BT = ("Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, Redneck Rampage): a "
      "digitized photograph crudely retouched by hand by a 1996 game artist, flat even lighting, no glow, no "
      "bloom, no steam, no smoke, no depth of field, no soft shadows, chunky pixels, a limited muddy palette, low "
      "saturation, slightly grimy and imperfect, hard edges, no readable text, no logos, no border, no "
      "watermark, no people, no hands. ")
BT_TOP = BT + "A flat orthographic view straight down from above, no perspective, filling the whole 16:9 canvas edge to edge: "
BT_FRONT = BT + "A flat orthographic straight-on front view, no perspective, filling the whole 16:9 canvas edge to edge: "
BT_SHEET = ("Pixel-art sprites in the style of 1990s Build-engine games (Duke Nukem 3D, Redneck Rampage): digitized "
            "and crudely retouched by hand, flat even lighting, chunky pixels, a limited muddy palette, low "
            "saturation, {view}. A sprite sheet: {n} separate objects in one row from left to right, each one "
            "whole, all at the same scale, with wide gaps of background between them so none touch. The background "
            "must be flat solid pure magenta #FF00FF everywhere, no cast shadows, no table, no text, no labels, no "
            "letters, no border, no watermark. The objects, left to right: ")
FRONT = "seen straight on from the front"
TOP = "seen straight down from above"
ROOM_SHEET = ("Pixel-art sprites in exactly the same style as the reference image (hand-retouched 1990s Build-engine "
              "game sprites, chunky pixels, a limited muddy palette, flat light), seen straight on from the front. A "
              "sprite sheet: {n} separate objects in one row from left to right, each one whole, with wide gaps of "
              "background between them so none touch. The background must be flat solid pure magenta #FF00FF "
              "everywhere, no cast shadows, no floor, no text, no letters, no labels, no border, no watermark. The "
              "objects, left to right: ")
MARK_SHEET = ("Small game icons in exactly the same style as the reference image (a chunky pixel-art icon with a dark "
              "outline, flat colours, readable at a tiny size), seen from the front. A sheet: {n} separate icons in one "
              "row from left to right, each one whole, all the same size, with wide gaps of background between them so "
              "none touch. The background must be flat solid pure magenta #FF00FF everywhere, no text, no letters, no "
              "numbers, no border, no watermark. The icons, left to right: ")

ROWS = [
    # ── the pub's stations ──────────────────────────────────────────────────────
    ("pt_tap", "16:9", REF_BT, BT_FRONT +
     "The barman's side of a 1980s Czech village pub bar. In the middle a tall chrome beer tower with one long black "
     "tap handle standing up and a short curved spout, under it a ribbed steel drip tray with nothing on it. On the "
     "left a long empty steel draining board. On the right an empty stretch of worn dark wooden bar top, a folded "
     "white bar towel at the far right edge. Behind, dark brown wood panelling. Absolutely no glasses, no mugs and "
     "no bottles anywhere."),
    ("pt_back", "16:9", REF_BT, BT_FRONT +
     "The back bar of a 1980s Czech village pub. In the top half three dark wooden shelves crowded with dusty "
     "liqueur and spirit bottles with plain blank labels, a spotted mirror behind them. In the bottom half a long "
     "empty stretch of worn dark wooden bar top with nothing standing on it, a stained cloth at the far left edge."),
    ("pt_wash", "16:9", REF_BT, BT_FRONT +
     "The glass washer behind a 1980s Czech pub bar. In the middle a deep steel sink full of grey soapy water with "
     "two round upright bristle brushes standing up out of the water on spindles (the kind a beer mug is pushed down "
     "onto). On the left a long empty steel counter. On the right an empty wire drying rack over a ribbed steel "
     "drainer. A brass tap above the sink, dark wood panelling behind. No glasses, no mugs."),
    ("pt_keg", "16:9", REF_BT, BT_FRONT +
     "A damp red-brick pub cellar wall with a cracked concrete floor in front of it. Left of the middle an empty "
     "low wooden pallet on the floor with nothing on it; a clear plastic beer hose comes down from the ceiling and "
     "ends in mid-air above the pallet. On the right a tall grey gas cylinder chained to the wall with a brass "
     "regulator, a round pressure gauge and a red valve wheel. At the far right a stack of empty wooden beer crates. "
     "A bare bulb on a wire at the top. No kegs, no barrels."),
    # ── the corn stand's stations ───────────────────────────────────────────────
    ("ct_counter", "16:9", REF_BT, BT_TOP +
     "The worn plank counter of a wooden roadside sweetcorn stand. On the left a big dented aluminium pot of "
     "boiling water on a gas ring, nothing in the water. In the middle a bare pale wooden chopping board, empty. "
     "Right of it a white enamel dish of melted yellow butter with a pastry brush in it, a glass salt shaker and a "
     "stack of white paper napkins. At the far right a grey steel cash box, open, with a few coins in it."),
    ("ct_husk", "16:9", REF_BT, BT_TOP +
     "A worn wooden trestle table behind a roadside sweetcorn stand. On the left a wooden crate full of fresh corn "
     "cobs still in their green husks. In the middle a large bare stretch of the table, empty. On the right a white "
     "enamel bowl, empty. At the bottom right corner a zinc bucket of torn green husks and corn silk."),
    # ── the things on them ──────────────────────────────────────────────────────
    ("pts_glass", "16:9", REF_BT, BT_SHEET.format(view=FRONT, n=8) +
     "an empty clean dimpled half-litre glass beer mug with a handle; the same mug full to the brim of golden lager "
     "with no foam at all; a thick white beer foam head on its own, wide and flat; a dirty empty beer mug with dried "
     "foam rings inside; a tall empty straight soft-drink glass; the same tall glass full of dark brown cola with a "
     "little foam; a small empty shot glass; the same shot glass full of clear spirit."),
    ("pts_bottles", "16:9", REF_BT, BT_SHEET.format(view=FRONT, n=5) +
     "a brown rum bottle with a plain cream label; a green bottle of herbal liqueur with a plain label; a clear "
     "bottle of plum brandy with a plain label; a dark brown glass cola bottle with a red cap; a small steel "
     "measuring jigger."),
    ("pts_bar", "16:9", REF_BT, BT_SHEET.format(view=FRONT, n=7) +
     "a long thin falling stream of golden beer; a long thin falling stream of white foam; a flat puddle of spilled "
     "beer; a round blank white cardboard beer mat; a folded white bar towel; a flat steel foam-cutting knife; a "
     "small falling drop of beer."),
    ("pts_keg", "16:9", REF_BT, BT_SHEET.format(view=FRONT, n=5) +
     "a dented steel 50-litre beer keg standing upright; the same keg with a big white chalk cross on it; a black "
     "keg coupler head with a short clear hose and a lever; a red cast-iron valve wheel; a white chalk tally of five "
     "strokes."),
    ("cts_corn", "16:9", REF_BT, BT_SHEET.format(view=TOP, n=8) +
     "a whole sweetcorn cob still in its green husk with silk at the tip; a single long torn green husk leaf; a tuft "
     "of pale corn silk; a husked raw pale-yellow corn cob; a boiled bright golden corn cob glistening wet; an "
     "overcooked grey soft corn cob; a buttered shiny golden corn cob with salt grains; a boiled corn cob wrapped in "
     "a white paper napkin."),
    # ── the marks over the rooms ────────────────────────────────────────────────
    ("psh_marks", "16:9", REF_MARK, MARK_SHEET.format(n=7) +
     "a full half-litre beer mug with a white head; a mug of almost all white foam; a small shot glass of brown "
     "rum; a tall glass of dark cola; a steel beer keg; a dirty beer mug with bubbles; a boiled yellow corn cob."),
    # ── the pub's rooms ─────────────────────────────────────────────────────────
    ("psh_room", "16:9", REF_ROOM, ROOM_SHEET.format(n=8) +
     "a wild boar head trophy on a dark wooden shield; a small red and white triangular football club pennant on a "
     "string; a framed faded black-and-white photograph of an ice hockey team; a wall calendar with a picture of an "
     "old car; a small blackboard on a nail with chalk scribbles; a black cast-iron stove with a pipe going up; a "
     "zinc coal scuttle with coal; a stack of round white cardboard beer mats."),
    ("psh_room2", "16:9", REF_ROOM, ROOM_SHEET.format(n=7) +
     "a red geranium in a clay pot; a carved wooden table plaque on a little stand; a wooden coat stand with a hat "
     "and a coat on it; a yellow fly paper strip hanging with dead flies; an old brown valve radio; a framed print "
     "of a Czech pond and forest; a yellow plastic crate of empty brown beer bottles."),
    ("psh_cellar", "16:9", REF_ROOM, ROOM_SHEET.format(n=6) +
     "a steel beer cooler box with coiled copper pipes; an old dark oak beer barrel with a chalk date on it; a "
     "wooden mousetrap; a worn straw broom; a zinc bucket; a grey dusty cobweb."),
]


def main():
    path = os.path.join(HERE, "prompts_pubcorn.tsv")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for row in ROWS:
            f.write("\t".join(row) + "\n")
    print("%d rows -> %s" % (len(ROWS), path))


if __name__ == "__main__":
    main()
