#!/usr/bin/env python3
"""Functions nobody calls (the D0 clean-up, TODO.md "DEMO AND STEAM"): every `func name`
in godot/scripts and godot/core whose name appears nowhere else in the project (scripts,
core, tools, scenes, as a call, a Callable, a string or a signal hookup). Engine callbacks
(_ready, _process, _draw, _gui_input...) and the debug hooks the tools call (main_debug.gd)
are left out. A name used only in comments still counts as used (a lead to look at).

    python tools/dead_code.py            the list, by file
    python tools/dead_code.py --count    only how many

Read each one before cutting it: GDScript calls by string too (call("x"), has_method,
Callable(obj, "x"), connect), and some are kept for a coming feature.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.path.join(ROOT, "godot")
ENGINE = set("""
_ready _process _physics_process _input _unhandled_input _unhandled_key_input _gui_input
_draw _notification _enter_tree _exit_tree _init _to_string _get _set _get_property_list
_validate_property _can_drop_data _drop_data _get_drag_data _has_point _make_custom_tooltip
_get_minimum_size _structured_text_parser _integrate_forces _shortcut_input _run
_get_configuration_warnings _property_can_revert _property_get_revert _iter_init _iter_next
_iter_get _clips_input
""".split())
FUNC = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(", re.M)


def files(exts, bases):
    for base in bases:
        for dp, dn, fn in os.walk(os.path.join(GODOT, base)):
            if ".godot" in dp:
                continue
            for f in fn:
                if f.endswith(exts) and not f.startswith("_tmp_"):
                    yield os.path.join(dp, f)


def main():
    texts = {p: open(p, encoding="utf-8", errors="replace").read() for p in files((".gd", ".tscn", ".tres"), ["scripts", "core", "tools", "scenes", "modules", "data"])}
    words = {}
    for p, t in texts.items():
        for w in re.findall(r"\w+", t):
            words[w] = words.get(w, 0) + 1
    dead = []
    for p, t in texts.items():
        if not p.endswith(".gd") or os.sep + "tools" + os.sep in p or p.endswith("main_debug.gd"):
            continue
        for name in FUNC.findall(t):
            if name in ENGINE:
                continue
            # The definition itself is one use.
            if words.get(name, 0) <= 1:
                dead.append((os.path.relpath(p, GODOT), name))
    if "--count" in sys.argv:
        print(len(dead))
        return
    last = ""
    for p, name in sorted(dead):
        if p != last:
            print(p)
            last = p
        print("   ", name)
    print("%d functions nobody names" % len(dead))


if __name__ == "__main__":
    main()
