extends Node
## Build-engine style HUD.
##
##   ┌ message feed (Duke3D quotes)                      objective tracker ┐
##   │                              +                                        │
##   │                       [E] ENTER RECEPTION                 guest card  │
##   │                     ── centre banner (NIGHT 1) ──                    │
##   └[HEALTH][STAM/LIGHT][CASH][DAY·CLOCK][GUESTS ☺][MAIL][NIGHT RISK]──────┘
##
## Everything is laid out in virtual pixels (vp) times an integer UI scale so the pixel
## fonts stay crisp (retro_ui.gd). The layout is rebuilt when the window size changes;
## all displayed values are cached so a rebuild restores them.
##
## Every meter carries a caption. The NIGHT RISK cell encodes the game's central
## risk/reward trade (see DESIGN.md) and must stay legible.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")

const HUD_LAYER_INDEX := 65
const HINT_LAYER_INDEX := 70

# Message kinds (push_status). Kept for callers of the previous HUD.
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_WARN := 2
const STATUS_DENY := 3
const STATUS_QUOTE := 4

const BAR_HEIGHT_VP := 40
const CELL_HEIGHT_VP := 34
const FEED_MAX_LINES := 4
const FEED_HOLD_SEC := 6.0
const FEED_FADE_SEC := 0.8
const CARD_HOLD_SEC := 7.0

# Time phases, mirroring main.gd / TimeSystem.
const PHASE_DAY := 0
const PHASE_EVENING := 1
const PHASE_NIGHT := 2
const PHASE_LABELS := ["DAY", "EVENING", "NIGHT"]

const WEATHER_LABELS := ["CLEAR", "WINDY", "FOG", "DRIZZLE", "RAIN", "STORM", "ANOMALY"]

## NIGHT RISK legend. Index matches the HUD level derived from expected spawns
## (`GuestManager.LIMINAL_HUD_EXPECTED_THRESHOLDS`).
const RISK_LEVEL_LABELS := ["CLEAR", "LOW", "RAISED", "HIGH", "CRITICAL"]
const RISK_TIER_LABELS := {"none": "clear", "tiny": "tiny", "small": "small", "medium": "medium", "large": "large"}

const NEED_ROWS := [
	["energy", "NRG"], ["hunger", "FOOD"], ["bladder", "WC"],
	["hygiene", "WASH"], ["fun", "FUN"], ["safety", "SAFE"],
]

## vp widths of the status bar cells (also asserted by tools/hud_layout_check.tscn).
const CELL_WIDTHS := {
	"health": 46, "stamina": 44, "cash": 68, "clock": 76, "guests": 64, "mail": 30, "risk": 62,
}
const HUD_MOOD_WORDS := {
	"Delighted": "GREAT", "Happy": "HAPPY", "Okay": "OKAY", "Grumpy": "GRUMPY",
	"Unhappy": "UPSET", "Furious": "FURIOUS", "Empty": "EMPTY",
}

var _scale: int = 3
var _layer: CanvasLayer
var _hint_layer: CanvasLayer
var _root: Control
var _hint_root: Control
var _world_visible: bool = true
var _built_for_size: Vector2 = Vector2.ZERO

# Widgets
var _bar: Control
var _cells: Dictionary = {}
var _health_value: Label
var _health_bar: Control
var _stamina_bar: Control
var _light_bar: Control
var _cash_value: Label
var _cash_delta: Label
var _clock_caption: Label
var _clock_value: Label
var _clock_phase: Label
var _weather_label: Label
var _guest_face: Control
var _guest_value: Label
var _guest_mood: Label
var _mail_value: Label
var _mail_cell: Control
var _risk_pips: Array[ColorRect] = []
var _risk_level: Label
var _risk_detail: Label
var _feed_box: VBoxContainer
var _objective_panel: Control
var _objective_title: Label
var _objective_text: Label
var _objective_progress: Label
var _hint_label: Label
var _crosshair: Control
var _card_panel: Control
var _card_name: Label
var _card_sub: Label
var _card_face: Control
var _card_quote: Label
var _card_bars: Dictionary = {}
var _banner_title: Label
var _banner_sub: Label
var _banner_box: Control

