extends Control

## Builder 98's hidden 3D view (the user, 21. 10.: "a lightly hidden but in-sight button
## in the Builder: the 2D isometric sprites switch to a normal bird's-eye view, a strategy
## in 3D; the Builder keeps all it does"). The button is the grip in the status bar's
## corner (builder_module._build_grip), drawn as a little cube of grip dots.
##
## The map panel (crt_map_panel.gd) keeps every tool, rule and request. While `on`, its
## point -> cell, cell -> point, guest picking, centring, pan and zoom come here
## (`map3d` hooks there), and this shows instead of its two layers:
##   the view    the camp's own world (the 3D models you walk among) from a strategy
##               camera of its own, at half the PC's pixels through the Build palette
##               (materials/builder3d_view.gdshader), in and out in an ordered dither;
##   the plates  every tile a tool talks about as a plate on the ground (one MultiMesh,
##               materials/builder3d_plate.gdshader): the ghost's footprint, a path or a
##               row being dragged, the bulldozer's box, the building whose card is open,
##               an overlay's colours, the light a lamp would give;
##   the ghost   the building in hand as a blueprint of its real model (building_models,
##               stripped to its meshes; materials/builder3d_ghost.gdshader); what you
##               build rises the same way where it lands;
##   the paper   in the PC's pixels on top: the price tags, the pops and dust, the guests'
##               thoughts, an overlay's labels, the compass and a top-down minimap.
## In and out: the camera starts from the 2D map's own angle (30 degrees down, the
## quarter it was turned, the same scale through a long lens) and lands as a strategy
## camera; on the way out it goes back to the nearest quarter and the map picks up there.
##
## Mouse: right drag pans (the ground stays under the pointer), middle drag turns and
## tilts, the wheel zooms to the pointer; T a quarter round; arrows pan. A click on the
## compass turns north up again.

signal left_3d

const BUILDING_MODELS = preload("res://scripts/building_models.gd")
const GOD = preload("res://scripts/god/god_cursor.gd")
const RETRO = preload("res://scripts/retro_materials.gd")
const T = preload("res://scripts/os98/os_theme.gd")
const VIEW_SHADER := preload("res://materials/builder3d_view.gdshader")
const PLATE_SHADER := preload("res://materials/builder3d_plate.gdshader")
const GHOST_SHADER := preload("res://materials/builder3d_ghost.gdshader")
const LUT := preload("res://assets/textury/palette/build_palette_lut.png")

## The strategy camera: its tilt, its lens, how near and far (metres to the point it looks
## at), and the ceiling (the cloud deck is at 95 m, in a storm 58 m).
const PITCH_MIN := deg_to_rad(26.0)
const PITCH_MAX := deg_to_rad(74.0)
const PITCH_DEF := deg_to_rad(47.0)
const FOV := 42.0
const DIST_MIN := 7.0
## Free to roam (the user, 21. 10.: "let me drive the camera wherever I want, to the map's
## edges, to the Liblice masts: we can look the map over like that"): the whole land of
## data/geo/world.json (x east, z south, metres from the camp), far out and high up.
const DIST_MAX := 1600.0
const CEILING := 1400.0
const ROAM := Rect2(-2150.0, -2450.0, 6600.0, 4500.0)
## The 2D map's camera, matched: 30 degrees down; through a long lens from where the
## clouds do not get in the way.
const ISO_PITCH := deg_to_rad(30.0)
const ISO_FOV_MIN := 16.0
const ISO_DIST_MAX := 150.0
const ENTER_SEC := 1.25
const LEAVE_SEC := 0.8
const DITHER_SEC := 0.4
## The view at half the PC's pixels (about the world view's 240 lines on the monitor).
const PX := 2
const PLATE_Y := 0.1
const MAX_PLATES := 900
const BLUE := Color(0.55, 0.85, 1.0)
const AMBER := Color(1.0, 0.78, 0.36)
const RED := Color(1.0, 0.36, 0.3)
const GOLD := Color(1.0, 0.92, 0.5)
const LAMP := Color(1.0, 0.82, 0.42)
## A lamp's and a fire's light, in tiles (the 2D map's LIGHT_REACH, as plates).
const REACH := {"lamp_post": 2.6, "bonfire": 3.4}
const MINI_CELL := 3.0

var panel: Control          # crt_map_panel.gd, the parent
var on := false             # the 3D view is the map (landed: it takes the map's input)
var _mode := 0              # 0 off, 1 coming in, 2 in, 3 going out
var _t := 0.0
var _from: Dictionary = {}
var _to: Dictionary = {}

var _vp: SubViewport
var _cam: Camera3D
var _view: TextureRect
var _view_mat: ShaderMaterial
var _over: Control
var _plates: MultiMeshInstance3D
var _env_t := 0.0

var _f := Vector3.ZERO      # the ground point looked at
var _ft := Vector3.ZERO
var _yaw := 0.0
var _yaw_t := 0.0
var _pitch := PITCH_DEF
var _pitch_t := PITCH_DEF
var _dist := 40.0
var _dist_t := 40.0
var _fov := FOV
var _vel := Vector3.ZERO
var _last_pan := 0.0
var _orbit := false
var _mini_drag := false
var _placed_once := false

var _ghost_type := ""
var _ghost: Node3D
var _ghost_mat: ShaderMaterial
var _ghost_h := 3.0
var _ghost_rise := 1.0
var _ghost_seen := false
var _row_ghosts: Array = []
## Which way the building in hand faces: an arrow on the ground off its front, turned with
## it by R (its blueprint alone did not say where its door was: playtest 21. 10.).
var _front_arrow: MeshInstance3D
var _front_mat: StandardMaterial3D
var _rising: Array = []     # {node, mat, t}
var _models: Dictionary = {} # type -> [clean model, height] (kept to copy)
var _clock := 0.0

var _scan_t := 0.0
var _mini_img: Image
var _mini_tex: ImageTexture
var _mini_rect := Rect2()
var _lights: Array = []     # [cell, type]
var _heights: Dictionary = {} # root instance id -> metres
var _compass_rect := Rect2()
## How much of the ground's fog the view keeps.
var fog_k := 0.12


func _exit_tree() -> void:
	for k in _models:
		var n = _models[k][0]
		if is_instance_valid(n):
			(n as Node).free()
	_models.clear()


func _ready() -> void:
	panel = get_parent() as Control
	add_to_group("builder_3d")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_vp = SubViewport.new()
	_vp.name = "Builder3DView"
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.audio_listener_enable_3d = false
	_vp.size = Vector2i(64, 64)
	add_child(_vp)
	_cam = Camera3D.new()
	# The Builder's eye: the camp as the PC has it, without the god cursor's theatre
	# (its copies falling; the buildings it has not dropped yet are on this eye only).
	_cam.set_meta("builder_eye", true)
	_cam.cull_mask = 0xFFFFF & ~GOD.THEATRE
	_cam.near = 0.4
	_cam.far = 7000.0
	_cam.fov = FOV
	_vp.add_child(_cam)
	_view = TextureRect.new()
	_view.name = "View"
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.texture = _vp.get_texture()
	_view_mat = ShaderMaterial.new()
	_view_mat.shader = VIEW_SHADER
	_view_mat.set_shader_parameter("palette_lut", LUT)
	_view_mat.set_shader_parameter("cell", float(PX))
	_view_mat.set_shader_parameter("reveal", 0.0)
	_view.material = _view_mat
	add_child(_view)
	_over = Control.new()
	_over.name = "Paper"
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_paper)
	add_child(_over)
	_plates = MultiMeshInstance3D.new()
	_plates.name = "Plates"
	_plates.set_meta("retro_skip", true)
	_plates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = MAX_PLATES
	mm.visible_instance_count = 0
	_plates.multimesh = mm
	var pm := ShaderMaterial.new()
	pm.shader = PLATE_SHADER
	_plates.material_override = pm
	_plates.extra_cull_margin = 16384.0
	_vp.add_child(_plates)
	if EventBus.has_signal("BuildConfirmed"):
		EventBus.BuildConfirmed.connect(_on_built)
	resized.connect(_fit)


