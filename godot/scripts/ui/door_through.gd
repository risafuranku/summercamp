extends Node

## Through a door on foot, in and out, at every building (the user 4. 11.: "the cabin's door
## has black behind it when it opens, I want a smooth way through into the room, as at the
## reception. AT EVERY BUILDING"). A room is a little world of its own (a SubViewport) and a
## building in the camp a shell, so the doorway is a portal, both ways:
##
##   in    the leaf swings (door_anim) on a pane in the doorway showing the room itself, drawn
##         from your eye carried through the door: the camp's door and the room's are laid
##         one on the other, so a step towards the one is a step towards the other. In the
##         doorway the pane fills the view; the room opens with its own eye at that very spot
##         and walks on in to where you stand in it.
##   out   the room's eye walks back to its door, the leaf opens on the camp seen through the
##         doorway (the same view the other way round: the building left out of it but for
##         the leaf), and out on the step the camp takes the walk on from the same point
##         (interior_manager._step_out_of).
##
## What a room gives door_through (cabin, caravan, tent, the service rooms, bowling):
##   door_spec(structure) -> {root: Node3D (room space), at: Vector3 (the doorway's floor in
##       the plane of the camp's leaf, room space), out: Vector3 (the way out), size: Vector2
##       (the doorway), inner: float (how far in from `at` the wall's inside face is), leaf:
##       Array (what shows the shut door from inside), in_camp: Transform3D (optional: room
##       space -> the camp, for a room built in its building as it is; else the two doors
##       are laid one on the other)}; {} when there is no walking through it
##   door_ready(structure)  made up as that building's room is, nothing shown
##   door_walking           true here while the eye is not the room's (no look, no clicks)
##   door_tick(eye, fov)    optional: its windows kept up for the eye coming in
##   door_walk_in(from, fov) optional: the room walks its own way in from the doorway
##
## A room built in the camp's own world (W26: spec "one_world") stands behind the doorway
## itself: no panes either way (the one in the room looking out drew itself, a portal into
## the endless, the user 5. 11.), the doorway's dark not drawn, the room's own leaf out of
## the way while you come through it; the eye goes on from where it is.

const VIEW := preload("res://scripts/ui/window_shared_view.gd")
const DOOR_ANIM := preload("res://scripts/attractions/door_anim.gd")
const WALK_PATH := preload("res://scripts/ui/walk_path.gd")

## What lies less deep than this in the room from the leaf's plane is the door's own wall and
## what hangs on it: the eye looks through all that from outside.
const PLANE_DEPTH := 0.35
## What lies over the room's windows inside (the camp in the glass, its rain): the rooms'
## INVIEW_HIDE_LAYER.
const OVER_WINDOWS := 1 << 17
## No eye's layer (one_world_room.NO_EYE).
const NO_EYE := 1 << 20
## Metres a second through a door, and seconds for turning right round.
const PACE := 1.5
const TURN_SEC := 0.75
## Where the walks hand over: this far out of the leaf's plane (interior_manager's walk up
## stops there; the doorway fills the view).
const STEP_M := 0.175
## How far from the door the leaf starts to open on the way out.
const OPEN_FROM_M := 1.5
## The pane on the way out keeps this far ahead of the eye (through the wall's thickness).
const PANE_AHEAD_M := 0.16
## The pane in the doorway outside: pulled toward the eye as the retro look pulls a small
## quad (retro_materials.PULL_SMALL), over the door's frame boards (pulled less), as the
## dark doorway it stands for was (the frame came over the room from a metre off).
const PANE_PULL := 0.009

## The walk in has handed the eye over.
signal walked