# Cached state
var _money: int = 0
var _money_known: bool = false
var _money_flash: float = 0.0
var _day: int = 1
var _time_str: String = "09:00"
var _phase: int = PHASE_DAY
var _weather: int = 0
var _health: float = 1.0
var _stamina: float = 1.0
var _light: float = 1.0
var _beds: Vector2i = Vector2i.ZERO
var _mood: Dictionary = {}
var _risk_level_index: int = 0
var _risk_payload: Dictionary = {}
var _unread: int = 0
var _objective: Dictionary = {}
var _hint_text: String = ""
var _feed: Array[Dictionary] = []
var _card_info: Dictionary = {}
var _card_timer: float = 0.0
var _banner_timer: float = 0.0
var _banner_total: float = 0.0
var _fear: float = 0.0
var _mail_bound: bool = false
var _poll_money: float = 0.0
var _poll_guests: float = 0.0
var _blink_t: float = 0.0
var _last_phase_announce: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP API (called from main.gd)
# ═══════════════════════════════════════════════════════════════════════════════

func setup_interaction_hint() -> void:
	_ensure_world_hud()


func setup_money_hud() -> void:
	_ensure_world_hud()


func setup_weather_hud() -> void:
	_ensure_world_hud()


func setup_time_hud() -> void:
	_ensure_world_hud()


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE API
# ═══════════════════════════════════════════════════════════════════════════════

func update_weather(state: int) -> void:
	_weather = clampi(state, 0, WEATHER_LABELS.size() - 1)
	_refresh_clock()


func update_time(time_str: String, day: int) -> void:
	_time_str = time_str
	_day = maxi(1, day)
	var minute := _parse_time_to_minutes(time_str)
	var phase := _phase_for_minute(minute)
	if phase != _phase and _last_phase_announce >= 0:
		_announce_phase(phase)
	_phase = phase
	_last_phase_announce = phase
	_refresh_clock()


func on_money_changed(new_amount: int) -> void:
	_apply_money(new_amount)


func set_world_hud_visible(visible: bool) -> void:
	_world_visible = visible
	if _layer != null:
		_layer.visible = visible
	if _hint_layer != null:
		_hint_layer.visible = visible


func set_hint_text(text: String) -> void:
	_hint_text = text
	if _hint_label != null:
		_hint_label.text = text.to_upper()
		_hint_label.visible = not text.is_empty()


func set_health_ratio(value: float) -> void:
	_health = clampf(value, 0.0, 1.0)
	_refresh_health()


func set_stamina_ratio(value: float) -> void:
	_stamina = clampf(value, 0.0, 1.0)
	if _stamina_bar != null:
		_stamina_bar.set_value(_stamina)


func set_light_ratio(value: float) -> void:
	_light = clampf(value, 0.0, 1.0)
	if _light_bar != null:
		_light_bar.set_value(_light)


## 0-1 fear from the night: tightens the face's eyes and tints the vignette.
func set_fear(value: float) -> void:
	_fear = clampf(value, 0.0, 1.0)
	_refresh_guests()


## Legacy entry point: level only. Prefer `set_liminal_forecast()`.
func set_liminal_forecast_count(value: int) -> void:
	_risk_level_index = clampi(value, 0, 4)
	_refresh_risk()


## Full forecast payload from `GuestManager.get_liminal_forecast_data()`.
func set_liminal_forecast(payload: Dictionary) -> void:
	_risk_payload = payload.duplicate(true)
	_risk_level_index = clampi(int(payload.get("hud_level", 0)), 0, 4)
	_refresh_risk()


## Message feed line (top-left). `kind` is one of the STATUS_* constants.
func push_status(text: String, kind: int = STATUS_INFO) -> void:
	if text.strip_edges().is_empty():
		return
	_ensure_world_hud()
	var color := RETRO_UI.C_BONE
	match kind:
		STATUS_GOOD:
			color = RETRO_UI.C_GREEN
		STATUS_WARN:
			color = RETRO_UI.C_AMBER
		STATUS_DENY:
			color = Color(1.0, 0.42, 0.34)
		STATUS_QUOTE:
			color = Color(0.98, 0.88, 0.62)
	_feed.append({"text": text, "color": color, "t": FEED_HOLD_SEC + FEED_FADE_SEC})
	while _feed.size() > FEED_MAX_LINES:
		_feed.remove_at(0)
	_rebuild_feed()


## A guest line in the Duke3D quote feed.
func show_quote(guest_name: String, text: String, mood: float) -> void:
	var prefix := ">:( " if mood < 35.0 else ""
	push_status("%s%s: \"%s\"" % [prefix, guest_name, text], STATUS_QUOTE)


## Talk interaction: a card with the guest's mood, needs and what they just said.
func show_guest_card(info: Dictionary) -> void:
	_ensure_world_hud()
	_card_info = info.duplicate(true)
	_card_timer = CARD_HOLD_SEC
	_refresh_card()


## Objective tracker (QuestManager). Keys: title, text, progress ("2/3"), reward, done.
func set_objective(data: Dictionary) -> void:
	_objective = data.duplicate(true)
	_refresh_objective()


func clear_objective() -> void:
	_objective.clear()
	_refresh_objective()


