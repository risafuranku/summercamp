extends "res://scripts/enemies/enemy_base.gd"

## The Girl: a Cheap Chick guest of yours, turned for the night (DESIGN §5).
##
## The one rule, which every loop of hers teaches: SHE ONLY MOVES WHILE YOU DO NOT SEE
## HER. In the dark you see her only in light: your torch on her, a lamp near her, or
## right up close. So the torch is the price: lit, she holds, and the battery drains
## five times over. She will not step into lamp light: under a lamp you are safe, and if
## you stay there long enough she gives up the loop. Going to her is the worst thing you
## can do: the nearer you come, the more often your torch dies in your hand, and in each
## of those moments she is a step nearer.
##
## Her signature, from far off: eyeshine. Out in the dark, where your torch points but
## does not reach, two small pale points where her eyes are, each blinking on its own
## (drawn on the screen by nightmare_fx, one game pixel each, at the eyes of whichever
## stage she is in). Lit, you see her own eyes instead. And a woman humming.
##
## A loop, the same grammar as every night thing:
##   omen      far out, the eyes and the humming; the first time it is still the guest in
##             her own clothes, standing much too still
##   approach  look away (or let the light leave her) and she is closer and changed: the
##             smile wider, then legs too long, then her back to you with her face turned
##             round, then on all fours, then an arm reaching too far; heels scurry on
##             the gravel while you are not looking; when you find her again, closer,
##             the sound of it
##   test      close, the torch dies in your hand now and then by itself: in that dark
##             she takes a step, and her face is there for a frame
##   strike    she has you: you cannot move or look away, her face comes at you in steps,
##             the smile tears open, the shriek in static, red, then black and a ring in
##             your ears with the world muffled; she has the guest for the morning
##   gone      one red heel where she stood; the next loop comes sooner, her steps longer

const GUEST := "res://assets/textury/npc/host3.png"
## Her mutations, far to near: whichever exist (art comes in as it is made). Always the
## guest's own colours, only her body and face deformed (playtest 18. 10.: no blue night
## lady; the old enemy_girl.png is never shown).
const N := "res://assets/textury/npc/"
## No crawling (playtest 18. 10.: "weird, not scary"): long arms, wrong proportions; no
## red cheeks, the brows furious over the drooling grin. Each stage the newest art first.
const M := [[N + "girl_m1.png"], [N + "girl4_m2.png", N + "girl_m2.png"], [N + "girl4_tall.png", N + "girl2_tall.png"], [N + "girl4_back.png", N + "girl_m3.png"], [N + "girl4_arms.png"]]
const REACH_TEX := N + "girl_reach.png"
## The strike, in order (playtest 18. 10.: girl_face_b is the one): drooling, then the
## face stretched long, then the jaw dropped further than it can.
const FACES := [[N + "girl4_face.png", N + "girl_face_b.png"], [N + "girl4_face_long.png"], [N + "girl4_face_jaw.png", N + "girl3_face_b.png"]]
## Eyeshine: the torch must point this close to her (degrees) for her eyes to catch it,
## out to this far.
const SHINE_DEG := 16.0
const SHINE_RANGE := 45.0
const HEEL := "res://assets/textury/pipes/red_shoe.png"
const SFX_STATIC := "res://assets/sfx/npc/girl_static.mp3"
const SFX_HUM := "res://assets/sfx/npc/girl_hum.mp3"
const SFX_HEEL := "res://assets/sfx/npc/girl_heel.mp3"
const SFX_RUSH := "res://assets/sfx/npc/girl_rush.mp3"
const SFX_STING := "res://assets/sfx/npc/girl_sting.mp3"
const SFX_GIGGLE := "res://assets/sfx/npc/girl_giggle.mp3"
const SFX_SCREAM := "res://assets/sfx/npc/girl_scream.mp3"
const SFX_DROOL := "res://assets/sfx/npc/girl_drool.mp3"
const LAMP_SAFE := 0.22
const REACH := 1.6
const HEIGHT := 1.72
## Seen only in light: the torch on her, a lamp near her, or this close.
const SEE_CLOSE := 3.5
const GIVE_UP_IN_LAMP := 18.0
## Within this, walking towards her makes the torch die more and more often.
const TOO_CLOSE := 9.0
const STRIKE_LEN := 2.3
## Look away this long and she may be right behind you when you turn (once a loop).
const BEHIND_AFTER := 3.5
const BEHIND_DIST := 2.7

