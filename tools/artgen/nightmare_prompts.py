#!/usr/bin/env python3
"""Writes tools/artgen/prompts_nightmare.tsv: the worst pictures of the Photographer and the
Silent Man (the user, 21. 10.: "like the Girl, almost over the line: morbid, brutal,
inhuman, nightmare fuel, evil made flesh, cursed"). Body horror, no sex.

    python tools/artgen/nightmare_prompts.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PH = "assets/textury/npc/tourist_idle.png"
SM = "assets/textury/npc/sm2_face.png"
SM_BODY = "assets/textury/npc/sm2_m1.png"

STYLE = ("Pixel-art in exactly the same style as the reference image: same pixel size, same palette, same shading, "
         "chunky pixels, a found 1990s horror game, grim and cursed, harsh flat flash light from the front so the "
         "edges fall to black. Background must be flat solid pure magenta #FF00FF everywhere around the figure, no "
         "text, no border, no watermark. ")
PH_MAN = ("It is the SAME man as in the reference: a chubby sunburnt tourist in a green and white trucker cap, black "
          "sunglasses, a beige t-shirt with a green mountain and red sun on it, an old black film camera on a strap. ")
SM_MAN = ("It is the SAME man as in the reference: a thin quiet man in a khaki bucket hat and round wire glasses, "
          "where his mouth should be only smooth stitched skin, a khaki short-sleeved shirt. ")

ROWS = [
    # The Photographer
    ("ph_face_lens", "1:1", PH, STYLE + PH_MAN + "An extreme close-up of his face filling the whole square, right "
     "against the viewer: the sunglasses pushed down his nose, and where his eyes should be two camera lenses have "
     "grown into the sockets, glass irises ringed with raw red flesh and dripping, the sunburnt skin peeling off in "
     "grey wet sheets, a grin stretched far too wide with receding bleeding gums and too many small crowded teeth."),
    ("ph_face_peel", "1:1", PH, STYLE + PH_MAN + "An extreme close-up of his face filling the whole square: the face is "
     "peeling off downward like the emulsion of a wet instant photo, a flap of skin hanging from his chin, underneath "
     "raw glistening red with rows of tiny teeth where no teeth should be, the sunglasses hanging from one ear, the "
     "cap still on, one lens-eye staring."),
    ("ph_neck", "1:2", PH, STYLE + PH_MAN + "Full body, front view, feet at the bottom edge: the camera strap pulled so "
     "tight round his neck it has cut in, his head hanging sideways at a broken angle on a neck much too long, yet "
     "he still holds the camera up to the viewer with both hands, the flash glowing, the grin upside-down."),
    ("ph_run", "1:2", PH, STYLE + PH_MAN + "Full body, front view, feet at the bottom edge: sprinting straight at the "
     "viewer in an inhuman lurch, knees bent wrong, the camera held out at arm's length towards the viewer, the "
     "flash firing, his mouth torn open in a laugh, the sunglasses gone and the eyes two lenses."),
    ("ph_polaroid_frame", "3:4", "-", "A single blank white instant camera photo lying flat, seen straight on, "
     "filling the canvas: a thick off-white border, wider at the bottom, the image square in it plain dark grey, "
     "a thumbprint smudged in dried brown on the border, slightly bent, 1990s, photographic, no text, no watermark."),
    # The Silent Man
    ("sm_face_cross", "1:1", SM, STYLE + SM_MAN + "An extreme close-up of his face filling the whole square: the "
     "stitched skin over his mouth has split open in a cross, four flaps of skin peeled back like a flower, inside a "
     "throat lined with rings of small yellow teeth going down into the dark, threads of drool, the round glasses "
     "cracked, his eyes wide and calm."),
    ("sm_face_second", "1:1", SM, STYLE + SM_MAN + "An extreme close-up of his face filling the whole square: the skin "
     "where his mouth should be is torn wide open in a ragged hole, and out of that hole a SECOND COMPLETE HUMAN FACE is "
     "pushing out, a smaller pale bald face with its own two eyes squeezed shut, its own nose and its own mouth wide "
     "open screaming, slick with fluid, stretching his skin around it like a birth; above it his own eyes behind the "
     "round glasses stay calm and look at the viewer."),
    ("sm_neck_long", "9:16", SM_BODY, STYLE + SM_MAN + "Full body, side-on, feet at the bottom edge: he stands behind "
     "the edge of a dark corner and only his neck comes round it, stretched impossibly long and thin, bending like a "
     "hose, the head with the bucket hat and glasses at the end of it, tilted, peering, the stitched mouth pulling."),
    ("sm_ceiling", "1:1", SM_BODY, STYLE + SM_MAN + "Seen from below: he clings flat to a dark ceiling corner on all "
     "fours, limbs bent backwards like a spider's, his head turned all the way round to face down at the viewer, the "
     "glasses catching the light, the stitched mouth torn at one corner, a thread of drool hanging down."),
    ("sm_hands_eyes", "1:1", SM_BODY, STYLE + "An extreme close-up from the viewer's own eyes: two thin grey hands "
     "with long cracked nails come in from both sides and press their thumbs over the viewer's eyes, blood under the "
     "nails, the khaki sleeves, his glasses and the top of his bucket hat just visible behind, very close."),
]


def main():
    out = os.path.join(HERE, "prompts_nightmare.tsv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for r in ROWS:
            assert "\t" not in "".join(r)
            f.write("\t".join(r) + "\n")
    print(len(ROWS), "rows ->", out)


if __name__ == "__main__":
    main()
