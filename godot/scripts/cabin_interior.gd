extends CanvasLayer

## The room swipe is a smooth push (scripts/ui/room_push.gd).
const ROOM_PUSH = preload("res://scripts/ui/room_push.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
## The cabin's plan, the same for the room and the model outside (scripts/cabin_layout.gd).
const CABIN_LAYOUT = preload("res://scripts/cabin_layout.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const SLOP_BUCKET_POS := Vector3(1.32, 0.05, 1.05)
## The bed: frame centre on the floor, and the top of its mattress.
const BED_POS := CABIN_LAYOUT.BED
const BED_TOP := CABIN_LAYOUT.BED_TOP
## Surfaces per cabin level: walls, floor, ceiling (assets/textury/camp).
const LEVEL_SURFACES := {
	1: ["planks_grey", "planks_red", "planks_grey"],
	2: ["knotty_pine", "lino_floor", "ceiling_board"],
	3: ["wallpaper_70s", "parquet", "ceiling_board"],
}
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
## The windows' curtains (scripts/reception/curtain.gd).
const CURTAIN = preload("res://scripts/reception/curtain.gd")
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const ROOM_WEATHER = preload("res://scripts/ambient/room_weather.gd")

signal room_task_completed(task_id: String)
signal request_close
signal request_upgrade

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const HOST_QUIET_TEXTURE = preload("res://assets/textury/npc/host1.png")
const HOST_DRUNK_TEXTURE = preload("res://assets/textury/npc/host2.png")
const HOST_CHEAP_TEXTURE = preload("res://assets/textury/npc/host3.png")

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)
const CABIN_GUEST_SPRITE_PIXEL_SIZE := 0.0032
const CABIN_GUEST_TARGET_HEIGHT := 1.62
const CABIN_GUEST_STAND_POINTS := [
	Vector3(-0.20, 0.82, -0.44),
	Vector3(0.24, 0.82, -0.30),
]

var _is_open: bool = false
var _cabin_level: int = 1
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _cabin_root: Node3D
var _guest_visual_root: Node3D
var _guest_occupants: Array = []
var _room_env: Environment
var _main_light: OmniLight3D
## The small fridge (level 2 and up) while there is power: its compressor runs a while
## and rests a while, and knocks as it starts (ElevenLabs world/fridge_hum, fridge_knock),
## through the room's echo (room_weather.gd's Room bus). The whole room is two metres
## across, so it is not placed (the room's own world has no listener of its own).
const FRIDGE_HUM := "res://assets/sfx/world/fridge_hum.mp3"
const FRIDGE_KNOCK := "res://assets/sfx/world/fridge_knock.mp3"
var _fridge_hum: AudioStreamPlayer
var _fridge_knock: AudioStreamPlayer
var _fridge_on := false
var _fridge_t := 0.0
var _window_view_sky: MeshInstance3D
## The cabin outside (InteriorManager sets it): the windows look out of it into the camp
## (off-axis cameras through each window, like the reception's), not at a picture.
const GLASS_LAYER := 1 << 19
var _anchor: Node3D
## Each tier's windows: level -> [{vp, cam, quad, frame: Transform3D (room), size, outward, curtain, cbody}].
var _level_portals: Dictionary = {}
## Each tier's room (walls, windows, furniture): level -> Node3D; the table's place in it.
var _level_shells: Dictionary = {}
var _level_tables: Dictionary = {}
var _catalog: Node3D
## The glint on a curtain under the cursor.
var _glint = HOVER_GLINT.new()
var _window_view_ground: MeshInstance3D
## Shown only in the basic cabin (the right wall's window, where better cabins have the
## bathroom door).
var _window_view_trees: MeshInstance3D
var _light_switch_body: StaticBody3D
var _light_switch_mesh: MeshInstance3D
var _light_switch_tex_on: Texture2D
var _light_switch_tex_off: Texture2D
var _manual_lights_on: bool = true
var _grid_power_available: bool = true
var _manual_light_tween: Tween
var _is_day_mode: bool = true
var _time_state: int = TIME_DAY
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _barrel_overlay: ColorRect
var _cam_base_rot: Vector3 = Vector3.ZERO
## Standing inside the door of the cabin: most of the room, never the door behind you.
var _look = INTERIOR_LOOK.new(72.0, 28.0, 38.0)
## Lying in this room's bed (scripts/lodge_bed.gd has the camera): no looking round,
## no leaving, no clicks till you are up.
var lodge_sleeping := false
var _exit_hint: Control
## The room's surfaces, re-skinned per level: {walls: [...], floor, ceiling}.
var _shell: Dictionary = {}
var _bath_shell: Dictionary = {}
var _texture_style
var _bathroom_root: Node3D
var _active_room: String = "main"
var _swipe_overlay: ColorRect
var _swipe_tween: Tween
var _swipe_animating: bool = false

# Screen-space active zones.
var _catalog_mesh: MeshInstance3D
var _side_hints: Control
var _prep = INTERIOR_PREP.new()


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	# Under the HUD (65), whose messages show over a room.
	layer = 56
	visible = false
	_build_viewport()
	_sync_viewport_to_window()
	_update_swipe_overlay_size()
	_build_cabin_room()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport_to_window()
		_update_swipe_overlay_size()


func is_open() -> bool:
	return _is_open


func set_is_day(is_day: bool) -> void:
	_time_state = TIME_DAY if is_day else TIME_NIGHT
	_is_day_mode = is_day
	_apply_time_profile()


func set_time_state(new_state: int) -> void:
	_time_state = int(clamp(new_state, TIME_DAY, TIME_NIGHT))
	_is_day_mode = (_time_state != TIME_NIGHT)
	_apply_time_profile()


func set_daylight_profile(daylight_factor: float, sun_color: Color, _ambient_color: Color, _ambient_energy: float) -> void:
	_daylight_factor = clampf(daylight_factor, 0.0, 1.0)
	_sunlight_color = sun_color
	_apply_time_profile()


func set_grid_power_available(power_available: bool) -> void:
	_grid_power_available = power_available
	_apply_time_profile(true)


func set_guest_occupants(entries: Array) -> void:
	_guest_occupants.clear()
	for entry_any in entries:
		if entry_any is Dictionary:
			_guest_occupants.append((entry_any as Dictionary).duplicate(true))
	_refresh_guest_visuals()


func open_cabin(level: int = 1) -> void:
	# Registered before it was in the tree (size 0, shrink 1): the low resolution now.
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	_release_inview()
	_cabin_level = clampi(level, 1, 3)
	_manual_lights_on = true
	_apply_switch_visual()
	if _is_open:
		_apply_level_variant()
		_apply_time_profile()
		_refresh_guest_visuals()
		return
	if _interior_camera == null:
		return
	_is_open = true
	visible = true
	_sync_viewport_to_window()
	# A little down: the floor in view to clean it at once, the window still whole (the
	# user 20. 10.).
	_interior_camera.rotation_degrees = Vector3(MAIN_PITCH_DEG, 0.0, 0.0)
	_set_cabin_room("main", false)
	_apply_level_variant()
	_apply_time_profile()
	_refresh_guest_visuals()
	_cam_base_rot = _interior_camera.rotation
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


const MAIN_PITCH_DEG := -13.0


## The cabin you are in, outside: its windows look out of it.
func set_world_anchor(n: Node3D) -> void:
	_anchor = n


func door_surface() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textury/camp/door_wood.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


var _weather


## The weather in here (scripts/ambient/room_weather.gd): rain on the glass, lightning
## through the windows, the timbers creaking in the gusts, a leak in the roof.
func _room_weather():
	if _weather == null or not is_instance_valid(_weather) or _weather.get_parent() != _cabin_root:
		_weather = ROOM_WEATHER.new()
		_weather.is_open = func(): return _is_open
		_cabin_root.add_child(_weather)
		_weather.set_drip(Vector3(0.9, 2.25, 0.6), 0.02)
	return _weather


## A window looking out: a quad in the opening shows what a camera sees through the same
## window of the cabin outside (the room is the model's own space, CabinLayout), with a
## curtain to draw over it (the Photographer takes pictures through the glass) that
## glints under the cursor like everything else you can use.
func _add_portal(shell: Node3D, lv: int, n: String, centre: Vector3, outward: Vector3, size: Vector2, curtain_tex: String) -> void:
	var vp := SubViewport.new()
	vp.name = n + str(lv)
	vp.size = Vector2i(224, int(224.0 * size.y / size.x))
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.cull_mask = 0xFFFFF & ~GLASS_LAYER
	vp.add_child(cam)
	var quad := MeshInstance3D.new()
	quad.name = n + "Glass"
	var q := QuadMesh.new()
	q.size = size
	quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = vp.get_texture()
	quad.material_override = m
	var z := -outward.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var frame := Transform3D(Basis(x, Vector3.UP, z), centre)
	quad.transform = frame
	quad.visible = false
	shell.add_child(quad)
	_room_weather().add_window(quad)
	var cur = CURTAIN.new()
	var hang := centre - outward.normalized() * (CABIN_LAYOUT.WALL_T + 0.08)
	cur.build(shell, hang, size.x + 0.1, size.y + 0.3, rad_to_deg(atan2(-outward.x, -outward.z)), curtain_tex, 0.7, self, true)
	var cbody := StaticBody3D.new()
	cbody.name = n + "CurtainBody"
	cbody.set_meta("interior_click_type", "cabin_curtain")
	cbody.set_meta("portal_index", (_level_portals[lv] as Array).size())
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(size.x + 0.5, size.y + 0.4, 0.14)
	cshape.shape = cbox
	cbody.add_child(cshape)
	cbody.transform = Transform3D(frame.basis, hang)
	shell.add_child(cbody)
	(_level_portals[lv] as Array).append({"vp": vp, "cam": cam, "quad": quad, "frame": frame, "size": size, "outward": outward.normalized(), "curtain": cur, "cbody": cbody})


## This tier's windows (the room's level).
func _portals_now() -> Array:
	return _level_portals.get(_cabin_level, [])


## Room space -> the camp (the model's own space under the cabin outside).
func _room_to_world() -> Transform3D:
	return _anchor.global_transform * Transform3D(Basis(), CABIN_LAYOUT.ROOM_TO_MODEL)


## The windows that look out now, as the camp has them: [{pos (the glass's middle,
## outside, world), out (the way it faces, world)}]. A thing that wants to be seen
## through one stands there (the Silent Man at the glass).
func outside_windows() -> Array:
	var out: Array = []
	if _anchor == null or not is_instance_valid(_anchor) or not _anchor.is_inside_tree() or _active_room != "main":
		return out
	var to_world := _room_to_world()
	for pt in _portals_now():
		var frame: Transform3D = pt["frame"]
		var o: Vector3 = pt["outward"]
		var dir := (to_world.basis * o).normalized()
		# How squarely you look at it now (1 straight at it).
		var facing := 0.0
		if _interior_camera != null and is_instance_valid(_interior_camera):
			var at := _cabin_root.global_transform * frame.origin
			var to := (at - _interior_camera.global_position).normalized()
			facing = (-_interior_camera.global_transform.basis.z).dot(to)
		out.append({"pos": to_world * (frame.origin + o * 0.03), "out": dir, "facing": facing})
	return out


## The windows for whatever is outside at night (the Photographer): outside_windows()
## with each one's curtain and its flash. [{pos, out, facing, open, flash: Callable}].
func photo_windows() -> Array:
	var out: Array = []
	var i := 0
	var wins := outside_windows()
	for pt in _portals_now():
		if i >= wins.size():
			break
		var w: Dictionary = wins[i]
		i += 1
		var cur = pt.get("curtain")
		w["open"] = float(cur.open) if cur != null else 1.0
		w["flash"] = _photo_flash.bind(pt)
		w["room_world"] = _viewport.find_world_3d() if _viewport != null else null
		w["glass"] = _cabin_root.global_transform * (pt["frame"] as Transform3D).origin
		w["eye"] = _interior_camera.global_position
		# Your eye out in the camp (the window's camera): what is out there stands on the
		# line from it through the glass.
		w["view"] = (pt["cam"] as Camera3D).global_position
		out.append(w)
	return out


var _photo_light: OmniLight3D
var _photo_t := 0.0


func _photo_flash(pt: Dictionary) -> void:
	if _photo_light == null or not is_instance_valid(_photo_light) or _photo_light.get_parent() != _cabin_root:
		_photo_light = OmniLight3D.new()
		_photo_light.name = "PhotoFlash"
		_photo_light.light_color = Color(0.9, 0.94, 1.0)
		_photo_light.omni_range = 6.0
		_photo_light.shadow_enabled = true
		_cabin_root.add_child(_photo_light)
	var frame: Transform3D = pt["frame"]
	_photo_light.position = frame.origin - (pt["outward"] as Vector3) * 0.4
	var cur = pt.get("curtain")
	_photo_light.set_meta("peak", 9.0 * (lerpf(0.15, 1.0, float(cur.open)) if cur != null else 1.0))
	_photo_t = 0.45


func _tick_photo_flash(delta: float) -> void:
	if _photo_light == null or not is_instance_valid(_photo_light):
		return
	_photo_t = maxf(0.0, _photo_t - delta)
	_photo_light.light_energy = float(_photo_light.get_meta("peak", 0.0)) * pow(_photo_t / 0.45, 1.6)


func curtains_state() -> Array:
	var out: Array = []
	for pt in _portals_now():
		var cur = pt.get("curtain")
		out.append(cur == null or cur.is_open())
	return out


func take_curtains(state: Array) -> void:
	var portals := _portals_now()
	for i in mini(state.size(), portals.size()):
		var cur = portals[i].get("curtain")
		if cur != null and cur.is_open() != bool(state[i]):
			cur.set_open(bool(state[i]))


## Each frame while you are in: every window's camera where your eye is, mapped out into
## the camp, the window its near plane (so it moves as you turn, a real view).
func _update_portals() -> void:
	var live := _anchor != null and is_instance_valid(_anchor) and _anchor.is_inside_tree()
	var dt := get_process_delta_time()
	_tick_photo_flash(dt)
	var to_world := _room_to_world() if live else Transform3D()
	for lv in _level_portals.keys():
		for pt in _level_portals[lv]:
			var cur = pt.get("curtain")
			var shown: bool = _active_room == "main" and int(lv) == _cabin_level
			if cur != null:
				cur.update(dt)
			(pt["cbody"] as StaticBody3D).collision_layer = 1 if shown else 0
			var on: bool = live and shown and (cur == null or cur.open > 0.03)
			(pt["quad"] as MeshInstance3D).visible = on
			var vp: SubViewport = pt["vp"]
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
			if not on:
				continue
			if vp.world_3d != _anchor.get_world_3d():
				vp.world_3d = _anchor.get_world_3d()
			var frame: Transform3D = pt["frame"]
			var eye := _cabin_root.global_transform.affine_inverse() * _interior_camera.global_position
			var e := frame.affine_inverse() * eye
			if e.z < 0.05:
				continue
			var cam: Camera3D = pt["cam"]
			cam.global_transform = Transform3D(to_world.basis * frame.basis, to_world * eye)
			cam.set_frustum((pt["size"] as Vector2).y, Vector2(-e.x, -e.y), e.z + 0.06, e.z + 220.0)


## The curtain under the cursor glints; the finger over it.
func _update_hover() -> void:
	var meshes: Array = []
	if not _prep.is_busy() and _active_room == "main":
		var hit := _raycast_world(get_viewport().get_mouse_position())
		var n = hit.get("collider", null) as Node
		while n != null and not n.has_meta("portal_index"):
			n = n.get_parent()
		if n != null:
			var portals := _portals_now()
			var i := int(n.get_meta("portal_index"))
			if i < portals.size() and portals[i].get("curtain") != null:
				meshes = portals[i]["curtain"].meshes
				HandCursor.want(HandCursor.POINT)
	_glint.show_on(meshes)


func close_cabin() -> void:
	if not _is_open:
		return
	# Off while nobody listens; the next visit finds it starting up soon enough.
	_fridge_set(false, false)
	_fridge_t = randf_range(1.0, 25.0)
	_is_open = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	ROOM_PUSH.cancel(_viewport_container)
	_swipe_animating = false
	for lv in _level_portals.keys():
		for pt in _level_portals[lv]:
			(pt["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	_glint.clear()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open:
		_update_inview(delta)
		return
	if _interior_camera == null:
		return
	_apply_idle_mouse_look(delta)
	_update_portals()
	_update_hover()
	_update_torch(delta)
	_update_fridge(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
		_side_hints = INTERIOR_LOOK.make_side_hints(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	if _active_room == "bathroom":
		INTERIOR_LOOK.set_side_hints(_side_hints, "Room  [A]", "")
	else:
		INTERIOR_LOOK.set_side_hints(_side_hints, "", "Bathroom  [D]" if _cabin_level >= 2 else "")


# ── the camp looking in ──────────────────────────────────────────────────────
#
# From the camp the nearest cabin's windows show this room (the user 21. 10.: the cabin's
# windows had the reception's trouble, flat from outside): a camera in the room's own
# world at the camp's eye (camp -> the cabin -> the room, CabinLayout: one plan for both),
# the panes reading its picture at their own screen pixels (materials/window_into
# .gdshader), as the reception's and the caravans' do. One room for every cabin: made up
# as the one looked into is (its tier, its mess, its curtains, its guests while they are
# up), its lamp lit when window_lights has that cabin lit. Farther than INVIEW_RANGE, or
# with no pane turned to you, the panes are window_lights' again (its "inview_live"
# panes only hear whether they are lit).

const INVIEW_RANGE := 30.0
## What lies over the room's windows inside (the camp in the glass, the rain on it): the
## camera looking in from the camp skips it.
const INVIEW_HIDE_LAYER := 1 << 17
var _inview_vp: SubViewport
var _inview_cam: Camera3D
var _inview_mat: ShaderMaterial
var _inview_cabin: Node3D
var _inview_panes: Array = []
var _inview_scan_t := 0.0
var _inview_light_t := 0.0
var _inview_cabins: Array = []


func _camp_camera() -> Camera3D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var w3d = scene.get("_world_3d") if scene != null else null
	if w3d is Node3D and (w3d as Node3D).is_inside_tree():
		return (w3d as Node3D).get_viewport().get_camera_3d()
	return null


func _find_cabins() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene if is_inside_tree() else null
	var bm = scene.get("building_manager") if scene != null else null
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures == null:
		return out
	for c in structures.get_children():
		if str(c.get_meta("building_type", "")).begins_with("cabin") and c is Node3D:
			out.append(c)
	return out


## The cabin's panes (building_models: its "lit_window" quads).
static func _panes_of(cabin: Node3D) -> Array:
	var out: Array = []
	for m in cabin.find_children("*", "MeshInstance3D", true, false):
		if (m as Node).has_meta("lit_window"):
			out.append(m)
	return out


static func _pane_turned_to(p: MeshInstance3D, eye: Vector3) -> bool:
	var to := eye - p.global_position
	return to.length() > 0.05 and p.global_basis.z.normalized().dot(to.normalized()) > 0.1


func _update_inview(delta: float) -> void:
	var cam := _camp_camera()
	var cabin: Node3D = null
	if cam != null and _cabin_root != null:
		_inview_scan_t -= delta
		if _inview_scan_t <= 0.0:
			_inview_scan_t = 1.0
			_inview_cabins = _find_cabins()
		var best := INVIEW_RANGE
		for c in _inview_cabins:
			if not is_instance_valid(c) or not (c as Node3D).is_inside_tree():
				continue
			var d := (c as Node3D).global_position.distance_to(cam.global_position)
			if d >= best:
				continue
			for p in _panes_of(c):
				if _pane_turned_to(p, cam.global_position):
					best = d
					cabin = c
					break
	if cabin != _inview_cabin:
		_release_inview()
		if cabin != null:
			_take_inview(cabin)
	if _inview_cabin == null or _inview_panes.is_empty():
		return
	for pt in _portals_now():
		var cur = pt.get("curtain")
		if cur != null:
			cur.update(delta)
	# The camp's eye in the room: the world -> the cabin (the room's model space) -> the room.
	var to_room: Transform3D = _cabin_root.global_transform * (_inview_cabin.global_transform * Transform3D(Basis(), CABIN_LAYOUT.ROOM_TO_MODEL)).affine_inverse()
	var t := to_room * cam.global_transform
	_inview_cam.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	_inview_cam.fov = cam.fov
	_inview_cam.keep_aspect = cam.keep_aspect
	# The camp's eye looking up or down is a shifted frustum (player_controller): the same.
	_inview_cam.projection = cam.projection
	var nk := _inview_cam.near / maxf(cam.near, 0.001)
	_inview_cam.size = cam.size * nk
	_inview_cam.frustum_offset = cam.frustum_offset * nk
	var px := Vector2i(cam.get_viewport().get_visible_rect().size)
	if _inview_vp.size != px and px.x > 0:
		_inview_vp.size = px
	_inview_light_t -= delta
	if _inview_light_t <= 0.0:
		_inview_light_t = 0.5
		_inview_room_light()


## The room made up as `cabin` is, and its panes given the room's picture.
func _take_inview(cabin: Node3D) -> void:
	_ensure_inview()
	_inview_cabin = cabin
	_inview_panes = _panes_of(cabin)
	var t := str(cabin.get_meta("building_type", "cabin_1"))
	_cabin_level = clampi(int(t.right(1)) if t.right(1).is_valid_int() else 1, 1, 3)
	_apply_level_variant()
	# The room and, from the tier up, the bathroom behind its own window.
	if _cabin_root != null:
		_cabin_root.visible = true
	if _bathroom_root != null:
		_bathroom_root.visible = _cabin_level >= 2
	var im := get_parent()
	if im != null and im.has_method("_push_room_state"):
		im.call("_push_room_state", self, cabin)
	var key: String = im.call("_room_key_for", cabin) if im != null and im.has_method("_room_key_for") else ""
	var by_room = im.get("_curtains_by_room") if im != null else null
	if key != "" and by_room is Dictionary and (by_room as Dictionary).has(key):
		take_curtains((by_room as Dictionary)[key])
	for p in _inview_panes:
		var mi := p as MeshInstance3D
		mi.set_meta("inview_was", mi.material_override)
		mi.set_meta("inview_live", true)
		mi.material_override = _inview_mat
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_inview_light_t = 0.0


func _release_inview() -> void:
	for p in _inview_panes:
		var mi := p as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		if mi.has_meta("inview_was"):
			mi.material_override = mi.get_meta("inview_was")
			mi.remove_meta("inview_was")
		mi.remove_meta("inview_live")
	_inview_panes.clear()
	_inview_cabin = null
	if _inview_vp != null:
		_inview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The room's light as the camp's hour has it, its lamp as window_lights has the cabin
## (guests in and up: lit), the guests in it while they are up.
func _inview_room_light() -> void:
	var scene := get_tree().current_scene
	var hour := float(scene.get("_time_of_day_hours")) if scene != null and scene.get("_time_of_day_hours") != null else 12.0
	var state := TIME_DAY if hour >= 6.5 and hour < 19.5 else (TIME_EVENING if hour >= 19.5 and hour < 21.0 else TIME_NIGHT)
	var im := get_parent()
	var ll = im.get("_last_light") if im != null else null
	if ll is Array and (ll as Array).size() >= 4:
		_daylight_factor = clampf(float(ll[0]), 0.0, 1.0)
		_sunlight_color = ll[1]
	var lit := 0.0
	for p in _inview_panes:
		lit = maxf(lit, float((p as Node).get_meta("wl_lit", 0.0)))
	var up := lit > 0.05 or state == TIME_DAY
	_manual_lights_on = up
	var guests: Array = []
	if up and im != null and im.has_method("_guest_visuals_for_structure"):
		guests = im.call("_guest_visuals_for_structure", _inview_cabin)
	if guests.size() != _guest_occupants.size():
		set_guest_occupants(guests)
	set_time_state(state)
	_inview_mat.set_shader_parameter("bright", 1.0 if state == TIME_NIGHT else (0.8 if state == TIME_EVENING else 0.62))
	_inview_mat.set_shader_parameter("glow", 0.0)


func _ensure_inview() -> void:
	if _inview_vp != null:
		return
	_inview_vp = SubViewport.new()
	_inview_vp.name = "CabinFromCamp"
	_inview_vp.size = Vector2i(426, 240)
	_inview_vp.world_3d = _viewport.find_world_3d()
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_inview_vp)
	_inview_cam = Camera3D.new()
	_inview_cam.near = 0.05
	_inview_cam.far = 40.0
	_inview_cam.cull_mask = 0xFFFFF & ~INVIEW_HIDE_LAYER & ~GLASS_LAYER
	_inview_vp.add_child(_inview_cam)
	# The room's own views out and the rain on their glass are for the inside only.
	for lv in _level_portals.keys():
		for pt in _level_portals[lv]:
			_hide_from_camp(pt["quad"])
	if _weather != null and is_instance_valid(_weather):
		_hide_from_camp(_weather)
	_inview_mat = ShaderMaterial.new()
	_inview_mat.shader = load("res://materials/window_into.gdshader")
	_inview_mat.set_shader_parameter("room_tex", _inview_vp.get_texture())
	_inview_mat.set_shader_parameter("live", 1.0)
	# Between the window's frame and its bar, both pulled forward by the retro look.
	_inview_mat.set_shader_parameter("depth_pull", 0.005)


static func _hide_from_camp(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = INVIEW_HIDE_LAYER
	for c in n.get_children():
		_hide_from_camp(c)


func _fridge_player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Room" if AudioServer.get_bus_index("Room") >= 0 else "Master"
	p.volume_db = db
	if ResourceLoader.exists(path):
		var st = load(path)
		if loop and st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			st.loop = true
		p.stream = st
	add_child(p)
	return p


## Runs a while, rests a while; a new visit finds it either way.
func _update_fridge(delta: float) -> void:
	var can := _cabin_level >= 2 and _grid_power_available and not _derelict
	if not can:
		if _fridge_on:
			_fridge_set(false, false)
		_fridge_t = randf_range(4.0, 30.0)
		return
	if _fridge_hum == null:
		_fridge_hum = _fridge_player(FRIDGE_HUM, -17.0, true)
		_fridge_knock = _fridge_player(FRIDGE_KNOCK, -15.0, false)
		_fridge_on = randf() < 0.6
		_fridge_t = randf_range(5.0, 40.0)
		if _fridge_on:
			_fridge_hum.play(randf() * 4.0)
	_fridge_t -= delta
	if _fridge_t <= 0.0:
		_fridge_set(not _fridge_on, true)
		_fridge_t = randf_range(35.0, 70.0) if _fridge_on else randf_range(20.0, 45.0)


func _fridge_set(on: bool, knock: bool) -> void:
	_fridge_on = on
	if _fridge_hum == null:
		return
	if on and not _fridge_hum.playing:
		_fridge_hum.play()
	elif not on:
		_fridge_hum.stop()
	if knock and _fridge_knock != null and _fridge_knock.stream != null:
		_fridge_knock.pitch_scale = randf_range(0.94, 1.06)
		_fridge_knock.play()


func _apply_idle_mouse_look(delta: float) -> void:
	if lodge_sleeping:
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_interior_camera.rotation = _cam_base_rot + offset
	# A/D turn the head; held on at the end of the turn, through the door that way.
	var push: int = _look.take_push()
	if push != 0:
		_switch_cabin_room(push)


func _input(event: InputEvent) -> void:
	if not _is_open or lodge_sleeping:
		return
	if _prep != null and _prep.is_scrubbing():
		return
	# Esc is the pause menu's (main): S or the way out behind you leaves (but not a
	# click on something to tidy, however low on the screen it is).
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (_prep.is_busy() and event is InputEventMouseButton):
		close_cabin()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		if _prep.is_busy():
			get_viewport().set_input_as_handled()
			return
		var tab := INTERIOR_LOOK.side_tab_at(get_viewport(), _side_hints)
		if tab != 0:
			_switch_cabin_room(tab)
			get_viewport().set_input_as_handled()
			return
		if _try_click_world(mouse_event):
			get_viewport().set_input_as_handled()
			return
		_try_click(mouse_event)
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		if key_event.physical_keycode == KEY_L:
			_toggle_manual_lights()
			get_viewport().set_input_as_handled()
			return


## The upgrade catalog on screen (normalised), wherever the head is turned.
func _catalog_screen_rect() -> Rect2:
	if _catalog_mesh != null and _catalog_mesh.is_visible_in_tree() and _viewport != null:
		var r := INTERIOR_LOOK.screen_rect_of(_interior_camera, Vector2(_viewport.size), _catalog_mesh)
		if r.has_area():
			return r.grow(0.03)
	return Rect2()


func _try_click(_event: InputEventMouseButton) -> void:
	var main_vp = get_viewport()
	if main_vp == null:
		return
	var mouse_pos = main_vp.get_mouse_position()
	var screen_size = main_vp.get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var norm = mouse_pos / screen_size

	# Upgrade catalog on table.
	if _catalog_screen_rect().has_point(norm):
		request_upgrade.emit()
		return


func _try_click_world(event: InputEventMouseButton) -> bool:
	var hit = _raycast_world(event.position)
	if hit.is_empty():
		return false
	var collider = hit.get("collider", null) as Node
	if collider == null:
		return false
	if _node_has_click_type(collider, "cabin_light_switch"):
		_toggle_manual_lights()
		return true
	if _node_has_click_type(collider, "cabin_curtain"):
		var n: Node = collider
		while n != null and not n.has_meta("portal_index"):
			n = n.get_parent()
		if n != null:
			var pt: Dictionary = _portals_now()[int(n.get_meta("portal_index"))]
			pt["curtain"].toggle()
			var im := get_parent()
			if im != null and im.has_method("coop_send_curtains"):
				im.coop_send_curtains(curtains_state())
		return true
	return false


func _node_has_click_type(node: Node, click_type: String) -> bool:
	var current = node
	while current != null:
		if str(current.get_meta("interior_click_type", "")) == click_type:
			return true
		current = current.get_parent()
	return false


func _raycast_world(mouse_pos: Vector2) -> Dictionary:
	if _interior_camera == null or _viewport == null:
		return {}
	var world = _viewport.find_world_3d()
	if world == null:
		return {}
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return {}
	var local_mouse = Vector2(
		clamp(mouse_pos.x / screen_size.x, 0.0, 1.0) * float(_viewport.size.x),
		clamp(mouse_pos.y / screen_size.y, 0.0, 1.0) * float(_viewport.size.y)
	)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_dir * 24.0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


func _build_light_switch() -> void:
	if _cabin_root == null:
		return
	_light_switch_tex_on = _pick_light_texture("cabin_switch_on", Color(0.82, 0.78, 0.66))
	_light_switch_tex_off = _pick_light_texture("cabin_switch_off", Color(0.66, 0.64, 0.58))
	var switch_body = StaticBody3D.new()
	switch_body.name = "CabinLightSwitch"
	switch_body.position = Vector3(1.38, 1.24, 0.84)
	switch_body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	switch_body.set_meta("interior_click_type", "cabin_light_switch")
	var switch_mesh = MeshInstance3D.new()
	switch_mesh.name = "SwitchVisual"
	var switch_box = BoxMesh.new()
	switch_box.size = Vector3(0.08, 0.32, 0.20)
	switch_mesh.mesh = switch_box
	var switch_mat := StandardMaterial3D.new()
	switch_mat.albedo_color = Color(0.82, 0.78, 0.66, 1.0)
	switch_mat.roughness = 0.96
	switch_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	switch_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	switch_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	switch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	switch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	switch_mat.emission_enabled = true
	switch_mat.emission = Color(0.16, 0.14, 0.10, 1.0)
	switch_mesh.material_override = switch_mat
	switch_body.add_child(switch_mesh)
	var switch_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.22, 0.46, 0.28)
	switch_shape.shape = box_shape
	switch_body.add_child(switch_shape)
	_cabin_root.add_child(switch_body)
	_light_switch_body = switch_body
	_light_switch_mesh = switch_mesh
	_apply_switch_visual()


func _pick_light_texture(category: String, color: Color) -> Texture2D:
	if _texture_style == null:
		return null
	return _texture_style.pick_texture(category, color)


func _apply_switch_visual() -> void:
	if _light_switch_mesh == null:
		return
	var switch_mat = _light_switch_mesh.material_override as StandardMaterial3D
	if switch_mat == null:
		return
	var wanted_tex: Texture2D = _light_switch_tex_on if _manual_lights_on else _light_switch_tex_off
	if wanted_tex != null:
		switch_mat.albedo_texture = wanted_tex
		switch_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		return
	switch_mat.albedo_texture = null
	switch_mat.albedo_color = Color(0.84, 0.80, 0.66, 1.0) if _manual_lights_on else Color(0.58, 0.56, 0.52, 1.0)


## A Grok sprite lying flat on the floor (a rug), or on the ceiling seen from below (the
## light, glowing).
func _flat_sprite(parent: Node3D, tex: String, size: Vector2, pos: Vector3, ceiling: bool, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	var path := "res://assets/textury/camp/" + tex + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if ceiling:
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = m.albedo_texture
		m.emission = Color(1.0, 0.94, 0.82)
		m.emission_energy_multiplier = 0.7
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _toggle_manual_lights() -> void:
	_manual_lights_on = not _manual_lights_on
	_apply_switch_visual()
	_apply_time_profile(true)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "CabinViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "CabinViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.78)
	env.ambient_light_energy = 0.98
	_room_env = env

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	# Interior-only barrel/fisheye pass.
	_barrel_overlay = ColorRect.new()
	_barrel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barrel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barrel_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	var barrel_mat = ShaderMaterial.new()
	barrel_mat.shader = INTERIOR_BARREL_SHADER
	barrel_mat.set_shader_parameter("barrel_strength", 0.0)
	barrel_mat.set_shader_parameter("vignette_strength", 0.0)
	barrel_mat.set_shader_parameter("chroma_shift", 0.0)
	_barrel_overlay.material = barrel_mat
	_barrel_overlay.material = barrel_mat
	_barrel_overlay.visible = false
	add_child(_barrel_overlay)

	_swipe_overlay = ColorRect.new()
	_swipe_overlay.name = "CabinSwipe"
	_swipe_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_overlay.color = Color(0.04, 0.05, 0.06, 0.92)
	_swipe_overlay.visible = false
	add_child(_swipe_overlay)
	_update_swipe_overlay_size()


func _sync_viewport_to_window() -> void:
	if _viewport_container != null and _viewport_container.stretch:
		return
	if _viewport == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_viewport.size = Vector2i(
		max(INTERIOR_RENDER_MIN_SIZE.x, int(screen_size.x)),
		max(INTERIOR_RENDER_MIN_SIZE.y, int(screen_size.y))
	)


func _build_cabin_room() -> void:
	_cabin_root = Node3D.new()
	_cabin_root.name = "CabinRoom"
	_viewport.add_child(_cabin_root)
	_guest_visual_root = Node3D.new()
	_guest_visual_root.name = "GuestVisuals"
	_cabin_root.add_child(_guest_visual_root)
	_light_switch_body = null
	_light_switch_mesh = null
	_bathroom_root = Node3D.new()
	_bathroom_root.name = "BathroomRoom"
	_viewport.add_child(_bathroom_root)

	_interior_camera = Camera3D.new()
	_interior_camera.name = "CabinCamera"
	_interior_camera.position = Vector3(0.0, 1.5, 1.0)
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_interior_camera.fov = 68.0
	_interior_camera.current = true
	_cabin_root.add_child(_interior_camera)

	# Warm cabin light.
	_main_light = OmniLight3D.new()
	_main_light.position = Vector3(0.0, 2.2, 0.0)
	_main_light.light_color = Color(0.96, 0.93, 0.84)
	_main_light.light_energy = 1.55
	_main_light.omni_range = 7.0
	_main_light.omni_attenuation = 1.2
	_main_light.shadow_enabled = true
	_cabin_root.add_child(_main_light)

	# The room of each tier, built from the cabin's plan (scripts/cabin_layout.gd) the way
	# the model outside is: its walls with the real openings, every window a view out with
	# a curtain, its own furniture. The three stand ready; the cabin's level shows one.
	for lv in [1, 2, 3]:
		_build_level_shell(lv)

	# Shared by every tier, at the same place in all of them: the bed (lodge_bed.gd lies in
	# it) and its pillow that room prep moves, the upgrade catalogue on the table.
	var K := INTERIOR_KIT
	K.prop(_cabin_root, "bed_wood", BED_POS)
	var pillow := K.slab(_cabin_root, Vector3(0.6, 0.12, 0.32), Vector3(BED_POS.x, BED_TOP + 0.06, BED_POS.z - 0.68), K.surface("mattress", 0.5, Color(1.0, 0.98, 0.94)), "Pillow")
	pillow.rotation.x = -0.12
	_catalog = Node3D.new()
	_catalog.name = "Catalogue"
	_cabin_root.add_child(_catalog)
	_catalog_mesh = _add_box(_catalog, "UpgradeCatalog", Vector3(0, 0.765, 0), Vector3(0.26, 0.02, 0.20), Color(0.84, 0.78, 0.68))
	for i in 3:
		_add_box(_catalog, "UpgradeCatalogInk%d" % (i + 1), Vector3(0, 0.777, -0.06 + i * 0.06), Vector3(0.18 - i * 0.02, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	var up_lbl = Label3D.new()
	up_lbl.text = "CATALOGUE"
	up_lbl.position = Vector3(0, 0.795, -0.16)
	up_lbl.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	up_lbl.font_size = 12
	up_lbl.modulate = Color(0.34, 0.28, 0.20, 0.8)
	_catalog.add_child(up_lbl)
	var bucket := K.prop(_cabin_root, "slop_bucket", SLOP_BUCKET_POS)
	bucket.name = "SlopBucket"
	_build_light_switch()
	_build_bathroom_room()
	_build_prep_props()
	_apply_level_variant()
	_apply_time_profile()


## One tier's room: the walls round the openings the plan has (the door you came in by
## in the front between two windows, the window over the table at the back, on the right
## the basic cabin's window or the better ones' bathroom door), the floor and the ceiling
## in this tier's surfaces, the windows, their curtains, the furniture.
func _build_level_shell(lv: int) -> void:
	var K := INTERIOR_KIT
	var CL := CABIN_LAYOUT
	var shell := Node3D.new()
	shell.name = "Level%d" % lv
	shell.visible = false
	_cabin_root.add_child(shell)
	_level_shells[lv] = shell
	_level_portals[lv] = []
	var inner: Vector2 = CL.inner(lv)
	var iw := inner.x
	var id := inner.y
	var t: float = CL.WALL_T
	var h: float = CL.wall_h(lv) - 0.12
	var f: float = CL.ROOM_FLOOR
	var surf: Array = LEVEL_SURFACES.get(lv, LEVEL_SURFACES[1])
	var wall := K.surface(str(surf[0]), 1.2)
	K.slab(shell, Vector3(iw, 0.1, id), Vector3(0, f - 0.05, 0), K.surface(str(surf[1]), 1.0), "Floor")
	K.slab(shell, Vector3(iw, 0.1, id), Vector3(0, f + h + 0.05, 0), K.surface(str(surf[2]), 1.0, Color(0.7, 0.66, 0.6) if lv == 1 else Color(1, 1, 1)), "Ceiling")
	# The openings in each wall: [along the wall from its left as you face it from inside,
	# bottom, width, height].
	var holes := {"front": [], "back": [], "right": [], "left": []}
	for win in CL.windows(lv):
		var c := CL.to_room(win["centre"])
		var sz: Vector2 = win["size"]
		var along := _along_wall(str(win["wall"]), c, iw, id)
		(holes[str(win["wall"])] as Array).append([along - sz.x * 0.5, c.y - sz.y * 0.5, sz.x, sz.y])
	(holes["front"] as Array).append([-CL.DOOR_W * 0.5, f, CL.DOOR_W, CL.DOOR_H])
	if CL.has_bath(lv):
		var bz: float = CL.bath_door_z(lv)
		(holes["right"] as Array).append([_along_wall("right", Vector3(0, 0, bz), iw, id) - CL.BATH_DOOR_W * 0.5, f, CL.BATH_DOOR_W, CL.BATH_DOOR_H])
	_wall_with_holes(shell, "front", iw, id, h, f, t, holes["front"], wall)
	_wall_with_holes(shell, "back", iw, id, h, f, t, holes["back"], wall)
	_wall_with_holes(shell, "right", iw, id, h, f, t, holes["right"], wall)
	_wall_with_holes(shell, "left", iw, id, h, f, t, holes["left"], wall)
	# Skirting and a cornice in dark wood, Build-style trim.
	var trim := K.surface("planks_dark", 0.6)
	for z: float in [-id * 0.5 + 0.015, id * 0.5 - 0.015]:
		K.slab(shell, Vector3(iw, 0.1, 0.03), Vector3(0, f + 0.05, z), trim, "Skirting")
		K.slab(shell, Vector3(iw, 0.06, 0.04), Vector3(0, f + h - 0.03, z), trim, "Cornice")
	for x: float in [-iw * 0.5 + 0.015, iw * 0.5 - 0.015]:
		K.slab(shell, Vector3(0.03, 0.1, id), Vector3(x, f + 0.05, 0), trim, "Skirting")
	# The door you came in by, shut behind you, its handle.
	var fz := id * 0.5
	K.slab(shell, Vector3(CL.DOOR_W + 0.14, CL.DOOR_H + 0.08, 0.05), Vector3(0, f + (CL.DOOR_H + 0.08) * 0.5, fz + 0.01), trim, "FrontDoorFrame")
	var fdoor := MeshInstance3D.new()
	fdoor.name = "FrontDoor"
	var fdq := QuadMesh.new()
	fdq.size = Vector2(CL.DOOR_W, CL.DOOR_H)
	fdoor.mesh = fdq
	fdoor.material_override = door_surface()
	fdoor.position = Vector3(0, f + CL.DOOR_H * 0.5, fz + t * 0.5)
	fdoor.rotation_degrees.y = 180.0
	shell.add_child(fdoor)
	K.slab(shell, Vector3(0.05, 0.05, 0.06), Vector3(-0.3, f + 0.95, fz + t * 0.5 - 0.03), K.surface("galvanized", 0.4), "FrontDoorHandle")
	# The windows: frames, the view out, a curtain each.
	for win in CL.windows(lv):
		_room_window(shell, lv, win)
	# The bathroom's door (closed; through it with D).
	if CL.has_bath(lv):
		var bz2: float = CL.bath_door_z(lv)
		var rx := iw * 0.5
		K.slab(shell, Vector3(0.05, CL.BATH_DOOR_H + 0.08, CL.BATH_DOOR_W + 0.14), Vector3(rx - 0.01, f + (CL.BATH_DOOR_H + 0.08) * 0.5, bz2), trim, "BathDoorFrame")
		var bdoor := MeshInstance3D.new()
		bdoor.name = "BathDoor"
		var bq := QuadMesh.new()
		bq.size = Vector2(CL.BATH_DOOR_W, CL.BATH_DOOR_H)
		bdoor.mesh = bq
		bdoor.material_override = door_surface()
		bdoor.position = Vector3(rx + t * 0.5, f + CL.BATH_DOOR_H * 0.5, bz2)
		bdoor.rotation_degrees.y = -90.0
		shell.add_child(bdoor)
	# Lived in at every tier: the warden's jacket on a hook by the door (between it and the
	# left window, clear of both), the calendar by the back window, the light.
	K.cutout(shell, "coat_hook", Vector2(0.38, 0.58), Vector3(-0.71, f + 1.0, fz - 0.03), 180.0, false, "Jacket")
	K.picture(shell, "calendar", Vector2(0.32, 0.43), Vector3(-0.92, f + 1.7, -id * 0.5 + 0.005), 0.0, "Calendar")
	if lv == 1:
		K.cutout(shell, "bulb_cord", Vector2(0.18, 0.5), Vector3(0.0, f + h - 0.25, 0.0), 0.0, true, "CeilingLamp")
	else:
		_flat_sprite(shell, "ceiling_lamp", Vector2(0.34, 0.34), Vector3(0.0, f + h - 0.005, 0.0), true, "CeilingLamp")
	_level_furniture(shell, lv, iw, id, f)


## Where a point is along a wall from inside, from its left end as you face it.
func _along_wall(which: String, p: Vector3, _iw: float, _id: float) -> float:
	match which:
		"front":
			return -p.x
		"back":
			return p.x
		"right":
			return p.z
		_:
			return -p.z


## A wall of the room with its openings: slabs round each hole (beside, under, over).
func _wall_with_holes(parent: Node3D, which: String, iw: float, id: float, h: float, f: float, t: float, holes: Array, mat: Material) -> void:
	var length := iw + 2.0 * t if which in ["front", "back"] else id
	var pieces: Array = []      # [u0, u1, y0, y1]
	var sorted := holes.duplicate()
	sorted.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var u := -length * 0.5
	for hole in sorted:
		var u0: float = hole[0]
		var u1: float = u0 + float(hole[2])
		var y0: float = hole[1]
		var y1: float = y0 + float(hole[3])
		if u0 > u + 0.001:
			pieces.append([u, u0, f, f + h])
		if y0 > f + 0.001:
			pieces.append([u0, u1, f, y0])
		if y1 < f + h - 0.001:
			pieces.append([u0, u1, y1, f + h])
		u = u1
	if u < length * 0.5 - 0.001:
		pieces.append([u, length * 0.5, f, f + h])
	var i := 0
	for pc in pieces:
		var u_mid: float = (float(pc[0]) + float(pc[1])) * 0.5
		var w: float = float(pc[1]) - float(pc[0])
		var y_mid: float = (float(pc[2]) + float(pc[3])) * 0.5
		var hh: float = float(pc[3]) - float(pc[2])
		var pos: Vector3
		var size: Vector3
		match which:
			"front":
				pos = Vector3(-u_mid, y_mid, id * 0.5 + t * 0.5)
				size = Vector3(w, hh, t)
			"back":
				pos = Vector3(u_mid, y_mid, -id * 0.5 - t * 0.5)
				size = Vector3(w, hh, t)
			"right":
				pos = Vector3(iw * 0.5 + t * 0.5, y_mid, u_mid)
				size = Vector3(t, hh, w)
			_:
				pos = Vector3(-iw * 0.5 - t * 0.5, y_mid, -u_mid)
				size = Vector3(t, hh, w)
		INTERIOR_KIT.slab(parent, size, pos, mat, "Wall%s%d" % [which.capitalize(), i])
		i += 1


## A window of the room: its pine frame in the opening, the view out (a camera through
## the same window of the cabin outside, _update_portals), a curtain to draw.
func _room_window(shell: Node3D, lv: int, win: Dictionary) -> void:
	var K := INTERIOR_KIT
	var CL := CABIN_LAYOUT
	var c := CL.to_room(win["centre"])
	var sz: Vector2 = win["size"]
	var out: Vector3 = win["out"]
	var yaw_out := rad_to_deg(atan2(out.x, out.z))
	var frame_mat := K.surface("knotty_pine", 0.6) if lv >= 2 else K.surface("planks_grey", 0.6, Color(0.82, 0.78, 0.7))
	var holder := Node3D.new()
	holder.name = "Window_" + str(win["id"])
	holder.position = c - out * (CL.WALL_T * 0.5)
	holder.rotation_degrees.y = yaw_out + 180.0
	shell.add_child(holder)
	# (Faces the room: +Z of the holder is into the room.)
	K.slab(holder, Vector3(sz.x + 0.12, 0.06, 0.16), Vector3(0, -sz.y * 0.5 - 0.03, 0.02), frame_mat, "Sill")
	K.slab(holder, Vector3(sz.x + 0.12, 0.06, CL.WALL_T + 0.02), Vector3(0, sz.y * 0.5 + 0.03, 0.0), frame_mat, "Top")
	for x: float in [-sz.x * 0.5 - 0.03, sz.x * 0.5 + 0.03]:
		K.slab(holder, Vector3(0.06, sz.y + 0.12, CL.WALL_T + 0.02), Vector3(x, 0, 0), frame_mat, "Side")
	K.slab(holder, Vector3(0.035, sz.y, 0.04), Vector3(0, 0, -CL.WALL_T * 0.5 + 0.03), frame_mat, "Mullion")
	K.slab(holder, Vector3(sz.x, 0.035, 0.04), Vector3(0, sz.y * 0.12, -CL.WALL_T * 0.5 + 0.03), frame_mat, "Transom")
	# The view: in the opening at the wall's outer face, where the glass is outside.
	var glass_at := c + out * (CL.WALL_T * 0.5 - 0.005)
	var curtain_tex := ["curtain_floral", "curtain_floral", "velvet"][lv - 1] as String
	_add_portal(shell, lv, "View_" + str(win["id"]), glass_at, out, sz, curtain_tex)


## The furniture that makes each tier's step up seen at once: bare boards and a bucket;
## then a wardrobe, a lamp over the bed, a fridge and a poster; then a rug, a stove under
## the chimney outside, the TV on a chest under the aerial, a shelf, a second chair, a
## picture and a bedside table.
func _level_furniture(shell: Node3D, lv: int, iw: float, id: float, f: float) -> void:
	var K := INTERIOR_KIT
	var back := -id * 0.5
	var front := id * 0.5
	var left := -iw * 0.5
	var right := iw * 0.5
	var table := Vector3(right - 0.62, f, back + 0.5)
	K.prop(shell, "table_wood", table)
	K.prop(shell, "chair_wood", table + Vector3(0, 0, 0.56), 180.0)
	_level_tables[lv] = table
	if lv >= 2:
		# By the door on the left; in the best cabin the stove has that corner and the
		# wardrobe stands along the wall past the bed's foot.
		var wz := (front - 0.62) if lv == 2 else (BED_POS.z + 1.4)
		K.prop(shell, "wardrobe", Vector3(left + 0.3, f, wz), 90.0)
		K.prop(shell, "wall_lamp", Vector3(left + 0.02, f + 1.45, BED_POS.z - 0.45), 90.0)
		var fridge := K.prop(shell, "fridge_small", Vector3(right - 0.3, f, front - 0.42), -90.0)
		fridge.name = "FridgeSmall"
	if lv == 2:
		K.picture(shell, "poster_lake", Vector2(0.48, 0.64), Vector3(right - 0.005, f + 1.5, back + 0.42), -90.0, "PosterLake")
	if lv == 3:
		_flat_sprite(shell, "rug_rag", Vector2(1.4, 1.05), Vector3(0.15, f + 0.007, 0.05), false, "Rug")
		K.prop(shell, "wall_shelf", Vector3(table.x, f + 1.42, back + 0.1))
		K.prop(shell, "chair_wood", table + Vector3(-0.56, 0, 0.05), 95.0)
		K.prop(shell, "nightstand", Vector3(left + 0.25, f, back + 0.2), 90.0)
		K.picture(shell, "picture_deer", Vector2(0.5, 0.66), Vector3(left + 0.005, f + 1.55, BED_POS.z + 0.15), 90.0, "PictureDeer")
		var chest := K.prop(shell, "dresser", Vector3(right - 0.24, f, 0.55), -90.0)
		chest.name = "TvChest"
		K.prop(shell, "tv_small", Vector3(right - 0.24, f + 0.77, 0.55), -90.0)
		_level_stove(shell, Vector3(left + 0.32, f, CABIN_LAYOUT.size(3).y * 0.5 - CABIN_LAYOUT.STOVE_FROM_FRONT), f + CABIN_LAYOUT.wall_h(3) - 0.12)


## The cast-iron stove of the best cabin under its chimney outside (building_models.cabin
## Lv3), its pipe up into the ceiling, a tin sheet under it.
func _level_stove(shell: Node3D, at: Vector3, ceiling: float) -> void:
	var K := INTERIOR_KIT
	var st := Node3D.new()
	st.name = "Stove"
	st.position = at
	st.rotation_degrees.y = 90.0
	shell.add_child(st)
	var iron := K.surface("planks_dark", 0.4, Color(0.34, 0.24, 0.18))
	K.slab(st, Vector3(0.44, 0.86, 0.4), Vector3(0, 0.43, 0), iron, "StoveBody")
	K.slab(st, Vector3(0.48, 0.035, 0.44), Vector3(0, 0.875, 0), K.surface("galvanized", 0.3, Color(0.22, 0.2, 0.2)), "StoveTop")
	K.picture(st, "stove", Vector2(0.44, 0.86), Vector3(0, 0.43, 0.202), 0.0, "StoveFace")
	var pipe := MeshInstance3D.new()
	pipe.name = "StovePipe"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = ceiling - at.y - 0.89
	cm.radial_segments = 8
	pipe.mesh = cm
	pipe.material_override = K.surface("galvanized", 0.3, Color(0.18, 0.17, 0.17))
	pipe.position = Vector3(0, 0.89 + cm.height * 0.5, -0.06)
	st.add_child(pipe)
	K.slab(st, Vector3(0.66, 0.008, 0.68), Vector3(0, 0.004, 0.12), K.surface("galvanized", 0.5, Color(0.55, 0.52, 0.48)), "StoveSheet")


## The cabin as the last guests left it: the blanket kicked into a heap with the pillow
## on the floor, empty bottles by the bed, and a toilet (or the bucket) nobody cleaned.
func _build_prep_props() -> void:
	var P := INTERIOR_PREP
	var blanket := P.camp_material("blanket_check.png", Color(0.9, 0.86, 0.8))
	var b := BED_POS
	var top := BED_TOP
	var heap_a := P.box(_cabin_root, Vector3(b.x + 0.02, top + 0.09, b.z + 0.35), Vector3(0.72, 0.2, 0.6), blanket, Vector3(0.1, 0.4, -0.12))
	var heap_b := P.box(_cabin_root, Vector3(b.x - 0.05, top + 0.04, b.z - 0.35), Vector3(0.6, 0.1, 0.5), blanket, Vector3(0.0, -0.3, 0.08))
	var pillow_floor := P.box(_cabin_root, Vector3(-0.3, 0.11, -0.15), Vector3(0.6, 0.1, 0.3), P.flat(Color(0.7, 0.7, 0.7)), Vector3(0.0, 0.7, 0.25))
	var made := P.box(_cabin_root, Vector3(b.x, top + 0.025, b.z + 0.18), Vector3(0.84, 0.05, 1.3), blanket)
	var made_fold := P.box(_cabin_root, Vector3(b.x, top + 0.04, b.z - 0.42), Vector3(0.84, 0.07, 0.14), P.flat(Color(0.88, 0.86, 0.8)))
	var pillow_bed := _cabin_root.get_node_or_null("Pillow")
	var bed_body := P.body(_cabin_root, Vector3(b.x, 0.4, b.z), Vector3(1.0, 0.7, 1.9))
	_prep.register("bed", bed_body, [heap_a, heap_b, pillow_floor], [made, made_fold, pillow_bed])

	# Where the mess can be this time (core/systems/mess_rules.gd ROOM_SPOTS, BATH_SPOTS).
	for spot in [["f1", Vector3(-0.35, 0.04, -1.15)], ["f2", Vector3(0.05, 0.04, -0.5)], ["f3", Vector3(0.4, 0.04, 0.0)],
			["f4", Vector3(-0.42, 0.04, 0.05)], ["f5", Vector3(0.75, 0.04, -0.3)], ["f6", Vector3(0.9, 0.04, 0.12)]]:
		_prep.add_spot(spot[0], _cabin_root, spot[1])
	# The toilet seat top, the basin, the floor in front of them.
	_prep.add_spot("wc", _bathroom_root, BATH_WC + Vector3(-0.06, 0.45, 0))
	_prep.add_spot("sink", _bathroom_root, BATH_SINK + Vector3(0, 0.92, -0.04))
	_prep.add_spot("bfloor", _bathroom_root, Vector3(0.05, 0.04, 0.1))
	_prep.add_spot("pail", _cabin_root, SLOP_BUCKET_POS + Vector3(0, 0.31, 0))
	# The back-left corner over the bed, across it at 45 degrees (the old cabin's cobwebs).
	var corner: Vector2 = CABIN_LAYOUT.inner(1) * 0.5
	_prep.add_spot("w1", _cabin_root, Vector3(-corner.x + 0.354, 2.07, -corner.y + 0.354), deg_to_rad(45.0), true)
	_prep.setup_tasks(self, _interior_camera, _viewport, "cabin")
	_prep.task_completed.connect(func(id: String): room_task_completed.emit(id))


# ── room preparation (see scripts/interior_prep.gd) ──────────────────────────

func set_room(room: Dictionary) -> void:
	_set_derelict(_is_derelict(str(room.get("key", ""))))
	_prep.set_room(room)


## The old cabin at the start (main._place_ruined_cabin) until it is patched up outside:
## the window boarded up from inside as well, and the bulb dead (the torch comes on).
var _derelict := false


func _is_derelict(key: String) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or key.is_empty():
		return false
	return bool((state.failures.get(key, {}) as Dictionary).get("derelict", false))


func _set_derelict(on: bool) -> void:
	if _cabin_root == null:
		return
	var boards := _cabin_root.get_node_or_null("RuinBoards")
	if on and boards == null:
		boards = Node3D.new()
		boards.name = "RuinBoards"
		_cabin_root.add_child(boards)
		var plank := INTERIOR_KIT.surface("planks_grey", 0.5, Color(0.9, 0.8, 0.66))
		var bw: Vector3 = CABIN_LAYOUT.to_room((CABIN_LAYOUT.windows(1)[2] as Dictionary)["centre"])
		bw.z = -CABIN_LAYOUT.inner(1).y * 0.5 + 0.1
		for b in [[Vector3(1.24, 0.13, 0.03), bw + Vector3(0.0, 0.2, 0.0), 0.2],
				[Vector3(1.2, 0.12, 0.03), bw + Vector3(0.03, -0.16, 0.01), -0.16],
				[Vector3(1.16, 0.12, 0.03), bw + Vector3(-0.02, 0.02, 0.02), 0.05]]:
			var s := INTERIOR_KIT.slab(boards, b[0], b[1], plank, "Board")
			s.rotation.z = float(b[2])
	elif not on and boards != null:
		boards.queue_free()
	if on != _derelict:
		_derelict = on
		# The whole profile again: the bulb's energy is built up from the time of day.
		_apply_time_profile(false)


func play_room_ready() -> void:
	_prep.play_room_ready()


## The bathroom built on at the right (Lv2+), inside the annex outside (CabinLayout
## ANNEX): its own room, through the door in the cabin's right wall (D). Its middle is
## its origin; it is moved to where the annex is for the cabin's width.
const BATH_WC := Vector3(0.48, 0.05, -0.5)
const BATH_SINK := Vector3(0.0, 0.05, 0.7)


func _build_bathroom_room() -> void:
	if _bathroom_root == null:
		return
	var K := INTERIOR_KIT
	var CL := CABIN_LAYOUT
	var box: AABB = CL.annex_box(2)
	var w: float = box.size.x - CL.WALL_T
	var d: float = box.size.z - CL.WALL_T * 2.0
	var h := 2.0
	var shell := K.room(_bathroom_root, Vector3(w, h, d), "tiles_green", "oil_wall", "ceiling_board", h, 0.8)
	for key in shell.keys():
		(shell[key] as Node3D).position.y += CL.ROOM_FLOOR
	_bath_shell = shell
	# The toilet against the outer wall, the basin on the back wall with its mirror, the
	# shower corner of the best cabin, the frosted window high in the outer wall.
	var wc := K.prop(_bathroom_root, "toilet", BATH_WC, -90.0)
	wc.name = "ToiletLv2"
	var sink := K.prop(_bathroom_root, "sink_pedestal", BATH_SINK, 180.0)
	sink.name = "SinkLv2"
	var mirror := K.prop(_bathroom_root, "mirror_frame", BATH_SINK + Vector3(0, 1.25, 0.1), 180.0)
	mirror.name = "SinkMirror"
	var shower := K.prop(_bathroom_root, "shower_corner", Vector3(-w * 0.5 + 0.42, CL.ROOM_FLOOR, -d * 0.5 + 0.42), 0.0)
	shower.name = "ShowerCorner"
	K.picture(_bathroom_root, "glass_blocks", CL.BATH_WIN, Vector3(w * 0.5 - 0.005, CL.ROOM_FLOOR + 1.62, 0.0), -90.0, "BathWindow")
	# Newspaper squares on a nail by the toilet.
	K.slab(_bathroom_root, Vector3(0.015, 0.18, 0.14), Vector3(w * 0.5 - 0.01, CL.ROOM_FLOOR + 0.85, -0.05), INTERIOR_PREP.flat(Color(0.82, 0.8, 0.72)), "Newspaper")


## The bathroom's middle for this tier (the annex is beside the cabin's right wall).
func _bath_origin() -> Vector3:
	var CL := CABIN_LAYOUT
	var box: AABB = CL.annex_box(maxi(2, _cabin_level))
	var inner_x := CL.size(_cabin_level).x * 0.5
	return Vector3(inner_x + (box.size.x - CL.WALL_T) * 0.5, 0.0, box.position.z + box.size.z * 0.5)


func _apply_level_variant() -> void:
	var CL := CABIN_LAYOUT
	for lv in _level_shells.keys():
		(_level_shells[lv] as Node3D).visible = int(lv) == _cabin_level
	var inner: Vector2 = CL.inner(_cabin_level)
	var h: float = CL.wall_h(_cabin_level) - 0.12
	if _main_light != null:
		_main_light.position = Vector3(0.0, CL.ROOM_FLOOR + h - 0.3, 0.0)
	if _catalog != null and _level_tables.has(_cabin_level):
		_catalog.position = (_level_tables[_cabin_level] as Vector3) + Vector3(0.05, 0.0, 0.0)
	if _light_switch_body != null:
		_light_switch_body.position = Vector3(0.62, CL.ROOM_FLOOR + 1.2, inner.y * 0.5 - 0.02)
	_set_node_visible("SlopBucket", _cabin_level == 1)
	if _bathroom_root != null:
		_bathroom_root.position = _bath_origin()
		if not _bath_shell.is_empty():
			var bath_wall := INTERIOR_KIT.surface("tiles_bathroom", 0.9) if _cabin_level >= 3 else INTERIOR_KIT.surface("oil_wall", 2.0)
			for key in ["back", "front", "left", "right"]:
				(_bath_shell[key] as MeshInstance3D).material_override = bath_wall
	_set_bathroom_variant()


func _set_bathroom_variant() -> void:
	if _bathroom_root == null:
		return
	var lv = _cabin_level
	_set_node_visible_in(_bathroom_root, "ToiletLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkMirror", lv >= 2)
	_set_node_visible_in(_bathroom_root, "ShowerCorner", lv == 3)


func _refresh_level_textures() -> void:
	if _cabin_root == null or _texture_style == null:
		return
	for child in _cabin_root.get_children():
		var mesh_inst = child as MeshInstance3D
		if mesh_inst == null:
			continue
		var std_mat = mesh_inst.material_override as StandardMaterial3D
		if std_mat == null:
			continue
		var category = _category_for_node(mesh_inst.name, std_mat.albedo_color)
		var tex = _texture_style.pick_texture(category, std_mat.albedo_color)
		if tex != null:
			std_mat.albedo_texture = tex
			std_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)


func _cabin_level_category(slot: String) -> String:
	var lv = _cabin_level
	# Swap Lv2 (Red) and Lv3 (Blue) materials/textures as requested
	if lv == 2: lv = 3
	elif lv == 3: lv = 2
	return "cabin_lv%d_%s" % [lv, slot]


func _set_node_visible(node_name: String, visible_flag: bool) -> void:
	if _cabin_root == null:
		return
	var node = _cabin_root.get_node_or_null(node_name) as Node3D
	if node != null:
		node.visible = visible_flag


func _set_node_visible_in(parent: Node, node_name: String, visible_flag: bool) -> void:
	if parent == null:
		return
	var node = parent.get_node_or_null(node_name) as Node3D
	if node != null:
		node.visible = visible_flag


func _switch_cabin_room(direction: int) -> void:
	if _swipe_animating:
		return
	var target = "main"
	if _active_room == "main" and direction > 0:
		if _cabin_level >= 2:
			target = "bathroom"
		else:
			print("[CabinInterior] Bathroom not available for Level 1 cabin.")
			return
	elif _active_room == "bathroom" and direction < 0:
		target = "main"
	
	if target == _active_room:
		return
	_play_room_swipe(target, direction)


func _play_room_swipe(target_room: String, direction: int) -> void:
	if _swipe_overlay == null:
		_set_cabin_room(target_room, true)
		return
	_update_swipe_overlay_size()
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		_set_cabin_room(target_room, true)
		return
	# The room you leave slides away as the next slides in (scripts/ui/room_push.gd).
	_swipe_animating = true
	_swipe_overlay.visible = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	_swipe_tween = ROOM_PUSH.play(self, _viewport_container, _viewport, direction,
		Callable(self, "_set_cabin_room").bind(target_room, true), Callable(self, "_finish_room_swipe"))


func _finish_room_swipe() -> void:
	_swipe_animating = false
	if _swipe_overlay != null:
		_swipe_overlay.visible = false


func _update_swipe_overlay_size() -> void:
	if _swipe_overlay == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_swipe_overlay.size = Vector2(screen_size.x * 1.18, screen_size.y)


func _set_cabin_room(room: String, update_camera: bool = true) -> void:
	if _cabin_root == null or _bathroom_root == null:
		return
	if room != _active_room:
		_look.reset()
	_active_room = room
	_cabin_root.visible = (room == "main")
	_bathroom_root.visible = (room == "bathroom")
	
	if update_camera and _interior_camera != null:
		if room == "bathroom":
			# In from the cabin's door, facing the outer wall (the toilet, the window).
			var bo := _bath_origin()
			var bw: float = CABIN_LAYOUT.annex_box(2).size.x - CABIN_LAYOUT.WALL_T
			# (From the doorway itself: the room is a metre and a half across.)
			_interior_camera.position = Vector3(bo.x - bw * 0.5 - 0.06, CABIN_LAYOUT.ROOM_FLOOR + 1.5, CABIN_LAYOUT.bath_door_z(_cabin_level))
			_interior_camera.rotation_degrees = Vector3(-9.0, -90.0, 0.0)
		else:
			# Just in by the front door, looking in at the back window.
			_interior_camera.position = Vector3(0.0, CABIN_LAYOUT.ROOM_FLOOR + 1.47, CABIN_LAYOUT.inner(_cabin_level).y * 0.5 - 0.42)
			_interior_camera.rotation_degrees = Vector3(MAIN_PITCH_DEG, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation
	_look.reset()


func _set_node_color(node_name: String, color: Color) -> void:
	if _cabin_root == null:
		return
	var mesh_inst = _cabin_root.get_node_or_null(node_name) as MeshInstance3D
	if mesh_inst == null:
		return
	var shader_mat = mesh_inst.material_override as ShaderMaterial
	if shader_mat != null:
		shader_mat.set_shader_parameter("base_color", color)
		return
	var std_mat = mesh_inst.material_override as StandardMaterial3D
	if std_mat != null and std_mat.albedo_texture == null:
		std_mat.albedo_color = color


func _apply_time_profile(animated: bool = false) -> void:
	if _room_env != null:
		match _time_state:
			TIME_DAY:
				_room_env.background_color = Color(0.62, 0.66, 0.70)
				_room_env.ambient_light_color = Color(0.78, 0.82, 0.78)
				_room_env.ambient_light_energy = 0.98
			TIME_EVENING:
				_room_env.background_color = Color(0.24, 0.20, 0.22)
				_room_env.ambient_light_color = Color(0.48, 0.42, 0.44)
				_room_env.ambient_light_energy = 0.52
			_:
				_room_env.background_color = Color(0.08, 0.10, 0.14)
				_room_env.ambient_light_color = Color(0.22, 0.26, 0.34)
				_room_env.ambient_light_energy = 0.04

	if _main_light != null:
		match _time_state:
			TIME_DAY:
				_main_light.light_color = Color(1.0, 0.96, 0.86)
				_main_light.light_energy = 1.66
			TIME_EVENING:
				_main_light.light_color = Color(0.92, 0.76, 0.64)
				_main_light.light_energy = 0.84
			_:
				_main_light.light_color = Color(0.66, 0.72, 0.90)
				_main_light.light_energy = 0.08

	if _window_view_sky != null:
		var sky_mat = _window_view_sky.material_override as StandardMaterial3D
		if sky_mat != null:
			match _time_state:
				TIME_DAY:
					sky_mat.albedo_color = Color(1.0, 1.0, 1.0)
				TIME_EVENING:
					sky_mat.albedo_color = Color(0.86, 0.6, 0.48)
				_:
					sky_mat.albedo_color = Color(0.1, 0.13, 0.22)

	if _window_view_ground != null:
		var ground_mat = _window_view_ground.material_override as StandardMaterial3D
		if ground_mat != null:
			match _time_state:
				TIME_DAY:
					ground_mat.albedo_color = Color(0.30, 0.48, 0.28)
				TIME_EVENING:
					ground_mat.albedo_color = Color(0.36, 0.28, 0.22)
				_:
					ground_mat.albedo_color = Color(0.08, 0.14, 0.10)

	if _window_view_trees != null:
		var trees_mat = _window_view_trees.material_override as StandardMaterial3D
		if trees_mat != null:
			match _time_state:
				TIME_DAY:
					trees_mat.albedo_color = Color(0.14, 0.30, 0.16)
				TIME_EVENING:
					trees_mat.albedo_color = Color(0.20, 0.18, 0.14)
				_:
					trees_mat.albedo_color = Color(0.05, 0.08, 0.10)

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _room_env != null:
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(sun_tint, 0.16 * daylight)
		_room_env.ambient_light_energy = lerpf(_room_env.ambient_light_energy * 0.82, _room_env.ambient_light_energy * 1.18, daylight)
	if _main_light != null:
		_main_light.light_color = _main_light.light_color.lerp(sun_tint, 0.10 * daylight)
		_main_light.light_energy = lerpf(_main_light.light_energy * 0.88, _main_light.light_energy * 1.10, daylight)
	if _window_view_sky != null:
		var sky_mat = _window_view_sky.material_override as StandardMaterial3D
		if sky_mat != null:
			sky_mat.albedo_color = sky_mat.albedo_color.lerp(sun_tint, 0.22 * daylight)
	# The old cabin while it is boarded up: only what gets in round the boards, grey-green.
	if _derelict and _room_env != null:
		_room_env.ambient_light_energy *= 0.36
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(Color(0.5, 0.56, 0.46), 0.5)
	_apply_manual_light_profile(animated)


func _refresh_guest_visuals() -> void:
	if _guest_visual_root == null:
		return
	for child in _guest_visual_root.get_children():
		child.queue_free()

	if _guest_occupants.is_empty():
		return

	var sorted = _guest_occupants.duplicate(true)
	sorted.sort_custom(func(a, b):
		var da = a if a is Dictionary else {}
		var db = b if b is Dictionary else {}
		var slot_a = int(da.get("slot_index", 0))
		var slot_b = int(db.get("slot_index", 0))
		if slot_a == slot_b:
			return int(da.get("guest_id", 0)) < int(db.get("guest_id", 0))
		return slot_a < slot_b
	)

	for i in range(sorted.size()):
		var entry_any = sorted[i]
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var sprite = _create_guest_sprite(entry)
		if sprite == null:
			continue
		var stand_pos = CABIN_GUEST_STAND_POINTS[min(i, CABIN_GUEST_STAND_POINTS.size() - 1)]
		if i >= CABIN_GUEST_STAND_POINTS.size():
			stand_pos += Vector3(0.12 * float(i - CABIN_GUEST_STAND_POINTS.size() + 1), 0.0, 0.0)
		sprite.position = stand_pos
		_guest_visual_root.add_child(sprite)


func _create_guest_sprite(entry: Dictionary) -> Sprite3D:
	var sprite = Sprite3D.new()
	var texture = _resolve_guest_texture(entry)
	if texture == null:
		return null
	sprite.texture = texture
	sprite.pixel_size = CABIN_GUEST_SPRITE_PIXEL_SIZE
	sprite.shaded = false
	sprite.double_sided = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fit_sprite_height(sprite, texture, CABIN_GUEST_TARGET_HEIGHT)
	return sprite


func _resolve_guest_texture(entry: Dictionary) -> Texture2D:
	var archetype = str(entry.get("archetype", "quiet_guy")).to_lower().strip_edges()
	match archetype:
		"drunk":
			return HOST_DRUNK_TEXTURE
		"cheap_chick", "cheapchick":
			return HOST_CHEAP_TEXTURE
		"tramp", "family", "picker":
			var path := "res://assets/textury/npc/%s.png" % {"tramp": "host_tramp", "family": "host_family", "picker": "host_pensioner"}[archetype]
			if ResourceLoader.exists(path):
				return load(path)
			return HOST_QUIET_TEXTURE
		_:
			return HOST_QUIET_TEXTURE


func _fit_sprite_height(sprite: Sprite3D, texture: Texture2D, target_height: float) -> void:
	if sprite == null or texture == null:
		return
	var tex_height = max(1.0, float(texture.get_height()))
	var base_world_height = tex_height * sprite.pixel_size
	if base_world_height <= 0.0001:
		return
	var scale_factor = target_height / base_world_height
	sprite.scale = Vector3.ONE * scale_factor


func _apply_manual_light_profile(animated: bool) -> void:
	if _main_light == null:
		return
	var target_energy = _main_light.light_energy
	if not _manual_lights_on:
		target_energy *= 0.10
	elif _time_state != TIME_DAY and _grid_power_available:
		# After dusk the bulb lights the room, not the window (the night profile above
		# is the moon through it): warm, and enough to see the corners.
		target_energy = maxf(target_energy, 1.15)
		_main_light.light_color = Color(1.0, 0.88, 0.68)
		if _room_env != null:
			_room_env.ambient_light_energy = maxf(_room_env.ambient_light_energy, 0.3)
	if not _grid_power_available or _derelict:
		target_energy = 0.0
	if animated:
		if _manual_light_tween != null and is_instance_valid(_manual_light_tween):
			_manual_light_tween.kill()
		_manual_light_tween = create_tween()
		_manual_light_tween.set_ease(Tween.EASE_IN_OUT)
		_manual_light_tween.set_trans(Tween.TRANS_SINE)
		_manual_light_tween.tween_property(_main_light, "light_energy", target_energy, 0.56)
		return
	_main_light.light_energy = target_energy


func _add_box(parent: Node, node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = node_name
	var box = BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var category = _category_for_node(node_name, color)
	var uv_scale = Vector3(max(1.0, box_size.x * 1.6), 1.0, max(1.0, box_size.z * 1.6))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = uv_scale
	if _texture_style != null:
		var tex = _texture_style.pick_texture(category, color)
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat

	parent.add_child(mesh_inst)
	return mesh_inst


func _category_for_node(node_name: String, color: Color) -> String:
	var n = node_name.to_lower()
	if n.contains("catalog"):
		return "decor_paper"
	if n.contains("wallpicture"):
		return "cabin_lv3_front"
	if n.contains("fridge") or n.contains("lamp"):
		return _cabin_level_category("metal")
	if n.contains("tvscreen"):
		return "cabin_lv3_front"
	if n.contains("tvbody") or n.contains("tvantenna"):
		return "cabin_lv3_side"
	if n.contains("mattress") or n.contains("pillow"):
		return _cabin_level_category("bed")
	if n.contains("floor") or n.contains("rug"):
		return _cabin_level_category("floor")
	if n.contains("chest"):
		return _cabin_level_category("drawer") if _cabin_level >= 2 else _cabin_level_category("wood")
	if n.contains("door") or n.contains("frame") or n.contains("table") or n.contains("shelf") or n.contains("bed"):
		return _cabin_level_category("wood")
	if n.contains("wall") or n.contains("ceiling"):
		return _cabin_level_category("wall")
	if color.s < 0.20 and color.v > 0.65:
		return "stone"
	return _cabin_level_category("wood")


## The torch comes on in here by itself when the room is dark (if it is on, F).
func _update_torch(delta: float) -> void:
	if _torch == null:
		_torch = INTERIOR_TORCH.new()
		_torch.name = "Torch"
		add_child(_torch)
		_torch.setup(_interior_camera, _viewport, _interior_camera.get_parent() as Node3D, layer)
	_torch.update(delta, room_is_dark())


## After dusk with the lights off (L) or the camp's power gone.
func room_is_dark() -> bool:
	return _derelict or (_time_state != TIME_DAY and (not _manual_lights_on or not _grid_power_available))
