extends "res://scripts/enemies/enemy_base.gd"

## The mushroom granny (Mushroom Pickers; DESIGN §5a.4, reworked with the user 2. 11.:
## "ví kde jsi a furt tě loví venku, a když zalezeš dovnitř jde postupně lovit tvoje hosty
## a žrát je"). The old picker of the day, turned in the small hours (02:30-06:00): the
## mushrooms have grown through her, caps where her eyes were and in her mouth, skin like
## bark and mould; bent like a hook she hunts, straightened she is far too tall. She never
## says a word: her basket creaks, she hums, her back cracks, she breathes.
##
## Out there she always knows where the warden she hunts is (in co-op coop_night.gd aims
## her at one who is outside):
##   hunt    bent double and quick, straight at you round the buildings (the hands' ways,
##           staff_runtime.way): a little under your walk at first, over it once she has
##           eaten. Keep moving.
##   look    now and then she stops dead, her back cracks and she straightens up, far too
##           tall, and looks: move in her sight and she comes at a run; stand still and
##           she stands over you a while, looking, then turns away a few steps and comes
##           on again.
##   strike  in reach: the knife at your ankles, you go down in the grass, she leans over
##           you and goes off to eat (FED_SEC). You limp a while (slower, no sprint). Two
##           or three of them and you are dead.
##   lamps   she never steps into a lamp's light. A lamp in her way she puts out: at the
##           edge of its light she straightens and her arm reaches up to the bulb, far too
##           long, slowly; then it is dark and she is there. The bulbs go in her basket.
## Hidden (a building, the lake, a minigame) and she goes for the guests, lodging by lodging:
##   ring    the lodging she means to have next has a ring of mushrooms coming up round
##           it; walk through it and it is kicked open, and she must plant it again there
##           first, round the lodging, bent.
##   breach  a tent she slits in seconds; a cabin's or a caravan's door she prises at much
##           longer. They wake: the light comes on inside.
##   eat     inside, unseen: the light goes out, a cry cut off, the munching, one party
##           after another, heard from out there, through the walls, and on the office
##           radio as it happens. Every one eaten she is worse (stages: taller, fuller,
##           bloodier, quicker).
##   out     step outside and she leaves the ones she was on (cut, alive: gone in the
##           morning with one star) and comes for you.
## Morning (dawn(), from main._claim_turned_guests): where she ate the lodging is hers to
## clean (GuestManager.make_room_carnage), those who lived through it leave, and a
## relative writes a day or two later.

const FIGURE = preload("res://scripts/figures/doom_figure.gd")
const WORLD_SOUNDS = preload("res://scripts/ambient/world_sounds.gd")

const N := "res://assets/textury/npc/"
## Her pictures, stage by stage: eight views (tools/artgen/figures.py), or until they are
## drawn the old two pictures.
const SETS := ["babka_s0", "babka_s1", "babka_s2"]
const OLD_BENT := N + "granny_pick.png"
const OLD_UP := N + "granny_up.png"
## Her two pictures from the front (Grok, from npc/host_pensioner.png) while the eight
## views are not drawn; the old ones before them.
const BENT := N + "babka_bent.png"
const UP := N + "babka_up.png"
const FACES := [N + "babka_face_s0.png", N + "babka_face_s1.png", N + "babka_face_s2.png"]
const OLD_FACE := N + "granny_face.png"
## The arm that reaches up to a bulb, drawn along its length (shoulder at the bottom).
const ARM := N + "babka_arm.png"
const MUSHROOM := "res://assets/textury/world/fly_agaric.png"

const S := "res://assets/sfx/npc/babka/"
const G := "res://assets/sfx/npc/granny/"
const STEPS := [S + "step_grass_a.mp3", S + "step_grass_b.mp3", S + "step_grass_c.mp3", S + "step_grass_d.mp3"]
const SFX := {
	"breath": S + "breath.mp3", "sniff": S + "sniff.mp3", "crack": S + "crack.mp3", "lunge": S + "lunge.mp3",
	"tendon": S + "tendon.mp3", "fall": S + "fall.mp3", "reach": S + "reach.mp3", "lamp_die": S + "lamp_die.mp3",
	"bulb": G + "bulb.mp3", "zip": S + "tent_zip.mp3", "tear": S + "tent_tear.mp3", "pry": S + "door_pry.mp3",
	"break": S + "door_break.mp3", "cry_m": S + "cry_m.mp3", "cry_f": S + "cry_f.mp3", "eat_a": S + "eat_a.mp3",
	"eat_b": S + "eat_b.mp3", "bone": S + "bone.mp3", "spores": S + "spores.mp3", "leave": S + "leave.mp3",
	"hum": G + "hum.mp3", "ring": G + "ring.mp3", "creak": "res://assets/sfx/npc/basket_creak.mp3",
	"kick": "res://assets/sfx/npc/twig_snap.mp3",
}

const FROM_HOUR := 2.5
const TO_HOUR := 6.0
## Her height bent over (hunting) and straightened, before the stages add to it.
const BENT_M := 1.75
const UP_M := 3.0
const STAGE_K := [1.0, 1.07, 1.15]
## Guests (heads) eaten for each stage.
const STAGE_AT := [1, 3]
## Your walk is 3.9 m/s, a sprint 5.2 for ~7 s: a little under the walk at first, over it
## fed. Quicker still the nearer dawn.
const HUNT_SPEED := [3.3, 3.7, 4.15]
const LUNGE_SPEED := 7.2
const LUNGE_SEC := 2.4
const GO_SPEED := [2.8, 3.1, 3.4]
## The stop: every LOOK_EVERY seconds (nearer, more often) she straightens for LOOK_SEC.
const LOOK_EVERY := Vector2(6.0, 12.0)
const LOOK_NEAR := Vector2(3.5, 7.0)
const LOOK_SEC := Vector2(1.8, 3.0)
const LOOK_SEE := 30.0
## The crack, and her straightening up: you have this long to stop before she sees.
const LOOK_GRACE := 0.5
## Seconds of you moving in her sight before she comes; what counts as moving.
const NOTICE := 0.22
const MOVING := 0.6
const STARE_NEAR := 3.6
const STARE_SEC := 2.8
const TURN_AWAY_SEC := 2.6
const REACH_M := 1.45
## A catch, by the night's difficulty 1..5 (100 health: two or three of them).
const HIT := Vector2i(38, 52)
const STRIKE_SEC := 2.3
const LIMP_SEC := 26.0
const LIMP_MULT := 0.55
const FED_SEC := 16.0
## Light at you at which she will not come on (a lamp), and the light she will not step in.
const LAMP_SAFE := 0.35
const LAMP_EDGE := 0.24
const REACH_LAMP_SEC := [5.0, 4.3, 3.6]
## The bulb on a lamp post: up its pole and out along its arm (building_manager).
const BULB_UP := 3.1
## Hidden this long and she turns to the guests.
const HIDDEN_SEC := 4.0
## At a lodging: breaching it (by kind), each head inside, leaving it when you came out.
const BREACH_SEC := {"tent": 3.0, "caravan": 10.0, "cabin": 15.0}
const EAT_SEC := [9.0, 7.5, 6.0]
const INTERRUPT_SEC := 1.8
## Rings: mushrooms round the lodging she means to have next.
const RING_N := 12
const RING_R := 2.8
const RING_GROW_SEC := 28.0
const RING_PLANT_SEC := 5.5
const RING_KICKED := 3

