extends "res://tools/shot_driver.gd"

## The Girl's night on pictures and timed (scripts/enemies/girl_brain.gd):
##   --part=stages  each stage of her art standing in front of you in the night (her brain
##                  held still, so the picture is the art as the game stands it), the reach,
##                  then her eyes far off in the dark and her strike step by step
##   --part=hitch   the same night without her and with her, then her firsts one after
##                  another (each nearer stage, the face for two frames, the ring round your
##                  lamp, the strike), every frame timed
##   --part=jam     her interference from all round (nightmare_fx.set_jam, her brain held
##                  still), then finding her frame by frame (run it with --fixed-fps 30)
##   --part=film    the real thing for --write-movie: she comes from behind on your right,
##                  you turn to her, she is found; you turn away, she comes, you find her
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/holka_shots.tscn -- --part=stages --out=DIR
##   godot --path godot --write-movie OUT/film.avi --fixed-fps 30 --resolution 960x540 res://tools/holka_shots.tscn -- --part=film
## (Co-op: tools/coop_scare.py, tools/coop_girl.py.)

const H := "get_tree().root.get_node('HolkaShots')"


func girl():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "girl":
			return b
	return null


func _ahead(dist: float) -> Vector3:
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var fwd := (-cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized()
	var want := p.global_position + fwd * dist
	var g = girl()
	var at: Vector3 = g._stand(want) if g != null else Vector3.INF
	return at if at != Vector3.INF else want


## Her in the art `path` ("" = stage `i`'s newest art) `dist` m in front of you, her
## brain held still.
func pose(i: int, path: String, dist: float) -> String:
	var g = girl()
	if g == null:
		return "no girl"
	g.set("_night_active", false)
	var body: Node3D = g.get("_body")
	body.global_position = _ahead(dist)
	body.visible = true
	if path == "":
		path = g._stage(i)
	g._set_body_tex(path)
	return "%s %.1f m" % [path.get_file(), dist]


## Her `dist` m in front of you in the dark, going on as herself, not stepping for a while.
func near(dist: float) -> String:
	var g = girl()
	if g == null:
		return "no girl"
	g.set("_night_active", true)
	var body: Node3D = g.get("_body")
	body.global_position = _ahead(dist)
	body.visible = true
	g._set_look(false, dist)
	g.set("_unseen_for", -30.0)
	return "%s %.1f m" % [str((body as Sprite3D).texture.resource_path).get_file(), dist]


func strike_now() -> String:
	var g = girl()
	if g == null:
		return "no girl"
	g.set("_night_active", true)
	var body: Node3D = g.get("_body")
	body.global_position = _ahead(1.4)
	body.visible = true
	g._start_strike()
	return "strike"


func subliminal() -> String:
	var g = girl()
	var fx = g._fx() if g != null else null
	if fx == null:
		return "no fx"
	fx.subliminal(g.get("_tex")[g.T_SMILE], 2, 0.95, Color(1, 1, 1, 0.85))
	return "face"


## How long her pictures made at run time take, each the first time (--part=probe).
func probe() -> String:
	var g = girl()
	if g == null:
		return "no girl"
	var out: Array = []
	var t0 := Time.get_ticks_usec()
	g.set("_upside_tex", null)
	g._upside()
	out.append("upside %d us" % (Time.get_ticks_usec() - t0))
	var tex: Texture2D = g.get("_tex")[g.GUEST]
	t0 = Time.get_ticks_usec()
	tex.get_image()
	out.append("get_image %d us" % (Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	g._find_eyes(tex)
	out.append("find_eyes %d us" % (Time.get_ticks_usec() - t0))
	t0 = Time.get_ticks_usec()
	var e: Node3D = g.ENEMY_EYES.new()
	(g.get("_root") as Node).add_child(e)
	e.call("setup", "girl", 0.0, null)
	out.append("eyes %d us" % (Time.get_ticks_usec() - t0))
	e.queue_free()
	t0 = Time.get_ticks_usec()
	for art in (g.get("_tex") as Dictionary).values():
		g._find_eyes(art)
	out.append("find_eyes all %d: %d us" % [(g.get("_tex") as Dictionary).size(), Time.get_ticks_usec() - t0])
	return ", ".join(out)


## Her `deg` from where you look (+ right), `dist` m off, her brain held still, and the
## interference she would give there set by hand each frame.
var _jam_hand := {}


func jam_at(deg: float, dist: float) -> String:
	var g = girl()
	if g == null:
		return "no girl"
	g.set("_night_active", false)
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var fwd := (-cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized()
	var dir := fwd.rotated(Vector3(0, 1, 0), -deg_to_rad(deg))
	var want := p.global_position + dir * dist
	var at: Vector3 = g._stand(want)
	var body: Node3D = g.get("_body")
	body.global_position = at if at != Vector3.INF else want
	body.visible = true
	g._set_look(false, dist)
	_jam_hand = {"point": body.global_position + Vector3(0, 1.5, 0), "level": clampf((16.0 - dist) / 13.0, 0.0, 1.0)}
	return "%d deg %.1f m level %.2f" % [int(deg), dist, float(_jam_hand["level"])]


func lock_now(k: float) -> String:
	_jam_hand = {}
	var g = girl()
	var fx = g._fx()
	var body: Sprite3D = g.get("_body")
	var p: Node3D = _main.get("_player")
	var tall := float(body.texture.get_height()) * body.pixel_size
	fx.lock(k, body.texture, body.global_position, body.global_position + Vector3(0, tall, 0), p.get_node("Head/Camera3D"))
	return "lock"


## The film: her from behind on your right, going on as herself.
func film_place(deg: float, dist: float) -> String:
	var g = girl()
	var p: Node3D = _main.get("_player")
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var fwd := (-cam.global_transform.basis.z).slide(Vector3(0, 1, 0)).normalized()
	var want := p.global_position + fwd.rotated(Vector3(0, 1, 0), -deg_to_rad(deg)) * dist
	var at: Vector3 = g._stand(want)
	var body: Node3D = g.get("_body")
	body.global_position = at if at != Vector3.INF else want
	body.visible = true
	g.set("_night_active", true)
	g.set("_phase", 1)
	g.set("_behind_done", true)
	g.set("_guest_done", true)
	g.set("_unseen_for", 0.0)
	g.set("_stutter_next", 99.0)
	g.set("_curse_next", 99.0)
	g._set_look(false, dist)
	return "at %.1f m, frame %d" % [dist, Engine.get_frames_drawn()]


## Turning at `speed` degrees a second to her (`to` true) or away from her, until there.
var _turn := {}


func turn(to: bool, speed: float) -> String:
	_turn = {"to": to, "speed": speed}
	return "turning, frame %d" % Engine.get_frames_drawn()


func _do_turn(delta: float) -> void:
	if _turn.is_empty():
		return
	var g = girl()
	var p: Node3D = _main.get("_player")
	if g == null or p == null:
		return
	var to: Vector3 = (g.get("_body") as Node3D).global_position - p.global_position
	var want := atan2(-to.x, -to.z)
	if not bool(_turn["to"]):
		want += PI
	var diff := wrapf(want - p.rotation.y, -PI, PI)
	var step := deg_to_rad(float(_turn["speed"])) * delta
	if absf(diff) <= step:
		p.rotation.y = want
		_turn = {}
		return
	p.rotation.y += signf(diff) * step


func ring() -> String:
	var g = girl()
	if g == null:
		return "no girl"
	g._round_the_lamp()
	return "round the lamp"


# ── frames timed ──────────────────────────────────────────────────────────────

## A hitch: a frame far longer than the frames round it (three times the running mean and
## over 50 ms), while watched. No pictures taken (a saved picture is a long frame itself).
var _watch_hitch := false
var _hitches := 0
var _mean_dt := 1.0 / 30.0
var _win := ""
var _win_dt: Array = []
var _win_ms: Array = []


## Pipelines compiled so far (Godot's own counters): a long frame with new ones is a
## shader met for the first time.
func _compiled() -> int:
	var n := 0
	for m in [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += int(Performance.get_monitor(m))
	return n


var _compiled_last := 0


func _process(delta: float) -> void:
	super._process(delta)
	_do_turn(delta)
	if not _jam_hand.is_empty():
		var g0 = girl()
		var fx0 = g0._fx() if g0 != null else null
		if fx0 != null:
			fx0.set_jam("test", _jam_hand["point"], (_main.get("_player") as Node).get_node("Head/Camera3D"), float(_jam_hand["level"]))
	var comp := _compiled()
	var new_comp := comp - _compiled_last
	_compiled_last = comp
	if _watch_hitch and delta > 0.05 and delta > _mean_dt * 3.0:
		_hitches += 1
		print("HITCH pipelines compiled in it: %d, scripts %.0f ms, physics %.0f ms" % [new_comp, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		var g = girl()
		var what := ""
		if g != null:
			var tex: Texture2D = (g.get("_body") as Sprite3D).texture
			var fx: Node = _main.get_tree().root.get_node_or_null("NightmareFX")
			what = "phase=%d strike_t=%.2f art=%s stutter=%.2f curse=%d jump=%s screen=%s sub=%s dist=%.1f" % [int(g.get("_phase")), float(g.get("_strike_t")), tex.resource_path.get_file() if tex != null else "-",
				float(g.get("_stutter_t")), int(g.get("_curse_frames")), g.get("_jump_ready"),
				fx.get("_screen").visible if fx != null else "-", fx.get("_sub").visible if fx != null else "-", g._distance_to_player((g.get("_body") as Node3D).global_position)]
		print("HITCH %d ms (frames round it %d ms) at step %d %s %s" % [int(delta * 1000.0), int(_mean_dt * 1000.0), _step_index, str(_steps[mini(_step_index, _steps.size() - 1)]), what])
	_mean_dt = lerpf(_mean_dt, minf(delta, 0.25), 0.1)
	if _win != "":
		_win_dt.append(delta)
		_win_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)


func watch(on: bool) -> String:
	_watch_hitch = on
	return "HITCHES %d" % _hitches


func window(label: String) -> String:
	var out := ""
	if _win != "" and not _win_dt.is_empty():
		var n := float(_win_dt.size())
		var dt := 0.0
		var ms := 0.0
		var worst := 0.0
		for i in _win_dt.size():
			dt += float(_win_dt[i])
			ms += float(_win_ms[i])
			worst = maxf(worst, float(_win_dt[i]))
		out = "PERF %s frames=%d fps=%.0f scripts=%.1fms worst=%dms" % [_win, int(n), n / dt, ms / n, int(worst * 1000.0)]
	_win = label
	_win_dt.clear()
	_win_ms.clear()
	return out


const STAGE_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["girl"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	# The test night's girl may be on you already: her afresh, far off.
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0], ["eval", "_set_player_health(100)"],
	["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 0.5],
	["eval", H + ".pose(0, '', 6.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s0_stage0"],
	["eval", H + ".pose(1, '', 6.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s1_stage1"],
	["eval", H + ".pose(2, '', 6.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s2_stage2"],
	["eval", H + ".pose(3, '', 6.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s3_stage3_back"],
	["eval", H + ".pose(4, '', 6.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s4_stage4"],
	["eval", H + ".pose(0, str(" + H + ".girl().REACH_TEX), 4.5)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s5_reach"],
	["eval", H + ".pose(3, '', 3.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s6_back_close"],
	["eval", H + ".pose(0, str(" + H + ".girl().REACH_TEX), 3.0)"], ["look_at_enemy"], ["wait", 0.5], ["shot", "s7_reach_close"],
	["eval", H + ".near(24.0)"], ["look_at_enemy"], ["wait", 1.0], ["shot", "s8_eyes_far"],
	["eval", H + ".strike_now()"], ["wait", 0.15], ["shot", "s9_strike_lunge"],
	["wait", 0.45], ["shot", "s10_strike_grab"], ["wait", 0.45], ["shot", "s11_strike_snap"],
	["wait", 0.25], ["shot", "s12_strike_split"], ["wait", 0.5], ["shot", "s13_strike_bite"],
	["wait", 1.0], ["shot", "s14_after"],
]

const HITCH_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["girl"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 2.0],
	# The same night without her, then with her; then her firsts, one after another.
	["call", "_stop_active_enemy_brain", []], ["wait", 3.0],
	["eval", H + ".window('alone')"], ["wait", 5.0], ["eval", H + ".window('')"],
	["eval", H + ".watch(true)"],
	["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 3.0],
	["eval", H + ".window('girl out')"], ["wait", 5.0], ["eval", H + ".window('')"],
	["eval", "_set_player_health(100)"],
	["eval", H + ".near(20.0)"], ["look_at_enemy"], ["wait", 1.5],
	["eval", H + ".near(14.0)"], ["look_at_enemy"], ["wait", 1.5],
	["eval", H + ".near(9.0)"], ["look_at_enemy"], ["wait", 1.5],
	["eval", H + ".near(5.0)"], ["look_at_enemy"], ["wait", 1.5],
	["eval", H + ".near(3.0)"], ["look_at_enemy"], ["wait", 1.5],
	["eval", H + ".subliminal()"], ["wait", 1.5],
	["eval", H + ".ring()"], ["wait", 4.0],
	["eval", H + ".strike_now()"], ["wait", 5.0], ["eval", "_set_player_health(100)"],
	# A second strike: what hitches again is work every strike does, not a first time.
	["eval", H + ".near(6.0)"], ["look_at_enemy"], ["wait", 1.0],
	["eval", H + ".strike_now()"], ["wait", 5.0], ["eval", "_set_player_health(100)"],
	["eval", "[" + H + ".girl().get_debug_snapshot(), _player_health]"],
	["eval", H + ".watch(false)"],
]


const JAM_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["girl"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0], ["eval", "_set_player_health(100)"],
	["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 0.5],
	["eval", H + ".jam_at(70.0, 9.0)"], ["wait", 1.2], ["shot", "j0_right_70_9m"],
	["eval", H + ".jam_at(110.0, 6.0)"], ["wait", 1.2], ["shot", "j1_right_110_6m"],
	["eval", H + ".jam_at(150.0, 6.0)"], ["wait", 1.2], ["shot", "j2_right_150_6m"],
	["eval", H + ".jam_at(180.0, 6.0)"], ["wait", 1.2], ["shot", "j3_behind_6m"],
	["eval", H + ".jam_at(-110.0, 4.0)"], ["wait", 1.2], ["shot", "j4_left_110_4m"],
	["eval", H + ".jam_at(-70.0, 13.0)"], ["wait", 1.2], ["shot", "j5_left_70_13m"],
	["eval", H + ".jam_at(35.0, 12.0)"], ["wait", 1.2], ["shot", "j6_in_frame_dark"],
	["eval", H + ".jam_at(0.0, 7.0)"], ["wait", 1.2], ["shot", "k0_before"],
	["eval", H + ".lock_now(0.8)"], ["shot", "k1"], ["shot", "k2"], ["shot", "k3"], ["shot", "k4"], ["shot", "k5"], ["shot", "k6"], ["shot", "k7"],
	["wait", 0.3], ["shot", "k8"], ["wait", 0.5], ["shot", "k9"],
]

const FILM_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["girl"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0], ["eval", "_set_player_health(100)"],
	["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 2.0],
	["eval", H + ".film_place(125.0, 13.0)"], ["wait", 3.2],
	["eval", H + ".turn(true, 170.0)"], ["wait", 2.6],
	["eval", H + ".turn(false, 200.0)"], ["wait", 2.4],
	["eval", H + ".turn(true, 260.0)"], ["wait", 2.2],
	["eval", "get_tree().quit()"],
]

const PROBE_STEPS := [
	["wait_menu"], ["call", "_on_menu_test_night", ["girl"]], ["wait", 4.0],
	["call", "_stop_active_enemy_brain", []], ["wait", 1.0],
	["eval", "debug_spawn_enemy('girl', 3)"], ["wait", 1.0],
	["eval", H + ".probe()"], ["wait", 0.5], ["eval", H + ".probe()"],
]


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--part=jam"):
		_steps = JAM_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=film"):
		_steps = FILM_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=probe"):
		_steps = PROBE_STEPS.duplicate(true)
		return
	if OS.get_cmdline_user_args().has("--part=hitch"):
		_steps = HITCH_STEPS.duplicate(true)
		return
	_steps = STAGE_STEPS.duplicate(true)
