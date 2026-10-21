extends "res://scripts/enemies/enemy_base.gd"

## The mushroom granny (Mushroom Pickers; DESIGN §5a.4). The old picker turned: her
## cardigan and flowered dress and green boots, bent at the waist like a hook, the
## basket on her arm, the little knife. She comes out in the small hours (02:30-06:00),
## as pickers do, and she harvests the camp. She sees only what moves, and only when she
## straightens up: Grandmother's footsteps.
##   pick     bent double over her harvest, the knife scraping, humming: she sees nothing.
##            Move.
##   up       her back cracks and the humming stops: she straightens, far too tall, and
##            looks. Anything of yours that moves in her sight and she comes.
##   come     her boots through the grass, quick, the knife low; freeze before she is on
##            you and she stands over you a while, looking, and goes back to her work.
##            At you: the knife at your ankles ("To je ale pěkný kozák"), the hit.
## What she harvests:
##   bulbs    the lamps, one by one: she unscrews the bulb and it goes in her basket, the
##            lamp is dark for the night. Creep up behind her while she is bent and take
##            them back out of the basket (E): every lamp she took is lit again (and she
##            straightens up at once).
##   rings    mushrooms round a lodging with guests in it, a few more each time she is
##            there: a ring closed by dawn and its guests are hers (sick in the morning,
##            heavy: one of them gone). Walk through a ring and you kick it open.
## Indoors: her knife along the outside wall, and the ring round your lodging grows.

const N := "res://assets/textury/npc/"
const SPR_PICK := N + "granny_pick.png"
const SPR_UP := N + "granny_up.png"
const FACE := N + "granny_face.png"
const OLD := N + "enemy_basket.png"
const MUSHROOM := "res://assets/textury/world/fly_agaric.png"
const S := "res://assets/sfx/npc/granny/"
const SFX_CREAK := "res://assets/sfx/npc/basket_creak.mp3"
const SAY := [S + "still.mp3", S + "basket.mp3", S + "mine.mp3"]
const VOICE_PITCH := 0.88
const FROM_HOUR := 2.5
const TO_HOUR := 6.0
const WALK := 1.2
const COME := 4.6
## How far she sees what moves when she straightens up, and while she walks.
const SEE_UP := 22.0
const SEE_WALK := 9.0
## Seconds of you moving in her sight before she comes (quick: she is watching for it).
const NOTICE := 0.35
const REACH := 1.6
## How long she stands over you looking when you froze in time.
const STARE := 3.5
## Her work at a place: how many times she bends (light .. heavy), how long bent, how
## long up.
const BENDS := Vector2i(3, 5)
const PICK_SEC := Vector2(2.6, 5.0)
const UP_SEC := Vector2(1.6, 3.2)
## A ring: mushrooms round a lodging, and the visits that close it.
const RING_N := 12
const RING_R := 2.6
const RING_VISITS := 3

var _hit := 35
var _phase := "away"
var _phase_t := 0.0
var _noticed := 0.0
var _target := {}
var _bends_left := 0
var _stare_left := 0.0
var _creak_t := 0.0
var _hum: AudioStreamPlayer3D
var _cut: AudioStreamPlayer3D
var _tex_pick: Texture2D
var _tex_up: Texture2D
var _face_tex: Texture2D
var _mush_tex: Texture2D
## The lamps she took tonight (where they stand), in her basket.
var bulbs: Array = []
## Her rings: "x:y" -> {center, stage, nodes, broken}.
var rings: Dictionary = {}
var _strike_t := -1.0
var _said := 0
## Tests: she is out whatever the hour.
var soon := false
var _in_next := -1.0
var _in_sound: AudioStreamPlayer