var _hit := 44
var _phase := "away"
var _phase_t := 0.0
var _look_len := 2.0
var _next_look := 8.0
var _noticed := 0.0
var _stage := 0
## Heads eaten tonight, and who: [{id, name, archetype, party}].
var _eaten := 0
var _eaten_guests: Array = []
## Guests she was on when you came out (they leave in the morning), and the lodgings she
## ate in ("x:y").
var _cut_ids: Array = []
var _ate_in: Dictionary = {}
var _fed_until := -1.0
var _hidden_t := 0.0
var _limp_until := -1.0
var _limping := false
var _strike_t := -1.0
var _speed := 0.0
var _last_pos := Vector3.INF
var _dir := Vector3.FORWARD
## The way she walks now (staff_runtime.way), where along it, and to where.
var _path := PackedVector3Array()
var _path_i := 0
var _path_goal := Vector3.INF
var _path_t := 0.0
var _staff_rt: Node
## The lodging she is going for: {key, at, kind, door, guests: [ids], i, t}.
var _target := {}
var _interrupt_t := 0.0
## The lamp she is putting out: {foot, bulb, t, len}.
var _lamp := {}
## The lamps she took tonight (where they stand), in her basket.
var bulbs: Array = []
## "x:y" -> {center, nodes: [Sprite3D], grown 0..1, kicked}.
var rings: Dictionary = {}
var _mark := ""
## Her eight views (FIGURE.set_of), the way she faces, the picture shown.
var _fig: Dictionary = {}
var _fig_yaw := 0.0
var _fig_sector := 0
var _fig_anim := "walk"
var _fig_frame := 0
var _fig_dist := 0.0
var _atlas: Dictionary = {}
var _tex_bent: Texture2D
var _tex_up: Texture2D
var _tall_old := false
var _tex_face: Array = []
var _arm: Sprite3D
var _streams: Dictionary = {}
var _hum: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _spores: AudioStreamPlayer3D
var _work: AudioStreamPlayer3D
var _in_room: AudioStreamPlayer
var _in_next := 0.0
var _step_dist := 0.0
var _step_i := 0
var _creak_t := 0.0
var _bone_t := 0.0
var _relaying := false
## Tests: she is out whatever the hour.
var soon := false


func get_enemy_id() -> String:
	return "basket"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(float(HIT.x), float(HIT.y), t))
	_tex_bent = load(BENT if ResourceLoader.exists(BENT) else OLD_BENT) as Texture2D
	_tex_up = load(UP if ResourceLoader.exists(UP) else OLD_UP) as Texture2D
	_tall_old = not ResourceLoader.exists(UP)
	# Each stage's face, else the nearest one drawn before it, else the old one.
	var last := OLD_FACE
	for i in FACES.size():
		if ResourceLoader.exists(FACES[i]):
			last = FACES[i]
		_tex_face.append(load(last) as Texture2D)
	# Everything she can show or sound now, not at the first use (no hitch).
	for k in SFX:
		_stream(str(SFX[k]))
	for p in STEPS:
		_stream(str(p))
	for i in SETS.size():
		FIGURE.set_of(SETS[i])
	_body = _make_body(OLD_BENT, BENT_M)
	_body.visible = false
	_set_stage(0)
	_make_eyes("basket", 1.35).set("x_off", 0.0)
	_arm = Sprite3D.new()
	_arm.texture = load(ARM) as Texture2D if ResourceLoader.exists(ARM) else null
	_arm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_arm.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_arm.shaded = true
	_arm.double_sided = true
	_arm.visible = false
	_root.add_child(_arm)
	# The loops (looped on their own resource: co-op mirrors a sound by its path).
	for k in ["eat_a", "eat_b", "pry"]:
		var s := _stream(SFX[k])
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
	_hum = _loop(SFX["hum"], -6.0)
	_breath = _loop(SFX["breath"], -4.0)
	_spores = _loop(SFX["spores"], -10.0)
	for p in [_hum, _breath, _spores]:
		_hold(p, false)
	if _breath != null:
		_breath.max_distance = 12.0
	if _spores != null:
		_spores.max_distance = 9.0
	_work = AudioStreamPlayer3D.new()
	_work.unit_size = 5.0
	_work.max_distance = 45.0
	_root.add_child(_work)
	_in_room = AudioStreamPlayer.new()
	_in_room.bus = WORLD_SOUNDS.wall_bus("Master")
	_root.add_child(_in_room)
	_fx()


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	_streams[path] = s
	return s


func _hour() -> float:
	var main := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 0.0


func _out_now() -> bool:
	var h := _hour()
	return soon or (h >= FROM_HOUR and h <= TO_HOUR)


# ── the night's tick: out there or hidden, she goes on ───────────────────────

## The base ticks nothing while the warden she hunts is indoors; she does (the guests).
func tick(delta: float) -> void:
	if not _night_active or _world_root == null or not is_instance_valid(_world_root):
		return
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	if _is_night_callable.is_valid() and not bool(_is_night_callable.call()):
		return
	var dt := maxf(delta, 0.0)
	_elapsed += dt
	_tick_rings(dt)
	if not _out_now():
		if _phase != "away":
			_go_away()
		return
	if _phase == "away":
		_arrive()
	var out := _is_ready()
	_track_speed(dt)
	_tick_limp()
	if _strike_t >= 0.0:
		if out:
			_tick_strike(dt)
		else:
			_end_strike()
		_after(dt, out)
		return
	if out and _elapsed >= _fed_until:
		_hidden_t = 0.0
		_tick_out(dt)
	else:
		_hidden_t += dt
		_tick_hidden(dt, out)
	_after(dt, out)


func _after(dt: float, out: bool) -> void:
	_update_body(out)
	_update_sounds(dt, out)
	_update_senses(dt, out)
	if out:
		_tick_eyes(dt)
	elif _eyes != null:
		_eyes.call("_hide")


## Out comes the old picker, at the edge of the camp, far from you (or anywhere at its
## edge while you are in).
func _arrive() -> void:
	var p := Vector3.INF
	if _is_ready():
		p = _point_from_player(_rng.randf_range(24.0, 32.0), _rng.randf_range(-80.0, 80.0))
		if p == Vector3.INF:
			p = _point_from_player(24.0, 0.0)
	if p == Vector3.INF and _grid_manager != null and _grid_manager.has_method("get_map_size_world"):
		var c: Vector3 = _grid_manager.get_map_center_world()
		var s: Vector2 = _grid_manager.get_map_size_world()
		var a := _rng.randf() * TAU
		p = _ground(c + Vector3(cos(a) * s.x * 0.45, 0.0, sin(a) * s.y * 0.45))
	if p == Vector3.INF:
		p = _player_pos()
	_place_body(p)
	_announce("A basket creaking out of the trees. Somebody picking, at this hour.")
	_mark_next(p)
	_set_phase("hunt", 0.0)
	_next_look = _rng.randf_range(LOOK_EVERY.x, LOOK_EVERY.y)


## Dawn: she is going, back into the trees with her basket; the one she was on lives.
func _go_away() -> void:
	if _phase == "eat":
		_spare_current()
	if _body != null and _body.visible:
		_sound(SFX["leave"], _body.global_position + Vector3(0, 1.0, 0), 0.0, 1.0, 40.0)
	_set_phase("away", 0.0)
	_relay(false)
	_force_window(str(_target.get("key", "")), "")
	_target = {}
	_end_strike()
	for p in [_hum, _breath, _spores]:
		_hold(p, false)
	_clear_rings()


# ── out there: the hunt ───────────────────────────────────────────────────────

