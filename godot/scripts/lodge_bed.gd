extends Node

## Sleeping in a bed of the camp's own lodgings (playtest 18. 10.: "two wardens cannot
## sleep in the one bed in the back room of the reception; one of them sleeps in a built
## tent, cabin or caravan"): at night, in a cabin, tent or caravan with nobody booked
## in and its bed made, a click on the bed lies you down. The same going to sleep as in
## the back room (scripts/reception/sleep_sequence.gd): onto the bed, the light off, the
## roof above you, the heavy blinks, the night in the dark, the alarm, up again. The
## night passes as it does in the back room (camp_office: in co-op only when both are in
## a bed); the other warden, coming in, sees you lying there (interior_manager
## coop_partner, bed_spot below).
##
## Made by InteriorManager; it watches whichever room is open.

const SLEEP = preload("res://scripts/reception/sleep_sequence.gd")

## Each kind's bed in its room's own coordinates (the camera's parent): the mattress's
## top centre, the head's end (the camera lies with its eyes there, looking down the
## bed and up a little), the click box over the bed.
const BEDS := {
	"cabin": {"centre": Vector3(-1.46, 0.59, -0.66), "eyes": Vector3(-1.46, 0.82, -1.18), "look": Vector3(14.0, 180.0, 0.0), "box": Vector3(1.0, 0.5, 1.9)},
	"tent": {"centre": Vector3(-0.2, 0.1, -0.02), "eyes": Vector3(-0.2, 0.26, -0.52), "look": Vector3(16.0, 180.0, 0.0), "box": Vector3(0.7, 0.3, 1.3)},
	"caravan": {"centre": Vector3(1.78, 0.66, 0.0), "eyes": Vector3(1.78, 0.9, -0.72), "look": Vector3(10.0, 180.0, 0.0), "box": Vector3(0.96, 0.4, 1.8)},
	# The staffroom's boiler room (scripts/staff/staffroom_plan.gd MATTRESS): the mattress
	# on the floor is the warden's (the user 21. 10.: "the mattress is for the player").
	"staff": {"centre": Vector3(3.39, 0.44, -0.1), "eyes": Vector3(3.39, 0.64, -0.82), "look": Vector3(16.0, 180.0, 0.0), "box": Vector3(0.8, 0.3, 1.9)},
}

var im: Node                      # InteriorManager
var _it: Node = null              # the lodging open now
var _kind := ""
var _body: StaticBody3D
var _sleep
var _cam: Camera3D
var _stand_pos := Vector3.ZERO
var _stand_rot := Vector3.ZERO


## Where the bed is in a room of `kind` (its camera parent's coordinates): {centre, head,
## foot}.
static func bed_spot(kind: String) -> Dictionary:
	if not BEDS.has(kind):
		return {}
	var b: Dictionary = BEDS[kind]
	var head := Vector3(b["eyes"].x, b["centre"].y, b["eyes"].z)
	var along: Vector3 = (head - (b["centre"] as Vector3)).normalized()
	# The foot end: half the bed's length (its click box) back from the middle.
	return {"centre": b["centre"], "head": head, "foot": (b["centre"] as Vector3) - along * ((b["box"] as Vector3).z * 0.5 - 0.05)}


func _ready() -> void:
	_sleep = SLEEP.new()
	add_child(_sleep)
	_sleep.finished.connect(_on_woke)


func is_sleeping() -> bool:
	return _sleep != null and _sleep.is_running()


## Lying with the eyes shut while the night goes by (the radio at the reception, heard
## through the walls, goes quiet for it: building_interior._eyes_shut).
func eyes_shut() -> bool:
	return is_sleeping() and _sleep.eyes_closing()


func _office():
	var main := get_tree().current_scene
	return main.get("camp_office") if main != null else null


func _office_call(m: String, args: Array, fallback):
	var o = _office()
	if o == null or not is_instance_valid(o) or not o.has_method(m):
		return fallback
	return o.callv(m, args)


func _process(_delta: float) -> void:
	if im == null or is_sleeping():
		return
	var it = im.call("_open_room_interior")
	var kind := ""
	if it != null:
		kind = str(im.call("_room_kind", it))
		# The staffroom is a service building with a bed of its own.
		if kind == "service" and str(it.get("_current_profile")) == "staff":
			kind = "staff"
	if not BEDS.has(kind):
		it = null
		kind = ""
	if it != _it:
		_detach()
		if it != null:
			_attach(it, kind)
	if _it != null and _body != null:
		# Only a made bed is for sleeping in (an unmade one is a job, room prep's click),
		# and only from the evening: by day it is not in the way of anything else.
		var live := _bed_made() and bool(_office_call("bedtime", [], true))
		_body.get_child(0).disabled = not live
		_body.collision_layer = 1 if live else 0


func _attach(it: Node, kind: String) -> void:
	_it = it
	_kind = kind
	_cam = it.get("_interior_camera")
	if _cam == null:
		return
	var root := _cam.get_parent() as Node3D
	var b: Dictionary = BEDS[kind]
	_body = StaticBody3D.new()
	_body.name = "LodgeBedSpot"
	_body.set_meta("interior_click_type", "lodge_bed")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = b["box"]
	shape.shape = box
	_body.add_child(shape)
	_body.position = (b["centre"] as Vector3) + Vector3(0, 0.05, 0)
	root.add_child(_body)


func _detach() -> void:
	if _body != null and is_instance_valid(_body):
		_body.queue_free()
	_body = null
	_it = null
	_kind = ""