enum { OMEN, STALK, STRIKE, GONE }

var _phase := OMEN
var _round := 0
var _unseen_for := 0.0
var _step_after := 2.6
var _step := Vector2(2.0, 3.5)
var _hit := 34
var _gone_until := 0.0
var _in_lamp_for := 0.0
var _stutter_next := 3.0
var _stutter_t := 0.0
var _step_in_dark := false
var _moved_unseen := false
var _last_d := 99.0
var _blink_next := [4.0, 5.2]
var _blink_t := [0.0, 0.0]
var _eye_spot := {}                 # texture -> Vector2(px right of centre, px up from feet)
var _strike_t := -1.0
var _wet_next := 3.0
## Not looking her way at all (the turn-round scare waits for this).
var _away_for := 0.0
var _behind_done := false
var _jump_ready := false
var _fake_done := false
var _strike_cues := {}
var _tex := {}
var _static: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D


func get_enemy_id() -> String:
	return "girl"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_after = lerpf(2.4, 1.3, t)
	_step = Vector2(lerpf(2.2, 3.2, t), lerpf(3.6, 5.2, t))
	_hit = int(lerpf(30.0, 45.0, t))
	for p in [GUEST, REACH_TEX]:
		if ResourceLoader.exists(p):
			_tex[p] = load(p)
	for alts in M:
		for p in alts:
			if ResourceLoader.exists(p):
				_tex[p] = load(p)
	for alts in FACES:
		for p in alts:
			if ResourceLoader.exists(p):
				_tex[p] = load(p)
	_body = _make_body(GUEST, HEIGHT)
	for art in _tex.values():
		_eye_spot[art] = _find_eyes(art)
	_static = _loop(SFX_STATIC, -60.0)
	_hum = _loop(SFX_HUM, -60.0)
	_begin_loop()


func _on_stop() -> void:
	_release_player()
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled") and _phase == STRIKE:
		_player.call("set_controls_enabled", true)


# ── the loop ─────────────────────────────────────────────────────────────────