func _tick_out(dt: float) -> void:
	# Back from a lodging when you came out: she leaves it (the ones inside live).
	if _phase in ["go", "plant", "breach", "eat", "out"]:
		if _phase == "eat":
			_interrupt_t += dt
			if _interrupt_t < INTERRUPT_SEC:
				_tick_eat(dt)
				return
			_spare_current()
		_come_out()
	var d := _distance_to_player(_body.global_position)
	match _phase:
		"hunt", "turn":
			if _phase == "turn":
				_phase_t -= dt
				_walk_to(_body.global_position + (_body.global_position - _player_pos()).normalized() * 3.0, HUNT_SPEED[_stage] * 0.6, dt)
				if _phase_t <= 0.0:
					_set_phase("hunt", 0.0)
				return
			if _player_lit():
				_lamp_or_wait(dt)
				return
			if d <= REACH_M:
				_start_strike()
				return
			_next_look -= dt
			if _next_look <= 0.0 and d > 2.2:
				_set_phase("look", _rng.randf_range(LOOK_SEC.x, LOOK_SEC.y) * (0.85 if _stage >= 2 else 1.0))
				return
			_come_on(_speed_now(), dt)
		"look":
			_phase_t -= dt
			_face_toward(_player_pos())
			# Straightening up takes her a moment (the crack is your warning): then she sees.
			var up_for := _look_len - _phase_t
			if up_for >= LOOK_GRACE and _quarry_moving() and d < LOOK_SEE and _sees_quarry():
				_noticed += dt
				if _noticed >= NOTICE:
					_set_phase("lunge", LUNGE_SEC)
					return
			if _phase_t <= 0.0:
				if d <= STARE_NEAR:
					_set_phase("stare", STARE_SEC)
				else:
					_set_phase("hunt", 0.0)
		"stare":
			# Over you, looking down at you: still, and she lets you be a moment.
			_phase_t -= dt
			_face_toward(_player_pos())
			if _quarry_moving():
				if d <= REACH_M + 0.6:
					_start_strike()
				else:
					_set_phase("lunge", LUNGE_SEC)
				return
			if _phase_t <= 0.0:
				_set_phase("turn", TURN_AWAY_SEC)
		"lunge":
			_phase_t -= dt
			if _player_lit():
				_lamp_or_wait(dt)
				return
			if d <= REACH_M:
				_start_strike()
				return
			_come_on(LUNGE_SPEED, dt, 0.25)
			if _phase == "lunge" and _phase_t <= 0.0:
				_set_phase("hunt", 0.0)
		"reach":
			_tick_reach(dt, "hunt")
		_:
			_set_phase("hunt", 0.0)


func _speed_now() -> float:
	# The nearer dawn the hungrier.
	var k := clampf((_hour() - FROM_HOUR) / (TO_HOUR - FROM_HOUR), 0.0, 1.0) if not soon else 0.0
	return float(HUNT_SPEED[_stage]) * (1.0 + 0.06 * k)


func _sees_quarry() -> bool:
	var eye := _body.global_position + Vector3(0, UP_M * float(STAGE_K[_stage]) * 0.92, 0)
	return not _ray_blocked(eye, _player_pos() + Vector3(0, 1.2, 0))


## Is the warden she hunts moving? (A stand-in's own speed is only right 15 times a
## second: the warden state's "v".)
func _quarry_moving() -> bool:
	var peer := _quarry_peer()
	if peer != 0:
		var v = Coop.state_of(peer).get("v", 0.0)
		var sp := 0.0
		if v is Vector3:
			sp = Vector2((v as Vector3).x, (v as Vector3).z).length()
		elif v is Vector2:
			sp = (v as Vector2).length()
		else:
			sp = float(v)
		return sp > MOVING
	return _speed > MOVING


func _track_speed(dt: float) -> void:
	var p := _player_pos()
	if _last_pos != Vector3.INF and dt > 0.0:
		var flat := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / dt
		_speed = lerpf(_speed, flat, clampf(dt * 8.0, 0.0, 1.0))
	_last_pos = p


func _player_lit() -> bool:
	return _lamp_light_at(_player_pos()) >= LAMP_SAFE


# ── lamps ─────────────────────────────────────────────────────────────────────

## You are in a lamp's light: she goes to the edge of it and puts it out.
func _lamp_or_wait(dt: float) -> void:
	var foot := _lamp_for(_player_pos())
	if foot == Vector3.INF:
		_walk_to(_player_pos(), _speed_now(), dt)
		return
	var edge := _edge_of(foot)
	if Vector2(edge.x - _body.global_position.x, edge.z - _body.global_position.z).length() > 0.5 and _walk_to(edge, _speed_now(), dt) == GOING:
		return
	_start_reach(foot)


## Coming at you, the way to you: a lamp in her way she puts out.
func _come_on(speed: float, dt: float, replan := 0.7) -> void:
	if _walk_to(_player_pos(), speed, dt, replan) == LIT:
		var foot := _lamp_for(_body.global_position + _dir * 2.0)
		if foot != Vector3.INF:
			_start_reach(foot)


## The lit lamp nearest `p` whose light reaches it, or INF.
func _lamp_for(p: Vector3) -> Vector3:
	var bm = _building_manager
	if bm == null or not bm.has_method("lit_lamp_positions"):
		return Vector3.INF
	var best := Vector3.INF
	var best_d := 18.0
	for l in bm.call("lit_lamp_positions"):
		var lp: Vector3 = l
		var d := Vector2(lp.x - p.x, lp.z - p.z).length()
		if d < best_d:
			best_d = d
			best = lp
	return best


## Where the lamp at `foot` stops lighting, on her side of it.
func _edge_of(foot: Vector3) -> Vector3:
	var away := _body.global_position - foot
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var r := 2.0
	while r < 15.0:
		var q := foot + away * r
		if _lamp_light_at(q) < LAMP_EDGE:
			var g := _ground(q)
			return g if g != Vector3.INF else q
		r += 0.5
	return foot + away * 15.0


func _start_reach(foot: Vector3) -> void:
	var bulb := foot + Vector3(0, BULB_UP, 0)
	_lamp = {"foot": foot, "bulb": bulb, "t": 0.0, "len": float(REACH_LAMP_SEC[_stage])}
	_set_phase("reach", 0.0)
	_sound(SFX["reach"], _body.global_position + Vector3(0, 2.4, 0), 1.0, _rng.randf_range(0.92, 1.05), 30.0)


## The arm going up to the bulb; then the phase `then` (the hunt, or her way to a lodging).
func _tick_reach(dt: float, then: String) -> void:
	if _lamp.is_empty():
		_set_phase(then, 0.0)
		return
	_lamp["t"] = float(_lamp["t"]) + dt
	var t: float = _lamp["t"]
	var len: float = _lamp["len"]
	_face_toward(_lamp["bulb"])
	# You left the light (and it is not in her way to you): she lets it be and comes.
	if then == "hunt" and not _player_lit() and t < len * 0.75 and _lamp_light_at(_body.global_position + (_player_pos() - _body.global_position).normalized() * 1.2) < LAMP_EDGE:
		_arm.visible = false
		_lamp = {}
		_set_phase("hunt", 0.0)
		return
	var k := clampf(t / (len * 0.8), 0.0, 1.0)
	_show_arm(k)
	if t >= len:
		var bm = _building_manager
		if bm != null and bm.has_method("darken_lamp_near"):
			var at: Vector3 = bm.call("darken_lamp_near", _lamp["foot"], 2.0, 3600.0)
			if at != Vector3.INF:
				bulbs.append(at)
		_sound(SFX["bulb"], _lamp["bulb"], 0.0, 1.0, 30.0)
		_sound(SFX["lamp_die"], _lamp["bulb"], 2.0, 1.0, 35.0)
		_arm.visible = false
		_lamp = {}
		_set_phase(then, 0.0)
		_next_look = _rng.randf_range(LOOK_NEAR.x, LOOK_NEAR.y) + 2.0


## The arm from her shoulder up toward the bulb, `k` of the way (0..1), turned to you.
func _show_arm(k: float) -> void:
	if _arm.texture == null or _lamp.is_empty():
		return
	var h := UP_M * float(STAGE_K[_stage])
	var a := _body.global_position + Vector3(0, h * 0.82, 0)
	var b: Vector3 = a.lerp(_lamp["bulb"], k)
	var axis := b - a
	var length := axis.length()
	if length < 0.05:
		_arm.visible = false
		return
	var cam := _camera()
	var eye := cam.global_position if cam != null else _player_pos() + Vector3(0, 1.6, 0)
	var y := axis / length
	var x := y.cross((eye - (a + b) * 0.5).normalized())
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	var tex_h := float(_arm.texture.get_height())
	# As thick as a leg: thinner, at the lamp's edge it was a dark thread against the sky.
	_arm.pixel_size = 0.4 / float(_arm.texture.get_width())
	_arm.global_transform = Transform3D(Basis(x, y * (length / (tex_h * _arm.pixel_size)), z), (a + b) * 0.5)
	_arm.visible = true


