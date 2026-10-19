#!/usr/bin/env python3
"""Goggle Reviews' art (the PC's Reviews tab) and Builder 98's tycoon bits, from the Grok
renders in tools/artgen/out/<id>/raw.png. Runs on whatever has been generated.

    python tools/artgen/web_review_art.py
-> godot/assets/textury/os98/icons/goggle.png (+_16), padlock.png (+_16)
   godot/assets/textury/os98/web/star_full|half|empty.png       16 px rating stars
   godot/assets/textury/os98/web/spotless_banner.png           SpotlessName Ltd's banner
   godot/assets/textury/builder/think_*.png                     guests' thought bubbles
   godot/assets/textury/builder/coin.png                        the coin that flies
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import os_art  # noqa: E402
from PIL import Image  # noqa: E402

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
    img = img.convert("RGB")
    # A 1998 banner's shape (468 x 60 halved: the place's column is narrow).
    w, h = img.size
    tw = int(h * 214 / 62)
    left = max(0, (w - tw) // 2) if tw < w else 0
    img = img.crop((left, 0, min(w, left + tw), h)).resize((214, 62), Image.LANCZOS)
    img = img.quantize(colors=64, dither=Image.Dither.NONE).convert("RGB")
    d = os.path.join(G, "os98", "web")
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, "spotless_banner.png"))
    print("banner")


def main():
    icon("ico2_goggle", "goggle")
    icon("ico2_padlock", "padlock")
    web = os.path.join(G, "os98", "web")
    for k in ["full", "half", "empty"]:
        small("web_star_" + k, os.path.join(web, "star_%s.png" % k), 16)
    banner()
    for k in ["hunger", "toilet", "cold", "scared", "happy", "sleepy", "dirty"]:
        small("think_" + k, os.path.join(G, "builder", "think_%s.png" % k), 20)
    small("spr_coin", os.path.join(G, "builder", "coin.png"), 12)


if __name__ == "__main__":
    os.chdir(HERE)
    main()
