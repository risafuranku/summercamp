extends "res://tools/shot_driver.gd"

## The Whistler's night on pictures (scripts/enemies/whistler_brain.gd, DESIGN §5a.3):
##   --part=strike  the string round your throat in steps (the camp's second time: it hurts),
##                  then the first time in a camp (he lets you go) and the kill
##   --part=hitch   him playing in the dark ahead, then the falter: the music gone, his slits
##   --part=walk    from eight sides: him round you at eight angles, standing, walking, running
##   --part=window  in a cabin, him out there by its window playing
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/piskac_shots.tscn -- --part=strike --out=DIR

const P := "get_tree().root.get_node('PiskacShots')"


func w():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "whistler":
			return b
	return null


func _fwd() -> Vector3:
	var cam: Camera3D = (_main.get("_player") as Node3D).get_node("Head/Camera3D")
	return (-cam.global_transform.basis.z).slide(Vector3.UP).normalized()


func _at(dist: float, deg: float) -> Vector3:
	var p: Node3D = _main.get("_player")
	var want := p.global_position + _fwd().rotated(Vector3.UP, deg_to_rad(-deg)) * dist
	var b = w()
	var at: Vector3 = b._stand(want) if b != null else Vector3.INF
	return at if at != Vector3.INF else want


## Whether the camp has met him (the first strike lets you go).
func met(on: bool) -> String:
	var d = _main.get("_director")
	if d != null and d.get("ever") is Dictionary:
		(d.get("ever") as Dictionary)["whistler_met"] = on
	return "met %s" % on


## At your back, the string: his strike from the start.
func strike_now() -> String:
	var b = w()
	if b == null:
		return "no whistler"
	b._enter("rest", 999.0)
	b.set("_pos", _at(1.2, 180.0))
	b._start_strike()
	return "strike kill=%s lesson=%s" % [b._strike.get("kill"), b._strike.get("lesson")]


## Him `dist` m ahead in the dark, playing and listening, a shape from there.
func play_ahead(dist: float) -> String:
	var b = w()
	if b == null:
		return "no whistler"
	b.set("_pos", _at(dist, 0.0))
	b._enter("play", 60.0)
	b.set("_grace", 0.0)
	b.set("_pos", _at(dist, 0.0))
	var body: Node3D = b.get("_body")
	body.visible = true
	b._place_body(b.get("_pos"))
	b._stand_toward((_main.get("_player") as Node3D).global_position)
	return "playing %.1f m" % dist


func hitch_now() -> String:
	var b = w()
	if b == null:
		return "no whistler"
	b._start_hitch()
	return "hitch %.1f s, music %.0f dB" % [float(b.get("_hitch_t")), float(b.get("_music").volume_db)]


## Him held still `dist` m off at `deg` round you (+ right), facing `face_deg` from facing you,
## in `anim` ("stand", "walk", "run") at frame `frame`.
func hold(dist: float, deg: float, face_deg: float, anim: String, frame: int) -> String:
	var b = w()
	if b == null:
		return "no whistler"
	b.set("_night_active", false)
	var p: Vector3 = _at(dist, deg)
	b.set("_pos", p)
	b._place_body(p)
	var me: Vector3 = (_main.get("_player") as Node3D).global_position
	var to := (me - p).slide(Vector3.UP).normalized().rotated(Vector3.UP, deg_to_rad(face_deg))
	b.set("_fig_yaw", atan2(-to.x, -to.z))
	b.set("_fig_anim", anim)
	b.set("_fig_dist", float(frame) * 0.34 + 0.01 if anim == "walk" else float(frame) * 0.62 + 0.01)
	b.set("_sitting", false)
	b._show_fig()
	var body: Sprite3D = b.get("_body")
	body.visible = true
	return "%s view %d flip %s" % [anim, absi(int(b.get("_fig_sector"))), body.flip_h]


func look(deg: float) -> String:
	var p: Node3D = _main.get("_player")
	p.rotation.y += deg_to_rad(-deg)
	return "turned %.0f" % deg


# ── in a cabin ────────────────────────────────────────────────────────────────

func into_cabin() -> String:
	var root = _main.get("building_manager").get_node_or_null("Structures")
	for child in root.get_children():
		if str(child.get_meta("building_type", "")).contains("cabin"):
			_main.set("debug_camera", null)
			_main.get("_player").global_position = child.global_position + Vector3(0, 0, 3.0)
			_main.get("_interior_manager")._on_cabin_interact(child)
			return str(child.get_meta("building_type", ""))
	return "no cabin"


## His song with him out there by the window you look at (its curtain open).
func window_now() -> String:
	var b = w()
	if b == null:
		return "no whistler"
	var wins: Array = b._room_windows()
	var best := -1
	var face := -9.0
	for i in wins.size():
		var wd: Dictionary = wins[i]
		if float(wd.get("open", 1.0)) >= 0.35 and float(wd.get("facing", 0.0)) > face:
			face = float(wd.get("facing", 0.0))
			best = i
	b._start_in_song(best)
	var wi := int(b.get("_in_win"))
	if wi < 0:
		return "at no window"
	var wp: Vector3 = (wins[wi] as Dictionary)["pos"]
	var bp: Vector3 = (b.get("_body") as Node3D).global_position
	return "at window %d (looked at %.2f), %.1f m out, shown %s" % [wi, face, Vector2(bp.x - wp.x, bp.z - wp.z).length(), (b.get("_body") as Node3D).visible]


