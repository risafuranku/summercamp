extends "res://scripts/enemies/enemy_base.gd"

## The Photographer (the Tourist; spawned by Drunk guests). Rule: never look at him when
## the flash goes; indoors, draw the curtains.
##
## Reworked 20. 10. with the user ("you always know about him and where he is, so he
## takes a lot of health; more an annoying bastard; he photographs you in buildings
## through the windows, so you have to draw the curtains"):
##   always there  he hums to himself wherever he is (a loop on his body), the camera's
##                 red standby lamp blinks once a second, and he is seen: walking from one
##                 spot to the next in plain view (his steps, the film wound on as he
##                 stops), never jumping. He is a nuisance you keep track of, not a jump.
##   the shot      he stands, raises the camera (the aim picture), the red focus lamp
##                 blinks with the autofocus beeps, faster, the flash whines (~2-3 s), the
##                 flash. In your view with a clear line: a hard white blast, your ears
##                 ring, his flash-lit picture burnt into your eyes for a moment, and a lot
##                 of health; then he waves at you with the instant photo, giggling, and
##                 walks on. Out of view, the place lights up from his side and he walks on
##                 (closer). Round and round, a shot every 7-10 s.
##   indoors       he comes to a window of the building you are in (seen in it: the
##                 window shows the camp), taps on the glass, breathes on it, and takes his
##                 picture through it: a window with its curtain open that you can see is a
##                 hit (the flash pops in the room); a drawn curtain lights up from behind
##                 and he goes to another window. No windows (a tent): he walks round it
##                 humming and the flash lights the canvas, no more.
##   up close      walking into him he does not bother with the camera.
##
## Worse (21. 10., the user: "like the Girl, almost over the line, evil made flesh"):
##   the pictures  they are real: each hit, the photo he took slides in at the corner of
##                 your eye and develops, and it is you, from where he stood (your own
##                 warden, from behind); every third one, he is in it too, right behind
##                 you, grinning into the lens. Through a window: you in your room, from
##                 the glass.
##   burnt in      his face, close, two camera lenses grown into the sockets, or the face
##                 peeling off like a wet print, for a few frames after the flash.
##   as it goes    two hits and his neck has gone: stretched, snapped, the head hanging off
##                 it sideways, one eye bulging behind the cracked glasses, the mouth stuffed
##                 with photographs, and still he raises the camera (the crack of it as he
##                 stops). Four and it has let go: the collar an empty stump, the head hangs
##                 upside down at his belly on the limp neck, screaming photographs.
##                 Three hits and he runs: out of the dark behind you in a lurch, boots on
##                 the gravel and the laugh, and the flash right at your ear. Do not turn
##                 round to it.
##   the last one  when a picture would be your last: the frame stops, his lens-face comes
##                 at you in steps, the word whispered wet in your ear, the flash, and the
##                 photo of your own face develops in the middle of the screen.
##
## Co-op (21. 10., "the other must not glimpse it"): what he does to the warden he hunts
## is on their machine alone: the white, the ringing, his burnt-in face, the sounds in
## their room and their pictures (taken there, of them: coop_night._on_ext). He comes to
## their windows too (their warden state "pw"). Walking round and framing, everyone sees
## him (he is always there); the run at your back, the last picture and him at your
## window are yours alone (is_private_now).

