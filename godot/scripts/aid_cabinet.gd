extends RefCounted

## A first-aid cabinet on a wall: one in the store behind the office, one in the staffroom's
## boiler room (the user 4. 11., W31: "a one-off first-aid kit in the store, in the
## staffroom too. Stocked again every morning. +50 HP. After use the cabinet stays open so
## you see it was used. Think of the co-op sync").
##
## The white enamel box with its red cross: a click opens it and takes what is in it
## (HEAL); its door then hangs open on the empty shelves till the morning
## (BalanceConfig.DAY_START_HOUR) stocks it again. Which were used is in the camp's books
## (state.biz["aid"] = {id: the morning it was used}): the host keeps them and sends them,
## so the other warden finds it open too.
##
##   var aid = AID_CABINET.new()
##   aid.build(root, "store", wall_point, yaw_deg)   # the front faces +Z turned yaw_deg
##   aid.tick()                                      # each frame the room is open
##   aid.use()                                       # the click

const K = preload("res://scripts/interior_kit.gd")
const BALANCE = preload("res://core/balance/balance_config.gd")
const HEAL := 50
## The front (frame and screws), the box's depth off the wall, the door in the frame and
## where its middle is from the front's: metres, the render's proportions.
const FRONT := Vector2(0.36, 0.48)
const DEPTH := 0.12
const DOOR := Vector2(0.31, 0.41)
const DOOR_AT := Vector2(0.004, -0.012)
## Swung open on its hinges at the left, out to the room.
const OPEN_DEG := -112.0
const SWING_SEC := 0.45
const SFX := "res://assets/sfx/rooms/aid_take.mp3"

var id := ""
var node: Node3D
var hinge: Node3D
## What glints under the cursor.
var meshes: Array = []
var _shown_open := false
var _tween: Tween
## The morning it was used on this machine, till the host's books have it too.
var _used_here := -99
var _player: AudioStreamPlayer3D


## Hangs it on a wall of `parent`: `wall` the point on the wall's face behind its middle,
## the front facing +Z turned `yaw_deg` (as K.picture).
func build(parent: Node3D, cab_id: String, wall: Vector3, yaw_deg: float) -> void:
	id = cab_id
	node = Node3D.new()
	node.name = "AidCabinet_" + cab_id
	node.position = wall
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	var enamel := K.surface("enamel_white", 0.4, Color(0.86, 0.84, 0.78))
	var box := K.slab(node, Vector3(FRONT.x - 0.012, FRONT.y - 0.012, DEPTH), Vector3(0, 0, DEPTH * 0.5), enamel, "AidBox")
	var front := K.cutout(node, "aid_front", FRONT, Vector3(0, -FRONT.y * 0.5, DEPTH + 0.002), 0.0, false, "AidFront")
	# Behind the door the shelves, empty but for a torn wrapper and a bottle.
	var inside := K.picture(node, "aid_inside", DOOR, Vector3(DOOR_AT.x, DOOR_AT.y, DEPTH + 0.004), 0.0, "AidInside")
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The door on its hinges at the left: a thin enamel leaf, the cross on its face.
	hinge = Node3D.new()
	hinge.name = "AidHinge"
	hinge.position = Vector3(DOOR_AT.x - DOOR.x * 0.5, DOOR_AT.y, DEPTH + 0.005)
	node.add_child(hinge)
	K.slab(hinge, Vector3(DOOR.x, DOOR.y, 0.01), Vector3(DOOR.x * 0.5, 0, 0.005), enamel, "AidLeaf")
	var face := K.picture(hinge, "aid_door", DOOR, Vector3(DOOR.x * 0.5, 0, 0.0112), 0.0, "AidDoor")
	meshes = [front, face, box]
	_player = AudioStreamPlayer3D.new()
	_player.name = "AidSound"
	_player.position = Vector3(0, 0, DEPTH + 0.1)
	_player.unit_size = 3.0
	_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	node.add_child(_player)
	_apply(false)


## The middle of its front (for the room's click box).
func centre() -> Vector3:
	return node.position + node.basis.z * (DEPTH * 0.5)


## The click box's size along the room's axes (turned with it).
func click_size() -> Vector3:
	var turned := absf(node.basis.z.x) > 0.5
	return Vector3(DEPTH + 0.06, FRONT.y, FRONT.x) if turned else Vector3(FRONT.x, FRONT.y, DEPTH + 0.06)


## The morning the camp's clock belongs to: before DAY_START_HOUR it is still the night of
## the day before (a night's wounds come out of the cabinet that was stocked that morning).
static func morning_of(day: int, hour: float) -> int:
	return day if hour >= BALANCE.DAY_START_HOUR else day - 1


func _morning() -> int:
	var day := CoreRoot.get_day() if CoreRoot != null else 1
	var main = node.get_tree().current_scene if node != null and node.is_inside_tree() else null
	var hour := float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0
	return morning_of(day, hour)


## Emptied this morning (here, or by the other warden: the host's books).
func used() -> bool:
	var m := _morning()
	if _used_here == m:
		return true
	var st = CoreRoot.get_state() if CoreRoot != null else null
	if st == null or not (st.biz is Dictionary):
		return false
	var aid = (st.biz as Dictionary).get("aid", {})
	return aid is Dictionary and int((aid as Dictionary).get(id, -99)) == m


## Each frame the room is open: shut again once the morning has stocked it, open when the
## other warden emptied it.
func tick() -> void:
	if node == null:
		return
	var open := used()
	if open != _shown_open:
		_apply(true)


## The click: opens it and takes what is in it (true), or it is empty (false: nothing
## happens, its open door says so).
func use() -> bool:
	if node == null or used():
		return false
	var m := _morning()
	_used_here = m
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.aid_used(id, m)
	var main = node.get_tree().current_scene
	if main != null and main.has_method("heal_player"):
		main.heal_player(HEAL)
	if _player != null and ResourceLoader.exists(SFX):
		_player.stream = load(SFX)
		_player.volume_db = -4.0
		_player.play()
	_apply(true)
	return true


func _apply(animated: bool) -> void:
	_shown_open = used()
	var want := OPEN_DEG if _shown_open else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animated or not node.is_inside_tree():
		hinge.rotation_degrees.y = want
		return
	_tween = node.create_tween()
	_tween.tween_property(hinge, "rotation_degrees:y", want, SWING_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
