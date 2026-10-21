extends Node3D

## The other warden as you see them (co-op, scripts/coop/coop.gd): a sprite like the
## guests' in the look they chose (scripts/coop/warden_looks.gd: who, the jacket), seen
## from eight sides as in Doom (scripts/figures/doom_figure.gd: they face where they look,
## the state's yaw), walking and running in frames by the ground they cover, a blob
## shadow, the torch in their hand lighting where they look, and their steps on the grass.
## A pose without pictures from the sides (at work, sat) is the old one from the front.
##
## Two ways to be fed:
##   - in the camp, the states the other machine sends about fifteen times a second
##     (push_state), drawn a tenth of a second behind between the two either side, so
##     they walk instead of jumping; gone while they are in a room, at the PC or on the
##     bus; in the boat when they row ("boat": the figure rows, seated in it);
##   - in a room (InteriorManager puts a second one in the room's own world): placed by
##     hand (show_at), standing about or at the job they are doing (sweep, crouch), and
##     in a tent lying on their belly (prone).

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const DOOM = preload("res://scripts/figures/doom_figure.gd")
const BOAT_RIG = preload("res://scripts/lake/boat_rig.gd")
const SPRITE_HEIGHT_M := 1.74
## On their feet they are drawn this much smaller than the poses below say, so that their
## eyes are where yours are (1.45 m over the ground: player_controller STANCE_CAPSULE;
## they were looked at in the belly, playtest 21. 10.). Seated and lying they fit the
## furniture as they are.
const FIGURE_SCALE := 0.91
const STANDING := ["stand", "sweep", "crouch", "kick", "bat", "climb", "fix", "fish", "tap", "pour", "wash", "cook", "till", "bag"]
## How tall each pose is drawn (its picture is that tall from top to bottom edge).
const POSE_HEIGHT := {"stand": 1.74, "row": 1.3, "sweep": 1.6, "crouch": 1.2, "prone": 0.62, "desk": 1.32,
	"sit": 1.3, "guitar": 1.3, "eat": 1.3, "swing": 1.36, "kick": 1.7, "bat": 1.6, "climb": 1.86,
	"fix": 1.72, "fish": 1.72, "saw": 1.35, "bag": 1.45,
	"tap": 1.72, "pour": 1.72, "wash": 1.72, "cook": 1.72, "till": 1.72, "write": 0.92,
	"bedfoot": 0.7}
## Poses drawn lying down: how long the picture is from side to side.
const POSE_WIDTH := {"bed": 1.85}
## The guests' walk cycle (scripts/guest_agents.gd), so the two look alike.
const ANIM_FPS := 8.0
const WALK_BOB_HZ := 2.6
## Faster than this (m/s) they run: a walk is 3.9, a sprint 5.2 (player_controller.gd).
const RUN_SPEED := 4.6
## The picture changes this many times a second, like the guests' moves (MOVE_FPS).
const VIEW_FPS := 12.0
## Drawn this far behind the newest state (seconds).
const DELAY := 0.1
## Further than this between two states is a jump (a door, the bus): no sliding.
const SNAP_DIST := 6.0
## The state's position is the player's body origin, and the body's capsule
## (player_controller.gd: 1.2 m tall, its middle 0.95 up) stands with its bottom this far
## above it: drawn at the origin they stood knee-deep in the ground (playtest 18. 10.).
const FEET_Y := 0.35
const FOOTSTEPS := "res://assets/sfx/grassfootsteps.mp3"

var model := 1
var color := 0
## Placed by hand (a room's copy): no network states, no steps.
var manual := false
var pose := "stand"
var _sprite: Sprite3D
var _shadow: MeshInstance3D
var _beam: SpotLight3D
var _halo: SpotLight3D
var _lens: Sprite3D
var _steps: AudioStreamPlayer3D
var _buf: Array = []          # [{at: seconds, s: state}]
var _time := 0.0
var _speed := 0.0
var _ready_once := false
var _work_phase := 0.0
## Seen from eight sides (null while the warden has no set: the old sprite from the front).
var _doom: DOOM = null
var _view_acc := 0.0
var _last_pos := Vector3.INF
var _walked := 0.0
## Where a room's copy faces (show_at), zero: toward the one looking.
var _face := Vector3.ZERO
## Standing still this long (seconds), and when the idle is next due.
var _still := 0.0
var _idle_from := 0.0
const IDLE_EVERY := 9.0


