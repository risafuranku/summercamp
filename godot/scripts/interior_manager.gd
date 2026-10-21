extends Node

signal service_repair_requested(coord: Vector2i, building_type: String)
## A line for the HUD feed (e.g. a room you cannot go into).
signal notice(text: String, kind: int)

const KNOCK_SFX := "res://assets/sfx/rooms/door_knock.mp3"

const BUILDING_INTERIOR_SCRIPT = preload("res://scripts/building_interior.gd")
const CABIN_INTERIOR_SCRIPT = preload("res://scripts/cabin_interior.gd")
const TENT_INTERIOR_SCRIPT = preload("res://scripts/tent_interior.gd")
const CARAVAN_INTERIOR_SCRIPT = preload("res://scripts/caravan_interior.gd")
const SERVICE_INTERIOR_SCRIPT = preload("res://scripts/service_interior_generator.gd")
const BUILDING_UPGRADE_MENU_SCRIPT = preload("res://scripts/building_upgrade_menu.gd")
const GUEST_DIALOG_SCRIPT = preload("res://scripts/guest_dialog.gd")
const MAINT_RULES = preload("res://core/systems/maintenance_rules.gd")
## Through the door and back: the frozen frame breaking up in steps (twelve a second).
const DOOR_TRANSITION_SCRIPT = preload("res://scripts/ui/door_transition.gd")
## Out of the camp: the barrier, the road, the bus stop (scripts/town/town_trip.gd).
const TOWN_TRIP_SCRIPT = preload("res://scripts/town/town_trip.gd")
## Birds, crows, bats and moths over wherever you are outdoors (scripts/ambient/sky_life.gd).
const SKY_LIFE_SCRIPT = preload("res://scripts/ambient/sky_life.gd")
## The businesses' books, sales, wages and deliveries (scripts/business/business_runtime.gd).
const BUSINESS_RUNTIME = preload("res://scripts/business/business_runtime.gd")
var business: Node
## The staffroom's hands at work (scripts/staff/staff_runtime.gd).
const STAFF_RUNTIME = preload("res://scripts/staff/staff_runtime.gd")
var staff: Node
## Autumn leaves blown about in the wind (scripts/ambient/wind_life.gd).
const WIND_LIFE_SCRIPT = preload("res://scripts/ambient/wind_life.gd")
var _wind_life: Node3D
## Puddles in the rain, mist along the ground at night (scripts/ambient/ground_life.gd).
const GROUND_LIFE_SCRIPT = preload("res://scripts/ambient/ground_life.gd")
var _ground_life: Node3D
const COOP_FIGURE = preload("res://scripts/coop/remote_player.gd")
const COOP_LOOKS = preload("res://scripts/coop/warden_looks.gd")
## The beds of the camp's own tents, cabins and caravans for a warden to sleep in.
const LODGE_BED = preload("res://scripts/lodge_bed.gd")
const DOOR_ANIM = preload("res://scripts/attractions/door_anim.gd")
var lodge_bed: Node

const TIME_NIGHT: int = 2

const INTERIOR_MODULE_MAIN := "main"
const INTERIOR_MODULE_TENT := "tent"
const INTERIOR_MODULE_CARAVAN := "caravan"
const INTERIOR_MODULE_CABIN := "cabin"
const INTERIOR_MODULE_SERVICE := "service"
## "trip_*" and "town_*" things outside the camp (town_trip.handles()).
const INTERIOR_MODULE_TRIP := "trip"
## The corn stand: behind its counter (scripts/corn/stand_view.gd: its two stations in 3D,
## the camp beyond the counter).
const INTERIOR_MODULE_STAND := "stand"
const STAND_VIEW = preload("res://scripts/corn/stand_view.gd")
var _corn_stand: CanvasLayer
const INTERIOR_ASSIGNMENTS := [
	{
		"module_id": INTERIOR_MODULE_MAIN,
		"building_types": ["main_building"],
		"hint": "Enter reception",
	},
	{
		"module_id": INTERIOR_MODULE_TENT,
		"building_types": ["tent", "tent_1", "tent_2", "tent_3"],
		"hint": "Enter tent",
	},
	{
		"module_id": INTERIOR_MODULE_CABIN,
		"building_types": ["cabin", "cabin_1", "cabin_2", "cabin_3"],
		"hint": "Enter cabin",
	},
	{
		"module_id": INTERIOR_MODULE_CARAVAN,
		"building_types": ["caravan_1", "caravan_2", "caravan_3"],
		"hint": "Enter caravan",
	},
	{
		"module_id": INTERIOR_MODULE_SERVICE,
		"building_types": ["restaurant", "pub", "toilet_block", "shower_block", "sewer", "power_generator", "vecerka", "staffroom"],
		"hint": "Enter",
		"hints": {
			"restaurant": "Enter bistro",
			"pub": "Enter pub",
			"vecerka": "Go into the Jednota",
			"toilet_block": "Enter toilets",
			"shower_block": "Enter showers",
			"sewer": "Open sewer hatch",
			"power_generator": "Enter generator shed",
			"staffroom": "Go into the staffroom",
		},
	},
	{
		"module_id": INTERIOR_MODULE_STAND,
		"building_types": ["corn_stand"],
		"hint": "Step behind the corn stand",
	},
]

var _world_3d: Node3D
var _player: Node
var _grid_manager: Node
var _building_manager: Node
var _legacy_ui_adapter: Node
var _audio_manager: Node
var _economy_manager: Node

var _building_interior
var _cabin_interior
var _tent_interior
var _caravan_interior
var _service_interior
var _building_upgrade_menu
var _guest_dialog

var _interior_module_lookup: Dictionary = {}
var _interior_hint_lookup: Dictionary = {}
var _interior_instances: Dictionary = {}

var _active_tent_node: Node3D
var _active_caravan_node: Node3D
var _active_cabin_node: Node3D
var _active_service_node: Node3D
var _pending_upgrade_context: Dictionary = {}
var _current_time_state: int = 0
var _grid_power_available: bool = true
var _crt_desktop_state_cache: Dictionary = {}


var _door_fx: CanvasLayer
var _town_trip: Node
var _sky_life: Node3D


func town_trip() -> Node:
	return _town_trip


## The camp is about to give way to a room, or a room has just closed: the frame on
## screen still shows what was there; it breaks up into what is there now.
func _door_transition(going_in: bool) -> void:
	# Walked in through a door you opened by hand (_walk_up_first): no frozen frame, no
	# dither; the camp's last frame is the dark doorway at your eyes and the room takes up
	# from its door (_step_in). The brief of 21. 10.: "doors without a seam".
	if going_in and Time.get_ticks_msec() - _walked_in_ms < 1500:
		return
	if _door_fx != null:
		_door_fx.play(going_in)


func setup(
	world_3d: Node3D,
	player: Node,
	grid_manager: Node,
	building_manager: Node,
	legacy_ui_adapter: Node,
	audio_manager: Node,
	economy_manager: Node
) -> void:
	_world_3d = world_3d
	_player = player
	_grid_manager = grid_manager
	_building_manager = building_manager
	_legacy_ui_adapter = legacy_ui_adapter
	_audio_manager = audio_manager
	_economy_manager = economy_manager
	_build_interior_assignment_lookup()
	_bind_guest_visual_event_handlers()
	if _door_fx == null:
		_door_fx = DOOR_TRANSITION_SCRIPT.new()
		add_child(_door_fx)
	if _town_trip == null:
		_town_trip = TOWN_TRIP_SCRIPT.new()
		_town_trip.name = "TownTrip"
		add_child(_town_trip)
		_register_interior_instance(INTERIOR_MODULE_TRIP, _town_trip)
	_town_trip.setup(self)
	if _sky_life == null and _world_3d != null:
		_sky_life = SKY_LIFE_SCRIPT.new()
		_world_3d.add_child(_sky_life)
		_sky_life.player_getter = func(): return _player
		_sky_life.indoors = func(): return is_any_open()
	if business == null:
		business = BUSINESS_RUNTIME.new()
		add_child(business)
	if staff == null:
		staff = STAFF_RUNTIME.new()
		staff.name = "StaffRuntime"
		add_child(staff)
	if lodge_bed == null:
		lodge_bed = LODGE_BED.new()
		lodge_bed.name = "LodgeBed"
		lodge_bed.im = self
		add_child(lodge_bed)
	if _wind_life == null and _world_3d != null:
		_wind_life = WIND_LIFE_SCRIPT.new()
		_world_3d.add_child(_wind_life)
		_wind_life.player_getter = func(): return _player
		_wind_life.indoors = func(): return is_any_open()
		_wind_life.weather_getter = func():
			var m := get_tree().current_scene
			return int(m.get("_weather_state")) if m != null and m.get("_weather_state") != null else 0
		_wind_life.season_getter = func():
			var m := get_tree().current_scene
			if m == null or m.get("_day_index") == null:
				return Vector2(10, 12)
			return Vector2(float(m.get("_day_index")), float(m.get("_time_of_day_hours")))
		_wind_life.wind_getter = func():
			var m := get_tree().current_scene
			var wv: Node = m.get("_weather_visuals") if m != null else null
			if wv == null:
				return Vector3.ZERO
			var d: Vector2 = wv.wind_dir
			return Vector3(d.x, float(wv.wind_gust), d.y)
	if _ground_life == null and _world_3d != null:
		_ground_life = GROUND_LIFE_SCRIPT.new()
		_world_3d.add_child(_ground_life)
		_ground_life.player_getter = func(): return _player
		_ground_life.indoors = func(): return is_any_open()
		_ground_life.weather_getter = _wind_life.weather_getter
		_ground_life.hour_getter = func():
			var m := get_tree().current_scene
			return float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0
	# setup() is called once before player spawn and again after spawn.
	# Rebind existing interiors so runtime refs (player/audio/grid) stay valid.
	if _building_interior != null and is_instance_valid(_building_interior) and _building_interior.has_method("setup"):
		_building_interior.setup(_grid_manager, _building_manager, _legacy_ui_adapter, _player)
		if _building_interior.has_method("import_crt_desktop_state"):
			# setup() can reconfigure CRT shell bindings; immediately re-apply cached desktop state.
			_building_interior.import_crt_desktop_state(_crt_desktop_state_cache.duplicate(true))


func _bind_guest_visual_event_handlers() -> void:
	if EventBus == null:
		return
	if EventBus.has_signal("guest_created"):
		var created_cb := Callable(self, "_on_guest_roster_changed")
		if not EventBus.guest_created.is_connected(created_cb):
			EventBus.guest_created.connect(created_cb)
	if EventBus.has_signal("guest_state_changed"):
		var state_cb := Callable(self, "_on_guest_state_transition")
		if not EventBus.guest_state_changed.is_connected(state_cb):
			EventBus.guest_state_changed.connect(state_cb)
	if EventBus.has_signal("accommodation_state_changed"):
		var acc_cb := Callable(self, "_on_accommodation_changed")
		if not EventBus.accommodation_state_changed.is_connected(acc_cb):
			EventBus.accommodation_state_changed.connect(acc_cb)


func _on_guest_roster_changed(_guest: Dictionary) -> void:
	_refresh_active_guest_visuals()