## Big centred title that fades out ("NIGHT 1", "OBJECTIVE COMPLETE").
func show_banner(title: String, subtitle: String = "", color: Color = Color(1.0, 0.72, 0.22), seconds: float = 3.6) -> void:
	_ensure_world_hud()
	if _banner_title == null:
		return
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = subtitle
	_banner_sub.visible = not subtitle.is_empty()
	_banner_total = maxf(0.8, seconds)
	_banner_timer = _banner_total
	_banner_box.visible = true
	_banner_box.modulate.a = 0.0


func set_bed_metrics(occupied: int, capacity: int) -> void:
	_beds = Vector2i(maxi(0, occupied), maxi(0, capacity))
	_refresh_guests()


func cycle_item_slot(_step: int) -> void:
	pass


func set_selected_slot(_index: int) -> void:
	pass


## Virtual-pixel width the status bar cells need (cells + gaps + margins).
static func bar_width_vp() -> float:
	var total := 0.0
	for key in CELL_WIDTHS.keys():
		total += float(CELL_WIDTHS[key])
	return total + 3.0 * float(CELL_WIDTHS.size() - 1) + 10.0


## Status bar height in real pixels (for code that must not draw under it).
func get_bar_height_px() -> float:
	return float(BAR_HEIGHT_VP * _scale)


# ═══════════════════════════════════════════════════════════════════════════════
# FRAME
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _root == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size != _built_for_size:
		_rebuild_layout()
	_blink_t += delta
	_poll_money -= delta
	if _poll_money <= 0.0:
		_poll_money = 0.5
		if CoreRoot != null and CoreRoot.has_method("get_money"):
			_apply_money(int(CoreRoot.get_money()))
	_poll_guests -= delta
	if _poll_guests <= 0.0:
		_poll_guests = 1.5
		_poll_guest_state()
	_update_feed(delta)
	_update_money_flash(delta)
	_update_card(delta)
	_update_banner(delta)
	if _mail_cell != null:
		_mail_value.modulate = Color(1, 1, 1, 1) if _unread == 0 or fmod(_blink_t, 1.0) < 0.6 else Color(1, 1, 1, 0.35)


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_world_hud() -> void:
	if _layer != null:
		_ensure_email_binding()
		return
	_layer = CanvasLayer.new()
	_layer.name = "RetroHudLayer"
	_layer.layer = HUD_LAYER_INDEX
	add_child(_layer)
	_root = Control.new()
	_root.name = "RetroHudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_hint_layer = CanvasLayer.new()
	_hint_layer.name = "InteractionHintLayer"
	_hint_layer.layer = HINT_LAYER_INDEX
	add_child(_hint_layer)
	_hint_root = Control.new()
	_hint_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_layer.add_child(_hint_root)

	_rebuild_layout()
	_ensure_email_binding()
	_on_unread_count_changed(_get_unread_count())
	_poll_guest_state()
	set_process(true)
	set_world_hud_visible(_world_visible)


func _rebuild_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_built_for_size = vp_size
	_scale = RETRO_UI.ui_scale(vp_size.y, vp_size.x, bar_width_vp())
	for child in _root.get_children():
		child.queue_free()
	for child in _hint_root.get_children():
		child.queue_free()
	_cells.clear()
	_risk_pips.clear()
	_card_bars.clear()

	_build_status_bar()
	_build_feed()
	_build_objective()
	_build_crosshair_and_hint()
	_build_card()
	_build_banner()

	_refresh_all()


func _bevel(recessed: bool, textured: bool = false) -> Control:
	var p := RETRO_UI.BevelPanel.new()
	p.ui_scale = _scale
	p.recessed = recessed
	if recessed:
		p.fill = RETRO_UI.C_LCD
		p.light = Color(0.40, 0.36, 0.30)
		p.dark = Color(0.02, 0.02, 0.02)
	if textured:
		p.tile_texture = RETRO_UI.texture(RETRO_UI.PLATE_TEXTURE_PATH)
	return p


func _vp(v: float) -> float:
	return v * float(_scale)


