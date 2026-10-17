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
## Through the door and back: the frozen frame breaking up in steps (twelve a second).
const DOOR_TRANSITION_SCRIPT = preload("res://scripts/ui/door_transition.gd")
## Out of the camp: the barrier, the road, the bus stop (scripts/town/town_trip.gd).
const TOWN_TRIP_SCRIPT = preload("res://scripts/town/town_trip.gd")
## Birds, crows, bats and moths over wherever you are outdoors (scripts/ambient/sky_life.gd).
const SKY_LIFE_SCRIPT = preload("res://scripts/ambient/sky_life.gd")
const COOP_FIGURE = preload("res://scripts/coop/remote_player.gd")

const TIME_NIGHT: int = 2

const INTERIOR_MODULE_MAIN := "main"
const INTERIOR_MODULE_TENT := "tent"
const INTERIOR_MODULE_CARAVAN := "caravan"
const INTERIOR_MODULE_CABIN := "cabin"
const INTERIOR_MODULE_SERVICE := "service"
## "trip_*" and "town_*" things outside the camp (town_trip.handles()).
const INTERIOR_MODULE_TRIP := "trip"
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
		"building_types": ["restaurant", "pub", "toilet_block", "shower_block", "sewer", "power_generator", "vecerka"],
		"hint": "Enter",
		"hints": {
			"restaurant": "Enter bistro",
			"pub": "Enter pub",
			"vecerka": "Enter Jednota Mart",
			"toilet_block": "Enter toilets",
			"shower_block": "Enter showers",
			"sewer": "Open sewer hatch",
			"power_generator": "Enter generator shed",
		},
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
## exit would (each hands the player back their controls).
func close_everything() -> void:
	if _guest_dialog != null and _guest_dialog.is_open():
		_guest_dialog.close_dialog()
	if _building_upgrade_menu != null and _building_upgrade_menu.is_open():
		_building_upgrade_menu.close_menu()
	for interior in _get_registered_interior_nodes():
		if not (interior.has_method("is_open") and interior.is_open()):
			continue
		for m in ["close_interior", "close_cabin", "close_tent", "close_caravan", "close_service"]:
			if interior.has_method(m):
				interior.call(m)
				break
	_set_player_controls_enabled(true)


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
		_:
			return


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
	return _hint_for_building_type(building_type)


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
	if _building_interior.is_open():
		return
	_apply_time_to_interior(_building_interior)
	_door_transition(true)
	_building_interior.open_interior()
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
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
		_door_transition(false)
		if _audio_manager != null and _audio_manager.has_method("play_door_close"):
			_audio_manager.play_door_close()
		_set_player_controls_enabled(true)


func _on_tent_interact(tent_node: Node) -> void:
	if _tent_interior == null:
		return
	if _tent_interior.is_open():
		return
	if _refuse_if_occupied(tent_node as Node3D, "tent"):
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
	var t := str(caravan_node.get_meta("building_type", "caravan_1"))
	var level := clampi(int(t.right(1)), 1, 3)
	_active_caravan_node = caravan_node as Node3D
	_apply_time_to_interior(_caravan_interior)
	_door_transition(true)
	_caravan_interior.open_caravan(level)
	_push_room_state(_caravan_interior, _active_caravan_node)
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
		_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


func _on_caravan_closed() -> void:
	_active_caravan_node = null
	_door_transition(false)
	if _audio_manager != null and _audio_manager.has_method("play_door_close"):
		_audio_manager.play_door_close()
	_set_player_controls_enabled(true)


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
	_active_tent_node = null
	_door_transition(false)
	_set_player_controls_enabled(true)


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
	_sync_cabin_guest_visuals()
	_push_room_state(_cabin_interior, _active_cabin_node)
	if _audio_manager != null and _audio_manager.has_method("play_door_open"):
		_audio_manager.play_door_open()
	_set_player_controls_enabled(false)


func _on_cabin_closed() -> void:
	if _cabin_interior != null and _cabin_interior.has_method("set_guest_occupants"):
		_cabin_interior.set_guest_occupants([])
	_active_cabin_node = null
	_door_transition(false)
	if _audio_manager != null and _audio_manager.has_method("play_door_close"):
		_audio_manager.play_door_close()
	_set_player_controls_enabled(true)


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
	_active_service_node = structure
	_apply_time_to_interior(_service_interior)
	if building_type == "toilet_block" and "toilet_entry" in _service_interior:
		_service_interior.toilet_entry = _toilet_door_of(structure as Node3D)
	_door_transition(true)
	_service_interior.open_service(building_type)
	if _service_interior.has_method("set_upkeep_target"):
		_service_interior.set_upkeep_target(structure.get_meta("grid_origin", Vector2i(-999, -999)), building_type)
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
	_active_service_node = null
	_door_transition(false)
	if _audio_manager != null and _audio_manager.has_method("play_door_close"):
		_audio_manager.play_door_close()
	_set_player_controls_enabled(true)


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
		_service_interior.close_service()
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
	# Co-op: upgrades are bought in the host's camp (the other warden's hands come later).
	if _building_upgrade_menu == null or Coop.is_client():
		return
	_building_upgrade_menu.open_menu(title_text, desc_text, cost_text, enabled)
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


