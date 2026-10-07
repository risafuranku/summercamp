extends Node
## Build-engine style HUD.
##
##   ┌ message feed (Duke3D quotes)                      objective tracker ┐
##   │                                                     guest card     │
##   │ ════════════════ centre banner band (NIGHT 1) ══════════════════  │
##   │                              +   ▼ 24M (objective marker)          │
##   │                       [E] ENTER RECEPTION                          │
##   └[HEALTH][STAM/LIGHT][CASH][DAY·CLOCK][GUESTS ☺][MAIL][NIGHT RISK]──┘
##
## Everything is laid out in virtual pixels (vp) times an integer UI scale so the pixel
## fonts stay crisp (retro_ui.gd). The layout is rebuilt when the window size changes;
## all displayed values are cached so a rebuild restores them.
##
## Layout rules (asserted by tools/hud_layout_check.tscn):
## - every status-bar label sits on a fixed baseline inside its cell and fits its width;
## - the guest card stacks under the objective tracker, never over it;
## - the banner is a full-width band drawn above both, so it reads as a deliberate
##   title card rather than text spilling over a panel;
## - the objective marker is screen-space and constant-size; it hides close to the
##   target, where the crosshair hint takes over.
##
## The NIGHT RISK cell encodes the game's central risk/reward trade (see DESIGN.md):
## lamps for the level, the archetype closest to tipping and its odds underneath.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")

const HUD_LAYER_INDEX := 65
const HINT_LAYER_INDEX := 70

# Message kinds (push_status).
const STATUS_INFO := 0
const STATUS_GOOD := 1
const STATUS_WARN := 2
const STATUS_DENY := 3
const STATUS_QUOTE := 4

const BAR_HEIGHT_VP := 40
const CELL_HEIGHT_VP := 34
const FEED_MAX_LINES := 4
const FEED_WIDTH_VP := 200
const FEED_HOLD_SEC := 6.0
const FEED_FADE_SEC := 0.8
const CARD_HOLD_SEC := 7.0
const TRACKER_WIDTH_VP := 150
const CARD_WIDTH_VP := 132
const WAYPOINT_HIDE_DISTANCE := 4.5
const WAYPOINT_EDGE_VP := 14.0

# Cell rows (baselines in vp from the cell top).
const ROW_CAPTION := 8
const ROW_VALUE := 22
const ROW_FOOTER := 31

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
const RISK_SHORT_NAMES := {"quiet_guy": "QUIET", "drunk": "DRUNK", "cheap_chick": "CHICK"}

const NEED_ROWS := [
	["energy", "NRG"], ["hunger", "FOOD"], ["bladder", "WC"],
	["hygiene", "WASH"], ["fun", "FUN"], ["safety", "SAFE"],
]

