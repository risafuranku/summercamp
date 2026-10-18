extends CanvasLayer

## Inside the line 380 bus, like the rooms: its own little world drawn small and scaled
## up, the restricted look, the cursor. You come in at the front door with the bus
## standing at the stop:
##   - the ticket machine on the pole (click: scripts/town/ticket_closeup.gd), the
##     driver (click: he says something), the seats (click one to sit down, with a
##     ticket that is good for where it goes), the door or the bottom of the screen to
##     get off again;
##   - sitting down: the doors hiss shut, the engine labours, and for a minute the land
##     goes past the windows (scripts/town/ride_scenery.gd: forest, the reservoir,
##     fields, the first houses), mouse to look round, until it pulls up at the other
##     end and town_trip.gd puts you out there (`arrived`).
## The game's clock runs on: the ride is the hour and a half the timetable says.
## Co-op: the other warden rides the same bus. You see them on board (standing at the
## front till they sit, then in their seat: from the front or, sat behind them, their
## back), the people already on board are the same for both, and the bus does not go
## while they are on it and not yet sat down (buying a ticket), nor for a moment while
## they are near the stop outside.
## Outside is lit by the hour and the weather (set_time); at night the strip lights are
## on inside and the windows are black but for what passes.

signal arrived
signal left_bus

