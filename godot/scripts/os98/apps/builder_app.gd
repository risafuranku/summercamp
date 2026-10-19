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
	_module.confirm_requested.connect(func(t: String, text: String, on_yes: Callable):
		shell.message_box(t, text, "question", ["Yes", "No"], func(b: String):
			if b == "Yes":
				on_yes.call()))
	_module.program_requested.connect(func(id: String): shell.open_app(id))
	_focus.call_deferred()
	# The shareware nag, once per sitting at the computer, after the title picture.
	if not shell.has_meta("builder_nagged"):
		shell.set_meta("builder_nagged", true)
		var left := maxi(1, 30 - CoreRoot.get_day())
		var nag := "Thank you for trying Builder 98!\n\nThis copy is not registered. You have %d days\nof your 30-day trial left.\n\nRegister for 990 Kc: Stavitel software, Brnenska 14, Jihlava." % left
		_module.splash_finished.connect(func(): shell.message_box("Builder 98 - Unregistered", nag, "info", ["Continue"]), CONNECT_ONE_SHOT)


func reopen(_args: Dictionary) -> void:
	_focus()


func shown() -> void:
	_focus()


## Another program pointed at a building: the map goes there and its card opens.
func focus_building(coord: Vector2i) -> void:
	if _module == null:
		return
	var map = _module._map_panel
	var info: Dictionary = map.structure_at(coord)
	if not _module.camp_focused:
		_module.camp_focused = map.focus_camp()
	map.debug_center_on(coord)
	map.inspect_origin = info.get("origin", Vector2i(-1, -1))
	map.inspect_footprint = info.get("footprint", Vector2i.ONE)
	_module._open_category("")
	_module._select("")
	_module._on_building_clicked(info)


func _focus() -> void:
	if _module != null:
		_module.focus_map()
