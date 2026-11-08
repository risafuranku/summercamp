extends "res://tools/shot_driver.gd"

## The Photographer's night measured (scripts/enemies/tourist_brain.gd):
##   --part=walk   two minutes of him walking round a warden standing in the camp among
##                 its buildings and trees: how high over the ground he ever stood, and
##                 how many of his walks went along the camp's ways (round a building or
##                 a tree in the way of his arc)
##   --part=hitch  his firsts in a row (his shots at you, the first picture of you, his
##                 window), every frame timed
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/foto_shots.tscn -- --part=walk
## (His scares on pictures: tools/photographer_shots.tscn, photographer_worse_shots.tscn;
## co-op: tools/coop_photo.py.)

const F := "get_tree().root.get_node('FotoShots')"


func photographer():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "tourist":
			return b
	return null


# ── his walking ───────────────────────────────────────────────────────────────

var _watch_walk := false
var _frames := 0
var _max_lift := 0.0
var _high := 0
var _walks := 0
var _routed := 0
var _last_from := Vector3.INF


func _process(delta: float) -> void:
	super._process(delta)
	if _watch_walk:
		_measure()
	_process_hitch(delta)


func _measure() -> void:
	var t = photographer()
	if t == null:
		return
	var b: Node3D = t.get("_body")
	if b == null or not b.visible:
		return
	_frames += 1
	var g := _floor_under(b.global_position)
	if g != Vector3.INF:
		var lift := b.global_position.y - g.y
		_max_lift = maxf(_max_lift, lift)
		if lift > 0.3:
			_high += 1
	var from: Vector3 = t.get("_walk_from")
	if from != _last_from:
		_last_from = from
		_walks += 1
		var r = t.get("_walk_route")
		if r is PackedVector3Array and (r as PackedVector3Array).size() > 1:
			_routed += 1


## The ground under `p` from just over the warden's feet (a roof or a tree's crown over
## it is not ground): measured here, the same for any version of his brain.
func _floor_under(p: Vector3) -> Vector3:
	var pl: Node3D = _main.get("_player")
	var top := pl.global_position.y + 1.6
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.z), Vector3(p.x, top - 6.0, p.z))
	q.exclude = [(pl as CollisionObject3D).get_rid()]
	var hit := pl.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3.INF


func walk_watch(on: bool) -> String:
	_watch_walk = on
	return "WALK frames=%d max_lift=%.2f m high_frames=%d walks=%d along_ways=%d" % [_frames, _max_lift, _high, _walks, _routed]


const WALK_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["tourist"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["eval", F + ".walk_watch(true)"],
	["wait", 30.0], ["eval", "_set_player_health(100)"], ["eval", F + ".walk_watch(true)"],
	["wait", 30.0], ["eval", "_set_player_health(100)"], ["eval", F + ".walk_watch(true)"],
	["wait", 30.0], ["eval", "_set_player_health(100)"], ["eval", F + ".walk_watch(true)"],
	["wait", 30.0], ["eval", F + ".walk_watch(false)"],
]



# ── his firsts, timed ─────────────────────────────────────────────────────────

## A hitch: a frame far longer than the frames round it (three times the running mean and
## over 50 ms), while watched. No pictures taken (a saved picture is a long frame itself).
var _watch_hitch := false
var _hitches := 0
var _mean_dt := 1.0 / 30.0
var _win := ""
var _win_dt: Array = []
var _win_ms: Array = []


func _process_hitch(delta: float) -> void:
	if _watch_hitch and delta > 0.05 and delta > _mean_dt * 3.0:
		_hitches += 1
		var t = photographer()
		print("HITCH %d ms (frames round it %d ms) %s" % [int(delta * 1000.0), int(_mean_dt * 1000.0), str(t.get_debug_snapshot()) if t != null else ""])
	_mean_dt = lerpf(_mean_dt, minf(delta, 0.25), 0.1)
	if _win != "":
		_win_dt.append(delta)
		_win_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)


func watch(on: bool) -> String:
	_watch_hitch = on
	return "HITCHES %d" % _hitches


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


