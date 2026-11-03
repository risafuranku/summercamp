extends "res://tools/shot_driver.gd"

## The mushroom granny's night (scripts/enemies/basket_brain.gd, DESIGN.md §5a.4): out
## there coming for you, stopped and looking, at a lamp's edge; you hidden in the office
## while she goes from lodging to lodging; out again; the morning, and the carnage inside
## a lodging she ate in. `--part=tear`: only a tent she tore open, the night and the camp
## through the hole, the day through it, and the canvas sewn up.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/babka_shots.tscn -- --out=<dir> [--part=tear]

var _torn_key := ""


func granny():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "basket":
			return b
	return null


func state() -> Dictionary:
	var g = granny()
	return g.get_debug_snapshot() if g != null else {}


## The warden under the camp's first lit lamp, looking out of its light.
func under_lamp() -> String:
	var bm = _main.get("building_manager")
	var lamps: Array = bm.lit_lamp_positions() if bm != null else []
	if lamps.is_empty():
		return "no lamp lit"
	var at: Vector3 = lamps[0]
	var p: Node3D = _main.get("_player")
	_main.set("debug_camera", null)
	p.global_position = Vector3(at.x + 1.2, p.global_position.y, at.z + 1.2)
	var g = granny()
	if g != null and g.get("_body") != null:
		var b: Vector3 = g._body.global_position
		p.look_at(Vector3(b.x, p.global_position.y, b.z))
	return "under the lamp at %s" % str(at)


## The warden at the door of a lodging she ate in, the lodging opened (the carnage).
func into_carnage() -> String:
	var keys: Array = []
	for k in CoreRoot.get_state().accommodation_states:
		var m = (CoreRoot.get_state().accommodation_states[k] as Dictionary).get("mess", {})
		if m is Dictionary and bool((m as Dictionary).get("carnage", false)):
			keys.append(str(k))
	if keys.is_empty():
		return "no carnage"
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		var o = child.get_meta("grid_origin", null)
		if o is Vector2i and "%d:%d" % [o.x, o.y] == keys[0]:
			var im = _main.get("_interior_manager")
			var t := str(child.get_meta("building_type", ""))
			_main.set("debug_camera", null)
			_main.get("_player").global_position = (child as Node3D).global_position + Vector3(0, 0, 3.0)
			if t.contains("tent"):
				im._on_tent_interact(child)
			elif t.contains("caravan"):
				im._on_caravan_interact(child)
			else:
				im._on_cabin_interact(child)
			return "%s (%s)" % [keys[0], t]
	return "no structure for %s" % keys[0]


## An empty tent of the camp as she leaves one (her carnage, its canvas torn), the warden
## in it.
func into_torn_tent() -> String:
	var st = CoreRoot.get_state()
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		var o = child.get_meta("grid_origin", null)
		if not str(child.get_meta("building_type", "")).contains("tent") or not (o is Vector2i):
			continue
		var key := "%d:%d" % [o.x, o.y]
		if not st.accommodation_states.has(key) or int((st.accommodation_states[key] as Dictionary).get("occupied", 0)) > 0:
			continue
		GuestManager.make_room_carnage(key)
		_torn_key = key
		_torn_node = child
		return reenter_tent()
	return "no empty tent"


var _torn_node: Node3D


func reenter_tent() -> String:
	_main.set("debug_camera", null)
	_main.get("_player").global_position = _torn_node.global_position + Vector3(0, 0, 3.0)
	_main.get("_interior_manager")._on_tent_interact(_torn_node)
	return _torn_key


## A few steps behind it (out of it first: the door puts you at its front), looking at its
## back (where she came through).
func behind_tent() -> String:
	var p: Node3D = _main.get("_player")
	var back := _torn_node.global_transform.basis.z.normalized()
	p.global_position = _torn_node.global_position - back * 3.2 + Vector3(0, 0.1, 0)
	var at := _torn_node.global_position
	p.look_at(Vector3(at.x, p.global_position.y, at.z))
	var hole = _torn_node.find_child("TentTear", true, false)
	return "hole outside: %s" % [hole != null and (hole as Node3D).is_visible_in_tree()]


