"""I2 (TODO.md SPLITSCREEN): every `Coop.<member>` goes to the co-op side of the instance
it is made for. Node scripts: INSTANCE.coop(self). RefCounted helpers with an owner:
INSTANCE.coop(<owner>). Constants and the Role enum (Coop.UPPER) stay on the autoload,
static funcs and inner classes too (reported), and coop.gd itself is left alone."""
import glob
import os
import re
import sys

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot"))
CONST_LINE = 'const INSTANCE = preload("res://scripts/instance/instance.gd")'
OWNER = {
    "scripts/coop/coop_camp.gd": "main",
    "scripts/demo/demo_end.gd": "main",
    "scripts/night/director_feed.gd": "main",
    "scripts/night/night_roll.gd": "main",
    "scripts/pipes/pipe_mate.gd": "host",
    "scripts/reception/desk_room.gd": "host",
    "scripts/reception/reception_extras.gd": "host",
    "scripts/reviews/camp_online.gd": "main",
    "scripts/save/camp_snapshot.gd": "main",
    "scripts/town/chapel_view.gd": "room",
    "scripts/town/motel_hall.gd": "room",
    "scripts/town/motel_nine.gd": "room",
    "scripts/town/motel_radio.gd": "room",
    "scripts/town/motel_view.gd": "room",
    "scripts/town/wc_view.gd": "room",
}
SKIP = {"scripts/coop/coop.gd", "scripts/instance/instance.gd"}
RE = re.compile(r"(?<![\w\.])Coop\.(?=[a-z_])")
dry = "--dry" in sys.argv
files = sorted(set(f.replace("\\", "/") for f in glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("core/**/*.gd", recursive=True)))
total = 0
left = []
for p in files:
    if p in SKIP:
        continue
    raw = open(p, "rb").read()
    crlf = b"\r\n" in raw
    s = raw.decode("utf-8").replace("\r\n", "\n")
    if not RE.search(s):
        continue
    m = re.search(r"^extends\s+(\S+)", s, re.M)
    ext = m.group(1) if m else "?"
    is_ref = ext == "RefCounted" or ext.startswith('"res://core')
    owner = OWNER.get(p)
    if is_ref and owner is None:
        left.append((p, "RefCounted without an owner", len(RE.findall(s))))
        continue
    target = "INSTANCE.coop(%s)." % (owner if is_ref else "self")
    out = []
    in_static = False
    in_inner = False
    n = 0
    for line in s.split("\n"):
        if re.match(r"^class \w+", line):
            in_inner = True
        elif re.match(r"^(static\s+)?func ", line) or re.match(r"^(var|const|signal|enum|@)", line):
            in_inner = False
        if re.match(r"^static\s+func ", line):
            in_static = True
        elif re.match(r"^func ", line) or re.match(r"^\t*func ", line) and not line.startswith("\t\t"):
            in_static = line.lstrip().startswith("static")
        if (in_static or in_inner) and RE.search(line):
            left.append((p, "static" if in_static else "inner class", line.strip()[:90]))
            out.append(line)
            continue
        new, k = RE.subn(target, line)
        n += k
        out.append(new)
    if n == 0:
        continue
    s2 = "\n".join(out)
    if CONST_LINE not in s2:
        lines = s2.split("\n")
        idx = len(lines)
        for i, l in enumerate(lines):
            if l.startswith(("const ", "var ", "func ", "signal ", "@onready", "@export", "enum ", "static func ", "class ")):
                idx = i
                break
        lines.insert(idx, CONST_LINE)
        s2 = "\n".join(lines)
    total += n
    if not dry:
        open(p, "wb").write((s2.replace("\n", "\r\n") if crlf else s2).encode("utf-8"))
print("routed", total)
for x in left:
    print("LEFT", x)
