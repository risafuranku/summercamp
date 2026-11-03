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


## An empty lodging of `kind` ("tent", "cabin", "caravan") as she leaves one (her carnage:
## a tent's canvas torn, a cabin's or caravan's window smashed), the warden in it.
func into_carnage_of(kind: String) -> String:
	var st = CoreRoot.get_state()
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		var o = child.get_meta("grid_origin", null)
		if not str(child.get_meta("building_type", "")).contains(kind) or not (o is Vector2i):
			continue
		var key := "%d:%d" % [o.x, o.y]
		if not st.accommodation_states.has(key) or int((st.accommodation_states[key] as Dictionary).get("occupied", 0)) > 0:
			continue
		GuestManager.make_room_carnage(key)
		_torn_key = key
		_torn_node = child
		_torn_kind = kind
		return reenter_tent()
	return "no empty %s" % kind


func into_torn_tent() -> String:
	return into_carnage_of("tent")


var _torn_node: Node3D
var _torn_kind := "tent"


func reenter_tent() -> String:
	_main.set("debug_camera", null)
	_main.get("_player").global_position = _torn_node.global_position + Vector3(0, 0, 3.0)
	var im = _main.get("_interior_manager")
	match _torn_kind:
		"cabin":
			im._on_cabin_interact(_torn_node)
		"caravan":
			im._on_caravan_interact(_torn_node)
		_:
			im._on_tent_interact(_torn_node)
	return _torn_key


## Its wall's carnage task done (`mess`: "slit" sewn up, "smashed" glazed), as a click does.
func finish_wall(mess: String) -> String:
	var im = _main.get("_interior_manager")
	var room = {"tent": [im._tent_interior, im._active_tent_node], "cabin": [im._cabin_interior, im._active_cabin_node],
		"caravan": [im._caravan_interior, im._active_caravan_node]}[_torn_kind]
	for t in GuestManager.get_room_state(_torn_key).get("tasks", []):
		if str(t.get("mess", "")) == mess:
			im._on_room_task_completed(room[0], room[1], str(t.get("id", "")))
			return str(t.get("id", ""))
	return "no %s task" % mess


