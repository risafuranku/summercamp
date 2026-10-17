extends Node

## What the night director (night_director.gd) decides, done with the camp's own things:
## the office's sounds, its window, its phone, its lights and curtain (building_interior),
## the lamps (building_manager), the omens (omens.gd), the radio (radio_dread). Everything
## here is temporary and is taken back: figures go, sounds stop, a lamp comes back on, a
## changed room is the player's to put right; at dawn `clear()` removes what is left.
##
## Debug builds only: F10 shows the director's state, tension, budget, archetypes, what
## it did and why (never in a release build).

const DIR := "res://assets/sfx/director/"
## A person, dark: one of us, standing where nobody should (not the hunters' own shapes).
const FIGURE_TEX := "res://assets/textury/npc/host1.png"
const FOOTPRINTS := "res://assets/textury/mess/dirt_footprints.png"
const STEPS_SFX := "res://assets/sfx/grassfootsteps.mp3"

var main: Node
var director
var _live: Array = []            # {node, until, kind, ...}
var _steps: Dictionary = {}      # the footsteps behind you
var _figure: Dictionary = {}     # the one in the window
var _debug: Label
var _t := 0.0


func setup(main_node: Node, dir) -> void:
	main = main_node
	director = dir
	if OS.is_debug_build():
		var layer := CanvasLayer.new()
		layer.layer = 230
		add_child(layer)
		_debug = Label.new()
		_debug.position = Vector2(8, 120)
		_debug.add_theme_font_size_override("font_size", 13)
		_debug.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		_debug.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug.add_theme_constant_override("outline_size", 4)
		_debug.visible = false
		layer.add_child(_debug)


func _unhandled_input(event: InputEvent) -> void:
	if _debug != null and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F10:
		_debug.visible = not _debug.visible


## Plays `id` now. ctx as the director's. Returns where it happened (or INF).
func run(id: String, ctx: Dictionary) -> Vector3:
	var bi = _office()
	match id:
		"window_tap":
			_room_sound(bi, "window_tap.mp3", Vector3(-0.4, 1.6, -2.45), -4.0)
		"knock":
			_room_sound(bi, "knock.mp3", Vector3(1.72, 1.3, -2.5), -2.0)
			return _leave_prints_at_door(bi)
		"knock_wrong":
			_room_sound(bi, "knock_wrong.mp3", Vector3(1.72, 1.3, -2.5), -2.0)
			return _leave_prints_at_door(bi)
		"handle":
			_room_sound(bi, "handle.mp3", Vector3(1.6, 1.05, -2.5), -1.0)
		"wall_brush":
			_room_sound(bi, "wall_brush.mp3", Vector3(-4.1, 1.2, -0.15), -3.0)
		"phone_night":
			if bi != null and bi.has_method("ring_phone"):
				var call := {"who": "", "number": "", "lines": [
					{"who": "", "text": "...", "voice": "breath"},
					{"who": "", "text": "(Breathing. Close to the mouthpiece. Then the line goes dead.)"},
				]}
				bi.ring_phone(call, 6)
		"radio_bleed":
			if bi != null and bi.has_method("nudge_radio_dread"):
				bi.nudge_radio_dread(0.55, 24.0)
		"room_changed":
			if bi != null and bi.has_method("disturb_office"):
				bi.disturb_office()
		"figure_window":
			return _figure_in_window(bi)
		"lamp_out":
			var bm = main.get("building_manager")
			if bm != null and bm.has_method("darken_lamp_near"):
				var at: Vector3 = bm.darken_lamp_near(ctx.get("pos", Vector3.ZERO), 20.0, randf_range(7.0, 12.0))
				if at != Vector3.INF:
					_world_sound("lamp_fizz.mp3", at + Vector3(0, 3.2, 0), -2.0, 30.0)
					return at
		"steps_behind":
			_start_steps()
		"call_far":
			var p := _dark_spot(ctx.get("pos", Vector3.ZERO), 38.0, 50.0)
			if p != Vector3.INF:
				_world_sound("call_far.mp3", p + Vector3(0, 1.6, 0), 2.0, 90.0, 18.0)
				return p
		"silhouette":
			return _silhouette(ctx.get("pos", Vector3.ZERO))
		"far_light":
			return _far_light(ctx.get("pos", Vector3.ZERO))
		"room_sounds":
			var de = main.get("_day_events")
			if de != null:
				var at2: Vector3 = de.haunted_near(ctx.get("pos", Vector3.ZERO), 14.0)
				if at2 != Vector3.INF:
					_world_sound("wet_steps.mp3" if randf() < 0.5 else "wall_brush.mp3", at2 + Vector3(0, 1.0, 0), -4.0, 22.0)
					return at2
		"omen":
			var om = main.get("_omens")
			if om != null and om.has_method("play_now"):
				om.play_now(ctx.get("pos", Vector3.ZERO), main.call("_omen_context") if main.has_method("_omen_context") else {})
	return Vector3.INF


