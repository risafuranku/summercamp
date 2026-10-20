extends CharacterBody3D

## Another warden as the host's night enemies see them (coop_night.gd): a body where
## they stand, a head camera looking where they look (Head/Camera3D, as the player's),
## their torch from their warden state, and what an enemy does to the torch in their hand
## sent to their machine.

const TORCH_RANGE := 18.0
const TORCH_HALF_ANGLE := 23.0

## The girl's cold drains the torch (girl_brain.gd sets it on whoever she hunts).
var flashlight_drain_boost := 0.0:
	set(v):
		if not is_equal_approx(v, flashlight_drain_boost):
			Coop.send_night_event("drain", [v], int(get_meta("coop_id", 0)))
		flashlight_drain_boost = v


## The torch dying in their hand, the hold on them, their hands off the controls (an
## enemy's work on whoever it hunts): sent to their machine.
var flashlight_stutter := 0.0:
	set(v):
		if not is_equal_approx(v, flashlight_stutter):
			Coop.send_night_event("stutter", [v], int(get_meta("coop_id", 0)))
		flashlight_stutter = v
var held_speed_mult := 1.0:
	set(v):
		if not is_equal_approx(v, held_speed_mult):
			Coop.send_night_event("held", [v], int(get_meta("coop_id", 0)))
		held_speed_mult = v


func set_controls_enabled(on: bool) -> void:
	Coop.send_night_event("controls", [on], int(get_meta("coop_id", 0)))


## Their warden state (the stand-in's peer id is its meta "coop_id").
func _state() -> Dictionary:
	return Coop.state_of(int(get_meta("coop_id", 0)))


func is_flashlight_active() -> bool:
	return bool(_state().get("t", false))


func get_flashlight_aim() -> Dictionary:
	if not is_flashlight_active():
		return {}
	var d: Vector3 = _state().get("d", Vector3.FORWARD)
	if d.length() < 0.01:
		d = Vector3.FORWARD
	return {"origin": global_position + Vector3(0.0, 1.4, 0.0), "dir": d.normalized(), "range": TORCH_RANGE, "half_angle": TORCH_HALF_ANGLE}