## vp widths of the status bar cells (also asserted by tools/hud_layout_check.tscn).
const CELL_WIDTHS := {
	"health": 46, "stamina": 44, "cash": 62, "clock": 86, "guests": 64, "mail": 30, "risk": 62,
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
var _camera_provider: Callable

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
var _feed_box: VBoxContainer
var _objective_panel: Control
var _objective_title: Label
var _objective_text: Label
var _objective_hint: Label
var _objective_progress: Label
var _hint_plate: Control
var _hint_label: Label
var _crosshair: Control
var _waypoint_marker: Control
var _card_panel: Control
var _card_name: Label
var _card_sub: Label
var _card_face: Control
var _card_quote: Label
var _card_bars: Dictionary = {}
var _banner_band: Control
var _banner_title
var _banner_sub: Label

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
var _risk_level_known: bool = false
var _risk_payload: Dictionary = {}
var _unread: int = 0
var _objective: Dictionary = {}
var _hint_text: String = ""
var _feed: Array[Dictionary] = []
var _card_info: Dictionary = {}
var _card_timer: float = 0.0
var _banner_title_text: String = ""
var _banner_sub_text: String = ""
var _banner_color: Color = RETRO_UI.C_AMBER
var _banner_timer: float = 0.0
var _banner_total: float = 0.0
var _fear: float = 0.0
var _mail_bound: bool = false
var _poll_money: float = 0.0
var _poll_guests: float = 0.0
var _blink_t: float = 0.0
var _last_phase_announce: int = -1
var _waypoint_pos: Vector3 = Vector3.INF
var _waypoint_label: String = ""


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


## Callable returning the active Camera3D (player camera). Needed for the objective
## marker, which projects a world position onto the screen.
func set_camera_provider(provider: Callable) -> void:
	_camera_provider = provider


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
	if _hint_label == null:
		return
	_hint_label.text = text.to_upper()
	_hint_plate.visible = not text.is_empty()
	_hint_plate.size = Vector2.ZERO


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


## 0-1 fear from the night: widens the status face's eyes.
func set_fear(value: float) -> void:
	_fear = clampf(value, 0.0, 1.0)
	_refresh_guests()


## Legacy entry point: level only. Prefer `set_liminal_forecast()`.
func set_liminal_forecast_count(value: int) -> void:
	_risk_payload.clear()
	_set_risk_level(clampi(value, 0, 4), false)


## Full forecast payload from `GuestManager.get_liminal_forecast_data()`.
func set_liminal_forecast(payload: Dictionary) -> void:
	_risk_payload = payload.duplicate(true)
	_set_risk_level(clampi(int(payload.get("hud_level", 0)), 0, 4), true)


## Message feed line (top-left). `kind` is one of the STATUS_* constants. Lines sharing
## a non-empty `group` replace each other (a phase change makes the previous phase's
## line stale, a new risk reading replaces the old one).
func push_status(text: String, kind: int = STATUS_INFO, group: String = "") -> void:
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
			color = RETRO_UI.C_RED_LIGHT
		STATUS_QUOTE:
			color = RETRO_UI.C_QUOTE
	if not group.is_empty():
		for i in range(_feed.size() - 1, -1, -1):
			if str(_feed[i].get("group", "")) == group:
				_feed.remove_at(i)
	_feed.append({"text": text, "color": color, "group": group, "t": FEED_HOLD_SEC + FEED_FADE_SEC})
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


## Objective tracker (QuestManager). Keys: title, text, hint, progress ("2/3"), reward.
func set_objective(data: Dictionary) -> void:
	_objective = data.duplicate(true)
	_refresh_objective()


func clear_objective() -> void:
	_objective.clear()
	_refresh_objective()


## Screen-space objective marker over a world position (Vector3.INF hides it).
func set_waypoint(world_pos: Vector3, label: String = "") -> void:
	_waypoint_pos = world_pos
	_waypoint_label = label
	if _waypoint_marker != null:
		_waypoint_marker.queue_redraw()


func clear_waypoint() -> void:
	set_waypoint(Vector3.INF)


## Full-width title band that fades out ("NIGHT 1", "TASK COMPLETE").
func show_banner(title: String, subtitle: String = "", color: Color = RETRO_UI.C_AMBER, seconds: float = 3.6) -> void:
	_ensure_world_hud()
	_banner_title_text = title
	_banner_sub_text = subtitle
	_banner_color = color
	_banner_total = maxf(0.8, seconds)
	_banner_timer = _banner_total
	_apply_banner()


func set_bed_metrics(occupied: int, capacity: int) -> void:
	_beds = Vector2i(maxi(0, occupied), maxi(0, capacity))
	_refresh_guests()


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
	_stack_right_column()
	if _waypoint_marker != null and _hint_layer.visible:
		_waypoint_marker.queue_redraw()
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
		_root.remove_child(child)
		child.queue_free()
	for child in _hint_root.get_children():
		_hint_root.remove_child(child)
		child.queue_free()
	_cells.clear()
	_risk_pips.clear()
	_card_bars.clear()

	_build_status_bar()
	_build_feed()
	_build_objective()
	_build_card()
	_build_banner()
	_build_crosshair_and_hint()
	_build_waypoint_marker()

	_refresh_all()


func _vp(v: float) -> float:
	return v * float(_scale)


func _bevel(recessed: bool, textured: bool = false) -> RETRO_UI.BevelPanel:
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


## Dark translucent plate that sizes itself to its content (tracker, card, hint).
func _plate() -> RETRO_UI.BevelPanel:
	var p := _bevel(false)
	p.fit_children = true
	p.fill = RETRO_UI.C_PANEL
	p.light = RETRO_UI.C_PANEL_LIGHT
	p.dark = Color(0.02, 0.02, 0.02, 0.9)
	return p


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

	# Rows inside a 34vp cell, all baseline-exact:
	#   caption  baseline 8   Silkscreen
	#   value    baseline 22  Jersey 10 (10px caps)
	#   footer   baseline 31  Silkscreen   (or a 3vp bar at y 26)
	var health := _cell(row, "health", "HEALTH")
	_health_value = _put(health, _big("100", RETRO_UI.C_BONE), ROW_VALUE)
	_health_bar = _put_bar(health, _segment_bar(10, RETRO_UI.C_RED_LIGHT, RETRO_UI.C_RED_DARK), 26, 3)

	var stam := _cell(row, "stamina", "STAMINA")
	_stamina_bar = _put_bar(stam, _segment_bar(8, RETRO_UI.C_GREEN, RETRO_UI.C_AMBER), 11, 4)
	_put(stam, _caption("LIGHT"), 22)
	_light_bar = _put_bar(stam, _segment_bar(8, Color(1.0, 0.92, 0.55), RETRO_UI.C_RED), 25, 4)

	var cash := _cell(row, "cash", "CASH")
	_cash_value = _put(cash, _big("$0", RETRO_UI.C_AMBER), ROW_VALUE)
	_cash_delta = _put(cash, _caption(""), ROW_FOOTER)

	var clock := _cell(row, "clock", "DAY 1")
	_clock_caption = clock.get_child(0) as Label
	_clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_weather_label = _put(clock, _caption("CLEAR", RETRO_UI.C_BLUE), ROW_CAPTION)
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_value = _put(clock, _big("09:00", RETRO_UI.C_BONE), ROW_VALUE)
	_clock_phase = _put(clock, _caption("DAY"), ROW_FOOTER)

	var guests := _cell(row, "guests", "GUESTS")
	_guest_face = RETRO_UI.PixelFace.new()
	_guest_face.ui_scale = _scale
	_guest_face.position = Vector2(0.0, _vp(11))
	_guest_face.size = Vector2(_vp(17), _vp(17))
	guests.add_child(_guest_face)
	_guest_value = _put(guests, _big("0/0", RETRO_UI.C_BONE), ROW_VALUE, _vp(19))
	_guest_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_guest_mood = _put(guests, _caption("EMPTY"), ROW_FOOTER, _vp(19))
	_guest_mood.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var mail := _cell(row, "mail", "MAIL")
	_mail_cell = mail
	_mail_value = _put(mail, _big("0", RETRO_UI.C_BONE_DIM), ROW_VALUE)

	var risk := _cell(row, "risk", "NIGHT RISK")
	var pip_w := 11.0
	var gap := 2.0
	var inner_w := float(CELL_WIDTHS["risk"]) - 4.0
	var start_x := floorf((inner_w - (pip_w * 4.0 + gap * 3.0)) * 0.5)
	for i in 4:
		var pip := ColorRect.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.position = Vector2(_vp(start_x + float(i) * (pip_w + gap)), _vp(12))
		pip.size = Vector2(_vp(pip_w), _vp(9))
		risk.add_child(pip)
		_risk_pips.append(pip)
	_risk_level = _put(risk, _caption("CLEAR", RETRO_UI.C_GREEN), ROW_FOOTER)


func _caption(text: String, color: Color = RETRO_UI.C_BONE_DIM) -> Label:
	return RETRO_UI.label(text, RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, color, _scale, false)


func _big(text: String, color: Color) -> Label:
	return RETRO_UI.label(text, RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG, color, _scale, true)


func _body(text: String, color: Color, shadow: bool = true) -> Label:
	return RETRO_UI.label(text, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, color, _scale, shadow)


## A recessed LCD cell. Returns the content Control (inner area, 2vp side padding) with
## the caption label already placed on the caption baseline.
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
	_put(content, _caption(caption), ROW_CAPTION)
	_cells[id] = panel
	return content


## Places a label full-width with its baseline at `baseline_vp` inside a cell.
func _put(content: Control, l: Label, baseline_vp: float, left_px: float = 0.0) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = left_px
	l.offset_right = 0.0
	RETRO_UI.place_on_baseline(l, baseline_vp, _scale)
	content.add_child(l)
	return l


func _put_bar(content: Control, bar: Control, y_vp: float, h_vp: float) -> Control:
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_top = _vp(y_vp)
	bar.offset_bottom = _vp(y_vp + h_vp)
	content.add_child(bar)
	return bar


func _segment_bar(segments: int, full: Color, low: Color) -> RETRO_UI.SegmentBar:
	var bar := RETRO_UI.SegmentBar.new()
	bar.ui_scale = _scale
	bar.segments = segments
	bar.color_full = full
	bar.color_low = low
	return bar


func _build_feed() -> void:
	_feed_box = VBoxContainer.new()
	_feed_box.name = "MessageFeed"
	_feed_box.position = Vector2(_vp(4), _vp(4))
	_feed_box.size = Vector2(_vp(_feed_width_vp()), 0)
	_feed_box.add_theme_constant_override("separation", int(_vp(1)))
	_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed_box)


