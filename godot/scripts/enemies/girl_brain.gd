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
## (enemy_eyes "girl", in the world, at the eyes of whichever stage she is in); the
## nearer she is, the bigger and wider apart they are. Lit, you see her own eyes
## instead. And a woman humming.
##
## The terror pass (Richard, 20. 10.: "total terror"):
##   the dead torch  close, when your torch dies in your hand she takes her step in that
##                   dark, and you see her eyes there, nearer, before the light comes back
##   the decoy       while your torch holds her, a second pair of her eyes opens out in the
##                   dark to one side, and a soft giggle from there; swing to it and there
##                   is nothing, and she has moved (you looked away)
##   the lamp's edge under a lamp she cannot come in: she goes round the edge of its light,
##                   a little further each time you look away, towards your back
##   your heart      the pressure, the drone and the heart (nightmare_fx.set_presence) as
##                   she comes, more in a dead torch
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
## The decoy: a second pair of her eyes in the dark ({eyes, at, t}; not under _root, only
## the warden she hunts sees it), and when the next may open.
var _decoy := {}
var _decoy_next := 8.0
## Close behind you: the world goes quiet (her hum and the static out, the presence at
## its height), then her wet breath at your ear, once a loop.
var _hush := false
var _breath_done := false
## Cursed frames: while you hold her in the light, now and then for two frames she is
## not as she is (her head upside down), with a crackle through the picture.
var _curse_next := 6.0
var _curse_frames := 0
var _curse_back: Texture2D
## Her laugh from far out in the dark, slowed down into something low.
var _far_laugh_next := 20.0
var _eye_tilt0 := 0.12
## Her head turned upside down on her neck (made from her art: the head cut out and
## flipped), and where its eyes are.
var _upside_tex: ImageTexture
const HUSH_DIST := 4.5
const DECOY_EVERY := Vector2(14.0, 26.0)


func get_enemy_id() -> String:
	return "girl"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_after = lerpf(2.4, 1.3, t)
	_step = Vector2(lerpf(2.2, 3.2, t), lerpf(3.6, 5.2, t))
	_hit = int(lerpf(30.0, 45.0, t))
	for p in [GUEST, REACH_TEX, T_LUNGE, T_HANDS, T_SPLIT, T_MAW, T_UPSIDE]:
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
	_eye_tilt0 = 0.12 if _rng.randf() < 0.5 else -0.12
	_make_eyes("girl", HEIGHT * 0.9).set("tilt", _eye_tilt0)
	for art in _tex.values():
		_eye_spot[art] = _find_eyes(art)
	_static = _loop(SFX_STATIC, -60.0)
	_hum = _loop(SFX_HUM, -60.0)
	_begin_loop()


func _on_stop() -> void:
	_release_player()
	_drop_decoy()
	if not _strike_cam.is_empty():
		_cam_set(0.0, 0.0)
		_strike_cam = {}
	if _after_light != null and is_instance_valid(_after_light):
		_after_light.visible = false
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0)
		fx.set_presence("girl", 0.0)
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
	_breath_done = false
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
		_drop_decoy()
		var fxg := _fx()
		if fxg != null:
			fxg.set_presence("girl", 0.0)
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
	_tick_curse(dt, sees and d < 16.0)
	_tick_far_laugh(dt, d)
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
	_update_shine(d, lit, stuttering)
	_update_decoy(dt, sees and torch_on_her, d)
	var near := clampf(1.0 - d / 22.0, 0.0, 1.0)
	_hush = d < HUSH_DIST and not looking
	_set_audio(0.0 if _hush else near)
	if _hush and not _breath_done and d < 3.0:
		_breath_done = true
		_sound(SFX_DROOL, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.3, 2.0, 0.8, 5.0)
	var fxp := _fx()
	if fxp != null:
		var in_lamp := _lamp_light_at(_player_pos()) > LAMP_SAFE
		var lv := 1.0 if _hush else clampf(near * near * 0.9 + (0.25 if stuttering and d < TOO_CLOSE else 0.0), 0.0, 1.0)
		fxp.set_presence("girl", 0.0 if in_lamp else lv)
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
	# Lamp light is a wall to her: she goes round its edge instead, towards your back.
	if _lamp_light_at(target) > LAMP_SAFE:
		target = _round_the_light(from, dist)
		if target == Vector3.INF:
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