const SPRITE := "res://assets/textury/npc/tourist_idle.png"
const POSES := {
	"walk_a": "res://assets/textury/npc/tourist_walk_a.png",
	"walk_b": "res://assets/textury/npc/tourist_walk_b.png",
	"aim": "res://assets/textury/npc/tourist_aim.png",
	"flash": "res://assets/textury/npc/tourist_flash.png",
	"wave": "res://assets/textury/npc/tourist_wave.png",
	"glass": "res://assets/textury/npc/tourist_glass.png",
	"back": "res://assets/textury/npc/tourist_back.png",
	"neck": "res://assets/textury/npc/ph_neck.png",
	"neck2": "res://assets/textury/npc/ph_neck2.png",
	"run": "res://assets/textury/npc/ph_run.png",
	"face_lens": "res://assets/textury/npc/ph_face_lens.png",
	"face_peel": "res://assets/textury/npc/ph_face_peel.png",
}
## Where his camera is in each picture of him (metres to the right as you see him, metres
## up from his feet): its red lamp is there, not on his face. Not here (his back): unseen.
const CAMERA_AT := {
	"idle": Vector2(0.0, 1.18), "walk_a": Vector2(-0.05, 1.15), "walk_b": Vector2(-0.03, 1.15),
	"aim": Vector2(0.0, 1.63), "flash": Vector2(0.0, 1.55), "wave": Vector2(0.0, 1.09),
	"glass": Vector2(-0.06, 1.46), "neck": Vector2(-0.03, 1.09), "neck2": Vector2(-0.06, 1.38),
	"run": Vector2(-0.26, 1.45),
}
const POLAROID = preload("res://scripts/enemies/polaroid.gd")
const SFX_WHISPER := "res://assets/sfx/npc/ph_whisper_smile.mp3"
const SFX_LAUGH_WET := "res://assets/sfx/npc/ph_laugh_wet.mp3"
const SFX_PEEL := "res://assets/sfx/npc/ph_peel.mp3"
const SFX_RUSH := "res://assets/sfx/npc/ph_rush.mp3"
const SFX_CRACK := "res://assets/sfx/npc/ph_crack.mp3"
const RUSH_SPEED := 9.5
const SFX_WHINE := "res://assets/sfx/npc/flash_whine.mp3"
const SFX_SHUTTER := "res://assets/sfx/npc/shutter.mp3"
const SFX_ADVANCE := "res://assets/sfx/npc/photo_advance.mp3"
const SFX_BEEP := "res://assets/sfx/npc/af_beep.mp3"
const SFX_HUM := "res://assets/sfx/npc/ph_hum.mp3"
const SFX_GIGGLE := "res://assets/sfx/npc/ph_giggle.mp3"
const SFX_WIND := "res://assets/sfx/npc/ph_wind.mp3"
const SFX_POLAROID := "res://assets/sfx/npc/ph_polaroid.mp3"
const SFX_STEPS := "res://assets/sfx/npc/ph_steps.mp3"
const SFX_ZOOM := "res://assets/sfx/npc/ph_zoom.mp3"
const SFX_TAP := "res://assets/sfx/npc/ph_glass_tap.mp3"
const SFX_BREATH := "res://assets/sfx/npc/ph_glass_breath.mp3"
const SFX_FLASH_ROOM := "res://assets/sfx/npc/ph_flash_room.mp3"
const SFX_HUM_GARGLE := "res://assets/sfx/npc/ph_hum_gargle.mp3"
const SFX_HUM_MUFFLED := "res://assets/sfx/npc/ph_hum_muffled.mp3"
const SFX_NECK_CREAK := "res://assets/sfx/npc/ph_neck_creak.mp3"
const SFX_TWITCH := "res://assets/sfx/npc/ph_neck_twitch.mp3"
const SFX_HEAD_SWING := "res://assets/sfx/npc/ph_head_swing.mp3"
const SFX_SCREAM := "res://assets/sfx/npc/ph_scream_paper.mp3"
const SFX_RUSTLE := "res://assets/sfx/npc/ph_photos_rustle.mp3"
const SFX_DRIP := "res://assets/sfx/npc/ph_drip.mp3"
const SFX_STEP_DRAG := "res://assets/sfx/npc/ph_step_drag.mp3"
const SFX_SHUTTER_FAR := "res://assets/sfx/npc/ph_shutter_far.mp3"
const SFX_CHUCKLE_WET := "res://assets/sfx/npc/ph_chuckle_wet.mp3"
const SFX_BREATH_BROKEN := "res://assets/sfx/npc/ph_breath_broken.mp3"
const SFX_RATTLE := "res://assets/sfx/npc/ph_camera_rattle.mp3"
const SFX_SPIT := "res://assets/sfx/npc/ph_spit_photo.mp3"
const SFX_JAW := "res://assets/sfx/npc/ph_jaw_click.mp3"
const SFX_FLICKER := "res://assets/sfx/npc/ph_flash_flicker.mp3"
## His poses alive (tools/artgen/photographer_frames.py: ph_anim/<pose>_<n>.png, each cut
## and moved from the pose itself): frames, how many a second, the order where it is not
## straight through; "spasm" the frame of the broken neck's jerk, played by itself now
## and then (_tick_grim).
const ANIM_DIR := "res://assets/textury/npc/ph_anim/"
const ANIM := {
	"idle": {"n": 2, "fps": 1.6}, "back": {"n": 2, "fps": 1.6}, "glass": {"n": 2, "fps": 2.2},
	"aim": {"n": 4, "fps": 12.0, "seq": [0, 1, 0, 0, 2, 0, 3, 0]},
	"wave": {"n": 6, "fps": 9.0},
	"flash": {"n": 3, "fps": 12.0, "seq": [1, 1, 0, 1, 2, 2, 0, 2]},
	"run": {"n": 2, "fps": 7.0},
	"neck": {"n": 10, "fps": 7.0, "spasm": 10},
	"neck2": {"n": 12, "fps": 9.0, "spasm": 12},
}
const GRAB_DISTANCE := 2.6
const WALK_SPEED := 3.2
const STEP := 1.0 / 12.0

enum Phase { WALK, SETTLE, FRAME, AFTER, RUSH }

var _phase := Phase.WALK
var _phase_end := 0.0
var _frame_seconds := 2.6
var _next_beep := 0.0
var _whine_started := false
var _dist := 18.0
var _min_dist := 9.0
var _flash: OmniLight3D
var _flash_t := 0.0
var _af_lamp: OmniLight3D
var _photo_damage := 18
var _grab_damage := 32
var _shots := 0
var _hits := 0
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _walk_c := Vector3.ZERO
var _walk_t := 0.0
var _walk_dur := 1.0
var _step_acc := 0.0
var _pose := ""
var _tex: Dictionary = {}
var _hum: AudioStreamPlayer3D
var _standby_t := 0.0
var _hit_last := false
## Indoors: the window he is at ({} none), the moment of the next thing he does there.
var _win: Dictionary = {}
var _in_next := 0.0
var _in_step := 0
var _in_beep := 0.0
var _room_audio: AudioStreamPlayer
## A dim light on him at the glass (the room's lamp through it), so the window shows him.
var _glass_light: OmniLight3D
var _self_light: OmniLight3D
var _polaroid: CanvasLayer
var _killing := false
var _rush_from := Vector3.ZERO
var _frames := {}
var _anim_t := 0.0
var _anim_i := -1
var _spasm_left := 0.0
var _spasm_wait := 3.0
## The hum as he is now ("" whole, "neck", "neck2"), louder for the new ones (their files
## are quieter), and the broken breathing once he is broken.
var _hum_stage := ""
var _hum_gain := 0.0
var _breath3d: AudioStreamPlayer3D
var _grim := {"rustle": 4.0, "drip": 3.0, "scream": 8.0, "far": 14.0}
var _flicker_at := -1.0


func get_enemy_id() -> String:
	return "tourist"


