extends "res://tools/shot_driver.gd"

## The Silent Man's night measured (scripts/enemies/silent_man_brain.gd, DESIGN.md §5a.1):
##   --sim=careful|careless|still|hidden   his night played by a bot (how fair he is)
##   --part=hitch                          his firsts in a row, every frame timed
##   --part=glass                          at the glass of the cabin you hide in, measured
##   --part=ceiling                        on the ceiling over you in the office, looked at and away
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/quiet_shots.tscn -- --sim=careful
## (His catches and the worse ones on pictures: tools/silentman_shots.tscn and the shot
## driver's scenario testsilent.)

const Q := "get_tree().root.get_node('QuietShots')"


func silent():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "silent_man":
			return b
	return null


func state() -> Dictionary:
	var s = silent()
	return s.get_debug_snapshot() if s != null else {}


# ── his night played by a bot ─────────────────────────────────────────────────

## On the same camp each time: "careful" walks a round in the dark, turns round the moment
## he is at its neck (a human's 0.4 s late) and every few seconds looks back over its
## shoulder; "careless" walks the same round and never looks back; "still" stands in the
## dark; "hidden" sits in the office all night. Counted: his holds at your neck, his
## catches (your health given back after each, the night goes on), how often he was
## driven off, and inside, his windows and the times he made himself known; and the
## longest stretch with nothing of him (dead minutes).
var _bot := ""
var _route: Array = []
var _route_i := 0
var _bot_t := 0.0
var _holds := 0
var _catches := 0
var _watches := 0
var _was_hold := false
var _was_seq := false
var _was_watch := false
var _hold_t := 0.0
var _glance_t := 0.0
var _first_at := -1.0
var _last_event := 0.0
var _longest_quiet := 0.0
var _lure0 := 0


func sim_start(bot: String) -> String:
	var s = silent()
	if s == null:
		return "no silent man"
	var p: Node3D = _main.get("_player")
	_main.set("debug_camera", null)
	var head: Node3D = p.get_node_or_null("Head")
	if head != null:
		head.rotation = Vector3.ZERO
	# A round of four corners 12 m apart, every corner in the dark, near where he is.
	_route.clear()
	var c0 := p.global_position
	for ring in [0.0, 14.0, 28.0, 42.0]:
		for k in 8:
			var c: Vector3 = c0 + Vector3(ring, 0, 0).rotated(Vector3.UP, TAU * k / 8.0)
			var corners: Array = [c, c + Vector3(12, 0, 0), c + Vector3(12, 0, 12), c + Vector3(0, 0, 12)]
			var ok := true
			for q in corners:
				if s._lamp_light_at(q) >= 0.2 or s._ground(q) == Vector3.INF:
					ok = false
					break
			if ok:
				_route = corners
				break
		if not _route.is_empty():
			break
	if _route.is_empty():
		return "no dark round"
	_bot = bot
	_bot_t = 0.0
	if bot == "hidden":
		_main.get("_interior_manager")._building_interior.open_interior()
	else:
		p.global_position = Vector3(_route[0].x, p.global_position.y, _route[0].z)
	_lure0 = int(state().get("lure", 0))
	return "SIM %s start: round %s, hour %.2f" % [bot, str(_route[0].snapped(Vector3.ONE)), float(_main.get("_time_of_day_hours"))]


func _event() -> void:
	if _first_at < 0.0:
		_first_at = _bot_t
	_longest_quiet = maxf(_longest_quiet, _bot_t - _last_event)
	_last_event = _bot_t


func sim_report() -> String:
	var s := state()
	_longest_quiet = maxf(_longest_quiet, _bot_t - _last_event)
	var out := "SIM %s after %.0f s: holds=%d catches=%d hits=%s driven_off=%s windows=%d inside_times=%d first=%.0fs longest_quiet=%.0fs hour %.2f" % [
		_bot, _bot_t, _holds, _catches, str(s.get("hits", "?")), str(s.get("driven_off", "?")), _watches,
		int(s.get("lure", 0)) - _lure0, _first_at, _longest_quiet, float(_main.get("_time_of_day_hours"))]
	_bot = ""
	return out


