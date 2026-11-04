#!/usr/bin/env python3
"""The chapel's candle up close and the Benzina's toilet (prompts_chapel2.tsv, the user's
words of 4. 11.): Grok's renders into the game, godot/assets/textury/camp/candle_* and
wc_*. Missing renders are skipped, so it can run while the queue works.

    python tools/artgen/chapel2_art.py            # everything there is
    python tools/artgen/chapel2_art.py <id> ...   # only these renders

Rows: (artgen id, mode, size, file under godot/assets/textury/). Modes are process.py's
(texture, panel, sprite) and:
  plate   the picture for the whole 320 x 276 plate of a close-up with no strip under it
          (candle_closeup.gd): cut at `size` = the band of the raw to keep (top, bottom)
          and brought to the palette;
  scaled  a sheet of things in a row on magenta, all at ONE scale, so the stages of a
          thing keep their sizes against each other: size = (scale, [files], gap);
  fire    the same for flames: not snapped to the palette (it has no bright yellow: they
          came out tan), 24 colours of their own, the edge hard;
  fit     a sheet in a row, each brought to its own height: size = [(file, height), ...];
  match   the match's stages: Grok keeps the burnt stick's whole length as charcoal, so the
          burnt ones are cut down (the ember and a bit of black over what is left of
          the wood) and the frames really get shorter; all on one canvas width with the
          stick in its middle, their feet level;
  thin    a sheet of fine scratches, cut by columns (the strokes of one mark do not touch):
          size = (height, [(file, x0, x1), ...]), the lines thickened before shrinking.
"""
import os
import sys

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402
import split_sheet  # noqa: E402
import mesto_art  # noqa: E402

TEX = os.path.join(HERE, "..", "..", "godot", "assets", "textury")
OUT = os.path.join(HERE, "out")
PLATE = (320, 276)
LEAN_RIGHT = ("candle_flame_5", "candle_flame_6")

ROWS = [
    # The candle up close.
    ("candle_cu_bg", "plate", (95, 978), "camp/candle_closeup.png"),
    ("candle_cu_hand_pinch", "sprite", 250, "camp/candle_hand_pinch.png"),
    ("candle_cu_hand_open", "sprite", 250, "camp/candle_hand_open.png"),
    ("candle_cu_hand_box", "sprite", 190, "camp/candle_hand_box.png"),
    ("sheet_candle_match", "match", 0.16, None),
    ("sheet_candle_mflames", "fire", (0.12, ["candle_mflame_%d" % i for i in range(5)], 44), None),
    ("sheet_candle_cflames", "fire", (0.12, ["candle_flame_%d" % i for i in range(7)], 14), None),
    ("sheet_candle_smoke", "scaled", (0.14, ["candle_smoke_%d" % i for i in range(3)], 14), None),
    ("sheet_candle_small", "fit", [("camp/candle_coin.png", 14), ("camp/candle_own.png", 46)], None),
    ("spr_candle_stand", "sprite", 112, "camp/candle_stand.png"),
    # The Benzina's toilet.
    ("face_wc_door_out", "panel", 96, "camp/wc_door_out.png"),
    ("face_wc_door_in", "panel", 96, "camp/wc_door_in.png"),
    ("tex_wc_tiles", "texture", 128, "camp/wc_tiles.png"),
    ("tex_wc_floor", "texture", 128, "camp/wc_floor.png"),
    ("tex_wc_ceiling", "texture", 128, "camp/wc_ceiling.png"),
    ("face_wc_window", "panel", 56, "camp/wc_window.png"),
    ("spr_wc_toilet", "sprite", 96, "camp/wc_toilet.png"),
    ("spr_wc_cistern", "sprite", 64, "camp/wc_cistern.png"),
    ("spr_wc_basin", "sprite", 60, "camp/wc_basin.png"),
    ("sheet_wc_wall", "fit", [("camp/wc_mirror.png", 56), ("camp/wc_dryer.png", 44), ("camp/wc_roll.png", 22)], None),
    ("sheet_wc_light", "fit", [("camp/wc_switch_off.png", 16), ("camp/wc_switch_on.png", 16), ("camp/wc_bulb_off.png", 48), ("camp/wc_bulb_on.png", 48)], None),
    ("sheet_wc_scratch", "thin", (64, [("camp/wc_scratch_0.png", 70, 300), ("camp/wc_scratch_1.png", 370, 590), ("camp/wc_scratch_2.png", 660, 890), ("camp/wc_scratch_3.png", 950, 1225)]), None),
    ("sheet_wc_fly", "fit", [("camp/wc_fly_0.png", 6), ("camp/wc_fly_1.png", 6), ("camp/wc_fly_side.png", 6)], None),
    ("spr_wc_mop", "sprite", 112, "camp/wc_mop.png"),
]


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return p if os.path.exists(p) else None


