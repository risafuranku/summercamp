#!/usr/bin/env python3
"""The guests' bowling poses (the camp's bowling alley, scripts/bowling/): rows
<sprite>_bowl and <sprite>_ball for every guest sprite that has its other poses, written
into prompts_kuzelna.tsv from the same person's _kick row in prompts.tsv (the style, the
person's clothes and the closing clause carried over, the action swapped).

    python tools/artgen/bowling_prompts.py
    bash tools/artgen/queue.sh host1_bowl host1_ball ...
    python tools/artgen/process.py host1_bowl sprite 128 assets/textury/npc/host1_bowl.png

On the approach the camera looks down the lanes, so the bowlers are seen from behind.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "prompts.tsv")
DEST = os.path.join(HERE, "prompts_kuzelna.tsv")

ACTIONS = {
    "bowl": ("Now bowling at a ten-pin bowling alley, seen from directly behind, the back of the "
             "person towards the viewer: the moment just after letting go of the ball, the right arm "
             "swung forward and up in the follow-through, the left arm out to the side for balance, the "
             "left knee bent in the slide, the right leg trailing behind across to the left, the body "
             "leaning forward toward the lane; the ball already gone, nothing in the hands."),
    "ball": ("Now at a ten-pin bowling alley, seen from directly behind, the back of the person "
             "towards the viewer: standing still on the approach, a black bowling ball held in front of "
             "the chest in both hands, about to start the run-up, the head turned a little to look "
             "down the lane."),
}
TAIL_BALL = ("The whole figure filling about 90% of the height, the feet touching the bottom edge. "
             "Background must be flat solid pure magenta #FF00FF everywhere around the figure, no "
             "lane, no pins, no ground shadow, no floor, no text, no border, no watermark.")


def main():
    rows = {}
    for line in open(SRC, encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) == 4 and parts[0].endswith("_kick"):
            rows[parts[0][:-5]] = parts
    keep = []
    if os.path.exists(DEST):
        for line in open(DEST, encoding="utf-8"):
            rid = line.split("\t", 1)[0]
            if not re.match(r"^host.*_(bowl|ball)$", rid):
                keep.append(line.rstrip("\n"))
    out = []
    for sprite, (_rid, aspect, ref, prompt) in sorted(rows.items()):
        # The action sentence(s): from "Now " up to the reference's grain clause.
        m = re.search(r"Now .*?(?= Keep exactly the reference)", prompt)
        if not m:
            print("skip (no action sentence)", sprite)
            continue
        for pose, action in ACTIONS.items():
            p = prompt.replace(m.group(0), action)
            if pose == "ball":
                p = re.sub(r"The whole figure filling.*$", TAIL_BALL, p)
            out.append("\t".join(["%s_%s" % (sprite, pose), aspect, ref, p]))
    with open(DEST, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(keep + out) + "\n")
    print("%d rows -> %s" % (len(out), DEST))
    print(" ".join(r.split("\t", 1)[0] for r in out))


if __name__ == "__main__":
    main()
