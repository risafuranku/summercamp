#!/usr/bin/env python3
"""Cut a Grok sprite sheet (items in a row on flat magenta) into single sprites.

    python tools/artgen/split_sheet.py <id> <scale> <dest dir relative to godot/> <name1,name2,...> [gap]

Keys out the magenta like process.py, finds the items (pixels closer than <gap> source
pixels, 14 by default, are one item: a spark beside its flame, ash beside its stub),
orders them left to right and names them in that order. Every item is scaled by the
same <scale> (output pixels per source pixel, e.g. 0.18), so the stages of one thing
keep their sizes against each other; then box-downsampled and snapped to the palette.
Prints each item's size and, for checking, writes tools/artgen/out/<id>/_cut.png with
the cut boxes drawn on the keyed sheet.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402


def items(img, gap):
    alpha = img.getchannel("A").point(lambda a: 255 if a > 40 else 0)
    # Grow every pixel by gap/2 so near bits join, then label the grown blobs.
    grown = alpha.filter(ImageFilter.MaxFilter(gap | 1))
    w, h = grown.size
    px = grown.load()
    seen = bytearray(w * h)
    boxes = []
    labels = {}
    for y0 in range(0, h):
        for x0 in range(0, w):
            if px[x0, y0] == 0 or seen[y0 * w + x0]:
                continue
            stack = [(x0, y0)]
            seen[y0 * w + x0] = 1
            members = []
            x1, y1, x2, y2 = x0, y0, x0, y0
            n = 0
            while stack:
                x, y = stack.pop()
                members.append(y * w + x)
                n += 1
                x1, y1, x2, y2 = min(x1, x), min(y1, y), max(x2, x), max(y2, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if n > 200:
                # Back to the real pixels inside the grown box.
                bb = alpha.crop((x1, y1, x2 + 1, y2 + 1)).getbbox()
                if bb:
                    box = (x1 + bb[0], y1 + bb[1], x1 + bb[2], y1 + bb[3])
                    boxes.append(box)
                    labels[box] = set(members)
    boxes.sort(key=lambda b: (b[0] + b[2]) / 2)
    return boxes, labels, w


def own(img, box, members, w):
    """The item alone: its box with every pixel of another item cleared."""
    out = img.crop(box)
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if ((box[1] + y) * w + box[0] + x) not in members:
                px[x, y] = (0, 0, 0, 0)
    return out


def shrink(img, scale):
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
    return process.snap(small, True)


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    art_id, scale, dest, names = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4].split(",")
    gap = int(sys.argv[5]) if len(sys.argv) > 5 else 14
    src = os.path.join(process.HERE, "out", art_id, "raw.png")
    img = process.key_out(Image.open(src))
    boxes, labels, w = items(img, gap)
    out_dir = os.path.join(process.GODOT, dest)
    os.makedirs(out_dir, exist_ok=True)
    check = img.copy()
    d = ImageDraw.Draw(check)
    for i, b in enumerate(boxes):
        d.rectangle(b, outline=(0, 255, 0, 255))
        d.text((b[0], max(0, b[1] - 12)), str(i), fill=(0, 255, 0, 255))
    check.save(os.path.join(process.HERE, "out", art_id, "_cut.png"))
    if len(boxes) != len(names):
        print("found %d items, %d names: see tools/artgen/out/%s/_cut.png" % (len(boxes), len(names), art_id))
        for b in boxes:
            print("  ", b)
        sys.exit(2)
    for name, b in zip(names, boxes):
        out = shrink(own(img, b, labels[b], w), scale)
        out.save(os.path.join(out_dir, name + ".png"))
        print("%s %s from %s" % (name, out.size, b))


if __name__ == "__main__":
    main()
