"""More interior props: tent, toilet/shower blocks, pub, restaurant and kitchen, shop,
reception, generator shed. Same conventions as build_props.py / propkit.py."""
import math

import propkit as K


def extend(m):
    """Add the materials these props use to `m`."""
    m.update({
        "canvas": K.mat("canvas", "tarp_canvas.png", (0.62, 0.66, 0.42), texel=0.8),
        "nylon": K.mat("nylon", "blanket_check.png", (0.5, 0.75, 1.0), texel=0.6),
        "steel": K.mat("steel", "steel_kitchen.png", texel=0.7),
        "formica": K.mat("formica", "formica.png", texel=0.8),
        "gingham": K.mat("gingham", "gingham.png", texel=0.6),
        "bar_front": K.mat("bar_front", "bar_front.png", texel=1.0),
        "pub_wood": K.mat("pub_wood", "pub_panel.png", texel=1.0),
        "crate": K.mat("crate", "beer_crate.png", texel=0.5),
        "cardboard": K.mat("cardboard", "cardboard.png", texel=0.6),
        "bottle_green": K.mat("bottle_green", None, (0.12, 0.32, 0.14)),
        "bottle_brown": K.mat("bottle_brown", None, (0.32, 0.18, 0.06)),
        "label": K.mat("label", None, (0.86, 0.8, 0.6)),
        "red": K.mat("red", "metal_green.png", (1.4, 0.5, 0.4), texel=0.6),
        "glow": K.mat("glow", None, (1.0, 0.8, 0.4)),
    })


# ── tent ──

def camp_bed(m):
    """An army cot: a steel tube frame, X legs, olive canvas."""
    parts = [K.box((0.68, 1.9, 0.03), (0, 0, 0.4), m["canvas"])]
    for x in (-0.34, 0.34):
        parts.append(K.cyl(0.018, 1.94, (x, 0, 0.41), m["metal_green"], 6, rot=(math.pi * 0.5, 0, 0)))
    for y in (-0.8, 0.0, 0.8):
        for s in (-1, 1):
            parts.append(K.box((0.02, 0.02, 0.56), (s * 0.3, y, 0.2), m["metal_green"], rot=(0, s * 0.62, 0)))
    return parts


def sleeping_bag(m):
    """A quilted sleeping bag laid out, the top folded back, a rolled jumper for a pillow."""
    parts = [K.box((0.72, 1.8, 0.08), (0, 0, 0.04), m["nylon"])]
    parts.append(K.box((0.72, 0.4, 0.05), (0, 0.62, 0.105), K.mat("bag_lining", "blanket_check.png", (1.0, 0.7, 0.5), 0.5)))
    for y in (-0.6, -0.2, 0.2):
        parts.append(K.box((0.73, 0.02, 0.085), (0, y, 0.04), m["nylon"]))
    parts.append(K.cyl(0.08, 0.5, (0, 0.82, 0.1), m["blanket"], 8, rot=(0, math.pi * 0.5, 0)))
    return parts


def lantern(m):
    """A kerosene storm lantern."""
    parts = [K.cyl(0.08, 0.06, (0, 0, 0.03), m["red"], 10)]
    parts.append(K.cyl(0.055, 0.14, (0, 0, 0.13), K.mat("lantern_glass", None, (0.9, 0.8, 0.55)), 10))
    parts.append(K.cyl(0.07, 0.04, (0, 0, 0.22), m["red"], 10, radius_top=0.03))
    for s in (-1, 1):
        parts.append(K.box((0.008, 0.008, 0.2), (s * 0.075, 0, 0.13), m["red"]))
    parts.append(K.box((0.15, 0.008, 0.008), (0, 0, 0.29), m["chrome"]))
    return parts


def backpack(m):
    """A frame rucksack standing on the floor."""
    parts = [K.box((0.36, 0.2, 0.52), (0, 0, 0.27), m["canvas"])]
    parts.append(K.box((0.3, 0.1, 0.2), (0, -0.14, 0.2), m["canvas"]))
    parts.append(K.box((0.38, 0.22, 0.08), (0, 0, 0.56), K.mat("pack_flap", "tarp_canvas.png", (0.45, 0.5, 0.32), 0.5)))
    parts.append(K.cyl(0.07, 0.36, (0, 0.02, 0.64), m["blanket"], 8, rot=(0, math.pi * 0.5, 0)))
    for x in (-0.12, 0.12):
        parts.append(K.box((0.04, 0.02, 0.4), (x, -0.2, 0.3), K.mat("strap", None, (0.25, 0.2, 0.12))))
    return parts


