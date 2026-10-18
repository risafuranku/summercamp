extends Node

## Upkeep in the world: what the player sees and does about building condition.
## Only the lamps wear (core/systems/maintenance_rules.gd): they dim day by day and go out
## when spent; hold R at one to put in a new bulb (the wrench). The derelict cabin of the
## start is the other thing R mends. Wear left on anything else (old saves) is cleared.
##
## - Every building's condition (GridModel cell "maintenance", 0..1) is mirrored onto
##   its structure, which darkens and corrodes as it wears (BuildingManager).
## - Poor buildings (below MaintenanceRules.SAFE_CONDITION, where breakdowns start)
##   carry an amber hazard sign; broken ones a blinking red one. Signs are unshaded
##   sprites, so at night they read as the only lit thing on a dead building.
## - Looking at a building shows its name and condition; holding R services it (or
##   repairs it when broken) for cash, with a progress bar under the crosshair.
## - Breakdowns and repairs post a line to the HUD feed.
## - Camp Status > Upkeep (CRT) reads `get_upkeep_snapshot()` and can call the crew.
##
## All writes go through CoreRoot.actions.service_building(); the rules (odds, costs,
## durations) live in core/systems/maintenance_rules.gd.

const RULES = preload("res://core/systems/maintenance_rules.gd")
const SFX_WORK := "res://assets/sfx/rednecksfx/rrtick.wav"
const SFX_DONE := "res://assets/sfx/rednecksfx/rrgeneratorpowerup.wav"
const SYNC_EVERY := 0.5
const VIEW_DISTANCE := 4.2
const VIEW_DOT := 0.55
const SIGN_PIXEL_SIZE := 0.05
## Kept up from the inside (scripts/service_interior.gd), not with hold R.
const CLEANED_INSIDE := ["toilet_block", "shower_block"]

var _world: Node3D
var _building_manager: Node
var _camera_getter: Callable
var _hud: Node
var _markers_root: Node3D
var _markers: Dictionary = {}
var _sync_t: float = 0.0
var _blink_t: float = 0.0
var _conditions_shown: Dictionary = {}
var _target: Dictionary = {}
var _work: float = 0.0
var _work_key: String = ""
var _work_tick: float = 0.0
var _denied_key: String = ""
var _sfx: AudioStreamPlayer
var _tex_poor: Texture2D
var _tex_broken: Texture2D
var _active: bool = false


func setup(world: Node3D, building_manager: Node, camera_getter: Callable, hud: Node) -> void:
	_world = world
	_building_manager = building_manager
	_camera_getter = camera_getter
	_hud = hud
	if _markers_root == null or not is_instance_valid(_markers_root):
		_markers_root = Node3D.new()
		_markers_root.name = "UpkeepSigns"
		_world.add_child(_markers_root)
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		_sfx.volume_db = -8.0
		add_child(_sfx)
	if _tex_poor == null:
		_tex_poor = _make_sign_texture(Color(1.0, 0.72, 0.18), Color(0.12, 0.08, 0.04))
		_tex_broken = _make_sign_texture(Color(0.92, 0.14, 0.10), Color(1.0, 0.95, 0.85))
	var failed_cb := Callable(self, "_on_building_failed")
	if not EventBus.building_failed.is_connected(failed_cb):
		EventBus.building_failed.connect(failed_cb)
	var serviced_cb := Callable(self, "_on_building_serviced")
	if not EventBus.building_serviced.is_connected(serviced_cb):
		EventBus.building_serviced.connect(serviced_cb)
	_active = true
	_sync_t = 0.0


func stop() -> void:
	_active = false
	_reset_work()
	for key in _markers.keys():
		var m = _markers[key]
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	_conditions_shown.clear()


## Called every gameplay frame. `can_act`: first-person, no interior or menu open.
func tick(delta: float, can_act: bool) -> void:
	if not _active:
		return
	_blink_t += delta
	_sync_t -= delta
	if _sync_t <= 0.0:
		_sync_t = SYNC_EVERY
		_sync_world()
	_update_sign_blink()
	_target = _find_target() if can_act else {}
	_update_work(delta, can_act)


