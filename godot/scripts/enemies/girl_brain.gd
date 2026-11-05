extends "res://scripts/enemies/enemy_base.gd"

## The Girl: a Cheap Chick guest of yours, turned for the night (DESIGN Â§5).
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
## instead. And a woman humming. And her laugh (the user 5. 11.: "the iconic sound of the
## Cheap Chick: she laughs so that you know where she is"; Richard's own cut, girl_laugh):
## out in the dark from where she really is, every few seconds the further off she is; her
## going round the lamp and her wall in the night laugh it too.
##
## The terror pass (Richard, 20. 10.: "total terror"):
##   the dead torch  close, when your torch dies in your hand she takes her step in that
##                   dark, and you see her eyes there, nearer, before the light comes back
##   the lamp's edge under a lamp she cannot come in: she goes round the edge of its light,
##                   a little further each time you look away, towards your back
##   your heart      the pressure, the drone and the heart (nightmare_fx.set_presence) as
##                   she comes, more in a dead torch
##
## You go in and she is still out there (the user 5. 11.: "make it real: when she is after
## me and I slip inside and step straight back out she will still be there; the player
## listens to her sounds, and when they stop it means she is far off; she simply loses
## interest in the building"): she comes up to the door you went in by and stands a little
## off it, tries the door and the window, then loses interest and goes off into the dark,
## and all that time you follow her by ear through the walls, her humming and her heels,
## nearer, further, gone. Out while you hear her and there she is; out after the quiet and
## she is far off, and it is a while before she notices you (the user: "give the player a
## chance to get out of the building, she is not to camp right at the door").
##
## A loop, the same grammar as every night thing:
##   omen      far out, the eyes and the humming; the first time it is still the guest in
##             her own clothes, standing much too still
##   approach  look away (or let the light leave her) and she is closer and changed: the
##             smile wider, then legs too long, then her back to you with her face turned
##             round, then her arms hanging to the ground, then an arm reaching too far
##             (no crawling on all fours: "weird, not scary", 18. 10.); heels scurry on
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
## (4. 11.: all the girl4 stages and the reach drawn after the guest herself, host3, for
## the grit of the first phase; drawn after a drawing of her they came out too clean.
## girl4_tall's render is narrowed to three quarters: a third too long, as she was asked.)
const M := [[N + "girl_m1.png"], [N + "girl4_m2.png", N + "girl_m2.png"], [N + "girl4_tall.png", N + "girl2_tall.png"], [N + "girl4_back.png", N + "girl_m3.png"], [N + "girl4_arms.png"]]
const REACH_TEX := N + "girl4_reach.png"
## The strike, in order (playtest 18. 10.: girl_face_b is the one): drooling, then the
## face stretched long, then the jaw dropped further than it can.
const FACES := [[N + "girl4_face.png", N + "girl_face_b.png"], [N + "girl4_face_long.png"], [N + "girl4_face_jaw.png", N + "girl3_face_b.png"]]
## Eyeshine: the torch must point this close to her (degrees) for her eyes to catch it,
## out to this far.
const SHINE_DEG := 16.0
const SHINE_RANGE := 45.0
const HEEL := "res://assets/textury/pipes/red_shoe.png"
## Her loops as seamless OGG looped by their import (ambience_loop.py --trim --lufs=-23):
## the MP3s looped in code clicked at every repeat and, their copies having no path,
## never reached the other wardens (coop_night mirrors a sound by its path).
const SFX_STATIC := "res://assets/sfx/npc/girl_static.ogg"
const SFX_HUM := "res://assets/sfx/npc/girl_hum.ogg"
## The one-shots of the same two (the burst at the curse, the humming in your room).
const SFX_STATIC_ONE := "res://assets/sfx/npc/girl_static.mp3"
const SFX_HUM_ONE := "res://assets/sfx/npc/girl_hum.mp3"
const WORLD_SOUNDS := preload("res://scripts/ambient/world_sounds.gd")
const SFX_HEEL := "res://assets/sfx/npc/girl_heel.mp3"
const SFX_RUSH := "res://assets/sfx/npc/girl_rush.mp3"
const SFX_STING := "res://assets/sfx/npc/girl_sting.mp3"
const SFX_GIGGLE := "res://assets/sfx/npc/girl_giggle.mp3"
const SFX_LAUGH := "res://assets/sfx/npc/girl_laugh.mp3"
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
## There behind you: this long more before her next step (her laugh, and time to turn round).
const BEHIND_GRACE := 1.5
## You go in with her this near and she comes for the door; further off she did not see.
const INTEREST_FROM := 26.0
## At the door this long, then she loses interest.
const LOSES_INTEREST := Vector2(16.0, 26.0)
const TO_DOOR_SPEED := 3.2
const OFF_SPEED := 2.0
## She stands out in front of the door you went in by, this far off it: stepping out you walk
## straight at her, and have her before you (never closer than OUT_NEAR when you are out),
## with this long more before her next step: the torch, or back in.
const DOOR_STAND := 6.0
const OUT_NEAR := 4.0
const OUT_MOMENT := 1.5
## She tries the door and the window from this near.
const TRIES_NEAR := 9.0
## You hear her through the walls to this far; past it she is gone.
const HEARD_TO := 30.0
## Out after the quiet: she is this far off, and it is OUT_GRACE before she notices you;
## nearer, less, and from NOTICES_NEAR in, not at all.
const OUT_DIST := Vector2(30.0, 38.0)
const OUT_GRACE := 20.0
const NOTICES_NEAR := 8.0

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
## Co-op: another warden's torch on her this tick. It holds her as yours does: no step,
## no step in your dead torch, not suddenly behind you.
var _held := false
## Her interference out of your sight (nightmare_fx.set_jam): from this far, full this near.
const JAM_FROM := 16.0
const JAM_FULL := 3.0
const FOUND_EVERY := 2.5
var _found_ok_at := 0.0
var _found_quiet_until := 0.0
var _behind_done := false
var _jump_ready := false
var _fake_done := false
var _strike_cues := {}
var _tex := {}
var _static: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
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
var _far_laugh_next := 6.0
var _eye_tilt0 := 0.12
## Her head turned upside down on her neck (made from her art: the head cut out and
## flipped), and where its eyes are.
var _upside_tex: ImageTexture
## Gone round the lamp this loop; her own eyes glowing behind you by themselves till then.
var _round_done := false
var _eyes_stay_until := -1.0
## Indoors (an outdoor hunter: she cannot hurt you in there; see the top). From the door,
## a pause between: her laugh and three slow knocks; her at the window you look at, pressed
## to the glass; her teeth chattering behind the wall. Gone off, now and then one of your
## guests instead, and nothing of that heard.
var _in_room := false
var _away_in := false
var _lure_n := 0
var _lure_next := -1.0
## Where she is out there while you are in (INF: gone off, or she never came), the door you
## went in by, when she loses interest, the way she goes then.
var _out_pos := Vector3.INF
var _door_at := Vector3.ZERO
var _stand_at := Vector3.ZERO
var _loses_at := -1.0
var _off_dir := Vector3.ZERO
## She has been after you out there since you last went in (a night that begins with you
## in has not).
var _after_you := false
var _heel_next := 0.0
var _guest_next := -1.0
## Her humming through the walls, by how far she is (a warden on another machine: in phrases).
var _wall_hum: AudioStreamPlayer
var _hum_next := 0.0
## Out of a door with her far off: till then she has not noticed you.
var _out_until := -1.0
## Her laugh is one voice (the user 5. 11.: "she lays several laughs over each other"):
## wherever it would come out while it is still going, it does not. Till when; any of her.
static var _voice_until := 0.0
var _glass_until := -1.0
var _glass_light: OmniLight3D
var _sound2d: AudioStreamPlayer
## Hers from out there while you are inside: through the walls, muffled.
var _wall2d: AudioStreamPlayer
## The guest herself, far off, till you have once had a good look at her so (1 s seen): her
## first unseen step no longer wasted it.
var _guest_seen := 0.0
var _guest_done := false
## The stage she has come to this round: never back (a jitter showed her younger nearer).
var _stage_floor := 0
## The heels she left: the last three stay, not one every round all night.
var _heels: Array = []
## The window she is at (where it is in the camp): she goes from it unseen, not on a timer.
var _glass_at := Vector3.INF
## Every sound of hers, loaded at the start of her night: never off the disk mid-scare.
var _sfx_cache: Array = []
const ROUND_AFTER := 6.0
## Far off, found again, she is not standing as a person stands: upside down, hanging
## from nothing, or far too tall. Till she moves.
var _pose_flip := false
var _pose_tall := 1.0
## Teeth chattering in the dark, close, while you do not look.
var _chatter_next := 6.0
## After she has had you: for a while her face is still there for a frame now and then.
var _residue_until := -1.0
var _residue_next := 4.0
const T_SMILE := N + "girl6_smile.png"
const FX_TEX := preload("res://scripts/night/fx_tex.gd")
const T_CROWD := N + "girl6_crowd.png"
const T_EYE := N + "girl6_eye.png"
const HUSH_DIST := 4.5


