"""The skies at the render's own fine pixel, two halves of the sky each its own render
(agent C, 20. 10.: "nove nebe jsou moc hrube pixelated, stare mely jemnejsi rozliseni, a
byly vic do ruda").

    python tools/artgen/sky_fine.py [name ...]

Each sky (prompts_sky.tsv) is two Grok renders of the upper half of the sky, 16:9: the
side toward the glow and the side away from it (the west and the east of an evening, the
other way round at dawn; two parts of one overcast). They go side by side round the
panorama for the sky shader (weather_visuals.gd, SKY_COORDS: u 0.25 is +X, the west where
the sun goes down; u 0.75 the east), each centred on its side, the two seams blended over
a band (the render a little mirrored past its edge into the other); 2560 x 1440, the
render's pixels as they are (the earlier skies took Grok's 4-wide pixels down to one and
drew each 4 x 4 again: blocks some 14 screen pixels wide at 1080p). Below the horizon,
each column's horizon colour, smoothed along and darkening. A limited palette, no dither.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SKY = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "skybox")
W, H = 1280, 720    # one half of the sky, the upper hemisphere
SEAM = 280          # half the width of the blend at a seam (the two halves' colours differ)
COLORS = 160
DEBLOCK = 3
EDGE = 6

# name -> (render on u 0..0.5 [centred on u 0.25, the west], render on u 0.5..1 [the east])
SKIES = {
    "skyf_dawn.png": ("skyf_dawn_w", "skyf_dawn_e"),
    "skyf_golden.png": ("skyf_golden_w", "skyf_golden_e"),
    "skyf_sunset.png": ("skyf_sunset_w", "skyf_sunset_e"),
    "skyf_blood.png": ("skyf_sunset_w", "skyf_sunset_e"),
    "skyf_blue.png": ("skyf_blue_w", "skyf_blue_e"),
    "skyf_grey.png": ("skyf_grey_a", "skyf_grey_b"),
    "skyf_greyeve.png": ("skyf_greyeve_w", "skyf_greyeve_e"),
}


def render(art_id: str) -> np.ndarray:
    """The render without Grok's blocks: its fuzzy 4-wide pixels (on no exact grid) taken
    down by area to a third and brought back up smooth; the limited palette then gives the
    gradients their bands, and the post pass's own pixel the rest."""
    im = Image.open(os.path.join(OUT, art_id, "raw.png")).convert("RGB")
    # Grok sometimes draws a line round the picture's edge: a seam's line in the sky.
    im = im.crop((EDGE, EDGE, im.width - EDGE, im.height - EDGE))
    im = im.resize((W // DEBLOCK, H // DEBLOCK), Image.BOX).resize((W, H), Image.BICUBIC)
    return np.asarray(im).astype(np.float32)


def smooth_cols(a: np.ndarray, k: int) -> np.ndarray:
    """A row of colours box-blurred along, wrapping round the panorama."""
    n = a.shape[0]
    pad = np.concatenate([a[-k:], a, a[:k]])
    cs = np.concatenate([np.zeros((1, 3)), pad.cumsum(0)])
    return (cs[2 * k + 1:] - cs[:-2 * k - 1])[:n] / (2 * k + 1)


def blood(up: np.ndarray) -> np.ndarray:
    """The sunset's renders after dark (the user 20. 10.: "ruda puvodni byla darker po
    setmeni, az krvave", as the Redneck dusk was): high up almost black wine, down to a
    deep blood red, an ember line along the horizon; the west crimson, the east plum."""
    y = (np.arange(H) / (H - 1))[:, None, None]
    k = 0.26 + 0.45 * y ** 1.4 + 0.20 * np.clip((y - 0.9) / 0.1, 0.0, 1.0)
    u = (np.arange(2 * W) + 0.5) / (2 * W)
    west = (0.5 + 0.5 * np.cos(2.0 * np.pi * (u - 0.25)))[None, :, None]
    crimson = np.array([1.0, 0.38, 0.30])
    plum = np.array([0.85, 0.30, 0.55])
    tint = crimson * west + plum * (1.0 - west)
    # The ember line keeps more of its orange.
    ember = np.clip((y - 0.93) / 0.07, 0.0, 1.0) * west
    tint = tint * (1.0 - ember) + np.array([1.0, 0.62, 0.40]) * ember
    return up * k * tint


TONES = {"skyf_blood.png": (blood, 0.75)}


def build(name: str, west_id: str, east_id: str) -> None:
    a, b = render(west_id), render(east_id)
    # Each row of each half shifted toward the other's colour the nearer it is to a seam
    # (half way at the seam, its own at its middle): the two halves' skies meet there
    # instead of standing side by side like curtains.
    ma, mb = a.mean(axis=1, keepdims=True), b.mean(axis=1, keepdims=True)
    toward = 0.5 - 0.5 * np.cos(np.pi * np.abs((np.arange(W) + 0.5) / W - 0.5) * 2.0)
    toward = (0.5 * toward)[None, :, None]
    a, b = a + toward * (mb - ma), b + toward * (ma - mb)
    up = np.concatenate([a, b], axis=1)               # 720 x 2560
    # The seams at u 0.5 (a -> b) and u 0 (b -> a, round the back).
    for left, right, s in ((a, b, W), (b, a, 0)):
        for d in range(-SEAM, SEAM):
            t = (d + SEAM + 0.5) / (2 * SEAM)
            t = t * t * (3 - 2 * t)
            # Past its own edge each render is mirrored back on itself.
            lc = left[:, W - 1 - d] if d >= 0 else left[:, W + d]
            rc = right[:, d] if d >= 0 else right[:, -d - 1]
            up[:, (s + d) % (2 * W)] = lc * (1 - t) + rc * t
    tone, below = TONES.get(name, (None, 0.45))
    if tone is not None:
        up = tone(up)
    # Below the horizon: the horizon's last rows, smoothed along, going in a few rows to a
    # darker shade of it and staying (behind the trees; a long gradient banded in curves).
    horizon = smooth_cols(up[H - 6: H].mean(axis=0), 200)
    low = np.empty_like(up)
    f = 1.0 - below * np.clip(np.arange(H) / (H * 0.12), 0.0, 1.0)
    low[:] = horizon[None, :, :] * f[:, None, None]
    pano = np.concatenate([up, low], axis=0)
    img = Image.fromarray(pano.clip(0, 255).astype(np.uint8))
    img = img.quantize(colors=COLORS, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    dst = os.path.join(SKY, name)
    img.save(dst, optimize=True)
    print("->", dst, img.size, os.path.getsize(dst) // 1024, "KB")


if __name__ == "__main__":
    want = sys.argv[1:] or list(SKIES)
    for name, (w, e) in SKIES.items():
        if name in want or name.removesuffix(".png") in want:
            if all(os.path.exists(os.path.join(OUT, i, "raw.png")) for i in (w, e)):
                build(name, w, e)
            else:
                print("missing renders for", name)