## Hint fragment for the building under the crosshair ("" when nothing is targeted).
## `has_other_hint`: the line already names the building (e.g. "[E] Enter Toilet").
func hint_for_view(has_other_hint: bool) -> String:
	if _target.is_empty():
		return ""
	var broken: bool = _target["broken"]
	var condition: float = _target["condition"]
	var parts: Array[String] = []
	if not has_other_hint:
		parts.append("%s %d%%" % [str(_target["label"]), int(round(condition * 100.0))])
	if broken and str(_target["type"]) == "sewer":
		# A broken sewer is fixed from the inside (the pipe crawl).
		parts.append("BROKEN - [E] go down and fix it")
	elif broken and str(_target["type"]) == "lamp_post":
		parts.append("[R] New bulb $%d" % int(_target["cost"]))
	elif broken:
		parts.append("[R] Repair $%d" % int(_target["cost"]))
	elif condition < 0.9:
		parts.append("[R] Service $%d" % int(_target["cost"]))
	elif has_other_hint:
		return ""
	return "   ".join(parts)


# ── world sync ────────────────────────────────────────────────────────────────

func _sync_world() -> void:
	var state = CoreRoot.get_state()
	if state == null or state.grid == null or _building_manager == null:
		return
	_clear_old_wear(state)
	var seen := {}
	for row in _wear_rows():
		var key := str(row["key"])
		var structure: Node3D = row["structure"]
		if structure == null:
			continue
		seen[key] = true
		var condition: float = row["condition"]
		var broken: bool = row["broken"]
		var shown := 0.0 if broken else condition
		if absf(float(_conditions_shown.get(key, -1.0)) - shown) > 0.02:
			_conditions_shown[key] = shown
			if str(row["type"]) == "lamp_post":
				# A lamp shows its wear in its light, not in rust.
				if _building_manager.has_method("set_lamp_wear"):
					_building_manager.set_lamp_wear(key, RULES.lamp_brightness(shown))
			elif _building_manager.has_method("set_structure_condition"):
				_building_manager.set_structure_condition(structure, shown)
		# Only a dead lamp (or the derelict cabin) gets the blinking sign.
		_set_sign(key, "broken" if broken else "", structure)
	for key in _markers.keys():
		if not seen.has(key):
			_set_sign(key, "", null)
	for key in _conditions_shown.keys():
		if not seen.has(key):
			_conditions_shown.erase(key)


## What can be mended: every lamp (on its own tile or on a path) and the derelict cabin.
## [{key, coord, type, def, condition, broken, structure}].
func _wear_rows() -> Array:
	var out: Array = []
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return out
	var lamp_def = CoreRoot.registry.get_def(&"lamp_post")
	var lamps := {}
	for n in get_tree().get_nodes_in_group("lamp_posts"):
		var l := n as Node3D
		if l != null and l.has_meta("grid_origin"):
			var o: Vector2i = l.get_meta("grid_origin")
			lamps["%d:%d" % [o.x, o.y]] = l
	for coord in state.grid.lamp_coords():
		var key := "%d:%d" % [coord.x, coord.y]
		out.append({"key": key, "coord": coord, "type": "lamp_post", "def": lamp_def,
			"condition": RULES.lamp_condition(state.grid.cells[coord]), "broken": state.failures.has(key), "structure": lamps.get(key, null)})
	var structures := _structures_by_key()
	for key in state.failures.keys():
		var f: Dictionary = state.failures[key]
		if not bool(f.get("derelict", false)):
			continue
		var coord: Vector2i = f.get("coord", Vector2i.ZERO)
		var cell: Dictionary = state.grid.cells.get(coord, {})
		var type := str(cell.get("type", f.get("type", "")))
		out.append({"key": str(key), "coord": coord, "type": type, "def": CoreRoot.registry.get_def(StringName(type)),
			"condition": float(cell.get("maintenance", 0.2)), "broken": true, "structure": structures.get(str(key), null)})
	return out


