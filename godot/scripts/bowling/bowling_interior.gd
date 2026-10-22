extends CanvasLayer

## Inside the camp's bowling alley (InteriorManager module "bowling"; the hall in
## scripts/bowling/bowling_layout.gd, the lanes scripts/bowling/lane.gd): you come in by
## the door on the left, straight to work like in the camp's other places: the station you
## were at last, the first time the shoe counter (desk_station.gd); the pit behind each pair
## of lanes is the other (pit_station.gd). BACK (S, the right button) leaves the station for
## the hall: a click there takes you to a station again, to the snack bar or behind a
## lane's bowler to watch; S in the hall goes out of the door.
##
## What goes on is scripts/bowling/bowling.gd's (it goes on while nobody is inside); the
## hall shows it: the parties come in through the door and queue at the counter, wait for a
## lane at a table, bowl on theirs (the lane draws it), go when their visit is over.
## The stations are worked on the business frame of the camp's other places (station3d.gd
## in the room, station_hud.gd round it): the rail of orders, the big ticket, SERVE, the
## tabs, the books.
## With a pinsetting machine from the books the pits are its (no tabs for them): the
## Stavomat's gear train is in the cellar under the hall (its own room, cellar_station.gd,
## the tab CELLAR; down the stairs behind the pit door), the lamp in the masking panel's
## corner goes red when it jams. A tab between the hall and the cellar goes through a
## dissolve (the rooms are far apart).

signal request_close

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const LAYOUT = preload("res://scripts/bowling/bowling_layout.gd")
const LANE = preload("res://scripts/bowling/lane.gd")
const BOWLING = preload("res://scripts/bowling/bowling.gd")
const POSES = preload("res://scripts/attractions/poses.gd")
const STATION3D = preload("res://scripts/business/station3d.gd")
const STATION_HUD = preload("res://scripts/business/station_hud.gd")
const LEDGER = preload("res://scripts/business/ledger_closeup.gd")
const KIT = preload("res://scripts/interior_kit.gd")
const BUSINESS_RT = preload("res://scripts/business/business_runtime.gd")
const SFX := "res://assets/sfx/bowling/"
const TIME_DAY: int = 0
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)
const MOVE_SEC := 0.55
const GUEST_H := 1.72
const STATION_SCRIPTS := {
	"desk": "res://scripts/bowling/desk_station.gd",
	"pit_a": "res://scripts/bowling/pit_station.gd",
	"pit_b": "res://scripts/bowling/pit_station.gd",
	"cellar": "res://scripts/bowling/cellar_station.gd",
}

var key := ""
var _is_open := false
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _root: Node3D
var _env: Environment
var _built := {}
var _lanes: Array = []
var _look = INTERIOR_LOOK.new(75.0, 20.0, 34.0)
var _cam_base_rot := Vector3.ZERO
var _spot := "hall"
var _move: Tween
var _exit_hint: Control
var _time_state := TIME_DAY
var _daylight := 1.0
var _power := true
var _bowling: Node
## visit -> {visit, members: [{node, sprite, base}], at ("door", "queue", "table", "lane",
## "out"), slot (the queue's place, the table, the lane), tween}
var _parties: Dictionary = {}
var _poll := 0.0
var _hall: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
## The stations (id -> station3d), the frame round them, the camera's way there and back.
var _stations: Dictionary = {}
var _station_hud: CanvasLayer
var _station_tween: Tween
var _station_cam_from: Array = []
var _switching := false
var _tabs_t := 0.0
var _ledger: Node
## The cellar under the hall (its own room, far off in the hall's world), the room the camera is in now, the
## machine and its jam as last seen (for the sound when it jams, the frame's paint).
var _cellar_root: Node3D
var _cellar := {}
var _room := "hall"
var _cellar_loop: AudioStreamPlayer
var _gears_loop: AudioStreamPlayer
var _brn_loop: AudioStreamPlayer
var _jam_sound: AudioStreamPlayer
var _machine_was := "?"
var _jam_was := ""
var _flicker_t := 0.0