# ── the strike ───────────────────────────────────────────────────────────────

func _start_strike() -> void:
	_strike_t = 0.0
	_set_phase("strike", 0.0)
	claimed = true
	_sound_quarry(SFX["tendon"], _player_pos() + Vector3(0, 0.2, 0), 3.0, 1.0, 10.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
		fx.tinnitus(2.2)
	_view_begin()


func _tick_strike(dt: float) -> void:
	_strike_t += dt
	var t := _strike_t
	var fx := _fx()
	if t >= 0.3 and t - dt < 0.3:
		_hurt(_hit)
		_sound_quarry(SFX["fall"], _player_pos() + Vector3(0, 0.2, 0), 2.0, 1.0, 10.0)
		if fx != null:
			fx.red_flash(0.55)
			fx.blood(0.5)
	if _player == null or not is_instance_valid(_player):
		return
	# Down in the grass, on your back: the sky, and her leaning over you.
	var down := clampf((t - 0.25) / 0.35, 0.0, 1.0)
	if not _view0.is_empty():
		_set_pitch(float(_view0["pitch"]) + lerpf(0.0, 0.95, down))
		_set_roll(float(_view0["roll"]) + lerpf(0.0, 0.32, down))
	if _quarry_peer() == 0 and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	if t >= 0.6 and fx != null:
		var k := clampf((t - 0.6) / 1.2, 0.0, 1.0)
		var st := floorf(k * 6.0) / 6.0
		fx.close_up(_tex_face[_stage], lerpf(0.9, 1.35, st), 1.0 + 0.08 * st, 0.004 + 0.01 * st, 0.0, Vector2(0, lerpf(0.12, -0.02, st)))
	if t >= 0.9 and t - dt < 0.9:
		_sound_quarry(SFX["sniff"], _player_pos() + Vector3(0, 1.0, 0), 2.0, 0.95, 8.0)
	if t >= STRIKE_SEC:
		_end_strike()
		_limp_until = _elapsed + LIMP_SEC
		# Off to eat, with you lying there: she has had her taste.
		_fed_until = _elapsed + FED_SEC
		_hidden_t = HIDDEN_SEC
		var p := _point_from_player(_rng.randf_range(5.0, 8.0), 180.0)
		if p != Vector3.INF:
			_place_body(p)
		_feed("A knife at your ankles, low in the grass.")
		_set_phase("hunt", 0.0)


func _end_strike() -> void:
	if _strike_t < 0.0:
		return
	_strike_t = -1.0
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.glitch(0.5, 0.5)
	if not _view0.is_empty():
		_set_pitch(float(_view0["pitch"]))
		_set_roll(float(_view0["roll"]))
	_view_end()
	if _quarry_peer() == 0 and _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", true)


## The ankle she cut: slower, no running, till it goes.
func _tick_limp() -> void:
	var on := _elapsed < _limp_until
	if on == _limping and not on:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if on:
		if "held_speed_mult" in _player:
			_player.set("held_speed_mult", LIMP_MULT)
		if _quarry_peer() == 0 and "stamina" in _player:
			_player.set("stamina", 0.0)
			_player.set("_stamina_locked", true)
	elif _limping and "held_speed_mult" in _player:
		_player.set("held_speed_mult", 1.0)
	_limping = on


# ── hidden: the guests ───────────────────────────────────────────────────────

func _tick_hidden(dt: float, _out: bool) -> void:
	match _phase:
		"go":
			_tick_go(dt)
		"reach_lodging":
			_tick_reach(dt, "go")
		"plant":
			_tick_plant(dt)
		"breach":
			_tick_breach(dt)
		"eat":
			_interrupt_t = 0.0
			_tick_eat(dt)
		"out":
			_phase_t -= dt
			if _phase_t <= 0.0:
				_next_lodging()
		"idle":
			# Nobody left to have: she waits, and looks again now and then.
			_phase_t -= dt
			if _phase_t <= 0.0:
				_next_lodging()
		_:
			if _phase == "reach":
				_arm.visible = false
				_lamp = {}
				_phase = "wait"
			if _hidden_t >= HIDDEN_SEC:
				_next_lodging()


## The lodging she has next: the one her ring is round, else the nearest with guests in.
func _next_lodging() -> void:
	var all := _lodgings()
	var here := _body.global_position
	var pick := {}
	var best := INF
	for l in all:
		var key := str(l["key"])
		if key == _quarry_room():
			continue
		var d := Vector2((l["at"] as Vector3).x - here.x, (l["at"] as Vector3).z - here.z).length()
		if key == _mark:
			d -= 1000.0
		if d < best:
			best = d
			pick = l
	if pick.is_empty():
		_target = {}
		_set_phase("idle", 3.0)
		return
	_target = pick.duplicate()
	_target["door"] = _door_of(pick)
	_target["i"] = 0
	_target["t"] = 0.0
	if _mark != str(pick["key"]):
		_mark = str(pick["key"])
	_set_phase("go", 0.0)


func _tick_go(dt: float) -> void:
	if _target.is_empty():
		_next_lodging()
		return
	var door: Vector3 = _target["door"]
	var went := _walk_to(door, float(GO_SPEED[_stage]), dt)
	# A lamp lights its door, or one is in her way: that one first.
	if went == LIT:
		var foot := _lamp_for(_body.global_position + _dir * 1.5)
		if foot != Vector3.INF:
			_start_reach(foot)
			_phase = "reach_lodging"
		return
	if went == THERE:
		var r: Dictionary = rings.get(str(_target["key"]), {})
		if r.is_empty() or bool(r.get("kicked", false)) or float(r.get("grown", 0.0)) < 1.0:
			_set_phase("plant", RING_PLANT_SEC)
		else:
			_start_breach()


## Round the lodging, bent, planting her ring where it was kicked open (or never grew).
func _tick_plant(dt: float) -> void:
	_phase_t -= dt
	var key := str(_target.get("key", ""))
	var c: Vector3 = _target.get("at", _body.global_position)
	var a := TAU * (1.0 - _phase_t / RING_PLANT_SEC)
	var p := _ground(c + Vector3(cos(a), 0, sin(a)) * (RING_R + 0.3))
	if p != Vector3.INF:
		_dir = (p - _body.global_position).normalized() if p.distance_to(_body.global_position) > 0.01 else _dir
		_body.global_position = p
		_fig_dist += 2.0 * dt
	_grow_ring(key, c, maxf(float((rings.get(key, {}) as Dictionary).get("grown", 0.0)), 1.0 - _phase_t / RING_PLANT_SEC), true)
	if _phase_t <= 0.0:
		_body.global_position = _ground(_target["door"]) if _ground(_target["door"]) != Vector3.INF else _target["door"]
		_start_breach()


func _start_breach() -> void:
	var kind := str(_target.get("kind", "tent"))
	_set_phase("breach", float(BREACH_SEC.get(kind, 12.0)) * (0.85 if _stage >= 2 else 1.0))
	_face_toward(_target["at"])
	var at: Vector3 = _target["door"]
	if kind == "tent":
		_sound(SFX["zip"], at + Vector3(0, 0.6, 0), 0.0, 1.0, 35.0)
	else:
		_play_work(SFX["pry"], at, 0.0)
	# They hear it: a light comes on inside.
	_force_window(str(_target["key"]), "on")


func _tick_breach(dt: float) -> void:
	_phase_t -= dt
	_face_toward(_target["at"])
	var kind := str(_target.get("kind", "tent"))
	if kind == "tent" and _phase_t < 2.0 and _phase_t + dt >= 2.0:
		_sound(SFX["tear"], (_target["door"] as Vector3) + Vector3(0, 0.6, 0), 2.0, 1.0, 40.0)
	if _phase_t > 0.0:
		return
	if kind != "tent":
		_work.stop()
		_sound(SFX["break"], (_target["door"] as Vector3) + Vector3(0, 1.0, 0), 3.0, 1.0, 45.0)
	# In, and the light goes out.
	_target["guests"] = _guests_in(str(_target["key"]))
	_target["i"] = 0
	_target["t"] = 0.0
	_set_phase("eat", 0.0)
	_body.visible = false
	_later_window(str(_target["key"]), "off", 0.9)
	_begin_meal()


## One party after another; the cry, then the eating, as long as there are heads in it.
func _tick_eat(dt: float) -> void:
	var guests: Array = _target.get("guests", [])
	var i := int(_target.get("i", 0))
	if i >= guests.size():
		_finish_lodging()
		return
	var g: Dictionary = guests[i]
	_target["t"] = float(_target["t"]) + dt
	var need: float = float(EAT_SEC[_stage]) * float(maxi(1, int(g.get("party", 1))))
	_bone_t -= dt
	if _bone_t <= 0.0:
		_bone_t = _rng.randf_range(2.0, 4.5)
		_sound(SFX["bone"], (_target["at"] as Vector3) + Vector3(0, 0.5, 0), -2.0, _rng.randf_range(0.85, 1.1), 30.0)
	if not _work.playing:
		_play_work(SFX["eat_a"] if _rng.randf() < 0.5 else SFX["eat_b"], _target["at"], 2.0)
	_relay(true)
	if float(_target["t"]) < need:
		return
	# Gone: nothing left of them but what the cleaning will find.
	var id := int(g.get("id", -1))
	if id >= 0 and GuestManager != null and GuestManager.vanish_guest(id):
		_eaten += maxi(1, int(g.get("party", 1)))
		_eaten_guests.append(g)
		_set_stage(_stage_for(_eaten))
	_target["i"] = i + 1
	_target["t"] = 0.0
	if i + 1 < guests.size():
		_begin_meal()


func _begin_meal() -> void:
	var guests: Array = _target.get("guests", [])
	var i := int(_target.get("i", 0))
	if i >= guests.size():
		return
	var g: Dictionary = guests[i]
	_sound(SFX["cry_f"] if _is_woman(g) else SFX["cry_m"], (_target["at"] as Vector3) + Vector3(0, 0.8, 0), 4.0, _rng.randf_range(0.95, 1.05), 45.0)
	_target["cried"] = true


## Nobody left in it: hers. Out again, to the next.
func _finish_lodging() -> void:
	var key := str(_target.get("key", ""))
	_ate_in[key] = true
	if GuestManager != null and GuestManager.has_method("make_room_carnage"):
		GuestManager.make_room_carnage(key)
	_force_window(key, "")
	_work.stop()
	_relay(false)
	_clear_ring(key)
	_mark = ""
	_come_out()
	_mark_next(_target.get("at", _body.global_position))


## Out of the lodging (its door), visible again.
func _come_out() -> void:
	_work.stop()
	_relay(false)
	if _phase == "eat" or _phase == "breach":
		var at: Vector3 = _target.get("door", _body.global_position)
		_place_body(at)
		_sound(SFX["zip"] if str(_target.get("kind", "")) == "tent" else SFX["creak"], at + Vector3(0, 0.8, 0), 0.0, 0.9, 30.0)
		# She had begun: what she did in there stays for the cleaning.
		if _phase == "eat" and (int(_target.get("i", 0)) > 0 or float(_target.get("t", 0.0)) > 2.5):
			_ate_in[str(_target.get("key", ""))] = true
			if GuestManager != null and GuestManager.has_method("make_room_carnage"):
				GuestManager.make_room_carnage(str(_target.get("key", "")))
		_force_window(str(_target.get("key", "")), "")
	_body.visible = true
	_interrupt_t = 0.0
	if _is_ready() and _elapsed >= _fed_until:
		_set_phase("hunt", 0.0)
		_next_look = _rng.randf_range(LOOK_NEAR.x, LOOK_NEAR.y)
	else:
		_set_phase("out", 0.8)


## You came out while she was on them: the ones still whole live, cut.
func _spare_current() -> void:
	var guests: Array = _target.get("guests", [])
	for j in range(int(_target.get("i", 0)), guests.size()):
		var id := int((guests[j] as Dictionary).get("id", -1))
		if id >= 0 and not _cut_ids.has(id):
			_cut_ids.append(id)
			if GuestManager != null:
				GuestManager.apply_guest_event(id, -60.0, {
					"tent": "Something came into the tent in the night. It had a knife. I can't stop shaking.",
					"cabin": "Something came into the cabin in the night. It had a knife. I can't stop shaking.",
					"caravan": "Something came into the caravan in the night. It had a knife. I can't stop shaking.",
				}[_kind_of(str(_target.get("key", "")))])


## The guests (parties) in the lodging at `key` now: [{id, name, archetype, party}],
## never the one she was (the turned guest sleeps through it, if she sleeps at all).
func _guests_in(key: String) -> Array:
	var out: Array = []
	var me := int((_night_entry.get("guest", {}) as Dictionary).get("id", -2)) if _night_entry.get("guest", {}) is Dictionary else -2
	for g in GuestManager.get_guest_life_snapshot():
		var c = g.get("lodging", Vector2i(-1, -1))
		if not (c is Vector2i) or "%d:%d" % [c.x, c.y] != key:
			continue
		if int(g.get("id", -1)) == me or not (str(g.get("status", "")) in ["active", "sleep"]):
			continue
		out.append({"id": int(g.get("id", -1)), "name": str(g.get("name", "")), "archetype": str(g.get("archetype", "")), "party": maxi(1, int(g.get("party_size", 1)))})
	out.shuffle()
	return out


static func _is_woman(g: Dictionary) -> bool:
	var n := str(g.get("name", ""))
	if str(g.get("archetype", "")) in ["cheap_chick", "family"]:
		return true
	return n.begins_with("Mrs ") or n.begins_with("Ms ") or n.ends_with("ova") or n.ends_with("ová")


## The lodgings with guests in them: {key, at, kind}.
func _lodgings() -> Array:
	var out: Array = []
	if GuestManager == null or _grid_manager == null or not _grid_manager.has_method("grid_to_world"):
		return out
	var state = CoreRoot.get_state()
	var seen := {}
	var me := int((_night_entry.get("guest", {}) as Dictionary).get("id", -2)) if _night_entry.get("guest", {}) is Dictionary else -2
	for g in GuestManager.get_guest_life_snapshot():
		var c = g.get("lodging", Vector2i(-1, -1))
		if not (c is Vector2i) or (c as Vector2i).x < 0 or int(g.get("id", -1)) == me:
			continue
		if not (str(g.get("status", "")) in ["active", "sleep"]):
			continue
		var key := "%d:%d" % [c.x, c.y]
		if seen.has(key):
			continue
		seen[key] = true
		var btype := ""
		if state != null and state.accommodation_states.has(key):
			btype = str((state.accommodation_states[key] as Dictionary).get("building_type", ""))
		var kind := "tent" if btype.contains("tent") else ("caravan" if btype.contains("caravan") else "cabin")
		var at: Vector3 = _grid_manager.grid_to_world(c)
		if _building_manager != null and _building_manager.has_method("get_footprint_for_building") and btype != "":
			var fp: Vector2i = _building_manager.call("get_footprint_for_building", btype)
			if fp.x > 1 or fp.y > 1:
				at = (at + _grid_manager.grid_to_world(c + fp - Vector2i.ONE)) * 0.5
		out.append({"key": key, "at": at, "kind": kind, "size": 1.6 if kind == "tent" else 2.6})
	return out


## Where she stands to get in: its side toward her.
func _door_of(l: Dictionary) -> Vector3:
	var at: Vector3 = l["at"]
	var off := _body.global_position - at
	off.y = 0.0
	off = off.normalized() if off.length() > 0.1 else Vector3.BACK
	var p := _ground(at + off * float(l.get("size", 2.0)))
	return p if p != Vector3.INF else at + off * float(l.get("size", 2.0))


## The building the warden she hunts is in ("office", "x:y"), or "".
func _quarry_room() -> String:
	var peer := _quarry_peer()
	if peer != 0:
		return str(Coop.state_of(peer).get("room", ""))
	var im = _im()
	if im != null and im.has_method("photo_building"):
		return str(im.call("photo_building"))
	return ""


func _im():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_interior_manager") if scene != null else null


static func _stage_for(eaten: int) -> int:
	if eaten >= STAGE_AT[1]:
		return 2
	if eaten >= STAGE_AT[0]:
		return 1
	return 0


func _set_stage(s: int) -> void:
	if s == _stage and not _fig.is_empty():
		return
	var up := s > _stage
	_stage = clampi(s, 0, 2)
	_fig = FIGURE.set_of(SETS[_stage])
	if _fig.is_empty():
		_fig = FIGURE.set_of(SETS[0])
	_atlas.clear()
	if up and _body != null and _body.visible:
		_sound(SFX["crack"], _body.global_position + Vector3(0, 1.6, 0), 2.0, 0.85, 35.0)


# ── what you notice from your room ───────────────────────────────────────────

## The eating as it reaches the warden she hunts, inside: through the walls, quieter the
## farther their room is from the lodging (their windows' outside is where the room is).
func _tick_heard_inside(dt: float) -> void:
	if _phase != "eat" and _phase != "breach":
		return
	_in_next -= dt
	if _in_next > 0.0:
		return
	var from := _room_place()
	var at: Vector3 = _target.get("at", _body.global_position)
	var d := maxf(4.0, Vector2(at.x - from.x, at.z - from.z).length()) if from != Vector3.INF else 25.0
	var db := clampf(-4.0 - 20.0 * log(d / 6.0) / log(10.0), -34.0, -6.0)
	var clip: String = SFX["eat_a"] if _rng.randf() < 0.5 else SFX["eat_b"]
	if _phase == "breach":
		clip = SFX["tear"] if str(_target.get("kind", "")) == "tent" else SFX["pry"]
	_in_next = 5.4 if _phase == "eat" else 3.6
	if _play_2d_remote(clip, db, 0.95):
		return
	_in_room.stream = _stream(clip)
	_in_room.volume_db = db
	_in_room.pitch_scale = 0.95
	_in_room.play()


## Where the room of the warden she hunts is, out in the camp (its windows).
func _room_place() -> Vector3:
	var peer := _quarry_peer()
	if peer != 0:
		for w in Coop.state_of(peer).get("pw", []):
			if w is Array and (w as Array).size() > 0 and w[0] is Vector3:
				return w[0]
		return Vector3.INF
	var im = _im()
	if im != null and im.has_method("photo_windows"):
		for w in im.photo_windows():
			if w is Dictionary and (w as Dictionary).get("pos") is Vector3:
				return w["pos"]
	return Vector3.INF


## The office radio, as it happens (its own layer, scripts/radio/radio_dread.gd).
func _relay(on: bool) -> void:
	if on == _relaying:
		return
	_relaying = on
	var dread = _dread()
	if dread == null:
		return
	if on and dread.has_method("relay"):
		dread.call("relay", _stream(SFX["eat_a"] if _rng.randf() < 0.5 else SFX["eat_b"]), 0.8)
	elif not on and dread.has_method("relay_off"):
		dread.call("relay_off")


func _dread():
	var im = _im()
	var bi = im.get("_building_interior") if im != null else null
	return bi.get("_dread") if bi != null else null


## The lodging's window: "on" lit (they woke), "off" dark, "" as the night has it.
func _force_window(key: String, state: String) -> void:
	if key == "":
		return
	var wl := _world_root.get_node_or_null("WindowLights") if _world_root != null else null
	if wl != null and wl.has_method("set_forced"):
		wl.call("set_forced", key, state)


func _later_window(key: String, state: String, seconds: float) -> void:
	if _world_root == null or not _world_root.is_inside_tree():
		return
	_world_root.get_tree().create_timer(seconds).timeout.connect(func():
		if _night_active and str(_target.get("key", "")) == key and _phase == "eat":
			_force_window(key, state))


# ── rings: her next ───────────────────────────────────────────────────────────

## The lodging nearest `from` with guests in it gets her ring, coming up slowly.
func _mark_next(from: Vector3) -> void:
	var best := INF
	var pick := {}
	for l in _lodgings():
		var d := Vector2((l["at"] as Vector3).x - from.x, (l["at"] as Vector3).z - from.z).length()
		if d < best and not _ate_in.has(str(l["key"])):
			best = d
			pick = l
	if pick.is_empty():
		_mark = ""
		return
	_mark = str(pick["key"])
	_grow_ring(_mark, pick["at"], 0.0, false)


func _tick_rings(dt: float) -> void:
	if _mark != "" and rings.has(_mark):
		var r: Dictionary = rings[_mark]
		if not bool(r["kicked"]) and float(r["grown"]) < 1.0 and _phase != "away":
			_grow_ring(_mark, r["center"], float(r["grown"]) + dt / RING_GROW_SEC, false)
	if rings.is_empty() or _player == null or not _is_ready():
		return
	var p := _player_pos()
	for key in rings:
		var r: Dictionary = rings[key]
		for n in r["nodes"]:
			var s := n as Sprite3D
			if s != null and is_instance_valid(s) and s.visible and Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() < 0.65:
				s.visible = false
				r["kick_n"] = int(r.get("kick_n", 0)) + 1
				_sound(SFX["kick"], s.global_position, -8.0, 1.4, 12.0)
				if int(r["kick_n"]) >= RING_KICKED and not bool(r["kicked"]):
					r["kicked"] = true
					r["grown"] = 0.0


## The ring round `key` grown to `grown` (0..1): that many of its mushrooms up.
func _grow_ring(key: String, center: Vector3, grown: float, planting: bool) -> void:
	if key == "":
		return
	if not rings.has(key):
		var tex: Texture2D = load(MUSHROOM) as Texture2D if ResourceLoader.exists(MUSHROOM) else null
		rings[key] = {"center": center, "nodes": [], "grown": 0.0, "kicked": false, "kick_n": 0}
		for i in RING_N:
			var a := TAU * float(i) / float(RING_N) + _rng.randf_range(-0.12, 0.12)
			var s := Sprite3D.new()
			s.texture = tex
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.shaded = true
			if tex != null:
				s.pixel_size = _rng.randf_range(0.16, 0.26) / float(tex.get_height())
				s.offset = Vector2(0, tex.get_height() * 0.5)
			s.visible = false
			_root.add_child(s)
			var p := _ground(center + Vector3(cos(a), 0, sin(a)) * RING_R)
			s.global_position = p if p != Vector3.INF else center + Vector3(cos(a), 0, sin(a)) * RING_R
			rings[key]["nodes"].append(s)
	var r: Dictionary = rings[key]
	if planting:
		r["kicked"] = false
		r["kick_n"] = 0
	var was := int(ceil(float(RING_N) * float(r["grown"]) - 0.001))
	r["grown"] = clampf(grown, 0.0, 1.0)
	var show := int(ceil(float(RING_N) * float(r["grown"]) - 0.001))
	var nodes: Array = r["nodes"]
	for i in nodes.size():
		var n: Sprite3D = nodes[i]
		if is_instance_valid(n) and i < show and (i >= was or planting):
			n.visible = true
	if show > was and show >= RING_N:
		_sound(SFX["ring"], center + Vector3(0, 0.2, 0), -4.0, 1.0, 25.0)


func _clear_ring(key: String) -> void:
	if not rings.has(key):
		return
	for n in rings[key]["nodes"]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	rings.erase(key)


func _clear_rings() -> void:
	for key in rings.keys():
		_clear_ring(key)
	_mark = ""


# ── moving ───────────────────────────────────────────────────────────────────

func _staff():
	if _staff_rt == null or not is_instance_valid(_staff_rt):
		_staff_rt = _world_root.get_tree().get_first_node_in_group("staff_runtime") if _world_root != null and _world_root.is_inside_tree() else null
	return _staff_rt


## What a step of hers came to: still going, there, or at the edge of a lamp's light.
const GOING := 0
const THERE := 1
const LIT := 2


## Along the camp's ways toward `goal` at `speed` (straight when it is near); never into a
## lamp's light (LIT: she stopped at its edge).
func _walk_to(goal: Vector3, speed: float, dt: float, replan := 0.7) -> int:
	var pos := _body.global_position
	var flat := Vector2(goal.x - pos.x, goal.z - pos.z).length()
	if flat <= 0.2:
		return THERE
	_path_t -= dt
	if flat < 5.0:
		_path = PackedVector3Array([pos, goal])
		_path_i = 1
		_path_goal = goal
	elif _path_goal == Vector3.INF or _path_t <= 0.0 or Vector2(_path_goal.x - goal.x, _path_goal.z - goal.z).length() > 2.0 or _path_i >= _path.size():
		_path_t = replan
		var rt = _staff()
		_path = rt.call("way", pos, goal) if rt != null and rt.has_method("way") else PackedVector3Array([pos, goal])
		_path_i = 1
		_path_goal = goal
	var left := speed * dt
	var to_pos := pos
	while left > 0.0001 and _path_i < _path.size():
		var p: Vector3 = _path[_path_i]
		var to := Vector3(p.x - to_pos.x, 0.0, p.z - to_pos.z)
		var d := to.length()
		if d < 0.01:
			_path_i += 1
			continue
		var step := minf(d, left)
		_dir = to / d
		to_pos += _dir * step
		left -= step
		if step >= d - 0.001:
			_path_i += 1
	# The light's edge: no further.
	if _lamp_light_at(to_pos) >= LAMP_EDGE and _lamp_light_at(pos) < LAMP_EDGE:
		return LIT
	var moved := Vector2(to_pos.x - pos.x, to_pos.z - pos.z).length()
	_body.global_position = _floor(to_pos)
	_fig_dist += moved
	_step(moved)
	return THERE if Vector2(goal.x - to_pos.x, goal.z - to_pos.z).length() <= 0.2 else GOING


## The ground under `p`, from just above where she is (never a roof).
func _floor(p: Vector3) -> Vector3:
	var space := _world_root.get_world_3d().direct_space_state if _world_root.get_world_3d() != null else null
	if space == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), p + Vector3(0, -4.0, 0))
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		var g := _ground(p)
		return g if g != Vector3.INF else p
	return hit["position"]