## Old saves: buildings worn or broken from before only the lamps wore go back to whole
## (a derelict building stays as it is: that one is mended by hand).
func _clear_old_wear(state) -> void:
	var lamp_keys := {}
	for coord in state.grid.lamp_coords():
		lamp_keys["%d:%d" % [coord.x, coord.y]] = true
	for key in state.failures.keys():
		var f: Dictionary = state.failures[key]
		if lamp_keys.has(str(key)) or bool(f.get("derelict", false)):
			continue
		CoreRoot.actions.clear_wear(f.get("coord", Vector2i.ZERO))
		var s: Node3D = _structures_by_key().get(str(key), null)
		if s != null and _building_manager.has_method("set_structure_condition"):
			_building_manager.set_structure_condition(s, 1.0)
	for coord_any in state.grid.cells.keys():
		var coord: Vector2i = coord_any
		var cell: Dictionary = state.grid.cells[coord]
		if cell.get("root_coord", coord) != coord or str(cell.get("type", "")) == "lamp_post":
			continue
		if float(cell.get("maintenance", 1.0)) < 1.0 and not state.failures.has("%d:%d" % [coord.x, coord.y]):
			CoreRoot.actions.clear_wear(coord)
			var s2: Node3D = _structures_by_key().get("%d:%d" % [coord.x, coord.y], null)
			if s2 != null and _building_manager.has_method("set_structure_condition"):
				_building_manager.set_structure_condition(s2, 1.0)


func _structures_by_key() -> Dictionary:
	var out := {}
	var root = _building_manager.get_node_or_null("Structures")
	if root == null:
		return out
	for child in root.get_children():
		var s := child as Node3D
		if s == null or not s.has_meta("grid_origin"):
			continue
		var origin: Vector2i = s.get_meta("grid_origin")
		out["%d:%d" % [origin.x, origin.y]] = s
	return out


func _set_sign(key: String, kind: String, structure: Node3D) -> void:
	var existing: Sprite3D = _markers.get(key, null)
	if kind.is_empty():
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		_markers.erase(key)
		return
	if existing == null or not is_instance_valid(existing):
		existing = Sprite3D.new()
		existing.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		existing.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		existing.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		existing.shaded = false
		existing.pixel_size = SIGN_PIXEL_SIZE
		_markers_root.add_child(existing)
		_markers[key] = existing
		existing.global_position = _sign_anchor(structure)
		existing.set_meta("base_y", existing.global_position.y)
	existing.texture = _tex_broken if kind == "broken" else _tex_poor
	existing.set_meta("kind", kind)


## Just above the structure's top, centred on its footprint.
func _sign_anchor(structure: Node3D) -> Vector3:
	var top := structure.global_position.y + 3.0
	var aabb := _world_aabb(structure)
	if aabb.size != Vector3.ZERO:
		top = aabb.end.y
		return Vector3(aabb.get_center().x, top + 0.7, aabb.get_center().z)
	return structure.global_position + Vector3(0.0, 3.6, 0.0)


func _world_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [node]
	while not stack.is_empty():
		var n = stack.pop_back()
		var vi := n as VisualInstance3D
		if vi != null and not (vi is Sprite3D):
			var box: AABB = vi.global_transform * vi.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in n.get_children():
			stack.append(c)
	return out


func _update_sign_blink() -> void:
	for key in _markers.keys():
		var m: Sprite3D = _markers[key]
		if not is_instance_valid(m):
			continue
		var broken := str(m.get_meta("kind", "")) == "broken"
		m.visible = not broken or fmod(_blink_t, 1.0) < 0.7
		var bob := sin(_blink_t * 2.2 + float(key.hash() % 7)) * 0.08 if broken else 0.0
		m.global_position.y = float(m.get_meta("base_y", m.global_position.y)) + bob


