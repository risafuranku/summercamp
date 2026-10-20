#!/usr/bin/env python3
"""Goggle Reviews' art (the PC's Reviews tab) and Builder 98's tycoon bits, from the Grok
renders in tools/artgen/out/<id>/raw.png. Runs on whatever has been generated.

    python tools/artgen/web_review_art.py
-> godot/assets/textury/os98/icons/goggle.png (+_16), padlock.png (+_16)
   godot/assets/textury/os98/web/star_full|half|empty.png       16 px rating stars
   godot/assets/textury/os98/web/spotless_banner.png           SpotlessName Ltd's banner
   godot/assets/textury/builder/think_*.png (24 px)             guests' thought bubbles
   godot/assets/textury/builder/coin.png                        the coin that flies
   godot/assets/textury/builder/site_scaffold|site_worker_*|rubble.png   the building site
   godot/assets/textury/builder/tb2_music_on|off, tb2_graphs, cur_blueprint, diploma.png
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import os_art  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

G = os_art.GODOT


def icon(art_id, name):
    img = os_art.keyed(art_id)
    if img is None:
        return
    d = os.path.join(G, "os98", "icons")
    os_art.fit(img, 32, 1).save(os.path.join(d, name + ".png"))
    os_art.fit(img, 16).save(os.path.join(d, name + "_16.png"))
    print("icon", name)


def small(art_id, dest, size):
    img = os_art.keyed(art_id)
    if img is None:
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    os_art.fit(img, size).save(dest)
    print("small", os.path.basename(dest))


def banner():
    img = os_art.raw("web_spotless_banner")
    if img is None:
        return
    src = img.convert("RGB")
    # The render is 16:9 inside its own frame; the place's column is 214 wide, so the
    # banner is 214 x 98: the frame off, a band through the broom and the cloud kept.
    W, H = 214, 98
    out = src.crop((40, 92, 1240, 642)).resize((W, H), Image.LANCZOS)
    # The pitch goes on the empty right side: calmer stripes there, so the words read.
    calm = Image.new("RGB", (W, H), (255, 252, 226))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rectangle((int(W * 0.43), 4, W - 5, H - 5), fill=175)
    out = Image.composite(calm, out, mask)
    # A frame like the render's: blue, yellow blocks along it.
    d = ImageDraw.Draw(out)
    blue, gold = (44, 52, 168), (238, 196, 64)
    d.rectangle((0, 0, W - 1, H - 1), outline=blue, width=3)
    for x in range(6, W - 6, 14):
        d.rectangle((x, 0, x + 6, 2), fill=gold)
        d.rectangle((x, H - 3, x + 6, H - 1), fill=gold)
    for y in range(6, H - 6, 14):
        d.rectangle((0, y, 2, y + 6), fill=gold)
        d.rectangle((W - 3, y, W - 1, y + 6), fill=gold)
    out = out.quantize(colors=64, dither=Image.Dither.NONE).convert("RGB")
    d = os.path.join(G, "os98", "web")
    os.makedirs(d, exist_ok=True)
    out.save(os.path.join(d, "spotless_banner.png"))
    print("banner")


def iso(art_id, dest, height, unpink=False):
    """A building-site sprite for Builder 98's map: keyed, cropped to what is drawn,
    `height` pixels tall, hard alpha, a 1998 palette (the map scales it like the others)."""
    img = os_art.keyed(art_id)
    if img is None:
        return
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if unpink and r > 150 and g < 120 and b > 100:
                # Specks of the magenta backdrop left in the sawdust.
                px[x, y] = (0, 0, 0, 0)
            elif r > g + 26 and b > g + 16:
                # The backdrop's tint on the edges and in the smoke: back to grey.
                v = (g * 2 + min(r, b)) // 3
                px[x, y] = (v, v, v, a)
    w = max(1, round(img.width * height / img.height))
    small = img.resize((w, height), Image.LANCZOS)
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    rgb = small.convert("RGB").quantize(colors=64, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(a)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    out.save(dest)
    print("iso", os.path.basename(dest), out.size)


def main():
    icon("ico2_goggle", "goggle")
    icon("ico2_padlock", "padlock")
    web = os.path.join(G, "os98", "web")
    for k in ["full", "half", "empty"]:
        small("web_star_" + k, os.path.join(web, "star_%s.png" % k), 16)
    banner()
    for k in ["hunger", "toilet", "cold", "scared", "happy", "sleepy", "dirty"]:
        small("think_" + k, os.path.join(G, "builder", "think_%s.png" % k), 24)
    small("spr_coin", os.path.join(G, "builder", "coin.png"), 12)
    b = os.path.join(G, "builder")
    iso("iso_scaffold", os.path.join(b, "site_scaffold.png"), 128)
    iso("iso_rubble", os.path.join(b, "rubble.png"), 112, unpink=True)
    iso("iso_worker_a", os.path.join(b, "site_worker_a.png"), 64)
    iso("iso_worker_a2", os.path.join(b, "site_worker_a2.png"), 64, unpink=True)
    iso("iso_worker_b", os.path.join(b, "site_worker_b.png"), 52, unpink=True)
    pair_frames(os.path.join(b, "site_worker_a.png"), os.path.join(b, "site_worker_a2.png"))
    # The toolbar's music and graphs buttons (32 px like the other tb2_ icons), the
    # blueprint beside the pointer (24 px), the district's diploma (its paper, no words).
    for n in ["music_on", "music_off", "graphs"]:
        k = os_art.keyed("tb2_" + n)
        if k is not None:
            os_art.fit(k, 32, 1).save(os.path.join(b, "tb2_%s.png" % n))
            print("tb2", n)
    small("cur_blueprint", os.path.join(b, "cur_blueprint.png"), 24)
    dip = os_art.raw("diploma_blank")
    if dip is not None:
        dip = dip.convert("RGB").resize((240, 320), Image.LANCZOS)
        dip.quantize(colors=96, dither=Image.Dither.NONE).convert("RGB").save(os.path.join(b, "diploma.png"))
        print("diploma")


def _helmet(img):
    """The yellow hard hat's box (it is the same hat in both frames)."""
    px = img.load()
    xs, ys = [], []
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and r > 200 and g > 160 and b < 90:
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs), max(ys)) if xs else None


