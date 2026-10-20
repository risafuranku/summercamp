extends Node

## Your two hands, for everything drawn in them (scripts/ui/torch_hand.gd, work_hand.gd,
## scripts/town/pockets.gd): one place that says
##   - how big their pixels are: all hands are drawn for a Build-engine screen of
##     VIRTUAL_LINES lines and scaled up by whole numbers (assets/textury/hands_lo/), so a
##     hand's pixels are as coarse as the world's;
##   - how they are lit: like a sprite in a Build sector, from the place you stand in (the
##     sky by the hour and the weather, a lamp post near you, the room's light or its
##     dark, your own torch's spill, the lighter's flame, the ember on a drag), in shade
##     steps, never brighter than the place;
##   - which hand holds what: the right hand has the torch unless it works (a tool, the
##     rubbish bag) or holds a bottle; then the torch goes to the left hand, and the
##     cigarette from the left hand into your mouth. A thing that wants a hand claims it
##     (claim / release) and asks who has it (owner).
## Made by the first one who asks (Hands.of(node)); in group "hands".

const VIRTUAL_LINES := 200.0
## Shade steps of the light on the hands (a Build palette's shade ramp has 32; the hands
## read better with fewer).
const SHADES := 16.0
## Priorities: the higher keeps the hand.
const PRIO := {"work": 3, "bottle": 2, "lighter": 2, "torch": 1, "cig": 1, "radio": 2, "megaphone": 2}

## The colour the hands are drawn with this frame (white = full daylight), in shade steps.
var light := Color.WHITE
## The same before the steps (the shader dithers between them).
var light_raw := Color.WHITE
## One material for everything drawn in your hands: the place's light, stepped and
## dithered, 15-bit colour (Build x PS1). Its "light" is set every frame.
var material: ShaderMaterial = _make_material()


static func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/hand_ps1.gdshader")
	m.set_shader_parameter("shades", SHADES)
	return m
## The flicker of the light that is in your hand (lighter, ember) for the drawing.
var _target := Color.WHITE
var _claims := {"right": {}, "left": {}}
var _glows: Dictionary = {}        # key -> {c: Color, until: msec}
var _lamps: Array = []
var _lamp_t := 0.0
var _t := 0.0


static var _one: Node


static func of(n: Node) -> Node:
	if _one != null and is_instance_valid(_one):
		return _one
	if n == null or not n.is_inside_tree():
		return null
	_one = load("res://scripts/ui/hands.gd").new()
	_one.name = "Hands"
	_one.add_to_group("hands")
	n.get_tree().root.add_child.call_deferred(_one)
	return _one


## Sprite pixels to screen pixels for a view `h` pixels high.
static func px(h: float) -> float:
	return float(maxi(1, int(round(h / VIRTUAL_LINES))))


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -10


# ── who holds what ───────────────────────────────────────────────────────────

## `who` is a kind ("torch", "work", "bottle", "cig", "lighter"), with "#<id>" after it
## when there can be more than one of it (a room's torch and the camp's).
func claim(hand: String, who: String) -> void:
	_claims[hand][who] = int(PRIO.get(who.get_slice("#", 0), 1))


func release(hand: String, who: String) -> void:
	_claims[hand].erase(who)


## What has `hand` now (its kind, "" free).
func owner(hand: String) -> String:
	return _owner(hand).get_slice("#", 0)


func _owner(hand: String) -> String:
	var best := ""
	var bp := -1
	for who in _claims[hand].keys():
		if int(_claims[hand][who]) > bp:
			bp = int(_claims[hand][who])
			best = who
	return best


## The torch's hand: "right", "left" when the right is busy and the left is not taken
## by something that outranks a cigarette, or "" (in your pocket).
func torch_hand() -> String:
	var r := owner("right")
	if r == "" or r == "torch":
		return "right"
	var l := owner("left")
	if l == "" or l == "cig" or l == "torch":
		return "left"
	return ""


## Is the cigarette in your fingers, or in your mouth because the left hand holds the torch.
func cig_in_mouth() -> bool:
	if torch_hand() != "left":
		return false
	for who in _claims["right"].keys():
		if str(who).begins_with("torch"):
			return true
	return false


# ── the light ────────────────────────────────────────────────────────────────

## A light in or by your hand for this frame and a little after: the lighter's flame, the
## ember on a drag (orange), a match.
func glow(key: String, c: Color) -> void:
	_glows[key] = {"c": c, "until": Time.get_ticks_msec() + 120}


## How the hands move with you, in sprite pixels (add it to where a hand is drawn): they
## trail a turn of the head and swing back past it (inertia), breathe when you stand,
## dip when you land from a jump.
var motion := Vector2.ZERO
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _last_look := Vector2.INF
var _land := 0.0
var _was_floor := true
var _fall_v := 0.0


