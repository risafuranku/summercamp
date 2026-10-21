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
##
## The boy (`boy` > 0: the family's boy, scripts/enemies/boy_brain.gd; DESIGN §5 "The
## boy"): it is him in there, hiding, his back to you, and it is hide and seek. He does
## not call: every few seconds he whispers at your ear how close you are, cold, warmer
## (nearer than the last time), burning (a few steps off); a giggle out of the stalks
## where he is. Found, you take his hand and he says not to look at him, and he follows.
## Look back at him while you lead him (on your screen, near) and his head comes round:
## the face, the shriek, the hit, and he is gone back into the corn to be found again.
## Medium he lies now and then (warmer when you go away), heavy more, and he asks you to
## turn round. No line of text tells any of it: his voice does.

signal finished(rescued: bool)

const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const CALL_SFX := "res://assets/sfx/world/corn_call.mp3"
const RUSH_SFX := "res://assets/sfx/world/corn_rush.mp3"
const STEP_FPS := 10.0
const HIT_DAMAGE := 22
const LIT_RANGE := 13.0
const NIGHTMARE_FX = preload("res://scripts/night/nightmare_fx.gd")
const BOY_DIR := "res://assets/sfx/npc/boy/"
const BOY_FACE := "res://assets/textury/npc/boy_face.png"
## Him facing you as he follows (what you see if you look back), and hiding (his back).
const BOY_FRONT := "res://assets/textury/npc/boy_t1.png"
## His voice is a young woman's pitched up (no child voices to be had).
const BOY_PITCH := 1.22
const BOY_SAYS := {
	"cold": ["cold_1", "cold_2", "cold_3"], "warm": ["warm_1", "warm_2", "warm_3"], "hot": ["hot_1", "hot_2"],
	"follow": ["follow_1", "follow_2", "follow_3", "follow_4"], "bait": ["bait_1", "bait_2", "bait_3"],
}
## By his tier (1 light .. 3 heavy): how often a hint lies, how often a line while he
## follows is a bait to look, how long a look back he lets go, how hard his face hits.
const BOY_LIES := [0.0, 0.0, 0.2, 0.35]
const BOY_BAITS := [0.0, 0.0, 0.3, 0.55]
const BOY_LOOK := [0.0, 0.4, 0.3, 0.2]
const BOY_HIT := [0, 16, 24, 34]

## The family's boy instead of a guest: his tier 1-3 (0: a guest).
var boy := 0
## The last hint he gave ("cold", "warm", "hot") and how many times his face came round
## (for the checks).
var last_hint := ""
var strikes := 0
var _whisper_t := 2.5
var _last_dist := -1
var _giggle_t := 7.0
var _look_t := 0.0
var _grace := 0.0
var _grace_clear := false
var _unseen_t := 0.0
var _line_t := 7.0
var _steps_t := 0.0
var _ear: AudioStreamPlayer
var _giggle_player: AudioStreamPlayer3D
var _boy_back: Texture2D
var _boy_front: Texture2D

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
	boy = int(guest.get("boy", 0))
	var ends: Array = corn.dead_ends()
	if ends.is_empty():
		return false
	# The farthest dead end from the way in, give or take.
	ends.sort_custom(func(a, b): return a.distance_squared_to(corn.entrance) > b.distance_squared_to(corn.entrance))
	var pick: Vector2i = ends[randi_range(0, mini(3, ends.size() - 1))]
	_guest = Sprite3D.new()
	_guest.name = "LostGuest"
	# Co-op: the other warden sees them in the corn too (scripts/coop/coop_night.gd), and
	# can take them by the arm (main.coop_request "corn_take").
	_guest.add_to_group("coop_mirror")
	_guest.set_meta("coop_tag", "corn_guest")
	var tex_path := str(guest.get("sprite_path", ""))
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_guest.texture = load(tex_path)
	_guest.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_guest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_guest.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_guest.shaded = true
	if _guest.texture != null:
		_guest.pixel_size = (1.25 if boy > 0 else 1.7) / float(_guest.texture.get_height())
		_guest.offset = Vector2(0, _guest.texture.get_height() * 0.5)
	corn.add_child(_guest)
	_guest.global_position = corn.tile_world(pick)
	_call_player = _sound(CALL_SFX if boy == 0 else "", _guest, 7.0, -3.0)
	if boy > 0:
		_boy_back = _guest.texture
		_boy_front = load(BOY_FRONT) if ResourceLoader.exists(BOY_FRONT) else _boy_back
		_giggle_player = _sound(BOY_DIR + "giggle_1.mp3", _guest, 4.0, -6.0)
		_giggle_player.pitch_scale = 1.1
		_ear = AudioStreamPlayer.new()
		add_child(_ear)
		# The night's screen made now: made at his strike it is not up till the frame after
		# and his face would not show.
		var world: Node = _main.get("_world_3d")
		if world != null:
			NIGHTMARE_FX.get_for(world)
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
	# A lighter they keep clicking: a small warm light you can see over the stalks (not
	# the boy: he hides in the dark).
	if boy > 0:
		_scare_tile = _far_tile([pick, corn.entrance])
		_place_scarecrow()
		return true
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