## Omen: out in the dark, far, humming; the guest still, in her own clothes.
func _begin_loop() -> void:
	_phase = OMEN
	_unseen_for = 0.0
	_in_lamp_for = 0.0
	_stutter_next = _rng.randf_range(2.5, 4.5)
	var dist := _rng.randf_range(18.0, 24.0) - 2.0 * float(mini(_round, 3))
	_behind_done = false
	_fake_done = false
	for _i in 16:
		# Off to one side of where you look: you can find her if you look for her.
		var side := _rng.randf_range(35.0, 150.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := _point_from_player(dist, side)
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		_place_body(p)
		_set_look(_round == 0, dist)
		_sound(SFX_HEEL, p, -10.0, _rng.randf_range(0.9, 1.05))
		_last_d = dist
		_phase = STALK
		return
	_body.visible = false
	_gone_until = _elapsed + 4.0
	_phase = GONE


func _on_tick(dt: float) -> void:
	if _phase == STRIKE:
		_update_strike(dt)
		return
	if _phase == GONE:
		_body.visible = false
		_set_audio(0.0)
		if _elapsed >= _gone_until:
			_begin_loop()
		return
	if not _body.visible:
		_begin_loop()
		return
	var head := _body.global_position + Vector3(0, _head_height(), 0)
	var d := _distance_to_player(_body.global_position)
	var torch_on_her := _in_flashlight(head)
	var lit := torch_on_her or _lamp_light_at(_body.global_position) > 0.12 or d < SEE_CLOSE
	var looking := _is_seen(head, -4.0)
	var stuttering := _stutter_t > 0.0
	var sees := looking and lit and not stuttering
	_away_for = 0.0 if looking else _away_for + dt
	if not _behind_done and _away_for >= BEHIND_AFTER and d < 22.0 and _rng.randf() < dt * 1.5:
		_go_behind()
		return
	if sees and _jump_ready:
		_jump_ready = false
		_jumpscare()
	if sees:
		_announce("Two white pinpricks out in the dark. Someone is standing there, and she hasn't moved.")
		_unseen_for = 0.0
		if torch_on_her:
			_player.set("flashlight_drain_boost", 5.0)
		if _moved_unseen:
			_moved_unseen = false
			if d < 16.0:
				# Found again, nearer than she was: the sound of it.
				_sound(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), lerpf(-2.0, -12.0, d / 16.0))
	else:
		_unseen_for += dt * (2.5 if stuttering else 1.0)
	# Under a lamp you are out of her reach; long enough and she lets this loop go.
	if _lamp_light_at(_player_pos()) > LAMP_SAFE:
		_in_lamp_for += dt
		if _in_lamp_for >= GIVE_UP_IN_LAMP:
			_sound(SFX_GIGGLE, head, -6.0)
			_leave(_rng.randf_range(10.0, 16.0))
			return
	else:
		_in_lamp_for = maxf(0.0, _in_lamp_for - dt * 0.5)
	if _unseen_for >= _step_after:
		_unseen_for = 0.0
		_advance(false)
		d = _distance_to_player(_body.global_position)
	var coming := _last_d - d > 0.02 and d < TOO_CLOSE
	_update_stutter(dt, d, coming)
	_last_d = d
	_update_eyes(dt, head, d, lit)
	var near := clampf(1.0 - d / 22.0, 0.0, 1.0)
	_set_audio(near)
	# Close: her drool on the gravel, now and then a wet laugh through the teeth.
	if d < 7.0:
		_wet_next -= dt
		if _wet_next <= 0.0:
			_wet_next = _rng.randf_range(2.5, 5.0)
			var mouth := _eyes_world() - Vector3(0, 0.12, 0)
			if _rng.randf() < 0.7:
				_sound(SFX_DROOL, mouth, lerpf(-2.0, -12.0, d / 7.0), _rng.randf_range(0.85, 1.1))
			else:
				_sound(SFX_GIGGLE, mouth, lerpf(-4.0, -14.0, d / 7.0), _rng.randf_range(0.8, 0.95))
	var fx := _fx()
	if fx != null:
		fx.set_dread("girl", near * near)
	if d < REACH:
		_start_strike()


## Where the eyes are in a stage's art: the head is the top of the figure; the eyes a
## tenth of the guest's height below it, centred on the head's pixels.
func _find_eyes(tex: Texture2D) -> Vector2:
	var img := tex.get_image()
	if img == null:
		return Vector2(0.0, float(tex.get_height()) * 0.86)
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var top := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return Vector2(0.0, float(h) * 0.86)
	var sum := 0.0
	var n := 0
	for y in range(top, mini(h, top + 14)):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				sum += float(x)
				n += 1
	var cx := sum / float(maxi(1, n))
	var guest: Texture2D = _tex.get(GUEST)
	var drop := 0.095 * float(guest.get_height() if guest != null else h)
	return Vector2(cx - float(w) * 0.5, float(h) - (float(top) + drop))


## Where her eyes are in the world for the stage she is in now.
func _eyes_world() -> Vector3:
	var spot: Vector2 = _eye_spot.get(_body.texture, Vector2(0.0, float(_body.texture.get_height()) * 0.86))
	var cam := _camera()
	var right := cam.global_transform.basis.x if cam != null else Vector3.RIGHT
	right.y = 0.0
	right = right.normalized()
	return _body.global_position + right * spot.x * _body.pixel_size + Vector3.UP * spot.y * _body.pixel_size