func _move(delta: float) -> void:
	var main := get_tree().current_scene
	var p = main.get("_player") if main != null else null
	if p == null or delta <= 0.0:
		motion = Vector2.ZERO
		return
	var cam = p.get("_camera")
	var look := Vector2(float(p.rotation.y), float((cam as Node3D).global_rotation.x) if cam is Node3D else 0.0)
	if _last_look == Vector2.INF:
		_last_look = look
	var d := look - _last_look
	d.x = wrapf(d.x, -PI, PI)
	_last_look = look
	# A spring: the turn pushes the hands the other way, they swing back and a little past.
	_sway_v += Vector2(d.x * 900.0, -d.y * 700.0)
	_sway_v += (-_sway * 120.0 - _sway_v * 14.0) * delta
	_sway += _sway_v * delta
	_sway = _sway.clamp(Vector2(-22, -14), Vector2(22, 14))
	var on_floor: bool = p.is_on_floor() if p.has_method("is_on_floor") else true
	var v: Vector3 = p.get("velocity")
	if not on_floor:
		_fall_v = minf(_fall_v, v.y)
	elif not _was_floor:
		# Landed: the harder the fall, the deeper the dip.
		_land = clampf(-_fall_v * 1.6, 3.0, 12.0)
		_fall_v = 0.0
	_was_floor = on_floor
	_land = move_toward(_land, 0.0, delta * 30.0)
	var still := Vector2(v.x, v.z).length() < 0.3
	var breath := sin(_t * 1.7) * (1.2 if still else 0.4)
	motion = Vector2(round(_sway.x), round(_sway.y + breath + _land))


func _process(delta: float) -> void:
	_t += delta
	_move(delta)
	_lamp_t -= delta
	if _lamp_t <= 0.0:
		_lamp_t = 1.0
		_lamps = get_tree().get_nodes_in_group("lamp_posts")
	_pocket_torch()
	_target = _measure()
	# The eye takes a moment, in steps (no smooth fade): towards it, a shade at a time.
	var k := clampf(delta * 7.0, 0.0, 1.0)
	light_raw = light_raw.lerp(_target, k)
	light = Color(_shade(light_raw.r), _shade(light_raw.g), _shade(light_raw.b), 1.0)
	# The hands' shader does the stepping itself, dithered (materials/hand_ps1.gdshader).
	material.set_shader_parameter("light", Color(maxf(light_raw.r, 0.06), maxf(light_raw.g, 0.06), maxf(light_raw.b, 0.06), 1.0))


## Both hands taken by things that outrank the torch: it goes in your pocket (dark) till
## a hand is free (player_controller.hand_busy).
func _pocket_torch() -> void:
	var main := get_tree().current_scene
	var p = main.get("_player") if main != null else null
	if p == null or not ("hand_busy" in p):
		return
	var busy := torch_hand() == ""
	if bool(p.get("hand_busy")) != busy:
		p.set("hand_busy", busy)
		if p.has_method("_refresh_flashlight_state"):
			p.call("_refresh_flashlight_state")


func _shade(v: float) -> float:
	return clampf(round(v * SHADES) / SHADES, 0.06, 1.0)


func _measure() -> Color:
	var main := get_tree().current_scene
	if main == null or main.get("_player") == null:
		return Color.WHITE
	var c := Color.BLACK
	var room := _open_room(main)
	if room != null:
		# A room: lit (its lamp or the day through the window), or dark.
		var dark := room.has_method("room_is_dark") and bool(room.call("room_is_dark"))
		c = Color(0.1, 0.1, 0.12) if dark else Color(0.92, 0.88, 0.8)
	else:
		c = _sky(main) + _lamp_light(main)
	# Your own torch: the hands are just behind its beam and catch its spill.
	var p = main.get("_player")
	if p != null and p.has_method("is_flashlight_active") and bool(p.is_flashlight_active()):
		c += Color(0.2, 0.19, 0.16)
	var now := Time.get_ticks_msec()
	for key in _glows.keys():
		var g: Dictionary = _glows[key]
		if int(g["until"]) < now:
			_glows.erase(key)
			continue
		c += g["c"]
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 1.0)


## Outdoors: the ambient and the sun as main's weather has them now.
func _sky(main: Node) -> Color:
	var we = main.get("world_environment")
	var sun = main.get("sun")
	var c := Color(0.08, 0.08, 0.1)
	if we != null and (we as WorldEnvironment).environment != null:
		var env: Environment = (we as WorldEnvironment).environment
		c += env.ambient_light_color * env.ambient_light_energy * 0.52
	if sun != null and (sun as DirectionalLight3D).visible:
		var s := sun as DirectionalLight3D
		var up := clampf(-s.global_basis.z.y, 0.0, 1.0)
		c += s.light_color * s.light_energy * (0.25 + up * 0.35)
	return c


## A lamp post's light where you stand (its pool on the ground, its glow).
func _lamp_light(main: Node) -> Color:
	var p = main.get("_player") as Node3D
	if p == null:
		return Color.BLACK
	var c := Color.BLACK
	for lamp in _lamps:
		if lamp == null or not is_instance_valid(lamp):
			continue
		var d := (lamp as Node3D).global_position.distance_to(p.global_position)
		if d > 14.0:
			continue
		for ch in (lamp as Node).find_children("*", "Light3D", true, false):
			var l := ch as Light3D
			if not l.visible or l.light_energy <= 0.01:
				continue
			var rng := 8.0
			if l is OmniLight3D:
				rng = (l as OmniLight3D).omni_range
			elif l is SpotLight3D:
				rng = (l as SpotLight3D).spot_range
			var dl := l.global_position.distance_to(p.global_position + Vector3.UP * 1.2)
			var f := clampf(1.0 - dl / maxf(rng, 0.1), 0.0, 1.0)
			c += l.light_color * l.light_energy * f * f * 0.14
	return c


func _open_room(main: Node) -> Node:
	if not (main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))):
		return null
	var im = main.get("_interior_manager")
	if im != null and im.has_method("_get_registered_interior_nodes"):
		for r in im._get_registered_interior_nodes():
			if r is CanvasLayer and (r as CanvasLayer).visible:
				return r
	return null
