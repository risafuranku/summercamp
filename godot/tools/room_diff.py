import glob
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

# A room seen from outside (W26): the pairs a_*.png (the room there) and b_*.png (not there)
# of tools/onesun_check --part=recdiff or --part=recgraze, what changes in each, the worst
# twelve marked in magenta in DIR/diff_top.png. Only the windows and the doorway may differ
# (and what moves by itself: trees in the wind, birds, the markers on the screen). With a
# views.json (--part=recgraze) only the walls count, the openings cut out of them: there
# nothing of the room may show, so the count must be 0.
#   python godot/tools/room_diff.py DIR [prefix]
d = sys.argv[1]
prefix = sys.argv[2] if len(sys.argv) > 2 else ''
TH = 28
views = {}
vp = os.path.join(d, 'views.json')
if os.path.exists(vp):
    views = json.load(open(vp, encoding='utf-8'))


def wall_mask(view, w, h):
    im = Image.new('L', (w, h), 0)
    dr = ImageDraw.Draw(im)
    for p in view['walls']:
        if len(p) >= 3:
            dr.polygon([(x * w, y * h) for x, y in p], fill=255)
    for p in view['holes']:
        if len(p) >= 3:
            pts = [(x * w, y * h) for x, y in p]
            dr.polygon(pts, fill=0)
            dr.line(pts + pts[:1], fill=0, width=9)
    return np.asarray(im) > 0


rows = []
for a in sorted(glob.glob(os.path.join(d, 'a_' + prefix + '*.png'))):
    name = os.path.basename(a)[2:-4]
    b = os.path.join(d, 'b_' + name + '.png')
    A = np.asarray(Image.open(a).convert('RGB')).astype(np.int16)
    B = np.asarray(Image.open(b).convert('RGB')).astype(np.int16)
    h, w, _ = A.shape
    m = np.abs(A - B).max(axis=2) > TH
    # Not the HUD along the bottom nor the pager lines and the key label.
    m[int(h * 0.83):, :] = False
    m[:int(h * 0.05), :] = False
    m[int(h * 0.28):int(h * 0.42), int(w * 0.82):] = False
    if name in views:
        m &= wall_mask(views[name], w, h)
    rows.append((int(m.sum()), name, a, b, m))
rows.sort(key=lambda r: -r[0])
for r in rows[:24]:
    print(r[0], r[1])
print('zero:', sum(1 for r in rows if r[0] == 0), 'of', len(rows), ' total px:', sum(r[0] for r in rows))
top = rows[:12]
cw, ch = 400, 225
sh = Image.new('RGB', (cw * 4, (ch + 14) * 3), (0, 0, 0))
dr = ImageDraw.Draw(sh)
for i, r in enumerate(top):
    im = Image.open(r[2]).convert('RGB')
    arr = np.asarray(im).copy()
    arr[r[4]] = (255, 0, 255)
    o = Image.fromarray(arr).resize((cw, ch), Image.NEAREST)
    x, y = (i % 4) * cw, (i // 4) * (ch + 14)
    sh.paste(o, (x, y))
    dr.text((x + 3, y + ch + 1), '%s  %d px' % (r[1], r[0]), fill=(255, 255, 0))
sh.save(os.path.join(d, 'diff_top%s.png' % ('_' + prefix if prefix else '')))
