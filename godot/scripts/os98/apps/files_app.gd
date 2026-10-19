extends Control

## Files: the camp computer's disk on one page (it replaced My Computer, the folder
## windows, the Recycle Bin, Notepad and the image viewer). The places down the left
## (Vera's documents, the downloads, the bin, the whole disk), the folder's files in a
## list, and under it the file you picked: text to read, the one picture, or what the
## file is. A file in the bin has to be restored before it can be read.

const T = preload("res://scripts/os98/os_theme.gd")
const FILES = preload("res://scripts/os98/os_files.gd")
const IMAGES := {"IMG0043.JPG": "res://assets/textury/os98/img0043.png"}
const PLACES := [
	["C:\\VERA", "Documents", "documents"],
	["C:\\DOWNLOAD", "Downloads", "folder"],
	["BIN", "Recycle Bin", "bin"],
	["C:\\", "My Computer", "computer"],
]
const PLACES_W := 128
const BAR_H := 24
const LIST_H := 150

var _shell
var _win
var _path := "C:\\VERA"
var _file := ""
var _places: Control
var _up: Button
var _address: Label
var _list: Tree
var _view: Control
var _text: RichTextLabel
var _image: TextureRect
var _note: Label
var _restore: Button
var _status: Label
var _img_cache: Dictionary = {}


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_build()
	reopen(args)
	if not args.has("path"):
		refresh_listing()


func reopen(args: Dictionary) -> void:
	if args.has("path"):
		_path = str(args["path"])
		if _path == "My Computer":
			_path = "C:\\"
		_file = ""
		refresh_listing()
	if args.has("file"):
		_select_file(str(args["file"]))


func refresh() -> void:
	refresh_listing()


# ── building ─────────────────────────────────────────────────────────────────

func _build() -> void:
	_places = Control.new()
	_places.mouse_filter = Control.MOUSE_FILTER_STOP
	_places.draw.connect(_draw_places)
	_places.gui_input.connect(_places_input)
	add_child(_places)
	var bar := HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)
	_up = Button.new()
	_up.text = "Up"
	_up.custom_minimum_size = Vector2(36, 20)
	_up.focus_mode = Control.FOCUS_NONE
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
	_list = Tree.new()
	_list.columns = 2
	_list.column_titles_visible = true
	_list.hide_root = true
	_list.select_mode = Tree.SELECT_ROW
	_list.focus_mode = Control.FOCUS_CLICK
	_list.set_column_title(0, "Name")
	_list.set_column_title(1, "Type")
	for c in 2:
		_list.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		_list.set_column_clip_content(c, true)
	_list.set_column_expand(0, true)
	_list.set_column_expand(1, false)
	_list.set_column_custom_minimum_width(1, 150)
	_list.item_selected.connect(func():
		var it := _list.get_selected()
		if it != null:
			_show(str(it.get_metadata(0)))
	)
	_list.item_activated.connect(func():
		var it := _list.get_selected()
		if it != null:
			_activate(str(it.get_metadata(0)))
	)
	add_child(_list)
	_view = Panel.new()
	_view.add_theme_stylebox_override("panel", T.box("field", T.WHITE, Vector4.ZERO))
	_view.clip_contents = true
	add_child(_view)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.selection_enabled = false
	_text.focus_mode = Control.FOCUS_NONE
	_text.scroll_active = true
	_text.add_theme_stylebox_override("normal", T.flat(T.WHITE, Vector4(8, 6, 8, 6)))
	_view.add_child(_text)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.add_child(_image)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_view.add_child(_note)
	_restore = Button.new()
	_restore.text = "Restore to C:\\VERA"
	_restore.focus_mode = Control.FOCUS_NONE
	_restore.pressed.connect(_restore_file)
	_view.add_child(_restore)
	var status := Panel.new()
	status.name = "Status"
	status.add_theme_stylebox_override("panel", T.box("well", T.FACE, Vector4.ZERO))
	add_child(status)
	_status = Label.new()
	_status.position = Vector2(4, 2)
	status.add_child(_status)
	resized.connect(_layout)
	_layout()
	_show("")