func _face_toward(p: Vector3) -> void:
	var to := p - _body.global_position
	to.y = 0.0
	if to.length() > 0.05:
		_dir = to.normalized()


## Her boots, a step every stride she covers.
func _step(metres: float) -> void:
	if metres <= 0.0 or _body == null:
		return
	_step_dist += metres
	var stride := 0.72 if _phase == "lunge" else 0.5
	if _step_dist < stride:
		return
	_step_dist = 0.0
	_step_i += 1
	var at := _body.global_position + Vector3(0, 0.15, 0)
	_sound(str(STEPS[_step_i % STEPS.size()]), at, -1.0 if _phase == "lunge" else -4.0, _rng.randf_range(0.9, 1.05), 26.0)


# ── her picture ──────────────────────────────────────────────────────────────

func _set_phase(phase: String, seconds: float) -> void:
	var was := _phase
	_phase = phase
	_phase_t = seconds
	_noticed = 0.0
	if phase == "look":
		_look_len = seconds
	if not (phase in ["reach", "reach_lodging"]) and _arm != null:
		_arm.visible = false
	match phase:
		"look":
			_sound(SFX["crack"], _body.global_position + Vector3(0, 1.6, 0), 2.0, _rng.randf_range(0.95, 1.05), 32.0)
			if _hum != null:
				_hum.stream_paused = true
		"lunge":
			_sound(SFX["lunge"], _body.global_position + Vector3(0, 0.6, 0), 3.0, 1.0, 35.0)
		"hunt":
			if was in ["look", "stare", "turn", "reach"]:
				_next_look = _rng.randf_range(LOOK_NEAR.x, LOOK_NEAR.y) if _distance_to_player(_body.global_position) < 10.0 else _rng.randf_range(LOOK_EVERY.x, LOOK_EVERY.y)
	if _body != null:
		_body.visible = not (phase in ["away", "eat", "idle_hidden"])


