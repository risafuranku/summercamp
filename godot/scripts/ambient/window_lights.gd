extends Node3D

## The camp's lodgings lived in after dark (made by weather_visuals.gd in the camp's world,
## like the world sounds; the inventory of 20. 10. found the camp looking empty after
## 20:00, every cabin dark with its guests in it):
##   - a cabin with its guests in and awake glows at its windows, and through them you see
##     into the room (materials/window_room.gdshader: interior mapping, the room's walls,
##     floor and ceiling behind the glass in depth that moves as you walk by, its things
##     half way in, the lamp in steps, the curtains drawn in at the sides and lit through;
##     the user 20. 10.: the lit windows were a flat picture of a window); in one cabin in
##     three the telly, its blue flickering in steps; a caravan the same, its own room;
##     the light lies on the grass in front;
##   - a tent with its guests in glows through the canvas, a lantern inside;
##   - the guests are abed from 20:00 for the simulation, but each lodging puts its light
##     out at its own time between 21:00 and 23:30; now and then one lights again round
##     three in the morning for a few minutes, somebody up; before the dawn some are up
##     early;
##   - the power off, the cabins and caravans have candles (dim, flickering), the tents
##     their lanterns as ever.
## The same lodgings light on every machine in co-op: the times come from the lodging and
## the day, the guests from the host's pulse. Stepped, twelve a second.
##
## They do not like being looked at (the user 5. 11., "as the pigs in Don't Starve put their
## lights out when you come near"): some lodgings pull their curtains for the night at their
## own time, a window after a window; come up to a lit cabin or caravan to spy and they all
## do, quickly; go away and somebody draws them again, a little less likely each time, till
## they stay shut till the morning. Each pane its own (window_cube's `shut`). A tent has no
## curtain: it puts its light out when you come near and pretends to sleep. Behind the
## windows somebody moves about now and then, their shape on the curtain or against the
## lamp (`figure`), and now and then a curtain lifts at a corner while you stand there.
## Each machine by its own warden: a thing of the eye, nothing in the books.

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
const ROOM_SHADER = preload("res://materials/window_room.gdshader")
## A cabin's or a van's panes from its room drawn into a cube (scripts/ui/room_cube.gd, the
## user 4. 11.: the interiors seen through the windows from far off, day and night, no pop
## as you come near): once its room is drawn, the panes are that, lit as the hour has it.
const ROOM_CUBE = preload("res://scripts/ui/room_cube.gd")
## By day the room is darker than the day outside (as the live view's, window_into).
const DAY_ROOM := 0.62
const MOON := Color(0.42, 0.5, 0.66)
## How near you must come for them to mind, from the middle of the lodging (m), and how far
## away to be gone. How far from you anybody is seen moving at all.
const SPY_NEAR := {"cabin": 8.5, "caravan": 7.5, "tent": 6.5}
const SPY_GONE := 4.5
const LIFE_WITHIN := 46.0
## A share of the lodgings draws them for the night anyway; from when, over how long.
const DRAW_SHARE := 0.42
const DRAW_FROM := 19.5
const DRAW_OVER := 2.2
## The chance they draw them again once you have gone, the first time, the second...: then
## they stay shut. Seconds after you went, somebody gets up.
const REOPEN := [0.9, 0.75, 0.4, 0.0]
const REOPEN_AFTER := Vector2(3.0, 9.0)
## A hand along the rod: a share of the way a second; the next window after this long (s),
## in a hurry or at leisure.
const PULL_SPEED := 1.7
const PULL_GAP_QUICK := Vector2(0.35, 0.8)
const PULL_GAP := Vector2(1.6, 4.5)
## Somebody crossing the room: the wait (s), how long it takes, how tall against the pane.
const WALK_EVERY := Vector2(5.0, 19.0)
const WALK_SEC := Vector2(1.5, 3.6)
const FIGURE_H := 2.1
const FIGURE_DARK := 0.74
## A curtain lifted at the corner while you stand there: the wait, how far, how long.
const PEEK_EVERY := Vector2(7.0, 18.0)
const PEEK_OPEN := 0.8
const PEEK_SEC := 1.3
const SFX_SHUT := preload("res://assets/sfx/backroom/curtain_shut.mp3")
const SFX_OPEN := preload("res://assets/sfx/backroom/curtain_open.mp3")
const FIGURE_TEX := preload("res://assets/textury/npc/host1.png")
const CAMP := "res://assets/textury/camp/"
## The room seen through a lit window, by kind: textures, depth, width, height, and how
## high its floor is over the ground outside.
const ROOMS := {
	"cabin": {"wall": "knotty_pine", "floor": "parquet", "ceil": "ceiling_pine", "curtain": "curtain_floral", "props": "window_room_cabin", "props_h": 1.85,
		"depth": 2.6, "w": 2.8, "h": 2.35, "floor_up": 0.12},
	"caravan": {"wall": "wallpaper_70s", "floor": "formica", "ceil": "ceiling_board", "curtain": "curtain_floral", "props": "window_room_caravan", "props_h": 1.05,
		"depth": 1.8, "w": 2.1, "h": 1.95, "floor_up": 0.5},
}