const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const SCENERY = preload("res://scripts/town/ride_scenery.gd")
const TICKET = preload("res://scripts/town/ticket_closeup.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const TEX := "res://assets/textury/town/"
const TEX_CAMP := "res://assets/textury/camp/"
const SFX := "res://assets/sfx/bus/"
const NPC := "res://assets/textury/npc/"
const CRUISE := 17.0
const ACCEL := 2.4
const BRAKE := 2.2
const HALF_W := 1.22
const FLOOR_Z := Vector2(-5.0, 5.0)
const STAND_POS := Vector3(0.62, 1.62, -3.45)
const STAND_LOOK := Vector3(-0.2, 1.1, -0.6)
## Seats (x, z): the right row skips the doors; the player's seat is one of these.
const SEATS := [Vector2(-0.68, -2.5), Vector2(-0.68, -1.6), Vector2(-0.68, -0.7), Vector2(-0.68, 0.2), Vector2(-0.68, 1.1), Vector2(-0.68, 2.0), Vector2(-0.68, 2.9), Vector2(-0.68, 3.8),
	Vector2(0.68, -2.5), Vector2(0.68, -1.6), Vector2(0.68, -0.7), Vector2(0.68, 2.0), Vector2(0.68, 2.9), Vector2(0.68, 3.8)]
const DRIVER_LINES := {
	"camp": ["Lesna, Hlubocany. Ticket from the machine.", "Machine. I don't do change.", "We go when we go."],
	"town": ["The camp? It's the end. Nobody gets off before.", "Machine. Not me.", "Last one tonight. Sit down."],
}
const DRIVER_NIGHT := ["Sit where I can see you.", "Don't open the window.", "We don't stop in the forest. Whatever waves."]

enum { CLOSED, BOARDING, SITTING, RIDING, STOPPING, DONE, HELD }

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
## How long a bus waits for the other warden near the stop outside (real seconds).
const MATE_WAIT := 15.0
## Where the stop is in the camp's world (town_trip sets it): "near the stop" is from here.
var stop_pos := Vector3.INF
var _mate: Sprite3D
var _mate_pose := ""
var _mate_wait := 0.0
var _mate_said := false

## "camp": standing at the camp stop, going to Lesna; "town": in Lesna, going to the camp.
var stop := "camp"
var worldgen: Node
var _state := CLOSED
var _built := false
var _container: SubViewportContainer
var _vp: SubViewport
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _cam: Camera3D
var _cam_base := Vector3.ZERO
var _look = INTERIOR_LOOK.new(115.0, 26.0, 34.0)
var _scenery
var _speed := 0.0
var _speed_prev := 0.0
## What swings with the bus: curtains, the mascot ({node, base, k}), in steps.
var _swingers: Array = []
var _swing := 0.0
var _swing_v := 0.0
var _swing_acc := 0.0
var _hot: Array = []
var _hover := ""
var _glint = HOVER_GLINT.new()
var _ticket_view
var _ticket: Dictionary = {}
var _ticket_card: Control
var _exit_hint: Control
var _say_label: Label
var _say_t := 0.0
var _ride: AudioStreamPlayer
var _one: AudioStreamPlayer
var _strip_mat: StandardMaterial3D
var _strip_lights: Array[OmniLight3D] = []
var _passengers: Array[Sprite3D] = []
var _taken: Dictionary = {}
var _seat := -1
var _done_t := 0.0
var _bump_t := 0.0
var _bump := 0.0
var _night := false
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _door_leaves: Array[MeshInstance3D] = []
var _glass: ShaderMaterial
## The panes: a little dirt, and in the rain drops running down them, blown back as the
## bus picks up speed (moved in steps, twelve a second).
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float rain = 0.0;
uniform float t = 0.0;
uniform float speed = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * vec2(110.0, 9.0);
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float r = h(cell);
	float drop = 0.0;
	if (r < 0.45 * rain) {
		// One drop per cell: it slides down (and back with the speed), leaving a trail.
		float y = fract(h(cell + 3.1) + t * (0.25 + r * 0.6));
		float x = 0.5 + (h(cell + 7.7) - 0.5) * 0.5 - (y - 0.5) * speed * 0.6;
		float d = abs(f.x - x);
		if (d < 0.09 && abs(f.y - y) < 0.12) { drop = 1.0; }
		else if (d < 0.05 && f.y < y) { drop = 0.35; }
	}
	ALBEDO = mix(vec3(0.7, 0.75, 0.76), vec3(0.88, 0.92, 0.95), drop);
	ALPHA = 0.08 + drop * 0.45;
}
"""


func _glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = GLASS_SHADER
		_glass.shader = sh
	return _glass


func _init() -> void:
	name = "BusRide"
	layer = 57
	visible = false


func _ready() -> void:
	_rng.randomize()


func is_open() -> bool:
	return _state != CLOSED


func is_riding() -> bool:
	return _state in [SITTING, RIDING, STOPPING, DONE, HELD]


## Co-op: where you are on this bus, for the other machine ({} off it): the stop, the
## seat (-1 standing) and whether it has gone.
func coop_state() -> Dictionary:
	if _state == CLOSED:
		return {}
	return {"st": stop, "s": _seat, "go": _state in [RIDING, STOPPING, DONE]}


## The other warden on a bus (their coop_state), or {}.
func _mate_info() -> Dictionary:
	if not Coop.has_partner():
		return {}
	var b = Coop.partner_state.get("bus", {})
	return b if b is Dictionary else {}


func _mate_aboard() -> bool:
	var m := _mate_info()
	return not m.is_empty() and str(m.get("st", "")) == stop and not bool(m.get("go", false))


# ── in and out ───────────────────────────────────────────────────────────────

## Gets on the bus standing at `at_stop` ("camp" or "town") at `hour`.
var _hour_now := 0.0


func open_ride(at_stop: String, hour: float, fog: float, raining: bool) -> void:
	stop = at_stop
	_hour_now = hour
	if not _built:
		_build()
		_built = true
	RETRO_RENDER.apply_to(_container)
	_state = BOARDING
	visible = true
	_ticket = {}
	_ticket_card.visible = false
	_seat = -1
	_mate_wait = 0.0
	_mate_said = false
	_speed = 0.0
	set_time(hour, fog, raining)
	_scenery.setup(stop == "camp", _night, worldgen)
	_scenery.advance(0.0, 0.0)
	_seat_passengers()
	_set_door(true)
	_cam.position = STAND_POS
	_cam.rotation = Transform3D(Basis(), STAND_POS).looking_at(STAND_LOOK, Vector3.UP).basis.get_euler()
	_cam_base = _cam.rotation
	_look = INTERIOR_LOOK.new(115.0, 26.0, 34.0)
	_ride.stream = _loop(load(SFX + "idle.mp3"))
	_ride.volume_db = -14.0
	_ride.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_say("", 0.0)


## Off the bus before it goes (S, the door, the bottom of the screen, the pause menu).
func leave() -> void:
	if _state != BOARDING:
		return
	_shut()
	left_bus.emit()


## The pause menu's way out while riding: there at once.
func close_interior() -> void:
	match _state:
		BOARDING:
			leave()
		SITTING, RIDING, STOPPING, DONE, HELD:
			_shut()
			arrived.emit()


func _shut() -> void:
	_state = CLOSED
	visible = false
	_glint.clear()
	_ride.stop()
	if _ticket_view != null and _ticket_view.visible:
		_ticket_view.close_view()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## The outside as it is in the game's world right now: its sky, sun, fog and light
## (copied from main.tscn's WorldEnvironment and Sun). Without them, by the hour.
func _copy_world_light() -> bool:
	var main := get_tree().current_scene
	var we := main.get_node_or_null("SubViewportContainer/SubViewport/World3D/WorldEnvironment") as WorldEnvironment if main != null else null
	var sun := main.get_node_or_null("SubViewportContainer/SubViewport/World3D/Sun") as DirectionalLight3D if main != null else null
	if we == null or we.environment == null or sun == null:
		return false
	var env := we.environment.duplicate() as Environment
	(_vp.get_node("BusEnv") as WorldEnvironment).environment = env
	_env = env
	_sun.light_color = sun.light_color
	_sun.light_energy = sun.light_energy
	_sun.global_transform = Transform3D(sun.global_transform.basis, Vector3.ZERO)
	_sun.visible = sun.visible
	return true


## The outside by the hour (and the weather): sky, sun, fog; the strip lights at night.
func set_time(hour: float, fog: float, raining: bool) -> void:
	if _env == null:
		return
	if _glass != null:
		_glass.set_shader_parameter("rain", 1.0 if raining else 0.0)
	var fill := _vp.get_node_or_null("CabinFill") as DirectionalLight3D
	if fill != null:
		fill.light_energy = 0.08 if (hour >= 20.3 or hour < 5.8) else 0.45
	if _copy_world_light():
		_night = hour >= 20.3 or hour < 5.8
		_strip_mat.emission = Color(1.0, 0.9, 0.7) * (1.6 if _night else 0.15)
		for l in _strip_lights:
			l.visible = _night
		if _scenery != null:
			_scenery.night = _night
		return
	_night = hour >= 20.3 or hour < 5.8
	var dusk := (hour >= 17.5 and hour < 20.3) or (hour >= 5.8 and hour < 7.5)
	var day_sky := Color(0.42, 0.56, 0.74)
	var day_hz := Color(0.76, 0.78, 0.76)
	if _night:
		_sky.sky_top_color = Color(0.02, 0.03, 0.06)
		_sky.sky_horizon_color = Color(0.05, 0.06, 0.09)
		_sun.light_energy = 0.08
		_sun.light_color = Color(0.6, 0.66, 0.9)
		_env.ambient_light_energy = 0.12
	elif dusk:
		_sky.sky_top_color = Color(0.3, 0.32, 0.5)
		_sky.sky_horizon_color = Color(0.92, 0.56, 0.32)
		_sun.light_energy = 0.7
		_sun.light_color = Color(1.0, 0.7, 0.45)
		_env.ambient_light_energy = 0.45
	else:
		_sky.sky_top_color = day_sky
		_sky.sky_horizon_color = day_hz
		_sun.light_energy = 1.05
		_sun.light_color = Color(1.0, 0.96, 0.86)
		_env.ambient_light_energy = 0.62
	if _glass != null:
		_glass.set_shader_parameter("rain", 1.0 if raining else 0.0)
	if raining and not _night:
		_sky.sky_top_color = _sky.sky_top_color.lerp(Color(0.5, 0.52, 0.54), 0.7)
		_sky.sky_horizon_color = _sky.sky_horizon_color.lerp(Color(0.6, 0.62, 0.62), 0.7)
		_sun.light_energy *= 0.5
	_sky.ground_horizon_color = _sky.sky_horizon_color
	_sky.ground_bottom_color = _sky.sky_horizon_color.darkened(0.5)
	# The sun's height from the hour (low in the morning and evening).
	var elev := clampf(sin((hour - 6.0) / 14.0 * PI), 0.08, 1.0) * 55.0
	_sun.rotation = Vector3(deg_to_rad(-elev), deg_to_rad(-40.0 + (hour - 12.0) * 12.0), 0)
	_env.fog_enabled = true
	_env.fog_light_color = _sky.sky_horizon_color
	_env.fog_density = 0.004 + fog * 0.03 + (0.006 if raining else 0.0) + (0.01 if _night else 0.0)
	_strip_mat.emission = Color(1.0, 0.9, 0.7) * (1.6 if _night else 0.15)
	for l in _strip_lights:
		l.visible = _night
	if _scenery != null:
		_scenery.night = _night


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _state == CLOSED:
		return
	_update_mate()
	if _state == HELD and _mate_ready(delta):
		_depart()
	_say_t -= delta
	if _say_label != null:
		_say_label.modulate.a = clampf(_say_t / 0.4, 0.0, 1.0)
	match _state:
		RIDING:
			var left: float = _scenery.route_length() - _scenery.travelled
			if left <= _speed * _speed / (2.0 * BRAKE) + 2.0:
				_state = STOPPING
				_play("brake_inside.mp3", -15.0)
			else:
				_speed = move_toward(_speed, CRUISE, ACCEL * delta)
		STOPPING:
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
			if _speed <= 0.05:
				_speed = 0.0
				_state = DONE
				_done_t = 0.0
				_set_door(true)
				_play("door_open.mp3", -2.0)
				_ride.stream = _loop(load(SFX + "idle.mp3"))
				_ride.volume_db = -14.0
				_ride.play()
		DONE:
			_done_t += delta
			if _done_t > 1.1:
				_shut()
				arrived.emit()
				return
	if _scenery != null and _speed > 0.0:
		_scenery.advance(_speed * delta, delta)
	if _state == RIDING or _state == STOPPING:
		_ride.volume_db = lerpf(-12.0, -4.0, clampf(_speed / CRUISE, 0.0, 1.0))
		_ride.pitch_scale = lerpf(0.85, 1.05, clampf(_speed / CRUISE, 0.0, 1.0))
	_update_bumps(delta)
	_update_swing(delta)
	if _glass != null:
		_glass.set_shader_parameter("t", floorf(Time.get_ticks_msec() / 83.0) * 0.083)
		_glass.set_shader_parameter("speed", clampf(_speed / CRUISE, 0.0, 1.0))
	if _ticket_view != null and _ticket_view.visible:
		return
	if _state == SITTING:
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_cam.rotation = _cam_base + offset
	_update_hover()
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self, "Get off   [S]")
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, _state == BOARDING)


## The road under the wheels: now and then a pothole jolts the view, in steps.
func _update_bumps(delta: float) -> void:
	_bump_t -= delta
	if _speed > 2.0 and _bump_t <= 0.0:
		_bump_t = _rng.randf_range(0.8, 3.0)
		_bump = _rng.randf_range(0.015, 0.04)
	_bump = maxf(0.0, _bump - delta * 0.12)
	var tick := floorf(Time.get_ticks_msec() / 83.0)
	var sway := 0.0
	if _speed > 1.0:
		sway = sin(tick * 0.37) * 0.006 * (_speed / CRUISE)
	if _state in [RIDING, STOPPING, DONE] and _seat >= 0:
		_cam.position = _seat_pos() + Vector3(sway, (_bump if int(tick) % 2 == 0 else -_bump * 0.5), 0)


func _update_hover() -> void:
	_hover = ""
	var hit := _raycast(get_viewport().get_mouse_position())
	var n = hit.get("collider", null)
	if n != null and (n as Node).has_meta("hot"):
		var id := str((n as Node).get_meta("hot"))
		if _hot_allowed(id):
			_hover = id
	if _hover != "":
		HandCursor.want(HandCursor.POINT)
		for h in _hot:
			if str(h["id"]) == _hover:
				_glint.show_on(h["meshes"])
	else:
		_glint.clear()
		if _state == BOARDING and INTERIOR_LOOK.in_exit_zone(get_viewport()):
			HandCursor.want(HandCursor.WALK)


func _hot_allowed(id: String) -> bool:
	if _state != BOARDING:
		return id == "driver"
	if id.begins_with("seat:"):
		return not _taken.has(int(id.get_slice(":", 1)))
	return true


func _raycast(mouse_pos: Vector2) -> Dictionary:
	if _cam == null or _vp == null:
		return {}
	var world := _vp.find_world_3d()
	var screen := get_viewport().get_visible_rect().size
	if world == null or screen.x <= 0.0:
		return {}
	var local := Vector2(clampf(mouse_pos.x / screen.x, 0.0, 1.0) * float(_vp.size.x), clampf(mouse_pos.y / screen.y, 0.0, 1.0) * float(_vp.size.y))
	var o := _cam.project_ray_origin(local)
	var d := _cam.project_ray_normal(local)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 12.0)
	return world.direct_space_state.intersect_ray(q)


func _input(event: InputEvent) -> void:
	if _state == CLOSED or get_tree().paused:
		return
	if _ticket_view != null and _ticket_view.visible:
		return
	if _state == BOARDING and INTERIOR_LOOK.is_exit_event(event, get_viewport()) and _hover == "":
		leave()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover != "":
		_click(_hover)
		get_viewport().set_input_as_handled()


func _click(id: String) -> void:
	if id == "machine":
		_open_machine()
	elif id == "driver":
		var lines: Array = (DRIVER_NIGHT if _night and _rng.randf() < 0.5 else DRIVER_LINES.get(stop, DRIVER_LINES["camp"]))
		_say("Driver: \"%s\"" % str(lines[_rng.randi() % lines.size()]), 3.5)
	elif id == "door":
		leave()
	elif id.begins_with("seat:"):
		_try_sit(int(id.get_slice(":", 1)))


# ── the ticket, the seat, the ride ───────────────────────────────────────────

func _open_machine() -> void:
	if _ticket_view == null:
		_ticket_view = TICKET.new()
		add_child(_ticket_view)
		_ticket_view.ticket_taken.connect(func(t: Dictionary):
			_ticket = t
			_ticket_card.visible = true
			_ticket_card.queue_redraw()
			# Ticket in hand: the machine is done with, back to the bus.
			get_tree().create_timer(0.8).timeout.connect(func():
				if _ticket_view.visible:
					_ticket_view.close_view()
			)
		)
	_ticket_view.stop = stop
	_glint.clear()
	_ticket_view.open_view()


## Where this bus goes, and whether `t` gets you there.
func _ticket_problem(t: Dictionary) -> String:
	if t.is_empty():
		return "Ticket. From the machine."
	var goes_to := "LESNA" if stop == "camp" else "KEMP"
	var to := str(t.get("to", ""))
	if str(t.get("kind", "")) == "half":
		return "Half fare? How old are you? Get a proper one."
	if to in ["DOG", "BAG"]:
		return "That's for a dog. You're not a dog. Are you?"
	if to == goes_to or to == "HLUBOCANY":
		return ""
	return "That's for the dam. This goes to %s." % ("Lesna" if goes_to == "LESNA" else "the camp")


func _try_sit(i: int) -> void:
	var problem := _ticket_problem(_ticket)
	if problem != "":
		_say("Driver: \"%s\"" % problem, 3.5)
		return
	var m := _mate_info()
	if _mate_aboard() and int(m.get("s", -1)) == i:
		_say("Driver: \"That one's taken. Look.\"", 3.0)
		return
	_seat = i
	_state = SITTING
	_glint.clear()
	var pos := _seat_pos()
	var face := pos + Vector3(1.3 if SEATS[i].x > 0.0 else -1.3, -0.1, -1.3)
	var rot := Transform3D(Basis(), pos).looking_at(face, Vector3.UP).basis.get_euler()
	CAM_MOVE.move(self, _cam, {"position": pos, "rotation": rot}, 0.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_play("door_close.mp3", -2.0)
	get_tree().create_timer(0.75).timeout.connect(func():
		if _state != SITTING:
			return
		_cam_base = rot
		_look = INTERIOR_LOOK.new(120.0, 24.0, 30.0)
		# Co-op: sat down, the bus waits for the other warden (_mate_ready).
		_state = HELD
	)


## The doors shut and it goes.
func _depart() -> void:
	_set_door(false)
	_state = RIDING
	_play("start_inside.mp3", -2.0)
	_ride.stream = _loop(load(SFX + "ride.mp3"))
	_ride.volume_db = -12.0
	_ride.play()


## Co-op: may it go? The other warden on board: once they sit (or it went for them).
## Near the stop outside: a moment for them. Elsewhere, or alone: at once.
func _mate_ready(delta: float) -> bool:
	if not Coop.has_partner():
		return true
	var m := _mate_info()
	if not m.is_empty() and str(m.get("st", "")) == stop:
		if int(m.get("s", -1)) >= 0 or bool(m.get("go", false)):
			return true
		_driver_waits()
		return false
	var p: Vector3 = Coop.partner_state.get("p", Vector3.INF)
	var near := stop_pos != Vector3.INF and p != Vector3.INF and not bool(Coop.partner_state.get("in", false)) \
		and Vector2(p.x - stop_pos.x, p.z - stop_pos.z).length() < 30.0
	if near and _mate_wait < MATE_WAIT:
		_mate_wait += delta
		_driver_waits()
		return false
	return true


func _driver_waits() -> void:
	if _mate_said:
		return
	_mate_said = true
	_say("Driver: \"Your mate coming or what?\"", 3.5)


## The other warden on this bus: standing by the door till they sit, then in their seat,
## seen from the front or (you behind them) from the back.
func _update_mate() -> void:
	var m := _mate_info()
	# On the same run: both still at the stop, or both gone.
	var here := not m.is_empty() and str(m.get("st", "")) == stop and bool(m.get("go", false)) == (_state in [RIDING, STOPPING, DONE])
	if not here:
		if _mate != null:
			_mate.visible = false
		return
	if _mate == null:
		_mate = Sprite3D.new()
		_mate.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_mate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mate.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_mate.shaded = true
		_mate.layers = 2
		_vp.add_child(_mate)
		_mate_pose = ""
	var seat := int(m.get("s", -1))
	var pos := Vector3(0.25, 0.0, -2.95)
	var pose := "stand"
	if seat >= 0 and seat < SEATS.size():
		var sv: Vector2 = SEATS[seat]
		pos = Vector3(sv.x, 0.0, sv.y)
		# The bus faces -z: sat behind them you see their back.
		pose = "desk" if _cam.position.z > sv.y + 0.2 else "sit"
	var look: Dictionary = Coop.partner_look
	var key := "%s|%d|%d" % [pose, int(look.get("m", 1)), int(look.get("c", 0))]
	if key != _mate_pose:
		_mate_pose = key
		var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), pose)
		_mate.texture = tex
		if tex != null:
			var tall := 1.62 if pose == "stand" else 1.25
			_mate.pixel_size = tall / float(tex.get_height())
			_mate.offset = Vector2(0.0, tex.get_height() * 0.5)
	_mate.position = pos
	_mate.visible = true


func _seat_pos() -> Vector3:
	if _seat < 0:
		return STAND_POS
	var s: Vector2 = SEATS[_seat]
	return Vector3(s.x * 1.12, 1.3, s.y + 0.05)


func _say(text: String, seconds: float) -> void:
	if _say_label == null:
		return
	_say_label.text = text
	_say_t = seconds


func _play(file: String, db: float) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


func _loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


## A few people already on board: sitting, facing the way the bus goes. The camp's own
## guests out for the day (gone "away") ride it too. The same people for both wardens:
## the dice are the run's (stop, day, hour).
func _seat_passengers() -> void:
	for p in _passengers:
		p.queue_free()
	_passengers.clear()
	_taken.clear()
	var day := int(CoreRoot.get_day()) if CoreRoot != null else 1
	_rng.seed = hash("%s|%d|%d" % [stop, day, int(floorf(_hour_now * 2.0))])
	var sprites := ["host1_sit.png", "host2_sit.png", "host3_sit.png", "host_family_sit.png"]
	var riders: Array = []
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			var act: Dictionary = g.get("activity", {})
			if str(act.get("kind", "")) == "away":
				var sit := str(g.get("sprite_path", "")).replace(".png", "_sit.png")
				if ResourceLoader.exists(sit):
					riders.append(sit)
	var n := _rng.randi_range(0, 1) if _night else _rng.randi_range(1, 4)
	for k in n + riders.size():
		var i := _rng.randi() % SEATS.size()
		if _taken.has(i):
			continue
		_taken[i] = true
		var path: String = str(riders[k]) if k < riders.size() else NPC + str(sprites[_rng.randi() % sprites.size()])
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite3D.new()
		s.texture = load(path)
		s.pixel_size = 0.0125
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = true
		s.layers = 2
		var seat: Vector2 = SEATS[i]
		s.position = Vector3(seat.x, 0.62, seat.y)
		_vp.add_child(s)
		_passengers.append(s)


# ── the bus inside ───────────────────────────────────────────────────────────

func _mat(key: String, path: String, tint: Color, uv: Vector2 = Vector2.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_color = tint
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	_mats[key] = m
	return m


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _quad(parent: Node, pos: Vector3, size: Vector2, rot_y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _hot_body(parent: Node, id: String, pos: Vector3, size: Vector3, meshes: Array) -> void:
	var body := StaticBody3D.new()
	body.set_meta("hot", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	_hot.append({"id": id, "body": body, "meshes": meshes})


func _build() -> void:
	_container = SubViewportContainer.new()
	_container.name = "BusViewportContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	RETRO_RENDER.register(_container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	_container.add_child(_vp)
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.8, 0.8, 0.78)
	_env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.name = "BusEnv"
	we.environment = _env
	_vp.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	_vp.add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 420.0
	_vp.add_child(_cam)
	_cam.current = true
	_scenery = SCENERY.new()
	_vp.add_child(_scenery)
	_build_cabin()
	# Inside is lit by the bus, not the sun: the cabin on layer 2, the sun on layer 1
	# only, a dim fill for the cabin by day (the strip lights at night).
	_sun.light_cull_mask = 1
	for n in _vp.get_node("Cabin").find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).layers = 2
	var fill := DirectionalLight3D.new()
	fill.name = "CabinFill"
	fill.light_cull_mask = 2
	fill.light_energy = 0.45
	fill.light_color = Color(0.92, 0.94, 1.0)
	fill.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(20.0), 0)
	_vp.add_child(fill)
	_ride = AudioStreamPlayer.new()
	add_child(_ride)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	# What is said (the driver), along the bottom.
	_say_label = Label.new()
	_say_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_say_label.position.y -= 90
	_say_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_label.add_theme_font_override("font", RETRO_UI.FONT_TEXT)
	_say_label.add_theme_font_size_override("font_size", 24)
	_say_label.add_theme_color_override("font_color", RETRO_UI.C_BONE)
	_say_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_say_label.add_theme_constant_override("shadow_offset_x", 2)
	_say_label.add_theme_constant_override("shadow_offset_y", 2)
	_say_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_say_label)
	# The ticket in your hand, bottom left, once you have one.
	_ticket_card = Control.new()
	_ticket_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticket_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ticket_card.size = Vector2(150, 70)
	_ticket_card.position = Vector2(40, -120)
	_ticket_card.rotation = deg_to_rad(-7.0)
	_ticket_card.visible = false
	_ticket_card.draw.connect(_draw_ticket_card)
	add_child(_ticket_card)


func _draw_ticket_card() -> void:
	var c := _ticket_card
	c.draw_rect(Rect2(4, 6, 140, 60), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(0, 0, 140, 60), Color(0.9, 0.88, 0.8))
	c.draw_rect(Rect2(0, 0, 140, 3), Color(0.72, 0.7, 0.62))
	var f: Font = RETRO_UI.FONT_TEXT
	var ink := Color(0.2, 0.2, 0.5)
	c.draw_string(f, Vector2(8, 18), "CSAD  380", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	c.draw_string(f, Vector2(8, 36), "%s - %s" % ["KEMP" if stop == "camp" else "LESNA", str(_ticket.get("to", ""))], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	c.draw_string(f, Vector2(8, 52), "$%d" % int(_ticket.get("price", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)


func _build_cabin() -> void:
	var cabin := Node3D.new()
	cabin.name = "Cabin"
	_vp.add_child(cabin)
	var wall := _mat("wall", TEX + "bus_wall.png", Color(0.86, 0.82, 0.7), Vector2(4.0, 1.0))
	var pillar := _mat("pillar", "", Color(0.78, 0.74, 0.62))
	var chrome := _mat("chrome", "", Color(0.72, 0.74, 0.76))
	var length := FLOOR_Z.y - FLOOR_Z.x
	var mid := (FLOOR_Z.x + FLOOR_Z.y) * 0.5
	_box(cabin, Vector3(0, -0.04, mid), Vector3(HALF_W * 2.0, 0.08, length), _mat("floor", TEX + "bus_floor.png", Color(0.5, 0.5, 0.5), Vector2(2.0, 8.0)))
	_box(cabin, Vector3(0, 2.14, mid), Vector3(HALF_W * 2.0, 0.08, length), _mat("ceiling", TEX + "bus_ceiling.png", Color(0.9, 0.88, 0.8), Vector2(2.0, 8.0)))
	# The strip lights along the ceiling.
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.albedo_color = Color(0.95, 0.92, 0.8)
	_strip_mat.emission_enabled = true
	for x in [-0.5, 0.5]:
		_box(cabin, Vector3(x, 2.08, mid), Vector3(0.12, 0.04, length - 1.0), _strip_mat)
	for z in [-3.0, 0.5, 3.6]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.9, 0.72)
		l.light_energy = 1.1
		l.omni_range = 4.5
		l.position = Vector3(0, 1.9, z)
		l.visible = false
		cabin.add_child(l)
		_strip_lights.append(l)
	# The sides: a panel under the windows, pillars, a strip above; the windows open.
	for side in [-1.0, 1.0]:
		var x: float = side * HALF_W
		_box(cabin, Vector3(x, 0.47, mid), Vector3(0.06, 0.94, length), wall)
		_box(cabin, Vector3(x, 1.95, mid), Vector3(0.06, 0.38, length), wall)
		var z := FLOOR_Z.x + 0.2
		while z < FLOOR_Z.y:
			_box(cabin, Vector3(x, 1.35, z), Vector3(0.07, 0.86, 0.09), pillar)
			z += 1.18
		# A faint pane: dirt and a little light on the glass.
		_quad(cabin, Vector3(x - side * 0.01, 1.35, mid), Vector2(length, 0.84), side * PI * 0.5, _glass_material())
	# The front door: no panel under the windows there, two leaves that fold.
	var door_mat := _mat("door", "", Color(0.55, 0.18, 0.13))
	for i in 2:
		var leaf := _box(cabin, Vector3(HALF_W - 0.02, 1.15, -3.75 + i * 0.37), Vector3(0.05, 2.0, 0.36), door_mat)
		_door_leaves.append(leaf)
	_hot_body(cabin, "door", Vector3(HALF_W, 1.1, -3.57), Vector3(0.3, 2.0, 0.8), _door_leaves.duplicate())
	# The rear: a wall with a small window and the long bench.
	_box(cabin, Vector3(0, 0.6, FLOOR_Z.y), Vector3(HALF_W * 2.0, 1.2, 0.06), wall)
	_box(cabin, Vector3(0, 1.85, FLOOR_Z.y), Vector3(HALF_W * 2.0, 0.6, 0.06), wall)
	for x in [-0.9, 0.9]:
		_box(cabin, Vector3(x, 1.35, FLOOR_Z.y), Vector3(0.5, 0.5, 0.06), wall)
	# The front: dashboard under the windscreen, the destination box over it.
	_box(cabin, Vector3(0, 0.55, FLOOR_Z.x), Vector3(HALF_W * 2.0, 1.1, 0.08), _mat("front", "", Color(0.3, 0.3, 0.3)))
	_box(cabin, Vector3(0, 1.0, FLOOR_Z.x + 0.3), Vector3(HALF_W * 2.0, 0.12, 0.6), _mat("dash", "", Color(0.18, 0.18, 0.2)))
	_box(cabin, Vector3(0, 2.0, FLOOR_Z.x + 0.05), Vector3(HALF_W * 2.0, 0.3, 0.12), _mat("board", "", Color(0.1, 0.1, 0.1)))
	# Seats: a cushion, a backrest with its vinyl and a chrome grip.
	var vinyl := _mat("seat", TEX + "bus_seat.png", Color(0.7, 0.42, 0.22))
	var cushion := _mat("cushion", "", Color(0.48, 0.28, 0.16))
	for i in SEATS.size():
		var s: Vector2 = SEATS[i]
		var seat := Node3D.new()
		seat.position = Vector3(s.x, 0, s.y)
		cabin.add_child(seat)
		var parts: Array = []
		parts.append(_box(seat, Vector3(0, 0.46, 0), Vector3(0.84, 0.1, 0.44), cushion))
		parts.append(_box(seat, Vector3(0, 0.78, 0.22), Vector3(0.84, 0.56, 0.06), cushion))
		parts.append(_quad(seat, Vector3(0, 0.78, 0.26), Vector2(0.84, 0.56), 0.0, vinyl))
		parts.append(_quad(seat, Vector3(0, 0.78, 0.18), Vector2(0.84, 0.56), PI, vinyl))
		_box(seat, Vector3(0, 1.09, 0.22), Vector3(0.7, 0.04, 0.04), chrome)
		_box(seat, Vector3(-s.x * 0.45, 0.2, 0), Vector3(0.06, 0.4, 0.06), chrome)
		_hot_body(seat, "seat:%d" % i, Vector3(0, 0.7, 0.05), Vector3(0.84, 0.8, 0.5), parts)
	# Poles and the ticket machine on the one by the door.
	for z in [-2.95, 0.65, 2.45]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 2.1
		cyl.radial_segments = 6
		pole.mesh = cyl
		pole.material_override = chrome
		pole.position = Vector3(0.12, 1.05, z)
		cabin.add_child(pole)
	var machine := Node3D.new()
	machine.position = Vector3(0.12, 1.32, -2.95)
	cabin.add_child(machine)
	var shell := _box(machine, Vector3(0.0, 0, 0), Vector3(0.18, 0.36, 0.26), _mat("machine_body", "", Color(0.78, 0.36, 0.14)))
	var face := _quad(machine, Vector3(0.091, 0, 0), Vector2(0.26, 0.36), PI * 0.5, _mat("machine", TEX + "ticket_machine.png", Color(0.9, 0.5, 0.2)))
	_hot_body(machine, "machine", Vector3.ZERO, Vector3(0.3, 0.45, 0.34), [shell, face])
	# The driver: in his seat front left, cap, shirt, hands on the wheel.
	var driver := Node3D.new()
	driver.position = Vector3(-0.62, 0, -4.2)
	cabin.add_child(driver)
	var shirt := _mat("shirt", "", Color(0.26, 0.32, 0.42))
	var skin := _mat("skin", "", Color(0.78, 0.6, 0.48))
	var parts_d: Array = []
	parts_d.append(_box(driver, Vector3(0, 0.95, 0.05), Vector3(0.48, 0.62, 0.3), shirt))
	parts_d.append(_box(driver, Vector3(0, 1.42, 0.02), Vector3(0.22, 0.26, 0.24), skin))
	parts_d.append(_box(driver, Vector3(0, 1.58, 0.0), Vector3(0.26, 0.08, 0.3), _mat("cap", "", Color(0.2, 0.22, 0.26))))
	_box(driver, Vector3(0, 0.5, 0.15), Vector3(0.5, 0.12, 0.5), cushion)
	_box(driver, Vector3(0, 0.95, 0.36), Vector3(0.5, 0.7, 0.08), cushion)
	var wheel := MeshInstance3D.new()
	var wcyl := CylinderMesh.new()
	wcyl.top_radius = 0.22
	wcyl.bottom_radius = 0.22
	wcyl.height = 0.03
	wcyl.radial_segments = 10
	wheel.mesh = wcyl
	wheel.material_override = _mat("wheel", "", Color(0.08, 0.08, 0.08))
	wheel.position = Vector3(0, 1.05, -0.38)
	wheel.rotation.x = deg_to_rad(60.0)
	driver.add_child(wheel)
	_hot_body(driver, "driver", Vector3(0, 1.1, 0), Vector3(0.6, 1.0, 0.5), parts_d)
	_dress_cabin(cabin, driver, parts_d)


## The Karosa as it was on the 380 (playtest 17. 10.: "polish the inside of the bus"):
## the dashboard with its dials, the driver from behind at his wheel (a Grok sprite in
## place of the boxes), the doors' glass leaves, short pleated curtains at the windows
## and a little bear and a pine tree swinging under the mirror (both swing with the
## bus), luggage nets, red STOP buttons on the poles, no-smoking stickers, sunflower
## shells and old tickets on the floor.
func _dress_cabin(cabin: Node3D, driver: Node3D, driver_parts: Array) -> void:
	var dash_t := _town_tex("bus_dash")
	if dash_t != null:
		var dash := _quad(cabin, Vector3(-0.55, 1.12, FLOOR_Z.x + 0.42), Vector2(1.2, 0.68), 0.0, _tex_mat(dash_t, false))
		dash.rotation.x = deg_to_rad(-58.0)
	var drv := _town_tex("bus_driver_back")
	if drv != null:
		for part in driver_parts:
			(part as Node3D).visible = false
		var h := 1.3
		var q := _quad(driver, Vector3(0.0, 0.42 + h * 0.5, 0.18), Vector2(h * float(drv.get_width()) / float(drv.get_height()), h), 0.0, _tex_mat(drv, true))
		q.name = "DriverBack"
		driver_parts.append(q)
	var door_t := _town_tex("bus_door_in")
	if door_t != null:
		for leaf in _door_leaves:
			var f := _quad(leaf, Vector3(-0.03, 0.0, 0.0), Vector2(0.36, 2.0), -PI * 0.5, _tex_mat(door_t, false))
			f.name = "DoorGlass"
	# Curtains bunched at the pillars, both sides.
	var cur := _town_tex("bus_curtain")
	if cur != null:
		var cm := _tex_mat(cur, false)
		cm.uv1_scale = Vector3(1.0, 1.0, 1.0)
		for side in [-1.0, 1.0]:
			var z := FLOOR_Z.x + 0.2
			while z < FLOOR_Z.y:
				if absf(z - (-3.57)) > 0.5 or side < 0.0:
					var pivot := Node3D.new()
					pivot.position = Vector3(side * (HALF_W - 0.06), 1.74, z + 0.13)
					cabin.add_child(pivot)
					var c := _quad(pivot, Vector3(0, -0.3, 0), Vector2(0.2, 0.6), side * PI * 0.5, cm)
					c.name = "Curtain"
					_swingers.append({"node": pivot, "k": 0.35})
				z += 1.18
	# The bear and the tree under the mirror.
	var mascot := _town_tex("bus_mascot")
	if mascot != null:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.15, 1.92, FLOOR_Z.x + 0.32)
		cabin.add_child(pivot)
		_box(pivot, Vector3(0, -0.06, 0), Vector3(0.005, 0.12, 0.005), _mat("string", "", Color(0.2, 0.2, 0.2)))
		var m := _quad(pivot, Vector3(0, -0.24, 0), Vector2(0.2 * float(mascot.get_width()) / float(mascot.get_height()), 0.2), 0.0, _tex_mat(mascot, true))
		m.name = "Mascot"
		_swingers.append({"node": pivot, "k": 1.0})
	# Luggage nets over the seats.
	var rack := _town_tex("bus_rack")
	if rack != null:
		for side in [-1.0, 1.0]:
			var rq := _quad(cabin, Vector3(side * (HALF_W - 0.2), 1.86, (FLOOR_Z.x + FLOOR_Z.y) * 0.5 + 0.8), Vector2(7.6, 0.36), side * PI * 0.5, _tex_mat(rack, true))
			rq.rotation.z = side * deg_to_rad(70.0)
			rq.name = "LuggageNet"
	# STOP buttons on the poles, the stickers.
	var red := _mat("stop_btn", "", Color(0.85, 0.12, 0.1))
	red.emission_enabled = true
	red.emission = Color(0.6, 0.05, 0.03)
	for z in [-2.95, 0.65, 2.45]:
		_box(cabin, Vector3(0.12, 1.42, z + 0.03), Vector3(0.07, 0.05, 0.07), red)
	var ns := _town_tex("no_smoking")
	if ns != null:
		_quad(cabin, Vector3(0.6, 1.98, FLOOR_Z.x + 0.12), Vector2(0.16, 0.16), 0.0, _tex_mat(ns, true))
		_quad(cabin, Vector3(0.0, 1.95, FLOOR_Z.y - 0.04), Vector2(0.16, 0.16), PI, _tex_mat(ns, true))
	var lit := _town_tex("bus_litter")
	if lit != null:
		for z in [-1.2, 1.5, 3.3]:
			var dq := _quad(cabin, Vector3(randf_range(-0.2, 0.25), 0.006, z), Vector2(0.45, 0.45), 0.0, _tex_mat(lit, true))
			dq.rotation.x = -PI * 0.5
			dq.rotation.z = randf() * TAU


func _town_tex(name: String) -> Texture2D:
	var p := TEX + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _tex_mat(t: Texture2D, cut: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Speeding up throws what hangs back, braking forward; it settles. Drawn in steps.
func _update_swing(delta: float) -> void:
	if _swingers.is_empty() or delta <= 0.0:
		return
	var accel := (_speed - _speed_prev) / delta
	_speed_prev = _speed
	_swing_v += (-_swing * 14.0 - _swing_v * 1.4 + accel * 0.05) * delta
	_swing += _swing_v * delta
	_swing_acc += delta
	if _swing_acc < 1.0 / 12.0:
		return
	_swing_acc = 0.0
	var wob := sin(Time.get_ticks_msec() * 0.004) * 0.02 * clampf(_speed / CRUISE, 0.0, 1.0)
	for sw in _swingers:
		var n: Node3D = sw["node"]
		if is_instance_valid(n):
			n.rotation.x = clampf((_swing + wob) * float(sw["k"]), -0.6, 0.6)


func _set_door(open: bool) -> void:
	for i in _door_leaves.size():
		var leaf := _door_leaves[i]
		leaf.scale.z = 0.25 if open else 1.0
		leaf.position.z = (-3.92 + i * 0.7) if open else (-3.75 + i * 0.37)
