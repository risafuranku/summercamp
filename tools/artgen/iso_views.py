#!/usr/bin/env python3
"""The Builder's four views of a building, from the camp's own 3D model.

    python tools/artgen/iso_views.py sheet <type> [<type> ...]
    python tools/artgen/iso_views.py cut <grok id> <type>
    python tools/artgen/iso_views.py raw <type> [<type> ...]

godot/tools/iso_render.tscn draws each building from the four corners the map turns to
(tools/artgen/out/iso3d/<type>_v<0-3>.png, 768 px canvases, 128 px across a tile's
diagonal, the footprint's middle at the canvas's middle).

sheet: the four views on one 2x2 sheet on magenta (v0 v1 / v2 v3), each scaled up by one
       factor so the biggest fills most of its quarter; written to
       out/iso3d/<type>_ref.png as the reference for the Grok row iso4_<type>_a/_b.
cut:   Grok's repaint of that sheet back into four sprites (and the windows that light at
       night, <type>_<v>_win.png, from the render's window pass, cut to the same box): each quarter keyed, its
       drawn part fitted over the render's drawn part (the same box, so the size, the
       ground and the footprint stay the model's), snapped to the palette; written to
       godot/assets/textury/builder/iso3d/<type>_<v>.png with the anchor (where the
       footprint's middle is in the picture) in iso3d/views.json.
sheet4 <name> <t1..t4>: four small things on one sheet, a row each (iso4_<name>), and
cut4 <grok id> <t1..t4> back; for the decor, where one Grok picture does four.
raw:   the same from the render itself (no Grok), for checking or as a stand-in.
frames <type> <n>: a moving thing's frames from the render (the flag waving): each
       view's n frames cut to one box, <type>_<v>_f<k>.png.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

SRC = os.path.join(process.HERE, "out", "iso3d")
DEST = os.path.join(process.GODOT, "assets", "textury", "builder", "iso3d")
INDEX = os.path.join(DEST, "views.json")
SHEET = 1024
Q = SHEET // 2
FILL = 0.74
MAGENTA = (255, 0, 255, 255)


def render(t, v):
    return Image.open(os.path.join(SRC, "%s_v%d.png" % (t, v))).convert("RGBA")


def bbox(img):
    return img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()


def layout(t):
    """Each view's box in its render and the one whole-number scale for the sheet."""
    boxes = [bbox(render(t, v)) for v in range(4)]
    big = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
    return boxes, Q * FILL / big


