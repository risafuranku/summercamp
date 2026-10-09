extends Control

## Builder 98 in its window: the site planner (builder_module.gd) fills the client area.
## The shell refuses to start it at night and closes it when the night comes.

var _shell
var _win
var _module: Control


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	clip_contents = true
	var script: Script = load("res://scripts/builder_module.gd")
	_module = script.new()
	_module.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_module)
	_module.setup(shell._grid_mgr, shell._building_mgr)
	_module.exit_requested.connect(func(): shell.close_app_window(win))
	_module.message_requested.connect(func(t: String, text: String, kind: String): shell.message_box(t, text, kind))
	_focus.call_deferred()
	# The shareware nag, once per sitting at the computer.
	if not shell.has_meta("builder_nagged"):
		shell.set_meta("builder_nagged", true)
		var left := maxi(1, 30 - CoreRoot.get_day())
		var nag := "Thank you for trying Builder 98!\n\nThis copy is not registered. You have %d days\nof your 30-day trial left.\n\nRegister for 990 Kc: Stavitel software, Brnenska 14, Jihlava." % left
		shell.message_box.call_deferred("Builder 98 - Unregistered", nag, "info", ["Continue"])


func reopen(_args: Dictionary) -> void:
	_focus()


func _focus() -> void:
	if _module != null:
		_module.focus_map()