func get_enemy_id() -> String:
	return "girl"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_after = lerpf(2.4, 1.3, t)
	_step = Vector2(lerpf(2.2, 3.2, t), lerpf(3.6, 5.2, t))
	_hit = int(lerpf(30.0, 45.0, t))
	for p in [GUEST, REACH_TEX, T_LUNGE, T_HANDS, T_SPLIT, T_MAW, T_UPSIDE, T_SMILE, T_CROWD, T_EYE]:
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
	var consts: Dictionary = get_script().get_script_constant_map()
	for k in consts:
		var v = consts[k]
		if v is String and (v as String).begins_with("res://assets/sfx/") and ResourceLoader.exists(v):
			_sfx_cache.append(load(v))
	_static = _loop(SFX_STATIC, -60.0)
	_hum = _loop(SFX_HUM, -60.0)
	if _hum != null:
		# Her humming carries: the omen far off (it was heard within ~10 m only).
		_hum.max_distance = 45.0
	_sound2d = AudioStreamPlayer.new()
	_root.add_child(_sound2d)
	_wall2d = AudioStreamPlayer.new()
	_wall2d.bus = WORLD_SOUNDS.wall_bus("Master")
	_root.add_child(_wall2d)
	_wall_hum = AudioStreamPlayer.new()
	_wall_hum.bus = _wall2d.bus
	_wall_hum.stream = load(SFX_HUM)
	_root.add_child(_wall_hum)
	_begin_loop()


func _on_stop() -> void:
	_release_player()
	_hide_glass()
	_hush_walls()
	if not _strike_cam.is_empty():
		_cam_set(0.0, 0.0)
		_view_end()
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


# â”€â”€ the loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

