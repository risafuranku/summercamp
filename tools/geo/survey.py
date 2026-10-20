"""Quick survey of the downloaded OSM area: what is there (counts, named things, POIs)."""
import json
import math
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

LAT0, LON0 = 50.0606589, 14.8477650
KX = 111320.0 * math.cos(math.radians(LAT0))
KZ = 110574.0


def xz(lat, lon):
    return ((lon - LON0) * KX, -(lat - LAT0) * KZ)


data = json.load(open(sys.argv[1], encoding="utf-8"))
els = data["elements"]
nodes = {e["id"]: e for e in els if e["type"] == "node"}
ways = [e for e in els if e["type"] == "way"]
rels = [e for e in els if e["type"] == "relation"]
print("nodes", len(nodes), "ways", len(ways), "relations", len(rels))
c = Counter()
for w in ways:
    t = w.get("tags", {})
    for k in ("highway", "building", "landuse", "natural", "waterway", "railway", "power", "man_made", "amenity", "barrier", "leisure"):
        if k in t:
            c[(k, t[k] if k != "building" else ("yes" if t[k] == "yes" else t[k]))] += 1
for k, v in sorted(c.items(), key=lambda kv: -kv[1])[:60]:
    print(v, k)
print("--- tagged nodes (POIs)")
pc = Counter()
for n in nodes.values():
    t = n.get("tags", {})
    for k in ("highway", "amenity", "shop", "man_made", "power", "natural", "place", "tourism", "historic"):
        if k in t:
            pc[(k, t[k])] += 1
for k, v in sorted(pc.items(), key=lambda kv: -kv[1])[:40]:
    print(v, k)
print("--- places, stops, fuel, masts, named water")
for n in nodes.values():
    t = n.get("tags", {})
    if t.get("place") or t.get("highway") == "bus_stop" or t.get("amenity") in ("fuel", "pub", "restaurant", "place_of_worship") or t.get("man_made") in ("mast", "tower") or t.get("shop"):
        x, z = xz(n["lat"], n["lon"])
        print("%-9s %-14s %-30s %7.0f %7.0f" % (n["type"], t.get("place") or t.get("highway") or t.get("amenity") or t.get("man_made") or "shop:" + t.get("shop", ""), t.get("name", "")[:30], x, z), {k: v for k, v in t.items() if k in ("height", "ref", "operator", "brand")})
for w in ways:
    t = w.get("tags", {})
    if (t.get("natural") == "water" or t.get("amenity") in ("fuel",) or t.get("man_made") in ("mast", "tower") or t.get("landuse") in ("cemetery",) or t.get("historic") or t.get("tourism") or t.get("amenity") == "place_of_worship") :
        pts = [nodes[i] for i in w["nodes"] if i in nodes]
        if not pts:
            continue
        cx = sum(xz(p["lat"], p["lon"])[0] for p in pts) / len(pts)
        cz = sum(xz(p["lat"], p["lon"])[1] for p in pts) / len(pts)
        print("way      %-14s %-30s %7.0f %7.0f" % (t.get("natural") or t.get("amenity") or t.get("man_made") or t.get("landuse") or t.get("historic") or t.get("tourism"), t.get("name", "")[:30], cx, cz), {k: v for k, v in t.items() if k in ("height", "water", "brand", "operator")})