func _process(delta: float) -> void:
	_t += delta
	_update_steps(delta)
	_update_figure(delta)
	var keep: Array = []
	var pl = main.get("_player") as Node3D
	for l in _live:
		# Things that go away when you come close.
		if l.has("vanish_at") and pl != null and pl.global_position.distance_to(l["vanish_at"]) < float(l["vanish_m"]):
			l["until"] = _t
		if _t >= float(l["until"]) or not is_instance_valid(l["node"]):
			if is_instance_valid(l["node"]):
				(l["node"] as Node).queue_free()
		else:
			keep.append(l)
	_live = keep
	if _debug != null and _debug.visible and director != null:
		var s: Dictionary = director.snapshot()
		var lines := ["NIGHT DIRECTOR  %s  tension %.2f  budget %.1f  t %ds" % [s["state"], s["tension"], s["budget"], int(s["night_t"])]]
		var a: Array = s["arch"]
		lines.append("arch  OBS %.2f  MIM %.2f  DIS %.2f  HUN %.2f" % [a[0], a[1], a[2], a[3]])
		lines.append("ignored %d  investigated %d" % [s["ignored"], s["investigated"]])
		lines.append("why: %s" % s["why"])
		for r in s["recent"]:
			lines.append("  %4ds %s (%s)" % [int(r["t"]), r["id"], r["place"]])
		lines.append("cooldowns: %s" % str(s["cooldowns"]))
		_debug.text = "\n".join(lines)


## Dawn, a new game, the menu: everything the night left goes.
func clear() -> void:
	var bi = _office()
	if bi != null and bi.has_method("undo_disturbances"):
		bi.undo_disturbances()
	for l in _live:
		if is_instance_valid(l["node"]):
			(l["node"] as Node).queue_free()
	_live.clear()
	_stop_steps()
	_end_figure()


# ── the office ───────────────────────────────────────────────────────────────

func _office():
	var im = main.get("_interior_manager")
	return im.get("_building_interior") if im != null else null


func _room_sound(bi, file: String, room_pos: Vector3, db: float) -> void:
	if bi != null and bi.has_method("play_room_sound"):
		bi.play_room_sound(DIR + file, room_pos, db)


## Wet bare footprints on the step outside the office door (stay till dawn): something
## was there. You find them if you go out to look.
func _leave_prints_at_door(bi) -> Vector3:
	if bi == null or not bi.get("_portal_ok"):
		return Vector3.INF
	var xf: Transform3D = bi.get("_portal_xform")
	var at: Vector3 = xf * Vector3(1.72, 0.03, -3.3)
	var d := _decal(FOOTPRINTS, 0.9, at, randf() * TAU, Color(0.35, 0.4, 0.42, 0.85))
	if d != null:
		_live.append({"node": d, "until": _t + 600.0})
	return at


## Somebody stands outside the office window, 8 m out, facing it: only the window shows
## them (the room is its own world). Look straight at them a moment, draw the curtain or
## go out, and they are gone; outside, wet prints where they stood.
func _figure_in_window(bi) -> Vector3:
	if bi == null or not bi.get("_portal_ok") or not _figure.is_empty():
		return Vector3.INF
	var xf: Transform3D = bi.get("_portal_xform")
	var at: Vector3 = xf * Vector3(-0.6 + randf_range(-1.2, 1.2), 0.0, -2.51 - randf_range(7.0, 10.0))
	at = _ground(at)
	var fig := _figure_sprite(at)
	if fig == null:
		return Vector3.INF
	_figure = {"node": fig, "at": at, "seen": 0.0, "until": _t + 45.0}
	return at


