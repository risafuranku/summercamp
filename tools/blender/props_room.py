"""Props for the reception's back room and the office phone (see propkit.py).

Registered into build_props.PROPS. Fronts face Blender -Y (Godot +Z).
"""
import math

import propkit as K


def extend(m):
    m.update({
        "velvet": K.mat("velvet", "velvet.png", (0.55, 0.16, 0.12), texel=0.7),
        "plastic_beige": K.mat("plastic_beige", None, (0.78, 0.72, 0.6)),
        "plastic_dark": K.mat("plastic_dark", None, (0.16, 0.15, 0.14)),
        "rubber": K.mat("rubber", None, (0.42, 0.42, 0.4)),
        "lcd": K.mat("lcd", None, (0.36, 0.44, 0.3)),
        "button_red": K.mat("button_red", None, (0.62, 0.12, 0.1)),
        "pillow": K.mat("pillow", "mattress.png", (1.0, 0.97, 0.9), texel=0.5),
    })


def phone_push(m):
    """A beige 1990s push-button desk phone: a wedge base, the handset across the top in
    its cradle, twelve grey keys, a small LCD and a red redial key. 0.24 x 0.2."""
    b = m["plastic_beige"]
    parts = [K.box((0.24, 0.2, 0.05), (0, 0, 0.025), b)]
    parts.append(K.box((0.24, 0.1, 0.035), (0, 0.05, 0.065), b))                # raised back
    parts.append(K.box((0.22, 0.12, 0.012), (0, -0.04, 0.056), b, rot=(-0.22, 0, 0)))  # sloped key deck
    for r in range(4):
        for c in range(3):
            parts.append(K.box((0.026, 0.018, 0.01), (0.02 + c * 0.034, -0.085 + r * 0.024, 0.058 + r * 0.0055), m["rubber"], rot=(-0.22, 0, 0)))
    parts.append(K.box((0.07, 0.03, 0.006), (-0.07, -0.02, 0.068), m["lcd"], rot=(-0.22, 0, 0)))
    parts.append(K.box((0.026, 0.016, 0.01), (-0.075, -0.075, 0.06), m["button_red"], rot=(-0.22, 0, 0)))
    # The handset: two cups joined by a bar, lying in the cradle.
    parts.append(K.box((0.24, 0.05, 0.035), (0, 0.055, 0.1), b))
    for x in (-0.1, 0.1):
        parts.append(K.box((0.06, 0.065, 0.04), (x, 0.055, 0.092), b))
    # The coiled cord off the left side: a few loops.
    for i in range(6):
        parts.append(K.cyl(0.012, 0.008, (-0.135 - i * 0.012, 0.03 - i * 0.004, 0.02), m["plastic_beige"], 6, rot=(0, math.pi * 0.5, 0)))
    return parts


def alarm_clock(m):
    """A black mains alarm clock with a smoked window (the digits are drawn in Godot)."""
    d = m["plastic_dark"]
    parts = [K.box((0.16, 0.08, 0.07), (0, 0, 0.035), d)]
    parts.append(K.box((0.15, 0.06, 0.02), (0, 0.0, 0.08), d, rot=(-0.3, 0, 0)))
    parts.append(K.box((0.12, 0.004, 0.045), (0, -0.041, 0.04), m["black"]))
    parts.append(K.box((0.03, 0.02, 0.008), (0.05, 0.015, 0.075), m["rubber"]))
    parts.append(K.box((0.03, 0.02, 0.008), (0.0, 0.015, 0.075), m["rubber"]))
    return parts


def tv_small(m):
    """A small portable black-and-white TV (Tesla, 31 cm): a grey box with a rounded-off
    tube behind, the screen recessed, two knobs and a rabbit-ear aerial."""
    g = m["plastic_dark"]
    parts = [K.box((0.36, 0.28, 0.3), (0, 0, 0.15), g)]
    parts.append(K.box((0.26, 0.16, 0.22), (0, 0.2, 0.15), g))                   # the tube's back
    parts.append(K.box((0.36, 0.02, 0.3), (0, -0.14, 0.15), m["plastic_beige"]))  # front panel
    parts.append(K.box((0.24, 0.01, 0.2), (-0.04, -0.152, 0.16), m["screen"]))
    for z in (0.21, 0.12):
        parts.append(K.cyl(0.018, 0.025, (0.13, -0.16, z), m["black"], 8, rot=(math.pi * 0.5, 0, 0)))
    parts.append(K.box((0.1, 0.06, 0.02), (0, 0.04, 0.31), m["black"]))
    for s in (-1, 1):
        parts.append(K.box((0.008, 0.008, 0.36), (s * 0.08, 0.04, 0.48), m["chrome"], rot=(0, s * 0.5, 0)))
    return parts


def dresser(m):
    """A low veneer chest of drawers (the TV stands on it)."""
    v = m["veneer"]
    parts = [K.box((0.8, 0.42, 0.7), (0, 0, 0.39), v)]
    parts.append(K.box((0.84, 0.45, 0.03), (0, 0, 0.755), v))
    parts.append(K.box((0.8, 0.4, 0.04), (0, 0, 0.02), m["black"]))
    for z in (0.62, 0.42, 0.22):
        parts.append(K.box((0.74, 0.01, 0.17), (0, -0.215, z), v))
        parts.append(K.box((0.1, 0.02, 0.02), (0, -0.23, z), m["brass"]))
    return parts


def nightstand(m):
    v = m["veneer"]
    parts = [K.box((0.42, 0.36, 0.5), (0, 0, 0.29), v)]
    parts.append(K.box((0.44, 0.38, 0.03), (0, 0, 0.555), v))
    parts.append(K.box((0.36, 0.01, 0.14), (0, -0.185, 0.42), v))
    parts.append(K.box((0.06, 0.02, 0.02), (0, -0.2, 0.42), m["brass"]))
    for x in (-0.18, 0.18):
        for y in (-0.15, 0.15):
            parts.append(K.box((0.04, 0.04, 0.05), (x, y, 0.025), m["black"]))
    return parts


def curtain_heavy(m):
    """Heavy velvet drapes, drawn: a fold every 9 cm, alternately forward and back, on a
    brass rod. 1.4 wide, 2.2 tall, hangs from its top (origin on the floor line)."""
    parts = []
    folds = 16
    w = 1.4 / folds
    for i in range(folds):
        x = -0.7 + w * (i + 0.5)
        y = -0.03 if i % 2 else 0.0
        parts.append(K.box((w * 1.15, 0.05, 2.1), (x, y, 1.08), m["velvet"], rot=(0, 0, 0.35 if i % 2 else -0.35)))
    parts.append(K.cyl(0.015, 1.6, (0, -0.02, 2.17), m["brass"], 8, rot=(0, math.pi * 0.5, 0)))
    for s in (-1, 1):
        parts.append(K.cyl(0.03, 0.04, (s * 0.8, -0.02, 2.17), m["brass"], 8, rot=(0, math.pi * 0.5, 0)))
    return parts


def pillow(m):
    return [K.box((0.6, 0.36, 0.12), (0, 0, 0.06), m["pillow"]), K.box((0.56, 0.32, 0.03), (0, 0, 0.125), m["pillow"])]


PROPS = {
    "phone_push": phone_push,
    "alarm_clock": alarm_clock,
    "tv_small": tv_small,
    "dresser": dresser,
    "nightstand": nightstand,
    "curtain_heavy": curtain_heavy,
    "pillow": pillow,
}
