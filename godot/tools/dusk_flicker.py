import glob
import os
import sys
import numpy as np
from PIL import Image

# The ground from the path at dusk (tools/y_check --y=duskpath, the user: "around 18:50 the
# paths started flashing red"): over the frames of DIR what flickers and what is red.
# Per stretch of 26 frames (about 7 s, 7 minutes of the clock): the share of ground pixels that
# changed brightness back and forth 4 times or more, and the share that was red at some frame
# and not at others (a red flash), the rest of the time the same pixel not red.
#   python godot/tools/dusk_flicker.py DIR
d = sys.argv[1]
fs = sorted(glob.glob(os.path.join(d, 'p_*.png')))
fr = []
for f in fs:
    a = np.asarray(Image.open(f).convert('RGB')).astype(np.int16)
    h, w, _ = a.shape
    # The ground, not the sky, the HUD or the markers at the right.
    fr.append(a[int(h * 0.56):int(h * 0.82), :int(w * 0.8)])
fr = np.stack(fr)
n = fr.shape[0]
print('frames', n, 'ground px', fr.shape[1] * fr.shape[2])
STEP = 26
for s0 in range(0, n - 1, STEP):
    part = fr[s0:s0 + STEP]
    if part.shape[0] < 6:
        continue
    lum = part.sum(axis=3) / 3.0
    dl = lum[1:] - lum[:-1]
    big = np.abs(dl) > 14
    sign = np.sign(dl) * big
    # Back and forth: the sign turns over.
    flips = np.zeros(lum.shape[1:], np.int16)
    last = np.zeros(lum.shape[1:], np.int16)
    for i in range(sign.shape[0]):
        cur = sign[i]
        turned = (cur != 0) & (last != 0) & (cur != last)
        flips += turned
        last = np.where(cur != 0, cur, last)
    red = (part[..., 0] > part[..., 1] * 1.45) & (part[..., 0] > 50)
    share = red.mean(axis=0)
    flash = ((share > 0.0) & (share < 0.5)).mean() * 100.0
    print('frames %3d-%3d  flicker %5.2f %%  red now and then %5.2f %%  red in a frame %5.2f %%' % (s0, s0 + part.shape[0] - 1, (flips >= 4).mean() * 100.0, flash, red.mean() * 100.0))
