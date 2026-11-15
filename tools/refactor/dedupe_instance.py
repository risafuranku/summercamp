"""Drop `const INSTANCE = preload(...)` from scripts whose parent script already has it."""
import glob
import os
import re

os.chdir("C:/grimroot/summercamp/godot")
LINE = 'const INSTANCE = preload("res://scripts/instance/instance.gd")\n'
files = glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("core/**/*.gd", recursive=True) + glob.glob("tools/*.gd")
files = [f.replace("\\", "/") for f in files]
classmap = {}
for p in files:
    s = open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r"^class_name\s+(\w+)", s, re.M)
    if m:
        classmap[m.group(1)] = p


def parent(p):
    s = open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r'^extends\s+"res://([^"]+)"', s, re.M)
    if m:
        return m.group(1)
    m = re.search(r"^extends\s+(\w+)", s, re.M)
    if m and m.group(1) in classmap:
        return classmap[m.group(1)]
    return None


def has_const(p):
    return LINE.strip() in open(p, encoding="utf-8", errors="replace").read()


removed = []
for p in files:
    if not has_const(p):
        continue
    q = parent(p)
    hops = 0
    while q and hops < 10:
        if os.path.exists(q) and has_const(q):
            raw = open(p, "rb").read()
            crlf = b"\r\n" in raw
            s = raw.decode("utf-8").replace("\r\n", "\n")
            s = s.replace(LINE, "", 1)
            open(p, "wb").write((s.replace("\n", "\r\n") if crlf else s).encode("utf-8"))
            removed.append(p)
            break
        q = parent(q) if os.path.exists(q) else None
        hops += 1
print(removed)
