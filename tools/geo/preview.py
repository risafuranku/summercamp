"""Top-down picture of godot/data/geo/world.json (tools/geo/design_world.py makes it).

    python tools/geo/preview.py <out.png> [px per metre]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
W = json.load(open(os.path.join(HERE, "..", "..", "godot", "data", "geo", "world.json"), encoding="utf-8"))
X0, Z0, X1, Z1 = -900, -1950, 3400, 1000
S = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5   # px per metre
img = Image.new("RGB", (int((X1 - X0) * S), int((Z1 - Z0) * S)), (236, 236, 226))
d = ImageDraw.Draw(img)


def pt(x, z):
    return ((x - X0) * S, (z - Z0) * S)


def pts(f):
    return [pt(f[i], f[i + 1]) for i in range(0, len(f), 2)]


COL = {"farmland": (232, 226, 190), "meadow": (200, 226, 170), "grass": (200, 226, 170), "orchard": (180, 214, 150),
       "wood": (120, 170, 110), "scrub": (160, 190, 130), "wetland": (170, 200, 200), "residential": (240, 220, 210),
       "industrial": (220, 210, 220), "cemetery": (170, 190, 160), "green": (190, 220, 160), "pitch": (170, 220, 170),
       "gardens": (200, 220, 170), "farmyard": (225, 205, 185)}
for l in W["land"]:
    d.polygon(pts(l["p"]), fill=COL.get(l["k"], (200, 200, 200)))
for w in W["water"]:
    d.polygon(pts(w["p"]), fill=(150, 190, 230))
for s in W["streams"]:
    d.line(pts(s["p"]), fill=(120, 160, 220), width=1)
for b in W["buildings"]:
    d.polygon(pts(b["p"]), fill=(150, 130, 120))
for r in W["roads"]:
    width = max(1, int(r["w"] * S))
    d.line(pts(r["p"]), fill=(250, 170, 60) if r["c"] == "primary" else (120, 120, 120) if not r.get("d") else (170, 150, 110), width=width)
for p in W["power"]:
    d.line(pts(p["p"]), fill=(60, 60, 60), width=1)
d.line(pts(W["route"]), fill=(220, 30, 30), width=max(2, int(3 * S)))
for k, s in W["stops"].items():
    x, z = pt(*s["p"])
    d.ellipse((x - 6, z - 6, x + 6, z + 6), outline=(200, 0, 200), width=3)
for m in W["masts"]:
    x, z = pt(*m)
    d.ellipse((x - 5, z - 5, x + 5, z + 5), fill=(0, 160, 0))
x, z = pt(0, 0)
d.rectangle((x - 56 * S, z - 56 * S, x + 56 * S, z + 56 * S), outline=(0, 0, 255), width=3)
img.save(sys.argv[1])
print(img.size)