func get_enemy_id() -> String:
	return "basket"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(28.0, 44.0, t))
	_tex_pick = load(SPR_PICK if ResourceLoader.exists(SPR_PICK) else OLD)
	_tex_up = load(SPR_UP) if ResourceLoader.exists(SPR_UP) else _tex_pick
	_face_tex = load(FACE) if ResourceLoader.exists(FACE) else null
	_mush_tex = load(MUSHROOM) if ResourceLoader.exists(MUSHROOM) else null
	_body = _make_body(SPR_UP if ResourceLoader.exists(SPR_UP) else OLD, 2.15)
	_body.visible = false
	_make_eyes("basket", 1.9).set("x_off", 0.0)
	_hum = AudioStreamPlayer3D.new()
	_hum.unit_size = 4.0
	_hum.max_distance = 30.0
	_hum.stream = load(S + "hum.mp3") if ResourceLoader.exists(S + "hum.mp3") else null
	if _hum.stream is AudioStreamMP3:
		(_hum.stream as AudioStreamMP3).loop = true
	_root.add_child(_hum)
	_cut = AudioStreamPlayer3D.new()
	_cut.unit_size = 3.0
	_cut.max_distance = 22.0
	_cut.stream = load(S + "cut.mp3") if ResourceLoader.exists(S + "cut.mp3") else null
	if _cut.stream is AudioStreamMP3:
		(_cut.stream as AudioStreamMP3).loop = true
	_root.add_child(_cut)
	_in_sound = AudioStreamPlayer.new()
	_root.add_child(_in_sound)
	_fx()


func _hour() -> float:
	var main := _world_root.get_tree().current_scene if _world_root != null else null
	return float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 0.0


func _out_now() -> bool:
	var h := _hour()
	return soon or (h >= FROM_HOUR and h <= TO_HOUR)


func _on_tick(dt: float) -> void:
	_tick_rings()
	if _strike_t >= 0.0:
		_tick_strike(dt)
		return
	if not _out_now():
		if _phase != "away":
			_set_phase("away", 0.0)
		_body.visible = false
		return
	if _phase == "away":
		_appear()
	_phase_t -= dt
	var pos := _body.global_position
	var moving := _player != null and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.4
	var d := _distance_to_player(pos)
	_creak_t -= dt
	if _creak_t <= 0.0 and _phase in ["walk", "come"]:
		_creak_t = 2.0 if _phase == "walk" else 0.8
		_sound(SFX_CREAK, pos + Vector3(0, 1.0, 0), -3.0, _rng.randf_range(0.9, 1.05), 30.0)
	_eyes.set("want", 1.0 if _phase in ["up", "come"] else 0.0)
	match _phase:
		"walk":
			_tick_walk(dt)
			if moving and d < SEE_WALK:
				_notice(dt)
		"pick":
			_noticed = 0.0
			_tick_take(d)
			if _phase_t <= 0.0:
				_set_phase("up", _rng.randf_range(UP_SEC.x, UP_SEC.y))
		"up":
			if moving and d < SEE_UP:
				_notice(dt)
			elif _phase_t <= 0.0:
				_bends_left -= 1
				if _bends_left <= 0:
					_harvest()
					_next_target()
				else:
					_set_phase("pick", _rng.randf_range(PICK_SEC.x, PICK_SEC.y))
		"come":
			_tick_come(dt, moving)


# ── her work ─────────────────────────────────────────────────────────────────

func _appear() -> void:
	var p := _point_from_player(_rng.randf_range(18.0, 26.0), _rng.randf_range(-70.0, 70.0))
	if p == Vector3.INF:
		p = _point_from_player(20.0, 0.0)
	_place_body(p)
	_announce("A basket creaking out of the trees. Somebody picking, at this hour.")
	_next_target()


