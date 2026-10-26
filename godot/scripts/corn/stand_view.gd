extends CanvasLayer

## Behind the corn stand (DESIGN.md §7b "The corn stand"; the playtest, 18. 10.: "the corn
## stand is the bottom of the screen, the top is the live view into the camp"; the
## stations in 3D, 20. 10.). You stand behind its counter out in the camp and work its two
## stations there (scripts/corn/counter_station.gd, husk_station.gd, made with the stand by
## corn_stand_life.gd): a camera of its own in the camp's world, through the Build palette
## like every view, stands behind the counter and looks out over it, the counter at the
## bottom of the picture and the camp above it (the guests coming up to the stand, the
## paths, the weather). The frame round it (scripts/business/station_hud.gd), the same as in
## the other places: the tickets, SERVE (Space, Enter), BACK (S, the right button), the
## stand's stations (Tab, 1-3; the drinks only while they are on the menu), BOOKS (B).
## You come back to the station you were at; the first time, the counter (where an order
## starts). Your warden stands behind the counter meanwhile (the others see you there).
## Made by scripts/interior_manager.gd.

signal closed

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const STATION3D = preload("res://scripts/business/station3d.gd")
const STATION_HUD = preload("res://scripts/business/station_hud.gd")
const LAYOUT = preload("res://scripts/corn/stand_layout.gd")
const LEDGER = preload("res://scripts/business/ledger_closeup.gd")
const BUSINESS = preload("res://scripts/business/business_runtime.gd")
const RULES = preload("res://core/systems/business_rules.gd")

var building_key := ""
var _open := false
var _structure: Node3D
var _stations: Dictionary = {}
var _box: SubViewportContainer
var _view: SubViewport
var _cam: Camera3D
var _hud: CanvasLayer
var _tween: Tween
var _switching := false
var _ledger: CanvasLayer
var _player: Node3D
var _player_was := Transform3D.IDENTITY
var _taken_t := 0.0


func _init() -> void:
	# Under your hand at the station (station_hands.gd, 95) and the frame (96).
	layer = 94
	add_to_group("closeup")  # the hands are on it (pockets.gd)
	# Which station this warden is at (cornstand.warden_stations: the hands keep off it).
	add_to_group("corn_stand_view")
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_view = SubViewport.new()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_box.add_child(_view)
	_cam = Camera3D.new()
	_cam.fov = 68.0
	_cam.near = 0.05
	_cam.far = 400.0
	_view.add_child(_cam)
	RETRO_RENDER.register(_box)
	_hud = STATION_HUD.new()
	_hud.name = "StandHud"
	add_child(_hud)
	_hud.mirror_of = func() -> Array:
		var open := _station_open()
		if open == "" or not _stations[open].has_method("mirror"):
			return []
		return _stations[open].call("mirror")
	_hud.alert_of = func(id: String) -> int:
		var st = _stations.get(id, null)
		return int(st.call("alert")) if st != null and is_instance_valid(st) else 0
	get_tree().root.size_changed.connect(_layout)


func is_open() -> bool:
	return _open


## Where you are for the other wardens (interior_manager.coop_room): at this stand, at
## which station.
func coop_room() -> Dictionary:
	if not _open:
		return {}
	return {"k": building_key, "t": "corn", "s": "stand", "w": _station_open()}


## Behind the stand at `key`; `structure` is the stand in the camp.
func open_for(key: String, structure: Node3D) -> void:
	building_key = key
	_structure = structure
	if CoreRoot != null and CoreRoot.actions != null and key != "":
		CoreRoot.actions.biz_site(key, "corn_stand")
	var life := structure.get_node_or_null("Use")
	if life != null and life.has_method("make_stations"):
		_stations = life.call("make_stations", key)
	for id in _stations:
		var st: Node = _stations[id]
		if not st.is_connected("closed", _on_station_closed):
			st.connect("closed", _on_station_closed)
			st.connect("switch_to", _switch)
		if st.get("open_books") != null:
			st.set("open_books", _open_books)
	_view.world_3d = structure.get_viewport().find_world_3d()
	_stand_behind(true)
	_open = true
	visible = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_layout()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# From where you stood out front, round behind the counter, in steps.
	var front := structure.global_transform * Vector3(0, 1.6, 2.2)
	_cam.global_transform = Transform3D(Basis(), front).looking_at(structure.global_transform * Vector3(0, 1.1, 0), Vector3.UP)
	var last := str(STATION3D.last_station.get(key, "counter"))
	_open_station(last if _tabs_ids().has(last) else "counter")