func close_room() -> String:
	var im = _main.get("_interior_manager")
	match _torn_kind:
		"cabin":
			im._cabin_interior.close_cabin()
		"caravan":
			im._caravan_interior.close_caravan()
		_:
			im._tent_interior.close_tent()
	return _torn_kind


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
	["eval", "get_tree().root.get_node('BabkaShots').close_room()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').behind_tent()"], ["wait", 2.0], ["shot", "t1_outside_night"],
	["eval", "get_tree().root.get_node('BabkaShots').reenter_tent()"], ["wait", 2.5],
	["eval", "time_system.set_time_hours(11.0)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 3.0], ["shot", "t2_tear_day"],
	["eval", "get_tree().root.get_node('BabkaShots').sew_tear()"], ["wait", 2.5],
	["eval", "_interior_manager._tent_interior._torn"], ["shot", "t3_sewn"],
	["eval", "get_tree().root.get_node('BabkaShots').close_room()"], ["wait", 2.0],
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
	if _bot != "":
		_bot_tick(delta)
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


## Every granny of the night out whatever the hour (a test night's is; one the night rolls
## itself keeps to the small hours), and what brains there are.
func keep_out() -> String:
	var out: Array = []
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id"):
			if str(b.get_enemy_id()) == "basket":
				b.set("soon", true)
			out.append("%s:%s" % [str(b.get_enemy_id()), str(b.get("_phase"))])
	return "BRAINS %s" % str(out)


## Her night played by a bot (how fair she is: DESIGN §5a.4, the loop's B10), on the
## same camp each time: "careful" walks round the lodgings, freezes the moment her back
## cracks (a human's 0.3 s late), runs from her when she is close; "careless" walks the
## same round and never stops; "hidden" sits in the office all night. Counted: her
## catches (your health given back after each, the night goes on), the guests she ate,
## the lamps she put out, the guests she was cut off from.
var _bot := ""
var _route: Array = []
var _route_i := 0
var _catches := 0
var _was_strike := false
var _look_for := 0.0
var _bot_t := 0.0


func sim_start(bot: String) -> String:
	var g = granny()
	if g == null:
		return "no granny"
	g.set("soon", true)
	_route.clear()
	for l in g._lodgings():
		_route.append(l["at"])
	if _route.is_empty():
		return "no lodgings"
	_bot = bot
	_catches = 0
	_bot_t = 0.0
	# A camp worth eating (the test camp lets in three parties): four more of other kinds.
	for party in [["Horak family", "family", 3], ["Pepa", "drunk", 2], ["Denisa", "cheap_chick", 2], ["Bobr", "tramp", 1]]:
		GuestManager.debug_check_in_party(str(party[0]), str(party[1]), int(party[2]), 3)
	_route.clear()
	for l in g._lodgings():
		_route.append(l["at"])
	if bot == "hidden":
		_main.get("_interior_manager")._building_interior.open_interior()
	else:
		_main.set("debug_camera", null)
		var p: Node3D = _main.get("_player")
		p.global_position = Vector3(_route[0].x, p.global_position.y, _route[0].z)
	return "SIM %s start: %d lodgings, %d guests in them, hour %.2f" % [bot, _route.size(), _guests_in(g), float(_main.get("_time_of_day_hours"))]


func _guests_in(g) -> int:
	var n := 0
	for l in g._lodgings():
		n += (g._guests_in(str(l["key"])) as Array).size()
	return n


## Half a minute in: the camp as the bot found it (the parties let in have gone to bed).
func sim_mid() -> String:
	var g = granny()
	_route.clear()
	for l in g._lodgings():
		_route.append(l["at"])
	return "SIM %s mid: %d lodgings, %d guests, catches=%d, hour %.2f" % [_bot, _route.size(), _guests_in(g), _catches, float(_main.get("_time_of_day_hours"))]


func sim_report() -> String:
	var g = granny()
	var s: Dictionary = g.get_debug_snapshot() if g != null else {}
	var out := "SIM %s after %.0f s: catches=%d eaten=%s lamps_out=%s cut=%s stage=%s guests_left=%d hour %.2f" % [_bot, _bot_t, _catches,
		str(s.get("eaten", "?")), str(s.get("bulbs", "?")), str(s.get("cut", "?")), str(s.get("stage", "?")), _guests_in(g) if g != null else -1,
		float(_main.get("_time_of_day_hours"))]
	_bot = ""
	return out


func _bot_tick(dt: float) -> void:
	var g = granny()
	var p: Node3D = _main.get("_player")
	if g == null or p == null or g.get("_body") == null:
		return
	_bot_t += dt
	var striking: bool = float(g.get("_strike_t")) >= 0.0
	if striking and not _was_strike:
		_catches += 1
	_was_strike = striking
	if int(_main.get("_player_health")) < 60:
		_main.call("_set_player_health", 100, false)
	if _bot == "hidden" or striking:
		return
	var phase := str(g.get("_phase"))
	var her: Vector3 = g._body.global_position
	var me := p.global_position
	var away := Vector3(me.x - her.x, 0.0, me.z - her.z)
	var speed := 3.9
	if _bot == "careful":
		_look_for = _look_for + dt if phase in ["look", "stare"] else 0.0
		if _look_for > 0.3:
			return
		if away.length() < 8.0:
			speed = 5.2
			p.global_position = me + away.normalized() * speed * dt
			return
	var target: Vector3 = _route[_route_i]
	var to := Vector3(target.x - me.x, 0.0, target.z - me.z)
	if to.length() < 1.2:
		_route_i = (_route_i + 1) % _route.size()
		return
	p.global_position = me + to.normalized() * speed * dt


static func sim_steps(bot: String) -> Array:
	return [
		["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", "get_tree().root.get_node('BabkaShots').sim_start('%s')" % bot],
		# Her whole night, 3.5 game hours at the clock's 1.25 minutes a second (the clock
		# does not follow Engine.time_scale, she would: no speeding up).
		["wait", 30.0], ["eval", "get_tree().root.get_node('BabkaShots').sim_mid()"],
		["wait", 138.0],
		["eval", "get_tree().root.get_node('BabkaShots').sim_report()"],
	]


## Her loops as they are: each one's stream, whether it loops and whether it plays.
func loops() -> String:
	var g = granny()
	var out: Array = []
	for n in ["_hum", "_breath", "_spores"]:
		var p = g.get(n)
		if p != null and p.stream != null:
			out.append("%s %s loop=%s playing=%s" % [n, p.stream.resource_path.get_file(), str(p.stream.get("loop")), str(p.playing)])
	for k in ["eat_a", "eat_b", "pry"]:
		var st = g._streams.get(g.SFX[k])
		out.append("%s %s loop=%s" % [k, st.resource_path.get_file() if st != null else "-", str(st.get("loop")) if st != null else "-"])
	return "LOOPS " + ", ".join(out)


## Her reach for the lamp you stand under (you stay in its light, looking at her): she at
## the edge of its light, her arm going up to the bulb.
func reach_now() -> String:
	var g = granny()
	var p: Node3D = _main.get("_player")
	var foot: Vector3 = g._lamp_for(p.global_position)
	if foot == Vector3.INF:
		return "no lamp"
	var edge: Vector3 = g._edge_of(foot)
	g._body.global_position = edge
	g._start_reach(foot)
	p.look_at(Vector3(edge.x, p.global_position.y, edge.z))
	return "reach from %s to the lamp at %s" % [str(edge), str(foot)]


## How she looks: hunting, straightened, her arm going up to a lamp (a picture every 0.8 s
## of the reach), and her worst face at the catch.
const LOOK_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.5],
	["look_at_enemy"], ["enemy_dist"], ["wait", 0.3], ["shot", "l0_hunt"],
	["eval", "get_tree().root.get_node('BabkaShots').loops()"],
	["eval", "get_tree().root.get_node('BabkaShots').granny()._set_phase('look', 3.0)"], ["wait", 0.6], ["look_at_enemy"], ["shot", "l1_up"],
	["eval", "get_tree().root.get_node('BabkaShots').keep_out()"],
	["eval", "get_tree().root.get_node('BabkaShots').under_lamp()"], ["wait", 1.0],
	["eval", "get_tree().root.get_node('BabkaShots').reach_now()"], ["wait", 0.6], ["shot", "l2_reach_a"],
	["wait", 0.8], ["shot", "l3_reach_b"], ["wait", 0.8], ["shot", "l4_reach_c"], ["wait", 0.8], ["shot", "l5_reach_d"],
	["eval", "get_tree().root.get_node('BabkaShots').state()"],
	["eval", "get_tree().root.get_node('BabkaShots').keep_out()"],
	["eval", "get_tree().root.get_node('BabkaShots').granny()._set_stage(2)"],
	["eval", "get_tree().root.get_node('BabkaShots').meet_granny()"], ["wait", 0.5],
	["eval", "get_tree().root.get_node('BabkaShots').granny()._start_strike()"], ["wait", 1.2], ["shot", "l6_strike_s2"],
	["wait", 0.7], ["shot", "l7_strike_s2b"],
]