func _build_status_bar() -> void:
	_bar = _bevel(false, true)
	_bar.name = "StatusBar"
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -_vp(BAR_HEIGHT_VP)
	_root.add_child(_bar)

	var row := HBoxContainer.new()
	row.name = "Cells"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(_vp(3)))
	row.offset_top = _vp(3)
	row.offset_bottom = -_vp(3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)

	# Rows inside a 34vp cell (baseline-exact, like a Build status bar):
	#   caption  y=1   Silkscreen 8
	#   value    y=8   Pixelify 16
	#   footer   y=23  Silkscreen 8   (or a bar at y=27)
	var health := _cell(row, "health", "HEALTH")
	_health_value = _put(health, RETRO_UI.label("100", RETRO_UI.FONT_TEXT, 16, RETRO_UI.C_BONE, _scale), 8)
	_health_bar = _put_bar(health, _segment_bar(10, Color(0.9, 0.2, 0.15), Color(0.5, 0.05, 0.03), 3), 28, 3)

	var stam := _cell(row, "stamina", "STAMINA")
	_stamina_bar = _put_bar(stam, _segment_bar(8, RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, 4), 11, 4)
	_put(stam, RETRO_UI.label("LIGHT", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false), 17)
	_light_bar = _put_bar(stam, _segment_bar(8, Color(1.0, 0.92, 0.55), RETRO_UI.C_RED, 4), 27, 4)

	var cash := _cell(row, "cash", "CASH")
	_cash_value = _put(cash, RETRO_UI.label("$0", RETRO_UI.FONT_TEXT, 16, RETRO_UI.C_AMBER, _scale), 8)
	_cash_delta = _put(cash, RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_GREEN, _scale, false), 23)

	var clock := _cell(row, "clock", "DAY 1")
	_clock_caption = clock.get_child(0) as Label
	_clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weather_label = _put(clock, RETRO_UI.label("CLEAR", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BLUE, _scale, false), 1)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_value = _put(clock, RETRO_UI.label("09:00", RETRO_UI.FONT_TEXT, 16, RETRO_UI.C_BONE, _scale), 8)
	_clock_phase = _put(clock, RETRO_UI.label("DAY", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false), 23)

	var guests := _cell(row, "guests", "GUESTS")
	_guest_face = RETRO_UI.PixelFace.new()
	_guest_face.ui_scale = _scale
	_guest_face.position = Vector2(0.0, _vp(12))
	_guest_face.size = Vector2(_vp(17), _vp(17))
	guests.add_child(_guest_face)
	_guest_value = _put(guests, RETRO_UI.label("0/0", RETRO_UI.FONT_TEXT, 8, RETRO_UI.C_BONE, _scale), 12, _vp(19))
	_guest_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_guest_mood = _put(guests, RETRO_UI.label("EMPTY", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false), 23, _vp(19))
	_guest_mood.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var mail := _cell(row, "mail", "MAIL")
	_mail_cell = mail
	_mail_value = _put(mail, RETRO_UI.label("0", RETRO_UI.FONT_TEXT, 16, RETRO_UI.C_BONE_DIM, _scale), 8)

	var risk := _cell(row, "risk", "NIGHT RISK")
	var pip_w := 10.0
	var inner_w := float(CELL_WIDTHS["risk"]) - 4.0
	var start_x := (inner_w - (pip_w * 4.0 + 2.0 * 3.0)) * 0.5
	for i in 4:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.position = Vector2(_vp(start_x + float(i) * (pip_w + 2.0)), _vp(12))
		pip.size = Vector2(_vp(pip_w), _vp(8))
		risk.add_child(pip)
		_risk_pips.append(pip)
	_risk_level = _put(risk, RETRO_UI.label("CLEAR", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_GREEN, _scale, false), 23)

	# Detail line for the risk sits just above the bar, right-aligned.
	_risk_detail = RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale)
	_risk_detail.anchor_left = 0.0
	_risk_detail.anchor_right = 1.0
	_risk_detail.anchor_top = 1.0
	_risk_detail.anchor_bottom = 1.0
	_risk_detail.offset_top = -_vp(BAR_HEIGHT_VP + 11)
	_risk_detail.offset_bottom = -_vp(BAR_HEIGHT_VP + 1)
	_risk_detail.offset_right = -_vp(4)
	_risk_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_risk_detail)