## Omen: out in the dark, far, humming; the guest still, in her own clothes.
func _begin_loop() -> void:
	_stage_floor = 0
	_phase = OMEN
	_unseen_for = 0.0
	_in_lamp_for = 0.0
	# (Not looking the other way for a new loop's sake: it had her at your back within the
	# second, every time.)
	_away_for = 0.0
	_stutter_next = _rng.randf_range(2.5, 4.5)
	var dist := _rng.randf_range(18.0, 24.0) - 2.0 * float(mini(_round, 3))
	if _elapsed < _out_until:
		dist = _rng.randf_range(OUT_DIST.x, OUT_DIST.y)
	_behind_done = false
	_fake_done = false
	_breath_done = false
	_round_done = false
	_set_pose(false)
	for _i in 16:
		# Off to one side of where you look: you can find her if you look for her.
		var side := _rng.randf_range(35.0, 150.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := _point_from_player(dist, side)
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		_place_body(p)
		_set_look(_round == 0, dist)
		_sound(SFX_HEEL, p, -4.0, _rng.randf_range(0.9, 1.05), 40.0)
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
		_set_audio(0.0, false)
		_tick_residue(dt)
		var fxg := _fx()
		if fxg != null:
			fxg.set_presence("girl", 0.0)
		if _elapsed >= _gone_until:
			_begin_loop()
		return
	if not _body.visible:
		_begin_loop()
		return
	_after_you = true
	var noticed := _elapsed >= _out_until
	var head := _body.global_position + Vector3(0, _head_height(), 0)
	var d := _distance_to_player(_body.global_position)
	var torch_on_her := _in_flashlight(head)
	var lit := torch_on_her or _lamp_light_at(_body.global_position) > 0.12 or d < SEE_CLOSE
	var looking := _is_seen(head, -4.0)
	var stuttering := _stutter_t > 0.0
	var sees := looking and lit and not stuttering
	_held = _lit_by_others(head)
	_away_for = 0.0 if looking or _held else _away_for + dt
	if noticed and not _behind_done and _away_for >= BEHIND_AFTER and d < 22.0 and _wall_clock() >= _voice_until and _rng.randf() < dt * 1.5:
		_go_behind()
		return
	if sees and _jump_ready:
		_jump_ready = false
		_jumpscare()
	_tick_curse(dt, sees and d < 16.0)
	_tick_far_laugh(dt, d)
	if sees and _body.texture == _tex.get(GUEST):
		_guest_seen += dt
		if _guest_seen >= 1.0:
			_guest_done = true
	if sees:
		_announce("Two white pinpricks out in the dark. Someone is standing there, and she hasn't moved.")
		_unseen_for = 0.0
		if torch_on_her:
			_player.set("flashlight_drain_boost", 5.0)
		if _moved_unseen:
			_moved_unseen = false
			if d < JAM_FROM:
				_found(d)
	elif not _held:
		if noticed:
			_unseen_for += dt * (2.5 if stuttering else 1.0)
		_tick_chatter(dt, d)
	# Another warden's machine holds the cold till told: off the moment your torch is off her.
	if _quarry_peer() != 0 and not (sees and torch_on_her):
		_player.set("flashlight_drain_boost", 0.0)
	# Under a lamp you are out of her reach; long enough and she lets this loop go.
	if _lamp_light_at(_player_pos()) > LAMP_SAFE:
		_in_lamp_for += dt
		if noticed and _in_lamp_for >= ROUND_AFTER and not _round_done:
			_round_the_lamp()
		# (Not before your eyes: she lets it go when you look away.)
		if _in_lamp_for >= GIVE_UP_IN_LAMP and not sees:
			_sound(SFX_LAUGH, head, -5.0, 0.97, 60.0)
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
	var near := clampf(1.0 - d / 22.0, 0.0, 1.0)
	_hush = d < HUSH_DIST and not looking
	_set_audio(near, not _hush and _elapsed >= _found_quiet_until)
	if _hush and not _breath_done and d < 3.0:
		_breath_done = true
		_near_you(_sound(SFX_DROOL, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.3, -1.0, 0.8, 5.0))
	var fxp := _fx()
	if fxp != null:
		var in_lamp := _lamp_light_at(_player_pos()) > LAMP_SAFE
		var lv := 1.0 if _hush else clampf(near * near * 0.9 + (0.25 if stuttering and d < TOO_CLOSE else 0.0), 0.0, 1.0)
		fxp.set_presence("girl", 0.0 if in_lamp else lv)
		# Out of your sight, she jams you from where she is.
		if not sees and not in_lamp and d < JAM_FROM:
			fxp.set_jam("girl", _eyes_world(), _camera(), clampf((JAM_FROM - d) / (JAM_FROM - JAM_FULL), 0.0, 1.0))
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
	_set_pose(false)
	_jump_ready = true
	_moved_unseen = false
	_unseen_for = -BEHIND_GRACE
	_sound(SFX_LAUGH, p + Vector3(0, 1.5, 0), -6.0, 1.02)


## Face to face after the turn: the sting, her face over everything for three frames,
## the picture tearing.
func _jumpscare() -> void:
	_near_you(_sound(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), 0.5))
	_near_you(_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 3.0, 1.25))
	var fx := _fx()
	if fx != null:
		fx.glitch(0.85, 0.9)
		fx.red_flash(0.35)
		fx.blood(0.15)


## Not looked at: she is closer, and changed; heels scurry where she went. Now and then
## she only changes where she stands. `small`: the step she takes in a dead torch.
func _advance(small: bool) -> void:
	var from := _body.global_position
	var to_player := _player_pos() - from
	to_player.y = 0.0
	var dist := to_player.length()
	if not small and _rng.randf() < 0.15 and dist > 6.0:
		_set_look(_round == 0 and not _guest_done, dist)
		_moved_unseen = true
		return
	var want := _rng.randf_range(0.8, 1.3) if small else _rng.randf_range(_step.x, _step.y) * (1.0 + 0.15 * float(mini(_round, 4)))
	var step := minf(want, maxf(0.0, dist - 0.4))
	var sideways := to_player.normalized().cross(Vector3.UP) * (_rng.randf_range(-0.3, 0.3) if small else _rng.randf_range(-1.4, 1.4))
	var target := _stand(from + to_player.normalized() * step + sideways)
	if target == Vector3.INF:
		return
	# Lamp light is a wall to her: she goes round its edge instead, towards your back.
	if _lamp_light_at(target) > LAMP_SAFE:
		target = _round_the_light(from, dist)
		if target == Vector3.INF:
			return
	_body.global_position = target
	var nd := _distance_to_player(target)
	_set_look(_round == 0 and not _guest_done, nd)
	_set_pose(not small and nd > 12.0 and _rng.randf() < 0.3)
	_moved_unseen = true
	_sound(SFX_HEEL if small else SFX_RUSH, target, lerpf(-3.0, -16.0, clampf(nd / 22.0, 0.0, 1.0)), _rng.randf_range(0.92, 1.08))
	if nd < JAM_FROM and _fx() != null:
		_fx().jam_burst(lerpf(1.0, 0.45, nd / JAM_FROM))
	# The nearest lamp out there stutters as she passes it (never one you stand under).
	if not small and _rng.randf() < 0.35 and _building_manager != null and _building_manager.has_method("darken_lamp_near"):
		if _lamp_light_at(_player_pos()) <= LAMP_SAFE:
			_building_manager.call("darken_lamp_near", target, 7.0, _rng.randf_range(0.3, 0.8))


