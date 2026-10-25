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
## The staffroom's two rooms (scripts/staff/staffroom.gd), its laptop and its books.
const STAFFROOM = preload("res://scripts/staff/staffroom.gd")
const STAFF_PLAN = preload("res://scripts/staff/staffroom_plan.gd")
const LAPTOP_VIEW = preload("res://scripts/staff/laptop_view.gd")
const STAFF_LEDGER = preload("res://scripts/staff/staff_ledger.gd")
var _staff_room
## Lying on the staffroom's mattress (scripts/lodge_bed.gd has the camera).
var lodge_sleeping := false
var _laptop_view: CanvasLayer
var _staff_ledger: CanvasLayer
const MESS_RULES = preload("res://core/systems/mess_rules.gd")
const BUILDING_MODELS = preload("res://scripts/building_models.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const UPKEEP_RULES = preload("res://core/systems/maintenance_rules.gd")
const SERVICE_LIFE = preload("res://scripts/food/service_life.gd")
## Where the work waits in here (the tap, the pass, the till...): scripts/food/work_marks.gd.
const WORK_MARKS = preload("res://scripts/food/work_marks.gd")
var _marks: Node
## The doors between a business's rooms, point and click (scripts/food/business_doors.gd).
const BUSINESS_DOORS = preload("res://scripts/food/business_doors.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
var _doors = BUSINESS_DOORS.new()
## The bistro (scripts/bistro/): its three rooms, its stations played full screen (one
## per station, made when first used), the marks over the room, the sentence under it.
const BISTRO_LAYOUT = preload("res://scripts/bistro/bistro_layout.gd")
const BISTRO_MARKS = preload("res://scripts/bistro/bistro_marks.gd")
const ROOM_SENTENCE = preload("res://scripts/bistro/room_sentence.gd")
const BISTRO_STATIONS := {
	"stove": "res://scripts/bistro/stove_station.gd",
	"pot": "res://scripts/bistro/pot_station.gd",
	"pass": "res://scripts/bistro/pass_station.gd",
	"sink": "res://scripts/bistro/sink_station.gd",
	"potatoes": "res://scripts/bistro/potato_station.gd",
	"breading": "res://scripts/bistro/breading_station.gd",
	"machine": "res://scripts/bistro/machine_station.gd",
	"grill": "res://scripts/bistro/grill_station.gd",
	"bufet": "res://scripts/bistro/bufet_station.gd",
	"floor": "res://scripts/bistro/floor_station.gd",
}
var _stations: Dictionary = {}
const STATION3D = preload("res://scripts/business/station3d.gd")
const STATION_HUD = preload("res://scripts/business/station_hud.gd")
const BIZ_RULES = preload("res://core/systems/business_rules.gd")
var _tabs_t := 0.0
var _station_hud: CanvasLayer
## Going from one station straight to another: the camera does not go back first.
var _switching := false
## Where the camera was before it went over a station ([transform, rotation]; [] none).
var _station_cam_from: Array = []
var _station_tween: Tween
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
var _sentence: Control
var _bistro_marks: Control
var _dirty_shown := -1
var _taken_t := 0.0
## The tickets up last time (a new one clips onto the rail with a ding).
var _tickets_seen: Dictionary = {}
var _tickets_known := false
var _bistro_sfx: AudioStreamPlayer
var _hot_glint = HOVER_GLINT.new()
var _hot_glint_on: Object = null
## The pub (scripts/pub/): its bar and its cellar, its stations worked in the rooms the
## bistro's way (pub_layout.gd STATIONS, SURFACES), the marks over its rooms; the bars'
## state is taproom.gd (made with the businesses).
const PUB_LAYOUT = preload("res://scripts/pub/pub_layout.gd")
const PUB_MARKS = preload("res://scripts/pub/pub_marks.gd")
const TAPROOM = preload("res://scripts/pub/taproom.gd")
const PUB_STATIONS := {
	"tap": "res://scripts/pub/tap_station.gd",
	"back": "res://scripts/pub/back_station.gd",
	"wash": "res://scripts/pub/wash_station.gd",
	"keg": "res://scripts/pub/keg_station.gd",
	"slot": "res://scripts/pub/slot_station.gd",
	"darts": "res://scripts/pub/darts_station.gd",
	"cards": "res://scripts/pub/cards_station.gd",
}
var _pub_marks: Control
## The Jednota (scripts/jednota/): its shop and its storeroom, its stations worked in the
## rooms the pub's way (jednota_layout.gd STATIONS, SURFACES); the shop's state is
## jednota.gd (made with the businesses).
const JEDNOTA_LAYOUT = preload("res://scripts/jednota/jednota_layout.gd")
const JEDNOTA = preload("res://scripts/jednota/jednota.gd")
const JEDNOTA_STATIONS := {
	"till": "res://scripts/jednota/till_station.gd",
	"shelves": "res://scripts/jednota/shelves_station.gd",
	"store": "res://scripts/jednota/store_station.gd",
	"deli": "res://scripts/jednota/deli_station.gd",
}
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
## The counter minigames (scripts/food/*_closeup.gd), clicked in the room to step behind
## the thing: none now (the bistro's, the pub's and the Jednota's stations are worked in
## their rooms: BISTRO_STATIONS, PUB_STATIONS, JEDNOTA_STATIONS).
const COUNTER_GAMES := {}
## The other jobs behind a counter: id -> {script, profile, room, at, size} (none now: the
## pub's back bar and washer are its stations).
const EXTRA_GAMES := {}
var _extra_games: Dictionary = {}
var _counter_game: CanvasLayer
## The business's books on the counter (scripts/business/ledger_closeup.gd).
const LEDGER := preload("res://scripts/business/ledger_closeup.gd")
const LEDGER_AT := {"pub": Vector3(0.42, 1.08, -1.1), "rest": Vector3(1.42, 0.98, -1.12), "vecerka": Vector3(3.02, 1.105, -1.05)}
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
		elif _current_profile == "pub" and not _is_open:
			_set_pub_room("main", true)
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
	if _current_profile == "staff" and _staff_room != null:
		_staff_room.on_open()
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
	for v in [_laptop_view, _staff_ledger]:
		if v != null and v.visible:
			v.call("close_now")
	for g in _extra_games.values():
		if (g as CanvasLayer).visible:
			(g as CanvasLayer).call("_closing")
			(g as CanvasLayer).visible = false
	_switching = true
	for v in _stations.values():
		if is_instance_valid(v):
			v.call("close_station")
	_switching = false
	if _station_hud != null and is_instance_valid(_station_hud):
		_station_hud.visible = false
	if _sentence != null:
		_sentence.visible = true
	_station_cam_from = []
	if _sentence != null:
		_sentence.clear()
	_stop_life()
	if _amb != null:
		_amb.stop()
	_update_sewer_ambience_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	if lodge_sleeping:
		_tick_windows(delta)
		return
	_tick_windows(delta)
	_hook_zreport()
	_update_late_night(delta)
	_update_basement_machine_animation(delta)
	if _marks != null and is_instance_valid(_marks):
		_marks.busy = [coop_job()] + coop_partner_jobs
	# Behind the counter in a close-up: the room holds still.
	if _counter_game != null and _counter_game.visible:
		return
	if _ledger != null and _ledger.visible:
		return
	if _current_profile == "staff" and _staff_room != null:
		_staff_room.tick(delta)
		if (_laptop_view != null and _laptop_view.visible) or (_staff_ledger != null and _staff_ledger.visible):
			return
		if _staff_room.walking():
			_hot_glint.clear()
			_hot_glint_on = null
			_update_torch(delta)
			return
	if _zreport != null and _zreport.visible:
		return
	if _sewer_terminal != null and _sewer_terminal.visible:
		return
	for g in _extra_games.values():
		if (g as CanvasLayer).visible:
			return
	if _current_profile in ["rest", "pub", "vecerka"]:
		if _current_profile == "rest":
			_bistro_tick(delta)
		elif _current_profile == "pub":
			_pub_tick(delta)
		else:
			_jednota_tick(delta)
		_tick_moods(delta)
		_tick_ambience(delta)
		# At a station, or the camera on its way to one or back: the room holds still.
		var open := _station_open()
		if open != "":
			_station_frame(open)
			return
		if _station_tween != null and _station_tween.is_valid() and _station_tween.is_running():
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
	elif _current_profile == "staff" and _staff_room != null and not INTERIOR_LOOK.in_exit_zone(get_viewport()) \
			and _staff_room.update_hover(get_viewport().get_mouse_position()) != "":
		_hover_things(null)
	elif INTERIOR_LOOK.in_exit_zone(get_viewport()):
		HandCursor.want(HandCursor.WALK)
		_hover_things(null)
	else:
		var hit := _raycast_world(get_viewport().get_mouse_position())
		var collider = hit.get("collider", null) as Node
		var door_hover := _doors.hover(collider, _door_room())
		if door_hover != "":
			HandCursor.want(HandCursor.WALK)
			_hover_things(null)
		elif _hover_click_type() != "":
			# Only worth a look (a line under the room): the eye; something that does
			# something: the finger and its glint.
			if _hover_click_type() == "bistro_look":
				HandCursor.want(HandCursor.LOOK)
				_hover_things(null)
			else:
				HandCursor.want(HandCursor.POINT)
				_hover_things(collider)
		else:
			_hover_things(null)
		if _sentence != null and _current_profile in ["rest", "pub", "vecerka"]:
			_sentence.hover(_bistro_sentence(collider, door_hover))
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
	if push != 0 and not (_current_profile in ["rest", "vecerka", "pub", "staff"]):
		_switch_service_room(push)


func _input(event: InputEvent) -> void:
	if not _is_open or lodge_sleeping:
		return
	if (_laptop_view != null and _laptop_view.visible) or (_staff_ledger != null and _staff_ledger.visible):
		return
	if _staff_room != null and _current_profile == "staff" and _staff_room.walking():
		return
	if _upkeep_prep != null and _upkeep_prep.is_scrubbing():
		return
	if _current_profile in ["rest", "pub", "vecerka"]:
		var open := _station_open()
		if open != "":
			_station_input(event, open)
			return
		if _station_tween != null and _station_tween.is_valid() and _station_tween.is_running():
			if not event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
			return
	# Esc is the pause menu's (main): S or the way out behind you leaves (but not a
	# click on something to clean, however low on the screen it is).
	var on_task: bool = _upkeep_prep != null and _upkeep_prep.is_busy()
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (on_task and event is InputEventMouseButton):
		# In the staffroom's boiler room S takes you back through to the lounge, not out of
		# the building (playtest 25. 10.); out is from the lounge.
		if _staff_room != null and _current_profile == "staff" and str(_staff_room.get("room")) == "boiler":
			_staff_room.walk_to("lounge")
			get_viewport().set_input_as_handled()
			return
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
	if _current_profile == "staff" and _staff_room != null and _staff_room.click():
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
	var station := _meta_up(collider, "bistro_station")
	if station != "":
		_open_station(station)
		return true
	var seen := _meta_up(collider, "bistro_look")
	if seen != "":
		if _sentence != null:
			_sentence.say(seen)
		return true
	if _node_has_click_type(collider, "window_curtain"):
		var wp = _meta_up_object(collider, "window_portal")
		if wp != null:
			wp.toggle_curtain()
			_send_curtains()
		return true
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
	for t in ["service_light_switch", "service_counter_game", "service_ledger", "service_stock", "sewer_enter", "sewer_terminal", "bistro_station", "bistro_look", "window_curtain"]:
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
		_ledger.connect("want_zreport", func(key: String) -> void:
			var site: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {})
			if not (site.get("zreport", {}) as Dictionary).is_empty():
				_ledger.call("close_view")
				_open_zreport(key, site["zreport"]))
	var btype: String = {"pub": "pub", "rest": "restaurant", "vecerka": "vecerka"}.get(_current_profile, "")
	if btype == "":
		return
	_ledger.open_for(_upkeep_key, btype)


## The night inside a place open late (scripts/business/late_night.gd): made while you are
## in one on its late shift.
const LATE_NIGHT = preload("res://scripts/business/late_night.gd")
var _late_night: Node
var _late_check := 0.0
var _late_base: Array = []


func _update_late_night(delta: float) -> void:
	_late_check -= delta
	if _late_check > 0.0:
		return
	_late_check = 1.0
	var late := false
	if _current_profile in ["rest", "pub", "vecerka"]:
		var BUSINESS := load("res://scripts/business/business_runtime.gd")
		late = BUSINESS.shift_now(_business_site()) == "late"
	if late and (_late_night == null or not is_instance_valid(_late_night)):
		_late_night = LATE_NIGHT.new()
		_late_night.name = "LateNight"
		_late_night.tension_of = func() -> float:
			var d = get_tree().current_scene.get("_director") if get_tree().current_scene != null else null
			return float(d.tension) if d != null else 0.3
		_late_night.dim = _late_dim
		_late_night.room_of = func() -> Node3D: return _late_room()
		_late_night.seats_of = func() -> Array: return _late_seats()
		_late_night.camera_of = func() -> Camera3D: return _interior_camera
		_late_night.front_room = func() -> bool: return (_current_profile == "rest" and _restaurant_room == "dining") or (_current_profile == "pub" and _pub_room == "main") or _current_profile == "vecerka"
		add_child(_late_night)
	elif not late and _late_night != null and is_instance_valid(_late_night):
		_late_night.queue_free()
		_late_night = null


## The room you are in now (the figure sits in it).
func _late_room() -> Node3D:
	match _current_profile:
		"rest":
			return {"dining": _restaurant_dining_root, "kitchen": _restaurant_kitchen_root, "basement": _restaurant_basement_root}.get(_restaurant_room, null)
		"pub":
			return _pub_main_root if _pub_room == "main" else _pub_cellar_root
		"vecerka":
			return _vecerka_shop_root
	return null


## Seats in the front room nobody is in, the far ones first: [[position, face], ...].
func _late_seats() -> Array:
	var out: Array = []
	if _life == null or not is_instance_valid(_life):
		return out
	var seats: Array = _life.get("seats")
	var cam := _interior_camera.global_position if _interior_camera != null else Vector3.ZERO
	var root := _late_room()
	for st in seats:
		if bool((st as Dictionary).get("stand", false)):
			continue
		var p: Vector3 = st["pos"]
		if root != null and (root.global_transform * p).distance_to(cam) < 2.0:
			continue
		out.append([p, Vector3.ZERO])
	return out


## The room's light at `level` (0 dark, 1 as it was): the main light, the ambient, the
## tubes' glow; what it was is kept and put back at 1.
func _late_dim(level: float) -> void:
	if _main_light == null:
		return
	if _late_base.is_empty():
		if level >= 1.0:
			return
		_late_base = [_main_light.light_energy, _room_env.ambient_light_energy if _room_env != null else 0.0]
	_main_light.light_energy = float(_late_base[0]) * level
	if _room_env != null:
		_room_env.ambient_light_energy = float(_late_base[1]) * (0.2 + 0.8 * level)
	var room := _late_room()
	if room != null:
		for t in room.find_children("Tube*", "MeshInstance3D", false, false):
			var m := (t as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				m.emission_energy_multiplier = 1.2 * level
	if level >= 1.0:
		_late_base = []


## The shift's Z report off the till (scripts/business/zreport_closeup.gd): out of the
## till when the place shuts while you are in it, or from the books.
const ZREPORT := preload("res://scripts/business/zreport_closeup.gd")
var _zreport: CanvasLayer
var _zreport_hooked := false


func _open_zreport(key: String, z: Dictionary) -> void:
	if _zreport == null:
		_zreport = ZREPORT.new()
		_zreport.name = "ZReport"
		add_child(_zreport)
	_zreport.call("open_report", key, z)


func _hook_zreport() -> void:
	if _zreport_hooked:
		return
	var biz := get_tree().get_first_node_in_group("businesses")
	if biz == null or not biz.has_signal("zreport"):
		return
	_zreport_hooked = true
	biz.connect("zreport", func(key: String, z: Dictionary) -> void:
		if _is_open and key == _upkeep_key and _current_profile in ["rest", "pub", "vecerka"]:
			_open_zreport(key, z))


## Where a counter close-up's click box stands, by profile: [centre, size] in the front
## room (none now: every place's work is a station in its room).
const COUNTER_GAME_SPOTS := {}


## A body over the counter thing, clicked to open its minigame; nothing to see, the model
## is the thing.
func _build_counter_game(profile: String) -> void:
	var spot: Array = COUNTER_GAME_SPOTS.get(profile, [])
	var parent: Node3D = {"pub": _pub_main_root, "rest": _restaurant_dining_root, "vecerka": _vecerka_shop_root}.get(profile)
	if spot.is_empty() or parent == null:
		return
	var body := StaticBody3D.new()
	body.name = "CounterGameSpot"
	body.position = spot[0]
	body.set_meta("interior_click_type", "service_counter_game")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = spot[1]
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
	elif profile == "staff":
		switch_pos = Vector3(STAFF_PLAN.DOOR_X - 0.68, STAFF_PLAN.FLOOR + 1.25, STAFF_PLAN.L_MAX.y - 0.04)
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
	_gear_sig = ""
	_pub_gear_sig = "-"
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
	_free_windows()
	_doors.host = self
	_dirty_shown = -1
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
		PUB_LAYOUT.bar(_pub_main_root, self)
		_pub_cellar_root = Node3D.new()
		_pub_cellar_root.name = "PubCellar"
		_room_root.add_child(_pub_cellar_root)
		PUB_LAYOUT.cellar(_pub_cellar_root, self)
		_set_pub_room("main", true)
	elif profile == "vecerka":
		_vecerka_shop_root = Node3D.new()
		_vecerka_shop_root.name = "VecerkaShop"
		_room_root.add_child(_vecerka_shop_root)
		_vecerka_storage_root = Node3D.new()
		_vecerka_storage_root.name = "VecerkaStorage"
		_room_root.add_child(_vecerka_storage_root)
		
		JEDNOTA_LAYOUT.shop(_vecerka_shop_root, self)
		JEDNOTA_LAYOUT.store(_vecerka_storage_root, self)
		_set_vecerka_room("shop", true)
	elif profile == "staff":
		_staff_room = STAFFROOM.new()
		_staff_room.build(self, _room_root)
		_staff_room.set_room("lounge", _interior_camera)
		_active_subroom = "lounge"
		_main_light.position = Vector3(-1.2, STAFF_PLAN.FLOOR + STAFF_PLAN.L_H - 0.3, 0.0)
		var bl := OmniLight3D.new()
		bl.name = "BoilerBulb"
		bl.light_color = Color(1.0, 0.84, 0.62)
		bl.light_energy = 0.9
		bl.omni_range = 4.0
		bl.shadow_enabled = true
		bl.position = Vector3(2.5, STAFF_PLAN.FLOOR + STAFF_PLAN.B_H - 0.45, 0.0)
		_room_root.add_child(bl)
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
	_make_windows(profile)
	if profile == "rest":
		# Every click box is built now: the hidden rooms' ones off.
		for r in [_restaurant_dining_root, _restaurant_kitchen_root, _restaurant_basement_root]:
			_bodies_live(r, r.visible)
	elif profile == "pub" and _pub_main_root != null and _pub_cellar_root != null:
		_bodies_live(_pub_main_root, _pub_main_root.visible)
		_bodies_live(_pub_cellar_root, _pub_cellar_root.visible)
	elif profile == "vecerka" and _vecerka_shop_root != null and _vecerka_storage_root != null:
		_bodies_live(_vecerka_shop_root, _vecerka_shop_root.visible)
		_bodies_live(_vecerka_storage_root, _vecerka_storage_root.visible)

	_cam_base_rot = _interior_camera.rotation
	_apply_time_profile()
	_update_sewer_ambience_state()


func _build_restaurant_dining_layout(parent: Node3D) -> void:
	BISTRO_LAYOUT.dining(parent, self)


func _build_restaurant_kitchen_layout(parent: Node3D) -> void:
	BISTRO_LAYOUT.kitchen(parent, self)


func _build_restaurant_basement_layout(parent: Node3D) -> void:
	BISTRO_LAYOUT.cellar(parent, self)


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
	# The three rooms stand in the same place: the hidden ones' click boxes must not catch
	# the pointer (physics ignores visibility).
	for r in [_restaurant_dining_root, _restaurant_kitchen_root, _restaurant_basement_root]:
		_bodies_live(r, r.visible)
	if _restaurant_room == "basement":
		_fill_cellar()
	elif _restaurant_room == "dining":
		_update_menu_board()
	if _room_env != null:
		# The cellar has only its bulb: the room's own light down there is low.
		_apply_time_profile()
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


## Which of the pub's rooms you are in: the bar, or the cellar under it (its kegs).
func _set_pub_room(room: String, update_camera: bool = true) -> void:
	if _pub_main_root == null or _pub_cellar_root == null:
		return
	_pub_room = "cellar" if room == "cellar" else "main"
	_active_subroom = _pub_room
	_pub_main_root.visible = _pub_room == "main"
	_pub_cellar_root.visible = _pub_room == "cellar"
	_bodies_live(_pub_main_root, _pub_main_root.visible)
	_bodies_live(_pub_cellar_root, _pub_cellar_root.visible)
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


## The doors between the rooms (business_doors.gd), in the walls the layouts left free.
func _build_business_doors(profile: String) -> void:
	match profile:
		"rest":
			_doors.add("d_kitchen", "dining", _restaurant_dining_root, Vector3(1.6, 0.05, -2.4), Vector3(0, 0, 1), "kitchen", "k_dining")
			_doors.add("k_dining", "kitchen", _restaurant_kitchen_root, Vector3(-3.1, 0.05, 1.45), Vector3(1, 0, 0), "dining", "d_kitchen")
			_doors.add("k_cellar", "kitchen", _restaurant_kitchen_root, Vector3(3.1, 0.05, 1.45), Vector3(-1, 0, 0), "basement", "c_kitchen")
			_doors.add("c_kitchen", "basement", _restaurant_basement_root, Vector3(3.1, 0.05, 1.3), Vector3(-1, 0, 0), "kitchen", "k_cellar")
			_build_stock_spot(_restaurant_basement_root, Vector3(-1.4, 0.8, -1.95), Vector3(2.0, 1.5, 0.8))
			_build_bistro_stations()
		"pub":
			_doors.add("p_cellar", "main", _pub_main_root, Vector3(2.9, 0.05, 0.3), Vector3(-1, 0, 0), "cellar", "pc_main")
			_doors.add("pc_main", "cellar", _pub_cellar_root, Vector3(2.9, 0.05, 0.9), Vector3(-1, 0, 0), "main", "p_cellar")
			_build_stock_spot(_pub_cellar_root, Vector3(0.7, 0.6, -1.85), Vector3(2.4, 1.2, 0.8))
			_ensure_sentence()
		"vecerka":
			_doors.add("s_store", "shop", _vecerka_shop_root, Vector3(1.9, 0.05, -2.6), Vector3(0, 0, 1), "storage", "st_shop")
			_doors.add("st_shop", "storage", _vecerka_storage_root, Vector3(2.4, 0.05, 0.85), Vector3(-1, 0, 0), "shop", "s_store")
			_build_stock_spot(_vecerka_storage_root, Vector3(-2.0, 0.8, 0.7), Vector3(0.6, 1.6, 1.8))
			_ensure_sentence()


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
	# Through a door from a station (a tool's walk): the station goes, the frame with it.
	var open := _station_open()
	if open != "":
		_switching = true
		_stations[open].call("close_station")
		_switching = false
		_station_cam_from = []
		if _station_hud != null and is_instance_valid(_station_hud):
			_station_hud.visible = false
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
## pub's full kegs (besides the one on the line), its crates of rum and kofola; the bistro's sacks of
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
		# The full kegs besides the one on the line (taproom.spares), along the rack.
		var tr = TAPROOM.of(get_tree())
		var kegs := clampi(int(tr.spares(_upkeep_key)) if tr != null and _upkeep_key != "" else int(ceil(float(stock.get("beer", 0)) / 50.0)), 0, 6)
		for i in kegs:
			_keg(stock_root, Vector3(-0.3 + float(i % 6) * 0.4, 0.17, -1.9))
		var crates := clampi(int(ceil(float(int(stock.get("rum", 0)) + int(stock.get("kofola", 0))) / 12.0)), 0, 5)
		for i in crates:
			K.cutout(stock_root, "beer_crate_full", Vector2(0.55, 0.42), Vector3(1.9, 0.05 + float(i % 3) * 0.36, -1.0 + float(i / 3) * 0.6), -90.0, true, "Crate")
	else:
		# Under the shelf at the back: the sacks of potatoes, the bread crates of
		# dumplings, the boxes of cheese and goulash tins.
		var sacks := clampi(int(ceil(float(stock.get("potatoes", 0)) / 10.0)), 0, 5)
		for i in sacks:
			_flat(stock_root, "res://assets/textury/town/sack_potatoes.png", Vector2(0.5, 0.62), Vector3(-2.75 + float(i % 3) * 0.42, 0.05, -2.15 + float(i / 3) * 0.3))
		var breads := clampi(int(ceil(float(stock.get("dumplings", 0)) / 10.0)), 0, 3)
		for i in breads:
			_flat(stock_root, "res://assets/textury/town/crates_bread.png", Vector2(0.6, 0.45), Vector3(-1.45, 0.05 + float(i) * 0.4, -2.15))
		var boxes := clampi(int(ceil(float(int(stock.get("cheese", 0)) + int(stock.get("goulash", 0))) / 12.0)), 0, 4)
		for i in boxes:
			K.prop(stock_root, "cardboard_boxes", Vector3(-0.8 + float(i % 2) * 0.45, 0.05 + float(i / 2) * 0.4, -2.1), 10.0 * float(i))
	_off_sprites(stock_root, "pub" if _current_profile == "pub" else "rest", Vector3(-2.3, 0.05, -1.55) if _current_profile != "pub" else Vector3(-1.6, 0.05, -1.4), Vector3(0.45, 0, 0))


func _business_site() -> Dictionary:
	var BUSINESS := load("res://scripts/business/business_runtime.gd")
	return BUSINESS.site(_upkeep_key)


## The bistro's menu board: what the cellar cannot make today crossed out in chalk.
func _update_menu_board() -> void:
	if _restaurant_dining_root == null:
		return
	var site := _business_site()
	if site.is_empty():
		return
	var can: Dictionary = load("res://core/systems/business_rules.gd").menu("rest", site.get("stock", {}))
	for dish in can:
		# Off the books' menu: crossed out in chalk the same.
		can[dish] = bool(can[dish]) and BIZ_RULES.menu_on("rest", site, str(dish))
		var strike := _restaurant_dining_root.get_node_or_null("MenuStrike_" + str(dish)) as Node3D
		if strike != null:
			strike.visible = not bool(can[dish])
		var line := _restaurant_dining_root.get_node_or_null("MenuLine_" + str(dish)) as Label3D
		if line != null:
			line.modulate = Color(0.92, 0.92, 0.86, 0.95) if bool(can[dish]) else Color(0.62, 0.62, 0.58, 0.8)


## What has gone off on the cellar's shelves, there till it is thrown out (the books'
## THROW OUT): mouldy, sprouting, bloated (assets/textury/camp/off_*.png).
const OFF_SPRITES := {
	"rest": {"potatoes": ["off_potatoes", 0.62], "cheese": ["off_cheese", 0.18], "dumplings": ["off_dumplings", 0.18]},
	"pub": {"beer": ["off_keg", 0.6], "kofola": ["off_milk", 0.26]},
	"vecerka": {"bread": ["off_bread", 0.22], "roll": ["off_rolls", 0.2], "milk": ["off_milk", 0.26], "salami": ["off_salami", 0.28], "veg": ["off_potatoes", 0.4]},
	"corn": {"cobs": ["off_cob", 0.2], "butter": ["off_cheese", 0.14]},
}


func _off_sprites(parent: Node3D, kind: String, first: Vector3, step: Vector3) -> void:
	var site := _business_site()
	var i := 0
	for g in (site.get("spoiled", {}) as Dictionary):
		if int(site["spoiled"][g]) <= 0 or not (OFF_SPRITES.get(kind, {}) as Dictionary).has(g):
			continue
		var d: Array = OFF_SPRITES[kind][g]
		var path := "res://assets/textury/camp/%s.png" % str(d[0])
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite3D.new()
		s.name = "Off_" + str(g)
		s.texture = STATION3D.room_tex(path, float(d[1]))
		s.pixel_size = 1.0 / STATION3D.PX_PER_M
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		if s.texture != null:
			s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
		s.position = first + step * float(i)
		parent.add_child(s)
		i += 1


## A full keg standing in the cellar: the keg's sprite (assets/textury/pub/keg.png, the
## one on the pallet at the keg's station), at the room's pixel.
func _keg(parent: Node3D, at: Vector3) -> void:
	var path := "res://assets/textury/pub/keg.png"
	if not ResourceLoader.exists(path):
		return
	var s := Sprite3D.new()
	s.name = "Keg"
	s.texture = STATION3D.room_tex(path, 0.6)
	s.pixel_size = 0.6 / float(maxi(1, s.texture.get_height())) if s.texture != null else 0.01
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	if s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	s.position = at
	parent.add_child(s)


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


## A lamp on its chain over a table, its brown glass shade a sprite, warm light.
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


func _set_vecerka_room(room: String, update_camera: bool = true) -> void:
	if _vecerka_shop_root == null or _vecerka_storage_root == null:
		return
	_active_subroom = "storage" if room == "storage" else "shop"
	_vecerka_shop_root.visible = _active_subroom == "shop"
	_vecerka_storage_root.visible = _active_subroom == "storage"
	_bodies_live(_vecerka_shop_root, _vecerka_shop_root.visible)
	_bodies_live(_vecerka_storage_root, _vecerka_storage_root.visible)
	if update_camera and _interior_camera != null:
		# Just inside the door (jednota_layout: the shop 5.2 m deep, the storeroom 4).
		if _active_subroom == "storage":
			_interior_camera.position = Vector3(0.0, 1.5, 1.62)
			_interior_camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
		else:
			_interior_camera.position = Vector3(0.0, 1.5, 2.2)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
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
		"staff":
			# The doorway is clicked (point and click), no tabs.
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
		# Only this stall is there; the other one is another room.
		for side in _toilet_stalls:
			var stall: Node3D = _toilet_stalls[side]
			if is_instance_valid(stall):
				stall.visible = str(side) == ("right" if room == "right" else "left")
				_bodies_live(stall, stall.visible)
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
	# Each stall is a room of its own (playtest 20. 10.: "I can clean the other toilet
	# through the wall"): its things and its mess under its own root, only the stall you
	# came in by shown (_set_hygiene_room); the other one is not there to see or reach.
	_toilet_stalls.clear()
	for side: float in [-1.0, 1.0]:
		var cx := side * TOILET_STALL_X
		var stall := Node3D.new()
		stall.name = "StallLeft" if side < 0.0 else "StallRight"
		_room_root.add_child(stall)
		_toilet_stalls["left" if side < 0.0 else "right"] = stall
		r = stall
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
	_sign(_toilet_stalls["left"], "ZENY", Vector3(-TOILET_STALL_X, 2.0, -d * 0.5 + 0.03), 18, "enamel")
	_sign(_toilet_stalls["right"], "MUZI", Vector3(TOILET_STALL_X, 2.0, -d * 0.5 + 0.03), 18, "enamel")
	_interior_camera.position = Vector3(-TOILET_STALL_X, 1.55, d * 0.5 - 0.12)
	_interior_camera.rotation_degrees = Vector3(-30.0, 0.0, 0.0)


const TOILET_W := 2.9
const TOILET_D := 2.1
const TOILET_STALL_X := 0.72
## The toilet block's stalls, each a room of its own: "left" / "right" -> its root.
var _toilet_stalls: Dictionary = {}


## The root of a toilet stall ("left" / "right"; the room when there is none).
func _toilet_stall(side: String) -> Node3D:
	var n = _toilet_stalls.get(side, null)
	return n if n != null and is_instance_valid(n) else _room_root


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
	K.slab(_room_root, Vector3(0.62, 0.05, d - 0.3), Vector3(0.0, 0.03, 0.0), K.surface(_sewer_tex("sewer_water", "sewer_floor"), 1.4, Color(0.62, 0.66, 0.52)), "SewerChannel")
	# The pipe mouth in the back wall, low: the way in.
	var mouth_path := INTERIOR_KIT.TEX + "sewer_mouth.png"
	var mouth: MeshInstance3D = null
	if ResourceLoader.exists(mouth_path):
		mouth = K.picture(_room_root, "sewer_mouth", Vector2(2.1, 2.1), Vector3(0.0, 1.05, -d * 0.5 + 0.02), 0.0, "PipeMouth")
	else:
		mouth = K.slab(_room_root, Vector3(1.2, 1.2, 0.04), Vector3(0.0, 0.62, -d * 0.5 + 0.03), K.surface("concrete", 1.0, Color(0.1, 0.1, 0.1)), "PipeMouth")
	# The hole is left of the picture's middle (Grok, camp/sewer_mouth.png).
	var enter := _click_box(_room_root, "sewer_enter", Vector3(-0.32, 1.05, -d * 0.5 + 0.15), Vector3(1.1, 1.1, 0.3))
	# Hovered, the rim of the mouth glints (not the whole picture, wall and all).
	if mouth != null:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.34
		ring.outer_radius = 0.46
		ring.rings = 16
		ring.ring_segments = 6
		enter.set_meta("glint_meshes", [_glint_shape(mouth, ring, Vector3(-0.33, 0.0, 0.02), Vector3(90.0, 0.0, 0.0))])
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
		var glass := QuadMesh.new()
		glass.size = Vector2(0.68, 0.51)
		var tbox := _click_box(_room_root, "sewer_terminal", term_at + Vector3(0, 0.85, 0.1), Vector3(1.2, 1.0, 0.6), -35.0)
		# Hovered, its screen glints.
		tbox.set_meta("glint_meshes", [_glint_shape(t, glass, Vector3(-0.26, 0.375, 0.02), Vector3.ZERO)])
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
	var rust := K.surface("galvanized", 1.4, Color(0.55, 0.36, 0.24))
	for z: float in [-2.2, -1.5, 1.6]:
		_pipe_run(_room_root, Vector3(-w * 0.5, h - 0.25 - absf(z) * 0.03, z), Vector3(w * 0.5, h - 0.25 - absf(z) * 0.03, z), 0.09 if z < 0.0 else 0.06, rust)
	for c: Vector3 in [Vector3(-w * 0.5 + 0.18, 0.0, -d * 0.5 + 0.18), Vector3(w * 0.5 - 0.18, 0.0, -d * 0.5 + 0.18)]:
		_pipe_run(_room_root, c, c + Vector3(0, h, 0), 0.12, rust)
	# The ladder up behind you, the daylight (or the night) through the hatch over it.
	var steel := K.surface("galvanized", 1.4, Color(0.5, 0.48, 0.44))
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
## An unseen shape on a picture that glints when its thing is hovered (the hover glint
## goes over the meshes it is given: a whole picture would glint wall and all).
func _glint_shape(on: Node3D, mesh: Mesh, at: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.rotation_degrees = rot_deg
	on.add_child(mi)
	return mi


func _click_box(root: Node3D, kind: String, at: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
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
	return body


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
		# Each stall's mess in its own stall (only the one you are in is there).
		var bz := -TOILET_D * 0.5 + 0.32 + 0.06
		var sl := _toilet_stall("left")
		var sr := _toilet_stall("right")
		_upkeep_prep.add_spot("bowl_l", sl, Vector3(-TOILET_STALL_X, 0.43, bz))
		_upkeep_prep.add_spot("bowl_r", sr, Vector3(TOILET_STALL_X, 0.43, bz))
		_upkeep_prep.add_spot("stall_l", sl, Vector3(-TOILET_STALL_X - 0.3, 0.01, -0.35))
		_upkeep_prep.add_spot("stall_r", sr, Vector3(TOILET_STALL_X + 0.3, 0.01, -0.35))
		_upkeep_prep.add_spot("wall_l", sl, Vector3(-TOILET_W * 0.5 + 0.02, 1.3, -0.1), PI * 0.5, true)
		_upkeep_prep.add_spot("wall_r", sr, Vector3(TOILET_W * 0.5 - 0.02, 1.3, -0.1), -PI * 0.5, true)
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
	# In through the door you are in the room, the place round you; a click on the bar (a
	# station) steps up to it (playtest 25. 10.: "entering the pub I do not see the room,
	# I am straight behind the bar"; it was straight to work, the brief of 21. 10.).
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
	var tasks: Array = _grouped_block_tasks(entry.get("tasks", []))
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


## A block's tasks by the part they are in (MESS_RULES.BLOCK_SPOTS: _l the left one, _r
## the right one), each with its heading, in that order: the checklist puts them under it.
func _grouped_block_tasks(tasks: Array) -> Array:
	var out: Array = []
	var order := ["_l", "_r", ""]
	for side in order:
		for t in tasks:
			var spot := str((t as Dictionary).get("spot", ""))
			var s := "_l" if spot.ends_with("_l") else ("_r" if spot.ends_with("_r") else "")
			if s != side:
				continue
			var d: Dictionary = (t as Dictionary).duplicate()
			var n := 1 if s == "_l" else 2
			if _upkeep_type == "toilet_block":
				d["group"] = tr("CUBICLE %d") % n if s != "" else tr("THE REST")
			else:
				d["group"] = tr("SHOWER %d") % n if s != "" else tr("THE REST")
			out.append(d)
	return out


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
	if _crew != null and is_instance_valid(_crew):
		_crew.clear()
		_crew.queue_free()
	_crew = null
	if _bistro_marks != null and is_instance_valid(_bistro_marks):
		_bistro_marks.queue_free()
	_bistro_marks = null
	if _pub_marks != null and is_instance_valid(_pub_marks):
		_pub_marks.queue_free()
	_pub_marks = null
	if _marks != null and is_instance_valid(_marks):
		_marks.clear()
		_marks.queue_free()
	_marks = null


## The hands at their jobs in the rooms (scripts/business/crew_figures.gd).
const CREW_FIGURES = preload("res://scripts/business/crew_figures.gd")
var _crew: Node3D
## Which station each of the bistro's jobs is worked at, and where the hand steps back to
## when a warden takes it (behind the warden, out of the camera's way).
const BISTRO_ROLE_AT := {"pass": "pass", "floor": "floor", "stove": "stove", "cellar": "potatoes", "sink": "sink", "grill": "grill", "bufet": "bufet"}
const BISTRO_ASIDE := {"pass": Vector3(1.4, 0, 0.6), "floor": Vector3(-0.8, 0, 1.2), "stove": Vector3(0.3, 0, 1.4), "potatoes": Vector3(1.3, 0, 0.9), "sink": Vector3(-1.4, 0, 0.7), "grill": Vector3(1.1, 0, 0.4), "bufet": Vector3(-0.6, 0, 0.5)}
## The pub's: behind the bar along the narrow way between the bar and the shelf (the
## tap's hand stands in front of the bottles: out of the way when you turn to them),
## the cellar's by the pallet.
const PUB_ROLE_AT := {"tap": "tap", "bar": "back", "wash": "wash", "cellar": "keg"}
const PUB_ASIDE := {"tap": Vector3(0.6, 0, 0), "back": Vector3(-0.6, 0, 0), "wash": Vector3(-0.45, 0, -0.1), "keg": Vector3(0.9, 0, 0.6)}
const PUB_CLEAR_OF := {"tap": ["back"]}
## The Jednota's: behind the till, in front of the rack, at the packing table; aside out
## of the station's camera.
const JEDNOTA_ROLE_AT := {"till": "till", "shelves": "shelves", "store": "store", "deli": "deli"}
const JEDNOTA_ASIDE := {"till": Vector3(0.0, 0, -1.1), "shelves": Vector3(-1.5, 0, 0.6), "store": Vector3(1.2, 0, 0.5), "deli": Vector3(0.0, 0, 0.7)}


func _start_crew() -> void:
	if _crew != null and is_instance_valid(_crew):
		_crew.clear()
		_crew.queue_free()
	_crew = CREW_FIGURES.new()
	_crew.name = "CrewFigures"
	_crew.key = _upkeep_key
	var spots := {}
	match _current_profile:
		"rest":
			for role in BISTRO_ROLE_AT:
				var st_id: String = BISTRO_ROLE_AT[role]
				var st: Dictionary = BISTRO_LAYOUT.STATIONS[st_id]
				var root: Node3D = _bistro_root(str(st["room"]))
				if root != null:
					spots[role] = {"root": root, "pos": st["stand"], "station": st_id, "aside": BISTRO_ASIDE.get(st_id, Vector3(0.8, 0, 0.8)), "note": (st["mark"] as Vector3) - Vector3(0, 0.45, 0)}
			_crew.busy_of = func() -> Array: return [_station_open()] + _bistro_taken().keys()
		"pub":
			for role in PUB_ROLE_AT:
				var pst_id: String = PUB_ROLE_AT[role]
				var pst: Dictionary = PUB_LAYOUT.STATIONS[pst_id]
				var proot: Node3D = _pub_cellar_root if str(pst["room"]) == "cellar" else _pub_main_root
				if proot != null:
					spots[role] = {"root": proot, "pos": pst["stand"], "station": pst_id, "aside": PUB_ASIDE.get(pst_id, Vector3(0.6, 0, 0)), "clear_of": PUB_CLEAR_OF.get(pst_id, []), "note": (pst["mark"] as Vector3) - Vector3(0, 0.45, 0)}
			_crew.busy_of = func() -> Array: return [_station_open()] + _bistro_taken().keys()
			_crew.open_of = func() -> String: return _station_open()
		"vecerka":
			for role in JEDNOTA_ROLE_AT:
				var jst_id: String = JEDNOTA_ROLE_AT[role]
				var jst: Dictionary = JEDNOTA_LAYOUT.STATIONS[jst_id]
				var jroot: Node3D = _station_root(str(jst["room"]))
				if jroot != null:
					spots[role] = {"root": jroot, "pos": jst["stand"], "station": jst_id, "aside": JEDNOTA_ASIDE.get(jst_id, Vector3(0.6, 0, 0.6)), "note": (jst["mark"] as Vector3) - Vector3(0, 0.45, 0)}
			# The second till's hand at their own counter by the door (gear).
			if _vecerka_shop_root != null:
				spots["till2"] = {"root": _vecerka_shop_root, "pos": JEDNOTA_LAYOUT.TILL2_STAND, "station": ""}
			_crew.busy_of = func() -> Array: return [_station_open()] + _bistro_taken().keys()
			_crew.open_of = func() -> String: return _station_open()
	_crew.spots = spots
	add_child(_crew)
	_crew.refresh()


## The marks over the places where work waits, for this pub, bistro or Jednota.
func _start_marks() -> void:
	var roots := {}
	match _current_profile:
		"pub":
			_start_pub_marks()
			_start_crew()
			return
		"rest":
			_start_bistro_marks()
			_start_crew()
			return
		"vecerka":
			_start_jednota()
			roots = {"shop": _vecerka_shop_root, "store": _vecerka_storage_root}
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
	if _current_profile == "vecerka":
		_start_crew()


# -- the bistro: its stations, its marks, the sentence ------------------------------

## The click boxes of the bistro's stations in their rooms (bistro_layout.STATIONS).
func _build_bistro_stations() -> void:
	for id in BISTRO_LAYOUT.STATIONS:
		var room := str(BISTRO_LAYOUT.STATIONS[id]["room"])
		var parent: Node3D = _bistro_root(room)
		if parent != null:
			BISTRO_LAYOUT.station_body(parent, str(id))
	_ensure_sentence()


## The line under the room (what the pointer is on, what was said).
func _ensure_sentence() -> void:
	if _sentence == null:
		_sentence = ROOM_SENTENCE.new()
		_sentence.name = "RoomSentence"
		add_child(_sentence)


## The stations of the building you are in: their layout (STATIONS, SURFACES), their
## scripts, the room a station is in.
func _station_layout():
	match _current_profile:
		"pub":
			return PUB_LAYOUT
		"vecerka":
			return JEDNOTA_LAYOUT
	return BISTRO_LAYOUT


func _station_scripts() -> Dictionary:
	match _current_profile:
		"pub":
			return PUB_STATIONS
		"vecerka":
			return JEDNOTA_STATIONS
	return BISTRO_STATIONS


func _station_root(room: String) -> Node3D:
	if _current_profile == "pub":
		return _pub_cellar_root if room == "cellar" else _pub_main_root
	if _current_profile == "vecerka":
		return _vecerka_storage_root if room == "store" else _vecerka_shop_root
	return _bistro_root(room)


## The bistro's room by its name: the kitchen, the cellar, the dining room.
func _bistro_root(room: String) -> Node3D:
	match room:
		"kitchen":
			return _restaurant_kitchen_root
		"dining":
			return _restaurant_dining_root
	return _restaurant_basement_root


## The station open now ("" none).
func _station_open() -> String:
	for id in _stations:
		var v = _stations[id]
		if is_instance_valid(v) and bool(v.call("is_open")):
			return str(id)
	return ""


## The frame under the room at a station (scripts/business/station_hud.gd), one for the
## building.
func _hud() -> CanvasLayer:
	if _station_hud == null or not is_instance_valid(_station_hud):
		_station_hud = STATION_HUD.new()
		_station_hud.name = "StationHud"
		add_child(_station_hud)
		_station_hud.mirror_of = func() -> Array:
			var open := _station_open()
			if open == "" or not _stations[open].has_method("mirror"):
				return []
			return _stations[open].call("mirror")
		_station_hud.alert_of = func(id: String) -> int:
			var st = _stations.get(id, null)
			return int(st.call("alert")) if st != null and is_instance_valid(st) else 0
		_station_hud.side_of = func(dir: int) -> String: return _station_beside(dir)
	return _station_hud


## A and D at a station: the next one beside it in the same room on that side, as it is
## seen from here ("" none: the bar's end; the cellar is not beside the bar).
func _station_beside(dir: int) -> String:
	var open := _station_open()
	if open == "" or _interior_camera == null or not _stations.has(open):
		return ""
	var room := str(_station_layout().STATIONS[open]["room"])
	var right := _interior_camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var here := (_stations[open] as Node3D).global_position
	var best := ""
	var best_d := INF
	for t in _room_tabs():
		var id := str(t[0])
		if id == open or not _stations.has(id) or str(_station_layout().STATIONS[id]["room"]) != room:
			continue
		var d := ((_stations[id] as Node3D).global_position - here).dot(right) * float(dir)
		if d > 0.05 and d < best_d:
			best_d = d
			best = id
	return best


## The tabs of the place's stations on the frame's bar, every room's (the brief of 21. 10.:
## the stations as tabs always in sight, a tab to another room takes you there):
## [[id, LABEL, icon], ...] in the order of the chain; what is off the books' menu has no
## tab (a station whose `menu` items are all off). `_room` is kept for the old callers.
func _room_tabs(_room: String = "") -> Array:
	var out: Array = []
	var stations: Dictionary = _station_layout().STATIONS
	var site := _business_site()
	var kind := str(site.get("kind", ""))
	for id in stations:
		var st: Dictionary = stations[id]
		if not bool(st.get("tab", true)) or not _station_scripts().has(id):
			continue
		var items: Array = st.get("menu", [])
		if not items.is_empty() and kind != "":
			var any := false
			for it in items:
				any = any or BIZ_RULES.menu_on(kind, site, str(it))
			if not any:
				continue
		out.append([str(id), str(st.get("tab_label", str(id).to_upper())), str(st.get("icon", ""))])
	return out


## The room a station stands in, as the room switches name it.
func _subroom_of(station_room: String) -> String:
	match _current_profile:
		"rest":
			return "basement" if station_room == "cellar" else station_room
		"vecerka":
			return "storage" if station_room == "store" else station_room
	return station_room


## Straight to work (the brief of 21. 10.; no longer on the way in, playtest 25. 10.):
## the station you were at last in this place, else its ENTRY (where an order starts: the
## tap, the bistro's floor, the till); never the cellar or the sink. BACK leaves the
## station for the room; S there leaves the place.
func _enter_business() -> void:
	if not (_current_profile in ["rest", "pub", "vecerka"]) or _upkeep_key == "" or not _is_open:
		return
	var tabs := _room_tabs()
	if tabs.is_empty():
		return
	var ids: Array = tabs.map(func(t) -> String: return str(t[0]))
	var consts: Dictionary = (_station_layout() as Script).get_script_constant_map()
	var first := str(consts.get("ENTRY", ids[0]))
	var last := str(STATION3D.last_station.get(_upkeep_key, first))
	var to: String = last if ids.has(last) else (first if ids.has(first) else str(ids[0]))
	_open_station(to)


## Steps up to the station `id` (unless another warden is at it): the room's camera goes
## over it in steps, the station takes the pointer.
func _open_station(id: String) -> void:
	if not _station_scripts().has(id):
		return
	var who := str(_bistro_taken().get(id, ""))
	if who != "":
		if _sentence != null:
			_sentence.say("%s is at %s." % [who, str(_station_layout().STATIONS[id]["label"])])
		return
	_make_stations()
	if not _stations.has(id):
		return
	var was := _station_open()
	if was == id:
		return
	if was != "":
		_switching = true
		_stations[was].call("close_station")
		_switching = false
	# A tab to a station in another room of the place: the room changes under a dissolve,
	# the camera starts from where you would stand in it.
	var sub := _subroom_of(str(_station_layout().STATIONS[id]["room"]))
	if sub != _door_room():
		var im := get_parent()
		if im != null and im.has_method("_door_transition"):
			im._door_transition(true)
		_apply_service_subroom(sub, true)
		_station_cam_from = [_interior_camera.transform, _interior_camera.rotation]
		was = ""
	if was == "" and _station_cam_from.is_empty():
		_station_cam_from = [_interior_camera.transform, _interior_camera.rotation]
	var st: Node3D = _stations[id]
	if _station_tween != null and _station_tween.is_valid():
		_station_tween.kill()
	_station_tween = STATION3D.step_camera(self, _interior_camera, st.call("cam_pose"), STATION3D.CAM_SEC if was == "" else 0.34)
	var hud := _hud()
	st.set("hud", hud)
	st.call("open_station", _interior_camera)
	hud.set("station", st)
	hud.set("tabs", _room_tabs())
	hud.set("taken", _bistro_taken())
	hud.set("view_size", Vector2(_viewport.size))
	hud.call("clear_say")
	hud.visible = true
	_hot_glint.clear()
	_hot_glint_on = null
	if _sentence != null:
		_sentence.clear()
		_sentence.visible = false
	if _bistro_marks != null and is_instance_valid(_bistro_marks):
		_bistro_marks.visible = false
	if _pub_marks != null and is_instance_valid(_pub_marks):
		_pub_marks.visible = false
	if _exit_hint != null:
		_exit_hint.modulate.a = 0.0


## A tab on the frame, a number key, Tab: straight to that station of the room.
func _switch_station(id: String) -> void:
	if str(_bistro_taken().get(id, "")) != "":
		var hud := _hud()
		hud.call("say", "", "%s is at %s." % [str(_bistro_taken()[id]), str(_station_layout().STATIONS[id]["label"])])
		return
	_open_station(id)


## Stepped away from a station: the camera goes back in steps to where you stood.
func _on_station_closed() -> void:
	if _switching or _station_open() != "" or _interior_camera == null:
		return
	if _station_hud != null and is_instance_valid(_station_hud):
		_station_hud.visible = false
	if _sentence != null:
		_sentence.visible = true
	if _bistro_marks != null and is_instance_valid(_bistro_marks):
		_bistro_marks.visible = true
	if _pub_marks != null and is_instance_valid(_pub_marks):
		_pub_marks.visible = true
	if _station_cam_from.is_empty():
		return
	var back: Transform3D = _station_cam_from[0]
	var rot: Vector3 = _station_cam_from[1]
	_station_cam_from = []
	if _station_tween != null and _station_tween.is_valid():
		_station_tween.kill()
	var parent_t := _interior_camera.get_parent_node_3d().global_transform if _interior_camera.get_parent_node_3d() != null else Transform3D()
	_station_tween = STATION3D.step_camera(self, _interior_camera, parent_t * back, STATION3D.CAM_SEC)
	_station_tween.finished.connect(func():
		_interior_camera.transform = back
		_interior_camera.rotation = rot
		_cam_base_rot = rot
		_look.reset())


## Each frame at a station: the pointer through the room's camera onto it (or the frame,
## or a ticket on the rail), the finger or the fist.
func _station_frame(open: String) -> void:
	var st: Node = _stations[open]
	var moving := _station_tween != null and _station_tween.is_valid() and _station_tween.is_running()
	var mouse: Vector2 = STATION3D.mouse_of(get_viewport())
	var hud := _hud()
	_tabs_t -= get_process_delta_time()
	if _tabs_t <= 0.0:
		# The menu may have changed in the books: the tabs follow it.
		_tabs_t = 0.5
		hud.set("tabs", _room_tabs())
		hud.set("view_size", Vector2(_viewport.size))
	var ui := str(hud.call("hit", mouse))
	hud.call("set_hover", ui if ui.begins_with("#tab") or ui.begins_with("#btn") or ui in ["#back", "#serve", "#books"] else "")
	var vp_mouse := _room_px(mouse)
	var rail := ""
	if ui == "" and not moving and st.call("holding") == "":
		rail = str(st.call("rail_ticket_at", vp_mouse))
	if moving or ((ui != "" or rail != "") and st.call("holding") == ""):
		st.call("point", Vector2(-1, -1))
	else:
		st.call("point", vp_mouse)
	if str(st.call("holding")) != "":
		HandCursor.want(HandCursor.GRAB)
	elif str(st.call("hovered")) != "" or rail != "" or ui.begins_with("#tab") or ui.begins_with("#btn") or ui in ["#back", "#serve", "#books"]:
		HandCursor.want(HandCursor.POINT)


## A point of the screen in the room's picture (its viewport's pixels).
func _room_px(screen: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	if _viewport == null or size.x <= 0.0 or size.y <= 0.0:
		return Vector2(-1, -1)
	return Vector2(clampf(screen.x / size.x, 0.0, 1.0) * float(_viewport.size.x), clampf(screen.y / size.y, 0.0, 1.0) * float(_viewport.size.y))


## The keys and the mouse while you are at a station. Esc goes on to the pause menu.
func _station_input(event: InputEvent, open: String) -> void:
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	var st: Node = _stations[open]
	var hud := _hud()
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		var act := str(hud.call("key_action", ke))
		match act:
			"back":
				st.call("close_station")
			"serve":
				if bool(st.call("serve_ready")):
					st.call("serve_now")
			"books":
				_open_ledger()
			"next":
				var nx := str(hud.call("next_tab"))
				if nx != "" and nx != open:
					_switch_station(nx)
			"":
				st.call("key", ke)
			_:
				if act.begins_with("tab:") and act.substr(4) != open:
					_switch_station(act.substr(4))
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		st.call("close_station")
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mb.pressed:
		st.call("release")
		return
	hud.call("poke")
	if _station_tween != null and _station_tween.is_valid() and _station_tween.is_running():
		return
	var ui := str(hud.call("hit", mb.position))
	if ui == "#back":
		st.call("close_station")
		return
	if ui == "#serve":
		if bool(st.call("serve_ready")):
			st.call("serve_now")
		return
	if ui == "#books":
		_open_ledger()
		return
	if ui.begins_with("#tab:"):
		var to := ui.substr(5)
		if to != open:
			_switch_station(to)
		return
	if ui.begins_with("#btn:"):
		st.call("bar_button", ui.substr(5))
		return
	if ui != "":
		return
	var rail := str(st.call("rail_ticket_at", _room_px(mb.position)))
	if rail != "":
		st.call("rail_clicked", rail)
		return
	st.call("press")


## Every station of the bistro or the pub, made once the building is known: each stands
## on its counter in its room (the layout's SURFACES), its things drawn from the kitchen
## or the taproom.
func _make_stations() -> void:
	if _upkeep_key == "" or not (_current_profile in ["rest", "pub", "vecerka"]):
		return
	var layout = _station_layout()
	var scripts := _station_scripts()
	var k = get_tree().get_first_node_in_group("kitchens") if _current_profile == "rest" else (TAPROOM.of(get_tree()) if _current_profile == "pub" else JEDNOTA.of(get_tree()))
	for id in scripts:
		var st: Dictionary = layout.STATIONS[id]
		var parent: Node3D = _station_root(str(st["room"]))
		if parent == null:
			continue
		var have = _stations.get(id, null)
		if have != null and is_instance_valid(have) and (have as Node).get_parent() == parent and str(have.get("building_key")) == _upkeep_key:
			continue
		if have != null and is_instance_valid(have):
			(have as Node).queue_free()
		var path := str(scripts[id])
		if not ResourceLoader.exists(path):
			continue
		var surf: Dictionary = layout.SURFACES[id]
		var made = load(path).new()
		if not (made is Node3D):
			(made as Node).free()
			continue
		var v: Node3D = made
		v.name = "Station3D_" + str(id)
		v.set("building_key", _upkeep_key)
		v.set("station", str(id))
		v.set("room", str(st["room"]))
		v.set("label", str(st["label"]))
		v.set("surf_at", surf["at"])
		v.set("surf_size", surf["size"])
		v.set("surf_yaw", float(surf["yaw"]))
		v.set("surf_flat", bool(surf["flat"]))
		v.set("cam_back", float(surf.get("cam_back", 0.0)))
		v.set("cam_up", float(surf.get("cam_up", 0.0)))
		v.set("cam_aim", float(surf.get("cam_aim", 0.0)))
		v.set("cam_side", float(surf.get("cam_side", 0.0)))
		v.set("state", k)
		if "open_books" in v:
			v.set("open_books", _open_ledger)
		parent.add_child(v)
		v.connect("closed", _on_station_closed)
		v.connect("switch_to", _switch_station)
		_stations[id] = v
		# Its counter's top is its Build picture, at the room's pixel.
		var quad := parent.get_node_or_null("Surface_" + str(id)) as MeshInstance3D
		var tex_path := str(surf.get("tex", "res://assets/textury/bistro/st_%s.png" % str(id)))
		var pic: Texture2D = STATION3D.room_tex(tex_path, (surf["size"] as Vector2).x) if quad != null else null
		if quad != null and pic != null:
			var m := quad.material_override as StandardMaterial3D
			m.albedo_texture = pic
			m.emission_texture = pic


## Over the waiting guests' heads how their patience goes (scripts/business/guest_mood.gd:
## dots, the watch, a red scribble, a line and a grumble; the brief of 21. 10.), from the
## place's tickets, eight times a second, in the room and at a station alike.
const GUEST_MOOD = preload("res://scripts/business/guest_mood.gd")
const PUB_RULES = preload("res://core/systems/pub_rules.gd")
const BISTRO_RULES = preload("res://core/systems/bistro_rules.gd")
const JEDNOTA_RULES = preload("res://core/systems/jednota_rules.gd")
var _mood: Node3D
var _mood_t := 0.0
## Those in their impatient picture now (put back to standing when it passes).
var _waiting_pose: Dictionary = {}
const POSES = preload("res://scripts/attractions/poses.gd")


func _tick_moods(delta: float) -> void:
	_mood_t -= delta
	if _mood_t > 0.0:
		return
	_mood_t = 0.125
	if _life == null or not is_instance_valid(_life) or _upkeep_key == "":
		return
	var room := _station_root(_jednota_room_of_life() if _current_profile == "vecerka" else ("dining" if _current_profile == "rest" else "main"))
	if room == null:
		return
	if _mood == null or not is_instance_valid(_mood) or _mood.get_parent() != room:
		if _mood != null and is_instance_valid(_mood):
			_mood.queue_free()
		_mood = GUEST_MOOD.new()
		_mood.name = "GuestMood"
		room.add_child(_mood)
	var left := _patience_map()
	var people = _life.get("_people")
	if people is Dictionary:
		for k in people:
			var p: Dictionary = people[k]
			var spr = p.get("sprite", null)
			if not (spr is Sprite3D) or not is_instance_valid(spr) or not (spr as Sprite3D).is_visible_in_tree():
				continue
			var s3 := spr as Sprite3D
			var box := s3.get_aabb()
			var head: Vector3 = s3.global_transform * Vector3(box.get_center().x, box.end.y, box.get_center().z)
			var parts := str(k).split(":")
			var key := "%s:%s" % [parts[0], parts[1] if parts.size() > 1 else "0"]
			_mood.call("show_for", str(k), head, float(left.get(key, left.get(parts[0] + ":*", -1.0))))
			# In a queue on their feet (the Jednota's till): the impatient ones in their
			# impatient picture, fidgeting; back to standing when they calm down or move on.
			if int(p.get("queue", -1)) >= 0 and str(p.get("state", "")) == "seat":
				var base := str(p.get("base", ""))
				if bool(_mood.call("impatient", str(k))) and GUEST_MOOD.show_wait(s3, base):
					_waiting_pose[str(k)] = true
				elif _waiting_pose.has(str(k)):
					_waiting_pose.erase(str(k))
					POSES.set_pose(s3, base, "")
	_mood.call("sweep")


## The room the Jednota's people stand in (the shop).
func _jednota_room_of_life() -> String:
	return "shop"


## Each place's own sound under its room (the brief of 21. 10.: "the bistro's kitchen, the
## Jednota's tubes and tills"): the kitchen at work while you are in it, the shop's tubes
## buzzing low and now and then a till while somebody queues. The dining room and the pub
## murmur from their guests (service_life).
const AMB_KITCHEN := "res://assets/sfx/bistro/kitchen_room.mp3"
const AMB_TUBES := "res://assets/sfx/power/board_hum.mp3"
const AMB_TILL := "res://assets/sfx/jednota/beep.mp3"
var _amb: AudioStreamPlayer
var _amb_till := 6.0


func _tick_ambience(delta: float) -> void:
	if _amb == null:
		_amb = AudioStreamPlayer.new()
		_amb.name = "PlaceAmbience"
		add_child(_amb)
	var want := ""
	var db := -18.0
	if _current_profile == "rest" and _restaurant_room == "kitchen":
		want = AMB_KITCHEN
		db = -15.0
	elif _current_profile == "vecerka" and _active_subroom == "shop":
		want = AMB_TUBES
		db = -30.0
	if want == "" or not ResourceLoader.exists(want):
		if _amb.playing:
			_amb.stop()
	elif _amb.stream == null or _amb.stream.resource_path != want or not _amb.playing:
		var st: AudioStream = load(want)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_amb.stream = st
		_amb.volume_db = db
		_amb.play()
	if _current_profile == "vecerka" and _station_open() != "till":
		_amb_till -= delta
		if _amb_till <= 0.0:
			_amb_till = randf_range(7.0, 15.0)
			var j = JEDNOTA.of(get_tree())
			if j != null and not (j.tickets(_upkeep_key) as Array).is_empty():
				_bistro_play(AMB_TILL, -24.0)


## How much patience each waiting guest has left (0..1): "guest id:member" (the Jednota's
## queue by the guest alone, "id:*").
func _patience_map() -> Dictionary:
	var out := {}
	var tix: Array = []
	var gone := 60.0
	match _current_profile:
		"pub":
			var tr = TAPROOM.of(get_tree())
			if tr != null:
				tix = tr.tickets(_upkeep_key)
				gone = float(PUB_RULES.PATIENCE_GONE)
				for b in tr.bills(_upkeep_key):
					out["%d:*" % int(b["guest_id"])] = 1.0 - clampf(float(b.get("age", 0)) / float(PUB_RULES.BILL_WAIT), 0.0, 1.0)
		"rest":
			var k = get_tree().get_first_node_in_group("kitchens")
			if k != null:
				tix = k.tickets(_upkeep_key)
				gone = float(BISTRO_RULES.PATIENCE_GONE)
		"vecerka":
			var j = JEDNOTA.of(get_tree())
			if j != null:
				for t in j.tickets(_upkeep_key):
					out["%d:*" % int(t["guest_id"])] = 1.0 - clampf(float(t.get("age", 0)) / float(JEDNOTA_RULES.PATIENCE_GONE), 0.0, 1.0)
	for t in tix:
		var key := "%d:%d" % [int(t.get("guest_id", -1)), int(t.get("member", 0))]
		var l := 1.0 - clampf(float(t.get("age", 0)) / gone, 0.0, 1.0)
		out[key] = minf(float(out.get(key, 1.0)), l)
	return out


## The other wardens at this bistro's stations: station -> their name.
func _bistro_taken() -> Dictionary:
	var out := {}
	if not Coop.is_active():
		return out
	var im := get_parent()
	var mine: Dictionary = im.coop_room() if im != null and im.has_method("coop_room") else {}
	if mine.is_empty():
		return out
	for id in Coop.others():
		var r: Dictionary = Coop.state_of(id).get("room", {})
		if str(r.get("k", "")) != str(mine.get("k", "")) or str(r.get("t", "")) != str(mine.get("t", "")):
			continue
		var w := str(r.get("w", ""))
		if _station_layout().STATIONS.has(w):
			out[w] = Coop.name_of(id)
	return out


## Each frame in the bistro: the stations' tabs know who is where, the dirty plates
## stand by the sink as many as there are.
## The bistro's gear in its rooms: the heat lamps over the pass lit only once bought,
## the ticket clock on the wall over it.
var _gear_sig := ""


func _apply_bistro_gear() -> void:
	var site := _business_site()
	var gear: Array = site.get("gear", [])
	var sig := ",".join(gear)
	if sig == _gear_sig or _restaurant_kitchen_root == null:
		return
	_gear_sig = sig
	var lamp := gear.has("lamp")
	for n in _restaurant_kitchen_root.find_children("LampGlow*", "MeshInstance3D", false, false):
		var m := (n as MeshInstance3D).material_override as StandardMaterial3D
		if m != null:
			m.emission_enabled = lamp
			m.albedo_color = Color(0.9, 0.2, 0.1) if lamp else Color(0.22, 0.2, 0.2)
	for n in _restaurant_kitchen_root.find_children("LampLight*", "OmniLight3D", false, false):
		(n as OmniLight3D).visible = lamp
	var clock := _restaurant_kitchen_root.get_node_or_null("GearClock") as Node3D
	if clock != null:
		clock.visible = gear.has("clock")


func _bistro_tick(delta: float) -> void:
	_rat_tick(delta)
	_taken_t -= delta
	if _taken_t <= 0.0:
		_taken_t = 0.5
		_apply_bistro_gear()
		if _restaurant_room == "dining":
			_update_menu_board()
		if _station_hud != null and is_instance_valid(_station_hud) and _station_hud.visible:
			_station_hud.set("taken", _bistro_taken())
	var k = get_tree().get_first_node_in_group("kitchens")
	if k != null and _upkeep_key != "" and _taken_t == 0.5:
		# A new ticket clips onto the rail: heard in any room of the bistro.
		var now := {}
		var fresh := false
		for t in k.tickets(_upkeep_key):
			now[str(t["id"])] = true
			fresh = fresh or not _tickets_seen.has(str(t["id"]))
		if fresh and _tickets_known:
			_bistro_play("res://assets/sfx/bistro/order_in.mp3", -10.0)
		_tickets_seen = now
		_tickets_known = true
	if k != null and _restaurant_kitchen_root != null and _upkeep_key != "":
		var dirty := int(k.plates(_upkeep_key)["dirty"])
		if dirty != _dirty_shown:
			_dirty_shown = dirty
			BISTRO_LAYOUT.dirty_pile(_restaurant_kitchen_root, dirty)


## Each frame in the pub: the stations' tabs know who is where, a new order is heard in
## either room (at a station its rail rings it), the gear stands in the rooms once bought.
func _pub_tick(delta: float) -> void:
	_taken_t -= delta
	if _taken_t > 0.0:
		return
	_taken_t = 0.5
	_apply_pub_gear()
	if _station_hud != null and is_instance_valid(_station_hud) and _station_hud.visible:
		_station_hud.set("taken", _bistro_taken())
	var tr = TAPROOM.of(get_tree())
	if tr == null or _upkeep_key == "":
		return
	var now := {}
	var fresh := false
	for t in tr.tickets(_upkeep_key):
		now[str(t["id"])] = true
		fresh = fresh or not _tickets_seen.has(str(t["id"]))
	if fresh and _tickets_known and _station_open() == "":
		var ding := "res://assets/sfx/pub/order_in.mp3"
		_bistro_play(ding if ResourceLoader.exists(ding) else "res://assets/sfx/bistro/order_in.mp3", -12.0)
	_tickets_seen = now
	_tickets_known = true


## The pub's gear in its rooms once bought (business_rules.GEAR): the glass washer by the
## sink, the keg cooler in the cellar.
var _pub_gear_sig := "-"


func _apply_pub_gear() -> void:
	if _pub_main_root == null or _pub_cellar_root == null:
		return
	var gear: Array = _business_site().get("gear", [])
	var sig := ",".join(gear)
	if sig == _pub_gear_sig:
		return
	_pub_gear_sig = sig
	var gw := _pub_main_root.get_node_or_null("GearGlassWasher") as Node3D
	if gw != null:
		gw.visible = gear.has("glasswasher")
	var cooler := _pub_cellar_root.get_node_or_null("Cooler") as Node3D
	if cooler != null:
		cooler.visible = gear.has("cooler")
	var look := _pub_cellar_root.get_node_or_null("Look_cooler")
	if look != null:
		for c in look.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = not gear.has("cooler")


## The marks over the pub's rooms (scripts/pub/pub_marks.gd), its stations made.
func _start_pub_marks() -> void:
	var tr = TAPROOM.of(get_tree())
	if tr == null:
		return
	tr.site(_upkeep_key)
	_make_stations()
	_pub_gear_sig = "-"
	_apply_pub_gear()
	_pub_marks = PUB_MARKS.new()
	_pub_marks.name = "PubMarks"
	_pub_marks.taproom = tr
	_pub_marks.key = _upkeep_key
	_pub_marks.roots = {"bar": _pub_main_root, "cellar": _pub_cellar_root}
	_pub_marks.camera_of = func() -> Camera3D: return _interior_camera
	_pub_marks.viewport_of = func() -> SubViewport: return _viewport
	_pub_marks.room_of = func() -> String: return "cellar" if _pub_room == "cellar" else "bar"
	_pub_marks.life_of = func(): return _life if _life != null and is_instance_valid(_life) else null
	_pub_marks.taken_of = func() -> Dictionary: return _bistro_taken()
	add_child(_pub_marks)
	_tickets_known = false
	if _sentence != null:
		move_child(_sentence, get_child_count() - 1)


## Each frame in the Jednota: the stations' tabs know who is where, somebody new in the
## queue rings the shop's bell (at the till its rail does), the gear stands in the shop
## once bought.
func _jednota_tick(delta: float) -> void:
	_taken_t -= delta
	if _taken_t > 0.0:
		return
	_taken_t = 0.5
	_apply_jednota_gear()
	if _station_hud != null and is_instance_valid(_station_hud) and _station_hud.visible:
		_station_hud.set("taken", _bistro_taken())
	var shop = JEDNOTA.of(get_tree())
	if shop == null or _upkeep_key == "":
		return
	var now := {}
	var fresh := false
	for t in shop.tickets(_upkeep_key):
		now[str(t["id"])] = true
		fresh = fresh or not _tickets_seen.has(str(t["id"]))
	if fresh and _tickets_known and _station_open() == "":
		_bistro_play("res://assets/sfx/town/shop_bell.mp3", -14.0)
	_tickets_seen = now
	_tickets_known = true


## The Jednota's gear in its rooms once bought (business_rules.GEAR): the second till by the
## door, the chiller beside the fridge, the extra shelves by the rack, the pallet truck in
## the storeroom.
var _jednota_gear_sig := "-"


func _apply_jednota_gear() -> void:
	if _vecerka_shop_root == null:
		return
	var gear: Array = _business_site().get("gear", [])
	var sig := ",".join(gear)
	if sig == _jednota_gear_sig:
		return
	_jednota_gear_sig = sig
	var t2 := _vecerka_shop_root.get_node_or_null("GearTill2") as Node3D
	if t2 != null:
		t2.visible = gear.has("till2")
	var ch := _vecerka_shop_root.get_node_or_null("GearChiller") as Node3D
	if ch != null:
		ch.visible = gear.has("fridge")
	var rk := _vecerka_shop_root.get_node_or_null("GearRacks") as Node3D
	if rk != null:
		rk.visible = gear.has("racks")
	var pt := _vecerka_storage_root.get_node_or_null("GearPallet") as Node3D if _vecerka_storage_root != null else null
	if pt != null:
		pt.visible = gear.has("pallet")


## The Jednota's state for this shop, its stations made, its gear in the rooms.
func _start_jednota() -> void:
	var shop = JEDNOTA.of(get_tree())
	if shop == null:
		return
	shop.site(_upkeep_key)
	_make_stations()
	_jednota_gear_sig = "-"
	_apply_jednota_gear()
	_tickets_known = false


## Now and then a rat runs along the cellar's back wall, in steps, and is gone behind the
## sacks.
var _rat: Sprite3D
var _rat_t := -1.0
var _rat_wait := 20.0


func _rat_tick(delta: float) -> void:
	if _restaurant_basement_root == null or _restaurant_room != "basement" or _station_open() != "":
		if _rat != null and is_instance_valid(_rat):
			_rat.visible = false
		_rat_t = -1.0
		return
	if _rat_t < 0.0:
		_rat_wait -= delta
		if _rat_wait > 0.0:
			return
		_rat_wait = randf_range(25.0, 60.0)
		var path := "res://assets/textury/camp/bistro_rat.png"
		if not ResourceLoader.exists(path):
			return
		if _rat == null or not is_instance_valid(_rat) or _rat.get_parent() != _restaurant_basement_root:
			_rat = Sprite3D.new()
			_rat.texture = load(path)
			_rat.pixel_size = 0.16 / float(_rat.texture.get_height())
			_rat.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			_rat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			_rat.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			_rat.shaded = true
			_restaurant_basement_root.add_child(_rat)
		_rat_t = 0.0
	_rat_t += delta
	var k := clampf(_rat_t / 2.2, 0.0, 1.0)
	# Twelve steps a second, from the peeler to behind the machine.
	var stepped := floorf(k * 26.0) / 26.0
	_rat.visible = k < 1.0
	_rat.flip_h = true
	_rat.position = Vector3(lerpf(-2.3, 0.6, stepped), 0.13, -2.05)
	if k >= 1.0:
		_rat_t = -1.0


func _bistro_play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	if _bistro_sfx == null:
		_bistro_sfx = AudioStreamPlayer.new()
		add_child(_bistro_sfx)
	_bistro_sfx.stream = load(path)
	_bistro_sfx.volume_db = db
	_bistro_sfx.play()


## The sentence for what is under the pointer in the bistro.
func _bistro_sentence(collider: Node, door: String) -> String:
	if door != "":
		var to := str(_doors.doors.get(door, {}).get("to", ""))
		return {"kitchen": "Go to the kitchen", "dining": "Go to the dining room", "basement": "Go down to the cellar",
			"cellar": "Go down to the cellar", "main": "Go up to the bar", "storage": "Go into the storeroom",
			"shop": "Go into the shop"}.get(to, "Go through")
	if collider == null:
		return ""
	var station := _meta_up(collider, "bistro_station")
	if station != "" and _station_layout().STATIONS.has(station):
		var who := str(_bistro_taken().get(station, ""))
		var label := str(_station_layout().STATIONS[station]["label"])
		return ("%s is at %s" % [who, label]) if who != "" else ("Look at %s" % label if station == "machine" else "Use %s" % label)
	var name := _meta_up(collider, "bistro_name")
	if name != "":
		return "Look at the " + name
	if _node_has_click_type(collider, "service_ledger"):
		return "Open the books"
	if _node_has_click_type(collider, "service_stock"):
		return "The stock: open the books"
	if _node_has_click_type(collider, "service_light_switch"):
		return "The light switch"
	return ""


# -- windows: real views out, curtains, the Photographer's flash -----------------------

## The rooms' windows (scripts/ui/window_portal.gd): [{w, root}]. The layouts paint a
## "window_view" picture where a window is; it is made a real one here (its glass a view
## of the camp from where the building stands, a curtain to draw). The Jednota's shop gets
## one in its right wall.
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
var _windows: Array = []


func _make_windows(profile: String) -> void:
	_free_windows()
	var roots: Array = []
	match profile:
		"rest":
			roots = [_restaurant_dining_root]
		"pub":
			roots = [_pub_main_root]
		"vecerka":
			roots = [_vecerka_shop_root]
		"staff":
			if _staff_room != null:
				_windows = _staff_room.make_windows(WINDOW_PORTAL)
			return
	for root in roots:
		if root == null:
			continue
		for n in (root as Node3D).find_children("*", "MeshInstance3D", false, false):
			# The painted views (the second of a name is renamed by Godot: told by the picture).
			var pic := n as MeshInstance3D
			var q := pic.mesh as QuadMesh
			var pm := pic.material_override as StandardMaterial3D
			if q == null or pm == null or pm.albedo_texture == null or not str(pm.albedo_texture.resource_path).ends_with("window_view.png"):
				continue
			# A picture faces +Z turned by its yaw: that is into the room; out is the other way.
			var into := pic.transform.basis.z
			var w = WINDOW_PORTAL.make(self, root, pic.position + into * 0.01, -into, q.size, "curtain_floral")
			pic.visible = false
			for c in (root as Node3D).get_children():
				# The rain on the glass and the lightning (scripts/ambient/room_weather.gd).
				if c.has_method("add_window"):
					c.add_window(w.quad)
				var cm = (c as MeshInstance3D).material_override as StandardMaterial3D if c is MeshInstance3D else null
				if cm != null and cm.albedo_texture != null and str(cm.albedo_texture.resource_path).ends_with("window_curtain.png") and (c as Node3D).position.distance_to(pic.position) < 0.3:
					(c as Node3D).visible = false
			_windows.append({"w": w, "root": root})
	if profile == "vecerka" and _vecerka_shop_root != null:
		var w2 = WINDOW_PORTAL.make(self, _vecerka_shop_root, Vector3(3.17, 1.55, 1.55), Vector3(1, 0, 0), Vector2(1.0, 0.8), "curtain_floral")
		_windows.append({"w": w2, "root": _vecerka_shop_root})


func _free_windows() -> void:
	for e in _windows:
		e["w"].free_all()
	_windows.clear()


func _tick_windows(delta: float) -> void:
	if _windows.is_empty():
		return
	var anchor := _service_anchor()
	var world: World3D = anchor.get_world_3d() if anchor != null else null
	for e in _windows:
		var root: Node3D = e["root"]
		var live: bool = anchor != null and root.is_visible_in_tree()
		var xf: Transform3D = WINDOW_PORTAL.room_to_world(anchor, e["w"], 0.0) if anchor != null else Transform3D()
		if e.has("room") and anchor != null:
			# The staffroom: its room space is the building's own (staffroom_plan.gd);
			# only the windows of the room you are in are drawn.
			xf = anchor.global_transform
			live = live and _staff_room != null and str(e["room"]) == str(_staff_room.room) and not _staff_room.walking()
		e["w"].update(root, _interior_camera, xf, live, world, delta)


## The building outside (InteriorManager's open structure).
func _service_anchor() -> Node3D:
	var im := get_parent()
	var n = im.get("_active_service_node") if im != null else null
	return n as Node3D if n != null and is_instance_valid(n) and (n as Node3D).is_inside_tree() else null


## The windows of the part you are in, for whatever is outside (the Photographer):
## [{pos, out (world), facing, open (the curtain 0..1), flash: Callable}].
func photo_windows() -> Array:
	var out: Array = []
	var anchor := _service_anchor()
	if anchor == null:
		return out
	for e in _windows:
		var root: Node3D = e["root"]
		if not root.is_visible_in_tree():
			continue
		var w = e["w"]
		var o: Dictionary = w.outside(anchor.global_transform if e.has("room") else WINDOW_PORTAL.room_to_world(anchor, w, 0.0))
		o["facing"] = w.facing(root, _interior_camera)
		o["open"] = w.curtain_open()
		o["flash"] = w.flash
		o["room_world"] = _viewport.find_world_3d() if _viewport != null else null
		o["glass"] = root.global_transform * w.frame.origin
		o["eye"] = _interior_camera.global_position
		# Your eye out in the camp (the window's camera).
		o["view"] = w.cam.global_position
		out.append(o)
	return out


## The curtains as they are (by window), for the other wardens in the same building.
func curtains_state() -> Array:
	var out: Array = []
	for e in _windows:
		out.append(e["w"].curtain_open() > 0.5)
	return out


func take_curtains(state: Array) -> void:
	for i in mini(state.size(), _windows.size()):
		_windows[i]["w"].set_curtain(bool(state[i]))


func _send_curtains() -> void:
	var im := get_parent()
	if im != null and im.has_method("coop_send_curtains"):
		im.coop_send_curtains(curtains_state())


## An Object a meta of `node` or a parent holds (null none).
func _meta_up_object(node: Node, meta: String) -> Object:
	var n := node
	while n != null:
		if n.has_meta(meta):
			return n.get_meta(meta)
		n = n.get_parent()
	return null


## The click boxes under `root` on (their own layers) or off (none).
func _bodies_live(root: Node3D, on: bool) -> void:
	for b in root.find_children("*", "StaticBody3D", true, false):
		var body := b as StaticBody3D
		if not body.has_meta("live_layer"):
			body.set_meta("live_layer", body.collision_layer)
		body.collision_layer = int(body.get_meta("live_layer")) if on else 0


## A meta of `node` or the nearest parent that has it ("" none).
func _meta_up(node: Node, meta: String) -> String:
	var n := node
	while n != null:
		if n.has_meta(meta):
			return str(n.get_meta(meta))
		n = n.get_parent()
	return ""


## A plate out through the hatch: seen on its sill in the dining room a moment before it
## is on their table.
func _on_plate_out(key: String, _tid: String, _verdict: Dictionary) -> void:
	if key != _upkeep_key or _restaurant_dining_root == null:
		return
	var path := "res://assets/textury/bistro/table_plate.png"
	if not ResourceLoader.exists(path):
		return
	var mi := MeshInstance3D.new()
	mi.name = "HatchPlate"
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.26)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mi.material_override = m
	mi.position = Vector3(0.45, 1.06, -2.28)
	_restaurant_dining_root.add_child(mi)
	get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(mi): mi.queue_free())


## The marks over the bistro's rooms (scripts/bistro/bistro_marks.gd).
func _start_bistro_marks() -> void:
	var k = get_tree().get_first_node_in_group("kitchens")
	if k == null:
		return
	if not k.plate_out.is_connected(_on_plate_out):
		k.plate_out.connect(_on_plate_out)
	_make_stations()
	# The steam and smoke over the stove and the pot (scripts/bistro/kitchen_fx.gd).
	if _restaurant_kitchen_root != null:
		var old := _restaurant_kitchen_root.get_node_or_null("KitchenFx")
		if old != null:
			old.queue_free()
		var fx: Node3D = load("res://scripts/bistro/kitchen_fx.gd").new()
		fx.name = "KitchenFx"
		fx.set("kitchen", k)
		fx.set("key", _upkeep_key)
		_restaurant_kitchen_root.add_child(fx)
	k.site(_upkeep_key)
	_bistro_marks = BISTRO_MARKS.new()
	_bistro_marks.name = "BistroMarks"
	_bistro_marks.kitchen = k
	_bistro_marks.key = _upkeep_key
	_bistro_marks.roots = {"dining": _restaurant_dining_root, "kitchen": _restaurant_kitchen_root, "basement": _restaurant_basement_root}
	_bistro_marks.camera_of = func() -> Camera3D: return _interior_camera
	_bistro_marks.viewport_of = func() -> SubViewport: return _viewport
	_bistro_marks.room_of = func() -> String: return _restaurant_room
	_bistro_marks.life_of = func(): return _life if _life != null and is_instance_valid(_life) else null
	_bistro_marks.taken_of = func() -> Dictionary: return _bistro_taken()
	add_child(_bistro_marks)
	_dirty_shown = -1
	_tickets_known = false
	if _sentence != null:
		move_child(_sentence, get_child_count() - 1)


# -- co-op: the other warden in here at the jobs ------------------------------------

## The game open now, as a job: the tap, the pass, the till, the bottles, the washer,
## the stove, the books; "" none.
func coop_job() -> String:
	var station := _station_open()
	if station != "":
		return station
	if _counter_game != null and _counter_game.visible:
		return {"pub": "tap", "vecerka": "till"}.get(_current_profile, "")
	for id in _extra_games:
		if (_extra_games[id] as CanvasLayer).visible:
			return str(id)
	if _ledger != null and _ledger.visible:
		return "ledger"
	if _laptop_view != null and _laptop_view.visible:
		return "laptop"
	if _staff_ledger != null and _staff_ledger.visible:
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
	if _current_profile == "staff" and _staff_room != null:
		return "staff/" + str(_staff_room.room)
	return _current_profile + "/main"


## Where the other warden stands at a job and what they look like doing it ({} not a job
## of this room): behind the bar at the tap, at the bottles, at the washer; at the pass,
## at the stove; at the till; over the books.
const COOP_JOB_SPOTS := {
	"pub": {"ledger": [Vector3(0.42, 0.05, -1.7), "write"]},
	"rest": {"ledger": [Vector3(1.42, 0.05, -1.7), "write"]},
	"vecerka": {"ledger": [Vector3(2.7, 0.05, -1.05), "write"]},
}


func coop_job_spot(job: String) -> Dictionary:
	if _current_profile == "staff" and _staff_room != null:
		# At the laptop: on its chair, the back to the room (you look over the shoulder);
		# at the books: standing at the table's end, bent over them.
		match job:
			"laptop":
				return {"pos": _room_root.global_transform * STAFF_PLAN.LAPTOP_CHAIR, "pose": "desk"}
			"ledger":
				return {"pos": _room_root.global_transform * Vector3(STAFF_PLAN.LEDGER.x - 0.1, STAFF_PLAN.FLOOR, STAFF_PLAN.LEDGER.z + 0.5), "pose": "write"}
		return {}
	if _current_profile == "pub" and PUB_LAYOUT.STATIONS.has(job):
		# At a station of the pub (scripts/pub/pub_layout.gd STATIONS).
		var pst: Dictionary = PUB_LAYOUT.STATIONS[job]
		var proot: Node3D = _station_root(str(pst["room"]))
		if proot == null or not proot.is_visible_in_tree():
			return {}
		return {"pos": proot.global_transform * (pst["stand"] as Vector3), "pose": str(pst["pose"])}
	if _current_profile == "vecerka" and JEDNOTA_LAYOUT.STATIONS.has(job):
		# At a station of the Jednota (scripts/jednota/jednota_layout.gd STATIONS).
		var jst: Dictionary = JEDNOTA_LAYOUT.STATIONS[job]
		var jroot: Node3D = _station_root(str(jst["room"]))
		if jroot == null or not jroot.is_visible_in_tree():
			return {}
		return {"pos": jroot.global_transform * (jst["stand"] as Vector3), "pose": str(jst["pose"])}
	if _current_profile == "rest" and BISTRO_LAYOUT.STATIONS.has(job):
		# At a station of the bistro (scripts/bistro/bistro_layout.gd STATIONS).
		var st: Dictionary = BISTRO_LAYOUT.STATIONS[job]
		var sroot: Node3D = _bistro_root(str(st["room"]))
		if sroot == null or not sroot.is_visible_in_tree():
			return {}
		return {"pos": sroot.global_transform * (st["stand"] as Vector3), "pose": str(st["pose"])}
	var spot: Array = (COOP_JOB_SPOTS.get(_current_profile, {}) as Dictionary).get(job, [])
	if spot.is_empty():
		return {}
	var root: Node3D = null
	match _current_profile:
		"pub":
			root = _pub_main_root
		"rest":
			root = _restaurant_dining_root
		"vecerka":
			root = _vecerka_shop_root
	if root == null or not root.is_visible_in_tree():
		return {}
	return {"pos": root.global_transform * (spot[0] as Vector3), "pose": str(spot[1])}


## The other wardens' jobs here (their warden states' room "w"): not marked as waiting
## for you, it is being done.
var coop_partner_jobs: Array = []


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
			for t: Vector3 in BISTRO_LAYOUT.TABLES:
				var top2 := _top_near(root, "GinghamTable", t, 0.78)
				for side: float in [-1.0, 1.0]:
					settings[seats.size()] = t + Vector3(side * 0.2, top2, 0)
					seats.append({"pos": t + Vector3(side * 0.45, 0, 0), "table": tj})
				tj += 1
		"vecerka":
			root = _vecerka_shop_root
			if root == null:
				return
			# Looking round at the racks (jednota_layout.BROWSE); the queue's places along
			# the till are service_life's (it walks them there when they have their basket).
			for b in JEDNOTA_LAYOUT.BROWSE:
				var bd: Dictionary = b
				seats.append({"pos": bd["pos"], "face": bd["face"], "stand": true, "clear_of": bd.get("clear_of", []), "aside": bd.get("aside", bd["pos"])})
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
	if _current_profile == "vecerka":
		_life.set("queue_spots", JEDNOTA_LAYOUT.QUEUE)
		_life.set("queue2_spots", JEDNOTA_LAYOUT.QUEUE2)
		_life.set("open_of", func() -> String: return _station_open())
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


# -- the staffroom: its laptop, its books (scripts/staff/) --------------------------

## The office PC (building_interior.gd): its desktop is the laptop's.
func _office_pc():
	var im := get_parent()
	return im.get("_building_interior") if im != null else null


## The picture on the laptop's screen: another warden's at it (co-op), the office PC's.
func _staff_pc_texture() -> Texture2D:
	if _laptop_view != null and is_instance_valid(_laptop_view) and _laptop_view.call("partner_texture") != null:
		return _laptop_view.call("partner_texture")
	var bi = _office_pc()
	var vp = bi.get("_crt_viewport") if bi != null else null
	return (vp as SubViewport).get_texture() if vp is SubViewport else null


func _staff_laptop_live() -> bool:
	return _laptop_view != null and (_laptop_view.visible or _laptop_view.call("partner_texture") != null)


func _staff_open_laptop() -> void:
	# Co-op: one at the PC at a time, here or at the office (the others look on).
	for id in Coop.others():
		var theirs: Dictionary = Coop.state_of(id).get("room", {})
		if str(theirs.get("w", "")) in ["pc", "laptop"]:
			var hud = get_tree().current_scene.get("_hud_manager") if get_tree().current_scene != null else null
			if hud != null:
				hud.push_status(tr("%s is on the PC. You look over their shoulder.") % Coop.name_of(id), 1)
			return
	_ensure_laptop_view()
	_hot_glint.clear()
	_laptop_view.call("open_for", _office_pc(), _interior_camera)


func _ensure_laptop_view() -> void:
	if _laptop_view == null:
		_laptop_view = LAPTOP_VIEW.new()
		_laptop_view.name = "LaptopView"
		add_child(_laptop_view)


func _staff_open_ledger() -> void:
	if _staff_ledger == null:
		_staff_ledger = STAFF_LEDGER.new()
		_staff_ledger.name = "StaffLedger"
		add_child(_staff_ledger)
	_hot_glint.clear()
	_staff_ledger.call("open_view")


## Co-op: the other warden's laptop screen (main.coop_show_screen), on its glass here.
func coop_show_laptop(frame: PackedByteArray) -> void:
	if _current_profile != "staff":
		return
	_ensure_laptop_view()
	_laptop_view.call("partner_frame", frame)


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
	if service_type == "staffroom":
		return "staff"
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
	# The bistro's windows go dark with the evening (the view is a day picture).
	if _restaurant_dining_root != null:
		var view := Color(1, 1, 1)
		if _time_state == TIME_EVENING:
			view = Color(0.55, 0.45, 0.45)
		elif _time_state == TIME_NIGHT:
			view = Color(0.08, 0.09, 0.14)
		for w in _restaurant_dining_root.find_children("*Window*", "MeshInstance3D", false, false):
			var wm := (w as MeshInstance3D).material_override as StandardMaterial3D
			if wm != null:
				wm.albedo_color = view


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
	if _current_profile == "rest" and _restaurant_room == "basement":
		target_ambient *= 0.28
		target_light *= 0.15
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