# ── co-op: the other warden in the same room (scripts/coop/coop.gd) ─────────

## The other warden's figure in the room you are in, and the interior it is in.
var _coop_fig: Node3D
var _coop_fig_in: Object
var _coop_fig_spot := Vector3.ZERO


## The room you are in, for the other machine: {k: room key, t: kind, s: which part
## of it, w: the job your hands are on}, or {} outside the rooms.
func coop_room() -> Dictionary:
	var it = _open_room_interior()
	if it == null:
		return {}
	var node: Node3D = _open_room_node(it)
	return {"k": _room_key_for(node), "t": _room_kind(it), "s": _room_part(it), "w": _room_job(it)}


func _open_room_interior():
	for it in [_cabin_interior, _tent_interior, _caravan_interior, _service_interior]:
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
		return "%s/%s/%s" % [str(it.get("_current_profile")), str(it.get("_active_subroom")), str(it.get("toilet_entry"))]
	return "main"


func _room_tasks(it):
	var prep = it.get("_prep") if it != _service_interior else it.get("_upkeep_prep")
	if prep == null:
		return null
	return prep.get("tasks")


func _room_job(it) -> String:
	var tasks = _room_tasks(it)
	return str(tasks.working_on()) if tasks != null and tasks.has_method("working_on") else ""


## The other warden's place in your room, each time their state comes in: their figure
## stands across the room from you (where you were looking when they came in), or at
## the job they are doing (the broom for sweeping and mopping, down on a knee for the
## rest; a job at your feet has them on its far side). In a tent they lie on their belly
## down its middle, under the ridge (at the back, or by their job). Not in your room: no
## figure.
func coop_partner(info: Dictionary) -> void:
	var mine := coop_room()
	var same: bool = not info.is_empty() and not mine.is_empty() and str(info.get("k", "")) == str(mine["k"]) \
		and str(info.get("t", "")) == str(mine["t"]) and str(info.get("s", "")) == str(mine["s"]) and str(mine["k"]) != ""
	if not same:
		coop_drop_partner()
		return
	var it = _open_room_interior()
	var vp: Node = it.get("_viewport")
	var cam: Camera3D = it.get("_interior_camera")
	if vp == null or cam == null:
		return
	var tent: bool = str(mine["t"]) == "tent"
	# The camera is a child of the room's root, which stands on the floor: its own height
	# is your eyes' (low in a tent).
	var root := cam.get_parent() as Node3D
	var floor_y := cam.global_position.y - cam.position.y
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	if _coop_fig == null or not is_instance_valid(_coop_fig) or _coop_fig_in != it or _coop_fig.get_parent() != vp:
		coop_drop_partner()
		var look: Dictionary = Coop.partner_look
		_coop_fig = COOP_FIGURE.new()
		_coop_fig.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
		vp.add_child(_coop_fig)
		_coop_fig_in = it
		var right := cam.global_basis.x
		right.y = 0.0
		right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
		# Across the room from you (a cabin is three paces deep), a little to one side; in
		# a tent at its back.
		_coop_fig_spot = cam.global_position + fwd * 1.8 + right * 0.3
		if tent and root != null:
			_coop_fig_spot = _coop_tent_spot(root, root.global_transform * Vector3(0.0, 0.0, -0.6))
		_coop_fig_spot.y = floor_y
	var job := str(info.get("w", ""))
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
			_coop_fig.show_at(at, "prone" if tent else pose)
			return
	_coop_fig.show_at(_coop_fig_spot, "prone" if tent else "stand")


## A place in a tent for the other warden: down its middle (the walls slope in to the
## ridge), between your knees and the back.
func _coop_tent_spot(root: Node3D, at: Vector3) -> Vector3:
	var loc := root.global_transform.affine_inverse() * at
	loc.x = clampf(loc.x, -0.12, 0.12)
	loc.z = clampf(loc.z, -0.75, -0.1)
	loc.y = 0.0
	return root.global_transform * loc


func coop_drop_partner() -> void:
	if _coop_fig != null and is_instance_valid(_coop_fig):
		_coop_fig.queue_free()
	_coop_fig = null
	_coop_fig_in = null


## The other warden's look changed: the figure in the room changes with it.
func coop_partner_look(look: Dictionary) -> void:
	if _coop_fig != null and is_instance_valid(_coop_fig) and _coop_fig.has_method("set_look"):
		_coop_fig.set_look(int(look.get("m", 1)), int(look.get("c", 0)))


## A room's state changed under you (the host's camp sent it, or did the other
## warden's job): the room you are in, if it is that one, shows it.
func coop_refresh_room(key: String) -> void:
	var it = _open_room_interior()
	if it == null or it == _service_interior:
		return
	var node: Node3D = _open_room_node(it)
	if _room_key_for(node) == key:
		_push_room_state(it, node)