var _room: Object
var _structure: Node3D
var _spec: Dictionary = {}
var _way: Dictionary = {}
var _eye: Camera3D
var _camp: Node3D
var _room_cam: Camera3D
## The camp -> the room's world, and the door's frame in the room's world.
var _to_room := Transform3D()
var _frame_g := Transform3D()
var _world: World3D
var _view: Node
var _base_mask := 0
## The doorways' panes in the camp (a double door has two) and what they had on them.
var _panes: Array = []
## On the way out: the pane in the room, and whether the door has opened yet.
var _out_pane: MeshInstance3D
var _out_open := false
var _plane: Array = []
var _leaf_shown: Array = []
## The room's leaves swung open on the way out (meta swing_deg: the pub's), shut again after.
var _leaf_swung: Array = []
var _walk: Tween
var _state := ""
var _done: Callable
## The room's eye as the room had it (it goes with yours on the way in).
var _stand: Array = []
## A room in the camp's own world (spec "one_world"): no panes.
var _one := false
var _ticked := Transform3D()
var _in_since := 0.0
## The room's own picture is drawn all the way up to its door, its eye with yours: the
## first frame it is on the screen is ready, not its clear colour (a tent's came up grey for
## a frame). Its update mode as it had it.
var _vp: SubViewport
var _vp_mode := -1


func _ready() -> void:
	_view = VIEW.for_host(self)
	_base_mask = _view.cam.cull_mask


## The room is on the other side of `structure`'s door now coming open: its picture in the
## doorway from here on. false: not a room you walk into, it opens as rooms always did.
func approach(room: Object, structure: Node3D, way: Dictionary, camp: Node3D) -> bool:
	finish()
	if not _take(room, structure, way, camp, true):
		return false
	_state = "approach"
	_room_cam = room.get("_interior_camera") as Camera3D
	_stand = [_room_cam.transform, _room_cam.fov] if _room_cam != null else []
	_ticked = Transform3D()
	_vp = room.get("_viewport") as SubViewport
	if _vp != null:
		_vp_mode = _vp.render_target_update_mode
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _one:
		# (Its walls are real round a real doorway: nothing of it is left out.)
		_clear_doorway()
		for n in _spec.get("leaf", []):
			if is_instance_valid(n) and (n as Node3D).visible:
				(n as Node3D).visible = false
				_leaf_shown.append(n)
		return true
	for d in _doors_of(way):
		var p := DOOR_ANIM.way_of(d)
		if p == null:
			continue
		var m: ShaderMaterial = _view.pane_material(false)
		m.set_shader_parameter("live", 1.0)
		m.set_shader_parameter("depth_pull", PANE_PULL)
		_panes.append([p, p.material_override])
		p.material_override = m
	if way.get("pane", null) is MeshInstance3D:
		var p2 := way["pane"] as MeshInstance3D
		var m2: ShaderMaterial = _view.pane_material(false)
		m2.set_shader_parameter("live", 1.0)
		_panes.append([p2, p2.material_override])
		p2.material_override = m2
	# A room that keeps its windows' views up for an eye coming in (door_tick) shows them;
	# else what lies over them inside (its views, never drawn while it is shut) is left out.
	_view.cam.cull_mask = _base_mask if room.has_method("door_tick") else _base_mask & ~OVER_WINDOWS
	_hide_plane()
	return true


## On the way to this room's door (interior_manager opens the room when the walk ends).
func coming_to(room: Object) -> bool:
	return _state == "approach" and _room == room