def folding_chair(m):
    p = m["metal_green"]
    parts = [K.box((0.42, 0.36, 0.03), (0, 0, 0.42), m["canvas"])]
    parts.append(K.box((0.42, 0.03, 0.34), (0, 0.18, 0.66), m["canvas"], rot=(-0.2, 0, 0)))
    for x in (-0.2, 0.2):
        parts.append(K.box((0.02, 0.02, 0.6), (x, 0, 0.3), p, rot=(0.55, 0, 0)))
        parts.append(K.box((0.02, 0.02, 0.6), (x, 0, 0.3), p, rot=(-0.55, 0, 0)))
        parts.append(K.box((0.02, 0.02, 0.42), (x, 0.2, 0.68), p, rot=(-0.2, 0, 0)))
    return parts


# ── toilet and shower blocks ──

def urinal_trough(m):
    """A galvanized trough on the wall with its flush pipe."""
    g = m["galv"]
    parts = [K.box((1.2, 0.04, 0.8), (0, 0.12, 0.95), g)]
    parts.append(K.box((1.2, 0.26, 0.03), (0, 0.0, 0.56), g, rot=(0.25, 0, 0)))
    for x in (-0.6, 0.6):
        parts.append(K.box((0.03, 0.26, 0.2), (x, 0.0, 0.64), g))
    parts.append(K.cyl(0.02, 1.2, (0, 0.1, 1.38), m["chrome"], 8, rot=(0, math.pi * 0.5, 0)))
    parts.append(K.cyl(0.03, 0.56, (0.55, 0.0, 0.28), g, 8))
    return parts


def wash_trough(m):
    """A long galvanized wash trough on legs with three taps on a pipe."""
    g = m["galv"]
    parts = [K.box((1.6, 0.42, 0.04), (0, 0, 0.72), g)]
    parts.append(K.box((1.6, 0.03, 0.2), (0, -0.2, 0.82), g))
    parts.append(K.box((1.6, 0.03, 0.3), (0, 0.2, 0.87), g))
    for x in (-0.8, 0.8):
        parts.append(K.box((0.03, 0.42, 0.2), (x, 0, 0.82), g))
        parts.append(K.box((0.04, 0.04, 0.72), (x * 0.95, 0.15, 0.36), m["metal_green"]))
        parts.append(K.box((0.04, 0.04, 0.72), (x * 0.95, -0.15, 0.36), m["metal_green"]))
    parts.append(K.cyl(0.02, 1.6, (0, 0.24, 1.08), m["chrome"], 8, rot=(0, math.pi * 0.5, 0)))
    for x in (-0.5, 0.0, 0.5):
        parts.append(K.box((0.03, 0.14, 0.03), (x, 0.17, 1.06), m["chrome"]))
        parts.append(K.box((0.06, 0.02, 0.02), (x, 0.24, 1.12), m["red"]))
    return parts


def duckboard(m):
    """A wooden slatted shower duckboard."""
    parts = []
    for i in range(7):
        parts.append(K.box((0.1, 0.8, 0.03), (-0.33 + i * 0.11, 0, 0.045), m["pine"]))
    for y in (-0.32, 0.32):
        parts.append(K.box((0.8, 0.06, 0.03), (0, y, 0.015), m["pine"]))
    return parts


def bench_slatted(m):
    p = m["pine"]
    parts = []
    for i in range(3):
        parts.append(K.box((1.4, 0.1, 0.03), (0, -0.12 + i * 0.12, 0.45), p))
    for x in (-0.6, 0.6):
        parts.append(K.box((0.05, 0.36, 0.43), (x, 0, 0.215), p))
    return parts