## Co-op: only the one he hunts sees him while he gets them (the run at their back, the
## last picture, at their window).
func is_private_now() -> bool:
	return _phase == Phase.RUSH or _killing or not _win.is_empty()


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_photo_damage = int(lerpf(16.0, 26.0, t))
	_grab_damage = int(lerpf(30.0, 42.0, t))
	_frame_seconds = lerpf(2.8, 2.0, t)
	_dist = lerpf(19.0, 14.0, t)
	_min_dist = lerpf(10.0, 7.0, t)
	_body = _make_body(SPRITE, 1.9)
	for k in POSES:
		if ResourceLoader.exists(POSES[k]):
			_tex[k] = load(POSES[k])
	_tex["idle"] = _body.texture
	for pose in ANIM:
		var fr: Array = []
		for i in int(ANIM[pose]["n"]) + (1 if ANIM[pose].has("spasm") else 0):
			var path := ANIM_DIR + "%s_%d.png" % [pose, i]
			if ResourceLoader.exists(path):
				fr.append(load(path))
		if not fr.is_empty():
			_frames[pose] = fr
	# The red lamp on the camera, a point where the camera is (enemy_eyes "tourist": a
	# sprite, so the other wardens see it blink too); the one thing of him in the dark.
	_make_eyes("tourist", 1.18)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.92, 0.95, 1.0)
	_flash.omni_range = 30.0
	_flash.omni_attenuation = 0.8
	_flash.light_energy = 0.0
	_flash.shadow_enabled = true
	_root.add_child(_flash)
	# Its red light on him and round him.
	_af_lamp = OmniLight3D.new()
	_af_lamp.light_color = Color(1.0, 0.1, 0.05)
	_af_lamp.omni_range = 1.1
	_af_lamp.light_energy = 0.0
	_root.add_child(_af_lamp)
	# A weak lamp on his chest strap (a cyclist's): he is seen wherever he is, a lit
	# figure in the dark, never hiding.
	_self_light = OmniLight3D.new()
	_self_light.light_color = Color(1.0, 0.86, 0.62)
	_self_light.omni_range = 2.6
	_self_light.light_energy = 0.9
	_root.add_child(_self_light)
	# He hums wherever he is: you always know.
	_hum = _loop(SFX_HUM, -6.0)
	if _hum != null:
		_hum.max_distance = 45.0
	_room_audio = AudioStreamPlayer.new()
	_root.add_child(_room_audio)
	var start := _point_from_player(_dist + 6.0, _rng.randf_range(100.0, 260.0))
	_body.global_position = start if start != Vector3.INF else _player_pos() + Vector3(_dist, 0, 0)
	_enter_walk()


## The base ticks nothing while you are indoors; then he is at your windows.
func tick(delta: float) -> void:
	# At a window his camera's lamp is seen from the room, through the glass.
	if _eyes != null:
		_eyes.set("view_from", (_win["pos"] as Vector3) - (_win["out"] as Vector3) * 1.5 if not _win.is_empty() else Vector3.INF)
	if _night_active and _player != null and is_instance_valid(_player) and not _is_ready() and _indoor_ok():
		_elapsed += delta
		_tick_flash(delta)
		_tick_indoors(delta)
		_tick_anim(delta)
		_follow_hum()
		_tick_eyes(delta)
		return
	if not _win.is_empty():
		_win = {}
		_body.visible = false
	if _glass_light != null:
		_glass_light.visible = false
	super(delta)


func _on_tick(dt: float) -> void:
	_tick_flash(dt)
	_body.visible = true
	_follow_hum()
	_tick_anim(dt)
	_tick_grim(dt)
	# The last picture: he stands where he took it while it develops.
	if _killing:
		return
	_standby(dt)
	if _distance_to_player(_body.global_position) < GRAB_DISTANCE:
		_grab()
		return
	match _phase:
		Phase.WALK:
			_tick_walk(dt)
		Phase.SETTLE:
			if _elapsed >= _phase_end:
				_enter_frame()
		Phase.FRAME:
			_tick_frame()
		Phase.AFTER:
			if _elapsed >= _phase_end:
				_enter_walk()
		Phase.RUSH:
			_tick_rush(dt)


# ── outdoors ─────────────────────────────────────────────────────────────────

func _enter_walk() -> void:
	# Three pictures of you tonight and he runs at you from behind now and then.
	if _hits >= 3 and _rng.randf() < 0.35 and not _is_seen(_head(), 10.0) and _distance_to_player(_body.global_position) < 22.0:
		_enter_rush()
		return
	_phase = Phase.WALK
	_set_af(false)
	_walk_from = _body.global_position
	_walk_to = _next_spot()
	_walk_c = _player_pos()
	_walk_t = 0.0
	_walk_dur = maxf(0.8, minf(_arc_length(), 24.0) / WALK_SPEED)
	# Broken, one foot drags.
	if _broken() != "":
		_sound(SFX_STEP_DRAG, _head(), 0.0, _rng.randf_range(0.92, 1.05), 30.0)
	else:
		_sound(SFX_STEPS, _head(), -2.0, _rng.randf_range(0.95, 1.05), 30.0)


func _tick_walk(dt: float) -> void:
	_walk_t += dt
	_step_acc += dt
	var k := clampf(_walk_t / _walk_dur, 0.0, 1.0)
	# Twelve steps a second, the game's machinery rate; the feet swap four times a second.
	if _step_acc >= STEP or k >= 1.0:
		_step_acc = 0.0
		var p := _arc(k)
		var was := _body.global_position
		var g := _ground(p)
		_body.global_position = g if g != Vector3.INF else p
		var step := _body.global_position - was
		var toward_you := (_player_pos() - was).normalized().dot(step.normalized()) > -0.4 if step.length() > 0.001 else true
		_set_pose(("walk_a" if int(_walk_t * 4.0) % 2 == 0 else "walk_b") if toward_you else "back")
	if k >= 1.0:
		_phase = Phase.SETTLE
		_phase_end = _elapsed + _rng.randf_range(0.5, 0.9)
		# Two pictures of you and his neck has gone: the head hangs, it cracks as he stops.
		if _broken() != "":
			_set_pose(_broken())
			_sound(SFX_CRACK, _head(), 4.0, _rng.randf_range(0.9, 1.05), 25.0)
		else:
			_set_pose("idle")
		_sound(SFX_WIND, _head(), 2.0, _rng.randf_range(0.95, 1.05), 40.0)