func _straight() -> bool:
	return _phase in ["look", "stare", "reach", "reach_lodging", "strike", "breach"]


func _update_body(out: bool) -> void:
	if _body == null:
		return
	if _phase in ["away", "eat"]:
		_body.visible = false
		return
	_body.visible = true
	_fig_yaw = atan2(-_dir.x, -_dir.z)
	var up := _straight()
	var h := (UP_M if up else BENT_M) * float(STAGE_K[_stage])
	var cam := _camera()
	var eye: Vector3 = cam.global_position if cam != null and out else _player_pos() + Vector3(0, 1.6, 0)
	if not _fig.is_empty():
		_fig_anim = "up" if up else ("run" if _phase == "lunge" else ("walk" if _phase in ["hunt", "turn", "go", "plant"] else "stand"))
		var stride := 0.7 if _fig_anim == "run" else 0.42
		var n := _frames(_fig_anim)
		_fig_frame = int(_fig_dist / stride) % maxi(1, n)
		_show_fig(eye, h)
	else:
		# Two pictures from the front: bent, or up and far too tall (the old ones were
		# drawn at one size: up is them stretched thin).
		_body.texture = _tex_up if up else _tex_bent
		if _body.texture != null:
			var at_h := h if not _tall_old else BENT_M * float(STAGE_K[_stage])
			_body.pixel_size = at_h / float(_body.texture.get_height())
			_body.offset = Vector2(0, _body.texture.get_height() * 0.5)
		var tall := (UP_M / BENT_M) if up and _tall_old else (1.08 if up else 1.0)
		_body.scale = Vector3(1.0 / sqrt(tall), tall, 1.0)
		# Drawn facing the right of the picture: going to the left of your view, mirrored.
		_body.flip_h = (_body.global_position - eye).cross(Vector3.UP).dot(_dir) < 0.0
	if _eyes != null:
		_eyes.set("height", h * (0.93 if up else 0.78))
		_eyes.set("want", 1.0 if up else 0.35)


