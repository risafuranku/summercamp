extends "res://scripts/enemies/enemy_base.gd"
class_name SilentManBrain

## The Silent Man: a Quiet Guy guest of yours, turned for the night (DESIGN §5). His hat,
## his glasses, his shirt; where his mouth was, smooth skin. Rule: DO NOT STAND STILL IN
## THE DARK.
##
## He is the camp's nuisance more than its killer (playtest 18. 10.): light always beats
## him. What he does is be there, round the corner, every time you leave the light.
##
##   lurk      while you are in light (a lamp) or indoors he waits in the dark round a
##             corner 7-13 m off, somewhere you cannot see from where you stand: a man
##             humming through a mouth that is sealed shut. Now and then he leans out
##             past the corner for a moment. Come out of a building and he is round the
##             corner by its door.
##   approach  step out of the light and THE HUMMING STOPS: he is coming. He only moves
##             while you are not looking his way. Walking, his steps fall half a beat
##             after yours (you lose them in your own); stop, and there is one step more
##             after you stopped. Standing still in the dark he comes on slow careful
##             steps, closer each time; running puts you ahead of him. Close, cloth
##             rustling and breath through the nose. Turn round and you may catch him
##             mid-stride, frozen there.
##   test      the light: put light on him (torch or a lamp he stands in) and his glasses
##             flare, a sharp breath, and he comes apart into the dark, a dither of game
##             pixels going back a step, a little dark ash going up; then a new corner.
##   strike    at your back he whispers at your ear: about a second to turn round or get
##             away. If not, one of his catches (at your ear, over you from above, or he
##             turns you round to him); the skin over his mouth tears open; he bites.
##   kill      when that bite would be your last, he finishes it his way: the hands round
##             your throat, your neck turned round, or the mouth that opens over your face.
##
## He has a real position (the sprite stands there, lit only by your light), so the HUD
## face and the insects (threat_senses.gd) track the same place you hear.
##
## The sixth sense (playtest 20. 10.: "the longer he gets to come on in one go, the more
## the game must tell you, by picture and by sound, that something is wrong"): a pressure
## builds while you are out in the dark and he is coming, faster the closer he is, and
## drains in the light. It is what you feel (nightmare_fx.set_presence): a drone in the
## ears that climbs, your heart, slow and then fast, the picture's edges closing in, the
## torch catching and stuttering in your hand. At your neck: his breath, cloth, the
## frame stops for a beat, his hands coming over your shoulder from the side he is on,
## and he holds you (you move at half speed): turn round, or get away.
##
## The first time (the first in this camp, never scripted to a place): when you first
## step out of the light the humming stops and he is there in front of you, at the edge
## of the light, caught mid-stride; look at him and he goes. The first time he reaches
## your neck he does not bite: he turns you round to him, face to face, the skin over his
## mouth pulling, and comes apart into the dark. (No text says so: the turn teaches it.)
##
## Indoors he does not hurt you and does not try to get you out (the user, 21. 10.): now
## and then he is out there, far off in the dark beyond a window, standing still and
## watching you, his glasses two points in the black; look away and when you look back he
## is nearer; after a while he is not there. Between, seldom, a sound of him: one slow step
## on the gravel, his humming far off, a breath at the wall; late, now and then, his face
## over the ceiling or a tap at the glass.
## In co-op only the warden he hunts feels any of it; the other's torch drives him off
## too (the counter for two: watch each other's backs).
##
## He calls you out (the user 5. 11.: "sounds to lure you out of the buildings, heard from
## far off outside, nothing typically horror, that give you goosebumps"; and then: "he does
## that far too often, he should really only do it now and then from far off, when you are
## in a cabin, say, like Freddy Fazbear"): not every night, once or twice in one, while you
## sit inside, from a long way out in the dark: a man with no mouth humming, the same to
## the last wobble every time (`SFX_CALL`; tools/audiogen/fever_dream.py far_call). His
## humming round his corner is as rare: a phrase, then nothing for minutes.
##
## Your own torch on him has its price (playtest 25. 10.): his glasses throw the light back
## and the bulb goes dead in your hand for three seconds, then catches again, flickering
## (player_controller.torch_blackout). More Quiet Guys turned, more of him (main starts
## one brain each, up to three): light one and the others come on in the dark while you
## have none, so you choose whom. Only one of them at your neck at a time.

const FX_TEX := preload("res://scripts/night/fx_tex.gd")
const WORLD_SOUNDS := preload("res://scripts/ambient/world_sounds.gd")
const FIGURE = preload("res://scripts/figures/doom_figure.gd")
const N := "res://assets/textury/npc/"
const GUEST := N + "host1.png"
const T_M1 := N + "sm_m1.png"
const T_M2 := N + "sm_m2.png"
const T_WALK := [N + "sm_walk_a.png", N + "sm_walk_b.png"]
const T_LIT := N + "sm_lit.png"
const T_FACE := N + "sm_face.png"
const T_TEAR := N + "sm_face_tear.png"
const T_UPSIDE := N + "sm_face_upside.png"
const T_HANDS := N + "sm_hands.png"
const T_OVER := N + "sm_over.png"
## Worse (21. 10., the user: "like the Girl, almost over the line"): the sealed mouth
## splitting in a cross on a throat of teeth; a second face pushing out through it; the
## neck that comes round a corner without him; on the ceiling; his thumbs on your eyes.
const T_CROSS := N + "sm_face_cross.png"
const T_SECOND := N + "sm_face_second.png"
const T_NECK := N + "sm_neck_long.png"
const T_CEILING := N + "sm_ceiling.png"
const T_EYES := N + "sm_hands_eyes.png"
const SFX_THROAT := "res://assets/sfx/npc/sm_throat.mp3"
const SFX_STRETCH := "res://assets/sfx/npc/sm_stretch.mp3"
const SFX_CEILING := "res://assets/sfx/npc/sm_ceiling.mp3"
const SFX_SECOND := "res://assets/sfx/npc/sm_second_voice.mp3"
const SFX_CALL := "res://assets/sfx/npc/sm_call_far.ogg"
## The wait between his calls (s), the first, how loud (-23 LUFS), and what each one more this
## stay adds, up to CALL_NEAR_MAX.
## His burning out of the world (`_driven_off`): at most this often.
const LOCK_EVERY := 6.0
const CALL_NIGHTS := 0.6
const CALLS_A_NIGHT := 2
const CALL_WAIT := Vector2(45.0, 150.0)
const CALL_DB := -7.0
## His humming round his corner: this long, this long apart.
const HUM_SEC := Vector2(4.0, 7.0)
const HUM_EVERY := Vector2(70.0, 160.0)
const SFX_STEPS := "res://assets/sfx/npc/silent_steps.mp3"
const SFX_STEP := "res://assets/sfx/npc/sm_step.mp3"
const SFX_WHISPER := "res://assets/sfx/npc/silent_whisper.mp3"
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"
const SFX_HUM := "res://assets/sfx/npc/sm_hum.mp3"
const SFX_BREATH := "res://assets/sfx/npc/sm_breath.mp3"
## The same as his loops: seamless OGG, looped by their import (tools/audiogen/
## ambience_loop.py --trim; the MP3s clicked or gapped at every repeat, and a loop set
## in code does not travel to the other warden). The MP3s stay for his one-shots.
const SFX_HUM_LOOP := "res://assets/sfx/npc/sm_hum.ogg"
const SFX_BREATH_LOOP := "res://assets/sfx/npc/sm_breath.ogg"
const SFX_MMM := "res://assets/sfx/npc/sm_mmm.mp3"
const SFX_CREAK := "res://assets/sfx/npc/sm_creak.mp3"
const SFX_TEAR := "res://assets/sfx/npc/sm_tear.mp3"
const SFX_SNAP := "res://assets/sfx/npc/sm_snap.mp3"
const SFX_CHOKE := "res://assets/sfx/npc/sm_choke.mp3"
const SFX_BITE := "res://assets/sfx/npc/sm_bite.mp3"
const SFX_STING := "res://assets/sfx/npc/sm_sting.mp3"
const SFX_VANISH := "res://assets/sfx/npc/sm_vanish.mp3"
const SFX_RUSTLE := "res://assets/sfx/npc/sm_rustle.mp3"
const SFX_SOFTSTEP := "res://assets/sfx/npc/sm_softstep.mp3"

const START_DIST := 14.0
const NECK_DIST := 1.6
const DARK_LIGHT := 0.35
const RUN_SPEED := 4.2
const HEIGHT := 1.82
const WALK_SECONDS := 0.55
const LIT_SECONDS := 0.9
const STRIKES := ["ear", "above", "turn", "cross"]
## Lurking: how far off, and how dark the spot must be.
const LURK_DIST := Vector2(7.0, 13.0)
const LURK_DARK := 0.15
const DISSOLVE_FRAMES := 6
const KILLS := ["strangle", "snap", "bite", "inside", "eyes"]

var _dist := START_DIST
var _step_gain := 1.6
var _step_interval := 2.2
var _grace := 1.2
var _damage := 16
var _next_step := 0.0
var _resume_at := 0.0
var _neck_until := -1.0
var _neck_from := Vector3.ZERO
var _last_player_pos := Vector3.INF
var _speed := 0.0
var _hits := 0
var _drive_offs := 0
## Seen: he flinches where the light found him and backs off till then, then is gone.
var _vanish_at := -1.0
var _shown_guest := false
## How long you have had him in sight as the guest himself (from far, the first time).
var _guest_seen := 0.0
var _tex := {}
## His set from eight sides (npc/sets/silent_s1, Richard 3. 11.): standing, the walk and
## near with the neck drawn out, each seen from where you are. The rest of him (in the
## light, the neck round a corner, the faces) is drawn from the front only.
const FIG_OF := {T_M1: "stand", T_M2: "near"}
## His glasses in a frame of the set, down from the top of his hat by the frame's height
## (as in sm2_m1 10/128, his walk 11-12/136, near sm2_m2 17/160).
const FIG_EYE_ROW := {"stand": 0.078, "walk": 0.085, "near": 0.106}
var _fig: Dictionary = {}
var _fig_img: Image
var _fig_anim := ""
var _fig_frame := 0
var _fig_yaw := 0.0
var _fig_sector := 99
var _fig_back := false
var _fig_atlas: Dictionary = {}
var _fig_eyes: Dictionary = {}
var _walk_odd := false
## Where his glasses are in each piece of art (sm2_*, texels from the top, the middle
## between them from the left, the head's tilt): his eyes in the dark sit on them.
const EYES_AT := {GUEST: [12.0, 31.5, 0.0], T_M1: [10.0, 19.5, 0.0], T_M2: [17.0, 21.5, -0.42],
	T_LIT: [13.5, 24.5, 0.0], "walk0": [12.0, 22.5, 0.0], "walk1": [11.0, 23.0, 0.0], T_NECK: [45.0, 67.0, -0.15]}