## You have her again: the set catches its picture (nightmare_fx.lock), the nearer the harder.
## Once in a while only: looking away and back is not a new find.
func _found(d: float) -> void:
	var fx := _fx()
	if fx == null or _elapsed < _found_ok_at:
		return
	_found_ok_at = _elapsed + FOUND_EVERY
	# And for a moment nothing of her either: "oukej, teď dobrý".
	_found_quiet_until = _elapsed + 0.7
	var tall := float(_body.texture.get_height()) * _body.pixel_size * _body.scale.y
	fx.lock(clampf(1.0 - d / JAM_FROM, 0.35, 1.0), _body.texture, _body.global_position, _body.global_position + Vector3(0, tall, 0), _camera())


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
		var p := _stand(me + dir * maxf(dist - 0.3, 2.0))
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		var k := fwd.dot(dir)
		if k < best_k:
			best_k = k
			best = p
	return best


## The base ticks nothing while you are indoors; she is still out there (_tick_room). Back
## out, she is where she got to.
func tick(delta: float) -> void:
	if _night_active and _phase != STRIKE:
		if not _is_ready():
			if not _away_in:
				_away_in = true
				_went_in()
			_tick_room(delta)
		elif _away_in:
			_away_in = false
			_in_room = false
			_hide_glass()
			_came_out()
	super(delta)
	if _night_active and _away_in and _glass_until > 0.0 and _body != null:
		_body.visible = true
		_tick_eyes(delta)


func _wall_clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _indoors_now() -> bool:
	return _quarry_indoors()


## You went in: was she after you? Then she stays what she was, a woman out there.
func _went_in() -> void:
	_set_audio(0.0, false)
	_door_at = _player_pos()
	_stand_at = _door_at - _forward_flat() * DOOR_STAND
	_off_dir = Vector3.ZERO
	var after := _after_you and _phase == STALK and _body.visible and _distance_to_player(_body.global_position) < INTEREST_FROM
	_after_you = false
	_out_pos = _body.global_position if after else Vector3.INF
	_loses_at = _elapsed + _rng.randf_range(LOSES_INTEREST.x, LOSES_INTEREST.y)
	# (_lure_n counts on over the night: going in and out does not start her over.)
	_lure_next = _wall_clock() + _rng.randf_range(3.0, 5.0)
	_heel_next = 0.0
	_hum_next = 0.0
	_guest_next = _wall_clock() + _rng.randf_range(70.0, 110.0)


## Out again: she is where she got to. Near, the hunt goes on from there (she holds while
## you have her in the light, as ever); gone off, she is out in the dark, and it is a while
## before she notices you.
func _came_out() -> void:
	_hush_walls()
	var p := _out_pos
	_out_pos = Vector3.INF
	var d := HEARD_TO if p == Vector3.INF else _distance_to_player(p)
	_out_until = _elapsed + OUT_GRACE * clampf((d - NOTICES_NEAR) / (HEARD_TO - NOTICES_NEAR), 0.0, 1.0)
	_away_for = 0.0
	_jump_ready = false
	# Her laugh, far off: where she is, when you step out into it.
	if d > 15.0:
		_far_laugh_next = minf(_far_laugh_next, _rng.randf_range(2.0, 5.0))
	if p == Vector3.INF:
		if _phase != GONE or _elapsed >= _gone_until:
			_begin_loop()
		return
	# Not on top of you (hot on your heels as you went in, or a door that lets you out by
	# another step than it took you in): ahead of you, where the door faces.
	if d < OUT_NEAR + 1.5:
		p = _player_pos() + _forward_flat() * (OUT_NEAR + 1.5)
		d = OUT_NEAR + 1.5
	var q := _stand(p)
	for _i in 8:
		if q != Vector3.INF and _lamp_light_at(q) <= LAMP_SAFE:
			break
		q = _point_from_player(d, _rng.randf_range(-150.0, 150.0))
	if q == Vector3.INF or _lamp_light_at(q) > LAMP_SAFE:
		_begin_loop()
		return
	_place_body(q)
	_set_look(_round == 0 and not _guest_done, d)
	_set_pose(false)
	_phase = STALK
	_unseen_for = -OUT_MOMENT
	_moved_unseen = false
	_behind_done = true
	_last_d = d


func _hush_walls() -> void:
	if _wall_hum != null and is_instance_valid(_wall_hum):
		_wall_hum.stop()