func _enter_frame() -> void:
	_phase = Phase.FRAME
	_phase_end = _elapsed + _frame_seconds
	_next_beep = _elapsed
	_whine_started = false
	_set_pose(_broken() if _broken() != "" else "aim")
	_sound(SFX_ZOOM, _head(), 0.0, 1.0, 30.0)
	if _rng.randf() < 0.45:
		_sound(SFX_RATTLE, _lens(), 0.0, _rng.randf_range(0.9, 1.1), 22.0)
	# Broken, his flash is too: it stutters once before it fires (not a shot).
	_flicker_at = _phase_end - _rng.randf_range(1.3, 1.8) if _broken() != "" and _rng.randf() < 0.5 else -1.0
	_announce("Humming between the trees. A red light. Beep... beep... Do not look at the flash.")


func _tick_frame() -> void:
	var left := _phase_end - _elapsed
	var progress := 1.0 - left / _frame_seconds
	# The beeps speed up as he settles the focus; the red lamp blinks with them.
	if _elapsed >= _next_beep:
		_next_beep = _elapsed + lerpf(0.5, 0.1, progress)
		_sound(SFX_BEEP, _head(), 4.0, 1.0 + progress * 0.15, 40.0)
		_set_af(true)
	elif _elapsed > _next_beep - lerpf(0.4, 0.05, progress):
		_set_af(false)
	if not _whine_started and left <= 1.1:
		_whine_started = true
		_sound(SFX_WHINE, _head(), 8.0, 1.0, 48.0)
	if _flicker_at > 0.0 and _elapsed >= _flicker_at:
		_flicker_at = -1.0
		_sputter()
	if left <= 0.0:
		_fire()


func _fire() -> void:
	_set_af(false)
	_shots += 1
	var head := _head()
	_set_pose("flash")
	_flash.global_position = head + Vector3(0, 0.3, 0)
	_flash_t = 0.35
	_sound(SFX_SHUTTER, head, 10.0, _rng.randf_range(0.95, 1.05), 48.0)
	_hit_last = _is_seen(head, 4.0)
	if _hit_last:
		_hits += 1
		if _player_health() <= _photo_damage:
			# Not again next frame: after it he walks on.
			_phase = Phase.AFTER
			_phase_end = _elapsed + 2.0
			_kill(head)
			return
		_hurt(_photo_damage)
		_blast_you()
		_picture_of_you(head, null)
		_feed("FLASH. He has you on film.")
	else:
		_dist = maxf(_min_dist, _dist - 2.0)
	_phase = Phase.AFTER
	_phase_end = _elapsed + _rng.randf_range(1.4, 2.2)
	# A moment in the flash, then the wave with the photo, giggling.
	get_tree_timer(0.3, func():
		if _phase == Phase.AFTER:
			_set_pose("wave" if _hit_last else "idle")
			if _hit_last:
				_sound(SFX_POLAROID, _head(), 0.0, 1.0, 30.0)
				if _broken() != "":
					# Through the photographs in his mouth; now and then he coughs one out.
					_sound(SFX_CHUCKLE_WET, _mouth(), 4.0, _rng.randf_range(0.9, 1.05), 35.0)
					if _rng.randf() < 0.45:
						get_tree_timer(1.1, func(): _sound(SFX_SPIT, _mouth(), 2.0, _rng.randf_range(0.9, 1.1), 25.0))
				else:
					_sound(SFX_GIGGLE, _head(), 4.0, _rng.randf_range(0.95, 1.1), 35.0))


func _grab() -> void:
	_hurt(_grab_damage)
	_blast_you()
	_sound(SFX_SHUTTER, _player_pos() + Vector3(0, 1.6, 0), 10.0, 0.7)
	_sound(SFX_GIGGLE, _head(), 6.0, 0.9, 20.0)
	_dist = 20.0
	var away := _point_from_player(_dist, _rng.randf_range(120.0, 240.0))
	if away != Vector3.INF:
		_body.global_position = away
	_enter_walk()


## His way to the next spot: round you along the arc (where you stood as he set off),
## never across you (a straight line between two spots round you can pass right
## through you, and walking into him is his grab).
func _arc(k: float) -> Vector3:
	var a := Vector2(_walk_from.x - _walk_c.x, _walk_from.z - _walk_c.z)
	var b := Vector2(_walk_to.x - _walk_c.x, _walk_to.z - _walk_c.z)
	if a.length() < 1.0 or b.length() < 1.0:
		return _walk_from.lerp(_walk_to, k)
	var v := Vector2.from_angle(lerp_angle(a.angle(), b.angle(), k)) * lerpf(a.length(), b.length(), k)
	return Vector3(_walk_c.x + v.x, lerpf(_walk_from.y, _walk_to.y, k), _walk_c.z + v.y)


func _arc_length() -> float:
	return _arc_between(_walk_from, _walk_to, _walk_c)


static func _arc_between(from: Vector3, to: Vector3, c: Vector3) -> float:
	var a := Vector2(from.x - c.x, from.z - c.z)
	var b := Vector2(to.x - c.x, to.z - c.z)
	if a.length() < 1.0 or b.length() < 1.0:
		return from.distance_to(to)
	return absf(angle_difference(a.angle(), b.angle())) * (a.length() + b.length()) * 0.5 + absf(a.length() - b.length())


