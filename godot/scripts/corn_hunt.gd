extends Node

## Night job "Someone is in the corn" (scripts/night_jobs.gd). A guest has wandered into
## the corn maze behind the wicket gate (cornfield.gd) and is standing at the end of some
## corridor, calling out now and then. Find them by their voice, press E, and they follow
## you; walk them out through the gate into the camp.
##
## The scarecrow is in there with you. It never moves while you can see it. Whenever you
## cannot (it is behind you, round a corner, or simply out of the beam), it steps one
## tile closer along the maze, a stalk-rustle each time, faster the longer you take. Keep
## the flashlight on it for a moment and it is somewhere else, far off, next time you
## look away. If it reaches you: a hit, and the guest bolts back into the corn.
##
## Everything moves in steps, 10 a second at most: the guest's walk, the scarecrow's
## lurch, the way the old film the camp is shot on would show it.

signal finished(rescued: bool)

const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const CALL_SFX := "res://assets/sfx/world/corn_call.mp3"
const RUSH_SFX := "res://assets/sfx/world/corn_rush.mp3"
const STEP_FPS := 10.0
const HIT_DAMAGE := 22
const LIT_RANGE := 13.0

var guest_id := -1
var guest_name := ""
var _main: Node
var _corn: Node
var _guest: Sprite3D
var _following := false
var _crumbs: Array[Vector3] = []
var _scare_tile := Vector2i(-1, -1)
var _scare_timer := 4.0
var _lit_time := 0.0
var _flee_pending := false
var _call_timer := 2.0
var _call_player: AudioStreamPlayer3D
var _rush_player: AudioStreamPlayer3D
var _step_acc := 0.0
var _elapsed := 0.0
var _done := false
var _hint_shown := ""
## The insects fall silent when the scarecrow is near (main reads this, like the omens).
var hush := 0.0
var _trail: Array[Node3D] = []
var _lighter: OmniLight3D
var _lighter_timer := 1.0
var _quote_timer := 6.0
var _leaves: Array = []   # {node, v, life}
var _leaf_mat: StandardMaterial3D
var _tilted := false
var _step_leaves_acc := 0.0

const FOLLOW_LINES := [
	"Is it still behind us?", "Don't turn round. Just don't.", "It was looking at me. All night.",
	"Which way? They all look the same.", "I only went for a pee, I swear.", "Faster. Please, faster.",
]
const TRAIL_KINDS := ["cans", "papers", "clothes", "bottles", "cans"]