func _ready() -> void:
	layer = 56
	visible = false
	_build_viewport()
	_root = Node3D.new()
	_root.name = "BowlingHall"
	_viewport.add_child(_root)
	_built = LAYOUT.build(_root)
	for i in LAYOUT.LANES.size():
		var lane := LANE.new()
		_root.add_child(lane)
		lane.setup(i)
		_lanes.append(lane)
	_cellar_root = Node3D.new()
	_cellar_root.name = "BowlingCellar"
	_cellar_root.position = LAYOUT.CELLAR_AT
	_root.add_child(_cellar_root)
	_cellar = LAYOUT.cellar(_cellar_root)
	_interior_camera = Camera3D.new()
	_interior_camera.fov = 62.0
	_interior_camera.near = 0.05
	_root.add_child(_interior_camera)
	_hall = _loop("hall_loop.mp3", -16.0)
	_hum = _loop("fluoro.mp3", -26.0)
	_cellar_loop = _loop("cellar_loop.ogg", -15.0)
	_gears_loop = _loop("gears_loop.ogg", -13.0)
	_brn_loop = _loop("brnoswick_loop.ogg", -15.0)
	_jam_sound = AudioStreamPlayer.new()
	_jam_sound.volume_db = -9.0
	add_child(_jam_sound)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "BowlingViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "BowlingViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.05, 0.05, 0.06)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.7, 0.74, 0.76)
	_env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = _env
	_viewport.add_child(we)


func _loop(file: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := SFX + file
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
	p.volume_db = db
	add_child(p)
	return p


func is_open() -> bool:
	return _is_open


func set_time_state(state: int) -> void:
	_time_state = state
	_apply_light()


func set_daylight_profile(daylight_factor: float, _sun: Color, _ambient: Color, _energy: float) -> void:
	_daylight = clampf(daylight_factor, 0.0, 1.0)
	_apply_light()


func set_grid_power_available(on: bool) -> void:
	_power = on
	_apply_light()


func _apply_light() -> void:
	var tubes: Array = _built.get("tubes", [])
	for t in tubes:
		(t as StandardMaterial3D).emission_energy_multiplier = 1.6 if _power else 0.0
	for l in _built.get("lights", []):
		(l as Light3D).visible = _power
	var glass: StandardMaterial3D = _built.get("glass")
	if glass != null:
		glass.emission_energy_multiplier = 0.15 + 0.75 * _daylight
	if _env != null:
		_env.ambient_light_energy = (0.55 if _power else 0.08) + 0.15 * _daylight
		# The cellar has no daylight and one bulb.
		if _room == "cellar":
			_env.ambient_light_energy = 0.16 if _power else 0.03
	var bulb: OmniLight3D = _cellar.get("bulb")
	if bulb != null:
		bulb.visible = _power


## In by the door of the bowling alley at `p_key` ("x:y"), straight to work.
func open_bowling(p_key: String) -> void:
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	key = p_key
	if _is_open:
		return
	_is_open = true
	visible = true
	_bowling = BOWLING.of(get_tree())
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_go("hall", true)
	_apply_light()
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_site(key, "bowling")
	_sync_guests()
	_sync_lanes()
	if _hall.stream != null:
		_hall.play(_rng.randf() * 4.0)
	if _hum.stream != null and _power:
		_hum.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_make_stations()
	_machine_was = "?"
	_jam_was = str(_bowling.jam_of(key).get("jam", "")) if _bowling.jammed(key) else ""
	_dress_machine()
	var first := str(LAYOUT.ENTRY_STATION)
	var last := str(STATION3D.last_station.get(key, first))
	var tabs: Array = _room_tabs().map(func(t) -> String: return str(t[0]))
	_open_station(last if tabs.has(last) else first)


func close_bowling() -> void:
	if not _is_open:
		return
	var open := _station_open()
	if open != "":
		_switching = true
		_stations[open].call("close_station")
		_switching = false
	if _station_hud != null and is_instance_valid(_station_hud):
		_station_hud.visible = false
	_station_cam_from = []
	_is_open = false
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_room = "hall"
	_hall.stop()
	_hum.stop()
	_cellar_loop.stop()
	_gears_loop.stop()
	_brn_loop.stop()
	for v in _parties.keys():
		_free_party(v)
	_parties.clear()
	for lane in _lanes:
		lane.reset_view()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_sync_guests()
		_dress_machine()
	_sync_lanes()
	_tick_machine(delta)
	var open := _station_open()
	if open != "":
		_station_frame(open)
		if _exit_hint != null:
			_exit_hint.modulate.a = 0.0
		return
	var moving := _station_tween != null and _station_tween.is_valid() and _station_tween.is_running()
	if not moving and (_move == null or not _move.is_running()):
		var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
		_interior_camera.rotation = _cam_base_rot + offset
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self, "Leave   [S]" if _spot == "hall" else "Back   [S]")
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	if not moving and _clicked() != "":
		HandCursor.want(HandCursor.POINT)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var open := _station_open()
	if open != "":
		_station_input(event, open)
		return
	if _station_tween != null and _station_tween.is_valid() and _station_tween.is_running():
		if not event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		get_viewport().set_input_as_handled()
		if _spot == "hall":
			close_bowling()
		else:
			_go("hall")
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var what := _clicked()
		if what == "":
			return
		get_viewport().set_input_as_handled()
		if what in ["pit_a", "pit_b"] and _bowling.machine_of(key) != "":
			return
		if STATION_SCRIPTS.has(what):
			_open_station(what)
		elif what == "pit":
			# Behind the pit door: the walkway, or with a machine the stairs down to its cellar.
			_open_station("cellar" if _bowling.machine_of(key) != "" else "pit_a")
		elif what.begins_with("lane") or what == "bufet":
			_go(what)