## His next spot: round you at the distance of this round, never straight ahead, not
## where he is now; a little closer every shot you dodge.
func _next_spot() -> Vector3:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	for _i in 12:
		var ang := side * _rng.randf_range(55.0, 170.0)
		var p := _point_from_player(_dist, ang)
		if p == Vector3.INF:
			continue
		if _body.global_position.distance_to(p) < 5.0 or _arc_between(_body.global_position, p, _player_pos()) > 24.0:
			continue
		return p
	var q := _point_from_player(_dist, side * 110.0)
	return q if q != Vector3.INF else _body.global_position


# ── indoors: at your windows ─────────────────────────────────────────────────

func _im():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_interior_manager") if scene != null else null


## Indoors at night: the warden he hunts in a room (this machine's, or in co-op the
## other's, on their machine).
func _indoor_ok() -> bool:
	if _is_night_callable.is_valid() and not bool(_is_night_callable.call()):
		return false
	if _fx() == null:
		return false
	return _quarry_indoors()


## The windows of the room the warden he hunts is in (InteriorManager.photo_windows); in
## co-op another warden's, as their machine sends them (warden state "pw"), marked "far":
## their flash and their picture are done there.
func _windows() -> Array:
	var peer := _quarry_peer()
	if peer == 0:
		var im = _im()
		return im.photo_windows() if im != null and im.has_method("photo_windows") else []
	var out: Array = []
	for w in Coop.state_of(peer).get("pw", []):
		out.append({"pos": w[0], "out": w[1], "open": float(w[2]), "facing": float(w[3]), "far": true})
	return out


func _tick_indoors(_dt: float) -> void:
	if _killing:
		return
	var wins := _windows()
	if wins.is_empty():
		# No windows (a tent, the toilets): he walks round outside humming; the flash
		# lights the walls, no more.
		_body.visible = false
		if _elapsed >= _in_next:
			_in_next = _elapsed + _rng.randf_range(9.0, 14.0)
			_room(SFX_SHUTTER, -10.0, 0.9)
		return
	if _win.is_empty() or _elapsed >= _in_next and _in_step == 0:
		_pick_window(wins)
		return
	# The window he is at, as it is now (the curtain, where you look).
	var w := _current(wins)
	if w.is_empty():
		_win = {}
		return
	_body.visible = true
	var lamp := _body.global_position + Vector3(0, (CAMERA_AT["glass"] as Vector2).y, 0) - (w["out"] as Vector3) * 0.2
	if _in_step == 3:
		# Framing through the glass: beeps, the red lamp, the whine.
		var left := _in_next - _elapsed
		var progress := 1.0 - clampf(left / _frame_seconds, 0.0, 1.0)
		if _elapsed >= _in_beep:
			_in_beep = _elapsed + lerpf(0.5, 0.1, progress)
			_room(SFX_BEEP, -6.0, 1.0 + progress * 0.15)
			_set_af_at(lamp, true)
		elif _elapsed > _in_beep - lerpf(0.4, 0.05, progress):
			_set_af_at(lamp, false)
		if left <= 1.1 and not _whine_started:
			_whine_started = true
			_room(SFX_WHINE, -2.0)
		if left <= 0.0:
			_fire_through(w)
		return
	if _elapsed < _in_next:
		_standby_at(lamp)
		return
	match _in_step:
		1:
			# Taps on the glass with the camera.
			_room(SFX_TAP, -2.0)
			_in_step = 2
			_in_next = _elapsed + _rng.randf_range(1.2, 2.0)
		2:
			if _broken() != "" and _rng.randf() < 0.5:
				# Wet paper and a jaw that clicks, against the glass.
				_room(SFX_RUSTLE if _rng.randf() < 0.6 else SFX_JAW, -4.0)
			elif _rng.randf() < 0.5:
				_room(SFX_BREATH, -6.0)
			else:
				_room(SFX_ZOOM, -8.0)
			_set_pose("aim")
			_in_step = 3
			_in_next = _elapsed + _frame_seconds
			_in_beep = _elapsed
			_whine_started = false
		4:
			# After the shot: to another window (or this one again), in a while.
			_win = {}
			_in_step = 0
			_in_next = _elapsed + _rng.randf_range(2.0, 4.0)


func _pick_window(wins: Array) -> void:
	# Mostly one with its curtain open, and of those the one you look at.
	var best: Dictionary = wins[_rng.randi() % wins.size()]
	var score := -INF
	for w in wins:
		var s := float(w.get("open", 1.0)) * 2.0 + float(w.get("facing", 0.0)) + _rng.randf_range(0.0, 0.8)
		if s > score:
			score = s
			best = w
	_win = best
	var p := _ground((best["pos"] as Vector3) + (best["out"] as Vector3) * 0.5)
	if p == Vector3.INF:
		p = (best["pos"] as Vector3) + (best["out"] as Vector3) * 0.5 - Vector3(0, 1.6, 0)
	_body.global_position = p
	_set_pose("glass" if _tex.has("glass") else "aim")
	if _glass_light == null:
		_glass_light = OmniLight3D.new()
		_glass_light.light_color = Color(1.0, 0.8, 0.55)
		_glass_light.omni_range = 2.0
		_glass_light.light_energy = 0.8
		_root.add_child(_glass_light)
	_glass_light.global_position = (best["pos"] as Vector3) + (best["out"] as Vector3) * 0.25
	_glass_light.visible = true
	_in_step = 1
	_in_next = _elapsed + _rng.randf_range(1.5, 3.0)
	_announce("Humming outside the window. A red light on the glass. Draw the curtains.")