func setup(p_model: int, p_color: int, p_manual := false) -> void:
	name = "OtherWarden"
	manual = p_manual
	add_to_group("coop_remote_player")
	_sprite = Sprite3D.new()
	_sprite.name = "Sprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.double_sided = true
	add_child(_sprite)
	_shadow = MeshInstance3D.new()
	_shadow.name = "BlobShadow"
	var q := QuadMesh.new()
	q.size = Vector2(0.75, 0.42)
	q.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	q.material = sm
	_shadow.mesh = q
	_shadow.position = Vector3(0.0, 0.03, 0.0)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	# Their torch: the same beam and halo as yours (player_controller.gd), a little
	# weaker seen from outside, and the bulb itself when it points your way.
	_beam = SpotLight3D.new()
	_beam.name = "TorchBeam"
	_beam.light_color = Color(1.0, 0.94, 0.82)
	_beam.light_energy = 2.4
	_beam.spot_range = 16.0
	_beam.spot_angle = 19.0
	_beam.spot_attenuation = 0.95
	_beam.shadow_enabled = false
	_beam.visible = false
	add_child(_beam)
	_halo = SpotLight3D.new()
	_halo.name = "TorchHalo"
	_halo.light_color = Color(1.0, 0.92, 0.8)
	_halo.light_energy = 0.34
	_halo.spot_range = 7.0
	_halo.spot_angle = 34.0
	_halo.shadow_enabled = false
	_halo.visible = false
	add_child(_halo)
	_lens = Sprite3D.new()
	_lens.name = "TorchLens"
	_lens.texture = _lens_texture()
	_lens.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lens.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_lens.shaded = false
	_lens.transparent = true
	_lens.pixel_size = 0.02
	_lens.visible = false
	add_child(_lens)
	if not manual:
		_steps = AudioStreamPlayer3D.new()
		_steps.name = "Steps"
		var st: AudioStream = load(FOOTSTEPS) if ResourceLoader.exists(FOOTSTEPS) else null
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_steps.stream = st
		_steps.unit_size = 3.0
		_steps.max_distance = 26.0
		_steps.volume_db = -80.0
		_steps.position = Vector3(0.0, 0.2, 0.0)
		add_child(_steps)
	set_look(p_model, p_color)
	visible = false


## Who they are and their jacket (they chose it on the CO-OP page).
func set_look(p_model: int, p_color: int) -> void:
	model = p_model
	color = p_color
	var set := LOOKS.figure_set(model)
	if set.is_empty():
		if _doom != null:
			_doom.release()
			_sprite.remove_meta("doom")
		_doom = null
	elif _doom == null or _doom.data != set:
		_doom = DOOM.new(_sprite, set, SPRITE_HEIGHT_M * FIGURE_SCALE, LOOKS.atlas(model, color))
		# Seated (not on their feet) at full size, as their old pictures are.
		for a in (set.get("anims", {}) as Dictionary):
			if not (str(a) in STANDING or str(a) in ["walk", "run", "idle"]):
				_doom.anim_k[a] = 1.0 / FIGURE_SCALE
	else:
		_doom.set_texture(LOOKS.atlas(model, color))
	_apply_pose(pose, true)


func _apply_pose(p: String, force := false) -> void:
	if p == pose and not force and _sprite.texture != null:
		return
	pose = p
	if _doom != null:
		# Standing, or a pose drawn from every side (sweeping, at the spanner, sat): the
		# figure's own; another pose its old picture from the front.
		if pose == "stand" or _doom.has_anim(pose):
			if not _doom.held():
				_doom.restore()
			_doom.set_anim(pose)
			_sprite.rotation.z = 0.0
			_sprite.position = Vector3.ZERO
			_shadow.visible = not (pose in ["row", "bed", "bedfoot", "write"])
			return
		_doom.release()
	var tex := LOOKS.texture(model, color, pose)
	_sprite.texture = tex
	if tex != null:
		if POSE_WIDTH.has(pose):
			_sprite.pixel_size = float(POSE_WIDTH[pose]) / float(tex.get_width())
		else:
			var k := FIGURE_SCALE if pose in STANDING else 1.0
			_sprite.pixel_size = float(POSE_HEIGHT.get(pose, SPRITE_HEIGHT_M)) * k / float(tex.get_height())
		_sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	# Seated in the boat the hull is their shadow; in bed and at the counter, the furniture.
	_shadow.visible = not (pose in ["row", "bed", "bedfoot", "write"])