# ── in and out ───────────────────────────────────────────────────────────────

## Whether the map is shown in 3D now (the panel's own two layers can rest).
func covers() -> bool:
	return _mode == 2


## Coming in or going out: the map takes no clicks till it is there.
func busy() -> bool:
	return _mode == 1 or _mode == 3


func enter(instant := false) -> bool:
	if _mode == 1 or _mode == 2 or not _world_ready():
		return false
	_vp.world_3d = panel.building_manager.get_world_3d()
	_fit()
	var iso: Dictionary = panel._compute_iso_layout(int(panel.grid_manager.grid_width), int(panel.grid_manager.grid_height))
	var mid: Vector2 = panel._panel_to_cell_f(panel.size * 0.5, iso)
	var ext := _iso_extent(float(iso.tile_w))
	var yaw := deg_to_rad(45.0 - 90.0 * float(panel.view_rot))
	var fov0 := maxf(ISO_FOV_MIN, rad_to_deg(2.0 * atan(ext / (2.0 * ISO_DIST_MAX))))
	_from = {"f": _cell_world(mid), "yaw": yaw, "pitch": ISO_PITCH, "fov": fov0, "ext": ext}
	# Where it lands: the same ground, nearer and steeper, the quarter it was turned.
	var land := clampf(ext * 0.8 / (2.0 * tan(deg_to_rad(FOV) * 0.5)), DIST_MIN, _dist_cap(PITCH_DEF))
	_to = {"f": _from["f"], "yaw": yaw, "pitch": PITCH_DEF, "fov": FOV, "ext": 2.0 * land * tan(deg_to_rad(FOV) * 0.5)}
	visible = true
	_vel = Vector3.ZERO
	_scan_t = 0.0
	_ghost_seen = false
	if instant:
		_land()
		_view_mat.set_shader_parameter("reveal", 1.0)
	else:
		_mode = 1
		_t = 0.0
		_pose(_from, 0.0)
		panel.call("_play", "turn_view", -8.0)
	return true


func leave(instant := false) -> void:
	if _mode == 0 or _mode == 3:
		return
	on = false
	_orbit = false
	_mini_drag = false
	# The nearest quarter, the same ground, the same scale.
	var r := wrapi(roundi((deg_to_rad(45.0) - _yaw) / (PI * 0.5)), 0, 4)
	var yaw_q := deg_to_rad(45.0 - 90.0 * float(r))
	yaw_q = _yaw + wrapf(yaw_q - _yaw, -PI, PI)
	var ext := 2.0 * _dist * tan(deg_to_rad(_fov) * 0.5)
	var fov1 := maxf(ISO_FOV_MIN, rad_to_deg(2.0 * atan(ext / (2.0 * ISO_DIST_MAX))))
	_from = {"f": _f, "yaw": _yaw, "pitch": _pitch, "fov": _fov, "ext": ext}
	_to = {"f": _f, "yaw": yaw_q, "pitch": ISO_PITCH, "fov": fov1, "ext": ext}
	# The 2D map set to it now, so it is ready under the dither.
	panel.call("set_3d_layers", false)
	panel.view_rot = r
	panel.call("match_view", _world_cell(_f), ext)
	_hide_ghosts()
	_plates.multimesh.visible_instance_count = 0
	if instant:
		_off()
		return
	_mode = 3
	_t = 0.0
	panel.call("_play", "turn_view", -8.0)


func _land() -> void:
	_mode = 2
	_t = 0.0
	on = true
	panel.call("set_3d_layers", true)
	_f = _to["f"]
	_ft = _f
	_yaw = float(_to["yaw"])
	_yaw_t = _yaw
	_pitch = float(_to["pitch"])
	_pitch_t = _pitch
	_fov = float(_to["fov"])
	_dist = float(_to["ext"]) / (2.0 * tan(deg_to_rad(_fov) * 0.5))
	_dist_t = _dist
	_apply_cam()


func _off() -> void:
	_mode = 0
	on = false
	visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_mat.set_shader_parameter("reveal", 0.0)
	RETRO.vis_far = 0.0
	_hide_ghosts()
	for r in _rising:
		if is_instance_valid(r["node"]):
			(r["node"] as Node).queue_free()
	_rising.clear()
	left_3d.emit()


## A pose between two (the way in and out): the lens and the distance go together so the
## ground keeps its size while the long lens opens up (a dolly zoom).
func _pose(a: Dictionary, s: float) -> void:
	var b := _to
	_f = (a["f"] as Vector3).lerp(b["f"], s)
	_yaw = lerpf(float(a["yaw"]), float(b["yaw"]), s)
	_pitch = lerpf(float(a["pitch"]), float(b["pitch"]), s)
	_fov = exp(lerpf(log(float(a["fov"])), log(float(b["fov"])), s))
	var ext := exp(lerpf(log(float(a["ext"])), log(float(b["ext"])), s))
	_dist = ext / (2.0 * tan(deg_to_rad(_fov) * 0.5))
	_ft = _f
	_yaw_t = _yaw
	_pitch_t = _pitch
	_dist_t = _dist
	_apply_cam()


## The camera-plane height of the 2D map's view, in metres (a tile's diagonal is tile_w
## pixels across, and so is its depth at 30 degrees, halved).
func _iso_extent(tile_w: float) -> float:
	return panel.size.y * _ts() * sqrt(2.0) / maxf(1.0, tile_w)


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _mode == 0:
		return
	var live := is_visible_in_tree() and _screen_live()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if not live:
		RETRO.vis_far = 0.0
		return
	_clock += delta
	_t += delta
	match _mode:
		1:
			var s := clampf(_t / ENTER_SEC, 0.0, 1.0)
			_pose(_from, s * s * s * (s * (s * 6.0 - 15.0) + 10.0))
			_view_mat.set_shader_parameter("reveal", _stepped(_t / DITHER_SEC))
			if s >= 1.0:
				_land()
		3:
			var s3 := clampf(_t / LEAVE_SEC, 0.0, 1.0)
			_pose(_from, s3 * s3 * (3.0 - 2.0 * s3))
			_view_mat.set_shader_parameter("reveal", 1.0 - _stepped((_t - LEAVE_SEC * 0.55) / DITHER_SEC))
			if _t >= LEAVE_SEC * 0.55 + DITHER_SEC:
				_off()
				return
		2:
			_steer(delta)
	_env_t -= delta
	if _env_t <= 0.0:
		_env_t = 0.5
		_sync_env()
	RETRO.vis_far = _dist * 3.0 if _mode == 2 else 0.0
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_scan()
	if _mode == 2:
		_update_ghost(delta)
		_update_plates()
	_tick_rising(delta)
	_over.queue_redraw()


func _stepped(x: float) -> float:
	return clampf(floorf(clampf(x, 0.0, 1.0) * 6.0) / 6.0, 0.0, 1.0)


## The PC's screen is being drawn (the monitor's viewport is live): otherwise nothing.
func _screen_live() -> bool:
	var sv := get_viewport() as SubViewport
	return sv == null or sv.render_target_update_mode != SubViewport.UPDATE_DISABLED


func _steer(delta: float) -> void:
	# Thrown: the pan glides on after a quick let-go.
	if not bool(panel.get("_pan_dragging")) and _vel.length_squared() > 0.0004:
		_ft += _vel * delta
		_f += _vel * delta
		_vel *= exp(-5.0 * delta)
	_ft = _clamp_focus(_ft)
	_pitch_t = clampf(_pitch_t, PITCH_MIN, PITCH_MAX)
	_dist_t = clampf(_dist_t, DIST_MIN, _dist_cap(_pitch_t))
	var k := 1.0 - exp(-11.0 * delta)
	_f = _f.lerp(_ft, k)
	_yaw = lerpf(_yaw, _yaw_t, k)
	_pitch = lerpf(_pitch, _pitch_t, k)
	_dist = exp(lerpf(log(_dist), log(_dist_t), k))
	_apply_cam()