# ── targeting + work ──────────────────────────────────────────────────────────

func _find_target() -> Dictionary:
	var cam: Camera3D = _camera_getter.call() if _camera_getter.is_valid() else null
	if cam == null or not is_instance_valid(cam):
		return {}
	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z.normalized()
	var best := {}
	var best_score := INF
	for row in _wear_rows():
		var s: Node3D = row["structure"]
		if s == null or not is_instance_valid(s):
			continue
		var lamp: bool = str(row["type"]) == "lamp_post"
		var footprint: Vector2i = s.get_meta("grid_footprint", Vector2i.ONE)
		var reach := VIEW_DISTANCE + (0.0 if lamp else float(maxi(footprint.x, footprint.y)) * 0.9)
		var center := s.global_position + Vector3(0.0, 1.4 if lamp else 1.0, 0.0)
		var to := center - origin
		var dist := to.length()
		if dist > reach or dist < 0.01:
			continue
		var dot := (to / dist).dot(forward)
		if dot < VIEW_DOT:
			continue
		var score := dist * (2.0 - dot)
		if score < best_score:
			best_score = score
			var def = row["def"]
			var condition: float = row["condition"]
			var broken: bool = row["broken"]
			best = {
				"key": str(row["key"]), "coord": row["coord"], "type": str(row["type"]),
				"label": str(def.display_name).split(" (")[0] if def != null else str(row["type"]).capitalize(),
				"condition": condition, "broken": broken,
				"cost": RULES.repair_cost(def) if broken else RULES.service_cost(def, condition),
				"seconds": RULES.work_seconds(condition, broken),
			}
	return best


func _update_work(delta: float, can_act: bool) -> void:
	var held := can_act and InputMap.has_action("maintain") and Input.is_action_pressed("maintain")
	var workable := not _target.is_empty() and (bool(_target["broken"]) or float(_target["condition"]) < 0.9)
	if workable and bool(_target["broken"]) and str(_target["type"]) == "sewer":
		workable = false
	if workable and CLEANED_INSIDE.has(str(_target["type"])):
		workable = false
	if not held or not workable:
		if not held:
			_denied_key = ""
		_reset_work()
		return
	var key := str(_target["key"])
	if key != _work_key:
		_reset_work()
		_work_key = key
	if CoreRoot.get_money() < int(_target["cost"]):
		if _denied_key != key and _hud != null:
			_denied_key = key
			_hud.push_status("Not enough cash: the %s needs $%d." % [str(_target["label"]).to_lower(), int(_target["cost"])], 3)
		_reset_work()
		return
	_work += delta / maxf(0.1, float(_target["seconds"]))
	_work_tick -= delta
	if _work_tick <= 0.0:
		_work_tick = 0.32
		_play(SFX_WORK, randf_range(0.55, 0.7))
	if _hud != null and _hud.has_method("set_work_progress"):
		var verb := "REPAIRING" if bool(_target["broken"]) else "SERVICING"
		_hud.set_work_progress("%s %s" % [verb, str(_target["label"]).to_upper()], _work)
	if _work >= 1.0:
		var target := _target.duplicate()
		_reset_work()
		_denied_key = key
		# Co-op: mended in the host's camp (it comes back as a fact).
		if Coop.is_client():
			Coop.send_request("service", [target["coord"], int(target["cost"])])
		else:
			CoreRoot.actions.service_building(target["coord"], int(target["cost"]))


func _reset_work() -> void:
	# Only take the bar (and the hand) down if this was what put it up: the day's
	# chores use the same HUD bar.
	var was_working := _work > 0.0 or _work_key != ""
	_work = 0.0
	_work_key = ""
	_work_tick = 0.0
	if was_working and _hud != null and _hud.has_method("clear_work_progress"):
		_hud.clear_work_progress()


# ── events ────────────────────────────────────────────────────────────────────

func _on_building_failed(coord: Vector2i, building_type: String) -> void:
	_sync_t = 0.0
	if _active and _hud != null:
		_hud.push_status("The %s broke down." % _label_for(building_type).to_lower(), 2)