## The feed may not run under the tracker: it gets whatever is left of the top row.
func _feed_width_vp() -> float:
	var screen_vp := _built_for_size.x / float(_scale)
	return clampf(screen_vp - float(TRACKER_WIDTH_VP) - 16.0, 120.0, float(FEED_WIDTH_VP))


func _build_objective() -> void:
	var panel := _plate()
	panel.name = "Objective"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -_vp(4)
	panel.offset_left = -_vp(4 + TRACKER_WIDTH_VP)
	panel.offset_top = _vp(4)
	_root.add_child(panel)
	_objective_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_vp(2)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_objective_title = RETRO_UI.label("VERA'S CHECKLIST", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, _scale)
	box.add_child(_objective_title)
	var wrap_w := _vp(TRACKER_WIDTH_VP - 8)
	_objective_text = _body("", RETRO_UI.C_BONE)
	_objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_text.custom_minimum_size = Vector2(wrap_w, 0)
	box.add_child(_objective_text)
	_objective_hint = _body("", RETRO_UI.C_BONE_DIM)
	_objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_hint.custom_minimum_size = Vector2(wrap_w, 0)
	box.add_child(_objective_hint)
	_objective_progress = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_GREEN, _scale, false)
	box.add_child(_objective_progress)


func _build_card() -> void:
	var panel := _plate()
	panel.name = "GuestCard"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -_vp(4)
	panel.offset_left = -_vp(4 + CARD_WIDTH_VP)
	panel.offset_top = _vp(4)
	panel.visible = false
	_root.add_child(panel)
	_card_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_vp(2)))
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
	names.add_theme_constant_override("separation", int(_vp(1)))
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	_card_name = _body("", RETRO_UI.C_AMBER)
	names.add_child(_card_name)
	_card_sub = _caption("")
	names.add_child(_card_sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(_vp(3)))
	grid.add_theme_constant_override("v_separation", int(_vp(2)))
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(grid)
	for row in NEED_ROWS:
		var cap := _caption(str(row[1]))
		cap.custom_minimum_size = Vector2(_vp(22), 0)
		grid.add_child(cap)
		var bar := _segment_bar(10, RETRO_UI.C_GREEN, RETRO_UI.C_RED)
		bar.custom_minimum_size = Vector2(0, _vp(4))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_card_bars[str(row[0])] = bar
	_card_quote = _body("", RETRO_UI.C_QUOTE)
	_card_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_quote.custom_minimum_size = Vector2(_vp(CARD_WIDTH_VP - 8), 0)
	box.add_child(_card_quote)