## Co-op: who leads them out (the other warden's stand-in when they took the arm).
var leader: Node3D


## The other warden took them by the arm (their stand-in leads from here).
func coop_take(by: Node3D) -> void:
	if _done or _following:
		return
	leader = by
	_following = true
	_crumbs.clear()
	_set_hint("")


func _process(delta: float) -> void:
	if _done or _main == null or _corn == null:
		return
	var player = leader if leader != null and is_instance_valid(leader) else _main.get("_player")
	if player == null or not is_instance_valid(player):
		return
	if get_tree().paused:
		return
	_elapsed += delta
	var ppos: Vector3 = player.global_position
	var in_corn: bool = _corn.in_maze(ppos) or (ppos.x < _corn.fence_x and absf(ppos.z - _corn.gate_z) < 2.0)

	if boy > 0:
		_boy_process(delta, player, ppos, in_corn)
	# The guest calls out until found.
	elif not _following:
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
	if _following and boy == 0:
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
	# The one leading them gets it (co-op: the other warden, on their machine).
	if leader != null and is_instance_valid(leader) and player == leader:
		Coop.send_night_event("hurt", [HIT_DAMAGE])
	elif _main.has_method("damage_player"):
		_main.damage_player(HIT_DAMAGE)
	if boy == 0:
		_notice("Something in the corn. %s screams and runs." % guest_name, 2)
	if _following:
		_following = false
		var ends: Array = _corn.dead_ends()
		if not ends.is_empty():
			_guest.global_position = _corn.tile_world(ends[randi_range(0, ends.size() - 1)])
	_scare_tile = _far_tile([_corn.world_tile(player.global_position)])
	_place_scarecrow()
	_scare_timer = 6.0


# ── the boy ──────────────────────────────────────────────────────────────────

func _boy_process(delta: float, player: Node3D, ppos: Vector3, in_corn: bool) -> void:
	if not _following:
		if in_corn:
			_boy_hints(delta, ppos)
		if Vector2(ppos.x - _guest.global_position.x, ppos.z - _guest.global_position.z).length() < 1.6:
			_set_hint("[E] Take his hand")
			if Input.is_action_just_pressed("interact"):
				_take_hand()
		else:
			_set_hint("")
		return
	# Following, a few steps behind you: his breadcrumbs.
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
			_steps_t -= 1.0 / STEP_FPS
			if _steps_t <= 0.0:
				_steps_t = randf_range(2.2, 3.4)
				_sound_at(BOY_DIR + "steps_corn.mp3", _guest.global_position, -10.0)
	if _guest.global_position.x > _corn.fence_x + 0.8 and ppos.x > _corn.fence_x + 0.8:
		_finish(true)
		return
	# His lines behind you; the worse he is, the more of them ask you to turn round.
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = randf_range(8.0, 14.0)
		_boy_say_kind("bait" if randf() < BOY_BAITS[boy] else "follow", -8.0)
	# Do not look at him.
	var in_sight := _boy_in_sight()
	if not _grace_clear:
		_grace -= delta
		_unseen_t = 0.0 if in_sight else _unseen_t + delta
		_grace_clear = _unseen_t >= 0.4 or _grace <= 0.0
		return
	if in_sight:
		_look_t += delta
		if _look_t >= BOY_LOOK[boy]:
			_boy_strike(player)
	else:
		_look_t = maxf(0.0, _look_t - delta * 2.0)


## Found: his cold hand in yours, "found me", and then not to look at him.
func _take_hand() -> void:
	_following = true
	_crumbs.clear()
	_set_hint("")
	# You face him as you take his hand: it counts from the first time you look away (or
	# a few seconds).
	_grace = 6.0
	_grace_clear = false
	_unseen_t = 0.0
	_look_t = 0.0
	_line_t = randf_range(7.0, 11.0)
	_boy_say("found", -6.0)
	_sfx_2d(BOY_DIR + "hand.mp3", -4.0, 1.0)
	_boy_look(_boy_front)
	get_tree().create_timer(1.6).timeout.connect(_say_rule)