var _hum: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _walk_t := -1.0
var _back_dir := Vector3.ZERO
## A catch in progress: {kind, t, cues, kill, yaw0, roll0}.
var _seq := {}
var _last_strike := ""
var _lurking := false
var _lurk_spot := Vector3.INF
var _peek_spot := Vector3.INF
var _peek_next := 6.0
var _peek_t := 0.0
var _away := false
var _was_moving := false
var _extra_step_at := -1.0
var _rustle_next := 3.0
var _dissolve := {}                # texture -> Array of ImageTexture (more gone each frame)
var _ash: GPUParticles3D
var _last_kill := ""
## The sixth sense: 0..1, built in the dark while he comes, drained in the light.
var _press := 0.0
var _stutter_next := 2.0
## His hands at your shoulder, from this side (1 right, -1 left), while he holds you.
var _hold_side := 1.0
## The first meeting in this camp: the reveal at the edge of the light, the lesson catch.
var _first := false
var _revealed := false
var _reveal_t := -1.0
var _reveal_seen := 0.0
var _lesson := false
## The chance at each of his moments at your back that the face shows, and the night it
## last did.
const FACE_CHANCE := 0.06
var _face_night := -1


func _night_no() -> int:
	var main: Node = _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return int(main.get("_day_index")) if main != null and main.get("_day_index") != null else 0


## Indoors: when he next calls you out, and how many times this stay.
var _call_next := 0.0
## Calls left tonight, and the night they are for.
var _calls := 0
var _calls_night := -1
var _hum_until := -1.0
var _hum_next := -1.0
var _lock_ok_at := 0.0
## Indoors: when the next moment of him, and how many there were.
var _lure_next := -1.0
var _lure_n := 0
## Watching through a window: which window (its index in the room's windows), how far off
## he stands, how many steps nearer he has come, whether you are looking at him now, and
## how long you have.
var _watch_win := -1
var _watch_dist := 0.0
var _watch_steps := 0
var _watch_seen := false
var _watch_looked := 0.0
var _watch_side := 0.0
var _indoors := false
var _sound2d: AudioStreamPlayer
## His sounds from out there while you are inside: through the walls, muffled.
var _wall2d: AudioStreamPlayer
## A face in the corner of your eye, two frames, when it gets bad.
var _sub_next := 5.0
## At a cabin's window while you are inside: until when.
var _glass_until := -1.0
## The room's light falling out through the glass onto him.
var _glass_light: OmniLight3D
## Late, him on the ceiling of the room you are in, over you (Richard 3. 11.: really there):
## there till you have looked up at him and away again, or a while unlooked at.
var _ceil: Sprite3D
var _ceil_seen := false
var _ceil_until := -1.0
## The stare: while you are under a lamp he stands out in the open dark facing you, his
## glasses on you, and every time you look away he is a step nearer the light's edge.
var _staring := false
var _stare_unseen := 0.0
var _stare_moved := false
## Out of the light: the glasses go dark, both at once (the one time they ever do), and
## stay dark till he has taken his first step.
var _eyes_out := false
## His head going over as he comes: the glasses tilt more the nearer he is; close, it
## cocks hard. This night's way (+1 or -1), the art's own tilt, and the extra now.
var _tilt_sign := 1.0
var _pose_tilt := 0.0
var _tilt_extra := 0.0
## Your torch's beam far past where it lights anything: his lenses catch it (a sting the
## first time each round).
var _glint_stung := false
## Glasses that are not him: at the edges of your view in the dark, when it is worst;
## look at one and it goes out. Only the warden he hunts sees them (not under _root).
var _phantoms: Array = []
var _phantom_next := 3.0
const STARE_CHANCE := 0.5
## Your torch dead after it drives him off (s), and its flicker back on.
const TORCH_DARK_SEC := 3.0
## How long your torch has him before the bulb goes (s).
const TORCH_FIND_SEC := 0.65
const TORCH_BACK_SEC := 1.1
## The one of them at your neck now (only one at a time).
static var _striker: Object = null
## The one of him who does the first meeting, when two or three are out the first night.
static var _first_one: WeakRef = null
## This one's own name for the night's picture and sound (several of him at once).
var _fx_key := "silent_man"
const STARE_DIST := Vector2(9.0, 15.0)
const STARE_MIN := 5.0
const GLINT_RANGE := 45.0


func get_enemy_id() -> String:
	return "silent_man"


## Co-op: only the one he hunts sees him while he scares them (a catch, at their neck,
## the first meeting, his flare, at their window, close behind them, his neck round the
## corner: it comes round the corner only from where they stand).
func is_private_now() -> bool:
	return not _seq.is_empty() or _neck_until > 0.0 or _reveal_t >= 0.0 or _vanish_at > 0.0 or _glass_until > 0.0 or (not _lurking and _dist < 5.0) 		or (_peek_t > 0.0 and _tex.has(T_NECK) and _body != null and _body.texture == _tex[T_NECK])


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_gain = lerpf(1.3, 2.2, t)
	_step_interval = lerpf(2.6, 1.6, t)
	_grace = lerpf(1.4, 1.0, t)
	_damage = int(lerpf(14.0, 24.0, t))
	_lure_n = 0
	_fig = FIGURE.set_of("silent_s1")
	if not _fig.is_empty() and _fig.get("tex") is Texture2D:
		_fig_img = (_fig["tex"] as Texture2D).get_image()
		if _fig_img != null and _fig_img.is_compressed():
			_fig_img.decompress()
	# Each piece of art by its first name; the body-horror round (sm2_*) wins where it is
	# there (playtest 18. 10.: the first round was "not disgusting enough").
	for p in [GUEST, T_M1, T_M2, T_LIT, T_FACE, T_TEAR, T_UPSIDE, T_HANDS, T_OVER, T_CROSS, T_SECOND, T_NECK, T_CEILING, T_EYES] + T_WALK:
		for alt in [p.replace("/sm_", "/sm2_"), p]:
			if ResourceLoader.exists(alt):
				_tex[p] = load(alt)
				break
	_body = _make_body(GUEST, HEIGHT)
	_make_eyes("silent_man", HEIGHT * 0.92)
	var nth := int(_night_entry.get("nth", 0)) if _night_entry is Dictionary else 0
	if nth > 0:
		_fx_key = "silent_man#%d" % nth
	_hum = _loop(SFX_HUM_LOOP, -60.0)
	_breath = _loop(SFX_BREATH_LOOP, -60.0)
	_reset_far(_rng.randf_range(3.0, 6.0))
	_first = not _met() and (_first_one == null or _first_one.get_ref() == null)
	if _first:
		_first_one = weakref(self)
	_tilt_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	_sound2d = AudioStreamPlayer.new()
	_root.add_child(_sound2d)
	_wall2d = AudioStreamPlayer.new()
	_wall2d.bus = WORLD_SOUNDS.wall_bus("Master")
	_root.add_child(_wall2d)


## The night is over (dawn, death, the menu): nothing of a catch stays on the screen.
## The base ticks nothing while you are indoors (or it is not night); back out, he is
## round the corner by the door you came out of.
func tick(delta: float) -> void:
	if _night_active and _seq.is_empty():
		var ready := _is_ready()
		if not ready:
			_away = true
			# (Gone in while he held you: his hands off the screen too, not left there.)
			_neck_until = -1.0
			_end_hold()
			_clear_phantoms()
			_tick_indoors(delta)
		elif _away:
			_away = false
			_indoors = false
			_on_return()
	super(delta)
	if _night_active and _away and _glass_until > 0.0 and _body != null:
		_body.visible = true
		_tick_eyes(delta)


func _on_return() -> void:
	_glass_until = -1.0
	_eyes_out = false
	_staring = false
	if _eyes != null:
		_eyes.set("view_from", Vector3.INF)
	if _glass_light != null:
		_glass_light.visible = false
	_neck_until = -1.0
	_vanish_at = -1.0
	_walk_t = -1.0
	_dist = START_DIST
	_resume_at = _elapsed + _rng.randf_range(1.5, 3.0)
	_next_step = _resume_at + _step_interval
	_choose_lurk()


func _on_stop() -> void:
	_end_seq()
	_end_hold()
	_clear_phantoms()
	_end_ceiling()
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0)
	if _player != null and is_instance_valid(_player):
		_player.set("flashlight_stutter", 0.0)
		if _player.has_method("set_controls_enabled"):
			_player.call("set_controls_enabled", true)


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	if _eyes != null:
		_eyes.set("want", 0.0 if _eyes_out or (_fig_anim != "" and _fig_back) else 1.0)
	_update_phantoms(dt)
	if not _seq.is_empty():
		_update_seq(dt)
		return
	_update_walk(dt)
	if _fig_anim != "" and _body.visible:
		_show_fig()
	_update_audio(dt)
	_update_presence(dt)
	_watch_guest(dt)
	if _reveal_t >= 0.0:
		_update_reveal(dt)
		return
	if _vanish_at > 0.0:
		_update_lit(dt)
		return
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	# Caught in the light: he flinches and backs off.
	if _elapsed >= _resume_at and _is_lit_and_seen(head):
		_driven_off()
		return
	if _neck_until > 0.0:
		_tick_neck()
		return
	if _elapsed < _resume_at:
		_body.visible = _lurking
		return
	_body.visible = true
	if _lamp_light_at(_player_pos()) >= DARK_LIGHT:
		_update_lurk(dt)
		return
	if _lurking and _first and not _revealed and _start_reveal():
		return
	if _lurking:
		# Out of the light: the humming stops, and the glasses go dark. He is coming.
		_lurking = false
		_staring = false
		_eyes_out = true
		_dist = minf(START_DIST, maxf(NECK_DIST + 2.0, _distance_to_player(_body.global_position)))
		_next_step = _elapsed + _rng.randf_range(0.8, 1.6)
	_update_footfall(dt)
	if _elapsed >= _next_step:
		_next_step = _elapsed + _step_interval * _rng.randf_range(0.85, 1.15)
		_step()


# ── the approach ─────────────────────────────────────────────────────────────

