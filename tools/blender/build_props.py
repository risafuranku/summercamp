"""Build and export the interior props (see propkit.py).

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
        --python tools/blender/build_props.py [-- only_this_prop another_prop]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import propkit as K  # noqa: E402
import props_more  # noqa: E402

TAU = math.tau


# ── materials (camp textures, generated with tools/artgen; flat tint if missing) ──

def M():
    m = _base_materials()
    props_more.extend(m)
    return m


def _base_materials():
    return {
        "pine": K.mat("pine", "knotty_pine.png", texel=0.9),
        "pine_raw": K.mat("pine_raw", "planks_grey.png", (1.0, 0.92, 0.8), texel=0.9),
        "veneer": K.mat("veneer", "veneer_dark.png", texel=0.7),
        "enamel": K.mat("enamel", "enamel_white.png", texel=0.45),
        "enamel_blue": K.mat("enamel_blue", "enamel_white.png", (0.25, 0.35, 0.7), texel=0.45),
        "porcelain": K.mat("porcelain", "porcelain.png", texel=0.5),
        "chrome": K.mat("chrome", "galvanized.png", (0.9, 0.92, 0.95), texel=0.3),
        "galv": K.mat("galv", "galvanized.png", texel=0.6),
        "mattress": K.mat("mattress", "mattress.png", texel=0.9),
        "blanket": K.mat("blanket", "blanket_grey.png", texel=0.8),
        "seat": K.mat("seat", "knotty_pine.png", (0.85, 0.62, 0.42), texel=0.4),
        "glass": K.mat("glass", None, (0.66, 0.74, 0.78)),
        "screen": K.mat("screen", None, (0.16, 0.2, 0.2)),
        "black": K.mat("black", None, (0.05, 0.05, 0.05)),
        "metal_green": K.mat("metal_green", "metal_green.png", texel=0.8),
        "curtain": K.mat("curtain", "curtain_floral.png", texel=0.9),
        "bulb": K.mat("bulb", None, (1.0, 0.92, 0.7)),
        "brass": K.mat("brass", "galvanized.png", (0.85, 0.66, 0.3), texel=0.3),
    }


# ── props ─────────────────────────────────────────────────────────────────────

def slop_bucket(m):
    """An enamel bucket with a blue rim and a wire handle (a basic cabin's toilet)."""
    parts = K.tube(0.17, 0.32, 0.012, (0, 0, 0.16), m["enamel"], radius_top=0.19, segments=14)
    parts.append(K.cyl(0.196, 0.025, (0, 0, 0.315), m["enamel_blue"], 14, cap=False))
    parts.append(K.cyl(0.172, 0.02, (0, 0, 0.012), m["enamel_blue"], 14))
    # The wire handle: an arch of short bars, and the two ears.
    for i in range(7):
        a = math.pi * (i + 0.5) / 7
        x, z = math.cos(a) * 0.2, 0.33 + math.sin(a) * 0.12
        parts.append(K.box((0.1, 0.01, 0.01), (x, 0, z), m["chrome"], rot=(0, -(a - math.pi * 0.5), 0)))
    for s in (-1, 1):
        parts.append(K.box((0.02, 0.03, 0.04), (s * 0.195, 0, 0.3), m["enamel_blue"]))
    return parts


def slop_lid(m):
    parts = [K.cyl(0.2, 0.018, (0, 0, 0.009), m["enamel"], 14)]
    parts.append(K.cyl(0.04, 0.03, (0, 0, 0.03), m["enamel_blue"], 8))
    return parts


def bed_wood(m):
    """A pine bed: frame, head and foot boards, a striped mattress (1.95 x 0.9)."""
    p = m["pine"]
    parts = []
    for x in (-0.43, 0.43):
        for y in (-0.93, 0.93):
            parts.append(K.box((0.07, 0.07, 0.42), (x, y, 0.21), p))
    for x in (-0.43, 0.43):
        parts.append(K.box((0.05, 1.86, 0.16), (x, 0, 0.32), p))
    parts.append(K.box((0.9, 0.05, 0.62), (0, 0.95, 0.55), p))          # head board (back, +Y)
    parts.append(K.box((0.9, 0.05, 0.36), (0, -0.95, 0.42), p))         # foot board
    parts.append(K.box((0.8, 1.84, 0.14), (0, 0, 0.47), m["mattress"]))
    return parts


def table_wood(m):
    p = m["pine"]
    parts = [K.box((0.8, 0.8, 0.04), (0, 0, 0.72), p)]
    for x in (-0.34, 0.34):
        for y in (-0.34, 0.34):
            parts.append(K.box((0.05, 0.05, 0.7), (x, y, 0.35), p))
    for x in (-0.34, 0.34):
        parts.append(K.box((0.04, 0.64, 0.08), (x, 0, 0.64), p))
    for y in (-0.34, 0.34):
        parts.append(K.box((0.64, 0.04, 0.08), (0, y, 0.64), p))
    return parts


def chair_wood(m):
    p = m["pine"]
    parts = [K.box((0.42, 0.42, 0.04), (0, 0, 0.45), p)]
    for x in (-0.18, 0.18):
        for y in (-0.18, 0.18):
            h = 0.9 if y > 0 else 0.45
            parts.append(K.box((0.04, 0.04, h), (x, y, h * 0.5), p))
    parts.append(K.box((0.36, 0.03, 0.12), (0, 0.18, 0.82), p))
    parts.append(K.box((0.36, 0.03, 0.06), (0, 0.18, 0.62), p))
    return parts


def wardrobe(m):
    v = m["veneer"]
    parts = [K.box((0.9, 0.55, 1.8), (0, 0, 0.98), v)]
    parts.append(K.box((0.94, 0.58, 0.05), (0, 0, 1.9), v))
    parts.append(K.box((0.9, 0.5, 0.08), (0, 0, 0.04), m["black"]))
    parts.append(K.box((0.005, 0.01, 1.62), (0, -0.28, 1.0), m["black"]))  # door gap
    for x in (-0.06, 0.06):
        parts.append(K.box((0.02, 0.03, 0.16), (x, -0.29, 1.05), m["brass"]))
    return parts


def wall_shelf(m):
    p = m["pine"]
    parts = [K.box((0.7, 0.2, 0.03), (0, 0, 0.2), p)]
    for x in (-0.28, 0.28):
        parts.append(K.box((0.03, 0.18, 0.2), (x, 0.0, 0.1), p))
    return parts


def tv_old(m):
    """A 1980s Tesla colour TV on its own little legs."""
    v = m["veneer"]
    parts = [K.box((0.6, 0.42, 0.44), (0, 0, 0.52), v)]
    parts.append(K.box((0.42, 0.01, 0.32), (-0.06, -0.212, 0.53), m["screen"]))
    for z in (0.62, 0.52, 0.44):
        parts.append(K.box((0.05, 0.01, 0.03), (0.22, -0.212, z), m["black"]))
    for x in (-0.24, 0.24):
        for y in (-0.16, 0.16):
            parts.append(K.box((0.025, 0.025, 0.3), (x, y, 0.15), m["black"]))
    for s in (-1, 1):
        parts.append(K.box((0.01, 0.01, 0.4), (s * 0.08, 0.05, 0.92), m["chrome"], rot=(0, s * 0.45, 0)))
    return parts


def fridge_small(m):
    """A Calex under-counter fridge: white enamel, chrome handle."""
    parts = [K.box((0.5, 0.5, 0.82), (0, 0, 0.45), m["enamel"])]
    parts.append(K.box((0.5, 0.48, 0.04), (0, 0, 0.02), m["black"]))
    parts.append(K.box((0.46, 0.01, 0.005), (0, -0.252, 0.66), m["black"]))
    parts.append(K.box((0.03, 0.03, 0.2), (0.19, -0.27, 0.6), m["chrome"]))
    return parts


def toilet(m):
    """A floor-standing bowl with a wooden seat, the lid up, a high cistern with a chain."""
    pc = m["porcelain"]
    parts = K.tube(0.19, 0.4, 0.03, (0, -0.05, 0.2), pc, radius_top=0.21, segments=12)
    parts.append(K.box((0.24, 0.3, 0.38), (0, 0.15, 0.19), pc))
    parts.append(K.box((0.42, 0.46, 0.035), (0, -0.04, 0.42), m["seat"]))
    parts.append(K.box((0.4, 0.035, 0.44), (0, 0.2, 0.64), m["seat"], rot=(0.18, 0, 0)))
    parts.append(K.box((0.46, 0.17, 0.26), (0, 0.26, 1.72), pc))
    parts.append(K.cyl(0.022, 1.2, (0.14, 0.27, 1.0), m["chrome"], 8))
    parts.append(K.box((0.006, 0.006, 0.42), (-0.15, 0.2, 1.38), m["chrome"]))
    parts.append(K.cyl(0.018, 0.08, (-0.15, 0.2, 1.13), m["seat"], 8))
    return parts


def sink_pedestal(m):
    pc = m["porcelain"]
    parts = [K.cyl(0.08, 0.78, (0, 0.02, 0.39), pc, 10, radius_top=0.06)]
    parts += K.tube(0.25, 0.14, 0.03, (0, -0.02, 0.84), pc, segments=12)
    parts.append(K.box((0.5, 0.1, 0.14), (0, 0.17, 0.84), pc))
    for x, col in ((-0.12, (0.7, 0.1, 0.08)), (0.12, (0.1, 0.2, 0.7))):
        parts.append(K.cyl(0.02, 0.12, (x, 0.16, 0.97), m["chrome"], 8))
        parts.append(K.box((0.07, 0.02, 0.02), (x, 0.16, 1.03), K.mat("tap", None, col)))
    parts.append(K.box((0.02, 0.12, 0.02), (0, 0.1, 1.02), m["chrome"]))
    return parts


def mirror_frame(m):
    parts = [K.box((0.5, 0.03, 0.62), (0, 0, 0.31), m["veneer"])]
    parts.append(K.box((0.44, 0.01, 0.56), (0, -0.018, 0.31), m["glass"]))
    parts.append(K.box((0.5, 0.12, 0.02), (0, -0.06, -0.02), m["porcelain"]))
    return parts


def shower_corner(m):
    """A tiled shower tray with a drain, a riser pipe and head, a rail and a curtain."""
    parts = [K.box((0.8, 0.8, 0.1), (0, 0, 0.05), m["porcelain"])]
    parts.append(K.cyl(0.05, 0.01, (0, 0, 0.105), m["black"], 8))
    parts.append(K.cyl(0.018, 1.7, (0.3, 0.38, 1.0), m["chrome"], 8))
    parts.append(K.cyl(0.07, 0.04, (0.3, 0.3, 1.86), m["chrome"], 10, rot=(0.5, 0, 0)))
    parts.append(K.box((0.8, 0.02, 0.02), (0, -0.4, 2.0), m["chrome"]))
    parts.append(K.box((0.02, 0.8, 0.02), (-0.4, 0, 2.0), m["chrome"]))
    parts.append(K.box((0.5, 0.02, 1.6), (0.12, -0.41, 1.17), m["curtain"]))
    return parts


def wall_lamp(m):
    parts = [K.box((0.1, 0.04, 0.14), (0, 0.02, 0.07), m["brass"])]
    parts.append(K.cyl(0.08, 0.14, (0, -0.08, 0.16), K.mat("shade", "mattress.png", (1.0, 0.85, 0.6), 0.3), 10, radius_top=0.05))
    parts.append(K.cyl(0.03, 0.05, (0, -0.08, 0.1), m["bulb"], 8))
    return parts


PROPS = {
    "slop_bucket": slop_bucket,
    "slop_lid": slop_lid,
    "bed_wood": bed_wood,
    "table_wood": table_wood,
    "chair_wood": chair_wood,
    "wardrobe": wardrobe,
    "wall_shelf": wall_shelf,
    "tv_old": tv_old,
    "fridge_small": fridge_small,
    "toilet": toilet,
    "sink_pedestal": sink_pedestal,
    "mirror_frame": mirror_frame,
    "shower_corner": shower_corner,
    "wall_lamp": wall_lamp,
}
PROPS.update(props_more.PROPS)


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    K.reset_scene()
    m = M()
    done = []
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        obj = K.join(name, fn(m))
        K.export(obj, name + ".glb")
        obj.hide_set(True)
        done.append(name)
    K.write_manifest()
    print("PROPS EXPORTED: " + " ".join(done))


if __name__ == "__main__":
    main()
