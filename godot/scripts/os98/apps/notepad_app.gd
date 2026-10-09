extends Control

## Notepad: a menu line that does nothing much, and the text. You can type in it; there
## is nowhere to save it (the disk is full, says File > Save).

const T = preload("res://scripts/os98/os_theme.gd")
const FILES = preload("res://scripts/os98/os_files.gd")

var _shell
var _win
var _edit: TextEdit
var _file := ""


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	var menu := HBoxContainer.new()
	menu.position = Vector2(2, 1)
	menu.add_theme_constant_override("separation", 2)
	add_child(menu)
	for m in ["File", "Edit", "Search", "Help"]:
		var b := Button.new()
		b.text = m
		b.flat = true
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", T.flat(T.NAVY))
		b.add_theme_color_override("font_pressed_color", T.WHITE)
		var label: String = m
		b.pressed.connect(func(): _menu(label))
		menu.add_child(b)
	_edit = TextEdit.new()
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edit.offset_top = 20
	add_child(_edit)
	_load(str(args.get("file", "")))


func reopen(args: Dictionary) -> void:
	_load(str(args.get("file", "")))


func _load(file: String) -> void:
	_file = file
	_edit.text = FILES.text_of(file) if not file.is_empty() else ""
	_win.title = "%s - Notepad" % (file if not file.is_empty() else "Untitled")


func _menu(which: String) -> void:
	match which:
		"File":
			_shell.message_box("Notepad", "Cannot save %s.\n\nThe disk is full or write-protected." % (_file if not _file.is_empty() else "Untitled"), "error")
		"Help":
			_shell.message_box("About Notepad", "Notepad\nOkna 98\n\nThis product is licensed to:\nKemp Cerne jezero", "info")
		_:
			pass
