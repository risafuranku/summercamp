#!/usr/bin/env python3
"""Pictures for the 1998 web (scripts/os98/web_pages.gd): a Grok render shrunk to the
size a 1998 home page would have used and saved the way it would have been: photos as
a low-quality JPEG (blocks and ringing), icons as a 16-colour GIF-ish palette.

    python tools/artgen/web_image.py <id> photo|news|gif <width> [<dest name>]
-> godot/assets/textury/web/<dest name or id>.png
"""
import io
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "web")


def main():
    art_id, kind, width = sys.argv[1], sys.argv[2], int(sys.argv[3])
    name = sys.argv[4] if len(sys.argv) > 4 else art_id
    img = Image.open(os.path.join(HERE, "out", art_id, "raw.png")).convert("RGB")
    h = max(1, round(img.height * width / img.width))
    img = img.resize((width, h), Image.Resampling.LANCZOS if kind != "gif" else Image.Resampling.BOX)
    if kind == "news":
        img = img.convert("L").convert("RGB")
    if kind in ("photo", "news"):
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=38 if kind == "photo" else 45, subsampling=2)
        img = Image.open(io.BytesIO(buf.getvalue())).convert("RGB")
    else:
        img = img.quantize(colors=16, dither=Image.Dither.NONE).convert("RGB")
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    print(name, img.size)


if __name__ == "__main__":
    main()