var player_getter: Callable

## key "x:y" -> {root, kind, windows: [MeshInstance3D], cloth, front: Vector3 (local),
## light: OmniLight3D, on: bool, tv: bool}
var _lodgings: Dictionary = {}
var _scan_t := 0.0
var _poll_t := 0.0
var _acc := 0.0
var _step := 0
var _in: Dictionary = {}             # key -> true: guests in the lodging (awake or abed)
var _forced: Dictionary = {}         # key -> "on" / "off": lit or dark whatever the hour (set_forced)
var _tex_lit: Texture2D
var _tex_tv: Texture2D
var _pull_snd: AudioStreamPlayer3D
var _clock := 0.0


func _ready() -> void:
	name = "WindowLights"
	_pull_snd = AudioStreamPlayer3D.new()
	_pull_snd.name = "CurtainPull"
	_pull_snd.unit_size = 3.0
	_pull_snd.max_distance = 24.0
	_pull_snd.volume_db = -16.0
	add_child(_pull_snd)
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
	_clock += delta
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
	# Looked into right now (caravan_interior): its own glass is the one it gives back.
	var src := (mi.get_meta("inview_was") if mi.has_meta("inview_was") else mi.material_override) as StandardMaterial3D
	if src == null:
		src = mi.get_active_material(0) as StandardMaterial3D
	if src == null:
		return
	var m := src.duplicate() as StandardMaterial3D
	_room_material(mi)
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission = LAMP
	m.emission_energy_multiplier = 0.0
	if m.emission_texture == null:
		m.emission_texture = m.albedo_texture
	if mi.has_meta("inview_was"):
		mi.set_meta("inview_was", m)
	else:
		mi.material_override = m
	mi.set_meta("wl_mat", m)


## The room behind a pane (a lodging's window): its own interior-mapping material, ready
## for when the window is lit.
func _room_material(mi: MeshInstance3D) -> void:
	var root := mi.get_parent()
	while root != null and not root.has_meta("building_type"):
		root = root.get_parent()
	if root == null or not (mi.mesh is QuadMesh):
		return
	var t := str(root.get_meta("building_type", ""))
	var kind := "cabin" if t.begins_with("cabin") else ("caravan" if t.begins_with("caravan") else "")
	if kind == "":
		return
	var spec: Dictionary = ROOMS[kind]
	var sm := ShaderMaterial.new()
	sm.shader = ROOM_SHADER
	for slot in [["wall_tex", "wall"], ["floor_tex", "floor"], ["ceil_tex", "ceil"], ["curtain_tex", "curtain"]]:
		var path: String = CAMP + str(spec[slot[1]]) + ".png"
		if ResourceLoader.exists(path):
			sm.set_shader_parameter(slot[0], load(path))
	var props: String = CAMP + str(spec["props"]) + ".png"
	sm.set_shader_parameter("has_props", ResourceLoader.exists(props))
	if ResourceLoader.exists(props):
		var pt: Texture2D = load(props)
		sm.set_shader_parameter("props", pt)
		# As tall as its tallest thing (the wardrobe, the cupboard), as wide as the picture says.
		var tall := float(spec["props_h"])
		sm.set_shader_parameter("props_size", Vector2(tall * float(pt.get_width()) / float(maxi(1, pt.get_height())), tall))
	var size: Vector2 = (mi.mesh as QuadMesh).size
	sm.set_shader_parameter("pane", size)
	sm.set_shader_parameter("depth", float(spec["depth"]))
	sm.set_shader_parameter("room_w", float(spec["w"]))
	sm.set_shader_parameter("room_h", float(spec["h"]))
	var over_ground: float = mi.global_position.y - (root as Node3D).global_position.y
	sm.set_shader_parameter("sill", clampf(over_ground - float(spec["floor_up"]), 0.6, float(spec["h"]) - 0.4))
	# Each window its own way into the room: the things stand a little to one side or the other.
	sm.set_shader_parameter("props_x", float(absi(hash(mi.get_instance_id())) % 5 - 2) * 0.25)
	mi.set_meta("wl_room", sm)


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

