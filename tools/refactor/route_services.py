"""I2b (TODO.md SPLITSCREEN): every `<Autoload>.<member>` goes to the instance's own copy:
CoreRoot -> INSTANCE.core(x), EventBus -> INSTANCE.bus(x), GuestManager -> INSTANCE.guests(x),
EmailManager -> INSTANCE.mail(x), Coop -> INSTANCE.coop(x). x: self in Node scripts, the
owner in RefCounted helpers (OWNER), `_world_root` in the enemy brains. Constants (UPPER)
stay; static funcs, inner classes and RefCounted helpers without an owner are reported."""
import glob
import os
import re
import sys

os.chdir("C:/grimroot/summercamp/godot")
CONST_LINE = 'const INSTANCE = preload("res://scripts/instance/instance.gd")'
SERVICES = {"CoreRoot": "core", "EventBus": "bus", "GuestManager": "guests", "EmailManager": "mail", "Coop": "coop"}
OWNER = {
    "scripts/coop/coop_camp.gd": "main", "scripts/demo/demo_end.gd": "main",
    "scripts/night/director_feed.gd": "main", "scripts/night/night_roll.gd": "main",
    "scripts/pipes/pipe_mate.gd": "host", "scripts/reception/desk_room.gd": "host",
    "scripts/reception/reception_extras.gd": "host", "scripts/reviews/camp_online.gd": "main",
    "scripts/save/camp_snapshot.gd": "main", "scripts/town/chapel_view.gd": "room",
    "scripts/town/motel_hall.gd": "room", "scripts/town/motel_nine.gd": "room",
    "scripts/town/motel_radio.gd": "room", "scripts/town/motel_view.gd": "room",
    "scripts/town/wc_view.gd": "room", "scripts/business/store_room.gd": "host",
    "scripts/camp/camp_structures.gd": "main", "scripts/camp/ruined_cabin.gd": "main",
    "scripts/debug/test_camps.gd": "main", "scripts/os98/icu_story.gd": "shell",
    "scripts/staff/staffroom.gd": "host", "scripts/ui/trouble_board.gd": "main",
}
BRAINS = "scripts/enemies/"
SKIP = {"scripts/instance/instance.gd"}
dry = "--dry" in sys.argv
only = [a for a in sys.argv[1:] if not a.startswith("--")]
services = {k: v for k, v in SERVICES.items() if not only or k in only}
files = sorted(set(f.replace("\\", "/") for f in glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("core/**/*.gd", recursive=True)))
total = 0
left = []
for p in files:
    if p in SKIP:
        continue
    raw = open(p, "rb").read()
    crlf = b"\r\n" in raw
    s = raw.decode("utf-8").replace("\r\n", "\n")
    res = {k: re.compile(r"(?<![\w\.])" + k + r"\.(?=[a-z_])") for k in services}
    if not any(r.search(s) for r in res.values()):
        continue
    m = re.search(r"^extends\s+(\S+)", s, re.M)
    ext = m.group(1) if m else "?"
    is_ref = ext in ("RefCounted", "Resource", "Object") or ext.startswith('"res://core')
    if p.startswith(BRAINS) and "_world_root" in s:
        who = "_world_root"
    elif is_ref:
        who = OWNER.get(p)
    else:
        who = "self"
    if who is None:
        left.append((p, "no owner", sum(len(r.findall(s)) for r in res.values())))
        continue
    out = []
    in_static = False
    in_inner = False
    n = 0
    for line in s.split("\n"):
        if re.match(r"^class \w+", line):
            in_inner = True
        elif re.match(r"^(static\s+)?func |^(var|const|signal|enum|@)", line):
            in_inner = False
        if re.match(r"^static\s+func ", line):
            in_static = True
        elif re.match(r"^func ", line):
            in_static = False
        hit = any(r.search(line) for r in res.values())
        if hit and (in_static or in_inner):
            left.append((p, "static" if in_static else "inner class", line.strip()[:90]))
            out.append(line)
            continue
        for k, r in res.items():
            line, c = r.subn("INSTANCE.%s(%s)." % (services[k], who), line)
            n += c
        out.append(line)
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
