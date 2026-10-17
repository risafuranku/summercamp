extends Node

## Your torch in a dark room at night (the lights off, the camp's power out, a tent): it
## is on in here if it is on outside (F works in here too), and its beam goes where the
## cursor points, a beat behind it, narrow and weak, so the corners stay dark. The hand
## holding it (torch_hand.gd) is at the bottom right of the view, turned toward where you
## shine. Each room (cabin, tent, services, reception) owns one and calls update() every
## frame it is open; when the calls stop (the room closed) it goes out by itself.

const TORCH_HAND = preload("res://scripts/ui/torch_hand.gd")
const FOLLOW := 9.0
const ENERGY := 1.9
const HALO_ENERGY := 0.3

var _camera: Camera3D
var _viewport: SubViewport
var _spot: SpotLight3D
var _halo: SpotLight3D
var _hand: CanvasLayer
var _q := Quaternion.IDENTITY
var _ready_q := false
var _on := false
var _t := 0.0
var _frame := -10


## `root`: a node in the room's own 3D world (the lights live there); `layer`: the room's
## CanvasLayer index (the hand is drawn just above it).
func setup(camera: Camera3D, viewport: SubViewport, root: Node3D, layer: int) -> void:
	_camera = camera
	_viewport = viewport
	_spot = SpotLight3D.new()
	_spot.name = "TorchBeam"
	_spot.light_color = Color(1.0, 0.92, 0.78)
	_spot.light_energy = ENERGY
	_spot.spot_range = 9.0
	_spot.spot_angle = 17.0
	_spot.spot_attenuation = 1.2
	_spot.shadow_enabled = true
	_spot.visible = false
	root.add_child(_spot)
	_halo = SpotLight3D.new()
	_halo.name = "TorchHalo"
	_halo.light_color = Color(1.0, 0.9, 0.74)
	_halo.light_energy = HALO_ENERGY
	_halo.spot_range = 6.0
	_halo.spot_angle = 30.0
	_halo.spot_attenuation = 1.6
	_halo.visible = false
	root.add_child(_halo)
	_hand = TORCH_HAND.new()
	_hand.name = "TorchHand"
	_hand.layer = layer + 1
	add_child(_hand)
	# In the room's own layer, right above its 3D view: its hints and panels stay on top.
	var room := get_parent()
	var view: Node = viewport
	while view != null and view.get_parent() != room:
		view = view.get_parent()
	if room != null and view != null:
		_hand.embed(room, view.get_index() + 1)


func is_on() -> bool:
	return _on


## Where the beam points now, in the room's world: {origin, dir} or {} when it is off.
func get_aim() -> Dictionary:
	if not _on:
		return {}
	return {"origin": _spot.global_position, "dir": -_spot.global_basis.z}


## `dark`: the room's lights are off or have no power, and it is dark outside.
func update(delta: float, dark: bool) -> void:
	_frame = Engine.get_process_frames()
	var player := _player()
	var torch_on := player != null and player.has_method("torch_wanted_indoors") and bool(player.torch_wanted_indoors())
	_set_on(dark and torch_on and _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree())
	if not _on:
		return
	_t += delta
	# Where the cursor is, in the room: the ray from the camera through it.
	var vp_size := Vector2(_viewport.size) if _viewport != null else Vector2.ONE
	var screen := _hand.get_viewport().get_visible_rect().size
	var m := _hand.get_viewport().get_mouse_position()
	var uv := Vector2(clampf(m.x / maxf(1.0, screen.x), 0.0, 1.0), clampf(m.y / maxf(1.0, screen.y), 0.0, 1.0))
	var dir := _camera.project_ray_normal(uv * vp_size)
	var want := Basis.looking_at(dir, Vector3.UP).get_rotation_quaternion()
	if not _ready_q:
		_q = want
		_ready_q = true
	_q = _q.slerp(want, clampf(1.0 - exp(-FOLLOW * delta), 0.0, 1.0)).normalized()
	# Held in the right hand, below the eyes; a hand is never quite still.
	var shake := Basis(Vector3.UP, sin(_t * 1.7) * 0.006) * Basis(Vector3.RIGHT, sin(_t * 2.3) * 0.005)
	var xf := Transform3D(Basis(_q) * shake, _camera.global_transform * Vector3(0.16, -0.14, -0.1))
	_spot.global_transform = xf
	_halo.global_transform = xf
	# The flicker of a tired cell.
	var batt := float(player.get("flashlight_battery"))
	var flick := 1.0 + sin(_t * 14.0) * 0.03 + sin(_t * 31.0) * 0.015
	if batt < 0.15 and fmod(_t * 3.1, 1.0) < 0.2:
		flick *= 0.1
	_spot.light_energy = ENERGY * flick
	_halo.light_energy = HALO_ENERGY * flick
	# The hand turns with the beam: toward the cursor, from the middle of the view.
	var beam_local := _camera.global_basis.orthonormalized().inverse() * (Basis(_q) * Vector3.FORWARD)
	_hand.set("lag", Vector2(atan2(beam_local.x, -beam_local.z), asin(clampf(beam_local.y, -1.0, 1.0))) * 0.8)
	_hand.set("bob", Vector2(0.0, sin(_t * 1.3) * 0.6))
	_hand.set("bar_px", 0.0)
	_hand.set("dim", batt < 0.15)


func _process(_delta: float) -> void:
	# The room stopped asking (it closed): out.
	if _on and Engine.get_process_frames() - _frame > 1:
		_set_on(false)


## F in a room (the player's own F is off while you are in here).
func _input(event: InputEvent) -> void:
	if Engine.get_process_frames() - _frame > 2:
		return
	var key := event as InputEventKey
	if key == null or key.echo or not event.is_action_pressed("toggle_flashlight"):
		return
	var player := _player()
	if player != null and player.has_method("toggle_flashlight"):
		player.toggle_flashlight()


func _set_on(on: bool) -> void:
	_on = on
	if _spot != null:
		_spot.visible = on
		_halo.visible = on
	if _hand != null:
		_hand.show_torch(on)
	if not on:
		_ready_q = false


func _player() -> Node:
	var tree := get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null