def coat_hooks(m):
    parts = [K.box((1.0, 0.03, 0.1), (0, 0, 0.05), m["pine"])]
    for i in range(5):
        x = -0.4 + i * 0.2
        parts.append(K.box((0.02, 0.08, 0.02), (x, -0.05, 0.06), m["chrome"]))
        parts.append(K.box((0.02, 0.02, 0.04), (x, -0.09, 0.08), m["chrome"]))
    return parts


# ── pub and restaurant ──

def _table(m, mat):
    parts = [K.box((0.8, 0.8, 0.04), (0, 0, 0.72), mat)]
    for x in (-0.34, 0.34):
        for y in (-0.34, 0.34):
            parts.append(K.box((0.05, 0.05, 0.7), (x, y, 0.35), mat))
    return parts


def bar_counter(m):
    """A pub bar: panelled front, a top, a brass foot rail, two beer taps."""
    parts = [K.box((2.0, 0.6, 1.0), (0, 0, 0.5), m["bar_front"])]
    parts.append(K.box((2.1, 0.7, 0.05), (0, 0.02, 1.025), m["pub_wood"]))
    parts.append(K.cyl(0.02, 2.0, (0, -0.36, 0.14), m["brass"], 8, rot=(0, math.pi * 0.5, 0)))
    for x in (-0.25, 0.1):
        parts.append(K.box((0.12, 0.08, 0.06), (x, 0.15, 1.08), m["chrome"]))
        parts.append(K.cyl(0.02, 0.3, (x, 0.15, 1.26), m["chrome"], 8))
        parts.append(K.box((0.04, 0.06, 0.12), (x, 0.08, 1.42), K.mat("tap_handle", None, (0.9, 0.85, 0.75))))
    parts.append(K.box((0.4, 0.3, 0.02), (-0.08, 0.15, 1.06), m["chrome"]))
    return parts


def bar_stool(m):
    parts = [K.cyl(0.18, 0.06, (0, 0, 0.74), K.mat("stool_seat", None, (0.45, 0.12, 0.1)), 10)]
    parts.append(K.cyl(0.03, 0.7, (0, 0, 0.37), m["chrome"], 8))
    parts.append(K.cyl(0.2, 0.03, (0, 0, 0.015), m["chrome"], 10))
    parts.append(K.cyl(0.16, 0.02, (0, 0, 0.3), m["chrome"], 10, cap=False))
    return parts


def pub_table(m):
    """A dark pub table with a beer mat and an ashtray."""
    parts = _table(m, m["pub_wood"])
    parts.append(K.box((0.1, 0.1, 0.004), (0.15, 0.1, 0.742), K.mat("beer_mat", None, (0.85, 0.82, 0.7))))
    parts.append(K.cyl(0.06, 0.03, (-0.15, -0.1, 0.755), m["glass"], 8))
    return parts


def bottle_shelf(m):
    """Back-bar shelves with rows of bottles."""
    parts = []
    for z in (0.0, 0.42, 0.84):
        parts.append(K.box((1.6, 0.25, 0.03), (0, 0, z + 0.015), m["pub_wood"]))
    for x in (-0.8, 0.8):
        parts.append(K.box((0.03, 0.25, 1.1), (x, 0, 0.55), m["pub_wood"]))
    parts.append(K.box((1.6, 0.02, 1.1), (0, 0.12, 0.55), m["pub_wood"]))
    for row, z in enumerate((0.03, 0.45, 0.87)):
        for i in range(12):
            x = -0.7 + i * 0.125
            mat = m["bottle_green"] if (i + row) % 3 else m["bottle_brown"]
            parts.append(K.cyl(0.035, 0.22, (x, -0.02, z + 0.11), mat, 6))
            parts.append(K.cyl(0.013, 0.08, (x, -0.02, z + 0.26), mat, 6))
            parts.append(K.box((0.05, 0.005, 0.07), (x, -0.056, z + 0.1), m["label"]))
    return parts


def beer_crates(m):
    """A stack of red plastic beer crates."""
    parts = []
    for x, z in ((0, 0.15), (0.0, 0.45), (0.42, 0.15)):
        parts.append(K.box((0.4, 0.3, 0.29), (x, 0, z), m["crate"]))
        for j in range(4):
            parts.append(K.cyl(0.03, 0.04, (x - 0.12 + j * 0.08, 0, z + 0.165), m["bottle_brown"], 6))
    return parts


