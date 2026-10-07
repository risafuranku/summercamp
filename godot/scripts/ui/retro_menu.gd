extends RefCounted

## Menu building blocks shared by the main menu, the pause menu and the game-over
## screen. Everything follows retro_ui.gd: virtual pixels times an integer scale, the
## baked pixel fonts, hard edges, no easing flourishes beyond whole-pixel slides.
##
## Pages are passive: the owning screen forwards input with `handle_input(event)` to
## whichever page is active, so two pages never fight over the same key.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const SETTINGS_PANEL = preload("res://scripts/settings_panel.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")

const SFX_MOVE_PATH := "res://assets/sfx/rednecksfx/rrtick.wav"


## Darkens the 3D view the way the Build engine did: a flat shade (it dimmed through the
## palette's shade tables, not with gradients). Where a shaded area meets the clear view
## the edge is an ordered (Bayer 4x4) dither band in whole virtual pixels. `mode`:
##   "full"  uniform shade (pause, loading, game over)
##   "left"  shade the left `reach` of the screen, dithered edge of `band` (menu column)
##   "frame" clear centre, a dithered band toward the edges (vignette)
class DitherShade:
	extends Control

	const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

	var ui_scale: int = 3
	var mode: String = "full"
	var color: Color = Color(0.0, 0.0, 0.0, 0.7)
	var reach: float = 0.55
	var band: float = 0.12
	var _tex: Texture2D
	var _built_for: Vector2i = Vector2i.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func rebuild() -> void:
		_built_for = Vector2i.ZERO
		queue_redraw()

	## 1 = shaded, 0 = clear, in between = dithered.
	func _coverage(u: float, v: float) -> float:
		match mode:
			"left":
				return clampf((reach - u) / maxf(0.001, band), 0.0, 1.0)
			"frame":
				var dx := absf(u - 0.5) * 2.0
				var dy := absf(v - 0.5) * 2.0
				return clampf((maxf(dx, dy) - (1.0 - band * 2.0)) / (band * 2.0), 0.0, 1.0)
			_:
				return 1.0

	func _draw() -> void:
		if mode == "full":
			draw_rect(Rect2(Vector2.ZERO, size), color)
			return
		var s := maxi(1, ui_scale)
		var w := maxi(1, int(ceil(size.x / float(s))))
		var h := maxi(1, int(ceil(size.y / float(s))))
		if _tex == null or _built_for != Vector2i(w, h):
			var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			var clear := Color(color.r, color.g, color.b, 0.0)
			for y in h:
				for x in w:
					var threshold := (float(BAYER[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0
					var c := _coverage(float(x) / float(w), float(y) / float(h))
					img.set_pixel(x, y, color if c > threshold else clear)
			_tex = ImageTexture.create_from_image(img)
			_built_for = Vector2i(w, h)
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(w, h) * float(s)), false)


## Vertical list of big outlined entries with a sliding chevron cursor (Duke3D-style).
## Items: {id, text, sub, enabled}. `sub` is a small dim note printed after the entry.
class MenuList:
	extends Control

	signal activated(id: String)
	signal moved(id: String)

	var ui_scale: int = 3
	var row_height_vp: int = 24
	var size_vp: int = 20
	var indent_vp: int = 14
	var color_normal_top: Color = Color(0.93, 0.89, 0.78, 1.0)
	var color_normal_bottom: Color = Color(0.70, 0.64, 0.54, 1.0)
	var color_selected_top: Color = Color(1.0, 0.88, 0.52, 1.0)
	var color_selected_bottom: Color = Color(1.0, 0.56, 0.12, 1.0)
	var color_disabled: Color = Color(0.36, 0.33, 0.29, 1.0)
	var items: Array[Dictionary] = []
	var selected: int = -1
	var _rows: Array[Control] = []
	var _titles: Array = []
	var _cursor: Control
	var _cursor_y: float = 0.0
	var _cursor_t: float = 0.0
	var _sfx: AudioStreamPlayer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_sfx = AudioStreamPlayer.new()
		_sfx.bus = "Master"
		_sfx.volume_db = -10.0
		if ResourceLoader.exists(SFX_MOVE_PATH):
			_sfx.stream = load(SFX_MOVE_PATH)
		add_child(_sfx)

	func set_items(new_items: Array[Dictionary]) -> void:
		var keep_id := current_id()
		items = new_items
		_rebuild()
		var idx := _index_of(keep_id)
		select(idx if idx >= 0 and _enabled(idx) else _first_enabled(), false)

	func set_item_enabled(id: String, enabled: bool) -> void:
		var i := _index_of(id)
		if i < 0:
			return
		items[i]["enabled"] = enabled
		_paint()

	func set_item_sub(id: String, sub: String) -> void:
		var i := _index_of(id)
		if i < 0 or i >= _rows.size():
			return
		items[i]["sub"] = sub
		var sub_label := _rows[i].get_node_or_null("Sub") as Label
		if sub_label != null:
			sub_label.text = sub.to_upper()

	## Width the entries need (cursor indent + widest entry, without sub notes).
	func content_width() -> float:
		var w := 0.0
		for t in _titles:
			w = maxf(w, t.custom_minimum_size.x)
		return float(indent_vp * ui_scale) + w

	func current_id() -> String:
		if selected < 0 or selected >= items.size():
			return ""
		return str(items[selected].get("id", ""))

	func select(index: int, play_sound: bool = true) -> void:
		if index < 0 or index >= items.size() or not _enabled(index):
			return
		var changed := index != selected
		selected = index
		_paint()
		if changed and play_sound:
			_play(1.0)
			moved.emit(current_id())

	func select_id(id: String) -> void:
		select(_index_of(id), false)

	## Up/down/accept. Returns true when the event was used.
	func handle_input(event: InputEvent) -> bool:
		if event.is_action_pressed("ui_down", true):
			_step(1)
			return true
		if event.is_action_pressed("ui_up", true):
			_step(-1)
			return true
		if event.is_action_pressed("ui_accept"):
			_activate(selected)
			return true
		return false

	func _step(dir: int) -> void:
		if items.is_empty():
			return
		var i := selected
		for _n in items.size():
			i = posmod(i + dir, items.size())
			if _enabled(i):
				select(i)
				return

	func _activate(index: int) -> void:
		if index < 0 or index >= items.size() or not _enabled(index):
			return
		_play(0.7)
		activated.emit(str(items[index].get("id", "")))

	func _play(pitch: float) -> void:
		if _sfx != null and _sfx.stream != null and _sfx.is_inside_tree():
			_sfx.pitch_scale = pitch
			_sfx.play()

	func _enabled(i: int) -> bool:
		return i >= 0 and i < items.size() and bool(items[i].get("enabled", true))

	func _first_enabled() -> int:
		for i in items.size():
			if _enabled(i):
				return i
		return -1

	func _index_of(id: String) -> int:
		for i in items.size():
			if str(items[i].get("id", "")) == id:
				return i
		return -1

	func _rebuild() -> void:
		for child in get_children():
			if child == _sfx:
				continue
			remove_child(child)
			child.queue_free()
		_rows.clear()
		_titles.clear()
		var s := float(ui_scale)
		var y := 0.0
		for i in items.size():
			var item: Dictionary = items[i]
			var row := Control.new()
			row.name = "Row_%s" % str(item.get("id", i))
			row.position = Vector2(0.0, y)
			row.size = Vector2(size.x, float(row_height_vp) * s)
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var index := i
			row.mouse_entered.connect(func() -> void: select(index))
			row.gui_input.connect(func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					select(index, false)
					_activate(index)
			)
			add_child(row)
			var title := RETRO_UI.PixelTitle.new()
			title.configure(RETRO_UI.FONT_BIG, size_vp, ui_scale)
			title.set_text(str(item.get("text", "")).to_upper())
			title.position = Vector2(float(indent_vp) * s, 0.0)
			title.size = title.custom_minimum_size
			row.add_child(title)
			_titles.append(title)
			var sub := RETRO_UI.label(str(item.get("sub", "")).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, ui_scale)
			sub.name = "Sub"
			sub.position = Vector2(title.position.x + title.custom_minimum_size.x + 4.0 * s, 0.0)
			# Baseline of the small note on the big entry's baseline.
			var big_px := float(RETRO_UI.font_pixel(RETRO_UI.FONT_BIG, size_vp)) * s
			var baseline := big_px + 10.0 * big_px
			sub.position.y = baseline - RETRO_UI.FONT_LABEL.get_ascent(RETRO_UI.SIZE_LABEL * ui_scale)
			row.add_child(sub)
			_rows.append(row)
			y += float(row_height_vp) * s
		custom_minimum_size = Vector2(0.0, y)
		_cursor = Control.new()
		_cursor.name = "Cursor"
		_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cursor.draw.connect(_draw_cursor)
		add_child(_cursor)
		_cursor_y = -1.0
		_paint()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			for row in _rows:
				row.size.x = size.x

	func _paint() -> void:
		for i in _titles.size():
			var t = _titles[i]
			if not _enabled(i):
				t.set_colors(color_disabled, color_disabled.darkened(0.2))
			elif i == selected:
				t.set_colors(color_selected_top, color_selected_bottom)
			else:
				t.set_colors(color_normal_top, color_normal_bottom)
			var sub := _rows[i].get_node_or_null("Sub") as Label
			if sub != null:
				sub.add_theme_color_override("font_color", RETRO_UI.C_AMBER_DIM if i == selected else RETRO_UI.C_BONE_DIM.darkened(0.15))

	func _process(delta: float) -> void:
		if _cursor == null or selected < 0 or selected >= _rows.size():
			return
		_cursor_t += delta
		var target := _rows[selected].position.y
		if _cursor_y < 0.0:
			_cursor_y = target
		# Whole-pixel slide: covers the gap in ~0.08s, never lands between pixels.
		var s := float(ui_scale)
		var step := maxf(s, absf(target - _cursor_y) * minf(1.0, delta * 22.0))
		_cursor_y = move_toward(_cursor_y, target, step)
		_cursor.position = Vector2(0.0, floorf(_cursor_y / s) * s)
		_cursor.queue_redraw()

	func _draw_cursor() -> void:
		var s := float(ui_scale)
		var big_px := float(RETRO_UI.font_pixel(RETRO_UI.FONT_BIG, size_vp)) * s
		var mid := big_px + 5.0 * big_px
		var nudge := s if fmod(_cursor_t, 0.8) < 0.4 else 0.0
		var tip := Vector2(float(indent_vp - 4) * s + nudge, floorf(mid / s) * s)
		# Right-pointing solid triangle, 7 px tall, outlined; upper half lit.
		var cells: Array[Vector2] = []
		for col in 4:
			for k in range(-(3 - col), 3 - col + 1):
				cells.append(Vector2(float(col), float(k)))
		var origin := tip - Vector2(3.0 * s, 0.0)
		for c in cells:
			_cursor.draw_rect(Rect2(origin + c * s - Vector2(s, s), Vector2(3.0 * s, 3.0 * s)), RETRO_UI.C_OUTLINE)
		for c in cells:
			var col := RETRO_UI.C_AMBER_LIGHT if c.y < 0.0 else RETRO_UI.C_AMBER
			_cursor.draw_rect(Rect2(origin + c * s, Vector2(s, s)), col)


## CONFIGURATION page: Duke-style option rows, LEFT/RIGHT (or click / right-click)
## change the value, values apply immediately through GameSettings.
class OptionsPage:
	extends Control

	signal back_requested
	signal controls_requested

	const MODE_IDS := ["windowed", "fullscreen", "borderless"]
	const MODE_LABELS := ["WINDOWED", "FULLSCREEN", "BORDERLESS"]
	const VOLUME_STEPS := [-40.0, -30.0, -24.0, -20.0, -16.0, -12.0, -9.0, -6.0, -4.0, -2.0, 0.0, 3.0, 6.0]
	const MOUSE_STEPS := [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

	var ui_scale: int = 3
	var selected: int = 0
	var _rows: Array[Dictionary] = []
	var _row_nodes: Array[Control] = []
	var _value_labels: Array[Label] = []
	var _bars: Array = []
	var _name_labels: Array[Label] = []
	var _highlight: Control
	var _sfx: AudioStreamPlayer
	var _bound: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_sfx = AudioStreamPlayer.new()
		_sfx.volume_db = -10.0
		if ResourceLoader.exists(SFX_MOVE_PATH):
			_sfx.stream = load(SFX_MOVE_PATH)
		add_child(_sfx)
		if GameSettings != null and not _bound:
			GameSettings.settings_changed.connect(func(_snap: Dictionary) -> void: refresh())
			_bound = true

	func build() -> void:
		for child in get_children():
			if child == _sfx:
				continue
			remove_child(child)
			child.queue_free()
		_rows = [
			{"id": "mode", "name": "Window mode"},
			{"id": "resolution", "name": "Resolution"},
			{"id": "render", "name": "Render style"},
			{"id": "palette", "name": "256-colour palette"},
			{"id": "volume", "name": "Master volume", "bar": VOLUME_STEPS.size() - 1},
			{"id": "mouse", "name": "Mouse speed", "bar": MOUSE_STEPS.size() - 1},
			{"id": "invert", "name": "Invert mouse Y"},
			{"id": "controls", "name": "Controls", "action": true},
			{"id": "reset", "name": "Reset defaults", "action": true},
			{"id": "back", "name": "Back", "action": true},
		]
		_row_nodes.clear()
		_value_labels.clear()
		_name_labels.clear()
		_bars.clear()
		var s := float(ui_scale)
		var row_h := 15.0 * s
		_highlight = RETRO_UI.BevelPanel.new()
		_highlight.ui_scale = ui_scale
		_highlight.fill = Color(0.22, 0.14, 0.07, 0.9)
		_highlight.light = RETRO_UI.C_AMBER_DIM
		_highlight.dark = Color(0.05, 0.03, 0.02, 1.0)
		add_child(_highlight)
		for i in _rows.size():
			var row_def: Dictionary = _rows[i]
			var row := Control.new()
			row.position = Vector2(0.0, float(i) * row_h)
			row.size = Vector2(size.x, row_h)
			row.mouse_filter = Control.MOUSE_FILTER_STOP
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var index := i
			row.mouse_entered.connect(func() -> void: _select(index))
			row.gui_input.connect(func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb == null or not mb.pressed:
					return
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_select(index, false)
					_change(1, true)
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					_select(index, false)
					_change(-1, true)
			)
			add_child(row)
			var name_label := RETRO_UI.label(str(row_def["name"]).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE, ui_scale)
			name_label.position = Vector2(6.0 * s, 0.0)
			name_label.size = Vector2(size.x * 0.5, row_h)
			RETRO_UI.place_on_baseline(name_label, 10.0, ui_scale)
			name_label.offset_left = 6.0 * s
			name_label.offset_right = size.x * 0.5
			row.add_child(name_label)
			_name_labels.append(name_label)
			var value := RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, ui_scale)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.anchor_left = 0.0
			value.anchor_right = 1.0
			value.offset_left = size.x * 0.45
			value.offset_right = -6.0 * s
			RETRO_UI.place_on_baseline(value, 10.0, ui_scale)
			row.add_child(value)
			_value_labels.append(value)
			if row_def.has("bar"):
				var bar := RETRO_UI.SegmentBar.new()
				bar.ui_scale = ui_scale
				bar.segments = int(row_def["bar"])
				bar.color_full = RETRO_UI.C_AMBER
				bar.color_low = RETRO_UI.C_AMBER_DIM
				bar.anchor_left = 0.0
				bar.anchor_right = 0.0
				bar.position = Vector2(size.x * 0.42, 6.0 * s)
				bar.size = Vector2(size.x * 0.28, 4.0 * s)
				row.add_child(bar)
				_bars.append(bar)
			else:
				_bars.append(null)
			_row_nodes.append(row)
		custom_minimum_size = Vector2(0.0, row_h * float(_rows.size()))
		refresh()
		_select(clampi(selected, 0, _rows.size() - 1), false)

	func refresh() -> void:
		if GameSettings == null:
			return
		for i in _rows.size():
			if i >= _value_labels.size():
				return
			var id := str(_rows[i]["id"])
			var text := ""
			var bar_value := -1.0
			match id:
				"mode":
					text = MODE_LABELS[maxi(0, MODE_IDS.find(GameSettings.get_window_mode()))]
				"resolution":
					var r: Vector2i = GameSettings.get_resolution()
					text = "%d X %d" % [r.x, r.y]
					if GameSettings.get_window_mode() != "windowed":
						text = "DESKTOP"
				"render":
					text = str(RETRO_RENDER.PRESET_LABELS.get(GameSettings.get_retro_preset(), "")).to_upper()
				"palette":
					text = "ON" if GameSettings.get_retro_palette_enabled() else "OFF"
				"volume":
					var db: float = GameSettings.get_master_volume_db()
					var vi := _nearest(VOLUME_STEPS, db)
					text = "OFF" if vi == 0 else "%+d DB" % int(round(db))
					bar_value = float(vi) / float(VOLUME_STEPS.size() - 1)
				"mouse":
					var m: float = GameSettings.get_mouse_sensitivity()
					var mi := _nearest(MOUSE_STEPS, m)
					text = "%d%%" % int(round(m * 100.0))
					bar_value = float(mi + 1) / float(MOUSE_STEPS.size())
				"invert":
					text = "ON" if GameSettings.get_invert_mouse_y() else "OFF"
				"controls", "reset", "back":
					text = ""
			if str(text) != "" and not _rows[i].has("bar") and not _rows[i].has("action"):
				text = "< %s >" % text
			_value_labels[i].text = text
			if _bars[i] != null and bar_value >= 0.0:
				_bars[i].set_value(bar_value)

	func handle_input(event: InputEvent) -> bool:
		if event.is_action_pressed("ui_down", true):
			_select(posmod(selected + 1, _rows.size()))
			return true
		if event.is_action_pressed("ui_up", true):
			_select(posmod(selected - 1, _rows.size()))
			return true
		if event.is_action_pressed("ui_right", true):
			_change(1, false)
			return true
		if event.is_action_pressed("ui_left", true):
			_change(-1, false)
			return true
		if event.is_action_pressed("ui_accept"):
			_change(1, true)
			return true
		if event.is_action_pressed("ui_cancel"):
			back_requested.emit()
			return true
		return false

	func _select(i: int, play_sound: bool = true) -> void:
		if i < 0 or i >= _row_nodes.size():
			return
		if i != selected and play_sound:
			_play(1.0)
		selected = i
		var row := _row_nodes[i]
		_highlight.position = row.position
		_highlight.size = row.size
		for k in _name_labels.size():
			_name_labels[k].add_theme_color_override("font_color", RETRO_UI.C_AMBER_LIGHT if k == i else RETRO_UI.C_BONE)

	## `dir` +1/-1. `activate` is Enter or a click: also runs action rows.
	func _change(dir: int, activate: bool) -> void:
		if GameSettings == null or selected < 0 or selected >= _rows.size():
			return
		var id := str(_rows[selected]["id"])
		match id:
			"mode":
				var mi := posmod(MODE_IDS.find(GameSettings.get_window_mode()) + dir, MODE_IDS.size())
				GameSettings.set_window_mode(MODE_IDS[mi], true, true)
			"resolution":
				var list: Array[Vector2i] = GameSettings.get_supported_resolutions()
				var ri := posmod(list.find(GameSettings.get_resolution()) + dir, list.size())
				GameSettings.set_resolution(list[ri], true, true)
			"render":
				var order: Array[String] = RETRO_RENDER.PRESET_ORDER
				var pi := posmod(order.find(GameSettings.get_retro_preset()) + dir, order.size())
				GameSettings.set_retro_preset(order[pi], true)
			"palette":
				GameSettings.set_retro_palette_enabled(not GameSettings.get_retro_palette_enabled(), true)
			"volume":
				var vi := clampi(_nearest(VOLUME_STEPS, GameSettings.get_master_volume_db()) + dir, 0, VOLUME_STEPS.size() - 1)
				GameSettings.set_master_volume_db(VOLUME_STEPS[vi], true, true)
			"mouse":
				var mi2 := clampi(_nearest(MOUSE_STEPS, GameSettings.get_mouse_sensitivity()) + dir, 0, MOUSE_STEPS.size() - 1)
				GameSettings.set_mouse_sensitivity(MOUSE_STEPS[mi2], true)
			"invert":
				GameSettings.set_invert_mouse_y(not GameSettings.get_invert_mouse_y(), true)
			"controls":
				if activate:
					controls_requested.emit()
				return
			"reset":
				if activate:
					GameSettings.reset_defaults()
				else:
					return
			"back":
				if activate:
					back_requested.emit()
				return
		_play(0.85)
		refresh()

	func _nearest(steps: Array, value: float) -> int:
		var best := 0
		for i in steps.size():
			if absf(float(steps[i]) - value) < absf(float(steps[best]) - value):
				best = i
		return best

	func _play(pitch: float) -> void:
		if _sfx != null and _sfx.stream != null and _sfx.is_inside_tree():
			_sfx.pitch_scale = pitch
			_sfx.play()


## Read-only controls reference (bindings are registered at runtime, so this is the
## only place a player can find them).
class ControlsPage:
	extends Control

	signal back_requested

	var ui_scale: int = 3

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func build() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		var s := float(ui_scale)
		var y := 0.0
		var entries: Array = SETTINGS_PANEL.CONTROL_REFERENCE.duplicate()
		if OS.is_debug_build():
			entries.append(["", ""])
			for e in SETTINGS_PANEL.DEBUG_CONTROL_REFERENCE:
				entries.append(["(debug) " + str(e[0]), e[1]])
		for entry in entries:
			var action := RETRO_UI.label(str(entry[0]), RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE, ui_scale)
			action.position = Vector2(6.0 * s, y)
			add_child(action)
			var keys := RETRO_UI.label(str(entry[1]).to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, ui_scale)
			keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			keys.anchor_right = 1.0
			keys.offset_left = size.x * 0.4
			keys.offset_right = -6.0 * s
			keys.offset_top = y + s
			keys.offset_bottom = y + 11.0 * s
			add_child(keys)
			y += 11.0 * s
		var hint := RETRO_UI.label("ESC / CLICK TO GO BACK", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE_DIM, ui_scale)
		hint.position = Vector2(6.0 * s, y + 6.0 * s)
		add_child(hint)
		custom_minimum_size = Vector2(0.0, y + 18.0 * s)

	func handle_input(event: InputEvent) -> bool:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			back_requested.emit()
			return true
		return false

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed:
			back_requested.emit()