func _build_banner() -> void:
	var band := _bevel(false)
	band.name = "Banner"
	band.fit_children = true
	band.pad_vp = Vector4(0, 5, 0, 5)
	band.fill = Color(0.03, 0.025, 0.02, 0.86)
	band.light = RETRO_UI.C_PANEL_LIGHT
	band.dark = Color(0.0, 0.0, 0.0, 0.9)
	# Full width; the side bevels sit just off-screen so only the top and bottom edges show.
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.offset_left = -_vp(1)
	band.offset_right = _vp(1)
	var world_h := _built_for_size.y - _vp(BAR_HEIGHT_VP)
	band.offset_top = floorf(world_h * 0.28 / float(_scale)) * float(_scale)
	band.visible = false
	_root.add_child(band)
	_banner_band = band
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(_vp(3)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(box)
	_banner_title = RETRO_UI.PixelTitle.new()
	_banner_title.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 2, _scale)
	box.add_child(_banner_title)
	_banner_sub = _caption("", RETRO_UI.C_BONE)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_banner_sub)


func _build_crosshair_and_hint() -> void:
	_crosshair = Control.new()
	_crosshair.name = "Crosshair"
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var s := float(_scale)
		var c := Color(0.95, 0.9, 0.78, 0.6)
		_crosshair.draw_rect(Rect2(Vector2(-2.0 * s, 0.0), Vector2(s, s)), c)
		_crosshair.draw_rect(Rect2(Vector2(s, 0.0), Vector2(s, s)), c)
		_crosshair.draw_rect(Rect2(Vector2(0.0, -2.0 * s), Vector2(s, s)), c)
		_crosshair.draw_rect(Rect2(Vector2(0.0, s), Vector2(s, s)), c)
	)
	_hint_root.add_child(_crosshair)
	_crosshair.position = _crosshair_center().floor()
	_crosshair.queue_redraw()

	_hint_plate = _plate()
	_hint_plate.name = "HintPlate"
	_hint_plate.pad_vp = Vector4(4, 2, 4, 2)
	_hint_plate.fill = Color(0.03, 0.025, 0.02, 0.72)
	_hint_plate.light = Color(0.30, 0.26, 0.20, 0.8)
	_hint_plate.anchor_left = 0.5
	_hint_plate.anchor_right = 0.5
	_hint_plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_plate.offset_top = _crosshair.position.y + _vp(12)
	_hint_plate.visible = false
	_hint_root.add_child(_hint_plate)
	_hint_label = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE, _scale)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_plate.add_child(_hint_label)


