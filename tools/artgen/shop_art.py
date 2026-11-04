#!/usr/bin/env python3
"""Liblice's shops, the counter and paying (prompts_shop.tsv): Grok's renders into the game.
Missing renders are skipped, so it can run while the queue works.

    python tools/artgen/shop_art.py            # everything there is
    python tools/artgen/shop_art.py <id> ...   # only these rows

Modes are process.py's (sprite, panel, texture), mesto_art.py's sheets, and:
  money    the notes (top row) and the coins (bottom row) of sheet_pay_money;
  till     the Jednota's till with a dark window for the sum in its top box;
  tags     the blank price tag with each price written on it, in both languages;
  kiosk    the kiosk counter's own front, without what its picture stands on it;
  laminate the counter's top made to tile (ground_tex.py), for the rooms' counters;
  hand     the hand with the match: the render put a black glove on it, the warden has none;
  photos   the Bulletin's photographs, printed: a column wide, ordered dots in the paper's ink.
Everything lands in godot/assets/textury/shop/, the bag's icons in items/.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ground_tex  # noqa: E402
import mesto_art  # noqa: E402
import process  # noqa: E402
import split_sheet  # noqa: E402

TEX = mesto_art.TEX

ROWS = [
    # The close-up at the counter.
    ("spr_pay_wallet", "sprite", 112, "shop/pay_wallet.png"),
    ("spr_pay_tray", "sprite", 86, "shop/pay_mat.png"),
    ("face_pay_counter", "panel", 320, "shop/pay_counter.png"),
    ("face_pay_counter", "laminate", 128, "shop/laminate.png"),
    ("face_pay_till", "panelcrop", (150, 0.0, 0.49), "shop/pay_till.png"),
    ("spr_pay_hand", "sprite", 150, "shop/pay_hand.png"),
    ("sheet_pay_money", "money", None, None),
    # What is for sale.
    ("sheet_shop_goods", "sheet", [("shop/good_matches.png", 20), ("shop/good_candle.png", 26), ("shop/good_newspaper.png", 40)], None),
    ("sheet_shop_display", "sheet", [("shop/matches_tray.png", 24), ("shop/candle_carton.png", 30), ("shop/battery_box.png", 26), ("shop/tag_blank.png", 28)], None),
    ("spr_newspaper_rack", "sprite", 128, "shop/newspaper_rack.png"),
    ("spr_kofola_crate", "sprite", 64, "shop/kofola_crate.png"),
    ("face_fridge_kofola", "panel", 80, "shop/fridge_kofola.png"),
    ("sheet_kiosk_counter", "sheet", [("shop/kiosk_till.png", 56), ("shop/kiosk_rack.png", 44), ("shop/kiosk_papers.png", 22)], None),
    # The bag and the paper.
    ("sheet_inv_goods", "sheet", [("items/matches.png", 14), ("items/candle.png", 18), ("items/bread.png", 15), ("items/kofola.png", 18), ("items/newspaper.png", 17)], None),
    ("tex_newsprint", "texture", 320, "shop/newsprint.png"),
    ("sheet_news_photos", "photos", 94, None),
    ("spr_match_hand", "hand", 96, "shop/hand_match.png"),
]

# The dark window painted on the Jednota's till (shop_till.png px: x0, y0, x1, y1).
TILL_WINDOW = (21, 9, 46, 15)
# The numbers on the tags: a pen's 3 x 5 pixels; the comma and the dash of a Czech price.
GLYPHS = dict(mesto_art.DIGITS)
GLYPHS["$"] = ["010", "111", "110", "011", "111"]
GLYPHS[","] = ["0", "0", "0", "1", "1"]
GLYPHS["-"] = ["000", "000", "111", "000", "000"]
PEN = (24, 36, 92, 255)
PRICES = {1: ("$1", "10,-"), 2: ("$2", "20,-"), 3: ("$3", "30,-")}
# Where the card is on the tag sprite: the height of its top edge, the writing's rows.
TAG_TEXT_Y = 9


def own_colours(crop, height, colours=40):
    """A cut item like mesto_art.keyed_item, without the palette: the money's greens and blues
    are not in it (the notes came out four greys). The rim of the key colour goes first, at
    Grok's size."""
    crop = crop.copy()
    crop.putalpha(crop.getchannel("A").filter(ImageFilter.MinFilter(9)))
    bbox = crop.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    if bbox:
        crop = crop.crop(bbox)
    w = max(1, round(crop.width * height / crop.height))
    r, g, b, a = crop.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", crop.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, height), Image.Resampling.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    out = small.convert("RGB").quantize(colors=colours, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(alpha)
    return out