## Why a window would not take him: each window's open, out, the spot, its light.
func window_probe() -> String:
	var b = w()
	if b == null:
		return "no whistler"
	var out: Array = []
	for wd in b._room_windows():
		var o: Vector3 = wd["out"]
		var flat := Vector3(o.x, 0.0, o.z)
		var p: Vector3 = b._stand((wd["pos"] as Vector3) + flat.normalized() * 9.0) if flat.length() > 0.1 else Vector3.INF
		out.append("open %.2f out %s spot %s light %.2f" % [float(wd.get("open", -1.0)), str(o.snapped(Vector3.ONE * 0.01)), str(p.snapped(Vector3.ONE * 0.1)) if p != Vector3.INF else "INF", b._lamp_light_at(p) if p != Vector3.INF else -1.0])
	return "%d windows: %s" % [out.size(), " | ".join(out)]


const START := [
	["wait_menu"], ["call", "_on_menu_test_night", ["whistler"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0], ["eval", "_set_player_health(100)"],
	["eval", "debug_spawn_enemy('whistler', 3)"], ["wait", 0.5],
]

const STRIKE_STEPS := [
	["eval", P + ".met(true)"], ["eval", P + ".strike_now()"],
	["wait", 0.2], ["shot", "k1_yanked"],
	["wait", 0.5], ["shot", "k2_string"],
	["wait", 0.6], ["shot", "k3_horn_coming"],
	["wait", 0.35], ["shot", "k4_whistle"],
	["wait", 0.35], ["shot", "k5_cut"],
	["wait", 0.5], ["shot", "k6_down"],
	["wait", 0.8], ["shot", "k7_coming_to"],
	["wait", 1.5], ["eval", "_player_health"],
	# The first in a camp: he lets you go.
	["eval", "_set_player_health(100)"], ["eval", P + ".met(false)"], ["eval", P + ".strike_now()"],
	["wait", 2.3], ["shot", "l1_lesson_whistle"], ["wait", 0.6], ["shot", "l2_lesson_loose"],
	["wait", 1.5], ["eval", "_player_health"],
	# The last: the string only tightens.
	["eval", "_set_player_health(20)"], ["eval", P + ".met(true)"], ["eval", P + ".strike_now()"],
	["wait", 3.4], ["shot", "x1_kill_dark"],
]

const HITCH_STEPS := [
	["eval", P + ".play_ahead(11.0)"], ["wait", 0.8], ["shot", "h1_playing"],
	["eval", P + ".hitch_now()"], ["wait", 0.4], ["shot", "h2_falter_slits"],
	["wait", 1.6], ["shot", "h3_plays_on"],
]

const WALK_STEPS := [
	["eval", P + ".hold(4.5, 0.0, 0.0, 'stand', 0)"], ["wait", 0.3], ["shot", "f0_front"],
	["eval", P + ".hold(4.5, 0.0, 45.0, 'stand', 0)"], ["wait", 0.3], ["shot", "f1_front_three_quarter"],
	["eval", P + ".hold(4.5, 0.0, 90.0, 'stand', 0)"], ["wait", 0.3], ["shot", "f2_side"],
	["eval", P + ".hold(4.5, 0.0, 135.0, 'stand', 0)"], ["wait", 0.3], ["shot", "f3_back_three_quarter"],
	["eval", P + ".hold(4.5, 0.0, 180.0, 'stand', 0)"], ["wait", 0.3], ["shot", "f4_back"],
	["eval", P + ".hold(4.5, 0.0, -90.0, 'walk', 0)"], ["wait", 0.3], ["shot", "w0_walk_side_0"],
	["eval", P + ".hold(4.5, 0.0, -90.0, 'walk', 1)"], ["wait", 0.3], ["shot", "w1_walk_side_1"],
	["eval", P + ".hold(4.5, 0.0, 0.0, 'walk', 2)"], ["wait", 0.3], ["shot", "w2_walk_toward"],
	["eval", P + ".hold(4.5, 0.0, 90.0, 'run', 0)"], ["wait", 0.3], ["shot", "r0_run_side_0"],
	["eval", P + ".hold(4.5, 0.0, 90.0, 'run', 1)"], ["wait", 0.3], ["shot", "r1_run_side_1"],
	["eval", P + ".hold(4.5, 0.0, 0.0, 'run', 0)"], ["wait", 0.3], ["shot", "r2_run_at_you"],
]

const WINDOW_STEPS := [
	["eval", P + ".into_cabin()"], ["wait", 3.0],
	["eval", "_interior_manager.get('_cabin_interior').take_curtains([true, true, true, true, true, true])"], ["wait", 1.5],
	["eval", P + ".window_probe()"], ["eval", P + ".window_now()"], ["wait", 0.8], ["shot", "o1_at_the_window"],
	["eval", "get_tree().root.get_node('PiskacShots').w()._stop_in(true)"], ["wait", 0.5], ["shot", "o2_stopped_slits"],
	["eval", "get_tree().root.get_node('PiskacShots').w()._to_the_glass()"], ["wait", 0.5], ["shot", "o3_at_the_glass"],
]


func _ready() -> void:
	super._ready()
	var part := "strike"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.get_slice("=", 1)
	var steps: Array = {"strike": STRIKE_STEPS, "hitch": HITCH_STEPS, "walk": WALK_STEPS, "window": WINDOW_STEPS}.get(part, STRIKE_STEPS)
	_steps = START.duplicate(true) + steps.duplicate(true) + [["eval", "get_tree().quit()"]]