## A recessed LCD cell. Returns the content Control (inner area, 2vp padding) with the
## caption label already placed at y=1.
func _cell(row: HBoxContainer, id: String, caption: String) -> Control:
	var panel := _bevel(true)
	panel.name = "Cell_%s" % id
	panel.custom_minimum_size = Vector2(_vp(float(CELL_WIDTHS.get(id, 50))), _vp(CELL_HEIGHT_VP))
	row.add_child(panel)
	var content := Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = _vp(2)
	content.offset_right = -_vp(2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	var cap := RETRO_UI.label(caption, RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false)
	_put(content, cap, 1)
	_cells[id] = panel
	return content


## Places a label full-width at y (vp) inside a cell content control.
func _put(content: Control, l: Label, y_vp: float, left_px: float = 0.0) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = left_px
	l.offset_right = 0.0
	l.offset_top = _vp(y_vp)
	l.offset_bottom = _vp(y_vp) + l.get_combined_minimum_size().y
	content.add_child(l)
	return l


func _put_bar(content: Control, bar: Control, y_vp: float, h_vp: float) -> Control:
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_top = _vp(y_vp)
	bar.offset_bottom = _vp(y_vp + h_vp)
	content.add_child(bar)
	return bar


func _segment_bar(segments: int, full: Color, low: Color, height_vp: int) -> Control:
	var bar := RETRO_UI.SegmentBar.new()
	bar.ui_scale = _scale
	bar.segments = segments
	bar.color_full = full
	bar.color_low = low
	bar.custom_minimum_size = Vector2(0, _vp(height_vp))
	return bar


func _build_feed() -> void:
	_feed_box = VBoxContainer.new()
	_feed_box.name = "MessageFeed"
	_feed_box.position = Vector2(_vp(4), _vp(3))
	_feed_box.size = Vector2(_vp(250), _vp(60))
	_feed_box.add_theme_constant_override("separation", 0)
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed_box)


func _build_objective() -> void:
	var panel := _bevel(false)
	panel.fill = Color(0.07, 0.06, 0.05, 0.82)
	panel.light = Color(0.45, 0.36, 0.20, 0.9)
	panel.dark = Color(0.02, 0.02, 0.02, 0.9)
	panel.name = "Objective"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -_vp(146)
	panel.offset_right = -_vp(4)
	panel.offset_top = _vp(4)
	panel.offset_bottom = _vp(46)
	_root.add_child(panel)
	_objective_panel = panel
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = _vp(4)
	box.offset_right = -_vp(4)
	box.offset_top = _vp(3)
	box.offset_bottom = -_vp(3)
	box.add_theme_constant_override("separation", int(_vp(1)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_objective_title = RETRO_UI.label("VERA'S CHECKLIST", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_AMBER, _scale)
	box.add_child(_objective_title)
	_objective_text = RETRO_UI.label("", RETRO_UI.FONT_TEXT, 8, RETRO_UI.C_BONE, _scale)
	_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_text.custom_minimum_size = Vector2(_vp(134), 0)
	box.add_child(_objective_text)
	_objective_progress = RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_GREEN, _scale, false)
	box.add_child(_objective_progress)


func _build_crosshair_and_hint() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var s := float(_scale)
		var c := Color(0.95, 0.9, 0.78, 0.55)
		_crosshair.draw_rect(Rect2(Vector2(-2.0 * s, -0.5 * s), Vector2(4.0 * s, s)), c)
		_crosshair.draw_rect(Rect2(Vector2(-0.5 * s, -2.0 * s), Vector2(s, 4.0 * s)), c)
	)
	_hint_root.add_child(_crosshair)
	_crosshair.position = _built_for_size * 0.5 - Vector2(0, _vp(BAR_HEIGHT_VP) * 0.5)
	_crosshair.queue_redraw()

	_hint_label = RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE, _scale)
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.offset_top = _crosshair.position.y + _vp(10)
	_hint_label.offset_bottom = _hint_label.offset_top + _vp(12)
	_hint_root.add_child(_hint_label)


func _build_card() -> void:
	var panel := _bevel(false)
	panel.fill = Color(0.07, 0.06, 0.05, 0.9)
	panel.name = "GuestCard"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -_vp(136)
	panel.offset_right = -_vp(4)
	panel.offset_top = -_vp(58)
	panel.offset_bottom = _vp(46)
	panel.visible = false
	_root.add_child(panel)
	_card_panel = panel
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = _vp(4)
	box.offset_right = -_vp(4)
	box.offset_top = _vp(3)
	box.offset_bottom = -_vp(3)
	box.add_theme_constant_override("separation", int(_vp(1)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", int(_vp(3)))
	box.add_child(head)
	_card_face = RETRO_UI.PixelFace.new()
	_card_face.ui_scale = _scale
	_card_face.custom_minimum_size = Vector2(_vp(17), _vp(17))
	head.add_child(_card_face)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(names)
	_card_name = RETRO_UI.label("", RETRO_UI.FONT_TEXT, 8, RETRO_UI.C_AMBER, _scale)
	names.add_child(_card_name)
	_card_sub = RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false)
	names.add_child(_card_sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vp(3)))
	grid.add_theme_constant_override("v_separation", int(_vp(1)))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for row in NEED_ROWS:
		grid.add_child(RETRO_UI.label(str(row[1]), RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false))
		var bar := _segment_bar(10, RETRO_UI.C_GREEN, RETRO_UI.C_RED, 4)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_card_bars[str(row[0])] = bar
	_card_quote = RETRO_UI.label("", RETRO_UI.FONT_TEXT, 8, Color(0.98, 0.88, 0.62), _scale)
	_card_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_quote.custom_minimum_size = Vector2(_vp(124), 0)
	box.add_child(_card_quote)