## The room has just opened, its eye where you stand in it: the eye goes back to where the
## camp's is, in the doorway, and walks in to that place.
func step_in() -> void:
	_room_cam = _room.get("_interior_camera") as Camera3D
	if _room_cam == null or _eye == null:
		finish()
		return
	# Its open put its eye back where you stand in it, or left it where the way in had it.
	if not _stand.is_empty():
		_room_cam.fov = _stand[1]
		if _room_cam.transform.is_equal_approx(_ticked):
			_room_cam.transform = _stand[0]
	# Open and on the screen now: drawn as it draws itself (a room that keeps its picture
	# shut, the caravan, says so itself as it opens).
	if _vp != null and _vp_mode == SubViewport.UPDATE_WHEN_VISIBLE:
		_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp = null
	_vp_mode = -1
	var t := _to_room * _eye.global_transform
	var from := Transform3D(t.basis.orthonormalized(), t.origin)
	_state = "in"
	_in_since = 0.0
	# (One world: the doorway's dark stays out of the way till you are in: finish.)
	if not _one:
		_restore_panes()
	# Its wall is not there yet for the eye that comes through it.
	_room_cam.cull_mask &= ~VIEW.HIDE_LAYER
	if _room.has_method("door_walk_in"):
		_room.call("door_walk_in", from, _eye.fov)
		return
	var stand_pos := _room_cam.position
	var stand_rot := _room_cam.rotation
	var fov := _room_cam.fov
	_room_cam.global_transform = from
	_room_cam.fov = _eye.fov
	var from_pos := _room_cam.position
	var from_rot := _room_cam.rotation
	var inner := float(_spec.get("inner", 0.15))
	var keys: Array = [{"pos": from_pos, "rot": from_rot}]
	# (A place right at the door needs no point past it.)
	if stand_pos.distance_to(from_pos) > (inner + 0.5) * 1.5:
		var through := _in_cam_space(Vector3(0.0, 0.0, -(inner + 0.5)))
		through.y = lerpf(from_pos.y, stand_pos.y, 0.5)
		keys.append({"pos": through, "rot": from_rot.lerp(stand_rot, 0.25)})
	keys.append({"pos": stand_pos, "rot": stand_rot})
	var dur := clampf(_length(keys) / PACE + _turn(keys) / PI * TURN_SEC, 0.7, 2.6)
	_room.set("door_walking", true)
	_walk = WALK_PATH.play(_room as Node, _room_cam, keys, dur)
	_walk.parallel().tween_property(_room_cam, "fov", fov, dur * 0.7)
	_walk.tween_callback(_walked_in)


func _walked_in() -> void:
	var room := _room
	var cam := _room_cam
	finish()
	if room == null or cam == null:
		return
	room.set("_cam_base_rot", cam.rotation)
	var look = room.get("_look")
	if look != null:
		look.reset()
	walked.emit()


## Out by the door of the open room `room`: its eye walks to the doorway, the leaf opens on
## the camp, and on the step `done` closes the room. false: no way out on foot from here (the
## caller closes the room as it did).
func leave(room: Object, structure: Node3D, way: Dictionary, camp: Node3D, done: Callable) -> bool:
	if _state != "":
		return _state == "out"
	if not _take(room, structure, way, camp, false):
		return false
	_room_cam = room.get("_interior_camera") as Camera3D
	if _room_cam == null:
		_clear()
		return false
	_done = done
	_state = "out"
	var inner := float(_spec.get("inner", 0.15))
	# On the step outside, at the height of the warden's eye, looking out.
	var sill: Vector3 = way["sill"]
	var normal: Vector3 = way["normal"]
	var step := Vector3(sill.x, _eye.global_position.y, sill.z) + normal * STEP_M
	var end_g: Vector3 = _to_room * step
	var end_f: Vector3 = _frame_g.affine_inverse() * end_g
	var parent := _room_cam.get_parent() as Node3D
	var end_pos: Vector3 = parent.global_transform.affine_inverse() * end_g if parent != null else end_g
	var from_pos := _room_cam.position
	var from_rot := _room_cam.rotation
	var out_rot := _facing_out()
	var keys: Array = [{"pos": from_pos, "rot": from_rot}]
	# Off the wall first: turned to the door where you stand, over to stand square in front
	# of it as deep in the room as you were (or deeper: the curtains and the coats hang by
	# the walls; along the pub's front wall the walk went through the curtain), then out.
	var from_f: Vector3 = _frame_g.affine_inverse() * _room_cam.global_position
	var front_f := Vector3(end_f.x, end_f.y, minf(from_f.z, -(inner + 0.62)))
	if from_f.z < -(inner + 0.2) and Vector2(from_f.x - front_f.x, from_f.z - front_f.z).length() > 0.25:
		var front := _in_cam_space(front_f)
		var to := front - from_pos
		keys.append({"pos": from_pos, "rot": Vector3(-0.04, atan2(-to.x, -to.z), 0.0)})
		keys.append({"pos": front, "rot": out_rot})
	keys.append({"pos": end_pos, "rot": out_rot})
	var dur := clampf(_length(keys) / PACE + _turn(keys) / PI * TURN_SEC, 0.8, 2.8)
	room.set("door_walking", true)
	if not _one:
		_make_out_pane()
	_walk = WALK_PATH.play(room as Node, _room_cam, keys, dur)
	_walk.parallel().tween_property(_room_cam, "fov", _eye.fov, dur)
	_walk.tween_callback(_walked_out)
	return true


