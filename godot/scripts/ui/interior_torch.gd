extends Node

## Your torch in a room: the same torch as in the camp, one switch (F here too), one cell, one
## beam (player_controller.hold_torch). The room's eye holds it, a beat behind the cursor where
## you point, in the right hand below the eyes; the hand holding it (torch_hand.gd) is at the
## bottom right of the view, turned toward where you shine. The rooms stand in the camp's own
## world, so the beam lights the room and goes on out of its windows and its door (playtest
## 14. 11.: the room had its own weaker beam that lit only the room, while the body's own torch
## shone in from the door). Each room (cabin, tent, services, reception) owns one and calls
## update() every frame it is open; when the calls stop (the room closed) it lets go.

const TORCH_HAND = preload("res://scripts/ui/torch_hand.gd")
const FOLLOW := 9.0

var _camera: Camera3D
var _viewport: SubViewport
var _hand: CanvasLayer
var _q := Quaternion.IDENTITY
var _ready_q := false
var _on := false
var _t := 0.0
var _frame := -10


## `layer`: the room's CanvasLayer index (the hand is drawn just above it).
func setup(camera: Camera3D, viewport: SubViewport, layer: int) -> void:
	_camera = camera
	_viewport = viewport
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


## Where the beam points now: {origin, dir, ...} or {} when it is off (the torch's own).
func get_aim() -> Dictionary:
	var player := _player()
	return player.get_flashlight_aim() if _on and player != null and player.has_method("get_flashlight_aim") else {}


func update(delta: float) -> void:
	_frame = Engine.get_process_frames()
	var player := _player()
	var switched := player != null and bool(player.get("torch_switch")) and _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree()
	if not switched:
		_set_on(false)
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
	player.hold_torch(Transform3D(Basis(_q) * shake, _camera.global_transform * Vector3(0.16, -0.14, -0.1)))
	# Lit or not is the torch's (a flat cell, a bottle in the hand, the night's things).
	_set_on(bool(player.is_flashlight_active()))
	if not _on:
		return
	# The hand turns with the beam: toward the cursor, from the middle of the view.
	var beam_local := _camera.global_basis.orthonormalized().inverse() * (Basis(_q) * Vector3.FORWARD)
	_hand.set("lag", Vector2(atan2(beam_local.x, -beam_local.z), asin(clampf(beam_local.y, -1.0, 1.0))) * 0.8)
	_hand.set("bob", Vector2(0.0, sin(_t * 1.3) * 0.6))
	_hand.set("bar_px", 0.0)
	_hand.set("dim", float(player.get("flashlight_battery")) < 0.15)


func _process(_delta: float) -> void:
	# The room stopped asking (it closed): let go.
	if _on and Engine.get_process_frames() - _frame > 1:
		_set_on(false)


## F in a room (the player's own F is off while you are in here).
func _input(event: InputEvent) -> void:
	if Engine.get_process_frames() - _frame > 2:
		return
	var key := event as InputEventKey
	# (The title's office is a room too: before the first camp's warden the action is not made.)
	if key == null or key.echo or not InputMap.has_action("toggle_flashlight") or not event.is_action_pressed("toggle_flashlight"):
		return
	var player := _player()
	if player != null and player.has_method("toggle_flashlight"):
		player.toggle_flashlight()


func _set_on(on: bool) -> void:
	_on = on
	if _hand != null:
		_hand.show_torch(on)
	if not on:
		_ready_q = false


func _player() -> Node:
	var tree := get_tree()
	return tree.get_first_node_in_group("player") if tree != null else null
