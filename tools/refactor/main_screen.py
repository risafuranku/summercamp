"""I4 (TODO.md SPLITSCREEN): main draws into its instance's own screen (scenes/main.tscn
Seat1/Screen): the world's view moved under it, everything main adds put on `_screen`, main's
own input heard inside the screen (scripts/instance/screen_input.gd). Run once."""
import os

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot"))
p = "scripts/main.gd"
raw = open(p, "rb").read()
crlf = b"\r\n" in raw
s = raw.decode("utf-8").replace("\r\n", "\n")


def rep(a, b, count=1):
    global s
    n = s.count(a)
    assert n == count, (a[:70], n)
    s = s.replace(a, b)


rep('@onready var _sub_viewport_container: SubViewportContainer = $SubViewportContainer\n',
    '## The instance\'s screen (scripts/instance/instance.gd screen_of): everything this warden\n'
    '## sees is drawn into it, the world\'s view and the UI; one player: the whole window.\n'
    '@onready var _screen: SubViewport = $Seat1/Screen\n'
    '@onready var _sub_viewport_container: SubViewportContainer = $Seat1/Screen/SubViewportContainer\n')
s = s.replace('= $SubViewportContainer/SubViewport/World3D', '= $Seat1/Screen/SubViewportContainer/SubViewport/World3D')
lines = s.split("\n")
n = 0
for i, l in enumerate(lines):
    st = l.lstrip("\t")
    if st.startswith("add_child("):
        lines[i] = l[: len(l) - len(st)] + "_screen." + st
        n += 1
s = "\n".join(lines)
print("main adds routed:", n)
rep("\tget_tree().root.add_child(_sign_paint)", "\t_screen.add_child(_sign_paint)")
rep("\tget_tree().root.add_child.call_deferred(keys)", "\t_screen.add_child.call_deferred(keys)")
rep('\tvar existing_econ = get_node_or_null("EconomyManager")', '\tvar existing_econ = _screen.get_node_or_null("EconomyManager")')
rep("func _input(event: InputEvent) -> void:\n\tvar mb := event as InputEventMouseButton",
    "## Main's input comes through its screen (scripts/instance/screen_input.gd, made in _ready),\n"
    "## heard where it was before the screen.\n"
    "func screen_input(event: InputEvent) -> void:\n\tvar mb := event as InputEventMouseButton")
rep("func _unhandled_input(event: InputEvent) -> void:\n\tif not _startup_bootstrap_complete:",
    "func screen_unhandled_input(event: InputEvent) -> void:\n\tif not _startup_bootstrap_complete:")
rep("\t\t_open_pause_menu()\n\t\tget_viewport().set_input_as_handled()\n\t\treturn\n",
    "\t\t_open_pause_menu()\n\t\t_screen.set_input_as_handled()\n\t\treturn\n")
rep("\t_apply_integer_canvas_scale()\n\tget_tree().root.size_changed.connect(_apply_integer_canvas_scale)\n\t_screen.add_child(HandCursor.new())\n",
    "\t_apply_integer_canvas_scale()\n\tget_tree().root.size_changed.connect(_apply_integer_canvas_scale)\n"
    "\t# Main's input heard inside its screen, first there (scripts/instance/screen_input.gd).\n"
    "\tvar heard := SCREEN_INPUT.new()\n\theard.name = \"MainInput\"\n\theard.main = self\n"
    "\t_screen.add_child(heard)\n\t_screen.move_child(heard, 0)\n"
    "\t_screen.add_child(HandCursor.new())\n")
rep('const INSTANCE = preload("res://scripts/instance/instance.gd")\n',
    'const INSTANCE = preload("res://scripts/instance/instance.gd")\n'
    'const SCREEN_INPUT = preload("res://scripts/instance/screen_input.gd")\n')
open(p, "wb").write((s.replace("\n", "\r\n") if crlf else s).encode("utf-8"))
print("ok")