def do_money():
    src = mesto_art.raw("sheet_pay_money")
    if src is None:
        return
    img = process.key_out(Image.open(src))
    boxes, labels, sw = split_sheet.items(img, 14)
    boxes = [b for b in boxes if (b[2] - b[0]) * (b[3] - b[1]) > 3000]
    notes = sorted([b for b in boxes if (b[2] - b[0]) > (b[3] - b[1]) * 1.3], key=lambda b: b[0])
    coins = sorted([b for b in boxes if (b[2] - b[0]) <= (b[3] - b[1]) * 1.3], key=lambda b: b[0])
    print("money: %d notes, %d coins" % (len(notes), len(coins)))
    for dest, h, box in zip(["shop/note_5.png", "shop/note_10.png", "shop/note_20.png", "shop/note_50.png"], [33] * 4, notes):
        mesto_art.save(own_colours(split_sheet.own(img, box, labels[box], sw), h), dest)
    for dest, h, box in zip(["shop/coin_1.png", "shop/coin_2.png"], [24, 24], coins):
        mesto_art.save(own_colours(split_sheet.own(img, box, labels[box], sw), h), dest)


def do_till():
    """The till with its window: the sum is laid on it in the game (counter_shop.gd)."""
    src = os.path.join(TEX, "camp", "shop_till.png")
    img = Image.open(src).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rectangle(TILL_WINDOW, fill=(7, 8, 8, 255))
    d.rectangle((TILL_WINDOW[0] - 1, TILL_WINDOW[1] - 1, TILL_WINDOW[2] + 1, TILL_WINDOW[3] + 1), outline=(78, 70, 58, 255))
    mesto_art.save(img, "shop/till.png")


def write(img, text, y):
    glyphs = [GLYPHS[c] for c in text]
    width = sum(len(g[0]) + 1 for g in glyphs) - 1
    x = (img.width - width) // 2
    px = img.load()
    for g in glyphs:
        for r, row in enumerate(g):
            for c, on in enumerate(row):
                if on == "1":
                    px[x + c, y + r] = PEN
        x += len(g[0]) + 1


def do_tags():
    src = os.path.join(TEX, "shop", "tag_blank.png")
    if not os.path.exists(src):
        return
    blank = Image.open(src).convert("RGBA")
    for price, (en, cs) in PRICES.items():
        for text, suffix in ((en, ""), (cs, "_cs")):
            img = blank.copy()
            write(img, text, TAG_TEXT_Y)
            mesto_art.save(img, "shop/tag_%d%s.png" % (price, suffix))


def do_laminate(src, size, dest):
    """The top of the render (no metal edge), square, tiling, for world-mapped counters."""
    img = Image.open(src).convert("RGB")
    s = round(img.height * 0.84)
    x0 = (img.width - s) // 2
    img = ground_tex.tileable(img.crop((x0, 0, x0 + s, s)).resize((size * 2, size * 2), Image.Resampling.BOX))
    mesto_art.save(process.snap(img.resize((size, size), Image.Resampling.BOX), False), dest)


