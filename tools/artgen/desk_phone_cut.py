#!/usr/bin/env python3
"""The office telephone cut out of its close-up (godot/assets/textury/closeup/phone.png,
the push-button set on its own dark desk) for the title's co-op page, which lays it on
the counter (scripts/ui/title/page_phone.gd):

    python tools/artgen/desk_phone_cut.py

-> godot/assets/textury/desk/phone.png: the set, its handset and its coiled cord, the
   desk round it transparent (the set's outline drawn round it by hand, the cord's coils
   kept by their light), cropped to the set. The keys'
   and the LCD's places in it are the close-up's less CROP (page_phone.gd).
"""
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "..", "godot", "assets", "textury")
SRC = os.path.join(TEX, "closeup", "phone.png")
OUT = os.path.join(TEX, "desk", "phone.png")
# (x0, y0, x1, y1) of the close-up kept: the set with its cord (which runs off the
# picture's foot: the page lays the cut's foot on the counter's).
CROP = (4, 12, 270, 240)
# The set's outline in the close-up (handset, cradle, base in its perspective).
BODY = [(40, 44), (46, 35), (60, 31), (232, 15), (246, 22), (250, 32), (268, 165), (268, 182),
        (262, 190), (100, 213), (80, 214), (66, 206), (58, 196), (48, 180), (42, 160), (40, 100)]
# Where its coiled cord lies (the grey coils in it are kept, the wood between them not).
CORD = [(4, 128), (52, 126), (62, 150), (58, 176), (104, 188), (104, 224), (84, 240), (4, 240)]


def poly_mask(points, shape):
    m = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return np.asarray(m) > 0


def main():
    img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    r, b = img[..., 0], img[..., 2]
    lum = 0.299 * r + 0.587 * img[..., 1] + 0.114 * b
    mx = img.max(axis=2)
    sat = (mx - img.min(axis=2)) / np.maximum(mx, 1.0)
    wood = (sat > 0.34) & (r - b > 26)
    body = poly_mask(BODY, lum.shape)
    # The outline's last pixels: wood that the polygon took in is left out.
    rim = body & ~ndimage.binary_erosion(body, iterations=3)
    body &= ~(rim & (wood | (lum < 40)))
    # The coils are lit plastic (the wood under them is dark): their lit tops, then the
    # shaded rims round them.
    in_cord = poly_mask(CORD, lum.shape)
    cord = in_cord & (lum > 88)
    cord |= ndimage.binary_dilation(cord, iterations=1) & in_cord & (lum > 52)
    lab, n = ndimage.label(cord)
    if n:
        sizes = ndimage.sum(cord, lab, range(1, n + 1))
        cord = np.isin(lab, [i + 1 for i in range(n) if sizes[i] >= 6])
    obj = body | cord
    rgba = np.dstack([img, obj.astype(np.float32) * 255.0]).astype(np.uint8)
    x0, y0, x1, y1 = CROP
    Image.fromarray(rgba[y0:y1, x0:x1], "RGBA").save(OUT)
    print(OUT, (x1 - x0, y1 - y0))


if __name__ == "__main__":
    main()