## Her next harvest: a lit lamp near you, or a lodging with guests in it, or mushrooms
## where she is (a camp with neither).
func _next_target() -> void:
	var options: Array = []
	var bm = _building_manager
	if bm != null and bm.has_method("lit_lamp_positions"):
		for p in bm.call("lit_lamp_positions"):
			if _distance_to_player(p) < 45.0:
				options.append({"kind": "lamp", "at": p})
	for l in _lodgings():
		var key := str(l["key"])
		if rings.has(key) and int(rings[key]["stage"]) >= RING_VISITS:
			continue
		if _distance_to_player(l["at"]) < 55.0:
			options.append({"kind": "ring", "at": l["at"], "key": key})
	if options.is_empty():
		var p := _point_from_player(_rng.randf_range(7.0, 14.0), _rng.randf_range(0.0, 360.0))
		options.append({"kind": "patch", "at": p if p != Vector3.INF else _body.global_position})
	_target = options[_rng.randi() % options.size()]
	var to: Vector3 = _target["at"]
	if str(_target["kind"]) == "ring":
		# At the ring's edge, the side nearest her.
		var off: Vector3 = _body.global_position - to
		off.y = 0.0
		to = to + (off.normalized() if off.length() > 0.1 else Vector3.RIGHT) * RING_R
	elif str(_target["kind"]) == "lamp":
		to = to + Vector3(0.7, 0, 0.0)
	_target["stand"] = to
	_set_phase("walk", 60.0)


func _tick_walk(dt: float) -> void:
	var pos := _body.global_position
	var to: Vector3 = _target["stand"] - pos
	to.y = 0.0
	if to.length() < 0.6 or _phase_t <= 0.0:
		_bends_left = _rng.randi_range(BENDS.x, BENDS.y) + (1 if _difficulty >= 4 else 0)
		_set_phase("pick", _rng.randf_range(PICK_SEC.x, PICK_SEC.y))
		return
	var np := _ground(pos + to.normalized() * WALK * dt)
	if np != Vector3.INF:
		_body.global_position = np


## Done at a place: the bulb in her basket, or the ring a step nearer closing.
func _harvest() -> void:
	match str(_target.get("kind", "")):
		"lamp":
			var bm = _building_manager
			if bm != null and bm.has_method("darken_lamp_near"):
				var at: Vector3 = bm.call("darken_lamp_near", _target["at"], 2.0, 3600.0)
				if at != Vector3.INF:
					bulbs.append(at)
					_sound(S + "bulb.mp3", at + Vector3(0, 2.6, 0), 0.0, 1.0, 30.0)
		"ring":
			_grow_ring(str(_target["key"]), _target["at"])


func _set_phase(phase: String, seconds: float) -> void:
	var was := _phase
	_phase = phase
	_phase_t = seconds
	_noticed = 0.0
	match phase:
		"pick":
			_body.texture = _tex_pick
			if _hum.stream != null and not _hum.playing:
				_hum.play(_rng.randf_range(0.0, 3.0))
			if _cut.stream != null and not _cut.playing:
				_cut.play()
		"up":
			_body.texture = _tex_up
			_hum.stop()
			_cut.stop()
			if was == "pick":
				_sound(S + "crack.mp3", _body.global_position + Vector3(0, 1.4, 0), 0.0, _rng.randf_range(0.95, 1.05), 28.0)
		"walk", "come":
			_body.texture = _tex_up if phase == "come" else _tex_pick
			_hum.stop()
			_cut.stop()
			if phase == "come":
				_sound(S + "step.mp3", _body.global_position + Vector3(0, 0.5, 0), 2.0, 1.0, 35.0)
		"away":
			_hum.stop()
			_cut.stop()
	if _body != null:
		_body.visible = phase != "away"
	_hum.global_position = _body.global_position + Vector3(0, 1.0, 0) if _body != null else Vector3.ZERO
	_cut.global_position = _body.global_position + Vector3(0, 0.3, 0) if _body != null else Vector3.ZERO


func _notice(dt: float) -> void:
	_noticed += dt
	if _noticed >= NOTICE:
		_stare_left = STARE
		_set_phase("come", 20.0)
		if _rng.randf() < 0.6:
			_say(SAY[_said % SAY.size()])
			_said += 1


