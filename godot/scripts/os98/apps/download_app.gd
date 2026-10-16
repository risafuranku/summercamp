extends Control

## The "File Download" box: a file comes down the phone line at modem speed into
## C:\DOWNLOAD, with the paper flying from the globe to the folder. When it is done:
## Open, Open Folder, Close.

const T = preload("res://scripts/os98/os_theme.gd")
const RATE_KB := [3.1, 4.1]   # 33.6k on a forest line

var _shell
var _win
var _file := ""
var _url := ""
var _kb := 40.0
var _got := 0.0
var _rate := 3.6
var _done := false
var _anim: Control
var _what: Label
var _bar: ProgressBar
var _left: Label
var _btns: HBoxContainer
var _t := 0.0
var _hdd := 0.0


func setup(shell, win, args: Dictionary) -> void:
	_shell = shell
	_win = win
	_file = str(args.get("file", "FILE.EXE"))
	_url = str(args.get("url", ""))
	_kb = float(args.get("kb", 40))
	win.can_maximize = false
	win.title = "0%% of %s Completed" % _file
	_anim = Control.new()
	_anim.position = Vector2(10, 6)
	_anim.size = Vector2(size.x - 20, 34)
	_anim.draw.connect(_draw_anim)
	add_child(_anim)
	_what = Label.new()
	_what.position = Vector2(10, 42)
	_what.size = Vector2(size.x - 20, 30)
	_what.clip_text = true
	_what.text = "Saving:\n%s from %s" % [_file, _host(_url)]
	add_child(_what)
	_bar = ProgressBar.new()
	_bar.position = Vector2(10, 76)
	_bar.size = Vector2(size.x - 20, 16)
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	add_child(_bar)
	_left = Label.new()
	_left.position = Vector2(10, 100)
	_left.size = Vector2(size.x - 20, 14)
	add_child(_left)
	_btns = HBoxContainer.new()
	_btns.alignment = BoxContainer.ALIGNMENT_END
	_btns.add_theme_constant_override("separation", 6)
	_btns.position = Vector2(10, size.y - 28)
	_btns.size = Vector2(size.x - 20, 23)
	add_child(_btns)
	_set_buttons(["Cancel"])
	_shell.set_busy(true)


func _set_buttons(names: Array) -> void:
	for c in _btns.get_children():
		c.queue_free()
	for n in names:
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(80, 23)
		var label: String = n
		b.pressed.connect(func(): _press(label))
		_btns.add_child(b)


func _press(which: String) -> void:
	match which:
		"Cancel", "Close":
			_shell.close_app_window(_win)
		"Open":
			_shell.close_app_window(_win)
			_shell.open_file("C:\\DOWNLOAD", _file)
		"Open Folder":
			_shell.close_app_window(_win)
			_shell.open_app("folder", {"path": "C:\\DOWNLOAD"})


func closing() -> void:
	if not _done:
		_shell.set_busy(false)


func _process(delta: float) -> void:
	_t += delta
	_anim.queue_redraw()
	if _done:
		return
	# The line stalls now and then, like they did.
	if fmod(_t, 7.0) < 6.2:
		_rate = lerpf(_rate, randf_range(RATE_KB[0], RATE_KB[1]), delta)
		_got = minf(_kb, _got + _rate * delta)
	_hdd -= delta
	if _hdd <= 0.0:
		_hdd = randf_range(1.5, 4.0)
		_shell.play("hdd", -16.0)
	var p := _got / _kb
	_bar.value = p
	_win.title = "%d%% of %s Completed" % [int(p * 100.0), _file]
	var secs := int(ceil((_kb - _got) / maxf(0.5, _rate)))
	_left.text = "Estimated time left: %d sec (%d KB of %d KB copied)\nTransfer rate: %.1f KB/Sec" % [secs, int(_got), int(_kb), _rate]
	if _got >= _kb:
		_finish()


func _finish() -> void:
	_done = true
	_shell.set_busy(false)
	_shell.finish_download(_file)
	_shell.play("ding", -6.0)
	_win.title = "Download complete"
	_what.text = "Download Complete\nSaved: %s to C:\\DOWNLOAD" % _file
	_left.text = "Downloaded: %d KB in %d sec\nTransfer rate: %.1f KB/Sec" % [int(_kb), int(_t), _kb / maxf(1.0, _t)]
	_set_buttons(["Open", "Open Folder", "Close"])