def save(img, dest):
    path = os.path.join(TEX, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("%s %s" % (dest, img.size))


def sprite(src, height):
    """process.py's sprite with the key's rim taken off at Grok's size first: its edges are
    blended into the magenta, and the pixels shrunk from them came out red."""
    img = process.key_out(Image.open(src))
    img.putalpha(img.getchannel("A").filter(ImageFilter.MinFilter(5)))
    return mesto_art.keyed_item(img, height)


def plate(src, band, dest):
    img = Image.open(src).convert("RGB")
    img = img.crop((0, band[0], img.width, band[1])).resize(PLATE, Image.Resampling.BOX)
    save(process.snap(img, False), dest)


def fire_shrink(img, scale):
    """split_sheet.shrink without the palette: box-downsampled, 24 colours, hard alpha."""
    w = max(1, round(img.width * scale))
    h = max(1, round(img.height * scale))
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, h), Image.Resampling.BOX)
    px = small.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    out = small.convert("RGB").quantize(colors=24, dither=Image.Dither.NONE).convert("RGBA")
    out.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 110 else 0))
    return out


def scaled(art_id, spec, shrink=split_sheet.shrink):
    scale, names, gap = spec
    src = raw(art_id)
    if src is None:
        return
    img = process.key_out(Image.open(src))
    boxes, labels, sw = split_sheet.items(img, gap)
    boxes.sort(key=lambda b: b[0])
    if len(boxes) != len(names):
        print("%s: %d items found, %d wanted: skipped" % (art_id, len(boxes), len(names)))
        for b in boxes:
            print("  ", b)
        return
    for name, b in zip(names, boxes):
        small = shrink(split_sheet.own(img, b, labels[b], sw), scale)
        # The bent flames lean to the right of the picture: the door is that way from the rack.
        if name in LEAN_RIGHT:
            small = small.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        save(small, "camp/%s.png" % name)


def match_frames(art_id, scale):
    """candle_match_0..4 and _spent: see `match` above."""
    src = raw(art_id)
    if src is None:
        return
    img = process.key_out(Image.open(src))
    boxes, labels, sw = split_sheet.items(img, 14)
    boxes.sort(key=lambda b: b[0])
    if len(boxes) != 6:
        print("%s: %d items found, 6 wanted: skipped" % (art_id, len(boxes)))
        return
    top = min(b[1] for b in boxes)
    foot = max(b[3] for b in boxes)
    half = 70
    names = ["candle_match_%d" % i for i in range(5)] + ["candle_match_spent"]
    for i, (name, b) in enumerate(zip(names, boxes)):
        item = split_sheet.own(img, b, labels[b], sw)
        canvas = Image.new("RGBA", (b[2] - b[0] + 2 * half, foot - top), (0, 0, 0, 0))
        canvas.alpha_composite(item, (half, b[1] - top))
        # The wood's middle, from the last rows of the stick: the frame's middle.
        px = canvas.load()
        row = canvas.height - 6
        xs = [x for x in range(canvas.width) if px[x, row][3] > 128]
        cx = (min(xs) + max(xs) + 1) // 2
        frame = canvas.crop((cx - half, 0, cx + half, canvas.height))
        if i in (2, 3, 4):
            # Where the wood begins, down the stick's middle.
            px = frame.load()
            wood = frame.height - 1
            for y in range(frame.height - 1, 0, -1):
                r, g, b2, a = px[half, y]
                if a < 128 or r + g + b2 < 300:
                    wood = y
                    break
            head = 58
            cut = Image.new("RGBA", (frame.width, head + frame.height - wood + 14), (0, 0, 0, 0))
            cut.alpha_composite(frame.crop((0, 0, frame.width, head)), (0, 0))
            cut.alpha_composite(frame.crop((0, wood - 14, frame.width, frame.height)), (0, head))
            frame = cut
        small = split_sheet.shrink(frame, scale)
        # The key's purple in the charcoal's edge: black again.
        px = small.load()
        for y in range(small.height):
            for x in range(small.width):
                r, g, b2, a = px[x, y]
                if a > 0 and b2 > g + 10 and r > g + 4:
                    px[x, y] = (g, g, g, a)
        save(small, "camp/%s.png" % name)


def thin(art_id, spec):
    height, parts = spec
    src = raw(art_id)
    if src is None:
        return
    img = process.key_out(Image.open(src))
    for dest, x0, x1 in parts:
        crop = img.crop((x0, 0, x1, img.height))
        bbox = crop.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
        crop = crop.crop(bbox)
        fat = crop.getchannel("A").filter(ImageFilter.MaxFilter(3))
        pale = Image.new("RGBA", crop.size, (214, 206, 186, 255))
        pale.putalpha(fat)
        save(mesto_art.keyed_item(pale, height), dest)


def main():
    only = sys.argv[1:]
    for art_id, mode, size, dest in ROWS:
        if only and art_id not in only:
            continue
        src = raw(art_id)
        if src is None:
            continue
        if mode == "plate":
            plate(src, size, dest)
        elif mode == "match":
            match_frames(art_id, size)
        elif mode == "thin":
            thin(art_id, size)
        elif mode == "scaled":
            scaled(art_id, size)
        elif mode == "fire":
            scaled(art_id, size, fire_shrink)
        elif mode == "fit":
            mesto_art.do_sheet(art_id, [(p, h) for p, h in size])
        elif mode == "sprite":
            save(sprite(src, size), dest)
        elif mode == "panel":
            save(process.panel(src, size), dest)
        else:
            save(process.texture(src, size), dest)


if __name__ == "__main__":
    main()