func _tick_room(dt: float) -> void:
	if not _indoors_now():
		# (The boat, the town: not a door she stands at.)
		_in_room = false
		_out_pos = Vector3.INF
		_hush_walls()
		return
	_in_room = true
	if _glass_until > 0.0 and _wall_clock() >= _glass_until and not _glass_looked_at():
		_hide_glass()
	if _out_pos == Vector3.INF:
		if _wall_clock() >= _guest_next:
			_guest_next = _wall_clock() + _rng.randf_range(90.0, 150.0)
			_visit_guest()
		return
	var walking := _walk_out_there(dt)
	var d := Vector2(_out_pos.x - _door_at.x, _out_pos.z - _door_at.z).length()
	if d >= HEARD_TO:
		_out_pos = Vector3.INF
		_hush_walls()
		return
	_through_walls(d, walking)
	if _elapsed >= _loses_at or d >= TRIES_NEAR or _glass_until > 0.0 or _wall_clock() < _lure_next:
		return
	_lure_next = _wall_clock() + _rng.randf_range(5.0, 8.0)
	# Only the warden she hunts hears it (co-op).
	if _fx() == null:
		return
	_room_lure(_lure_n)
	_lure_n += 1


## Where she goes while you are in: up to the door and a little off it (or to the edge of its
## lamp's light: she does not step into it), then, interest lost, away. Whether she walks.
func _walk_out_there(dt: float) -> bool:
	if _glass_until > 0.0:
		return false
	if _elapsed < _loses_at:
		var to := _stand_at - _out_pos
		to.y = 0.0
		var d := to.length()
		if d <= 0.05:
			return false
		var next := _out_pos + to / d * minf(TO_DOOR_SPEED * dt, d)
		if _lamp_light_at(next) > LAMP_SAFE:
			return false
		_out_pos = next
		return true
	if _off_dir == Vector3.ZERO:
		var out := _out_pos - _door_at
		out.y = 0.0
		out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		_off_dir = out.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-40.0, 40.0)))
	_out_pos += _off_dir * OFF_SPEED * dt
	return true


## What comes of her through the walls, by how far she is from the door: her humming, her
## heels, a step at a time while she walks, a shift of her weight while she stands.
func _through_walls(d: float, walking: bool) -> void:
	var k := clampf((d - DOOR_STAND) / (HEARD_TO - DOOR_STAND), 0.0, 1.0)
	var hum_db := lerpf(-8.0, -40.0, k)
	if _quarry_peer() != 0:
		if _wall_clock() >= _hum_next:
			_hum_next = _wall_clock() + 5.8
			_room_2d(SFX_HUM_ONE, hum_db, 0.95, true)
	elif _wall_hum != null:
		_wall_hum.volume_db = hum_db
		if not _wall_hum.playing:
			_wall_hum.play()
	if _wall_clock() >= _heel_next:
		_heel_next = _wall_clock() + (_rng.randf_range(0.5, 0.75) if walking else _rng.randf_range(2.5, 5.0))
		_room_2d(SFX_HEEL, lerpf(-9.0, -36.0, k), _rng.randf_range(0.9, 1.05), true)


## From by the door: the three, in turn, a pause between.
func _room_lure(n: int) -> void:
	var scene := _world_root.get_tree().current_scene
	var im = scene.get("_interior_manager") if scene != null else null
	match n % 3:
		0:
			_room_2d(SFX_LAUGH, -7.0, 0.98, true)
			for i in 3:
				_later(1.3 + 0.9 * float(i), func(): _room_2d("res://assets/sfx/director/knock.mp3", -6.0, 0.85))
		1:
			if not _at_glass(im):
				_room_2d("res://assets/sfx/director/window_tap.mp3", -4.0, 0.9)
		_:
			for i in 12:
				_later(0.05 * float(i), func(): _room_2d(SFX_SNAP, -7.0, _rng.randf_range(2.2, 2.8), true))
			_later(1.2, func(): _room_2d(SFX_DROOL, -9.5, 0.8, true))


func _later(seconds: float, f: Callable) -> void:
	if _root != null and _root.is_inside_tree():
		_root.get_tree().create_timer(seconds).timeout.connect(func():
			if _night_active and _away_in:
				f.call())


## A sound of her while you are inside. `wall`: she is out there and it comes through the
## walls, muffled; not the knock, the tap on the glass or the sting.
func _room_2d(file: String, db: float, pitch: float = 1.0, wall := false) -> void:
	if not _voice_free(file, pitch):
		return
	if _play_2d_remote(file, db, pitch, wall):
		return
	var base := _wall2d if wall else _sound2d
	if base == null or not ResourceLoader.exists(file):
		return
	# One sound over another: each its own player when the one is busy.
	var p := base
	if p.playing:
		p = AudioStreamPlayer.new()
		p.bus = base.bus
		_root.add_child(p)
		p.finished.connect(p.queue_free)
	p.stream = load(file)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## The room you are in (any with windows: the office, a cabin, a caravan, a service block;