## The lodging at `key` lit ("on") or dark ("off") whatever its guests' hour; "" lets it be.
func set_forced(key: String, state: String) -> void:
	if state == "":
		_forced.erase(key)
	else:
		_forced[key] = state
	# (Not while the world is being taken down: the night's brains let go of theirs then.)
	if is_inside_tree():
		_update()


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
		# Something at the door in the night (scripts/enemies/basket_brain.gd): they woke
		# and put the light on, then it went out.
		var forced := str(_forced.get(key, ""))
		if forced != "":
			on = dark and forced == "on"
		var tv := str(rec["kind"]) == "cabin" and powered and hour >= 12.0 and _dice(str(key), day, 7) < 0.33 and forced == ""
		_watched(rec, str(key), on, dark, hour, day, main)
		# A tent has no curtain: its light is out while you are about.
		if str(rec["kind"]) == "tent" and bool(rec.get("hiding", false)):
			on = false
		_show(rec, on, tv, powered, dark, hour)
		_life(rec, on, main)


# ── being looked at ──────────────────────────────────────────────────────────

## This lodging's night: whether it wants its curtains pulled now, you near or not.
func _watched(rec: Dictionary, key: String, lit: bool, dark: bool, hour: float, day: int, main: Node) -> void:
	var night := day if hour >= 12.0 else day - 1
	if int(rec.get("night", -9)) != night:
		rec["night"] = night
		rec["spied"] = 0
		rec["stay"] = false
		rec["near"] = false
		rec["back_at"] = -1.0
		rec["hiding"] = false
	var near := bool(rec.get("near", false))
	var d := _from_you(rec, main)
	var at: float = float(SPY_NEAR.get(str(rec["kind"]), 8.0))
	if lit and not near and d < at:
		near = true
		rec["spied"] = int(rec["spied"]) + 1
		rec["back_at"] = -1.0
	elif near and (d > at + SPY_GONE or not lit):
		near = false
		var n := mini(int(rec["spied"]) - 1, REOPEN.size() - 1)
		if randf() >= float(REOPEN[n]):
			rec["stay"] = true
		rec["back_at"] = _clock + randf_range(REOPEN_AFTER.x, REOPEN_AFTER.y)
	rec["near"] = near
	var evening: bool = str(rec["kind"]) != "tent" and _dice(key, night, 20) < DRAW_SHARE and _past(hour, DRAW_FROM + DRAW_OVER * _dice(key, night, 21))
	var hide: bool = dark and (near or bool(rec["stay"]) or evening or _clock < float(rec["back_at"]))
	if str(rec["kind"]) == "tent":
		rec["hiding"] = hide
		return
	_pull(rec, hide, near)
	_tick_panes(rec, near)
	# Near, the room itself stands behind the glass: its own curtains go with the panes.
	if _in.has(key) or bool(rec.get("pulled", false)):
		var im = main.get("_interior_manager")
		var room = im.get("_cabin_interior" if str(rec["kind"]) == "cabin" else "_caravan_interior") if im != null else null
		if room != null and room.has_method("guest_curtains"):
			var shuts: Array = []
			for w in rec["windows"]:
				shuts.append(is_instance_valid(w) and float((w as Node).get_meta("wl_shut", 0.0)) > 0.5)
			room.call("guest_curtains", rec["root"], shuts)


## Past `hour` this evening (or on into the small hours).
static func _past(now: float, hour: float) -> bool:
	return now >= hour or now < 12.0


## How far you are from the lodging's middle (INF in a room: you are not out there).
func _from_you(rec: Dictionary, main: Node) -> float:
	var p: Node3D = main.get("_player") as Node3D
	if p == null or not is_instance_valid(rec["root"]) or (main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))):
		return INF
	var a: Vector3 = (rec["root"] as Node3D).global_position
	return Vector2(a.x - p.global_position.x, a.z - p.global_position.z).length()


## Every pane to go shut or back, one after another in an order of their own.
func _pull(rec: Dictionary, shut: bool, quick: bool) -> void:
	if bool(rec.get("pulled", false)) == shut:
		return
	rec["pulled"] = shut
	var order: Array = (rec["windows"] as Array).duplicate()
	order.shuffle()
	var gap: Vector2 = PULL_GAP_QUICK if quick else PULL_GAP
	var when := _clock + randf_range(0.1, gap.x)
	for w in order:
		if not is_instance_valid(w):
			continue
		(w as Node).set_meta("wl_goal", 1.0 if shut else 0.0)
		(w as Node).set_meta("wl_when", when)
		when += randf_range(gap.x, gap.y)