def _boot(img):
    """Where the kneeling worker's back boot touches the ground: the leftmost drawn
    pixel of the lower half, and the lowest drawn pixel near it."""
    a = img.getchannel("A").load()
    w, h = img.size
    for x in range(w):
        col = [y for y in range(h // 2, h) if a[x, y]]
        if col:
            return x, max(col)
    return 0, h - 1


def pair_frames(path_a, path_b):
    """Two frames of one worker from two renders: frame b scaled so the hats match,
    both on one canvas with the back boot on the same spot, so the map only swaps them."""
    if not (os.path.exists(path_a) and os.path.exists(path_b)):
        return
    fa = Image.open(path_a).convert("RGBA")
    fb = Image.open(path_b).convert("RGBA")
    ha, hb = _helmet(fa), _helmet(fb)
    if ha and hb:
        k = (ha[2] - ha[0] + 1) / float(hb[2] - hb[0] + 1)
        fb = fb.resize((max(1, round(fb.width * k)), max(1, round(fb.height * k))), Image.NEAREST)
    ba, bb = _boot(fa), _boot(fb)
    # Canvas big enough for both with the boots on one point.
    left = max(ba[0], bb[0])
    down = max(fa.height - ba[1], fb.height - bb[1])
    top = max(ba[1], bb[1])
    right = max(fa.width - ba[0], fb.width - bb[0])
    W, H = left + right, top + down
    for img, boot, path in ((fa, ba, path_a), (fb, bb, path_b)):
        c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        c.alpha_composite(img, (left - boot[0], top - boot[1]))
        c.save(path)
    print("pair", os.path.basename(path_a), os.path.basename(path_b), (W, H))


if __name__ == "__main__":
    os.chdir(HERE)
    main()