func _layout() -> void:
	if _list == null:
		return
	var right := PLACES_W + 4.0
	_places.position = Vector2(2, 2)
	_places.size = Vector2(PLACES_W, size.y - 24)
	var bar: Control = get_node("Bar")
	bar.position = Vector2(right, 2)
	bar.size = Vector2(size.x - right - 2, 20)
	_list.position = Vector2(right, BAR_H + 2)
	_list.size = Vector2(size.x - right - 2, LIST_H)
	_view.position = Vector2(right, BAR_H + LIST_H + 6)
	_view.size = Vector2(size.x - right - 2, size.y - BAR_H - LIST_H - 30)
	_text.position = Vector2(2, 2)
	_text.size = _view.size - Vector2(4, 4)
	_image.position = Vector2(6, 6)
	_image.size = _view.size - Vector2(12, 12)
	_note.position = Vector2(56, 18)
	_note.size = Vector2(_view.size.x - 70, 60)
	_restore.position = Vector2(56, 84)
	_restore.size = Vector2(150, 24)
	var status: Control = get_node("Status")
	status.position = Vector2(0, size.y - 18)
	status.size = Vector2(size.x, 18)


# ── places ───────────────────────────────────────────────────────────────────

func _draw_places() -> void:
	var c := _places
	c.draw_style_box(T.box("field", Color8(232, 236, 244), Vector4.ZERO), Rect2(Vector2.ZERO, c.size))
	c.draw_string(T.FONT_BOLD, Vector2(8, 16), "Places", HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.NAVY)
	for i in PLACES.size():
		var r := Rect2(4, 24 + i * 40, c.size.x - 8, 38)
		var on := _place_of(_path) == str(PLACES[i][0])
		if on:
			c.draw_rect(r, T.NAVY)
		var ic := str(PLACES[i][2])
		if ic == "bin" and not _shell.bin_items().is_empty():
			ic = "bin_full"
		c.draw_texture(_shell.icon(ic), r.position + Vector2(2, 3))
		c.draw_string(T.FONT, r.position + Vector2(38, 23), str(PLACES[i][1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, T.FONT_SIZE, T.WHITE if on else T.TEXT)
	# Web View: the folder's name over the coloured rule, then what the picked file is.
	var y := 24.0 + PLACES.size() * 40 + 14
	var folder := "Recycle Bin" if _path == "BIN" else ("(C:)" if _path == "C:\\" else _path.trim_suffix("\\").get_slice("\\", _path.trim_suffix("\\").get_slice_count("\\") - 1))
	c.draw_string(T.FONT_BOLD, Vector2(8, y + 10), folder, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 16, T.FONT_SIZE, T.TEXT)
	var rule_w := c.size.x - 16
	for x in int(rule_w):
		var k := float(x) / rule_w
		var col: Color = T.NAVY.lerp(Color8(0, 160, 160), k * 2.0) if k < 0.5 else Color8(0, 160, 160).lerp(Color8(240, 210, 60), (k - 0.5) * 2.0)
		c.draw_rect(Rect2(8 + x, y + 16, 1, 2), col)
	y += 34
	if _file == "":
		c.draw_multiline_string(T.FONT, Vector2(8, y), "Select an item to view its description.", HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 16, T.FONT_SIZE, -1, T.TEXT)
		return
	c.draw_string(T.FONT_BOLD, Vector2(8, y), _file, HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 16, T.FONT_SIZE, T.TEXT)
	y += 16
	var lines: Array = [_kind_label(_file)]
	if FILES.MODIFIED.has(_file):
		lines.append("Modified: %s" % FILES.MODIFIED[_file])
	if not (_path != "BIN" and _shell.is_dir(_full(_file))):
		lines.append("Size: %d KB" % FILES.size_kb(_file))
	if _path == "BIN":
		lines.append("Original location:")
		lines.append("  C:\\VERA")
	for l in lines:
		c.draw_string(T.FONT, Vector2(8, y), str(l), HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 16, T.FONT_SIZE, T.TEXT)
		y += 14


func _place_of(path: String) -> String:
	if path == "BIN" or path == "C:\\VERA" or path == "C:\\DOWNLOAD":
		return path
	return "C:\\"


func _places_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := int((e.position.y - 24) / 40)
		if e.position.y >= 24 and i >= 0 and i < PLACES.size():
			_shell.play("click", -14.0)
			_path = str(PLACES[i][0])
			_file = ""
			refresh_listing()


# ── the list ─────────────────────────────────────────────────────────────────

func refresh_listing() -> void:
	if _list == null:
		return
	_list.clear()
	var root := _list.create_item()
	var items: Array = _shell.list_dir(_path)
	var keep: TreeItem = null
	for name in items:
		var n := str(name)
		var it := _list.create_item(root)
		it.set_text(0, n)
		it.set_icon(0, _icon_for(n))
		it.set_text(1, _kind_label(n))
		it.set_metadata(0, n)
		if n == _file:
			keep = it
	_address.text = "Recycle Bin" if _path == "BIN" else _path
	_win.title = "Files - " + ("Recycle Bin" if _path == "BIN" else _path)
	_status.text = "%d object(s)" % items.size()
	if _path == "BIN" and not items.is_empty():
		_status.text += "      Pick a file to restore it."
	_up.disabled = _path == "C:\\" or _path == "BIN"
	if keep != null:
		keep.select(0)
	else:
		_show("")
	_places.queue_redraw()


func _go_up() -> void:
	if _path.begins_with("C:\\") and _path != "C:\\":
		var cut := _path.trim_suffix("\\").rfind("\\")
		_path = "C:\\" if cut <= 2 else _path.substr(0, cut)
		_file = ""
		refresh_listing()


func _full(name: String) -> String:
	return _path.trim_suffix("\\") + "\\" + name


func _icon_for(name: String) -> Texture2D:
	if _path != "BIN" and _shell.is_dir(_full(name)):
		return _shell.icon("folder", true)
	if _shell.installer_of(name) != "":
		return _shell.icon("setup", true)
	match FILES.file_kind(name):
		"text":
			return _shell.icon("txt", true)
		"exe":
			var app := str(FILES.EXE_APPS.get(name, ""))
			if app != "" and _shell.PROGRAMS.has(app):
				return _shell.icon(str(_shell.PROGRAMS[app]["icon"]), true)
			if app != "":
				return _shell.icon({"mail": "mail", "browser": "browser"}.get(app, "setup"), true)
			return _shell.icon("setup", true)
		"image":
			return _shell.icon("image", true)
	return _shell.icon("txt", true)


func _kind_label(name: String) -> String:
	if _path != "BIN" and _shell.is_dir(_full(name)):
		return "File Folder"
	if _shell.installer_of(name) != "":
		return "Setup program"
	match FILES.file_kind(name):
		"text":
			return "Text Document"
		"exe":
			return "Application"
		"image":
			return "JPEG Image"
	return "%s File" % name.get_extension().to_upper()


func _select_file(name: String) -> void:
	_file = name
	var root := _list.get_root()
	var rows: Array = root.get_children() if root != null else []
	for it in rows:
		if str(it.get_metadata(0)) == name:
			it.select(0)
			_list.scroll_to_item(it)
			return
	_show(name)


## Double-click: into a folder, or run it.
func _activate(name: String) -> void:
	if _path != "BIN" and _shell.is_dir(_full(name)):
		_path = _full(name)
		_file = ""
		refresh_listing()
		return
	if _path == "BIN":
		return
	match FILES.file_kind(name):
		"text", "image":
			_show(name)
		_:
			_shell.open_file(_path, name)


# ── the file, below ──────────────────────────────────────────────────────────

func _show(name: String) -> void:
	_file = name
	_places.queue_redraw()
	_text.visible = false
	_image.visible = false
	_note.visible = false
	_restore.visible = false
	if name == "":
		_note.visible = true
		_note.position = Vector2(12, 12)
		_note.text = "Select a file to view it."
		_note.add_theme_color_override("font_color", T.SHADOW)
		return
	_note.remove_theme_color_override("font_color")
	_note.position = Vector2(56, 18)
	if _path == "BIN":
		_note.visible = true
		_restore.visible = true
		_note.text = "%s is in the Recycle Bin.\nRestore it to its original place to open it." % name
		_view.queue_redraw()
		return
	if _shell.is_dir(_full(name)):
		_note.visible = true
		_note.text = "%s\nFile Folder. Double-click to open it." % name
		return
	match FILES.file_kind(name):
		"text":
			_text.visible = true
			_text.text = FILES.text_of(name) if FILES.text_of(name) != "" else "(empty)"
			_text.scroll_to_line(0)
		"image":
			var path := str(IMAGES.get(name, ""))
			if path != "" and ResourceLoader.exists(path):
				if not _img_cache.has(path):
					_img_cache[path] = load(path)
				_image.texture = _img_cache[path]
				_image.visible = true
			else:
				_note.visible = true
				_note.text = "Cannot read %s.\nThe file is damaged or the format is not supported." % name
		"exe":
			_note.visible = true
			var prog: String = _shell.installer_of(name)
			_note.text = ("%s\nSetup program. Double-click to install %s." % [name, _shell.PROGRAMS[prog]["title"]]) if prog != "" else ("%s\nApplication. Double-click to run it." % name)
		_:
			_note.visible = true
			_note.text = "%s\nThis file is used by the system or another program\nand cannot be opened." % name


func _restore_file() -> void:
	if _file == "" or _path != "BIN":
		return
	var name := _file
	_path = "C:\\VERA"
	_file = name
	_shell.play("click", -10.0)
	_shell.restore_from_bin(name)
	_select_file(name)