func _tick_panes(rec: Dictionary, near: bool) -> void:
	for w in rec["windows"]:
		var mi := w as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var now_at := float(mi.get_meta("wl_shut", 0.0))
		var goal := float(mi.get_meta("wl_goal", 0.0))
		if _clock < float(mi.get_meta("wl_when", 0.0)):
			continue
		# (Lifted at the corner, somebody looking out: it drops again by itself.)
		if goal >= 1.0 and _clock < float(mi.get_meta("wl_peek", 0.0)):
			goal = PEEK_OPEN
		if is_equal_approx(now_at, goal):
			continue
		if not bool(mi.get_meta("wl_moving", false)):
			mi.set_meta("wl_moving", true)
			_curtain_sound(mi, goal >= now_at)
		now_at = move_toward(now_at, goal, PULL_SPEED / FPS)
		mi.set_meta("wl_shut", now_at)
		mi.set_instance_shader_parameter("shut", now_at)
		if is_equal_approx(now_at, goal):
			mi.set_meta("wl_moving", false)
	if near and _clock >= float(rec.get("peek_next", 0.0)):
		rec["peek_next"] = _clock + randf_range(PEEK_EVERY.x, PEEK_EVERY.y)
		var panes: Array = rec["windows"]
		if not panes.is_empty():
			var one = panes[randi() % panes.size()]
			if is_instance_valid(one) and float((one as Node).get_meta("wl_shut", 0.0)) >= 0.99:
				(one as Node).set_meta("wl_peek", _clock + PEEK_SEC)


func _curtain_sound(mi: MeshInstance3D, shut: bool) -> void:
	if _pull_snd.playing:
		return
	_pull_snd.stream = SFX_SHUT if shut else SFX_OPEN
	_pull_snd.global_position = mi.global_position
	_pull_snd.pitch_scale = randf_range(0.92, 1.08)
	_pull_snd.play()


## Somebody moving about in there: across a pane now and then, near enough to be seen.
func _life(rec: Dictionary, lit: bool, main: Node) -> void:
	var panes: Array = rec["windows"]
	if panes.is_empty():
		return
	var mi := rec.get("walker", null) as MeshInstance3D
	if mi != null and not is_instance_valid(mi):
		mi = null
		rec["walker"] = null
	if mi != null:
		var k := (_clock - float(rec["walk_at"])) / maxf(0.1, float(rec["walk_sec"]))
		if k >= 1.0 or not lit:
			mi.set_instance_shader_parameter("figure", Vector3.ZERO)
			rec["walker"] = null
		else:
			# In steps with the rest, stopping a moment half way.
			var x := float(rec["walk_from"]) + (float(rec["walk_to"]) - float(rec["walk_from"])) * (k if k < 0.45 else (0.45 if k < 0.6 else (k - 0.15) / 0.85))
			mi.set_instance_shader_parameter("figure", Vector3(x, FIGURE_H, FIGURE_DARK))
		return
	if not lit or _clock < float(rec.get("walk_next", 0.0)) or _from_you(rec, main) > LIFE_WITHIN:
		return
	rec["walk_next"] = _clock + randf_range(WALK_EVERY.x, WALK_EVERY.y)
	var one = panes[randi() % panes.size()]
	if not is_instance_valid(one):
		return
	var left := randf() < 0.5
	if (one as MeshInstance3D).mesh is QuadMesh:
		(one as MeshInstance3D).set_instance_shader_parameter("pane_size", ((one as MeshInstance3D).mesh as QuadMesh).size)
	rec["walker"] = one
	rec["walk_at"] = _clock
	rec["walk_sec"] = randf_range(WALK_SEC.x, WALK_SEC.y)
	rec["walk_from"] = -0.25 if left else 1.25
	rec["walk_to"] = 1.25 if left else -0.25


