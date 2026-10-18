extends Node

## Mr Novotny, the electrician, after you rang him (scripts/closeup/phone_book.gd): his
## van pulls up on the gate road after the time he said, he walks in through the gap by
## the barrier with his toolbox (and a torch after dark), goes to the generator, works
## at the board for a while with the sounds of it, puts everything right that the night
## left (the tripped main and the circuit that had to stay off) and walks back out.
## The fee comes off the till when he is done: day rate, double after nine.
## He is a sprite like the guests (assets/textury/npc/npc_electrician.png).

signal finished

const BOOK = preload("res://scripts/closeup/phone_book.gd")
const SPRITE := "res://assets/textury/npc/npc_electrician.png"
const SPRITE_FALLBACK := "res://assets/textury/npc/host_pensioner.png"
const SFX_CAR := "res://assets/sfx/gate/car_arrive.mp3"
const SFX_WORK := ["res://assets/sfx/power/breaker_click.mp3", "res://assets/sfx/rednecksfx/rrtick.wav", "res://assets/sfx/power/main_switch.mp3"]
const SFX_SPARK := "res://assets/sfx/power/main_trip.mp3"
const SPRITE_HEIGHT_M := 1.74
const WALK_SPEED := 1.35
## Game minutes until he arrives, and how long he works.
const ARRIVE_DAY := 30.0
const ARRIVE_NIGHT := 60.0
const WORK_MINUTES := 18.0

var night := false
var _main: Node
var _state := "coming"         # coming, walking_in, working, walking_out
var _arrive_at := 0.0           # abs game minute
var _work_until := 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_d := 0.0
var _path_len := 0.0
var _body: Node3D
var _sprite: Sprite3D
var _torch: SpotLight3D
var _anim_t := 0.0
var _work_sfx_t := 0.0


func begin(main_node: Node, at_night: bool, _delay := 0.0) -> void:
	_main = main_node
	night = at_night
	_arrive_at = _now() + (ARRIVE_NIGHT if night else ARRIVE_DAY)
	_state = "coming"


func export_state() -> Dictionary:
	return {"night": night, "arrive_at": _arrive_at, "state": "coming" if _state == "coming" else "working", "work_until": _work_until}


func import_state(main_node: Node, data: Dictionary) -> void:
	_main = main_node
	night = bool(data.get("night", false))
	_arrive_at = float(data.get("arrive_at", _now()))
	# A save made while he was here: he is at the board again.
	_state = "coming"
	if str(data.get("state", "coming")) == "working":
		_arrive_at = _now()


func _now() -> float:
	return float(_main._now_abs_minutes_float()) if _main != null and _main.has_method("_now_abs_minutes_float") else 0.0


func _process(delta: float) -> void:
	if _main == null:
		return
	var now := _now()
	match _state:
		"coming":
			if now >= _arrive_at:
				_arrive()
		"walking_in":
			if _walk(delta):
				_state = "working"
				_work_until = now + WORK_MINUTES
				_say("\"%s\"" % ("Evening. Right, where is it." if night else "Morning. Let's have a look at it."))
		"working":
			_work_sounds(delta)
			if now >= _work_until:
				_finish_work()
		"walking_out":
			if _walk(delta):
				_leave()
	_animate(delta)


func _arrive() -> void:
	var gate := get_tree().get_first_node_in_group("camp_gate")
	var gen := _generator()
	if gate == null or gen == null:
		# No generator to fix, or nowhere to come from: he does it from the road box.
		_finish_work()
		_leave()
		return
	var start: Vector3 = gate.waiting_spot(0) + Vector3(0.0, 0.0, -9.0)
	_sound_at(SFX_CAR, start + Vector3(0, 0.5, -10.0), 0.0, 70.0)
	_make_body()
	_path = _route(start, gen)
	_begin_walk()
	_body.global_position = _path[0]
	_state = "walking_in"
	_say("A van on the gate road. Novotny." if not night else "Headlights on the gate road, then off. Novotny, with a torch.")


func _finish_work() -> void:
	var jobs = _main.get("_night_jobs")
	var what := "the main"
	if jobs != null:
		if int(jobs.dead_circuit) >= 0:
			what = ["the north lamps", "the south lamps", "the office", "the kitchen", "the wash block", "the pump"][clampi(int(jobs.dead_circuit), 0, 5)]
		jobs.breaker_tripped = false
		jobs.dead_circuit = -1
		jobs.changed.emit()
	if _main.has_method("_sync_dark_lamps"):
		_main._sync_dark_lamps()
	var fee := BOOK.FEE_NIGHT if night else BOOK.FEE_DAY
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.add_money(-fee)
	_say("Novotny: \"That was %s. Water in a junction box. %d, I'll put it on Vera's account.\"  -$%d" % [what, fee, fee], 3)
	var gate := get_tree().get_first_node_in_group("camp_gate")
	if _body != null and gate != null:
		_path = _route(_body.global_position, gate.waiting_spot(0) + Vector3(0.0, 0.0, -14.0))
		_begin_walk()
		_state = "walking_out"
	else:
		_state = "walking_out"
		_path = PackedVector3Array()


func _leave() -> void:
	if _body != null:
		_body.queue_free()
		_body = null
	finished.emit()
	queue_free()


# ── walking ───────────────────────────────────────────────────────────────────

func _generator() -> Node3D:
	if _main.has_method("debug_structure_of_type"):
		return _main.debug_structure_of_type("power_generator")
	return null


