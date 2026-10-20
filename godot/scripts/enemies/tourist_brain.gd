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

const SPRITE := "res://assets/textury/npc/tourist_idle.png"
const POSES := {
	"walk_a": "res://assets/textury/npc/tourist_walk_a.png",
	"walk_b": "res://assets/textury/npc/tourist_walk_b.png",
	"aim": "res://assets/textury/npc/tourist_aim.png",
	"flash": "res://assets/textury/npc/tourist_flash.png",
	"wave": "res://assets/textury/npc/tourist_wave.png",
	"glass": "res://assets/textury/npc/tourist_glass.png",
	"back": "res://assets/textury/npc/tourist_back.png",
}
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
const GRAB_DISTANCE := 2.6
const WALK_SPEED := 3.2
const STEP := 1.0 / 12.0

enum Phase { WALK, SETTLE, FRAME, AFTER }

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
var _af_dot: MeshInstance3D
var _photo_damage := 18
var _grab_damage := 32
var _shots := 0
var _hits := 0
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
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
var _blast: CanvasLayer
var _blast_rect: ColorRect
var _blast_t := 0.0


func get_enemy_id() -> String:
	return "tourist"


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
	# One eye, the lens; the focus lamp blinks red in the middle of it.
	_make_eyes("tourist", 1.65)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.92, 0.95, 1.0)
	_flash.omni_range = 30.0
	_flash.omni_attenuation = 0.8
	_flash.light_energy = 0.0
	_flash.shadow_enabled = true
	_root.add_child(_flash)
	# The red lamp on the camera: the one thing you can see of him in the dark.
	_af_lamp = OmniLight3D.new()
	_af_lamp.light_color = Color(1.0, 0.1, 0.05)
	_af_lamp.omni_range = 1.4
	_af_lamp.light_energy = 0.0
	_root.add_child(_af_lamp)
	_af_dot = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	_af_dot.mesh = sphere
	var dot_mat := StandardMaterial3D.new()
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.albedo_color = Color(1.0, 0.15, 0.1)
	dot_mat.no_depth_test = false
	_af_dot.material_override = dot_mat
	_af_dot.visible = false
	_root.add_child(_af_dot)
	# A soft red glow round it, so it reads at 20 m on a low-res screen.
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	glow.mesh = quad
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = _glow_texture()
	glow_mat.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
	glow.material_override = glow_mat
	_af_dot.add_child(glow)
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


func _on_stop() -> void:
	if _blast != null and is_instance_valid(_blast):
		_blast.queue_free()
	_blast = null


## The base ticks nothing while you are indoors; then he is at your windows.
func tick(delta: float) -> void:
	if _night_active and _player != null and is_instance_valid(_player) and not _is_ready() and _indoor_ok():
		_elapsed += delta
		_tick_blast(delta)
		_tick_flash(delta)
		_tick_indoors(delta)
		_follow_hum()
		_tick_eyes(delta)
		return
	if not _win.is_empty():
		_win = {}
		_body.visible = false
	if _glass_light != null:
		_glass_light.visible = false
	super(delta)
	_tick_blast(delta)


func _on_tick(dt: float) -> void:
	_tick_flash(dt)
	_body.visible = true
	_follow_hum()
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


# ── outdoors ─────────────────────────────────────────────────────────────────

func _enter_walk() -> void:
	_phase = Phase.WALK
	_set_af(false)
	_walk_from = _body.global_position
	_walk_to = _next_spot()
	_walk_t = 0.0
	_walk_dur = maxf(0.8, _walk_from.distance_to(_walk_to) / WALK_SPEED)
	_sound(SFX_STEPS, _head(), -2.0, _rng.randf_range(0.95, 1.05), 30.0)


func _tick_walk(dt: float) -> void:
	_walk_t += dt
	_step_acc += dt
	var k := clampf(_walk_t / _walk_dur, 0.0, 1.0)
	# Twelve steps a second, the game's machinery rate; the feet swap four times a second.
	if _step_acc >= STEP or k >= 1.0:
		_step_acc = 0.0
		var p := _walk_from.lerp(_walk_to, k)
		var g := _ground(p)
		_body.global_position = g if g != Vector3.INF else p
		var toward_you := (_player_pos() - _body.global_position).dot(_walk_to - _walk_from) > 0.0
		_set_pose(("walk_a" if int(_walk_t * 4.0) % 2 == 0 else "walk_b") if toward_you else "back")
	if k >= 1.0:
		_phase = Phase.SETTLE
		_phase_end = _elapsed + _rng.randf_range(0.5, 0.9)
		_set_pose("idle")
		_sound(SFX_WIND, _head(), 2.0, _rng.randf_range(0.95, 1.05), 40.0)


func _enter_frame() -> void:
	_phase = Phase.FRAME
	_phase_end = _elapsed + _frame_seconds
	_next_beep = _elapsed
	_whine_started = false
	_set_pose("aim")
	_sound(SFX_ZOOM, _head(), 0.0, 1.0, 30.0)
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
		_hurt(_photo_damage)
		_blast_you()
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