func _build_banner() -> void:
	_banner_box = VBoxContainer.new()
	_banner_box.name = "Banner"
	_banner_box.anchor_left = 0.0
	_banner_box.anchor_right = 1.0
	_banner_box.anchor_top = 0.24
	_banner_box.anchor_bottom = 0.24
	_banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.visible = false
	_root.add_child(_banner_box)
	_banner_title = RETRO_UI.label("", RETRO_UI.FONT_TITLE, 22, RETRO_UI.C_AMBER, _scale)
	_banner_title.add_theme_constant_override("outline_size", _scale * 2)
	_banner_title.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.01))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_title)
	_banner_sub = RETRO_UI.label("", RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE, _scale)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner_sub)


# ═══════════════════════════════════════════════════════════════════════════════
# REFRESH
# ═══════════════════════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_health()
	if _stamina_bar != null:
		_stamina_bar.set_value(_stamina)
	if _light_bar != null:
		_light_bar.set_value(_light)
	if _cash_value != null and _money_known:
		_cash_value.text = "$%s" % _format_money(_money)
	_refresh_clock()
	_refresh_guests()
	_refresh_mail()
	_refresh_risk()
	_refresh_objective()
	set_hint_text(_hint_text)
	_rebuild_feed()
	if _card_timer > 0.0:
		_refresh_card()


func _refresh_health() -> void:
	if _health_value == null:
		return
	var hp := int(round(_health * 100.0))
	_health_value.text = str(hp)
	_health_value.add_theme_color_override("font_color", RETRO_UI.C_RED if hp < 35 else Color(0.98, 0.34, 0.26))
	_health_bar.set_value(_health)
	_health_bar.blink = _health < 0.3


func _refresh_clock() -> void:
	if _clock_value == null:
		return
	_clock_value.text = _time_str
	_clock_caption.text = "DAY %d" % _day
	_clock_phase.text = str(PHASE_LABELS[_phase])
	var cap_col := RETRO_UI.C_BONE_DIM
	var clock_col := RETRO_UI.C_BONE
	if _phase == PHASE_EVENING:
		cap_col = RETRO_UI.C_AMBER
	elif _phase == PHASE_NIGHT:
		cap_col = Color(1.0, 0.36, 0.30)
		clock_col = Color(0.72, 0.80, 1.0)
	_clock_phase.add_theme_color_override("font_color", cap_col)
	_clock_value.add_theme_color_override("font_color", clock_col)
	_weather_label.text = str(WEATHER_LABELS[_weather])


func _refresh_guests() -> void:
	if _guest_value == null:
		return
	_guest_value.text = "%d/%d" % [_beds.x, _beds.y]
	var count := int(_mood.get("guests", 0))
	var avg := float(_mood.get("avg_mood", 60.0))
	var unhappy := int(_mood.get("unhappy", 0))
	if count <= 0:
		_guest_mood.text = "EMPTY"
		_guest_mood.add_theme_color_override("font_color", RETRO_UI.C_BONE_DIM)
	else:
		var label := str(HUD_MOOD_WORDS.get(str(_mood.get("mood_label", "")), "OKAY"))
		if unhappy > 0:
			label = "%d UPSET" % unhappy
		_guest_mood.text = label
		var col := RETRO_UI.C_GREEN if avg >= 62.0 else (RETRO_UI.C_AMBER if avg >= 35.0 else Color(1.0, 0.36, 0.30))
		_guest_mood.add_theme_color_override("font_color", col)
	_guest_face.set_state(avg, _fear, count <= 0)


func _refresh_mail() -> void:
	if _mail_value == null:
		return
	_mail_value.text = str(_unread)
	_mail_value.add_theme_color_override("font_color", RETRO_UI.C_AMBER if _unread > 0 else RETRO_UI.C_BONE_DIM)


func _refresh_risk() -> void:
	if _risk_level == null:
		return
	var level := _risk_level_index
	for i in _risk_pips.size():
		var lit := i < level
		_risk_pips[i].color = _risk_color(i + 1) if lit else Color(0.12, 0.11, 0.10)
	_risk_level.text = str(RISK_LEVEL_LABELS[level])
	_risk_level.add_theme_color_override("font_color", _risk_color(level))
	var detail := _compose_risk_detail(_risk_payload)
	_risk_detail.text = "" if detail.is_empty() else "NIGHT RISK: %s" % detail.to_upper()


