extends CanvasLayer

## The room swipe moves in steps, twelve a second (scripts/ui/step12.gd).
const STEP12 = preload("res://scripts/ui/step12.gd")
const ROOM_PUSH = preload("res://scripts/ui/room_push.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const GENERATOR_SHED = preload("res://scripts/shed/generator_shed.gd")
const MESS_RULES = preload("res://core/systems/mess_rules.gd")
const BUILDING_MODELS = preload("res://scripts/building_models.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const GOODS := ["goods_cans", "goods_jars", "goods_drinks", "goods_bread"]
const UPKEEP_RULES = preload("res://core/systems/maintenance_rules.gd")
const SERVICE_LIFE = preload("res://scripts/food/service_life.gd")
## Where the work waits in here (the tap, the pass, the till...): scripts/food/work_marks.gd.
const WORK_MARKS = preload("res://scripts/food/work_marks.gd")
var _marks: Node
## The doors between a business's rooms, point and click (scripts/food/business_doors.gd).
const BUSINESS_DOORS = preload("res://scripts/food/business_doors.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
var _doors = BUSINESS_DOORS.new()
var _hot_glint = HOVER_GLINT.new()
var _hot_glint_on: Object = null
## The pub's rooms: the bar room and the cellar under it (its kegs).
var _pub_cellar_root: Node3D
var _pub_room := "main"

signal request_close
signal request_repair

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const AUDIO_MANAGER_SCRIPT = preload("res://scripts/audio_manager.gd")
const USE_LEGACY_SEWER_AMBIENCE := false
const SFX_SEWER_AMBIENCE := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const SEWER_AMBIENCE_VOLUME_DB := -3.5
const BASEMENT_MACHINE_ANIM_FRAME_TIME := 0.18

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)

var _is_open: bool = false
var _time_state: int = TIME_DAY
var _is_day_mode: bool = true
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _service_type: String = "restaurant"
var _current_profile: String = "rest"

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _room_root: Node3D
var _interior_camera: Camera3D
var _room_env: Environment
var _main_light: OmniLight3D
var _light_switch_body: StaticBody3D
var _light_switch_mesh: MeshInstance3D
var _light_switch_tex_on: Texture2D
var _light_switch_tex_off: Texture2D
var _manual_lights_on: bool = true
var _grid_power_available: bool = true
var _manual_light_tween: Tween
var _barrel_overlay: ColorRect
var _cam_base_rot: Vector3 = Vector3.ZERO
## Standing in a service building: you look around the room you are in.
var _sewer_hint: Label3D
var _sewer_broken: bool = false
var _look = INTERIOR_LOOK.new(65.0, 28.0, 38.0)
var _side_hints: Control
## The generator shed's two rooms, the junk and the board (scripts/shed/generator_shed.gd).
var _shed
var _exit_hint: Control
var _texture_style
var _restaurant_dining_root: Node3D
var _restaurant_kitchen_root: Node3D
var _restaurant_basement_root: Node3D
var _restaurant_room: String = "dining"
var _kitchen_texture_variant_alt: bool = false
var _pub_main_root: Node3D
var _vecerka_shop_root: Node3D
var _vecerka_storage_root: Node3D
var _active_subroom: String = "shop" # Generic subroom tracker
var _swipe_overlay: ColorRect
var _swipe_tween: Tween
var _swipe_animating: bool = false
var _sewer_ambience_player: AudioStreamPlayer
var _audio_loader: Node
var _basement_machine_anim_materials: Array[StandardMaterial3D] = []
var _basement_machine_anim_frames: Array[Texture2D] = []
var _basement_machine_anim_timer: float = 0.0
var _basement_machine_anim_frame: int = 0
## Cleaning a toilet / shower block from the inside (core/systems/mess_rules.gd
## block_tasks): the list is fixed when you first walk in and remembered per block
## until it is serviced, so leaving halfway keeps what you did.
var _upkeep_prep = null
var _upkeep_key := ""
## The counter minigames (scripts/food/*_closeup.gd): the tap in the pub, the pass in the
## bistro, the till in the Jednota. Click the thing in the room to step behind it.
const COUNTER_GAMES := {
	"pub": "res://scripts/food/tap_closeup.gd",
	"rest": "res://scripts/food/hatch_closeup.gd",
	"vecerka": "res://scripts/food/till_closeup.gd",
}
## The other jobs behind the counter: id -> {script, profile, room, at, size}.
const EXTRA_GAMES := {
	"shots": {"script": "res://scripts/food/shots_closeup.gd", "profile": "pub", "at": Vector3(1.35, 1.45, -2.05), "size": Vector3(1.4, 0.8, 0.4)},
	"wash": {"script": "res://scripts/food/glass_wash_closeup.gd", "profile": "pub", "at": Vector3(2.35, 1.05, -1.2), "size": Vector3(0.5, 0.4, 0.5)},
	"fryer": {"script": "res://scripts/food/fryer_closeup.gd", "profile": "rest", "room": "kitchen", "at": Vector3(0.0, 1.0, -2.02), "size": Vector3(1.0, 0.6, 0.7)},
}
var _extra_games: Dictionary = {}
var _counter_game: CanvasLayer
## The business's books on the counter (scripts/business/ledger_closeup.gd).
const LEDGER := preload("res://scripts/business/ledger_closeup.gd")
const LEDGER_AT := {"pub": Vector3(0.42, 1.08, -1.1), "rest": Vector3(1.42, 0.98, -1.12), "vecerka": Vector3(-1.4, 0.93, 0.55)}
var _ledger: CanvasLayer
## Which stall of the toilet block you go into: the door you walked up to outside
## ("left" / "right"), set by InteriorManager before open_service().
var toilet_entry := "left"
var _counter_game_profile := ""
## The guests in here (pub, bistro, shop): scripts/food/service_life.gd.
var _life: Node3D
var _upkeep_coord := Vector2i(-999, -999)
var _upkeep_type := ""
static var _upkeep_cache: Dictionary = {}   # key -> {tasks, done, broken}


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_audio_loader = AUDIO_MANAGER_SCRIPT.new()
	# Under the HUD (65), whose messages show over a room.
	layer = 58
	visible = false
	_build_viewport()
	_sync_viewport_to_window()
	_setup_sewer_ambience_player()
	_build_service_room("rest")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport_to_window()
		_update_swipe_overlay_size()


func is_open() -> bool:
	return _is_open


func is_sewer_profile_active() -> bool:
	return _is_open and _current_profile == "sewer"


func is_restaurant_basement_active() -> bool:
	return _is_open and _current_profile == "rest" and _restaurant_room == "basement"


func set_is_day(is_day: bool) -> void:
	set_time_state(TIME_DAY if is_day else TIME_NIGHT)


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


func open_service(service_type: String) -> void:
	# Registered before it was in the tree (size 0, shrink 1): the low resolution now.
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	_service_type = service_type
	var wanted_profile = _profile_for_service(service_type)
	if wanted_profile == "rest":
		_restaurant_room = "dining"
	if wanted_profile != _current_profile:
		_current_profile = wanted_profile
		_build_service_room(_current_profile)
	else:
		if _current_profile == "rest":
			_set_restaurant_room("dining", true)
		elif _current_profile == "toilet" and not _is_open:
			# The same room built as last time: in through the door you used now.
			_set_hygiene_room(toilet_entry)
		elif _current_profile == "wash" and not _is_open:
			_set_hygiene_room("center")
		_apply_time_profile()
	if _interior_camera == null:
		return
	if _is_open:
		_update_sewer_ambience_state()
		return
	_is_open = true
	visible = true
	_sync_viewport_to_window()
	if _current_profile == "generator" and _shed != null:
		_active_subroom = "set"
		_shed.on_open(_time_state == TIME_NIGHT, _nights_visited())
	_cam_base_rot = _interior_camera.rotation
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_sewer_ambience_state()


func close_service() -> void:
	if not _is_open:
		return
	if _upkeep_prep != null and _upkeep_prep.tasks != null and _upkeep_prep.tasks.is_scrubbing():
		_upkeep_prep.tasks._scrub.close()
	_is_open = false
	visible = false
	if _counter_game != null and _counter_game.visible:
		_counter_game.call("_closing")
		_counter_game.visible = false
	if _ledger != null and _ledger.visible:
		_ledger.visible = false
	for g in _extra_games.values():
		if (g as CanvasLayer).visible:
			(g as CanvasLayer).call("_closing")
			(g as CanvasLayer).visible = false
	_stop_life()
	_update_sewer_ambience_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	_update_basement_machine_animation(delta)
	if _marks != null and is_instance_valid(_marks):
		_marks.busy = [coop_job(), coop_partner_job]
	# Behind the counter in a close-up: the room holds still.
	if _counter_game != null and _counter_game.visible:
		return
	if _ledger != null and _ledger.visible:
		return
	if _sewer_terminal != null and _sewer_terminal.visible:
		return
	for g in _extra_games.values():
		if (g as CanvasLayer).visible:
			return
	if _current_profile == "sewer" and _sewer_bulb != null and is_instance_valid(_sewer_bulb):
		# The bare bulb that will not stay on.
		var flick := int(Time.get_ticks_msec() / 90) % 47
		_sewer_bulb.light_energy = 0.15 if flick in [3, 4, 19] else (0.6 if flick == 31 else 1.0)
	# Walking through a door: the walk has the camera.
	if _doors.walking():
		_hot_glint.clear()
		_hot_glint_on = null
		return
	if _current_profile == "generator" and _shed != null:
		_shed.update_hover(get_viewport().get_mouse_position())
	elif INTERIOR_LOOK.in_exit_zone(get_viewport()):
		HandCursor.want(HandCursor.WALK)
		_hover_things(null)
	else:
		var hit := _raycast_world(get_viewport().get_mouse_position())
		var collider = hit.get("collider", null) as Node
		if _doors.hover(collider, _door_room()) != "":
			HandCursor.want(HandCursor.WALK)
			_hover_things(null)
		elif _hover_click_type() != "":
			HandCursor.want(HandCursor.POINT)
			_hover_things(collider)
		else:
			_hover_things(null)
	_apply_idle_mouse_look(delta)
	_update_torch(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
		_side_hints = INTERIOR_LOOK.make_side_hints(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	var sides := _side_hint_texts()
	INTERIOR_LOOK.set_side_hints(_side_hints, sides[0], sides[1])


func _apply_idle_mouse_look(delta: float) -> void:
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_interior_camera.rotation = _cam_base_rot + offset
	# A/D turn the head; held on at the end of the turn, through the door that way.
	var push: int = _look.take_push()
	if push != 0 and not (_current_profile in ["rest", "vecerka", "pub"]):
		_switch_service_room(push)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if _upkeep_prep != null and _upkeep_prep.is_scrubbing():
		return
	# Esc is the pause menu's (main): S or the way out behind you leaves (but not a
	# click on something to clean, however low on the screen it is).
	var on_task: bool = _upkeep_prep != null and _upkeep_prep.is_busy()
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (on_task and event is InputEventMouseButton):
		close_service()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		var tab := INTERIOR_LOOK.side_tab_at(get_viewport(), _side_hints)
		if tab != 0:
			_switch_service_room(tab)
			get_viewport().set_input_as_handled()
			return
		if _try_click_world(mouse_event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("service_repair"):
		_try_request_service_repair()
		get_viewport().set_input_as_handled()
		return
	if _current_profile in ["sewer", "generator"] and event.is_action_pressed("interact"):
		_try_request_service_repair()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_secret_room"):
		_toggle_secret_room()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_kitchen_variant"):
		_toggle_kitchen_texture_variant()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		if key_event.physical_keycode == KEY_L:
			_toggle_manual_service_lights()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R:
			_try_request_service_repair()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_S:
			_toggle_secret_room()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_P:
			_toggle_kitchen_texture_variant()
			get_viewport().set_input_as_handled()
			return


func _try_click_world(event: InputEventMouseButton) -> bool:
	var hit = _raycast_world(event.position)
	if hit.is_empty():
		return false
	var collider = hit.get("collider", null) as Node
	if collider == null:
		return false
	if _current_profile == "generator" and _shed != null and _shed.click():
		return true
	var door_id := _doors.hover(collider, _door_room())
	if door_id != "":
		_go_door(door_id)
		return true
	if _node_has_click_type(collider, "service_stock"):
		_open_ledger()
		return true
	if _node_has_click_type(collider, "sewer_enter"):
		_try_request_service_repair()
		return true
	if _node_has_click_type(collider, "sewer_terminal"):
		_open_sewer_terminal()
		return true
	if not (collider is Node3D and (collider as Node3D).is_visible_in_tree()):
		return false
	if _node_has_click_type(collider, "service_light_switch"):
		_toggle_manual_service_lights()
		return true
	if _node_has_click_type(collider, "service_counter_game"):
		_open_counter_game()
		return true
	if _node_has_click_type(collider, "service_ledger"):
		_open_ledger()
		return true
	var n := collider as Node
	while n != null:
		if n.has_meta("service_game"):
			_open_extra_game(str(n.get_meta("service_game")))
			return true
		n = n.get_parent()
	return false


## What the cursor is over in the room, if it can be clicked ("" = nothing).
func _hover_click_type() -> String:
	var hit := _raycast_world(get_viewport().get_mouse_position())
	var collider = hit.get("collider", null) as Node
	if collider == null or not (collider is Node3D and (collider as Node3D).is_visible_in_tree()):
		return ""
	for t in ["service_light_switch", "service_counter_game", "service_ledger", "service_stock", "sewer_enter", "sewer_terminal"]:
		if _node_has_click_type(collider, t):
			return t
	var n := collider as Node
	while n != null:
		if n.has_meta("service_game"):
			return "service_game"
		n = n.get_parent()
	return ""


func _open_counter_game() -> void:
	var path := str(COUNTER_GAMES.get(_current_profile, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	if _counter_game != null and _counter_game_profile != _current_profile:
		_counter_game.queue_free()
		_counter_game = null
	if _counter_game == null:
		var scr = load(path)
		if not (scr is GDScript and (scr as GDScript).can_instantiate()):
			return
		_counter_game = scr.new()
		_counter_game.name = "CounterGame"
		add_child(_counter_game)
		_counter_game_profile = _current_profile
	_counter_game.set("building_key", _upkeep_key)
	_counter_game.open_view()


## The books: an accounts book lying open on the counter, its cover and its pages (the
## same Grok page as the close-up), a pencil across it; click it for the desk.
func _build_ledger(profile: String) -> void:
	if not LEDGER_AT.has(profile):
		return
	var parent: Node3D = {"pub": _pub_main_root, "rest": _restaurant_dining_root, "vecerka": _vecerka_shop_root}.get(profile)
	if parent == null:
		return
	var K := INTERIOR_KIT
	var at: Vector3 = LEDGER_AT[profile]
	var book := Node3D.new()
	book.name = "Ledger"
	book.position = at
	book.rotation.y = 0.25
	parent.add_child(book)
	K.slab(book, Vector3(0.36, 0.025, 0.25), Vector3(0, 0.0125, 0), K.surface("velvet", 0.3, Color(0.45, 0.12, 0.1)), "LedgerCover")
	var page := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.23)
	q.orientation = PlaneMesh.FACE_Y
	page.mesh = q
	# The open pages from above, pencil in the gutter (Grok, camp/ledger_open.png).
	var m := StandardMaterial3D.new()
	var page_tex := "res://assets/textury/camp/ledger_open.png"
	if ResourceLoader.exists(page_tex):
		m.albedo_texture = load(page_tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	page.material_override = m
	page.position = Vector3(0, 0.027, 0)
	book.add_child(page)
	var body := StaticBody3D.new()
	body.name = "LedgerSpot"
	body.set_meta("interior_click_type", "service_ledger")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 0.12, 0.32)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 0.05, 0)
	book.add_child(body)


## The other jobs' spots in this room (the back bar, the sink, the stove).
func _build_extra_games(profile: String) -> void:
	for id in EXTRA_GAMES:
		var g: Dictionary = EXTRA_GAMES[id]
		if str(g["profile"]) != profile:
			continue
		var parent: Node3D = _pub_main_root if profile == "pub" else (_restaurant_kitchen_root if str(g.get("room", "")) == "kitchen" else _restaurant_dining_root)
		if parent == null:
			continue
		var body := StaticBody3D.new()
		body.name = "Game_" + id
		body.set_meta("service_game", id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = g["size"]
		shape.shape = box
		body.add_child(shape)
		body.position = g["at"]
		parent.add_child(body)


func _open_extra_game(id: String) -> void:
	var g: Dictionary = EXTRA_GAMES.get(id, {})
	if g.is_empty() or not ResourceLoader.exists(str(g["script"])):
		return
	if not _extra_games.has(id):
		var inst: CanvasLayer = load(str(g["script"])).new()
		inst.name = "Game_" + id
		add_child(inst)
		_extra_games[id] = inst
	var game: CanvasLayer = _extra_games[id]
	game.set("building_key", _upkeep_key)
	game.open_view()


func _open_ledger() -> void:
	if _ledger == null:
		_ledger = LEDGER.new()
		_ledger.name = "Ledger"
		add_child(_ledger)
	var btype: String = {"pub": "pub", "rest": "restaurant", "vecerka": "vecerka"}.get(_current_profile, "")
	if btype == "":
		return
	_ledger.open_for(_upkeep_key, btype)


## A body over the counter thing (the tap tower on the bar, the bistro's pass, the till),
## clicked to open its minigame; nothing to see, the model is the thing.
func _build_counter_game(profile: String) -> void:
	var parent: Node3D = null
	var at := Vector3.ZERO
	var size := Vector3.ONE
	match profile:
		"pub":
			parent = _pub_main_root
			at = Vector3(1.275, 1.28, -1.405)
			size = Vector3(0.52, 0.46, 0.34)
		"rest":
			# The pass is the kitchen's: the island in the middle (plates, the bell).
			parent = _restaurant_kitchen_root
			at = Vector3(0.0, 1.05, 0.25)
			size = Vector3(1.3, 0.45, 0.7)
		"vecerka":
			parent = _vecerka_shop_root
			at = Vector3(-1.43, 1.12, -0.35)
			size = Vector3(0.5, 0.42, 0.6)
	if parent == null:
		return
	var body := StaticBody3D.new()
	body.name = "CounterGameSpot"
	body.position = at
	body.set_meta("interior_click_type", "service_counter_game")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


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


func _build_service_light_switch(profile: String) -> void:
	if _room_root == null:
		return
	_light_switch_tex_on = _pick_service_texture("interior_switch_on", Color(0.82, 0.78, 0.66))
	_light_switch_tex_off = _pick_service_texture("interior_switch_off", Color(0.66, 0.64, 0.58))
	var switch_pos = Vector3(2.74, 1.22, 1.78)
	if profile == "pub" or profile == "rest":
		switch_pos = Vector3(2.70, 1.26, 2.04)
	elif profile == "wash":
		switch_pos = Vector3(1.92, 1.24, 1.32)
	elif profile == "toilet":
		switch_pos = Vector3(2.00, 1.24, 1.20)
	var switch_body = StaticBody3D.new()
	switch_body.name = "ServiceLightSwitch"
	switch_body.position = switch_pos
	switch_body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	switch_body.set_meta("interior_click_type", "service_light_switch")
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
	_room_root.add_child(switch_body)
	_light_switch_body = switch_body
	_light_switch_mesh = switch_mesh
	_apply_service_switch_visual()


func _pick_service_texture(category: String, color: Color) -> Texture2D:
	if _texture_style == null:
		return null
	return _texture_style.pick_texture(category, color)


func _apply_service_switch_visual() -> void:
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


func _toggle_manual_service_lights() -> void:
	_manual_lights_on = not _manual_lights_on
	_apply_service_switch_visual()
	_apply_time_profile(true)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "ServiceViewportContainer"
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "ServiceViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.80, 0.76)
	env.ambient_light_energy = 0.94
	_room_env = env

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

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
	_barrel_overlay.visible = false
	add_child(_barrel_overlay)

	_swipe_overlay = ColorRect.new()
	_swipe_overlay.name = "ServiceRoomSwipe"
	_swipe_overlay.anchor_left = 0.0
	_swipe_overlay.anchor_top = 0.0
	_swipe_overlay.anchor_right = 0.0
	_swipe_overlay.anchor_bottom = 0.0
	_swipe_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_overlay.color = Color(0.04, 0.05, 0.06, 0.92)
	_swipe_overlay.visible = false
	add_child(_swipe_overlay)
	_update_swipe_overlay_size()


func _setup_sewer_ambience_player() -> void:
	if _sewer_ambience_player != null:
		return
	_sewer_ambience_player = AudioStreamPlayer.new()
	_sewer_ambience_player.name = "SewerAmbience"
	_sewer_ambience_player.volume_db = SEWER_AMBIENCE_VOLUME_DB
	_sewer_ambience_player.bus = "OutdoorAmbience"
	var stream = _load_service_stream(SFX_SEWER_AMBIENCE)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_sewer_ambience_player.stream = stream
	add_child(_sewer_ambience_player)


func _load_service_stream(res_path: String) -> AudioStream:
	var stream = load(res_path) as AudioStream
	if stream != null:
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		return stream
	if _audio_loader != null and _audio_loader.has_method("_try_load_stream"):
		var fallback = _audio_loader.call("_try_load_stream", res_path) as AudioStream
		if fallback is AudioStreamWAV:
			(fallback as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif fallback is AudioStreamMP3:
			(fallback as AudioStreamMP3).loop = true
		elif fallback is AudioStreamOggVorbis:
			(fallback as AudioStreamOggVorbis).loop = true
		return fallback
	return null


func _update_sewer_ambience_state() -> void:
	if not USE_LEGACY_SEWER_AMBIENCE:
		if _sewer_ambience_player != null and _sewer_ambience_player.playing:
			_sewer_ambience_player.stop()
		return
	if _sewer_ambience_player == null:
		return
	if _sewer_ambience_player.stream == null:
		_sewer_ambience_player.stream = _load_service_stream(SFX_SEWER_AMBIENCE)
		if _sewer_ambience_player.stream == null:
			printerr("[ServiceInterior] FAILED to load sewer ambience stream: ", SFX_SEWER_AMBIENCE)
			return
	
	var should_play = _is_open and _current_profile == "sewer"
	if should_play:
		if not _sewer_ambience_player.playing:
			var s = _sewer_ambience_player.stream
			if s is AudioStreamWAV:
				(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			elif s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			elif s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
				
			print("[ServiceInterior] STARTING sewer ambience. Vol: ", _sewer_ambience_player.volume_db, " Bus: ", _sewer_ambience_player.bus)
			_sewer_ambience_player.play()
	elif _sewer_ambience_player.playing:
		print("[ServiceInterior] STOPPING sewer ambience")
		_sewer_ambience_player.stop()


func _build_service_room(profile: String) -> void:
	if _viewport == null:
		return
	_swipe_animating = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	ROOM_PUSH.cancel(_viewport_container)
	if _swipe_overlay != null:
		_swipe_overlay.visible = false
	if _room_root != null and is_instance_valid(_room_root):
		if _room_root.get_parent() != null:
			_room_root.get_parent().remove_child(_room_root)
		_room_root.free()

	_room_root = Node3D.new()
	_room_root.name = "ServiceRoom"
	_viewport.add_child(_room_root)
	_doors.clear()
	_doors.host = self
	_hot_glint.clear()
	_hot_glint_on = null
	_pub_cellar_root = null
	_pub_room = "main"

	_interior_camera = Camera3D.new()
	_interior_camera.name = "ServiceCamera"
	_interior_camera.position = Vector3(0.0, 1.46, 1.96)
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_interior_camera.fov = 68.0
	_interior_camera.near = 0.05
	_interior_camera.far = 18.0
	_interior_camera.current = true
	_room_root.add_child(_interior_camera)

	_main_light = OmniLight3D.new()
	_main_light.position = Vector3(0.0, 2.30, 0.0)
	_main_light.light_color = Color(0.96, 0.94, 0.88)
	_main_light.light_energy = 1.28
	_main_light.omni_range = 8.0
	_main_light.omni_attenuation = 1.2
	_main_light.shadow_enabled = true
	_room_root.add_child(_main_light)
	_restaurant_dining_root = null
	_restaurant_kitchen_root = null
	_restaurant_basement_root = null
	_pub_main_root = null
	_vecerka_shop_root = null
	_vecerka_storage_root = null
	_light_switch_body = null
	_light_switch_mesh = null
	_manual_lights_on = true
	_basement_machine_anim_materials.clear()
	_basement_machine_anim_frames.clear()
	_basement_machine_anim_timer = 0.0
	_basement_machine_anim_frame = 0
	_free_upkeep_prep()
	if profile == "toilet":
		_build_toilet_layout()
		_active_subroom = toilet_entry
		_set_hygiene_room(toilet_entry)
	elif profile == "wash":
		_build_wash_layout(true)
		# _interior_camera set by _set_hygiene_room
		_active_subroom = "center"
		_set_hygiene_room("center")
	elif profile == "sewer":
		_build_sewer_layout()
	elif profile == "pub":
		_pub_main_root = Node3D.new()
		_pub_main_root.name = "PubMainRoom"
		_room_root.add_child(_pub_main_root)
		_build_pub_main_layout(_pub_main_root)
		_pub_cellar_root = Node3D.new()
		_pub_cellar_root.name = "PubCellar"
		_room_root.add_child(_pub_cellar_root)
		_build_pub_cellar_layout(_pub_cellar_root)
		_set_pub_room("main", true)
	elif profile == "vecerka":
		_vecerka_shop_root = Node3D.new()
		_vecerka_shop_root.name = "VecerkaShop"
		_room_root.add_child(_vecerka_shop_root)
		_vecerka_storage_root = Node3D.new()
		_vecerka_storage_root.name = "VecerkaStorage"
		_room_root.add_child(_vecerka_storage_root)
		
		_build_vecerka_shop_layout(_vecerka_shop_root)
		_build_vecerka_storage_layout(_vecerka_storage_root)
		_set_vecerka_room("shop", true)
	elif profile == "generator":
		_build_generator_layout()
		_active_subroom = "set"
		_shed.set_room("set", _interior_camera)
		_cam_base_rot = _interior_camera.rotation
	else:
		_restaurant_dining_root = Node3D.new()
		_restaurant_dining_root.name = "RestaurantDining"
		_room_root.add_child(_restaurant_dining_root)
		_restaurant_kitchen_root = Node3D.new()
		_restaurant_kitchen_root.name = "RestaurantKitchen"
		_room_root.add_child(_restaurant_kitchen_root)
		_restaurant_basement_root = Node3D.new()
		_restaurant_basement_root.name = "RestaurantBasement"
		_room_root.add_child(_restaurant_basement_root)
		# Restaurant dining now mirrors pub layout (pub is low-cost restaurant variant).
		_build_restaurant_dining_layout(_restaurant_dining_root)
		_build_restaurant_kitchen_layout(_restaurant_kitchen_root)
		_build_restaurant_basement_layout(_restaurant_basement_root)
		_set_restaurant_room(_restaurant_room, true)
	if profile != "sewer":
		_build_service_light_switch(profile)
	_build_counter_game(profile)
	_build_ledger(profile)
	_build_extra_games(profile)
	_build_business_doors(profile)

	_cam_base_rot = _interior_camera.rotation
	_apply_time_profile()
	_update_sewer_ambience_state()


func _build_restaurant_dining_layout(parent: Node3D) -> void:
	# A roadside bufet: oil-painted walls, checker lino, gingham tables, the till and its
	# fridge at the back right, a deer over the tables and the mushroom chart.
	var K := INTERIOR_KIT
	var size := Vector3(6.2, 2.9, 4.8)
	K.room(parent, size, "lino_checker", "oil_wall", "ceiling_board", size.y, 0.9, 0.05)
	K.skirting(parent, size, "planks_dark", 0.05)
	K.prop(parent, "shop_counter", Vector3(2.0, 0.05, -1.25))
	K.prop(parent, "fridge_tall", Vector3(2.65, 0.05, -2.02))
	K.prop(parent, "radio_set", Vector3(1.5, 0.99, -1.2), 10.0)
	for t: Vector3 in [Vector3(-1.7, 0.05, -1.0), Vector3(-1.7, 0.05, 0.9), Vector3(0.35, 0.05, 0.6)]:
		K.prop(parent, "gingham_table", t)
		K.prop(parent, "chair_wood", t + Vector3(-0.55, 0, 0), 90.0)
		K.prop(parent, "chair_wood", t + Vector3(0.55, 0, 0), -90.0)
	K.picture(parent, "picture_deer", Vector2(0.6, 0.8), Vector3(-3.04, 1.75, -0.1), 90.0, "Deer")
	K.picture(parent, "poster_mushrooms", Vector2(0.6, 0.8), Vector3(3.04, 1.6, 0.8), -90.0, "Mushrooms")
	var board := K.slab(parent, Vector3(2.0, 0.82, 0.04), Vector3(-0.3, 1.9, -2.36), K.surface("ceiling_board", 4.0, Color(1.05, 1.02, 0.94)), "DiningMenuBoard")
	K.slab(parent, Vector3(2.08, 0.9, 0.03), Vector3(-0.3, 1.9, -2.385), K.surface("planks_dark", 0.6), "MenuFrame")
	board.name = "DiningMenuBoard"
	var menu := Label3D.new()
	menu.text = "DNES VARIME / TODAY\nGoulash & dumplings .. 32 Kcs\nFried cheese ......... 28 Kcs\nPork, knedlo, zelo ... 35 Kcs\nBeer 10 .............. 6 Kcs\nKofola ............... 4 Kcs"
	menu.position = Vector3(-0.3, 1.9, -2.33)
	menu.font_size = 18
	menu.modulate = Color(0.12, 0.1, 0.08, 0.95)
	menu.outline_size = 0
	menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(menu)
	K.cutout(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(-2.2, 2.0, -2.37), 0.0, false, "Clock")
	K.cutout(parent, "plastic_plant", Vector2(0.45, 0.8), Vector3(2.7, 0.05, 1.9), 0.0, true, "Plant")
	for t: Vector3 in [Vector3(-1.7, 0.05, -1.0), Vector3(-1.7, 0.05, 0.9), Vector3(0.35, 0.05, 0.6)]:
		K.cutout(parent, "ashtray", Vector2(0.15, 0.13), t + Vector3(0.12, 0.76, -0.1), 0.0, true, "Ashtray")
	_sign(parent, "BUFET\ndiner", Vector3(-0.3, 2.6, -2.33), 30, "enamel")


func _build_restaurant_kitchen_layout(parent: Node3D) -> void:
	# The canteen kitchen: brown 70s tiles, checker lino, the range between two steel
	# counters at the back, an island in the middle, the big fridge, pots on a shelf.
	var K := INTERIOR_KIT
	var size := Vector3(6.2, 2.9, 4.8)
	K.room(parent, size, "lino_checker", "tiles_brown", "ceiling_board", 0.7, 0.9, 0.05)
	K.skirting(parent, size, "steel_kitchen", 0.05)
	K.prop(parent, "stove", Vector3(0.0, 0.05, -2.02))
	K.prop(parent, "steel_counter", Vector3(-1.35, 0.05, -2.06))
	K.prop(parent, "steel_counter", Vector3(1.35, 0.05, -2.06))
	K.prop(parent, "steel_counter", Vector3(0.0, 0.05, 0.25))
	K.prop(parent, "fridge_tall", Vector3(2.7, 0.05, -0.6), -90.0)
	K.prop(parent, "fridge_tall", Vector3(2.7, 0.05, 0.2), -90.0)
	K.prop(parent, "wall_shelf", Vector3(-2.9, 1.5, -0.6), 90.0, 1.6)
	K.prop(parent, "beer_crates", Vector3(-2.6, 0.05, -1.75), 90.0)
	K.prop(parent, "cardboard_boxes", Vector3(-2.55, 0.05, 0.2), 80.0)
	K.slab(parent, Vector3(1.7, 1.0, 0.04), Vector3(0.0, 1.6, 2.38), K.surface("steel_kitchen", 0.8), "KitchenPassDoor")
	_sign(parent, "KUCHYNE\nkitchen", Vector3(0.0, 2.36, -2.33), 32, "enamel")


func _build_restaurant_basement_layout(parent: Node3D) -> void:
	# The cellar: brick, a concrete floor, crates and drums along the walls, and in the
	# middle the machine nobody ordered (its core is animated, see _setup_basement_machine_animation).
	var K := INTERIOR_KIT
	var size := Vector3(6.2, 2.7, 4.8)
	K.room(parent, size, "concrete", "brick_red", "concrete", 1.0, 1.2, 0.05)
	var green := K.surface("metal_green", 0.8)
	K.slab(parent, Vector3(2.16, 1.44, 1.18), Vector3(0.0, 0.77, -0.20), green, "MachineBase")
	K.slab(parent, Vector3(2.28, 0.10, 1.30), Vector3(0.0, 1.53, -0.20), K.surface("steel_kitchen", 0.8), "MachineTop")
	var machine_core = _add_box("MachineCore", Vector3(0.0, 1.14, 0.42), Vector3(1.12, 0.66, 0.36), Color(0.70, 0.24, 0.18), "service_basement_machine_anim_539", parent)
	for x: float in [-1.28, 1.28]:
		K.slab(parent, Vector3(0.2, 1.2, 0.2), Vector3(x, 2.1, -0.70), K.surface("galvanized", 0.6), "MachinePipe")
	K.slab(parent, Vector3(2.76, 0.18, 0.18), Vector3(0.0, 2.6, -0.70), K.surface("galvanized", 0.6), "MachinePipeTop")
	K.prop(parent, "oil_drum", Vector3(-2.6, 0.05, -1.9))
	K.prop(parent, "oil_drum", Vector3(-2.0, 0.05, -2.0), 40.0)
	K.prop(parent, "beer_crates", Vector3(2.5, 0.05, -1.9))
	K.prop(parent, "cardboard_boxes", Vector3(2.5, 0.05, -0.75), -90.0)
	K.picture(parent, "poster_mushrooms", Vector2(0.6, 0.8), Vector3(-3.04, 1.5, 0.6), 90.0, "CellarChart")
	_setup_basement_machine_animation([machine_core])

	_sign(parent, "SKLEP\ncellar", Vector3(0.0, 2.25, -2.33), 32, "enamel")
	_sign(parent, "PROTOTYPE 540", Vector3(0.0, 0.55, 0.41), 18, "plate")


func _setup_basement_machine_animation(meshes: Array) -> void:
	_basement_machine_anim_materials.clear()
	_basement_machine_anim_frames.clear()
	_basement_machine_anim_timer = 0.0
	_basement_machine_anim_frame = 0
	if _texture_style == null:
		return
	var frame_categories = [
		"service_basement_machine_anim_539",
		"service_basement_machine_anim_540",
		"service_basement_machine_anim_541",
		"service_basement_machine_anim_542"
	]
	for category in frame_categories:
		var tex = _texture_style.pick_texture(category, Color(0.70, 0.24, 0.18))
		if tex != null:
			_basement_machine_anim_frames.append(tex)
	if _basement_machine_anim_frames.is_empty():
		return
	for mesh_any in meshes:
		var mesh = mesh_any as MeshInstance3D
		if mesh == null:
			continue
		var mat = mesh.material_override as StandardMaterial3D
		if mat == null:
			continue
		_basement_machine_anim_materials.append(mat)
	_apply_basement_machine_frame(0)


func _update_basement_machine_animation(delta: float) -> void:
	if _basement_machine_anim_frames.size() < 2:
		return
	if _basement_machine_anim_materials.is_empty():
		return
	_basement_machine_anim_timer += max(delta, 0.0)
	while _basement_machine_anim_timer >= BASEMENT_MACHINE_ANIM_FRAME_TIME:
		_basement_machine_anim_timer -= BASEMENT_MACHINE_ANIM_FRAME_TIME
		_apply_basement_machine_frame(_basement_machine_anim_frame + 1)


func _apply_basement_machine_frame(frame_index: int) -> void:
	var frame_count = _basement_machine_anim_frames.size()
	if frame_count == 0:
		return
	_basement_machine_anim_frame = wrapi(frame_index, 0, frame_count)
	var tex = _basement_machine_anim_frames[_basement_machine_anim_frame]
	for mat in _basement_machine_anim_materials:
		if mat == null:
			continue
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)


func _set_restaurant_room(room: String, update_camera: bool = true) -> void:
	if _restaurant_dining_root == null or _restaurant_kitchen_root == null or _restaurant_basement_root == null:
		return
	var wanted_room = "dining"
	if room == "kitchen":
		wanted_room = "kitchen"
	elif room == "basement":
		wanted_room = "basement"
	_restaurant_room = wanted_room
	_restaurant_dining_root.visible = (_restaurant_room == "dining")
	_restaurant_kitchen_root.visible = (_restaurant_room == "kitchen")
	_restaurant_basement_root.visible = (_restaurant_room == "basement")
	if update_camera and _interior_camera != null:
		if _restaurant_room == "kitchen":
			_interior_camera.position = Vector3(0.12, 1.50, 1.92)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		elif _restaurant_room == "basement":
			_interior_camera.position = Vector3(0.0, 1.44, 1.86)
			_interior_camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		else:
			_interior_camera.position = Vector3(0.0, 1.46, 1.96)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _build_pub_main_layout(
	parent: Node3D,
	title_text: String = "HOSPODA\nthe pub",
	nav_text: String = "",
	_seat_category: String = "service_rest_booth"
) -> void:
	# A village hospoda: dark panelled walls, worn plank floor, the bar on the right with
	# its taps and a wall of bottles, crates by the cellar door, two tables with chairs on
	# the left, a dartboard and the lake poster.
	var K := INTERIOR_KIT
	var size := Vector3(5.8, 2.8, 4.6)
	K.room(parent, size, "planks_red", "pub_panel", "planks_dark", 1.4, 1.0, 0.05)
	K.skirting(parent, size, "planks_dark", 0.05)
	K.prop(parent, "bar_counter", Vector3(1.35, 0.05, -1.25))
	K.prop(parent, "bottle_shelf", Vector3(1.35, 1.0, -2.16))
	K.prop(parent, "beer_crates", Vector3(2.5, 0.05, -1.95))
	K.prop(parent, "radio_set", Vector3(0.62, 1.13, -1.2), -15.0)
	for x: float in [0.6, 1.3, 2.0]:
		K.prop(parent, "bar_stool", Vector3(x, 0.05, -0.6))
	for t: Vector3 in [Vector3(-1.6, 0.05, -1.0), Vector3(-1.6, 0.05, 0.9)]:
		K.prop(parent, "pub_table", t)
		K.prop(parent, "chair_wood", t + Vector3(-0.55, 0, 0), 90.0)
		K.prop(parent, "chair_wood", t + Vector3(0.55, 0, 0), -90.0)
	K.prop(parent, "coat_hooks", Vector3(-1.6, 1.55, 2.27), 180.0)
	K.picture(parent, "poster_lake", Vector2(0.6, 0.8), Vector3(2.85, 1.6, 1.55), -90.0, "PubPoster")
	# The dartboard, the antlers, the brewery's enamel sign, the clock (Grok sprites, the
	# same as Lesna's pub: scripts/town/town_room.gd).
	K.cutout(parent, "dartboard", Vector2(0.48, 0.48), Vector3(-2.88, 1.46, -1.0), 90.0, false, "PubDartBoard")
	K.cutout(parent, "antlers", Vector2(0.4, 0.52), Vector3(-2.88, 1.6, 0.0), 90.0, false, "Antlers")
	K.picture(parent, "pub_sign", Vector2(0.7, 0.52), Vector3(-0.9, 1.75, -2.28), 0.0, "BrewerySign")
	K.cutout(parent, "wall_clock", Vector2(0.3, 0.3), Vector3(2.4, 1.85, -2.28), 0.0, false, "Clock")
	for t: Vector3 in [Vector3(-1.6, 0.05, -1.0), Vector3(-1.6, 0.05, 0.9)]:
		K.cutout(parent, "ashtray", Vector2(0.15, 0.13), t + Vector3(0.1, 0.74, 0.1), 0.0, true, "Ashtray")
		_pub_lamp(parent, t + Vector3(0, 2.05, 0))
	_pub_lamp(parent, Vector3(1.35, 2.15, -1.2))
	_sign(parent, title_text, Vector3(0.0, 2.36, -2.24), 30, "enamel")


## A lamp on its chain over a table, its brown glass shade a sprite, warm light.
func _set_pub_room(room: String, update_camera: bool = true) -> void:
	if _pub_main_root == null or _pub_cellar_root == null:
		return
	_pub_room = "cellar" if room == "cellar" else "main"
	_active_subroom = _pub_room
	_pub_main_root.visible = _pub_room == "main"
	_pub_cellar_root.visible = _pub_room == "cellar"
	if _pub_room == "cellar":
		_fill_cellar()
	if update_camera and _interior_camera != null:
		if _pub_room == "cellar":
			_interior_camera.position = Vector3(0.0, 1.44, 1.7)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		else:
			_interior_camera.position = Vector3(0.0, 1.46, 1.96)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


## The pub's cellar: brick and a concrete floor under a bare bulb, the kegs along the
## back wall (as many as there is beer in the books: _fill_cellar), crates of the rest.
func _build_pub_cellar_layout(parent: Node3D) -> void:
	var K := INTERIOR_KIT
	var size := Vector3(5.8, 2.5, 4.6)
	K.room(parent, size, "concrete", "brick_red", "concrete", 1.0, 1.2, 0.05)
	K.prop(parent, "wall_shelf", Vector3(-2.75, 1.4, -0.4), 90.0, 1.4)
	K.prop(parent, "oil_drum", Vector3(-2.4, 0.05, 1.5))
	K.slab(parent, Vector3(2.6, 0.12, 0.6), Vector3(0.0, 0.11, -1.9), K.surface("planks_dark", 0.8), "KegRack")
	var bulb := OmniLight3D.new()
	bulb.position = Vector3(0.0, 2.2, -0.2)
	bulb.light_color = Color(1.0, 0.86, 0.62)
	bulb.light_energy = 1.1
	bulb.omni_range = 5.5
	parent.add_child(bulb)
	_sign(parent, "SKLEP\ncellar", Vector3(-0.2, 2.05, -2.24), 30, "enamel")


## The doors between the rooms (business_doors.gd), in the walls the layouts left free.
func _build_business_doors(profile: String) -> void:
	match profile:
		"rest":
			_doors.add("d_kitchen", "dining", _restaurant_dining_root, Vector3(1.6, 0.05, -2.4), Vector3(0, 0, 1), "kitchen", "k_dining")
			_doors.add("k_dining", "kitchen", _restaurant_kitchen_root, Vector3(-3.1, 0.05, 1.45), Vector3(1, 0, 0), "dining", "d_kitchen")
			_doors.add("k_cellar", "kitchen", _restaurant_kitchen_root, Vector3(3.1, 0.05, 1.45), Vector3(-1, 0, 0), "basement", "c_kitchen")
			_doors.add("c_kitchen", "basement", _restaurant_basement_root, Vector3(3.1, 0.05, 1.3), Vector3(-1, 0, 0), "kitchen", "k_cellar")
			_build_stock_spot(_restaurant_basement_root, Vector3(-1.6, 0.6, -1.6), Vector3(2.4, 1.2, 1.4))
		"pub":
			_doors.add("p_cellar", "main", _pub_main_root, Vector3(2.9, 0.05, 0.3), Vector3(-1, 0, 0), "cellar", "pc_main")
			_doors.add("pc_main", "cellar", _pub_cellar_root, Vector3(2.9, 0.05, 0.9), Vector3(-1, 0, 0), "main", "p_cellar")
			_build_stock_spot(_pub_cellar_root, Vector3(0.0, 0.6, -1.8), Vector3(3.0, 1.2, 0.9))
		"vecerka":
			_doors.add("s_store", "shop", _vecerka_shop_root, Vector3(-1.8, 0.05, -1.1), Vector3(1, 0, 0), "storage", "st_shop")
			_doors.add("st_shop", "storage", _vecerka_storage_root, Vector3(1.8, 0.05, -1.1), Vector3(-1, 0, 0), "shop", "s_store")


## Which room of this building you are in (the doors of that room are the clickable ones).
func _door_room() -> String:
	match _current_profile:
		"rest":
			return _restaurant_room
		"pub":
			return _pub_room
		"vecerka":
			return _active_subroom
	return ""


func _go_door(id: String) -> void:
	_doors.go(id, _interior_camera,
		func(to: String): _apply_service_subroom(to, true),
		func() -> Array: return [_interior_camera.position, _interior_camera.rotation],
		func():
			var im := get_parent()
			if im != null and im.has_method("_door_transition"):
				im._door_transition(true))


## The goods in the cellar, click them for the books (what is on the shelf, ordering):
## the click box over them.
func _build_stock_spot(root: Node3D, at: Vector3, size: Vector3) -> void:
	if root == null:
		return
	var body := StaticBody3D.new()
	body.name = "StockSpot"
	body.set_meta("interior_click_type", "service_stock")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)


## What the books have on the shelf, stood in the cellar (each time you come down): the
## pub's kegs (one for every 25 pints), its crates of rum and kofola; the bistro's sacks of
## potatoes, the crates of dumplings, the boxes of cheese and goulash.
func _fill_cellar() -> void:
	var root: Node3D = _pub_cellar_root if _current_profile == "pub" else _restaurant_basement_root
	if root == null:
		return
	var old := root.get_node_or_null("Stock")
	if old != null:
		old.free()
	var stock_root := Node3D.new()
	stock_root.name = "Stock"
	root.add_child(stock_root)
	var site := _business_site()
	var stock: Dictionary = site.get("stock", {})
	var K := INTERIOR_KIT
	if _current_profile == "pub":
		var kegs := clampi(int(ceil(float(stock.get("beer", 0)) / 25.0)), 0, 6)
		for i in kegs:
			_keg(stock_root, Vector3(-1.05 + float(i % 6) * 0.42, 0.17, -1.9))
		var crates := clampi(int(ceil(float(int(stock.get("rum", 0)) + int(stock.get("kofola", 0))) / 12.0)), 0, 5)
		for i in crates:
			K.cutout(stock_root, "beer_crate_full", Vector2(0.55, 0.42), Vector3(1.9, 0.05 + float(i % 3) * 0.36, -1.0 + float(i / 3) * 0.6), -90.0, true, "Crate")
	else:
		var sacks := clampi(int(ceil(float(stock.get("potatoes", 0)) / 10.0)), 0, 6)
		for i in sacks:
			_flat(stock_root, "res://assets/textury/town/sack_potatoes.png", Vector2(0.5, 0.62), Vector3(-2.6 + float(i % 3) * 0.5, 0.05, -1.95 + float(i / 3) * 0.25))
		var breads := clampi(int(ceil(float(stock.get("dumplings", 0)) / 10.0)), 0, 4)
		for i in breads:
			_flat(stock_root, "res://assets/textury/town/crates_bread.png", Vector2(0.6, 0.45), Vector3(-1.1, 0.05 + float(i) * 0.4, -1.95))
		var boxes := clampi(int(ceil(float(int(stock.get("cheese", 0)) + int(stock.get("goulash", 0))) / 12.0)), 0, 4)
		for i in boxes:
			K.prop(stock_root, "cardboard_boxes", Vector3(-1.4 + float(i) * 0.5, 0.05, -1.0), 20.0 * float(i))


func _business_site() -> Dictionary:
	var BUSINESS := load("res://scripts/business/business_runtime.gd")
	return BUSINESS.site(_upkeep_key)


## A keg: a short cylinder in the keg's Grok face (assets/textury/town/keg.png).
func _keg(parent: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Keg"
	var c := CylinderMesh.new()
	c.top_radius = 0.19
	c.bottom_radius = 0.19
	c.height = 0.55
	c.radial_segments = 10
	mi.mesh = c
	var m := StandardMaterial3D.new()
	var path := "res://assets/textury/town/keg.png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = m
	mi.position = at + Vector3(0, 0.275, 0)
	parent.add_child(mi)


## A stand-up picture of a thing on the floor (a sack, a crate), facing the room.
func _flat(parent: Node3D, path: String, size: Vector2, at: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mi.material_override = m
	mi.position = at + Vector3(0, size.y * 0.5, 0)
	parent.add_child(mi)


## Whatever you can use under the cursor glints (the tap, the bottles, the books, the
## stock...): the meshes of its room that stand inside its click box.
func _hover_things(collider: Node) -> void:
	var body: Node3D = null
	var n := collider
	while n != null:
		if n is StaticBody3D and (n.has_meta("interior_click_type") or n.has_meta("service_game")):
			body = n
			break
		n = n.get_parent()
	if body == _hot_glint_on:
		return
	_hot_glint_on = body
	if body == null:
		_hot_glint.clear()
		return
	if not body.has_meta("glint_meshes"):
		body.set_meta("glint_meshes", _meshes_in_box(body))
	_hot_glint.show_on(body.get_meta("glint_meshes"))


func _meshes_in_box(body: StaticBody3D) -> Array:
	var out: Array = []
	var shape := body.get_child(0) as CollisionShape3D
	var box := shape.shape as BoxShape3D if shape != null else null
	if box == null:
		return out
	var half := box.size * 0.5 + Vector3(0.08, 0.08, 0.08)
	var inv := body.global_transform.affine_inverse()
	var room: Node = body.get_parent()
	while room != null and room.get_parent() != _room_root:
		room = room.get_parent()
	if room == null:
		room = body.get_parent()
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.name.begins_with("WorkMark"):
			continue
		var c := inv * m.global_transform * m.get_aabb().get_center()
		if absf(c.x) <= half.x and absf(c.y) <= half.y and absf(c.z) <= half.z:
			out.append(m)
	return out


func _pub_lamp(parent: Node3D, at: Vector3) -> void:
	var K := INTERIOR_KIT
	K.slab(parent, Vector3(0.015, 2.85 - at.y, 0.015), Vector3(at.x, (2.85 + at.y) * 0.5, at.z), K.surface("galvanized", 0.3, Color(0.3, 0.3, 0.3)), "LampChain")
	var shade := K.cutout(parent, "pub_lamp", Vector2(0.24, 0.42), at - Vector3(0, 0.42, 0), 0.0, true, "PubLamp")
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := shade.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = m.albedo_texture
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 0.7
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.76, 0.45)
	l.light_energy = 0.55
	l.omni_range = 2.8
	l.position = at - Vector3(0, 0.45, 0)
	parent.add_child(l)


func _build_vecerka_shop_layout(parent: Node3D) -> void:
	# The Jednota: oil-painted walls, brown lino, green racks of goods along the back and
	# the right, the counter with its till and scale on the left, the hot-dog steel by the
	# door, posters.
	var K := INTERIOR_KIT
	var size := Vector3(3.6, 3.2, 3.6)
	K.room(parent, size, "lino_floor", "oil_wall", "ceiling_board", 3.2, 1.0, 0.05)
	K.skirting(parent, size, "planks_dark", 0.05)
	_shelf_with_goods(parent, Vector3(-0.85, 0.05, -1.52), 0.0, 0)
	_shelf_with_goods(parent, Vector3(0.85, 0.05, -1.52), 0.0, 1)
	_shelf_with_goods(parent, Vector3(1.52, 0.05, 0.1), -90.0, 2)
	K.prop(parent, "shop_counter", Vector3(-1.38, 0.05, 0.05), 90.0)
	K.prop(parent, "steel_counter", Vector3(-1.4, 0.05, 1.22), 90.0, 0.8)
	K.slab(parent, Vector3(0.4, 0.1, 0.6), Vector3(-1.4, 0.82, 1.2), K.surface("steel_kitchen", 0.4, Color(0.6, 0.6, 0.62)), "HotdogGrill")
	K.picture(parent, "poster_mushrooms", Vector2(0.5, 0.66), Vector3(-1.79, 2.1, 0.75), 90.0, "PosterA")
	K.picture(parent, "shop_poster", Vector2(0.5, 0.66), Vector3(1.79, 2.25, 1.2), -90.0, "PosterB")
	# The things of a village shop (the same Grok art as Lesna's Jednota).
	K.cutout(parent, "shop_scales", Vector2(0.2, 0.38), Vector3(-1.45, 0.92, -0.45), 90.0, false, "Scales")
	K.cutout(parent, "card_box", Vector2(0.17, 0.24), Vector3(-1.4, 0.92, 0.45), 90.0, false, "Cards")
	K.cutout(parent, "beer_crate_full", Vector2(0.55, 0.42), Vector3(0.2, 0.05, 1.45), 0.0, true, "Crate")
	K.cutout(parent, "shop_baskets", Vector2(0.5, 0.48), Vector3(1.2, 0.05, 1.5), 0.0, true, "Baskets")
	var fridge := K.picture(parent, "shop_fridge", Vector2(0.62, 0.84), Vector3(1.79, 1.0, -0.95), -90.0, "FridgeDoor")
	var fm := fridge.material_override as StandardMaterial3D
	fm.emission_enabled = true
	fm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	fm.emission_texture = fm.albedo_texture
	fm.emission = Color(0.7, 0.85, 1.0)
	fm.emission_energy_multiplier = 0.4
	_sign(parent, "VECERKA\nopen till 22:00", Vector3(0.0, 2.65, -1.76), 34, "enamel")


## A green rack with a row of goods on every shelf (assets/textury/camp/goods_*.png).
func _shelf_with_goods(parent: Node3D, pos: Vector3, yaw: float, first: int) -> void:
	var K := INTERIOR_KIT
	var pivot := Node3D.new()
	pivot.name = "Rack"
	pivot.position = pos
	pivot.rotation_degrees.y = yaw
	parent.add_child(pivot)
	K.prop(pivot, "shop_shelf", Vector3.ZERO)
	var levels := [0.12, 0.5, 0.88, 1.26, 1.64]
	for i in levels.size():
		var tex: String = GOODS[(first + i) % GOODS.size()]
		var goods := K.picture(pivot, tex, Vector2(1.18, 0.34), Vector3(0, float(levels[i]) + 0.185, 0.04), 0.0, "Goods")
		# Repeat the row sideways so the goods keep their shape on a long shelf.
		var gmat := goods.material_override as StandardMaterial3D
		if gmat != null and gmat.albedo_texture != null:
			var t_size := gmat.albedo_texture.get_size()
			gmat.uv1_scale = Vector3(maxf(1.0, round((1.18 / 0.34) / (t_size.x / t_size.y))), 1.0, 1.0)


func _build_vecerka_storage_layout(parent: Node3D) -> void:
	# The storeroom: bare oil paint and concrete, staff lockers, a rack of tins, boxes and
	# crates waiting to be unpacked.
	var K := INTERIOR_KIT
	var size := Vector3(3.6, 3.2, 3.6)
	K.room(parent, size, "concrete", "oil_wall", "concrete", 3.2, 1.2, 0.05)
	K.prop(parent, "locker", Vector3(-0.9, 0.05, -1.52))
	_shelf_with_goods(parent, Vector3(0.85, 0.05, -1.52), 0.0, 3)
	K.prop(parent, "cardboard_boxes", Vector3(-1.3, 0.05, 0.2), 90.0)
	K.prop(parent, "beer_crates", Vector3(1.25, 0.05, 0.3), -90.0)
	K.prop(parent, "cardboard_boxes", Vector3(1.2, 0.05, 1.1), -70.0)
	_sign(parent, "SKLAD\nstaff only", Vector3(0.0, 2.6, -1.74), 34, "enamel")


func _set_vecerka_room(room: String, update_camera: bool = true) -> void:
	if _vecerka_shop_root == null or _vecerka_storage_root == null:
		return
	_active_subroom = room
	_vecerka_shop_root.visible = (room == "shop")
	_vecerka_storage_root.visible = (room == "storage")
	
	if update_camera and _interior_camera != null:
		if room == "storage":
			_interior_camera.position = Vector3(0.0, 1.5, 1.4)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		else:
			# Keep camera inside room volume; z=1.8 sits in the front wall plane for 3.6 depth.
			_interior_camera.position = Vector3(0.0, 1.5, 1.28)
			_interior_camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


## [left, right] door names for the side tabs (interior_look.make_side_hints).
func _side_hint_texts() -> Array:
	match _current_profile:
		"rest", "vecerka", "pub":
			# Doors (business_doors.gd): you click them, no tabs.
			return ["", ""]
		"rest":
			match _restaurant_room:
				"dining":
					return ["", "Kitchen  [D]"]
				"kitchen":
					return ["Dining room  [A]", "Cellar  [D]"]
				_:
					return ["Kitchen  [A]", ""]
		"vecerka":
			return ["", "Storeroom  [D]"] if _active_subroom == "shop" else ["Shop  [A]", ""]
		"sewer":
			# The pipe mouth is clicked (point and click), no tab.
			return ["", ""]
		"generator":
			if _active_subroom == "board":
				return ["Back  [A]", ""]
			if _sewer_broken:
				return ["", "Repair the set  [R]"]
			return ["", "Switch room  [D]" if _shed != null and _shed.can_enter_board() else ""]
		"toilet":
			# Each stall has its own door outside (playtest: "left door one toilet, the
			# other door the other one"): no way through the partition.
			return ["", ""]
		"wash":
			# One room for all the showers: A/D only turn the head.
			return ["", ""]
	return ["", ""]


func _switch_service_room(direction: int) -> void:
	if _swipe_animating:
		return
	var target_room = ""
	if _current_profile == "rest":
		if direction > 0 and _restaurant_room == "dining":
			target_room = "kitchen"
		elif direction < 0 and _restaurant_room == "basement":
			target_room = "kitchen"
		elif direction < 0 and _restaurant_room == "kitchen":
			target_room = "dining"
		elif direction > 0 and _restaurant_room == "kitchen":
			target_room = "basement"
	elif _current_profile == "vecerka":
		if direction > 0 and _active_subroom == "shop":
			target_room = "storage"
		elif direction < 0 and _active_subroom == "storage":
			target_room = "shop"
	elif _current_profile == "generator" and _shed != null:
		if direction > 0 and _active_subroom == "set":
			_shed.try_door()
			return
		elif direction < 0 and _active_subroom == "board":
			target_room = "set"
	elif _current_profile == "toilet":
		return
	elif _current_profile == "wash":
		return
	
	if target_room == "":
		return
	if _current_profile == "rest" and target_room == _restaurant_room:
		return
	if _current_profile == "vecerka" and target_room == _active_subroom:
		return
	if (_current_profile == "toilet" or _current_profile == "wash") and target_room == _active_subroom:
		return
	_play_room_swipe(target_room, direction)


func _toggle_secret_room() -> void:
	if _current_profile != "rest":
		return
	if _swipe_animating:
		return
	if _restaurant_room == "kitchen":
		_play_room_swipe("basement", 1)
	elif _restaurant_room == "basement":
		_play_room_swipe("kitchen", -1)


func _toggle_kitchen_texture_variant() -> void:
	_kitchen_texture_variant_alt = not _kitchen_texture_variant_alt
	if _current_profile != "rest":
		return
	var wanted_room = _restaurant_room
	var wanted_manual_lights = _manual_lights_on
	_build_service_room("rest")
	_set_restaurant_room(wanted_room, true)
	_manual_lights_on = wanted_manual_lights
	_apply_service_switch_visual()
	_apply_manual_service_light_profile(false)


func _apply_service_subroom(target_room: String, update_camera: bool = true) -> void:
	# Through the door you face the new room, not the wall you pushed at.
	_look.reset()
	if _current_profile == "rest":
		_set_restaurant_room(target_room, update_camera)
	elif _current_profile == "pub":
		_set_pub_room(target_room, update_camera)
	elif _current_profile == "vecerka":
		_set_vecerka_room(target_room, update_camera)
	elif _current_profile == "toilet" or _current_profile == "wash":
		_set_hygiene_room(target_room)
	elif _current_profile == "generator" and _shed != null:
		_active_subroom = target_room
		_shed.set_room(target_room, _interior_camera)
		_cam_base_rot = _interior_camera.rotation
		_look.reset()


## Where you stand in the shower room (just inside the door, the room is 3.2 m deep).
const WASH_CAM_Z := 1.3
## The shower room's glass blocks: the daylight comes through them (_apply_time_profile).
var _wash_glass: StandardMaterial3D


func _set_hygiene_room(room: String) -> void:
	if _interior_camera == null:
		return
	_active_subroom = room
	if _current_profile == "toilet":
		# In the doorway of the stall, looking down at the bowl.
		var sx := TOILET_STALL_X * (1.0 if room == "right" else -1.0)
		_interior_camera.position = Vector3(sx, 1.55, TOILET_D * 0.5 - 0.12)
		_interior_camera.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
	else:
		# The shower room is one room: in the doorway, the three cubicles ahead, the
		# bench to the left, the trough and the boiler to the right (turn the head).
		_interior_camera.position = Vector3(0.0, 1.5, WASH_CAM_Z)
		_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _play_room_swipe(target_room: String, direction: int) -> void:
	if _swipe_overlay == null:
		_apply_service_subroom(target_room, true)
		return
	_update_swipe_overlay_size()
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		_apply_service_subroom(target_room, true)
		return
	# The room you leave slides away as the next slides in (scripts/ui/room_push.gd).
	_swipe_animating = true
	_swipe_overlay.visible = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	_swipe_tween = ROOM_PUSH.play(self, _viewport_container, _viewport, direction,
		Callable(self, "_apply_service_subroom").bind(target_room, true), Callable(self, "_finish_room_swipe"))


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


## Inside the WC shack (hajzly in the Builder): grey planks, two stalls with their doors
## open on white bowls, a tin urinal trough between them, a basin and a cracked mirror
## on the left, the heart window on the right. Cleaning spots: MESS_RULES.BLOCK_SPOTS.
func _build_toilet_layout() -> void:
	var K := INTERIOR_KIT
	# The outhouse outside (building_models._toilets: 2.9 x 2.1, two doors with hearts):
	# inside, the same two stalls side by side, one behind each door, a bowl in each
	# (playtest 2026-10-17: "match the toilets inside to outside, two single toilets").
	var w := TOILET_W
	var d := TOILET_D
	var h := 2.25
	var r := _room_root
	var shell := K.room(r, Vector3(w, h, d), "concrete", "planks_grey", "planks_dark", 1.2, 1.2)
	(shell["ceiling"] as MeshInstance3D).material_override = K.surface("planks_dark", 1.0, Color(0.8, 0.74, 0.66))
	var planks := K.surface("planks_grey", 1.2)
	K.slab(r, Vector3(0.05, h, d), Vector3(0, h * 0.5, 0), planks, "StallPartition")
	var wall_body := StaticBody3D.new()
	wall_body.name = "StallPartitionBody"
	wall_body.position = Vector3(0, h * 0.5, 0)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.05, h, d)
	wall_shape.shape = wall_box
	wall_body.add_child(wall_shape)
	r.add_child(wall_body)
	for side: float in [-1.0, 1.0]:
		var cx := side * TOILET_STALL_X
		_build_bowl(r, Vector3(cx, 0.0, -d * 0.5 + 0.32))
		# Paper on the partition, the newspaper on a nail on the outer wall.
		var roll := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 0.1
		roll.mesh = cyl
		roll.material_override = INTERIOR_PREP.flat(Color(0.92, 0.9, 0.84))
		roll.rotation.z = PI * 0.5
		roll.position = Vector3(cx - side * 0.66, 0.78, -d * 0.5 + 0.55)
		r.add_child(roll)
		K.slab(r, Vector3(0.02, 0.24, 0.18), Vector3(side * (w * 0.5 - 0.02), 1.05, -d * 0.5 + 0.6), INTERIOR_PREP.flat(Color(0.8, 0.78, 0.7)), "Newspaper")
		# The heart cut in the door lets a little day in: a warm patch on the floor.
		var heart := OmniLight3D.new()
		heart.position = Vector3(cx, 1.6, d * 0.5 - 0.1)
		heart.light_color = Color(1.0, 0.92, 0.78)
		heart.light_energy = 0.35
		heart.omni_range = 2.2
		r.add_child(heart)
		var bulb := MeshInstance3D.new()
		var bulb_mesh := SphereMesh.new()
		bulb_mesh.radius = 0.045
		bulb_mesh.height = 0.09
		bulb.mesh = bulb_mesh
		var bulb_mat := INTERIOR_PREP.flat(Color(1.0, 0.95, 0.8))
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.9, 0.7)
		bulb.material_override = bulb_mat
		bulb.position = Vector3(cx, h - 0.22, 0.0)
		r.add_child(bulb)
	_sign(r, "ZENY", Vector3(-TOILET_STALL_X, 2.0, -d * 0.5 + 0.03), 18, "enamel")
	_sign(r, "MUZI", Vector3(TOILET_STALL_X, 2.0, -d * 0.5 + 0.03), 18, "enamel")
	_interior_camera.position = Vector3(-TOILET_STALL_X, 1.55, d * 0.5 - 0.12)
	_interior_camera.rotation_degrees = Vector3(-30.0, 0.0, 0.0)


const TOILET_W := 2.9
const TOILET_D := 2.1
const TOILET_STALL_X := 0.72


## A proper outhouse toilet, Build style: the pedestal, the bowl, the black seat with the
## lid up, the high cistern on its pipe and the pull chain.
func _build_bowl(r: Node3D, at: Vector3) -> void:
	var porcelain := INTERIOR_KIT.surface("porcelain", 0.4)
	var ped := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.13
	pc.bottom_radius = 0.15
	pc.height = 0.3
	pc.radial_segments = 12
	ped.mesh = pc
	ped.material_override = porcelain
	ped.position = at + Vector3(0, 0.15, 0.04)
	ped.scale = Vector3(1.0, 1.0, 1.25)
	r.add_child(ped)
	var bowl := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.21
	bc.bottom_radius = 0.15
	bc.height = 0.13
	bc.radial_segments = 14
	bowl.mesh = bc
	bowl.material_override = porcelain
	bowl.position = at + Vector3(0, 0.36, 0.06)
	bowl.scale = Vector3(1.0, 1.0, 1.3)
	r.add_child(bowl)
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 0.15
	wc.bottom_radius = 0.15
	wc.height = 0.004
	wc.radial_segments = 14
	water.mesh = wc
	water.material_override = INTERIOR_PREP.flat(Color(0.32, 0.38, 0.36))
	water.position = at + Vector3(0, 0.42, 0.06)
	water.scale = Vector3(1.0, 1.0, 1.3)
	r.add_child(water)
	var seat := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.14
	tm.outer_radius = 0.22
	tm.rings = 18
	tm.ring_segments = 6
	seat.mesh = tm
	seat.material_override = INTERIOR_PREP.flat(Color(0.08, 0.08, 0.09))
	seat.position = at + Vector3(0, 0.44, 0.06)
	seat.scale = Vector3(1.0, 0.25, 1.28)
	r.add_child(seat)
	var lid := INTERIOR_KIT.slab(r, Vector3(0.4, 0.46, 0.025), at + Vector3(0, 0.68, -0.2), INTERIOR_PREP.flat(Color(0.1, 0.1, 0.11)), "Lid")
	lid.rotation.x = -0.12
	INTERIOR_KIT.slab(r, Vector3(0.46, 0.22, 0.16), at + Vector3(0, 1.86, -0.22), INTERIOR_KIT.surface("enamel_white", 0.5), "Cistern")
	var pipe := MeshInstance3D.new()
	var pcy := CylinderMesh.new()
	pcy.top_radius = 0.022
	pcy.bottom_radius = 0.022
	pcy.height = 1.3
	pipe.mesh = pcy
	pipe.material_override = INTERIOR_KIT.surface("galvanized", 0.3)
	pipe.position = at + Vector3(0, 1.12, -0.24)
	r.add_child(pipe)
	INTERIOR_KIT.slab(r, Vector3(0.008, 0.5, 0.008), at + Vector3(0.2, 1.52, -0.15), INTERIOR_KIT.surface("galvanized", 0.2), "Chain")
	INTERIOR_KIT.slab(r, Vector3(0.03, 0.08, 0.03), at + Vector3(0.2, 1.24, -0.15), INTERIOR_PREP.flat(Color(0.86, 0.84, 0.78)), "ChainHandle")


## Inside the shower block (sprchy in the Builder): three tiled cubicles at the back
## with curtains, drains, a bench with hooks on the left, sinks on the right, the
## boiler pipe along the ceiling.
func _build_wash_layout(shower_mode: bool, title_override: String = "") -> void:
	var K := INTERIOR_KIT
	var w := 3.6
	var d := 3.2
	var h := 2.5
	var r := _room_root
	# Tiled cubicles at the back, oil-painted walls, a tiled floor, the boiler pipe.
	var shell := K.room(r, Vector3(w, h, d), "tiles_green", ["tiles_bathroom", "oil_wall", "oil_wall", "tiles_bathroom"], "concrete", 0.9, 0.7)
	for key in ["front", "left"]:
		(shell[key] as MeshInstance3D).material_override = K.surface("oil_wall", h)
	var tiles := K.surface("tiles_bathroom", 0.9)
	for i in 3:
		var cx := -1.15 + i * 1.15
		if i < 2:
			K.slab(r, Vector3(0.05, 2.0, 1.1), Vector3(cx + 0.575, 1.0, -d * 0.5 + 0.55), tiles, "Partition")
		if shower_mode:
			K.prop(r, "duckboard", Vector3(cx, 0.0, -1.05))
			var pipe := K.slab(r, Vector3(0.04, 1.0, 0.04), Vector3(cx + 0.25, 1.7, -d * 0.5 + 0.06), K.surface("galvanized", 0.3), "ShowerPipe")
			pipe.name = "ShowerPipe"
			var head := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.03
			cone.bottom_radius = 0.08
			cone.height = 0.08
			head.mesh = cone
			head.material_override = K.surface("galvanized", 0.3)
			head.position = Vector3(cx + 0.25, 2.18, -d * 0.5 + 0.16)
			head.rotation.x = 0.6
			r.add_child(head)
			var curtain := K.slab(r, Vector3(0.36, 1.6, 0.02), Vector3(cx + 0.36, 1.15, -d * 0.5 + 1.1), K.surface("curtain_floral", 0.9), "Curtain")
			curtain.rotation.y = 0.08
		else:
			K.prop(r, "sink_pedestal", Vector3(cx, 0.0, -d * 0.5 + 0.25))
		K.slab(r, Vector3(1.1, 0.025, 0.025), Vector3(cx, 2.0, -d * 0.5 + 1.1), K.surface("galvanized", 0.3), "CurtainRail")
	# The bench and hooks on the left, the wash trough and a mirror on the right.
	K.prop(r, "bench_slatted", Vector3(-w * 0.5 + 0.3, 0.0, 0.55), 90.0)
	K.prop(r, "coat_hooks", Vector3(-w * 0.5 + 0.03, 1.55, 0.55), 90.0)
	K.slab(r, Vector3(0.03, 0.5, 0.3), Vector3(-w * 0.5 + 0.1, 1.33, 0.4), K.surface("blanket_grey", 0.4, Color(1.0, 0.55, 0.5)), "Towel")
	K.prop(r, "wash_trough", Vector3(w * 0.5 - 0.24, 0.0, 0.45), -90.0)
	K.prop(r, "mirror_frame", Vector3(w * 0.5 - 0.05, 1.3, 0.45), -90.0, 1.2)
	var boiler_pipe := MeshInstance3D.new()
	var bp := CylinderMesh.new()
	bp.top_radius = 0.04
	bp.bottom_radius = 0.04
	bp.height = w
	boiler_pipe.mesh = bp
	boiler_pipe.material_override = K.surface("galvanized", 0.5, Color(1.0, 0.8, 0.6))
	boiler_pipe.position = Vector3(0, h - 0.18, -d * 0.5 + 0.25)
	boiler_pipe.rotation.z = PI * 0.5
	r.add_child(boiler_pipe)
	var boiler := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.25
	bc.bottom_radius = 0.25
	bc.height = 0.8
	boiler.mesh = bc
	boiler.material_override = K.surface("enamel_white", 0.5)
	boiler.position = Vector3(w * 0.5 - 0.35, h - 0.55, -0.6)
	r.add_child(boiler)
	# The concrete house's strip of glass blocks under the ceiling over the cubicles and a
	# square of them in each side wall (building_models._showers), and the bulb.
	var glass := K.surface("glass_blocks", 0.42) if ResourceLoader.exists("res://assets/textury/camp/glass_blocks.png") else K.surface("tiles_bathroom", 0.9, Color(0.7, 0.85, 0.88))
	_wash_glass = glass as StandardMaterial3D
	K.slab(r, Vector3(w * 0.78, 0.42, 0.03), Vector3(0, h - 0.3, -d * 0.5 + 0.02), glass, "GlassBlocks")
	for side: float in [-1.0, 1.0]:
		var gb := K.slab(r, Vector3(0.56, 0.42, 0.03), Vector3(side * (w * 0.5 - 0.02), h - 0.3, -d * 0.5 + 0.7), glass, "GlassBlocks")
		gb.rotation.y = PI * 0.5
	K.slab(r, Vector3(0.16, 0.05, 0.16), Vector3(0, h - 0.025, 0.1), K.surface("galvanized", 0.3), "BulbRose")
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.06
	bulb_mesh.height = 0.12
	bulb.mesh = bulb_mesh
	bulb.material_override = INTERIOR_PREP.flat(Color(1.0, 0.94, 0.72))
	bulb.position = Vector3(0, h - 0.11, 0.1)
	r.add_child(bulb)
	var default_title = "SPRCHY\nshowers" if shower_mode else "UMYVARNA\nwashroom"
	var sign := _sign(r, title_override if title_override != "" else default_title, Vector3(-w * 0.5 + 0.06, 1.95, -0.6), 24, "enamel")
	sign.rotation_degrees.y = 90.0
	_interior_camera.position = Vector3(0.0, 1.5, WASH_CAM_Z)
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)


## A sign on a wall (facing +Z from `pos`, turn the returned node to put it elsewhere):
## an enamel plate sized to the text, a dark rim and the lettering. Styles: "enamel"
## (cream, dark ink), "danger" (yellow, red ink), "plate" (steel, black ink).
func _sign(parent: Node3D, text: String, pos: Vector3, font_size: int, style: String = "enamel") -> Node3D:
	var K := INTERIOR_KIT
	var root := Node3D.new()
	root.name = "Sign"
	root.position = pos
	parent.add_child(root)
	var lines := text.split("\n")
	var longest := 0
	for line in lines:
		longest = maxi(longest, line.length())
	var char_h := float(font_size) * 0.005
	var size := Vector2(longest * char_h * 0.62 + 0.16, lines.size() * char_h * 1.15 + 0.1)
	var plate := Color(0.92, 0.9, 0.82)
	var ink := Color(0.12, 0.12, 0.16)
	var rim := Color(0.16, 0.2, 0.36)
	if style == "danger":
		plate = Color(0.95, 0.8, 0.2)
		ink = Color(0.6, 0.06, 0.04)
		rim = Color(0.1, 0.08, 0.06)
	elif style == "plate":
		plate = Color(0.62, 0.64, 0.66)
		ink = Color(0.06, 0.06, 0.06)
		rim = Color(0.3, 0.3, 0.32)
	K.slab(root, Vector3(size.x + 0.05, size.y + 0.05, 0.015), Vector3(0, 0, -0.012), INTERIOR_PREP.flat(rim), "SignRim")
	K.slab(root, Vector3(size.x, size.y, 0.02), Vector3(0, 0, -0.004), INTERIOR_PREP.flat(plate), "SignPlate")
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 0
	label.modulate = ink
	label.position = Vector3(0, 0, 0.008)
	label.shaded = true
	root.add_child(label)
	return root


## The sewer's pumping chamber, down the ladder from the hatch (Grok faces and textures,
## assets/textury/camp/sewer_*.png): wet stained concrete, a gutter of grey water
## running out of the pipe mouth in the back wall (its grille hanging open, scratches,
## hair, hand prints going in: click it to crawl in, broken or not), a wall of valves
## and gauges, the amber monitoring terminal on its desk (click it: the network and its
## faults), rusted pipes along the ceiling, a bare bulb that will not stay on, the ladder
## up behind you. The other warden down here is seen as in any room.
const SEWER_TERMINAL = preload("res://scripts/pipes/sewer_terminal.gd")
## The rooms' pixel: their textures are 128 px to a 1.4 m tile.
const ROOM_PX_PER_M := 128.0 / 1.4
var _sewer_terminal: CanvasLayer
var _sewer_bulb: OmniLight3D


func _sewer_tex(name: String, fallback: String) -> String:
	return name if ResourceLoader.exists(INTERIOR_KIT.TEX + name + ".png") else fallback


func _build_sewer_layout() -> void:
	var w := 5.2
	var d := 5.6
	var h := 2.8
	var K := INTERIOR_KIT
	K.room(_room_root, Vector3(w, h, d), _sewer_tex("sewer_floor", "concrete"), _sewer_tex("sewer_wall", "pipe_concrete"), "concrete", 1.4, 1.4, 0.05)
	# The gutter out of the pipe mouth, the length of the chamber.
	K.slab(_room_root, Vector3(0.62, 0.05, d - 0.3), Vector3(0.0, 0.03, 0.0), K.surface(_sewer_tex("sewer_water", "sewer_floor"), 0.25, Color(0.62, 0.66, 0.52)), "SewerChannel")
	# The pipe mouth in the back wall, low: the way in.
	var mouth_path := INTERIOR_KIT.TEX + "sewer_mouth.png"
	var mouth: MeshInstance3D = null
	if ResourceLoader.exists(mouth_path):
		mouth = K.picture(_room_root, "sewer_mouth", Vector2(2.1, 2.1), Vector3(0.0, 1.05, -d * 0.5 + 0.02), 0.0, "PipeMouth")
	else:
		mouth = K.slab(_room_root, Vector3(1.2, 1.2, 0.04), Vector3(0.0, 0.62, -d * 0.5 + 0.03), K.surface("concrete", 1.0, Color(0.1, 0.1, 0.1)), "PipeMouth")
	# The hole is left of the picture's middle (Grok, camp/sewer_mouth.png).
	_click_box(_room_root, "sewer_enter", Vector3(-0.32, 1.05, -d * 0.5 + 0.15), Vector3(1.1, 1.1, 0.3))
	if ResourceLoader.exists("res://assets/textury/camp/sewer_sign.png"):
		K.cutout(_room_root, "sewer_sign", Vector2(0.5, 0.35), Vector3(1.3, 1.7, -d * 0.5 + 0.03), 0.0, false, "WarningPlate")
	# The valves and gauges on the left wall.
	if ResourceLoader.exists(INTERIOR_KIT.TEX + "sewer_valves.png"):
		K.picture(_room_root, "sewer_valves", Vector2(3.4, 1.9), Vector3(-w * 0.5 + 0.02, 1.4, -0.4), 90.0, "ValveWall")
	# The terminal on its desk, at the right, turned to you.
	var term_at := Vector3(1.85, 0.0, -1.2)
	if ResourceLoader.exists(INTERIOR_KIT.TEX + "sewer_terminal.png"):
		var t := K.picture(_room_root, "sewer_terminal", Vector2(1.5, 1.5), term_at + Vector3(0, 0.75, 0), -35.0, "Terminal")
		t.name = "Terminal"
	else:
		K.prop(_room_root, "steel_counter", term_at, -35.0, 0.6)
	_click_box(_room_root, "sewer_terminal", term_at + Vector3(0, 0.85, 0.1), Vector3(1.2, 1.0, 0.6), -35.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.15)
	glow.light_energy = 0.55
	glow.omni_range = 2.0
	glow.position = term_at + Vector3(-0.3, 1.0, 0.45)
	_room_root.add_child(glow)
	# Rusted pipes along the ceiling and down the corners.
	var rust := K.surface("galvanized", 0.6, Color(0.55, 0.36, 0.24))
	for z: float in [-2.2, -1.5, 1.6]:
		_pipe_run(_room_root, Vector3(-w * 0.5, h - 0.25 - absf(z) * 0.03, z), Vector3(w * 0.5, h - 0.25 - absf(z) * 0.03, z), 0.09 if z < 0.0 else 0.06, rust)
	for c: Vector3 in [Vector3(-w * 0.5 + 0.18, 0.0, -d * 0.5 + 0.18), Vector3(w * 0.5 - 0.18, 0.0, -d * 0.5 + 0.18)]:
		_pipe_run(_room_root, c, c + Vector3(0, h, 0), 0.12, rust)
	# The ladder up behind you, the daylight (or the night) through the hatch over it.
	var steel := K.surface("galvanized", 0.4, Color(0.5, 0.48, 0.44))
	for x: float in [-0.25, 0.25]:
		K.slab(_room_root, Vector3(0.05, h, 0.05), Vector3(x, h * 0.5, d * 0.5 - 0.12), steel, "LadderRail")
	for i in 8:
		K.slab(_room_root, Vector3(0.5, 0.035, 0.035), Vector3(0, 0.3 + i * 0.32, d * 0.5 - 0.12), steel, "LadderRung")
	# What lies about: a drum, a bucket, a rag of a coat on a nail.
	K.prop(_room_root, "oil_drum", Vector3(-1.9, 0.05, -2.2))
	K.prop(_room_root, "slop_bucket", Vector3(0.75, 0.05, -2.3))
	for dec in [["res://assets/textury/mess/decal_handprint.png", Vector3(-0.85, 0.5, -d * 0.5 + 0.015), 0.22], ["res://assets/textury/mess/decal_handprint.png", Vector3(0.82, 0.32, -d * 0.5 + 0.015), 0.2], ["res://assets/textury/mess/decal_scratches.png", Vector3(-0.6, 1.3, -d * 0.5 + 0.015), 0.4]]:
		if ResourceLoader.exists(str(dec[0])):
			_wall_decal(_room_root, str(dec[0]), dec[1], float(dec[2]))
	# The bulb, flickering (_process).
	_sewer_bulb = OmniLight3D.new()
	_sewer_bulb.light_color = Color(1.0, 0.86, 0.6)
	_sewer_bulb.light_energy = 1.0
	_sewer_bulb.omni_range = 6.5
	_sewer_bulb.position = Vector3(0.2, h - 0.35, 0.3)
	_room_root.add_child(_sewer_bulb)
	_interior_camera.position = Vector3(0.0, 1.5, d * 0.5 - 0.7)
	_interior_camera.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	_sewer_hint = null


## A click box for the chamber's things (the pipe mouth, the terminal).
func _click_box(root: Node3D, kind: String, at: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Click_" + kind
	body.set_meta("interior_click_type", kind)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	body.rotation_degrees.y = yaw
	root.add_child(body)


func _pipe_run(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = mat
	root.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.99:
		mi.look_at_from_position(mi.position, b, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## A mark on the wall `size` m tall, brought down to the rooms' own pixel (128 px to
## 1.4 m): the picture is shrunk to as many pixels as the wall has there.
func _wall_decal(root: Node3D, path: String, at: Vector3, size: float) -> void:
	var src: Texture2D = load(path)
	var img: Image = src.get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	var px_h := maxi(2, roundi(size * ROOM_PX_PER_M))
	var px_w := maxi(1, roundi(float(img.get_width()) * float(px_h) / float(img.get_height())))
	img.resize(px_w, px_h, Image.INTERPOLATE_BILINEAR)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(px_w, px_h) / ROOM_PX_PER_M
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = m
	mi.position = at
	root.add_child(mi)


func _open_sewer_terminal() -> void:
	var crawl = get_tree().current_scene.get("_sewer_pipe_minigame") if get_tree().current_scene != null else null
	if crawl == null or not crawl.has_method("preview_network"):
		return
	if _sewer_terminal == null:
		_sewer_terminal = SEWER_TERMINAL.new()
		_sewer_terminal.name = "SewerTerminal"
		add_child(_sewer_terminal)
	var net: Dictionary = crawl.preview_network(_upkeep_coord)
	_sewer_terminal.open_for(net, int(net.get("level", 1)), _time_state == TIME_NIGHT)


func _build_generator_layout() -> void:
	# The set room (the diesel set, the drums, the junk, the steel door) and the switch
	# room behind it with the board: scripts/shed/generator_shed.gd.
	_shed = GENERATOR_SHED.new()
	_shed.build(self, _room_root)
	_sign(_shed.set_root, "TRAFOSTANICE\nDANGER - high voltage", Vector3(-0.6, 2.35, -1.98), 30, "danger")
	_sewer_hint = Label3D.new()
	_sewer_hint.position = Vector3(-0.6, 1.95, -1.97)
	_sewer_hint.font_size = 18
	_shed.set_root.add_child(_sewer_hint)
	_apply_sewer_hint()


# ── cleaning the block from the inside ────────────────────────────────────────

func _free_upkeep_prep() -> void:
	if _upkeep_prep != null:
		_upkeep_prep.dispose()
	_upkeep_prep = null


## Spots of the current hygiene layout, where the mess can be (MESS_RULES.BLOCK_SPOTS).
func _build_upkeep_spots(block: String) -> void:
	_free_upkeep_prep()
	_upkeep_prep = INTERIOR_PREP.new()
	var r := _room_root
	if block == "toilet":
		var bz := -TOILET_D * 0.5 + 0.32 + 0.06
		_upkeep_prep.add_spot("bowl_l", r, Vector3(-TOILET_STALL_X, 0.43, bz))
		_upkeep_prep.add_spot("bowl_r", r, Vector3(TOILET_STALL_X, 0.43, bz))
		_upkeep_prep.add_spot("stall_l", r, Vector3(-TOILET_STALL_X - 0.3, 0.01, -0.35))
		_upkeep_prep.add_spot("stall_r", r, Vector3(TOILET_STALL_X + 0.3, 0.01, -0.35))
		_upkeep_prep.add_spot("wall_l", r, Vector3(-TOILET_W * 0.5 + 0.02, 1.3, -0.1), PI * 0.5, true)
		_upkeep_prep.add_spot("wall_r", r, Vector3(TOILET_W * 0.5 - 0.02, 1.3, -0.1), -PI * 0.5, true)
	else:
		_upkeep_prep.add_spot("shower_l", r, Vector3(-1.15, 0.5, -1.54), 0.0, true)
		_upkeep_prep.add_spot("shower_r", r, Vector3(1.15, 0.5, -1.54), 0.0, true)
		_upkeep_prep.add_spot("drain_l", r, Vector3(-1.15, 0.01, -1.0))
		_upkeep_prep.add_spot("drain_r", r, Vector3(1.15, 0.01, -1.0))
		# All within a turn of the head from the doorway (no stepping across any more).
		_upkeep_prep.add_spot("floor_c", r, Vector3(0.0, 0.01, -0.5))
		_upkeep_prep.add_spot("floor_l", r, Vector3(-1.2, 0.01, -0.2))
		_upkeep_prep.add_spot("floor_r", r, Vector3(1.2, 0.01, -0.1))
	_upkeep_prep.setup_tasks(self, _interior_camera, _viewport)
	_upkeep_prep.task_completed.connect(_on_upkeep_task_done)
	var st = CoreRoot.get_state()
	_upkeep_prep.tasks.set_scrub_seed(int(st.day) if st != null else 1)


## InteriorManager, after open_service(): which block this is. Toilet and shower blocks
## get their cleaning list; everything else ignores it.
func set_upkeep_target(coord: Vector2i, building_type: String) -> void:
	_upkeep_coord = coord
	_upkeep_type = building_type
	_upkeep_key = "%d:%d" % [coord.x, coord.y]
	_start_life()
	_start_marks()
	var block := "toilet" if building_type == "toilet_block" else ("wash" if building_type == "shower_block" else "")
	if block.is_empty() or _room_root == null:
		_free_upkeep_prep()
		return
	if not EventBus.building_serviced.is_connected(_on_block_serviced):
		EventBus.building_serviced.connect(_on_block_serviced)
	var state = CoreRoot.get_state()
	var cell: Dictionary = state.grid.cells.get(coord, {}) if state != null else {}
	var condition := float(cell.get("maintenance", 1.0))
	var broken: bool = state != null and state.failures.has(_upkeep_key)
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	if bool(entry.get("spent", false)):
		entry = {}
	var spots: Array = MESS_RULES.BLOCK_SPOTS.get(block, [])
	for t in entry.get("tasks", []):
		if not spots.has(str((t as Dictionary).get("spot", ""))):
			entry = {}
			break
	# A breakdown since the last visit adds its job to the list.
	if entry.is_empty() or (broken and not bool(entry.get("broken", false))):
		var day := int(state.day) if state != null else 1
		entry = {
			"tasks": MESS_RULES.block_tasks(block, condition, broken, absi(("%s|%d" % [_upkeep_key, day]).hash())),
			"done": (entry.get("done", []) as Array).duplicate() if not entry.is_empty() else [],
			"broken": broken,
		}
		_upkeep_cache[_upkeep_key] = entry
	_build_upkeep_spots(block)
	_refresh_upkeep_room()
	# Everything done last time but the bill was not paid: try again now.
	if not (entry["tasks"] as Array).is_empty() and _all_upkeep_done(entry):
		_finish_upkeep()


func _upkeep_room_dict() -> Dictionary:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	var tasks: Array = entry.get("tasks", [])
	var clean := tasks.is_empty() or bool(entry.get("spent", false))
	var label := "Toilets" if _upkeep_type == "toilet_block" else "Showers"
	return {
		"label": "%s %s" % [label, _upkeep_key],
		"status": "ready" if clean else "dirty",
		"ready_text": "CLEAN",
		"dirty_text": "BROKEN DOWN" if bool(entry.get("broken", false)) else "NEEDS CLEANING",
		"done": entry.get("done", []),
		"tasks": tasks,
		"occupied": false,
		"note": "" if bool(entry.get("spent", false)) else str(entry.get("note", "")),
	}


func _refresh_upkeep_room() -> void:
	if _upkeep_prep != null:
		_upkeep_prep.set_room(_upkeep_room_dict())


func _all_upkeep_done(entry: Dictionary) -> bool:
	for t in entry.get("tasks", []):
		if not (entry.get("done", []) as Array).has(str(t["id"])):
			return false
	return true


func _on_upkeep_task_done(task_id: String) -> void:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	if entry.is_empty():
		return
	var done: Array = entry.get("done", [])
	if not done.has(task_id):
		done.append(task_id)
	entry["done"] = done
	_upkeep_cache[_upkeep_key] = entry
	if _all_upkeep_done(entry):
		_finish_upkeep()
	else:
		_refresh_upkeep_room()


## The last job done: the block is back to 100%. Cleaning costs the supplies, a
## breakdown the spare part (the same prices as the crew's, minus the crew).
func _finish_upkeep() -> void:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	var def = CoreRoot.registry.get_def(StringName(_upkeep_type)) if CoreRoot != null else null
	var state = CoreRoot.get_state()
	var cell: Dictionary = state.grid.cells.get(_upkeep_coord, {}) if state != null else {}
	var broken := bool(entry.get("broken", false))
	var cost := UPKEEP_RULES.repair_cost(def) if broken else UPKEEP_RULES.service_cost(def, float(cell.get("maintenance", 1.0)))
	# Co-op: serviced in the host's camp (it comes back as a fact, _on_block_serviced).
	if Coop.is_client():
		Coop.send_request("service", [_upkeep_coord, cost])
		if _upkeep_prep != null:
			_upkeep_prep.play_room_ready()
		return
	if not CoreRoot.actions.service_building(_upkeep_coord, cost):
		entry["note"] = "NO CASH FOR THE %s ($%d)" % ["SPARE PART" if broken else "SUPPLIES", cost]
		_upkeep_cache[_upkeep_key] = entry
		_refresh_upkeep_room()
		return
	if _upkeep_prep != null:
		_upkeep_prep.play_room_ready()
	_refresh_upkeep_room()


func _on_block_serviced(coord: Vector2i, _type: String, _was_broken: bool, _cost: int) -> void:
	var key := "%d:%d" % [coord.x, coord.y]
	var entry: Dictionary = _upkeep_cache.get(key, {})
	if entry.is_empty():
		return
	# Serviced (by you or the crew): the list is spent. Keep it shown as done while you
	# are still standing in there.
	if key == _upkeep_key and _is_open:
		var all_ids: Array = (entry.get("tasks", []) as Array).map(func(t): return str(t["id"]))
		entry["done"] = all_ids
		entry["spent"] = true
		_upkeep_cache[key] = entry
		_refresh_upkeep_room()
	else:
		_upkeep_cache.erase(key)


func _stop_life() -> void:
	if _life != null and is_instance_valid(_life):
		_life.queue_free()
	_life = null
	if _marks != null and is_instance_valid(_marks):
		_marks.clear()
		_marks.queue_free()
	_marks = null


## The marks over the places where work waits, for this pub, bistro or Jednota.
func _start_marks() -> void:
	var roots := {}
	match _current_profile:
		"pub":
			roots = {"": _pub_main_root}
		"rest":
			roots = {"dining": _restaurant_dining_root, "kitchen": _restaurant_kitchen_root}
		"vecerka":
			roots = {"shop": _vecerka_shop_root}
		_:
			return
	_marks = WORK_MARKS.new()
	_marks.name = "WorkMarks"
	add_child(_marks)
	_marks.profile = _current_profile
	_marks.key = _upkeep_key
	_marks.roots = roots
	var biz := get_tree().get_first_node_in_group("businesses")
	var key := _upkeep_key
	_marks.waiting_count = func() -> int: return int(biz.waiting_at(key)) if biz != null and is_instance_valid(biz) else 0


# -- co-op: the other warden in here at the jobs ------------------------------------

## The game open now, as a job: the tap, the pass, the till, the bottles, the washer,
## the stove, the books; "" none.
func coop_job() -> String:
	if _counter_game != null and _counter_game.visible:
		return {"pub": "tap", "rest": "hatch", "vecerka": "till"}.get(_current_profile, "")
	for id in _extra_games:
		if (_extra_games[id] as CanvasLayer).visible:
			return str(id)
	if _ledger != null and _ledger.visible:
		return "ledger"
	return ""


## Which room of the building you are in (the bistro's dining room, kitchen, cellar...).
func coop_part() -> String:
	match _current_profile:
		"rest":
			return "rest/" + _restaurant_room
		"vecerka", "generator", "toilet", "wash":
			return "%s/%s/%s" % [_current_profile, _active_subroom, toilet_entry]
	if _current_profile == "pub":
		return "pub/" + _pub_room
	return _current_profile + "/main"


## Where the other warden stands at a job and what they look like doing it ({} not a job
## of this room): behind the bar at the tap, at the bottles, at the washer; at the pass,
## at the stove; at the till; over the books.
const COOP_JOB_SPOTS := {
	"pub": {"tap": [Vector3(1.275, 0.05, -1.8), "tap"], "shots": [Vector3(1.75, 0.05, -1.85), "pour"], "wash": [Vector3(2.35, 0.05, -1.75), "wash"], "ledger": [Vector3(0.42, 0.05, -1.7), "write"]},
	"rest": {"hatch": [Vector3(0.0, 0.05, -0.4), "cook"], "ledger": [Vector3(1.42, 0.05, -1.7), "write"], "fryer": [Vector3(0.0, 0.05, -1.4), "cook"]},
	"vecerka": {"till": [Vector3(-1.95, 0.05, -0.35), "till"], "ledger": [Vector3(-1.9, 0.05, 0.55), "write"]},
}


func coop_job_spot(job: String) -> Dictionary:
	var spot: Array = (COOP_JOB_SPOTS.get(_current_profile, {}) as Dictionary).get(job, [])
	if spot.is_empty():
		return {}
	var root: Node3D = null
	match _current_profile:
		"pub":
			root = _pub_main_root
		"rest":
			root = _restaurant_kitchen_root if job in ["fryer", "hatch"] else _restaurant_dining_root
		"vecerka":
			root = _vecerka_shop_root
	if root == null or not root.is_visible_in_tree():
		return {}
	return {"pos": root.global_transform * (spot[0] as Vector3), "pose": str(spot[1])}


## The other warden's job here (their warden state's room "w"): not marked as waiting
## for you, it is being done.
var coop_partner_job := ""


## Seats the guests the simulation has in this pub / bistro / shop right now.
func _start_life() -> void:
	_stop_life()
	var root: Node3D = null
	var seats: Array = []
	var settings: Dictionary = {}
	match _current_profile:
		"pub":
			root = _pub_main_root
			if root == null:
				return
			var ti := 0
			for t: Vector3 in [Vector3(-1.6, 0.05, -1.0), Vector3(-1.6, 0.05, 0.9)]:
				var top := _top_near(root, "PubTable", t, 0.78)
				for side: float in [-1.0, 1.0]:
					settings[seats.size()] = t + Vector3(side * 0.2, top, 0)
					seats.append({"pos": t + Vector3(side * 0.45, 0, 0), "table": ti})
				ti += 1
			# The counter top of the model (bar_counter.glb: 1.05 m; the tap tower stands on it).
			var bar_top := 0.05 + 1.05
			for x: float in [0.6, 1.3, 2.0]:
				settings[seats.size()] = Vector3(x, bar_top, -1.08)
				# Up on a bar stool: the figure's seat (0.45 m up the sprite) on the stool
				# top, just in front of it so the seat does not cut through the legs.
				var stool_top := _top_near(root, "BarStool", Vector3(x, 0.05, -0.6), 0.78)
				seats.append({"pos": Vector3(x, stool_top - 0.45, -0.36), "table": -1})
		"rest":
			root = _restaurant_dining_root
			if root == null:
				return
			var tj := 0
			for t: Vector3 in [Vector3(-1.7, 0.05, -1.0), Vector3(-1.7, 0.05, 0.9), Vector3(0.35, 0.05, 0.6)]:
				var top2 := _top_near(root, "GinghamTable", t, 0.78)
				for side: float in [-1.0, 1.0]:
					settings[seats.size()] = t + Vector3(side * 0.2, top2, 0)
					seats.append({"pos": t + Vector3(side * 0.45, 0, 0), "table": tj})
				tj += 1
		"vecerka":
			root = _vecerka_shop_root
			if root == null:
				return
			# At the back racks, the side rack and the counter, far enough from the door
			# (where you stand) to be people in the room, not a face in the lens.
			for spot in [[Vector3(-0.85, 0.05, -1.0), Vector3(0, 0, -1)], [Vector3(0.85, 0.05, -1.0), Vector3(0, 0, -1)], [Vector3(1.0, 0.05, -0.32), Vector3(1, 0, 0)], [Vector3(-0.95, 0.05, -0.38), Vector3(-1, 0, 0)]]:
				seats.append({"pos": spot[0], "face": spot[1], "stand": true})
		_:
			return
	# Nobody sits in your lap: seats too near where you stand stay empty.
	var door := Vector3.INF
	if _interior_camera != null:
		var cam := root.to_local(_interior_camera.global_position)
		door = Vector3(cam.x, 0.05, cam.z)
		var kept: Array = []
		var kept_settings: Dictionary = {}
		for i in seats.size():
			var at: Vector3 = seats[i]["pos"]
			if Vector2(at.x - cam.x, at.z - cam.z).length() < 1.7:
				continue
			if settings.has(i):
				kept_settings[kept.size()] = settings[i]
			kept.append(seats[i])
		seats = kept
		settings = kept_settings
	_life = SERVICE_LIFE.new()
	_life.name = "ServiceLife"
	root.add_child(_life)
	_life.setup(_current_profile, _upkeep_key, seats, settings, door)


## The top of the prop called `n` nearest `at` under `root` (room y), or `fallback`.
func _top_near(root: Node3D, n: String, at: Vector3, fallback: float) -> float:
	var best: Node3D = null
	var best_d := INF
	for c in root.find_children(n + "*", "Node3D", false, false):
		var d := (c as Node3D).position.distance_to(at)
		if d < best_d:
			best_d = d
			best = c
	if best == null or best_d > 0.6:
		return fallback
	var top := -INF
	for m in best.find_children("*", "MeshInstance3D", true, false):
		var bb := (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		top = maxf(top, bb.end.y)
	if top == -INF:
		return fallback
	# The room root is never rotated or scaled: its y is a plain offset.
	return top - root.global_position.y


func _profile_for_service(service_type: String) -> String:
	if service_type == "restaurant":
		return "rest"
	if service_type == "pub":
		return "pub"
	if service_type == "shower_block":
		return "wash"
	if service_type == "toilet_block":
		return "toilet"
	if service_type == "sewer":
		return "sewer"
	if service_type == "vecerka":
		return "vecerka"
	if service_type == "power_generator":
		return "generator"
	return "rest"


func _try_request_service_repair() -> void:
	# The sewer's pipe mouth takes you in broken or not (nothing to mend: just down).
	if not (_current_profile in ["sewer", "generator"]) or (not _sewer_broken and _current_profile != "sewer"):
		return
	request_repair.emit()


## Whether the building behind this hatch is broken. Only then is there a leak to find
## down there, and only then does R take you into the pipes.
func set_sewer_broken(broken: bool) -> void:
	_sewer_broken = broken
	_apply_sewer_hint()


func _apply_sewer_hint() -> void:
	if _sewer_hint == null or not is_instance_valid(_sewer_hint):
		return
	if _sewer_broken and _current_profile == "generator":
		_sewer_hint.text = "FAULT REPORTED"
		_sewer_hint.modulate = Color(1.0, 0.62, 0.36, 0.95)
	elif _sewer_broken:
		_sewer_hint.text = "LEAK REPORTED"
		_sewer_hint.modulate = Color(1.0, 0.62, 0.36, 0.95)
	else:
		_sewer_hint.text = "NO FAULTS"
		_sewer_hint.modulate = Color(0.70, 0.76, 0.70, 0.70)


func _apply_time_profile(animated: bool = false) -> void:
	if _room_env != null:
		match _time_state:
			TIME_DAY:
				_room_env.background_color = Color(0.62, 0.68, 0.74)
				_room_env.ambient_light_color = Color(0.80, 0.84, 0.82)
				_room_env.ambient_light_energy = 0.94
			TIME_EVENING:
				_room_env.background_color = Color(0.24, 0.22, 0.26)
				_room_env.ambient_light_color = Color(0.54, 0.52, 0.56)
				_room_env.ambient_light_energy = 0.50
			_:
				_room_env.background_color = Color(0.08, 0.10, 0.14)
				_room_env.ambient_light_color = Color(0.24, 0.28, 0.36)
				_room_env.ambient_light_energy = 0.12 # Increased base night ambient

	if _main_light != null:
		match _time_state:
			TIME_DAY:
				_main_light.light_color = Color(1.0, 0.96, 0.88)
				_main_light.light_energy = 1.30
			TIME_EVENING:
				_main_light.light_color = Color(0.92, 0.80, 0.68)
				_main_light.light_energy = 0.88
			_:
				_main_light.light_color = Color(0.66, 0.72, 0.88)
				_main_light.light_energy = 0.24 # Increased base night energy

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _wash_glass != null:
		_wash_glass.emission_enabled = true
		_wash_glass.emission = Color(0.62, 0.7, 0.68) * (0.08 + 0.7 * daylight)
	if _room_env != null:
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(sun_tint, 0.16 * daylight)
		_room_env.ambient_light_energy = lerpf(_room_env.ambient_light_energy * 0.82, _room_env.ambient_light_energy * 1.16, daylight)
	if _main_light != null:
		_main_light.light_color = _main_light.light_color.lerp(sun_tint, 0.10 * daylight)
		_main_light.light_energy = lerpf(_main_light.light_energy * 0.90, _main_light.light_energy * 1.10, daylight)
	_apply_manual_service_light_profile(animated)


func _apply_manual_service_light_profile(animated: bool) -> void:
	if _main_light == null:
		return
	var target_ambient = _room_env.ambient_light_energy if _room_env != null else 0.0
	var target_light = _main_light.light_energy
	if not _manual_lights_on:
		target_ambient *= 0.45
		target_light = 0.0
	else:
		# If ON, we want a decent minimum brightness even at night
		target_ambient = max(target_ambient, 0.50)
		target_light = max(target_light, 1.10)
	if not _grid_power_available:
		target_ambient *= 0.30
		target_light = 0.0
	if animated:
		if _manual_light_tween != null and is_instance_valid(_manual_light_tween):
			_manual_light_tween.kill()
		_manual_light_tween = create_tween()
		_manual_light_tween.set_parallel(true)
		_manual_light_tween.set_ease(Tween.EASE_IN_OUT)
		_manual_light_tween.set_trans(Tween.TRANS_SINE)
		if _room_env != null:
			_manual_light_tween.tween_property(_room_env, "ambient_light_energy", target_ambient, 0.56)
		_manual_light_tween.tween_property(_main_light, "light_energy", target_light, 0.56)
		return
	if _room_env != null:
		_room_env.ambient_light_energy = target_ambient
	_main_light.light_energy = target_light


func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, category: String, parent: Node3D = null) -> MeshInstance3D:
	if _room_root == null:
		return null
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = node_name
	var box = BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(max(1.0, box_size.x * 1.4), 1.0, max(1.0, box_size.z * 1.4))
	if _texture_style != null:
		var tex = _texture_style.pick_texture(category, color)
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat

	var parent_node = parent if parent != null else _room_root
	parent_node.add_child(mesh_inst)
	return mesh_inst


func _nights_visited() -> int:
	var n: Node = self
	while n != null and not n.has_method("get_electricity_ui_snapshot"):
		n = n.get_parent()
	var ledger = n.get("_week_ledger") if n != null else null
	return int(ledger.nights_visited()) if ledger != null and ledger.has_method("nights_visited") else 0


## The shed's switch room when the board's close-up closes again.
func on_breaker_board_closed() -> void:
	if _shed != null:
		_shed.on_board_closed()
	if _is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


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
	return _time_state != TIME_DAY and (not _manual_lights_on or not _grid_power_available)