## Through the gap by the barrier, then over the camp's walkable tiles (the guests' A*).
func _route(from: Vector3, to_node) -> PackedVector3Array:
	var pts := PackedVector3Array([from])
	var gm = _main.get("grid_manager")
	var ga = _main.get("_guest_agents")
	var goal: Vector3 = to_node.global_position if to_node is Node3D else to_node
	var gate := get_tree().get_first_node_in_group("camp_gate")
	if gate != null:
		var inside := Vector3(gate.gap_center_x, 0.0, gate.fence_z + 1.6)
		var outside := Vector3(gate.gap_center_x, 0.0, gate.fence_z - 2.0)
		if from.z < gate.fence_z:
			pts.append(outside)
			pts.append(inside)
		elif goal.z < gate.fence_z:
			pass
	if gm != null and ga != null and ga.has_method("_find_path") and gm.has_method("world_to_grid"):
		var a: Vector2i = gm.world_to_grid(pts[pts.size() - 1])
		var b: Vector2i = gm.world_to_grid(goal)
		var bt: Vector2i = ga._stand_tile(b, a) if ga.has_method("_stand_tile") else b
		for c in ga._find_path(ga._stand_tile(a, a), bt):
			pts.append(gm.grid_to_world(c))
	if to_node is Node3D:
		pts.append(pts[pts.size() - 1].lerp(goal, 0.25))
	else:
		if gate != null and goal.z < gate.fence_z:
			pts.append(Vector3(gate.gap_center_x, 0.0, gate.fence_z + 1.6))
			pts.append(Vector3(gate.gap_center_x, 0.0, gate.fence_z - 2.0))
		pts.append(goal)
	for i in pts.size():
		pts[i].y = _ground(pts[i])
	return pts


func _ground(p: Vector3) -> float:
	# The camp is flat; the road outside the gate too.
	var gm = _main.get("grid_manager")
	if gm != null:
		return float(gm.grid_to_world(Vector2i.ZERO).y)
	return 0.0


func _begin_walk() -> void:
	_path_d = 0.0
	_path_len = 0.0
	for i in range(1, _path.size()):
		_path_len += _path[i - 1].distance_to(_path[i])


## Moves along the path; true when there.
func _walk(delta: float) -> bool:
	if _body == null or _path.size() < 2:
		return true
	_path_d = minf(_path_len, _path_d + WALK_SPEED * delta)
	var d := _path_d
	for i in range(1, _path.size()):
		var seg := _path[i - 1].distance_to(_path[i])
		if d <= seg or i == _path.size() - 1:
			var t := 0.0 if seg < 0.001 else clampf(d / seg, 0.0, 1.0)
			_body.global_position = _path[i - 1].lerp(_path[i], t)
			var dir := (_path[i] - _path[i - 1])
			if dir.length() > 0.01 and _torch != null:
				_torch.look_at(_body.global_position + Vector3(dir.x, -0.35, dir.z).normalized() * 3.0 + Vector3(0, 1.2, 0), Vector3.UP)
			break
		d -= seg
	return _path_d >= _path_len - 0.01


func _make_body() -> void:
	_body = Node3D.new()
	_body.name = "Electrician"
	# Co-op: the other warden sees him come too (scripts/coop/coop_night.gd).
	_body.add_to_group("coop_mirror")
	var world = _main.get("_world_3d")
	(world if world != null else _main).add_child(_body)
	_sprite = Sprite3D.new()
	var path := SPRITE if ResourceLoader.exists(SPRITE) else SPRITE_FALLBACK
	var tex := load(path) as Texture2D
	_sprite.texture = tex
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.double_sided = true
	if path == SPRITE_FALLBACK:
		_sprite.modulate = Color(0.62, 0.72, 1.0)
	if tex != null:
		_sprite.pixel_size = SPRITE_HEIGHT_M / float(tex.get_height())
		_sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	_body.add_child(_sprite)
	if night:
		_torch = SpotLight3D.new()
		_torch.light_color = Color(1.0, 0.92, 0.72)
		_torch.light_energy = 2.4
		_torch.spot_range = 14.0
		_torch.spot_angle = 22.0
		_torch.position = Vector3(0.25, 1.15, 0.0)
		_body.add_child(_torch)


## The walk in steps like the guests' (8 a second): a bob and a sway.
func _animate(delta: float) -> void:
	if _sprite == null:
		return
	_anim_t += delta
	var walking := _state == "walking_in" or _state == "walking_out"
	var f := floorf(_anim_t * 8.0)
	_sprite.position.y = (absf(sin(f * 0.8)) * 0.05) if walking else 0.0
	_sprite.rotation.z = (sin(f * 0.8) * 0.03) if walking else (sin(f * 0.3) * 0.02 if _state == "working" else 0.0)


func _work_sounds(delta: float) -> void:
	_work_sfx_t -= delta
	if _work_sfx_t > 0.0 or _body == null:
		return
	_work_sfx_t = randf_range(1.6, 3.4)
	var file: String = SFX_WORK[randi() % SFX_WORK.size()]
	if randf() < 0.2:
		file = SFX_SPARK
	_sound_at(file, _body.global_position + Vector3(0, 1.0, 0), -4.0, 30.0)


func _sound_at(path: String, at: Vector3, db: float, max_d: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = db
	p.max_distance = max_d
	var world = _main.get("_world_3d")
	(world if world != null else _main).add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


func _say(text: String, kind := 1) -> void:
	var hud = _main.get("_hud_manager")
	if hud != null:
		hud.push_status(text, kind)