## What the cursor is on in the hall: the click box's name ("desk", "lane2"...), or "".
func _clicked() -> String:
	if _viewport == null or _interior_camera == null:
		return ""
	var c := INTERIOR_LOOK.cursor_of(get_viewport())
	if c.x < 0.0:
		return ""
	var at := c * Vector2(_viewport.size)
	var from := _interior_camera.project_ray_origin(at)
	var dir := _interior_camera.project_ray_normal(at)
	var space := _interior_camera.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return ""
	var col = hit.get("collider")
	return str((col as Node).get_meta("bowling_click", "")) if col is Node else ""


## The camera to `spot` ("hall", "bufet", "lane<i>").
func _go(spot: String, at_once := false) -> void:
	var s: Array = LAYOUT.lane_spot(int(spot.substr(4))) if spot.begins_with("lane") else LAYOUT.SPOTS.get(spot, LAYOUT.SPOTS["hall"])
	_spot = spot
	if _exit_hint != null:
		_exit_hint.queue_free()
		_exit_hint = null
	var rot := Vector3(deg_to_rad(float((s[1] as Vector3).x)), deg_to_rad(float((s[1] as Vector3).y)), 0.0)
	_look.reset()
	_cam_base_rot = rot
	if _move != null and _move.is_valid():
		_move.kill()
	if at_once:
		_interior_camera.position = s[0]
		_interior_camera.rotation = rot
		return
	_move = CAM_MOVE.move(self, _interior_camera, {"position": s[0], "rotation": rot}, MOVE_SEC)


# ── the guests ───────────────────────────────────────────────────────────────

## Who the simulation has visiting this building now (the whole guest records).
func _visitors() -> Array:
	var out: Array = []
	if GuestManager == null or key == "":
		return out
	var now: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	for g in GuestManager.get_guest_life_snapshot():
		var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
		if str(act.get("kind", "")) != "visit" or str(act.get("target_key", "")) != key or bool(act.get("queued", false)):
			continue
		if int(act.get("arrive", now)) > now:
			continue
		out.append(g)
	return out


## Everyone where the alley's record has them: in the queue at the counter, at a table
## waiting for a lane, on their lane (the lane moves them there), out of the door.
func _sync_guests() -> void:
	if _bowling == null or key == "":
		return
	var s: Dictionary = _bowling.site(key)
	var seen := {}
	for g in _visitors():
		var act: Dictionary = g.get("activity", {})
		var visit := "%d@%d" % [int(g.get("id", 0)), int(act.get("start", 0))]
		seen[visit] = true
		if not _parties.has(visit):
			_parties[visit] = _make_party(g, visit)
	var queue: Array = (s["desk"] as Array).map(func(d) -> String: return str(d["visit"]))
	var tables := 0
	for v in _parties.keys():
		var p: Dictionary = _parties[v]
		var at := "out"
		var slot := 0
		if seen.has(v) and not s["gone"].has(v):
			if s["checked"].has(v):
				var li := int(s["checked"][v].get("lane", -1))
				if li >= 0:
					at = "lane"
					slot = li
				else:
					at = "table"
					slot = tables
					tables += 1
			else:
				at = "queue"
				var q := queue.find(v)
				slot = q if q >= 0 else queue.size()
		if at != str(p["at"]) or (at != "lane" and slot != int(p["slot"])):
			_move_party(p, at, slot)
	for v in _parties.keys():
		if str(_parties[v]["at"]) == "gone":
			_parties.erase(v)


