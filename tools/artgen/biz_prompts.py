#!/usr/bin/env python3
"""Writes tools/artgen/prompts_biz.tsv: the businesses' people and things for the shared
systems (DESIGN.md §7b): the hands (a sheet each: standing, and at work at a counter),
the ID photos of the two applicants nobody quite remembers, the goods gone off.

    python tools/artgen/biz_prompts.py

gen.sh reads prompts.tsv and every prompts_*.tsv beside it; processed by biz_art.py.
The hands are the people on the old ID photos (assets/textury/os98/photos/<slug>.png),
drawn the way the guests are (memory: eerie guests look; grainy, something off).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REF_W = "assets/textury/npc/host_pensioner.png"
REF_M = "assets/textury/npc/host_tramp.png"
REF_PHOTO = "assets/textury/os98/photos/hanka.png"
REF_ROOM = "assets/textury/camp/bistro_cakes.png"

STAFF = ("Pixel-art game character sprites in exactly the same style as the reference image: the same pixel size, "
         "the same palette and shading, the same rough grain, noise and dither, sallow slightly wrong skin tones and "
         "stiff, vacant, unsettling faces. Two figures of the SAME person side by side on one sheet, with a wide gap "
         "of background between them so they do not touch, both at exactly the same size and scale, each filling "
         "about 85% of the height, the feet touching the bottom edge. LEFT: standing facing the viewer, arms hanging "
         "at the sides. RIGHT: the same person seen from the front working at a counter that is NOT drawn, both "
         "forearms forward at waist height, the hands busy just below the waist, the head bowed looking down at the "
         "work. The person: {who} Nothing in the hands but {tool}. Something about this person is subtly off, like a "
         "stranger you would not sit next to. No smile, not cheerful, not clean or cartoonish, the same uncomfortable "
         "proportions as the reference. The background must be flat solid pure magenta #FF00FF everywhere around the "
         "figures, no counter, no table, no floor, no ground shadow, no text, no border, no watermark.")

# slug -> (reference, description, tool)
HANDS = [
    ("dvorakova", REF_W, "a heavy woman of about sixty with wavy grey hair, a broad tired face, a cream blouse under a "
     "white kitchen smock with old brown stains, a white apron tied over it, thick flesh-coloured stockings, worn brown "
     "slip-on shoes.", "a dishcloth"),
    ("pepa", REF_M, "a bald heavy man of about fifty with a thick brown moustache and a red face, a stained white "
     "double-breasted cook's jacket with the sleeves pushed up, checked grey kitchen trousers, black clogs.",
     "a ladle"),
    ("hanka", REF_W, "a thin young woman of about twenty-five with long straight brown hair parted in the middle, dark "
     "rings under her eyes, a white blouse with the sleeves rolled up, a short black apron, a dark knee-length skirt, "
     "flat black shoes.", "a cloth"),
    ("lojza", REF_M, "a heavy man of about sixty with a red face, a grey moustache and a faded green cap, a yellowish "
     "short-sleeved shirt with sweat marks, a dark knitted waistcoat over it, a tea towel over one shoulder, brown "
     "trousers, worn black shoes.", "a beer mug"),
    ("franta", REF_M, "a man of about thirty-five with a dark curly mullet and stubble, a faded denim jacket with the "
     "sleeves pushed up over a grey t-shirt, black jeans, white trainers gone grey.", "a beer mug"),
    ("mirek", REF_M, "a thin young man of about twenty with short bleached hair, a black t-shirt, a black waiter's "
     "apron, black jeans, scuffed black shoes.", "a glass"),
    ("novakova", REF_W, "a woman of about fifty with long dyed red hair and big glasses that catch the light, a "
     "faded blue nylon shop smock buttoned to the neck, a pencil in the breast pocket, dark trousers, brown "
     "slippers.", "a paper bag"),
    ("zdenka", REF_W, "a woman of about forty with short dark hair and a tired grey face, a dark grey cardigan over a "
     "light blouse, a faded blue nylon shop smock over it, a dark skirt, flat brown shoes.", "a paper bag"),
    ("ivan", REF_M, "a gaunt man of about thirty with long dark greasy hair, a hollow face, a brown warehouse coat "
     "worn open over a black t-shirt, grey work trousers, heavy black boots.", "a cardboard box"),
    ("pepicek", REF_M, "a boy of about fifteen with a dark bowl haircut and a pale round face, a navy and white "
     "striped t-shirt, a too big grey tracksuit trousers, dirty white trainers.", "a corn cob"),
    ("klara", REF_W, "a girl of about sixteen with blonde hair in two plaits, pale blue eyes too far apart, a beige "
     "t-shirt, a denim skirt, white socks, sandals.", "a corn cob"),
    ("novak_boy", REF_M, "a boy of about fourteen with very short dark hair and a fixed grin that does not reach his "
     "eyes, a red tracksuit jacket with white stripes on the sleeves, blue jeans, white trainers.", "a corn cob"),
    # The two nobody quite remembers (DESIGN.md §7b, the hands: the strange ones).
    ("jaromir", REF_M, "a thin pale man of indeterminate age with neatly combed dark hair parted on the side, an "
     "old-fashioned brown suit too tight at the shoulders, a spotless white apron over it, polished black shoes, a "
     "small smile held a moment too long.", "a white cloth folded very neatly"),
    ("marta", REF_W, "a woman of about forty with smooth dark hair pinned up, a pale face with very still eyes, a "
     "pale green 1970s nylon uniform dress with a white collar, a white apron, white nurse's shoes.", "a pencil"),
]

PHOTO = ("A grainy small ID photograph in exactly the same style as the reference image (a pixel-art passport photo, "
         "the same pixel size, palette, grain, noise and dither, sallow slightly wrong skin tones, a stiff vacant "
         "face, the same mottled grey-blue backdrop and the same framing: head and shoulders, straight on, filling "
         "the picture). {who} No smile. Something about the face is subtly off. No text, no border, no watermark.")
PHOTOS = [
    ("ph_jaromir", REF_PHOTO, "A thin pale man of indeterminate age with neatly combed dark hair parted on the side, "
     "a brown suit jacket, a white shirt buttoned to the top, a small smile held a moment too long, eyes that look "
     "just past the camera."),
    ("ph_marta", REF_PHOTO, "A woman of about forty with smooth dark hair pinned up, a pale face, very still dark "
     "eyes, a pale green uniform with a white collar."),
]
# Marta's photo is a little different every few days: each made from the one before.
DRIFT = [
    ("ph_marta2", "assets/textury/os98/photos/marta.png", "Exactly the same photograph of the same woman, identical "
     "in every way, except that her eyes are set very slightly further apart and her head is tilted a few degrees."),
    ("ph_marta3", "assets/textury/os98/photos/marta2.png", "Exactly the same photograph of the same woman, identical "
     "in every way, except that her mouth is a little longer and she seems slightly nearer the camera."),
]

THINGS = ("Pixel-art sprites in exactly the same style as the reference image (hand-retouched 1990s Build-engine "
          "game sprites, chunky pixels, a limited muddy palette, flat light), seen {view}. A sprite sheet: {n} "
          "separate objects in one row from left to right, each one whole, all at the same scale, with wide gaps of "
          "background between them so none touch. The background must be flat solid pure magenta #FF00FF "
          "everywhere, no cast shadows, no floor, no text, no letters, no labels, no border, no watermark. The "
          "objects, left to right: ")
GOODS_OFF = [
    ("bzs_off1", "16:9", REF_ROOM, THINGS.format(view="straight on from the front", n=5) +
     "a jute sack of potatoes slumped open with long pale sprouts growing out of the potatoes; a block of yellow "
     "Edam cheese with blue-green mould spreading over one end; a round loaf of brown bread gone grey-green with "
     "furry mould; a bloated white milk bag in a plastic jug, swollen and sagging; a dried-out corn cob with "
     "shrivelled brown kernels and black spots."),
    ("bzs_off2", "16:9", REF_ROOM, THINGS.format(view="straight on from the front", n=5) +
     "a tray of bread rolls gone hard and pale grey with mould spots; a stick of salami with white mould and a "
     "slimy cut end; a glass jar of gherkins with cloudy brine and a bulging lid; a small cardboard tray of "
     "dumpling slices gone hard and cracked; a beer keg with a chalk cross on it and a dusty flat top."),
    ("bzs_chalk", "16:9", "assets/textury/camp/ceiling_board.png", THINGS.format(view="straight on from the front", n=4) +
     "a single long rough horizontal stroke of white chalk, slightly wavy, as if a word was crossed out on a "
     "blackboard; a rough chalk X; a short rough chalk underline; a rough chalk tick mark. White chalk only, dusty "
     "and broken, on nothing."),
]


# The gear a place buys (the only progression, DESIGN.md §7b), seen in the room once in.
REF_BT = "assets/textury/redneck/RRTX0020.png"
GEAR = [
    ("bzg_bistro", "16:9", REF_ROOM, THINGS.format(view="as the description says", n=4) +
     "a heavy black cast-iron frying pan seen straight down from above, empty, oily; a big dented steel stock pot "
     "full of dark red goulash seen straight down from above; a red heat lamp in a dented steel hood seen from the "
     "front; a round white kitchen wall clock with paper order slips tucked into its rim seen from the front."),
    ("bzg_washer", "16:9", REF_BT, "Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, "
     "Blood, Redneck Rampage): a digitized photograph crudely retouched by hand by a 1996 game artist, flat even "
     "lighting, chunky pixels, a limited muddy palette, low saturation, slightly grimy, hard edges, no readable text, "
     "no logos, no people. A flat orthographic straight-on front view, no perspective, filling the whole 16:9 canvas "
     "edge to edge: the front of a 1980s Czechoslovak stainless steel industrial dishwasher, a lift-up hood with a "
     "small dark window, two chunky dials and a red lamp, a drip-stained front panel."),
    ("bzg_pub", "16:9", REF_ROOM, THINGS.format(view="straight on from the front", n=4) +
     "a second chrome beer tap tower with one black handle and a curved spout; a brass keg coupler with a short "
     "black hose; a squat white glass-washing machine with a round porthole; a grey metal keg cooler box with frost "
     "on its lid."),
    ("bzg_corn", "16:9", REF_ROOM, THINGS.format(view="as the description says", n=3) +
     "a big dented aluminium pot of boiling water with corn cobs in it seen straight down from above; a small "
     "enamel pan of melted yellow butter with a pastry brush seen straight down from above; a rough wooden husking "
     "table top with corn husks on it seen straight down from above."),
    ("bzg_jednota", "16:9", REF_ROOM, THINGS.format(view="straight on from the front", n=4) +
     "a second grey mechanical cash register with a crank handle; a red manual pallet truck with its long handle; "
     "a tall glass-fronted chiller cabinet with milk bags and salami inside; a grey metal shop shelf unit stacked "
     "with tins and jars."),
]


def main():
    rows = []
    for slug, ref, who, tool in HANDS:
        rows.append(("bzh_" + slug, "16:9", ref, STAFF.format(who=who, tool=tool)))
    for pid, ref, who in PHOTOS:
        rows.append((pid, "3:4", ref, PHOTO.format(who=who)))
    for pid, ref, text in DRIFT:
        rows.append((pid, "3:4", ref, text + " " + PHOTO.format(who="")))
    rows += GOODS_OFF
    rows += GEAR
    path = os.path.join(HERE, "prompts_biz.tsv")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for r in rows:
            f.write("\t".join(r) + "\n")
    print("wrote", path, len(rows), "rows")


if __name__ == "__main__":
    main()
