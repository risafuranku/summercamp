#!/usr/bin/env python3
"""The lettering on Lesna's buildings, the way Czech village signs were made before 1998:
sheet-metal letters screwed to the render one by one (JEDNOTA, with rust running down
the wall under them and a letter that fell off years ago), names painted straight on the
plaster and flaking (HOSTINEC U JEZERA, HASICSKA ZBROJNICE), tube letters that glow at
night (MOTEL), a ghost slogan painted over and showing through, house numbers in black
paint, and the white village sign with its black border.

    python tools/artgen/lettering.py [name ...]

-> godot/assets/textury/town/sign_<name>.png (RGBA, hard alpha, game palette), plus
   sign_<name>_glow.png for the ones that light up. PX_M pixels per metre: the game puts
   each on a quad of (width, height) / PX_M metres in front of the wall
   (town_lesna._letters).

Fonts are Windows' own (Bahnschrift, the DIN of Czech signwriters; Arial Narrow): fine
for the prototype, swap for OFL faces before any public release (like the RR textures).
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

import process

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "town")
FONTS = "C:/Windows/Fonts/"
PX_M = 48
SS = 8

BAHN = ("bahnschrift.ttf", None)

# name: text, font (file, variation), cap height in metres, style, colours, extras.
SIGNS = {
    "jednota": dict(text="JEDNOTA", font=(BAHN[0], b"Bold SemiCondensed"), cap=0.62, style="raised",
                    face=(178, 30, 24), side=(104, 18, 14), track=0.06, rust=0.7, seed=3),
    "samoobsluha": dict(text="SAMOOBSLUHA", font=(BAHN[0], b"Bold SemiCondensed"), cap=0.3, style="raised",
                        face=(178, 30, 24), side=(104, 18, 14), track=0.04, rust=0.5, missing=[7], seed=4),
    "hostinec": dict(text="HOSTINEC U JEZERA", font=(BAHN[0], b"SemiBold Condensed"), cap=0.38, style="painted",
                     face=(40, 44, 36), shadow=(150, 140, 110), track=0.05, wear=0.12, seed=5),
    "motel": dict(text="MOTEL", font=(BAHN[0], b"Bold Condensed"), cap=0.8, style="neon",
                  face=(150, 40, 36), glow=(255, 70, 52), track=0.12, seed=6),
    "motel_lesna": dict(text="LESNA", font=(BAHN[0], b"SemiBold Condensed"), cap=0.42, style="raised",
                        face=(226, 222, 210), side=(120, 118, 110), track=0.1, rust=0.3, seed=7),
    "benzina": dict(text="BENZINA", font=(BAHN[0], b"Bold"), cap=0.36, style="raised",
                    face=(238, 234, 222), side=(150, 148, 140), track=0.05, rust=0.0, seed=8),
    "hasici": dict(text="HASIČSKÁ ZBROJNICE", font=(BAHN[0], b"SemiBold Condensed"), cap=0.3, style="painted",
                   face=(126, 30, 24), shadow=None, track=0.05, wear=0.12, seed=9),
    "slogan": dict(text="SE SOVĚTSKÝM SVAZEM NA VĚČNÉ ČASY", font=(BAHN[0], b"Bold Condensed"), cap=0.42,
                   style="painted", face=(196, 150, 124), shadow=None, track=0.04, wear=0.3, seed=10),
    "obec": dict(text="LESNA", style="plate", cap=0.2, seed=11),
    # Podlesi: the hamlet's sign at its turn, the request stop's name plate, and the lit
    # STOJIME over the driver of the 380.
    "podlesi": dict(text="PODLESÍ", style="plate", cap=0.17, seed=12),
    "podlesi_stop": dict(text="PODLESÍ, rozc.", sub="na znamení", style="plate", cap=0.1, size=(1.1, 0.34), seed=13),
    "stojime": dict(text="STOJÍME", font=(BAHN[0], b"Bold Condensed"), cap=0.3, style="neon",
                    face=(120, 30, 26), glow=(255, 60, 40), track=0.06, seed=14),
}
# Numbers painted by the doors.
for n in ["12", "27", "31", "44", "58", "63", "71", "89", "95", "103", "116", "128"]:
    SIGNS["cp_" + n] = dict(text=n, font=("ARIALNB.TTF", None), cap=0.15, style="painted",
                            face=(30, 30, 30), shadow=None, track=0.02, wear=0.05, seed=int(n))


def font_for(spec, cap_px):
    fname, var = spec
    probe = ImageFont.truetype(FONTS + fname, 400)
    if var:
        probe.set_variation_by_name(var)
    b = probe.getbbox("H")
    size = max(4, round(400 * cap_px / (b[3] - b[1])))
    f = ImageFont.truetype(FONTS + fname, size)
    if var:
        f.set_variation_by_name(var)
    return f


def letter_masks(text, font, track_px):
    """Each letter's mask on one line, at supersampled size: [(x, mask image)], width, height."""
    asc, desc = font.getmetrics()
    # Room over the capitals for the hacky and carkas (C with caron reaches above 0).
    top = int(asc * 0.35)
    h = top + asc + desc
    x = 0
    out = []
    for ch in text:
        adv = font.getlength(ch)
        if ch != " ":
            m = Image.new("L", (int(adv) + 4, h), 0)
            ImageDraw.Draw(m).text((0, top), ch, font=font, fill=255)
            out.append((ch, x, m))
        x += adv + track_px
    return out, int(x - track_px) + 4, h