func _apply_cam() -> void:
	var back := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.fov = _fov
	_cam.transform = Transform3D(Basis.from_euler(Vector3(-_pitch, _yaw, 0.0)), _f + back * _dist)


func _dist_cap(pitch: float) -> float:
	return minf(DIST_MAX, CEILING / maxf(0.2, sin(pitch)))


func _clamp_focus(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, ROAM.position.x, ROAM.end.x), 0.0, clampf(p.z, ROAM.position.y, ROAM.end.y))


## Where the land round the camp is built (town_trip._eye_for_geo asks): the ground this
## view looks at while it shows and the PC's screen is drawn; INF otherwise.
func geo_eye() -> Vector3:
	return _f if on and is_visible_in_tree() and _screen_live() else Vector3.INF


func _fit() -> void:
	if _vp == null:
		return
	var want := Vector2i(maxi(16, int(size.x) / PX), maxi(16, int(size.y) / PX))
	if _vp.size != want:
		_vp.size = want


## The world's own sky and light (the hour, the weather), its fog thinned: from up here
## the whole camp is in the view, and the fog of the ground would have it all grey.
func _sync_env() -> void:
	var main := get_tree().current_scene if get_tree() != null else null
	var we = main.get("world_environment") if main != null else null
	var src: Environment = (we as WorldEnvironment).environment if we is WorldEnvironment else null
	if src == null and _vp.world_3d != null:
		src = _vp.world_3d.environment
	if src == null:
		return
	var env: Environment = src.duplicate()
	# Thinner the higher it is: from a kilometre up the whole land, not a grey sheet.
	env.fog_density = src.fog_density * fog_k * clampf(80.0 / maxf(1.0, _dist), 0.04, 1.0)
	env.fog_enabled = src.fog_enabled and fog_k > 0.0
	env.volumetric_fog_enabled = false
	_cam.environment = env
	var lines := int(size.y) / PX
	_view_mat.set_shader_parameter("dither_strength", 0.3 if lines <= 240 else 0.45)


# ── the panel's questions ────────────────────────────────────────────────────

## The tile under a point of the map (-1, -1 off the site or in the sky).
func cell_at(local: Vector2) -> Vector2i:
	var g := _ground(local)
	if g == Vector3.INF:
		return Vector2i(-1, -1)
	var c: Vector2i = panel.grid_manager.world_to_grid(g)
	if c.x < 0 or c.y < 0 or c.x >= int(panel.grid_manager.grid_width) or c.y >= int(panel.grid_manager.grid_height):
		return Vector2i(-1, -1)
	return c


## Where a building's roof (or a tile) is on the map, for the coins that fly from it.
func cell_point(coord: Vector2i) -> Vector2:
	var info: Dictionary = panel.structure_at(coord)
	var o: Vector2i = info.get("origin", coord)
	var fp: Vector2i = info.get("footprint", Vector2i.ONE)
	var top := _height_of(info.get("root")) if info.has("root") else 0.5
	var p := screen_of(_foot_world(o, fp) + Vector3(0, top, 0))
	return p if Rect2(Vector2.ZERO, size).grow(-4.0).has_point(p) else Vector2.INF


func guest_at(local: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	var guests: Dictionary = panel.get("_guests")
	for id in guests:
		for m in guests[id].get("members", [{"cell": guests[id]["cell"]}]):
			var foot := screen_of(_cell_world(m["cell"]))
			var head := screen_of(_cell_world(m["cell"]) + Vector3(0, 1.8, 0))
			if foot == Vector2.INF or head == Vector2.INF:
				continue
			var h := maxf(10.0, foot.y - head.y)
			var r := Rect2(Vector2(foot.x - maxf(5.0, h * 0.35), head.y - 2.0), Vector2(maxf(10.0, h * 0.7), h + 4.0))
			if r.has_point(local):
				var d := foot.distance_to(local)
				if d < best_d:
					best_d = d
					best = int(id)
	return best


func follow(cell: Vector2) -> void:
	_ft = _cell_world(cell)
	_vel = Vector3.ZERO


func center_on(cell: Vector2) -> void:
	_ft = _cell_world(cell)
	_vel = Vector3.ZERO


func turn(step: int) -> void:
	_yaw_t += float(step) * PI * 0.5
	panel.call("_play", "turn_view", -9.0)


func zoom_step(direction: int, local: Vector2) -> void:
	var old := _dist_t
	# Bigger steps far out (seven metres to a kilometre and a half).
	var k := 1.2 if _dist_t < 150.0 else 1.35
	_dist_t = clampf(_dist_t * (1.0 / k if direction > 0 else k), DIST_MIN, _dist_cap(_pitch_t))
	var g := _ground(local) if Rect2(Vector2.ZERO, size).has_point(local) else Vector3.INF
	if g != Vector3.INF and old > 0.0:
		_ft = _clamp_focus(_ft + (g - _ft) * (1.0 - _dist_t / old))


## The arrows: `px` PC pixels' worth of the ground under the middle.
func key_pan(move: Vector2, px: float) -> void:
	var mpp := 2.0 * _dist * tan(deg_to_rad(_fov) * 0.5) / maxf(1.0, size.y)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	_ft = _clamp_focus(_ft + (right * move.x - fwd * move.y) * px * mpp)
	_vel = Vector3.ZERO


## A right-button drag: the ground under the pointer stays under it.
func pan_by(pos: Vector2, rel: Vector2) -> void:
	var a := _ground(pos - rel)
	var b := _ground(pos)
	var d := Vector3.ZERO
	if a != Vector3.INF and b != Vector3.INF:
		d = a - b
	else:
		var mpp := 2.0 * _dist * tan(deg_to_rad(_fov) * 0.5) / maxf(1.0, size.y)
		d = (Vector3(cos(_yaw), 0.0, -sin(_yaw)) * -rel.x + Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * rel.y) * mpp
	d.y = 0.0
	if d.length() > _dist * 0.5:
		d = d.normalized() * _dist * 0.5
	_ft = _clamp_focus(_ft + d)
	_f = _clamp_focus(_f + d)
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _last_pan, 1.0 / 240.0, 0.1)
	_last_pan = now
	_vel = _vel.lerp(d / dt, 0.4)
	_apply_cam()


## The panel hands every event here first; true = taken (the middle button's turning,
## the minimap, the compass).
func take_input(event: InputEvent) -> bool:
	if _mode != 2:
		return busy()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit = mb.pressed
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _mini_rect.grow(3.0).has_point(mb.position):
				_mini_drag = true
				_mini_go(mb.position)
				panel.call("_play", "click", -14.0)
				return true
			if mb.pressed and _compass_rect.has_point(mb.position):
				_yaw_t = _yaw + wrapf(0.0 - _yaw, -PI, PI)
				panel.call("_play", "turn_view", -9.0)
				return true
			if not mb.pressed and _mini_drag:
				_mini_drag = false
				return true
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			# Let go after a pause: no throw.
			if Time.get_ticks_msec() / 1000.0 - _last_pan > 0.08:
				_vel = Vector3.ZERO
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbit:
			_yaw_t -= mm.relative.x * 0.0085
			_pitch_t = clampf(_pitch_t + mm.relative.y * 0.006, PITCH_MIN, PITCH_MAX)
			return true
		if _mini_drag:
			_mini_go(mm.position)
			return true
	return false


func minimap_click(local: Vector2) -> bool:
	if not _mini_rect.grow(3.0).has_point(local):
		return false
	_mini_go(local)
	return true


func _mini_go(local: Vector2) -> void:
	if _mini_rect.size.x <= 0.0:
		return
	var c := (local - _mini_rect.position) / MINI_CELL - Vector2(0.5, 0.5)
	_ft = _clamp_focus(_cell_world(c))
	_vel = Vector3.ZERO


# ── projection ───────────────────────────────────────────────────────────────

func screen_of(w: Vector3) -> Vector2:
	if _cam == null or not _cam.is_inside_tree() or _cam.is_position_behind(w):
		return Vector2.INF
	return _cam.unproject_position(w) * size / Vector2(_vp.size)