func _frames(a: String) -> int:
	var views: Array = (_fig.get("anims", {}) as Dictionary).get(a, [])
	var n := 1
	for v in views:
		n = maxi(n, (v as Array).size())
	return n


## The view of her from `eye` as an atlas region (co-op mirrors AtlasTextures, not regions).
func _show_fig(eye: Vector3, height_m: float) -> void:
	_fig_sector = FIGURE.sector_for(_body.global_position, _fig_yaw, eye, _fig_sector)
	var view := absi(_fig_sector)
	var flip := _fig_sector < 0
	var anims: Dictionary = _fig.get("anims", {})
	var fr = FIGURE._frame_of(anims, _fig_anim, view, _fig_frame)
	if fr == null:
		fr = FIGURE._frame_of(anims, "stand", view, 0)
	if fr == null:
		fr = FIGURE._frame_of(anims, "stand", 0, 0)
	if fr == null:
		return
	var key := str(_fig.get("name", "")) + str(fr)
	var at: AtlasTexture = _atlas.get(key)
	if at == null:
		at = AtlasTexture.new()
		at.atlas = _fig.get("tex")
		at.region = Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3]))
		_atlas[key] = at
	_body.scale = Vector3.ONE
	_body.texture = at
	_body.pixel_size = height_m / float(_fig.get("h", 128))
	_body.flip_h = flip
	var w := float(fr[2])
	var hh := float(fr[3])
	var ox := w * 0.5 - float(fr[4])
	_body.offset = Vector2(-ox if flip else ox, float(fr[5]) - hh * 0.5)


