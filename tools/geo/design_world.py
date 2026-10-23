"""The land round the camp, designed by hand: godot/data/geo/world.json.

No map data goes in (the user, 23. 10.: "not from OpenStreetMap, so it does not have to
go in the credits"): the bus route is drawn through the user's own points (20. 10.: the
camp 50.0606589 N 14.8477650 E, the Pristoupim stop 50.0637817 N 14.8760308 E, the
Liblice stop 50.0713692 N 14.8845433 E, and his red line on the map: up from the camp to
road 12, east along it, north at Pristoupim to the stop at the fork, north-east past the
ponds up to Liblice) and the long stretches are half as long as the real ones ("the road
from the camp is far too long, shorten the main road by half"). Along road 12 there are
fields and nothing else ("away with the houses left and right of the main road"); the
houses are the game's own villages (town_lesna.gd, hamlet_podlesi.gd). The rest is made
up the way that country looks from a bus: big JZD fields, balks, a wood on the hill, the
brook with its alders, two ponds, the masts of Liblice B behind their fence, a line of
pylons, cherry alleys along the side roads.

    python -I tools/geo/design_world.py          (then tools/geo/preview.py to look)

Coordinates: metres from the camp's centre, x east, z south (the camp's gate faces
north, to road 12). The schema is the one scripts/geo/geo_data.gd and geo_world.gd read.
"""
import json
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "data", "geo", "world.json")
rng = random.Random(380)

# The world the land fills (geo_world.gd AREA).
AREA = (-900.0, -1950.0, 3400.0, 1000.0)
# The camp's own ground (its map, lake and forest road): no fields laid over it.
CAMP_ZONE = (-130.0, -280.0, 150.0, 175.0)


# ── geometry ─────────────────────────────────────────────────────────────────

def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def mul(a, k):
    return (a[0] * k, a[1] * k)


def length(a):
    return math.hypot(a[0], a[1])


def norm(a):
    n = length(a)
    return (a[0] / n, a[1] / n) if n > 1e-9 else (0.0, 0.0)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def fillet(points, radii, step=4.0):
    """A polyline through `points` whose corners are circular arcs of `radii` (one per
    point, the ends' ignored): the straights stay straight."""
    out = [points[0]]
    for i in range(1, len(points) - 1):
        p0, p, p1 = points[i - 1], points[i], points[i + 1]
        u = norm(sub(p, p0))
        v = norm(sub(p1, p))
        turn = math.atan2(cross(u, v), dot(u, v))
        r = radii[i]
        if abs(turn) < 1e-3 or r <= 0:
            out.append(p)
            continue
        t = r * math.tan(abs(turn) * 0.5)
        lim = 0.45 * min(length(sub(p, p0)), length(sub(p1, p)))
        if t > lim:
            r *= lim / t
            t = lim
        a = sub(p, mul(u, t))
        side = 1.0 if turn > 0 else -1.0
        # The centre: from the arc's start, square to the way in, towards the turn.
        centre = add(a, mul((-u[1] * side, u[0] * side), r))
        a0 = math.atan2(a[1] - centre[1], a[0] - centre[0])
        n = max(2, int(math.ceil(abs(turn) * r / step)))
        for k in range(n + 1):
            ang = a0 + turn * k / n
            out.append((centre[0] + r * math.cos(ang), centre[1] + r * math.sin(ang)))
    out.append(points[-1])
    return out


def offset_line(line, off):
    """The polyline `off` metres to its right (x east, z south: right of the way it goes)."""
    out = []
    for i, p in enumerate(line):
        a = line[max(0, i - 1)]
        b = line[min(len(line) - 1, i + 1)]
        d = norm(sub(b, a))
        out.append((p[0] - d[1] * off, p[1] + d[0] * off))
    return out


def arc_lengths(line):
    s = [0.0]
    for i in range(1, len(line)):
        s.append(s[-1] + length(sub(line[i], line[i - 1])))
    return s


def project(line, q):
    """Distance along `line` of the point nearest q, and how far off it is."""
    best = (0.0, 1e18)
    acc = 0.0
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        ab = sub(b, a)
        ll = dot(ab, ab)
        f = 0.0 if ll < 1e-9 else max(0.0, min(1.0, dot(sub(q, a), ab) / ll))
        d = length(sub(q, add(a, mul(ab, f))))
        if d < best[1]:
            best = (acc + f * math.sqrt(ll), d)
        acc += math.sqrt(ll)
    return best