func _head_height() -> float:
	return _eyes_world().y - _body.global_position.y


## Stage `i`'s art: the newest there is (null if none).
func _stage(i: int) -> String:
	for p in M[i]:
		if _tex.has(p):
			return p
	return ""


## Strike face `i` (0 the face, 1 upside down, 2 the jaw): the newest art there is, else
## the one before it in the sequence.
func _face(i: int) -> Texture2D:
	for j in range(clampi(i, 0, FACES.size() - 1), -1, -1):
		for p in FACES[j]:
			if _tex.has(p):
				return _tex[p]
	return _tex.get(GUEST)


## The turn-round: while you look the other way she is suddenly right behind you, very
## close (not yet in reach). Turn and she is there, face to face; back off.
func _go_behind() -> void:
	_behind_done = true
	var p := _point_from_player(BEHIND_DIST, 180.0 + _rng.randf_range(-20.0, 20.0))
	if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
		return
	_body.global_position = p
	_set_look(false, BEHIND_DIST)
	_jump_ready = true
	_moved_unseen = false
	_sound(SFX_GIGGLE, p + Vector3(0, 1.5, 0), -16.0)


## Face to face after the turn: the sting, her face over everything for three frames,
## the picture tearing.
func _jumpscare() -> void:
	_sound(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), 6.0)
	_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), -4.0, 1.25)
	var fx := _fx()
	if fx != null:
		fx.subliminal(_face(_rng.randi_range(0, 2)), 4, 1.15)
		fx.glitch(0.85, 0.9)
		fx.red_flash(0.35)


## Not looked at: she is closer, and changed; heels scurry where she went. Now and then
## she only changes where she stands. `small`: the step she takes in a dead torch.
func _advance(small: bool) -> void:
	var from := _body.global_position
	var to_player := _player_pos() - from
	to_player.y = 0.0
	var dist := to_player.length()
	if not small and _rng.randf() < 0.15 and dist > 6.0:
		_set_look(false, dist)
		_moved_unseen = true
		return
	var want := _rng.randf_range(0.8, 1.3) if small else _rng.randf_range(_step.x, _step.y) * (1.0 + 0.15 * float(mini(_round, 4)))
	var step := minf(want, maxf(0.0, dist - 0.4))
	var sideways := to_player.normalized().cross(Vector3.UP) * (_rng.randf_range(-0.3, 0.3) if small else _rng.randf_range(-1.4, 1.4))
	var target := _ground(from + to_player.normalized() * step + sideways)
	if target == Vector3.INF:
		return
	# Lamp light is a wall to her.
	if _lamp_light_at(target) > LAMP_SAFE:
		return
	_body.global_position = target
	var nd := _distance_to_player(target)
	_set_look(false, nd)
	_moved_unseen = true
	_sound(SFX_HEEL if small else SFX_RUSH, target, lerpf(-3.0, -16.0, clampf(nd / 22.0, 0.0, 1.0)), _rng.randf_range(0.92, 1.08))
	# The nearest lamp out there stutters as she passes it (never one you stand under).
	if not small and _rng.randf() < 0.35 and _building_manager != null and _building_manager.has_method("darken_lamp_near"):
		if _lamp_light_at(_player_pos()) <= LAMP_SAFE:
			_building_manager.call("darken_lamp_near", target, 7.0, _rng.randf_range(0.3, 0.8))


## Her look by how near she is: the guest herself only the first time, far off; then
## the smile, the long legs, the face turned round over her back, on all fours, reaching.
func _set_look(guest_ok: bool, dist: float) -> void:
	var have: Array = []
	for i in M.size():
		var p := _stage(i)
		if p != "":
			have.append(p)
	var path := GUEST
	if not (guest_ok and dist > 18.0):
		if not have.is_empty():
			var near := clampf(1.0 - (dist - 3.0) / 22.0, 0.0, 1.0)
			var i := clampi(int(near * float(have.size()) + _rng.randf_range(-0.4, 0.6)), 0, have.size() - 1)
			path = have[i]
			if dist < 6.0 and _tex.has(REACH_TEX) and _rng.randf() < 0.35:
				path = REACH_TEX
	_set_body_tex(path)


