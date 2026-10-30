extends Node

## One view of the camp for all of a room's windows (the user 25. 10.: "the caravan's many
## windows are heavy on the hardware, can it be done more cleverly? do it shared like
## this IN ALL INTERIORS, and so in every future one"). A window used to draw a whole view
## of the camp of its own, up to eight a frame in the caravan. Here one camera stands where
## your eye is, mapped out into the camp the way the room lies in its building, with the
## room camera's own lens, drawn at the room's own pixel size; every pane, doorway and
## window of the room reads it at its own screen pixels (materials/window_into.gdshader),
## so what is behind each lines up with the room as a portal does, and the camp is drawn
## once, only while some window is in sight and open.
##
## The building you are in is hidden from this camera while you are inside (its meshes on
## HIDE_LAYER only), else its own walls stood in front of every window; the next frame
## nobody asks for the view it is given back to the camp as it was.
##
## One to one with the room (the playtest of 30. 10.: "the view out lags half a second
## behind my look, the window's frames fly after it"): the camera is put where the eye is
## at the last moment before the frame is drawn (RenderingServer.frame_pre_draw: after
## every script, tween and walk has moved the eye this frame), and the view's viewport
## hangs under the room's own, so it is drawn before the room that reads it.
##
## Every room gets it the same way (window_portal.gd does it for its windows):
##   var view = WINDOW_SHARED_VIEW.for_host(room_node)   # one per room script
##   pane material: view.pane_material(...)  (or window_portal.use_shared)
##   each frame a window wants the camp: view.offer(eye, room, room_to_world, world, building)

const GLASS_LAYER := 1 << 19
const HIDE_LAYER := 1 << 16
const PANE_SHADER := preload("res://materials/window_into.gdshader")

var vp: SubViewport
var cam: Camera3D
var _hidden: Array = []      # [GeometryInstance3D, its layers]
var _anchor: Node3D
var _offered := false
var _quiet := 0
## What the last offer asked for, the camera put from it just before the frame is drawn.
var _eye: Camera3D
var _room: Node3D
var _xform := Transform3D()
## The tools' before and after (false: the camera put at the offer, as it used to be).
static var sync_at_draw := true


## The view of `host` (a room's script node), made the first time it is asked for.
static func for_host(host: Node) -> Node:
	var v := host.get_node_or_null("WindowsView")
	if v == null:
		v = load("res://scripts/ui/window_shared_view.gd").new()
		v.name = "WindowsView"
		host.add_child(v)
	return v


func _init() -> void:
	# After the room (its windows offer first), before the frame is drawn.
	process_priority = 1000
	vp = SubViewport.new()
	vp.name = "View"
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(64, 64)
	add_child(vp)
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~GLASS_LAYER & ~HIDE_LAYER
	cam.near = 0.05
	cam.far = 400.0
	vp.add_child(cam)


func texture() -> Texture2D:
	return vp.get_texture()


## A pane reading this view at its screen pixels: old glass (`tint`, `sheen` at a slant),
## or an open doorway (no tint, no sheen).
func pane_material(glass := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PANE_SHADER
	m.set_shader_parameter("room_tex", texture())
	m.set_shader_parameter("tint", Vector3(0.95, 0.97, 0.97) if glass else Vector3.ONE)
	m.set_shader_parameter("sheen", 0.6 if glass else 0.0)
	m.set_shader_parameter("live", 0.0)
	return m


## This frame a window of the room wants the camp: `eye` the room's camera, `room` the
## node whose space `xform` maps into the camp, `world` the camp's, `building` the camp's
## building the room is in (hidden from this view while it is drawn; null: none hidden).
## The first offer of a frame places the camera.
func offer(eye: Camera3D, room: Node3D, xform: Transform3D, world: World3D, building: Node3D = null) -> void:
	if _offered or eye == null or world == null or room == null:
		return
	_offered = true
	var room_vp := eye.get_viewport()
	if vp.world_3d != world:
		vp.world_3d = world
	if room_vp != null:
		var px := Vector2i(room_vp.get_visible_rect().size)
		if px.x > 0 and px.y > 0 and vp.size != px:
			vp.size = px
	cam.fov = eye.fov
	cam.keep_aspect = eye.keep_aspect
	# A shifted frustum (the camp's eye looking up or down, when the eye is the camp's own
	# looking in through a caravan: caravan_interior._update_inview) the same.
	cam.projection = eye.projection
	if eye.projection == Camera3D.PROJECTION_FRUSTUM:
		var nk := cam.near / maxf(eye.near, 0.001)
		cam.size = eye.size * nk
		cam.frustum_offset = eye.frustum_offset * nk
	cam.global_transform = xform * (room.global_transform.affine_inverse() * eye.global_transform)
	_eye = eye
	_room = room
	_xform = xform
	# Drawn before the room that reads it: its viewport under the room's.
	if sync_at_draw and room_vp != null and vp.get_parent() != room_vp:
		vp.reparent(room_vp, false)
	_hide_building(building)


func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_put_camera):
		RenderingServer.frame_pre_draw.connect(_put_camera)


## The eye as it is when the frame is drawn, straight to the renderer (a transform set now
## would reach it only with the next frame's notifications).
func _put_camera() -> void:
	if not sync_at_draw or not _offered_last or _eye == null or not is_instance_valid(_eye) or _room == null or not is_instance_valid(_room):
		return
	if not _eye.is_inside_tree() or not _room.is_inside_tree() or not cam.is_inside_tree():
		return
	var t := _xform * (_room.global_transform.affine_inverse() * _eye.global_transform)
	cam.global_transform = t
	RenderingServer.camera_set_transform(cam.get_camera_rid(), t)


## Offered this frame (kept past _process, which clears _offered, for _put_camera).
var _offered_last := false


func _process(_delta: float) -> void:
	_offered_last = _offered
	if _offered:
		_quiet = 0
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_quiet += 1
		if _quiet == 2:
			_show_building()
	_offered = false


## Where the view's eye is in the camp now (the Photographer looks for you through it).
func eye_position() -> Vector3:
	return cam.global_position


func _hide_building(anchor: Node3D) -> void:
	if anchor == _anchor:
		return
	_show_building()
	_anchor = anchor
	if anchor == null:
		return
	for n in anchor.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		_hidden.append([g, g.layers])
		g.layers = HIDE_LAYER


func _show_building() -> void:
	for h in _hidden:
		var g = h[0]
		if g != null and is_instance_valid(g):
			(g as GeometryInstance3D).layers = int(h[1])
	_hidden.clear()
	_anchor = null


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_put_camera):
		RenderingServer.frame_pre_draw.disconnect(_put_camera)
	_show_building()
	# The viewport hung under a room's goes with this node.
	if vp != null and is_instance_valid(vp) and vp.get_parent() != self:
		vp.queue_free()