## in co-op the other warden's): she stands at the window you look at, its curtain open,
## pressed to the glass, her face in it and her eyes; for two frames, the face she
## pretends with.
func _at_glass(_im) -> bool:
	var wins: Array = _room_windows().filter(func(c): return float(c.get("open", 1.0)) >= 0.35)
	if wins.is_empty():
		return false
	var w: Dictionary = wins[0]
	for c in wins:
		if float(c.get("facing", 0.0)) > float(w.get("facing", 0.0)):
			w = c
	var p := _floor_at((w["pos"] as Vector3) + (w["out"] as Vector3) * 0.3)
	_glass_at = w["pos"]
	if p == Vector3.INF:
		return false
	_room_2d("res://assets/sfx/director/window_tap.mp3", -6.0, 1.1)
	_body.global_position = p
	_set_pose(false)
	_set_body_tex(_stage(0) if _stage(0) != "" else GUEST)
	_body.visible = true
	_glass_until = _wall_clock() + _rng.randf_range(3.5, 5.0)
	if _eyes != null:
		var spot: Vector2 = _eye_spot.get(_body.texture, Vector2(0.0, float(_body.texture.get_height()) * 0.86))
		_eyes.set("height", spot.y * _body.pixel_size)
		_eyes.set("x_off", spot.x * _body.pixel_size)
		_eyes.set("view_from", w.get("view", (w["pos"] as Vector3) - (w["out"] as Vector3) * 1.5))
		_eyes.set("want", 1.0)
		_eyes.set("size_k", 1.6)
		# Her face in the middle of the glass, a step off the ground at most (a window set
		# higher shows her from the chest up: she does not float, nor stand in a hole).
		var y := (w["pos"] as Vector3).y - float(_eyes.get("height")) - 0.04
		_body.global_position.y = clampf(y, p.y - 0.15, p.y + 0.15)
	if _glass_light == null:
		_glass_light = OmniLight3D.new()
		_glass_light.light_color = Color(1.0, 0.8, 0.55)
		_glass_light.omni_range = 2.2
		_glass_light.light_energy = 1.0
		_root.add_child(_glass_light)
	_glass_light.global_position = (w["pos"] as Vector3) + (w["out"] as Vector3) * 0.15
	_glass_light.visible = true
	if float(w.get("facing", 0.0)) > 0.8 and _tex.has(T_SMILE):
		_later(0.8, func(): _room_2d(SFX_STING, -2.0, 0.9))
	_later(1.6, func(): _room_2d(SFX_GIGGLE, -10.0, 0.7, true))
	return true


## Her laugh and her giggle: not while one is still going. (Free: this one takes its turn.)
func _voice_free(file: String, pitch: float) -> bool:
	if file != SFX_LAUGH and file != SFX_GIGGLE:
		return true
	var now := _wall_clock()
	if now < _voice_until:
		return false
	var s := load(file) as AudioStream
	_voice_until = now + (s.get_length() if s != null else 4.0) / maxf(pitch, 0.1)
	return true


func _sound(path: String, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 40.0) -> AudioStreamPlayer3D:
	if not _voice_free(path, pitch):
		return null
	return super(path, at, volume_db, pitch, max_dist)


## You look at the window she is at: she does not go while you watch her there.
func _glass_looked_at() -> bool:
	for w in _room_windows():
		if (w["pos"] as Vector3).distance_to(_glass_at) < 0.5:
			return float(w.get("facing", 0.0)) > 0.82
	return false


func _hide_glass() -> void:
	if _glass_until < 0.0:
		return
	_glass_until = -1.0
	if _body != null:
		_body.visible = false
	if _eyes != null:
		_eyes.set("view_from", Vector3.INF)
		_eyes.set("want", 0.0)
	if _glass_light != null:
		_glass_light.visible = false


## Hide long enough and it is somebody else: a guest's night goes wrong (one of the
## Cheap Chicks first: she was one of them).
func _visit_guest() -> void:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or GuestManager == null:
		return
	var pick := {}
	for g in state.guests:
		if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
			pick = g
			if str(g.get("archetype", "")) == "cheap_chick":
				break
	if pick.is_empty():
		return
	GuestManager.apply_guest_event(int(pick.get("id", -1)), -18.0, "A woman stood outside all night, laughing at nothing. She knew my name.")


## Upside down (hanging from nothing, her feet up in the dark) or far too tall; else as a
## person stands.
func _set_pose(wrong: bool) -> void:
	_pose_flip = false
	_pose_tall = 1.0
	if wrong:
		if _rng.randf() < 0.5:
			_pose_flip = true
		else:
			_pose_tall = _rng.randf_range(1.45, 1.75)
	_body.flip_v = _pose_flip
	_body.scale = Vector3(1.0 / sqrt(_pose_tall), _pose_tall, 1.0)


## Close, while you do not look: her teeth, chattering, fast, from where she is.
func _tick_chatter(dt: float, d: float) -> void:
	if d > 8.0 or _root == null or not _root.is_inside_tree():
		return
	_chatter_next -= dt
	if _chatter_next > 0.0:
		return
	_chatter_next = _rng.randf_range(5.0, 10.0)
	var at := _eyes_world() - Vector3(0, 0.1, 0)
	var n := _rng.randi_range(8, 14)
	for i in n:
		_root.get_tree().create_timer(0.055 * float(i)).timeout.connect(func():
			if _phase == STALK:
				_sound(SFX_SNAP, at, lerpf(-2.5, -11.0, d / 8.0), _rng.randf_range(2.1, 2.7), 14.0))


## Under a lamp long enough: she goes round the edge of its light to your back, herself, her
## laugh from there and her own eyes in the dark a while. Once a loop. (Every eye that shines
## out there is really one of them, the user 5. 11.: "the only glowing eyes will really be
## the enemy, no fakes": no pairs of her eyes round the lamp, no second pair to one side.)
func _round_the_lamp() -> void:
	_round_done = true
	var p := _point_from_player(_rng.randf_range(7.0, 9.0), 180.0 + _rng.randf_range(-25.0, 25.0))
	if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
		return
	_body.global_position = p
	_set_look(false, _distance_to_player(p))
	_moved_unseen = true
	_eyes_stay_until = _elapsed + 5.0
	_sound_quarry(SFX_LAUGH, p + Vector3(0, 1.5, 0), -9.0, 0.97, 30.0)
	_near_you(_sound_quarry(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), 0.5, 0.8))