## The lanes drawn from their records, each with its party's figures (and the machine over
## their decks, the score screens over their approaches, from the books).
func _sync_lanes() -> void:
	if _bowling == null or key == "":
		return
	var mach: String = _bowling.machine_of(key)
	var screens := BUSINESS_RT.has_gear(key, "scoreboard")
	for i in _lanes.size():
		_lanes[i].set("machine", mach)
		_lanes[i].set("screens", screens)
		var rec: Dictionary = _bowling.lane(key, i)
		var p: Dictionary = _parties.get(str(rec.get("visit", "")), {})
		_lanes[i].sync(rec, p.get("members", []) if str(p.get("at", "")) == "lane" else [])


func _make_party(g: Dictionary, visit: String) -> Dictionary:
	var arch := str(g.get("archetype", ""))
	var n: int = POSES.figure_count(arch, int(g.get("party_size", 1)))
	var base := str(g.get("sprite_path", ""))
	var members: Array = []
	for k in n:
		var node := Node3D.new()
		node.name = "Bowler"
		_root.add_child(node)
		var own := POSES.member_path(arch, base, k)
		var sprite := Sprite3D.new()
		sprite.name = "Sprite"
		if ResourceLoader.exists(own):
			sprite.texture = load(own)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.double_sided = true
		if sprite.texture != null:
			sprite.pixel_size = GUEST_H / float(sprite.texture.get_height())
			sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5)
		node.add_child(sprite)
		node.position = Vector3(LAYOUT.DOOR_X + (float(k) - 0.5) * 0.4, 0.0, LAYOUT.FRONT_Z - 0.4)
		POSES.set_pose(sprite, own, "")
		members.append({"node": node, "sprite": sprite, "base": own})
	return {"visit": visit, "members": members, "at": "door", "slot": -1, "tween": null}


## The party to its new place: walking there (in through the door, along the counter, to
## a table and sitting down, out of the door); on a lane the lane takes them over.
func _move_party(p: Dictionary, at: String, slot: int) -> void:
	p["at"] = at
	p["slot"] = slot
	var old: Tween = p.get("tween")
	if old != null and old.is_valid():
		old.kill()
	p["tween"] = null
	if at == "lane":
		return
	var members: Array = p["members"]
	if members.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	p["tween"] = tw
	for k in members.size():
		var m: Dictionary = members[k]
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			continue
		var to := node.position
		var sit := false
		match at:
			"queue":
				var q: Array = LAYOUT.DESK_QUEUE[mini(slot, LAYOUT.DESK_QUEUE.size() - 1)]
				var face: Vector3 = q[1]
				# The party bunched behind its first, away from the counter.
				to = (q[0] as Vector3) - face.normalized() * 0.35 * float(k) + Vector3(0.18 * float(k % 2), 0, 0)
				if slot >= LAYOUT.DESK_QUEUE.size():
					to += Vector3(0.45 * float(slot - LAYOUT.DESK_QUEUE.size() + 1), 0, 0)
			"table":
				var t: Vector3 = LAYOUT.TABLES[slot % LAYOUT.TABLES.size()]
				to = t + Vector3((float(k) - 0.5) * 0.9, 0, 0.55 if k % 2 == 0 else -0.55)
				sit = true
			"out":
				to = Vector3(LAYOUT.DOOR_X + (float(k) - 0.5) * 0.4, 0.0, LAYOUT.FRONT_Z - 0.2)
		POSES.set_pose(m["sprite"], str(m["base"]), "")
		var dur := maxf(0.3, node.position.distance_to(to) / 1.15)
		var step := tw.tween_property(node, "position", to, dur).set_delay(0.2 * k)
		if sit:
			step.finished.connect(func() -> void:
				if is_instance_valid(node) and str(p.get("at", "")) == "table":
					POSES.set_pose(m["sprite"], str(m["base"]), "sit"))
	if at == "out":
		tw.chain().tween_callback(func() -> void:
			_free_party(str(p["visit"]))
			p["at"] = "gone")