func _on_building_serviced(_coord: Vector2i, building_type: String, was_broken: bool, cost: int) -> void:
	_sync_t = 0.0
	if not _active or _hud == null:
		return
	if was_broken:
		_play(SFX_DONE, 1.0)
		_hud.push_status("%s repaired. -$%d" % [_label_for(building_type), cost], 1)
	else:
		_play(SFX_WORK, 1.2)
		_hud.push_status("%s serviced. -$%d" % [_label_for(building_type), cost], 1)


func _label_for(type: String) -> String:
	var def = CoreRoot.registry.get_def(StringName(type)) if CoreRoot != null else null
	return str(def.display_name).split(" (")[0] if def != null else type.capitalize()


func _play(path: String, pitch: float) -> void:
	if _sfx == null or not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.pitch_scale = pitch
	_sfx.play()


# ── terminal (Camp Status > Upkeep) ───────────────────────────────────────────

## Every building that can wear, worst first.
func get_upkeep_snapshot() -> Dictionary:
	var rows: Array = []
	var crew_cost := 0
	var needs_crew := 0
	for row in _wear_rows():
		var def = row["def"]
		var condition: float = row["condition"]
		var broken: bool = row["broken"]
		var cost := RULES.repair_cost(def) if broken else RULES.service_cost(def, condition)
		rows.append({
			"key": str(row["key"]), "coord": row["coord"], "type": str(row["type"]),
			"label": str(def.display_name).split(" (")[0] if def != null else str(row["type"]),
			"condition": condition, "broken": broken, "cost": cost,
			"decay": float(def.maintenance_decay) if def != null else 0.0,
		})
		if broken or condition < RULES.WORN_CONDITION:
			crew_cost += int(ceil(float(cost) * RULES.CREW_PREMIUM))
			needs_crew += 1
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["broken"]) != bool(b["broken"]):
			return bool(a["broken"])
		return float(a["condition"]) < float(b["condition"])
	)
	return {"rows": rows, "crew_cost": crew_cost, "crew_jobs": needs_crew, "night": CoreRoot.is_night()}


## The crew services everything worn and repairs everything broken, at a premium.
## They do not come out at night.
func request_maintenance_crew() -> Dictionary:
	var snap := get_upkeep_snapshot()
	if bool(snap["night"]):
		return {"ok": false, "reason": "night"}
	if int(snap["crew_jobs"]) <= 0:
		return {"ok": false, "reason": "nothing_to_do"}
	var total := int(snap["crew_cost"])
	if CoreRoot.get_money() < total:
		return {"ok": false, "reason": "insufficient_funds", "amount": total}
	var done := 0
	for row_any in snap["rows"]:
		var row: Dictionary = row_any
		if not bool(row["broken"]) and float(row["condition"]) >= RULES.WORN_CONDITION:
			continue
		if CoreRoot.actions.service_building(row["coord"], int(ceil(float(row["cost"]) * RULES.CREW_PREMIUM))):
			done += 1
	return {"ok": done > 0, "jobs": done, "amount": total}


# ── art ───────────────────────────────────────────────────────────────────────

## 13x12 hazard triangle with an exclamation mark, dark outline. Drawn in code so the
## sign stays on the same pixel grid as everything else.
func _make_sign_texture(fill: Color, ink: Color) -> Texture2D:
	var w := 13
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color(0.06, 0.04, 0.03, 1.0)
	for y in h:
		var half := int(floor(float(y) * 0.5)) + 1
		for x in range(6 - half, 6 + half + 1):
			if x < 0 or x >= w:
				continue
			var edge := x == 6 - half or x == 6 + half or y == h - 1
			img.set_pixel(x, y, outline if edge else fill)
	for y in [3, 4, 5, 6, 7]:
		img.set_pixel(6, y, ink)
	img.set_pixel(6, 9, ink)
	return ImageTexture.create_from_image(img)