def point_at(line, s):
    """The point `s` metres along and the heading there."""
    acc = 0.0
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        seg = length(sub(b, a))
        if acc + seg >= s or i == len(line) - 2:
            f = 0.0 if seg < 1e-9 else max(0.0, min(1.0, (s - acc) / seg))
            return add(a, mul(sub(b, a), f)), norm(sub(b, a))
        acc += seg
    return line[-1], (1.0, 0.0)


def seg_dist(q, a, b):
    ab = sub(b, a)
    ll = dot(ab, ab)
    f = 0.0 if ll < 1e-9 else max(0.0, min(1.0, dot(sub(q, a), ab) / ll))
    return length(sub(q, add(a, mul(ab, f))))


def line_dist(q, line):
    return min(seg_dist(q, line[i], line[i + 1]) for i in range(len(line) - 1))


def in_poly(q, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        a, b = poly[i], poly[j]
        if (a[1] > q[1]) != (b[1] > q[1]) and q[0] < (b[0] - a[0]) * (q[1] - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
        j = i
    return inside


def frame(origin, d, local):
    """A point given in a frame at `origin` whose +x is `d` (+z its right) into the world."""
    right = (-d[1], d[0])
    return add(origin, add(mul(d, local[0]), mul(right, local[1])))


def rect_in(origin, d, x0, z0, x1, z1):
    return [frame(origin, d, c) for c in [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]]


def blob(c, rx, rz, yaw, n=18, wob=0.12):
    """A pond's or a wood's outline: an ellipse with a ragged edge."""
    out = []
    cy, sy = math.cos(yaw), math.sin(yaw)
    for k in range(n):
        a = math.tau * k / n
        w = 1.0 + rng.uniform(-wob, wob)
        x, z = math.cos(a) * rx * w, math.sin(a) * rz * w
        out.append((c[0] + x * cy - z * sy, c[1] + x * sy + z * cy))
    return out


def flat(pts):
    out = []
    for p in pts:
        out += [round(p[0], 1), round(p[1], 1)]
    return out


# ── the roads ────────────────────────────────────────────────────────────────

# Up from where the camp's forest road (road_south.gd) ends to road 12.
R0 = (-13.2, -273.3)
C1 = (0.0, -302.0)
J = (26.3, -335.5)                 # the camp's turn off road 12 (the Benzina by it)
# Road 12, a long gentle sweep east (half the real stretch).
M = [(150.0, -287.0), (330.0, -238.0), (560.0, -205.0), (820.0, -182.0)]
T = (1110.0, -160.0)               # Pristoupim's turn north off road 12
T2 = (1112.0, -212.0)
A1 = (1060.0, -288.0)              # the straight past the Pristoupim stop ...
P = (1020.0, -330.0)               # ... the stop (the user's point, the stretch halved)
B1 = (981.0, -371.0)               # the fork: on north-east for Liblice, north-west for Brod
D = [(1010.0, -440.0), (1075.0, -525.0), (1165.0, -600.0), (1260.0, -660.0)]
Q = (1338.0, -690.7)               # the junction at the foot of Liblice
L = (1327.6, -759.9)               # the Liblice stop (on the straight Q-N)
N = (1293.6, -987.4)               # the far end of the village street, east for Lstibor
E = [(1340.0, -1012.0), (1480.0, -1042.0), (1620.0, -1062.0)]

ROUTE_PTS = [R0, C1, J] + M + [T, T2, A1, B1] + D + [Q, N] + E
ROUTE_R = [0, 40, 18, 500, 600, 800, 800, 16, 30, 60, 20, 120, 200, 200, 200, 30, 25, 25, 200, 0]
ROUTE = fillet(ROUTE_PTS, ROUTE_R)

ROAD12 = fillet([(-1500.0, -930.0), (-760.0, -640.0), (-420.0, -515.0), (-180.0, -420.0), J] + M
                + [T, (1400.0, -135.0), (1800.0, -110.0), (2300.0, -90.0), (3500.0, -55.0)],
                [0, 900, 900, 700, 0, 500, 600, 800, 800, 0, 800, 900, 900, 0])
CAMP_LINK = fillet([R0, C1, J], [0, 40, 0])
SIDE = fillet([T, T2, A1, B1] + D + [Q, N] + E, [0, 30, 60, 20, 120, 200, 200, 200, 30, 25, 25, 200, 0])
BROD = fillet([B1, (900.0, -455.0), (780.0, -580.0), (600.0, -760.0), (380.0, -990.0), (150.0, -1300.0)], [0, 200, 300, 300, 400, 0])
SOUTH = fillet([T, (1115.0, -40.0), (1125.0, 120.0), (1140.0, 330.0), (1170.0, 1100.0)], [0, 300, 400, 500, 0])
EAST_Q = fillet([Q, (1460.0, -668.0), (1640.0, -640.0), (1900.0, -610.0), (2600.0, -560.0)], [0, 300, 400, 500, 0])
NORTH_N = fillet([N, (1275.0, -1110.0), (1255.0, -1260.0), (1220.0, -1500.0)], [0, 200, 300, 0])
MASTS = [(1396.0, -243.0), (1412.0, -301.0)]
MAST_ROAD = fillet([T2, (1250.0, -232.0), (1352.0, -262.0)], [0, 150, 0])
TRACKS = [
    fillet([(480.0, -216.0), (490.0, -60.0), (470.0, 150.0), (440.0, 420.0)], [0, 300, 300, 0]),
    fillet([(700.0, -195.0), (692.0, -300.0), (690.0, -380.0)], [0, 200, 0]),
    fillet([(820.0, -182.0), (835.0, 40.0), (900.0, 260.0)], [0, 300, 0]),
    fillet([(1165.0, -600.0), (1090.0, -700.0), (1040.0, -820.0)], [0, 150, 0]),
    fillet([(-420.0, -515.0), (-390.0, -300.0), (-330.0, -60.0)], [0, 300, 0]),
    fillet([(1800.0, -110.0), (1830.0, 150.0), (1880.0, 420.0)], [0, 300, 0]),
]

roads = [
    {"c": "primary", "w": 7.5, "p": flat(ROAD12), "n": "12"},
    {"c": "tertiary", "w": 6.0, "p": flat(CAMP_LINK), "n": "Zahrady"},
    {"c": "secondary", "w": 6.5, "p": flat(SIDE), "n": "Pristoupimska"},
    {"c": "tertiary", "w": 5.5, "p": flat(BROD), "n": "na Brod"},
    {"c": "tertiary", "w": 5.5, "p": flat(SOUTH), "n": "Pristoupim"},
    {"c": "tertiary", "w": 5.5, "p": flat(EAST_Q), "n": "na Tuchoraz"},
    {"c": "residential", "w": 5.0, "p": flat(NORTH_N), "n": "Liblice"},
    {"c": "service", "w": 4.0, "p": flat(MAST_ROAD), "n": "k vysilaci"},
]
for t in TRACKS:
    roads.append({"c": "track", "w": 3.0, "d": 1, "p": flat(t)})
for i, r in enumerate(roads):
    r["id"] = 100 + i
ALL_ROADS = [ROAD12, CAMP_LINK, SIDE, BROD, SOUTH, EAST_Q, NORTH_N, MAST_ROAD] + TRACKS


def road_clear(q, margin):
    """Nothing standing within `margin` of a road's edge here."""
    for r, line in zip(roads, ALL_ROADS):
        if line_dist(q, line) < float(r["w"]) * 0.5 + margin:
            return False
    return True


# ── where the stops and the game's places are ────────────────────────────────

S = arc_lengths(ROUTE)
s_j = project(ROUTE, J)[0]
s_t = project(ROUTE, T)[0]
s_p = project(ROUTE, P)[0]
s_l = project(ROUTE, L)[0]
# The game's places sit in frames along the route (town_trip.gd _place_towns): Liblice's
# centre LIBLICE_PAST_STOP on from its stop, Pristoupim's at its stop.
LIBLICE_PAST_STOP = 110.0
town_o, town_d = point_at(ROUTE, s_l + LIBLICE_PAST_STOP)
ham_o, ham_d = point_at(ROUTE, s_p)


# ── the land ─────────────────────────────────────────────────────────────────

land = []


def add_land(kind, poly):
    land.append({"k": kind, "p": flat(poly), "id": 1000 + len(land)})


def overlaps(rect_a, rect_b):
    return rect_a[0] < rect_b[2] and rect_b[0] < rect_a[2] and rect_a[1] < rect_b[3] and rect_b[1] < rect_a[3]


def bbox(poly):
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    return (min(xs), min(zs), max(xs), max(zs))


# The fields: big JZD blocks along road 12, their edges following its sweep, a balk of
# grass between them; on past the road's ends, the same blocks run on to the horizon.
U = norm(sub(T, J))
V = (-U[1], U[0])                  # right of the road (south)
S12 = arc_lengths(ROAD12)


def road12_v(u):
    """How far right of the J-T line road 12 runs where the line is `u` m along."""
    q = add(J, mul(U, u))
    best = None
    for i in range(len(ROAD12) - 1):
        a, b = ROAD12[i], ROAD12[i + 1]
        ua, ub = dot(sub(a, J), U), dot(sub(b, J), U)
        if (ua - u) * (ub - u) <= 0 and abs(ub - ua) > 1e-6:
            f = (u - ua) / (ub - ua)
            p = add(a, mul(sub(b, a), f))
            best = dot(sub(p, J), V)
    return best if best is not None else 0.0


def kind_of_field():
    x = rng.random()
    if x < 0.74:
        return "farmland"
    if x < 0.9:
        return "meadow"
    return "grass"


u = -1900.0
while u < 3600.0:
    w = rng.uniform(200.0, 380.0)
    v0a, v0b = road12_v(u), road12_v(u + w)
    for side in (-1.0, 1.0):
        v = 7.0
        while v < 2000.0:
            h = rng.uniform(150.0, 300.0)
            near, far = v + 2.5, v + h - 2.5
            corners = [(u + 2.5, v0a + side * near), (u + w - 2.5, v0b + side * near),
                       (u + w - 2.5, v0b + side * far), (u + 2.5, v0a + side * far)]
            poly = [add(J, add(mul(U, c[0]), mul(V, c[1]))) for c in corners]
            box = bbox(poly)
            inside_area = overlaps(box, AREA)
            if inside_area and not overlaps(box, CAMP_ZONE):
                add_land(kind_of_field(), poly)
            v += h
    u += w

# Round the camp, outside its own ground: meadow, an old orchard to the east, scrub and
# birch to the west of its forest road, a pond in the meadow.
add_land("meadow", [(-130.0, 175.0), (150.0, 175.0), (150.0, 330.0), (-130.0, 330.0)])
add_land("meadow", [(150.0, -260.0), (260.0, -250.0), (260.0, 175.0), (150.0, 175.0)])
add_land("orchard", [(190.0, -90.0), (420.0, -60.0), (440.0, 180.0), (210.0, 200.0)])
add_land("scrub", [(-280.0, -300.0), (-70.0, -292.0), (-50.0, -215.0), (-160.0, -160.0), (-290.0, -190.0)])

# The woods: north of road 12 by the camp's turn, the copse on the hill, a grove south of
# the road, and the forests on every horizon.
WOODS = [
    [(-90.0, -440.0), (-20.0, -400.0), (70.0, -385.0), (140.0, -420.0), (110.0, -490.0), (-60.0, -505.0)],
    [(560.0, -420.0), (700.0, -395.0), (790.0, -440.0), (760.0, -540.0), (620.0, -560.0), (540.0, -500.0)],
    [(520.0, 40.0), (660.0, 30.0), (700.0, 120.0), (570.0, 170.0), (500.0, 110.0)],
    # The forests on the horizon, ragged at the edge.
    blob((600.0, -1620.0), 380.0, 160.0, 0.05, 26, 0.2),
    blob((2560.0, -860.0), 230.0, 200.0, 0.1, 22, 0.2),
    blob((600.0, 650.0), 330.0, 160.0, -0.03, 24, 0.2),
    blob((-720.0, 50.0), 150.0, 230.0, 0.05, 22, 0.2),
    blob((2280.0, 460.0), 300.0, 200.0, 0.0, 24, 0.2),
    blob((-420.0, -1480.0), 260.0, 190.0, 0.1, 22, 0.2),
]
for wd in WOODS:
    add_land("wood", wd)

# Pristoupim (hamlet_podlesi.gd: the road along its local x, the hamlet to its right):
# the meadow round it, gardens behind the houses, the spruce wood behind them.
add_land("meadow", rect_in(ham_o, ham_d, -135.0, 4.0, 40.0, 225.0))
add_land("gardens", rect_in(ham_o, ham_d, -62.0, 88.0, 62.0, 172.0))
add_land("meadow", rect_in(ham_o, ham_d, -110.0, -60.0, -30.0, -5.0))
add_land("wood", rect_in(ham_o, ham_d, -150.0, 190.0, 40.0, 330.0))
# Liblice (town_lesna.gd: the street along its local x): its gardens round the village.
add_land("residential", rect_in(town_o, town_d, -125.0, -88.0, 125.0, 78.0))
add_land("orchard", rect_in(town_o, town_d, -90.0, 92.0, 60.0, 150.0))
# Liblice B: the masts in their mown enclosure.
MAST_YARD = [(1350.0, -335.0), (1455.0, -335.0), (1460.0, -212.0), (1352.0, -212.0)]
add_land("grass", MAST_YARD)

# ── water: the brook and its alders, the ponds ──────────────────────────────

BROOK = fillet([(1250.0, 400.0), (1200.0, 150.0), (1172.0, -60.0), (1190.0, -330.0), (1235.0, -430.0),
                (1300.0, -520.0), (1380.0, -600.0), (1470.0, -660.0), (1560.0, -760.0), (1700.0, -900.0),
                (1900.0, -1050.0)], [0, 300, 300, 200, 150, 150, 150, 150, 200, 300, 0], step=8.0)
streams = [{"p": flat(BROOK), "w": 2.0}]
# Alders and willows along it, not over a road.
for i in range(0, len(BROOK) - 1):
    a, b = BROOK[i], BROOK[i + 1]
    mid = mul(add(a, b), 0.5)
    if not road_clear(mid, 14.0):
        continue
    d = norm(sub(b, a))
    side = (-d[1], d[0])
    w = rng.uniform(8.0, 15.0)
    add_land("scrub", [add(a, mul(side, w)), add(b, mul(side, w)), sub(b, mul(side, w)), sub(a, mul(side, w))])

PONDS = [blob((1000.0, -600.0), 44.0, 26.0, 0.5), blob((935.0, -662.0), 52.0, 30.0, 0.6),
         blob((1150.0, -860.0), 70.0, 42.0, -0.3), blob((-170.0, 92.0), 13.0, 9.0, 0.2)]
water = [{"p": flat(p), "n": ""} for p in PONDS]
for p in PONDS[:3]:
    add_land("wetland", [add(q, mul(sub(q, mul(add(p[0], p[len(p) // 2]), 0.5)), 0.25)) for q in p])

# ── trees in rows and alone ─────────────────────────────────────────────────

tree_rows = []


def row_along(line, off, s0, s1):
    """A row of trees `off` m right of `line` from s0 to s1 metres along it."""
    pts = []
    ss = arc_lengths(line)
    for i, p in enumerate(line):
        if s0 <= ss[i] <= s1:
            pts.append(p)
    if len(pts) >= 2:
        tree_rows.append({"p": flat(offset_line(pts, off))})


# Cherry alleys along the road up to Liblice and the road south to Pristoupim village.
side_s = arc_lengths(SIDE)
s_b1 = project(SIDE, B1)[0]
s_q = project(SIDE, Q)[0]
for off in (-7.5, 7.5):
    row_along(SIDE, off, s_b1 + 30.0, s_q - 30.0)
    row_along(SOUTH, off, 30.0, 700.0)
row_along(BROD, -7.0, 40.0, 900.0)
row_along(EAST_Q, 7.0, 40.0, 600.0)
# Balks with a hedge: a few lines across the fields, square to road 12.
for u0 in [240.0, 610.0, 980.0, 1650.0, -420.0]:
    for side in (-1.0, 1.0):
        v0 = road12_v(u0)
        a = add(J, add(mul(U, u0), mul(V, v0 + side * 30.0)))
        b = add(J, add(mul(U, u0), mul(V, v0 + side * rng.uniform(260.0, 520.0))))
        if not overlaps(bbox([a, b]), CAMP_ZONE):
            tree_rows.append({"p": flat([a, b])})

trees = []
for p in [(1124.0, -146.0), (300.0, -120.0), (780.0, -118.0), (1500.0, -300.0), (860.0, -268.0),
          (1352.0, -704.0), (470.0, -260.0), (1700.0, -160.0)]:
    if road_clear(p, 4.0):
        trees += [p[0], p[1]]

# ── wires, fences, the masts' buildings ─────────────────────────────────────

# The 110 kV line over the fields on its lattice pylons, and the village lines on
# concrete poles along road 12 and up to the masts.
power = [
    {"k": "line", "p": flat([(480.0, 1000.0), (440.0, -200.0), (380.0, -1900.0)])},
    {"k": "minor_line", "p": flat(offset_line(ROAD12[next(i for i, p in enumerate(ROAD12) if p[0] > -400): next(i for i, p in enumerate(ROAD12) if p[0] > 1080)], -12.0))},
    {"k": "minor_line", "p": flat(offset_line(MAST_ROAD, -9.0))},
]
fences = [{"k": "fence", "p": flat([(1352.0, -250.0), (1352.0, -212.0), (1460.0, -212.0), (1455.0, -335.0),
                                     (1350.0, -335.0), (1352.0, -272.0)])}]
buildings = [
    {"k": "industrial", "p": flat([(1366.0, -292.0), (1392.0, -292.0), (1392.0, -280.0), (1366.0, -280.0)])},
    {"k": "service", "p": flat([(1428.0, -232.0), (1435.0, -232.0), (1435.0, -226.0), (1428.0, -226.0)])},
]

# ── out ──────────────────────────────────────────────────────────────────────

world = {
    "origin": [50.0606589, 14.8477650],
    "roads": roads,
    "land": land,
    "water": water,
    "streams": streams,
    "buildings": buildings,
    "trees": [round(v, 1) for v in trees],
    "tree_rows": tree_rows,
    "power": power,
    "rails": [],
    "fences": fences,
    "route": flat(ROUTE),
    "stops": {
        "pristoupim": {"s": round(s_p, 1), "p": [round(P[0], 1), round(P[1], 1)], "off": 1.5},
        "liblice": {"s": round(s_l, 1), "p": [round(L[0], 1), round(L[1], 1)], "off": 0.5},
    },
    # Where along the route: road 12 (the camp's turn to Pristoupim's), the village signs.
    "marks": {"main_from": round(s_j, 1), "main_to": round(s_t, 1),
              "sign_pristoupim": round(s_t + 45.0, 1), "sign_liblice": round(s_l - 55.0, 1)},
    "route_len": round(S[-1], 1),
    "masts": [[m[0], m[1]] for m in MASTS],
    "fuel": [{"k": "benzina", "n": "Benzina", "p": [70.1, -281.6]}],
}
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    json.dump(world, f, ensure_ascii=False, separators=(",", ":"))
print("route %.0f m: road 12 %.0f-%.0f, Pristoupim at %.0f, Liblice at %.0f; %d fields and patches, %d roads"
      % (S[-1], s_j, s_t, s_p, s_l, len(land), len(roads)))
# What stands too near a road (woods' trees are not kept off the roads in the game): the
# outline every 10 m, and the middle.
for k, l in enumerate(land):
    if l["k"] in ("wood", "orchard"):
        pts = [(l["p"][i], l["p"][i + 1]) for i in range(0, len(l["p"]), 2)]
        probe = [mul(add(pts[0], pts[len(pts) // 2]), 0.5)]
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n = max(1, int(length(sub(b, a)) / 10.0))
            probe += [add(a, mul(sub(b, a), j / n)) for j in range(n)]
        for q in probe:
            if not road_clear(q, 6.0) or any(in_poly(q, w) for w in PONDS):
                print("  near a road or in a pond:", l["k"], k, [round(v) for v in q])
                break