## At the edge of the light you stand in: a step round it at the same distance, the way
## that is more behind you. INF if there is no dark there.
func _round_the_light(from: Vector3, dist: float) -> Vector3:
	var me := _player_pos()
	var out := from - me
	out.y = 0.0
	if out.length() < 0.5:
		return Vector3.INF
	var fwd := _forward_flat()
	var best := Vector3.INF
	var best_k := 2.0
	for ang in [30.0, -30.0, 55.0, -55.0]:
		var dir := out.normalized().rotated(Vector3.UP, deg_to_rad(ang))
		var p := _ground(me + dir * maxf(dist - 0.3, 2.0))
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		var k := fwd.dot(dir)
		if k < best_k:
			best_k = k
			best = p
	return best


## Two frames of her not as she is, while you look at her: her head upside down on her
## neck, a crackle through the picture; then she is as she was.
func _tick_curse(dt: float, seen_near: bool) -> void:
	if _curse_frames > 0:
		_curse_frames -= 1
		if _curse_frames <= 0 and _curse_back != null:
			_set_body_texture(_curse_back)
			_curse_back = null
		return
	if not seen_near:
		return
	_curse_next -= dt
	if _curse_next > 0.0:
		return
	_curse_next = _rng.randf_range(5.0, 11.0)
	var up := _upside()
	if up == null:
		return
	_curse_back = _body.texture
	_set_body_texture(up)
	_curse_frames = 2
	var fx := _fx()
	if fx != null:
		fx.glitch(0.35, 0.15)
	_sound(SFX_STATIC, _body.global_position + Vector3(0, 1.4, 0), -6.0, 0.7, 30.0)


## Out of the dark, far off, her laugh slowed down into something low and long.
func _tick_far_laugh(dt: float, d: float) -> void:
	_far_laugh_next -= dt
	if _far_laugh_next > 0.0 or d < 11.0:
		return
	_far_laugh_next = _rng.randf_range(16.0, 32.0)
	_sound(SFX_GIGGLE, _body.global_position + Vector3(0, 1.5, 0), -10.0, _rng.randf_range(0.48, 0.58), 50.0)


## Her own art with the head cut out and turned upside down on the neck: the cap at the
## bottom, the hair falling up, the grin the wrong way up. Made once.
func _upside() -> Texture2D:
	if _upside_tex != null:
		return _upside_tex
	var src: Texture2D = _tex.get(T_UPSIDE, _tex.get(GUEST))
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var top := 0
	for y in h:
		var hit := false
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				hit = true
				break
		if hit:
			top = y
			break
	var hh := int(float(h) * 0.17)
	var head := img.get_region(Rect2i(0, top, w, hh))
	head.flip_y()
	img.fill_rect(Rect2i(0, top, w, hh), Color(0, 0, 0, 0))
	img.blit_rect(head, Rect2i(0, 0, w, hh), Vector2i(0, top))
	_upside_tex = ImageTexture.create_from_image(img)
	# Its eyes: where the art's are, mirrored in the head.
	var spot: Vector2 = _eye_spot.get(src, _find_eyes(src))
	var from_top := float(h) - spot.y
	var flipped := float(top) + float(hh) - (from_top - float(top))
	_eye_spot[_upside_tex] = Vector2(spot.x, float(h) - flipped)
	return _upside_tex


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
	_set_body_texture(_tex.get(path))