func _refresh_objective() -> void:
	if _objective_panel == null:
		return
	if _objective.is_empty():
		_objective_panel.visible = false
		return
	_objective_panel.visible = true
	_objective_title.text = str(_objective.get("title", "VERA'S CHECKLIST")).to_upper()
	_objective_text.text = str(_objective.get("text", ""))
	var progress := str(_objective.get("progress", ""))
	var reward := str(_objective.get("reward", ""))
	var parts: Array[String] = []
	if not progress.is_empty():
		parts.append(progress)
	if not reward.is_empty():
		parts.append("REWARD %s" % reward)
	_objective_progress.text = "  ".join(parts)
	_objective_progress.visible = not parts.is_empty()
	# Let the panel grow with wrapped text.
	await get_tree().process_frame
	if _objective_panel == null or not is_instance_valid(_objective_panel):
		return
	var box := _objective_panel.get_child(0) as Control
	if box != null:
		_objective_panel.offset_bottom = _objective_panel.offset_top + box.get_combined_minimum_size().y + _vp(6)


func _refresh_card() -> void:
	if _card_panel == null or _card_info.is_empty():
		return
	_card_panel.visible = true
	_card_panel.modulate.a = 1.0
	_card_name.text = str(_card_info.get("name", "Guest"))
	var archetype := str(_card_info.get("archetype", "")).replace("_", " ").to_upper()
	var party := int(_card_info.get("party_size", 1))
	_card_sub.text = "%s  x%d  %s" % [archetype, party, str(_card_info.get("mood_label", "")).to_upper()]
	var mood := float(_card_info.get("mood", 60.0))
	_card_face.set_state(mood, 1.0 - float((_card_info.get("needs", {}) as Dictionary).get("safety", 80.0)) / 100.0)
	var needs: Dictionary = _card_info.get("needs", {})
	for key in _card_bars.keys():
		(_card_bars[key]).set_value(float(needs.get(key, 70.0)) / 100.0)
	var thought := str(_card_info.get("thought", "")).strip_edges()
	_card_quote.text = "\"%s\"" % thought if not thought.is_empty() else ""
	await get_tree().process_frame
	if _card_panel == null or not is_instance_valid(_card_panel):
		return
	var box := _card_panel.get_child(0) as Control
	if box != null:
		var h := box.get_combined_minimum_size().y + _vp(6)
		_card_panel.offset_top = -h * 0.5 - _vp(10)
		_card_panel.offset_bottom = h * 0.5 - _vp(10)


func _rebuild_feed() -> void:
	if _feed_box == null:
		return
	for child in _feed_box.get_children():
		child.queue_free()
	for entry in _feed:
		var l := RETRO_UI.label(str(entry["text"]), RETRO_UI.FONT_TEXT, 8, entry["color"], _scale)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(_vp(250), 0)
		_feed_box.add_child(l)
		entry["label"] = l


func _update_feed(delta: float) -> void:
	var removed := false
	for i in range(_feed.size() - 1, -1, -1):
		var entry: Dictionary = _feed[i]
		entry["t"] = float(entry["t"]) - delta
		var l := entry.get("label", null) as Label
		if l != null and is_instance_valid(l):
			l.modulate.a = clampf(float(entry["t"]) / FEED_FADE_SEC, 0.0, 1.0)
		if float(entry["t"]) <= 0.0:
			_feed.remove_at(i)
			removed = true
	if removed:
		_rebuild_feed()


func _update_card(delta: float) -> void:
	if _card_panel == null or _card_timer <= 0.0:
		return
	_card_timer -= delta
	if _card_timer <= 0.0:
		_card_panel.visible = false
		_card_info.clear()
	elif _card_timer < 0.6:
		_card_panel.modulate.a = _card_timer / 0.6


func _update_banner(delta: float) -> void:
	if _banner_box == null or _banner_timer <= 0.0:
		return
	_banner_timer -= delta
	var elapsed := _banner_total - _banner_timer
	var a := 1.0
	if elapsed < 0.35:
		a = elapsed / 0.35
	elif _banner_timer < 0.8:
		a = _banner_timer / 0.8
	_banner_box.modulate.a = clampf(a, 0.0, 1.0)
	if _banner_timer <= 0.0:
		_banner_box.visible = false


func _apply_money(amount: int) -> void:
	if _money_known and amount == _money:
		return
	var delta := amount - _money if _money_known else 0
	_money = amount
	_money_known = true
	if _cash_value != null:
		_cash_value.text = "$%s" % _format_money(amount)
	if delta != 0 and _cash_delta != null:
		_cash_delta.text = "%s$%s" % ["+" if delta > 0 else "-", _format_money(absi(delta))]
		_cash_delta.add_theme_color_override("font_color", RETRO_UI.C_GREEN if delta > 0 else Color(1.0, 0.36, 0.30))
		_money_flash = 2.0


