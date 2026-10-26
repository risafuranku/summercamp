extends CanvasLayer

## Bowling yourself on a free lane of the camp's alley (the user, 21. 10.: "the player can
## play a game of bowling too"; scripts/bowling/bowling_interior.gd starts it when you click
## a lane nobody is on). You stand on the approach behind the foul line, the ball in your
## gloved hand at the bottom of the view.
##   stand   the mouse left and right: where on the approach you stand (a click: there)
##   aim     the mouse left and right: where it goes, the chalk dots on the boards show the
##           way a straight ball would take (a click back: stand again)
##   swing   hold the button, pull back down and flick up, let go: how fast you flick is how
##           fast it rolls, a flick to a side curls it that way on the dry end (the hook)
##   rolling the ball goes its way (BowlingRules, the lane draws it, bowling.gd counts it)
## The pins stand again by themselves on your lane (or the machine sets them), your card is
## on the board over the lane and on the strip at the top; S or the right button on the
## approach leaves the lane. In co-op the other warden sees your balls (bowling.gd's ops).

const RULES := preload("res://core/systems/bowling_rules.gd")
const LAYOUT := preload("res://scripts/bowling/bowling_layout.gd")
const RETRO_UI := preload("res://scripts/ui/retro_ui.gd")
const PROFILES := preload("res://scripts/profiles.gd")
const INTERIOR_LOOK := preload("res://scripts/interior_look.gd")
const LANG := preload("res://scripts/lang.gd")
const HAND_HOLD := "res://assets/textury/hands/bowl_hold.png"
const HAND_RELEASE := "res://assets/textury/hands/bowl_release.png"
const PAPER := "res://assets/textury/bistro/ticket.png"
## Where you may stand (metres either side of the lane's middle), how far you may aim.
const STAND_MAX := 0.42
const AIM_MAX := 0.05
## The flick: below this many screen heights a second up it is no throw; the speeds it gives.
const FLICK_MIN := 0.55
const SPEED := Vector2(5.2, 9.8)
const HOOK_MAX := 1.6
const EYE := 1.5

signal finished

var host: Node
var lane := -1
var phase := ""
var x0 := 0.0
var aim := 0.0
var _aim_from := 0.0
var _pts: Array = []
var _pull := 0.0
var _release_t := -9.0
var _thrown_seq := -1
var _hand_in := 1.0
var _ui: Control
var _dots: Array = []
var _dot_mat: StandardMaterial3D
var _tex: Dictionary = {}
var _t := 0.0
var _final := -1
var _final_t := -9.0


func _ready() -> void:
	layer = 58
	visible = false
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	for p in [HAND_HOLD, HAND_RELEASE, PAPER]:
		_tex[p] = load(p) if ResourceLoader.exists(p) else null
	_dot_mat = StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Red chalk: the boards are pale, a pale mark is lost on them.
	_dot_mat.albedo_color = Color(0.92, 0.22, 0.08, 0.9)
	_dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Over the boards whatever the depth says (a guide for the eye, gone once it is thrown).
	_dot_mat.no_depth_test = true
	_dot_mat.render_priority = 4


func active() -> bool:
	return lane >= 0


func _me() -> String:
	return str(multiplayer.get_unique_id()) if Coop.is_active() else "me"


func _bowling() -> Node:
	return host.get("_bowling")


func _key() -> String:
	return str(host.get("key"))


## Onto lane `li` if nobody is on it; false when it is taken.
func start(li: int) -> bool:
	var name := PROFILES.profile_name()
	if name == "":
		name = tr("Warden")
	if not bool(_bowling().take_lane(_key(), li, _me(), name)):
		return false
	lane = li
	phase = "stand"
	x0 = 0.0
	aim = 0.0
	_thrown_seq = -1
	_final = -1
	_hand_in = 0.0
	visible = true
	_make_dots()
	_place_camera(true)
	return true


func stop() -> void:
	if lane < 0:
		return
	_bowling().leave_lane(_key(), lane, _me())
	lane = -1
	phase = ""
	visible = false
	for d in _dots:
		if is_instance_valid(d):
			(d as Node).queue_free()
	_dots.clear()
	finished.emit()


func _camera() -> Camera3D:
	return host.get("_interior_camera")


func _place_camera(at_once := false) -> void:
	var cam := _camera()
	if cam == null:
		return
	var to := LAYOUT.lane_point(lane, x0, RULES.LANE_LEN + 1.7, EYE)
	cam.position = to if at_once else cam.position.lerp(to, minf(1.0, get_process_delta_time() * 10.0))
	cam.rotation = Vector3(deg_to_rad(-7.0), 0.0, 0.0)


# ── the chalk dots of the way ────────────────────────────────────────────────

