extends Node3D

## The camp's lodgings lived in after dark (made by weather_visuals.gd in the camp's world,
## like the world sounds; the inventory of 20. 10. found the camp looking empty after
## 20:00, every cabin dark with its guests in it):
##   - a cabin with its guests in and awake glows at its windows: its red curtains lit by
##     a lamp behind them (Grok camp/window_lit.png, the day's window_curtain.png at
##     night), or in one cabin in three the telly (window_tv.png), its blue flickering
##     in steps; a caravan's curtains glow orange; the light lies on the grass in front;
##   - a tent with its guests in glows through the canvas, a lantern inside;
##   - the guests are abed from 20:00 for the simulation, but each lodging puts its light
##     out at its own time between 21:00 and 23:30; now and then one lights again round
##     three in the morning for a few minutes, somebody up; before the dawn some are up
##     early;
##   - the power off, the cabins and caravans have candles (dim, flickering), the tents
##     their lanterns as ever.
## The same lodgings light on every machine in co-op: the times come from the lodging and
## the day, the guests from the host's pulse. Stepped, twelve a second.

const FPS := 12.0
const WINDOW_LIT := "res://assets/textury/camp/window_lit.png"
const WINDOW_TV := "res://assets/textury/camp/window_tv.png"
const LAMP := Color(1.0, 0.72, 0.42)
## A window picture lit already has the lamp's colour in it.
const LIT_TINT := Color(1.0, 0.92, 0.8)
const CANDLE := Color(1.0, 0.6, 0.3)
const TV := Color(0.55, 0.7, 1.0)
## How dark it must be (the day's light, weather_visuals.compute_daylight_factor()).
const DARK_BELOW := 0.38

var player_getter: Callable

## key "x:y" -> {root, kind, windows: [MeshInstance3D], cloth, front: Vector3 (local),
## light: OmniLight3D, on: bool, tv: bool}
var _lodgings: Dictionary = {}
var _scan_t := 0.0
var _poll_t := 0.0
var _acc := 0.0
var _step := 0
var _in: Dictionary = {}             # key -> true: guests in the lodging (awake or abed)
var _tex_lit: Texture2D
var _tex_tv: Texture2D


func _ready() -> void:
	name = "WindowLights"
	_tex_lit = load(WINDOW_LIT) if ResourceLoader.exists(WINDOW_LIT) else null
	_tex_tv = load(WINDOW_TV) if ResourceLoader.exists(WINDOW_TV) else null


func _process(delta: float) -> void:
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 3.0
		_scan()
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0
		_poll_guests()
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	_step += 1
	_update()


# ── the lodgings ─────────────────────────────────────────────────────────────

func _scan() -> void:
	var main := get_tree().current_scene
	var bm = main.get("building_manager") if main != null else null
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures == null:
		return
	var seen := {}
	for c in structures.get_children():
		var t := str(c.get_meta("building_type", ""))
		var kind := ""
		if t.begins_with("cabin"):
			kind = "cabin"
		elif t.begins_with("caravan"):
			kind = "caravan"
		elif t.begins_with("tent"):
			kind = "tent"
		if kind == "" or not (c is Node3D):
			continue
		var origin = c.get_meta("grid_origin", null)
		if not (origin is Vector2i):
			continue
		var key := "%d:%d" % [origin.x, origin.y]
		seen[key] = true
		var rec: Dictionary = _lodgings.get(key, {})
		if not rec.is_empty() and is_instance_valid(rec["root"]) and rec["root"] == c:
			continue
		if not rec.is_empty():
			_drop(rec)
		_lodgings[key] = _make(c as Node3D, kind)
	for key in _lodgings.keys():
		if not seen.has(key):
			_drop(_lodgings[key])
			_lodgings.erase(key)


func _make(root: Node3D, kind: String) -> Dictionary:
	var rec := {"root": root, "kind": kind, "windows": [], "cloth": null, "on": false, "tv": false, "light": null}
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var bb := root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
		# The panes (building_models.gd marks them; their names repeat, so Godot renames all
		# but the first).
		if kind != "tent" and mi.has_meta("lit_window"):
			_own_material(mi)
			(rec["windows"] as Array).append(mi)
	if kind == "tent":
		# The canvas: the biggest mesh straight under the tent (pegs and ropes are small).
		var best: MeshInstance3D = null
		var best_v := 0.0
		for m2 in root.get_children():
			var mi2 := m2 as MeshInstance3D
			if mi2 == null or mi2.mesh == null:
				continue
			var v := mi2.get_aabb().get_volume()
			if v > best_v:
				best_v = v
				best = mi2
		if best != null:
			_own_material(best)
			rec["cloth"] = best
	rec["front"] = Vector3(box.get_center().x, 0.0, box.end.z) if not first else Vector3(0, 0, 1.5)
	return rec


## A material of its own on `mi` (windows of one kind share theirs), its glow ready and off
## (switching emission on later would make the PS1 surfaces build another shader: a pop).
func _own_material(mi: MeshInstance3D) -> void:
	if mi.has_meta("wl_mat"):
		return
	var src := mi.material_override as StandardMaterial3D
	if src == null:
		src = mi.get_active_material(0) as StandardMaterial3D
	if src == null:
		return
	var m := src.duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = LAMP
	m.emission_energy_multiplier = 0.0
	if m.emission_texture == null:
		m.emission_texture = m.albedo_texture
	mi.material_override = m
	mi.set_meta("wl_mat", m)


func _drop(rec: Dictionary) -> void:
	var l = rec.get("light", null)
	if l != null and is_instance_valid(l):
		(l as Node).queue_free()


# ── who is in ────────────────────────────────────────────────────────────────

