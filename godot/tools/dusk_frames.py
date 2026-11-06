import glob
import os
import sys
import numpy as np
from PIL import Image

# Frame by frame at the red hour (tools/y_check --y=duskpath saves every frame as dNNN.png): the
# ground's brightness and red from one frame to the next, a flash of a frame or two shows
# as a jump that goes back at once.
#   python godot/tools/dusk_frames.py DIR
d = sys.argv[1]
fs = sorted(glob.glob(os.path.join(d, 'd[0-9][0-9][0-9].png')))
lum, red, prev, moved = [], [], None, []
for f in fs:
    a = np.asarray(Image.open(f).convert('RGB')).astype(np.float32)
    h, w, _ = a.shape
    g = a[int(h * 0.56):int(h * 0.82), :int(w * 0.8)]
    lum.append(g.mean())
    red.append(((g[..., 0] > g[..., 1] * 1.45) & (g[..., 0] > 50)).mean() * 100.0)
    if prev is not None:
        moved.append((np.abs(g - prev).max(axis=2) > 24).mean() * 100.0)
    prev = g
lum, red, moved = np.array(lum), np.array(red), np.array(moved)
print('frames', len(fs))
print('ground brightness: %.2f .. %.2f, red %.2f .. %.2f %%' % (lum.min(), lum.max(), red.min(), red.max()))
print('pixels changing from one frame to the next: median %.2f %%, worst %.2f %%' % (np.median(moved), moved.max()))
# A flash: up and down again within three frames.
fl = 0
for i in range(1, len(lum) - 3):
    up = lum[i] - lum[i - 1]
    if abs(up) > 1.2 and abs(lum[i + 2] - lum[i - 1]) < abs(up) * 0.4:
        fl += 1
print('flashes (brightness jumps over 1.2 that go back within 2 frames):', fl)
print('worst frames:', [(int(i), round(float(moved[i]), 1)) for i in np.argsort(moved)[-6:][::-1]])