def gingham_table(m):
    """A buffet table with a red check cloth hanging over the edges."""
    parts = _table(m, m["pine"])
    parts.append(K.box((0.9, 0.9, 0.012), (0, 0, 0.75), m["gingham"]))
    for x in (-0.45, 0.45):
        parts.append(K.box((0.012, 0.9, 0.16), (x, 0, 0.67), m["gingham"]))
    for y in (-0.45, 0.45):
        parts.append(K.box((0.9, 0.012, 0.16), (0, y, 0.67), m["gingham"]))
    return parts


def stove(m):
    """A canteen range: four plates, an oven door, a steel splash back, a pot."""
    parts = [K.box((1.0, 0.7, 0.86), (0, 0, 0.43), m["enamel"])]
    parts.append(K.box((1.0, 0.7, 0.04), (0, 0, 0.88), m["steel"]))
    for x in (-0.25, 0.25):
        for y in (-0.15, 0.15):
            parts.append(K.cyl(0.11, 0.03, (x, y, 0.91), m["black"], 10))
    parts.append(K.box((0.8, 0.01, 0.42), (0, -0.351, 0.4), m["steel"]))
    parts.append(K.box((0.5, 0.03, 0.03), (0, -0.37, 0.66), m["chrome"]))
    for i in range(4):
        parts.append(K.cyl(0.025, 0.03, (-0.36 + i * 0.24, -0.36, 0.78), m["black"], 8, rot=(math.pi * 0.5, 0, 0)))
    parts.append(K.box((1.0, 0.04, 0.5), (0, 0.33, 1.15), m["steel"]))
    parts += K.tube(0.16, 0.24, 0.01, (-0.25, 0.12, 1.04), m["steel"], segments=12)
    return parts


def steel_counter(m):
    parts = [K.box((1.4, 0.65, 0.04), (0, 0, 0.88), m["steel"])]
    parts.append(K.box((1.36, 0.6, 0.03), (0, 0, 0.3), m["steel"]))
    for x in (-0.66, 0.66):
        for y in (-0.28, 0.28):
            parts.append(K.box((0.04, 0.04, 0.88), (x, y, 0.44), m["steel"]))
    parts += K.tube(0.12, 0.14, 0.008, (0.4, 0.05, 0.97), m["galv"], segments=10)
    parts.append(K.box((0.36, 0.25, 0.03), (-0.3, 0, 0.915), K.mat("board", "veneer_dark.png", (1.3, 1.2, 1.0), 0.4)))
    return parts


def fridge_tall(m):
    parts = [K.box((0.7, 0.66, 1.75), (0, 0, 0.9), m["enamel"])]
    parts.append(K.box((0.66, 0.01, 0.005), (0, -0.335, 1.25), m["black"]))
    parts.append(K.box((0.04, 0.04, 0.3), (0.27, -0.35, 1.0), m["chrome"]))
    parts.append(K.box((0.04, 0.04, 0.2), (0.27, -0.35, 1.45), m["chrome"]))
    parts.append(K.box((0.66, 0.62, 0.04), (0, 0, 0.02), m["black"]))
    return parts


# ── shop ──

def shop_shelf(m):
    """A green steel shop rack, five shelves (the goods are added in Godot)."""
    g = m["metal_green"]
    parts = []
    for x in (-0.6, 0.6):
        for y in (-0.2, 0.2):
            parts.append(K.box((0.04, 0.04, 1.9), (x, y, 0.95), g))
    for z in (0.12, 0.5, 0.88, 1.26, 1.64):
        parts.append(K.box((1.24, 0.44, 0.025), (0, 0, z), g))
        parts.append(K.box((1.24, 0.02, 0.06), (0, -0.22, z + 0.02), m["label"]))
    parts.append(K.box((1.24, 0.02, 1.9), (0, 0.22, 0.95), g))
    return parts


