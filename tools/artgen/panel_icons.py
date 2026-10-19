"""Small Okna 98 icons for the camp computer's panel that no Grok render was made for:
the shareware games (Komar, Vylet, Pexeso), the jobs (KlikBanka, SectiTo) and the Games
tab's joystick. Drawn with primitives at 32x32 in the 98 manner (a dark outline, a light
top-left, a shadow bottom-right) and boxed down to 16x16 for the small ones.

    python tools/artgen/panel_icons.py

Writes godot/assets/textury/os98/icons/<name>.png and <name>_16.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "godot" / "assets" / "textury" / "os98" / "icons"
INK = (20, 20, 20, 255)


def canvas():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def komar():
    img, d = canvas()
    # Legs, long and thin.
    for x0, y0, x1, y1 in [(12, 18, 5, 27), (15, 19, 11, 29), (18, 19, 21, 29), (20, 18, 27, 26), (13, 15, 4, 11), (19, 15, 28, 10)]:
        d.line((x0, y0, x1, y1), fill=(60, 50, 40, 255))
    # Wings, glassy.
    d.ellipse((4, 4, 15, 14), fill=(214, 228, 240, 210), outline=(120, 130, 150, 255))
    d.ellipse((17, 4, 28, 14), fill=(214, 228, 240, 210), outline=(120, 130, 150, 255))
    # Body, striped, and the full belly.
    d.ellipse((12, 12, 20, 24), fill=(70, 56, 44, 255), outline=INK)
    d.line((13, 17, 19, 17), fill=(150, 130, 100, 255))
    d.line((13, 20, 19, 20), fill=(150, 130, 100, 255))
    d.ellipse((13, 21, 19, 27), fill=(200, 30, 30, 255), outline=INK)
    # Head and the proboscis.
    d.ellipse((13, 8, 19, 13), fill=(50, 40, 34, 255), outline=INK)
    d.line((16, 8, 16, 2), fill=INK)
    return img


def vylet():
    img, d = canvas()
    d.polygon([(10, 1), (19, 16), (1, 16)], fill=(30, 110, 50, 255), outline=INK)
    d.polygon([(10, 7), (20, 24), (0, 24)], fill=(40, 130, 60, 255), outline=INK)
    d.line((5, 14, 12, 8), fill=(110, 190, 120, 255))
    d.rectangle((8, 24, 11, 30), fill=(110, 70, 30, 255), outline=INK)
    # The hiker: rucksack, green jacket, a stick.
    d.rectangle((24, 13, 28, 21), fill=(150, 90, 40, 255), outline=INK)
    d.ellipse((19, 6, 25, 12), fill=(232, 184, 140, 255), outline=INK)
    d.rectangle((19, 5, 25, 7), fill=(30, 70, 30, 255))
    d.rectangle((19, 12, 25, 22), fill=(40, 110, 60, 255), outline=INK)
    d.line((19, 23, 18, 30), fill=(40, 40, 70, 255), width=2)
    d.line((24, 23, 25, 30), fill=(40, 40, 70, 255), width=2)
    d.line((17, 13, 14, 30), fill=(120, 80, 40, 255), width=1)
    return img


def pexeso():
    img, d = canvas()
    # The back of a card, tilted behind.
    d.polygon([(3, 6), (17, 2), (22, 24), (8, 28)], fill=(30, 46, 130, 255), outline=INK)
    d.polygon([(10, 10), (13, 17), (7, 18)], fill=(70, 160, 90, 255))
    # The face of a card in front: a tent on it.
    d.rectangle((13, 7, 29, 30), fill=(255, 252, 236, 255), outline=INK)
    d.line((14, 8, 28, 8), fill=(255, 255, 255, 255))
    d.line((28, 9, 28, 29), fill=(160, 150, 130, 255))
    d.polygon([(21, 12), (27, 24), (15, 24)], fill=(230, 120, 30, 255), outline=INK)
    d.line((21, 16, 21, 24), fill=(120, 50, 10, 255))
    return img


def klikbank():
    img, d = canvas()
    # The cable, the mouse.
    d.line((14, 2, 14, 6), fill=(60, 60, 60, 255), width=2)
    d.arc((8, -4, 20, 8), 0, 90, fill=(60, 60, 60, 255))
    d.rounded_rectangle((6, 6, 22, 28), radius=7, fill=(222, 216, 196, 255), outline=INK)
    d.line((6, 14, 22, 14), fill=(140, 134, 116, 255))
    d.line((14, 6, 14, 14), fill=(140, 134, 116, 255))
    d.line((8, 8, 8, 24), fill=(250, 248, 236, 255))
    # A gold coin on top of it.
    d.ellipse((17, 15, 31, 29), fill=(240, 196, 40, 255), outline=(110, 80, 0, 255))
    d.ellipse((20, 18, 28, 26), outline=(190, 140, 10, 255))
    d.text((21, 16), "$", fill=(120, 80, 0, 255))
    return img


def sectito():
    img, d = canvas()
    # The aerial photograph: a field, the water, tents as dots.
    d.rectangle((1, 3, 25, 25), fill=(250, 250, 246, 255), outline=INK)
    d.rectangle((3, 5, 23, 23), fill=(90, 120, 60, 255))
    d.polygon([(17, 5), (23, 5), (23, 23), (14, 23), (16, 14)], fill=(50, 80, 110, 255))
    for x, y, c in [(5, 8, (230, 120, 30)), (9, 12, (40, 90, 200)), (6, 17, (200, 40, 40)), (11, 19, (230, 120, 30))]:
        d.rectangle((x, y, x + 2, y + 1), fill=c + (255,))
    # The magnifying glass.
    d.line((22, 22, 30, 30), fill=(90, 60, 30, 255), width=3)
    d.ellipse((13, 13, 25, 25), fill=(200, 230, 255, 120), outline=INK)
    d.arc((15, 15, 23, 23), 180, 270, fill=(255, 255, 255, 255))
    return img


def games():
    img, d = canvas()
    # A joystick: the black base, the stick, the red ball, the fire button.
    d.polygon([(3, 22), (29, 22), (31, 28), (1, 28)], fill=(40, 40, 46, 255), outline=INK)
    d.line((4, 23, 28, 23), fill=(100, 100, 110, 255))
    d.ellipse((22, 23, 27, 26), fill=(230, 200, 40, 255), outline=INK)
    d.rectangle((14, 9, 17, 23), fill=(70, 70, 76, 255), outline=INK)
    d.ellipse((9, 1, 22, 13), fill=(210, 30, 30, 255), outline=INK)
    d.ellipse((12, 3, 16, 7), fill=(255, 140, 140, 255))
    return img


def small(img):
    return img.resize((16, 16), Image.Resampling.BOX)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [("komar", komar), ("vylet", vylet), ("pexeso", pexeso), ("klikbank", klikbank), ("sectito", sectito), ("games", games)]:
        img = fn()
        img.save(OUT / f"{name}.png")
        small(img).save(OUT / f"{name}_16.png")
        print("wrote", name)


if __name__ == "__main__":
    main()
