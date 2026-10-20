#!/usr/bin/env python3
"""The real land round the camp, 1:1, from OpenStreetMap: Podvinak by Cesky Brod (the
camp), road 12 east, Pristoupim, Liblice and the Liblice B masts.

    python -I tools/geo/build_world.py [tools/geo/osm/area.json]

The download (tools/geo/osm/area.json, not in git) is an Overpass export of
nwr(50.050,14.830,50.082,14.905):

    curl -A "cursed-camp-map/1.0" --data-urlencode 'data=[out:json][timeout:180];
      (nwr(50.050,14.830,50.082,14.905););out body;>;out skel qt;' \
      https://overpass-api.de/api/interpreter -o tools/geo/osm/area.json

Writes godot/data/geo/world.json: roads, the land's patches (fields, meadows, woods,
gardens), water, building footprints, trees, power lines, the bus route of line 380 and
its stops, in metres from the camp's centre (x east, z south: -z is north, as the
camp's gate and road face). scripts/geo/geo_world.gd builds the world from it.

Data (c) OpenStreetMap contributors, ODbL: the game must credit it (README; the credits
when there are some).
"""
import heapq
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "data", "geo", "world.json")
SRC = os.path.join(HERE, "osm", "area.json")

LAT0, LON0 = 50.0606589, 14.8477650
KX = 111320.0 * math.cos(math.radians(LAT0))
KZ = 110574.0

# What is built (x0, z0, x1, z1): the corridor of the route and the villages.
AREA = (-900.0, -1950.0, 3400.0, 1000.0)
# Cesky Brod is a town: only its southern edge, the part seen from road 12.
BROD = (-900.0, -1950.0, 1500.0, -700.0)
BROD_KEEP_Z = -1150.0
# The camp stays as the game has it (112 m square round the origin, its lake band and
# the gate's road): nothing of the real map is laid there.
CAMP = (-80.0, -80.0, 80.0, 95.0)
# The real road 1133 from the camp up to road 12 is the camp's own road
# (scripts/town/road_south.gd) as far as this node, the real one after it.
CAMP_ROAD_JOIN = 334442674          # (-13, -273), where "Chouranice" starts
DROP_WAYS = {289669467, 289669457}  # 1133 south of the join, Zahrady past the camp

ROAD_W = {"motorway": 9.0, "trunk": 8.5, "primary": 7.5, "secondary": 7.0, "tertiary": 6.0,
          "unclassified": 5.0, "residential": 5.0, "living_street": 4.0, "service": 3.5,
          "track": 3.0, "footway": 1.6, "path": 1.4, "cycleway": 2.0, "pedestrian": 4.0,
          "steps": 1.6, "primary_link": 6.0, "secondary_link": 5.5, "tertiary_link": 5.0}
LAND = {
    ("landuse", "farmland"): "farmland", ("landuse", "meadow"): "meadow", ("landuse", "grass"): "grass",
    ("landuse", "orchard"): "orchard", ("landuse", "forest"): "wood", ("natural", "wood"): "wood",
    ("natural", "scrub"): "scrub", ("natural", "grassland"): "meadow", ("natural", "wetland"): "wetland",
    ("landuse", "residential"): "residential", ("landuse", "industrial"): "industrial",
    ("landuse", "commercial"): "industrial", ("landuse", "retail"): "industrial",
    ("landuse", "cemetery"): "cemetery", ("landuse", "village_green"): "green",
    ("leisure", "park"): "green", ("leisure", "pitch"): "pitch", ("leisure", "playground"): "green",
    ("landuse", "allotments"): "gardens", ("landuse", "farmyard"): "farmyard", ("leisure", "garden"): "gardens",
}

# The bus stops (the user's points, 20. 10.) and the line's way through the road graph.
STOPS = {
    "pristoupim": (50.0637817, 14.8760308),
    "liblice": (50.0713692, 14.8845433),
}
# Nodes the route goes through, in order: the camp road's join, road 12 at the camp's
# junction, road 12 at Pristoupim (where 1131 leaves it), the fork for Liblice
# (Pristoupimska), Bylanska at Liblice's south end, Bylanska and Lstiborska, then
# Lstiborska east out of the map (the line goes on to Lstibor).
ROUTE_VIA = [334442674, 34595193, 30593928, 1619211674, 21055838, 21055839, 34594764, 287448982]


def xz(n):
    return ((n["lon"] - LON0) * KX, -(n["lat"] - LAT0) * KZ)


def r1(v):
    return round(v, 1)


def flat(pts):
    out = []
    for x, z in pts:
        out.append(r1(x))
        out.append(r1(z))
    return out