func _set_body_texture(tex: Texture2D) -> void:
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
## catch it: two small pale points, each blinking on its own, on the eyes of the stage
## she is in. Not while she is lit (you see her own eyes then), not behind things (the
## eyes' own line of sight). In a dead torch near you they are there by themselves.
func _update_shine(d: float, lit: bool, stuttering: bool) -> void:
	if _eyes == null:
		return
	var spot: Vector2 = _eye_spot.get(_body.texture, Vector2(0.0, float(_body.texture.get_height()) * 0.86))
	_eyes.set("height", spot.y * _body.pixel_size)
	_eyes.set("x_off", spot.x * _body.pixel_size)
	# Her face stretching: nearer, wider apart and bigger.
	var near := clampf(1.0 - d / 16.0, 0.0, 1.0)
	_eyes.set("gap_k", 1.0 + 1.1 * near * near)
	_eyes.set("size_k", 1.0 + 0.35 * near)
	# Near, they sit wrong on her face: one higher, more and more.
	_eyes.set("tilt", _eye_tilt0 + signf(_eye_tilt0) * 0.55 * near * near)
	_eyes.set("want", 1.0 if _shines(d, lit) or (stuttering and d < TOO_CLOSE) else 0.0)


func _shines(d: float, lit: bool) -> bool:
	if lit or d > SHINE_RANGE or not _flashlight_on():
		return false
	var aim: Dictionary = _player.call("get_flashlight_aim") if _player.has_method("get_flashlight_aim") else {}
	if aim.is_empty():
		return false
	var to: Vector3 = _eyes_world() - (aim["origin"] as Vector3)
	return (aim["dir"] as Vector3).normalized().dot(to.normalized()) >= cos(deg_to_rad(SHINE_DEG))


## The decoy: while your torch holds her, now and then a second pair of her eyes opens in
## the dark off to one side, with a soft giggle from there. Look at it and it goes out;
## it goes out by itself in a few seconds. Never two.
func _update_decoy(dt: float, holding: bool, d: float) -> void:
	var cam := _camera()
	if not _decoy.is_empty():
		var e: Node3D = _decoy["eyes"]
		_decoy["t"] = float(_decoy["t"]) - dt
		var looked := false
		if cam != null:
			var to: Vector3 = (_decoy["at"] as Vector3) - cam.global_position
			looked = (-cam.global_transform.basis.z).dot(to.normalized()) > cos(deg_to_rad(10.0))
		if float(_decoy["t"]) <= 0.0 or looked or e == null or not is_instance_valid(e) or cam == null:
			_drop_decoy()
			return
		e.set("strength", 1.0)
		e.call("update", dt, cam)
		return
	_decoy_next -= dt if holding else dt * 0.25
	if not holding or _decoy_next > 0.0 or d < 6.0 or cam == null or _fx() == null:
		return
	_decoy_next = _rng.randf_range(DECOY_EVERY.x, DECOY_EVERY.y)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var p := _point_from_player(clampf(d * _rng.randf_range(0.8, 1.2), 8.0, 24.0), side * _rng.randf_range(24.0, 38.0))
	if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
		return
	var at := p + Vector3(0, HEIGHT * 0.9, 0)
	if _ray_blocked(cam.global_position, at):
		return
	var e: Node3D = ENEMY_EYES.new()
	_world_root.add_child(e)
	e.call("setup", "girl", 0.0, null)
	e.set("anchor", null)
	e.set("point", at)
	e.set("tilt", float(_eyes.get("tilt")) if _eyes != null else 0.1)
	_decoy = {"eyes": e, "at": at, "t": _rng.randf_range(3.5, 6.0)}
	_sound(SFX_GIGGLE, at, -18.0, _rng.randf_range(0.85, 1.0), 30.0)


func _drop_decoy() -> void:
	if _decoy.is_empty():
		return
	var e: Node3D = _decoy["eyes"]
	if e != null and is_instance_valid(e):
		e.queue_free()
	_decoy = {}


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
	_step_in_dark = false
	# Her step, in this dark: you see her eyes there, nearer, before the light is back.
	if d < TOO_CLOSE:
		_advance(true)
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