func _crosshair_center() -> Vector2:
	return Vector2(_built_for_size.x * 0.5, (_built_for_size.y - _vp(BAR_HEIGHT_VP)) * 0.5)


func _build_waypoint_marker() -> void:
	_waypoint_marker = Control.new()
	_waypoint_marker.name = "ObjectiveMarker"
	_waypoint_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_waypoint_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waypoint_marker.draw.connect(_draw_waypoint)
	_hint_root.add_child(_waypoint_marker)
	_hint_root.move_child(_waypoint_marker, 0)


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
	if _banner_timer > 0.0:
		_apply_banner()


func _refresh_health() -> void:
	if _health_value == null:
		return
	var hp := int(round(_health * 100.0))
	_health_value.text = str(hp)
	_health_value.add_theme_color_override("font_color", RETRO_UI.C_RED if hp < 35 else RETRO_UI.C_RED_LIGHT)
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
		cap_col = RETRO_UI.C_RED_LIGHT
		clock_col = RETRO_UI.C_NIGHT
	_clock_phase.add_theme_color_override("font_color", cap_col)
	_clock_value.add_theme_color_override("font_color", clock_col)
	_weather_label.text = str(WEATHER_LABELS[_weather])
	_weather_label.add_theme_color_override("font_color", RETRO_UI.C_RED_LIGHT if _weather == WEATHER_LABELS.size() - 1 else RETRO_UI.C_BLUE)


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
		var col := RETRO_UI.C_GREEN if avg >= 62.0 else (RETRO_UI.C_AMBER if avg >= 35.0 else RETRO_UI.C_RED_LIGHT)
		_guest_mood.add_theme_color_override("font_color", col)
	_guest_face.set_state(avg, _fear, count <= 0)