## The same window in this moment's list (by where it is), {} gone.
func _current(wins: Array) -> Dictionary:
	for w in wins:
		if (w["pos"] as Vector3).distance_to(_win["pos"]) < 0.3:
			return w
	return {}


func _fire_through(w: Dictionary) -> void:
	_set_af_at(Vector3.ZERO, false)
	_shots += 1
	_set_pose("flash")
	_room(SFX_FLASH_ROOM, 2.0)
	_room(SFX_SHUTTER, -4.0)
	if bool(w.get("far", false)):
		var fx := _fx()
		if fx != null:
			fx.call("ext", "window_flash", [w["pos"]])
	else:
		var flash: Callable = w.get("flash", Callable())
		if flash.is_valid():
			flash.call()
	_flash.global_position = _head() + Vector3(0, 0.2, 0)
	_flash_t = 0.35
	var open := float(w.get("open", 1.0))
	if open > 0.25 and float(w.get("facing", -1.0)) > 0.2:
		_hits += 1
		if _player_health() <= _photo_damage:
			_in_step = 4
			_in_next = _elapsed + 2.0
			_kill(_head())
			return
		_hurt(_photo_damage)
		_blast_you()
		_picture_of_you(_head(), w)
		_feed("FLASH through the window. Draw the curtains.")
		get_tree_timer(0.5, func(): _room(SFX_GIGGLE, -4.0))
	elif open <= 0.25:
		# The curtain: a shape behind it, lit; he taps, annoyed.
		get_tree_timer(0.6, func(): _room(SFX_TAP, -2.0, 0.9))
	_in_step = 4
	_in_next = _elapsed + _rng.randf_range(1.2, 2.0)


## A sound in the room you are in (through the wall: no direction, a little dull); in
## co-op, on the hunted warden's machine.
func _room(path: String, db: float, pitch: float = 1.0) -> void:
	if _play_2d_remote(path, db, pitch):
		return
	if _room_audio == null or not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = pitch
	_root.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


# ── always there ─────────────────────────────────────────────────────────────

func _follow_hum() -> void:
	if _self_light != null:
		var cam := _camera()
		var toward := (cam.global_position - _head()).normalized() if cam != null else Vector3.ZERO
		_self_light.global_position = _head() + Vector3(0, -0.5, 0) + toward * 0.6
	if _hum != null and is_instance_valid(_hum):
		_hum_for(_broken())
		_hum.global_position = _mouth()
		if _breath3d != null and is_instance_valid(_breath3d):
			_breath3d.global_position = _mouth()
		# Quieter through a wall, still there.
		var db := (-14.0 if not _win.is_empty() or not _is_ready() else -6.0) + _hum_gain
		# Muted on this machine for co-op privacy (coop_night._hide_private): kept for later.
		if _hum.has_meta("coop_db"):
			_hum.set_meta("coop_db", db)
		else:
			_hum.volume_db = db


## The camera's red standby lamp: once a second, a short blink (not while framing).
func _standby(dt: float) -> void:
	if _phase == Phase.FRAME:
		return
	_standby_t += dt
	_set_af(fmod(_standby_t, 1.0) < 0.12)


func _standby_at(at: Vector3) -> void:
	_standby_t += get_process_delta()
	_set_af_at(at, fmod(_standby_t, 1.0) < 0.12)


func get_process_delta() -> float:
	return _world_root.get_process_delta_time() if _world_root != null else 0.016


func _set_pose(p: String) -> void:
	if p == _pose or _body == null:
		return
	_pose = p
	var t: Texture2D = _tex.get(p, _tex.get("idle"))
	if t == null:
		return
	_body.texture = t
	if _frames.has(p):
		_body.texture = _frames[p][0]
	_anim_t = 0.0
	_anim_i = -1
	# Every picture of him at one density (140 pixels are 1.9 m): the broken neck as tall
	# as it is drawn, at the glass the upper half of him pressed to it (lifted).
	var lift := 0.75 if p == "glass" else 0.0
	_body.pixel_size = 1.9 / 140.0
	_body.offset = Vector2(0, t.get_height() * 0.5 + lift / _body.pixel_size)
	# His camera's lamp where the camera is in this one.
	if _eyes != null and CAMERA_AT.has(p):
		_eyes.set("height", (CAMERA_AT[p] as Vector2).y)
		_eyes.set("x_off", (CAMERA_AT[p] as Vector2).x)