def sheet(t):
    boxes, k = layout(t)
    out = Image.new("RGBA", (SHEET, SHEET), MAGENTA)
    for v in range(4):
        b = boxes[v]
        crop = render(t, v).crop(b)
        crop = crop.resize((round(crop.width * k), round(crop.height * k)), Image.Resampling.LANCZOS)
        qx, qy = (v % 2) * Q, (v // 2) * Q
        at = (qx + (Q - crop.width) // 2, qy + (Q - crop.height) // 2)
        out.alpha_composite(crop, at)
    path = os.path.join(SRC, "%s_ref.png" % t)
    out.convert("RGB").save(path)
    print("%s -> %s (x%.1f)" % (t, path, k))


def biggest_part(img):
    """The keyed quarter's drawn part: every piece of it (a chair beside the caravan, the
    tow bar), not the specks Grok leaves round its edges."""
    a = img.getchannel("A").point(lambda x: 255 if x > 40 else 0)
    w, h = a.size
    px = a.load()
    seen = bytearray(w * h)
    parts = []
    for y0 in range(h):
        for x0 in range(w):
            if px[x0, y0] == 0 or seen[y0 * w + x0]:
                continue
            stack = [(x0, y0)]
            seen[y0 * w + x0] = 1
            n = 0
            x1, y1, x2, y2 = x0, y0, x0, y0
            while stack:
                x, y = stack.pop()
                n += 1
                x1, y1, x2, y2 = min(x1, x), min(y1, y), max(x2, x), max(y2, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            parts.append((n, (x1, y1, x2 + 1, y2 + 1)))
    if not parts:
        return None
    big = max(p[0] for p in parts)
    keep = [p[1] for p in parts if p[0] >= max(40, big * 0.01)]
    return (min(b[0] for b in keep), min(b[1] for b in keep), max(b[2] for b in keep), max(b[3] for b in keep))


def shrink(img, size):
    """Box-downsample with premultiplied alpha (as process.sprite does)."""
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize(size, Image.Resampling.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return small


def save_view(t, v, sprite, box):
    """`sprite` covers the render's box `box`: written trimmed, with its anchor."""
    os.makedirs(DEST, exist_ok=True)
    snapped = process.snap(sprite, True)
    tb = snapped.getchannel("A").getbbox() or (0, 0, 1, 1)
    snapped = snapped.crop(tb)
    name = "%s_%d.png" % (t, v)
    snapped.save(os.path.join(DEST, name))
    # The windows that light at night, cut to the same box (iso_render's _win pass).
    win_src = os.path.join(SRC, "%s_v%d_win.png" % (t, v))
    if os.path.exists(win_src):
        win = Image.open(win_src).convert("RGBA").crop((box[0] + tb[0], box[1] + tb[1], box[0] + tb[2], box[1] + tb[3]))
        a = win.getchannel("A").point(lambda x: 255 if x > 40 else 0)
        if a.getbbox():
            out = Image.new("RGBA", win.size, (255, 255, 255, 0))
            out.putalpha(a)
            out.save(os.path.join(DEST, "%s_%d_win.png" % (t, v)))
    canvas = render(t, v).size
    ax = canvas[0] * 0.5 - (box[0] + tb[0])
    ay = canvas[1] * 0.5 - (box[1] + tb[1])
    index = {}
    if os.path.exists(INDEX):
        with open(INDEX, encoding="utf-8") as f:
            index = json.load(f)
    index["%s_%d" % (t, v)] = {"anchor": [round(ax, 1), round(ay, 1)], "size": list(snapped.size)}
    with open(INDEX, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print("%s v%d -> %s %s anchor %.0f,%.0f" % (t, v, name, snapped.size, ax, ay))


def cut(art_id, t):
    boxes, _k = layout(t)
    raw = process.key_out(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png")))
    hw, hh = raw.width // 2, raw.height // 2
    for v in range(4):
        q = raw.crop(((v % 2) * hw, (v // 2) * hh, (v % 2 + 1) * hw, (v // 2 + 1) * hh))
        part = biggest_part(q)
        if part is None:
            print("%s v%d: nothing drawn" % (t, v))
            continue
        b = boxes[v]
        drawn = q.crop(part)
        save_view(t, v, shrink(drawn, (b[2] - b[0], b[3] - b[1])), b)


def sheet4(name, types):
    """Four small things on one sheet: a row each, its four views across (v0..v3)."""
    cell = SHEET // 4
    big = 1
    for t in types:
        for v in range(4):
            b = bbox(render(t, v))
            big = max(big, b[2] - b[0], b[3] - b[1])
    out = Image.new("RGBA", (SHEET, SHEET), MAGENTA)
    for r, t in enumerate(types):
        boxes = [bbox(render(t, v)) for v in range(4)]
        tb = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
        k = cell * FILL / tb
        for v in range(4):
            crop = render(t, v).crop(boxes[v])
            crop = crop.resize((max(1, round(crop.width * k)), max(1, round(crop.height * k))), Image.Resampling.LANCZOS)
            out.alpha_composite(crop, (v * cell + (cell - crop.width) // 2, r * cell + (cell - crop.height) // 2))
    path = os.path.join(SRC, "%s_ref.png" % name)
    out.convert("RGB").save(path)
    print("%s -> %s" % (",".join(types), path))


def cut4(art_id, types):
    raw = process.key_out(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png")))
    cw, ch = raw.width // 4, raw.height // 4
    for r, t in enumerate(types):
        boxes, _k = layout(t)
        for v in range(4):
            q = raw.crop((v * cw, r * ch, (v + 1) * cw, (r + 1) * ch))
            part = biggest_part(q)
            if part is None:
                print("%s v%d: nothing drawn" % (t, v))
                continue
            b = boxes[v]
            save_view(t, v, shrink(q.crop(part), (b[2] - b[0], b[3] - b[1])), b)


def frames(t, n):
    """A moving thing's frames (iso_render's <type>_v<v>_f<k>), each view's frames cut to one
    box so they stand still against each other: <type>_<v>_f<k>.png."""
    for v in range(4):
        imgs = [Image.open(os.path.join(SRC, "%s_v%d_f%d.png" % (t, v, k))).convert("RGBA") for k in range(n)]
        boxes = [bbox(i) for i in imgs]
        box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
        for k in range(n):
            snapped = process.snap(imgs[k].crop(box), True)
            name = "%s_%d_f%d" % (t, v, k)
            snapped.save(os.path.join(DEST, name + ".png"))
            canvas = imgs[k].size
            index = {}
            if os.path.exists(INDEX):
                with open(INDEX, encoding="utf-8") as f:
                    index = json.load(f)
            index[name] = {"anchor": [round(canvas[0] * 0.5 - box[0], 1), round(canvas[1] * 0.5 - box[1], 1)], "size": list(snapped.size)}
            with open(INDEX, "w", encoding="utf-8") as f:
                json.dump(index, f, indent=1, sort_keys=True)
        print("%s v%d: %d frames %s" % (t, v, n, box))


def raw_views(t):
    for v in range(4):
        img = render(t, v)
        b = bbox(img)
        save_view(t, v, img.crop(b), b)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "sheet":
        for t in sys.argv[2:]:
            sheet(t)
    elif sys.argv[1] == "cut":
        cut(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "sheet4":
        sheet4(sys.argv[2], sys.argv[3:7])
    elif sys.argv[1] == "cut4":
        cut4(sys.argv[2], sys.argv[3:7])
    elif sys.argv[1] == "frames":
        frames(sys.argv[2], int(sys.argv[3]))
    elif sys.argv[1] == "raw":
        for t in sys.argv[2:]:
            raw_views(t)


if __name__ == "__main__":
    main()