## The cube's material for this lodging's panes, made once its room is drawn (null till
## then: the panes as they were).
func _cube_of(rec: Dictionary) -> ShaderMaterial:
	if rec.has("cube"):
		return rec["cube"]
	var kind := str(rec["kind"])
	if kind != "cabin" and kind != "caravan":
		return null
	var main := get_tree().current_scene
	var im = main.get("_interior_manager") if main != null else null
	var it = im.get("_cabin_interior" if kind == "cabin" else "_caravan_interior") if im != null else null
	if it == null or not is_instance_valid(it) or not it.has_method("cube_spec") or not is_instance_valid(rec["root"]):
		return null
	var spec: Dictionary = it.call("cube_spec", rec["root"])
	if spec.is_empty():
		return null
	var m := ROOM_CUBE.material(spec["tex"], spec["box"], spec["eye"], spec["world_to_room"])
	# Between a cabin's window frame and its bar, as the retro look pulls them (its live
	# view's own pull, cabin_interior._ensure_inview); a van's over its skin, a quad pulled
	# too: not pulled, from a few metres off the skin stood in front of every pane, a van with
	# no windows by day and by night (the user 6. 11.).
	m.set_shader_parameter("depth_pull", 0.009)
	# Its curtains open at the sides of the glass, as they hang inside.
	var spec_room: Dictionary = ROOMS[kind]
	var cpath: String = CAMP + str(spec_room["curtain"]) + ".png"
	if ResourceLoader.exists(cpath):
		m.set_shader_parameter("curtain_tex", load(cpath))
		m.set_shader_parameter("curtain", 0.72 if kind == "cabin" else 0.3)
	m.set_shader_parameter("figure_tex", FIGURE_TEX)
	rec["cube"] = m
	for w in rec["windows"]:
		if is_instance_valid(w):
			(w as Node).set_meta("wl_cube", m)
	return m


func _show(rec: Dictionary, on: bool, tv: bool, powered: bool, dark := false, hour := 12.0) -> void:
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
	# The room from its cube: lit by its lamp (the candle, the telly) after dark, by the day
	# through its windows by day, by the moon when its light is out.
	var cube := _cube_of(rec)
	if cube != null:
		if dark and on:
			cube.set_shader_parameter("light", Vector3(col.r, col.g, col.b) if col != LIT_TINT else Vector3(LAMP.r, LAMP.g, LAMP.b))
			# (Far off a pane is a few pixels: the room drawn by day, lit up past its day.)
			cube.set_shader_parameter("energy", clampf(amount * 1.1, 0.2, 2.4))
		elif dark:
			cube.set_shader_parameter("light", Vector3(MOON.r, MOON.g, MOON.b))
			cube.set_shader_parameter("energy", 0.07)
		else:
			# As bright as the near room's live view is by the hour (the interiors' own day and
			# evening: cabin_interior._inview_room_light's `bright` over its room lit by day or
			# by the evening), so the one fades into the other unseen.
			cube.set_shader_parameter("light", Vector3(1.0, 0.97, 0.92))
			cube.set_shader_parameter("energy", DAY_ROOM if hour >= 6.5 and hour < 19.5 else 0.42)
	# (The colour of the lamp in the glass of the one with the room in it, pane_figure's glow.)
	var lamp_col: Color = LAMP if col == LIT_TINT else col
	var in_glass := Vector3(lamp_col.r, lamp_col.g, lamp_col.b) * clampf(amount / 1.6, 0.0, 1.0)
	for w in rec["windows"]:
		var mi := w as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		if cube != null:
			if mi.has_meta("inview_live"):
				mi.set_meta("wl_lit", amount)
				mi.set_meta("wl_candle", candle)
				mi.set_meta("wl_tv", tv)
				mi.set_instance_shader_parameter("glow", in_glass)
			elif mi.material_override != cube:
				mi.material_override = cube
			continue
		# Looked into from the camp (caravan_interior._update_inview: the real room in the
		# glass): its pane is the room's now; it only hears whether it is lit, and how.
		if mi.has_meta("inview_live"):
			mi.set_meta("wl_lit", amount)
			mi.set_meta("wl_candle", candle)
			mi.set_meta("wl_tv", tv)
			mi.set_instance_shader_parameter("glow", in_glass)
			continue
		var m := mi.get_meta("wl_mat", null) as StandardMaterial3D
		if m == null:
			continue
		# Lit, a cabin's or a caravan's pane shows the room behind it.
		var room := mi.get_meta("wl_room", null) as ShaderMaterial
		if room != null:
			var want_mat: Material = room if on else m
			if mi.material_override != want_mat:
				mi.material_override = want_mat
			if on:
				room.set_shader_parameter("light", Vector3(col.r, col.g, col.b) if col != LIT_TINT else Vector3(LAMP.r, LAMP.g, LAMP.b))
				room.set_shader_parameter("energy", clampf(amount * (0.62 if kind == "cabin" else 0.3), 0.0, 1.2))
				room.set_shader_parameter("curtain", lerpf(0.32 if not tv else 0.5, 1.0, float(mi.get_meta("wl_shut", 0.0))))
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
