"""The camp's gravel as one seamless fill (godot/assets/textury/redneck/paths/gravel_fill.png).

The paths are composed tile by tile from their eight neighbours (godot/scripts/path_tiles.gd):
the gravel everywhere a path reaches, the grass see-through so the camp's own ground shows.
The fill is the Redneck straight piece's gravel band (gravel.png, rows BAND), stretched over
the whole tile and made to wrap top to bottom by blending it with itself half a tile round;
left to right it already wraps (the piece was made to chain).

    python tools/artgen/path_fill.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "godot/assets/textury/redneck/paths"
BAND = (36, 206)
SIZE = 256
FADE = 48
GRAIN = 1.5
FLATTEN = 0.85


def main() -> None:
    src = Image.open(ROOT / "gravel.png").convert("RGB")
    src = src.resize((SIZE, SIZE), Image.NEAREST) if src.size != (SIZE, SIZE) else src
    band = src.crop((0, BAND[0], SIZE, BAND[1])).resize((SIZE, SIZE), Image.BICUBIC)
    rolled = Image.new("RGB", (SIZE, SIZE))
    rolled.paste(band.crop((0, SIZE // 2, SIZE, SIZE)), (0, 0))
    rolled.paste(band.crop((0, 0, SIZE, SIZE // 2)), (0, SIZE // 2))
    # Near the top and bottom edges the rolled copy (whose middle is there) takes over.
    mask = Image.new("L", (SIZE, SIZE))
    px = mask.load()
    for y in range(SIZE):
        d = min(y, SIZE - 1 - y)
        a = 255 if d < FADE // 4 else max(0, int(255 * (1.0 - (d - FADE // 4) / FADE)))
        for x in range(SIZE):
            px[x, y] = a
    out = Image.composite(rolled, band, mask)
    # The band's ruts out (each row brought to the whole's mean: tile after tile they
    # read as planks), its grain stronger (at the camp's 240 lines and through the palette
    # the soft band went flat).
    px2 = out.load()
    mean = [0.0, 0.0, 0.0]
    rows = []
    for y in range(SIZE):
        r = [sum(px2[x, y][k] for x in range(SIZE)) / SIZE for k in range(3)]
        rows.append(r)
        mean = [m + v / SIZE for m, v in zip(mean, r)]
    for y in range(SIZE):
        for x in range(SIZE):
            px2[x, y] = tuple(max(0, min(255, int(m + (c - r * FLATTEN - m * (1 - FLATTEN)) * GRAIN))) for c, r, m in zip(px2[x, y], rows[y], mean))
    # The tufts of grass between the ruts: gravel from further along instead.
    src2 = out.copy().load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b = src2[x, y]
            if g >= r * 0.92 or b >= r * 0.85:
                for k in (61, 97, 131, 173):
                    r2, g2, b2 = src2[(x + k * 3) % SIZE, (y + k) % SIZE]
                    if g2 < r2 * 0.92 and b2 < r2 * 0.85:
                        px2[x, y] = (r2, g2, b2)
                        break
    out.save(ROOT / "gravel_fill.png")
    print("wrote", ROOT / "gravel_fill.png")


if __name__ == "__main__":
    main()