func _update_figure(delta: float) -> void:
	if _figure.is_empty():
		return
	var bi = _office()
	var gone: bool = _t > float(_figure["until"]) or bi == null or not bi.visible
	if not gone:
		if bi.has_method("is_looking_at_window") and bi.is_looking_at_window():
			_figure["seen"] = float(_figure["seen"]) + delta
		if float(_figure["seen"]) > 1.6:
			gone = true
		var c = bi.get("_office_curtain")
		if c != null and float(c.get("open")) < 0.3:
			gone = true
	if gone:
		var at: Vector3 = _figure["at"]
		_end_figure()
		var d := _decal(FOOTPRINTS, 0.8, at + Vector3(0, 0.03, 0), randf() * TAU, Color(0.35, 0.4, 0.42, 0.85))
		if d != null:
			_live.append({"node": d, "until": _t + 600.0})


func _end_figure() -> void:
	if not _figure.is_empty() and is_instance_valid(_figure["node"]):
		(_figure["node"] as Node).queue_free()
	_figure = {}


# ── outdoors ─────────────────────────────────────────────────────────────────

## Steps on the grass a few metres behind you while you walk; they stop when you stop,
## and when you turn round there is nobody.
func _start_steps() -> void:
	var p = main.get("_player")
	if p == null or not ResourceLoader.exists(STEPS_SFX):
		return
	_stop_steps()
	var s := AudioStreamPlayer3D.new()
	var st := (load(STEPS_SFX) as AudioStream).duplicate()
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	s.stream = st
	s.unit_size = 4.0
	s.volume_db = -6.0
	s.pitch_scale = 0.92
	main.get("_world_3d").add_child(s)
	_steps = {"node": s, "until": _t + randf_range(4.0, 7.0)}
	s.play()


func _update_steps(_delta: float) -> void:
	if _steps.is_empty():
		return
	var p = main.get("_player") as Node3D
	var s := _steps["node"] as AudioStreamPlayer3D
	if p == null or not is_instance_valid(s):
		_stop_steps()
		return
	var cam := p.get_viewport().get_camera_3d()
	var fwd: Vector3 = -cam.global_transform.basis.z if cam != null else -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	s.global_position = p.global_position - fwd * 5.5 + Vector3(0, 0.2, 0)
	var vel: Vector3 = p.get("velocity") if p.get("velocity") != null else Vector3.ZERO
	var moving := Vector2(vel.x, vel.z).length() > 0.8
	s.stream_paused = not moving
	if _t > float(_steps["until"]):
		_stop_steps()


func _stop_steps() -> void:
	if not _steps.is_empty() and is_instance_valid(_steps["node"]):
		(_steps["node"] as Node).queue_free()
	_steps = {}


## A light out in the trees beyond the camp, 45-60 m, where no lamp is: a lantern's warm
## glow that breathes slowly. It goes out when you are halfway there; nothing at the spot.
func _far_light(from: Vector3) -> Vector3:
	# Where you are looking (it wants to be seen), in the dark.
	var p := _dark_spot(from, 45.0, 60.0, 0.75)
	if p == Vector3.INF:
		return Vector3.INF
	p = _ground(p) + Vector3(0, 1.1, 0)
	var root := Node3D.new()
	root.name = "DirectorFarLight"
	main.get("_world_3d").add_child(root)
	root.global_position = p
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.45)
	light.light_energy = 1.6
	light.omni_range = 5.0
	root.add_child(light)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 0.32)
	glow.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.55)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.material_override = m
	root.add_child(glow)
	var tw := root.create_tween().set_loops()
	tw.tween_property(light, "light_energy", 0.7, 1.6)
	tw.tween_property(light, "light_energy", 1.6, 1.6)
	_live.append({"node": root, "until": _t + 40.0, "vanish_at": p, "vanish_m": maxf(18.0, from.distance_to(p) * 0.5)})
	return p