func _room() -> Dictionary:
	var node = im.call("_open_room_node", _it)
	var key := str(im.call("_room_key_for", node))
	return {"key": key, "state": GuestManager.get_room_state(key) if key != "" else {}}


func _bed_made() -> bool:
	var st: Dictionary = _room()["state"]
	return not ("bed" in (st.get("remaining", []) as Array))


func _input(event: InputEvent) -> void:
	if _it == null or _body == null or is_sleeping() or get_tree().paused:
		return
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _kind == "cabin" and str(_it.get("_active_room")) == "bathroom":
		return
	var prep = _it.get("_prep")
	if prep != null and (prep.is_busy() or prep.is_scrubbing()):
		return
	var mouse := (event as InputEventMouseButton).position
	# The room's upgrade catalog wins where the two overlap on screen.
	if _it.has_method("_catalog_screen_rect"):
		var screen := get_viewport().get_visible_rect().size
		var cat: Rect2 = _it.call("_catalog_screen_rect")
		if screen.x > 0.0 and cat.has_point(mouse / screen):
			return
	if not _hits_bed(mouse):
		return
	get_viewport().set_input_as_handled()
	_try_sleep()


func _hits_bed(mouse: Vector2) -> bool:
	var vp: SubViewport = _it.get("_viewport")
	if vp == null or _cam == null:
		return false
	var screen := get_viewport().get_visible_rect().size
	var local := Vector2(clampf(mouse.x / screen.x, 0.0, 1.0) * vp.size.x, clampf(mouse.y / screen.y, 0.0, 1.0) * vp.size.y)
	var from := _cam.project_ray_origin(local)
	var q := PhysicsRayQueryParameters3D.create(from, from + _cam.project_ray_normal(local) * 8.0)
	var hit := vp.find_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") == _body


## Whether you may lie down here: the night's own rules (camp_office), no guests booked
## in, the other warden not already in this bed.
func _refusal() -> String:
	var r := str(_office_call("sleep_refusal", [], ""))
	if r != "":
		return r
	var room := _room()
	if bool((room["state"] as Dictionary).get("occupied", false)):
		return "Guests are staying here. Not this bed."
	for id in Coop.others():
		var st: Dictionary = Coop.state_of(id)
		if bool(st.get("z", false)) and str((st.get("room", {}) as Dictionary).get("k", "")) == str(room["key"]):
			return "%s is asleep in it." % Coop.name_of(id)
	return ""


func _try_sleep() -> void:
	var refusal := _refusal()
	if refusal != "":
		_office_call("say", [refusal], null)
		return
	var b: Dictionary = BEDS[_kind]
	_stand_pos = _cam.position
	_stand_rot = _it.get("_cam_base_rot") if _it.get("_cam_base_rot") != null else _cam.rotation
	_it.set("lodge_sleeping", true)
	var look: Vector3 = b["look"]
	_sleep.camera = _cam
	_sleep.lie_pos = b["eyes"]
	_sleep.lie_rot = Vector3(deg_to_rad(look.x), deg_to_rad(look.y), deg_to_rad(look.z))
	_sleep.stand_pos = _stand_pos
	_sleep.stand_rot = _stand_rot
	_sleep.lamp = func(on: bool): _lamp(on)
	_sleep.tv_focus = func(_on: bool): pass
	_sleep.fast_forward = func(): _office_call("start_sleep", [], null)
	_sleep.fast_forward_done = func(): return not bool(_office_call("is_sleeping_through", [], false))
	_sleep.wake_text = func(): return str(_office_call("clock_text", [], "06:30"))
	_sleep.may_sleep = func(): return bool(_office_call("may_sleep", [], true))
	_sleep.woke_early = func(): _office_call("get_up", [], null)
	_office_call("lie_down", [], null)
	_sleep.start()


## The room's light: off as you lie down, on again when you get up.
func _lamp(on: bool) -> void:
	if _it == null:
		return
	if _kind == "cabin" and _it.has_method("_toggle_manual_lights") and bool(_it.get("_manual_lights_on")) != on:
		_it.call("_toggle_manual_lights")
	elif _kind == "caravan" and _it.has_method("_apply_light"):
		_it.set("_lights_on", on)
		_it.call("_apply_light")
	elif _kind == "staff" and _it.has_method("_toggle_manual_service_lights") and bool(_it.get("_manual_lights_on")) != on:
		_it.call("_toggle_manual_service_lights")


func _on_woke() -> void:
	if _it != null and is_instance_valid(_it):
		_it.set("lodge_sleeping", false)
		var look = _it.get("_look")
		if look != null and look.has_method("reset"):
			look.reset()
		_lamp(true)
	_office_call("on_woke", [], null)


## Debug (tools/shot_driver.gd): lie down in the open lodging now, rules or not.
func debug_lie_down() -> void:
	if _it != null:
		var b: Dictionary = BEDS[_kind]
		var look: Vector3 = b["look"]
		_stand_pos = _cam.position
		_stand_rot = _cam.rotation
		_it.set("lodge_sleeping", true)
		_sleep.camera = _cam
		_sleep.lie_pos = b["eyes"]
		_sleep.lie_rot = Vector3(deg_to_rad(look.x), deg_to_rad(look.y), deg_to_rad(look.z))
		_sleep.stand_pos = _stand_pos
		_sleep.stand_rot = _stand_rot
		_sleep.lamp = func(on: bool): _lamp(on)
		_sleep.may_sleep = func(): return true
		_office_call("lie_down", [], null)
		_sleep.start()
