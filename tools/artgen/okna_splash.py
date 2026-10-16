#!/usr/bin/env python3
"""The Okna 98 art (the camp computer's operating system, scripts/os98/os_shell.gd):
keys the Grok logo out of its magenta (soft alpha, the OS is not on the game palette),
and composes the boot and shut-down screens at 640x480 from the Grok sky and the logo
with the wordmark set in Franklin Gothic, the way the real screens were made.

    python tools/artgen/okna_splash.py
-> godot/assets/textury/os98/okna_logo.png, okna_logo_small.png, okna_splash.png,
   okna_shutdown.png, okna_safe.png
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "os98")
FONTS = "C:/Windows/Fonts/"


def key_logo():
    img = Image.open(os.path.join(HERE, "out", "okna_logo", "raw.png")).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # Distance from pure magenta; soft edge.
            d = abs(r - 255) + g + abs(b - 255)
            if d < 90:
                px[x, y] = (0, 0, 0, 0)
            elif d < 200:
                k = (d - 90) / 110.0
                # Pull the magenta fringe out of the colour.
                px[x, y] = (int(min(255, r * k + g * (1 - k))), g, int(min(255, b * k + g * (1 - k))), int(255 * k))
    return img.crop(img.getbbox())


def text(d, xy, s, font, fill, shadow=None):
    if shadow:
        d.text((xy[0] + 2, xy[1] + 2), s, font=font, fill=shadow)
    d.text(xy, s, font=font, fill=fill)


def main():
    os.makedirs(OUT, exist_ok=True)
    logo = key_logo()
    logo.resize((256, round(256 * logo.height / logo.width)), Image.LANCZOS).save(os.path.join(OUT, "okna_logo.png"))
    logo.resize((32, round(32 * logo.height / logo.width)), Image.LANCZOS).save(os.path.join(OUT, "okna_logo_small.png"))
    logo.resize((18, round(18 * logo.height / logo.width)), Image.LANCZOS).save(os.path.join(OUT, "okna_logo_start.png"))

    sky = Image.open(os.path.join(HERE, "out", "splash_sky", "raw.png")).convert("RGB").resize((640, 480), Image.LANCZOS)
    big = ImageFont.truetype(FONTS + "framdit.ttf", 64)
    num = ImageFont.truetype(FONTS + "framd.ttf", 40)
    small = ImageFont.truetype(FONTS + "arialbd.ttf", 11)
    tiny = ImageFont.truetype(FONTS + "arial.ttf", 10)

    def compose(name, line, dark=False):
        img = sky.copy()
        if dark:
            img = Image.blend(img, Image.new("RGB", img.size, (10, 16, 40)), 0.55)
        lg = logo.resize((150, round(150 * logo.height / logo.width)), Image.LANCZOS)
        # A soft glow behind the logo, like the real one's airbrush.
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse((90, 120, 300, 300), fill=(255, 255, 230, 110))
        glow = glow.filter(ImageFilter.GaussianBlur(28))
        img = Image.alpha_composite(img.convert("RGBA"), glow)
        img.alpha_composite(lg, (110, 150))
        d = ImageDraw.Draw(img)
        text(d, (288, 175), "Okna", big, (255, 255, 255), (20, 30, 70))
        text(d, (440, 166), "98", num, (255, 230, 120), (20, 30, 70))
        text(d, (292, 252), "Okenni software a.s.", small, (230, 236, 255), (20, 30, 70))
        if line:
            w = d.textlength(line, font=small)
            text(d, ((640 - w) / 2, 330), line, small, (255, 255, 255), (10, 20, 50))
        text(d, (16, 446), "Copyright (C) 1985-1998 Okenni software a.s. Vsechna prava vyhrazena.", tiny, (220, 228, 250))
        img.convert("RGB").save(os.path.join(OUT, name))

    compose("okna_splash.png", "")
    compose("okna_shutdown.png", "Please wait while your computer shuts down.", dark=True)
    print("ok")


if __name__ == "__main__":
    main()