func _set_body_tex(path: String) -> void:
	var tex: Texture2D = _tex.get(path)
	if tex == null or _body.texture == tex:
		return
	_body.texture = tex
	# One pixel scale for all of her (the guest's): a stage drawn taller stands taller,
	# crouched lower.
	var guest: Texture2D = _tex.get(GUEST)
	var ref_h := float(guest.get_height()) if guest != null else float(tex.get_height())
	_body.pixel_size = HEIGHT / ref_h
	_body.offset = Vector2(0.0, float(tex.get_height()) * 0.5)


## Eyeshine: in the dark, where your torch points (it need not reach her), her eyes
## catch it: two small pale points, each blinking on its own. Not while she is lit (you
## see her own eyes then), not behind things.
func _update_eyes(dt: float, _head: Vector3, d: float, lit: bool) -> void:
	var fx := _fx()
	var cam := _camera()
	if fx == null or cam == null:
		return
	var open := [1.0, 1.0]
	for i in 2:
		_blink_next[i] -= dt
		if _blink_next[i] <= 0.0:
			_blink_t[i] = 0.22
			_blink_next[i] = _rng.randf_range(2.5, 7.5)
		if _blink_t[i] > 0.0:
			_blink_t[i] -= dt
			open[i] = 0.0
	if lit or d > SHINE_RANGE or not _flashlight_on():
		return
	var eyes := _eyes_world()
	var aim: Dictionary = _player.call("get_flashlight_aim") if _player.has_method("get_flashlight_aim") else {}
	if aim.is_empty():
		return
	var to: Vector3 = eyes - (aim["origin"] as Vector3)
	if (aim["dir"] as Vector3).normalized().dot(to.normalized()) < cos(deg_to_rad(SHINE_DEG)):
		return
	if _ray_blocked(cam.global_position, eyes):
		return
	fx.set_eyes("girl", eyes, cam, open[0], 0.0, 2.2 * _body.pixel_size, open[1])


## The torch dies in your hand now and then when she is close: a moment of dark she uses.
## Walking towards her, it dies much more often, and each time she is a step nearer.
func _update_stutter(dt: float, d: float, coming: bool) -> void:
	if _stutter_t > 0.0:
		_stutter_t -= dt
		if _stutter_t <= 0.0:
			_player.set("flashlight_stutter", 0.0)
			if _step_in_dark:
				_step_in_dark = false
				_advance(true)
		return
	if d > 12.0 or not _flashlight_on():
		return
	_stutter_next -= dt * (3.0 if coming else 1.0)
	if _stutter_next > 0.0:
		return
	_stutter_next = _rng.randf_range(2.2, 4.0) * lerpf(0.6, 1.0, d / 12.0)
	_stutter_t = _rng.randf_range(0.2, 0.34)
	_player.set("flashlight_stutter", 1.0)
	_step_in_dark = d < TOO_CLOSE
	var fx := _fx()
	if fx != null:
		if not _fake_done and d < 8.0:
			# Once a loop, in the dead torch: her face, all of it, and a shriek cut short.
			_fake_done = true
			fx.subliminal(_face(_rng.randi_range(0, 2)), 3, 1.1)
			fx.glitch(0.6, 0.5)
			_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), -2.0, 1.4)
		elif _rng.randf() < 0.5:
			fx.subliminal(_face(_rng.randi_range(0, 2)), 2, 0.8, Color(1, 1, 1, 0.5))


# ── the strike ───────────────────────────────────────────────────────────────