## Where the camp's eye was in the walk out's last frame, for the camp to take it on from.
var handoff_eye := Vector3.INF


func _walked_out() -> void:
	if _room_cam != null:
		handoff_eye = _to_room.affine_inverse() * _room_cam.global_position
	var d := _done
	finish()
	if d.is_valid():
		d.call()


## Whatever was going on at a door, over: the camp's door and the room as they were.
func finish() -> void:
	if _walk != null and _walk.is_valid():
		_walk.kill()
	_walk = null
	_restore_panes()
	_restore_plane()
	for n in _leaf_shown:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_leaf_shown.clear()
	for n in _leaf_swung:
		if is_instance_valid(n):
			(n as Node3D).rotation_degrees.y = 0.0
	_leaf_swung.clear()
	if _out_pane != null and is_instance_valid(_out_pane):
		_out_pane.queue_free()
	_out_pane = null
	_one = false
	_out_open = false
	if _room_cam != null and is_instance_valid(_room_cam):
		_room_cam.cull_mask |= VIEW.HIDE_LAYER
	if _room != null and is_instance_valid(_room):
		_room.set("door_walking", false)
	# (Walked away from the door before it opened: the room as it was.)
	if _vp != null and is_instance_valid(_vp) and _vp_mode >= 0 and not (_room != null and is_instance_valid(_room) and _room.has_method("is_open") and bool(_room.call("is_open"))):
		_vp.render_target_update_mode = _vp_mode
	_vp = null
	_vp_mode = -1
	_clear()


func _clear() -> void:
	_room = null
	_structure = null
	_spec = {}
	_way = {}
	_state = ""
	_room_cam = null
	_done = Callable()
	_stand = []


## The leaves of the doorway (a double door's both).
static func _doors_of(way: Dictionary) -> Array:
	var out: Array = []
	for k in ["door", "pair"]:
		if way.get(k, null) is MeshInstance3D and is_instance_valid(way[k]):
			out.append(way[k])
	return out


func _take(room: Object, structure: Node3D, way: Dictionary, camp: Node3D, make_up: bool) -> bool:
	if room == null or structure == null or camp == null or not room.has_method("door_spec") or not way.has("sill"):
		return false
	var eye := camp.get_viewport().get_camera_3d()
	if eye == null:
		return false
	if make_up and room.has_method("door_ready"):
		room.call("door_ready", structure)
	var spec: Dictionary = room.call("door_spec", structure)
	if spec.is_empty() or not (spec.get("root") is Node3D) or not (spec["root"] as Node3D).is_inside_tree():
		return false
	_room = room
	_structure = structure
	_spec = spec
	_way = way
	_one = bool(spec.get("one_world", false))
	_eye = eye
	_camp = camp
	var root: Node3D = spec["root"]
	_world = root.get_world_3d()
	_frame_g = root.global_transform * _frame(spec["at"], spec["out"])
	if _one:
		# The room is where its building is: the eye goes on from where it is (laid one door
		# on the other, it jumped by what the two doors' planes differ).
		_to_room = Transform3D()
	elif spec.get("in_camp") is Transform3D:
		_to_room = root.global_transform * (spec["in_camp"] as Transform3D).affine_inverse()
	else:
		_to_room = _frame_g * _frame(way["sill"], way["normal"]).affine_inverse()
	return true


