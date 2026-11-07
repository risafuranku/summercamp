"""The camp lamp's cone of light made soft: Grok's `spr_lamp_beam` kept as lamp_beam_grok.png,
out of it lamp_beam.png.

    python tools/artgen/lamp_beam_soft.py

Grok's picture is a wedge of four flat bands, 48 texels wide. Over a dark meadow it read as a
solid tan pyramid under every lamp, a rocket on the pad from across the camp (7. 11.). Twice
the texels, its bands and its outline blurred, and thinning from the middle to the sides and
down to the ground: light in the air. The picture's own colours; the post pass dithers it.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
CAMP = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "camp")
SRC = os.path.join(HERE, "lamp_beam_grok.png")
DST = os.path.join(CAMP, "lamp_beam.png")
SCALE = 2
BLUR = 7.0


def main() -> None:
    # (Beside this script: in the assets it would be imported with the rest.)
    im = Image.open(SRC).convert("RGBA")
    w, h = im.width * SCALE, im.height * SCALE
    big = im.resize((w, h), Image.NEAREST)
    a = np.asarray(big).astype(np.float32) / 255.0
    lum = a[..., :3].max(axis=2) * a[..., 3]
    soft = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(BLUR))).astype(np.float32) / 255.0
    # Thinner toward the sides of the wedge at each height, and toward the ground.
    ys = (np.arange(h) / float(h - 1))[:, None]
    xs = np.abs(np.arange(w) / float(w - 1) - 0.5)[None, :] * 2.0
    wedge = 0.14 + 0.86 * ys
    side = np.clip(1.0 - (xs / wedge) ** 2, 0.0, 1.0) ** 1.4
    foot = np.clip((1.0 - ys) / 0.35, 0.0, 1.0)
    alpha = soft * side * foot
    # One colour for the light: the picture's brightest, its steps are gone from the alpha.
    keep = a[..., 3] > 0.5
    col = a[keep][:, :3]
    tint = col[col.max(axis=1) >= np.percentile(col.max(axis=1), 75)].mean(axis=0)
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = tint
    out[..., 3] = alpha / max(alpha.max(), 0.001)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(DST)
    print("lamp_beam.png", (w, h), "tint", tint)


if __name__ == "__main__":
    main()