def inside(box, x, z):
    return box[0] <= x <= box[2] and box[1] <= z <= box[3]


def centroid(pts):
    a = 0.0
    cx = cz = 0.0
    n = len(pts)
    for i in range(n):
        x0, z0 = pts[i]
        x1, z1 = pts[(i + 1) % n]
        c = x0 * z1 - x1 * z0
        a += c
        cx += (x0 + x1) * c
        cz += (z0 + z1) * c
    if abs(a) < 1e-6:
        return (sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n)
    return (cx / (3.0 * a), cz / (3.0 * a))


def area(pts):
    s = 0.0
    for i in range(len(pts)):
        x0, z0 = pts[i]
        x1, z1 = pts[(i + 1) % len(pts)]
        s += x0 * z1 - x1 * z0
    return abs(s) * 0.5


def simplify(pts, tol):
    """Douglas-Peucker on an open polyline."""
    if len(pts) < 3:
        return pts
    def rec(a, b):
        ax, az = pts[a]
        bx, bz = pts[b]
        dx, dz = bx - ax, bz - az
        ll = math.hypot(dx, dz) or 1e-9
        best, bi = -1.0, -1
        for i in range(a + 1, b):
            px, pz = pts[i]
            d = abs((px - ax) * dz - (pz - az) * dx) / ll
            if d > best:
                best, bi = d, i
        if best > tol:
            return rec(a, bi)[:-1] + rec(bi, b)
        return [pts[a], pts[b]]
    return rec(0, len(pts) - 1)


def ring_simplify(pts, tol):
    if len(pts) > 3 and pts[0] == pts[-1]:
        pts = pts[:-1]
    if len(pts) < 4:
        return pts
    # Split the ring at its farthest point from the first and simplify both halves.
    far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    a = simplify(pts[: far + 1], tol)
    b = simplify(pts[far:] + [pts[0]], tol)
    out = a[:-1] + b[:-1]
    return out if len(out) >= 3 else pts


def assemble_rings(ways):
    """Outer member ways of a multipolygon joined end to end into closed rings."""
    segs = [list(w) for w in ways if len(w) >= 2]
    rings = []
    while segs:
        cur = segs.pop(0)
        changed = True
        while cur[0] != cur[-1] and changed:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == cur[-1]:
                    cur += s[1:]
                elif s[-1] == cur[-1]:
                    cur += list(reversed(s))[1:]
                elif s[-1] == cur[0]:
                    cur = s[:-1] + cur
                elif s[0] == cur[0]:
                    cur = list(reversed(s))[:-1] + cur
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        if cur[0] == cur[-1] and len(cur) >= 4:
            rings.append(cur)
    return rings