## His next spot: round you at the distance of this round, never straight ahead, not
## where he is now; a little closer every shot you dodge.
func _next_spot() -> Vector3:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	for _i in 12:
		var ang := side * _rng.randf_range(55.0, 170.0)
		var p := _point_from_player(_dist, ang)
		if p == Vector3.INF:
			continue
		if _body.global_position.distance_to(p) < 5.0 or _body.global_position.distance_to(p) > 22.0:
			continue
		return p
	var q := _point_from_player(_dist, side * 110.0)
	return q if q != Vector3.INF else _body.global_position


# ── indoors: at your windows ─────────────────────────────────────────────────

func _im():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_interior_manager") if scene != null else null


## Indoors at night, with this machine's warden (not the other's stand-in) in a room.
func _indoor_ok() -> bool:
	if _is_night_callable.is_valid() and not bool(_is_night_callable.call()):
		return false
	if _fx() == null:
		return false
	var im = _im()
	return im != null and im.has_method("photo_windows") and im.has_method("is_any_open") and bool(im.is_any_open())


func _tick_indoors(_dt: float) -> void:
	var im = _im()
	var wins: Array = im.photo_windows() if im != null else []
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
	var lamp := _head() + (w["out"] as Vector3) * -0.25
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
			if _rng.randf() < 0.5:
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
	var flash: Callable = w.get("flash", Callable())
	if flash.is_valid():
		flash.call()
	_flash.global_position = _head() + Vector3(0, 0.2, 0)
	_flash_t = 0.35
	var open := float(w.get("open", 1.0))
	if open > 0.25 and float(w.get("facing", -1.0)) > 0.2:
		_hits += 1
		_hurt(_photo_damage)
		_blast_you()
		_feed("FLASH through the window. Draw the curtains.")
		get_tree_timer(0.5, func(): _room(SFX_GIGGLE, -4.0))
	elif open <= 0.25:
		# The curtain: a shape behind it, lit; he taps, annoyed.
		get_tree_timer(0.6, func(): _room(SFX_TAP, -2.0, 0.9))
	_in_step = 4
	_in_next = _elapsed + _rng.randf_range(1.2, 2.0)


## A sound in the room you are in (through the wall: no direction, a little dull).
func _room(path: String, db: float, pitch: float = 1.0) -> void:
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
		_hum.global_position = _head()
		# Quieter through a wall, still there.
		_hum.volume_db = -14.0 if not _win.is_empty() or not _is_ready() else -6.0


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
	# At the glass he is the upper half of him, pressed to it (a picture of the waist up).
	var h := 1.05 if p == "glass" else 1.9
	var lift := 0.75 if p == "glass" else 0.0
	_body.pixel_size = h / float(t.get_height())
	_body.offset = Vector2(0, t.get_height() * 0.5 + lift / _body.pixel_size)


func _tick_flash(dt: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - dt)
		# A hard white pop that falls off over a third of a second.
		_flash.light_energy = 40.0 * pow(_flash_t / 0.35, 2.0)


## Caught: a white blast over the screen, the ringing, his flash-lit picture burnt in.
func _blast_you() -> void:
	var fx := _fx()
	if fx == null:
		return
	if _blast == null or not is_instance_valid(_blast):
		_blast = CanvasLayer.new()
		_blast.layer = 120
		_blast_rect = ColorRect.new()
		_blast_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blast_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blast_rect.color = Color(1, 1, 1, 0)
		_blast.add_child(_blast_rect)
		_world_root.get_tree().root.add_child(_blast)
	_blast_t = 1.0
	if fx.has_method("tinnitus"):
		fx.tinnitus(1.6)
	if fx.has_method("subliminal") and _tex.has("flash"):
		get_tree_timer(0.18, func():
			var f := _fx()
			if f != null:
				f.subliminal(_tex["flash"], 3, 1.6, Color(0.6, 0.65, 0.75)))


func _tick_blast(delta: float) -> void:
	if _blast_rect == null or not is_instance_valid(_blast_rect):
		return
	_blast_t = maxf(0.0, _blast_t - delta * 0.9)
	_blast_rect.color = Color(1, 1, 1, pow(_blast_t, 1.5) * 0.95)


func get_tree_timer(sec: float, fn: Callable) -> void:
	if _world_root == null or not _world_root.is_inside_tree():
		return
	_world_root.get_tree().create_timer(sec).timeout.connect(fn)


func _head() -> Vector3:
	return _body.global_position + Vector3(0, 1.6, 0)


func _set_af(on: bool) -> void:
	_set_af_at(_head() + Vector3(0, 0.05, 0), on)


func _set_af_at(at: Vector3, on: bool) -> void:
	if at != Vector3.ZERO:
		_af_lamp.global_position = at
		_af_dot.global_position = at
	_af_lamp.light_energy = 2.4 if on else 0.0
	_af_dot.visible = on


func _glow_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


func get_debug_snapshot() -> Dictionary:
	return {
		"phase": ["walk", "settle", "frame", "after"][_phase],
		"distance": snappedf(_distance_to_player(_body.global_position), 0.1),
		"shots": _shots,
		"hits": _hits,
		"window": not _win.is_empty(),
		"pose": _pose,
	}