## A small round glow, drawn once: the bulb of the torch seen from in front.
static func _lens_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length()
			var a := clampf(1.0 - d / 4.0, 0.0, 1.0)
			# Stepped, like the game's other glows (no smooth bloom).
			a = floorf(a * 4.0) / 4.0
			img.set_pixel(x, y, Color(1.0, 0.95, 0.8, a))
	return ImageTexture.create_from_image(img)


## One state from the other machine: {p: Vector3, y: yaw, d: torch direction, t: torch
## on, v: speed, in: inside something, boat: [Transform3D] while rowing}.
func push_state(s: Dictionary) -> void:
	_buf.append({"at": Time.get_ticks_msec() / 1000.0, "s": s})
	while _buf.size() > 16:
		_buf.pop_front()


## A room's copy: stand at `pos` (the room's own world), in `p_pose`, facing `face` (their
## torch aims there, and seen from eight sides they turn that way; none given: toward you).
func show_at(pos: Vector3, p_pose: String, torch_on := false, face := Vector3.ZERO) -> void:
	visible = true
	global_position = pos
	_apply_pose(p_pose)
	_face = face
	_beam.visible = torch_on
	_halo.visible = torch_on
	if torch_on:
		var aim := face if face.length_squared() > 0.0001 else Vector3.FORWARD
		var up := Vector3.UP if absf(aim.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		var xf := Transform3D(Basis.looking_at(aim.normalized(), up), Vector3(0.0, 1.2, 0.0))
		_beam.transform = xf
		_halo.transform = xf


func _process(delta: float) -> void:
	_time += delta
	if manual:
		_animate_work(delta)
		return
	if _buf.is_empty():
		visible = false
		return
	var now := Time.get_ticks_msec() / 1000.0 - DELAY
	var a: Dictionary = _buf[0]
	var b: Dictionary = _buf[_buf.size() - 1]
	for i in range(_buf.size() - 1):
		if float(_buf[i]["at"]) <= now and float(_buf[i + 1]["at"]) >= now:
			a = _buf[i]
			b = _buf[i + 1]
			break
	var sa: Dictionary = a["s"]
	var sb: Dictionary = b["s"]
	var span := float(b["at"]) - float(a["at"])
	var f := clampf((now - float(a["at"])) / span, 0.0, 1.0) if span > 0.0001 else 1.0
	if sb.has("boat") and sb["boat"] is Transform3D:
		# Rowing: seated on the boat's thwart (coop.gd moves this machine's boat too),
		# pulling on the oars while the boat goes.
		var boat: Transform3D = sb["boat"]
		var was: Transform3D = sa["boat"] if sa.get("boat") is Transform3D else boat
		var going := was.origin.distance_to(boat.origin) / maxf(span, 0.05) > 0.3
		visible = true
		_apply_pose("row")
		# On the aft thwart of this machine's boat (it goes where theirs does and rides the
		# swell: scripts/lake/boat_rig.gd), boots on the bottom boards.
		global_transform = Transform3D(Basis(), _seat_in_boat(boat, BOAT_RIG.ROWER_FEET))
		var rp = sb.get("rp", [])
		_animate_row(going, float(rp[0]) if rp is Array and (rp as Array).size() >= 4 else -2.0,
			int(rp[2]) if rp is Array and (rp as Array).size() >= 4 else 1)
		_beam.visible = false
		_halo.visible = false
		_lens.visible = false
		_update_steps(true)
		return
	if sb.get("ride") is Transform3D:
		# A passenger on the bow seat of your boat, facing you.
		visible = true
		_apply_pose("sit")
		global_transform = Transform3D(Basis(), _seat_in_boat(sb["ride"] as Transform3D, BOAT_RIG.BOW_FEET))
		_sprite.position = Vector3.ZERO
		_sprite.rotation.z = 0.0
		_shadow.visible = false
		_beam.visible = false
		_halo.visible = false
		_lens.visible = false
		_update_steps(true)
		return
	if bool(sb.get("dn", false)):
		# Knocked down: lying where they fell, face in the grass.
		visible = true
		global_position = sb.get("p", global_position)
		_apply_pose("prone")
		_sprite.position = Vector3.ZERO
		_sprite.rotation.z = 0.0
		_beam.visible = false
		_halo.visible = false
		_lens.visible = false
		_update_steps(true)
		return
	if sb.has("att"):
		# In an attraction: where this machine's attraction puts them (warden_play.gd).
		var wp := get_tree().get_first_node_in_group("warden_play")
		var place: Dictionary = wp.mate_place(int(get_meta("coop_id", 0))) if wp != null else {}
		if not place.is_empty():
			visible = true
			global_position = place["pos"]
			_apply_pose(str(place["pose"]))
			_sprite.flip_h = bool(place["flip"])
			_sprite.rotation.z = float(place["rz"])
			_sprite.position = Vector3.ZERO
			var cam := get_viewport().get_camera_3d()
			if _doom != null and _doom.held() and cam != null:
				_doom.set_anim(pose)
				_doom.show(cam.global_position)
			_shadow.visible = bool(place["ground"]) and pose in ["stand", "kick", "bat"]
			_beam.visible = false
			_halo.visible = false
			_lens.visible = false
			_update_steps(true)
			return
	var lift := Vector3(0.0, FEET_Y, 0.0)
	var pa: Vector3 = sa.get("p", global_position - lift) + lift
	var pb: Vector3 = sb.get("p", pa - lift) + lift
	if pa.distance_to(pb) > SNAP_DIST:
		f = 1.0
	var inside := bool(sb.get("in", false))
	visible = not inside
	# At work out in the camp (hold R at a lamp, a branch sawn, rubbish bagged) or fishing
	# on the far shore: that, where they stand.
	var act := str(sb.get("act", ""))
	_apply_pose(act if act != "" else "stand")
	global_position = pa.lerp(pb, f) if _ready_once else pb
	_ready_once = true
	_speed = lerpf(_speed, float(sb.get("v", 0.0)), clampf(delta * 10.0, 0.0, 1.0))
	if _doom != null and _doom.held():
		_doom.yaw = lerp_angle(float(sa.get("y", 0.0)), float(sb.get("y", 0.0)), f)
		_walk_doom(delta, pa.distance_to(pb) > SNAP_DIST)
	elif act != "":
		_animate_act(act)
	else:
		_animate()
	_aim_torch(sb, inside)
	_update_steps(inside)


## At work in the camp: the spanner turning, the saw going, a bend for the rubbish, the
## rod held still (a twitch now and then), in steps.
func _animate_act(act: String) -> void:
	var step := floorf(_time * ANIM_FPS)
	var ph := step / ANIM_FPS * TAU
	_sprite.flip_h = false
	match act:
		"saw":
			_sprite.position = Vector3(sin(ph * 1.6) * 0.04, 0.0, 0.0)
			_sprite.rotation.z = sin(ph * 1.6) * 0.03
		"fix":
			_sprite.position = Vector3(0.0, 0.01 if int(step / 3.0) % 2 == 0 else 0.0, 0.0)
			_sprite.rotation.z = sin(ph * 0.9) * 0.02
		"bag":
			_sprite.position = Vector3(0.0, -0.03 if int(step / 5.0) % 2 == 0 else 0.0, 0.0)
			_sprite.rotation.z = 0.0
		_:
			_sprite.position = Vector3.ZERO
			_sprite.rotation.z = 0.01 if int(step / 23.0) % 7 == 0 else 0.0


## Seen from eight sides: walking or running in the frames of the ground they covered
## (a jump through a door covers none), the picture for where you look from, in steps.
func _walk_doom(delta: float, jumped: bool) -> void:
	var here := global_position
	var step := Vector2(here.x - _last_pos.x, here.z - _last_pos.z).length() if _last_pos != Vector3.INF else 0.0
	if not jumped and step < 2.0:
		_walked += step
	_last_pos = here
	_view_acc += delta
	if _view_acc < 1.0 / VIEW_FPS:
		return
	_view_acc = 0.0
	if pose != "stand" and _doom.has_anim(pose):
		_doom.set_anim(pose)
		_still = 0.0
	elif _speed > 0.4:
		_doom.set_anim("run" if _speed > RUN_SPEED else "walk")
		_still = 0.0
	else:
		# Standing a while: a glance at the watch now and then (the idle, once through).
		_still += 1.0 / VIEW_FPS
		if _doom.anim == "idle":
			if not _doom.idle_at(_still - _idle_from):
				_doom.set_anim("stand")
				_idle_from = _still + IDLE_EVERY
		else:
			_doom.set_anim("stand")
			if _idle_from <= 0.0 or _still < 0.2:
				_idle_from = IDLE_EVERY
			if _doom.has_anim("idle") and _still >= _idle_from:
				_doom.set_anim("idle")
				_idle_from = _still
				_doom.idle_at(0.0)
	_doom.advance(_walked)
	_walked = 0.0
	# A little lift on the frames between the steps (the legs together), no sway, no flip.
	_sprite.rotation.z = 0.0
	_sprite.position = Vector3(0.0, 0.015 if _doom.anim in ["walk", "run"] and _doom.frame % 2 == 1 else 0.0, 0.0)
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		_doom.show(cam.global_position)


## The guests' walk: steps at ANIM_FPS, a bob, a sway, the flip on each step.
func _animate() -> void:
	if _sprite == null:
		return
	if _speed > 0.4:
		var phase := floorf(_time * ANIM_FPS) / ANIM_FPS * WALK_BOB_HZ * TAU * clampf(_speed / 3.9, 0.7, 1.4)
		_sprite.position.y = absf(sin(phase)) * 0.06
		_sprite.flip_h = sin(phase * 0.5) > 0.0
		_sprite.rotation.z = sin(phase) * 0.04
	else:
		_sprite.position.y = 0.0
		_sprite.rotation.z = sin(floorf(_time * ANIM_FPS) / ANIM_FPS * 0.8) * 0.01


## In the boat: leaning into each stroke as their oars go (`u` the stroke's phase they
## sent, boat_rig.gd; -2 when they sent none: in steps while the boat goes), in steps.
func _animate_row(going: bool, u := -2.0, dir := 1) -> void:
	_sprite.rotation.z = 0.0
	_sprite.flip_h = false
	if u > -1.5:
		var lean := 0.0
		if u >= 0.0 and u < BOAT_RIG.RELEASE:
			lean = sin(PI * u / BOAT_RIG.RELEASE) * float(dir)
		_sprite.position.y = -0.04 * floorf(absf(lean) * 4.0) / 4.0
		return
	if not going:
		_sprite.position.y = 0.0
		return
	var ph := floorf(_time * ANIM_FPS) / ANIM_FPS * 0.8 * TAU
	_sprite.position.y = -0.05 * (0.5 + 0.5 * sin(ph))


var _lake_cache: Node


## A seat of the boat as this machine has it (its hull rocking under them), or of the boat
## as their state put it when there is none here.
func _seat_in_boat(state_xf: Transform3D, seat: Vector3) -> Vector3:
	if _lake_cache == null or not is_instance_valid(_lake_cache):
		_lake_cache = get_tree().root.find_child("CampLake", true, false)
	var boat = _lake_cache.get("boat") if _lake_cache != null else null
	var rig = (boat as Node).get_node_or_null("BoatRig") if boat != null and is_instance_valid(boat) else null
	if rig != null and rig.get("hull") != null:
		return (rig.hull as Node3D).global_transform * seat
	return state_xf * seat


## A room's copy walking (through the office's doorways): the stepped walk.
var _manual_walk := false


func set_walking(on: bool) -> void:
	_manual_walk = on


func set_flip(on: bool) -> void:
	if _doom != null and _doom.held():
		return
	if _sprite != null:
		_sprite.flip_h = on


## At a job: the broom or the brush going, in steps (a push and back, the flip).
func _animate_work(_delta: float) -> void:
	if _sprite == null:
		return
	if _doom != null and _doom.held():
		_room_doom(_delta)
		return
	if _manual_walk:
		_speed = 2.2
		_sprite.position.x = 0.0
		_animate()
		return
	if pose == "bed":
		# Asleep: only the breath, in steps.
		_sprite.rotation.z = 0.0
		_sprite.position = Vector3(0.0, 0.01 if int(floorf(_time * 0.4 * 2.0)) % 2 == 0 else 0.0, 0.0)
		return
	if pose == "write":
		# The pen going along the line and back to the start of the next.
		var st := floorf(_time * ANIM_FPS)
		_sprite.position = Vector3(fposmod(st, 16.0) / 16.0 * 0.03, 0.0, 0.0)
		_sprite.rotation.z = 0.0
		return
	if pose == "sweep" or pose == "crouch":
		var step := floorf(_time * ANIM_FPS)
		var hz := 1.8 if pose == "sweep" else 3.0
		var ph := step / ANIM_FPS * hz * TAU
		_sprite.position.x = sin(ph) * (0.05 if pose == "sweep" else 0.03)
		_sprite.rotation.z = sin(ph) * (0.05 if pose == "sweep" else 0.03)
		_sprite.flip_h = int(step / 6.0) % 2 == 1 and pose == "crouch"
	else:
		_sprite.position.x = 0.0
		_sprite.rotation.z = sin(floorf(_time * ANIM_FPS) / ANIM_FPS * 0.8) * 0.01


## A room's copy seen from eight sides: walking (through the office's doorways) the way
## they go, else facing the job they are at (show_at's face) or you.
func _room_doom(delta: float) -> void:
	var here := global_position
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var moved := Vector3.ZERO
	if _last_pos != Vector3.INF:
		moved = here - _last_pos
		moved.y = 0.0
	_last_pos = here
	if moved.length() > 1.0:
		moved = Vector3.ZERO
	_walked += moved.length()
	if _manual_walk and moved.length() > 0.0005:
		_doom.turn_toward(moved, PI)
	elif not _manual_walk:
		if _face.length_squared() > 0.0001:
			_doom.face(_face)
		elif cam != null:
			_doom.face(cam.global_position - here)
	_view_acc += delta
	if _view_acc < 1.0 / VIEW_FPS:
		return
	_view_acc = 0.0
	_doom.set_anim("walk" if _manual_walk else (pose if _doom.has_anim(pose) else "stand"))
	_doom.advance(_walked)
	_walked = 0.0
	_sprite.rotation.z = 0.0
	_sprite.position = Vector3.ZERO
	if cam != null:
		_doom.show(cam.global_position)


func _aim_torch(s: Dictionary, inside: bool) -> void:
	var on := bool(s.get("t", false)) and not inside
	_beam.visible = on
	_halo.visible = on
	_lens.visible = false
	if not on:
		return
	var dir: Vector3 = s.get("d", Vector3.FORWARD)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	# The torch in their right hand, a little in front of them at chest height.
	var yaw := float(s.get("y", 0.0))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var hand := Vector3(0.0, 1.2, 0.0) + right * 0.28 + Vector3(-sin(yaw), 0.0, -cos(yaw)) * 0.2
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var xf := Transform3D(Basis.looking_at(dir, up), hand)
	_beam.transform = xf
	_halo.transform = xf
	# The bulb shows when the beam comes your way.
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		var to_cam := (cam.global_position - (global_position + hand)).normalized()
		if dir.dot(to_cam) > 0.55:
			_lens.visible = true
			_lens.position = hand + dir * 0.12
			_lens.modulate.a = clampf((dir.dot(to_cam) - 0.55) / 0.3, 0.3, 1.0)


func _update_steps(inside: bool) -> void:
	if _steps == null or _steps.stream == null:
		return
	var walking := _speed > 0.4 and not inside
	if walking and not _steps.playing:
		_steps.play()
	_steps.volume_db = lerpf(-24.0, -4.0, clampf(_speed / 5.2, 0.0, 1.0)) if walking else -80.0
	_steps.pitch_scale = lerpf(0.95, 1.08, clampf(_speed / 5.2, 0.0, 1.0))
	if not walking and _steps.playing and _steps.volume_db <= -79.0:
		_steps.stop()
