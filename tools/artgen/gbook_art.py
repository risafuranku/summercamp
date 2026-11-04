#!/usr/bin/env python3
"""The Hruska gBook (rows in prompts_gbook.tsv): Grok's renders into the game. Missing renders
are skipped, so it can run while the queue works.

    python tools/artgen/gbook_art.py            # everything there is
    python tools/artgen/gbook_art.py laptop     # one part: laptop, icons, pear, desktop, bitmaps

-> godot/assets/textury/gbook/
   laptop.png     the close-up, the screen a hole of exactly gOS's pixels (it prints where:
                  gbook.gd HOLE_AT, PIC_SIZE), the name on the bezel in the system's own font
   <icon>.png     32 px, <icon>_16.png for the list view
   pear_*.png     the menu's pear, its pale copy for the open menu, the small white one of the
                  menus' key marks (tinted when drawn), the start-up's with a face
   desktop.png    the pattern, one repeat of it
   pointer*.png, dither.png   hand-set bitmaps: the system's pointers are pixels by nature
"""
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402
import split_sheet  # noqa: E402

GODOT = os.path.join(HERE, "..", "..", "godot")
DEST = os.path.join(GODOT, "assets", "textury", "gbook")
OUT = os.path.join(HERE, "out")
OS_SIZE = (400, 270)

SHEETS = {
    "gb_icons_a": [["hd", None, "trash_full", "folder"]],
    "gb_icons_b": [["folder_system", "doc", "panels", "key"], ["app_reader", "app_calc", "app_puzzle", "app_installer"]],
    "gb_icons_c": [["app_dialer", "cp_sound", "cp_date"], ["about", "alert_caution", "alert_stop"]],
}

POINTER = """
W..........
WW.........
WBW........
WBBW.......
WBBBW......
WBBBBW.....
WBBBBBW....
WBBBBBBW...
WBBBBBBBW..
WBBBBBBBBW.
WBBBBBWWWWW
WBBWBBW....
WBW.WBBW...
WW..WBBW...
W....WBBW..
.....WBBW..
......WW...
"""
POINTER_BUSY = """
....BBBBBBB....
....BBBBBBB....
....BBBBBBB....
...BBBBBBBBB...
..BBWWWWWWWBB..
.BBWWWWBWWWWBB.
.BWWWWWBWWWWWB.
BBWWWWWBWWWWWBB
BBWWWWWBBBBWWBBB
BBWWWWWWWWWWWBB
.BWWWWWWWWWWWB.
.BBWWWWWWWWWBB.
..BBWWWWWWWBB..
...BBBBBBBBB...
....BBBBBBB....
....BBBBBBB....
....BBBBBBB....
"""
POINTER_BEAM = """
BB.BB
..B..
..B..
..B..
..B..
..B..
..B..
..B..
..B..
..B..
..B..
..B..
..B..
BB.BB
"""


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return Image.open(p) if os.path.exists(p) else None


def save(img, name):
    os.makedirs(DEST, exist_ok=True)
    img.save(os.path.join(DEST, name + ".png"))
    print("%s %s" % (name, img.size))