## For a while after she has had you: your head not your own for a moment now and then,
## even with her gone; the torch catching in your hand.
func _tick_residue(dt: float) -> void:
	if _elapsed >= _residue_until:
		return
	_residue_next -= dt
	if _residue_next > 0.0:
		return
	_residue_next = _rng.randf_range(5.0, 11.0)
	var fx := _fx()
	if fx == null:
		return
	if fx.has_method("fever_pulse"):
		fx.fever_pulse(0.55, 1.6)
	if _flashlight_on() and _rng.randf() < 0.5:
		_player.set("flashlight_stutter", 1.0)
		_root.get_tree().create_timer(0.12).timeout.connect(func():
			if _player != null and is_instance_valid(_player):
				_player.set("flashlight_stutter", 0.0))


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
	_sound(SFX_STATIC_ONE, _body.global_position + Vector3(0, 1.4, 0), 3.0, 0.7, 30.0)


## Her laugh out of the dark, from where she really is: the further off, the more often,
## carried far (a big unit size: you hear where); now and then slowed down into something
## low and long.
func _tick_far_laugh(dt: float, d: float) -> void:
	_far_laugh_next -= dt
	if _far_laugh_next > 0.0 or d < 9.0:
		return
	_far_laugh_next = lerpf(14.0, 7.0, clampf((d - 9.0) / 30.0, 0.0, 1.0)) * _rng.randf_range(0.8, 1.25)
	# (Not noticed you yet: the next when she has.)
	_far_laugh_next = maxf(_far_laugh_next, _out_until - _elapsed)
	var slow := _rng.randf() < 0.18
	var p := _sound(SFX_LAUGH, _body.global_position + Vector3(0, 1.5, 0), -6.0 if slow else -3.0,
		_rng.randf_range(0.5, 0.6) if slow else _rng.randf_range(0.96, 1.04), 80.0)
	if p != null:
		p.unit_size = 9.0


## Her own art with the head cut out and turned upside down on the neck: the cap at the
## bottom, the hair falling up, the grin the wrong way up. Made once.
func _upside() -> Texture2D:
	if _upside_tex != null:
		return _upside_tex
	var src: Texture2D = _tex.get(T_UPSIDE, _tex.get(GUEST))
	if src == null:
		return null
	_upside_tex = FX_TEX.flip_head(src, 0.17)
	if _upside_tex == null:
		return null
	# Its eyes: where the art's are, mirrored in the head.
	var h := float(src.get_height())
	var top := float(_upside_tex.get_meta("flip_top", 0))
	var hh := float(_upside_tex.get_meta("flip_h", 0))
	var spot: Vector2 = _eye_spot.get(src, _find_eyes(src))
	var from_top := h - spot.y
	_eye_spot[_upside_tex] = Vector2(spot.x, h - (top + hh - (from_top - top)))
	return _upside_tex


## Her look by how near she is: the guest herself only the first time, far off; then
## the smile, the long legs, the face turned round over her back, her arms to the ground,
## reaching.
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
			i = maxi(i, mini(_stage_floor, have.size() - 1))
			_stage_floor = i
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
	var eh := spot.y * _body.pixel_size
	if _pose_flip:
		eh = float(_body.texture.get_height()) * _body.pixel_size - eh
	_eyes.set("height", eh * _pose_tall)
	_eyes.set("x_off", spot.x * _body.pixel_size)
	# Her face stretching: nearer, wider apart and bigger.
	var near := clampf(1.0 - d / 16.0, 0.0, 1.0)
	_eyes.set("gap_k", 1.0 + 1.1 * near * near)
	_eyes.set("size_k", 1.0 + 0.35 * near)
	# Near, they sit wrong on her face: one higher, more and more.
	_eyes.set("tilt", _eye_tilt0 + signf(_eye_tilt0) * 0.55 * near * near)
	_eyes.set("want", 1.0 if _shines(d, lit) or (stuttering and d < TOO_CLOSE) or (_elapsed < _eyes_stay_until and not lit) else 0.0)


func _shines(d: float, lit: bool) -> bool:
	if lit or d > SHINE_RANGE or not _flashlight_on():
		return false
	var aim: Dictionary = _player.call("get_flashlight_aim") if _player.has_method("get_flashlight_aim") else {}
	if aim.is_empty():
		return false
	var to: Vector3 = _eyes_world() - (aim["origin"] as Vector3)
	return (aim["dir"] as Vector3).normalized().dot(to.normalized()) >= cos(deg_to_rad(SHINE_DEG))


## The torch dies in your hand now and then when she is close: a moment of dark she uses.
## Walking towards her, it dies much more often, and each time she is a step nearer.
func _update_stutter(dt: float, d: float, coming: bool) -> void:
	if _stutter_t > 0.0:
		_stutter_t -= dt
		if _stutter_t <= 0.0:
			_player.set("flashlight_stutter", 0.0)
			if _step_in_dark:
				_step_in_dark = false
				if not _held:
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
	if d < TOO_CLOSE and not _held:
		_advance(true)
	var fx := _fx()
	if fx != null:
		if not _fake_done and d < 8.0:
			# Once a loop, in the dead torch: a shriek cut short.
			_fake_done = true
			fx.glitch(0.6, 0.5)
			_near_you(_sound_quarry(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 3.0, 1.4))


# â”€â”€ the strike â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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


## Co-op: only the one she hunts sees her while she scares them (the strike, right behind
## them, at their window, close, the frames she is not as she is).
func is_private_now() -> bool:
	if _phase == STRIKE or _jump_ready or _glass_until > 0.0 or _curse_frames > 0 or _elapsed < _eyes_stay_until:
		return true
	return _body != null and _body.visible and _distance_to_player(_body.global_position) < 6.0


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
	_set_pose(false)
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
	_view_begin()
	_set_yaw(atan2(-to.x, -to.z))
	var cam := _camera()
	_strike_cam = {"pitch0": cam.rotation.x if cam != null else 0.0, "roll0": cam.rotation.z if cam != null else 0.0}
	_set_audio(0.0, false)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
	_near_you(_sound(SFX_RUSH, _player_pos() + _forward_flat() * 1.2, -2.0, 1.15, 12.0))
	_near_you(_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 3.0))


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
	_near_you(_sound(file, _player_pos() + Vector3(0, 1.55, 0) + _forward_flat() * 0.15, db, pitch, 6.0))