## Coming at you. Froze in time: she stands over you looking, and goes back to work.
func _tick_come(dt: float, moving: bool) -> void:
	var pos := _body.global_position
	var to := _player_pos() - pos
	to.y = 0.0
	if to.length() <= REACH:
		if moving or _stare_left <= 0.0 and _difficulty >= 4:
			_start_strike()
			return
	if to.length() <= 3.0:
		# Over you, looking down at you: still, and she goes back.
		_body.texture = _tex_up
		if moving:
			_start_strike()
			return
		_stare_left -= dt
		if _stare_left <= 0.0:
			_set_phase("walk", 60.0)
		return
	var np := _ground(pos + to.normalized() * COME * dt)
	if np != Vector3.INF:
		_body.global_position = np
	if _phase_t <= 0.0:
		_set_phase("walk", 60.0)


## Behind her while she is bent: her basket within reach, the bulbs back (E).
var _take_hint := ""


func _tick_take(d: float) -> void:
	_take_hint = ""
	if bulbs.is_empty() or d > 1.9 or _quarry_peer() != 0:
		return
	_take_hint = "[E] Take the bulbs from her basket"
	if Input.is_action_just_pressed("interact"):
		take_bulbs()


## The bulbs back out of her basket: every lamp she took is lit again, and she is up.
func take_bulbs() -> void:
	var bm = _building_manager
	for at in bulbs:
		if bm != null and bm.has_method("relight_lamp_near"):
			bm.call("relight_lamp_near", at, 2.0)
	bulbs.clear()
	_take_hint = ""
	_sound(S + "bulb.mp3", _player_pos() + Vector3(0, 1.0, 0), 2.0, 1.2, 10.0)
	_set_phase("up", UP_SEC.y + 1.0)


## The interaction line for the HUD while you can take them (main reads it).
func hint() -> String:
	return _take_hint


# ── the strike ───────────────────────────────────────────────────────────────

func _start_strike() -> void:
	_strike_t = 0.0
	_body.visible = false
	_hum.stop()
	_cut.stop()
	_say(S + "kozak.mp3")
	var fx := _fx()
	if fx != null:
		fx.freeze(0.1)
		if _face_tex != null:
			fx.close_up(_face_tex, 1.1, 1.0, 0.02, 0.0, Vector2(0, 0.08))
		fx.tinnitus(2.5)


func _tick_strike(dt: float) -> void:
	_strike_t += dt
	var fx := _fx()
	if fx != null and _face_tex != null and _strike_t < 1.2:
		fx.close_up(_face_tex, lerpf(1.1, 1.45, _strike_t / 1.2), 1.0, 0.02, 0.0, Vector2(0, lerpf(0.08, -0.04, _strike_t / 1.2)))
	if _strike_t >= 0.9 and _strike_t - dt < 0.9:
		_sound_quarry(S + "slash.mp3", _player_pos() + Vector3(0, 0.3, 0), 4.0, 1.0, 10.0)
	if _strike_t >= 1.2:
		_strike_t = -1.0
		if fx != null:
			fx.close_up_off()
			fx.red_flash(0.6)
			fx.glitch(0.6, 0.6)
		_hurt(_hit)
		claimed = true
		_feed("A knife at your ankles, low in the grass.")
		# Off to her work elsewhere, far.
		var p := _point_from_player(_rng.randf_range(22.0, 30.0), 180.0)
		if p != Vector3.INF:
			_place_body(p)
		_next_target()


# ── the rings ────────────────────────────────────────────────────────────────

## The lodgings with guests in them: {key, at}.
func _lodgings() -> Array:
	var out: Array = []
	if GuestManager == null or _grid_manager == null or not _grid_manager.has_method("grid_to_world"):
		return out
	var seen := {}
	for g in GuestManager.get_guest_life_snapshot():
		var c = g.get("lodging", Vector2i(-1, -1))
		if not (c is Vector2i) or (c as Vector2i).x < 0:
			continue
		var key := "%d:%d" % [c.x, c.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"key": key, "at": _grid_manager.grid_to_world(c)})
	return out