func _step() -> void:
	var in_light := _lamp_light_at(_player_pos()) >= DARK_LIGHT
	if in_light:
		# He waits where the light ends; now and then a twig gives him away.
		if _rng.randf() < 0.35:
			_sound(SFX_TWIG, _body.global_position + Vector3(0, 0.2, 0), -4.0, _rng.randf_range(0.9, 1.1), 30.0)
		return
	# He only moves while you are not looking his way.
	if _is_seen(_body.global_position + Vector3(0, HEIGHT * 0.7, 0), 4.0) and _dist > NECK_DIST + 0.5:
		return
	var walking := _speed > 0.6
	if _speed > RUN_SPEED:
		_dist = minf(START_DIST, _dist + 1.0)
	elif walking:
		_dist -= _step_gain * 0.5
	else:
		_dist -= _step_gain
	_dist = maxf(NECK_DIST, _dist)
	_place_behind(_dist)
	_eyes_out = false
	_tilt_head()
	var at := _walk_to + Vector3(0, 0.3, 0)
	if walking:
		# Half a beat after your own steps: lost in them.
		get_tree_timer(0.25, func(): _sound(SFX_SOFTSTEP, at, lerpf(-30.5, -20.5, 1.0 - _dist / START_DIST), _rng.randf_range(0.9, 1.05), 26.0))
	else:
		_sound(SFX_STEPS, at, lerpf(-15.0, -5.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.94, 1.04), 34.0)
	if _rng.randf() < 0.3:
		_sound(SFX_CREAK, at + Vector3(0, 1.2, 0), lerpf(-22.0, -10.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.9, 1.1), 24.0)
	_announce("Footsteps on the gravel behind you. They stop when you stop.")
	if _dist <= NECK_DIST + 0.01:
		# The first time he gives you longer: it is how the rule is learnt.
		_neck_until = _elapsed + _grace * (1.7 if _first else 1.0)
		_neck_from = _player_pos()
		_near_you(_sound(SFX_WHISPER, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.35, -3.0, 1.0, 8.0))
		_start_hold()


func get_tree_timer(seconds: float, f: Callable) -> void:
	if _root != null and _root.is_inside_tree():
		_root.get_tree().create_timer(seconds).timeout.connect(f)


## Your footfall and his: stop walking, and there is one step more after you stopped (his
## signature); close, his clothes, his breath.
func _update_footfall(dt: float) -> void:
	var moving := _speed > 0.6
	if _was_moving and _speed < 0.25 and _extra_step_at < 0.0:
		_extra_step_at = _elapsed + _rng.randf_range(0.3, 0.5)
	_was_moving = moving if moving else (_was_moving and _speed >= 0.25)
	if _extra_step_at > 0.0 and _elapsed >= _extra_step_at:
		_extra_step_at = -1.0
		if not _is_seen(_body.global_position + Vector3(0, HEIGHT * 0.7, 0), 4.0):
			_dist = maxf(NECK_DIST + 0.3, _dist - 0.5)
			_place_behind(_dist)
			_sound(SFX_STEP, _walk_to + Vector3(0, 0.3, 0), lerpf(-23.0, -13.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.95, 1.03), 30.0)
	if _dist < 5.0:
		_rustle_next -= dt
		if _rustle_next <= 0.0:
			_rustle_next = _rng.randf_range(2.5, 5.0)
			_sound(SFX_RUSTLE, _body.global_position + Vector3(0, 1.2, 0), lerpf(-4.0, -14.0, _dist / 5.0), _rng.randf_range(0.9, 1.1), 14.0)


# ── the lurk ─────────────────────────────────────────────────────────────────

## A dark spot round a corner from you: hidden from where you stand, a step aside from a
## place you could see (so he can lean out), behind or beside you rather than ahead.
func _choose_lurk() -> void:
	_eyes_out = false
	var cam := _camera()
	if cam == null:
		return
	# Sometimes not round a corner at all: out in the open dark, facing you. Never at
	# the first meeting (that one is its own).
	if not (_first and not _revealed) and _rng.randf() < STARE_CHANCE and _choose_stare(cam):
		return
	_staring = false
	var best := -1.0
	var best_p := Vector3.INF
	var best_peek := Vector3.INF
	for _i in 28:
		var ang := _rng.randf_range(0.0, 360.0)
		var p := _point_from_player(_rng.randf_range(LURK_DIST.x, LURK_DIST.y), ang)
		if p == Vector3.INF or _lamp_light_at(p) > LURK_DARK:
			continue
		var head := p + Vector3(0, HEIGHT * 0.8, 0)
		if not _ray_blocked(cam.global_position, head):
			continue
		var score := 1.0 + (0.5 if absf(wrapf(ang, -180.0, 180.0)) > 90.0 else 0.0)
		var to := (p - _player_pos())
		to.y = 0.0
		var side := to.normalized().cross(Vector3.UP)
		var peek := Vector3.INF
		for sgn in [1.0, -1.0]:
			var q := _ground(p + side * sgn * 0.8)
			if q != Vector3.INF and not _ray_blocked(cam.global_position, q + Vector3(0, HEIGHT * 0.8, 0)):
				peek = q
				score += 1.0
				break
		if score > best:
			best = score
			best_p = p
			best_peek = peek
	if best_p == Vector3.INF:
		_lurking = false
		return
	_lurking = true
	_lurk_spot = best_p
	_peek_spot = best_peek
	_peek_t = 0.0
	_peek_next = _rng.randf_range(5.0, 9.0)
	_body.global_position = best_p
	_body.visible = true
	_set_tex(_look_for(LURK_DIST.y))


## Out in the open where you can see him from your light, dark, 9-15 m off, facing you.
func _choose_stare(cam: Camera3D) -> bool:
	for _i in 24:
		var p := _point_from_player(_rng.randf_range(STARE_DIST.x, STARE_DIST.y), _rng.randf_range(0.0, 360.0))
		if p == Vector3.INF or _lamp_light_at(p) > LURK_DARK:
			continue
		if _ray_blocked(cam.global_position, p + Vector3(0, HEIGHT * 0.92, 0)):
			continue
		_lurking = true
		_staring = true
		_stare_unseen = 0.0
		_stare_moved = false
		_lurk_spot = p
		_peek_spot = Vector3.INF
		_body.global_position = p
		_body.visible = true
		_tilt_extra = 0.0
		_set_tex(_look_for(_distance_to_player(p)))
		_apply_tilt()
		return true
	return false


## The stare: still, the glasses on you. Look away, look back: a step nearer, never into
## the light. Each step his head a little further over.
func _update_stare(dt: float) -> void:
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	if _is_seen(head, 4.0):
		_stare_unseen = 0.0
		_stare_moved = false
		return
	_stare_unseen += dt
	if _stare_moved or _stare_unseen < 1.4:
		return
	_stare_moved = true
	var to := _player_pos() - _body.global_position
	to.y = 0.0
	if to.length() <= STARE_MIN:
		return
	var p := _ground(_body.global_position + to.normalized() * minf(_rng.randf_range(1.0, 1.8), to.length() - STARE_MIN))
	if p == Vector3.INF or _lamp_light_at(p) > LURK_DARK:
		return
	_body.global_position = p
	_lurk_spot = p
	_set_tex(_look_for(_distance_to_player(p)))
	_tilt_extra = _tilt_sign * clampf(_tilt_extra * _tilt_sign + 0.12, 0.0, 0.7)
	_apply_tilt()
	_sound(SFX_SOFTSTEP, p + Vector3(0, 0.3, 0), -32.5, _rng.randf_range(0.9, 1.0), 22.0)


## While you are in the light: he hums round his corner; now and then he leans out past
## it for a moment and back.
func _update_lurk(dt: float) -> void:
	if not _lurking or _lurk_spot == Vector3.INF or _distance_to_player(_lurk_spot) > LURK_DIST.y + 4.0:
		_choose_lurk()
		if not _lurking:
			return
	if _staring:
		_update_stare(dt)
		return
	if _peek_t > 0.0:
		_peek_t -= dt
		if _peek_t <= 0.0:
			_body.global_position = _lurk_spot
			_body.flip_h = false
			_set_tex(_look_for(_distance_to_player(_lurk_spot)))
		return
	_peek_next -= dt
	if _peek_next <= 0.0 and _peek_spot != Vector3.INF:
		_peek_next = _rng.randf_range(6.0, 11.0)
		_peek_t = _rng.randf_range(0.9, 1.5)
		_body.global_position = _peek_spot
		if _tex.has(T_NECK) and _rng.randf() < 0.4:
			_show_neck(_peek_spot, _lurk_spot)
			_sound(SFX_STRETCH, _peek_spot + Vector3(0, 1.6, 0), -21.5, _rng.randf_range(0.9, 1.05), 22.0)
		else:
			_sound(SFX_RUSTLE, _peek_spot + Vector3(0, 1.2, 0), -14.0, _rng.randf_range(0.9, 1.1), 20.0)


## Only his neck comes round the corner, long, the head at the end of it: the neck's
## root (the sprite's left edge) on the side he stands (`behind`), tucked behind it.
func _show_neck(at: Vector3, behind: Vector3) -> void:
	_set_tex(T_NECK)
	var cam := _camera()
	var right := cam.global_transform.basis.x if cam != null else Vector3.RIGHT
	right.y = 0.0
	var side := signf((behind - at).dot(right))
	if side == 0.0:
		side = -1.0
	# The art has the root on the left: flip it when he stands to the right.
	_body.flip_h = side > 0.0
	_body.global_position = at + right.normalized() * side * 0.45
	if _eyes != null:
		_pose_eyes(T_NECK, _body.texture)
		if side > 0.0:
			_eyes.set("x_off", -float(_eyes.get("x_off")))


## Right behind you: turn round or get away, now.
func _tick_neck() -> void:
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	if _is_seen(head, 6.0) or _player_pos().distance_to(_neck_from) > 1.8:
		_neck_until = -1.0
		_end_hold()
		_mark_met()
		_driven_off()
		return
	_update_hold()
	if _elapsed >= _neck_until:
		_neck_until = -1.0
		_end_hold()
		# Another of him has you already: this one goes back into the dark (the lesson too).
		if _striker != null and _striker != self and is_instance_valid(_striker):
			_reset_far(_rng.randf_range(3.0, 6.0))
			return
		if _first:
			# The lesson: he turns you round to him and lets you see. No bite this time.
			_lesson = true
			_mark_met()
			_start_catch("turn")
			return
		_hits += 1
		_start_catch()


## Closes in on you along the line from where he stands, so turning round finds him;
## the way there is walked (stiffly, two frames), not jumped.
func _place_behind(dist: float) -> void:
	var from := _body.global_position
	var to := _player_pos()
	var dir := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if dir.length_squared() < 0.01:
		dir = -_forward_flat()
	var p := _ground(to + dir.normalized() * dist)
	if p == Vector3.INF:
		return
	_walk_from = from
	_walk_to = p
	_walk_t = 0.0
	_walk_odd = not _walk_odd
	_set_tex(_look_for(dist))