func _tick_flash(dt: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		# A hard white pop that falls off over a third of a second.
		_flash.light_energy = 40.0 * pow(_flash_t / 0.35, 2.0)


## Caught: a white blast over the screen, the ringing, his flash-lit picture burnt in
## (nightmare_fx; in co-op on the hunted warden's screen).
func _blast_you() -> void:
	var fx := _fx()
	if fx == null:
		return
	fx.white_blast(1.0)
	if fx.has_method("tinnitus"):
		fx.tinnitus(1.6)
	var burnt: Texture2D = _tex.get("face_peel" if _hits % 2 == 0 else "face_lens", _tex.get("flash"))
	if fx.has_method("subliminal") and burnt != null:
		get_tree_timer(0.18, func():
			var f := _fx()
			if f != null:
				f.subliminal(burnt, 4, 1.0, Color(0.75, 0.78, 0.9)))
	if _hits % 2 == 0:
		get_tree_timer(0.4, func(): _room(SFX_PEEL, -6.0))


func get_tree_timer(sec: float, fn: Callable) -> void:
	if _world_root == null or not _world_root.is_inside_tree():
		return
	_world_root.get_tree().create_timer(sec).timeout.connect(fn)


# ── worse ────────────────────────────────────────────────────────────────────

## The picture he took (scripts/enemies/polaroid.gd): you, from his lens. Every third,
## him right behind you in it. Through a window `w`: taken in your room, from the glass.
func _picture_of_you(lens: Vector3, w) -> void:
	var extra: Texture2D = _tex.get("idle") if _hits % 3 == 0 else null
	_photo(lens, extra, w if w is Dictionary else {}, false)


## The picture on the hunted warden's screen (polaroid.take_of): here, or in co-op sent
## to their machine and taken there, of them (coop_night._on_ext "polaroid").
func _photo(lens: Vector3, extra: Texture2D, w: Dictionary, big: bool) -> void:
	var fx := _fx()
	if fx == null:
		return
	if _quarry_peer() != 0:
		fx.call("ext", "polaroid", [lens, extra, big, w.get("pos")])
		return
	if _polaroid == null or not is_instance_valid(_polaroid):
		_polaroid = POLAROID.new()
		_world_root.get_tree().root.add_child(_polaroid)
	_polaroid.call("take_of", _world_root.get_world_3d(), lens, _player, extra, w, big)


## The last picture: the frame stops, his lens-face comes at you in steps, the word wet
## in your ear, the flash, and your own face develops in the middle of the screen.
func _kill(lens: Vector3) -> void:
	if _killing:
		return
	_killing = true
	var fx := _fx()
	var face: Texture2D = _tex.get("face_lens")
	if fx == null or face == null:
		_hurt(_photo_damage)
		_killing = false
		return
	fx.freeze(0.25)
	_room(SFX_WHISPER, 4.0)
	for i in 6:
		var k := float(i) / 5.0
		get_tree_timer(0.18 * float(i), func():
			var f := _fx()
			if f != null:
				f.close_up(face, lerpf(0.55, 1.5, k), 1.0, 0.004 + 0.01 * k))
	get_tree_timer(1.15, func():
		var f := _fx()
		if f != null:
			f.close_up_off()
		_room(SFX_SHUTTER, 8.0, 0.8)
		_room(SFX_LAUGH_WET, 2.0)
		_blast_you()
		# Your face, from right in front of it, looking at him.
		_photo(lens, null, {}, true)
		# You watch it develop, held still, and only then does it end.
		if _player != null and _player.has_method("set_controls_enabled"):
			_player.call("set_controls_enabled", false)
		get_tree_timer(3.8, func():
			if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
				_player.call("set_controls_enabled", true)
			_hurt(_photo_damage * 3)
			_killing = false))


## Out of the dark behind you, at a run, laughing, and the flash at your ear: turn round
## to it and it is in your eyes.
func _enter_rush() -> void:
	_phase = Phase.RUSH
	_set_af(false)
	var behind := _point_from_player(_rng.randf_range(14.0, 18.0), _rng.randf_range(160.0, 200.0))
	if behind != Vector3.INF:
		_body.global_position = behind
	_rush_from = _body.global_position
	_set_pose("run" if _tex.has("run") else "walk_a")
	_sound(SFX_RUSH, _head(), 8.0, 1.0, 40.0)
	get_tree_timer(0.3, func(): _sound(SFX_LAUGH_WET, _head(), 4.0, 1.1, 30.0))


func _tick_rush(dt: float) -> void:
	_step_acc += dt
	if _step_acc < STEP:
		return
	var to := _player_pos() - _body.global_position
	to.y = 0.0
	if to.length() <= 3.0:
		# At your ear: the whisper, the flash.
		_room(SFX_WHISPER, 2.0)
		_phase = Phase.FRAME
		_phase_end = _elapsed + 0.35
		_whine_started = true
		_next_beep = _elapsed + 1.0
		return
	var p := _body.global_position + to.normalized() * minf(to.length() - 2.8, RUSH_SPEED * _step_acc)
	_step_acc = 0.0
	var g := _ground(p)
	_body.global_position = g if g != Vector3.INF else p


## (Nowhere once the night is over: a timer of his may still go off after it.)
func _head() -> Vector3:
	if _body == null or not is_instance_valid(_body):
		return Vector3.ZERO
	return _body.global_position + Vector3(0, 1.6, 0)


func _set_af(on: bool) -> void:
	_set_af_at(_lens(), on)


## The camera's red lamp on or off at `at` (its light; the point of it is the eyes, where
## the camera is in his picture). Off, your torch on the lens still throws it back white.
func _set_af_at(at: Vector3, on: bool) -> void:
	if at != Vector3.ZERO:
		_af_lamp.global_position = at
	_af_lamp.light_energy = 1.1 if on else 0.0
	if _eyes != null:
		var seen := CAMERA_AT.has(_pose if _pose != "" else "idle")
		_eyes.set("want", 1.0 if seen and (on or float(_eyes.get("flare")) > 0.3) else 0.0)
		_eyes.set("tint", Color(1.0, 0.14, 0.08) if on else Color(0, 0, 0, 0))


## His pose's frame now (ANIM), and what goes with the frames of a broken neck (the creak
## at the end of each sway, the wet swing of the head at his belly).
func _tick_anim(dt: float) -> void:
	var a: Dictionary = ANIM.get(_pose, {})
	var fr: Array = _frames.get(_pose, [])
	if a.is_empty() or fr.is_empty():
		return
	_anim_t += dt
	var i := 0
	if _spasm_left > 0.0 and a.has("spasm"):
		_spasm_left -= dt
		i = int(a["spasm"])
	else:
		var seq: Array = a.get("seq", [])
		var k := int(_anim_t * float(a["fps"]))
		i = int(seq[k % seq.size()]) if not seq.is_empty() else k % int(a["n"])
	if i != _anim_i:
		_anim_i = i
		if _pose == "neck" and (i == 3 or i == 8) and _rng.randf() < 0.3:
			_sound(SFX_NECK_CREAK, _mouth(), -2.0, _rng.randf_range(0.85, 1.1), 18.0)
		elif _pose == "neck2" and (i == 3 or i == 9) and _rng.randf() < 0.35:
			_sound(SFX_HEAD_SWING, _mouth(), 0.0, _rng.randf_range(0.9, 1.1), 18.0)
	if i < fr.size() and _body.texture != fr[i]:
		_body.texture = fr[i]


## Broken, he is never still: the neck jerks (the spasm frame, the snap, the jaw), the
## wet photographs in his mouth, the drip at his feet, and from the head at his belly a
## scream through the paper. Whole or not, out of your sight a shutter goes now and then
## far off in the dark.
func _tick_grim(dt: float) -> void:
	for k in _grim:
		_grim[k] = float(_grim[k]) - dt
	var b := _broken()
	if b != "":
		_spasm_wait -= dt
		if _spasm_wait <= 0.0:
			_spasm_wait = _rng.randf_range(2.5, 6.0)
			_spasm_left = 0.17
			_sound(SFX_TWITCH, _mouth(), 2.0, _rng.randf_range(0.9, 1.1), 22.0)
			if _rng.randf() < 0.4:
				_sound(SFX_JAW, _mouth(), 0.0, _rng.randf_range(0.9, 1.1), 16.0)
		if float(_grim["rustle"]) <= 0.0:
			_grim["rustle"] = _rng.randf_range(4.0, 8.0)
			_sound(SFX_RUSTLE, _mouth(), -2.0, _rng.randf_range(0.9, 1.1), 14.0)
		if float(_grim["drip"]) <= 0.0:
			_grim["drip"] = _rng.randf_range(2.5, 5.0)
			_sound(SFX_DRIP, _body.global_position + Vector3(0, 0.2, 0), -6.0, _rng.randf_range(0.9, 1.1), 10.0)
		if b == "neck2" and float(_grim["scream"]) <= 0.0:
			_grim["scream"] = _rng.randf_range(7.0, 14.0)
			_sound(SFX_SCREAM, _mouth(), 2.0, _rng.randf_range(0.9, 1.05), 35.0)
	if _phase == Phase.WALK and float(_grim["far"]) <= 0.0:
		_grim["far"] = _rng.randf_range(12.0, 22.0)
		if _distance_to_player(_body.global_position) > 14.0 and not _is_seen(_head(), 0.0):
			_sound(SFX_SHUTTER_FAR, _head(), 2.0, _rng.randf_range(0.9, 1.05), 70.0)


## The broken flash stutters: three weak pops of his light and the crackle (no shot).
func _sputter() -> void:
	_sound(SFX_FLICKER, _head(), 2.0, _rng.randf_range(0.95, 1.05), 35.0)
	for at in [0.0, 0.14, 0.33]:
		get_tree_timer(at + 0.01, func():
			if _flash != null and is_instance_valid(_flash):
				_flash.global_position = _head() + Vector3(0, 0.3, 0)
				_flash_t = maxf(_flash_t, 0.09))


## Where his mouth is now: up on the head, or (the neck let go) at his belly.
func _mouth() -> Vector3:
	if _body == null or not is_instance_valid(_body):
		return Vector3.ZERO
	return _body.global_position + Vector3(0, 0.9 if _pose == "neck2" else 1.75, 0)


## The hum for what he is now: whole, gargled through the broken throat, or muffled by
## the paper from the head at his belly; broken, his wet breathing with it.
func _hum_for(stage: String) -> void:
	if stage == _hum_stage:
		return
	_hum_stage = stage
	var path := SFX_HUM if stage == "" else (SFX_HUM_GARGLE if stage == "neck" else SFX_HUM_MUFFLED)
	var st := _looped(path)
	if st != null:
		_hum.stream = st
		_hum.play()
	_hum_gain = 0.0 if stage == "" else 6.0
	if stage != "" and _breath3d == null:
		_breath3d = _loop(SFX_BREATH_BROKEN, -6.0)
		if _breath3d != null:
			_breath3d.max_distance = 14.0


static func _looped(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st := load(path) as AudioStream
	if st is AudioStreamMP3:
		st = (st as AudioStreamMP3).duplicate()
		(st as AudioStreamMP3).loop = true
	return st


## What the pictures of you have done to him: two and his neck has broken (the head hangs
## off it sideways, the mouth stuffed with photographs); four and it has let go (the
## collar an empty stump, the head hanging upside down at his belly, screaming). "" whole.
func _broken() -> String:
	if _hits >= 4 and _tex.has("neck2"):
		return "neck2"
	if _hits >= 2 and _tex.has("neck"):
		return "neck"
	return ""


## His camera, where it is in this picture of him, a little out in front of him (seen
## from the warden he hunts).
func _lens() -> Vector3:
	var c: Vector2 = CAMERA_AT.get(_pose if _pose != "" else "idle", CAMERA_AT["idle"])
	var to := _player_pos() - _body.global_position
	to.y = 0.0
	var toward := to.normalized() if to.length() > 0.01 else Vector3.ZERO
	return _body.global_position + Vector3(0, c.y, 0) + Vector3.UP.cross(toward) * c.x + toward * 0.12


func get_debug_snapshot() -> Dictionary:
	return {
		"phase": ["walk", "settle", "frame", "after", "rush"][_phase],
		"distance": snappedf(_distance_to_player(_body.global_position), 0.1),
		"shots": _shots,
		"hits": _hits,
		"window": not _win.is_empty(),
		"pose": _pose,
	}