## Him 9 m in front of you, facing you, and his shot now: it catches you (the white, the
## ringing, his face, the picture of you developing).
func shot_now() -> String:
	var t = photographer()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var fwd := (-cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized()
	(t.get("_body") as Node3D).global_position = t._stand(p.global_position + fwd * 9.0) if t._stand(p.global_position + fwd * 9.0) != Vector3.INF else p.global_position + fwd * 9.0
	t._fire()
	return "shot, hit %s" % str(t.get("_hit_last"))


## Him `dist` m behind you (`deg` off straight behind) and the flash now: your shadow out
## ahead of you (`--part=shadow`). Held still, so the shot is the flash's moment.
func shot_behind(dist: float, deg: float) -> String:
	var t = photographer()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var back := (cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized().rotated(Vector3.UP, deg_to_rad(deg))
	var want := p.global_position + back * dist
	var at: Vector3 = t._stand(want)
	(t.get("_body") as Node3D).global_position = at if at != Vector3.INF else want
	t._fire()
	var d: Node3D = _main.get("_world_3d").get_node_or_null("FlashShadow")
	return "shot from behind, hit %s, shadow %s" % [str(t.get("_hit_last")), str(d.visible) if d != null else "none"]


## The warden moved to open ground (nothing at eye height for 10 m all round, from points
## round where they stand), looking a little down at the ground ahead.
func open_ground() -> String:
	var t = photographer()
	var p: Node3D = _main.get("_player")
	var from := p.global_position
	for r in [0.0, 6.0, 12.0, 18.0, 24.0, 30.0]:
		for k in 12:
			var c: Vector3 = from + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * float(k) / 12.0)
			var g: Vector3 = t._stand(c)
			if g == Vector3.INF:
				continue
			var ok := true
			for a in 8:
				var d := Vector3(0, 0, -10.0).rotated(Vector3.UP, TAU * float(a) / 8.0)
				if t._ray_blocked(g + Vector3(0, 1.5, 0), g + d + Vector3(0, 1.5, 0)) or t._ray_blocked(g + Vector3(0, 0.4, 0), g + d * 0.6 + Vector3(0, 0.4, 0)):
					ok = false
					break
			if ok:
				p.global_position = g + Vector3(0, 0.05, 0)
				p.set("_pitch", -0.4)
				p.set("_pitch_target", -0.4)
				return "open ground at %s (%.0f m off)" % [str(g.snapped(Vector3.ONE * 0.1)), r]
	return "no open ground"


## Him framing you ahead (`--part=shadow`): the presence while he would have you.
func framing_ahead() -> String:
	var t = photographer()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var fwd := (-cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized()
	var at: Vector3 = t._stand(p.global_position + fwd * 10.0)
	(t.get("_body") as Node3D).global_position = at if at != Vector3.INF else p.global_position + fwd * 10.0
	t._enter_frame()
	return "framing"


func presence_now() -> String:
	var fx = _main.get_tree().root.get_node_or_null("NightmareFX")
	return "presence %.2f" % float(fx.get("_presence")) if fx != null else "no fx"


const SHADOW_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["tourist"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0], ["eval", "_set_player_health(100)"],
	["eval", "debug_spawn_enemy('tourist', 3)"], ["wait", 1.0],
	# On open ground, looking a little down at the ground ahead, him behind: the flash.
	["eval", F + ".open_ground()"], ["wait", 1.0],
	["eval", F + ".shot_behind(9.0, 0.0)"], ["wait", 0.05], ["shot", "s1_shadow_ahead"],
	["wait", 0.5], ["shot", "s2_shadow_gone"],
	["eval", F + ".shot_behind(7.0, 35.0)"], ["wait", 0.05], ["shot", "s3_shadow_slant"],
	["wait", 1.5], ["eval", "_player.set('_pitch_target', 0.0)"], ["wait", 0.5],
	["eval", F + ".framing_ahead()"], ["wait", 1.6], ["eval", F + ".presence_now()"], ["shot", "s4_framed"],
	["eval", "_player.rotate_y(PI)"], ["wait", 1.0], ["eval", F + ".presence_now()"],
]


const HITCH_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["tourist"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
	# The same night without him, then with him; then his firsts, one after another.
	["call", "_stop_active_enemy_brain", []], ["wait", 3.0],
	["eval", F + ".window('alone')"], ["wait", 5.0], ["eval", F + ".window('')"],
	["eval", "debug_spawn_enemy('tourist', 3)"], ["wait", 3.0],
	["eval", F + ".window('photographer out')"], ["wait", 5.0], ["eval", F + ".window('')"],
	["eval", F + ".watch(true)"],
	["eval", F + ".shot_now()"], ["wait", 4.0], ["eval", "_set_player_health(100)"],
	["eval", F + ".shot_now()"], ["wait", 4.0], ["eval", "_set_player_health(100)"],
	["eval", F + ".shot_now()"], ["wait", 4.0], ["eval", "_set_player_health(100)"],
	["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 2.0],
	["eval", F + ".window('inside')"], ["wait", 14.0], ["eval", F + ".window('')"],
	["eval", "[" + F + ".photographer().get_debug_snapshot(), _player_health]"],
	["eval", F + ".watch(false)"],
]


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=hitch"):
		_steps = HITCH_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=shadow"):
		_steps = SHADOW_STEPS.duplicate(true)
		return
	_steps = WALK_STEPS.duplicate(true)