## In steps, twelve a second: the stride frames while he walks, then the stage he is in.
func _update_walk(dt: float) -> void:
	if _walk_t < 0.0:
		return
	_walk_t += dt
	var k := clampf(_walk_t / WALK_SECONDS, 0.0, 1.0)
	var st := floorf(k * WALK_SECONDS * 12.0) / maxf(1.0, WALK_SECONDS * 12.0)
	_body.global_position = _walk_from.lerp(_walk_to, st)
	var frames: Array = T_WALK.filter(func(p): return _tex.has(p))
	if not _fig.is_empty() and k < 1.0:
		# Four frames, two strides: this step is one half of the cycle.
		_fig_frame = mini(1, int(k * 2.0)) + (2 if _walk_odd else 0)
		_set_tex(T_WALK[0])
	elif frames.size() == 2 and k < 1.0:
		_set_tex(frames[int(_walk_t * 6.0) % 2])
	if k >= 1.0:
		_walk_t = -1.0
		_body.global_position = _walk_to
		_set_tex(_look_for(_dist))


## The guest himself till you have once had a good look at him so, from far (seen, not
## only shown: round his corner he wasted it); then mouthless; near, the long neck and arms.
func _watch_guest(dt: float) -> void:
	if _shown_guest or not _body.visible or _body.texture != _tex.get(GUEST):
		return
	if _is_seen(_body.global_position + Vector3(0, HEIGHT * 0.8, 0)):
		_guest_seen += dt
		if _guest_seen >= 1.0:
			_shown_guest = true


## See _watch_guest.
func _look_for(dist: float) -> String:
	if not _shown_guest and dist > 9.0:
		return GUEST
	if dist < 6.0 and _tex.has(T_M2):
		return T_M2
	if _tex.has(T_M1):
		return T_M1
	return GUEST


func _set_tex(path: String) -> void:
	if not _fig.is_empty() and (FIG_OF.has(path) or T_WALK.has(path)):
		var a: String = "walk" if T_WALK.has(path) else str(FIG_OF[path])
		if a != "walk":
			_fig_frame = 0
		_fig_anim = a
		_show_fig()
		return
	var tex: Texture2D = _tex.get(path)
	if tex == null or (_body.texture == tex and _fig_anim == ""):
		return
	_fig_anim = ""
	_fig_back = false
	_body.texture = tex
	_body.flip_h = false
	# One pixel scale for all of him (the guest's): a stage drawn taller stands taller.
	var guest: Texture2D = _tex.get(GUEST)
	_body.pixel_size = HEIGHT / float(guest.get_height() if guest != null else tex.get_height())
	_body.offset = Vector2(0.0, float(tex.get_height()) * 0.5)
	_pose_eyes(path, tex)


## The view of him from your eye, a region of his set as an AtlasTexture (co-op mirrors
## those), turned the way he steps or, standing, to you. Each frame anew while he shows
## one: you walk round him.
func _show_fig() -> void:
	var cam := _camera()
	var eye: Vector3 = cam.global_position if cam != null else _player_pos() + Vector3(0, 1.6, 0)
	var step := _walk_to - _walk_from
	if _fig_anim == "walk" and _walk_t >= 0.0 and Vector2(step.x, step.z).length() > 0.01:
		_fig_yaw = atan2(-step.x, -step.z)
	else:
		var to := eye - _body.global_position
		_fig_yaw = atan2(-to.x, -to.z)
	_fig_sector = FIGURE.sector_for(_body.global_position, _fig_yaw, eye, _fig_sector)
	var view := absi(_fig_sector)
	var flip := _fig_sector < 0
	var anims: Dictionary = _fig.get("anims", {})
	var fr = FIGURE._frame_of(anims, _fig_anim, view, _fig_frame)
	if fr == null:
		fr = FIGURE._frame_of(anims, "stand", view, 0)
	if fr == null:
		return
	var key := str(fr)
	var at: AtlasTexture = _fig_atlas.get(key)
	if at == null:
		at = AtlasTexture.new()
		at.atlas = _fig.get("tex")
		at.region = Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3]))
		_fig_atlas[key] = at
	if _body.texture == at and _body.flip_h == flip:
		return
	_body.texture = at
	_body.flip_h = flip
	_body.pixel_size = HEIGHT / float(_fig.get("h", 128))
	var ox := float(fr[2]) * 0.5 - float(fr[4])
	_body.offset = Vector2(-ox if flip else ox, float(fr[5]) - float(fr[3]) * 0.5)
	# His glasses: on the frame's head; from the side and behind none (the other side).
	_fig_back = view >= 2
	if _eyes == null:
		return
	var g: Vector2 = _fig_eyes.get(key, Vector2.INF)
	if g == Vector2.INF:
		g = _head_of(fr)
		_fig_eyes[key] = g
	var px := _body.pixel_size
	_eyes.set("height", (float(fr[5]) - g.y) * px)
	var x := (g.x - float(fr[4])) * px
	_eyes.set("x_off", -x if flip else x)
	_pose_tilt = 0.0
	_apply_tilt()


## Where his glasses are in a frame of the set (texels in it): FIG_EYE_ROW of its height
## below the top of his hat, in the middle of his head there.
func _head_of(fr: Array) -> Vector2:
	var x0 := int(fr[0])
	var y0 := int(fr[1])
	var w := int(fr[2])
	var h := int(fr[3])
	var fallback := Vector2(float(fr[4]), float(h) * 0.08)
	if _fig_img == null:
		return fallback
	var top := -1
	for yy in h:
		for xx in w:
			if _fig_img.get_pixel(x0 + xx, y0 + yy).a > 0.5:
				top = yy
				break
		if top >= 0:
			break
	if top < 0:
		return fallback
	var row := float(top) + float(h) * float(FIG_EYE_ROW.get(_fig_anim, 0.08))
	var sx := 0.0
	var n := 0
	for yy in range(top + int(h * 0.04), mini(h, top + int(h * 0.11))):
		for xx in w:
			if _fig_img.get_pixel(x0 + xx, y0 + yy).a > 0.5:
				sx += xx
				n += 1
	return Vector2(sx / float(n) if n > 0 else float(fr[4]), row)


## His eyes onto the glasses of the art he is in now.
func _pose_eyes(path: String, tex: Texture2D) -> void:
	if _eyes == null:
		return
	var key := path
	if T_WALK.has(path):
		key = "walk%d" % T_WALK.find(path)
	var at: Array = EYES_AT.get(key, [12.0, float(tex.get_width()) * 0.5, 0.0])
	var px := _body.pixel_size
	_eyes.set("height", (float(tex.get_height()) - float(at[0])) * px)
	_eyes.set("x_off", (float(at[1]) - float(tex.get_width()) * 0.5) * px)
	_pose_tilt = float(at[2])
	_apply_tilt()


func _apply_tilt() -> void:
	if _eyes != null:
		_eyes.set("tilt", _pose_tilt + _tilt_extra)


## Nearer, the head further over; within a few metres now and then it cocks hard.
func _tilt_head() -> void:
	var close := clampf(1.0 - _dist / START_DIST, 0.0, 1.0)
	_tilt_extra = _tilt_sign * (0.08 + 0.5 * close * close)
	if _dist < 4.5 and _rng.randf() < 0.45:
		_tilt_extra = _tilt_sign * _rng.randf_range(0.9, 1.3)
	_apply_tilt()


## His lenses catch your torch far past where it lights anything (he stays: he is not lit).
func _eyes_flare(at: Vector3) -> float:
	if _in_flashlight(at):
		return 1.0
	if not _flashlight_on() or not _player.has_method("get_flashlight_aim"):
		return 0.0
	var aim: Dictionary = _player.call("get_flashlight_aim")
	if aim.is_empty():
		return 0.0
	var to: Vector3 = at - (aim["origin"] as Vector3)
	var d := to.length()
	if d > GLINT_RANGE or d < 0.5:
		return 0.0
	# A little narrower than the beam: the glint is where it points.
	var c := (aim["dir"] as Vector3).normalized().dot(to / d)
	var k := clampf((c - cos(deg_to_rad(float(aim["half_angle"]) * 0.8))) / 0.02, 0.0, 1.0)
	if k > 0.5 and not _glint_stung and d > 9.0 and _body.visible and _fx() != null:
		_glint_stung = true
		_ear(SFX_STING, -3.0, 0.8)
	return k


func _update_audio(dt: float) -> void:
	var d := _distance_to_player(_body.global_position)
	if _hum != null:
		_hum.global_position = _body.global_position + Vector3(0, 1.6, 0)
		# He hums only while he waits for you in the dark round his corner, and seldom.
		if _hum_next < 0.0:
			_hum_next = _elapsed + _rng.randf_range(20.0, HUM_EVERY.x)
		if _lurking and _elapsed >= _hum_next:
			_hum_until = _elapsed + _rng.randf_range(HUM_SEC.x, HUM_SEC.y)
			_hum_next = _hum_until + _rng.randf_range(HUM_EVERY.x, HUM_EVERY.y)
		var want := lerpf(-30.0, -15.0, clampf(1.0 - d / (LURK_DIST.y + 4.0), 0.0, 1.0)) if _lurking and _elapsed < _hum_until else -60.0
		_hum.volume_db = move_toward(_hum.volume_db, want, (60.0 if want < _hum.volume_db else 20.0) * dt)
	if _breath != null:
		_breath.global_position = _body.global_position + Vector3(0, 1.6, 0)
		_breath.volume_db = -60.0 if (d > 4.5 or _elapsed < _resume_at) else lerpf(-8.5, -28.5, d / 4.5)
	var fx := _fx()
	if fx != null and _elapsed >= _resume_at:
		fx.set_dread(_fx_key, clampf(1.0 - _dist / START_DIST, 0.0, 1.0) * 0.8)


# ── the light ────────────────────────────────────────────────────────────────

