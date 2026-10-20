#!/usr/bin/env python3
"""Rows for tools/artgen/prompts_podniky.tsv: the businesses' polish (the brief of 20. 10.,
"podniky"): the hands at every station, the eye cursor, the new stations' things.

    python tools/artgen/podniky_prompts.py        (rewrites prompts_podniky.tsv)

Hands: every frame twice (<id> and <id>_b), the better one picked by hand (no second
neck, no bare hand, no pose that makes no sense). Then tools/artgen/podniky_art.py.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
GLOVE = "assets/textury/hands/torch.png"

HAND = ("Pixel-art first-person POV sprite exactly like the hand and weapon sprites of a 1990s "
        "Build-engine game (Duke Nukem 3D, Blood, Redneck Rampage). The player's hand wears EXACTLY "
        "the worn tan leather work glove of the reference image, with the same rolled-up grey "
        "work-shirt sleeve, same pixel size, palette and shading. TRUE FIRST-PERSON VIEW: the camera "
        "is the player's own eyes, standing behind a counter and looking forward and down at the "
        "work on it; we see only what the player sees of their own RIGHT hand and forearm, coming up "
        "from the bottom RIGHT edge of the picture and reaching forward, with correct perspective and "
        "foreshortening. ")
HAND_END = (" Only ONE gloved hand and ONE forearm in the whole picture, no second hand, no bare skin, "
            "nothing held that is not described. Chunky pixels, strong simple shading, low saturation, "
            "the forearm touches the bottom edge of the canvas. Background must be flat solid pure "
            "magenta #FF00FF everywhere around the arm, no shadow, no counter, no table, no text, no "
            "border, no watermark.")

TEX = ("Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, Redneck "
       "Rampage): a digitized photograph crudely retouched by hand by a 1996 game artist, flat even "
       "lighting, no glow, no bloom, no steam, no smoke, no depth of field, no soft shadows, chunky "
       "pixels, a limited muddy palette, low saturation, slightly grimy and imperfect, hard edges, no "
       "readable text, no logos, no border, no watermark, no people, no hands. A flat orthographic "
       "view straight down from above, no perspective, filling the whole 16:9 canvas edge to edge: ")
TEX_REF = "assets/textury/redneck/RRTX0020.png"

SHEET = ("Pixel-art sprites in the style of 1990s Build-engine games (Duke Nukem 3D, Redneck Rampage): "
         "digitized and crudely retouched by hand, flat even lighting, chunky pixels, a limited muddy "
         "palette, low saturation. A sprite sheet: {n} separate objects in one row from left to right, "
         "each one whole, all at the same scale, with wide gaps of background between them so none "
         "touch. The background must be flat solid pure magenta #FF00FF everywhere, no cast shadows, no "
         "table, no text, no labels, no letters, no border, no watermark. ")

# Station hands: id -> what the gloved hand does (two variants of each).
HANDS = {
    # The bare glove at any station (smaller than the old reach hands, hand7_*).
    "pk_hand_open": "The gloved hand is open and empty, reaching forward and down towards the counter ahead "
                    "to pick something up: the back of the glove towards us, the fingers slightly spread and "
                    "curved, the fingertips furthest away.",
    "pk_hand_grab": "The gloved hand reaching forward and down has just closed into a loose fist round a small "
                    "object we cannot see, the fingers curled under, the knuckles towards us.",
    "pk_hand_press": "The gloved hand reaching forward and down presses one button or key with the straight "
                     "index finger, the other fingers curled in, the thumb tucked.",
    # The corn stand.
    "pk_hand_tongs": "The gloved hand holds a pair of long steel kitchen tongs by their handle, the tongs "
                     "pointing forward and down towards the counter ahead, their two scalloped tips open "
                     "and empty, ready to pick something up.",
    "pk_hand_tongs_cob": "The gloved hand holds a pair of long steel kitchen tongs, the tongs closed tight "
                         "on one whole boiled bright golden corn cob held crosswise, lifted a little, a few "
                         "drops of hot water dripping off the cob.",
    "pk_hand_brush": "The gloved hand holds a short wooden pastry brush like a pencil, its flat bristles "
                     "yellow and shiny with melted butter, the bristles pointing forward and down, resting "
                     "just above the counter.",
    "pk_hand_brush_stroke": "The gloved hand pushes a short wooden pastry brush sideways to the left, the "
                            "butter-yellow bristles pressed flat and bent by the stroke, a shiny streak of "
                            "melted butter left behind them.",
    "pk_hand_salt": "The gloved hand holds a small old glass salt shaker with a dented chrome cap upright "
                    "between the fingers and thumb, full of white salt.",
    "pk_hand_salt_shake": "The gloved hand holds a small old glass salt shaker with a dented chrome cap "
                          "turned upside down and tipped forward, a little shower of white salt grains "
                          "falling from its holes.",
    "pk_hand_husk": "The gloved fist grips the end of one long torn green corn husk leaf and pulls it "
                    "back towards the viewer, the leaf stretched out forward, its far end still curling, "
                    "a few pale corn silk threads hanging off it.",
    "pk_hand_cup": "The gloved hand holds one empty thin white plastic drinking cup upright by its body, "
                   "the cup's round open mouth facing up.",
    "pk_hand_cup_tea": "The gloved hand holds one thin white plastic drinking cup upright, full to the brim "
                       "with cold amber iced tea, a little bead of it running down the side.",
}

# Station hands as sheets of two frames of one movement (rest, act), side by side: the
# two frames drawn together keep the same glove, scale and light. id -> (rest, act).
PAIR = ("Pixel-art first-person POV sprite sheet exactly like the hand and weapon animation frames of a "
        "1990s Build-engine game (Duke Nukem 3D, Blood, Redneck Rampage). TWO separate frames of one "
        "animation side by side, the LEFT frame and the RIGHT frame, each a whole picture of the player's "
        "own RIGHT hand and forearm coming up from the bottom edge, with a WIDE gap of flat magenta "
        "between the two frames so they do not touch. The hand wears EXACTLY the worn tan leather work "
        "glove of the reference image, with the same rolled-up grey work-shirt sleeve, same pixel size, "
        "palette and shading. TRUE FIRST-PERSON VIEW: the player stands behind a bar counter and looks "
        "forward and down at the work; correct perspective and foreshortening. ")
PAIR_END = (" One gloved hand in each frame, no second hand, no bare skin, nothing held that is not "
            "described, the same size in both frames. Chunky pixels, strong simple shading, low "
            "saturation, each forearm touches the bottom edge of the canvas. Background must be flat "
            "solid pure magenta #FF00FF everywhere around and between the arms, no shadow, no counter, "
            "no text, no border, no watermark.")
PAIRS = {
    # The pub.
    "pk_hs_tap": ("The gloved fist grips the black handle of a chrome beer tap, the handle pulled towards "
                  "the viewer", "the same gloved fist on the same black tap handle pushed away from the "
                  "viewer"),
    "pk_hs_bottle": ("The gloved hand holds a green glass spirits bottle upright by its neck",
                     "the same gloved hand tips the same green bottle forward and down, pouring a thin "
                     "stream from its neck"),
    "pk_hs_wash": ("The gloved hand holds a wet empty glass beer mug with a handle, upside down, dripping",
                   "the same gloved hand pushes the same upside-down mug down onto a round bristle brush, "
                   "suds round it"),
    "pk_hs_pencil": ("The gloved hand holds a short stub of carpenter's pencil like a pen, its point "
                     "down, about to write", "the same gloved hand draws a short stroke with the pencil "
                     "point pressed down, the wrist moved a little to the left"),
    "pk_hs_coin": ("The gloved hand holds a few silver and brass coins pinched between thumb and fingers",
                   "the same gloved hand opens and lets the coins drop, the coins falling out of it"),
    "pk_hs_dart": ("The gloved hand holds one brass dart with red flights between thumb and two fingers, "
                   "raised by the cheek, the dart pointing forward and away, aiming",
                   "the same gloved hand just after the throw, pushed forward, the fingers open and "
                   "empty, the dart gone"),
    # The bistro.
    "pk_hs_ladle": ("The gloved hand holds a big dented aluminium soup ladle by its long handle, the bowl "
                    "of the ladle down and forward, full of brown soup",
                    "the same gloved hand tips the same ladle over sideways, the brown soup pouring out of "
                    "it in a thick stream"),
    "pk_hs_opener": ("The gloved hand holds a flat steel bottle opener hooked under the gold crown cap of a "
                     "brown glass bottle standing on the counter",
                     "the same gloved hand has levered the opener up hard: the bent gold crown cap pops off "
                     "and flies up into the air, a little puff of fizz at the bottle's mouth"),
    # The Jednota's deli counter.
    "pk_hs_knife": ("The gloved hand holds a long thin butcher's slicing knife by its black handle, the "
                    "blade pointing forward and down, ready to cut",
                    "the same gloved hand pushes the same knife down and forward through a cut, the blade "
                    "lower, the wrist turned a little"),
    "pk_hs_wrap": ("The gloved hand presses its flat palm down on a folded parcel of grey wrapping paper",
                   "the same gloved hand folds the near edge of the grey paper over the parcel, the "
                   "fingers pinching the fold"),
}

ROWS = [
    # The eye: things worth a look in the rooms (HandCursor.LOOK).
    ("pk_cursor_look", "1:1", "assets/textury/ui/cursor_point.png",
     "Pixel-art mouse cursor icon from a 1990s Build-engine game's interface (Duke Nukem 3D, Redneck "
     "Rampage), matching the reference image's pixel size, dark outline, palette and shading: a single "
     "wide-open human eye seen straight from the front, almond-shaped, its white slightly yellowed, a "
     "brown iris and a black pupil with one small white highlight, a heavy upper lid with a few short dark "
     "lashes, drawn as a chunky simple icon that reads at 24 pixels. One eye only, centred, nothing else. "
     "Background must be flat solid pure magenta #FF00FF everywhere, no shadow, no text, no border, no "
     "watermark."),
    # The corn stand's drinks: the end table with the iced tea barrel and the bags of lemonade.
    ("pk_ct_drinks", "16:9", TEX_REF,
     TEX + "The worn plank top of a small wooden table at the end of a roadside sweetcorn stand. At the "
     "far left a stack of white plastic cups upside down. Left of the middle a round grey metal drip "
     "grate set into the planks, wet. Right of the middle a bare stretch of planks, empty. At the right a "
     "flat cardboard tray with a pile of empty clear plastic bags and a bundle of bendy striped drinking "
     "straws."),
    ("pk_cts_drinks", "16:9", TEX_REF,
     SHEET.format(n=8) + "Seen from the front, a little from above. The objects, left to right: a squat "
     "orange plastic drinks cooler barrel with a white lid and a small white push-button tap low on its "
     "front; a big two-litre plastic bottle of bright red raspberry lemonade with a white cap; an empty "
     "thin white plastic cup; the same cup full of amber iced tea; a clear plastic bag, empty and flat; "
     "the same clear plastic bag full of red lemonade, its neck gathered and tied tight round a bendy "
     "striped straw sticking out of the top; a thin straight falling stream of amber iced tea; a thin "
     "straight falling stream of red lemonade."),
    # The pub's fun: LUCKY 7, darts, cards (Czech German-suited cards).
    ("pk_ps_slot", "16:9", TEX_REF,
     SHEET.format(n=2) + "Seen straight from the front. The objects, left to right: an old 1970s "
     "one-armed-bandit slot machine for a village pub, a tall cabinet of chipped red and cream enamelled "
     "metal with chrome trim, a glass window in its middle with three empty reel slots side by side, a "
     "coin slot and a metal payout tray at the bottom, a small lit panel on top with a big red number "
     "seven painted on it, NO lever on the machine; then, separate, the machine's lever: a chrome rod "
     "with a red ball knob on top, standing upright."),
    ("pk_ps_reels", "16:9", TEX_REF,
     SHEET.format(n=6) + "Seen straight from the front, each one a small square slot-machine reel "
     "picture on a cream background: a big red number seven; two red cherries on a stalk; a golden "
     "bell; a yellow lemon; a black bar with the word BAR; a purple plum."),
    ("pk_ps_darts", "16:9", TEX_REF,
     SHEET.format(n=3) + "The objects, left to right: one brass dart with red feather flights lying "
     "sideways, its point to the left; the same dart seen from behind as it flies away, small, only "
     "the red flights and the shaft; the same dart stuck point first, seen from the side, as if in a "
     "board."),
    ("pk_ps_cards", "16:9", TEX_REF,
     SHEET.format(n=9) + "Old worn Czech German-suited playing cards (the 'William Tell' pattern, "
     "mariasove karty), each card upright, seen straight from the front, all the same size: the back of "
     "a card with a faded green and red pattern; then hearts cards: the seven of hearts, the eight of "
     "hearts, the nine of hearts, the ten of hearts, the Unter (a man in an old costume, hearts), the "
     "Ober (a man in an old costume holding a heart high), the King of hearts on his throne, the Ace "
     "of hearts (the Daus) with a big heart."),
    # The pub's waiter's wallet and a dartboard without darts in it.
    ("pk_ps_wallet", "16:9", TEX_REF,
     SHEET.format(n=2) + "Seen straight down from above. The objects, left to right: an old black "
     "leather Czech waiter's wallet (cisnicka penezenka) lying open, its zipped coin pouch open with "
     "four little compartments of silver and brass coins, a few worn banknotes in the back; a round "
     "sisal dartboard seen from the front, black and cream sectors, red and green rings, a thin wire "
     "web, NO darts in it, a black ring of numbers round it."),
    # The bistro's grill (the kitchen island) and its bufet counter (soup, bottles).
    ("pk_bt_grill", "16:9", TEX_REF,
     TEX + "The stainless steel top of a kitchen island with a small gas grill set into it. At the far "
     "left a small white enamel tray, empty. In the middle a black cast-iron grill grate over a gas "
     "burner, its bars running left to right, empty. At the right a steel wire resting rack, empty."),
    ("pk_bts_grill", "16:9", TEX_REF,
     SHEET.format(n=8) + "Seen straight down from above. The objects, left to right: a thick raw pink "
     "Czech sausage (klobasa), slightly curved; the same sausage half grilled, brown on one side with grill "
     "marks; the same sausage grilled all over, brown and shiny with black grill marks; the same sausage "
     "burnt black and split; a dollop of yellow mustard; a slice of dark Czech rye bread with a brown "
     "crust; a small glass jar of yellow mustard with a wooden spoon in it; a small wicker basket of rye "
     "bread slices."),
    ("pk_bt_bufet", "16:9", TEX_REF,
     TEX + "The worn top of the counter of a 1980s Czech roadside canteen (bufet), brown laminate "
     "with steel edges. At the left a big dented aluminium soup pot on a hot plate, full of brown potato "
     "soup, a ladle in it. Next to it a stack of thick white soup bowls. In the middle a bare stretch of "
     "the counter. At the right a yellow plastic crate of brown and clear glass soda bottles with crown "
     "caps, and a steel bottle opener on a string."),
    ("pk_bts_bufet", "16:9", TEX_REF,
     SHEET.format(n=8) + "Seen from the front, a little from above. The objects, left to right: a thick "
     "white soup bowl, empty; the same bowl full of brown Czech potato soup (bramboracka) with bits of "
     "mushroom and parsley; a half-litre brown glass bottle of Kofola with a red and black label and a gold "
     "crown cap; the same bottle opened, no cap, a little fizz at its mouth; a half-litre clear glass "
     "bottle of red raspberry soda (malinovka) with a gold crown cap; the same bottle opened, no cap; one "
     "gold bottle crown cap, bent from opening; a flat steel bottle opener."),
    # The Jednota's deli counter: slice, weigh, wrap.
    ("pk_jt_deli", "16:9", TEX_REF,
     TEX + "The worn top of the deli counter of a 1980s Czech village grocery (Jednota): white "
     "enamelled steel. At the left a wooden cutting board, empty. In the middle a white enamelled "
     "butcher's scale with a round dial and a steel weighing plate, empty. At the right a roll of grey "
     "wrapping paper on a steel holder, its loose end lying flat on the counter."),
    ("pk_jts_deli", "16:9", TEX_REF,
     SHEET.format(n=8) + "Seen straight down from above. The objects, left to right: a whole long "
     "stick of Czech salami (Vysocina) in its pale skin; a small pile of round salami slices; a block of "
     "yellow Eidam cheese; a small pile of square cheese slices; a round loaf of Czech rye bread "
     "(chleba) with caraway seeds; the same loaf cut in half; a parcel wrapped in grey paper, tied with "
     "white string; a long thin butcher's knife with a black handle."),
    # The Jednota's new goods (the fun, the rum, the cigarettes) and the deli's parcel.
    ("pk_jts_goods", "16:9", "assets/textury/jednota/goods_beer.png",
     SHEET.format(n=5) + "Matching the reference image's pixel size and palette. Seen from the front. "
     "The objects, left to right: a soft paper pack of Czech Start cigarettes, white with a red band and "
     "a small red star; a brown glass bottle of Czech Tuzemak rum with a yellow and green label and a "
     "metal screw cap; a pack of playing cards in a worn red cardboard box; a folded 1980s Czech youth "
     "magazine with a faded colour cover photo; a parcel of grey grocer's paper tied with white string."),
    ("pk_pot_boil", "16:9", TEX_REF,
     SHEET.format(n=3) + "Seen straight down from above. Three frames of one animation: the round surface "
     "of boiling water inside a dented aluminium pot, the pot's rim round it, the water grey-white with "
     "rolling bubbles, the bubbles in different places in each of the three frames."),
]


def main():
    lines = []
    for art_id, aspect, ref, prompt in ROWS:
        lines.append("\t".join([art_id, aspect, ref, prompt]))
        if art_id.startswith("pk_cursor"):
            lines.append("\t".join([art_id + "_b", aspect, ref, prompt]))
    for hid, what in HANDS.items():
        prompt = HAND + what + HAND_END
        for suffix in ("", "_b"):
            lines.append("\t".join([hid + suffix, "1:1", GLOVE, prompt]))
    for pid, (rest, act) in PAIRS.items():
        prompt = PAIR + "LEFT frame: " + rest + ". RIGHT frame: " + act + "." + PAIR_END
        for suffix in ("", "_b"):
            lines.append("	".join([pid + suffix, "16:9", GLOVE, prompt]))
    path = os.path.join(HERE, "prompts_podniky.tsv")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("%d rows -> %s" % (len(lines), path))


if __name__ == "__main__":
    main()