func close_view() -> void:
	if not _open:
		return
	_switching = true
	for v in _stations.values():
		if is_instance_valid(v):
			v.call("close_station")
	_switching = false
	_hud.visible = false
	if _ledger != null and _ledger.visible:
		_ledger.call("close_view")
	_stand_behind(false)
	_open = false
	visible = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


## Your warden behind the counter while you are at it (the others see you there), back
## where you stood after.
func _stand_behind(on: bool) -> void:
	var main := get_tree().current_scene
	var p = main.get("_player") if main != null else null
	if not (p is Node3D):
		return
	_player = p
	if on:
		_player_was = _player.global_transform
		var at := _structure.global_transform * LAYOUT.VENDOR
		var face := _structure.global_transform.basis.z
		_player.global_transform = Transform3D(Basis.looking_at(-face, Vector3.UP), at)
	elif _player_was != Transform3D.IDENTITY:
		_player.global_transform = _player_was


func _layout() -> void:
	if _box == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_box.position = Vector2.ZERO
	_box.size = vp
	RETRO_RENDER.apply_to(_box)


func _open_books() -> void:
	if _ledger == null:
		_ledger = LEDGER.new()
		add_child(_ledger)
	_ledger.layer = 98
	_ledger.open_for(building_key, "corn_stand")


# ── the stations ─────────────────────────────────────────────────────────────

func _station_open() -> String:
	for id in _stations:
		var v = _stations[id]
		if is_instance_valid(v) and bool(v.call("is_open")):
			return str(id)
	return ""


func _tabs() -> Array:
	var out: Array = []
	for id in _tabs_ids():
		out.append([str(id), str(LAYOUT.STATIONS[id]["tab_label"]), str(LAYOUT.STATIONS[id].get("icon", ""))])
	return out


## The stations with a tab now: the drinks only while one of them is on the menu.
func _tabs_ids() -> Array:
	var out: Array = []
	var site := BUSINESS.site(building_key)
	for id in LAYOUT.STATIONS:
		if str(id) == "drinks" and not (RULES.menu_on("corn", site, "tea") or RULES.menu_on("corn", site, "limo")):
			continue
		out.append(str(id))
	return out


## The other wardens at this stand's stations: station -> their name.
func _taken() -> Dictionary:
	var out := {}
	if not Coop.is_active():
		return out
	for id in Coop.others():
		var r: Dictionary = Coop.state_of(id).get("room", {})
		if str(r.get("k", "")) == building_key and str(r.get("t", "")) == "corn" and LAYOUT.STATIONS.has(str(r.get("w", ""))):
			out[str(r["w"])] = Coop.name_of(id)
	return out


## The hands working the stations now: station -> first name (their tabs say so).
func _hands_at() -> Dictionary:
	var out := {}
	var cs := get_tree().get_first_node_in_group("cornstands") if is_inside_tree() else null
	if cs == null:
		return out
	var places: Dictionary = cs.crew_places(building_key)
	for p in BUSINESS.crew_now(building_key):
		var at := str(places.get(str(p.get("slug", "")), ""))
		if at != "":
			out[at] = str(p.get("name", "")).split(" ")[0]
	return out


