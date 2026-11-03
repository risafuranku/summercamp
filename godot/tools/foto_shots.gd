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
	_steps = WALK_STEPS.duplicate(true)
