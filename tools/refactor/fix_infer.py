"""Fix 'Cannot infer the type' parse errors from a Godot log: `var x := <untyped>` -> `var x = ...`."""
import os
import re
import sys

os.chdir("C:/grimroot/summercamp/godot")
log = open(sys.argv[1], encoding="utf-8", errors="replace").read().split("\n")
todo = {}
for i, line in enumerate(log):
    if "Cannot infer the type" in line and i + 1 < len(log):
        m = re.search(r"res://([^:]+):(\d+)\)", log[i + 1])
        if m:
            todo.setdefault(m.group(1), set()).add(int(m.group(2)))
n = 0
for path, lines in todo.items():
    raw = open(path, "rb").read()
    crlf = b"\r\n" in raw
    rows = raw.decode("utf-8").replace("\r\n", "\n").split("\n")
    for ln in lines:
        row = rows[ln - 1]
        new = re.sub(r"^(\s*var\s+\w+)\s*:=", r"\1 =", row, count=1)
        if new != row:
            rows[ln - 1] = new
            n += 1
        else:
            print("NOFIX", path, ln, row.strip()[:80])
    s = "\n".join(rows)
    open(path, "wb").write((s.replace("\n", "\r\n") if crlf else s).encode("utf-8"))
print("fixed", n, "in", len(todo), "files")