def shop_counter(m):
    """The Jednota counter: formica top, a steel cash register, a scale."""
    parts = [K.box((1.6, 0.6, 0.9), (0, 0, 0.45), m["metal_green"])]
    parts.append(K.box((1.66, 0.66, 0.04), (0, 0, 0.92), m["formica"]))
    parts.append(K.box((0.36, 0.34, 0.16), (0.4, 0.05, 1.02), m["steel"]))
    parts.append(K.box((0.34, 0.2, 0.16), (0.4, 0.1, 1.14), m["steel"], rot=(-0.4, 0, 0)))
    for i in range(3):
        for j in range(4):
            parts.append(K.box((0.04, 0.04, 0.015), (0.3 + j * 0.065, 0.02 + i * 0.05, 1.11), m["label"]))
    parts.append(K.box((0.3, 0.26, 0.08), (-0.4, 0.0, 0.98), m["enamel"]))
    parts.append(K.cyl(0.13, 0.02, (-0.4, 0.0, 1.04), m["chrome"], 12))
    parts.append(K.box((0.2, 0.04, 0.16), (-0.4, 0.13, 1.1), m["enamel"]))
    return parts


def cardboard_boxes(m):
    parts = []
    for x, y, z, sx, sy, sz in ((0, 0, 0.2, 0.5, 0.4, 0.4), (0.05, 0.02, 0.58, 0.44, 0.36, 0.36), (0.55, -0.05, 0.15, 0.4, 0.34, 0.3)):
        parts.append(K.box((sx, sy, sz), (x, y, z), m["cardboard"]))
        parts.append(K.box((0.06, sy + 0.005, 0.005), (x, y, z + sz * 0.5), K.mat("tape", None, (0.75, 0.6, 0.35))))
    return parts


def locker(m):
    """A row of three steel staff lockers."""
    g = m["metal_green"]
    parts = [K.box((1.2, 0.5, 1.85), (0, 0, 0.925), g)]
    for i in range(3):
        x = -0.4 + i * 0.4
        parts.append(K.box((0.36, 0.01, 1.75), (x, -0.255, 0.93), g))
        for j in range(5):
            parts.append(K.box((0.2, 0.012, 0.02), (x, -0.262, 1.55 + j * 0.05), m["black"]))
        parts.append(K.box((0.03, 0.03, 0.1), (x + 0.13, -0.27, 1.0), m["chrome"]))
    return parts


# ── reception and generator shed ──

def filing_cabinet(m):
    g = m["metal_green"]
    parts = [K.box((0.46, 0.6, 1.3), (0, 0, 0.65), g)]
    for i in range(4):
        z = 0.2 + i * 0.31
        parts.append(K.box((0.42, 0.01, 0.27), (0, -0.305, z), g))
        parts.append(K.box((0.14, 0.03, 0.03), (0, -0.32, z + 0.06), m["chrome"]))
        parts.append(K.box((0.08, 0.01, 0.04), (0, -0.312, z + 0.1), m["label"]))
    return parts


def key_board(m):
    """The key board on the reception wall: hooks and red tags."""
    parts = [K.box((0.7, 0.03, 0.5), (0, 0, 0.25), m["pine"])]
    for r in range(3):
        for c in range(5):
            x, z = -0.26 + c * 0.13, 0.38 - r * 0.14
            parts.append(K.box((0.012, 0.04, 0.012), (x, -0.03, z), m["brass"]))
            if (r * 5 + c) % 4 != 1:
                parts.append(K.box((0.03, 0.006, 0.06), (x, -0.05, z - 0.05), K.mat("keytag", None, (0.7, 0.2, 0.15))))
    return parts


def radio_set(m):
    """A 1970s Tesla valve radio: veneer case, cloth grille, a dial."""
    parts = [K.box((0.5, 0.22, 0.3), (0, 0, 0.15), m["veneer"])]
    parts.append(K.box((0.26, 0.01, 0.2), (-0.08, -0.111, 0.16), K.mat("grille", "blanket_check.png", (0.6, 0.5, 0.35), 0.1)))
    parts.append(K.box((0.14, 0.01, 0.06), (0.15, -0.111, 0.21), K.mat("dial", None, (0.9, 0.8, 0.5))))
    for x in (0.11, 0.19):
        parts.append(K.cyl(0.022, 0.03, (x, -0.12, 0.09), m["black"], 8, rot=(math.pi * 0.5, 0, 0)))
    return parts