## The strike, about four seconds you cannot move or look away from (Richard, 20. 10.:
## "10/10 morbid"), in steps of twelve a second like the rest of her:
##   lunge   she comes out of the dark at you, arms far too long, hands at the lens
##   grab    her hands close round your head from both sides; your head is pulled in to
##           her face, the drooling grin an inch off, twitching; a wet giggle in your ear
##   snap    her head jerks over on its neck, the frame jumps
##   split   her face splits open down the middle like a second mouth, teeth along both
##           edges; the tearing, her shriek in static; blood on the lens
##   bite    her mouth comes over you, rings of teeth into the throat: the crunch, red,
##           blood all over the lens, the ring in your ears
##   black   chewing, wet, under the ring; you go over sideways
##   after   you are on the ground, the picture on its side, blood running down it; out
##           there she stands with her head upside down on her neck and giggles; a blink
##           and she is not there
const T_LUNGE := N + "girl5_lunge.png"
const T_HANDS := N + "girl5_hands.png"
const T_SPLIT := N + "girl5_split.png"
const T_MAW := N + "girl5_maw.png"
const T_UPSIDE := N + "girl5_upside.png"
const SFX_TEAR := "res://assets/sfx/npc/sm_tear.mp3"
const SFX_BITE := "res://assets/sfx/npc/sm_bite.mp3"
const SFX_SNAP := "res://assets/sfx/npc/sm_snap.mp3"
const SFX_RUSTLE := "res://assets/sfx/npc/sm_rustle.mp3"
const STRIKE_SEC := 4.5
var _strike_cam := {}
var _after_light: OmniLight3D
var _strike_side := 1.0


func _t5(path: String, fallback: Texture2D) -> Texture2D:
	return _tex.get(path, fallback)


## Her open jaw, only the mouth: what comes over you when she bites.
var _mouth_tex: AtlasTexture


func _mouth() -> Texture2D:
	if _mouth_tex != null:
		return _mouth_tex
	var f := _face(2)
	if f == null:
		return null
	var at := AtlasTexture.new()
	_mouth_tex = at
	at.atlas = f
	var w := float(f.get_width())
	var h := float(f.get_height())
	at.region = Rect2(w * 0.25, h * 0.52, w * 0.5, h * 0.48)
	return at


