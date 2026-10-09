extends Control

## My Computer, the Recycle Bin and every folder: an address line, large icons on white,
## a status bar. Double-click opens (shell.open_file), Up goes to the parent folder.

const T = preload("res://scripts/os98/os_theme.gd")
const FILES = preload("res://scripts/os98/os_files.gd")

var _shell
var _win
var _path := "My Computer"
var _address: Label
var _grid: Control
var _status: Label
var _up: Button
var _selected := ""


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	match win.app_id:
		"bin":
			_path = "BIN"
		"mycomputer":
			_path = "My Computer"
		_:
			_path = str(args.get("path", "C:\\"))
	_build()
	refresh_listing()


func reopen(args: Dictionary) -> void:
	if args.has("path"):
		_path = str(args["path"])
		refresh_listing()


func _build() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(2, 2)
	bar.size = Vector2(size.x - 4, 22)
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	_up = Button.new()
	_up.text = "Up"
	_up.custom_minimum_size = Vector2(36, 20)
	_up.pressed.connect(_go_up)
	bar.add_child(_up)
	var lab := Label.new()
	lab.text = "Address"
	bar.add_child(lab)
	var field := Panel.new()
	field.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size = Vector2(0, 20)
	bar.add_child(field)
	_address = Label.new()
	_address.position = Vector2(6, 3)
	field.add_child(_address)
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
	well.position = Vector2(0, 26)
	well.size = Vector2(size.x, size.y - 46)
	add_child(well)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(2, 2)
	scroll.size = well.size - Vector2(4, 4)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = maxi(1, int((size.x - 24) / 76))
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)
	var status := Panel.new()
	status.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	status.position = Vector2(0, size.y - 18)
	status.size = Vector2(size.x, 18)
	add_child(status)
	_status = Label.new()
	_status.position = Vector2(4, 2)
	status.add_child(_status)


func refresh_listing() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = _shell.list_dir(_path)
	for name in items:
		_grid.add_child(_make_item(str(name)))
	_address.text = "Recycle Bin" if _path == "BIN" else _path
	_win.title = _title_for(_path)
	_status.text = "%d object(s)" % items.size()
	if _path == "BIN" and not items.is_empty():
		_status.text += "      Double-click a file to restore it."
	_up.disabled = _path == "My Computer" or _path == "BIN"


func _go_up() -> void:
	if _path == "C:\\":
		_path = "My Computer"
	elif _path.begins_with("C:\\"):
		var cut := _path.trim_suffix("\\").rfind("\\")
		_path = "C:\\" if cut <= 2 else _path.substr(0, cut)
	refresh_listing()


func _title_for(path: String) -> String:
	match path:
		"BIN":
			return "Recycle Bin"
		"My Computer":
			return "My Computer"
		"C:\\":
			return "(C:)"
	var parts := path.trim_suffix("\\").split("\\")
	return parts[parts.size() - 1]


func _icon_for(name: String) -> Texture2D:
	if _path == "My Computer":
		return _shell.icon("floppy" if name.begins_with("3 1/2") else "drive")
	var full := _path.trim_suffix("\\") + "\\" + name
	if _path != "BIN" and _shell.is_dir(full):
		return _shell.icon("folder")
	if _shell.INSTALLERS.has(name):
		return _shell.icon("setup")
	match FILES.file_kind(name):
		"text":
			return _shell.icon("txt")
		"exe":
			var app := str(FILES.EXE_APPS.get(name, ""))
			if not app.is_empty() and _shell.APPS.has(app):
				return _shell.icon(str(_shell.APPS[app]["icon"]))
			return _shell.icon("setup")
		"image":
			return _shell.icon("image")
	return _shell.icon("txt")


func _make_item(name: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(74, 62)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var tex := _icon_for(name)
	c.draw.connect(func():
		var sel := _selected == name
		c.draw_texture(tex, Vector2(21, 2), Color(0.55, 0.55, 1.0) if sel else Color.WHITE)
		var lines := _wrap(name, 70)
		var y := 47.0
		for l in lines:
			var tw := T.FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
			var tx := floorf((74 - tw) * 0.5)
			if sel:
				c.draw_rect(Rect2(tx - 1, y - 11, tw + 2, 13), T.NAVY)
			c.draw_string(T.FONT, Vector2(tx, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.WHITE if sel else T.TEXT)
			y += 12
	)
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_selected = name
			for k in _grid.get_children():
				k.queue_redraw()
			if e.double_click:
				_open(name)
	)
	return c


func _open(name: String) -> void:
	var full := _path.trim_suffix("\\") + "\\" + name
	if _path == "My Computer" and name == "(C:)":
		_path = "C:\\"
		refresh_listing()
	elif _path != "BIN" and _path != "My Computer" and _shell.is_dir(full):
		_path = full
		refresh_listing()
	else:
		_shell.open_file(_path, name)


func _wrap(text: String, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line.is_empty() else line + " " + word
		if T.FONT.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = cand
	if not line.is_empty():
		out.append(line)
	return out.slice(0, 2)