func _bot_tick(dt: float) -> void:
	var s = silent()
	var p: Node3D = _main.get("_player")
	if s == null or p == null or s.get("_body") == null:
		return
	_bot_t += dt
	var hold: bool = float(s.get("_neck_until")) > 0.0
	var seq: bool = not (s.get("_seq") as Dictionary).is_empty()
	var watching: bool = int(s.get("_watch_win")) >= 0
	if hold and not _was_hold:
		_holds += 1
		_event()
	if seq and not _was_seq:
		_catches += 1
		_event()
	if watching and not _was_watch:
		_watches += 1
		_event()
	_was_hold = hold
	_was_seq = seq
	_was_watch = watching
	if int(_main.get("_player_health")) < 60:
		_main.call("_set_player_health", 100, false)
	if _bot == "hidden" or _bot == "still" or seq:
		return
	var me := p.global_position
	var him: Vector3 = (s.get("_body") as Node3D).global_position
	if _bot == "careful":
		if hold:
			_hold_t += dt
			if _hold_t > 0.4:
				p.look_at(Vector3(him.x, me.y, him.z))
				return
		else:
			_hold_t = 0.0
		_glance_t += dt
		if _glance_t > 6.0:
			if _glance_t > 6.6:
				_glance_t = 0.0
			var back := me - (-p.global_transform.basis.z) * 2.0
			p.look_at(Vector3(back.x, me.y, back.z))
			return
	var target: Vector3 = _route[_route_i]
	var to := Vector3(target.x - me.x, 0.0, target.z - me.z)
	if to.length() < 1.0:
		_route_i = (_route_i + 1) % _route.size()
		return
	p.look_at(Vector3(target.x, me.y, target.z))
	p.global_position = me + to.normalized() * 3.9 * dt