def downsample(rgba):
    """Box down to game pixels (premultiplied), hard alpha, the game palette."""
    w = max(1, rgba.width // SS)
    h = max(1, rgba.height // SS)
    r, g, b, a = rgba.split()
    zero = Image.new("L", rgba.size, 0)
    pre = Image.merge("RGBA", [Image.composite(ch, zero, a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, h), Image.Resampling.BOX)
    px = small.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return small


def crop_to_content(img, pad):
    box = img.getchannel("A").getbbox()
    if box is None:
        return img
    l, t, r, b = box
    return img.crop((max(0, l - pad), max(0, t - pad), min(img.width, r + pad), min(img.height, b + pad)))


def raised(spec, rng):
    """Sheet-metal letters a few centimetres off the wall: the face, its edge, the shadow
    they throw, rust streaks down the render under them; a lost letter leaves its screw
    holes and its streaks."""
    cap_px = spec["cap"] * PX_M * SS
    font = font_for(spec["font"], cap_px)
    letters, w, h = letter_masks(spec["text"], font, spec["track"] * PX_M * SS)
    depth = max(SS, int(0.035 * PX_M * SS))
    pad = int(0.5 * PX_M * SS)
    W, H = w + pad * 2, h + pad * 2
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow = Image.new("L", (W, H), 0)
    sidem = Image.new("L", (W, H), 0)
    face = Image.new("L", (W, H), 0)
    missing = set(spec.get("missing", []))
    holes = []
    streak_cols = []
    for i, (ch, x, m) in enumerate(letters):
        ox, oy = pad + int(x), pad
        bbox = m.getbbox()
        if i in missing:
            if bbox:
                holes += [(ox + bbox[0] + (bbox[2] - bbox[0]) // 4, oy + bbox[1] + (bbox[3] - bbox[1]) // 4),
                          (ox + bbox[0] + 3 * (bbox[2] - bbox[0]) // 4, oy + bbox[3] - (bbox[3] - bbox[1]) // 4)]
                streak_cols.append((ox + bbox[0], ox + bbox[2], oy + bbox[3]))
            continue
        shadow.paste(255, (ox + depth * 2, oy + depth * 2), m)
        for d in range(1, depth + 1):
            sidem.paste(255, (ox + d, oy + d), m)
        face.paste(255, (ox, oy), m)
        if bbox:
            streak_cols.append((ox + bbox[0], ox + bbox[2], oy + bbox[3]))
    dark = Image.new("RGBA", (W, H), (58, 54, 48, 255))
    img.paste(dark, (0, 0), shadow)
    # Rust bleeding down the render, in game-pixel columns.
    rust = spec.get("rust", 0.0)
    if rust > 0.0:
        draw = ImageDraw.Draw(img)
        for x0, x1, y0 in streak_cols:
            gx = x0 - x0 % SS
            while gx < x1:
                if rng.random() < rust * 0.22:
                    length = int(rng.uniform(0.05, 0.4) * PX_M * SS)
                    col = rng.choice([(132, 92, 62, 255), (146, 108, 76, 255), (118, 84, 60, 255)])
                    y = y0 - SS * 2
                    while y < y0 + length:
                        # Thinning out towards its end.
                        if rng.random() < 1.0 - 0.6 * (y - y0) / max(1, length):
                            draw.rectangle([gx, y, gx + SS - 1, y + SS - 1], fill=col)
                        y += SS
                gx += SS
    img.paste(Image.new("RGBA", (W, H), tuple(spec["side"]) + (255,)), (0, 0), sidem)
    img.paste(Image.new("RGBA", (W, H), tuple(spec["face"]) + (255,)), (0, 0), face)
    # Screw holes of the letter that is gone.
    draw = ImageDraw.Draw(img)
    for hx, hy in holes:
        gx, gy = hx - hx % SS, hy - hy % SS
        draw.rectangle([gx, gy, gx + SS - 1, gy + SS - 1], fill=(70, 52, 40, 255))
    return crop_to_content(img, SS), None


def painted(spec, rng):
    """Paint straight on the plaster: flat letters, flaking in game-pixel chips; an
    optional painted shadow (the signwriter's trick) offset down and right."""
    cap_px = spec["cap"] * PX_M * SS
    font = font_for(spec["font"], cap_px)
    letters, w, h = letter_masks(spec["text"], font, spec["track"] * PX_M * SS)
    pad = int(0.2 * PX_M * SS)
    W, H = w + pad * 2, h + pad * 2
    face = Image.new("L", (W, H), 0)
    for ch, x, m in letters:
        face.paste(255, (pad + int(x), pad), m)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if spec.get("shadow"):
        off = max(SS, int(0.03 * PX_M * SS))
        img.paste(Image.new("RGBA", (W, H), tuple(spec["shadow"]) + (255,)), (off, off), face)
    img.paste(Image.new("RGBA", (W, H), tuple(spec["face"]) + (255,)), (0, 0), face)
    small = downsample(img)
    # Flakes: the paint gone in clumps of game pixels (a coarse noise, blown up), so it
    # reads as weather on paint and not as a dither.
    wear = spec.get("wear", 0.0)
    px = small.load()
    if wear > 0.0:
        cell = 3
        cw, ch_ = small.width // cell + 2, small.height // cell + 2
        coarse = [[rng.random() for _ in range(cw)] for _ in range(ch_)]
        for y in range(small.height):
            for x in range(small.width):
                if px[x, y][3] < 128:
                    continue
                n = coarse[y // cell][x // cell] * 0.7 + rng.random() * 0.3
                if n < wear:
                    px[x, y] = (0, 0, 0, 0)
    return crop_to_content(small, 1), "small"


def neon(spec, rng):
    """Tube letters on their brackets: dull red by day, the glow map for the night."""
    img, _ = raised(dict(spec, side=tuple(max(0, c - 70) for c in spec["face"]), rust=0.15), rng)
    small = downsample(img)
    glow = Image.new("RGBA", small.size, (0, 0, 0, 255))
    sp = small.load()
    gp = glow.load()
    fr, fg, fb = spec["face"]
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = sp[x, y]
            if a >= 128 and abs(r - fr) < 40 and abs(g - fg) < 40 and abs(b - fb) < 40:
                gp[x, y] = tuple(spec["glow"]) + (255,)
    return small, glow


def plate(spec, rng):
    """A white plate, black border, the name in black (the village sign; with `sub` a
    smaller second line, like the request stop's "na znameni")."""
    w_m, h_m = spec.get("size", (1.1, 0.5))
    W, H = int(w_m * PX_M * SS), int(h_m * PX_M * SS)
    img = Image.new("RGBA", (W, H), (236, 236, 230, 255))
    d = ImageDraw.Draw(img)
    b = int(max(0.015, 0.03 * h_m / 0.5) * PX_M * SS)
    d.rectangle([0, 0, W - 1, H - 1], outline=(20, 20, 20, 255), width=b)
    font = font_for((BAHN[0], b"SemiBold"), spec["cap"] * PX_M * SS)
    asc, desc = font.getmetrics()
    tw = font.getlength(spec["text"])
    if spec.get("sub"):
        small = font_for((BAHN[0], b"Regular"), spec["cap"] * 0.75 * PX_M * SS)
        sw = small.getlength(spec["sub"])
        d.text(((W - tw) / 2, H * 0.1), spec["text"], font=font, fill=(20, 20, 20, 255))
        d.text(((W - sw) / 2, H * 0.55), spec["sub"], font=small, fill=(20, 20, 20, 255))
    else:
        d.text(((W - tw) / 2, (H - asc - desc) / 2 + desc * 0.3), spec["text"], font=font, fill=(20, 20, 20, 255))
    return img, None


def make(name):
    spec = SIGNS[name]
    rng = random.Random(spec.get("seed", 1))
    style = spec["style"]
    glow = None
    if style == "raised":
        img, _ = raised(spec, rng)
        img = downsample(img)
    elif style == "painted":
        img, _ = painted(spec, rng)
    elif style == "neon":
        img, glow = neon(spec, rng)
    else:
        img, _ = plate(spec, rng)
        img = downsample(img)
    out = process.snap(img, True)
    out.save(os.path.join(OUT, "sign_%s.png" % name))
    if glow is not None:
        process.snap(glow, False).save(os.path.join(OUT, "sign_%s_glow.png" % name))
    print("sign_%s.png" % name, out.size)


def main():
    names = sys.argv[1:] or list(SIGNS.keys())
    for n in names:
        make(n)


if __name__ == "__main__":
    main()