## The ground (y = `y`) under a point of the map; INF where the pointer is in the sky.
func _ground(local: Vector2, y := 0.0) -> Vector3:
	if _cam == null or not _cam.is_inside_tree() or size.x <= 0.0:
		return Vector3.INF
	var p := local * Vector2(_vp.size) / size
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	if d.y > -0.002:
		return Vector3.INF
	return o + d * ((y - o.y) / d.y)


func _mc() -> Vector3:
	return panel.grid_manager.get_map_min_corner()


func _ts() -> float:
	return float(panel.grid_manager.tile_size)


## A fractional cell (whole numbers at tile middles, as the panel keeps them) on the ground.
func _cell_world(c: Vector2) -> Vector3:
	var mc := _mc()
	var ts := _ts()
	return Vector3(mc.x + (c.x + 0.5) * ts, 0.0, mc.z + (c.y + 0.5) * ts)


func _world_cell(w: Vector3) -> Vector2:
	var mc := _mc()
	var ts := _ts()
	return Vector2((w.x - mc.x) / ts - 0.5, (w.z - mc.z) / ts - 0.5)


func _foot_world(o: Vector2i, fp: Vector2i) -> Vector3:
	return _cell_world(Vector2(o) + Vector2(fp - Vector2i.ONE) * 0.5)


func _world_ready() -> bool:
	return panel != null and panel.grid_manager != null and panel.building_manager != null \
		and is_instance_valid(panel.building_manager) and (panel.building_manager as Node3D).is_inside_tree() \
		and int(panel.grid_manager.grid_width) > 0


## How tall a building stands (its meshes), for labels over it.
func _height_of(root) -> float:
	if not (root is Node3D) or not is_instance_valid(root):
		return 0.5
	var id: int = (root as Node3D).get_instance_id()
	if _heights.has(id):
		return float(_heights[id])
	var top := 0.5
	var base := (root as Node3D).global_position.y
	for m in (root as Node).find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		top = maxf(top, bb.end.y - base)
	top = minf(top, 12.0)
	_heights[id] = top
	return top


# ── the plates ───────────────────────────────────────────────────────────────

var _plate_n := 0


func _plate(c: Vector2i, col: Color, pattern := 0, fill := 0.2) -> void:
	if _plate_n >= MAX_PLATES or not panel._is_valid_coord(c):
		return
	var ts := _ts()
	var w := _cell_world(Vector2(c))
	var mm := _plates.multimesh
	mm.set_instance_transform(_plate_n, Transform3D(Basis().scaled(Vector3(ts * 0.96, 1.0, ts * 0.96)), w + Vector3(0, PLATE_Y, 0)))
	mm.set_instance_color(_plate_n, col)
	mm.set_instance_custom_data(_plate_n, Color(float(pattern), fill, 0.0, 0.0))
	_plate_n += 1


func _update_plates() -> void:
	_plate_n = 0
	var pulse := 0.75 + 0.25 * sin(_clock * 6.0)
	var sel: String = panel.selected_building
	var hover: Vector2i = panel.hover_coord
	var ov: String = panel.overlay
	# The overlay's colours under the buildings.
	if ov == "light":
		for l in _lights:
			var r := float(REACH.get(str(l[1]), 2.6))
			var lc: Vector2 = l[0]
			for y in range(int(floor(lc.y - r)), int(ceil(lc.y + r)) + 1):
				for x in range(int(floor(lc.x - r)), int(ceil(lc.x + r)) + 1):
					var dd := Vector2(x, y).distance_to(lc)
					if dd <= r:
						_plate(Vector2i(x, y), LAMP, 2, 0.34 * (1.0 - dd / (r + 0.5)))
	elif ov != "":
		var gm = panel._grid_model()
		var od: Dictionary = panel.get("_ov_data")
		for o in od:
			var v: Array = od[o]
			for c in _footprint(o, _fp_of(gm, o)):
				_plate(c, v[2], 0, 0.42)
	# The building whose card is open.
	var io: Vector2i = panel.inspect_origin
	if io.x >= 0:
		for c in _footprint(io, panel.inspect_footprint):
			_plate(c, Color(GOLD.r, GOLD.g, GOLD.b, 0.7 + 0.3 * sin(_clock * 5.0)), 0, 0.18)
	# The tool.
	if bool(panel.get("_path_drag_active")):
		var cost: int = panel._get_cost("path")
		var afford := 1 << 30
		if cost > 0:
			afford = int(CoreRoot.get_money()) / cost
		var n_new := 0
		for e in panel.get("_path_line"):
			var kind := int(e[1])
			match kind:
				0:
					n_new += 1
					if n_new > afford:
						_plate(e[0], RED, 0, 0.14)
					else:
						_plate(e[0], AMBER, 0, 0.3)
				1:
					_plate(e[0], BLUE, 0, 0.12)
				2:
					_plate(e[0], RED, 1, 0.22)
	elif sel == "demolish":
		var rect := _demolish_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			var chosen := not bool(panel.get("_demolish_drag_active"))
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var c := Vector2i(x, y)
					var t = panel.grid_manager.get_tile(c)
					var full: bool = t != null and t.occupied
					_plate(c, RED, 1 if full else 2, (0.16 if chosen else 0.1) if not full else 0.2)
		elif panel._is_valid_coord(hover):
			_plate(hover, RED, 0, 0.16 * pulse)
	elif sel != "" and sel != "path":
		if bool(panel.get("_row_drag")) and (panel.get("_row_line") as Array).size() > 1:
			for e in panel.get("_row_line"):
				_plate(e[0], BLUE if bool(e[1]) else RED, 0 if bool(e[1]) else 1, 0.2)
		else:
			var coord: Vector2i = panel.get("_ghost_coord") if bool(panel.get("_ghost_locked")) else hover
			if panel._is_valid_coord(coord):
				_local_grid(coord)
				var fp: Vector2i = panel._get_footprint(sel)
				var fit: bool = panel._can_place(coord, fp, sel)
				var pay: bool = panel._has_money(sel)
				var col := BLUE if fit and pay else (AMBER if fit else RED)
				for c in _footprint(coord, fp):
					_plate(c, col, 0 if fit else 1, 0.2 if fit and pay else 0.26)
				# Where a light would reach: plates warm and faint.
				if REACH.has(sel):
					var mid := Vector2(coord) + Vector2(fp - Vector2i.ONE) * 0.5
					var r := float(REACH[sel])
					for y in range(int(floor(mid.y - r)), int(ceil(mid.y + r)) + 1):
						for x in range(int(floor(mid.x - r)), int(ceil(mid.x + r)) + 1):
							var dd := Vector2(x, y).distance_to(mid)
							if dd <= r and dd > 0.6:
								_plate(Vector2i(x, y), LAMP, 2, 0.3 * (1.0 - dd / (r + 0.5)))
	elif panel._is_valid_coord(hover) and not bool(panel.get("_pan_dragging")):
		_plate(hover, Color(BLUE.r, BLUE.g, BLUE.b, pulse), 0, 0.16 * pulse)
	_plates.multimesh.visible_instance_count = _plate_n


## The tiles round the pointer, rims only, fading out (the 2D map's local grid).
func _local_grid(at: Vector2i) -> void:
	for y in range(at.y - 3, at.y + 4):
		for x in range(at.x - 3, at.x + 4):
			var d := Vector2(x, y).distance_to(Vector2(at))
			if d <= 3.4 and d > 0.0:
				_plate(Vector2i(x, y), Color(BLUE.r, BLUE.g, BLUE.b, 0.5 * (1.0 - d / 3.6)), 0, 0.0)


func _footprint(o: Vector2i, fp: Vector2i) -> Array:
	var out: Array = []
	for y in maxi(1, fp.y):
		for x in maxi(1, fp.x):
			out.append(o + Vector2i(x, y))
	return out


func _fp_of(gm, o: Vector2i) -> Vector2i:
	var cell: Dictionary = gm.cells.get(o, {}) if gm != null else {}
	if cell.has("type") and CoreRoot != null and CoreRoot.registry != null:
		var def = CoreRoot.registry.get_def(StringName(str(cell["type"])))
		if def != null:
			return def.footprint
	return Vector2i.ONE