static func sim_steps(bot: String) -> Array:
	return [
		["wait_menu"], ["call", "_on_menu_test_night", ["silent_man"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", Q + ".sim_start('%s')" % bot],
		# 3.5 game hours at the clock's 1.25 minutes a second (the clock does not follow
		# Engine.time_scale: no speeding up).
		["wait", 168.0],
		["eval", Q + ".sim_report()"],
	]


# ── his firsts, timed ─────────────────────────────────────────────────────────

## A hitch: a frame far longer than the frames round it (three times the running mean and
## over 50 ms), while watched. No pictures taken (a saved picture is a long frame itself).
var _watch := false
var _hitches := 0
var _mean_dt := 1.0 / 30.0
var _win := ""
var _win_dt: Array = []
var _win_ms: Array = []


func _process(delta: float) -> void:
	super._process(delta)
	if _bot != "":
		_bot_tick(delta)
	if _watch and delta > 0.05 and delta > _mean_dt * 3.0:
		_hitches += 1
		print("HITCH %d ms (frames round it %d ms) %s" % [int(delta * 1000.0), int(_mean_dt * 1000.0), str(state())])
	_mean_dt = lerpf(_mean_dt, minf(delta, 0.25), 0.1)
	if _win != "":
		_win_dt.append(delta)
		_win_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)


func watch(on: bool) -> String:
	_watch = on
	return "HITCHES %d" % _hitches


## Ends the stretch being measured (its mean frame, the scripts' mean share, its worst
## frame) and starts one called `label` ("" none).
func window(label: String) -> String:
	var out := ""
	if _win != "" and not _win_dt.is_empty():
		var n := float(_win_dt.size())
		var dt := 0.0
		var ms := 0.0
		var worst := 0.0
		for i in _win_dt.size():
			dt += float(_win_dt[i])
			ms += float(_win_ms[i])
			worst = maxf(worst, float(_win_dt[i]))
		out = "PERF %s frames=%d fps=%.0f scripts=%.1fms worst=%dms" % [_win, int(n), n / dt, ms / n, int(worst * 1000.0)]
	_win = label
	_win_dt.clear()
	_win_ms.clear()
	return out


## Out of any lurk or lesson, free to act at once.
func _ready_now(s) -> void:
	s.set("_lurking", false)
	s.set("_staring", false)
	s.set("_resume_at", 0.0)
	s.set("_reveal_t", -1.0)
	s.set("_vanish_at", -1.0)
	(s.get("_body") as Node3D).visible = true


## At your neck, the hold on: his hands, his breath, the frame stopping for a beat.
func neck_now() -> String:
	var s = silent()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	_ready_now(s)
	var back := cam.global_transform.basis.z.slide(Vector3.UP).normalized()
	(s.get("_body") as Node3D).global_position = p.global_position + back * 1.6
	s.set("_neck_from", p.global_position)
	s.set("_neck_until", float(s.get("_elapsed")) + 2.5)
	s.call("_start_hold")
	return "hold"


func catch_now(kind: String) -> String:
	var s = silent()
	_ready_now(s)
	s.set("_neck_until", -1.0)
	s.call("_end_hold")
	s.call("_start_catch", kind)
	return "catch " + kind


## In front of you, in your torch: he comes apart.
func lit_now() -> String:
	var s = silent()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	_ready_now(s)
	var fwd := (-cam.global_transform.basis.z).slide(Vector3.UP).normalized()
	(s.get("_body") as Node3D).global_position = p.global_position + fwd * 5.0
	s.call("_driven_off")
	return "lit"


## Out beyond a window of the room you are in.
func watch_now() -> String:
	var s = silent()
	return "watch %s" % str(s.call("_start_watch"))


const HITCH_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["silent_man"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
	# The same night without him, then with him; then his firsts, one after another.
	["call", "_stop_active_enemy_brain", []], ["wait", 3.0],
	["eval", Q + ".window('alone')"], ["wait", 5.0], ["eval", Q + ".window('')"],
	["eval", "debug_spawn_enemy('silent_man', 3)"], ["wait", 3.0],
	["eval", Q + ".window('silent man out')"], ["wait", 5.0], ["eval", Q + ".window('')"],
	["eval", Q + ".watch(true)"],
	["eval", Q + ".neck_now()"], ["wait", 2.0],
	["eval", Q + ".catch_now('ear')"], ["wait", 2.5],
	["eval", Q + ".catch_now('above')"], ["wait", 2.5],
	["eval", Q + ".lit_now()"], ["wait", 2.5],
	["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 2.0],
	["eval", Q + ".window('inside')"],
	["eval", Q + ".watch_now()"], ["wait", 5.0],
	["eval", Q + ".window('')"],
	["eval", Q + ".state()"],
	["eval", Q + ".watch(false)"],
]


# ── at the glass of a cabin you hide in ───────────────────────────────────────

var _cabin: Node3D


## Into a cabin of the camp, as a click on its door does.
func into_cabin() -> String:
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		if str(child.get_meta("building_type", "")).contains("cabin"):
			_cabin = child
			_main.set("debug_camera", null)
			_main.get("_player").global_position = child.global_position + Vector3(0, 0, 3.0)
			_main.get("_interior_manager")._on_cabin_interact(child)
			return str(child.get_meta("building_type", ""))
	return "no cabin"


## You looking at the cabin's first window, and him outside it (his tap on the glass).
func glass_now() -> String:
	var s = silent()
	var im = _main.get("_interior_manager")
	var cab = im.get("_cabin_interior")
	var pts: Array = cab._portals_now()
	if pts.is_empty():
		return "no window"
	var at: Vector3 = cab._cabin_root.global_transform * (pts[0]["frame"] as Transform3D).origin
	var cam: Camera3D = cab._interior_camera
	cam.look_at(at)
	var want: Vector3 = (cab.outside_windows()[0]["pos"] as Vector3)
	for i in 8:
		if s._at_glass(im):
			var b: Vector3 = (s.get("_body") as Node3D).global_position
			if Vector2(b.x - want.x, b.z - want.z).length() < 1.0:
				return "at the first window"
		s._end_watch()
	return "at another window"


## How he stands there: his feet against the ground, his glasses against the window.
func glass_probe() -> String:
	var s = silent()
	var body: Node3D = s.get("_body")
	var g: Vector3 = s._ground(body.global_position)
	var cab = _main.get("_interior_manager").get("_cabin_interior")
	var w: Dictionary = cab.outside_windows()[0]
	var eyes = s.get("_eyes")
	var glasses := body.global_position.y + float(eyes.get("height")) if eyes != null else -1.0
	var pt: Dictionary = cab._portals_now()[0]
	var pcam: Camera3D = pt["cam"]
	return "GLASS feet %.2f m off the ground, glasses %.2f m, window middle %.2f m (both over the ground), shown %s in tree %s, window camera %.2f m off him, its current %s" % [
		body.global_position.y - g.y, glasses - g.y, (w["pos"] as Vector3).y - g.y, str(body.visible), str(body.is_visible_in_tree()),
		pcam.global_position.distance_to(body.global_position + Vector3(0, 1.6, 0)), str(pcam.current)]


const GLASS_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["silent_man"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["eval", Q + ".into_cabin()"], ["wait", 3.0],
	["eval", Q + ".glass_now()"], ["wait", 0.6], ["shot", "g1_glass_inside"],
	["eval", Q + ".glass_probe()"],
]



# ── on the ceiling of the room you are in ─────────────────────────────────────

func ceiling_now() -> String:
	var s = silent()
	return "on the ceiling %s" % str(s.call("_start_ceiling"))


func ceiling_probe() -> String:
	var s = silent()
	var c = s.get("_ceil")
	if c == null or not is_instance_valid(c):
		return "CEIL gone"
	var cam: Camera3D = (c as Node3D).get_viewport().get_camera_3d()
	return "CEIL there, looked at %s, %.2f m over your eyes, %.2f m in front" % [str(s.get("_ceil_seen")),
		(c as Node3D).global_position.y - cam.global_position.y,
		Vector2((c as Node3D).global_position.x - cam.global_position.x, (c as Node3D).global_position.z - cam.global_position.z).length()]


const BI := "_interior_manager._building_interior"
const CEILING_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["silent_man"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["eval", BI + ".open_interior()"], ["wait", 3.0],
	["eval", Q + ".ceiling_now()"], ["wait", 0.4], ["shot", "c0_level"], ["eval", Q + ".ceiling_probe()"],
	# You look up: he is there. You look down again: he is not.
	["eval", BI + ".set('_idle_cam_base_rot', Vector3(0.95, 0.0, 0.0))"], ["wait", 0.6], ["shot", "c1_up"], ["eval", Q + ".ceiling_probe()"],
	["eval", BI + ".set('_idle_cam_base_rot', Vector3(-0.15, 0.0, 0.0))"], ["wait", 0.6], ["eval", Q + ".ceiling_probe()"],
	["eval", BI + ".set('_idle_cam_base_rot', Vector3(0.95, 0.0, 0.0))"], ["wait", 0.6], ["shot", "c2_up_again"], ["eval", Q + ".ceiling_probe()"],
]

func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sim="):
			_steps = sim_steps(a.get_slice("=", 1))
			return
	if OS.get_cmdline_user_args().has("--part=hitch"):
		_steps = HITCH_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=ceiling"):
		_steps = CEILING_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=glass"):
		_steps = GLASS_STEPS.duplicate(true)
		return
	_steps = sim_steps("careful")