func _refresh_mail() -> void:
	if _mail_value == null:
		return
	_mail_value.text = str(mini(_unread, 99))
	_mail_value.add_theme_color_override("font_color", RETRO_UI.C_AMBER if _unread > 0 else RETRO_UI.C_BONE_DIM)


func _set_risk_level(level: int, from_payload: bool) -> void:
	var previous := _risk_level_index
	var known := _risk_level_known
	_risk_level_index = level
	_risk_level_known = true
	_refresh_risk()
	if known and from_payload and level != previous:
		var detail := _compose_risk_detail(_risk_payload)
		var verb := "raised" if level > previous else "eased"
		var kind := STATUS_WARN if level > previous else STATUS_GOOD
		var line := "Night risk %s: %s" % [verb, RISK_LEVEL_LABELS[level].to_lower()]
		if not detail.is_empty():
			line += " (%s)" % detail
		push_status(line, kind, "risk")


func _refresh_risk() -> void:
	if _risk_level == null:
		return
	var level := _risk_level_index
	for i in _risk_pips.size():
		var lit := i < level
		_risk_pips[i].color = _risk_color(i + 1) if lit else Color(0.12, 0.11, 0.10)
	_risk_level.text = _risk_footer(level)
	_risk_level.add_theme_color_override("font_color", _risk_color(level))


## Footer under the risk lamps: "CLEAR", or the archetype closest to tipping and its
## odds ("DRUNK 27%", "CHICK SURE") so the meter says what to do about it.
func _risk_footer(level: int) -> String:
	var worst := _worst_risk_entry(_risk_payload)
	if level <= 0 or worst.is_empty():
		return str(RISK_LEVEL_LABELS[level])
	var name_id := str(worst.get("archetype", ""))
	var short := str(RISK_SHORT_NAMES.get(name_id, str(worst.get("label", "?")).to_upper().left(5)))
	if int(worst.get("guaranteed_spawns", 0)) > 0:
		return "%s SURE" % short
	var pct := int(round(float(worst.get("chance_probability", 0.0)) * 100.0))
	if pct <= 0:
		return str(RISK_LEVEL_LABELS[level])
	return "%s %d%%" % [short, pct]


func _refresh_objective() -> void:
	if _objective_panel == null:
		return
	if _objective.is_empty():
		_objective_panel.visible = false
		return
	_objective_panel.visible = true
	_objective_title.text = str(_objective.get("title", "VERA'S CHECKLIST")).to_upper()
	var text := str(_objective.get("text", ""))
	var hint := str(_objective.get("hint", ""))
	# Older callers fold the hint into the text after "\n> ".
	var split := text.find("\n> ")
	if hint.is_empty() and split >= 0:
		hint = text.substr(split + 3)
		text = text.substr(0, split)
	_objective_text.text = text
	_objective_hint.text = "> %s" % hint if not hint.is_empty() else ""
	_objective_hint.visible = not hint.is_empty()
	var progress := str(_objective.get("progress", ""))
	var reward := str(_objective.get("reward", ""))
	var parts: Array[String] = []
	if not progress.is_empty():
		parts.append(progress)
	if not reward.is_empty():
		parts.append("REWARD %s" % reward)
	_objective_progress.text = "  ".join(parts)
	_objective_progress.visible = not parts.is_empty()
	_objective_panel.size = Vector2(_vp(TRACKER_WIDTH_VP), 0)


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
	var needs: Dictionary = _card_info.get("needs", {})
	_card_face.set_state(mood, 1.0 - float(needs.get("safety", 80.0)) / 100.0)
	for key in _card_bars.keys():
		(_card_bars[key]).set_value(float(needs.get(key, 70.0)) / 100.0)
	var thought := str(_card_info.get("thought", "")).strip_edges()
	_card_quote.text = "\"%s\"" % thought if not thought.is_empty() else ""
	_card_quote.visible = not thought.is_empty()
	_card_panel.size = Vector2(_vp(CARD_WIDTH_VP), 0)
	_stack_right_column()