func _demolish_rect() -> Rect2i:
	if bool(panel.get("_demolish_drag_active")):
		return panel._rect_from_points(panel.get("_demolish_drag_start"), panel.get("_demolish_drag_end"))
	if bool(panel.get("_demolish_selection_active")):
		return panel.get("_demolish_selection_rect")
	return Rect2i()


# ── the ghost ────────────────────────────────────────────────────────────────

## The building in hand at the tile under the pointer, the way it will face; a row's
## things each on their tile.
func _update_ghost(delta: float) -> void:
	var sel: String = panel.selected_building
	var show := sel != "" and sel != "path" and sel != "demolish"
	var row := show and bool(panel.get("_row_drag")) and (panel.get("_row_line") as Array).size() > 1
	var coord: Vector2i = panel.get("_ghost_coord") if bool(panel.get("_ghost_locked")) else panel.hover_coord
	show = show and panel._is_valid_coord(coord) and not row
	if sel != _ghost_type:
		_ghost_type = sel
		_hide_ghosts()
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		if sel != "" and sel != "path" and sel != "demolish":
			var made := _ghost_model(sel)
			_ghost = made[0]
			_ghost_h = float(made[1])
			_ghost_mat = made[2]
			_vp.add_child(_ghost)
			_ghost.visible = false
		_ghost_seen = false
	if _ghost == null:
		return
	if show and not _ghost_seen:
		_ghost_seen = true
		_ghost_rise = 0.0
	_ghost_rise = minf(1.0, _ghost_rise + delta / 0.3)
	_ghost.visible = show
	var fp: Vector2i = panel._get_footprint(sel)
	if show:
		var fit: bool = panel._can_place(coord, fp, sel)
		var pay: bool = panel._has_money(sel)
		_ghost.transform = Transform3D(Basis(Vector3.UP, _turn_of(sel)), _foot_world(coord, fp))
		var tint := BLUE if fit and pay else (AMBER if fit else RED)
		_ghost_mat.set_shader_parameter("tint", tint)
		_ghost_mat.set_shader_parameter("base_y", 0.0)
		_ghost_mat.set_shader_parameter("height", _ghost_h)
		_ghost_mat.set_shader_parameter("rise", floorf(_ghost_rise * 6.0) / 6.0)
		_ghost_mat.set_shader_parameter("t", floorf(_clock * 12.0) / 12.0)
	_show_front(sel, coord, fp, show and panel._supports_rotation(sel), BLUE if not show else (BLUE if panel._can_place(coord, fp, sel) and panel._has_money(sel) else (AMBER if panel._can_place(coord, fp, sel) else RED)))
	# A row: a copy on each tile that fits.
	var cells: Array = []
	if row:
		for e in panel.get("_row_line"):
			if bool(e[1]):
				cells.append(e[0])
	while _row_ghosts.size() < mini(cells.size(), 40):
		var g := _ghost.duplicate() as Node3D
		_vp.add_child(g)
		_row_ghosts.append(g)
	for i in _row_ghosts.size():
		var rg: Node3D = _row_ghosts[i]
		rg.visible = i < cells.size()
		if rg.visible:
			rg.transform = Transform3D(Basis(Vector3.UP, _turn_of(sel)), _foot_world(cells[i], Vector2i.ONE))
	if row:
		_ghost_mat.set_shader_parameter("tint", BLUE)
		_ghost_mat.set_shader_parameter("rise", 1.0)
		_ghost_mat.set_shader_parameter("t", floorf(_clock * 12.0) / 12.0)


func _show_front(sel: String, coord: Vector2i, fp: Vector2i, on: bool, tint: Color) -> void:
	if not on:
		if _front_arrow != null:
			_front_arrow.visible = false
		return
	if _front_arrow == null or not is_instance_valid(_front_arrow):
		_front_arrow = MeshInstance3D.new()
		_front_arrow.name = "GhostFront"
		_front_arrow.mesh = _arrow_mesh()
		_front_mat = StandardMaterial3D.new()
		_front_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_front_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_front_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_front_arrow.material_override = _front_mat
		_front_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vp.add_child(_front_arrow)
	var b := Basis(Vector3.UP, _turn_of(sel))
	var half := float(fp.y) * _ts() * 0.5
	_front_arrow.transform = Transform3D(b, _foot_world(coord, fp) + b * Vector3(0.0, 0.08, half + 0.3))
	_front_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55 + 0.25 * float(int(_clock * 4.0) % 2))
	_front_arrow.visible = true


## A flat arrow on the ground pointing +Z (a head and a stem), about a metre long.
static func _arrow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		# The stem.
		Vector3(-0.16, 0, 0.0), Vector3(0.16, 0, 0.0), Vector3(0.16, 0, 0.55),
		Vector3(-0.16, 0, 0.0), Vector3(0.16, 0, 0.55), Vector3(-0.16, 0, 0.55),
		# The head.
		Vector3(-0.45, 0, 0.55), Vector3(0.45, 0, 0.55), Vector3(0.0, 0, 1.1),
	]
	for v in pts:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	return st.commit()


func _turn_of(type: String) -> float:
	if not panel._supports_rotation(type):
		return 0.0
	var r := wrapi(int(panel.get("_rotation_steps")), 0, 4)
	if panel._turns_round_only(type) and r % 2 == 1:
		r -= 1
	return deg_to_rad(float(r) * 90.0)


func _hide_ghosts() -> void:
	if _ghost != null:
		_ghost.visible = false
	if _front_arrow != null and is_instance_valid(_front_arrow):
		_front_arrow.visible = false
	for g in _row_ghosts:
		if is_instance_valid(g):
			(g as Node).queue_free()
	_row_ghosts.clear()


## A clean copy of a building's model, its meshes only, in the ghost's material:
## [node, height, material]. Built off the tree (nothing of the real building runs: no
## scripts, bodies, lights or sounds), then kept per type.
func _ghost_model(type: String) -> Array:
	if not _models.has(type):
		var src := Node3D.new()
		var bm = panel.building_manager
		var models = BUILDING_MODELS.new(Callable(bm, "_make_psx_material"))
		var ts := _ts()
		var fp: Vector2i = panel._get_footprint(type)
		if type.begins_with("tent_"):
			_tent(src, clampi(int(type.right(1)), 1, 3), ts, bm, models)
		elif type.begins_with("cabin"):
			var lv := clampi(int(type.right(1)), 1, 3) if type != "cabin" else 1
			var ch := float(bm.get("cabin_height"))
			var ww := ts * (1.56 + float(lv - 1) * 0.06)
			models.cabin(src, lv, ww, ww, ch * (0.86 + float(lv - 1) * 0.04), ch * 0.45)
		elif type.begins_with("caravan_"):
			models.caravan(src, ts * 2.0, ts, clampi(int(type.right(1)), 1, 3))
		elif type == "lamp_post":
			_lamp(src)
		elif BUILDING_MODELS.has_model(type):
			models.build(type, src, ts, fp)
		else:
			var b := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(ts * float(fp.x) * 0.8, 2.0, ts * float(fp.y) * 0.8)
			b.mesh = bx
			b.position.y = 1.0
			src.add_child(b)
		var clean := Node3D.new()
		clean.set_meta("retro_skip", true)
		var top := [0.4]
		_copy_meshes(src, Transform3D.IDENTITY, clean, top)
		src.free()
		_models[type] = [clean, minf(float(top[0]), 12.0)]
	var kept: Array = _models[type]
	var node := (kept[0] as Node3D).duplicate() as Node3D
	var mat := ShaderMaterial.new()
	mat.shader = GHOST_SHADER
	mat.set_shader_parameter("height", float(kept[1]))
	_dress(node, mat)
	return [node, float(kept[1]), mat]


