"""Characters the Czech translations use that a game font (BMFont .fnt) has no glyph for:
a missing one is drawn as a box. 2. 11.: „ was in no font and – not in the PC's (w95),
added to the .fnt files as entries that reuse a glyph they have (” set down, the hyphen).

  python tools/i18n/font_gaps.py
"""
import collections
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'godot')
po = open(G + '/locale/cs.po', encoding='utf-8').read()
used = collections.Counter()
for m in re.finditer(r'^msgstr(?:\[\d\])? ((?:".*"\n?)+)', po, re.M):
    text = ''.join(re.findall(r'"(.*)"', m.group(1)))
    for ch in text:
        if ord(ch) > 126:
            used[ch] += 1
print('non-ASCII characters in the Czech:', ''.join(sorted(used)))
for f in sorted(glob.glob(G + '/assets/fonts/*.fnt')):
    ids = set(int(x) for x in re.findall(r'^char id=(\d+)', open(f, encoding='utf-8', errors='replace').read(), re.M))
    missing = sorted((ch for ch in used if ord(ch) not in ids), key=lambda c: -used[c])
    print('%-16s %3d glyphs, missing: %s' % (os.path.basename(f), len(ids), ' '.join('%s(U+%04X x%d)' % (c, ord(c), used[c]) for c in missing)))
