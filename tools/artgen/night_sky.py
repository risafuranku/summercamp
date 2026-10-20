"""The clear night's sky and the moon, from Grok's renders (agent B, 20. 10.).

    python tools/artgen/night_sky.py

  out/sky_night_stars/raw.png (16:9, a starry autumn night, the milky way across it)
      -> godot/assets/textury/skybox/skystars.png, an equirectangular panorama for the
         sky shader (weather_visuals.gd SKY_TEX_NIGHT_CLEAR_PATHS), 640 x 360 of the
         render's own pixels (Grok draws them 4 wide) each drawn 4 x 4 (2560 x 1440, hard
         edges through the shader's linear filter; about the size the other skies' pixels
         are on screen): the render is the upper half of the sky, once as it is and once
         mirrored beside it (so it meets itself at both seams and the milky way rises and
         falls round the sky as a great circle does); the stars are taken out, the sky
         behind brought to 40 colours, and the stars set back as one sharp pixel each (the
         brightest with a cross), the ones in the mirrored half moved along, not mirrored,
         so no star has a twin; below the horizon the horizon's navy, darkening.
  out/sky_dawn/raw.png (16:9, the sky before sunrise, the glow low along the horizon)
      -> godot/assets/textury/skybox/skydawn.png, the same way (no stars to reset: its
         few faint ones are left as they are), the glow strongest in the east where the
         sun comes up (-X, a quarter turn before the panorama's middle; SKY_COORDS u 0.75)
         and the west's horizon cooler and dimmer.
  out/sky_golden, sky_sunset, sky_bluehour/raw.png (the clear evening: gold an hour
      before the sun goes down, just after it, the blue hour)
      -> skybox/skygolden.png, skysunset.png, skybluehour.png, the same way with the glow
         in the west (+X, u 0.25), where the sun goes down.
  out/spr_moon/raw.png (the full moon on magenta)
      -> godot/assets/textury/skybox/moon.png, 24 x 24 with alpha (the moon is some 20 of
         the screen's lines across at Build 240p: its pixels about the screen's).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SKY = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "skybox")
PX = 4          # the render's pixel
UP = 4          # the panorama's pixel


def native(a: np.ndarray) -> np.ndarray:
    """The render at its own pixel size: Grok draws pixels four of its pixels wide."""
    h, w = a.shape[0] // PX * PX, a.shape[1] // PX * PX
    return a[:h, :w].reshape(h // PX, PX, w // PX, PX, 3).astype(np.float32).mean(axis=(1, 3))


def box_blur(img: np.ndarray, k: int) -> np.ndarray:
    pad = np.pad(img, ((k, k), (k, k)) + ((0, 0),) * (img.ndim - 2), mode="edge")
    cs = np.pad(pad.cumsum(0).cumsum(1), ((1, 0), (1, 0)) + ((0, 0),) * (img.ndim - 2))
    n = 2 * k + 1
    out = (cs[n:, n:] - cs[:-n, n:] - cs[n:, :-n] + cs[:-n, :-n]) / (n * n)
    return out[: img.shape[0], : img.shape[1]]


def stars_of(a: np.ndarray) -> list:
    """(x, y, colour, strength) of each star in the render: a bright pixel brighter than
    all round it, well over the sky behind it (the milky way's glow included)."""
    lum = a.astype(np.float32).mean(axis=2)
    bg = box_blur(lum, 12)
    out = []
    h, w = lum.shape
    ys, xs = np.nonzero(lum - bg > 34)
    for y, x in zip(ys, xs):
        if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
            continue
        v = lum[y, x]
        win = lum[y - 2: y + 3, x - 2: x + 3]
        if v < win.max():
            continue
        # A star's flat top of equal pixels: its first pixel only.
        if lum[y, x - 1] == v or lum[y - 1, x] == v or lum[y - 1, x - 1] == v or lum[y - 1, x + 1] == v:
            continue
        out.append((x, y, a[y, x].astype(np.float32), float(v - bg[y, x])))
    return out


def build_sky() -> None:
    raw = np.asarray(Image.open(os.path.join(OUT, "sky_night_stars", "raw.png")).convert("RGB"))
    stars = stars_of(raw)
    # A cross on the brightest one in a hundred (the render's own few sparkles).
    big = float(np.percentile([st[3] for st in stars], 99))
    print("stars found:", len(stars), "cross over", round(big))
    # The sky without its stars, at the render's own pixel size.
    clean = raw.astype(np.float32).copy()
    blur = box_blur(clean, 6)
    for x, y, _c, _s in stars:
        y0, y1, x0, x1 = max(y - 4, 0), min(y + 5, raw.shape[0]), max(x - 4, 0), min(x + 5, raw.shape[1])
        clean[y0:y1, x0:x1] = blur[y0:y1, x0:x1]
    sky = native(clean)                              # 320 x 180: the upper half of the sky
    nh, nw = sky.shape[:2]
    pano = np.zeros((nh * 2, nw * 2, 3), np.float32)
    pano[:nh, :nw] = sky
    pano[:nh, nw:] = sky[:, ::-1]
    # Below the horizon: the horizon's navy (its last rows, smoothed along), darkening.
    horizon = box_blur(pano[nh - 6: nh].mean(axis=0, keepdims=True).repeat(9, 0), 4)[4]
    for y in range(nh, nh * 2):
        pano[y] = horizon * (1.0 - 0.45 * (y - nh) / nh)
    # A limited palette for the sky behind (it is all dark blues).
    pal = Image.fromarray(pano.clip(0, 255).astype(np.uint8)).quantize(colors=40, method=Image.MEDIANCUT, dither=Image.NONE)
    pano = np.asarray(pal.convert("RGB")).astype(np.float32)
    # The stars, one pixel each at their own brightness; the second half's moved half a
    # render along, not mirrored (a star mirrored beside itself makes twins).
    for half in (0, 1):
        for x, y, col, strength in stars:
            nx = (x // PX if half == 0 else ((x // PX) + nw // 2) % nw) + half * nw
            ny = y // PX
            if ny >= nh:
                continue
            c = np.minimum(col, 255)
            pano[ny, nx] = np.maximum(pano[ny, nx], c)
            # The brightest few: a cross of four dimmer pixels round them.
            if strength >= big:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    jx, jy = (nx + dx) % (nw * 2), ny + dy
                    if 0 <= jy < nh:
                        pano[jy, jx] = np.maximum(pano[jy, jx], c * 0.45)
    img = Image.fromarray(pano.clip(0, 255).astype(np.uint8))
    # Each pixel UP x UP: hard edges through the sky shader's linear filter.
    img = img.resize((nw * 2 * UP, nh * 2 * UP), Image.NEAREST)
    dst = os.path.join(SKY, "skystars.png")
    img.save(dst, optimize=True)
    print("->", dst, img.size, os.path.getsize(dst) // 1024, "KB")


def build_dawn() -> None:
    build_glow_sky("sky_dawn", "skydawn.png", 0.75)


# The evening skies: the glow in the west, where the sun goes down (+X, u 0.25).
EVENING = {"golden": ("sky_golden", "skygolden.png"), "sunset": ("sky_sunset", "skysunset.png"),
           "bluehour": ("sky_bluehour", "skybluehour.png")}


def build_glow_sky(art_id: str, name: str, glow_u: float) -> None:
    """A sky with a glow on one side: the render once as it is and once mirrored, the side
    away from the glow greyed and dimmed toward the horizon."""
    raw = np.asarray(Image.open(os.path.join(OUT, art_id, "raw.png")).convert("RGB")).astype(np.float32)
    sky = native(raw)                                # 320 x 180: the upper half
    nh, nw = sky.shape[:2]
    pano = np.zeros((nh * 2, nw * 2, 3), np.float32)
    pano[:nh, :nw] = sky
    pano[:nh, nw:] = sky[:, ::-1]
    # East glows, west is the cold side: the same sky greyed and dimmed, more so lower down.
    u = (np.arange(nw * 2) + 0.5) / (nw * 2)
    east = 0.5 + 0.5 * np.cos(2.0 * np.pi * (u - glow_u))
    lum = pano[:nh].mean(axis=2, keepdims=True)
    cold = lum * np.array([0.78, 0.82, 0.98]) * 0.85
    low = np.linspace(0.0, 1.0, nh)[:, None, None] ** 1.5
    west_mix = (1.0 - east)[None, :, None] * 0.75 * low
    pano[:nh] = pano[:nh] * (1.0 - west_mix) + cold * west_mix
    # Below the horizon: the horizon's colour all round, darkening (by the column it made
    # curved bands of the palette's steps).
    horizon = pano[nh - 4: nh].mean(axis=(0, 1))
    for y in range(nh, nh * 2):
        pano[y] = horizon * (1.0 - 0.5 * (y - nh) / nh)
    img = Image.fromarray(pano.clip(0, 255).astype(np.uint8))
    img = img.quantize(colors=96, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    img = img.resize((nw * 2 * UP, nh * 2 * UP), Image.NEAREST)
    dst = os.path.join(SKY, name)
    img.save(dst, optimize=True)
    print("->", dst, img.size, os.path.getsize(dst) // 1024, "KB")


def build_moon() -> None:
    a = np.asarray(Image.open(os.path.join(OUT, "spr_moon", "raw.png")).convert("RGB")).astype(np.float32)
    # Magenta is red and blue with no green; the moon's grey and yellow have their green
    # up with the rest (its dark seas too), its edge pixels blended half way.
    g = a[..., 1]
    pink = np.minimum(a[..., 0], a[..., 2]) - g
    inside = pink < 60
    ys, xs = np.nonzero(pink < 128)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    side = max(y1 - y0, x1 - x0)
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    top, left = cy - side // 2, cx - side // 2
    a, inside, pink = a[top: top + side, left: left + side], inside[top: top + side, left: left + side], pink[top: top + side, left: left + side]
    # 24 x 24: the colour of the moon's own pixels in each cell (no magenta fringe), the
    # edge hard: in when half the cell is moon.
    n = 24
    cell = side / n
    out = np.zeros((n, n, 4), np.uint8)
    for j in range(n):
        for i in range(n):
            sl = (slice(int(j * cell), int((j + 1) * cell)), slice(int(i * cell), int((i + 1) * cell)))
            m = inside[sl]
            if (pink[sl] < 128).mean() < 0.5 or m.sum() == 0:
                continue
            out[j, i, :3] = a[sl][m].mean(axis=0).clip(0, 255)
            out[j, i, 3] = 255
    dst = os.path.join(SKY, "moon.png")
    Image.fromarray(out, "RGBA").save(dst)
    print("->", dst, (n, n))


if __name__ == "__main__":
    what = sys.argv[1:] or ["sky", "dawn", "moon"] + list(EVENING)
    if "sky" in what:
        build_sky()
    if "dawn" in what:
        build_dawn()
    for k, (art_id, name) in EVENING.items():
        if k in what:
            build_glow_sky(art_id, name, 0.25)
    if "moon" in what:
        build_moon()