func _copy_meshes(n: Node, xf: Transform3D, into: Node3D, top: Array) -> void:
	for ch in n.get_children():
		if not (ch is Node3D):
			continue
		var c3 := ch as Node3D
		var cx := xf * c3.transform
		if not c3.visible:
			continue
		if c3 is MeshInstance3D and (c3 as MeshInstance3D).mesh != null:
			var mi := MeshInstance3D.new()
			mi.mesh = (c3 as MeshInstance3D).mesh
			mi.transform = cx
			mi.set_meta("retro_skip", true)
			into.add_child(mi)
			top[0] = maxf(float(top[0]), (cx * mi.mesh.get_aabb()).end.y)
		elif c3 is MultiMeshInstance3D and (c3 as MultiMeshInstance3D).multimesh != null:
			var mm := MultiMeshInstance3D.new()
			mm.multimesh = (c3 as MultiMeshInstance3D).multimesh
			mm.transform = cx
			mm.set_meta("retro_skip", true)
			into.add_child(mm)
		_copy_meshes(c3, cx, into, top)


func _dress(node: Node, mat: Material) -> void:
	for m in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := m as GeometryInstance3D
		gi.material_override = mat
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.set_meta("retro_skip", true)
		gi.extra_cull_margin = 4.0


## A tent as BuildingManager.place_tent_at pitches it (one yellow, two red, one big blue).
func _tent(root: Node3D, level: int, ts: float, bm, models) -> void:
	var count := 2 if level == 2 else 1
	var k: float = [0.75, 0.62, 1.0][level - 1]
	var col: Color = [Color(1.0, 0.86, 0.16), Color(0.96, 0.14, 0.1), Color(0.16, 0.42, 1.0)][level - 1]
	var th := float(bm.get("tent_height"))
	for i in count:
		var at := Vector3.ZERO if count == 1 else Vector3((-0.18 if i == 0 else 0.18) * ts, 0.0, 0.0)
		var m: MeshInstance3D = bm._create_tent_prism(ts * 0.6 * k, th * k, ts * 0.7 * k, col)
		m.position = at
		root.add_child(m)
		models.tent_details(root, ts * 0.6 * k, th * k, ts * 0.7 * k, at, 0.0, col)


func _lamp(root: Node3D) -> void:
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.06
	cy.bottom_radius = 0.08
	cy.height = 3.4
	pole.mesh = cy
	pole.position.y = 1.7
	root.add_child(pole)
	var head := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.5, 0.18, 0.3)
	head.mesh = bx
	head.position = Vector3(0.2, 3.35, 0.0)
	root.add_child(head)


## A thing built while the view is on rises where it lands, as its blueprint, and goes.
func _on_built(type: String, pos: Vector2i, rot: int) -> void:
	if _mode != 2 or type == "path" or type == "" or _rising.size() > 24:
		return
	var made := _ghost_model(type)
	var node: Node3D = made[0]
	var fp: Vector2i = panel._get_footprint(type)
	var turn := 0.0
	if panel._supports_rotation(type):
		var r := wrapi(rot, 0, 4)
		if fp.x != fp.y and r % 2 == 1:
			r -= 1
		turn = deg_to_rad(float(r) * 90.0)
	node.transform = Transform3D(Basis(Vector3.UP, turn), _foot_world(pos, fp))
	var mat: ShaderMaterial = made[2]
	mat.set_shader_parameter("tint", Color(1.0, 0.95, 0.7))
	mat.set_shader_parameter("rise", 0.0)
	_vp.add_child(node)
	_rising.append({"node": node, "mat": mat, "t": 0.0})


func _tick_rising(delta: float) -> void:
	for i in range(_rising.size() - 1, -1, -1):
		var r: Dictionary = _rising[i]
		r["t"] = float(r["t"]) + delta
		var t := float(r["t"])
		var mat: ShaderMaterial = r["mat"]
		mat.set_shader_parameter("rise", floorf(clampf(t / 0.55, 0.0, 1.0) * 8.0) / 8.0)
		mat.set_shader_parameter("fade", clampf(1.0 - (t - 0.6) / 0.45, 0.0, 1.0))
		mat.set_shader_parameter("t", floorf(_clock * 12.0) / 12.0)
		if t > 1.05:
			if is_instance_valid(r["node"]):
				(r["node"] as Node).queue_free()
			_rising.remove_at(i)


# ── the camp, read every half second (the minimap, the lights) ──────────────

func _scan() -> void:
	var gm = panel._grid_model()
	if gm == null:
		return
	var gw := int(panel.grid_manager.grid_width)
	var gh := int(panel.grid_manager.grid_height)
	if _mini_img == null or _mini_img.get_width() != gw or _mini_img.get_height() != gh:
		_mini_img = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	var colors: Dictionary = panel.MINI_COLORS
	var ground: Color = panel._mini_ground()
	_mini_img.fill(ground)
	for c in gm.tile_types:
		var t := int(gm.tile_types[c])
		if t == panel.grid_manager.TILE_LAKE or t == panel.grid_manager.TILE_RESERVED:
			if c.x >= 0 and c.y >= 0 and c.x < gw and c.y < gh:
				_mini_img.set_pixelv(c, colors["lake" if t == panel.grid_manager.TILE_LAKE else "reserved"])
	_lights.clear()
	var seen := {}
	var occ: Dictionary = gm.occupants
	for coord in occ:
		var node = occ[coord]
		if node == null or not is_instance_valid(node):
			continue
		var root = panel._resolve_occupant_root(node)
		if root == null:
			continue
		var bt := str(root.get_meta("building_type", ""))
		var mk: String = "corn" if root.is_in_group("corn") else ("tree" if root.is_in_group("trees") else panel._mini_kind(bt))
		if coord.x >= 0 and coord.y >= 0 and coord.x < gw and coord.y < gh:
			_mini_img.set_pixelv(coord, colors.get(mk, ground))
		var rid: int = root.get_instance_id()
		if seen.has(rid):
			continue
		seen[rid] = true
		if bt == "lamp_post" or bt == "bonfire":
			var o: Vector2i = root.get_meta("grid_origin", coord)
			_lights.append([Vector2(o), bt])
		elif bt == "path" and panel._path_has_lamp(coord):
			_lights.append([Vector2(coord), "lamp_post"])
	if _mini_tex == null or _mini_tex.get_width() != gw or _mini_tex.get_height() != gh:
		_mini_tex = ImageTexture.create_from_image(_mini_img)
	else:
		_mini_tex.update(_mini_img)


# ── the paper over the view ──────────────────────────────────────────────────

func _draw_paper() -> void:
	if _mode == 0:
		return
	var cv := _over
	panel.set("_cv", cv)
	if _mode == 2:
		if panel.overlay == "light":
			cv.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.08, 0.4))
		_draw_overlay_labels(cv)
		_draw_badges(cv)
		_draw_guest_minds(cv)
		_draw_fx(cv)
		_draw_demolish_outline(cv)
		_draw_tags()
		_draw_overlay_key(cv)
	_draw_minimap(cv)
	_draw_compass(cv)
	if _mode == 2:
		panel.call("_draw_hover_card")


## Pixels per metre at a point of the world (how big to draw things there).
func _ppm(w: Vector3) -> float:
	var a := screen_of(w)
	var b := screen_of(w + Vector3(0, 1, 0))
	if a == Vector2.INF or b == Vector2.INF:
		return 0.0
	return a.distance_to(b)