## The torn canvas sewn up (its task done, as a click on it does).
func sew_tear() -> String:
	for t in GuestManager.get_room_state(_torn_key).get("tasks", []):
		if str(t.get("mess", "")) == "slit":
			var im = _main.get("_interior_manager")
			im._on_room_task_completed(im._tent_interior, im._active_tent_node, str(t.get("id", "")))
			return str(t.get("id", ""))
	return "no slit task"


const TEAR_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["call", "_stop_active_enemy_brain", []],
	["eval", "get_tree().root.get_node('BabkaShots').into_torn_tent()"], ["wait", 3.0],
	["eval", "[_interior_manager._tent_interior._torn, _interior_manager._tent_interior._tear.get_meta('tear_mats')[0].get_shader_parameter('live')]"],
	["shot", "t0_tear_night"],
	["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').behind_tent()"], ["wait", 2.0], ["shot", "t1_outside_night"],
	["eval", "get_tree().root.get_node('BabkaShots').reenter_tent()"], ["wait", 2.5],
	["eval", "time_system.set_time_hours(11.0)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 3.0], ["shot", "t2_tear_day"],
	["eval", "get_tree().root.get_node('BabkaShots').sew_tear()"], ["wait", 2.5],
	["eval", "_interior_manager._tent_interior._torn"], ["shot", "t3_sewn"],
	["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').behind_tent()"], ["wait", 2.0], ["shot", "t4_outside_sewn"],
]


## What she is at and whether the lodging she is at is lit now (window_lights), a line
## each half second while you hide: on as she breaks in, out as she eats.
func window_probe() -> String:
	var s := state()
	var key := str(s.get("target", ""))
	var wl = _main.get_tree().get_first_node_in_group("window_lights")
	if wl == null:
		wl = _main.find_child("WindowLights", true, false)
	var lit = wl.lit_state(key) if wl != null and key != "" else {}
	var forced = (wl.get("_forced") as Dictionary).get(key, "") if wl != null else ""
	return "WINDOW %s %s eaten=%s lit=%s forced=%s" % [str(s.get("phase", "")), key, str(s.get("eaten", 0)), str(not (lit as Dictionary).is_empty()), str(forced)]