# ── her sounds and what you feel ─────────────────────────────────────────────

func _update_sounds(dt: float, out: bool) -> void:
	if _body == null:
		return
	var at := _body.global_position
	var d := _distance_to_player(at) if out else 99.0
	var shown := _body.visible
	if _hum != null:
		_hum.global_position = at + Vector3(0, 1.2, 0)
		_hold(_hum, shown and _phase in ["hunt", "go", "turn", "plant"] and d > 9.0)
	if _breath != null:
		_breath.global_position = at + Vector3(0, 1.5, 0)
		_hold(_breath, shown and d < 11.0)
	if _spores != null:
		_spores.global_position = at + Vector3(0, 1.0, 0)
		_hold(_spores, shown and d < 8.0)
	_creak_t -= dt
	if _creak_t <= 0.0 and shown and _phase in ["hunt", "go", "lunge", "plant"]:
		_creak_t = 0.7 if _phase == "lunge" else _rng.randf_range(1.6, 2.8)
		_sound(SFX["creak"], at + Vector3(0, 1.0, 0), -5.0, _rng.randf_range(0.9, 1.05), 28.0)
	if _work.playing:
		_work.global_position = (_target.get("at", at) as Vector3) + Vector3(0, 0.6, 0)
	if not out:
		_tick_heard_inside(dt)


## A loop on (from somewhere in it) or off. Stopped, not paused: co-op mirrors what plays.
func _hold(p: AudioStreamPlayer3D, on: bool) -> void:
	if p == null or p.stream == null:
		return
	if on and not p.playing:
		p.play(_rng.randf_range(0.0, maxf(0.0, p.stream.get_length() - 0.5)))
	elif not on and p.playing:
		p.stop()


func _play_work(path: String, at: Vector3, db: float) -> void:
	var s := _stream(path)
	if s == null:
		return
	_work.stream = s
	_work.volume_db = db
	_work.global_position = at + Vector3(0, 0.6, 0)
	_work.play()


## The sixth sense and the spores: what is near you, when she is.
func _update_senses(_dt: float, out: bool) -> void:
	var fx := _fx()
	if fx == null:
		return
	if not out or _body == null or not _body.visible:
		fx.set_presence("basket", 0.0)
		if fx.has_method("set_spores"):
			fx.set_spores("basket", 0.0)
		return
	var d := _distance_to_player(_body.global_position)
	var near := clampf(1.0 - (d - 2.0) / 26.0, 0.0, 1.0)
	var level := near * near * (1.0 if _phase in ["lunge", "stare", "look"] else 0.8)
	fx.set_presence("basket", level)
	if fx.has_method("set_spores"):
		fx.set_spores("basket", clampf(1.0 - (d - 1.5) / 8.5, 0.0, 1.0))


# ── the morning ──────────────────────────────────────────────────────────────

## The night's account (main._claim_turned_guests): those she was on and their room-mates
## leave, shaken, with one star; a relative writes about each one she ate; the lines for
## the morning.
func dawn() -> Array:
	var lines: Array = []
	var leaving: Array = _cut_ids.duplicate()
	var lodged := {}
	for g in GuestManager.get_guest_life_snapshot():
		var c = g.get("lodging", Vector2i(-1, -1))
		if c is Vector2i:
			lodged[int(g.get("id", -1))] = "%d:%d" % [c.x, c.y]
		if c is Vector2i and _ate_in.has("%d:%d" % [c.x, c.y]) and not leaving.has(int(g.get("id", -1))):
			leaving.append(int(g.get("id", -1)))
	for id in leaving:
		if GuestManager.has_method("shaken_leave"):
			GuestManager.shaken_leave(int(id), {
				"tent": "Something came into our tent in the night and took the others. Nobody came. Never again.",
				"cabin": "Something came into our cabin in the night and took the others. Nobody came. Never again.",
				"caravan": "Something came into our caravan in the night and took the others. Nobody came. Never again.",
			}[_kind_of(str(lodged.get(int(id), "")))], "We are leaving. Now.")
	var main := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	var day := int(main.get("_day_index")) if main != null and main.get("_day_index") != null else 1
	for g in _eaten_guests:
		var name := str((g as Dictionary).get("name", ""))
		if EmailManager != null and EmailManager.has_method("schedule_pool_mail"):
			EmailManager.schedule_pool_mail(_relative_mail(g, day + _rng.randi_range(1, 2)))
		lines.append("Morning: %s is gone. Their lodging is not fit to be seen." % name)
	return lines


## A relative's mail about `g`, for EmailManager.schedule_pool_mail (Czech by its format).
func _relative_mail(g: Dictionary, day: int) -> Dictionary:
	var name := str(g.get("name", ""))
	var arch := str(g.get("archetype", ""))
	var body := ""
	var from := "Jana"
	var subject := "Have you seen %s?" % name
	match arch:
		"family":
			from = "M. Kratochvilova"
			body = "Good day,\n\nthe %s were to be home on Sunday. They wrote from your camp that the children loved the lake. Since then nothing, and nobody answers at their flat.\n\nIf you know anything, please write.\n\nTheir neighbour" % name
		"drunk", "tramp":
			from = "Pavel"
			body = "Hello,\n\nmy brother %s went to your camp with the lads and has not come back. His car is still standing in front of your gate, they say. He always rings Mum on Wednesday.\n\nDid he say where he was going?" % name
		"cheap_chick":
			from = "Petra"
			body = "Hi,\n\n%s went to you with a friend and doesn't answer the phone. Her mother is going mad. Is she still with you? Please tell her to ring home.\n\nPetra" % name
		"picker":
			# A woman by her name (Mrs, or a Czech first name in -a: Jaroslava, Vlasta).
			var first := name.get_slice(" ", 0)
			if name.begins_with("Mrs ") or (not name.begins_with("Mr ") and first.ends_with("a")):
				body = "Dear Sir or Madam,\n\nmy mother %s went to you for mushrooms and has not rung since. She always rings. She has her pills only for the week.\n\nPlease, if you know anything, write back.\n\nJana" % name
			else:
				body = "Dear Sir or Madam,\n\nmy father %s went to you for mushrooms and has not rung since. He always rings. He has his pills only for the week.\n\nPlease, if you know anything, write back.\n\nJana" % name
		_:
			# The Quiet Guy: alone, every year the same week.
			from = "Marta"
			body = "Good day,\n\nmy son %s goes to you every year for a quiet week on his own. He always sends a postcard on the second day. This year no postcard came, and his telephone is off.\n\nPlease write if you know anything.\n\nHis mother" % name
	return {"day": day, "time": "%02d:%02d" % [_rng.randi_range(7, 11), _rng.randi_range(0, 59)], "from": from, "sender": from,
		"subject": subject, "body": body, "type": "guest"}


## "tent", "cabin" or "caravan": the lodging at `key` ("x:y").
func _kind_of(key: String) -> String:
	var st = CoreRoot.get_state() if CoreRoot != null else null
	var acc: Dictionary = st.accommodation_states.get(key, {}) if st != null else {}
	var t := str(acc.get("building_type", ""))
	return "cabin" if t.contains("cabin") else ("caravan" if t.contains("caravan") else "tent")


func _on_stop() -> void:
	_relay(false)
	if _target.has("key"):
		_force_window(str(_target["key"]), "")
	if _limping and _player != null and is_instance_valid(_player) and "held_speed_mult" in _player:
		_player.set("held_speed_mult", 1.0)
	_limping = false
	_end_strike()
	_clear_rings()


func get_debug_snapshot() -> Dictionary:
	return {"phase": _phase, "stage": _stage, "eaten": _eaten, "target": str(_target.get("key", "")), "mark": _mark,
		"bulbs": bulbs.size(), "rings": rings.size(), "cut": _cut_ids.size(), "limp": _elapsed < _limp_until,
		"dist": snappedf(_distance_to_player(_body.global_position), 0.1) if _body != null else -1.0}