def main(argv):
    src = argv[0] if argv else SRC
    data = json.load(open(src, encoding="utf-8"))
    els = data["elements"]
    # The export lists some elements twice (tagged, then again bare from the recursion):
    # keep the tagged one.
    nodes = {}
    ways = {}
    for e in els:
        d = nodes if e["type"] == "node" else ways if e["type"] == "way" else None
        if d is not None and (e["id"] not in d or e.get("tags")):
            d[e["id"]] = e
    rels = [e for e in els if e["type"] == "relation"]
    P = {i: xz(n) for i, n in nodes.items()}

    def wpts(w):
        return [P[i] for i in w["nodes"] if i in P]

    def in_area(pts):
        return any(inside(AREA, x, z) for x, z in pts)

    def in_camp(pts):
        return any(inside(CAMP, x, z) for x, z in pts)

    out = {"origin": [LAT0, LON0], "roads": [], "land": [], "water": [], "streams": [], "buildings": [],
           "trees": [], "tree_rows": [], "power": [], "rails": [], "fences": []}

    # ── roads ──
    for w in ways.values():
        t = w.get("tags", {})
        hw = t.get("highway")
        if hw not in ROAD_W or w["id"] in DROP_WAYS:
            continue
        pts = wpts(w)
        if len(pts) < 2 or not in_area(pts):
            continue
        if all(inside(CAMP, x, z) for x, z in pts):
            continue
        if hw in ("footway", "path", "steps", "cycleway") and not any(inside((1650, -2000, 3300, 900), x, z) for x, z in pts):
            continue
        if hw in ("footway", "path", "steps", "cycleway") and t.get("indoor") == "yes":
            continue
        pts = simplify(pts, 0.25)
        surf = t.get("surface", "")
        dirt = hw in ("track", "path") or surf in ("unpaved", "gravel", "dirt", "ground", "grass", "compacted", "fine_gravel")
        rd = {"c": hw, "w": float(t.get("width", ROAD_W[hw])) if t.get("width", "").replace(".", "").isdigit() else ROAD_W[hw],
              "p": flat(pts), "id": w["id"]}
        if dirt:
            rd["d"] = 1
        if t.get("name"):
            rd["n"] = t["name"]
        if t.get("ref"):
            rd["r"] = t["ref"]
        if t.get("bridge") == "yes":
            rd["b"] = 1
        out["roads"].append(rd)

    # ── rails (the old yard by Cesky Brod) ──
    for w in ways.values():
        t = w.get("tags", {})
        if t.get("railway") in ("rail", "abandoned", "disused"):
            pts = wpts(w)
            if len(pts) >= 2 and in_area(pts) and not in_camp(pts):
                out["rails"].append({"p": flat(simplify(pts, 0.4)), "k": t["railway"]})

    # ── polygons: land, water, buildings (ways and multipolygon relations) ──
    polys = []   # (tags, ring points, id)
    for w in ways.values():
        if len(w["nodes"]) >= 4 and w["nodes"][0] == w["nodes"][-1]:
            polys.append((w.get("tags", {}), wpts(w), w["id"]))
    for r in rels:
        t = r.get("tags", {})
        if t.get("type") != "multipolygon":
            continue
        outers = [ways[m["ref"]]["nodes"] for m in r.get("members", []) if m["type"] == "way" and m.get("role") in ("outer", "") and m["ref"] in ways]
        for ring in assemble_rings(outers):
            polys.append((t, [P[i] for i in ring if i in P], r["id"]))

    for t, pts, pid in polys:
        if len(pts) < 4 or not in_area(pts):
            continue
        if "building" in t:
            if in_camp(pts):
                continue
            cx, cz = centroid(pts[:-1] if pts[0] == pts[-1] else pts)
            if not inside(AREA, cx, cz):
                continue
            if inside(BROD, cx, cz) and cz < BROD_KEEP_Z:
                continue
            ring = ring_simplify(pts, 0.3)
            if len(ring) < 3 or area(ring) < 6.0:
                continue
            b = {"p": flat(ring), "k": t.get("building", "yes"), "id": pid}
            if t.get("building:levels", "").isdigit():
                b["lv"] = int(t["building:levels"])
            if t.get("height", "").replace(".", "").isdigit():
                b["h"] = float(t["height"])
            if t.get("roof:shape"):
                b["rs"] = t["roof:shape"]
            if t.get("name"):
                b["n"] = t["name"]
            if t.get("amenity") or t.get("shop"):
                b["a"] = t.get("amenity") or t.get("shop")
            out["buildings"].append(b)
            continue
        if t.get("natural") == "water" or t.get("landuse") in ("reservoir", "basin"):
            ring = ring_simplify(pts, 0.6)
            if in_camp(ring):
                # Podvinak's north end is the camp's own lake: only south of it.
                ring = [(x, max(z, CAMP[3] + 2.0)) for x, z in ring]
            if area(ring) < 20.0:
                continue
            out["water"].append({"p": flat(ring), "n": t.get("name", ""), "id": pid})
            continue
        kind = None
        for k, v in t.items():
            kind = LAND.get((k, v))
            if kind:
                break
        if kind is None:
            continue
        ring = ring_simplify(pts, 0.8)
        if len(ring) < 3 or area(ring) < 30.0:
            continue
        if in_camp(ring) and kind not in ("farmland",):
            continue
        out["land"].append({"k": kind, "p": flat(ring), "id": pid})

    # ── streams, tree rows, fences, power ──
    for w in ways.values():
        t = w.get("tags", {})
        pts = wpts(w)
        if len(pts) < 2 or not in_area(pts):
            continue
        if t.get("waterway") in ("stream", "ditch", "drain", "river", "canal"):
            if not in_camp(pts):
                out["streams"].append({"p": flat(simplify(pts, 0.5)), "w": 3.0 if t["waterway"] in ("river", "canal") else 1.6, "n": t.get("name", "")})
        elif t.get("natural") == "tree_row":
            out["tree_rows"].append({"p": flat(simplify(pts, 0.5))})
        elif t.get("power") in ("line", "minor_line") and not in_camp(pts):
            poles = [P[i] for i in w["nodes"] if i in P and nodes[i].get("tags", {}).get("power") in ("tower", "pole")]
            out["power"].append({"k": t["power"], "p": flat(pts), "poles": flat(poles)})
        elif t.get("barrier") in ("fence", "wall", "hedge") and not in_camp(pts):
            if inside((1650, -2000, 3300, 900), pts[0][0], pts[0][1]):
                out["fences"].append({"k": t["barrier"], "p": flat(simplify(pts, 0.3))})

    for n in nodes.values():
        t = n.get("tags", {})
        if t.get("natural") == "tree":
            x, z = xz(n)
            if inside(AREA, x, z) and not inside(CAMP, x, z):
                out["trees"].append(r1(x))
                out["trees"].append(r1(z))

    # ── the route ──
    graph = {}
    for w in ways.values():
        t = w.get("tags", {})
        if t.get("highway") not in ("primary", "secondary", "tertiary", "unclassified", "residential", "service", "living_street"):
            continue
        if w["id"] in DROP_WAYS:
            continue
        ids = [i for i in w["nodes"] if i in P]
        for a, b in zip(ids, ids[1:]):
            d = math.dist(P[a], P[b])
            cost = d * (1.0 if t["highway"] in ("primary", "secondary", "tertiary") else 3.0)
            graph.setdefault(a, []).append((b, cost))
            if t.get("oneway") != "yes":
                graph.setdefault(b, []).append((a, cost))

    def path(a, b):
        dist = {a: 0.0}
        prev = {}
        q = [(0.0, a)]
        while q:
            d, u = heapq.heappop(q)
            if u == b:
                break
            if d > dist.get(u, 1e18):
                continue
            for v, c in graph.get(u, []):
                nd = d + c
                if nd < dist.get(v, 1e18):
                    dist[v] = nd
                    prev[v] = u
                    heapq.heappush(q, (nd, v))
        if b not in dist:
            raise SystemExit("no route %d -> %d" % (a, b))
        seq = [b]
        while seq[-1] != a:
            seq.append(prev[seq[-1]])
        return list(reversed(seq))

    seq = [ROUTE_VIA[0]]
    for a, b in zip(ROUTE_VIA, ROUTE_VIA[1:]):
        seq += path(a, b)[1:]
    route = [P[i] for i in seq]
    # Dedupe points closer than half a metre.
    clean = [route[0]]
    for p in route[1:]:
        if math.dist(p, clean[-1]) > 0.5:
            clean.append(p)
    out["route"] = flat(clean)
    out["route_nodes"] = seq

    def along(pts, q):
        """Distance along the polyline of the point nearest q, and the nearest point."""
        best = (1e18, 0.0, pts[0])
        acc = 0.0
        for a, b in zip(pts, pts[1:]):
            ax, az = a
            bx, bz = b
            dx, dz = bx - ax, bz - az
            ll = dx * dx + dz * dz
            f = 0.0 if ll < 1e-9 else max(0.0, min(1.0, ((q[0] - ax) * dx + (q[1] - az) * dz) / ll))
            px, pz = ax + dx * f, az + dz * f
            d = math.hypot(q[0] - px, q[1] - pz)
            if d < best[0]:
                best = (d, acc + f * math.sqrt(ll), (px, pz))
            acc += math.sqrt(ll)
        return best

    stops = {}
    for k, (lat, lon) in STOPS.items():
        q = ((lon - LON0) * KX, -(lat - LAT0) * KZ)
        d, s, p = along(clean, q)
        stops[k] = {"s": round(s, 1), "p": [r1(p[0]), r1(p[1])], "off": round(d, 1)}
    out["stops"] = stops
    total = sum(math.dist(a, b) for a, b in zip(clean, clean[1:]))
    out["route_len"] = round(total, 1)

    # The masts of Liblice B (RKS Liblice 2), 355 m guyed lattice, demolished 2021: their
    # footings as OSM still has them.
    masts = []
    for w in ways.values():
        t = w.get("tags", {})
        if t.get("name") == "RKS Liblice 2" and "demolished:tower:construction" in t:
            masts.append([r1(v) for v in centroid(wpts(w)[:-1])])
    out["masts"] = masts
    fuel = []
    for n in nodes.values():
        t = n.get("tags", {})
        if t.get("amenity") == "fuel":
            fuel.append({"n": t.get("name", ""), "p": [r1(v) for v in xz(n)]})
    out["fuel"] = fuel

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("roads %d, land %d, water %d, streams %d, buildings %d, trees %d, rows %d, power %d, fences %d"
          % (len(out["roads"]), len(out["land"]), len(out["water"]), len(out["streams"]), len(out["buildings"]),
             len(out["trees"]) // 2, len(out["tree_rows"]), len(out["power"]), len(out["fences"])))
    print("route %.0f m, %d points; stops %s; masts %s" % (total, len(clean), stops, masts))
    print("written", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main(sys.argv[1:])
