"""A ground texture from a Grok render that must tile (agent B, 20. 10.): Grok's "seamless"
is a wish, so the seams are made here.

    python tools/artgen/ground_tex.py <id> <dest relative to godot/> [size] [--own]

The render is centre-cropped square and brought to twice the size (a box filter), laid
over a copy of itself moved half its size each way (the copy's edges were the render's
middle, so they meet), the copy showing at the edges and the render in the middle, then
brought to `size` and snapped to the game's palette (process.py); with --own to 48 colours
of its own instead (the palette has few mid greens: the summer meadow came out brown; the
screen's palette pass dithers them in from its own colours).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402

GODOT = os.path.join(HERE, "..", "..", "godot")


def tileable(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    h, w = a.shape[:2]
    moved = np.roll(a, (h // 2, w // 2), axis=(0, 1))
    # 1 in the middle, 0 at the edges: the render where its own middle is, the moved copy
    # (whose edges meet) at the edges.
    y = 1.0 - np.abs(np.linspace(-1.0, 1.0, h))
    x = 1.0 - np.abs(np.linspace(-1.0, 1.0, w))
    m = np.clip(np.minimum.outer(y, x) * 2.2, 0.0, 1.0)[..., None]
    return Image.fromarray((a * m + moved * (1.0 - m)).clip(0, 255).astype(np.uint8))


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    art_id, dest = args[0], args[1]
    size = int(args[2]) if len(args) > 2 else 128
    img = Image.open(os.path.join(HERE, "out", art_id, "raw.png")).convert("RGB")
    s = min(img.size)
    img = img.crop(((img.width - s) // 2, (img.height - s) // 2, (img.width - s) // 2 + s, (img.height - s) // 2 + s))
    img = tileable(img.resize((size * 2, size * 2), Image.Resampling.BOX))
    small = img.resize((size, size), Image.Resampling.BOX)
    if "--own" in sys.argv:
        out = small.quantize(colors=48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    else:
        out = process.snap(small, False)
    path = os.path.join(GODOT, dest)
    out.save(path)
    print(art_id, "->", dest, out.size)


if __name__ == "__main__":
    main()
