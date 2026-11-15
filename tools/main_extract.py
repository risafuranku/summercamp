#!/usr/bin/env python3
"""Moves a stretch of godot/scripts/main.gd into a module of its own (the D0 clean-up,
TODO.md "DEMO AND STEAM"): the module gets `var main` and every name the stretch used of
main's (its vars, funcs and consts, found in main.gd and not declared in the stretch
itself) is written main.<name>; functions can be renamed on the way; main gets the
text given in its place (a const preload, a var holding the module, one-line facades).

    python tools/main_extract.py SPEC.json

SPEC: {"start": first line's text, "end": text of the line after the stretch,
       "module": "scripts/.../x.gd", "head": the module's text before the functions
       (extends, the doc, consts, vars; "@MAIN@" where `var main` and _init go),
       "rename": {"_old_func": "new"}, "drop": [exact text cut out of the stretch],
       "keep_names": [main names not to prefix (declared again in the module)],
       "replace_in_main": text put where the stretch was,
       "main_subs": [[regex, repl], ...] applied to main afterwards}

GDScript then says (a headless start) any name of main's still bare in the module, and
`python tools/main_refs_check.py` any main.<name> elsewhere that main no longer has.
"""
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.path.join(ROOT, "godot")
MAIN = os.path.join(GODOT, "scripts", "main.gd")
DECL = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|func|const|signal|enum)\s+(\w+)", re.M)
LOCAL = re.compile(r"(?:\bvar\s+|\bfor\s+|\bconst\s+)(\w+)")
PARAMS = re.compile(r"^func\s+\w+\(([^)]*)\)", re.M)
MAIN_HEAD = '''var main: Node


func _init(main_node: Node) -> void:
	main = main_node
'''


def main():
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    src = open(MAIN, encoding="utf-8").read()
    a = src.index(spec["start"])
    b = src.index(spec["end"], a)
    block = src[a:b]
    for d in spec.get("drop", []):
        assert d in block, d
        block = block.replace(d, "")
    rest = src[:a] + src[b:]
    main_names = (set(DECL.findall(rest)) | set(spec.get("extra_main_names", []))) - set(spec.get("keep_names", []))
    local = set(LOCAL.findall(block))
    for p in PARAMS.findall(block):
        for part in p.split(","):
            n = part.strip().split(":")[0].split("=")[0].strip()
            if n:
                local.add(n)
    declared_here = set(DECL.findall(block))
    names = sorted((main_names - local - declared_here), key=len, reverse=True)
    # A member renamed to a name a local already has would be shadowed by it (the old
    # cabin's `key = key`, 15. 11.).
    clash = set(spec.get("rename", {}).values()) & local
    assert not clash, "renamed onto locals: %s" % clash
    # ...or to a name main has (it would be written main.<name>: main's, not the module's).
    clash = set(spec.get("rename", {}).values()) & main_names
    assert not clash, "renamed onto main's names: %s" % clash
    m = block
    for old, new in spec.get("rename", {}).items():
        m = re.sub(r"(?<![\w.\"])" + re.escape(old) + r"\b", new, m)
        # Its name as a string where the string means this script's method (Callable(self,
        # "x"), a bare call_deferred("x")); not any "x" (bi.has_method("coop_screen_frame")
        # is another object's, and renaming it broke the co-op screen, 15. 11.).
        m = m.replace('Callable(self, "%s")' % old, 'Callable(self, "%s")' % new)
        m = re.sub(r'(?<![\w.])call_deferred\("%s"' % re.escape(old), 'call_deferred("%s"' % new, m)
    # Main's methods named in a string on self: main's.
    for n in main_names - declared_here:
        m = m.replace('Callable(self, "%s")' % n, 'Callable(main, "%s")' % n)
        m = re.sub(r'(?<![\w.])call_deferred\("%s"' % re.escape(n), 'main.call_deferred("%s"' % n, m)
    # A RefCounted has no tree: the Node's own calls go to main.
    for n in ["get_tree", "add_child", "remove_child", "get_viewport", "create_tween", "get_node_or_null",
              "get_node", "is_inside_tree", "get_process_delta_time", "get_physics_process_delta_time", "get_window"]:
        m = re.sub(r"(?<![\w.])" + n + r"\(", "main." + n + "(", m)
    # Main's names, not after a dot, outside strings and comments:
    out_lines = []
    for line in m.split("\n"):
        if line.lstrip().startswith("#"):
            out_lines.append(line)
            continue
        # Leave string literals alone: split on quotes, prefix only outside them.
        parts = re.split(r'("(?:[^"\\]|\\.)*")', line)
        for i in range(0, len(parts), 2):
            seg = parts[i]
            for n in names:
                seg = re.sub(r"(?<![\w.$])" + re.escape(n) + r"\b", "main." + n, seg)
            parts[i] = seg
        out_lines.append("".join(parts))
    m = "\n".join(out_lines)
    m = re.sub(r"\n{4,}", "\n\n\n", m)
    mod = os.path.join(GODOT, spec["module"])
    os.makedirs(os.path.dirname(mod), exist_ok=True)
    if spec.get("append"):
        # Into a module made before (it has main already): the stretch at its end.
        assert os.path.exists(mod), mod
        out = open(mod, encoding="utf-8").read().rstrip("\n") + "\n\n\n" + m.strip("\n") + "\n"
    else:
        if os.path.exists(mod):
            raise SystemExit("exists: " + mod)
        head = spec["head"].replace("@MAIN@", MAIN_HEAD)
        out = head.rstrip("\n") + "\n\n\n" + m.strip("\n") + "\n"
    open(mod, "w", encoding="utf-8").write(out)
    new_main = src[:a] + spec["replace_in_main"] + src[b:]
    for rx, repl in spec.get("main_subs", []):
        new_main = re.sub(rx, repl, new_main)
    open(MAIN, "w", encoding="utf-8").write(new_main)
    print("module", spec["module"], len(out.split("\n")), "lines; main", len(new_main.split("\n")), "lines")
    print("prefixed:", ", ".join(n for n in sorted(names) if re.search(r"main\." + re.escape(n) + r"\b", m)))


if __name__ == "__main__":
    main()