## A sound at you (your ear, your face) at the gain written: 0.3 m off it got +20 dB from
## its nearness and every one hit the 3D player's ceiling (+3) alike; its unit size the
## distance it is at takes that out.
func _near_you(p: AudioStreamPlayer3D) -> void:
	var cam := _camera()
	if p != null and cam != null:
		p.unit_size = maxf(0.05, cam.global_position.distance_to(p.global_position))


func _cam_set(pitch: float, roll: float) -> void:
	if _strike_cam.is_empty():
		return
	_set_pitch(float(_strike_cam["pitch0"]) + pitch)
	_set_roll(float(_strike_cam["roll0"]) + roll)


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
	# Her eye, an inch from yours, for a step; then the lunge.
	if st < 0.09 and _tex.has(T_EYE):
		if fx != null:
			fx.close_up(_tex[T_EYE], 1.25, 1.0, 0.006, 0.0)
		_cam_set(0.0, 0.0)
	elif st < 0.3:
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
			_ear_sfx(SFX_DROOL, -1.0, 0.9)
			if fx != null:
				fx.freeze(0.05)
				fx.glitch(0.4, 0.4)
		if _cue(0.62, "giggle"):
			_ear_sfx(SFX_GIGGLE, -3.0, 0.85)
	# Snap: her head jerks over on its neck.
	elif st < 1.12:
		if fx != null:
			# Her head goes over on its neck, all the way: upside down.
			fx.close_up(_face(1), 1.38, 1.12, 0.03, _strike_side * (0.7 if st < 1.06 else PI))
			if hands != null:
				fx.overlay(hands, 1.1, 0.012)
		_cam_set(-0.1, 0.22 * _strike_side)
		if _cue(1.0, "snap"):
			_sound(SFX_SNAP, _player_pos() + _forward_flat() * 0.5 + Vector3(0, 1.5, 0), -0.5, 0.8, 8.0)
			_ear_sfx(SFX_SNAP, -1.0, 1.3)
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
			_ear_sfx(SFX_TEAR, -0.5, 0.9)
			_near_you(_sound(SFX_SCREAM, _player_pos() + Vector3(0, 1.5, 0), 3.0, 0.85))
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
			_ear_sfx(SFX_BITE, 1.0, 0.9)
			_ear_sfx(SFX_SNAP, -0.5, 0.8)
			if fx != null:
				fx.red_flash(1.0)
				fx.blood(1.0)
				fx.tinnitus(6.0)
				fx.glitch(1.0, 1.0)
	# Black: chewing under the ring; you go over sideways; she drags you along the
	# ground by the head, in jerks, the picture coming and going.
	elif st < 2.9:
		var k := (st - 2.0) / 0.9
		if fx != null:
			fx.close_up_off()
			var drag := st >= 2.3 and st < 2.8
			fx.set_black(1.0 if not drag else (0.35 if int(st * 12.0) % 2 == 0 else 0.8))
		_cam_set(lerpf(-0.26, -0.1, k), lerpf(0.0, 1.3, k) * _strike_side)
		for i in 5:
			var at := 2.3 + 0.1 * float(i)
			if _cue(at, "drag%d" % i):
				var to := _ground(_player_pos() + _forward_flat() * 0.45)
				if to != Vector3.INF:
					_move_player(to + Vector3(0, 0.05, 0))
				_ear_sfx(SFX_HEEL, -4.0, 0.45)
				_ear_sfx(SFX_RUSTLE, -6.0, 0.7)
		if _cue(2.15, "chew"):
			_ear_sfx(SFX_DROOL, -2.0, 0.7)
		if _cue(2.5, "chew2"):
			_ear_sfx(SFX_BITE, -1.5, 0.75)
	# After: on the ground, the picture on its side; she stands out there, head upside
	# down, and giggles; a blink and she is gone.
	elif st < STRIKE_SEC:
		var k := (st - 2.9) / (STRIKE_SEC - 2.9)
		_cam_set(-0.1 * (1.0 - clampf((st - 3.95) / 0.35, 0.0, 1.0)), 1.3 * _strike_side * (1.0 - clampf((st - 3.95) / 0.35, 0.0, 1.0)))
		if fx != null:
			fx.set_black(clampf(1.0 - (st - 2.9) / 0.5, 0.0, 1.0) if st < 3.75 else (1.0 if st < 3.84 else 0.0))
		if _cue(2.9, "after"):
			var p := _stand(_player_pos() + _forward_flat() * 6.5)
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
					# (Not blue: no blue night lady, 18. 10.)
					_after_light.light_color = Color(0.82, 0.78, 0.72)
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
				_ear_sfx(SFX_SCREAM, 3.0, 0.6)
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
	_residue_until = _elapsed + 40.0
	_residue_next = _rng.randf_range(3.0, 6.0)
	_set_pose(false)
	_cam_set(0.0, 0.0)
	_view_end()
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
		_heels.append(heel)
		while _heels.size() > 3:
			var old = _heels.pop_front()
			if old != null and is_instance_valid(old):
				(old as Node).queue_free()
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


## Her humming and the static by how near she is; `there` false (gone, the hush, the
## strike): nothing of them left where she last stood.
func _set_audio(near: float, there := true) -> void:
	for a in [_static, _hum]:
		if a != null and is_instance_valid(a):
			a.global_position = _body.global_position + Vector3(0, 1.3, 0)
	if _static != null:
		_static.volume_db = lerpf(-36.0, 3.0, near * near) if there else -80.0
	if _hum != null:
		_hum.volume_db = lerpf(-12.0, 3.0, near) if there else -80.0