func _poll_guests() -> void:
	_in.clear()
	if GuestManager == null or not GuestManager.has_method("get_guest_life_snapshot"):
		return
	for g in GuestManager.get_guest_life_snapshot():
		var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
		var kind := str(act.get("kind", ""))
		if kind != "rest" and kind != "sleep":
			continue
		var at = g.get("lodging", null)
		if at is Vector2i and (at as Vector2i).x >= 0:
			_in["%d:%d" % [at.x, at.y]] = true


## 0..1 from the lodging and the day, the same on every machine.
static func _dice(key: String, day: int, salt: int) -> float:
	return float(absi(hash("%s/%d/%d" % [key, day, salt])) % 10000) / 10000.0


## Whether the lodging at `key` has its light on at `hour` of `day` (its guests in).
static func lit_at(key: String, day: int, hour: float) -> bool:
	if hour >= 12.0:
		# The evening: out at the lodging's own bedtime, 21:00 to 23:30.
		return hour < 21.0 + 2.5 * _dice(key, day, 1)
	# After midnight it belongs to the evening before.
	var night := day - 1
	if _dice(key, night, 2) < 0.18:
		var start := 2.5 + 1.2 * _dice(key, night, 3)
		if hour >= start and hour < start + (6.0 + 8.0 * _dice(key, night, 4)) / 60.0:
			return true
	# Up early, before the light: some lodgings from 5:45.
	if _dice(key, day, 5) < 0.45:
		return hour >= 5.75 + 0.75 * _dice(key, day, 6)
	return false


# ── drawing ──────────────────────────────────────────────────────────────────

## Builder 98's map lights the same windows (crt_map_panel.gd): {} when the lodging at
## `key` ("x:y") is dark, else {tv, candle}.
func lit_state(key: String) -> Dictionary:
	var rec: Dictionary = _lodgings.get(key, {})
	if rec.is_empty() or not bool(rec.get("on", false)):
		return {}
	return {"tv": bool(rec.get("tv", false)), "candle": bool(rec.get("candle", false)), "kind": str(rec.get("kind", ""))}


func _update() -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var hour: float = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 12.0
	var day: int = int(main.get("_day_index")) if main.get("_day_index") != null else 1
	var wv = main.get("_weather_visuals")
	var daylight := float(wv.compute_daylight_factor()) if wv != null and wv.has_method("compute_daylight_factor") else 1.0
	var dark := daylight < DARK_BELOW
	var powered: bool = not main.has_method("_is_grid_powered") or bool(main.call("_is_grid_powered"))
	for key in _lodgings:
		var rec: Dictionary = _lodgings[key]
		if not is_instance_valid(rec["root"]):
			continue
		var on := dark and _in.has(key) and lit_at(str(key), day, hour)
		var tv := str(rec["kind"]) == "cabin" and powered and hour >= 12.0 and _dice(str(key), day, 7) < 0.33
		_show(rec, on, tv, powered)


func _show(rec: Dictionary, on: bool, tv: bool, powered: bool) -> void:
	var kind := str(rec["kind"])
	var candle := not powered and kind != "tent"
	var salt := absi(hash(rec["root"].get_instance_id()))
	var col := LAMP
	# (A caravan's window is mostly grey glass: it takes more to read lit from the path.)
	var energy := 2.0
	# The picture that glows: a cabin's window lit (or the telly), else the window's own.
	var pic: Texture2D = null
	if kind == "cabin":
		pic = _tex_tv if tv and _tex_tv != null else _tex_lit
		col = LIT_TINT
		energy = 1.6
	if kind == "tent":
		energy = 0.45
	elif candle:
		col = CANDLE if pic == null else LIT_TINT * CANDLE
		# A candle's flame, in steps.
		energy = 0.55 + 0.2 * float((_step * 7 + salt) % 3) / 2.0
	elif tv:
		# The picture changing on the screen: its light in steps of a few frames each.
		col = TV.lerp(Color(0.9, 0.92, 1.0), float((_step / 3 + salt) % 4) / 3.0)
		energy = 1.0 + 0.6 * float((_step / 2 + salt) % 3) / 2.0
	var amount := energy if on else 0.0
	for w in rec["windows"]:
		var mi := w as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var m := mi.get_meta("wl_mat", null) as StandardMaterial3D
		if m == null:
			continue
		var want: Texture2D = pic if pic != null else m.albedo_texture
		if on and m.emission_texture != want:
			m.emission_texture = want
		m.emission = col
		m.emission_energy_multiplier = amount
	var cloth: MeshInstance3D = rec.get("cloth", null)
	if cloth != null and is_instance_valid(cloth):
		var cm := cloth.get_meta("wl_mat", null) as StandardMaterial3D
		if cm != null:
			cm.emission = col
			cm.emission_energy_multiplier = amount
	# The light on the ground in front of the door.
	var light: OmniLight3D = rec.get("light", null)
	if on and (light == null or not is_instance_valid(light)):
		light = OmniLight3D.new()
		light.name = "WindowLight"
		light.shadow_enabled = false
		light.omni_range = 3.2 if kind == "tent" else 4.8
		light.omni_attenuation = 1.3
		var root: Node3D = rec["root"]
		root.add_child(light)
		light.position = (rec["front"] as Vector3) + Vector3(0, 0.8 if kind == "tent" else 1.2, 0.7)
		rec["light"] = light
	if light != null and is_instance_valid(light):
		light.visible = on
		light.light_color = LAMP if col == LIT_TINT else (CANDLE if candle else col)
		light.light_energy = amount * (0.55 if kind == "tent" else 0.7)
	rec["on"] = on
	rec["tv"] = tv and not candle
	rec["candle"] = candle