## Found by the light: the glasses flare, a sharp breath, and he comes apart into the dark:
## a dither of game pixels in six steps (twelve a second) going back a step, a little
## dark ash going up. Then a new corner. Your own torch on him: first the world burnt out
## and him in it, black, the two points (nightmare_fx.lock, its negative).
func _driven_off() -> void:
	_drive_offs += 1
	var stood: Texture2D = _body.texture
	var tall := float(stood.get_height()) * _body.pixel_size * _body.scale.y if stood != null else HEIGHT
	_end_hold()
	_staring = false
	_eyes_out = false
	_glint_stung = false
	_tilt_extra = 0.0
	_apply_tilt()
	_press = maxf(0.0, _press - 0.45)
	_walk_t = -1.0
	_lurking = false
	if _tex.has(T_LIT):
		_set_tex(T_LIT)
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	_sound(SFX_VANISH, head, 2.0, _rng.randf_range(0.95, 1.05), 30.0)
	var fx := _fx()
	if fx != null and _in_flashlight(head) and _elapsed >= _lock_ok_at:
		_lock_ok_at = _elapsed + LOCK_EVERY
		fx.lock(clampf(1.0 - _distance_to_player(_body.global_position) / 16.0, 0.4, 1.0), stood, _body.global_position, _body.global_position + Vector3(0, tall, 0), _camera(), true)
	var away := _body.global_position - _player_pos()
	away.y = 0.0
	_back_dir = away.normalized() if away.length_squared() > 0.01 else -_forward_flat()
	_walk_from = _body.global_position
	_vanish_at = _elapsed + LIT_SECONDS
	_player.set("flashlight_stutter", 0.35)
	# Your own torch did it: his glasses throw it back and the bulb goes (not a lamp's
	# light, not the other warden's torch). A beat after it finds him: you see him in it
	# first (it was dead the moment you put it on him, the user 4. 11.).
	if _in_flashlight(head) and _player.has_method("torch_blackout"):
		var p := _player
		p.get_tree().create_timer(TORCH_FIND_SEC).timeout.connect(func():
			if is_instance_valid(p):
				p.set("flashlight_stutter", 1.0)
				p.call("torch_blackout", TORCH_DARK_SEC, TORCH_BACK_SEC))
	_neck_until = -1.0
	_dissolve_base = _body.texture
	_puff_ash()


var _dissolve_base: Texture2D


func _update_lit(_dt: float) -> void:
	_body.visible = true
	var left := _vanish_at - _elapsed
	var k := clampf(1.0 - left / LIT_SECONDS, 0.0, 1.0)
	if k > 0.1:
		_player.set("flashlight_stutter", 0.0)
	# The glasses flare white in the light, then nothing is behind them.
	if _eyes != null:
		_eyes.set("want", 1.0 if k < 0.25 else 0.0)
		_eyes.set("flare", 1.0)
	# After the flare: the dither takes him, a frame at a time, as he goes back a step.
	if k > 0.15 and _dissolve_base != null:
		var frames: Array = _dissolve_frames(_dissolve_base)
		var i := clampi(int((k - 0.15) / 0.85 * float(DISSOLVE_FRAMES + 1)), 0, DISSOLVE_FRAMES)
		if i >= DISSOLVE_FRAMES:
			_body.visible = false
		else:
			_body.texture = frames[i]
		_body.global_position = _walk_from + _back_dir * 0.5 * floorf((k - 0.15) / 0.85 * 6.0) / 6.0
	if left <= 0.0:
		_vanish_at = -1.0
		_player.set("flashlight_stutter", 0.0)
		_body.texture = null
		_body.texture = _dissolve_base
		_reset_far(_rng.randf_range(4.0, 8.0))


## The art going to nothing in an ordered dither (whole pixels, darker as it goes), made
## once per picture (scripts/night/fx_tex.gd, so the warden he hunts on another machine
## sees him come apart too, not just gone).
func _dissolve_frames(tex: Texture2D) -> Array:
	if _dissolve.has(tex):
		return _dissolve[tex]
	var out: Array = []
	for f in DISSOLVE_FRAMES:
		var im := FX_TEX.dissolve(tex, f, DISSOLVE_FRAMES)
		if im == null:
			break
		out.append(im)
	_dissolve[tex] = out
	return out


## A little dark ash going up off him as he goes.
func _puff_ash() -> void:
	if _ash == null:
		_ash = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.25, 0.85, 0.1)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 35.0
		pm.initial_velocity_min = 0.15
		pm.initial_velocity_max = 0.5
		pm.gravity = Vector3(0, 0.35, 0)
		pm.damping_min = 0.4
		pm.damping_max = 0.8
		_ash.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.035, 0.035)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.045, 0.04, 0.9)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = m
		_ash.draw_pass_1 = q
		_ash.amount = 40
		_ash.lifetime = 1.4
		_ash.one_shot = true
		_ash.explosiveness = 0.5
		_root.add_child(_ash)
	_ash.global_position = _body.global_position + Vector3(0, HEIGHT * 0.5, 0)
	_ash.restart()
	_ash.emitting = true


func _reset_far(pause: float) -> void:
	_lurking = false
	_dist = START_DIST
	_resume_at = _elapsed + pause
	_next_step = _resume_at + _step_interval
	_walk_t = -1.0
	# Out of sight, somewhere behind you.
	var p := _point_from_player(_dist, 180.0 + _rng.randf_range(-50.0, 50.0))
	if p != Vector3.INF:
		_body.global_position = p
	_set_tex(_look_for(_dist))


# ── the catch and the kill ───────────────────────────────────────────────────

func _start_catch(forced := "") -> void:
	var kill := forced == "" and _player_health() - _damage <= 0
	var needs := {"cross": T_CROSS, "inside": T_SECOND, "eyes": T_EYES}
	var pool: Array = (KILLS if kill else STRIKES).filter(func(k): return k != (_last_kill if kill else _last_strike) and (not needs.has(k) or _tex.has(needs[k])))
	var kind: String = forced if forced != "" else pool[_rng.randi() % pool.size()]
	if kill:
		_last_kill = kind
	else:
		_last_strike = kind
	var cam := _camera()
	_striker = self
	_seq = {"kind": kind, "t": 0.0, "cues": {}, "kill": kill, "yaw0": _player.rotation.y, "roll0": cam.rotation.z if cam != null else 0.0, "pitch0": cam.rotation.x if cam != null else 0.0}
	_view_begin()
	if _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	_player.set("flashlight_stutter", 0.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
	_near_you(_sound(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), 1.5))


func _cue(at: float, id: String) -> bool:
	var cues: Dictionary = _seq["cues"]
	if float(_seq["t"]) >= at and not cues.has(id):
		cues[id] = true
		return true
	return false


func _ear(file: String, db: float, pitch: float = 1.0) -> void:
	_near_you(_sound(file, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.3, db, pitch, 10.0))


## A sound at you (your ear, your neck, the sting in your face) at the gain written: a
## sound 0.3 m off gets +20 dB from its nearness and every one of them hit the 3D
## player's ceiling (+3) alike; its unit size the distance it is at takes that out.
func _near_you(p: AudioStreamPlayer3D) -> void:
	var cam := _camera()
	if p != null and cam != null:
		p.unit_size = maxf(0.05, cam.global_position.distance_to(p.global_position))


func _hit_now() -> void:
	var fx := _fx()
	if _lesson:
		# He has shown you his face. That is all, this once.
		if fx != null:
			fx.glitch(0.8, 0.9)
			fx.tinnitus(3.0)
		return
	_hurt(_damage)
	claimed = true
	if fx != null:
		fx.red_flash(1.0)
		fx.glitch(1.0, 1.2)
		fx.tinnitus(4.5)


func _update_seq(dt: float) -> void:
	_seq["t"] = float(_seq["t"]) + dt
	var t: float = _seq["t"]
	var st := floorf(t * 12.0) / 12.0
	var fx := _fx()
	var cam := _camera()
	match str(_seq["kind"]):
		"ear":
			# Your head is pulled to the side: his face at your ear; the skin tears; the bite.
			if cam != null:
				_set_roll(float(_seq["roll0"]) + 0.32 * clampf(st / 0.25, 0.0, 1.0))
			_set_yaw(float(_seq["yaw0"]) + deg_to_rad(75.0) * clampf(st / 0.25, 0.0, 1.0))
			if fx != null:
				if st < 0.7:
					fx.close_up(_t(T_FACE), lerpf(1.0, 1.25, st / 0.7), 1.0, 0.006, -0.25)
				elif st < 1.15:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.3, 1.9, (st - 0.7) / 0.45), 1.0, 0.02, -0.25)
			if _cue(0.25, "breath"):
				_ear(SFX_BREATH, -2.0)
			if _cue(0.62, "tear"):
				_ear(SFX_TEAR, -0.5)
			if _cue(1.0, "bite"):
				_ear(SFX_BITE, 1.0)
				_hit_now()
			_fade_out(fx, t, 1.15, 1.6)
		"above":
			# He leans over you from behind and above: his face upside down coming down.
			if fx != null:
				if st < 0.8:
					fx.close_up(_t(T_UPSIDE, T_FACE), lerpf(1.05, 1.3, st / 0.8), 1.0, 0.006, 0.0 if _tex.has(T_UPSIDE) else PI, Vector2(0.0, lerpf(-0.9, 0.0, clampf(st / 0.35, 0.0, 1.0))))
				elif st < 1.2:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.4, 2.0, (st - 0.8) / 0.4), 1.0, 0.022, PI)
			if _cue(0.1, "breath"):
				_ear(SFX_BREATH, -2.0, 0.9)
			if _cue(0.7, "tear"):
				_ear(SFX_TEAR, -0.5)
			if _cue(1.05, "bite"):
				_ear(SFX_BITE, 1.0)
				_hit_now()
			_fade_out(fx, t, 1.2, 1.7)
		"turn":
			# You are turned round to him, in three jerks; face to face; the skin tears.
			_set_yaw(float(_seq["yaw0"]) + PI * clampf(floorf(st / 0.08) / 3.0, 0.0, 1.0))
			if fx != null:
				if st < 0.3:
					pass
				elif st < 0.8:
					fx.close_up(_t(T_FACE), lerpf(1.1, 1.35, (st - 0.3) / 0.5), 1.0, 0.008)
				elif st < 1.2:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.4, 2.1, (st - 0.8) / 0.4), 1.0, 0.024)
			if _cue(0.3, "mmm"):
				_ear(SFX_MMM, 3.0)
			if _cue(0.75, "tear"):
				_ear(SFX_TEAR, -0.5)
			if _cue(1.05, "bite"):
				_ear(SFX_BITE, 1.0)
				_hit_now()
			_fade_out(fx, t, 1.2, 1.7)
		"strangle":
			# His hands come round from behind and close; the edges go dark; his face
			# presses close; the last thing, your own face small in his glasses.
			if fx != null:
				if st < 1.5:
					fx.close_up(_t(T_HANDS, T_FACE), lerpf(1.9, 1.0, st / 1.5), 1.0, 0.004 + 0.02 * st / 1.5)
					fx.set_dread(_fx_key, 1.0)
				elif st < 3.0:
					fx.close_up(_t(T_FACE), lerpf(1.3, 2.4, (st - 1.5) / 1.5), 1.0, 0.02 * (1.0 - (st - 1.5) / 1.5))
					fx.set_black(clampf((st - 1.5) / 1.5, 0.0, 0.85))
			if _cue(0.1, "choke"):
				_ear(SFX_CHOKE, -1.5)
			if _cue(1.4, "breath"):
				_ear(SFX_BREATH, -2.0, 0.85)
			if cam != null:
				_set_pitch(float(_seq["pitch0"]) + 0.12 * clampf(st / 1.5, 0.0, 1.0))
			if _cue(3.0, "hit"):
				_hit_now()
			_fade_out(fx, t, 3.0, 3.6)
		"snap":
			# Hands on your head; it is turned round in steps; the crack; from the ground,
			# him standing over you.
			if fx != null and st < 0.6:
				fx.close_up(_t(T_HANDS, T_FACE), lerpf(1.6, 1.15, st / 0.6), 1.0, 0.012)
			var turn := clampf(floorf((st - 0.6) / 0.1) / 6.0, 0.0, 1.0)
			_set_yaw(float(_seq["yaw0"]) + PI * turn)
			if _cue(0.6, "grind"):
				_ear(SFX_CHOKE, -2.5, 1.3)
			if _cue(1.2, "snap"):
				_ear(SFX_SNAP, -0.5)
				if fx != null:
					fx.red_flash(0.8)
					fx.glitch(0.9, 0.6)
			if cam != null and st >= 1.25:
				_set_roll(float(_seq["roll0"]) + 1.45 * clampf((st - 1.25) / 0.25, 0.0, 1.0))
			if fx != null and st >= 1.5 and st < 2.9:
				fx.close_up(_t(T_OVER, T_FACE), 1.05, 1.0, 0.0, 0.0)
				fx.set_black(clampf((st - 2.0) / 0.9, 0.0, 0.8))
			if _cue(2.9, "hit"):
				_hit_now()
			_fade_out(fx, t, 2.9, 3.4)
		"bite":
			# The skin over his mouth opens over your face and it closes.
			if fx != null:
				if st < 0.5:
					fx.close_up(_t(T_FACE), lerpf(1.0, 1.4, st / 0.5), 1.0, 0.008)
				elif st < 1.3:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.5, 3.2, (st - 0.5) / 0.8), 1.0, 0.02 + 0.02 * (st - 0.5), 0.0, Vector2(0.0, -0.25 * (st - 0.5)))
			if _cue(0.45, "tear"):
				_ear(SFX_TEAR, -0.5, 0.9)
			if _cue(1.1, "bite"):
				_ear(SFX_BITE, 1.0, 0.9)
				if fx != null:
					fx.red_flash(1.0)
			if cam != null and st >= 1.3:
				# You go down.
				_set_pitch(float(_seq["pitch0"]) - 0.9 * clampf((st - 1.3) / 0.4, 0.0, 1.0))
				_set_roll(float(_seq["roll0"]) + 0.6 * clampf((st - 1.3) / 0.4, 0.0, 1.0))
			if _cue(1.8, "hit"):
				_hit_now()
			_fade_out(fx, t, 1.3, 2.3)
		_:
			_update_seq_worse(str(_seq["kind"]), t, st, fx, cam)