func _on_guest_state_transition(_guest_id: int, _old_state: String, _new_state: String) -> void:
	_refresh_active_guest_visuals()


func _on_accommodation_changed(_accommodation_key: String, _status: String, _guest_count: int) -> void:
	_refresh_active_guest_visuals()


func _refresh_active_guest_visuals() -> void:
	_sync_tent_guest_visuals()
	_sync_cabin_guest_visuals()


func _sync_tent_guest_visuals() -> void:
	if _tent_interior == null or not is_instance_valid(_tent_interior):
		return
	if not _tent_interior.has_method("set_guest_occupants"):
		return
	if not _tent_interior.has_method("is_open") or not _tent_interior.is_open():
		return
	_tent_interior.set_guest_occupants(_guest_visuals_for_structure(_active_tent_node))


func _sync_cabin_guest_visuals() -> void:
	if _cabin_interior == null or not is_instance_valid(_cabin_interior):
		return
	if not _cabin_interior.has_method("set_guest_occupants"):
		return
	if not _cabin_interior.has_method("is_open") or not _cabin_interior.is_open():
		return
	_cabin_interior.set_guest_occupants(_guest_visuals_for_structure(_active_cabin_node))


func _guest_visuals_for_structure(structure: Node) -> Array:
	if structure == null or not is_instance_valid(structure):
		return []
	if GuestManager == null or not GuestManager.has_method("get_accommodation_guest_visuals_by_coord"):
		return []
	var coord_any = structure.get_meta("grid_origin", null)
	if not (coord_any is Vector2i):
		return []
	var visuals_any = GuestManager.get_accommodation_guest_visuals_by_coord(coord_any as Vector2i)
	return visuals_any if visuals_any is Array else []


func setup_all() -> void:
	_setup_building_interior()
	_setup_cabin_interior()
	_setup_tent_interior()
	_setup_caravan_interior()
	_setup_service_interior()
	_setup_building_upgrade_menu()
	_setup_guest_dialog()


func sync_time(time_state: int) -> void:
	_current_time_state = time_state
	for interior in _get_registered_interior_nodes():
		_apply_time_to_interior(interior)


func sync_weather(weather_state: int) -> void:
	for interior in _get_registered_interior_nodes():
		if interior != null and interior.has_method("set_weather_state"):
			interior.set_weather_state(weather_state)


func set_grid_power_available(power_available: bool) -> void:
	_grid_power_available = power_available
	for interior in _get_registered_interior_nodes():
		_apply_grid_power_to_interior(interior)


## The camp's light as last pushed (main, every sync): given to a room as it opens, so it
## never shows the light of when it was last open for its first frames.
var _last_light: Array = []


func apply_dynamic_lighting(
	daylight_factor: float,
	sun_color: Color,
	ambient_color: Color,
	ambient_energy: float
) -> void:
	_last_light = [daylight_factor, sun_color, ambient_color, ambient_energy]
	for interior in _get_registered_interior_nodes():
		_apply_dynamic_light_to_interior(interior, daylight_factor, sun_color, ambient_color, ambient_energy)


func is_structure_open() -> bool:
	for interior in _get_registered_interior_nodes():
		if interior.has_method("is_open") and interior.is_open():
			return true
	return false


func is_any_open() -> bool:
	if is_structure_open():
		return true
	if _building_upgrade_menu != null and _building_upgrade_menu.is_open():
		return true
	if _guest_dialog != null and _guest_dialog.is_open():
		return true
	return false


## The pause menu's "Go outside": shuts whatever room or panel is open the way its own
## exit would (each hands the player back their controls). `silent` (back to the main
## menu): no walk out of the door, no door sound; a room left open stayed under the
## menu and went on taking clicks.
func close_everything(silent := false) -> void:
	if _guest_dialog != null and _guest_dialog.is_open():
		_guest_dialog.close_dialog()
	if _building_upgrade_menu != null and _building_upgrade_menu.is_open():
		_building_upgrade_menu.close_menu()
	_no_step_out = silent
	_silent_close = silent
	for interior in _get_registered_interior_nodes():
		if not (interior.has_method("is_open") and interior.is_open()):
			continue
		for m in ["close_interior", "close_cabin", "close_tent", "close_caravan", "close_service"]:
			if interior.has_method(m):
				interior.call(m)
				break
	# Behind the corn stand (not one of the rooms): its stations and their hand go too (the
	# gloved hand stayed over the title screen: playtest 21. 10.).
	if _corn_stand != null and is_instance_valid(_corn_stand) and _corn_stand.has_method("close_view") and _corn_stand.is_open():
		_corn_stand.close_view()
	_no_step_out = false
	_silent_close = false
	if silent and stepping_out():
		_stepping_out.kill()
		var body := _player as CharacterBody3D
		if body != null:
			body.collision_mask = _walk_mask
	if not stepping_out():
		_set_player_controls_enabled(true)


var _silent_close := false


func _play_door_close() -> void:
	if not _silent_close and _audio_manager != null and _audio_manager.has_method("play_door_close"):
		_audio_manager.play_door_close()


## The reception's own front door (an old wooden door with a glass pane and a shop bell
## over it), not the rooms' generic one.
const OFFICE_DOOR_OPEN := "res://assets/sfx/rooms/office_door_open.mp3"
const OFFICE_DOOR_CLOSE := "res://assets/sfx/rooms/office_door_close.mp3"
var _office_door: AudioStreamPlayer


