extends Control

## Display Properties (right-click the desktop > Properties): the wallpaper and the
## screen saver, with the little monitor that previews them, OK / Cancel / Apply.

const T = preload("res://scripts/os98/os_theme.gd")
const WALLPAPERS := [
	["(None)", ""],
	["Autumn Lake", "res://assets/textury/os98/wall_autumn.png"],
	["Okna", "res://assets/textury/os98/wall_okna.png"],
	["Kemp", "res://assets/textury/crt/UI/bios/wallpaper.png"],
	["Clouds", "res://assets/textury/os98/splash_sky.png"],
	["Black Lake", "res://assets/textury/os98/wall_lake.png"],
	["Camp 97", "res://assets/textury/web/web_camp.png"],
	["Pine boards", "res://assets/textury/camp/knotty_pine.png"],
]
const WAITS := [1, 2, 5, 10, 15]
var _wall_tex := {}

var _shell
var _win
var _tabs: TabContainer
var _list: ItemList
var _saver: OptionButton
var _wait: OptionButton
var _preview: Control
var _wall_i := 1
var _saver_i := 0
var _t := 0.0


func setup(shell, win, _args: Dictionary) -> void:
	_shell = shell
	_win = win
	win.can_maximize = false
	_wall_i = 0
	for i in WALLPAPERS.size():
		if WALLPAPERS[i][1] == _shell.wallpaper_path():
			_wall_i = i
	_saver_i = maxi(0, _shell.extras().SAVERS.find(_shell.extras().saver))
	_preview = Control.new()
	_preview.position = Vector2((size.x - 150) * 0.5, 8)
	_preview.size = Vector2(150, 120)
	# Loaded here, not in the draw (a texture first loaded inside a draw call comes out white).
	for w in WALLPAPERS:
		if str(w[1]) != "" and ResourceLoader.exists(str(w[1])):
			_wall_tex[str(w[1])] = load(str(w[1]))
	_preview.draw.connect(_draw_preview)
	add_child(_preview)
	_tabs = TabContainer.new()
	_tabs.position = Vector2(8, 134)
	_tabs.size = Vector2(size.x - 16, size.y - 134 - 36)
	add_child(_tabs)
	var bg := Control.new()
	bg.name = "Background"
	_tabs.add_child(bg)
	var lab := Label.new()
	lab.text = "Wallpaper:"
	lab.position = Vector2(8, 6)
	bg.add_child(lab)
	_list = ItemList.new()
	_list.position = Vector2(8, 24)
	_list.size = Vector2(200, 70)
	for w in WALLPAPERS:
		_list.add_item(str(w[0]))
	_list.select(_wall_i)
	_list.item_selected.connect(func(i): _wall_i = i; _preview.queue_redraw())
	bg.add_child(_list)
	var ss := Control.new()
	ss.name = "Screen Saver"
	_tabs.add_child(ss)
	var l2 := Label.new()
	l2.text = "Screen Saver:"
	l2.position = Vector2(8, 8)
	ss.add_child(l2)
	_saver = OptionButton.new()
	_saver.position = Vector2(8, 26)
	_saver.size = Vector2(160, 22)
	for s in _shell.extras().SAVERS:
		_saver.add_item(s)
	_saver.select(_saver_i)
	_saver.item_selected.connect(func(i): _saver_i = i)
	ss.add_child(_saver)
	var l3 := Label.new()
	l3.text = "Wait:            minutes"
	l3.position = Vector2(190, 30)
	ss.add_child(l3)
	_wait = OptionButton.new()
	_wait.position = Vector2(222, 26)
	_wait.size = Vector2(44, 22)
	for w in WAITS:
		_wait.add_item(str(w))
	var cur := int(round(_shell.extras().saver_wait / 60.0))
	_wait.select(maxi(0, WAITS.find(cur)))
	ss.add_child(_wait)
	var ap := Control.new()
	ap.name = "Appearance"
	_tabs.add_child(ap)
	var l4 := Label.new()
	l4.text = "Scheme:  Okna Standard\n\n(Other schemes are on the installation CD.)"
	l4.position = Vector2(8, 8)
	ap.add_child(l4)
	var row := HBoxContainer.new()
	row.position = Vector2(size.x - 8 - 3 * 76, size.y - 30)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for n in ["OK", "Cancel", "Apply"]:
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(72, 23)
		var nm: String = n
		b.pressed.connect(func(): _press(nm))
		row.add_child(b)


func _press(which: String) -> void:
	if which != "Cancel":
		_shell.set_wallpaper(str(WALLPAPERS[_wall_i][1]))
		_shell.extras().saver = str(_shell.extras().SAVERS[_saver_i])
		_shell.extras().saver_wait = float(WAITS[maxi(0, _wait.selected)]) * 60.0
	if which != "Apply":
		_shell.close_app_window(_win)


func _process(delta: float) -> void:
	_t += delta
	_preview.queue_redraw()


## The little beige monitor with the chosen wallpaper on it.
func _draw_preview() -> void:
	var c := _preview
	c.draw_rect(Rect2(10, 4, 130, 96), Color8(200, 192, 170))
	c.draw_rect(Rect2(10, 4, 130, 96), T.DARK, false, 1.0)
	var scr := Rect2(20, 12, 110, 80)
	c.draw_rect(scr, T.DESKTOP)
	var path := str(WALLPAPERS[_wall_i][1])
	if _wall_tex.has(path):
		c.draw_texture_rect(_wall_tex[path], scr, path.ends_with("knotty_pine.png"))
	c.draw_rect(Rect2(60, 100, 30, 8), Color8(180, 172, 150))
	c.draw_rect(Rect2(45, 108, 60, 6), Color8(180, 172, 150))
	c.draw_rect(Rect2(118, 94, 4, 3), Color8(60, 220, 80) if fmod(_t, 1.0) < 0.8 else Color8(40, 90, 40))