## The worse catches: in _update_seq's match (its `_` arm calls this).
func _update_seq_worse(kind: String, t: float, st: float, fx, cam: Camera3D) -> void:
	match kind:
		"cross":
			# Face to face, and the skin over his mouth splits in four and folds back: the
			# throat is teeth, ring after ring, going down; it comes over you.
			_set_yaw(float(_seq["yaw0"]) + PI * clampf(floorf(st / 0.08) / 3.0, 0.0, 1.0))
			if fx != null:
				if st < 0.6:
					fx.close_up(_t(T_FACE), lerpf(1.05, 1.3, st / 0.6), 1.0, 0.006)
				elif st < 1.4:
					fx.close_up(_t(T_CROSS, T_TEAR), lerpf(1.2, 2.6, (st - 0.6) / 0.8), 1.0, 0.01 + 0.025 * (st - 0.6))
			if _cue(0.5, "stretch"):
				_ear(SFX_STRETCH, -12.5)
			if _cue(0.7, "throat"):
				_ear(SFX_THROAT, -8.0)
			if _cue(1.3, "bite"):
				_ear(SFX_BITE, 1.0, 0.8)
				_hit_now()
			_fade_out(fx, t, 1.4, 1.9)
		"inside":
			# Something pushes out through where his mouth should be: a second face,
			# screaming without a sound you can hear past his skin; then his own mouth
			# opens round it and round you.
			if fx != null:
				if st < 0.5:
					fx.close_up(_t(T_FACE), lerpf(1.0, 1.25, st / 0.5), 1.0, 0.004)
				elif st < 1.9:
					fx.close_up(_t(T_SECOND, T_TEAR), lerpf(1.2, 1.6, (st - 0.5) / 1.4), 1.0, 0.004 + 0.02 * (st - 0.5))
				elif st < 2.6:
					fx.close_up(_t(T_CROSS, T_TEAR), lerpf(1.6, 4.0, (st - 1.9) / 0.7), 1.0, 0.03)
					fx.set_black(clampf((st - 2.2) / 0.4, 0.0, 0.9))
			if _cue(0.5, "second"):
				_ear(SFX_SECOND, 2.5)
			if _cue(1.9, "throat"):
				_ear(SFX_THROAT, -8.0, 0.85)
			if _cue(2.5, "bite"):
				_ear(SFX_BITE, 1.0, 0.75)
				if fx != null:
					fx.red_flash(1.0)
			if _cue(2.6, "hit"):
				_hit_now()
			_fade_out(fx, t, 2.6, 3.2)
		"eyes":
			# His thumbs come over your eyes from behind and press: the picture goes dark
			# from the edges in, red, and the wet give.
			if fx != null and st < 2.4:
				fx.close_up(_t(T_EYES, T_HANDS), lerpf(1.6, 1.05, clampf(st / 0.8, 0.0, 1.0)), 1.0, 0.004 + 0.01 * st)
				fx.set_black(clampf((st - 0.8) / 1.4, 0.0, 0.95))
				if st > 1.6:
					fx.red_flash(0.5)
			if _cue(0.1, "breath"):
				_ear(SFX_BREATH, -2.0, 0.8)
			if _cue(0.9, "stretch"):
				_ear(SFX_STRETCH, -12.5, 0.8)
			if _cue(1.8, "give"):
				_ear(SFX_BITE, 1.0, 0.6)
			if cam != null:
				_set_pitch(float(_seq["pitch0"]) + 0.25 * clampf(st / 1.0, 0.0, 1.0))
			if _cue(2.4, "hit"):
				_hit_now()
			_fade_out(fx, t, 2.4, 3.0)


## After the hit: black, then (a catch, not a kill) the world back, him gone for a while.
func _fade_out(fx, t: float, from: float, to: float) -> void:
	if fx != null and t >= from:
		if t >= from + 0.05:
			fx.close_up_off()
		fx.set_black(clampf((t - from) / 0.25, 0.0, 1.0))
	if t >= to:
		var kill: bool = _seq.get("kill", false)
		_end_seq()
		if _lesson:
			_lesson = false
			_first = false
			_feed("He was right behind you. Turn round. Put a light on him.")
		if not kill:
			_reset_far(_rng.randf_range(12.0, 18.0))


func _end_seq() -> void:
	if _seq.is_empty():
		return
	var cam := _camera()
	if cam != null and is_instance_valid(cam):
		_set_roll(float(_seq["roll0"]))
		_set_pitch(float(_seq["pitch0"]))
	_view_end()
	var kill: bool = _seq.get("kill", false)
	_seq = {}
	if _striker == self:
		_striker = null
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0 if not kill else 1.0)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled") and not kill:
		_player.call("set_controls_enabled", true)


func _t(path: String, fallback: String = GUEST) -> Texture2D:
	return _tex.get(path, _tex.get(fallback, _tex.get(GUEST)))


# ── the sixth sense ──────────────────────────────────────────────────────────

## What you feel: built while you are in the dark and he is coming (faster the closer he
## is), drained in the light. Lurking near while you stand in the light, a little of it:
## the light is safe, and you still feel watched.
func _update_presence(dt: float) -> void:
	var fx := _fx()
	var in_light := _lamp_light_at(_player_pos()) >= DARK_LIGHT
	var hunting := not _lurking and _vanish_at < 0.0 and _elapsed >= _resume_at and not in_light
	var close := clampf(1.0 - (_dist - NECK_DIST) / (START_DIST - NECK_DIST), 0.0, 1.0)
	if hunting:
		_press = minf(1.0, _press + dt * (0.025 + 0.11 * close))
	else:
		_press = maxf(0.0, _press - dt * (0.3 if in_light else 0.12))
	var level := maxf(close * close * 0.85, _press * 0.9) if hunting else _press * 0.6
	if _lurking and in_light:
		level = maxf(level, 0.12 * clampf(1.0 - _distance_to_player(_body.global_position) / (LURK_DIST.y + 4.0), 0.0, 1.0) * 2.0)
	if _neck_until > 0.0:
		level = 1.0
	if fx != null:
		fx.set_presence(_fx_key, level)
		# His one face for a blink, the white points in the black glasses (the user 5. 11.:
		# "that one is great, but make it really rare"): at most once a night.
		if level > 0.7 and _neck_until < 0.0 and _face_night != _night_no():
			_sub_next -= dt
			if _sub_next <= 0.0:
				_sub_next = _rng.randf_range(4.0, 9.0) * (1.8 - level)
				if _rng.randf() < FACE_CHANCE:
					_face_night = _night_no()
					fx.subliminal(_t(T_FACE), 2, _rng.randf_range(0.9, 1.1), Color(0.8, 0.76, 0.72))
	# The torch in your hand catches and stutters as it gets bad.
	if level > 0.55 and _player != null:
		_stutter_next -= dt
		if _stutter_next <= 0.0:
			_stutter_next = _rng.randf_range(1.2, 3.5) * (1.6 - level)
			_player.set("flashlight_stutter", 0.5 + 0.5 * level)
			get_tree_timer(_rng.randf_range(0.08, 0.2), func():
				if _player != null and is_instance_valid(_player) and _vanish_at < 0.0:
					_player.set("flashlight_stutter", 0.0))


func _clear_phantoms() -> void:
	for ph in _phantoms:
		var n: Node3D = ph["eyes"]
		if n != null and is_instance_valid(n):
			n.queue_free()
	_phantoms.clear()