func _free_party(v: String) -> void:
	var p: Dictionary = _parties.get(v, {})
	var old = p.get("tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	for m in p.get("members", []):
		var node: Node3D = m.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()


# ── the stations (the business frame, as in the camp's other places) ─────────

## The station open now ("" none).
func _station_open() -> String:
	for id in _stations:
		var v = _stations[id]
		if is_instance_valid(v) and bool(v.call("is_open")):
			return str(id)
	return ""


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
	return _station_hud


## The tabs of the stations on the frame's bar: [[id, LABEL, icon], ...]: the pits while
## the pins are set by hand, the cellar while the Stavomat sets them (the Brnoswick needs
## nobody).
func _room_tabs() -> Array:
	var out: Array = []
	var mach: String = _bowling.machine_of(key) if _bowling != null and key != "" else ""
	for id in LAYOUT.STATIONS:
		if str(id) in ["pit_a", "pit_b"] and mach != "":
			continue
		if str(id) == "cellar" and mach != "machine":
			continue
		var st: Dictionary = LAYOUT.STATIONS[id]
		out.append([str(id), str(st.get("tab_label", str(id).to_upper())), str(st.get("icon", ""))])
	return out


## The machine as the books have it: the cellar's frame in the Stavomat's grey-green or the
## Brnoswick's enamel; the room's sounds.
func _dress_machine() -> void:
	if _bowling == null or key == "":
		return
	var mach: String = _bowling.machine_of(key)
	if mach == _machine_was:
		return
	_machine_was = mach
	var frame: MeshInstance3D = _cellar.get("frame")
	if frame != null:
		frame.material_override = KIT.surface(LAYOUT._tex_or("bowl_brnoswick" if mach == "brnoswick" else "bowl_machine", "steel_brushed"), 0.9)
	_room_audio()


## The jam lamp over the lanes, the sound when it jams, the cellar's bulb now and then
## catching.
func _tick_machine(delta: float) -> void:
	if _bowling == null or key == "":
		return
	var jam: String = str(_bowling.jam_of(key).get("jam", "")) if _bowling.jammed(key) else ""
	var lamp: StandardMaterial3D = _built.get("jam_lamp")
	var on := jam != "" and fposmod(float(Time.get_ticks_msec()) * 0.0025, 2.0) < 1.0
	if lamp != null:
		lamp.emission_energy_multiplier = (2.4 if on else 0.15) if jam != "" else 0.0
	var glow: OmniLight3D = _built.get("jam_glow")
	if glow != null:
		glow.light_energy = 1.6 if on and _power else 0.0
	if jam != _jam_was:
		if jam != "" and ResourceLoader.exists(SFX + "machine_jam.mp3"):
			_jam_sound.stream = load(SFX + "machine_jam.mp3")
			_jam_sound.volume_db = -6.0 if _room == "cellar" else -14.0
			_jam_sound.play()
		_jam_was = jam
		_room_audio()
	if _room == "cellar":
		_flicker_t -= delta
		var bulb: OmniLight3D = _cellar.get("bulb")
		var bm: StandardMaterial3D = _cellar.get("bulb_mat")
		if bulb != null and _power:
			if _flicker_t <= 0.0:
				_flicker_t = _rng.randf_range(2.5, 9.0)
			var dim := _flicker_t < 0.18 and int(_flicker_t * 40.0) % 2 == 0
			bulb.light_energy = 0.35 if dim else 1.1
			if bm != null:
				bm.emission_energy_multiplier = 0.4 if dim else 1.4


## The sounds of the room the camera is in: the hall's, or the cellar's drip and the
## machine turning (the Stavomat's iron when it runs, the Brnoswick's purr).
func _room_audio() -> void:
	if not _is_open:
		return
	var in_cellar := _room == "cellar"
	var mach: String = _bowling.machine_of(key) if _bowling != null else ""
	var running: bool = mach == "machine" and not bool(_bowling.jammed(key))
	_set_loop(_cellar_loop, in_cellar)
	_set_loop(_gears_loop, in_cellar and running)
	_set_loop(_brn_loop, in_cellar and mach == "brnoswick")
	_hall.volume_db = -30.0 if in_cellar else -16.0
	_hum.volume_db = -40.0 if in_cellar else -26.0


func _set_loop(p: AudioStreamPlayer, on: bool) -> void:
	if p == null or p.stream == null:
		return
	if on and not p.playing:
		p.play(_rng.randf() * 3.0)
	elif not on and p.playing:
		p.stop()


## The camera from the hall into the cellar or back: through a dissolve, all at once.
func _cross_to(room: String) -> void:
	if room == _room:
		return
	var im := get_parent()
	if im != null and im.has_method("_door_transition"):
		im.call("_door_transition", room == "cellar")
	_room = room
	_apply_light()
	_room_audio()


## Every station of the hall, made once the building is known, standing where it is worked
## (the layout's SURFACES), the alley's record as its state.
func _make_stations() -> void:
	if key == "":
		return
	for id in STATION_SCRIPTS:
		var have = _stations.get(id, null)
		if have != null and is_instance_valid(have) and str(have.get("building_key")) == key:
			continue
		if have != null and is_instance_valid(have):
			(have as Node).queue_free()
		var path := str(STATION_SCRIPTS[id])
		if not ResourceLoader.exists(path):
			continue
		var st: Dictionary = LAYOUT.STATIONS[id]
		var surf: Dictionary = LAYOUT.SURFACES[id]
		var v: Node3D = load(path).new()
		v.name = "Station3D_" + str(id)
		var parent: Node3D = _cellar_root if str(st.get("room", "hall")) == "cellar" else _root
		v.set("building_key", key)
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
		v.set("state", _bowling)
		if "lanes" in v:
			var views: Array = []
			for i in st.get("lanes", []):
				views.append(_lanes[int(i)])
			v.set("lanes", views)
		if "open_books" in v:
			v.set("open_books", _open_ledger)
		parent.add_child(v)
		v.connect("closed", _on_station_closed)
		v.connect("switch_to", _switch_station)
		_stations[id] = v


## Steps up to the station `id`: the hall's camera glides over it, the station takes the
## pointer, the frame comes up round the room.
func _open_station(id: String) -> void:
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
	if was == "" and _station_cam_from.is_empty():
		_station_cam_from = [_interior_camera.transform, _interior_camera.rotation]
	if _move != null and _move.is_valid():
		_move.kill()
	var st: Node3D = _stations[id]
	if _station_tween != null and _station_tween.is_valid():
		_station_tween.kill()
	var room := str(LAYOUT.STATIONS[id].get("room", "hall"))
	if room != _room:
		# Down the stairs or up them: the camera is there at once, behind a dissolve.
		_cross_to(room)
		_interior_camera.global_transform = st.call("cam_pose")
		_station_tween = create_tween()
		_station_tween.tween_interval(0.01)
	else:
		_station_tween = STATION3D.step_camera(self, _interior_camera, st.call("cam_pose"), STATION3D.CAM_SEC if was == "" else 0.34)
	var hud := _hud()
	st.set("hud", hud)
	st.call("open_station", _interior_camera)
	hud.set("station", st)
	hud.set("tabs", _room_tabs())
	hud.set("taken", {})
	hud.set("view_size", Vector2(_viewport.size))
	hud.call("clear_say")
	hud.visible = true
	if _exit_hint != null:
		_exit_hint.modulate.a = 0.0


func _switch_station(id: String) -> void:
	_open_station(id)


## Stepped away from a station: the camera goes back to where you stood in the hall.
func _on_station_closed() -> void:
	if _switching or _station_open() != "" or _interior_camera == null:
		return
	if _station_hud != null and is_instance_valid(_station_hud):
		_station_hud.visible = false
	if _station_cam_from.is_empty():
		return
	var back: Transform3D = _station_cam_from[0]
	var rot: Vector3 = _station_cam_from[1]
	_station_cam_from = []
	if _station_tween != null and _station_tween.is_valid():
		_station_tween.kill()
	if _room != "hall":
		# Up the stairs: back where you stood in the hall.
		_cross_to("hall")
		_interior_camera.transform = back
		_interior_camera.rotation = rot
		_cam_base_rot = rot
		_look.reset()
		return
	_station_tween = STATION3D.step_camera(self, _interior_camera, _root.global_transform * back, STATION3D.CAM_SEC)
	_station_tween.finished.connect(func():
		_interior_camera.transform = back
		_interior_camera.rotation = rot
		_cam_base_rot = rot
		_look.reset())


## Each frame at a station: the pointer through the hall's camera onto it (or the frame, or
## a ticket on the rail), the finger or the fist.
func _station_frame(open: String) -> void:
	var st: Node = _stations[open]
	var moving := _station_tween != null and _station_tween.is_valid() and _station_tween.is_running()
	var mouse: Vector2 = STATION3D.mouse_of(get_viewport())
	var hud := _hud()
	_tabs_t -= get_process_delta_time()
	if _tabs_t <= 0.0:
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


## A point of the screen in the hall's picture (its viewport's pixels).
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


## The alley's books (scripts/business/ledger_closeup.gd): the menu, the goods, the hands,
## the gear.
func _open_ledger() -> void:
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = LEDGER.new()
		_ledger.name = "Ledger"
		add_child(_ledger)
	_ledger.call("open_for", key, "bowling")


# ── debug (the shot drivers) ─────────────────────────────────────────────────

func debug_station(id: String) -> Node:
	return _stations.get(id, null)


func debug_open_station(id: String) -> void:
	_open_station(id)