## A sheet of paper flies from the globe to the folder while bytes come in: the globe
## turns, the page tumbles along its arc in steps (12 a second, like the real one), the
## folder's flap lifts as each page drops in. The line stalls: so does the paper.
func _draw_anim() -> void:
	var t := floorf(_t * 12.0) / 12.0
	var globe := Vector2(20, 16)
	var folder := Vector2(_anim.size.x - 24, 18)
	_anim.draw_circle(globe, 13, Color8(0, 80, 176))
	# Continents: two blobs sliding round as it turns.
	for k in 2:
		var x := fmod(t * 9.0 + k * 13.0, 26.0) - 13.0
		var hw := sqrt(maxf(0.0, 169.0 - x * x)) * 0.35
		_anim.draw_rect(Rect2(globe + Vector2(x - hw * 0.5, -5 + k * 6), Vector2(hw, 5)), Color8(0, 160, 64))
	for m in 3:
		var phase := fmod(t * 0.6 + m / 3.0, 1.0)
		var rx := absf(cos(phase * PI)) * 13.0
		_anim.draw_arc(globe, 13, 0, TAU, 20, T.DARK)
		_anim.draw_line(globe + Vector2(-rx, -11), globe + Vector2(-rx, 11), Color8(120, 170, 230, 120), 1.0)
	_anim.draw_line(globe - Vector2(13, 0), globe + Vector2(13, 0), Color8(120, 170, 230), 1.0)
	var stalled := fmod(_t, 7.0) >= 6.2
	var landing := 0.0
	if not _done and not stalled:
		for k in 2:
			var f := fmod(t * 0.85 + k * 0.5, 1.0)
			var p := globe.lerp(folder, f) + Vector2(0, -sin(f * PI) * 12.0)
			var tilt := floorf(f * 6.0) * 0.5
			_page(p, tilt)
			if f > 0.85:
				landing = maxf(landing, (f - 0.85) / 0.15)
	# The folder, its flap lifting as a page goes in.
	var c := Color8(255, 214, 80)
	_anim.draw_rect(Rect2(folder - Vector2(14, 6), Vector2(28, 18)), c)
	_anim.draw_rect(Rect2(folder - Vector2(14, 10), Vector2(11, 5)), c)
	_anim.draw_rect(Rect2(folder - Vector2(14, 6), Vector2(28, 18)), T.DARK, false, 1.0)
	var lift := floorf(landing * 3.0) * 2.0
	_anim.draw_colored_polygon(PackedVector2Array([folder + Vector2(-14, 0 - lift), folder + Vector2(14, 0 - lift * 0.5), folder + Vector2(14, 12), folder + Vector2(-14, 12)]), Color8(240, 190, 60))
	_anim.draw_polyline(PackedVector2Array([folder + Vector2(-14, 0 - lift), folder + Vector2(14, 0 - lift * 0.5), folder + Vector2(14, 12), folder + Vector2(-14, 12), folder + Vector2(-14, 0 - lift)]), T.DARK, 1.0)


func _page(p: Vector2, tilt: float) -> void:
	var w := 8.0
	var h := 10.0
	var xf := Transform2D(tilt * 0.3, p)
	var pts := PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5 - 3, -h * 0.5), Vector2(w * 0.5, -h * 0.5 + 3), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
	var out := PackedVector2Array()
	for q in pts:
		out.append(xf * q)
	_anim.draw_colored_polygon(out, T.WHITE)
	out.append(out[0])
	_anim.draw_polyline(out, T.DARK, 1.0)
	for li in 3:
		_anim.draw_line(xf * Vector2(-2.5, -2 + li * 2.5), xf * Vector2(2.5, -2 + li * 2.5), Color8(128, 128, 128), 1.0)


func _host(url: String) -> String:
	var s := url.trim_prefix("http://")
	var i := s.find("/")
	return s.substr(0, i) if i > 0 else s