# The black glove on the render: a polygon round it (render px); inside it what is dark and
# grey goes to the hand's own tan, the outlines stay.
GLOVE = [(345, 590), (470, 370), (590, 270), (760, 330), (900, 420), (900, 600), (640, 830), (560, 790), (345, 640)]


def do_hand(src, height, dest):
    img = Image.open(src).convert("RGBA")
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(GLOVE, fill=255)
    px = img.load()
    m = mask.load()
    for y in range(img.height):
        for x in range(img.width):
            if not m[x, y]:
                continue
            r, g, b, a = px[x, y]
            hi, lo = max(r, g, b), min(r, g, b)
            lum = (r * 3 + g * 6 + b) / 10.0
            if lum > 100 or (hi - lo) > 34 or lum < 16:
                continue
            t = min(1.0, max(0.0, (lum - 16.0) / 60.0))
            px[x, y] = (int(70 + t * 122), int(46 + t * 90), int(16 + t * 44), a)
    tmp = os.path.join(mesto_art.OUT, "spr_match_hand", "tan.png")
    img.save(tmp)
    mesto_art.save(process.sprite(tmp, height), dest)


# The print: ink and paper of the page, 4 x 4 Bayer dots over five greys.
INK = (38, 35, 32)
PAPER = (206, 196, 172)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def do_photos(art_id, width):
    src = mesto_art.raw(art_id)
    if src is None:
        return
    img = process.key_out(Image.open(src))
    boxes, labels, sw = split_sheet.items(img, 14)
    boxes = sorted(boxes, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:3]
    boxes.sort(key=lambda b: b[0])
    for i, box in enumerate(boxes):
        # Inside the white border Grok gave each print.
        inset = round((box[2] - box[0]) * 0.03)
        crop = img.crop((box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)).convert("L")
        height = round(crop.height * width / crop.width)
        small = crop.resize((width, height), Image.Resampling.BOX)
        out = Image.new("RGB", small.size)
        px, dst = small.load(), out.load()
        for y in range(height):
            for x in range(width):
                v = px[x, y] / 255.0 * 4.0
                level = int(v) + (1 if (v - int(v)) > (BAYER[y % 4][x % 4] + 0.5) / 16.0 else 0)
                t = min(level, 4) / 4.0
                dst[x, y] = tuple(round(INK[k] + (PAPER[k] - INK[k]) * t) for k in range(3))
        mesto_art.save(out, "shop/news_photo_%d.png" % i)


def do_kiosk():
    """The kiosk's counter picture has its things drawn on it: only the front below them."""
    src = os.path.join(TEX, "camp", "kiosk_counter.png")
    img = Image.open(src).convert("RGB")
    w, h = img.size
    mesto_art.save(img.crop((0, round(h * 0.60), round(w * 0.76), h)), "shop/kiosk_front.png")


def main():
    only = sys.argv[1:]
    for art_id, mode, size, dest in ROWS:
        if only and art_id not in only:
            continue
        if mode == "money":
            do_money()
            continue
        if mode == "sheet":
            mesto_art.do_sheet(art_id, size)
            continue
        if mode == "photos":
            do_photos(art_id, size)
            continue
        src = mesto_art.raw(art_id)
        if src is None:
            continue
        if mode == "panelcrop":
            img = Image.open(src).convert("RGB")
            band = img.crop((0, round(img.height * size[1]), img.width, round(img.height * size[2])))
            mesto_art.save(mesto_art.panel_img(band, size[0]), dest)
        elif mode == "laminate":
            do_laminate(src, size, dest)
        elif mode == "hand":
            do_hand(src, size, dest)
        elif mode == "sprite":
            mesto_art.save(process.sprite(src, size), dest)
        elif mode == "panel":
            mesto_art.save(process.panel(src, size), dest)
        else:
            mesto_art.save(process.texture(src, size), dest)
    if not only:
        do_till()
        do_tags()
        do_kiosk()


if __name__ == "__main__":
    main()
