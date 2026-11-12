"""The belt pager's slim body (godot/assets/textury/hud/pager_slim.png) cut out of the Grok one
(pager.png, prompts_day.tsv hud_pager) at its own pixels: the buttons' strip and most of the
plastic round the screen left out, the screen two lines of the HUD's small font tall
(12. 11.: the whole pager took a quarter of the view). Nothing is scaled, only cut and joined
where the plastic is the same, so it stays the picture that was chosen.

    python tools/artgen/pager_slim.py
"""
from pathlib import Path

from PIL import Image

HUD = Path(__file__).resolve().parents[2] / "godot" / "assets" / "textury" / "hud"

# Columns of the original that make up the slim one, left to right: the body's edge, the
# screen's chrome frame, the screen, its frame on the right, the body's edge.
EDGE = 4
TOP = 5
LCD_W = 78
LCD_H = 18


# Transparent pixels a row from each corner.
CORNER = [3, 2, 1, 1]


def columns(w: int) -> list:
    return list(range(0, EDGE)) + list(range(10, 16)) + list(range(16, 16 + LCD_W)) + list(range(105, 111)) + list(range(w - EDGE, w))


def rows(h: int) -> list:
    return list(range(0, TOP)) + list(range(10, 15)) + list(range(15, 15 + LCD_H)) + list(range(42, 47)) + list(range(h - EDGE, h))


def main() -> None:
    src = Image.open(HUD / "pager.png").convert("RGBA")
    cols, rws = columns(src.width), rows(src.height)
    out = Image.new("RGBA", (len(cols), len(rws)))
    for y, sy in enumerate(rws):
        for x, sx in enumerate(cols):
            out.putpixel((x, y), src.getpixel((sx, sy)))
    # The LED (4 x 4 at 102,4 in the original) into the plastic over the screen's right end.
    led_x = out.width - EDGE - 6 - 6
    for dy in range(4):
        for dx in range(4):
            p = src.getpixel((102 + dx, 4 + dy))
            if p[3] > 0:
                out.putpixel((led_x + dx, 1 + dy), p)
    # The body's corners round again (the cut took the original's curve away).
    for y, n in enumerate(CORNER):
        for x in range(n):
            for cx, cy in ((x, y), (out.width - 1 - x, y), (x, out.height - 1 - y), (out.width - 1 - x, out.height - 1 - y)):
                out.putpixel((cx, cy), (0, 0, 0, 0))
    out.save(HUD / "pager_slim.png")
    print("pager_slim.png", out.size, "screen at", (EDGE + 6, TOP + 5), (LCD_W, LCD_H), "led at", (led_x, 1))


if __name__ == "__main__":
    main()
