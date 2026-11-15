"""I5 (TODO.md SPLITSCREEN): the rooms' look (scripts/interior_look.gd) reads the input of the
instance it looks for. Its update() gets the node it looks for (`who`, the caller: self), its
static key axes too (turn_axis(who), tilt_axis(who), key_axis(who)). Run once."""
import glob
import os
import re

os.chdir("C:/grimroot/summercamp/godot")


def split_args(s, start):
    """The args of the call whose '(' is at s[start]: (list of (a, b) spans, index of ')')."""
    depth = 0
    spans = []
    i = start + 1
    a = i
    in_str = None
    while i < len(s):
        c = s[i]
        if in_str:
            if c == in_str and s[i - 1] != "\\":
                in_str = None
        elif c in "\"'":
            in_str = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                spans.append((a, i))
                return spans, i
            depth -= 1
        elif c == "," and depth == 0:
            spans.append((a, i))
            a = i + 1
        i += 1
    raise ValueError("unclosed call")


n_update = 0
n_axis = 0
for p in sorted(set(f.replace("\\", "/") for f in glob.glob("scripts/**/*.gd", recursive=True))):
    if p.endswith("interior_look.gd"):
        continue
    raw = open(p, "rb").read()
    crlf = b"\r\n" in raw
    s = raw.decode("utf-8").replace("\r\n", "\n")
    orig = s
    # look.update(delta, INTERIOR_LOOK.cursor_of(...), ...) -> ..., self)
    for m in reversed(list(re.finditer(r"\b(_look|look|look_back|look_store|look_bench|look_side)\.update\(", s))):
        open_i = m.end() - 1
        spans, close_i = split_args(s, open_i)
        if len(spans) >= 4:
            continue
        if "cursor_of" not in s[open_i:close_i]:
            continue
        extra = ", self" if len(spans) == 3 else ", 0.0, self"
        s = s[:close_i] + extra + s[close_i:]
        n_update += 1
    s2, k = re.subn(r"\b(INTERIOR_LOOK|LOOK)\.(turn_axis|tilt_axis|key_axis)\(\)", r"\1.\2(self)", s)
    n_axis += k
    s = s2
    if s != orig:
        open(p, "wb").write((s.replace("\n", "\r\n") if crlf else s).encode("utf-8"))
print("update calls", n_update, "axis calls", n_axis)
