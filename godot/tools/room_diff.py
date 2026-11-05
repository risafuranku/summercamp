import glob
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

# A room seen from outside (W26): the pairs a_*.png (the room there) and b_*.png (not there)
# of tools/onesun_check --part=recdiff, what changes in each, the worst twelve marked in
# magenta in DIR/diff_top.png. Only the windows and the doorway may differ (and what moves by
# itself: trees in the wind, birds, the markers on the screen).
#   python godot/tools/room_diff.py DIR
d = sys.argv[1]
TH = 28
rows = []
for a in sorted(glob.glob(os.path.join(d, 'a_*.png'))):
    b = os.path.join(d, 'b_' + os.path.basename(a)[2:])
    A = np.asarray(Image.open(a).convert('RGB')).astype(np.int16)
    B = np.asarray(Image.open(b).convert('RGB')).astype(np.int16)
    h, w, _ = A.shape
    m = np.abs(A - B).max(axis=2) > TH
    # Not the HUD along the bottom nor the pager lines and the key label.
    m[int(h * 0.83):, :] = False
    m[:int(h * 0.05), :] = False
    m[int(h * 0.28):int(h * 0.42), int(w * 0.82):] = False
    rows.append((int(m.sum()), os.path.basename(a)[2:-4], a, b, m))
rows.sort(key=lambda r: -r[0])
for r in rows[:24]:
    print(r[0], r[1])
print('zero:', sum(1 for r in rows if r[0] == 0), 'of', len(rows))
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
sh.save(os.path.join(d, 'diff_top.png'))