## A visit more to the ring round this lodging: more of the mushrooms up.
func _grow_ring(key: String, center: Vector3) -> void:
	if not rings.has(key):
		rings[key] = {"center": center, "stage": 0, "nodes": [], "broken": false}
		for i in RING_N:
			var a := TAU * float(i) / float(RING_N) + _rng.randf_range(-0.12, 0.12)
			var s := Sprite3D.new()
			s.texture = _mush_tex
			s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			s.shaded = true
			if _mush_tex != null:
				s.pixel_size = _rng.randf_range(0.16, 0.26) / float(_mush_tex.get_height())
				s.offset = Vector2(0, _mush_tex.get_height() * 0.5)
			s.visible = false
			_root.add_child(s)
			var p := _ground(center + Vector3(cos(a), 0, sin(a)) * RING_R)
			s.global_position = p if p != Vector3.INF else center + Vector3(cos(a), 0, sin(a)) * RING_R
			rings[key]["nodes"].append(s)
	var r: Dictionary = rings[key]
	r["stage"] = mini(RING_VISITS, int(r["stage"]) + 1)
	r["broken"] = false
	var show := int(ceil(float(RING_N) * float(r["stage"]) / float(RING_VISITS)))
	var nodes: Array = r["nodes"]
	for i in nodes.size():
		var n: Sprite3D = nodes[i]
		if is_instance_valid(n):
			n.visible = i < show
	_sound(S + "ring.mp3", center + Vector3(0, 0.2, 0), -2.0, 1.0, 25.0)


## Walk through a ring and you kick it open: the mushrooms you touch are gone.
func _tick_rings() -> void:
	if rings.is_empty() or _player == null:
		return
	var p := _player_pos()
	for key in rings:
		var r: Dictionary = rings[key]
		for n in r["nodes"]:
			var s := n as Sprite3D
			if s != null and is_instance_valid(s) and s.visible and Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() < 0.6:
				s.visible = false
				r["broken"] = true
				_sound("res://assets/sfx/npc/twig_snap.mp3", s.global_position, -8.0, 1.4, 12.0)


## Dawn: the rings closed (all her visits, not kicked open): their guests are hers.
## main calls it (_claim_turned_guests).
func closed_ring_lodgings() -> Array:
	var out: Array = []
	for key in rings:
		var r: Dictionary = rings[key]
		if int(r["stage"]) >= RING_VISITS and not bool(r["broken"]):
			out.append(key)
	return out


# ── indoors ──────────────────────────────────────────────────────────────────

## The base ticks nothing while you are indoors: her knife along the outside wall now and
## then, and the ring round your lodging grows.
func tick(delta: float) -> void:
	if _night_active and _world_root != null and is_instance_valid(_world_root) and not _is_ready() and _quarry_indoors() and _out_now():
		var now := Time.get_ticks_msec() / 1000.0
		if _in_next < 0.0:
			_in_next = now + _rng.randf_range(12.0, 25.0)
		elif now >= _in_next and _fx() != null:
			_in_next = now + _rng.randf_range(35.0, 60.0)
			_in_sound.stream = load(S + "cut.mp3")
			_in_sound.volume_db = -10.0
			_in_sound.pitch_scale = 0.8
			_in_sound.play()
	super(delta)


func _say(path: String) -> void:
	if _body == null:
		return
	_sound_quarry(path, _body.global_position + Vector3(0, 1.5, 0), 0.0, VOICE_PITCH, 30.0)


func _on_stop() -> void:
	for key in rings:
		for n in rings[key]["nodes"]:
			if is_instance_valid(n):
				(n as Node).queue_free()
	rings.clear()


func get_debug_snapshot() -> Dictionary:
	return {"phase": _phase, "target": str(_target.get("kind", "")), "bulbs": bulbs.size(), "rings": rings.size(),
		"dist": snappedf(_distance_to_player(_body.global_position), 0.1) if _body != null else -1.0}