func _say_rule() -> void:
	if _following and not _done:
		_boy_say("rule_1" if randf() < 0.6 else "rule_2", -5.0)


## Cold, warmer, burning: by the way through the maze from you to him, against the last.
func _boy_hints(delta: float, ppos: Vector3) -> void:
	_giggle_t -= delta
	if _giggle_t <= 0.0:
		_giggle_t = randf_range(9.0, 16.0)
		if _giggle_player != null:
			_giggle_player.stream = load(BOY_DIR + ("giggle_1.mp3" if randf() < 0.5 else "giggle_2.mp3"))
			_giggle_player.play()
	_whisper_t -= delta
	if _whisper_t > 0.0:
		return
	_whisper_t = randf_range(3.5, 6.0)
	var me: Vector2i = _corn.world_tile(ppos)
	if not _corn.maze_open.has(me):
		me = _corn.entrance
	var d: int = (_corn.path_between(me, _corn.world_tile(_guest.global_position)) as Array).size()
	var kind := "hot" if d <= 3 else ("warm" if (_last_dist >= 0 and d < _last_dist) or d <= 7 else "cold")
	if kind != "hot" and randf() < BOY_LIES[boy]:
		kind = "cold" if kind == "warm" else "warm"
	_last_dist = d
	last_hint = kind
	_boy_say_kind(kind, -7.0)


## Him on your screen, near, nothing between: you looked back.
func _boy_in_sight() -> bool:
	var at := _guest.global_position + Vector3(0, 0.8, 0)
	var cam: Camera3D = _main.call("_get_player_camera") if _main.has_method("_get_player_camera") else null
	if cam == null or cam.global_position.distance_to(at) > 9.0:
		return false
	return _in_view(at)


## His head comes round: the face in yours, the shriek, the hit; he is gone back into the
## corn, and it is to do again.
func _boy_strike(player: Node3D) -> void:
	_following = false
	_look_t = 0.0
	_last_dist = -1
	strikes += 1
	var world: Node = _main.get("_world_3d")
	var fx = NIGHTMARE_FX.get_for(world) if world != null else null
	_sfx_2d(BOY_DIR + "turn.mp3", 0.0, 1.0)
	_sfx_2d(BOY_DIR + "shriek.mp3", 2.0, 1.0)
	if fx != null:
		var face: Texture2D = load(BOY_FACE if ResourceLoader.exists(BOY_FACE) else "res://assets/textury/npc/host_kid.png")
		fx.freeze(0.12)
		fx.close_up(face, 1.0, 1.0, 0.015)
		fx.glitch(0.9, 0.7)
		fx.tinnitus(2.5)
		# Red once his face is gone (over it, it hid him).
		get_tree().create_timer(0.9).timeout.connect(func():
			fx.close_up_off()
			fx.red_flash(0.55))
	if leader != null and is_instance_valid(leader) and player == leader:
		Coop.send_night_event("hurt", [BOY_HIT[boy]])
	elif _main.has_method("damage_player"):
		_main.damage_player(BOY_HIT[boy])
	get_tree().create_timer(2.2).timeout.connect(_say_looked)
	# Back in the corn, far from you, hiding again.
	_boy_look(_boy_back)
	_guest.global_position = _corn.tile_world(_far_tile([_corn.world_tile(player.global_position)]))
	_whisper_t = 4.0


## His picture (front or back), kept to his height.
func _boy_look(tex: Texture2D) -> void:
	if tex == null:
		return
	_guest.texture = tex
	_guest.pixel_size = 1.25 / float(tex.get_height())
	_guest.offset = Vector2(0, tex.get_height() * 0.5)


func _say_looked() -> void:
	if not _done:
		_boy_say("looked", -6.0)


func _boy_say_kind(kind: String, db: float) -> void:
	var ids: Array = BOY_SAYS[kind]
	_boy_say(str(ids[randi_range(0, ids.size() - 1)]), db)


## At your ear, wherever he is.
func _boy_say(id: String, db: float) -> void:
	_sfx_2d(BOY_DIR + id + ".mp3", db, BOY_PITCH)


func _sfx_2d(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := _ear
	if p == null or p.playing:
		p = AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(p.queue_free)
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _sound_at(path: String, at: Vector3, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = db
	p.unit_size = 4.0
	p.max_distance = 30.0
	_corn.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


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