func _play_office_door(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	if _office_door == null or not is_instance_valid(_office_door):
		_office_door = AudioStreamPlayer.new()
		_office_door.name = "OfficeDoorSfx"
		_office_door.volume_db = -6.0
		add_child(_office_door)
	_office_door.stream = load(path)
	_office_door.pitch_scale = randf_range(0.96, 1.03)
	_office_door.play()
	return true


func _play_office_door_close() -> void:
	if _silent_close or not _play_office_door(OFFICE_DOOR_CLOSE):
		_play_door_close()


func is_crt_desktop_active() -> bool:
	if _building_interior == null:
		return false
	if not _building_interior.has_method("is_open") or not _building_interior.is_open():
		return false
	if _building_interior.has_method("is_crt_view_active"):
		return bool(_building_interior.is_crt_view_active())
	return true


func export_crt_desktop_state() -> Dictionary:
	if _building_interior != null and is_instance_valid(_building_interior) and _building_interior.has_method("export_crt_desktop_state"):
		var data_any = _building_interior.export_crt_desktop_state()
		if data_any is Dictionary:
			_crt_desktop_state_cache = (data_any as Dictionary).duplicate(true)
	return _crt_desktop_state_cache.duplicate(true)


func import_crt_desktop_state(state: Dictionary) -> void:
	_crt_desktop_state_cache = state.duplicate(true)
	if _building_interior == null or not is_instance_valid(_building_interior):
		return
	if not _building_interior.has_method("import_crt_desktop_state"):
		return
	_building_interior.import_crt_desktop_state(_crt_desktop_state_cache.duplicate(true))


func is_service_sewer_profile_active() -> bool:
	if _service_interior == null:
		return false
	if not _service_interior.has_method("is_open") or not _service_interior.is_open():
		return false
	if _service_interior.has_method("is_sewer_profile_active"):
		return bool(_service_interior.is_sewer_profile_active())
	return false


func is_service_restaurant_basement_active() -> bool:
	if _service_interior == null:
		return false
	if not _service_interior.has_method("is_open") or not _service_interior.is_open():
		return false
	if _service_interior.has_method("is_restaurant_basement_active"):
		return bool(_service_interior.is_restaurant_basement_active())
	return false


## Main may take an interaction first (the distribution board while the breaker is out).
var structure_interact_override: Callable


func handle_structure_interact(structure: Node3D) -> void:
	if structure == null:
		return
	if structure_interact_override.is_valid() and bool(structure_interact_override.call(structure)):
		return
	var building_type = str(structure.get_meta("building_type", ""))
	match _module_for_building_type(building_type):
		INTERIOR_MODULE_MAIN:
			_on_crt_interact()
		INTERIOR_MODULE_TENT:
			_on_tent_interact(structure)
		INTERIOR_MODULE_CABIN:
			_on_cabin_interact(structure)
		INTERIOR_MODULE_CARAVAN:
			_on_caravan_interact(structure)
		INTERIOR_MODULE_SERVICE:
			_on_service_interact(structure)
		INTERIOR_MODULE_TRIP:
			_town_trip.interact(structure)
		INTERIOR_MODULE_STAND:
			_on_corn_stand_interact(structure)
		_:
			return


## Behind the corn stand's counter: its stations (the pot, the butter, the salt, the husking)
## with the camp beyond the counter, the books on the frame.
func _on_corn_stand_interact(structure: Node3D) -> void:
	if _corn_stand == null:
		_corn_stand = STAND_VIEW.new()
		add_child(_corn_stand)
		_corn_stand.closed.connect(func():
			_set_player_controls_enabled(true)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	var origin = structure.get_meta("grid_origin", null)
	var key := ""
	if origin is Vector2i:
		key = "%d:%d" % [origin.x, origin.y]
	_set_player_controls_enabled(false)
	_corn_stand.open_for(key, structure)


func open_startup_crt_view() -> void:
	if _building_interior == null:
		return
	_apply_time_to_interior(_building_interior)
	_building_interior.open_interior()
	_set_player_controls_enabled(false)
	_building_interior.call_deferred("enter_crt_view", true)


func close_main_interior_if_open() -> void:
	if _building_interior == null:
		return
	if _building_interior.has_method("is_open") and _building_interior.is_open():
		_building_interior.close_interior()


func resolve_interactable_structure(node: Node) -> Node3D:
	var structure = _resolve_structure_with_building_type(node)
	if structure == null:
		return null
	var building_type = str(structure.get_meta("building_type", ""))
	if not _building_type_has_interior(building_type):
		return null
	return structure


func get_hint_for_building_type(building_type: String) -> String:
	return _hint_for_building_type(building_type)


## The hint for this very thing (things out of the camp word theirs by their state).
func get_hint_for_structure(structure: Node3D) -> String:
	var building_type := str(structure.get_meta("building_type", ""))
	if _town_trip != null and _town_trip.handles(building_type):
		return str(_town_trip.hint_for(structure))
	var hint := _hint_for_building_type(building_type)
	# The toilets and showers get dirty with use and are cleaned inside.
	if MAINT_RULES.soils(building_type) and not hint.is_empty():
		var state = CoreRoot.get_state()
		var origin: Vector2i = structure.get_meta("grid_origin", Vector2i(-999, -999))
		var cell: Dictionary = state.grid.cells.get(origin, {}) if state != null and state.grid != null else {}
		var condition := float(cell.get("maintenance", 1.0))
		if condition < MAINT_RULES.FILTHY:
			hint += " - filthy, clean it"
		elif condition < 0.9:
			hint += " - needs cleaning"
	return hint


func _set_player_controls_enabled(enabled: bool) -> void:
	if _player != null and _player.has_method("set_controls_enabled"):
		_player.set_controls_enabled(enabled)


func _apply_time_to_interior(interior: Object) -> void:
	if interior == null:
		return
	if not _last_light.is_empty() and interior.has_method("set_daylight_profile"):
		interior.set_daylight_profile(_last_light[0], _last_light[1], _last_light[2], _last_light[3])
	if interior.has_method("set_time_state"):
		interior.set_time_state(_current_time_state)
	elif interior.has_method("set_is_day"):
		interior.set_is_day(_current_time_state != TIME_NIGHT)
	_apply_grid_power_to_interior(interior)


func _apply_grid_power_to_interior(interior: Object) -> void:
	if interior == null:
		return
	if interior.has_method("set_grid_power_available"):
		interior.set_grid_power_available(_grid_power_available)


func _apply_dynamic_light_to_interior(
	interior: Object,
	daylight_factor: float,
	sun_color: Color,
	ambient_color: Color,
	ambient_energy: float
) -> void:
	if interior == null:
		return
	if interior.has_method("is_open") and not interior.is_open():
		return
	if interior.has_method("set_daylight_profile"):
		interior.set_daylight_profile(daylight_factor, sun_color, ambient_color, ambient_energy)


func _on_crt_interact() -> void:
	if _building_interior == null:
		return
	if _building_interior.is_open() or stepping_out():
		return
	# Near the front door: the warden walks the last steps up to the door, it opens, and
	# the room takes the walk on from its doorway (the user 20. 10.: coming in as smooth as
	# going out). The camp's office is a shell with nothing in it: the walk stops short of
	# its door (the user 21. 10.: "for a moment you see the empty inside" when the eye went
	# through the shut door into it), and the frame the door transition freezes is the door.
	# From further off the room opens as it did.
	var body := _player as CharacterBody3D
	var way: Dictionary = _building_interior.walk_in_handoff() if body != null and _building_interior.has_method("walk_in_handoff") else {}
	if not way.is_empty() and Vector2(body.global_position.x - way["to"].x, body.global_position.z - way["to"].z).length() < WALK_IN_FROM_M:
		var stop: Vector3 = (way["to"] as Vector3) - (way["dir"] as Vector3) * WALK_IN_SHORT_M
		var dist := body.global_position.distance_to(stop)
		_set_player_controls_enabled(false)
		var mask := body.collision_mask
		body.collision_mask = 0
		body.velocity = Vector3.ZERO
		var dir: Vector3 = way["dir"]
		body.rotation.y = atan2(-dir.x, -dir.z)
		body.set("_pitch", 0.0)
		body.set("_pitch_target", 0.0)
		var tw := create_tween()
		_stepping_out = tw
		tw.tween_property(body, "global_position", stop, clampf(dist / 2.4, 0.25, 0.9)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void:
			if is_instance_valid(body):
				body.collision_mask = mask
			_play_office_door(OFFICE_DOOR_OPEN)
			_enter_office(true))
		return
	_enter_office(false)


## How near the front door (m) the warden must be for the walk up to it.
const WALK_IN_FROM_M := 4.5
## How far short of the room's doorway eye (reception_extras.FRONT_STEP_IN) the camp's
## walk stops: outside the shut door, its frame still in view.
const WALK_IN_SHORT_M := 1.1


func _enter_office(walked_in: bool) -> void:
	_apply_time_to_interior(_building_interior)
	_door_transition(true)
	if walked_in and _building_interior.has_method("open_interior_walk_in"):
		_building_interior.open_interior_walk_in()
	else:
		_building_interior.open_interior()
		if not _play_office_door(OFFICE_DOOR_OPEN) and _audio_manager != null and _audio_manager.has_method("play_door_open"):
			_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


func _setup_building_interior() -> void:
	if _building_interior != null and is_instance_valid(_building_interior):
		if _building_interior.has_method("setup"):
			_building_interior.setup(_grid_manager, _building_manager, _legacy_ui_adapter, _player)
		if _building_interior.has_method("import_crt_desktop_state"):
			_building_interior.import_crt_desktop_state(_crt_desktop_state_cache.duplicate(true))
		_apply_grid_power_to_interior(_building_interior)
		return
	_building_interior = BUILDING_INTERIOR_SCRIPT.new()
	_building_interior.name = "BuildingInterior"
	# Here, not in the world: the world is drawn small and scaled up (render style),
	# and so was everything 2D in a room (its prompts, lists, close-ups) with it
	# (playtest 2026-10-17: "render scale makes the HUD huge"). Rooms have their own 3D.
	add_child(_building_interior)
	_register_interior_instance(INTERIOR_MODULE_MAIN, _building_interior)
	if _building_interior.has_method("setup"):
		_building_interior.setup(_grid_manager, _building_manager, _legacy_ui_adapter, _player)
	if _building_interior.has_method("import_crt_desktop_state"):
		_building_interior.import_crt_desktop_state(_crt_desktop_state_cache.duplicate(true))
	_apply_grid_power_to_interior(_building_interior)
	_building_interior.visibility_changed.connect(_on_interior_visibility_changed)


func _on_interior_visibility_changed() -> void:
	if _building_interior == null:
		return
	if not _building_interior.is_open():
		if bool(_building_interior.get("walked_out")):
			_building_interior.set("walked_out", false)
			_play_office_door_close()
			_walk_on_out_of_office()
			return
		_play_office_door_close()
		_step_out_of(_world_3d.find_child("MainBuilding", true, false) as Node3D if _world_3d != null else null)


## Out of a room any other way (S, the bottom band, the pause menu's Go outside): no
## dissolve (playtest 18. 10.: "totally smooth"); the camp takes over at the building's
## door, the warden a step out of it facing away, walking on off the doorstep. The door
## nearest to where you went in (the toilets have two); a sewer hatch has none to walk from.
const STEP_OUT_FROM := 0.3
const STEP_OUT_TO := 1.3
const NO_STEP_OUT := ["sewer", "sewage_tank"]


var _no_step_out := false
var _stepping_out: Tween
var _walk_mask := 1


func stepping_out() -> bool:
	return _stepping_out != null and _stepping_out.is_valid() and _stepping_out.is_running()


func _step_out_of(structure: Node3D) -> void:
	var body := _player as CharacterBody3D
	if _no_step_out or body == null or structure == null or not is_instance_valid(structure) \
			or str(structure.get_meta("building_type", "")) in NO_STEP_OUT:
		_set_player_controls_enabled(true)
		return
	var doors: Array = DOOR_ANIM.find_doors(structure)
	if doors.is_empty():
		doors = structure.find_children("TentFlap", "MeshInstance3D", true, false)
	var pick := 0
	var best := INF
	for i in doors.size():
		var d := body.global_position.distance_to((doors[i] as Node3D).global_position)
		if d < best:
			best = d
			pick = i
	var way: Dictionary = DOOR_ANIM.entry_points(structure, pick)
	if way.is_empty():
		_set_player_controls_enabled(true)
		return
	var out: Vector3 = way["outside"] - way["inside"]
	out.y = 0.0
	out = out.normalized()
	var sill: Vector3 = (way["outside"] + way["inside"]) * 0.5
	sill.y = body.global_position.y
	if way["door"] != null:
		DOOR_ANIM.open_now(way["door"], WALK_OUT_SEC + 0.6)
	_walk_body(body, sill + out * STEP_OUT_FROM, sill + out * STEP_OUT_TO, out)


## The warden's body from `from` to `to` facing `dir`, no collisions on the way (through
## the door body, over the porch); the keys are his when he is down.
func _walk_body(body: CharacterBody3D, from: Vector3, to: Vector3, dir: Vector3) -> void:
	var mask := body.collision_mask
	if stepping_out():
		_stepping_out.kill()
		mask = _walk_mask
	_walk_mask = mask
	_set_player_controls_enabled(false)
	body.global_position = from
	body.rotation.y = atan2(-dir.x, -dir.z)
	body.set("_pitch", 0.0)
	body.set("_pitch_target", 0.0)
	body.velocity = Vector3.ZERO
	body.collision_mask = 0
	var tw := create_tween()
	_stepping_out = tw
	tw.tween_property(body, "global_position", to, WALK_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(body):
			body.collision_mask = mask
			body.velocity = Vector3.ZERO
		_set_player_controls_enabled(true)
	)


## Out of the office's front door on foot (reception_extras.go_out_front): the warden's
## body is put under the room's eye as the room closes, facing out, and walks on
## through the doorway and off the porch under it, so the camp picks the walk up where
## the room left it (playtest 18. 10.: "absolutely smooth"). Through the building's
## door body and over the porch with no collisions; the keys are his when he is down.
const WALK_OUT_SEC := 0.55


func _walk_on_out_of_office() -> void:
	var body := _player as CharacterBody3D
	var way: Dictionary = _building_interior.walk_out_handoff() if body != null else {}
	if way.is_empty():
		_set_player_controls_enabled(true)
		return
	# The camp building's own leaf is shut (the room's doorway view never showed it): the
	# eye starts right at it, and for some frames the walk out was through a door.
	var office := _world_3d.find_child("MainBuilding", true, false) as Node3D if _world_3d != null else null
	var leaf := DOOR_ANIM.find_door(office) if office != null else null
	if leaf != null:
		DOOR_ANIM.open_now(leaf, WALK_OUT_SEC + 0.6)
	_walk_body(body, way["from"], way["to"], way["dir"])


## The last steps up to a building's door outside, the door opening as you come, before
## its room opens (the user 20. 10.: every way in as smooth as the way out). `again` is the
## interact once there; true while walking (the caller stops), false to open now (too far
## or too near to walk, a hatch, already walked).
const WALK_UP_FROM_M := 4.0
const STEP12 = preload("res://scripts/ui/step12.gd")
var _walked_up_to := 0
## When the last walk in through a door ended (msec): the room opens with no dissolve.
var _walked_in_ms := -100000


func _walk_up_first(structure: Node3D, again: Callable) -> bool:
	if structure == null or not is_instance_valid(structure):
		return false
	if _walked_up_to == structure.get_instance_id():
		_walked_up_to = 0
		return false
	var body := _player as CharacterBody3D
	if body == null or stepping_out() or str(structure.get_meta("building_type", "")) in NO_STEP_OUT:
		return false
	var doors: Array = DOOR_ANIM.find_doors(structure)
	if doors.is_empty():
		doors = structure.find_children("TentFlap", "MeshInstance3D", true, false)
	var pick := 0
	var best := INF
	for i in doors.size():
		var dd := body.global_position.distance_to((doors[i] as Node3D).global_position)
		if dd < best:
			best = dd
			pick = i
	var way: Dictionary = DOOR_ANIM.entry_points(structure, pick)
	if way.is_empty():
		return false
	var into: Vector3 = way["inside"] - way["outside"]
	into.y = 0.0
	into = into.normalized()
	# Up to the door and into the doorway, the eye at the door's own plane: the hand takes
	# the handle (reach_hand.gd), the leaf swings with its weight (door_anim.open), and
	# the dark of the room is in front of you as it opens.
	var to: Vector3 = (way["outside"] as Vector3).lerp(way["inside"], 0.42)
	to.y = body.global_position.y
	var d := Vector2(body.global_position.x - to.x, body.global_position.z - to.z).length()
	if d > WALK_UP_FROM_M or d < 0.2:
		return false
	if way["door"] != null:
		DOOR_ANIM.open(way["door"], 3.0)
	_set_player_controls_enabled(false)
	var mask := body.collision_mask
	body.collision_mask = 0
	body.velocity = Vector3.ZERO
	body.set("_pitch_target", 0.0)
	var yaw := body.rotation.y + wrapf(atan2(-into.x, -into.z) - body.rotation.y, -PI, PI)
	var dur := clampf(d / 2.0, 0.35, 1.0)
	var tw := create_tween()
	_stepping_out = tw
	# A beat for the hand on the handle and the leaf to swing in.
	tw.tween_interval(0.4)
	tw.tween_property(body, "global_position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(body, "rotation:y", yaw, dur * 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var id := structure.get_instance_id()
	tw.tween_callback(func() -> void:
		if is_instance_valid(body):
			body.collision_mask = mask
		_walked_up_to = id
		_walked_in_ms = Time.get_ticks_msec()
		again.call())
	return true


## Inside, the room's eye takes the last step in from the doorway to where it stands.
func _step_in(interior: Object) -> void:
	var cam := interior.get("_interior_camera") as Camera3D if interior != null else null
	if cam == null or not (interior is Node):
		return
	var at := cam.position
	cam.position = at + cam.transform.basis.z.normalized() * 0.45 + Vector3(0, 0.04, 0)
	STEP12.move(interior as Node, cam, {"position": at}, 0.42)


func _on_tent_interact(tent_node: Node) -> void:
	if _tent_interior == null:
		return
	if _tent_interior.is_open():
		return
	if _refuse_if_occupied(tent_node as Node3D, "tent"):
		return
	if _walk_up_first(tent_node as Node3D, _on_tent_interact.bind(tent_node)):
		return
	var level = 1
	var tent_type = str(tent_node.get_meta("building_type", "tent_1"))
	if tent_type == "tent_2":
		level = 2
	elif tent_type == "tent_3":
		level = 3
	elif tent_node.name.contains("Lv2"):
		level = 2
	elif tent_node.name.contains("Lv3"):
		level = 3
	_active_tent_node = tent_node as Node3D
	_apply_time_to_interior(_tent_interior)
	_door_transition(true)
	_tent_interior.open_tent(level)
	_step_in(_tent_interior)
	_sync_tent_guest_visuals()
	_push_room_state(_tent_interior, _active_tent_node)
	_set_player_controls_enabled(false)


func _setup_tent_interior() -> void:
	if _tent_interior != null and is_instance_valid(_tent_interior):
		_apply_grid_power_to_interior(_tent_interior)
		return
	_tent_interior = TENT_INTERIOR_SCRIPT.new()
	_tent_interior.name = "TentInterior"
	# Here, not in the world: the world is drawn small and scaled up (render style),
	# and so was everything 2D in a room (its prompts, lists, close-ups) with it
	# (playtest 2026-10-17: "render scale makes the HUD huge"). Rooms have their own 3D.
	add_child(_tent_interior)
	_register_interior_instance(INTERIOR_MODULE_TENT, _tent_interior)
	if _tent_interior.has_signal("request_close"):
		_tent_interior.request_close.connect(_on_tent_closed)
	if _tent_interior.has_signal("request_upgrade"):
		_tent_interior.request_upgrade.connect(_on_tent_upgrade_requested)
	if _tent_interior.has_signal("room_task_completed"):
		_tent_interior.room_task_completed.connect(func(task_id: String): _on_room_task_completed(_tent_interior, _active_tent_node, task_id))
	_apply_grid_power_to_interior(_tent_interior)


func _setup_caravan_interior() -> void:
	if _caravan_interior != null and is_instance_valid(_caravan_interior):
		_apply_grid_power_to_interior(_caravan_interior)
		return
	_caravan_interior = CARAVAN_INTERIOR_SCRIPT.new()
	_caravan_interior.name = "CaravanInterior"
	add_child(_caravan_interior)
	_register_interior_instance(INTERIOR_MODULE_CARAVAN, _caravan_interior)
	_caravan_interior.request_close.connect(_on_caravan_closed)
	_caravan_interior.request_upgrade.connect(_on_caravan_upgrade_requested)
	_caravan_interior.room_task_completed.connect(func(task_id: String): _on_room_task_completed(_caravan_interior, _active_caravan_node, task_id))
	_apply_grid_power_to_interior(_caravan_interior)


func _on_caravan_interact(caravan_node: Node) -> void:
	if _caravan_interior == null or _caravan_interior.is_open():
		return
	if _refuse_if_occupied(caravan_node as Node3D, "caravan"):
		return
	if _walk_up_first(caravan_node as Node3D, _on_caravan_interact.bind(caravan_node)):
		return
	var t := str(caravan_node.get_meta("building_type", "caravan_1"))
	var level := clampi(int(t.right(1)), 1, 3)
	_active_caravan_node = caravan_node as Node3D
	_apply_time_to_interior(_caravan_interior)
	_door_transition(true)
	_caravan_interior.open_caravan(level)
	_step_in(_caravan_interior)
	call_deferred("_restore_curtains")
	_push_room_state(_caravan_interior, _active_caravan_node)
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
		_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


func _on_caravan_closed() -> void:
	var was: Node3D = _active_caravan_node
	_active_caravan_node = null
	_play_door_close()
	_step_out_of(was)


func _on_caravan_upgrade_requested() -> void:
	var caravan = _active_caravan_node
	if caravan == null or not is_instance_valid(caravan) or _economy_manager == null:
		return
	var origin = caravan.get_meta("grid_origin", Vector2i(-1, -1))
	var current_type = str(caravan.get_meta("building_type", "caravan_1"))
	var next_type := {"caravan_1": "caravan_2", "caravan_2": "caravan_3"}.get(current_type, "") as String
	if next_type == "":
		_pending_upgrade_context.clear()
		_open_upgrade_menu("Caravan: Max Level", "This caravan is already Lv3.", "MAX", false)
		return
	var cost = max(30, _economy_manager.get_cost(next_type) - _economy_manager.get_cost(current_type))
	_pending_upgrade_context = {"mode": "replace", "origin": origin, "old_type": current_type, "new_type": next_type, "cost": cost}
	var desc = "Upgrade %s -> %s (one more bed)." % [_economy_manager.get_label(current_type), _economy_manager.get_label(next_type)]
	_open_upgrade_menu("Caravan: Upgrade", desc, "$%d" % cost, _economy_manager.get_money() >= cost)


func _on_tent_closed() -> void:
	if _tent_interior != null and _tent_interior.has_method("set_guest_occupants"):
		_tent_interior.set_guest_occupants([])
	var was: Node3D = _active_tent_node
	_active_tent_node = null
	_step_out_of(was)


func _setup_cabin_interior() -> void:
	if _cabin_interior != null and is_instance_valid(_cabin_interior):
		_apply_grid_power_to_interior(_cabin_interior)
		return
	_cabin_interior = CABIN_INTERIOR_SCRIPT.new()
	_cabin_interior.name = "CabinInterior"
	# Here, not in the world: the world is drawn small and scaled up (render style),
	# and so was everything 2D in a room (its prompts, lists, close-ups) with it
	# (playtest 2026-10-17: "render scale makes the HUD huge"). Rooms have their own 3D.
	add_child(_cabin_interior)
	_register_interior_instance(INTERIOR_MODULE_CABIN, _cabin_interior)
	if _cabin_interior.has_signal("request_close"):
		_cabin_interior.request_close.connect(_on_cabin_closed)
	if _cabin_interior.has_signal("request_upgrade"):
		_cabin_interior.request_upgrade.connect(_on_cabin_upgrade_requested)
	if _cabin_interior.has_signal("room_task_completed"):
		_cabin_interior.room_task_completed.connect(func(task_id: String): _on_room_task_completed(_cabin_interior, _active_cabin_node, task_id))
	_apply_grid_power_to_interior(_cabin_interior)


func _on_cabin_interact(cabin_node: Node) -> void:
	if _cabin_interior == null:
		return
	if _cabin_interior.is_open():
		return
	if _refuse_if_occupied(cabin_node as Node3D, "cabin"):
		return
	if _walk_up_first(cabin_node as Node3D, _on_cabin_interact.bind(cabin_node)):
		return
	var level = 1
	var cabin_type = str(cabin_node.get_meta("building_type", "cabin_1"))
	if cabin_type == "cabin_2":
		level = 2
	elif cabin_type == "cabin_3":
		level = 3
	elif cabin_type == "cabin":
		level = 1
	elif cabin_node.name.contains("Lv2"):
		level = 2
	elif cabin_node.name.contains("Lv3"):
		level = 3
	_active_cabin_node = cabin_node as Node3D
	_apply_time_to_interior(_cabin_interior)
	if _cabin_interior.has_method("set_world_anchor"):
		_cabin_interior.set_world_anchor(_active_cabin_node)
	_door_transition(true)
	_cabin_interior.open_cabin(level)
	_step_in(_cabin_interior)
	call_deferred("_restore_curtains")
	_sync_cabin_guest_visuals()
	_push_room_state(_cabin_interior, _active_cabin_node)
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
		_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


func _on_cabin_closed() -> void:
	if _cabin_interior != null and _cabin_interior.has_method("set_guest_occupants"):
		_cabin_interior.set_guest_occupants([])
	var was: Node3D = _active_cabin_node
	_active_cabin_node = null
	_play_door_close()
	_step_out_of(was)


## Room preparation: the interior shows the mess for what is not done yet.
func _room_key_for(structure: Node3D) -> String:
	if structure == null or not is_instance_valid(structure):
		return ""
	var origin_any = structure.get_meta("grid_origin", null)
	if not (origin_any is Vector2i):
		return ""
	return "%d:%d" % [(origin_any as Vector2i).x, (origin_any as Vector2i).y]


## A room with guests checked in is theirs: you knock, somebody answers, you stay out.
func _refuse_if_occupied(structure: Node3D, kind: String) -> bool:
	var key := _room_key_for(structure)
	if key.is_empty() or GuestManager == null:
		return false
	if not bool(GuestManager.get_room_state(key).get("occupied", false)):
		return false
	var knock := AudioStreamPlayer3D.new()
	knock.stream = load(KNOCK_SFX)
	knock.unit_size = 4.0
	add_child(knock)
	knock.global_position = structure.global_position + Vector3(0, 1.2, 0)
	knock.finished.connect(knock.queue_free)
	knock.play()
	var replies := ["\"Occupied!\"", "\"We're asleep!\"", "\"Come back later.\"", "\"Who is it?\""]
	notice.emit("The %s is taken. %s" % [kind, replies[randi() % replies.size()]], 1)
	return true


func _push_room_state(interior: Object, structure: Node3D) -> void:
	var key := _room_key_for(structure)
	if interior == null or key.is_empty() or not interior.has_method("set_room"):
		return
	interior.set_room(GuestManager.get_room_state(key))


func _on_room_task_completed(interior: Object, structure: Node3D, task_id: String) -> void:
	var key := _room_key_for(structure)
	if key.is_empty():
		return
	var was_ready := str(GuestManager.get_room_state(key).get("status", "")) == "ready"
	GuestManager.complete_room_task(key, task_id)
	# Co-op: done here at once, and for real in the host's camp (which sends it back).
	Coop.send_room_task(key, task_id)
	var room: Dictionary = GuestManager.get_room_state(key)
	interior.set_room(room)
	if not was_ready and str(room.get("status", "")) == "ready" and interior.has_method("play_room_ready"):
		interior.play_room_ready()


func _setup_service_interior() -> void:
	if _service_interior != null and is_instance_valid(_service_interior):
		_apply_grid_power_to_interior(_service_interior)
		return
	_service_interior = SERVICE_INTERIOR_SCRIPT.new()
	_service_interior.name = "ServiceInterior"
	# Here, not in the world: the world is drawn small and scaled up (render style),
	# and so was everything 2D in a room (its prompts, lists, close-ups) with it
	# (playtest 2026-10-17: "render scale makes the HUD huge"). Rooms have their own 3D.
	add_child(_service_interior)
	_register_interior_instance(INTERIOR_MODULE_SERVICE, _service_interior)
	if _service_interior.has_signal("request_close"):
		_service_interior.request_close.connect(_on_service_closed)
	if _service_interior.has_signal("request_repair"):
		_service_interior.request_repair.connect(_on_service_repair_requested)
	_apply_grid_power_to_interior(_service_interior)


func _on_service_interact(service_node: Node) -> void:
	if _service_interior == null:
		return
	if _service_interior.is_open():
		return
	var structure = _resolve_service_structure(service_node)
	if structure == null:
		return
	var building_type = str(structure.get_meta("building_type", ""))
	if not _is_supported_service_building_type(building_type):
		return
	if _walk_up_first(structure as Node3D, _on_service_interact.bind(service_node)):
		return
	_active_service_node = structure
	_apply_time_to_interior(_service_interior)
	if building_type == "toilet_block" and "toilet_entry" in _service_interior:
		_service_interior.toilet_entry = _toilet_door_of(structure as Node3D)
	_door_transition(true)
	_service_interior.open_service(building_type)
	if _service_interior.has_method("set_upkeep_target"):
		_service_interior.set_upkeep_target(structure.get_meta("grid_origin", Vector2i(-999, -999)), building_type)
	call_deferred("_restore_curtains")
	if _service_interior.has_method("set_sewer_broken"):
		var origin: Vector2i = structure.get_meta("grid_origin", Vector2i(-999, -999))
		var state = CoreRoot.get_state() if CoreRoot != null else null
		_service_interior.set_sewer_broken(state != null and state.failures.has("%d:%d" % [origin.x, origin.y]))
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
		_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


## The toilet block has a door per stall (building_models._toilets): the one on the side
## of the building you are standing at, as seen from its front.
func _toilet_door_of(structure: Node3D) -> String:
	var p := _player as Node3D
	if structure == null or p == null:
		return "left"
	return "left" if structure.to_local(p.global_position).x < 0.0 else "right"


func _on_service_closed() -> void:
	var was: Node3D = _active_service_node as Node3D
	_active_service_node = null
	_play_door_close()
	_step_out_of(was)


func _on_service_repair_requested() -> void:
	if _active_service_node == null or not is_instance_valid(_active_service_node):
		return
	if not _active_service_node.has_meta("grid_origin"):
		return
	var coord = _active_service_node.get_meta("grid_origin", Vector2i.ZERO)
	var building_type = str(_active_service_node.get_meta("building_type", ""))
	if building_type == "water_pump" or building_type == "sewage_tank":
		building_type = "sewer"
	var is_sewer_service = (building_type == "sewer")
	if not is_sewer_service:
		if _economy_manager == null or not _economy_manager.has_method("has_failed_utility_at"):
			return
		if not _economy_manager.has_failed_utility_at(coord):
			return
	if _service_interior != null and _service_interior.is_open():
		# Straight into the repair: no walk out of the door under it.
		_no_step_out = true
		_service_interior.close_service()
		_no_step_out = false
	service_repair_requested.emit(coord, building_type)


func _build_interior_assignment_lookup() -> void:
	_interior_module_lookup.clear()
	_interior_hint_lookup.clear()
	for assignment in INTERIOR_ASSIGNMENTS:
		var module_id = str(assignment.get("module_id", ""))
		if module_id == "":
			continue
		var default_hint = str(assignment.get("hint", ""))
		var custom_hints: Dictionary = assignment.get("hints", {})
		var building_types: Array = assignment.get("building_types", [])
		for raw_type in building_types:
			var canonical_type = _canonical_building_type(str(raw_type))
			if canonical_type == "":
				continue
			_interior_module_lookup[canonical_type] = module_id
			var custom_hint = default_hint
			if custom_hints.has(canonical_type):
				custom_hint = str(custom_hints[canonical_type])
			_interior_hint_lookup[canonical_type] = custom_hint


func _register_interior_instance(module_id: String, interior: Object) -> void:
	if module_id == "" or interior == null:
		return
	_interior_instances[module_id] = interior


func _get_registered_interior_nodes() -> Array:
	var interiors: Array = []
	for interior in _interior_instances.values():
		if interior != null:
			interiors.append(interior)
	return interiors


func _canonical_building_type(building_type: String) -> String:
	var normalized = building_type.strip_edges()
	if normalized == "tent":
		return "tent_1"
	if normalized == "cabin":
		return "cabin_1"
	if normalized == "water_pump" or normalized == "sewage_tank":
		return "sewer"
	return normalized


func _module_for_building_type(building_type: String) -> String:
	var canonical_type = _canonical_building_type(building_type)
	if canonical_type == "":
		return ""
	if _town_trip != null and _town_trip.handles(canonical_type):
		return INTERIOR_MODULE_TRIP
	if not _interior_module_lookup.has(canonical_type):
		return ""
	return str(_interior_module_lookup[canonical_type])


func _hint_for_building_type(building_type: String) -> String:
	var canonical_type = _canonical_building_type(building_type)
	if canonical_type == "":
		return ""
	if not _interior_hint_lookup.has(canonical_type):
		return ""
	return str(_interior_hint_lookup[canonical_type])


func _building_type_has_interior(building_type: String) -> bool:
	return _module_for_building_type(building_type) != ""


func _resolve_structure_with_building_type(node: Node) -> Node3D:
	var current = node
	while current != null:
		if current is Node3D and current.has_meta("building_type"):
			return current as Node3D
		current = current.get_parent()
	return null


func _get_structures_root() -> Node3D:
	if _building_manager == null:
		return null
	return _building_manager.get_node_or_null("Structures") as Node3D


func _setup_building_upgrade_menu() -> void:
	if _building_upgrade_menu != null and is_instance_valid(_building_upgrade_menu):
		return
	_building_upgrade_menu = BUILDING_UPGRADE_MENU_SCRIPT.new()
	_building_upgrade_menu.name = "BuildingUpgradeMenu"
	add_child(_building_upgrade_menu)
	if _building_upgrade_menu.has_signal("upgrade_confirmed"):
		_building_upgrade_menu.upgrade_confirmed.connect(_on_upgrade_confirmed)
	if _building_upgrade_menu.has_signal("menu_closed"):
		_building_upgrade_menu.menu_closed.connect(_on_upgrade_menu_closed)


func _setup_guest_dialog() -> void:
	if _guest_dialog != null and is_instance_valid(_guest_dialog):
		return
	_guest_dialog = GUEST_DIALOG_SCRIPT.new()
	_guest_dialog.name = "GuestDialog"
	add_child(_guest_dialog)
	if _guest_dialog.has_signal("dialog_closed"):
		_guest_dialog.dialog_closed.connect(_on_guest_dialog_closed)


func _has_guest_inside(structure: Node) -> bool:
	if structure == null:
		return false
	var visuals = _guest_visuals_for_structure(structure)
	if not visuals.is_empty():
		return true
	if structure.has_meta("guest_count"):
		return int(structure.get_meta("guest_count", 0)) > 0
	if structure.has_meta("has_guest"):
		return bool(structure.get_meta("has_guest", false))
	return false


func _open_guest_dialog(title_text: String, body_text: String) -> void:
	if _guest_dialog == null:
		return
	_guest_dialog.open_dialog(title_text, body_text)
	_set_player_controls_enabled(false)


func _on_guest_dialog_closed() -> void:
	_set_player_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_tent_upgrade_requested() -> void:
	var tent = _active_tent_node
	if tent == null or not is_instance_valid(tent):
		return
	if _economy_manager == null:
		return
	var origin = tent.get_meta("grid_origin", Vector2i(-1, -1))
	var current_type = str(tent.get_meta("building_type", "tent_1"))
	var next_type = ""
	match current_type:
		"tent_1":
			next_type = "tent_2"
		"tent_2":
			next_type = "tent_3"
		_:
			next_type = ""

	if current_type == "tent_3":
		_pending_upgrade_context.clear()
		_open_upgrade_menu("Tent: Max Level", "This tent is already Lv3. No further upgrade available.", "MAX", false)
		return

	if next_type == "":
		_pending_upgrade_context.clear()
		_open_upgrade_menu("Tent: Upgrade", "Invalid tent level.", "N/A", false)
		return

	var cost = max(20, _economy_manager.get_cost(next_type) - _economy_manager.get_cost(current_type))
	_pending_upgrade_context = {
		"mode": "replace",
		"origin": origin,
		"old_type": current_type,
		"new_type": next_type,
		"cost": cost,
	}
	var can_pay = _economy_manager.get_money() >= cost
	var desc = "Upgrade %s -> %s (better comfort + capacity)." % [_economy_manager.get_label(current_type), _economy_manager.get_label(next_type)]
	_open_upgrade_menu("Tent: Upgrade", desc, "$%d" % cost, can_pay)


func _on_cabin_upgrade_requested() -> void:
	var cabin = _active_cabin_node
	if cabin == null or not is_instance_valid(cabin):
		return
	if _economy_manager == null:
		return
	var origin = cabin.get_meta("grid_origin", Vector2i(-1, -1))
	var current_type = str(cabin.get_meta("building_type", "cabin_1"))
	if current_type == "cabin":
		current_type = "cabin_1"
	var next_type = ""
	match current_type:
		"cabin_1":
			next_type = "cabin_2"
		"cabin_2":
			next_type = "cabin_3"
		_:
			next_type = ""

	if current_type == "cabin_3":
		_pending_upgrade_context.clear()
		_open_upgrade_menu("Cabin: Max Level", "This cabin is already Lv3. No further upgrade available.", "MAX", false)
		return

	if next_type == "":
		_pending_upgrade_context.clear()
		_open_upgrade_menu("Cabin: Upgrade", "Invalid cabin level.", "N/A", false)
		return

	var cost = max(30, _economy_manager.get_cost(next_type) - _economy_manager.get_cost(current_type))
	_pending_upgrade_context = {
		"mode": "replace",
		"origin": origin,
		"old_type": current_type,
		"new_type": next_type,
		"cost": cost,
	}
	var can_pay = _economy_manager.get_money() >= cost
	var desc = "Upgrade %s -> %s (bigger comfort + capacity)." % [_economy_manager.get_label(current_type), _economy_manager.get_label(next_type)]
	_open_upgrade_menu("Cabin: Upgrade", desc, "$%d" % cost, can_pay)


func _open_upgrade_menu(title_text: String, desc_text: String, cost_text: String, enabled: bool) -> void:
	# Not until the camp is rated well enough on Goggle.
	var need := _upgrade_locked(str(_pending_upgrade_context.get("new_type", "")))
	if need > 0.0:
		_pending_upgrade_context.clear()
		cost_text = "%d GUESTS" % int(need)
		enabled = false
	if _building_upgrade_menu == null:
		return
	var room: Node = null
	for r in [_tent_interior, _cabin_interior, _caravan_interior]:
		if r != null and is_instance_valid(r) and r.has_method("is_open") and r.is_open():
			room = r
			break
	_building_upgrade_menu.open_menu(title_text, desc_text, cost_text, enabled, room)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_upgrade_confirmed() -> void:
	if _pending_upgrade_context.is_empty():
		if _building_upgrade_menu != null:
			_building_upgrade_menu.close_menu()
		return
	if _economy_manager == null:
		if _building_upgrade_menu != null:
			_building_upgrade_menu.close_menu()
		return

	var mode = str(_pending_upgrade_context.get("mode", ""))
	var cost = int(_pending_upgrade_context.get("cost", 0))
	# Co-op: bought in the host's camp (the new building comes back as a fact).
	if Coop.is_client():
		Coop.send_request("upgrade", [_pending_upgrade_context.duplicate()])
		if _building_upgrade_menu != null:
			_building_upgrade_menu.close_menu()
		return
	if not _economy_manager.has_method("spend_money") or not _economy_manager.spend_money(cost):
		if _building_upgrade_menu != null:
			_building_upgrade_menu.close_menu()
		return

	if mode == "replace":
		var origin = _pending_upgrade_context.get("origin", Vector2i.ZERO)
		var old_type = str(_pending_upgrade_context.get("old_type", ""))
		var new_type = str(_pending_upgrade_context.get("new_type", ""))
		_handle_replace_upgrade(origin, old_type, new_type, cost)
	elif mode == "comfort":
		var origin_c = _pending_upgrade_context.get("origin", Vector2i.ZERO)
		var comfort_delta = float(_pending_upgrade_context.get("comfort_delta", 0.15))
		_economy_manager.upgrade_comfort(origin_c, comfort_delta)

	if _building_upgrade_menu != null:
		_building_upgrade_menu.close_menu()


## The next level of a lodging (tent, cabin, caravan), or "" at the top.
const NEXT_LEVEL := {"tent_1": "tent_2", "tent_2": "tent_3", "cabin": "cabin_2", "cabin_1": "cabin_2", "cabin_2": "cabin_3", "caravan_1": "caravan_2", "caravan_2": "caravan_3"}
## The least an upgrade costs, by kind (the brochures' own floors).
const UPGRADE_FLOOR := {"tent": 20, "cabin": 30, "caravan": 30}


## Builder's map: what upgrading the lodging at `origin` would be ({} if it cannot be).
## The same rule and price as the brochure in the room.
func map_upgrade_offer(origin: Vector2i, current_type: String) -> Dictionary:
	if _economy_manager == null:
		return {}
	var cur := "cabin_1" if current_type == "cabin" else current_type
	var next := str(NEXT_LEVEL.get(cur, ""))
	if next == "":
		return {"max": true, "old_type": cur}
	var floor_cost := int(UPGRADE_FLOOR.get(cur.get_slice("_", 0), 20))
	var cost: int = max(floor_cost, _economy_manager.get_cost(next) - _economy_manager.get_cost(cur))
	return {"mode": "replace", "origin": origin, "old_type": cur, "new_type": next, "cost": cost,
		"label": str(_economy_manager.get_label(next)), "locked": _upgrade_locked(next)}


## An upgrade to `new_type` waits for the camp's Goggle rating (scripts/reviews/goggle.gd):
## the guests in the camp it needs, or 0.0 when it is open.
func _upgrade_locked(new_type: String) -> float:
	var main := get_tree().current_scene if get_tree() != null else null
	var g = main.get("_goggle") if main != null else null
	if g == null:
		return 0.0
	var lvl := new_type.get_slice("_", 1)
	if lvl != "2" and lvl != "3":
		return 0.0
	var item := "upgrade:" + lvl
	if g.unlocked(item):
		return 0.0
	return float(g.TIERS[g.tier_of(item)]["guests"])


## Builder's map: buy the upgrade there and then. False if it could not be paid or done.
func map_upgrade(origin: Vector2i, current_type: String) -> bool:
	var offer := map_upgrade_offer(origin, current_type)
	if offer.is_empty() or bool(offer.get("max", false)) or float(offer.get("locked", 0.0)) > 0.0:
		return false
	if Coop.is_client():
		Coop.send_request("upgrade", [offer.duplicate()])
		return true
	if not _economy_manager.has_method("spend_money") or not _economy_manager.spend_money(int(offer["cost"])):
		return false
	# The replace points the open room at the new building; from the map no room is
	# open on it, so whatever was open stays as it was.
	var keep := [_active_tent_node, _active_cabin_node, _active_caravan_node]
	_handle_replace_upgrade(origin, str(offer["old_type"]), str(offer["new_type"]), int(offer["cost"]))
	_active_tent_node = keep[0]
	_active_cabin_node = keep[1]
	_active_caravan_node = keep[2]
	return true


## The host: the other warden bought an upgrade (the menu's context, as it was there).
func coop_upgrade(ctx: Dictionary) -> void:
	if _economy_manager == null or not _economy_manager.has_method("spend_money"):
		return
	var cost := int(ctx.get("cost", 0))
	if not _economy_manager.spend_money(cost):
		return
	match str(ctx.get("mode", "")):
		"replace":
			_handle_replace_upgrade(ctx.get("origin", Vector2i.ZERO), str(ctx.get("old_type", "")), str(ctx.get("new_type", "")), cost)
		"comfort":
			_economy_manager.upgrade_comfort(ctx.get("origin", Vector2i.ZERO), float(ctx.get("comfort_delta", 0.15)))


func _handle_replace_upgrade(origin: Vector2i, old_type: String, new_type: String, cost: int) -> void:
	if _grid_manager == null or _building_manager == null or _economy_manager == null:
		_refund_upgrade_cost(cost)
		return
	if not _building_manager.has_method("place_building_at"):
		_refund_upgrade_cost(cost)
		return

	var tile = _grid_manager.get_tile(origin)
	if tile == null or not tile.occupied or tile.occupant == null:
		_refund_upgrade_cost(cost)
		return

	var root = _resolve_failed_utility_structure(tile.occupant)
	var preserved_rotation := 0
	if root != null:
		preserved_rotation = wrapi(int(root.get_meta("build_rotation", 0)), 0, 4)

	if not _building_manager.remove_structure(tile.occupant):
		_refund_upgrade_cost(cost)
		return
	var placed_ok = _building_manager.place_building_at(origin, new_type)
	if not placed_ok:
		_building_manager.place_building_at(origin, old_type)
		_refund_upgrade_cost(cost)
		return

	# The core grid is what guests, rooms and saves read: it must know the new type.
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.retype_building(origin, new_type)
	# Co-op: the other warden's camp gets the same upgrade.
	Coop.send_fact("upgrade", [origin, old_type, new_type])
	var removed_registered = _economy_manager.unregister_building_at(origin, old_type)
	if not removed_registered and old_type == "cabin_1":
		_economy_manager.unregister_building_at(origin, "cabin")
	_economy_manager.register_building(new_type, origin)

	var updated_tile = _grid_manager.get_tile(origin)
	if updated_tile != null and updated_tile.occupied and updated_tile.occupant != null:
		var updated_node = _resolve_failed_utility_structure(updated_tile.occupant) as Node3D
		if updated_node != null:
			updated_node.set_meta("build_rotation", preserved_rotation)
			updated_node.rotation.y = deg_to_rad(float(preserved_rotation) * 90.0)
			if new_type.begins_with("tent_"):
				_active_tent_node = updated_node
			elif new_type.begins_with("cabin_"):
				_active_cabin_node = updated_node
			elif new_type.begins_with("caravan_"):
				_active_caravan_node = updated_node

	_refresh_upgraded_interior_state(new_type)


func _refresh_upgraded_interior_state(new_type: String) -> void:
	if new_type.begins_with("tent_") and _tent_interior != null and _tent_interior.is_open():
		var upgraded_level = clampi(int(new_type.get_slice("_", 1)), 1, 3)
		_apply_time_to_interior(_tent_interior)
		_tent_interior.open_tent(upgraded_level)
	if new_type.begins_with("caravan_") and _caravan_interior != null and _caravan_interior.is_open():
		_apply_time_to_interior(_caravan_interior)
		_caravan_interior.open_caravan(clampi(int(new_type.get_slice("_", 1)), 1, 3))
		_push_room_state(_caravan_interior, _active_caravan_node)
	if new_type.begins_with("cabin_") and _cabin_interior != null and _cabin_interior.is_open():
		var upgraded_cabin_level = clampi(int(new_type.get_slice("_", 1)), 1, 3)
		_apply_time_to_interior(_cabin_interior)
		_cabin_interior.open_cabin(upgraded_cabin_level)


func _refund_upgrade_cost(cost: int) -> void:
	if _economy_manager != null and _economy_manager.has_method("add_money"):
		_economy_manager.add_money(cost)


func _on_upgrade_menu_closed() -> void:
	_pending_upgrade_context.clear()
	var keep_visible_mouse = is_structure_open()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if keep_visible_mouse else Input.MOUSE_MODE_CAPTURED)


func _resolve_failed_utility_structure(node: Node) -> Node3D:
	var current = node
	while current != null:
		if current is Node3D and current.has_meta("grid_origin"):
			return current as Node3D
		current = current.get_parent()
	return null


func _resolve_service_structure(node: Node) -> Node3D:
	var structure = _resolve_structure_with_building_type(node)
	if structure == null:
		return null
	var building_type = str(structure.get_meta("building_type", ""))
	return structure if _is_supported_service_building_type(building_type) else null


func _is_supported_service_building_type(building_type: String) -> bool:
	return _module_for_building_type(building_type) == INTERIOR_MODULE_SERVICE


# ── windows: what is outside sees in (scripts/ui/window_portal.gd) ────────────

## The windows of the room you are in, for whatever is outside at night (the
## Photographer, scripts/enemies/tourist_brain.gd; the Silent Man watching): [{pos, out
## (world), facing (how squarely you look at it), open (its curtain 0..1), flash: Callable,
## view (your eye out in the camp: the window's camera)}]; [] outdoors or in a room with
## none.
func photo_windows() -> Array:
	var it = _open_room_interior()
	if it != null and it.has_method("photo_windows"):
		return it.photo_windows()
	return []


## The building whose windows those are ("office", "x:y"), "" none.
func photo_building() -> String:
	var r := coop_room()
	return str(r.get("k", ""))


## Curtains drawn here: to the other wardens (they see them drawn when in the same room).
var _curtains_by_room: Dictionary = {}


func coop_send_curtains(state: Array) -> void:
	var key := photo_building()
	if key == "":
		return
	_curtains_by_room[key] = state.duplicate()
	if Coop.is_active():
		Coop.send_curtains(key, state)


func coop_take_curtains(key: String, state: Array) -> void:
	_curtains_by_room[key] = state.duplicate()
	if photo_building() != key:
		return
	var it = _open_room_interior()
	if it != null and it.has_method("take_curtains"):
		it.take_curtains(state)


## Coming into a room: its curtains as somebody left them.
func _restore_curtains() -> void:
	var key := photo_building()
	var it = _open_room_interior()
	if key != "" and _curtains_by_room.has(key) and it != null and it.has_method("take_curtains"):
		it.take_curtains(_curtains_by_room[key])


# ── co-op: the other warden in the same room (scripts/coop/coop.gd) ─────────

## The other wardens' figures in the room you are in: peer id -> {fig, in: the interior
## it is in, spot: where they stand about, sleeper: the one along a bed, job: theirs}.
var _coop_figs: Dictionary = {}


func _coop_entry(id: int) -> Dictionary:
	if not _coop_figs.has(id):
		_coop_figs[id] = {"fig": null, "in": null, "spot": Vector3.ZERO, "sleeper": null, "job": ""}
	return _coop_figs[id]


## The jobs the other wardens in your room have their hands on (theirs while they are at
## them), to the room's tasks and the businesses' marks.
func _coop_push_jobs() -> void:
	var jobs: Array = []
	for id in _coop_figs.keys():
		var j := str(_coop_figs[id].get("job", ""))
		if j != "":
			jobs.append(j)
	var it = _open_room_interior()
	if it == null:
		return
	var room_tasks = _room_tasks(it) if it != _building_interior else null
	if room_tasks != null and "coop_taken" in room_tasks:
		room_tasks.coop_taken = jobs
	if it == _service_interior and "coop_partner_jobs" in it:
		it.coop_partner_jobs = jobs


## The room you are in, for the other machine: {k: room key, t: kind, s: which part
## of it, w: the job your hands are on}, or {} outside the rooms.
func coop_room() -> Dictionary:
	# Behind the corn stand: which station (scripts/corn/stand_view.gd).
	if _corn_stand != null and _corn_stand.is_open():
		return _corn_stand.coop_room()
	var it = _open_room_interior()
	if it == null:
		return {}
	if it == _building_interior:
		var extras = it.get("_extras")
		var part := str(extras.get("where")) if extras != null else "office"
		var desk = it.get("_desk_room")
		var job := "pc" if it.is_crt_view_active() else ("desk" if desk != null and desk.is_open() else "")
		# Reading the board or on the phone: the other warden sees them at it (the user
		# 20. 10.: "a visible action for the others").
		if job == "" and extras != null:
			var bv = extras.get("board_view")
			var pv = extras.get("phone_view")
			if bv != null and is_instance_valid(bv) and bool(bv.get("visible")):
				job = "board"
			elif pv != null and is_instance_valid(pv) and bool(pv.get("visible")):
				job = "phone"
		var info := {"k": "office", "t": "office", "s": part, "w": job}
		# Walking between the office's rooms: where from, how far along (the other machine
		# walks their figure through the doorway).
		var walk: Dictionary = extras.coop_walk() if extras != null and extras.has_method("coop_walk") else {}
		if not walk.is_empty():
			info["go"] = walk
		return info
	var node: Node3D = _open_room_node(it)
	return {"k": _room_key_for(node), "t": _room_kind(it), "s": _room_part(it), "w": _room_job(it)}


## Where the other warden stands in the office building (its rooms' own coordinates,
## on the floor): leaning on the counter from the front, by the set at the foot of the
## bed, at the back of the store; at the PC, on its chair (beside you, at the counter).
const COOP_OFFICE_SPOTS := {"office": Vector3(-0.6, 0.0, -0.9), "back": Vector3(-4.3, 0.0, 1.85), "store": Vector3(-0.3, 0.0, 3.95)}
## At the desk: behind the counter to your right, by the phone (the "write" picture is
## the body from the hips up; the counter top hides where it ends).
const COOP_DESK_SPOT := Vector3(1.15, 0.84, 0.74)
## At the cork board on the right wall (reception_extras._build_board), and behind the
## counter at the phone (_build_phone), on the floor.
const COOP_BOARD_SPOT := Vector3(1.98, 0.0, -0.45)
const COOP_PHONE_SPOT := Vector3(1.42, 0.0, 0.8)
## The back room's bed (back_room.BED), the mattress's top.
const COOP_BED := Vector3(-5.1, 0.5, 0.85)
## From the office's own spot to the doorway and through it (the floor under the camera's
## way in reception_extras.go_back_room / go_store), to the room's spot.
const COOP_OFFICE_WAYS := {
	"back": [Vector3(-0.6, 0.0, -0.9), Vector3(-0.8, 0.0, 0.6), Vector3(-1.05, 0.0, 1.26), Vector3(-2.15, 0.0, 1.28), Vector3(-3.15, 0.0, 1.32), Vector3(-4.3, 0.0, 1.85)],
	"store": [Vector3(-0.6, 0.0, -0.9), Vector3(-0.7, 0.0, 0.7), Vector3(0.12, 0.0, 1.85), Vector3(0.0, 0.0, 2.55), Vector3(-0.3, 0.0, 3.95)],
}


func _coop_office_path(from: String, to: String) -> Array:
	if COOP_OFFICE_WAYS.has(to):
		return COOP_OFFICE_WAYS[to]
	var back: Array = (COOP_OFFICE_WAYS.get(from, COOP_OFFICE_WAYS["back"]) as Array).duplicate()
	back.reverse()
	return back


func _coop_along(path: Array, k: float) -> Vector3:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector3).distance_to(path[i - 1])
	var want := total * k
	for i in range(1, path.size()):
		var seg := (path[i] as Vector3).distance_to(path[i - 1])
		if want <= seg or i == path.size() - 1:
			return (path[i - 1] as Vector3).lerp(path[i], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return path[0]


func _open_room_interior():
	for it in [_cabin_interior, _tent_interior, _caravan_interior, _service_interior, _building_interior]:
		if it != null and is_instance_valid(it) and it.has_method("is_open") and it.is_open():
			return it
	return null


func _open_room_node(it) -> Node3D:
	if it == _cabin_interior:
		return _active_cabin_node
	if it == _tent_interior:
		return _active_tent_node
	if it == _caravan_interior:
		return _active_caravan_node
	return _active_service_node


func _room_kind(it) -> String:
	if it == _cabin_interior:
		return "cabin"
	if it == _tent_interior:
		return "tent"
	if it == _caravan_interior:
		return "caravan"
	return "service"


## Which part of the room (the cabin's bathroom, a block's left stall, the pub's cellar).
func _room_part(it) -> String:
	if it == _cabin_interior:
		return str(it.get("_active_room"))
	if it == _service_interior:
		return str(it.coop_part()) if it.has_method("coop_part") else "%s/%s/%s" % [str(it.get("_current_profile")), str(it.get("_active_subroom")), str(it.get("toilet_entry"))]
	return "main"


func _room_tasks(it):
	var prep = it.get("_prep") if it != _service_interior else it.get("_upkeep_prep")
	if prep == null:
		return null
	return prep.get("tasks")


func _room_job(it) -> String:
	var tasks = _room_tasks(it)
	var w := str(tasks.working_on()) if tasks != null and tasks.has_method("working_on") else ""
	# A business's counter games: the tap, the pass, the till... (service_interior.coop_job).
	if w == "" and it == _service_interior and it.has_method("coop_job"):
		w = str(it.coop_job())
	return w


## Another warden's place in your room (`id`: theirs), each time their state comes in:
## their figure stands across the room from you (where you were looking when they came
## in; the next one a pace further along), or at the job they are doing (the broom for
## sweeping and mopping, down on a knee for the rest; a job at your feet has them on its
## far side). In a tent they lie on their belly down its middle, under the ridge (at the
## back, or by their job). Not in your room: no figure.
func coop_partner(info: Dictionary, id := 0) -> void:
	if id == 0:
		id = Coop.remote_id
	var look: Dictionary = Coop.look_of(id)
	var model := int(look.get("m", 1))
	var mine := coop_room()
	var same: bool = not info.is_empty() and not mine.is_empty() and str(info.get("k", "")) == str(mine["k"]) \
		and str(info.get("t", "")) == str(mine["t"]) and str(info.get("s", "")) == str(mine["s"]) and str(mine["k"]) != ""
	# The office building is one space (the office, the back room and the store are built
	# side by side; the walls and doors between them are real): whoever is anywhere in it
	# stands where they are, seen from wherever the walls let you (playtest 20. 10.: "from
	# the little room you cannot see the player in the reception, at the PC").
	if not same and not info.is_empty() and str(info.get("k", "")) == "office" and str(mine.get("k", "")) == "office":
		same = true
	if not same:
		coop_drop_partner(id)
		return
	var it = _open_room_interior()
	if it == null:
		# Both behind the corn stand: they are seen there in the camp, as they are.
		coop_drop_partner(id)
		return
	var e := _coop_entry(id)
	# Their job is theirs while they are at it.
	e["job"] = str(info.get("w", ""))
	_coop_push_jobs()
	var vp: Node = it.get("_viewport")
	var cam: Camera3D = it.get("_interior_camera")
	if vp == null or cam == null:
		return
	# In bed: seen lying on it from the back room, or in the tent, cabin or caravan
	# they turned in in (lodge_bed.gd), nowhere else.
	var has_bed: bool = COOP_LOOKS.has_pose(model, "bed")
	# The staffroom's boiler room has a bed too (lodge_bed "staff").
	var bed_kind := "staff" if str(mine["t"]) == "service" and str(mine.get("s", "")).begins_with("staff/") else str(mine["t"])
	var lodge: bool = not LODGE_BED.bed_spot(bed_kind).is_empty()
	if bool(info.get("b", false)) and not (has_bed and (lodge or str(mine["t"]) == "office")):
		coop_drop_partner(id)
		return
	var tent: bool = str(mine["t"]) == "tent"
	# The camera is a child of the room's root, which stands on the floor: its own height
	# is your eyes' (low in a tent).
	var root := cam.get_parent() as Node3D
	var floor_y := cam.global_position.y - cam.position.y
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var fig: Node3D = e["fig"]
	if fig == null or not is_instance_valid(fig) or e["in"] != it or fig.get_parent() != vp:
		coop_drop_partner(id)
		e = _coop_entry(id)
		e["job"] = str(info.get("w", ""))
		fig = COOP_FIGURE.new()
		fig.setup(model, int(look.get("c", 0)), true)
		vp.add_child(fig)
		e["fig"] = fig
		e["in"] = it
		var right := cam.global_basis.x
		right.y = 0.0
		right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
		# Across the room from you (a cabin is three paces deep), a little to one side, the
		# next of them a pace along the other way; in a tent at its back, one behind another.
		var nth := maxi(0, Coop.others().find(id))
		var side := 0.3 + 0.6 * float(nth)
		var spot: Vector3 = cam.global_position + fwd * 1.8 + right * (side if nth % 2 == 0 else -side)
		if tent and root != null:
			spot = _coop_tent_spot(root, root.global_transform * Vector3(0.0, 0.0, -0.6 + 0.25 * float(nth)))
		spot.y = floor_y
		e["spot"] = spot
	if not (bool(info.get("b", false)) and lodge):
		_coop_hide_sleeper(id)
	if bool(info.get("b", false)) and lodge and root != null:
		# On their back on the bed, the head on the pillow end.
		var spot: Dictionary = LODGE_BED.bed_spot(bed_kind)
		var head: Vector3 = root.global_transform * (spot["head"] as Vector3)
		var mid: Vector3 = root.global_transform * (spot["centre"] as Vector3)
		fig.set_walking(false)
		# Seen along the bed (a cabin's, a tent's from the door): from the foot end; seen
		# across it (the caravan's dinette): from the side.
		var axis := head - mid
		axis.y = 0.0
		var along: bool = axis.length() > 0.01 and absf(axis.normalized().dot(fwd)) > 0.6
		if along and COOP_LOOKS.has_pose(model, "bedfoot"):
			fig.visible = false
			_coop_lay_sleeper(id, vp, root.global_transform * (spot["foot"] as Vector3), head)
			return
		_coop_hide_sleeper(id)
		fig.show_at(mid, "bed")
		fig.set_flip((head - mid).dot(cam.global_basis.x) > 0.0)
		return
	if str(mine["t"]) == "office" and root != null:
		_place_office_fig(fig, info, model, root, cam.global_basis.x)
		return
	var job := str(info.get("w", ""))
	if it == _service_interior and it.has_method("coop_job_spot"):
		var at_job: Dictionary = it.coop_job_spot(job) if job != "" else {}
		if not at_job.is_empty():
			# Behind the counter at the job they have open (the tap, the pass, the till).
			var pose := str(at_job["pose"])
			if not COOP_LOOKS.has_pose(model, pose):
				pose = "stand"
			fig.set_walking(false)
			fig.show_at(at_job["pos"], pose)
			return
	if job != "":
		var tasks = _room_tasks(it)
		var t: Dictionary = tasks.target_info(job) if tasks != null and tasks.has_method("target_info") else {}
		if not t.is_empty():
			# Just this side of the job, but a pace and a half from you at least.
			var to: Vector3 = (t["pos"] as Vector3) - cam.global_position
			to.y = 0.0
			var dist := to.length()
			var dir := to / dist if dist > 0.01 else fwd
			var near := 0.8 if tent else 1.5
			var at := cam.global_position + dir * clampf(dist - 0.45, near, dist + 0.6)
			if tent and root != null:
				at = _coop_tent_spot(root, at)
			at.y = floor_y
			var verb := str(t.get("verb", ""))
			var pose := "sweep" if verb in ["Sweeping", "Mopping"] else ("stand" if verb in ["Making the bed", "Rolling out"] else "crouch")
			fig.show_at(at, "prone" if tent else pose)
			return
	fig.show_at(e["spot"], "prone" if tent else "stand")


## A warden in the office building where their state says they are (their part of it,
## their job, the bed, the walk through a doorway), in the office's own world: for whoever
## is in it with them, and seen from the camp through its windows (_coop_office_from_camp).
## `right`: the eye's right, for which way a sleeper is drawn.
func _place_office_fig(fig: Node3D, info: Dictionary, model: int, root: Node3D, right: Vector3) -> void:
	var it = _building_interior
	fig.set_walking(false)
	fig.set_flip(false)
	if bool(info.get("b", false)):
		# On their back on the bed, the head on the pillow (back_room.lie_pose's end).
		var head: Vector3 = root.global_transform * (COOP_BED + Vector3(0.0, 0.0, -0.75))
		var feet: Vector3 = root.global_transform * (COOP_BED + Vector3(0.0, 0.0, 0.75))
		fig.show_at(root.global_transform * COOP_BED, "bed")
		fig.set_flip((head - feet).dot(right) > 0.0)
		return
	var go: Dictionary = info.get("go", {})
	if not go.is_empty():
		# Through the doorway, as their camera goes (reception_extras.go_*).
		var path := _coop_office_path(str(go.get("f", "")), str(go.get("to", "")))
		var at := _coop_along(path, clampf(float(go.get("k", 0.0)), 0.0, 1.0))
		fig.show_at(root.global_transform * at, "stand")
		fig.set_walking(true)
		return
	# Where they are (their part of the building, not yours).
	var spot: Vector3 = COOP_OFFICE_SPOTS.get(str(info.get("s", "office")), COOP_OFFICE_SPOTS["office"])
	var pose := "stand"
	if str(info.get("w", "")) == "desk" and COOP_LOOKS.has_pose(model, "write"):
		# Behind the counter, bent over the register.
		spot = COOP_DESK_SPOT
		pose = "write"
	elif str(info.get("w", "")) == "board":
		# In front of the board, reading it.
		spot = COOP_BOARD_SPOT
		fig.set_flip(true)
	elif str(info.get("w", "")) == "phone":
		# At the phone behind the counter, the handset up (bent to it, if there is a picture).
		spot = COOP_PHONE_SPOT
		if COOP_LOOKS.has_pose(model, "write"):
			spot = COOP_DESK_SPOT + Vector3(0.12, 0.0, 0.1)
			pose = "write"
	if str(info.get("w", "")) == "pc":
		# On the chair at the PC, their back to the room: you look over their shoulder.
		var seat: Vector3 = it.get("_crt_full_cam_pos")
		# The eyes' seat is a little back from the keyboard: the body sits in nearer.
		var screen: Vector3 = it.PC_OFFSET + it.CRT_PIVOT
		var at_desk := seat.lerp(screen, 0.38)
		spot = Vector3(at_desk.x, 0.0, at_desk.z)
		pose = "desk"
	fig.show_at(root.global_transform * spot, pose)


## The other wardens in the office building seen from the camp through its windows (the
## user 21. 10.: "players walking about inside, at the PC, going into the other room: all
## of it seen from outside and in step"): while the office is not open here and its
## windows look into it (building_interior._inview_live), each warden whose room is the
## office gets a figure in the office's world, placed as inside (_place_office_fig).
var _office_figs: Dictionary = {}
var _office_figs_t := 0.0


func _coop_office_from_camp(delta: float) -> void:
	var bi = _building_interior
	var live: bool = bi != null and Coop.is_active() and not bi.is_open() and bool(bi.get("_inview_live"))
	if not live:
		if not _office_figs.is_empty():
			for id in _office_figs.keys():
				var f = _office_figs[id]
				if f != null and is_instance_valid(f):
					f.queue_free()
			_office_figs.clear()
		return
	_office_figs_t -= delta
	if _office_figs_t > 0.0:
		return
	_office_figs_t = 0.1
	var vp: Node = bi.get("_viewport")
	var root: Node3D = bi.get("_room_root")
	if vp == null or root == null:
		return
	var seen: Array = []
	for id in Coop.others():
		var info: Dictionary = Coop.state_of(id).get("room", {})
		if str(info.get("k", "")) != "office":
			continue
		seen.append(id)
		var look: Dictionary = Coop.look_of(id)
		var model := int(look.get("m", 1))
		var fig = _office_figs.get(id)
		if fig == null or not is_instance_valid(fig):
			fig = COOP_FIGURE.new()
			fig.setup(model, int(look.get("c", 0)), true)
			vp.add_child(fig)
			_office_figs[id] = fig
		_place_office_fig(fig, info, model, root, Vector3.RIGHT)
	for id in _office_figs.keys():
		if not id in seen:
			var f = _office_figs[id]
			if f != null and is_instance_valid(f):
				f.queue_free()
			_office_figs.erase(id)


## A place in a tent for the other warden: down its middle (the walls slope in to the
## ridge), between your knees and the back.
func _coop_tent_spot(root: Node3D, at: Vector3) -> Vector3:
	var loc := root.global_transform.affine_inverse() * at
	loc.x = clampf(loc.x, -0.12, 0.12)
	loc.z = clampf(loc.z, -0.75, -0.1)
	loc.y = 0.0
	return root.global_transform * loc


## The other warden asleep in a lodging's bed, seen along it (lodge_bed.gd): their
## picture from the foot end laid back along the mattress (the head on the pillow, the
## boots towards the foot, tilted up enough to be seen), not turning to face you.
const COOP_SLEEPER_TILT := 28.0
const COOP_SLEEPER_LENGTH := 0.72


func _coop_lay_sleeper(id: int, vp: Node, foot: Vector3, head: Vector3) -> void:
	var e := _coop_entry(id)
	var sl: Sprite3D = e["sleeper"]
	if sl == null or not is_instance_valid(sl) or sl.get_parent() != vp:
		_coop_hide_sleeper(id)
		var look: Dictionary = Coop.look_of(id)
		var tex: Texture2D = COOP_LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "bedfoot")
		if tex == null:
			return
		var s := Sprite3D.new()
		s.name = "CoopSleeper"
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.double_sided = true
		s.shaded = true
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.texture = tex
		s.pixel_size = COOP_SLEEPER_LENGTH / float(tex.get_height())
		s.offset = Vector2(0.0, tex.get_height() * 0.5)
		vp.add_child(s)
		e["sleeper"] = s
		sl = s
	var along := head - foot
	along.y = 0.0
	along = along.normalized()
	var tilt := deg_to_rad(COOP_SLEEPER_TILT)
	var up := (along * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var n := (Vector3.UP * cos(tilt) - along * sin(tilt)).normalized()
	var right := up.cross(n)
	sl.global_transform = Transform3D(Basis(right, up, n), head - along * (COOP_SLEEPER_LENGTH * cos(tilt)) + Vector3(0, 0.04, 0))


func _coop_hide_sleeper(id: int) -> void:
	if not _coop_figs.has(id):
		return
	var sl = _coop_figs[id].get("sleeper")
	if sl != null and is_instance_valid(sl):
		sl.queue_free()
	_coop_figs[id]["sleeper"] = null


## A warden's figure gone from your room (`id` -1: every one of them).
func coop_drop_partner(id := -1) -> void:
	var ids: Array = _coop_figs.keys() if id == -1 else [id]
	for i in ids:
		if not _coop_figs.has(i):
			continue
		_coop_hide_sleeper(i)
		var fig = _coop_figs[i].get("fig")
		if fig != null and is_instance_valid(fig):
			fig.queue_free()
		_coop_figs.erase(i)
	_coop_push_jobs()


## A warden's look changed: their figure in the room changes with it (`id` 0: all).
func coop_partner_look(look: Dictionary, id := 0) -> void:
	for i in _coop_figs.keys():
		if id != 0 and i != id:
			continue
		var fig = _coop_figs[i].get("fig")
		if fig != null and is_instance_valid(fig) and fig.has_method("set_look"):
			var l: Dictionary = Coop.look_of(i) if id == 0 else look
			fig.set_look(int(l.get("m", 1)), int(l.get("c", 0)))


## A room's state changed under you (the host's camp sent it, or did the other
## warden's job): the room you are in, if it is that one, shows it.
func coop_refresh_room(key: String) -> void:
	var it = _open_room_interior()
	if it == null or it == _service_interior:
		return
	var node: Node3D = _open_room_node(it)
	if _room_key_for(node) == key:
		_push_room_state(it, node)