## When it is worst (the sixth sense high, out in the dark): a pair of his glasses at
## the edge of your view where he is not, in the dark, 10-20 m off. Look at it, or wait,
## and it goes out. Up to two at once. Never seen by anyone but you.
func _update_phantoms(dt: float) -> void:
	var cam := _camera()
	var fx := _fx()
	var bad := _press > 0.45 and _seq.is_empty() and _neck_until < 0.0 and _vanish_at < 0.0 and fx != null and cam != null
	for i in range(_phantoms.size() - 1, -1, -1):
		var ph: Dictionary = _phantoms[i]
		var e: Node3D = ph["eyes"]
		ph["t"] = float(ph["t"]) - dt
		var looked := false
		if cam != null:
			var to: Vector3 = (ph["at"] as Vector3) - cam.global_position
			looked = (-cam.global_transform.basis.z).dot(to.normalized()) > cos(deg_to_rad(14.0))
		if not bad or float(ph["t"]) <= 0.0 or looked or e == null or not is_instance_valid(e):
			if e != null and is_instance_valid(e):
				e.queue_free()
			_phantoms.remove_at(i)
			continue
		e.set("strength", 1.0)
		e.call("update", dt, cam)
	if not bad:
		_phantom_next = maxf(_phantom_next, 1.5)
		return
	_phantom_next -= dt * (0.5 + _press)
	if _phantom_next > 0.0 or _phantoms.size() >= 2:
		return
	_phantom_next = _rng.randf_range(2.5, 6.0)
	# Off to one side, well inside the frame's edge, not where you look.
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var p := _point_from_player(_rng.randf_range(10.0, 20.0), side * _rng.randf_range(24.0, 40.0))
	if p == Vector3.INF or _lamp_light_at(p) > LURK_DARK:
		return
	var at := p + Vector3(0, HEIGHT * 0.92, 0)
	if _ray_blocked(cam.global_position, at):
		return
	var e: Node3D = ENEMY_EYES.new()
	_root.add_child(e)
	e.set_meta("coop_quarry_only", true)
	e.call("setup", "silent_man", 0.0, null)
	e.set("anchor", null)
	e.set("point", at)
	e.set("tilt", _tilt_sign * _rng.randf_range(0.0, 0.5))
	_phantoms.append({"eyes": e, "at": at, "t": _rng.randf_range(1.2, 3.0)})


## His hands come over your shoulder from the side he is on; he holds you back.
func _start_hold() -> void:
	var cam := _camera()
	if cam != null:
		var right := cam.global_transform.basis.x
		var to := _body.global_position - cam.global_position
		_hold_side = 1.0 if right.dot(to) >= 0.0 else -1.0
	var fx := _fx()
	if fx != null:
		fx.freeze(0.06)
	_ear(SFX_BREATH, -2.0, 0.95)
	_near_you(_sound(SFX_RUSTLE, _player_pos() + Vector3(0, 1.3, 0) - _forward_flat() * 0.4, 0.0, 1.0, 6.0))
	if "held_speed_mult" in _player:
		_player.set("held_speed_mult", 0.5)


func _update_hold() -> void:
	var fx := _fx()
	if fx == null:
		return
	var k := clampf(1.0 - (_neck_until - _elapsed) / maxf(0.1, _grace), 0.0, 1.0)
	var st := floorf(k * 8.0) / 8.0
	fx.close_up(_t(T_HANDS, T_FACE), lerpf(0.75, 1.0, st), 1.0, 0.003 + 0.006 * st, -0.35 * _hold_side, Vector2(_hold_side * lerpf(0.62, 0.34, st), lerpf(0.5, 0.28, st)))
	fx.set_dread(_fx_key, 1.0)


func _end_hold() -> void:
	if _player != null and is_instance_valid(_player) and "held_speed_mult" in _player:
		_player.set("held_speed_mult", 1.0)
	if _neck_until > 0.0 or not _seq.is_empty():
		return
	var fx := _fx()
	if fx != null:
		fx.close_up_off()


# ── the first meeting ────────────────────────────────────────────────────────

func _met() -> bool:
	var d = _director()
	if d == null or not (d.get("ever") is Dictionary):
		return false
	return bool((d.get("ever") as Dictionary).get("silent_man_met", false))


func _mark_met() -> void:
	var d = _director()
	if d != null and d.get("ever") is Dictionary:
		(d.get("ever") as Dictionary)["silent_man_met"] = true


func _director():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_director") if scene != null else null


## The first step out of the light: the humming stops, and he is there in front of you
## at the edge of it, caught mid-stride. False when there is no such spot.
func _start_reveal() -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for _i in 12:
		var ang := deg_to_rad(_rng.randf_range(-22.0, 22.0))
		var dir := fwd.rotated(Vector3.UP, ang)
		var p := _ground(_player_pos() + dir * _rng.randf_range(8.0, 11.0))
		if p == Vector3.INF or _lamp_light_at(p) > DARK_LIGHT:
			continue
		if _ray_blocked(cam.global_position, p + Vector3(0, HEIGHT * 0.8, 0)):
			continue
		_revealed = true
		_lurking = false
		_body.global_position = p
		_body.visible = true
		var frames: Array = T_WALK.filter(func(q): return _tex.has(q))
		_set_tex(frames[0] if not frames.is_empty() else _look_for(9.0))
		_reveal_t = 0.0
		_reveal_seen = 0.0
		_sound(SFX_STEP, p + Vector3(0, 0.3, 0), -17.0, 0.92, 30.0)
		_announce("Footsteps on the gravel behind you. They stop when you stop.")
		return true
	return false


## Held there: look at him and he goes (the glasses, the dither); look away and he is not
## there when you look back. Either way the hunt then starts from behind you.
func _update_reveal(dt: float) -> void:
	_reveal_t += dt
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	var fx := _fx()
	if fx != null:
		fx.set_presence(_fx_key, 0.45)
	if _is_seen(head, 2.0):
		_reveal_seen += dt
		if _reveal_seen >= 0.55:
			_reveal_t = -1.0
			_sound(SFX_HUM, head, -4.0, 0.8, 20.0)
			_driven_off()
			_drive_offs -= 1
			return
	if _reveal_t >= 4.0 or (_reveal_seen > 0.0 and not _is_seen(head, 2.0)):
		_reveal_t = -1.0
		_body.visible = false
		_reset_far(_rng.randf_range(2.0, 4.0))


# ── indoors: watching you ────────────────────────────────────────────────────

## Watching through a window: how far off he stands (m), the steps nearer (each a share of
## the way), how long you look before he may go, how long it lasts at most.
const WATCH_DIST := Vector2(15.0, 24.0)
const WATCH_STEP := 0.62
const WATCH_STEPS := 2
const WATCH_LOOKED := 2.2
const WATCH_MAX := 32.0
## The wait between his moments indoors (s), and how often a moment is the window.
const INDOOR_EVERY := Vector2(24.0, 46.0)
const WATCH_CHANCE := 0.6


## While you are inside at night he cannot reach you, and he knows where you are. Now and
## then he is out there watching through a window; between, seldom, a sound of him.
func _tick_indoors(delta: float) -> void:
	if not _night_active or not _indoors_now():
		_indoors = false
		_end_watch()
		_end_ceiling()
		return
	if not _indoors:
		_indoors = true
		# (_lure_n counts on over the night, every stay inside: "late in his night" is the
		# night's, not this stay's; going in and out does not start him over.)
		_lure_next = _wall_clock() + _rng.randf_range(12.0, 22.0)
		_call_next = maxf(_call_next, _wall_clock() + _rng.randf_range(CALL_WAIT.x, CALL_WAIT.y))
	if _wall_clock() >= _call_next and _call_due() and _fx() != null:
		_call_next = _wall_clock() + 2.0 * _rng.randf_range(CALL_WAIT.x, CALL_WAIT.y)
		_call_out()
	if _ceil != null:
		_tick_ceiling()
	if _watch_win >= 0:
		_tick_watch(delta)
		return
	# Gone from the glass when his time there is up.
	if _glass_until > 0.0 and _wall_clock() >= _glass_until:
		_end_watch()
	if _wall_clock() < _lure_next:
		return
	_lure_next = _wall_clock() + _rng.randf_range(INDOOR_EVERY.x, INDOOR_EVERY.y)
	# Only the one he hunts sees or hears it (co-op).
	if _fx() == null:
		return
	_lure_n += 1
	if _rng.randf() < WATCH_CHANCE and _start_watch():
		return
	_indoor_sound()


## From out in the dark, through the walls: tonight's call.
func _call_out() -> void:
	_room_2d(SFX_CALL, CALL_DB)
	_calls -= 1


## Has he a call left tonight? Rolled once a night; the first of him only, a second Silent
## Man is not a second voice.
func _call_due() -> bool:
	if _calls_night != _night_no():
		_calls_night = _night_no()
		var first := _fx_key == "silent_man"
		_calls = CALLS_A_NIGHT if first and _rng.randf() < CALL_NIGHTS else 0
	return _calls > 0


## Seconds while indoors (the base's _elapsed does not run while it cannot act).
func _wall_clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _indoors_now() -> bool:
	return _quarry_indoors()


## Out in the dark beyond one of the room's windows (one with its curtain open), far off,
## still, facing the glass. Mostly a window you are not looking at, so you find him.
func _start_watch() -> bool:
	var wins := _room_windows()
	var pick := -1
	var best := 9.0
	for i in wins.size():
		var w: Dictionary = wins[i]
		if float(w.get("open", 1.0)) < 0.35:
			continue
		var f := float(w.get("facing", 0.0)) + _rng.randf_range(-0.3, 0.3)
		if f < best:
			best = f
			pick = i
	if pick < 0:
		return false
	var w: Dictionary = wins[pick]
	_watch_side = _rng.randf_range(-0.08, 0.08)
	for _i in 6:
		_watch_dist = _rng.randf_range(WATCH_DIST.x, WATCH_DIST.y)
		var p := _watch_point(w)
		if p != Vector3.INF and _lamp_light_at(p) < DARK_LIGHT:
			_watch_win = pick
			_watch_steps = 0
			_watch_seen = false
			_watch_looked = 0.0
			_glass_until = _wall_clock() + WATCH_MAX
			_place_watch(w, p)
			return true
	return false


