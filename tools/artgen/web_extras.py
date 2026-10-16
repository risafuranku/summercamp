#!/usr/bin/env python3
"""The rest of the 1998 web's art (scripts/os98/web_pages.gd) from the Grok renders:

  - ad banners, 468x60 like every banner of the time, three frames of text each (and a
    fourth the browser swaps in after dark), set in a hard-edged bold face and cut down to
    a GIF palette: web/banner_<id>_<n>.png
  - page background tiles (GeoCities stars, the Courier's paper, the pub's planks):
    web/tile_<id>.png
  - the weather icons, cut from the 3x2 sheet: web/wx_<id>.png
  - photos and the halftone at home-page size, the lake again at 640x480 as a wallpaper.

    python tools/artgen/web_extras.py
"""
import io
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
WEB = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "web")
OS98 = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "os98")
FONTS = "C:/Windows/Fonts/"


def raw(art_id):
    return Image.open(os.path.join(HERE, "out", art_id, "raw.png")).convert("RGB")


def jpeg(img, q):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=q, subsampling=2)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def gif(img, colors):
    return img.quantize(colors=colors, dither=Image.Dither.NONE).convert("RGB")


# ── banners ─────────────────────────────────────────────────────────────────

BANNERS = {
    # id: (art, object box in the render, text colour, outline, frames, night frame)
    "mobile": ("web_banner_mobile", (150, 40, 600, 690), (255, 255, 255), (0, 30, 110), [
        ["BOHEMIATEL GSM", "the network that goes where you go"],
        ["Call home from the lake!", "coverage in 94 % of the country"],
        ["Phones from 3 990 Kc", ">> CLICK HERE <<"],
    ], ["NO SIGNAL", "at Cerne jezero after dark"]),
    "cd": ("web_banner_cd", (60, 80, 720, 620), (255, 240, 120), (40, 0, 60), [
        ["ENCYCLOPAEDIA BOHEMICA 98", "on CD-ROM"],
        ["The whole world on one disc!", "40 000 entries, 900 pictures, sound"],
        ["Only 1 490 Kc", "ORDER NOW >>"],
    ], ["NOW WITH EVERY NAME", "every one of them"]),
    "beer": ("web_banner_beer", (110, 110, 540, 660), (255, 220, 120), (40, 10, 0), [
        ["HLUBOCANY 12", "pale lager from the district brewery"],
        ["The cold one from the reservoir", "brewed with our own water"],
        ["Now at Jednota Lesna", "and at Hostinec U Jezera"],
    ], ["DONT DRINK THE WATER", ""]),
}


def outlined(d, xy, s, font, fill, outline):
    x, y = xy
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                d.text((x + dx, y + dy), s, font=font, fill=outline)
    d.text(xy, s, font=font, fill=fill)


def banners():
    big = ImageFont.truetype(FONTS + "ariblk.ttf", 18)
    small = ImageFont.truetype(FONTS + "arialbd.ttf", 11)
    for bid, (art, box, fill, outline, frames, night) in BANNERS.items():
        src = raw(art)
        # The background: the render's empty side, stretched to the strip.
        bg = src.crop((700, 0, 1280, 720)).resize((468, 60), Image.LANCZOS)
        obj = src.crop(box)
        oh = 58
        obj = obj.resize((round(obj.width * oh / obj.height), oh), Image.LANCZOS)
        for n, lines in enumerate(frames + [night]):
            img = bg.copy()
            img.paste(obj, (6, 1))
            d = ImageDraw.Draw(img)
            d.fontmode = "1"
            x = 6 + obj.width + 10
            if lines[1]:
                outlined(d, (x, 8), lines[0], big, fill, outline)
                outlined(d, (x + 1, 36), lines[1], small, (255, 255, 255), outline)
            else:
                outlined(d, (x, 19), lines[0], big, fill, outline)
            # The 1 px frame every banner had.
            d.rectangle((0, 0, 467, 59), outline=(0, 0, 0))
            name = "banner_%s_%s.png" % (bid, "night" if n == len(frames) else n)
            gif(img, 48).save(os.path.join(WEB, name))
        print("banner", bid)


# ── tiles ───────────────────────────────────────────────────────────────────

def tiles():
    # Stars: grow them before shrinking, or they average away.
    stars = raw("web_tile_stars").filter(ImageFilter.MaxFilter(9)).resize((128, 128), Image.BOX)
    # Only the brightest few stay stars; the rest goes back to the night, or the text
    # on top would drown.
    lum = sorted(sum(px) for px in stars.getdata())
    cut = lum[int(len(lum) * 0.965)]
    px = stars.load()
    for y in range(stars.height):
        for x in range(stars.width):
            if sum(px[x, y]) < cut:
                px[x, y] = (2, 6, 34)
    gif(stars, 12).save(os.path.join(WEB, "tile_stars.png"))
    gif(raw("web_tile_paper").resize((128, 128), Image.LANCZOS), 16).save(os.path.join(WEB, "tile_paper.png"))
    gif(raw("web_tile_wood").resize((128, 128), Image.LANCZOS), 24).save(os.path.join(WEB, "tile_wood.png"))
    print("tiles")


# ── weather icons ───────────────────────────────────────────────────────────

WX = ["sun", "suncloud", "cloud", "rain", "storm", "fog"]


def weather():
    src = raw("web_weather")
    cw, ch = src.width // 3, src.height // 2
    for i, wid in enumerate(WX):
        cell = src.crop(((i % 3) * cw, (i // 3) * ch, (i % 3 + 1) * cw, (i // 3 + 1) * ch))
        # Trim the white round the icon.
        mask = cell.convert("L").point(lambda v: 255 if v < 238 else 0)
        bb = mask.getbbox() or (0, 0, cw, ch)
        side = max(bb[2] - bb[0], bb[3] - bb[1]) + 16
        cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
        sq = Image.new("RGB", (side, side), (255, 255, 255))
        sq.paste(cell.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)), (0, 0))
        gif(sq.resize((40, 40), Image.LANCZOS), 24).save(os.path.join(WEB, "wx_%s.png" % wid))
    print("weather")


# ── photos ──────────────────────────────────────────────────────────────────

def photos():
    for art, w, q in (("web_band", 240, 38), ("web_karel", 240, 40), ("web_lake_photo", 280, 40)):
        img = raw(art)
        jpeg(img.resize((w, round(img.height * w / img.width)), Image.LANCZOS), q).save(os.path.join(WEB, art + ".png"))
    hr = raw("web_hruby").convert("L").convert("RGB")
    jpeg(hr.resize((200, round(hr.height * 200 / hr.width)), Image.LANCZOS), 45).save(os.path.join(WEB, "web_hruby.png"))
    lake = raw("web_lake_photo").resize((640, 480), Image.LANCZOS)
    jpeg(lake, 70).save(os.path.join(OS98, "wall_lake.png"))
    print("photos")


if __name__ == "__main__":
    os.makedirs(WEB, exist_ok=True)
    banners()
    tiles()
    weather()
    photos()
