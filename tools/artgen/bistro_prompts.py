#!/usr/bin/env python3
"""Writes tools/artgen/prompts_bistro.tsv: the bistro's station screens (16:9 paintings
the stations are played on, scripts/bistro/) and the sheets of things drawn over them.

    python tools/artgen/bistro_prompts.py

gen.sh reads prompts.tsv and every prompts_*.tsv beside it.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REF_BG = "assets/textury/closeup/bistro_hatch.png"
REF_FOOD = "assets/textury/closeup/bistro_hatch.png"

BG = ("Hand-painted pixel art in exactly the same style as the reference image (an early 1990s "
      "DOS adventure game close-up: chunky dithered pixels, a limited 256-colour palette, warm "
      "lamplight, painted look, low saturation), but a WIDE 16:9 full-screen background for a "
      "cooking game station like Papa's Burgeria: seen from above and a little in front, "
      "everything large, clear and easy to read, filling the whole canvas edge to edge, no "
      "people, no hands, no readable text, no letters, no numbers, no UI, no border, no "
      "watermark. ")

SHEET = ("Pixel-art sprites in exactly the same style as the reference image (hand-painted early "
         "1990s DOS adventure game art: chunky dithered pixels, the same 256-colour palette, the "
         "same warm light and the same view from above and a little in front). A sprite sheet: "
         "{n} separate objects in one row from left to right, each one whole, all at the same "
         "scale, with wide gaps of background between them so none touch. The background must "
         "be flat solid pure magenta #FF00FF everywhere, no cast shadows, no table, no "
         "surface, no text, no labels, no border, no watermark. The objects, left to right: ")

REF_BT = "assets/textury/redneck/RRTX0020.png"
BT = ("Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, Redneck Rampage): a "
      "digitized photograph crudely retouched by hand by a 1996 game artist, flat even lighting, no glow, no "
      "bloom, no steam, no smoke, no depth of field, no soft shadows, chunky pixels, a limited muddy palette, low "
      "saturation, slightly grimy and imperfect, hard edges, no readable text, no logos, no border, no "
      "watermark, no people, no hands. ")
BT_TOP = BT + "A flat orthographic view straight down from above, no perspective, filling the whole 16:9 canvas edge to edge: "
BT_FRONT = BT + "A flat orthographic straight-on front view, no perspective, filling the whole 16:9 canvas edge to edge: "
BT_SHEET = ("Pixel-art sprites in the style of 1990s Build-engine games (Duke Nukem 3D, Redneck Rampage): digitized "
            "and crudely retouched by hand, flat even lighting, chunky pixels, a limited muddy palette, low "
            "saturation, seen straight down from above. A sprite sheet: {n} separate objects in one row from left "
            "to right, each one whole, all at the same scale, with wide gaps of background between them so none "
            "touch. The background must be flat solid pure magenta #FF00FF everywhere, no cast shadows, no table, "
            "no text, no labels, no border, no watermark. The objects, left to right: ")

ROWS = [
    # ── the station screens ──────────────────────────────────────────────────────
    ("bst_stove", "16:9", REF_BG, BG +
     "The frying station of a small 1980s Czech roadside bistro kitchen. In the middle a black "
     "cast-iron gas range seen from above. On its left burner, low in the picture, a very large "
     "wide black frying pan with a thin layer of shimmering hot oil and absolutely nothing in it. "
     "On the right a square stainless deep-fryer tank of bubbling golden oil, empty, with nothing "
     "hanging over it. At the far left a strip of steel counter with an empty white enamel tray. "
     "At the far right a strip of steel counter with an empty wire cooling rack under a glowing "
     "red heat lamp. Brown 1970s wall tiles behind, a little grease, a wisp of steam. The pan, "
     "the fryer, the tray and the rack are empty and clearly apart with room around each."),
    ("bst_pot", "16:9", REF_BG, BG +
     "The goulash station of a small 1980s Czech roadside bistro kitchen. On the left half a huge "
     "dented aluminium pot on a gas ring with a small blue flame, seen from above so its whole "
     "round mouth is visible, full of dark red-brown goulash. On the right half a big pale "
     "wooden chopping board lying flat and completely empty, with a white cotton thread "
     "stretched taut across the board from one nail to another. Behind the board an aluminium "
     "steamer pot with a lid, a puff of steam. A tin of paprika on the shelf at the back, brown "
     "1970s tiles. Nothing on the board."),
    ("bst_pass", "16:9", REF_BG, BG +
     "The serving pass of a small 1980s Czech roadside bistro kitchen, seen from the cook's side "
     "looking down at a long brushed steel counter. Across the top a wide serving hatch opening "
     "into the warm-lit dining room beyond, blurred tables with red gingham cloths, a chrome "
     "service bell standing on the hatch sill at the right. On the counter, left to right: a "
     "steel water bath with a pan of dark goulash and a ladle in it, then a large clear empty "
     "space of bare steel in the middle where one plate will be set, then a bowl of white tartar "
     "sauce with a spoon and a bowl of raw onion rings. Above the counter on the left, an empty "
     "steel shelf under red heat lamps. Keep the middle of the counter and the shelf bare."),
    ("bst_sink", "16:9", REF_BG, BG +
     "The washing-up corner of a small 1980s Czech roadside bistro kitchen. In the middle a white "
     "enamel sink full of grey soapy water with white foam, a brass tap over it. On the left an "
     "empty steel draining board. On the right an empty wooden plate drying rack on the wall "
     "with slots for plates. A scrubbing brush and a bar of yellow soap on the edge. Brown 1970s "
     "tiles, a bare bulb. Keep the draining board and the rack empty."),
    ("bst_potatoes", "16:9", REF_BG, BG +
     "A corner of the damp red-brick cellar under a 1980s Czech roadside bistro, lit by one bare "
     "bulb. On the left an old cream enamel electric potato peeling machine: a tall round drum "
     "with an open top, a big black rotary switch on its side and a short chute at its foot. On "
     "the right a cast-iron chip cutter press bolted to a worn wooden table: a square grid of "
     "blades with a long lever arm raised up. On the concrete floor between them an empty zinc "
     "bucket. A bulging jute sack of potatoes slumped against the wall at the far left. Keep the "
     "bucket and the cutter's grid empty."),
    ("bst_breading", "16:9", REF_BG, BG +
     "A prep table in the damp red-brick cellar under a 1980s Czech roadside bistro, seen from "
     "above, lit by one bare bulb. Across the middle three white enamel bowls in a row, well "
     "apart: the first full of white flour, the second full of beaten yellow egg, the third full "
     "of golden breadcrumbs. On the left a wooden board with a big block of yellow Edam cheese "
     "and a kitchen knife. On the right an empty white enamel tray. Flour dust on the scrubbed "
     "wooden table top. Keep the tray empty."),
    ("bst_machine", "16:9", REF_BG, BG +
     "The far end of a dark brick cellar under a 1980s Czech roadside bistro, behind a sagging "
     "chain-link partition with its gate ajar: a big old industrial machine nobody ordered, built "
     "of green-painted riveted steel, a wide funnel hopper on top, a riveted drum with a heavy "
     "crank wheel, a ribbed steel chute at the front ending over an empty white enamel tray, a "
     "small round gauge and a dark red indicator lamp, a thick black cable running from it to a "
     "plug lying unplugged on the wet concrete floor. A riveted maker's plate with no readable "
     "writing. Dark stains on the floor under the chute. One weak bare bulb. Serious and uncanny, "
     "not cartoonish."),
    # ── the things drawn over them ───────────────────────────────────────────────
    ("bsh_dumplings", "16:9", REF_FOOD, SHEET.format(n=4) +
     "1) a whole steamed Czech bread dumpling: a long fat pale cylinder of soft white bread with "
     "small holes, lying on its side; 2) the same loaf half cut, its cut face showing; 3) one "
     "single round slice of bread dumpling lying flat, about as thick as a finger; 4) a fan of "
     "four overlapping slices of bread dumpling."),
    ("bsh_potatoes", "16:9", REF_FOOD, SHEET.format(n=5) +
     "1) one raw potato with brown earthy skin; 2) one peeled raw potato, pale yellow and wet; "
     "3) a small heap of raw cut potato chips, pale sticks; 4) a zinc bucket full of pale raw "
     "potato chips in water; 5) a heap of brown potato peelings."),
    ("bsh_breading", "16:9", "assets/textury/closeup/parts/cheese_raw.png", SHEET.format(n=5) +
     "five stages of the same thick rounded-oblong slice of Edam cheese, the same size and the "
     "same angle each time: 1) a plain slice of yellow Edam cheese; 2) the slice dusted white "
     "with flour; 3) the floured slice dripping with glossy yellow beaten egg; 4) the slice fully "
     "coated in pale cream breadcrumbs, ready to fry; 5) the slice badly coated, patchy "
     "breadcrumbs with bare yellow cheese showing through."),
    ("bsh_plates", "16:9", REF_FOOD, SHEET.format(n=5) +
     "1) a clean empty round white plate with a thin blue rim, seen from above; 2) the same plate "
     "dirty, smeared with red-brown goulash sauce and crumbs, a crust of dumpling; 3) a stack of "
     "six clean white plates with blue rims seen from the side and a little above; 4) a yellow "
     "kitchen sponge with a green scourer side; 5) a cluster of white soap bubbles."),
    ("bsh_cook", "16:9", REF_FOOD, SHEET.format(n=6) +
     "1) an empty wire chip basket with a long handle; 2) the same wire basket full of pale raw "
     "chips; 3) the same basket full of golden fried chips; 4) a long wooden cooking spoon; 5) a "
     "steel soup ladle full of dark goulash; 6) a few raw white onion rings."),
    ("bsh_marks", "16:9", "assets/textury/ui/mark_plate.png", SHEET.format(n=8) +
     "eight small bold game icons in the same style as the reference icon, each a single clear "
     "object: 1) a wooden spoon stirring a pot; 2) a frying pan with a slice in it; 3) a stack "
     "of dirty plates; 4) a raw potato; 5) a slice of breaded cheese; 6) a bread dumpling; 7) a "
     "chrome service bell; 8) a small paper order ticket."),
    ("bsh_dining", "16:9", REF_BG, SHEET.format(n=7) +
     "things from a 1980s Czech roadside bistro dining room, each seen from the front: 1) a "
     "glass-fronted cake display case on legs with cream cakes and pastries inside; 2) a chrome "
     "drinks tap tower with two taps and a drip tray; 3) a sticky yellow fly paper strip hanging "
     "from a pin, a few flies stuck on it; 4) a small grey television on a black wall bracket; "
     "5) a thin glass vase with one red plastic carnation; 6) a steel napkin holder with paper "
     "napkins beside a glass salt and pepper shaker; 7) a bentwood coat stand with a grey coat "
     "and a hat hung on it."),
    ("bsh_kitchen", "16:9", REF_BG, SHEET.format(n=7) +
     "things from a 1980s Czech canteen kitchen, each seen from the front: 1) a wall rail with "
     "hanging steel ladles, a skimmer and two small pans; 2) a magnetic knife strip with four "
     "kitchen knives; 3) a blue glowing electric fly zapper lamp; 4) a tall pile of dirty white "
     "plates; 5) a steel wall rack of clean white plates standing in slots; 6) a jute sack of "
     "flour, open at the top; 7) a fat round aluminium stock pot with a lid."),
    ("bsh_cellar", "16:9", REF_BG, SHEET.format(n=7) +
     "things from a damp 1980s Czech cellar, each seen from the front: 1) an old cream enamel "
     "electric potato peeling machine, a tall drum on legs with a switch; 2) a cast-iron chip "
     "cutter press with a lever, bolted on a small wooden table; 3) a wooden shelf of glass jars "
     "of pickled gherkins; 4) a thick dusty cobweb; 5) a brown rat sitting up; 6) a wooden mouse "
     "trap; 7) a bare light bulb hanging on a twisted cord."),
    # ── textures for the rooms ───────────────────────────────────────────────────
    ("tex_steel_brushed", "1:1", "-", "Seamless tileable texture, flat orthographic view filling the whole square, no perspective: "
     "clean brushed stainless steel sheet from a 1980s canteen kitchen counter, fine horizontal brushing grain, a soft "
     "light sheen, a few faint scratches, no dents, no rivets, no seams. Light silver grey. In the style of 1990s "
     "Build-engine game textures (Duke Nukem 3D, Redneck Rampage), crisp, no text, no border, no watermark, must tile "
     "seamlessly on all four edges."),
    ("tex_kitchen_tiles", "1:1", "-", "Seamless tileable texture, flat front view filling the whole square: a grid of small "
     "square glazed white wall tiles, 6 by 6, from a 1980s Czech canteen kitchen, light grey grout, faint yellowed grease "
     "near the grout lines, one chipped corner. Low saturation, in the style of 1990s Build-engine game textures (Duke "
     "Nukem 3D, Redneck Rampage), crisp, no text, no border, no watermark, no stripes, must tile seamlessly on all four "
     "edges."),
    ("tex_chainlink", "1:1", "-", "Seamless tileable texture, flat front view filling the whole square: rusty galvanised "
     "chain-link fence mesh, diamond pattern, thin wires, the background between the wires must be flat solid pure "
     "magenta #FF00FF. In the style of 1990s Build-engine game textures, crisp, no text, no border, must tile seamlessly."),
    ("bsh_extra", "16:9", REF_FOOD, SHEET.format(n=6) +
     "1) a big round catering tin of goulash with a dented red lid; 2) a gold five-pointed star; 3) the same star dull "
     "grey; 4) a white china plate standing on its edge, seen from the front, thin blue rim; 5) a wooden cooking spoon "
     "held upright; 6) a small bowl of white tartar sauce."),
    # ── the stations again, as Build-engine textures (playtest 19. 10.: "less like AI pixel
    # art, more like imperfect human Build-engine textures"): flat, orthographic, crude ──
    ("bt_stove", "16:9", REF_BT, BT_TOP +
     "The top of a black cast-iron gas range in a 1980s Czech canteen kitchen. On the left half a big round "
     "black frying pan with a thin layer of oil in it, empty. On the right a square steel deep fryer full of "
     "golden oil, empty. At the far left edge a strip of steel counter with an empty white enamel tray; at the "
     "far right edge a strip of steel counter with an empty wire rack. Burner grates; a row of knobs along the "
     "bottom edge."),
    ("bt_pass", "16:9", REF_BT, BT_TOP +
     "A long brushed steel serving counter in a 1980s Czech canteen. On the left a big aluminium pot of dark red "
     "goulash standing in a water bath, a ladle in it. In the middle a large empty area of bare steel. On the "
     "right a bowl of white tartar sauce with a spoon and a bowl of raw onion rings. Along the top edge a strip "
     "of steel shelf, bare, and a chrome service bell at the top right corner."),
    ("bt_pot", "16:9", REF_BT, BT_TOP +
     "On the left a huge round dented aluminium pot full of dark red-brown goulash on a gas ring. On the right "
     "a pale wooden chopping board, empty, with a white cotton thread stretched across it between two nails. "
     "At the top right a round aluminium steamer pot with its lid on. At the top middle a big catering tin with "
     "a red lid. Steel counter between them."),
    ("bt_sink", "16:9", REF_BT, BT_TOP +
     "A white enamel sink full of grey soapy water and foam set in a steel counter, a brass tap at the top edge. "
     "On the left an empty ribbed steel draining board. On the right a bare stretch of steel counter. A "
     "scrubbing brush and a yellow bar of soap on the edge."),
    ("bt_potatoes", "16:9", REF_BT, BT_FRONT +
     "A damp red-brick cellar wall with things standing in front of it on a concrete floor: on the left an old "
     "cream enamel electric potato peeling machine, a drum on a stand with a black switch and a short chute; "
     "in the middle on the floor an empty zinc bucket; on the right a cast-iron chip cutter press with its lever "
     "raised, bolted on a wooden table; a jute sack of potatoes at the far left."),
    ("bt_breading", "16:9", REF_BT, BT_TOP +
     "A scrubbed wooden table in a cellar. Three white enamel bowls in a row across the middle, well apart: "
     "white flour, beaten yellow egg, golden breadcrumbs. On the left a wooden board with a block of yellow Edam "
     "cheese and a kitchen knife. On the right an empty white enamel tray. Flour dust."),
    ("bt_machine", "16:9", REF_BT, BT_FRONT +
     "A big old industrial machine of green-painted riveted steel against a dark brick cellar wall: a funnel "
     "hopper on top, a riveted drum with a crank wheel at the side, a ribbed chute at the front over an empty "
     "white enamel tray, a round gauge, a dark red lamp, a thick black cable to an unplugged plug on the wet "
     "concrete floor, a riveted maker's plate with no readable writing, stains under the chute."),
    ("bts_fry", "16:9", REF_BT, BT_SHEET.format(n=6) +
     "1) a raw breaded slice of Czech fried cheese, pale crumbs; 2) the same slice fried golden brown; 3) the "
     "same slice burnt black with cheese running out; 4) an empty wire chip basket with a handle; 5) the same "
     "basket full of pale raw chips; 6) the same basket full of golden fried chips."),
    ("bts_plate", "16:9", REF_BT, BT_SHEET.format(n=8) +
     "1) an empty round white plate with a thin blue rim; 2) a ladleful of dark red goulash with chunks of meat, "
     "no onion; 3) one round slice of bread dumpling; 4) a fried breaded cheese slice; 5) a heap of golden chips; "
     "6) a dollop of white tartar sauce; 7) a few raw white onion rings; 8) the white plate dirty with goulash "
     "smears and crumbs."),
    ("bts_cellar", "16:9", REF_BT, BT_SHEET.format(n=7) +
     "1) a raw potato with brown earthy skin; 2) a peeled raw potato, pale and wet; 3) a small heap of pale raw "
     "potato chips; 4) a whole steamed Czech bread dumpling loaf lying on its side; 5) a plain thick slice of "
     "yellow Edam cheese; 6) the same slice dusted white with flour; 7) the same slice wet with yellow egg."),
    ("bts_misc", "16:9", REF_BT, BT_SHEET.format(n=7) +
     "1) the cheese slice coated in breadcrumbs; 2) the cheese slice patchily coated, cheese showing; 3) a stack "
     "of white plates with blue rims; 4) a yellow kitchen sponge; 5) a long wooden cooking spoon; 6) a gold "
     "star; 7) the same star dull grey."),
    # The fronts of the stations' counters in the rooms (the tops are the stations).
    ("bf_stove", "16:9", REF_BT, BT_FRONT +
     "The front of a black cast-iron 1980s canteen gas range and deep fryer side by side: a row of black knobs "
     "along the top, two oven doors with small windows and chrome handles below, a fryer cabinet with a "
     "thermostat dial on the right, grease stains, kick plate along the bottom."),
    ("bf_steel", "16:9", REF_BT, BT_FRONT +
     "The front of a long stainless steel canteen kitchen counter: three cupboard doors with recessed handles, "
     "a drawer row along the top, dents and smudges, a kick plate along the bottom."),
    ("bf_table", "16:9", REF_BT, BT_FRONT +
     "The front of an old scrubbed wooden work table seen straight on: a thick worn top edge, a drawer with a "
     "round knob, four square legs, a low shelf between them with a sack of flour and a basket of eggs."),
]


def main() -> None:
    out = os.path.join(HERE, "prompts_bistro.tsv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for row in ROWS:
            assert "\t" not in "".join(row)
            f.write("\t".join(row) + "\n")
    print(f"{len(ROWS)} rows -> {out}")


if __name__ == "__main__":
    main()
