"""Highways near a point (x, z in metres from the camp GPS; -z north, +x east)."""
import json
import math
import sys

sys.stdout.reconfigure(encoding="utf-8")
LAT0, LON0 = 50.0606589, 14.8477650
KX = 111320.0 * math.cos(math.radians(LAT0))
KZ = 110574.0


def xz(n):
    return ((n["lon"] - LON0) * KX, -(n["lat"] - LAT0) * KZ)


data = json.load(open(sys.argv[1], encoding="utf-8"))
cx, cz, r = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
nodes = {e["id"]: e for e in data["elements"] if e["type"] == "node"}
for w in data["elements"]:
    if w["type"] != "way":
        continue
    t = w.get("tags", {})
    if "highway" not in t and not (len(sys.argv) > 5 and any(k in t for k in sys.argv[5].split(","))):
        continue
    pts = [xz(nodes[i]) for i in w["nodes"] if i in nodes]
    if not any(math.hypot(x - cx, z - cz) < r for x, z in pts):
        continue
    key = t.get("highway") or next((k + "=" + t[k] for k in sys.argv[5].split(",") if k in t), "")
    print(w["id"], key, t.get("name", ""), t.get("ref", ""), t.get("surface", ""), t.get("lanes", ""),
          " ".join("(%d,%d)" % p for p in pts[:: max(1, len(pts) // 12)]))