func setup(main_node: Node, corn: Node, guest: Dictionary) -> bool:
	_main = main_node
	_corn = corn
	guest_id = int(guest.get("id", -1))
	guest_name = str(guest.get("name", "A guest"))
	var ends: Array = corn.dead_ends()
	if ends.is_empty():
		return false
	# The farthest dead end from the way in, give or take.
	ends.sort_custom(func(a, b): return a.distance_squared_to(corn.entrance) > b.distance_squared_to(corn.entrance))
	var pick: Vector2i = ends[randi_range(0, mini(3, ends.size() - 1))]
	_guest = Sprite3D.new()
	_guest.name = "LostGuest"
	# Co-op: the other warden sees them in the corn too (scripts/coop/coop_night.gd).
	_guest.add_to_group("coop_mirror")
	var tex_path := str(guest.get("sprite_path", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_guest.texture = load(tex_path)
	_guest.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_guest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_guest.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_guest.shaded = true
	if _guest.texture != null:
		_guest.pixel_size = 1.7 / float(_guest.texture.get_height())
		_guest.offset = Vector2(0, _guest.texture.get_height() * 0.5)
	corn.add_child(_guest)
	_guest.global_position = corn.tile_world(pick)
	_call_player = _sound(CALL_SFX, _guest, 7.0, -3.0)
	_rush_player = _sound(RUSH_SFX, corn.scarecrow, 4.0, 0.0)
	# What they dropped on the way in: a trail every few tiles from the gate to them.
	var path: Array = corn.path_between(corn.entrance, pick)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var k := 4
	while k < path.size() - 2:
		var at: Vector3 = corn.tile_world(path[k]) + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
		var built: Dictionary = INTERIOR_PREP.build_mess(corn, at, TRAIL_KINDS[rng.randi_range(0, TRAIL_KINDS.size() - 1)], rng, rng.randf() * TAU)
		(built["body"] as Node).queue_free()
		_trail.append(built["root"])
		k += rng.randi_range(4, 7)
	# A lighter they keep clicking: a small warm light you can see over the stalks.
	_lighter = OmniLight3D.new()
	_lighter.light_color = Color(1.0, 0.72, 0.36)
	_lighter.omni_range = 5.0
	_lighter.light_energy = 0.0
	_lighter.position = Vector3(0.25, 1.3, 0.0)
	_guest.add_child(_lighter)
	_leaf_mat = StandardMaterial3D.new()
	_leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_leaf_mat.albedo_color = Color(0.62, 0.55, 0.3)
	# The scarecrow starts at another dead end, well away from both of you.
	_scare_tile = _far_tile([pick, corn.entrance])
	_place_scarecrow()
	return true


func _sound(path: String, parent: Node, unit: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path) if ResourceLoader.exists(path) else null
	p.unit_size = unit
	p.volume_db = db
	p.max_distance = 60.0
	parent.add_child(p)
	return p


func _process(delta: float) -> void:
	if _done or _main == null or _corn == null:
		return
	var player = _main.get("_player")
	if player == null or not is_instance_valid(player):
		return
	if get_tree().paused:
		return
	_elapsed += delta
	var ppos: Vector3 = player.global_position
	var in_corn: bool = _corn.in_maze(ppos) or (ppos.x < _corn.fence_x and absf(ppos.z - _corn.gate_z) < 2.0)

	# The guest calls out until found.
	if not _following:
		_call_timer -= delta
		if _call_timer <= 0.0:
			_call_timer = randf_range(5.0, 9.0)
			if _call_player != null and _call_player.stream != null:
				_call_player.play()
		if Vector2(ppos.x - _guest.global_position.x, ppos.z - _guest.global_position.z).length() < 1.8:
			_set_hint("[E] Take %s by the arm" % guest_name)
			if Input.is_action_just_pressed("interact"):
				_following = true
				_crumbs.clear()
				_set_hint("")
				_notice("%s grabs your sleeve. \"Get me out of here.\"" % guest_name, 1)
		else:
			_set_hint("")
	else:
		# Breadcrumbs: the guest walks where you walked, a few steps behind.
		if _crumbs.is_empty() or _crumbs.back().distance_to(ppos) > 0.35:
			_crumbs.append(ppos)
			if _crumbs.size() > 40:
				_crumbs.pop_front()
		_step_acc += delta
		if _step_acc >= 1.0 / STEP_FPS:
			_step_acc = 0.0
			var target: Vector3 = _crumbs[maxi(0, _crumbs.size() - 5)]
			var gp := _guest.global_position
			var to := Vector3(target.x - gp.x, 0, target.z - gp.z)
			if to.length() > 0.9:
				_guest.global_position = gp + to.normalized() * minf(to.length() - 0.9, 0.55)
				_guest.flip_h = not _guest.flip_h
		# Out through the gate, into the camp: done.
		if _guest.global_position.x > _corn.fence_x + 0.8 and ppos.x > _corn.fence_x + 0.8:
			_finish(true)
			return

	_update_lighter(delta)
	_update_leaves(delta)
	if _following:
		_quote_timer -= delta
		if _quote_timer <= 0.0:
			_quote_timer = randf_range(9.0, 16.0)
			var hud = _main.get("_hud_manager")
			if hud != null and hud.has_method("show_quote"):
				hud.show_quote(guest_name, FOLLOW_LINES[randi_range(0, FOLLOW_LINES.size() - 1)], 20.0)
	# The scarecrow: only while you are in the corn. The crickets know where it is.
	var near := 0.0
	if _corn.scarecrow != null:
		near = clampf(1.0 - (_corn.scarecrow.global_position.distance_to(ppos) - 4.0) / 10.0, 0.0, 1.0)
	hush = move_toward(hush, near if in_corn else 0.0, delta * 0.8)
	if in_corn:
		_update_scarecrow(delta, player)


## Click... a flame for a moment... gone. Stepped, flickering, until they are found.
func _update_lighter(delta: float) -> void:
	if _lighter == null:
		return
	_lighter_timer -= delta
	if _following:
		_lighter.light_energy = 0.0
		return
	if _lighter_timer <= 0.0:
		var lit := _lighter.light_energy > 0.0
		_lighter_timer = randf_range(2.0, 4.5) if lit else randf_range(1.2, 2.5)
		_lighter.light_energy = 0.0 if lit else 1.2
	elif _lighter.light_energy > 0.0 and fmod(_elapsed, 0.1) < delta:
		_lighter.light_energy = randf_range(0.9, 1.5)


func _update_leaves(delta: float) -> void:
	_step_leaves_acc += delta
	if _step_leaves_acc < 0.1:
		return
	_step_leaves_acc = 0.0
	for l in _leaves:
		var n: MeshInstance3D = l["node"]
		n.position += l["v"]
		n.rotation.z += 0.6
		l["life"] -= 1
		if int(l["life"]) <= 0:
			n.queue_free()
	_leaves = _leaves.filter(func(l): return int(l["life"]) > 0)


## Leaves and husks shaken off the stalks where it just went through.
func _shed_leaves(at: Vector3) -> void:
	for i in 7:
		var n := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.12, 0.06)
		n.mesh = q
		n.material_override = _leaf_mat
		_corn.add_child(n)
		n.global_position = at + Vector3(randf_range(-0.8, 0.8), randf_range(1.4, 2.3), randf_range(-0.8, 0.8))
		_leaves.append({"node": n, "v": Vector3(randf_range(-0.03, 0.03), -0.12, randf_range(-0.03, 0.03)), "life": randi_range(10, 18)})


func _update_scarecrow(delta: float, player: Node3D) -> void:
	var scare: Sprite3D = _corn.scarecrow
	if scare == null:
		return
	var seen := _in_view(scare.global_position + Vector3(0, 1.2, 0))
	var lit: bool = seen and player.has_method("is_flashlight_active") and player.is_flashlight_active() \
		and scare.global_position.distance_to(player.global_position) < LIT_RANGE
	if lit:
		_lit_time += delta
		# It does not move in the light. It tilts its head. Once.
		if _lit_time > 0.6 and not _tilted:
			_tilted = true
			scare.rotation.z = 0.22 if randf() < 0.5 else -0.22
		if _lit_time > 1.2:
			_flee_pending = true
	else:
		_lit_time = 0.0
	if seen:
		return
	if _flee_pending:
		# Gone, somewhere far off, the moment you looked away.
		_flee_pending = false
		_scare_tile = _far_tile([_corn.world_tile(player.global_position)])
		_place_scarecrow()
		_scare_timer = 5.0
		return
	_scare_timer -= delta
	if _scare_timer > 0.0:
		return
	# Faster the longer you are in there: from every 4 s down to every 1.6 s.
	_scare_timer = clampf(4.0 - _elapsed * 0.02, 1.6, 4.0)
	var me: Vector2i = _corn.world_tile(player.global_position)
	if not _corn.maze_open.has(me):
		me = _corn.entrance
	var path: Array = _corn.path_between(_scare_tile, me)
	if path.size() <= 2:
		_hit(player)
		return
	_scare_tile = path[1]
	_place_scarecrow()
	scare.flip_h = not scare.flip_h
	scare.rotation.z = randf_range(-0.08, 0.08)
	_tilted = false
	_shed_leaves(scare.global_position)
	if _rush_player != null and _rush_player.stream != null:
		_rush_player.play()


func _hit(player: Node3D) -> void:
	if _main.has_method("damage_player"):
		_main.damage_player(HIT_DAMAGE)
	_notice("Something in the corn. %s screams and runs." % guest_name, 2)
	if _following:
		_following = false
		var ends: Array = _corn.dead_ends()
		if not ends.is_empty():
			_guest.global_position = _corn.tile_world(ends[randi_range(0, ends.size() - 1)])
	_scare_tile = _far_tile([_corn.world_tile(player.global_position)])
	_place_scarecrow()
	_scare_timer = 6.0


func _place_scarecrow() -> void:
	var scare: Sprite3D = _corn.scarecrow
	if scare != null and _scare_tile.x >= 0:
		scare.global_position = _corn.tile_world(_scare_tile)


## A path tile far from all of `avoid` (dead ends first).
func _far_tile(avoid: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1.0
	var cands: Array = _corn.dead_ends()
	if cands.is_empty():
		cands = _corn.maze_open.keys()
	for t in cands:
		var d := INF
		for a in avoid:
			d = minf(d, Vector2(t).distance_to(Vector2(a)))
		d += randf() * 3.0
		if d > best_d:
			best_d = d
			best = t
	return best


## On screen and nothing solid in between.
func _in_view(at: Vector3) -> bool:
	var cam: Camera3D = _main.call("_get_player_camera") if _main.has_method("_get_player_camera") else null
	if cam == null:
		return false
	if cam.is_position_behind(at):
		return false
	var vp := cam.get_viewport().get_visible_rect().size
	var sp := cam.unproject_position(at)
	if sp.x < 0 or sp.y < 0 or sp.x > vp.x or sp.y > vp.y:
		return false
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, at)
	var player = _main.get("_player")
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _finish(rescued: bool) -> void:
	if _done:
		return
	_done = true
	_set_hint("")
	if _guest != null and is_instance_valid(_guest):
		_guest.queue_free()
	finished.emit(rescued)


## Dawn came first.
func abandon() -> void:
	_finish(false)


func _set_hint(text: String) -> void:
	_hint_shown = text


## The interaction line for the HUD (main shows it before anything else).
func hint() -> String:
	return "" if _done else _hint_shown


func _notice(text: String, kind: int) -> void:
	var hud = _main.get("_hud_manager")
	if hud != null:
		hud.push_status(text, kind)


func _exit_tree() -> void:
	for t in _trail:
		if is_instance_valid(t):
			t.queue_free()
	for l in _leaves:
		if is_instance_valid(l["node"]):
			l["node"].queue_free()
	if _corn != null and _corn.scarecrow != null:
		_corn.scarecrow.rotation.z = 0.0
	if _guest != null and is_instance_valid(_guest):
		_guest.queue_free()
	for p in [_call_player, _rush_player]:
		if p != null and is_instance_valid(p):
			p.queue_free()