func _start_strike() -> void:
	_phase = STRIKE
	_drop_decoy()
	if _eyes != null:
		_eyes.set("want", 0.0)
	_strike_t = 0.0
	_strike_cues.clear()
	_release_player()
	_strike_side = -1.0 if _rng.randf() < 0.5 else 1.0
	# You cannot move or look away: you are turned to her.
	if _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	var to := _body.global_position - _player_pos()
	_player.rotation.y = atan2(-to.x, -to.z)
	var cam := _camera()
	_strike_cam = {"pitch0": cam.rotation.x if cam != null else 0.0, "roll0": cam.rotation.z if cam != null else 0.0}
	_set_audio(0.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
	_sound(SFX_RUSH, _player_pos() + _forward_flat() * 1.2, 4.0, 1.15, 12.0)
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


func _ear_sfx(file: String, db: float, pitch: float = 1.0) -> void:
	_sound(file, _player_pos() + Vector3(0, 1.55, 0) + _forward_flat() * 0.15, db, pitch, 6.0)


func _cam_set(pitch: float, roll: float) -> void:
	var cam := _camera()
	if cam == null or _strike_cam.is_empty():
		return
	cam.rotation.x = float(_strike_cam["pitch0"]) + pitch
	cam.rotation.z = float(_strike_cam["roll0"]) + roll


func _update_strike(dt: float) -> void:
	_strike_t += dt
	var fx := _fx()
	var st := floorf(_strike_t * 12.0) / 12.0
	var face0 := _face(0)
	var hands: Texture2D = _tex.get(T_HANDS)
	if fx != null:
		fx.set_dread("girl", 1.0)
		# Not the full tunnel while her face is there: it would eat the art.
		# After the bite your heart stops: no drone, no beat, only the ring and her eating.
		fx.set_presence("girl", 0.45 if st < 1.9 else (0.0 if st < 2.9 else 0.4))
	# Lunge.
	if st < 0.3:
		var k := st / 0.3
		if fx != null:
			fx.close_up(_t5(T_LUNGE, face0), lerpf(0.35, 1.15, k), 1.0, 0.01 + 0.02 * k, _twitch(st))
		_cam_set(0.0, 0.0)
	# Grab: her hands round your head, pulled in to her face.
	elif st < 1.0:
		var k := (st - 0.3) / 0.7
		if fx != null:
			fx.close_up(face0, lerpf(1.05, 1.32, k), 1.0, 0.012, _twitch(st))
			if hands != null:
				fx.overlay(hands, 1.0 + 0.08 * k, 0.005)
		_cam_set(-0.08 * k, 0.05 * sin(st * 37.0))
		if _cue(0.3, "grab"):
			_ear_sfx(SFX_RUSTLE, 2.0, 0.9)
			_ear_sfx(SFX_DROOL, 4.0, 0.9)
			if fx != null:
				fx.freeze(0.05)
				fx.glitch(0.4, 0.4)
		if _cue(0.62, "giggle"):
			_ear_sfx(SFX_GIGGLE, 0.0, 0.85)
	# Snap: her head jerks over on its neck.
	elif st < 1.12:
		if fx != null:
			# Her head goes over on its neck, all the way: upside down.
			fx.close_up(_face(1), 1.38, 1.12, 0.03, _strike_side * (0.7 if st < 1.06 else PI))
			if hands != null:
				fx.overlay(hands, 1.1, 0.012)
		_cam_set(-0.1, 0.22 * _strike_side)
		if _cue(1.0, "snap"):
			_sound(SFX_SNAP, _player_pos() + _forward_flat() * 0.5 + Vector3(0, 1.5, 0), 4.0, 0.8, 8.0)
			_ear_sfx(SFX_SNAP, 0.0, 1.3)
			if fx != null:
				fx.red_flash(0.25)
	# Split: the face opens down the middle like a second mouth.
	elif st < 1.65:
		var k := (st - 1.12) / 0.53
		if fx != null:
			if _tex.has(T_SPLIT):
				fx.close_up(_tex[T_SPLIT], lerpf(1.25, 1.72, k), lerpf(1.0, 1.12, k), 0.02 + 0.025 * k, _twitch(st) * 1.5)
			else:
				# Her own face cut down the middle and pulled apart, the inside between.
				fx.close_up_off()
				fx.split(face0, lerpf(1.3, 1.55, k), floorf(k * 6.0) / 6.0, 0.012 + 0.02 * k)
			if hands != null:
				fx.overlay(hands, 1.12 + 0.1 * k, 0.014)
		_cam_set(-0.12, 0.05 * _strike_side + 0.04 * sin(st * 45.0))
		if _cue(1.12, "tear"):
			_ear_sfx(SFX_TEAR, 6.0, 0.9)
			_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 4.0, 0.85)
			if fx != null:
				fx.glitch(0.45, 0.6)
				fx.blood(0.35, Vector2(0.5, 0.45))
	# Bite: the mouth over you.
	elif st < 2.0:
		var k := (st - 1.65) / 0.35
		if fx != null:
			fx.overlay_off()
			fx.split_off()
			fx.close_up(_t5(T_MAW, _mouth()), lerpf(1.2, 3.2, k * k), 1.0, 0.04, _twitch(st) * 2.0)
		_cam_set(-0.16 - 0.1 * k, 0.04 * _strike_side)
		if _cue(1.9, "bite"):
			_hurt(_hit)
			claimed = true
			_ear_sfx(SFX_BITE, 8.0, 0.9)
			_ear_sfx(SFX_SNAP, 3.0, 0.8)
			if fx != null:
				fx.red_flash(1.0)
				fx.blood(1.0)
				fx.tinnitus(6.0)
				fx.glitch(1.0, 1.0)
	# Black: chewing under the ring; you go over sideways.
	elif st < 2.9:
		var k := (st - 2.0) / 0.9
		if fx != null:
			fx.close_up_off()
			fx.set_black(1.0)
		_cam_set(lerpf(-0.26, -0.1, k), lerpf(0.0, 1.3, k) * _strike_side)
		if _cue(2.15, "chew"):
			_ear_sfx(SFX_DROOL, -2.0, 0.7)
		if _cue(2.5, "chew2"):
			_ear_sfx(SFX_BITE, -8.0, 0.75)
	# After: on the ground, the picture on its side; she stands out there, head upside
	# down, and giggles; a blink and she is gone.
	elif st < STRIKE_SEC:
		var k := (st - 2.9) / (STRIKE_SEC - 2.9)
		_cam_set(-0.1 * (1.0 - clampf((st - 3.95) / 0.35, 0.0, 1.0)), 1.3 * _strike_side * (1.0 - clampf((st - 3.95) / 0.35, 0.0, 1.0)))
		if fx != null:
			fx.set_black(clampf(1.0 - (st - 2.9) / 0.5, 0.0, 1.0) if st < 3.75 else (1.0 if st < 3.84 else 0.0))
		if _cue(2.9, "after"):
			var p := _ground(_player_pos() + _forward_flat() * 6.5)
			if p != Vector3.INF:
				_body.global_position = p
				var up := _upside()
				if up != null:
					_set_body_texture(up)
				else:
					_set_body_tex(_stage(mini(3, M.size() - 1)))
				_body.visible = true
				# Her eyes in the upside-down head, red.
				if _eyes != null:
					var spot: Vector2 = _eye_spot.get(_body.texture, Vector2(0.0, float(_body.texture.get_height()) * 0.86))
					_eyes.set("height", spot.y * _body.pixel_size)
					_eyes.set("x_off", spot.x * _body.pixel_size)
					_eyes.set("tint", Color(0.95, 0.08, 0.05))
					_eyes.set("size_k", 1.4)
					_eyes.set("gap_k", 1.3)
					_eyes.set("want", 1.0)
				if _after_light == null:
					_after_light = OmniLight3D.new()
					_after_light.light_color = Color(0.62, 0.66, 0.82)
					_after_light.omni_range = 4.5
					_after_light.light_energy = 2.2
					_root.add_child(_after_light)
				_after_light.global_position = p + Vector3(0, 2.2, 0.6)
				_after_light.visible = true
		if _cue(3.25, "giggle_far"):
			_sound(SFX_GIGGLE, _body.global_position + Vector3(0, 1.5, 0), -2.0, 0.55, 30.0)
		if _cue(3.8, "gone"):
			_body.visible = false
			if _eyes != null:
				_eyes.set("want", 0.0)
			if _after_light != null:
				_after_light.visible = false
		# A blink, and her face upside down is in yours; then nothing.
		if fx != null and st >= 3.86 and st < 4.08:
			fx.close_up(_face(0), 1.3, 1.0, 0.03, PI + _twitch(st))
			if _cue(3.86, "last"):
				_ear_sfx(SFX_SCREAM, 4.0, 0.6)
				fx.glitch(0.9, 0.5)
				fx.red_flash(0.4)
				fx.blood(0.4)
		elif fx != null and st >= 4.08:
			fx.close_up_off()
		if k >= 1.0:
			pass
	else:
		_end_strike()


func _end_strike() -> void:
	_cam_set(0.0, 0.0)
	_strike_cam = {}
	var fx := _fx()
	if fx != null:
		fx.set_black(0.0)
		fx.close_up_off()
		fx.set_presence("girl", 0.0)
	if _after_light != null:
		_after_light.visible = false
	if _eyes != null:
		_eyes.set("tint", Color(0, 0, 0, 0))
		_eyes.set("want", 0.0)
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
