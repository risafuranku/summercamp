#!/usr/bin/env python3
"""Writes tools/artgen/prompts_photographer.tsv: the Photographer's poses (the night's
Tourist, scripts/enemies/tourist_brain.gd), all of the same man as the
guest he came with (npc/host2.png: the cap, the sunglasses), never drifting.

    python tools/artgen/photographer_prompts.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REF = "assets/textury/npc/host2.png"
BASE = ("Pixel-art game character sprite in exactly the same style as the reference image: same pixel size, same "
        "palette, same shading, full body, feet touching the bottom edge, character centred and filling about 90% of "
        "the height. It is EXACTLY the same man as in the reference, every piece of him unchanged: a chubby "
        "sunburnt middle-aged tourist, a green and white trucker cap, black sunglasses, a beige t-shirt with a green "
        "mountain and a red sun printed on it, a black film camera on a strap round his neck, a rolled green "
        "sleeping mat under his arm, a red and black checked flannel shirt tied round his waist, frayed denim shorts, "
        "white socks, brown hiking boots. Keep the cap and the sunglasses in every picture. Something is deeply "
        "wrong with him in a quiet way, like a found 1990s horror game: his smile is much too wide with too many small "
        "teeth, the sunburn has gone grey and peeling in patches. Background must be flat solid pure magenta #FF00FF "
        "everywhere around him, no ground shadow, no floor, no text, no border, no watermark. ")

ROWS = [
    ("tourist_idle", "1:2", REF, BASE + "Front view, standing still and too straight, the camera held at his chest in both hands, "
     "staring at the viewer through the sunglasses, the wide smile."),
    ("tourist_walk_a", "1:2", REF, BASE + "Front view, walking towards the viewer mid-stride, left foot forward, the camera hanging on its "
     "strap at his belly, both hands on it, his face visible: the sunglasses, a smile much too wide with too many small teeth."),
    ("tourist_walk_b", "1:2", REF, BASE + "Front view, walking towards the viewer mid-stride, right foot forward, the camera hanging on its "
     "strap at his belly, both hands on it, his face visible: the sunglasses, a smile much too wide with too many small teeth."),
    ("tourist_aim", "1:2", REF, BASE + "Front view, standing still, holding the camera up with both hands so it covers his eyes, "
     "the big round lens pointed straight at the viewer, a small red focus lamp on the front of the camera, his wide "
     "smile under it, leaning forward a little, too eager."),
    ("tourist_flash", "1:2", REF, BASE + "Front view, the camera up at his eyes and the flash firing: a burst of hard white light from "
     "the flash bulb, his body lit flat white from the front with black shadows behind, the smile showing every tooth."),
    ("tourist_wave", "1:2", REF, BASE + "Front view, standing still after taking a picture, the camera lowered on its strap, one hand "
     "raised waving slowly at the viewer, a white instant photo held in the other hand, head tilted, the too-wide "
     "smile, the sunglasses fixed on the viewer."),
    ("tourist_glass", "1:2", REF, BASE + "Front view seen through a window from inside a dark room at night: his face pressed close, "
     "the camera held up against the glass with both hands, the lens touching the glass, nose flattened, the "
     "smile wide, only his upper body from the waist up filling the frame."),
    ("tourist_back", "1:2", REF, BASE + "Back view, walking away, the rucksack on his back with dozens of white instant photos "
     "pinned all over it, the rope, the boots."),
]


def main():
    out = os.path.join(HERE, "prompts_photographer.tsv")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        for row in ROWS:
            f.write("\t".join(row) + "\n")
    print(len(ROWS), "rows ->", out)


if __name__ == "__main__":
    main()