def despill(img):
    """The key's cast off the black outlines (a dark purple at Grok's antialiased edges)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and r > g * 1.2 + 2 and b > g * 1.2 + 2:
                px[x, y] = (g, g, g, a)
    return img


def fit(img, size, pad=0, colours=48):
    """As the camp's icons (os_art.py): down by Lanczos, hard alpha, a limited palette."""
    img = despill(img.copy())
    k = min((size - pad * 2) / img.width, (size - pad * 2) / img.height)
    small = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - small.width) // 2, (size - small.height) // 2), small)
    a = canvas.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    rgb = canvas.convert("RGB").quantize(colors=colours, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def items_of(art_id, rows, gap=14):
    """The keyed items of a sheet in reading order, `rows` the count in each row; the biggest
    ones if Grok drew crumbs."""
    src = raw(art_id)
    if src is None:
        return None
    img = process.key_out(src)
    boxes, labels, w = split_sheet.items(img, gap)
    wanted = sum(rows)
    if len(boxes) < wanted:
        print("%s: %d items found, %d wanted; skipped" % (art_id, len(boxes), wanted))
        return None
    boxes = sorted(boxes, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:wanted]
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    ordered = []
    for n in rows:
        row, boxes = boxes[:n], boxes[n:]
        ordered += sorted(row, key=lambda b: b[0])
    return [split_sheet.own(img, b, labels[b], w) for b in ordered]


def icons():
    for art_id, rows in SHEETS.items():
        parts = items_of(art_id, [len(r) for r in rows])
        if parts is None:
            continue
        for name, part in zip([n for r in rows for n in r], parts):
            if name is None:
                continue
            save(fit(part, 32, 1), name)
            save(fit(part, 16), name + "_16")


def grid_down(img, step, off):
    """A picture of pixels back to its own pixels (measured on the render): the middle of each."""
    w, h = img.size
    cols = int((w - off) / step)
    rows = int((h - off) / step)
    out = Image.new("RGBA", (cols, rows), (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(rows):
        for x in range(cols):
            r, g, b, a = src[int(off + (x + 0.5) * step), int(off + (y + 0.5) * step)]
            dst[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return out.crop(out.getchannel("A").getbbox())


def pear():
    parts = items_of("gb_pear", [2])
    if parts is None:
        return
    logo, face = parts
    menu = fit(logo, 13, 0, 16)
    bbox = menu.getchannel("A").getbbox()
    menu = menu.crop(bbox)
    save(menu, "pear_menu")
    # The open menu's black behind it: the outline white, the fruit lit.
    inv = menu.copy()
    ip = inv.load()
    for y in range(inv.height):
        for x in range(inv.width):
            r, g, b, a = ip[x, y]
            if a:
                ip[x, y] = (240, 239, 232, a) if max(r, g, b) < 70 else (min(255, r + 46), min(255, g + 46), min(255, b + 46), a)
    save(inv, "pear_menu_inv")
    # The key mark, one flat colour: the menu tints it.
    mark = fit(logo, 10, 0, 16)
    mark = mark.crop(mark.getchannel("A").getbbox())
    flat = Image.new("RGBA", mark.size, (255, 255, 255, 0))
    flat.putalpha(mark.getchannel("A"))
    save(flat, "pear_key")
    save(grid_down(face, 6.51, 1.63), "pear_face")


def _font_glyphs(path):
    glyphs = {}
    for m in re.finditer(r"char id=(\d+)\s+x=(\d+)\s+y=(\d+)\s+width=(\d+)\s+height=(\d+)\s+xoffset=(-?\d+)\s+yoffset=(-?\d+)\s+xadvance=(\d+)", open(path, encoding="utf-8").read()):
        glyphs[int(m.group(1))] = tuple(int(v) for v in m.groups()[1:])
    return glyphs


def stamp(img, text, x, y, ink, shine):
    """`text` pressed into the plastic, in the system's bold font (the bitmap's own pixels)."""
    fnt = os.path.join(GODOT, "assets", "fonts", "w95b.fnt")
    page = Image.open(fnt[:-4] + ".png").convert("RGBA").getchannel("A")
    glyphs = _font_glyphs(fnt)
    px = img.load()
    pp = page.load()
    cx = x
    for ch in text:
        g = glyphs.get(ord(ch))
        if g is None:
            continue
        gx, gy, gw, gh, ox, oy, adv = g
        for j in range(gh):
            for i in range(gw):
                if pp[gx + i, gy + j] > 128:
                    px[cx + ox + i + 1, y + oy + j + 1] = shine
        for j in range(gh):
            for i in range(gw):
                if pp[gx + i, gy + j] > 128:
                    px[cx + ox + i, y + oy + j] = ink
        cx += adv


def edge_dark(img, side, top, bottom):
    w, h = img.size
    px = img.load()
    for y in range(h):
        for x in range(w):
            k = min(1.0, min(x, w - 1 - x) / side, y / top, (h - 1 - y) / bottom)
            if k < 1.0:
                k = k ** 1.4
                r, g, b = px[x, y]
                px[x, y] = (int(r * k), int(g * k), int(b * k))
    return img


def laptop():
    src = raw("gb_laptop")
    if src is None:
        return
    img = src.convert("RGB")
    w, h = img.size
    px = img.load()
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 200 and b > 200 and g < 70:
                xs.append(x)
                ys.append(y)
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    # The key and its blended rim to black first: no purple line round the screen.
    for y in range(max(0, y0 - 4), min(h, y1 + 4)):
        for x in range(max(0, x0 - 4), min(w, x1 + 4)):
            r, g, b = px[x, y]
            if r > 90 and b > 90 and g < 80 and abs(r - b) < 80:
                px[x, y] = (8, 8, 9)
    sx = OS_SIZE[0] / (x1 - x0)
    sy = OS_SIZE[1] / (y1 - y0)
    size = (round(w * sx), round(h * sy))
    small = img.resize(size, Image.Resampling.BOX)
    # The room goes dark round the picture: no edge where a window is bigger than it.
    small = edge_dark(small, 40, 14, 10)
    pic = process.snap(small, False).convert("RGBA")
    hx, hy = round(x0 * sx), round(y0 * sy)
    # The name on the bezel left of the pear, as such machines have it.
    stamp(pic, "Hruška gBook", hx + 6, hy + OS_SIZE[1] + 15, (74, 70, 60, 255), (190, 184, 166, 255))
    # The lip round the panel, black all the way (the key's rim snaps to a dark red).
    lip = Image.new("RGBA", (OS_SIZE[0] + 4, OS_SIZE[1] + 4), (10, 10, 12, 255))
    pic.paste(lip, (hx - 2, hy - 2))
    hole = Image.new("RGBA", OS_SIZE, (0, 0, 0, 0))
    pic.paste(hole, (hx, hy))
    save(pic, "laptop")
    print("HOLE_AT := Vector2i(%d, %d)  PIC_SIZE := Vector2i(%d, %d)" % (hx, hy, size[0], size[1]))


def bitmap(art, name, colours):
    rows = art.strip("\n").split("\n")
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours:
                px[x, y] = colours[ch]
    save(img, name)


def bitmaps():
    ink = {"B": (18, 17, 20, 255), "W": (240, 239, 232, 255)}
    bitmap(POINTER, "pointer", ink)
    bitmap(POINTER_BUSY, "pointer_busy", ink)
    bitmap(POINTER_BEAM, "pointer_beam", ink)
    d = Image.new("RGB", (2, 2), (118, 117, 122))
    d.putpixel((1, 0), (86, 85, 90))
    d.putpixel((0, 1), (86, 85, 90))
    save(d, "dither")


def desktop():
    """One repeat of the pattern: Grok's pear out of its rows (the render's spacing is uneven
    and it does not tile), on the system's own one-pixel checker, the rows staggered."""
    src = raw("gb_desktop")
    if src is None:
        return
    # The pear in the render's clean row, between its neighbours (96 x 136 px a repeat).
    cell = src.convert("L").crop((432, 482, 528, 618))
    cw, ch = 24, 34
    # Its checker ground averaged away first: what is left dark is the pear.
    small = cell.resize((cw, ch), Image.Resampling.BOX)
    lo, hi = small.getextrema()
    cut = lo + (hi - lo) * 0.55
    mask = small.point(lambda v: 255 if v < cut else 0)
    ground_a, ground_b, fruit = (104, 118, 96), (90, 104, 84), (66, 80, 62)
    tile = Image.new("RGB", (cw, ch * 2))
    px = tile.load()
    mp = mask.load()
    for y in range(ch * 2):
        for x in range(cw):
            px[x, y] = ground_a if (x + y) % 2 == 0 else ground_b
            sx = x if y < ch else (x + cw // 2) % cw
            if mp[sx, y % ch]:
                px[x, y] = fruit
    save(tile, "desktop")


PARTS = {"laptop": laptop, "icons": icons, "pear": pear, "desktop": desktop, "bitmaps": bitmaps}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(PARTS):
        PARTS[name]()