## A door's frame: at `at`, up, +Z the way out.
static func _frame(at: Vector3, out: Vector3) -> Transform3D:
	var z := Vector3(out.x, 0.0, out.z).normalized()
	return Transform3D(Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z), at)


static func _length(keys: Array) -> float:
	var l := 0.0
	for i in range(1, keys.size()):
		l += (keys[i]["pos"] as Vector3).distance_to(keys[i - 1]["pos"])
	return l


## How far the head turns along the keys (radians, the short way round).
static func _turn(keys: Array) -> float:
	var a := 0.0
	for i in range(1, keys.size()):
		a += absf(wrapf(float((keys[i]["rot"] as Vector3).y) - float((keys[i - 1]["rot"] as Vector3).y), -PI, PI))
	return a


## A point of the door's frame in the space the room's eye moves in.
func _in_cam_space(p: Vector3) -> Vector3:
	var parent := _room_cam.get_parent() as Node3D
	var g := _frame_g * p
	return parent.global_transform.affine_inverse() * g if parent != null else g


## The room's eye turned to look out of the door, as its rotation.
func _facing_out() -> Vector3:
	var parent := _room_cam.get_parent() as Node3D
	var b := _frame_g.basis * Basis(Vector3.UP, PI)
	if parent != null:
		b = parent.global_transform.basis.inverse() * b
	return b.orthonormalized().get_euler(EULER_ORDER_YXZ)


func _hide_plane() -> void:
	var inv := _frame_g.affine_inverse()
	for n in (_spec["root"] as Node3D).find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		# Not what lies over the room's windows inside (their views of the camp): kept off the
		# camp's looks into the room on their own layer, given HIDE_LAYER they showed in the
		# building's front windows from outside, the camp in them, all the way up to the
		# door (the user 4. 11.: "the outside windows stop working while you walk in"). In the
		# door's own wall they are not seen through the doorway anyway.
		if g.layers & OVER_WINDOWS:
			continue
		var box: AABB = (inv * g.global_transform) * g.get_aabb()
		if box.position.z > -PLANE_DEPTH:
			_plane.append([g, g.layers])
			g.layers = VIEW.HIDE_LAYER


func _restore_plane() -> void:
	for h in _plane:
		if is_instance_valid(h[0]):
			(h[0] as GeometryInstance3D).layers = int(h[1])
	_plane.clear()


func _restore_panes() -> void:
	for h in _panes:
		if is_instance_valid(h[0]):
			(h[0] as MeshInstance3D).material_override = h[1]
			if h.size() > 2:
				(h[0] as MeshInstance3D).layers = int(h[2])
	_panes.clear()


## One world: the doorway's dark (door_anim's, behind the leaf as it opens) not drawn while
## you come or go through it: the room itself, or the camp, is there.
func _clear_doorway() -> void:
	for d in _doors_of(_way):
		var p := DOOR_ANIM.way_of(d)
		if p != null and p.layers != NO_EYE:
			_panes.append([p, p.material_override, p.layers])
			p.layers = NO_EYE
	if _way.get("pane", null) is MeshInstance3D:
		var p2 := _way["pane"] as MeshInstance3D
		if p2.layers != NO_EYE:
			_panes.append([p2, p2.material_override, p2.layers])
			p2.layers = NO_EYE


## The doorway from inside: a pane showing the camp, hidden till the door opens.
func _make_out_pane() -> void:
	_out_pane = MeshInstance3D.new()
	_out_pane.name = "DoorThroughPane"
	_out_pane.mesh = QuadMesh.new()
	var m: ShaderMaterial = _view.pane_material(false)
	m.set_shader_parameter("live", 1.0)
	_out_pane.material_override = m
	_out_pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_out_pane.layers = OVER_WINDOWS
	_out_pane.visible = false
	(_spec["root"] as Node3D).add_child(_out_pane)
	_place_out_pane(-(float(_spec.get("inner", 0.15)) + 0.012))


