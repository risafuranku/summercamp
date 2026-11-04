extends "res://tools/shot_driver.gd"

## Through the doors (the user 4. 11.: "smooth, at every building"; scripts/ui/door_through.gd):
## each kind of building with a room is put up, the warden stands before its door and goes
## in and out on foot (a station or a side room first left with a second Esc); a tent is
## looked at from outside after, unzipped and zipped. Prints the frame times of each walk
## against standing still ("DVERE ... median / p95 / spikes", each spike with what was going
## on), with --out=DIR the pictures (and the door's view of the camp on the way out).
## --part=<type>[,<type>...] some of them ("cabin_1", "pub", ...).
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/dvere_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('DvereCheck')"
## (The tiers above the first come by upgrading: the harness builds the first.)
const ALL := ["cabin_1", "caravan_1", "tent_1", "toilet_block", "shower_block", "power_generator", "pub", "restaurant", "vecerka", "staffroom", "bowling"]

var _worst := 0.0
var _deltas: Array = []
var _last_ms := 0
var _watch := false
var _structure: Node3D


func _process(delta: float) -> void:
	super._process(delta)
	if _watch:
		_worst = maxf(_worst, delta)
		_deltas.append(delta)
		if delta > 0.045 and _main != null:
			var im = _main.get("_interior_manager")
			var th = im.get("through") if im != null else null
			print("DVERE spike %d ms frame=%d state=%s open=%s process=%.1f ms physics=%.1f ms objects=%d draws=%d" % [int(delta * 1000.0), _deltas.size(), th.get("_state") if th != null else "?", _main.call("_is_any_interior_open"), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func stand_before(kind: String) -> String:
	var bm = _main.get("building_manager")
	var s: Node3D = null
	for c in bm.get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")) == kind:
			s = c
	_structure = s
	if s == null:
		return "no " + kind
	var door_anim = load("res://scripts/attractions/door_anim.gd")
	var way: Dictionary = door_anim.entry_points(s, 0)
	var out: Vector3 = (way["outside"] - way["inside"]).normalized()
	var p: Node3D = _main.get("_player")
	var at: Vector3 = way["outside"] + out * 1.8
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.rotation.y = atan2(out.x, out.z)
	return "stands before %s at %s" % [kind, p.global_position]


func interact() -> String:
	_worst = 0.0
	_watch = true
	var im = _main.get("_interior_manager")
	im.call("handle_structure_interact", _structure)
	return "interact"


## Where the door walk's eye is in the door's frame, and the pane on the way out.
func probe(label: String) -> String:
	var th = _main.get("_interior_manager").get("through")
	var cam: Camera3D = th.get("_room_cam")
	var fg: Transform3D = th.get("_frame_g")
	var pane = th.get("_out_pane")
	var leaves := []
	var spec: Dictionary = th.get("_spec")
	for n in spec.get("leaf", []):
		if is_instance_valid(n):
			leaves.append("%s vis=%s at=%s" % [(n as Node).get_path(), (n as Node3D).visible, fg.affine_inverse() * (n as Node3D).global_position])
	var da = load("res://scripts/attractions/door_anim.gd")
	var doors := []
	var way: Dictionary = th.get("_way")
	for k in ["door", "pair"]:
		var d = way.get(k, null)
		if d != null and is_instance_valid(d):
			var rec: Dictionary = da._doors.get(d.get_instance_id(), {})
			doors.append("%s angle=%s until=%.2f clock=%.2f" % [d.name, rec.get("angle", "?"), float(rec.get("open_until", -1.0)), da._clock])
	var vcam: Camera3D = th.get("_view").get("cam")
	if _structure != null:
		var fdc := _structure.find_child("FrontDoor", true, false)
		var hidden: Array = th.get("_view").get("_hidden")
		doors.append("camp_frontdoor=%s layers=%s hidden_n=%d mask=%s vpworld_is_camp=%s" % [fdc.get_path() if fdc != null else "none", (fdc as GeometryInstance3D).layers if fdc is GeometryInstance3D else -1, hidden.size(), vcam.cull_mask, (th.get("_view").get("vp") as SubViewport).world_3d == _structure.get_world_3d()])
	if _out_dir != "":
		var vimg: Image = (th.get("_view").get("vp") as SubViewport).get_texture().get_image()
		if vimg != null:
			vimg.save_png(_out_dir + "/view_" + label + ".png")
	if way.has("sill"):
		var tr: Transform3D = th.get("_to_room")
		doors.append("sill_in_frame=%s normal_in_frame=%s" % [fg.affine_inverse() * (tr * (way["sill"] as Vector3)), fg.basis.inverse() * (tr.basis * (way["normal"] as Vector3))])
	var line := "DVERE probe %s: state=%s eye=%s pane=%s vis=%s leaves=%s doors=%s viewcam=%s" % [label, th.get("_state"), (fg.affine_inverse() * cam.global_position) if cam != null else Vector3.INF, (fg.affine_inverse() * pane.global_position) if pane != null else Vector3.INF, pane.visible if pane != null else false, leaves, doors, vcam.global_position]
	print(line)
	return line


func st(label: String) -> String:
	var im = _main.get("_interior_manager")
	var th = im.get("through")
	var fx = im.get("_door_fx")
	var line := "DVERE st %s: through=%s open=%s stepping=%s fx=%s since_walked=%d" % [label, th.get("_state"), _main.call("_is_any_interior_open"), im.stepping_out(), fx.is_playing() if fx != null else false, Time.get_ticks_msec() - int(im.get("_walked_in_ms"))]
	print(line)
	return line


## A station or a side room open: Esc once more takes you to where the way out is.
func esc_again() -> String:
	var th = _main.get("_interior_manager").get("through")
	if str(th.get("_state")) == "" and bool(_main.call("_is_any_interior_open")):
		for pressed in [true, false]:
			var e := InputEventKey.new()
			e.keycode = KEY_ESCAPE
			e.physical_keycode = KEY_ESCAPE
			e.pressed = pressed
			Input.parse_input_event(e)
		return "esc again"
	return "no need"


## Out in front of the door again, looking at it (an unzipped tent: in through it).
func look_back(kind: String) -> String:
	var line := stand_before(kind)
	var p: Node3D = _main.get("_player")
	var door_anim = load("res://scripts/attractions/door_anim.gd")
	var way: Dictionary = door_anim.entry_points(_structure, 0)
	var out: Vector3 = (way["outside"] - way["inside"]).normalized()
	var at: Vector3 = way["outside"] + out * (0.9 if kind.begins_with("tent") else 1.6)
	p.global_position = Vector3(at.x, p.global_position.y, at.z)
	p.rotation.y = atan2(out.x, out.z)
	if kind.begins_with("tent"):
		p.call("set_stance", 1)
		p.set("_pitch", deg_to_rad(-24.0))
		p.set("_pitch_target", deg_to_rad(-24.0))
	var im = _main.get("_interior_manager")
	var key: String = im.call("_room_key_for", _structure)
	line += " door_open=%s" % [im.call("tent_door_open", key) if im.has_method("tent_door_open") else "?"]
	print("DVERE look_back " + line)
	return line


func zip(open: bool) -> String:
	var im = _main.get("_interior_manager")
	var key: String = im.call("_room_key_for", _structure)
	im.call("set_tent_door", key, open)
	return "tent %s open=%s" % [key, open]


func toggle(path: String, on: bool) -> String:
	var n := _main.get_node_or_null(path)
	if n == null:
		return "no " + path
	n.set_process(on)
	return "%s process=%s" % [path, on]


func watch() -> String:
	_worst = 0.0
	_deltas.clear()
	_watch = true
	return "watching"


func report(kind: String, what: String) -> String:
	var open: bool = _main.call("_is_any_interior_open")
	var d := _deltas.duplicate()
	d.sort()
	var med := float(d[d.size() / 2]) if not d.is_empty() else 0.0
	var p95 := float(d[int(d.size() * 0.95)]) if not d.is_empty() else 0.0
	var spikes := 0
	for x in _deltas:
		if float(x) > med * 2.5 and float(x) > 0.04:
			spikes += 1
	var line := "DVERE %s %s: open=%s worst_frame=%d ms median=%d p95=%d spikes=%d frames=%d" % [kind, what, open, int(_worst * 1000.0), int(med * 1000.0), int(p95 * 1000.0), spikes, _deltas.size()]
	print(line)
	_worst = 0.0
	_deltas.clear()
	return line


func _ready() -> void:
	super._ready()
	var kinds: Array = ALL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			kinds = a.trim_prefix("--part=").split(",")
	var steps: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.4],
		["key", "Escape"], ["wait", 3.2],
		["money", 200000], ["clear", 6, 10, 20, 14],
	]
	var x := 8
	for k in kinds:
		steps.append_array([["build", k, x, 14, 0], ["prep_all"]])
		x += 6
	steps.append(["wait", 1.0])
	steps.append_array([["eval", C + ".stand_before('%s')" % kinds[0]], ["wait", 2.0], ["eval", C + ".watch()"], ["wait", 5.0], ["eval", C + ".report('baseline', 'standing')"]])
	for k in kinds:
		steps.append_array([
			["eval", C + ".stand_before('%s')" % k], ["wait", 0.6], ["shot", "%s_0_before" % k],
			["eval", C + ".interact()"],
			["wait", 0.35], ["eval", C + ".st('1_door')"], ["shot", "%s_1_door" % k],
			["wait", 0.35], ["eval", C + ".st('2_door')"], ["shot", "%s_2_door" % k],
			["wait", 0.3], ["eval", C + ".st('3_door')"], ["eval", C + ".probe('h3')"], ["shot", "%s_3_door" % k],
			["wait", 0.25], ["eval", C + ".st('4_step')"], ["shot", "%s_4_step" % k],
			["wait", 0.25], ["eval", C + ".st('5_in')"], ["shot", "%s_5_in" % k],
			["wait", 0.4], ["shot", "%s_6_in" % k],
			["wait", 2.2], ["shot", "%s_7_room" % k], ["eval", C + ".report('%s', 'in')" % k],
			["key", "Escape"], ["wait", 0.6], ["eval", C + ".esc_again()"],
			["wait", 0.15], ["eval", C + ".probe('o1')"], ["shot", "%s_7a_out" % k],
			["wait", 0.15], ["eval", C + ".probe('o2')"], ["shot", "%s_7b_out" % k],
			["wait", 0.2], ["eval", C + ".probe('o3')"], ["shot", "%s_8_out" % k],
			["wait", 0.25], ["eval", C + ".probe('o4')"], ["shot", "%s_8b_out" % k],
			["wait", 0.25], ["eval", C + ".probe('o5')"], ["shot", "%s_9_out" % k],
			["wait", 0.5], ["shot", "%s_a_out" % k],
			["wait", 0.5], ["shot", "%s_b_out" % k],
			["wait", 2.0], ["shot", "%s_c_out" % k], ["eval", C + ".report('%s', 'out')" % k],
		])
		if k.begins_with("tent"):
			steps.append_array([
				["eval", C + ".look_back('%s')" % k], ["wait", 1.2], ["shot", "%s_d_open_seen" % k],
				["eval", C + ".zip(false)"], ["wait", 0.6], ["shot", "%s_e_zipped" % k],
			])
	_steps = steps