func _make_dots() -> void:
	var root: Node3D = host.get("_root")
	for k in 12:
		var d := MeshInstance3D.new()
		d.name = "AimDot"
		# Chalk dashes along the way, big enough for the low screen.
		var q := PlaneMesh.new()
		q.size = Vector2(0.06, 0.2)
		d.mesh = q
		d.material_override = _dot_mat
		d.set_meta("retro_skip", true)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(d)
		_dots.append(d)


func _update_dots() -> void:
	var show := phase in ["stand", "aim", "swing"]
	if not show:
		for d in _dots:
			(d as Node3D).visible = false
		return
	var path: Array = RULES.roll(x0, aim, 7.6, 0.0)["path"]
	var n := path.size()
	for k in _dots.size():
		var d: Node3D = _dots[k]
		var at := int(float(k + 1) / float(_dots.size() + 4) * float(n))
		if at >= n:
			d.visible = false
			continue
		var p: Vector3 = path[at]
		d.visible = absf(p.x) < RULES.LANE_W * 0.5
		d.position = LAYOUT.lane_point(lane, p.x, p.y, 0.066)
		# Turned along the way it goes.
		var nxt: Vector3 = path[mini(at + 1, n - 1)]
		d.rotation.y = atan2(nxt.x - p.x, nxt.y - p.y)
	_dot_mat.albedo_color.a = 0.9 if phase == "aim" else 0.45


# ── the input ────────────────────────────────────────────────────────────────

## An event while you are on the lane; true when it was taken.
func handle(event: InputEvent) -> bool:
	if lane < 0:
		return false
	var vp := get_viewport()
	if event.is_action_pressed("ui_cancel"):
		return false
	if INTERIOR_LOOK.is_exit_event(event, vp) or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		if phase == "aim":
			phase = "stand"
		elif phase == "stand":
			stop()
		return true
	var size := vp.get_visible_rect().size
	if event is InputEventMouseMotion:
		var mx := (event as InputEventMouseMotion).position.x
		match phase:
			"stand":
				x0 = clampf((mx / size.x - 0.5) * 1.1, -STAND_MAX, STAND_MAX)
			"aim":
				aim = clampf(_aim_from + (mx - float(_aim_from_px)) / size.x * 0.14, -AIM_MAX, AIM_MAX)
			"swing":
				_pts.append([_t, (event as InputEventMouseMotion).position])
				_pull = clampf(((event as InputEventMouseMotion).position.y - float(_swing_y)) / size.y, -0.4, 0.6)
		return true
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match phase:
				"stand":
					phase = "aim"
					_aim_from = aim
					_aim_from_px = mb.position.x
				"aim":
					phase = "swing"
					_pts = [[_t, mb.position]]
					_swing_y = mb.position.y
					_pull = 0.0
		elif phase == "swing":
			_throw(size)
		return true
	return event is InputEventKey


var _aim_from_px := 0.0
var _swing_y := 0.0


## Let go: the flick's last tenth of a second is the ball.
func _throw(size: Vector2) -> void:
	var now: Vector2 = _pts.back()[1] if not _pts.is_empty() else Vector2.ZERO
	var then := now
	var dt := 0.0
	for i in range(_pts.size() - 1, -1, -1):
		then = _pts[i][1]
		dt = _t - float(_pts[i][0])
		if dt >= 0.1:
			break
	var v := (now - then) / maxf(dt, 0.016)
	var up := -v.y / size.y
	if up < FLICK_MIN:
		# No flick: the ball stays in the hand.
		phase = "aim"
		_pull = 0.0
		return
	var speed := lerpf(SPEED.x, SPEED.y, clampf((up - 0.8) / 3.2, 0.0, 1.0))
	var hook := clampf(v.x / size.x * 1.8, -HOOK_MAX, HOOK_MAX)
	# (The record is counted as the ball goes: its number read before.)
	var seq0 := int(_bowling().lane(_key(), lane).get("seq", 0))
	var got: Dictionary = _bowling().warden_ball(_key(), lane, x0, aim, speed, hook)
	if got.is_empty():
		phase = "aim"
		return
	_thrown_seq = seq0 + 1
	phase = "rolling"
	_release_t = _t
	_pull = 0.0
	var res: Dictionary = got["res"]
	if (res.get("down", []) as Array).size() == 10:
		_final_t = -9.0


func _process(delta: float) -> void:
	if lane < 0:
		return
	_t += delta
	_place_camera()
	_update_dots()
	var rec: Dictionary = _bowling().lane(_key(), lane)
	# Back on the approach with the next ball once it has gone and the pins stand again.
	if phase == "rolling" and int(rec.get("seq", 0)) >= _thrown_seq and str(rec.get("set", "")) == "" and _t - _release_t > 1.2:
		var view = host.get("_lanes")[lane]
		if str(view.get("_phase")) == "idle":
			phase = "stand"
			_hand_in = 0.0
	# A game done: its total a while on the strip.
	var m: Dictionary = (rec.get("members", [{}]) as Array)[0] if not (rec.get("members", []) as Array).is_empty() else {}
	if int(m.get("last", -1)) >= 0 and int(m.get("last", -1)) != _final and (m.get("balls", []) as Array).is_empty():
		_final = int(m["last"])
		_final_t = _t
	if phase != "rolling":
		_hand_in = minf(1.0, _hand_in + delta * 3.0)
	_ui.queue_redraw()