## A caravan for the smashed window (the test camp has none): one built through the real
## builder north of the gate, beside the far tents.
func build_caravan() -> String:
	var g: Vector2i = _main.get("world_generator").gate_tile()
	EventBus.RequestBuild.emit("caravan_1", Vector2i(g.x - 2, 10), 0)
	return "caravan asked for at %s" % str(Vector2i(g.x - 2, 10))


## The room's smashed window now: its shards shown, its pane without the glass's tint.
func smash_probe() -> String:
	var im = _main.get("_interior_manager")
	var quad: MeshInstance3D = null
	if _torn_kind == "caravan":
		var c = im._caravan_interior
		quad = c._windows[c.SMASH_WINDOW].quad
	else:
		for pt in im._cabin_interior._portals_now():
			if str((pt["quad"] as Node).name) == "View_backGlass":
				quad = pt["quad"]
	if quad == null:
		return "SMASH no window"
	var shards = quad.get_meta("smashed_shards") if quad.has_meta("smashed_shards") else null
	var m := quad.material_override as ShaderMaterial
	var n := 0
	for c in quad.get_parent().get_children():
		if str(c.name).begins_with("SmashedShards"):
			n += 1
	return "SMASH %s shards=%s (%d made) tint=%s" % [_torn_kind, str(shards != null and is_instance_valid(shards) and (shards as Node3D).visible), n, str(m.get_shader_parameter("tint")) if m != null else "?"]


## A cabin and a caravan she smashed a window of: inside, from the camp behind, glazed.
const SMASH_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["call", "_stop_active_enemy_brain", []],
	["eval", "get_tree().root.get_node('BabkaShots').into_carnage_of('cabin')"], ["wait", 3.5], ["shot", "w0_cabin_night"],
	["eval", "get_tree().root.get_node('BabkaShots').smash_probe()"],
	["eval", "get_tree().root.get_node('BabkaShots').close_room()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').behind_tent()"], ["wait", 1.5], ["shot", "w1_cabin_outside"],
	["eval", "get_tree().root.get_node('BabkaShots').reenter_tent()"], ["wait", 2.5],
	["eval", "get_tree().root.get_node('BabkaShots').finish_wall('smashed')"], ["wait", 2.5], ["shot", "w2_cabin_glazed"],
	["eval", "get_tree().root.get_node('BabkaShots').close_room()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').build_caravan()"], ["wait", 2.0],
	["eval", "get_tree().root.get_node('BabkaShots').into_carnage_of('caravan')"], ["wait", 3.5], ["shot", "w3_caravan_night"],
	["eval", "get_tree().root.get_node('BabkaShots').smash_probe()"],
	["eval", "get_tree().root.get_node('BabkaShots').finish_wall('smashed')"], ["wait", 2.5],
	["eval", "get_tree().root.get_node('BabkaShots').smash_probe()"], ["shot", "w4_caravan_glazed"],
]


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=tear"):
		_steps = TEAR_STEPS.duplicate(true)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sim="):
			_steps = sim_steps(a.get_slice("=", 1))
			return
	if OS.get_cmdline_user_args().has("--part=smash"):
		_steps = SMASH_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=look"):
		_steps = LOOK_STEPS.duplicate(true)
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