def generator(m):
    """A diesel generator set on skids, with exhaust, fuel cap and a gauge panel."""
    g = m["metal_green"]
    parts = [K.box((1.6, 0.8, 0.12), (0, 0, 0.06), m["black"])]
    parts.append(K.box((0.9, 0.7, 0.8), (-0.3, 0, 0.52), g))
    parts.append(K.cyl(0.32, 0.6, (0.48, 0, 0.5), g, 12, rot=(0, math.pi * 0.5, 0)))
    parts.append(K.cyl(0.05, 0.9, (-0.6, 0.25, 1.3), m["galv"], 8))
    parts.append(K.box((0.36, 0.02, 0.26), (-0.3, -0.36, 0.7), m["black"]))
    for i in range(3):
        parts.append(K.cyl(0.04, 0.01, (-0.42 + i * 0.12, -0.372, 0.74), m["label"], 8, rot=(math.pi * 0.5, 0, 0)))
    parts.append(K.cyl(0.05, 0.05, (-0.1, 0.1, 0.94), m["red"], 8))
    return parts


def oil_drum(m):
    parts = [K.cyl(0.29, 0.88, (0, 0, 0.44), m["red"], 14)]
    for z in (0.3, 0.6):
        parts.append(K.cyl(0.3, 0.03, (0, 0, z), m["red"], 14, cap=False))
    parts.append(K.cyl(0.03, 0.02, (0.15, 0.1, 0.89), m["black"], 8))
    return parts


# ── the lake ──

def rowboat(m):
    """A small wooden rowing boat: planked sides that taper to a pointed bow, a flat
    stern, two thwarts, a pair of oars laid inside. 2.6 m long, bow towards -Y."""
    hull = K.mat("hull", "planks_red.png", (0.8, 0.85, 0.9), texel=0.8)
    inside = K.mat("hull_in", "planks_grey.png", (0.9, 0.85, 0.75), texel=0.8)
    parts = [K.box((0.9, 1.7, 0.05), (0, 0.25, 0.06), inside)]
    for s in (-1, 1):
        # Midship side plank, then the two bow planks closing on the stem.
        parts.append(K.box((0.04, 1.7, 0.42), (s * 0.47, 0.25, 0.24), hull, rot=(0, s * 0.12, 0)))
        parts.append(K.box((0.04, 0.95, 0.42), (s * 0.25, -0.95, 0.26), hull, rot=(0, s * 0.1, s * -0.5)))
    parts.append(K.box((0.86, 0.04, 0.42), (0, 1.1, 0.24), hull))
    parts.append(K.box((0.06, 0.06, 0.5), (0, -1.38, 0.3), hull, rot=(0.35, 0, 0)))
    for y in (-0.2, 0.6):
        parts.append(K.box((0.88, 0.2, 0.03), (0, y, 0.33), m["pine"]))
    for s in (-1, 1):
        parts.append(K.box((0.05, 1.9, 0.03), (s * 0.18, 0.15, 0.37), m["pine"], rot=(0, 0, s * 0.08)))
        parts.append(K.box((0.12, 0.4, 0.015), (s * 0.18, 1.0, 0.38), m["pine"]))
    return parts


PROPS = {
    "camp_bed": camp_bed,
    "sleeping_bag": sleeping_bag,
    "lantern": lantern,
    "backpack": backpack,
    "folding_chair": folding_chair,
    "urinal_trough": urinal_trough,
    "wash_trough": wash_trough,
    "duckboard": duckboard,
    "bench_slatted": bench_slatted,
    "coat_hooks": coat_hooks,
    "bar_counter": bar_counter,
    "bar_stool": bar_stool,
    "pub_table": pub_table,
    "bottle_shelf": bottle_shelf,
    "beer_crates": beer_crates,
    "gingham_table": gingham_table,
    "stove": stove,
    "steel_counter": steel_counter,
    "fridge_tall": fridge_tall,
    "shop_shelf": shop_shelf,
    "shop_counter": shop_counter,
    "cardboard_boxes": cardboard_boxes,
    "locker": locker,
    "filing_cabinet": filing_cabinet,
    "key_board": key_board,
    "radio_set": radio_set,
    "generator": generator,
    "oil_drum": oil_drum,
    "rowboat": rowboat,
}
