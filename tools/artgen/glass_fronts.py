#!/usr/bin/env python3
"""The businesses' faces with real windows (TODO "BUSINESS WINDOWS", DESIGN §7b).

    python tools/artgen/glass_fronts.py pub

A face picture (Grok, assets/textury/camp/) painted its windows; the building now has the
room behind them (one plan: scripts/pub/pub_layout.gd), so the panes go: the picture is
padded with its own plaster to the house's new width at the pixels a metre it had (no
stretching), a window may be moved to where the room has one, and its glass is cut out
(alpha 0; the painted frames, the mullions and the curtains' coloured hems kept). Writes
<name>_glass.png beside the picture and prints each pane in the house's own space
(metres: the picture's middle at the house's middle, its bottom at BASE).
"""
import colorsys
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CAMP = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "camp")


def pad(im, left, right, strip):
    """`im` wider by `left` and `right` columns of plain wall: the strip (x0, x1) of it
    where nothing stands, laid side by side, every other one turned round."""
    w, h = im.size
    band = im.crop((strip[0], 0, strip[1] + 1, h))
    flip = band.transpose(Image.FLIP_LEFT_RIGHT)
    out = Image.new("RGBA", (w + left + right, h))
    out.paste(im, (left, 0))
    for x0, n in ((0, left), (left + w, right)):
        x = 0
        k = 0
        while x < n:
            piece = (band if k % 2 == 0 else flip).crop((0, 0, min(band.width, n - x), h))
            out.paste(piece, (x0 + x, 0))
            x += piece.width
            k += 1
    return out


def cut(im, rect, keep_cols=(), keep_saturated=False):
    """The glass inside `rect` (x0, y0, x1, y1 inclusive) made clear; columns in
    `keep_cols` (a mullion) and, with `keep_saturated`, strongly coloured pixels (a
    curtain's hem) stay."""
    px = im.load()
    x0, y0, x1, y1 = rect
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if x in keep_cols:
                continue
            r, g, b, a = px[x, y]
            if keep_saturated:
                _h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                if s > 0.45 and v > 0.3:
                    continue
            px[x, y] = (r, g, b, 0)


def panes_in_metres(rects, size_px, size_m, base):
    """Each (x0, y0, x1, y1) pane as {centre [u, y], size [w, h]} in metres: u across the
    face from its middle (left to right as you look at it), y up from the ground."""
    w_px, h_px = size_px
    w_m, h_m = size_m
    out = []
    for x0, y0, x1, y1 in rects:
        a = (x0 / w_px - 0.5) * w_m
        b = ((x1 + 1) / w_px - 0.5) * w_m
        top = base + (1.0 - y0 / h_px) * h_m
        bot = base + (1.0 - (y1 + 1) / h_px) * h_m
        out.append({"centre": [round((a + b) * 0.5, 3), round((top + bot) * 0.5, 3)], "size": [round(b - a, 3), round(top - bot, 3)]})
    return out


def pub():
    # The house: 6.0 x 4.8 m (PUB_LAYOUT.SIZE and its 0.1 walls), the faces 3.1 m from 0.1 up.
    front = Image.open(os.path.join(CAMP, "camp_pub_front.png")).convert("RGBA")
    # 224 px were 4.96 m: 271 px for 6.0 m, with the plaster between the two windows.
    front = pad(front, 23, 24, (150, 164))
    # The panes (the lace and the room painted in them), the mullions kept; the geraniums
    # over the sills stay.
    panes = []
    for gx0, gx1, m0 in ((112, 141, 125), (174, 203, 187)):
        r = (gx0 + 23, 27, gx1 + 23, 64)
        cut(front, r, keep_cols=tuple(range(m0 + 23, m0 + 27)))
        panes.append(r)
    front.save(os.path.join(CAMP, "camp_pub_front_glass.png"))
    side = Image.open(os.path.join(CAMP, "camp_pub_side.png")).convert("RGBA")
    # The barred window (its frame x 16-48, y 26-60, the sill to y 64) from the back to the
    # middle of the wall over the crates, where the room's window is (PUB_LAYOUT: z 0.05
    # in front of the room's middle); plaster cloned where it was.
    win = side.crop((13, 24, 52, 67))
    side.paste(side.crop((112, 2, 151, 51)), (13, 24))
    # 192 px were 4.0 m: 230 px for 4.8 m. The window's middle 0.05 m in front of the
    # house's middle: 0.5 + 0.05 / 4.8 across.
    side = pad(side, 19, 19, (53, 63))
    mid = int(round((0.5 + 0.05 / 4.8) * side.width))
    x0 = mid - win.width // 2
    side.alpha_composite(win, (x0, 24))
    glass = (x0 + 6, 29, x0 + 32, 58)
    cut(side, glass)
    # Its bars (the picture's, x 23, 28, 33, 38, 43 and y 37): in metres across the face.
    bars = [round((x0 + bx - 13 + 0.5) / side.width * 4.8 - 2.4, 3) for bx in (23, 28, 33, 38, 43)]
    side.save(os.path.join(CAMP, "camp_pub_side_glass.png"))
    print(json.dumps({
        "front": panes_in_metres(panes, front.size, (6.0, 3.1), 0.1),
        "side": panes_in_metres([glass], side.size, (4.8, 3.1), 0.1),
        "side_bars_u": bars, "side_bar_y": round(0.1 + (1.0 - 37.5 / side.height) * 3.1, 3),
        "front_px": front.size, "side_px": side.size}, indent=1))


def bistro():
    # The house: the dining room (BISTRO_LAYOUT.SIZE 6.2 x 4.8 and 0.1 walls) 6.4 m wide,
    # the face 2.9 m from 0.1 up: the picture (224 px for the old 5.76 m) laid over it as it
    # is, a little wider. Its four panes, the transom bar, the cafe lace across them and the
    # menu card in the second kept.
    front = Image.open(os.path.join(CAMP, "camp_bistro_front.png")).convert("RGBA")
    panes = [(5, 29, 47, 91), (53, 29, 92, 91), (131, 29, 170, 91), (176, 29, 218, 91)]
    for x0, y0, x1, y1 in panes:
        for band in ((y0, 40), (44, 63), (84, y1)):
            cut(front, (x0, band[0], x1, band[1]))
    # The menu card in the second pane back as it was.
    card = Image.open(os.path.join(CAMP, "camp_bistro_front.png")).convert("RGBA").crop((59, 45, 84, 61))
    front.paste(card, (59, 45))
    front.save(os.path.join(CAMP, "camp_bistro_front_glass.png"))
    print(json.dumps({"front": panes_in_metres(panes, front.size, (6.4, 2.9), 0.1)}, indent=1))


def jednota():
    # The house: the shop (JEDNOTA_LAYOUT.SIZE 6.4 x 5.2 and 0.1 walls) 6.6 m wide, the face
    # 3.4 m from 0.1 up: the picture (256 px for the old 7.2 m) laid over it as it is. Its
    # four shop windows cut (the goods painted in them give way to the shop's own racks);
    # the door stays.
    front = Image.open(os.path.join(CAMP, "jednota_front.png")).convert("RGBA")
    panes = [(19, 40, 59, 103), (63, 40, 102, 103), (154, 40, 193, 103), (199, 40, 237, 103)]
    for r in panes:
        cut(front, r)
    front.save(os.path.join(CAMP, "jednota_front_glass.png"))
    print(json.dumps({"front": panes_in_metres(panes, front.size, (6.6, 3.4), 0.1)}, indent=1))


if __name__ == "__main__":
    {"pub": pub, "bistro": bistro, "jednota": jednota}[sys.argv[1]]()
