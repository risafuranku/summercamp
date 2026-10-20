#!/usr/bin/env python3
"""The businesses' polish art (rows in prompts_podniky.tsv, written by podniky_prompts.py)
from tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/podniky_art.py [id ...]     (all when none are given)

- the hands at the stations: every frame was rendered twice (<id>, <id>_b); PICK says
  which one was chosen by hand (no second neck, no bare hand, no pose that makes no
  sense), processed to the hands' pixel (hands_lo/, ~VIRTUAL_LINES 200: a hand at a
  station is about half the view high) as hands_lo/st_<name>.png;
- the sheets of things on magenta, cut apart left to right, each shrunk to its own size
  and snapped to the palette (see pub_art.py);
- the stations' Build pictures (16:9 textures).
A missing render is skipped with a note.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")
HL = "assets/textury/hands_lo/"
C = "assets/textury/corn/"
UI = "assets/textury/ui/"

# A hand at a station is drawn smaller than the hands out in the camp (hand7_* are 100):
# it must not hide the counter it works on.
HAND_H = 88
# Hand frames: render id -> (file, the variant picked: "" or "_b").
HANDS = {
    "pk_hand_open": ("st_open", ""),
    "pk_hand_grab": ("st_grab", ""),
    "pk_hand_press": ("st_press", ""),
    "pk_hand_tongs": ("st_tongs", ""),
    "pk_hand_tongs_cob": ("st_tongs_cob", ""),
    "pk_hand_brush": ("st_brush", ""),
    "pk_hand_brush_stroke": ("st_brush_stroke", ""),
    "pk_hand_salt": ("st_salt", ""),
    "pk_hand_salt_shake": ("st_salt_shake", ""),
    "pk_hand_husk": ("st_husk", ""),
    "pk_hand_cup": ("st_cup", ""),
    "pk_hand_cup_tea": ("st_cup_tea", ""),
}
# Hand sheets of two frames (rest, act): render id -> (rest file, act file, the variant
# picked). Both frames get one scale (the taller to HAND_H) so the hand keeps its size.
PAIRS = {
    "pk_hs_tap": ("st_tap", "st_tap_act", ""),
    "pk_hs_bottle": ("st_bottle", "st_bottle_act", ""),
    "pk_hs_wash": ("st_wash", "st_wash_act", ""),
    "pk_hs_pencil": ("st_pencil", "st_pencil_act", ""),
    "pk_hs_coin": ("st_coin", "st_coin_act", ""),
    "pk_hs_dart": ("st_dart", "st_dart_act", ""),
    "pk_hs_ladle": ("st_ladle", "st_ladle_act", ""),
    "pk_hs_opener": ("st_opener", "st_opener_act", ""),
    "pk_hs_knife": ("st_knife", "st_knife_act", ""),
    "pk_hs_wrap": ("st_wrap", "st_wrap_act", ""),
}
# (render id, [(file under godot/, longer side px), ...] left to right)
SHEETS = [
    ("pk_cts_drinks", [(C + "drink_barrel.png", 40), (C + "drink_bottle.png", 32), (C + "cup_empty.png", 12),
                       (C + "cup_tea.png", 12), (C + "bag_empty.png", 15), (C + "bag_limo.png", 16),
                       (C + "stream_tea.png", 12), (C + "stream_limo.png", 12)]),
    ("pk_pot_boil", [(C + "boil_0.png", 52), (C + "boil_1.png", 52), (C + "boil_2.png", 52)]),
]
J = "assets/textury/jednota/"
B = "assets/textury/bistro/"
P = "assets/textury/pub/"
CAMP = "assets/textury/camp/"
FOOD = "assets/textury/closeup/food/"
SHEETS += [
    ("pk_jts_goods", [(J + "goods_cigs.png", 22), (J + "goods_rum.png", 44), (J + "goods_cards.png", 20),
                      (J + "goods_magazine.png", 36), (J + "goods_parcel.png", 30)]),
    ("pk_jts_deli", [(J + "deli_salami.png", 60), (J + "deli_salami_slices.png", 26), (J + "deli_cheese.png", 44),
                     (J + "deli_cheese_slices.png", 28), (J + "deli_bread.png", 52), (J + "deli_bread_half.png", 48),
                     (J + "parcel.png", 34), (J + "deli_knife.png", 60)]),
    ("pk_bts_grill", [(B + "sausage_raw.png", 34), (B + "sausage_half.png", 34), (B + "sausage_done.png", 34),
                      (B + "sausage_burnt.png", 34), (B + "food_mustard.png", 12), (B + "food_bread.png", 20),
                      (B + "mustard_jar.png", 22), (B + "bread_basket.png", 34)]),
    ("pk_bts_bufet", [(B + "bowl_empty.png", 26), (B + "bowl_soup.png", 26), (B + "bottle_kofola.png", 44),
                      (B + "bottle_kofola_open.png", 44), (B + "bottle_malinovka.png", 44), (B + "bottle_malinovka_open.png", 44),
                      (B + "bottle_cap.png", 6), (B + "opener.png", 20)]),
    ("pk_ps_slot", [(CAMP + "pub_slot.png", 136), (P + "slot_lever.png", 30)]),
    ("pk_ps_reels", [(P + "reel_seven.png", 14), (P + "reel_cherry.png", 14), (P + "reel_bell.png", 14),
                     (P + "reel_lemon.png", 14), (P + "reel_bar.png", 14), (P + "reel_plum.png", 14)]),
    ("pk_ps_darts", [(P + "dart_side.png", 16), (P + "dart_fly.png", 8), (P + "dart_stuck.png", 10)]),
    ("pk_ps_cards", [(P + "card_back.png", 16), (P + "card_7.png", 16), (P + "card_8.png", 16), (P + "card_9.png", 16),
                     (P + "card_10.png", 16), (P + "card_unter.png", 16), (P + "card_ober.png", 16), (P + "card_king.png", 16),
                     (P + "card_ace.png", 16)]),
    ("pk_ps_wallet", [(P + "wallet.png", 34), (CAMP + "dartboard_clean.png", 56)]),
]
# The marks on the slips (16 px) cut from the same sheets: (render id, index, file, px).
MARKS = [
    ("pk_cts_drinks", 3, UI + "mark_tea.png", 14),
    ("pk_cts_drinks", 5, UI + "mark_limo.png", 16),
    # The bistro's tickets' pictures (bistro_station ICONS), 16 px.
    ("pk_bts_grill", 2, FOOD + "icon_sausage.png", 16),
    ("pk_bts_grill", 4, FOOD + "icon_mustard.png", 10),
    ("pk_bts_grill", 5, FOOD + "icon_bread.png", 12),
    ("pk_bts_bufet", 1, FOOD + "icon_soup.png", 16),
    ("pk_bts_bufet", 2, FOOD + "icon_kofola.png", 16),
    ("pk_bts_bufet", 4, FOOD + "icon_malinovka.png", 16),
]
# The stations' Build pictures: (render id, file, width px: the bistro's PANEL_W, the top
# of the counter in the render when Grok drew it in perspective with its front: its four
# corners upper left, lower left, lower right, upper right, or None).
TEXTURES = [
    ("pk_ct_drinks", C + "st_drinks.png", 0, (0, 62, 0, 590, 1280, 590, 1280, 62)),
    ("pk_bt_grill", B + "st_grill.png", 0, (86, 64, 10, 566, 1270, 566, 1196, 64)),
    ("pk_bt_bufet", B + "st_bufet.png", 0, None),
    ("pk_jt_deli", J + "st_deli.png", 0, (0, 68, 0, 608, 1280, 608, 1280, 68)),
]


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return p if os.path.exists(p) else None


def save(img, dest):
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("  ->", dest, img.size)


def hands(only):
    for art_id, (name, pick) in HANDS.items():
        if only and art_id not in only:
            continue
        src = raw(art_id + pick)
        if src is None:
            print("missing", art_id + pick)
            continue
        save(process.sprite(src, HAND_H), HL + name + ".png")


def pairs(only):
    for art_id, (rest, act, pick) in PAIRS.items():
        if only and art_id not in only:
            continue
        got = cut(art_id + pick)
        if got is None:
            print("missing", art_id + pick)
            continue
        img, boxes = got
        if len(boxes) < 2:
            print("  %s: %d pieces, not 2 (look at the render)" % (art_id + pick, len(boxes)))
            continue
        # The two biggest pieces, left to right (crumbs of spray or a coin are dropped).
        boxes = sorted(sorted(boxes, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]), reverse=True)[:2], key=lambda b: b[0])
        tallest = max(b[3] - b[1] for b in boxes)
        for box, name in zip(boxes, (rest, act)):
            piece = img.crop(box)
            longest = max(piece.width, piece.height) * HAND_H / tallest
            save(shrink(piece, longest), HL + name + ".png")


def cut(art_id):
    src = raw(art_id)
    if src is None:
        return None
    img = process.key_out(Image.open(src))
    boxes, _labels, _w = split_sheet.items(img, 14)
    return img, boxes


def shrink(piece, longest):
    k = longest / max(piece.width, piece.height)
    w = max(1, round(piece.width * k))
    h = max(1, round(piece.height * k))
    r, g, b, a = piece.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", piece.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, h), Image.Resampling.BOX)
    px = small.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                kk = 255.0 / pa
                px[x, y] = (min(255, int(pr * kk)), min(255, int(pg * kk)), min(255, int(pb * kk)), 255 if pa > 110 else 0)
    return process.snap(small, True)


def sheets(only):
    for art_id, outs in SHEETS:
        if only and art_id not in only:
            continue
        got = cut(art_id)
        if got is None:
            print("missing", art_id)
            continue
        img, boxes = got
        if len(boxes) != len(outs):
            print("  %s: %d pieces for %d names (look at out/%s/_cut.png)" % (art_id, len(boxes), len(outs), art_id))
        for box, (dest, longest) in zip(boxes, outs):
            save(shrink(img.crop(box), longest), dest)
    for art_id, idx, dest, longest in MARKS:
        if only and art_id not in only:
            continue
        got = cut(art_id)
        if got is None or idx >= len(got[1]):
            continue
        img, boxes = got
        save(shrink(img.crop(boxes[idx]), longest), dest)


def textures(only):
    for art_id, dest, width, top in TEXTURES:
        if only and art_id not in only:
            continue
        src = raw(art_id)
        if src is None:
            print("missing", art_id)
            continue
        # The bistro's way (bistro_art.buildify): shrunk, roughened, snapped.
        import bistro_art  # noqa: E402
        img = Image.open(src).convert("RGB")
        if top is not None:
            # Only the top, unwarped to the station's 16:9.
            img = img.transform((1280, 720), Image.Transform.QUAD, top, Image.Resampling.BICUBIC)
        small = img.resize((bistro_art.PANEL_W, round(img.height * bistro_art.PANEL_W / img.width)), Image.Resampling.BOX)
        save(process.snap(bistro_art.buildify(small, 12), False), dest)


def main():
    only = set(sys.argv[1:])
    hands(only)
    pairs(only)
    sheets(only)
    textures(only)


if __name__ == "__main__":
    main()