## The relatives' mails: scheduled, and delivered to the inbox.
func mail_probe() -> String:
	var sched := 0
	for e in EmailManager._scheduled_mails:
		if str((e.get("mail", {}) as Dictionary).get("subject", "")).begins_with("Have you seen"):
			sched += 1
	var got: Array = []
	for m in EmailManager.inbox:
		if str(m.get("subject", "")).begins_with("Have you seen"):
			got.append("%s / %s / day %s %s / %s" % [str(m.get("from", "")), str(m.get("subject", "")), str(m.get("day", "")), str(m.get("time", "")), str(m.get("body", "")).get_slice("
", 2)])
	return "MAIL scheduled=%d delivered=%d %s" % [sched, got.size(), str(got)]


func _window_steps() -> Array:
	var steps: Array = [
		["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.open_interior()"],
	]
	for i in 90:
		steps.append(["wait", 0.5])
		steps.append(["eval", "get_tree().root.get_node('BabkaShots').window_probe()"])
	steps += [
		["eval", "debug_jump_to(3, 6.6)"], ["wait", 3.0],
		["eval", "get_tree().root.get_node('BabkaShots').mail_probe()"],
		["eval", "debug_jump_to(5, 13.0)"], ["wait", 3.0],
		["eval", "get_tree().root.get_node('BabkaShots').mail_probe()"],
	]
	return steps


## A hitch: a frame far longer than the frames round it (three times the running mean and
## over 50 ms), while watched, with what she was at then. Her firsts in a row, no pictures
## taken (a picture saved is a long frame of its own).
var _watch := false
var _hitches := 0
var _mean_dt := 1.0 / 30.0
## A measured stretch: each frame's length and the scripts' share of it.
var _win := ""
var _win_dt: Array = []
var _win_ms: Array = []


func _process(delta: float) -> void:
	super._process(delta)
	if _watch and delta > 0.05 and delta > _mean_dt * 3.0:
		_hitches += 1
		print("HITCH %d ms (frames round it %d ms) phase=%s" % [int(delta * 1000.0), int(_mean_dt * 1000.0), str(state().get("phase", ""))])
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


## The warden two steps from her, facing her (her spores, her catch).
func meet_granny() -> String:
	var g = granny()
	var p: Node3D = _main.get("_player")
	var b: Vector3 = g._body.global_position
	p.global_position = Vector3(b.x + 2.0, p.global_position.y, b.z)
	p.look_at(Vector3(b.x, p.global_position.y, b.z))
	return "near her"


const HITCH_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
	# The same night without her, then with her, far and near, and hidden while she eats.
	["call", "_stop_active_enemy_brain", []], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('alone')"], ["wait", 5.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('')"],
	["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('alone in the office')"], ["wait", 5.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('')"],
	["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 3.0],
	["eval", "debug_spawn_enemy('basket', 3)"], ["eval", "_enemy_brains.back().set('soon', true)"], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('granny out')"], ["wait", 5.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('')"],
	["eval", "get_tree().root.get_node('BabkaShots').watch(true)"],
	["eval", "get_tree().root.get_node('BabkaShots').granny()._set_phase('look', 3.0)"], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').meet_granny()"], ["wait", 1.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('granny near')"], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('')"],
	["eval", "get_tree().root.get_node('BabkaShots').granny()._start_strike()"], ["wait", 4.0],
	["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 8.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('hidden, she goes for them')"], ["wait", 20.0],
	["eval", "get_tree().root.get_node('BabkaShots').window('')"],
	["eval", "get_tree().root.get_node('BabkaShots').state()"],
	["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 3.0],
	["eval", "get_tree().root.get_node('BabkaShots').into_torn_tent()"], ["wait", 4.0],
	["eval", "get_tree().root.get_node('BabkaShots').watch(false)"],
]


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=tear"):
		_steps = TEAR_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=hitch"):
		_steps = HITCH_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=windows"):
		_steps = _window_steps()
		return
	_steps = [
		["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", "get_tree().root.get_node('BabkaShots').state()"],
		["look_at_enemy"], ["enemy_dist"], ["wait", 0.3], ["shot", "b0_far"],
		["wait", 3.0], ["look_at_enemy"], ["enemy_dist"], ["shot", "b1_coming"],
		["eval", "get_tree().root.get_node('BabkaShots').granny()._set_phase('look', 3.0)"], ["wait", 0.6], ["look_at_enemy"], ["shot", "b2_look"],
		# Under a lamp: she stops at its edge and reaches up for the bulb.
		["eval", "get_tree().root.get_node('BabkaShots').under_lamp()"], ["wait", 6.0],
		["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b3_lamp_edge"],
		["wait", 3.0], ["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b4_lamp_out"],
		# Hidden in the office: she goes for the guests.
		["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 18.0],
		["eval", "[get_tree().root.get_node('BabkaShots').state(), _interior_manager._building_interior._dread._relay_on]"], ["shot", "b5_office"],
		["wait", 30.0], ["eval", "get_tree().root.get_node('BabkaShots').state()"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.5],
		["eval", "get_tree().root.get_node('BabkaShots').state()"], ["look_at_enemy"], ["shot", "b6_out_again"],
		# The morning: who is gone, and what is left in there.
		["eval", "debug_jump_to(3, 6.6)"], ["wait", 3.0], ["shot", "b7_morning"],
		["eval", "EmailManager._scheduled_mails.size()"],
		["eval", "get_tree().root.get_node('BabkaShots').into_carnage()"], ["wait", 2.5], ["shot", "b8_carnage"],
	]