func _place_out_pane(z: float) -> void:
	var size: Vector2 = _spec.get("size", Vector2(0.9, 2.0))
	_out_pane.global_transform = _frame_g * Transform3D(Basis(), Vector3(0.0, size.y * 0.5, z))
	# Past the wall's inside face it is the camp itself behind the doorway: big, so the eye
	# in the doorway sees no edge of it beside the jambs (the room has nothing out there).
	var past := z > -float(_spec.get("inner", 0.15)) + 0.002
	(_out_pane.mesh as QuadMesh).size = Vector2(8.0, 8.0) if past else size + Vector2(0.03, 0.03)


func _process(delta: float) -> void:
	if _state == "":
		return
	if _room == null or not is_instance_valid(_room) or _eye == null or not is_instance_valid(_eye) or _camp == null or not is_instance_valid(_camp):
		finish()
		return
	match _state:
		"approach":
			if not _one:
				_view.offer(_eye, _camp, _to_room * _camp.global_transform, _world, null)
			var t := _to_room * _eye.global_transform
			var at := Transform3D(t.basis.orthonormalized(), t.origin)
			if _room.has_method("door_tick"):
				_room.call("door_tick", at, _eye.fov)
			elif _room_cam != null and is_instance_valid(_room_cam):
				_room_cam.global_transform = at
				_room_cam.fov = _eye.fov
			if _room_cam != null and is_instance_valid(_room_cam):
				_ticked = _room_cam.transform
		"in":
			# Past the door's wall: it is behind you, it is there again.
			_in_since += delta
			if _room_cam == null or not is_instance_valid(_room_cam):
				finish()
				return
			if _plane.size() > 0 and (_frame_g.affine_inverse() * _room_cam.global_position).z < -PLANE_DEPTH - 0.1:
				_restore_plane()
				_room_cam.cull_mask |= VIEW.HIDE_LAYER
			# A room walking its own way in (door_walk_in) has it from here.
			if _walk == null and (_plane.is_empty() or _in_since > 3.0):
				var room := _room
				finish()
				if room != null:
					walked.emit()
		"out":
			_tick_out()


func _tick_out() -> void:
	var z: float = (_frame_g.affine_inverse() * _room_cam.global_position).z
	var doors := _doors_of(_way)
	if not _out_open and z > -OPEN_FROM_M:
		_out_open = true
		for d in doors:
			DOOR_ANIM.open(d, 6.0)
		var im := get_parent()
		if im != null and im.has_method("coop_door_opens") and not doors.is_empty():
			im.call("coop_door_opens", _structure, doors[0], 3.0)
		# (A tent unzips its door.)
		if _room.has_method("door_opening"):
			_room.call("door_opening")
		for n in _spec.get("leaf", []):
			if not is_instance_valid(n) or not (n as Node3D).visible:
				continue
			if (n as Node).has_meta("swing_deg"):
				# A leaf on its hinges opens out with the camp's (it vanished, the
				# user 4. 11.), shut again once you are out (finish).
				var sw := (n as Node3D).create_tween()
				sw.tween_property(n, "rotation_degrees:y", float((n as Node).get_meta("swing_deg")), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				_leaf_swung.append(n)
				continue
			(n as Node3D).visible = false
			_leaf_shown.append(n)
		if _one:
			_clear_doorway()
		else:
			_out_pane.visible = true
	if not _out_open or _one:
		return
	_place_out_pane(maxf(-(float(_spec.get("inner", 0.15)) + 0.012), z + PANE_AHEAD_M))
	var root: Node3D = _spec["root"]
	var keep: Array = []
	for d in doors:
		keep.append_array(DOOR_ANIM.moving_parts(d))
	_view.offer(_room_cam, root, _to_room.affine_inverse() * root.global_transform, _camp.get_world_3d(), _structure, keep)