func _update_money_flash(delta: float) -> void:
	if _money_flash <= 0.0 or _cash_delta == null:
		return
	_money_flash -= delta
	_cash_delta.modulate.a = clampf(_money_flash, 0.0, 1.0)
	if _money_flash <= 0.0:
		_cash_delta.text = ""


func _poll_guest_state() -> void:
	if GuestManager == null:
		return
	if GuestManager.has_method("get_bed_metrics"):
		var beds: Dictionary = GuestManager.get_bed_metrics()
		_beds = Vector2i(int(beds.get("occupied", 0)), int(beds.get("capacity", 0)))
	if GuestManager.has_method("get_camp_mood_summary"):
		_mood = GuestManager.get_camp_mood_summary()
	_refresh_guests()


func _announce_phase(phase: int) -> void:
	match phase:
		PHASE_DAY:
			show_banner("DAY %d" % _day, "THE BUILDER IS UNLOCKED. THE CAMP IS YOURS AGAIN.", RETRO_UI.C_AMBER, 3.2)
		PHASE_EVENING:
			push_status("Evening. Guests start drifting back to their beds.", STATUS_WARN)
		PHASE_NIGHT:
			show_banner("NIGHT %d" % _day, "BUILDER LOCKED. SURVIVE UNTIL 06:30.", Color(1.0, 0.30, 0.24), 4.2)


# ═══════════════════════════════════════════════════════════════════════════════
# BINDINGS + HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_email_binding() -> void:
	if _mail_bound or EmailManager == null:
		return
	if EmailManager.has_signal("unread_count_changed"):
		var callback := Callable(self, "_on_unread_count_changed")
		if not EmailManager.unread_count_changed.is_connected(callback):
			EmailManager.unread_count_changed.connect(callback)
		_mail_bound = true


func _on_unread_count_changed(count: int) -> void:
	_unread = maxi(0, count)
	_refresh_mail()


func _get_unread_count() -> int:
	if EmailManager != null and EmailManager.has_method("get_unread_count"):
		return int(EmailManager.call("get_unread_count"))
	return 0


## Mirrors TimeSystem thresholds: day 06:30, evening 18:00, night 20:00.
func _phase_for_minute(minute: int) -> int:
	if minute >= 20 * 60 or minute < 390:
		return PHASE_NIGHT
	if minute >= 18 * 60:
		return PHASE_EVENING
	return PHASE_DAY


func _risk_color(level: int) -> Color:
	match clampi(level, 0, 4):
		0:
			return RETRO_UI.C_GREEN
		1:
			return Color(0.86, 0.83, 0.45)
		2:
			return RETRO_UI.C_AMBER
		3:
			return Color(0.95, 0.42, 0.22)
		_:
			return RETRO_UI.C_RED


## One line naming the archetype closest to tipping, so the meter is actionable
## rather than merely ominous.
func _compose_risk_detail(payload: Dictionary) -> String:
	var entries_any = payload.get("archetypes", [])
	if not (entries_any is Array):
		return ""
	var worst: Dictionary = {}
	var worst_score := -1.0
	for entry_any in entries_any:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var score := float(entry.get("expected_spawns", 0.0))
		if int(entry.get("guaranteed_spawns", 0)) > 0:
			score += 10.0
		if score > worst_score:
			worst_score = score
			worst = entry
	if worst.is_empty():
		return ""
	var label := str(worst.get("label", "?"))
	var count := int(worst.get("count", 0))
	if int(worst.get("guaranteed_spawns", 0)) > 0:
		return "%s x%d - spawn guaranteed" % [label, count]
	var tier := str(worst.get("chance_tier", "none"))
	if tier == "none" or tier.is_empty():
		var thresholds_any = worst.get("next_thresholds", {})
		if thresholds_any is Dictionary:
			var small_at := int((thresholds_any as Dictionary).get("small_at", 0))
			if small_at > count:
				return "safe - %s risk starts at %d" % [label, small_at]
		return "all archetypes within safe count"
	var pct := int(round(float(worst.get("chance_probability", 0.0)) * 100.0))
	return "%s x%d - %s risk %d%%" % [label, count, str(RISK_TIER_LABELS.get(tier, tier)), pct]


func _format_money(amount: int) -> String:
	var negative := amount < 0
	var digits := str(absi(amount))
	var out := ""
	var counter := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		counter += 1
		if counter % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if negative else out


func _parse_time_to_minutes(time_str: String) -> int:
	var parts := time_str.strip_edges().split(":")
	if parts.size() < 2:
		return 9 * 60
	return (int(parts[0]) * 60) + int(parts[1])