## Someone crosses open ground 25-35 m off, in the dark, in a second and a half: gone by
## the time you get there, prints where they went.
func _silhouette(from: Vector3) -> Vector3:
	var p = main.get("_player") as Node3D
	if p == null:
		return Vector3.INF
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	for attempt in 6:
		var dist := randf_range(25.0, 34.0)
		var mid := from + fwd.rotated(Vector3.UP, randf_range(-0.35, 0.35)) * dist
		mid = _ground(mid)
		if not _open_ground(cam.global_position, mid + Vector3(0, 1.2, 0)):
			continue
		var bm = main.get("building_manager")
		if bm != null and bm.has_method("get_light_level_at") and float(bm.get_light_level_at(mid)) > 0.35:
			continue
		var a := mid - side * 3.5
		var b := mid + side * 3.5
		var fig := _figure_sprite(a)
		if fig == null:
			return Vector3.INF
		var tw := fig.create_tween()
		tw.tween_property(fig, "global_position", b, 1.5)
		_live.append({"node": fig, "until": _t + 1.55})
		var d := _decal(FOOTPRINTS, 0.8, b + Vector3(0, 0.03, 0), randf() * TAU, Color(0.3, 0.32, 0.3, 0.8))
		if d != null:
			_live.append({"node": d, "until": _t + 600.0})
		return b
	return Vector3.INF


## A dark spot rmin-rmax m away; `ahead` > 0: within that many radians of where the
## camera looks.
func _dark_spot(from: Vector3, rmin: float, rmax: float, ahead := 0.0) -> Vector3:
	var bm = main.get("building_manager")
	var base_ang := 0.0
	if ahead > 0.0:
		var pl = main.get("_player") as Node3D
		var cam := pl.get_viewport().get_camera_3d() if pl != null else null
		if cam != null:
			var f := -cam.global_transform.basis.z
			base_ang = atan2(f.z, f.x)
	for i in 10:
		var ang := (base_ang + randf_range(-ahead, ahead)) if ahead > 0.0 else randf() * TAU
		var p := from + Vector3(cos(ang), 0, sin(ang)) * randf_range(rmin, rmax)
		if bm == null or not bm.has_method("get_light_level_at") or float(bm.get_light_level_at(p)) < 0.08:
			return p
	return Vector3.INF


# ── helpers ──────────────────────────────────────────────────────────────────

func _figure_sprite(at: Vector3) -> Sprite3D:
	if not ResourceLoader.exists(FIGURE_TEX):
		return null
	var s := Sprite3D.new()
	s.texture = load(FIGURE_TEX)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.modulate = Color(0.07, 0.07, 0.08)
	s.pixel_size = 1.85 / float(maxi(1, s.texture.get_height()))
	s.offset = Vector2(0, s.texture.get_height() * 0.5)
	main.get("_world_3d").add_child(s)
	s.global_position = at
	return s


func _decal(path: String, width: float, at: Vector3, yaw: float, tint: Color) -> MeshInstance3D:
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * float(tex.get_height()) / float(tex.get_width()))
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.2
	mi.material_override = m
	main.get("_world_3d").add_child(mi)
	mi.global_position = at
	mi.rotation.y = yaw
	return mi


func _world_sound(file: String, at: Vector3, db: float, max_d: float, unit := 6.0) -> void:
	if not ResourceLoader.exists(DIR + file):
		return
	var s := AudioStreamPlayer3D.new()
	s.stream = load(DIR + file)
	s.volume_db = db
	s.max_distance = max_d
	s.unit_size = unit
	main.get("_world_3d").add_child(s)
	s.global_position = at
	s.finished.connect(s.queue_free)
	s.play()


func _ground(p: Vector3) -> Vector3:
	var w = main.get("_world_3d") as Node3D
	if w == null or w.get_world_3d() == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 20, 0), p + Vector3(0, -20, 0))
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or float(hit["position"].y) > p.y + 1.5:
		return Vector3(p.x, 0.0, p.z)
	return hit["position"]


func _open_ground(eye: Vector3, at: Vector3) -> bool:
	var w = main.get("_world_3d") as Node3D
	if w == null or w.get_world_3d() == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(eye, at)
	var p = main.get("_player")
	if p is CollisionObject3D:
		q.exclude = [(p as CollisionObject3D).get_rid()]
	return w.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