# ── what is drawn over the view ──────────────────────────────────────────────

func _draw_ui() -> void:
	var size := _ui.get_viewport_rect().size
	var k := maxf(1.0, floorf(minf(size.x / 640.0, size.y / 360.0)))
	# The hand: the ball held low, pulled down in the swing, gone up after the throw.
	var hold: Texture2D = _tex.get(HAND_HOLD)
	var rel: Texture2D = _tex.get(HAND_RELEASE)
	var since := _t - _release_t
	if phase == "rolling" and since < 0.7 and rel != null:
		var hk := size.y * 0.52 / float(rel.get_height())
		var rs := rel.get_size() * hk
		_ui.draw_texture_rect(rel, Rect2(Vector2(size.x * 0.62 - rs.x * 0.5, size.y - rs.y + size.y * 0.25 * since), rs), false)
	elif phase != "rolling" and hold != null:
		var hk2 := size.y * 0.5 / float(hold.get_height())
		var hs := hold.get_size() * hk2
		var drop := (1.0 - _hand_in) * hs.y + maxf(0.0, _pull) * size.y * 0.8
		# Low on the right, the way to the pins clear in the middle.
		_ui.draw_texture_rect(hold, Rect2(Vector2(size.x * 0.7 - hs.x * 0.5, size.y - hs.y * 0.8 + drop), hs), false)
	_draw_card(size, k)


## Your card on a paper strip at the top: the ten frames, the marks, the running total.
func _draw_card(size: Vector2, k: float) -> void:
	var rec: Dictionary = _bowling().lane(_key(), lane)
	var members: Array = rec.get("members", [])
	if members.is_empty():
		return
	var m: Dictionary = members[0]
	var card := RULES.card(m.get("balls", []))
	var box := Vector2(24, 26) * k
	var w := box.x * 10.0 + 54.0 * k
	var r := Rect2(Vector2((size.x - w) * 0.5, 8.0 * k), Vector2(w, box.y + 8.0 * k))
	var paper: Texture2D = _tex.get(PAPER)
	if paper != null:
		_ui.draw_texture_rect(paper, r, false)
	else:
		_ui.draw_rect(r, Color(0.92, 0.88, 0.76))
	var ink := Color(0.16, 0.12, 0.1)
	var red := Color(0.55, 0.1, 0.08)
	var f: Font = RETRO_UI.FONT_TEXT
	var fs := int(8 * k)
	_ui.draw_string(RETRO_UI.FONT_LABEL, r.position + Vector2(4, 12) * k, str(m.get("name", "")).substr(0, 7).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 48 * k, fs, red)
	var frames: Array = card["frames"]
	for i in 10:
		var b := Rect2(r.position + Vector2(50.0 * k + box.x * float(i), 4.0 * k), box)
		var cur := i == int(card["frame"]) and not bool(card["done"])
		_ui.draw_rect(b, Color(1, 0.9, 0.5, 0.35) if cur else Color(1, 1, 1, 0.15))
		_ui.draw_rect(b, ink, false, 1.0)
		var fr: Dictionary = frames[i]
		_ui.draw_string(f, b.position + Vector2(2, 9) * k, " ".join(fr["marks"] as Array), HORIZONTAL_ALIGNMENT_LEFT, box.x - 2 * k, fs, ink)
		if int(fr.get("total", -1)) >= 0:
			_ui.draw_string(f, b.position + Vector2(2, 21) * k, str(int(fr["total"])), HORIZONTAL_ALIGNMENT_LEFT, box.x - 2 * k, fs, red)
	# The last game's total, a while after it ended.
	if _final >= 0 and _t - _final_t < 4.0:
		var s := LANG.f("Game: %d", _final)
		var sw := RETRO_UI.FONT_BIG.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * k)).x
		_ui.draw_string(RETRO_UI.FONT_BIG, Vector2((size.x - sw) * 0.5, r.end.y + 16 * k), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * k), RETRO_UI.C_AMBER_LIGHT)


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## A ball thrown as a flick would: from `stand` at `aim`, `speed`, `hook`.
func debug_throw(stand: float, at: float, speed: float, hook: float) -> void:
	x0 = stand
	aim = at
	var seq0 := int(_bowling().lane(_key(), lane).get("seq", 0))
	if _bowling().warden_ball(_key(), lane, x0, aim, speed, hook).is_empty():
		return
	_thrown_seq = seq0 + 1
	phase = "rolling"
	_release_t = _t