func _start_strike() -> void:
	_phase = STRIKE
	_strike_t = 0.0
	_strike_cues.clear()
	_release_player()
	# You cannot move or look away: you are turned to her.
	if _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	var to := _body.global_position - _player_pos()
	_player.rotation.y = atan2(-to.x, -to.z)
	_set_audio(0.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.1)
	_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), -6.0)


## Her face twitches on the beat: a small tilt, one way then back, every third step.
func _twitch(st: float) -> float:
	var step := int(st * 12.0)
	return (0.05 if step % 6 == 3 else (-0.035 if step % 6 == 4 else 0.0))


func _cue(at: float, id: String) -> bool:
	if _strike_t >= at and not _strike_cues.has(id):
		_strike_cues[id] = true
		return true
	return false


## Her face comes at you in steps (twelve a second), the smile tearing; the shriek; red;
## black and the ring. Then she is gone and you can move.
func _update_strike(dt: float) -> void:
	_strike_t += dt
	var fx := _fx()
	var st := floorf(_strike_t * 12.0) / 12.0
	if fx != null:
		if st < 0.34:
			var k := st / 0.34
			fx.close_up(_face(0), lerpf(0.6, 1.05, k), 1.0, 0.006 + 0.012 * k, _twitch(st))
			fx.set_dread("girl", 1.0)
		elif st < 0.5:
			# Two frames: the head upside down, the same stare.
			fx.close_up(_face(1), 1.1, 1.0, 0.016, _twitch(st))
			fx.set_dread("girl", 1.0)
		elif st < 0.95:
			var k2 := (st - 0.5) / 0.45
			fx.close_up(_face(2), lerpf(1.15, 2.0, k2), 1.0, 0.025, _twitch(st) * 1.6)
			fx.set_dread("girl", 1.0)
		else:
			fx.close_up_off()
	if _cue(0.45, "tear"):
		_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 5.0, 0.92)
		if fx != null:
			fx.glitch(1.0, 1.8)
			fx.red_flash(0.7)
	if _cue(0.85, "hit"):
		_hurt(_hit)
		claimed = true
		if fx != null:
			fx.red_flash(1.0)
			fx.tinnitus(5.0)
	if fx != null and _strike_t >= 0.95:
		fx.set_black(clampf(1.0 - (_strike_t - 1.6) / 0.7, 0.0, 1.0))
	if _cue(1.4, "giggle"):
		_sound(SFX_GIGGLE, _player_pos() + _forward_flat() * -6.0 + Vector3(0, 1.4, 0), -10.0)
	if _strike_t >= STRIKE_LEN:
		if fx != null:
			fx.set_black(0.0)
			fx.close_up_off()
		if _player.has_method("set_controls_enabled"):
			_player.call("set_controls_enabled", true)
		_leave(_rng.randf_range(20.0, 30.0) * maxf(0.45, 1.0 - 0.18 * float(_round)))


## She is gone for `seconds`, leaving one red heel where she stood.
func _leave(seconds: float) -> void:
	if ResourceLoader.exists(HEEL) and _body != null:
		var heel := Sprite3D.new()
		heel.texture = load(HEEL)
		heel.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		heel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		heel.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		heel.shaded = true
		heel.pixel_size = 0.2 / float(heel.texture.get_width())
		heel.offset = Vector2(0.0, float(heel.texture.get_height()) * 0.5)
		_root.add_child(heel)
		heel.global_position = _body.global_position
	_body.visible = false
	_phase = GONE
	_round += 1
	_gone_until = _elapsed + seconds
	_release_player()


func _release_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.set("flashlight_drain_boost", 0.0)
		_player.set("flashlight_stutter", 0.0)
	_stutter_t = 0.0
	_step_in_dark = false


func _set_audio(near: float) -> void:
	for a in [_static, _hum]:
		if a != null and is_instance_valid(a):
			a.global_position = _body.global_position + Vector3(0, 1.3, 0)
	if _static != null:
		_static.volume_db = lerpf(-46.0, -3.0, near * near)
	if _hum != null:
		_hum.volume_db = lerpf(-28.0, -6.0, near)
