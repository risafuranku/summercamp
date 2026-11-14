#!/usr/bin/env python3
"""After code moves out of godot/scripts/main.gd: every `main.<name>` (and main.call /
main.get / main.set / has_method with a literal name) in the scripts and tools must be
something main.gd still declares (var, func, const, signal) or a Node's own member.
GDScript checks an untyped `main` only when that line runs, so a function moved into a
module and still called on main breaks only in play; this finds it before.

    python tools/main_refs_check.py            every script and tool
    python tools/main_refs_check.py FILE...    only those

Prints each unknown name with where it is used; exit 1 if there is any.
"""
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.path.join(ROOT, "godot")
MAIN = os.path.join(GODOT, "scripts", "main.gd")

# What every Node (and Object) has: not main's own.
NODE = set("""
add_child remove_child get_child get_children get_child_count get_node get_node_or_null
find_child find_children has_node get_parent get_tree get_viewport get_window is_inside_tree
is_node_ready queue_free call call_deferred callv get set get_indexed set_indexed has_method
has_signal connect disconnect is_connected emit_signal set_process set_physics_process
set_process_input set_process_unhandled_input name owner process_mode get_script
set_meta get_meta has_meta remove_meta notification propagate_notification
is_queued_for_deletion get_instance_id tr tr_n is_class get_class free set_deferred
create_tween add_to_group is_in_group remove_from_group get_path print_tree
""".split())

# Other things called main (a lamp's main light, "main.tscn").
IGNORE = {"light_color", "light_energy", "omni_range", "position", "tscn"}

DECL = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|func|const|signal|enum)\s+(\w+)", re.M)
USE = re.compile(r"\bmain\.(\w+)")
LIT = re.compile(r"\bmain\.(?:call|call_deferred|get|set|has_method|has_signal)\(\s*\"(\w+)\"")
# Names the screenshot driver's eval strings call on main (they run with main as base).
EVAL = re.compile(r"\[\s*\"eval[s]?\"\s*,\s*\"([^\"]*)\"")
CALL_STEP = re.compile(r"\[\s*\"call\"\s*,\s*\"(\w+)\"")


def declared():
    src = open(MAIN, encoding="utf-8").read()
    names = set(DECL.findall(src))
    # main.gd extends Node3D/Node: its base members count too.
    return names | NODE | IGNORE


def files(args):
    if args:
        return args
    out = []
    for base in ("scripts", "core", "tools"):
        for dp, dn, fn in os.walk(os.path.join(GODOT, base)):
            for f in fn:
                if f.endswith(".gd") and not f.startswith("_tmp_"):
                    out.append(os.path.join(dp, f))
    return out


def main():
    have = declared()
    bad = {}
    for path in files(sys.argv[1:]):
        if os.path.abspath(path) == os.path.abspath(MAIN):
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        for n, line in enumerate(text.split("\n"), 1):
            if line.lstrip().startswith("#"):
                continue
            for name in USE.findall(line) + LIT.findall(line):
                if name not in have:
                    bad.setdefault(name, []).append("%s:%d" % (os.path.relpath(path, ROOT), n))
            if path.endswith("shot_driver.gd") or "check" in os.path.basename(path):
                for name in CALL_STEP.findall(line):
                    if name not in have:
                        bad.setdefault(name, []).append("%s:%d (call step)" % (os.path.relpath(path, ROOT), n))
    for name in sorted(bad):
        print(name, "  ", ", ".join(bad[name][:4]), "..." if len(bad[name]) > 4 else "")
    print("%d unknown" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
