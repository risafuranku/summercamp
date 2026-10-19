#!/usr/bin/env python3
"""The stages of a cigarette burning down, made from ONE hand sprite that holds it.

    python tools/artgen/cig_stages.py <sprite relative to godot/> [out prefix]

The hand and the cigarette are one Grok picture (the grip is right because it was drawn
so); this finds the cigarette's pixels in it (white paper, the orange-red ember, the
grey ash), its axis and which end burns, and writes the same picture with the
cigarette burned down, pixel by pixel, never anything pasted on:

    <prefix>_new          unlit, whole (the tip tobacco brown)
    <prefix>_full         lit, whole (the ember ring at the tip)
    <prefix>_<k>          lit, burned to 3q / half / quarter / end
    <prefix>_<k>_ash      the same with grey ash hanging off the ember
    <prefix>_<k>_out      gone out in the rain (the ember dead grey)

<prefix> defaults to the sprite's own path without .png. Check the picture it prints.
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")

STAGES = {"full": 1.0, "3q": 0.76, "half": 0.54, "quarter": 0.34, "end": 0.16}
EMBER = [(120, 24, 16), (214, 60, 22), (255, 150, 52)]
ASH = [(118, 114, 108), (156, 152, 146), (186, 182, 176)]
DEAD = [(70, 66, 62), (96, 92, 88)]
TOBACCO = (122, 78, 40)


def is_paper(c):
    r, g, b, a = c
    return a > 0 and min(r, g, b) > 168 and max(r, g, b) - min(r, g, b) < 70


def is_ember(c):
    r, g, b, a = c
    return a > 0 and r > 150 and g < 150 and b < 110 and r - g > 60


def is_ash(c):
    r, g, b, a = c
    return a > 0 and 90 < max(r, g, b) < 200 and max(r, g, b) - min(r, g, b) < 26


def largest(points, w):
    """The biggest 8-connected group of the points."""
    left = set(points)
    best = []
    while left:
        seed = left.pop()
        group = [seed]
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in left:
                        left.remove(q)
                        group.append(q)
                        stack.append(q)
        if len(group) > len(best):
            best = group
    return best


def main():
    src = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else src[:-4]
    img = Image.open(os.path.join(GODOT, src)).convert("RGBA")
    px = img.load()
    w, h = img.size
    paper = largest([(x, y) for y in range(h) for x in range(w) if is_paper(px[x, y])], w)
    if len(paper) < 6:
        sys.exit("no cigarette found")
    pset = set(paper)
    # The axis through the paper (its long direction).
    mx = sum(p[0] for p in paper) / len(paper)
    my = sum(p[1] for p in paper) / len(paper)
    sxx = sum((p[0] - mx) ** 2 for p in paper)
    syy = sum((p[1] - my) ** 2 for p in paper)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in paper)
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ax = (math.cos(ang), math.sin(ang))

    def t(p):
        return (p[0] - mx) * ax[0] + (p[1] - my) * ax[1]

    ts = [t(p) for p in paper]
    lo, hi = min(ts), max(ts)
    # The burning end: where the ember is; else the end away from the hand's mass.
    near = [(x, y) for y in range(h) for x in range(w) if is_ember(px[x, y]) or is_ash(px[x, y])]
    near = [p for p in near if min(abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in paper) <= 3]
    if near:
        te = sum(t(p) for p in near) / len(near)
        tip_hi = abs(te - hi) < abs(te - lo)
    else:
        opaque = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0]
        cx = sum(p[0] for p in opaque) / len(opaque)
        cy = sum(p[1] for p in opaque) / len(opaque)
        tip_hi = t((cx, cy)) < (lo + hi) / 2
    sign = 1.0 if tip_hi else -1.0
    # Along the cigarette from the filter (0) to the tip (1); the tip end includes its
    # ember and ash pixels.
    cig = pset | set(near)
    ends = [sign * t(p) for p in cig]
    f0, f1 = min(ends), max(ends)
    # Its dark outline too, in the half towards the tip (out in the air, clear of the
    # fingers): every opaque pixel that close to the axis.
    def perp(p):
        return abs((p[0] - mx) * -ax[1] + (p[1] - my) * ax[0])
    thick = max(perp(p) for p in paper)
    mid = f0 + (f1 - f0) * 0.5
    for y in range(h):
        for x in range(w):
            p = (x, y)
            if px[x, y][3] > 0 and p not in cig and perp(p) <= thick + 3.2 and mid <= sign * t(p) <= f1 + 8.0:
                cig.add(p)
    ends = [sign * t(p) for p in cig]
    f1 = max(ends)

    def u(p):
        return (sign * t(p) - f0) / max(1e-6, f1 - f0)

    def width_at(p):
        return abs((p[0] - mx) * -ax[1] + (p[1] - my) * ax[0])

    span = f1 - f0

    def stage(length, lit=True, ash=0, dead=False, new=False):
        out = img.copy()
        o = out.load()
        band = 1.3 / span
        for p in cig:
            k = u(p)
            if k > length + ash / span:
                o[p] = (0, 0, 0, 0)
            elif k > length:
                # Ash where the paper was: lighter at the very end.
                j = (k - length) * span / max(ash, 1)
                c = ASH[min(2, int(j * 3))]
                o[p] = c + (255,)
            elif k > length - band:
                if new:
                    o[p] = TOBACCO + (255,)
                elif dead:
                    o[p] = DEAD[0 if width_at(p) > 0.8 else 1] + (255,)
                else:
                    # The ring: dark red outside, bright inside.
                    o[p] = EMBER[2 if width_at(p) < 0.8 else (1 if k > length - band * 0.5 else 0)] + (255,)
            elif p not in pset and lit is not None:
                # Ember or ash of the drawing further back than the new end: paper now.
                o[p] = (236, 232, 222, 255)
        return out

    outs = {"new": stage(1.0, new=True), "full": stage(1.0)}
    for name, k in STAGES.items():
        if name == "full":
            continue
        outs[name] = stage(k)
        if name != "end":
            outs[name + "_ash"] = stage(k, ash=2.6 if k > 0.5 else 2.0)
        outs[name + "_out"] = stage(k, dead=True)
    outs["full_out"] = stage(1.0, dead=True)
    tips = {}
    for name, im in outs.items():
        im.save(os.path.join(GODOT, "%s_%s.png" % (prefix, name)))
        # Where the burning end is in this picture (sprite pixels): smoke and ash leave it.
        k = 1.0 if name in ("new", "full", "full_out") else STAGES.get(name.split("_")[0], 1.0)
        tip_t = f0 + (f1 - f0) * k
        tips[name] = [round(mx + ax[0] * sign * tip_t, 1), round(my + ax[1] * sign * tip_t, 1)]
    import json
    with open(os.path.join(GODOT, prefix + "_tips.json"), "w") as fh:
        json.dump(tips, fh, indent=0)
    # A sheet to look at.
    k = 4
    names = list(outs.keys())
    sheet = Image.new("RGBA", ((w * k + 6) * len(names), h * k), (60, 70, 60, 255))
    for i, name in enumerate(names):
        sheet.alpha_composite(outs[name].resize((w * k, h * k), Image.NEAREST), (i * (w * k + 6), 0))
    check = os.path.join(HERE, "out", "_cig_stages_%s.png" % os.path.basename(prefix))
    sheet.save(check)
    print("%d stages, axis %.0f deg, tip %s; look at %s" % (len(outs), math.degrees(ang), "hi" if tip_hi else "lo", check))


if __name__ == "__main__":
    main()