## The card hangs under the tracker; both are self-sizing, so this runs every frame.
func _stack_right_column() -> void:
	if _card_panel == null or not _card_panel.visible:
		return
	var top := _vp(4)
	if _objective_panel != null and _objective_panel.visible:
		top = _objective_panel.position.y + _objective_panel.size.y + _vp(3)
	_card_panel.offset_top = top
	_card_panel.offset_bottom = top + _card_panel.get_combined_minimum_size().y


func _rebuild_feed() -> void:
	if _feed_box == null:
		return
	for child in _feed_box.get_children():
		_feed_box.remove_child(child)
		child.queue_free()
	var width := _vp(_feed_width_vp())
	for entry in _feed:
		var l := _body(str(entry["text"]), entry["color"])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		_feed_box.add_child(l)
		entry["label"] = l
	_feed_box.size = Vector2(width, 0)


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


func _apply_banner() -> void:
	if _banner_band == null:
		return
	_banner_title.set_colors(_banner_color.lerp(Color.WHITE, 0.45), _banner_color)
	_banner_title.set_text(_banner_title_text)
	_banner_sub.text = _banner_sub_text.to_upper()
	_banner_sub.visible = not _banner_sub_text.is_empty()
	_banner_band.visible = _banner_timer > 0.0
	_banner_band.size = Vector2(_banner_band.size.x, 0)
	_update_banner(0.0)


## The band opens vertically from its centre line (0.15s), holds, then fades. The open
## is stepped in whole virtual pixels so the bevel never lands between pixels.
func _update_banner(delta: float) -> void:
	if _banner_band == null or _banner_timer <= 0.0:
		return
	_banner_timer -= delta
	var elapsed := _banner_total - _banner_timer
	var open := clampf(elapsed / 0.15, 0.0, 1.0)
	var a := 1.0
	if _banner_timer < 0.8:
		a = _banner_timer / 0.8
	_banner_band.modulate.a = clampf(a, 0.0, 1.0)
	var full_h := maxf(1.0, _banner_band.size.y / float(_scale))
	var h := maxf(2.0, floorf(full_h * open))
	_banner_band.scale = Vector2(1.0, h / full_h)
	_banner_band.pivot_offset = Vector2(0.0, _banner_band.size.y * 0.5)
	if _banner_timer <= 0.0:
		_banner_band.visible = false


func _apply_money(amount: int) -> void:
	if _money_known and amount == _money:
		return
	var delta := amount - _money if _money_known else 0
	_money = amount
	_money_known = true
	if _cash_value != null:
		_cash_value.text = "$%s" % _format_money(amount)
		_cash_value.add_theme_color_override("font_color", RETRO_UI.C_RED_LIGHT if amount < 0 else RETRO_UI.C_AMBER)
	if delta != 0 and _cash_delta != null:
		_cash_delta.text = "%s$%s" % ["+" if delta > 0 else "-", _format_money(absi(delta))]
		_cash_delta.add_theme_color_override("font_color", RETRO_UI.C_GREEN if delta > 0 else RETRO_UI.C_RED_LIGHT)
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
			push_status("Morning. The builder is unlocked again.", STATUS_GOOD, "phase")
			show_banner("DAY %d" % _day, "The builder is unlocked. The camp is yours again.", RETRO_UI.C_AMBER, 3.2)
		PHASE_EVENING:
			push_status("Evening. Guests start drifting back to their beds.", STATUS_WARN, "phase")
		PHASE_NIGHT:
			push_status("Night. The builder is locked until 06:30.", STATUS_DENY, "phase")
			show_banner("NIGHT %d" % _day, "Builder locked. Survive until 06:30.", RETRO_UI.C_RED_LIGHT, 4.2)


# ═══════════════════════════════════════════════════════════════════════════════
# OBJECTIVE MARKER
# ═══════════════════════════════════════════════════════════════════════════════

func _active_camera() -> Camera3D:
	if _camera_provider.is_valid():
		return _camera_provider.call() as Camera3D
	return null


