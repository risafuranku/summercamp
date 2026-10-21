#!/usr/bin/env python3
"""Writes tools/artgen/prompts_staff.tsv: the staffroom (DESIGN.md §7c) and the post's
plate on the HUD: the hut outside and in (a 1970s Czech village prefab, the lounge and
the boiler room behind it), its things, the old chunky laptop, the TV's programmes, the
lockers, the cards in the books, the Builder's sprites, the hands at rest and at work.

    python tools/artgen/staff_prompts.py

gen.sh reads prompts.tsv and every prompts_*.tsv beside it; processed by staff_art.py.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

TEX = ("Seamless tileable texture, flat front view filling the whole square: {what} Low saturation, in the style of "
       "1990s Build-engine game textures (Duke Nukem 3D, Blood, Redneck Rampage), crisp hand-pixelled look, no text, "
       "no border, no watermark, must tile seamlessly on all four edges.")
FACE = ("Pixel-art texture in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, Redneck Rampage): a flat "
        "orthographic straight-on view filling the whole canvas edge to edge with no perspective, no background, no "
        "shadow, chunky pixels, low saturation, slightly grimy, no readable text, no logos, no border, no watermark. {what}")
SPRITE = ("Pixel-art game sprite in the style of 1990s Build-engine games (Duke Nukem 3D, Redneck Rampage): chunky "
          "visible pixels, a limited muted palette, strong simple shading, a single object in the centre, full size. "
          "Background must be flat solid pure magenta #FF00FF everywhere around it, no ground shadow, no floor, no "
          "text, no border, no watermark. {what}")
ISO = ("An isometric building sprite for a late-1990s camp tycoon game in the style of the reference image: 2:1 "
       "isometric pixel art seen from the south-west, the same scale, palette, weathered textures and soft top-left "
       "light as the reference, a small dark shadow on the ground under it. The object stands alone on a flat pure "
       "magenta (#FF00FF) background, no ground tile, no text, no border. The object: {what}")
HUT = ("a small single-storey 1970s Czechoslovak prefab staff hut at a holiday camp, about eight metres wide: rough "
       "grey-beige dash plaster walls with damp stains, a flat roof of black tar paper with a thin tin edge, a brown "
       "plywood front door in the middle of the long front with a small white enamel plate on it (no letters), two "
       "windows with white wooden frames and yellowed net curtains either side of the door, a lower boiler-room "
       "annex at the right end with a dirty steel door, a small high window and a square brick chimney, a heap of "
       "black coal by the annex, a mop bucket and a crate of empty beer bottles by the front door.")

ROWS = [
    # Outside.
    ("tex_staff_plaster", "1:1", "-", TEX.format(what="the outside wall of a 1970s Czech village prefab hut, rough "
     "grey-beige dash plaster (brizolit) with a coarse pebbly grain, faint damp stains and a few hairline cracks, "
     "even all over.")),
    ("tex_staff_tarpaper", "1:1", "-", TEX.format(what="a flat roof seen from above covered with black bitumen tar "
     "paper in long overlapping strips, sun-faded grey-black, a few blisters, a darker patch nailed over a tear, "
     "grit and pine needles in the seams.")),
    ("tex_staff_plinth", "1:1", "-", TEX.format(what="the plinth of a Czech village building: grey rough cement "
     "render splashed with dried mud, a little moss, darker and damp at the bottom.")),
    ("face_staff_door", "9:16", "-", FACE.format(what="The front door of a 1970s Czechoslovak prefab staff hut, the "
     "door alone filling the canvas: a brown varnished plywood door gone dull, a small window of wired glass in its "
     "top quarter, a bent aluminium lever handle and a keyhole, a small blank white enamel plate screwed above the "
     "window, kick marks and dirt along the bottom, a strip of a torn sticker.")),
    ("face_staff_steel_door", "9:16", "-", FACE.format(what="The steel door of a boiler room in a Czech village "
     "building, the door alone filling the canvas: dark grey painted sheet steel, rust bleeding from the rivets and "
     "along the bottom, a heavy lever handle, a yellow and black hazard triangle with a lightning bolt (no letters), "
     "soot round the top edge.")),
    ("iso_staffroom", "1:1", "assets/textury/builder/chata1.PNG", ISO.format(what=HUT)),
    # The lounge.
    ("tex_staff_wall_in", "1:1", "-", TEX.format(what="the wall of a staff room in a 1980s Czech holiday camp: the "
     "lower half glossy ochre-brown oil paint, a thin dark red line across it at exactly half the height, the upper "
     "half pale blue limewash, scuffed and grimy along the line, a few chips in the oil paint.")),
    ("tex_staff_lino", "1:1", "-", TEX.format(what="a floor of brown and beige patterned PVC linoleum from 1980s "
     "Czechoslovakia seen from above, a small geometric pattern of squares, worn grey paths, cigarette burns, a few "
     "black heel marks.")),
    ("tex_sofa_cord", "1:1", "-", TEX.format(what="worn rust-brown ribbed corduroy upholstery fabric of a 1970s "
     "sofa, the ribs vertical, shiny worn patches, a few dark stains.")),
    ("tex_formica", "1:1", "-", TEX.format(what="the top of an old kitchen table: pale yellow-grey formica with a "
     "faint speckled pattern, coffee cup rings, knife scratches and a cigarette burn.")),
    ("face_staff_fridge", "9:16", "-", FACE.format(what="The front of a small old cream-white 1970s Czechoslovak "
     "refrigerator (Calex) standing on the floor, the fridge alone filling the canvas: rounded corners, a chrome "
     "lever handle, a small freezer door line near the top, yellowed enamel, faded stickers of fruit and a cartoon "
     "bear, a magnet holding a curled paper note, rust along the bottom edge.")),
    ("spr_coffee_maker", "1:1", "-", SPRITE.format(what="A cheap 1990s drip filter coffee machine, cream plastic gone "
     "yellow, a glass jug half full of black coffee on the hot plate, a small orange power switch glowing, coffee "
     "stains down the side, seen from the front.")),
    ("face_staff_tv", "4:3", "-", FACE.format(what="The front of an old 1980s Czechoslovak television set (Tesla), "
     "the set alone filling the canvas: a walnut-veneer wooden cabinet, a rounded grey screen switched off on the "
     "left two thirds, on the right a column of chrome push buttons, two knobs and a speaker grille, dust on the "
     "top edge, a crocheted doily hanging over the top.")),
    ("face_tvshow_testcard", "4:3", "-", FACE.format(what="The Czechoslovak television test card of the 1980s as "
     "seen on an old TV screen, filling the canvas: a big circle with a grid, grey steps, black and white bars and "
     "colour bars, a soft glow, scan lines and a little snow, slightly bent at the edges. No readable letters.")),
    ("face_tvshow_forest", "4:3", "-", FACE.format(what="A late-night 1990s Czech TV picture as seen on an old TV "
     "screen, filling the canvas: a dark spruce forest at night lit by a single lamp, fog between the trunks, far "
     "back between the trees something pale stands that might be a person, grainy, scan lines, a little snow. No "
     "readable letters.")),
    ("face_tvshow_weather", "4:3", "-", FACE.format(what="A 1990s Czech TV weather forecast as seen on an old TV "
     "screen, filling the canvas: a flat blue map of Czechoslovakia with a white outline, small yellow sun and grey "
     "cloud symbols with rain lines over it, a thin blue bar at the bottom, scan lines, a little snow. No readable "
     "letters or numbers.")),
    ("face_bozp_poster", "3:4", "-", FACE.format(what="A faded 1980s Czechoslovak workplace safety poster pinned to a "
     "wall, filling the canvas: a drawn worker in a white helmet and blue overalls pointing at a ladder and a bucket, "
     "red and yellow blocks of colour, a big red exclamation mark, yellowed paper, torn corners, rusty pins. No "
     "readable letters.")),
    # The laptop.
    ("face_laptop_keys", "4:3", "-", FACE.format(what="The keyboard half of a chunky dark grey 1990s notebook computer "
     "seen straight from above, filling the canvas: a full keyboard of worn grey keys with shiny tops, a small round "
     "trackball and two buttons in the middle below it, a row of little status lights, scratches and a coffee ring. "
     "No readable letters on the keys.")),
    ("face_laptop_lid", "4:3", "-", FACE.format(what="The back of the lid of a chunky dark grey 1990s notebook "
     "computer, filling the canvas: textured grey plastic, a small square maker's badge (no letters), a peeling "
     "inventory sticker with a barcode, scratches and a dent.")),
    ("cu_laptop", "16:9", "-", "Pixel-art scene in the style of 1990s Build-engine games (Duke Nukem 3D, Blood, "
     "Redneck Rampage), chunky pixels, a limited muted palette, grimy, seen from a person sitting at a table: a chunky "
     "dark grey 1990s notebook computer open on a pale formica table, filling most of the picture, its screen a flat "
     "solid pure magenta #FF00FF rectangle (exactly flat magenta, nothing on it) in a thick grey bezel at the top "
     "middle, below it the keyboard of worn grey keys with a round trackball, a tangle of a power cable. Beside it on "
     "the table a chipped mug of coffee on the left, a crumpled pack of cigarettes and a full glass ashtray on the "
     "right, a ring binder. The edges of the picture are the dim room. No readable text, no logos, no border, no "
     "watermark."),
    # The boiler room.
    ("tex_kotelna_wall", "1:1", "-", TEX.format(what="a boiler room wall in a Czech village building: rough "
     "whitewashed brick, blackened with coal soot towards the top, damp grey patches, flaking lime.")),
    ("tex_kotelna_floor", "1:1", "-", TEX.format(what="the cracked concrete floor of a boiler room seen from above, "
     "coal dust and black smudges, a dark oil stain, grit.")),
    ("face_kotel", "3:4", "-", FACE.format(what="A big old cast-iron coal boiler from 1970s Czechoslovakia "
     "(Viadrus), the boiler alone filling the canvas: dark green enamel side panels, two cast-iron doors with latches "
     "on the front, a round pressure gauge and a thermometer on the top, a thick flue pipe going up, soot round the "
     "doors, a faint orange glow through a crack of the lower door.")),
    ("face_locker", "9:16", "-", FACE.format(what="A tall narrow grey-green steel staff locker from a 1980s Czech "
     "factory changing room, the locker door alone filling the canvas: louvred vents at the top and the bottom, a "
     "lever handle with a padlock loop, dents, a strip of masking tape for a name with nothing written on it, "
     "scratches.")),
    ("face_locker_open", "9:16", "-", FACE.format(what="Inside an open tall narrow grey-green steel staff locker, "
     "filling the canvas: a blue work coat hanging on a hook, a pair of black rubber boots at the bottom, a dented "
     "thermos and a folded newspaper on the little top shelf, a photo of a woman taped inside, rust in the "
     "corners.")),
    ("tex_mattress_stain", "1:1", "-", TEX.format(what="an old mattress seen from above, blue and white striped "
     "ticking, big yellow-brown stains, a cigarette burn, worn grey in the middle.")),
    ("spr_coal_pile", "1:1", "-", SPRITE.format(what="A heap of black coal lumps on the floor with a coal shovel "
     "stuck in it, a little coal dust round it, seen from the front.")),
    # The books' cards (pictures glued in, a catalogue cut-out each).
    ("card_locker", "3:4", "-", SPRITE.format(what="A small picture cut out of a 1980s Czechoslovak furniture "
     "catalogue: a tall grey-green steel locker, standing, printed in faded colours on yellowed paper with cut edges "
     "and a little glue at the corners.")),
    ("card_mattress", "4:3", "-", SPRITE.format(what="A small picture cut out of a 1980s Czechoslovak furniture "
     "catalogue: a rolled-out striped mattress lying on the floor with a grey wool blanket folded on it, printed in "
     "faded colours on yellowed paper with cut edges and a little glue at the corners.")),
    # The post's plate on the HUD.
    ("spr_hud_post", "4:3", "-", SPRITE.format(what="A small yellow 1990s Czech Post van (Skoda 1203) seen exactly "
     "from the side, driving to the right: a boxy yellow body, a thin blue stripe, a round headlight, black tyres, "
     "windows dark.")),
    ("spr_hud_parcel", "1:1", "-", SPRITE.format(what="A small brown paper parcel tied with string, a white label "
     "on it (no letters), seen from the front at a slight angle.")),
    # The hands' armchairs in the lounge (instead of a bed: the mattress is the warden's).
    ("card_armchair", "4:3", "-", SPRITE.format(what="A small picture cut out of a 1980s Czechoslovak furniture "
     "catalogue: a boxy 1970s armchair with wooden armrests and mustard-green woven upholstery, printed in faded "
     "colours on yellowed paper with cut edges and a little glue at the corners.")),
    ("tex_armchair", "1:1", "-", TEX.format(what="worn mustard-green woven upholstery fabric of a 1970s Czech "
     "armchair, a small check pattern, bobbles, a dark greasy patch.")),
    # Personal 98's icon (SoftSklad's fifth program), beside the others'.
    ("spr_icon_staff", "1:1", "-", SPRITE.format(what="A tiny 32x32 Windows 95 style desktop icon: a grey steel "
     "locker with a broom leaning on it and a little white name badge in front.")),
]

# The hands at rest and at work (business_rules.PEOPLE that ask at the staffroom): three
# figures of the same person on one sheet, the reference their own standing sprite.
POSES = ("Pixel-art game character sprites in exactly the same style as the reference image: the same pixel size, "
         "the same palette and shading, the same rough grain, noise and dither, sallow slightly wrong skin tones and "
         "stiff, vacant, unsettling faces. Three figures of the SAME person as the reference, in the SAME clothes, "
         "side by side on one sheet with wide gaps of background between them so they do not touch, all at exactly "
         "the same scale. LEFT: sitting on a low sofa that is NOT drawn, seen from the front, the knees forward, "
         "the hands in the lap, the head tipped back, eyes half shut. MIDDLE: lying flat on the back asleep on a "
         "mattress that is NOT drawn, seen exactly from the side, the head to the left, the arms along the body. "
         "RIGHT: sweeping the floor with a long broom, seen from the side facing right, bent forward a little. The "
         "person: {who} Something about this person is subtly off. No smile, not cheerful, not clean or cartoonish. "
         "The background must be flat solid pure magenta #FF00FF everywhere around the figures, no sofa, no mattress, "
         "no floor, no ground shadow, no text, no border, no watermark.")
HANDS = [
    ("dvorakova", "a heavy woman of about sixty with wavy grey hair, a cream blouse under a white smock with old "
     "brown stains, a white apron, thick flesh-coloured stockings, worn brown slip-on shoes."),
    ("hanka", "a thin young woman of about twenty-five with long straight brown hair parted in the middle, dark rings "
     "under her eyes, a white blouse with the sleeves rolled up, a short black apron, a dark knee-length skirt, flat "
     "black shoes."),
    ("zdenka", "a woman of about forty with short dark hair and a tired grey face, a dark grey cardigan over a light "
     "blouse, a faded blue nylon smock over it, a dark skirt, flat brown shoes."),
    ("ivan", "a gaunt man of about thirty with long dark greasy hair, a hollow face, a brown warehouse coat worn open "
     "over a black t-shirt, grey work trousers, heavy black boots."),
    ("mirek", "a thin young man of about twenty with short bleached hair, a black t-shirt, a black apron, black "
     "jeans, scuffed black shoes."),
    ("marta", "a woman of about forty with smooth dark hair pinned up, a pale face with very still eyes, a pale green "
     "1970s nylon uniform dress with a white collar, a white apron, white nurse's shoes."),
    ("jaromir", "a thin pale man of indeterminate age with neatly combed dark hair parted on the side, an "
     "old-fashioned brown suit too tight at the shoulders, a spotless white apron over it, polished black shoes."),
]


def main():
    lines = []
    for rid, aspect, ref, prompt in ROWS:
        lines.append("\t".join([rid, aspect, ref, prompt]))
    for slug, who in HANDS:
        lines.append("\t".join(["stp_" + slug, "16:9", "assets/textury/npc/staff/%s.png" % slug, POSES.format(who=who)]))
    with open(os.path.join(HERE, "prompts_staff.tsv"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(len(lines), "rows")


if __name__ == "__main__":
    main()
