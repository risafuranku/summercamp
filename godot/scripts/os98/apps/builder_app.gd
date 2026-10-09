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
	_module.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_module)
	if _module.has_method("setup"):
		_module.setup(shell._grid_mgr, shell._building_mgr)
	if _module.has_method("set_day_mode"):
		_module.set_day_mode(shell.is_day())
	_focus.call_deferred()


func reopen(_args: Dictionary) -> void:
	_focus()


func _focus() -> void:
	if _module != null and _module.has_method("focus_map"):
		_module.focus_map()