## A pixel chevron over the target with the distance under it. When the target is off
## screen the marker clamps to the nearest edge and the chevron points the way; when it
## is behind the player it sits on the left or right edge, whichever way is the shorter
## turn.
func _draw_waypoint() -> void:
	if _waypoint_pos == Vector3.INF or _objective.is_empty():
		return
	var cam := _active_camera()
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var dist := cam.global_position.distance_to(_waypoint_pos)
	if dist < WAYPOINT_HIDE_DISTANCE:
		return
	var cam_vp := cam.get_viewport()
	var src_size := cam_vp.get_visible_rect().size if cam_vp != null else _built_for_size
	if src_size.x <= 0.0 or src_size.y <= 0.0:
		return
	var s := float(_scale)
	var screen := _built_for_size
	var world_h := screen.y - _vp(BAR_HEIGHT_VP)
	var margin := _vp(WAYPOINT_EDGE_VP)
	var local := cam.global_transform.affine_inverse() * _waypoint_pos
	var at := Vector2.ZERO
	var dir := Vector2.DOWN
	var on_screen := false
	if local.z < -0.1:
		var p := cam.unproject_position(_waypoint_pos) / src_size * screen
		var clamped := Vector2(clampf(p.x, margin, screen.x - margin), clampf(p.y, margin, world_h - margin))
		on_screen = clamped.is_equal_approx(p)
		at = clamped
		if not on_screen:
			var off := p - clamped
			dir = Vector2(signf(off.x), 0.0) if absf(off.x) >= absf(off.y) else Vector2(0.0, signf(off.y))
	else:
		var right := local.x >= 0.0
		at = Vector2(screen.x - margin if right else margin, world_h * 0.5)
		dir = Vector2.RIGHT if right else Vector2.LEFT
	at = (at / s).floor() * s
	var bob := floorf(sin(_blink_t * 4.0) * 1.5 + 0.5) * s
	var c := RETRO_UI.C_AMBER
	var dark := RETRO_UI.C_OUTLINE
	if on_screen:
		_draw_chevron(at + Vector2(0.0, -_vp(8) + bob), Vector2.DOWN, c, dark)
	else:
		_draw_chevron(at + dir * (absf(bob) + s), dir, c, dark)
	var text := "%dM" % int(round(dist))
	if not _waypoint_label.is_empty():
		text = "%s %s" % [_waypoint_label.to_upper(), text]
	var font := RETRO_UI.FONT_LABEL
	var fsize := RETRO_UI.SIZE_LABEL * _scale
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var tx := floorf(clampf(at.x - w * 0.5, s * 2.0, screen.x - w - s * 2.0) / s) * s
	var ty := at.y + (_vp(4) if on_screen else _vp(12))
	if not on_screen and dir.y < 0.0:
		ty = at.y + _vp(14)
	elif not on_screen and dir.y > 0.0:
		ty = at.y - _vp(8)
	_waypoint_marker.draw_string(font, Vector2(tx + s, ty + s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, RETRO_UI.C_SHADOW)
	_waypoint_marker.draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, c)


## A 7-pixel-wide chevron whose tip is at `tip`, pointing along a cardinal `dir`, with a
## one-pixel dark outline.
func _draw_chevron(tip: Vector2, dir: Vector2, c: Color, dark: Color) -> void:
	var s := float(_scale)
	var back := -dir
	var side := Vector2(-dir.y, dir.x)
	var cells: Array[Vector2] = []
	for row in 4:
		var half := row
		for k in range(-half, half + 1):
			cells.append(back * float(row) + side * float(k))
	for cell in cells:
		_waypoint_marker.draw_rect(Rect2(tip + cell * s - Vector2(s, s), Vector2(3.0 * s, 3.0 * s)), dark)
	for cell in cells:
		_waypoint_marker.draw_rect(Rect2(tip + cell * s, Vector2(s, s)), c)


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


func _worst_risk_entry(payload: Dictionary) -> Dictionary:
	var entries_any = payload.get("archetypes", [])
	if not (entries_any is Array):
		return {}
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
	return worst


## One line naming the archetype closest to tipping, so the meter is actionable
## rather than merely ominous.
func _compose_risk_detail(payload: Dictionary) -> String:
	var worst := _worst_risk_entry(payload)
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
				return "%s risk starts at %d" % [label, small_at]
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