func _open_station(id: String) -> void:
	if not _stations.has(id):
		return
	var who := str(_taken().get(id, ""))
	if who != "":
		_hud.call("say", "", "%s is at %s." % [who, str(LAYOUT.STATIONS[id]["label"])])
		if _station_open() == "":
			# Nowhere else to be: the other one, then.
			for other in _stations:
				if str(other) != id and str(_taken().get(other, "")) == "":
					_open_station(str(other))
					return
		return
	var was := _station_open()
	if was == id:
		return
	if was != "":
		_switching = true
		_stations[was].call("close_station")
		_switching = false
	var st: Node3D = _stations[id]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = STATION3D.step_camera(self, _cam, st.call("cam_pose"), STATION3D.CAM_SEC if was == "" else 0.34)
	st.set("hud", _hud)
	st.call("open_station", _cam)
	_hud.set("station", st)
	_hud.set("tabs", _tabs())
	_hud.set("taken", _taken())
	_hud.set("hands", _hands_at())
	_hud.set("view_size", Vector2(_view.size))
	_hud.call("clear_say")
	_hud.visible = true


func _switch(id: String) -> void:
	if str(_taken().get(id, "")) != "":
		_hud.call("say", "", "%s is at %s." % [str(_taken()[id]), str(LAYOUT.STATIONS[id]["label"])])
		return
	_open_station(id)


func _on_station_closed() -> void:
	if _switching or not _open:
		return
	# BACK at a station: you step away from the stand.
	close_view()


# ── each frame, the input ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _open:
		return
	_taken_t -= delta
	if _taken_t <= 0.0:
		_taken_t = 0.5
		_hud.set("taken", _taken())
		_hud.set("hands", _hands_at())
		_hud.set("tabs", _tabs())
		_hud.set("view_size", Vector2(_view.size))
		# The drinks went off the menu while you were at them.
		var at := _station_open()
		if at != "" and not _tabs_ids().has(at):
			_switch("counter")
	if _ledger != null and _ledger.visible:
		return
	var open := _station_open()
	if open == "":
		return
	var st: Node = _stations[open]
	var moving := _tween != null and _tween.is_valid() and _tween.is_running()
	var mouse: Vector2 = STATION3D.mouse_of(get_viewport())
	var ui := str(_hud.call("hit", mouse))
	_hud.call("set_hover", ui if ui.begins_with("#tab") or ui.begins_with("#btn") or ui in ["#back", "#serve", "#books"] else "")
	var vp_mouse := _view_px(mouse)
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


## A point of the screen in the view's own pixels (the camp is drawn small).
func _view_px(screen: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(-1, -1)
	return Vector2(clampf(screen.x / size.x, 0.0, 1.0) * float(_view.size.x), clampf(screen.y / size.y, 0.0, 1.0) * float(_view.size.y))


func _input(event: InputEvent) -> void:
	if not _open or get_tree().paused:
		return
	if _ledger != null and _ledger.visible:
		return
	# Esc is the pause menu's.
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	var open := _station_open()
	if open == "":
		return
	var st: Node = _stations[open]
	if event is InputEventKey and event.pressed and not event.echo:
		var ke := event as InputEventKey
		var act := str(_hud.call("key_action", ke))
		match act:
			"back":
				close_view()
			"serve":
				if bool(st.call("serve_ready")):
					st.call("serve_now")
			"books":
				_open_books()
			"next":
				_switch(str(_hud.call("next_tab")))
			"":
				st.call("key", ke)
			_:
				if act.begins_with("tab:") and act.substr(4) != open:
					_switch(act.substr(4))
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		close_view()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mb.pressed:
		st.call("release")
		return
	_hud.call("poke")
	if _tween != null and _tween.is_valid() and _tween.is_running():
		return
	var ui := str(_hud.call("hit", mb.position))
	if ui == "#back":
		close_view()
		return
	if ui == "#serve":
		if bool(st.call("serve_ready")):
			st.call("serve_now")
		return
	if ui == "#books":
		_open_books()
		return
	if ui.begins_with("#tab:"):
		var to := ui.substr(5)
		if to != open:
			_switch(to)
		return
	if ui.begins_with("#btn:"):
		st.call("bar_button", ui.substr(5))
		return
	if ui != "":
		return
	var rail := str(st.call("rail_ticket_at", _view_px(mb.position)))
	if rail != "":
		st.call("rail_clicked", rail)
		return
	st.call("press")
