#!/usr/bin/env python3
"""The 380's bus as a Karosa SM 11 in the white and yellow of the CSAD (photo, playtest
20. 10.): its sides, front, back, the front door's folding panels and what is inside
(seats, the driver's seat, the dashboard), drawn here to the metre so the holes, windows
and wheel arches sit exactly where scripts/town/bus_model.gd builds them.

    python tools/artgen/karosa.py

Writes godot/assets/textury/town/karosa_*.png. Drawn at twice the size, boxed down,
grained and snapped to the game's palette like the Grok art (tools/artgen/process.py).
Transparent where the model has an opening (the front door, the windscreen, the wheel
arches) or glass of its own (the door panels).

The numbers below are the model's (bus_model.gd): keep them in step.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from process import snap  # noqa: E402

OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "town")
FONTS = "C:/Windows/Fonts/"

# ── the model's measures (metres) ────────────────────────────────────────────
LENGTH = 10.8
WIDTH = 2.5
LOW = 0.40          # the side's bottom edge
HIGH = 3.0          # the side's top edge (the roof's curve starts there)
AXLES = [2.4, 7.7]  # from the front
WHEEL_Y = 0.5
ARCH_R = 0.62
DOOR = (0.38, 1.40)         # the front door on the right, from the front
DOOR_TOP = 2.64
REAR_DOOR = (8.55, 9.45)    # the back door on the right (shut, painted)
WIN = (1.62, 2.64)          # the windows' sill and top
SKIRT_TOP = 1.02            # yellow below
WHITE_TOP = 1.34            # the white band
PILLAR = 0.11
RIGHT_WINDOWS = []
LEFT_WINDOWS = [(0.32, 1.42)]
WINDSCREEN = (1.38, 2.84)   # its bottom and top on the front (y)

PPM = 64            # pixels a metre in the result
SS = 2              # supersampling while drawing

# The CSAD's colours, weathered.
WHITE = (222, 220, 208)
YELLOW = (224, 194, 112)
YELLOW_DARK = (184, 150, 76)
ORANGE = (206, 120, 44)
RUBBER = (26, 26, 28)
STEEL = (150, 150, 144)
CHROME = (176, 178, 174)
GLASS_TOP = (104, 116, 124)
GLASS_LOW = (44, 50, 56)
TAN = (156, 116, 74)


def _windows(start, end, n):
    w = (end - start - (n - 1) * PILLAR) / n
    return [(start + i * (w + PILLAR), start + i * (w + PILLAR) + w) for i in range(n)]


RIGHT_WINDOWS += _windows(DOOR[1] + 0.12, REAR_DOOR[0] - 0.12, 6)
RIGHT_WINDOWS += [(REAR_DOOR[1] + 0.11, 10.44)]
LEFT_WINDOWS += _windows(1.52, 10.44, 8)


class Canvas:
    """A face of the bus in metres: x from its left edge as you look at it, y up from the
    ground (its bottom edge at `y0`)."""

    def __init__(self, w_m, y0, y1, ppm=PPM):
        self.ppm = ppm * SS
        self.y0, self.y1 = y0, y1
        self.w = round(w_m * self.ppm)
        self.h = round((y1 - y0) * self.ppm)
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def px(self, x, y):
        return (x * self.ppm, (self.y1 - y) * self.ppm)

    def rect(self, x0, y0, x1, y1, fill, r=0.0):
        a = self.px(x0, y1)
        b = self.px(x1, y0)
        box = [round(a[0]), round(a[1]), round(b[0]) - 1, round(b[1]) - 1]
        if r > 0:
            self.d.rounded_rectangle(box, radius=max(1, round(r * self.ppm)), fill=fill)
        else:
            self.d.rectangle(box, fill=fill)

    def hline(self, x0, x1, y, h, fill):
        self.rect(x0, y - h * 0.5, x1, y + h * 0.5, fill)

    def ellipse(self, cx, cy, rx, ry, fill):
        a = self.px(cx - rx, cy + ry)
        b = self.px(cx + rx, cy - ry)
        self.d.ellipse([round(a[0]), round(a[1]), round(b[0]), round(b[1])], fill=fill)

    def gradient(self, x0, y0, x1, y1, top, low, r=0.0):
        """A vertical gradient (glass) in a rounded box."""
        a = self.px(x0, y1)
        b = self.px(x1, y0)
        w = max(1, round(b[0]) - round(a[0]))
        h = max(1, round(b[1]) - round(a[1]))
        g = Image.new("RGBA", (w, h))
        gd = ImageDraw.Draw(g)
        for j in range(h):
            t = j / max(1, h - 1)
            gd.line([(0, j), (w, j)], fill=tuple(round(top[k] + (low[k] - top[k]) * t) for k in range(3)) + (255,))
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=max(1, round(r * self.ppm)), fill=255)
        self.img.paste(g, (round(a[0]), round(a[1])), m)

    def clear(self, x0, y0, x1, y1, r=0.0):
        self.rect(x0, y0, x1, y1, (0, 0, 0, 0), r)

    def arch(self, cx, cy, radius, y_low, fill):
        """A wheel arch: the circle and straight down to the bottom edge."""
        self.ellipse(cx, cy, radius, radius, fill)
        self.rect(cx - radius, y_low - 0.1, cx + radius, cy, fill)

    def text(self, x, y, s, size_m, fill, font="ARIALNB.TTF", anchor="ls"):
        f = ImageFont.truetype(FONTS + font, max(6, round(size_m * self.ppm)))
        self.d.text(self.px(x, y), s, font=f, fill=fill, anchor=anchor)

    def done(self, rng, grain=7, grime=True):
        """Down to size, weathered, on the game's palette."""
        img = self.img.resize((self.w // SS, self.h // SS), Image.Resampling.BOX)
        px = img.load()
        w, h = img.size
        for y in range(h):
            # Road spray darkens the bottom, soot the top edge a little.
            t = y / max(1, h - 1)
            dirt = 0.0
            if grime:
                dirt = max(0.0, (t - 0.72) / 0.28) * 0.28
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                n = rng.randint(-grain, grain)
                k = 1.0 - dirt
                px[x, y] = (_c(r * k + n - dirt * 18), _c(g * k + n - dirt * 22), _c(b * k + n - dirt * 26), a)
        return img


def _c(v):
    return max(0, min(255, int(v)))


def streaks(img, rng, rows, strength=26):
    """Dirt run down from window sills and the roof's edge: thin darker lines."""
    px = img.load()
    w, h = img.size
    for (y_from, y_to) in rows:
        for _ in range(w // 3):
            x = rng.randrange(w)
            length = rng.randint(3, max(4, y_to - y_from))
            s = rng.uniform(0.3, 1.0) * strength
            for y in range(y_from, min(h, y_from + length)):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                f = 1.0 - (y - y_from) / max(1, length)
                px[x, y] = (_c(r - s * f), _c(g - s * f), _c(b - s * f * 1.2), a)


def rust(img, rng, spots, size=3):
    px = img.load()
    w, h = img.size
    for (cx, cy, n) in spots:
        for _ in range(n):
            x = int(cx + rng.gauss(0, size * 2))
            y = int(cy + rng.gauss(0, size))
            if 0 <= x < w and 0 <= y < h and px[x, y][3] > 0:
                r, g, b, a = px[x, y]
                px[x, y] = (_c(r * 0.62 + 40), _c(g * 0.5 + 12), _c(b * 0.4), a)


def save(img, name, alpha=True):
    out = snap(img, alpha) if alpha else snap(img.convert("RGB"), False)
    out.save(os.path.join(OUT, name))
    print("wrote", name, out.size)


# ── the sides ────────────────────────────────────────────────────────────────

def livery(c, x0, x1):
    """The bands along a side between x0 and x1 (metres along the canvas)."""
    c.rect(x0, LOW, x1, SKIRT_TOP, YELLOW)
    c.rect(x0, SKIRT_TOP, x1, WHITE_TOP, WHITE)
    c.rect(x0, WHITE_TOP, x1, WIN[0], YELLOW)
    c.rect(x0, WIN[0], x1, HIGH, WHITE)
    # The rubbing strip along the white band and the line under the belt.
    c.hline(x0, x1, SKIRT_TOP + 0.01, 0.035, STEEL)
    c.hline(x0, x1, SKIRT_TOP + 0.04, 0.012, (120, 118, 110))
    c.hline(x0, x1, WHITE_TOP, 0.02, YELLOW_DARK)
    # The skirt's bottom lip.
    c.hline(x0, x1, LOW + 0.02, 0.04, (60, 58, 52))


def window(c, x0, x1, rng, vent=True, seats=True, driver=False):
    y0, y1 = WIN
    c.rect(x0 - 0.035, y0 - 0.035, x1 + 0.035, y1 + 0.035, RUBBER, 0.07)
    c.gradient(x0, y0, x1, y1, GLASS_TOP, GLASS_LOW, 0.05)
    # What shows through: the tan seat backs and their headrest covers, low in the pane.
    if seats:
        w = x1 - x0
        n = 2 if w > 0.8 else 1
        for k in range(n):
            sx = x0 + w * (k + 0.5) / n
            c.rect(sx - 0.2, y0, sx + 0.2, y0 + 0.36, (98, 78, 56), 0.06)
            c.rect(sx - 0.14, y0 + 0.24, sx + 0.14, y0 + 0.36, (150, 146, 134), 0.04)
    if driver:
        # The driver's sliding pane: a vertical runner.
        c.rect((x0 + x1) * 0.5 - 0.015, y0, (x0 + x1) * 0.5 + 0.015, y1, STEEL)
    # The sky's light on the glass: a pale diagonal band or two.
    for k in range(2):
        t = rng.uniform(0.1, 0.8)
        bx = x0 + (x1 - x0) * t
        for j in range(10):
            yy = y1 - 0.08 - j * 0.07
            if yy < y0 + 0.05:
                break
            xx = bx + j * 0.05
            if x0 < xx < x1 - 0.04:
                c.rect(xx, yy - 0.05, xx + 0.04, yy, (150, 160, 166, 255))
    if vent:
        # The sliding top panes: a bar at a third from the top, split in two above it.
        vy = y1 - (y1 - y0) * 0.3
        c.rect(x0, vy - 0.02, x1, vy + 0.02, (70, 72, 74))
        c.rect((x0 + x1) * 0.5 - 0.015, vy, (x0 + x1) * 0.5 + 0.015, y1, (70, 72, 74))


def side(right):
    rng = random.Random(380 + (1 if right else 0))
    c = Canvas(LENGTH, LOW, HIGH)

    # Canvas x runs from the back (right side: art from the back on the left) or the front.
    def X(d):
        return LENGTH - d if right else d

    livery(c, 0.0, LENGTH)
    # The rounded corners front and back: a darker edge.
    for d in (0.0, LENGTH):
        x = X(d)
        c.rect(max(0.0, x - 0.05), LOW, min(LENGTH, x + 0.05), HIGH, (168, 166, 156))
    for (a, b) in (RIGHT_WINDOWS if right else LEFT_WINDOWS):
        xa, xb = sorted((X(a), X(b)))
        window(c, xa, xb, rng, vent=(b - a) > 0.7, driver=(not right and a < 0.5), seats=not (not right and a < 0.5))
    if right:
        # The back door, shut: two leaves, glass to low down, yellow under it.
        xa, xb = sorted((X(REAR_DOOR[0]), X(REAR_DOOR[1])))
        c.rect(xa - 0.04, LOW + 0.04, xb + 0.04, DOOR_TOP + 0.04, RUBBER)
        mid = (xa + xb) * 0.5
        for (p, q) in ((xa, mid - 0.01), (mid + 0.01, xb)):
            c.rect(p, LOW + 0.06, q, DOOR_TOP, STEEL)
            c.gradient(p + 0.04, 1.05, q - 0.04, DOOR_TOP - 0.05, GLASS_TOP, GLASS_LOW, 0.04)
            c.rect(p + 0.04, LOW + 0.1, q - 0.04, 1.0, YELLOW)
        c.rect(mid - 0.012, LOW + 0.06, mid + 0.012, DOOR_TOP, RUBBER)
        # The front door: an opening (the model's leaves and steps are in it), its rubber.
        xa, xb = sorted((X(DOOR[0]), X(DOOR[1])))
        c.rect(xa - 0.035, LOW, xb + 0.035, DOOR_TOP + 0.035, RUBBER)
        c.clear(xa, LOW - 0.1, xb, DOOR_TOP)
        # The fuel flap and a side marker or two.
        fx = X(4.6)
        c.rect(fx - 0.12, 0.62, fx + 0.12, 0.84, YELLOW_DARK, 0.03)
    for d in AXLES:
        x = X(d)
        # Rubber round the arch, then the hole (the wheel shows through it).
        c.arch(x, WHEEL_Y, ARCH_R + 0.04, LOW, RUBBER)
        c.arch(x, WHEEL_Y, ARCH_R, LOW, (0, 0, 0, 0))
    for d in (1.9 if right else 1.75, 5.05, 9.3):
        x = X(d)
        c.rect(x - 0.05, 0.56, x + 0.05, 0.62, (220, 130, 40))
    # The maker's badge on the white band, aft of the front wheel.
    bx = X(3.4)
    c.rect(bx - 0.14, 1.12, bx + 0.14, 1.22, CHROME, 0.02)
    img = c.done(rng)
    h = img.size[1]
    sill = round((HIGH - WIN[0]) * PPM)
    top = round((HIGH - WIN[1]) * PPM)
    streaks(img, rng, [(sill + 2, sill + 18), (0, top - 1)], 22)
    rust(img, rng, [(round(X(d) * PPM), round((HIGH - WHEEL_Y - ARCH_R) * PPM), 26) for d in AXLES], 3)
    rust(img, rng, [(rng.randrange(img.size[0]), h - 4, 14) for _ in range(6)], 2)
    save(img, "karosa_side_r.png" if right else "karosa_side_l.png")
    # The night: where the windows let the light out (white), for an emission mask.
    m = Canvas(LENGTH, LOW, HIGH)
    for (a, b) in (RIGHT_WINDOWS if right else LEFT_WINDOWS):
        xa, xb = sorted((X(a), X(b)))
        m.rect(xa, WIN[0], xb, WIN[1], (236, 236, 236, 255), 0.05)
        # The seats' backs against the light, and their covers paler.
        if not (not right and a < 0.5):
            w = xb - xa
            n = 2 if w > 0.8 else 1
            for k in range(n):
                sx = xa + w * (k + 0.5) / n
                m.rect(sx - 0.2, WIN[0], sx + 0.2, WIN[0] + 0.36, (60, 60, 60, 255), 0.06)
                m.rect(sx - 0.14, WIN[0] + 0.24, sx + 0.14, WIN[0] + 0.36, (150, 150, 150, 255), 0.04)
    if right:
        xa, xb = sorted((X(REAR_DOOR[0]), X(REAR_DOOR[1])))
        m.rect(xa + 0.04, 1.05, xb - 0.04, DOOR_TOP - 0.05, (200, 200, 200, 255))
    lit = m.img.resize((m.w // SS, m.h // SS), Image.Resampling.BOX).convert("RGB")
    lit.save(os.path.join(OUT, "karosa_side_r_lit.png" if right else "karosa_side_l_lit.png"))


# ── front and back ───────────────────────────────────────────────────────────

def front():
    rng = random.Random(11)
    c = Canvas(WIDTH, LOW, HIGH)
    c.rect(0, LOW, WIDTH, HIGH, WHITE)
    # The windscreen: an opening (the model's glass is in it), two panes on a pillar.
    c.rect(0.05, WINDSCREEN[0] - 0.04, WIDTH - 0.05, WINDSCREEN[1] + 0.04, RUBBER, 0.1)
    c.clear(0.09, WINDSCREEN[0], WIDTH * 0.5 - 0.02, WINDSCREEN[1], 0.08)
    c.clear(WIDTH * 0.5 + 0.02, WINDSCREEN[0], WIDTH - 0.09, WINDSCREEN[1], 0.08)
    # The orange-yellow panel under it with KAROSA, its winkers at the ends.
    c.rect(0.16, 0.98, WIDTH - 0.16, 1.3, ORANGE, 0.02)
    c.rect(0.16, 0.98, WIDTH - 0.16, 1.0, (150, 84, 30))
    for k in range(6):
        c.hline(0.4, WIDTH - 0.62, 1.06 + k * 0.035, 0.012, (170, 96, 36))
    c.text(WIDTH - 0.48, 1.08, "KAROSA", 0.09, (26, 24, 22), anchor="ms")
    for x in (0.16, WIDTH - 0.32):
        c.rect(x, 1.04, x + 0.16, 1.24, (236, 150, 40))
    # The black band with the round lamps and the grille between.
    c.rect(0.12, 0.7, WIDTH - 0.12, 0.96, (24, 24, 24))
    for x in (0.34, WIDTH - 0.34):
        c.ellipse(x, 0.83, 0.1, 0.1, (190, 190, 180))
        c.ellipse(x, 0.83, 0.07, 0.07, (232, 230, 214))
    for k in range(10):
        c.hline(0.6, WIDTH - 0.6, 0.73 + k * 0.022, 0.008, (62, 62, 60))
    # The bumper: yellow with black rubber ends, the plate's place.
    c.rect(0.0, LOW, WIDTH, 0.66, YELLOW, 0.03)
    c.rect(0.0, LOW, 0.2, 0.66, RUBBER, 0.03)
    c.rect(WIDTH - 0.2, LOW, WIDTH, 0.66, RUBBER, 0.03)
    c.rect(0.0, LOW, WIDTH, LOW + 0.04, (60, 58, 52))
    # Two step holes and towing eyes under it all.
    for x in (0.7, WIDTH - 0.7):
        c.rect(x - 0.05, LOW + 0.06, x + 0.05, LOW + 0.12, (40, 40, 40))
    img = c.done(rng, grime=True)
    streaks(img, rng, [(round((HIGH - WINDSCREEN[1]) * PPM) - 9, round((HIGH - WINDSCREEN[1]) * PPM) - 2)], 14)
    save(img, "karosa_front.png")


def back():
    rng = random.Random(12)
    c = Canvas(WIDTH, LOW, HIGH)
    c.rect(0, LOW, WIDTH, HIGH, WHITE)
    c.rect(0, LOW, WIDTH, SKIRT_TOP, YELLOW)
    c.rect(0, WHITE_TOP, WIDTH, WIN[0], YELLOW)
    c.hline(0, WIDTH, SKIRT_TOP + 0.01, 0.035, STEEL)
    # The back window high up, the engine's louvred lid low down.
    c.rect(0.3, 1.86, WIDTH - 0.3, 2.66, RUBBER, 0.08)
    c.gradient(0.34, 1.9, WIDTH - 0.34, 2.62, GLASS_TOP, GLASS_LOW, 0.06)
    for x in (0.7, 1.25, 1.8):
        c.rect(x - 0.2, 1.9, x + 0.2, 2.18, (98, 78, 56), 0.05)
    c.rect(0.32, 0.7, WIDTH - 0.32, 1.32, (196, 196, 186), 0.03)
    for k in range(12):
        c.hline(0.4, WIDTH - 0.4, 0.76 + k * 0.045, 0.018, (70, 70, 66))
    # The lamps up the corners: red, amber, red.
    for x in (0.08, WIDTH - 0.26):
        c.rect(x, 0.78, x + 0.18, 1.5, (34, 34, 34), 0.03)
        for k, col in enumerate([(176, 30, 20), (214, 130, 30), (176, 30, 20)]):
            c.ellipse(x + 0.09, 0.9 + k * 0.22, 0.07, 0.07, col)
    c.text(WIDTH * 0.5, 1.44, "ŠM 11", 0.08, CHROME, anchor="ms")
    c.rect(0.0, LOW, WIDTH, 0.62, YELLOW, 0.03)
    c.rect(0.0, LOW, 0.2, 0.62, RUBBER, 0.03)
    c.rect(WIDTH - 0.2, LOW, WIDTH, 0.62, RUBBER, 0.03)
    img = c.done(rng)
    # Soot from the engine round the lid.
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            yy = HIGH - y / PPM
            if 0.62 < yy < 1.4 and rng.random() < 0.35:
                px[x, y] = (_c(r * 0.8), _c(g * 0.8), _c(b * 0.8), a)
    save(img, "karosa_back.png")


# ── the front door's panels ──────────────────────────────────────────────────

def door_panel():
    """One of the four folding panels (0.255 m by DOOR_TOP - LOW): a steel frame, its
    glass left open (the model glazes it), the yellow kick panel low down."""
    rng = random.Random(13)
    w = (DOOR[1] - DOOR[0]) / 4.0
    c = Canvas(w, LOW, DOOR_TOP, ppm=128)
    c.rect(0, LOW, w, DOOR_TOP, (200, 200, 194))
    c.rect(0.0, LOW, 0.012, DOOR_TOP, (120, 120, 116))
    c.rect(w - 0.012, LOW, w, DOOR_TOP, (120, 120, 116))
    c.rect(0.03, LOW + 0.05, w - 0.03, 0.98, YELLOW)
    c.rect(0.03, 0.98, w - 0.03, 1.02, (120, 120, 116))
    c.clear(0.035, 1.06, w - 0.035, DOOR_TOP - 0.05, 0.03)
    c.rect(0.0, DOOR_TOP - 0.03, w, DOOR_TOP, RUBBER)
    img = c.done(rng, grain=5, grime=False)
    save(img, "karosa_door_panel.png")


# ── inside ───────────────────────────────────────────────────────────────────

def cloth(name, base, size=32, seed=5, weave=10):
    rng = random.Random(seed)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            n = rng.randint(-weave, weave) + (6 if (x + y) % 2 == 0 else -6)
            px[x, y] = (_c(base[0] + n), _c(base[1] + n), _c(base[2] + n * 0.6))
    save(img, name, alpha=False)


def leather():
    rng = random.Random(6)
    size = 64
    img = Image.new("RGB", (size, size))
    px = img.load()
    base = (92, 56, 38)
    for y in range(size):
        for x in range(size):
            n = rng.randint(-5, 5)
            # Creases: soft diagonal waves.
            w = math.sin((x * 0.6 + y * 0.25) * 0.9) * 6 + math.sin((x * 0.2 - y * 0.7) * 1.3) * 4
            px[x, y] = (_c(base[0] + n + w), _c(base[1] + n + w * 0.7), _c(base[2] + n + w * 0.5))
    save(img, "karosa_leather.png", alpha=False)


def seat_back():
    """A double seat's back as the row behind sees it: tan cloth in pleats, the brown
    vinyl edge, the white cloth over the top with its lace edge."""
    rng = random.Random(7)
    c = Canvas(0.84, 0.0, 0.62, ppm=128)
    c.rect(0, 0, 0.84, 0.62, (96, 62, 40), 0.06)
    for half in (0.0, 0.42):
        c.rect(half + 0.04, 0.04, half + 0.38, 0.54, TAN, 0.04)
        for k in range(5):
            px = half + 0.08 + k * 0.065
            c.rect(px, 0.06, px + 0.006, 0.5, (130, 94, 58))
        c.rect(half + 0.1, 0.5, half + 0.32, 0.6, (226, 224, 214), 0.02)
        for k in range(8):
            c.ellipse(half + 0.11 + k * 0.03, 0.5, 0.008, 0.008, (226, 224, 214))
    img = c.done(rng, grain=6, grime=False)
    save(img, "karosa_seat_back.png")


def dash():
    """The dashboard as in the photo: black, the two big dials, a row of small ones to
    the right, warning lamps over them, switches to the left, the radio low right."""
    rng = random.Random(8)
    c = Canvas(1.3, 0.0, 0.42, ppm=160)
    c.rect(0, 0, 1.3, 0.42, (30, 30, 32))
    c.rect(0.0, 0.38, 1.3, 0.42, (20, 20, 20))
    for k in range(8):
        x = 0.06 + k * 0.045
        c.rect(x, 0.22, x + 0.025, 0.3, (12, 12, 12))
        c.rect(x + 0.006, 0.27, x + 0.019, 0.33, (190, 190, 186))
    for (cx, r) in ((0.6, 0.085), (0.8, 0.085)):
        c.ellipse(cx, 0.2, r + 0.012, r + 0.012, (70, 70, 70))
        c.ellipse(cx, 0.2, r, r, (18, 18, 20))
        for k in range(11):
            a = math.radians(220 - k * 26)
            c.rect(cx + math.cos(a) * r * 0.82 - 0.004, 0.2 + math.sin(a) * r * 0.82 - 0.004,
                   cx + math.cos(a) * r * 0.82 + 0.004, 0.2 + math.sin(a) * r * 0.82 + 0.004, (220, 220, 214))
        a = math.radians(rng.uniform(150, 200))
        for t in range(12):
            q = t / 12.0 * r * 0.75
            c.rect(cx + math.cos(a) * q - 0.003, 0.2 + math.sin(a) * q - 0.003, cx + math.cos(a) * q + 0.003, 0.2 + math.sin(a) * q + 0.003, (220, 90, 40))
    for row in range(2):
        for k in range(3):
            cx = 0.98 + k * 0.1
            cy = 0.27 - row * 0.11
            c.ellipse(cx, cy, 0.04, 0.04, (80, 80, 80))
            c.ellipse(cx, cy, 0.032, 0.032, (16, 16, 18))
            c.rect(cx - 0.002, cy, cx + 0.002, cy + 0.025, (220, 220, 214))
    for k, col in enumerate([(200, 40, 30), (40, 170, 60), (220, 160, 40), (200, 40, 30), (60, 120, 200), (40, 170, 60)]):
        c.rect(0.48 + k * 0.035, 0.335, 0.5 + k * 0.035, 0.355, col)
    c.rect(0.98, 0.02, 1.26, 0.1, (50, 50, 52))
    c.rect(1.0, 0.04, 1.18, 0.08, (14, 14, 14))
    c.text(1.22, 0.045, "TESLA", 0.025, (170, 170, 164), font="ARIALN.TTF", anchor="ms")
    img = c.done(rng, grain=4, grime=False)
    save(img, "karosa_dash.png")


def skoda_dash():
    """Old Vondra's Skoda 120 from the passenger seat (scripts/town/skoda_ride.gd): the
    dark grey dash, his two dials on the left, the radio in the middle, your glovebox."""
    rng = random.Random(120)
    c = Canvas(1.4, 0.0, 0.34, ppm=160)
    c.rect(0, 0, 1.4, 0.34, (58, 56, 54))
    c.rect(0, 0.28, 1.4, 0.34, (40, 38, 36))
    # His two dials in their hood.
    c.rect(0.12, 0.06, 0.52, 0.27, (24, 24, 24), 0.04)
    for cx in (0.22, 0.42):
        c.ellipse(cx, 0.165, 0.075, 0.075, (78, 78, 74))
        c.ellipse(cx, 0.165, 0.064, 0.064, (16, 16, 18))
        for k in range(9):
            a = math.radians(220 - k * 32)
            c.rect(cx + math.cos(a) * 0.05 - 0.003, 0.165 + math.sin(a) * 0.05 - 0.003,
                   cx + math.cos(a) * 0.05 + 0.003, 0.165 + math.sin(a) * 0.05 + 0.003, (220, 216, 200))
        a = math.radians(rng.uniform(140, 210))
        for t in range(8):
            q = t / 8.0 * 0.05
            c.rect(cx + math.cos(a) * q - 0.0025, 0.165 + math.sin(a) * q - 0.0025, cx + math.cos(a) * q + 0.0025, 0.165 + math.sin(a) * q + 0.0025, (230, 120, 40))
    # Lamps and switches under them, the radio in the middle, the ashtray.
    for k, col in enumerate([(40, 160, 60), (200, 50, 30), (220, 160, 40)]):
        c.rect(0.16 + k * 0.05, 0.03, 0.18 + k * 0.05, 0.045, col)
    c.rect(0.6, 0.1, 0.84, 0.2, (30, 30, 30))
    c.rect(0.62, 0.13, 0.76, 0.17, (120, 110, 70))
    c.ellipse(0.8, 0.15, 0.015, 0.015, (160, 160, 150))
    c.text(0.69, 0.11, "TESLA", 0.022, (150, 150, 140), font="ARIALN.TTF", anchor="ms")
    c.rect(0.64, 0.03, 0.8, 0.07, (36, 36, 36))
    # The glovebox lid on your side, a crack in the plastic.
    c.rect(0.92, 0.05, 1.32, 0.24, (66, 64, 60), 0.02)
    c.rect(1.1, 0.2, 1.16, 0.215, (30, 30, 30))
    c.rect(0.98, 0.12, 1.06, 0.124, (34, 32, 30))
    img = c.done(rng, grain=5, grime=False)
    save(img, "skoda_dash.png")


def main():
    side(True)
    side(False)
    front()
    back()
    door_panel()
    cloth("karosa_cloth.png", (196, 158, 70), seed=5)
    cloth("karosa_seat_cloth.png", TAN, seed=9, weave=7)
    leather()
    seat_back()
    dash()
    skoda_dash()


if __name__ == "__main__":
    main()