## On the line from your eye through the glass (the window's camera in the camp), so the
## window shows him however slant you look through it; straight out from it without one.
func _watch_point(w: Dictionary) -> Vector3:
	var pos: Vector3 = w["pos"]
	var from: Vector3 = w.get("view", pos - (w["out"] as Vector3) * 2.0)
	var dir := pos - from
	dir.y = 0.0
	if dir.length() < 0.05 or dir.normalized().dot(w["out"] as Vector3) < 0.2:
		dir = w["out"] as Vector3
		dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, _watch_side)
	return _ground(from + dir * _watch_dist)


func _place_watch(w: Dictionary, p: Vector3) -> void:
	_body.global_position = p
	_body.visible = true
	_set_tex(T_M1 if _watch_dist > 9.0 or not _tex.has(T_M2) else T_M2)
	# His glasses, seen from the room (the window's own camera looks out from in there).
	if _eyes != null:
		_eyes.set("view_from", w.get("view", (w["pos"] as Vector3) - (w["out"] as Vector3) * 1.5))


## While he watches: you look at the window (he is there, still); you look away (he is a
## step nearer when you look back, twice at most); you have looked at him long enough and
## look away, or his time is up: he is not there any more.
func _tick_watch(delta: float) -> void:
	var wins := _room_windows()
	if _watch_win >= wins.size() or _wall_clock() >= _glass_until:
		_end_watch()
		return
	var w: Dictionary = wins[_watch_win]
	if float(w.get("open", 1.0)) < 0.35:
		# The curtain drawn on him: behind it he is gone.
		_end_watch()
		return
	var seen := float(w.get("facing", 0.0)) > 0.82
	if seen:
		_watch_looked += delta
		if not _watch_seen and _watch_steps > 0:
			# Nearer than he was: the sting, once.
			_room_2d(SFX_STING, -2.0, 0.85, false)
	elif _watch_seen:
		# You looked away.
		if _watch_looked >= WATCH_LOOKED and (_watch_steps >= WATCH_STEPS or _rng.randf() < 0.45):
			_end_watch()
			return
		if _watch_steps < WATCH_STEPS:
			_watch_steps += 1
			_watch_dist *= WATCH_STEP
			var p := _watch_point(w)
			if p != Vector3.INF:
				_place_watch(w, p)
			if _rng.randf() < 0.5:
				_room_2d(SFX_SOFTSTEP, -30.5, 0.9)
	_watch_seen = seen
	_body.visible = true


func _end_watch() -> void:
	_watch_win = -1
	_glass_until = -1.0
	if _body != null:
		_body.visible = false
	if _eyes != null:
		_eyes.set("view_from", Vector3.INF)
	if _glass_light != null:
		_glass_light.visible = false


## A sound of him between the windows, seldom: a slow step on the gravel, the humming far
## off, a breath at the wall; late in his night, now and then, his face over the ceiling or
## a tap at the glass close to you.
func _indoor_sound() -> void:
	var late := _lure_n >= 4
	var r := _rng.randf()
	if late and r < 0.18 and _tex.has(T_CEILING):
		_room_2d(SFX_CEILING, -8.5)
		get_tree_timer(2.4, func():
			if not _indoors:
				return
			# (Another warden's room is on their machine: there the sound alone.)
			if _quarry_peer() == 0:
				_start_ceiling())
		return
	if late and r < 0.32 and _at_glass(_im()):
		return
	if _rng.randf() < 0.5:
		_room_2d(SFX_SOFTSTEP, -29.5, 0.85)
	else:
		_room_2d(SFX_BREATH, -20.0, 0.9)


## The cabin you are in: he stands outside one of its windows, close to the glass, and
## the window (a view of the real camp) shows him. A tap on it first. Then he is not there.
func _at_glass(im) -> bool:
	# Their cabin is on their machine, not in this one's rooms.
	if _quarry_peer() != 0:
		return false
	var cab = im.get("_cabin_interior") if im != null else null
	if cab == null or not is_instance_valid(cab) or not cab.has_method("outside_windows") or not bool(cab.call("is_open")):
		return false
	var wins: Array = cab.call("outside_windows")
	if wins.is_empty():
		return false
	# Mostly the window you are looking at; now and then the one at the edge of your eye.
	var w: Dictionary = wins[_rng.randi() % wins.size()]
	if _rng.randf() < 0.7:
		for c in wins:
			if float(c.get("facing", 0.0)) > float(w.get("facing", 0.0)):
				w = c
	var p := _ground((w["pos"] as Vector3) + (w["out"] as Vector3) * 0.55)
	if p == Vector3.INF:
		return false
	_room_2d("res://assets/sfx/director/window_tap.mp3", -4.0, 1.0, false)
	_body.global_position = p
	_body.visible = true
	# On the ground, as he stands: his glasses at 1.68 m, the middle of a cabin window at
	# 1.67 (cabin_layout SILL_MID). (The taller one, his neck drawn out, was let down into
	# the ground 0.4 m to get his face there; seen from outside, he stood in a hole.)
	_set_tex(T_M1 if _tex.has(T_M1) else T_M2)
	_glass_until = _wall_clock() + _rng.randf_range(3.5, 5.5)
	# His glasses in the window, seen from the room (the window's own camera).
	if _eyes != null:
		_eyes.set("view_from", (w["pos"] as Vector3) - (w["out"] as Vector3) * 1.5)
	if _glass_light == null:
		_glass_light = OmniLight3D.new()
		_glass_light.light_color = Color(1.0, 0.78, 0.5)
		_glass_light.omni_range = 2.2
		_glass_light.light_energy = 0.9
		_root.add_child(_glass_light)
	_glass_light.global_position = (w["pos"] as Vector3) + (w["out"] as Vector3) * 0.15
	_glass_light.visible = true
	return true


## Him on the ceiling over you, a step in front, flat to it and looking down, hung on the
## room there. The rooms' ceilings have no collision: it is the lowest thin wide slab
## drawn over you (a tent's canvas is none: false, as where there is no ceiling).
func _start_ceiling() -> bool:
	_end_ceiling()
	var cam := _room_camera()
	if cam == null:
		return false
	var fwd := (-cam.global_transform.basis.z).slide(Vector3.UP)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var under := cam.global_position + fwd * 0.6
	var slab: VisualInstance3D = null
	var y := INF
	for id in RenderingServer.instances_cull_ray(under, under + Vector3.UP * 3.5, cam.get_world_3d().scenario):
		var n = instance_from_id(id)
		if not (n is VisualInstance3D) or not (n as Node3D).is_visible_in_tree():
			continue
		var box: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		# (The cull takes the ray as endless: only what is over your head in the room.)
		if box.size.y > 0.3 or box.size.x < 1.0 or box.size.z < 1.0 or box.position.y < under.y + 0.3 or box.position.y > under.y + 3.5:
			continue
		if box.position.y < y:
			y = box.position.y
			slab = n
	if slab == null:
		return false
	_ceil = Sprite3D.new()
	_ceil.texture = _t(T_CEILING)
	_ceil.pixel_size = 0.009
	_ceil.shaded = false
	_ceil.modulate = Color(0.55, 0.5, 0.5)
	_ceil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_ceil.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	slab.add_child(_ceil)
	# Its face down (+Z to the floor), his head away from you.
	_ceil.global_transform = Transform3D(Basis.looking_at(Vector3.UP, fwd), Vector3(under.x, y - 0.02, under.z))
	_ceil_seen = false
	_ceil_until = _wall_clock() + 12.0
	return true


## The camera of the room you are in (each room draws through its own viewport: the
## game's is still the one outside, the rooms stand far off in the sky).
func _room_camera() -> Camera3D:
	var im = _im()
	if im == null:
		return null
	for n in ["_building_interior", "_cabin_interior", "_caravan_interior", "_tent_interior", "_service_interior"]:
		var r = im.get(n)
		if r == null or not is_instance_valid(r):
			continue
		var c = r.get("_interior_camera")
		if c is Camera3D and is_instance_valid(c) and (c as Camera3D).is_inside_tree() and (c as Camera3D).current:
			return c
	return null


## Look up: he is there (the sting, once). Look away again: he is not. Never looked at, he
## is gone after a while.
func _tick_ceiling() -> void:
	if not is_instance_valid(_ceil) or not _ceil.is_inside_tree():
		_ceil = null
		return
	var cam := _ceil.get_viewport().get_camera_3d()
	var seen := false
	if cam != null:
		var to := _ceil.global_position - cam.global_position
		seen = (-cam.global_transform.basis.z).normalized().dot(to.normalized()) > cos(deg_to_rad(cam.fov * 0.45))
	if seen and not _ceil_seen:
		_ceil_seen = true
		_room_2d(SFX_STING, -2.0, 0.75, false)
	elif (_ceil_seen and not seen) or (not _ceil_seen and _wall_clock() > _ceil_until):
		_end_ceiling()


func _end_ceiling() -> void:
	if _ceil != null and is_instance_valid(_ceil):
		_ceil.queue_free()
	_ceil = null
	_ceil_seen = false


## A sound of him while you are inside. `wall`: he is out there and it comes through the
## walls, muffled (his step, his humming, his breath, him over the roof); not for the
## tap on the glass itself, nor the sting.
func _room_2d(file: String, db: float, pitch: float = 1.0, wall := true) -> void:
	if _play_2d_remote(file, db, pitch, wall):
		return
	var p := _wall2d if wall else _sound2d
	if p == null or not ResourceLoader.exists(file):
		return
	p.stream = load(file)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


# ── helpers ──────────────────────────────────────────────────────────────────

func _is_lit_and_seen(head: Vector3) -> bool:
	# Another warden's torch on him drives him off too: watching each other's backs.
	if _lit_by_others(head):
		return true
	if not _is_seen(head, 0.0):
		return false
	return _in_flashlight(head) or _lamp_light_at(_body.global_position) >= DARK_LIGHT


func _track_speed(dt: float) -> void:
	var p := _player_pos()
	if _last_player_pos != Vector3.INF and dt > 0.0:
		var flat := Vector2(p.x - _last_player_pos.x, p.z - _last_player_pos.z).length() / dt
		_speed = lerpf(_speed, flat, clampf(dt * 6.0, 0.0, 1.0))
	_last_player_pos = p


func get_debug_snapshot() -> Dictionary:
	return {
		"distance": snappedf(_dist, 0.1),
		"neck": _neck_until > 0.0,
		"paused": _elapsed < _resume_at,
		"hits": _hits,
		"driven_off": _drive_offs,
		"player_speed": snappedf(_speed, 0.1),
		"catch": str(_seq.get("kind", "")),
		"press": snappedf(_press, 0.01),
		"first": _first,
		"lure": _lure_n,
		"stare": _staring,
		"eyes_out": _eyes_out,
		"phantoms": _phantoms.size(),
	}