func _draw_fx(cv: Control) -> void:
	var dust: Texture2D = panel.get("_dust_tex")
	for f in panel.get("_fx"):
		var k := float(f["t"]) / float(f["life"])
		var w := _cell_world(f["cell"])
		var ppm := _ppm(w)
		if ppm <= 0.0:
			continue
		match str(f["kind"]):
			"dust":
				var sd := float(f["seed"])
				for i in 4:
					var a := sd * TAU + i * 1.7
					var r := 0.6 + k * 2.0
					var q := screen_of(w + Vector3(cos(a) * r, 0.4 + k * 1.6, sin(a) * r))
					if q == Vector2.INF:
						continue
					var ps := ppm * (0.9 + k * 1.1)
					if dust != null:
						cv.draw_set_transform(q, a + k * 0.8, Vector2.ONE)
						cv.draw_texture_rect(dust, Rect2(Vector2(-ps, -ps * 0.8), Vector2(ps * 2.0, ps * 1.6)), false, Color(1, 1, 1, 0.85 * (1.0 - k)))
						cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					else:
						cv.draw_circle(q, ps * 0.4, Color(0.62, 0.56, 0.46, 0.55 * (1.0 - k)))
			"pop":
				var txt := tr(str(f["text"]))
				var q2 := screen_of(w + Vector3(0, 2.4 + k * 2.0, 0))
				if q2 == Vector2.INF:
					continue
				q2 = q2.floor()
				var col: Color = f["color"]
				col.a = 1.0 - maxf(0.0, k - 0.6) / 0.4
				var tw := T.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
				cv.draw_string(T.FONT_BOLD, q2 + Vector2(-tw * 0.5 + 1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color(0, 0, 0, col.a))
				cv.draw_string(T.FONT_BOLD, q2 + Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, col)


## Every lodging's name over its roof (T1, C2, V1), as on the 2D map and its key.
func _draw_badges(cv: Control) -> void:
	if GuestManager == null or not GuestManager.has_method("room_short"):
		return
	var accs: Dictionary = GuestManager.get_accommodation_states()
	for key in accs.keys():
		var acc: Dictionary = accs[key]
		var kind: String = GuestManager.lodging_kind(str(acc.get("building_type", "")))
		if kind == "":
			continue
		var c: Vector2i = acc.get("coord", Vector2i(-1, -1)) if acc.get("coord", null) is Vector2i else panel.SAVE_CODEC.coord_from_key(str(key))
		if c.x < 0:
			continue
		var def = CoreRoot.registry.get_def(StringName(str(acc.get("building_type", "")))) if CoreRoot != null else null
		var fp: Vector2i = def.footprint if def != null else Vector2i.ONE
		var info: Dictionary = panel.structure_at(c)
		var top := _height_of(info.get("root")) if info.has("root") else 2.0
		var p := screen_of(_foot_world(c, fp) + Vector3(0, top + 0.5, 0))
		if p == Vector2.INF or not Rect2(Vector2.ZERO, size).has_point(p):
			continue
		var text: String = GuestManager.room_short(str(key))
		var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var r := Rect2((p - Vector2(tw * 0.5 + 3, 7)).floor(), Vector2(tw + 6, 13))
		var col: Color = {"tent": Color8(48, 112, 54), "cabin": Color8(168, 38, 30), "caravan": Color8(42, 72, 150)}.get(kind, Color8(90, 90, 90))
		cv.draw_rect(r.grow(1), Color(0, 0, 0, 0.55))
		cv.draw_rect(r, col)
		cv.draw_string(T.FONT, r.position + Vector2(3, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(250, 244, 226))


## The guests' thoughts and faces over their heads (the 2D map's, the same beat).
func _draw_guest_minds(cv: Control) -> void:
	var guests: Dictionary = panel.get("_guests")
	for id in guests:
		var g: Dictionary = guests[id]
		var w := _cell_world(g["cell"])
		var foot := screen_of(w)
		var head := screen_of(w + Vector3(0, 1.8, 0))
		if foot == Vector2.INF or head == Vector2.INF or not Rect2(Vector2.ZERO, size).has_point(head):
			continue
		var h := clampf(foot.y - head.y, 8.0, 48.0)
		panel.call("_draw_think", {"id": int(id), "phase": float(g.get("phase", 0.0))}, foot, Vector2(h * 0.5, h))


## What each building is at in the overlay, over its roof.
func _draw_overlay_labels(cv: Control) -> void:
	var ov: String = panel.overlay
	if ov == "" or ov == "light":
		return
	var gm = panel._grid_model()
	var od: Dictionary = panel.get("_ov_data")
	for o in od:
		var v: Array = od[o]
		var fp := _fp_of(gm, o)
		var info: Dictionary = panel.structure_at(o)
		var top := _height_of(info.get("root")) if info.has("root") else 1.0
		var p := screen_of(_foot_world(o, fp) + Vector3(0, top + 0.6, 0))
		if p == Vector2.INF or not Rect2(Vector2.ZERO, size).has_point(p):
			continue
		var text := tr(str(v[1]))
		var tw := T.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		var rr := Rect2((p - Vector2(tw * 0.5 + 3, 13)).floor(), Vector2(tw + 6, 13))
		cv.draw_rect(rr, Color(0, 0, 0, 0.72))
		cv.draw_rect(rr, (v[2] as Color), false, 1.0)
		cv.draw_string(T.FONT, rr.position + Vector2(3, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, (v[2] as Color).lightened(0.35))
		cv.draw_line(Vector2(floorf(p.x), rr.end.y), Vector2(floorf(p.x), rr.end.y + 4.0), Color(0, 0, 0, 0.72), 1.0)


func _draw_overlay_key(cv: Control) -> void:
	var ov: String = panel.overlay
	if ov == "":
		return
	var label := tr(str(panel.OVERLAY_NAMES.get(ov, ov))).capitalize()
	var lw := T.FONT_BOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
	var lr := Rect2(Vector2(6, size.y - 22), Vector2(lw + 12, 16))
	cv.draw_rect(lr, Color(0, 0, 0, 0.7))
	cv.draw_rect(lr, Color(1, 1, 1, 0.4), false, 1.0)
	cv.draw_string(T.FONT_BOLD, lr.position + Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, Color8(255, 236, 160))


## The bulldozer's box, its edge on the ground with the light running round it.
func _draw_demolish_outline(cv: Control) -> void:
	if panel.selected_building != "demolish":
		return
	var rect := _demolish_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var p0 := Vector2(rect.position) - Vector2(0.5, 0.5)
	var p1 := Vector2(rect.end) - Vector2(0.5, 0.5)
	var pts := PackedVector2Array()
	for c in [p0, Vector2(p1.x, p0.y), p1, Vector2(p0.x, p1.y)]:
		var s := screen_of(_cell_world(c) + Vector3(0, PLATE_Y, 0))
		if s == Vector2.INF:
			return
		pts.append(s)
	var loop := pts.duplicate()
	loop.append(pts[0])
	cv.draw_polyline(loop, Color(RED.r, RED.g, RED.b, 0.95), 2.0)
	var total := 0.0
	for i in 4:
		total += pts[i].distance_to(pts[(i + 1) % 4])
	var head := fmod(_clock * 0.9, 1.0) * total
	var run := 0.0
	for i in 4:
		var a := pts[i]
		var b := pts[(i + 1) % 4]
		var l := a.distance_to(b)
		var s0 := clampf((head - run) / maxf(l, 0.001), 0.0, 1.0)
		var s1 := clampf((head - run + 30.0) / maxf(l, 0.001), 0.0, 1.0)
		if s1 > s0 and head - run < l:
			cv.draw_line(a.lerp(b, s0), a.lerp(b, s1), Color(1, 1, 1, 0.85), 3.0)
		run += l
	# Its price, as the 2D map gives it.
	var sum: Dictionary = panel._demolish_summary(rect)
	var tag := "%dx%d" % [rect.size.x, rect.size.y]
	var bad := false
	if not sum.is_empty():
		if int(sum["count"]) == 0:
			tag = tr("%dx%d  nothing to clear") % [rect.size.x, rect.size.y]
			bad = true
		else:
			tag = tr("%dx%d  clear %d  $%d") % [rect.size.x, rect.size.y, int(sum["tiles"]), int(sum["fee"])]
			if int(CoreRoot.get_money()) < int(sum["fee"]):
				bad = true
	var top := pts[0]
	for p in pts:
		if p.y < top.y:
			top = p
	panel.call("_draw_tag", top + Vector2(-40, -20), tag, bad)


## The ghost's price (or why not), a path's and a row's, by the tile the pointer is on.
func _draw_tags() -> void:
	var sel: String = panel.selected_building
	if bool(panel.get("_path_drag_active")):
		var line: Array = panel.get("_path_line")
		if line.is_empty():
			return
		var cost: int = panel._get_cost("path")
		var afford := 1 << 30
		if cost > 0:
			afford = int(CoreRoot.get_money()) / cost
		var n_new := 0
		var blocked := false
		for e in line:
			if int(e[1]) == 0:
				n_new += 1
			elif int(e[1]) == 2:
				blocked = true
		var tag := tr("%d tiles  $%d") % [n_new, n_new * cost]
		var bad := n_new == 0 or n_new > afford
		if n_new == 0:
			tag = tr("Nothing new") if not blocked else tr("Blocked")
		elif n_new > afford:
			tag = tr("%d tiles  $%d - money for %d") % [n_new, n_new * cost, afford]
		_tag_at(_cell_world(Vector2(line.back()[0])), tag, bad)
		return
	if sel == "" or sel == "path" or sel == "demolish":
		return
	if bool(panel.get("_row_drag")) and (panel.get("_row_line") as Array).size() > 1:
		var n := 0
		for e in panel.get("_row_line"):
			if bool(e[1]):
				n += 1
		var each: int = panel._get_cost(sel)
		var afford_all := int(CoreRoot.get_money()) >= n * each
		var t2 := tr("%d x $%d = $%d") % [n, each, n * each] if afford_all else tr("$%d - no money for all") % (n * each)
		_tag_at(_cell_world(Vector2((panel.get("_row_line") as Array).back()[0])), t2, not afford_all or n == 0)
		return
	var coord: Vector2i = panel.get("_ghost_coord") if bool(panel.get("_ghost_locked")) else panel.hover_coord
	if not panel._is_valid_coord(coord):
		return
	var fp: Vector2i = panel._get_footprint(sel)
	var fit: bool = panel._can_place(coord, fp, sel)
	var pay: bool = panel._has_money(sel)
	var cost1: int = panel._get_cost(sel)
	var t1 := "$%d" % cost1
	if not fit:
		t1 = tr(panel._blocked_reason(coord, fp))
	elif not pay:
		t1 = tr("$%d - no money") % cost1
	_tag_at(_foot_world(coord, fp) + Vector3(0, _ghost_h + 0.4, 0), t1, not (fit and pay))


func _tag_at(w: Vector3, tag: String, bad: bool) -> void:
	var p := screen_of(w)
	if p == Vector2.INF:
		return
	panel.call("_draw_tag", p + Vector2(10, -18), tag, bad)


## Top right: the camp from straight above, north up, what the camera sees on it.
func _draw_minimap(cv: Control) -> void:
	if _mini_tex == null:
		_mini_rect = Rect2()
		return
	var dims := Vector2(_mini_tex.get_width(), _mini_tex.get_height())
	var sz := dims * MINI_CELL
	_mini_rect = Rect2(Vector2(size.x - sz.x - 12.0, 12.0).floor(), sz)
	var frame := _mini_rect.grow(5.0)
	cv.draw_style_box(T.box("window", T.FACE, Vector4.ZERO), frame)
	cv.draw_style_box(T.box("well", Color(0, 0, 0), Vector4.ZERO), _mini_rect.grow(1.0))
	cv.draw_texture_rect(_mini_tex, _mini_rect, false)
	# The ground the camera sees: its four corners on the ground (towards the horizon,
	# no further than the far side of the map).
	var corners := [Vector2(0, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]
	var pts := PackedVector2Array()
	for c in corners:
		var g := _ground(c)
		if g == Vector3.INF:
			var p: Vector2 = c * Vector2(_vp.size) / size
			var o := _cam.project_ray_origin(p)
			var d := _cam.project_ray_normal(p)
			d.y = 0.0
			g = o + d.normalized() * 400.0
		var mc := _world_cell(g) + Vector2(0.5, 0.5)
		var lim := dims + Vector2(4, 4)
		mc = Vector2(clampf(mc.x, -4.0, lim.x), clampf(mc.y, -4.0, lim.y))
		pts.append(_mini_rect.position + mc * MINI_CELL)
	pts.append(pts[0])
	cv.draw_polyline(pts, Color(0, 0, 0, 0.6), 3.0)
	cv.draw_polyline(pts, Color(1.0, 1.0, 0.6, 0.95), 1.0)
	# The camera, a notch where it stands.
	var cam_c := _world_cell(_cam.global_position) + Vector2(0.5, 0.5)
	var cp := _mini_rect.position + Vector2(clampf(cam_c.x, -1.0, dims.x + 1.0), clampf(cam_c.y, -1.0, dims.y + 1.0)) * MINI_CELL
	cv.draw_rect(Rect2(cp.floor() - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 1.0, 0.6))
	cv.draw_rect(Rect2(cp.floor() - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0), false, 1.0)


## Bottom right, where the 2D map shows the building's turn: a compass whose needle
## points north as the camera turns; with a thing in hand, where its front will face.
func _draw_compass(cv: Control) -> void:
	var box := Vector2(70.0, 76.0)
	var r := Rect2(Vector2(size.x - box.x - 6.0, size.y - box.y - 6.0), box)
	_compass_rect = r
	cv.draw_style_box(T.box("window", T.FACE, Vector4.ZERO), r)
	var c := (r.position + Vector2(box.x * 0.5, 33.0)).floor()
	var dial := 25.0
	cv.draw_style_box(T.box("well", Color8(24, 30, 26), Vector4.ZERO), Rect2(c - Vector2(dial + 3, dial + 3), Vector2(dial * 2 + 6, dial * 2 + 6)))
	# The ticks: the four quarters long, the eighths short (they turn with the camera).
	for i in 8:
		var a := _yaw + float(i) * PI * 0.25
		var d := Vector2(sin(a), -cos(a))
		var l := 6.0 if i % 2 == 0 else 3.0
		cv.draw_line((c + d * (dial - l)).floor(), (c + d * dial).floor(), Color8(150, 170, 150) if i % 2 == 0 else Color8(90, 105, 92), 1.0)
	# North: a needle in two halves, red to the north.
	var nd := Vector2(sin(_yaw), -cos(_yaw))
	var perp := Vector2(-nd.y, nd.x)
	var tip := c + nd * (dial - 4.0)
	var tail := c - nd * (dial - 6.0)
	cv.draw_colored_polygon(PackedVector2Array([tip, c + perp * 4.0, c - perp * 4.0]), Color8(200, 40, 30))
	cv.draw_colored_polygon(PackedVector2Array([tail, c - perp * 4.0, c + perp * 4.0]), Color8(220, 220, 210))
	cv.draw_rect(Rect2(c.floor() - Vector2(1, 1), Vector2(2, 2)), Color8(40, 40, 40))
	var sel: String = panel.selected_building
	var label := ""
	if sel != "" and sel != "demolish" and sel != "path" and panel._supports_rotation(sel):
		var turn := _turn_of(sel)
		var fw := Vector3(sin(turn), 0.0, cos(turn))
		var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var sd := Vector2(fw.dot(right), -fw.dot(fwd)).normalized()
		panel.call("_draw_panel_arrow", c + sd * (dial + 1.0), sd, T.NAVY)
		label = str(panel.ROTATION_LABELS[wrapi(int(panel.get("_rotation_steps")), 0, 4)])
	if label != "":
		label = tr(label)
		var lw := T.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE).x
		cv.draw_string(T.FONT, r.position + Vector2((box.x - lw) * 0.5, box.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FONT_SIZE, T.TEXT)
	else:
		# The camera's height, in steps, where the label would be.
		var k := clampf((_dist - DIST_MIN) / (_dist_cap(_pitch) - DIST_MIN), 0.0, 1.0)
		var bar := Rect2(r.position + Vector2(10, box.y - 12.0), Vector2(box.x - 20.0, 5.0))
		cv.draw_style_box(T.box("well", Color8(24, 30, 26), Vector4.ZERO), bar.grow(1.0))
		for i in 8:
			if float(i) / 8.0 < k + 0.06:
				cv.draw_rect(Rect2(bar.position + Vector2(float(i) * bar.size.x / 8.0 + 1.0, 1.0), Vector2(bar.size.x / 8.0 - 2.0, 3.0)), Color8(110, 200, 110))
