extends Node3D

## One lane of the camp's bowling alley in the hall (scripts/bowling/bowling_interior.gd
## keeps four): its ten pins, the ball, the chalkboard over the approach and its party,
## all drawn from the lane's record in scripts/bowling/bowling.gd (sync(), every frame
## while the hall is open). The record bowls; this only shows it.
##
## A new ball in the record (its `seq`) is played: the bowler gets up from the bench and
## steps up to the line holding the ball (pose "ball"), swings it (pose "bowl"), it rolls
## the record's way down (BowlingRules.roll, the lane squeezed to the room's) into the
## pins; those the record took down go over the way they were knocked and lie where they
## ended, on the deck or back in the pit, those that rocked rock, and the board counts.
## Then they lie there until the record says the pins are up again (who did it is the
## record's business: the hand, the machine, you in the pit). In the pit you work the pins
## here yourself (scripts/bowling/pit_station.gd): take one, stand it on a spot, clear the
## deadwood into the pit, send the ball back. With a machine from the books (`machine`,
## set by the hall) its setting table comes down out from behind the masking panel, takes
## up the pins still standing, the sweep bar drops and clears the deadwood back into the
## pit, the table sets them down again (all ten after a frame) and goes back up, the ball
## back on the return; the Brnoswick does it quicker. With the score screens (`screens`)
## the chalkboard is a monitor. Stepped smooth, at the full frame rate.

const RULES = preload("res://core/systems/bowling_rules.gd")
const LAYOUT = preload("res://scripts/bowling/bowling_layout.gd")
const PIN_MESH = preload("res://scripts/bowling/pin_mesh.gd")
const POSES = preload("res://scripts/attractions/poses.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const KIT = preload("res://scripts/interior_kit.gd")
const BOARD_TEXT = preload("res://scripts/bowling/board_text.gd")
## The chalk's colour, and the screens' phosphor.
const CHALK := Color(0.9, 0.9, 0.84)
const PHOSPHOR := Color(0.55, 1.0, 0.5)
const SFX := "res://assets/sfx/bowling/"
## The ball takes this share of its real time on the room's shorter lane
## (bowling.gd ROLL_SHARE).
const VIS_TIME := 0.62
const PIN_H := 0.381
## The bowler's way up: to the line, holding the ball there, the swing; the pins falling.
const STEP_SEC := 0.9
const HOLD_SEC := 0.7
const FALL_SEC := 1.5
## Where the lying pins and the ball are in the pit behind the deck (the lane's metres
## from the head pin), and how high a lying pin's middle is off the floor.
const PIT_NEAR := -1.18
const PIT_FAR := -1.5
const LYING_Y := 0.05

var index := 0
var _visit := ""
var _seq := -1
var _rec: Dictionary = {}
## The party's figures, in the record's member order: [{node, sprite, base}].
var _figs: Array = []
## Each pin: {spot (the spot it stands on, -1 down), where ("up", "deck", "pit", "hand")}.
var _pin_state: Array = []
var _pins: Array = []
var _ball: MeshInstance3D
var _rack_ball: MeshInstance3D
## Where the ball is: "rack" (back at the front), "rolling", "pit" (lying behind the pins).
var _ball_at := "rack"
var _board: SubViewport
var _phase := "idle"
var _t := 0.0
var _throw := {}
var _anims: Array = []
var _rng := RandomNumberGenerator.new()
var _sound: AudioStreamPlayer3D
var _roll_sound: AudioStreamPlayer3D
## Pins down from the last ball until the record has them up again.
var _await_set := false
## The pinsetting machine over the deck: "", "machine" (the Stavomat), "brnoswick".
var machine := ""
## The score screens from the books: the chalkboard turns into a monitor.
var screens := false
var _table: MeshInstance3D
var _sweep: MeshInstance3D
## The machine's cycle playing ({} none): {t, k (its slowness), standing, lifted, fresh,
## done: {step: true}}.
var _cyc: Dictionary = {}
var _slate: MeshInstance3D
var _screens_were := false
## What the snack bar brought them, standing on the end of their bench.
var _snacks: Array = []
var _snacks_were: Array = []
## The table and the sweep bar: hidden at rest behind the masking panel (its lower edge),
## the table over the pin tops when it takes them, held up, set down on the deck.
const MASK_EDGE := 1.0
const TABLE_GRAB := 0.06 + PIN_H + 0.03
const TABLE_HOLD := 0.86
const TABLE_SET := 0.06 + PIN_H + 0.012
const SWEEP_LOW := 0.13


func setup(i: int) -> void:
	index = i
	name = "Lane%d" % i
	_rng.seed = 7919 * (i + 1)
	var mat := PIN_MESH.material()
	var mesh := PIN_MESH.mesh(PIN_H, 10)
	for k in 10:
		var p := MeshInstance3D.new()
		p.name = "Pin%d" % (k + 1)
		p.mesh = mesh
		p.material_override = mat
		add_child(p)
		_pins.append(p)
		_pin_state.append({"spot": k, "where": "up"})
		_place_pin(k)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = [Color(0.08, 0.08, 0.1), Color(0.35, 0.08, 0.1), Color(0.1, 0.16, 0.34), Color(0.18, 0.2, 0.12)][i % 4]
	bm.roughness = 0.35
	_ball = _ball_mesh(bm, "Ball")
	_ball.visible = false
	_rack_ball = _ball_mesh(bm, "RackBall")
	# On the rack of the return between the pair, this lane's side of it.
	var rx: float = LAYOUT.RETURNS[0 if i < 2 else 1]
	_rack_ball.position = Vector3(rx, 0.61 + RULES.BALL_R, LAYOUT.FOUL_Z + 0.9 + (0.2 if i % 2 == 0 else -0.2))
	_rack_ball.visible = false
	# The chalkboard over the approach, facing the benches.
	var slate := MeshInstance3D.new()
	slate.name = "Slate"
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 0.62)
	slate.mesh = q
	slate.material_override = KIT.surface(LAYOUT._tex_or("bowl_slate", "veneer_dark"), 0.7, Color(1, 1, 1) if ResourceLoader.exists(KIT.TEX + "bowl_slate.png") else Color(0.3, 0.42, 0.34))
	slate.position = Vector3(float(LAYOUT.LANES[i]), 2.45, LAYOUT.FOUL_Z + 0.3)
	# Not pulled out in front of its own chalk (retro_materials._pull_of).
	slate.set_meta("retro_no_pull", true)
	add_child(slate)
	_slate = slate
	# The chalk on it: the party's names, their last frames and the running total, written
	# by the 2D renderer onto a picture over the slate (board_text.gd).
	_board = BOARD_TEXT.new()
	_board.name = "BoardWords"
	add_child(_board)
	_board.setup(Vector2i(128, 61), RETRO_UI.FONT_LABEL, 8, CHALK)
	BOARD_TEXT.quad(self, _board, Vector2(1.3, 0.62), slate.position + Vector3(0, 0, 0.012), false)
	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 4.0
	_sound.position = LAYOUT.lane_point(i, 0.0, -0.3, 0.3)
	add_child(_sound)
	_roll_sound = AudioStreamPlayer3D.new()
	_roll_sound.unit_size = 4.0
	add_child(_roll_sound)


func _ball_mesh(m: Material, n: String) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	b.name = n
	var sm := SphereMesh.new()
	sm.radius = RULES.BALL_R
	sm.height = RULES.BALL_R * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	b.mesh = sm
	b.material_override = m
	add_child(b)
	return b


func busy() -> bool:
	return _visit != ""


## The hall closed: nothing shown is kept (its figures are gone); the next sync shows the
## record afresh.
func reset_view() -> void:
	_visit = ""
	_figs = []
	_rec = {}
	_anims.clear()
	_cyc = {}
	if _table != null:
		_table.visible = false
		_sweep.visible = false
	_phase = "idle"
	_throw = {}
	_await_set = false
	_roll_sound.stop()
	_ball.visible = false
	_rack_ball.visible = false
	_ball_at = "rack"
	_board.show_text("")
	_snacks_were = []
	_show_snacks([])
	for k in 10:
		_pin_state[k]["spot"] = k
		_pin_state[k]["where"] = "up"
		_place_pin(k)


## The lane as its record has it now (`rec`: bowling.gd's lane), its party's figures with
## it. A new party takes the bench; a new ball is played; the pins put up by whoever set
## them stand again.
func sync(rec: Dictionary, figs: Array) -> void:
	_rec = rec
	if screens != _screens_were:
		_screens_were = screens
		_dress_board()
	var sn: Array = rec.get("snacks", [])
	if sn != _snacks_were:
		_snacks_were = sn.duplicate()
		_show_snacks(sn)
	var visit := str(rec.get("visit", ""))
	if visit != _visit:
		_visit = visit
		# The last party's figures are the hall's again.
		_anims = _anims.filter(func(a) -> bool: return a["node"] is MeshInstance3D)
		_figs = figs
		_seq = int(rec.get("seq", 0))
		_phase = "idle"
		_throw = {}
		_cyc = {}
		if _table != null:
			_table.visible = false
			_sweep.visible = false
		_roll_sound.stop()
		_settle()
		_seat_all()
		_draw_board()
		return
	if figs.size() != _figs.size():
		_figs = figs
		_seat_all()
	var seq := int(rec.get("seq", 0))
	if _phase == "idle" and seq != _seq:
		if seq == _seq + 1 and not (rec.get("last", {}) as Dictionary).is_empty():
			_seq = seq
			_start_ball(rec["last"])
		else:
			_seq = seq
			_settle()
			_draw_board()
		return
	if _phase == "idle" and _await_set and str(rec.get("set", "")) == "":
		_await_set = false
		_reconcile(rec.get("standing", RULES._all_up()))


## Shown straight as the record has it (the hall just opened, balls were bowled while
## nobody looked): the pins up stand, the last ball's deadwood lies where it went while
## the pins wait, the rest are in the pit.
func _settle() -> void:
	_anims = _anims.filter(func(a) -> bool: return not (a["node"] is MeshInstance3D))
	var standing: Array = _rec.get("standing", RULES._all_up())
	var waiting := _visit != "" and str(_rec.get("set", "")) != ""
	var falls: Dictionary = ((_rec.get("last", {}) as Dictionary).get("res", {}) as Dictionary).get("falls", {}) if waiting else {}
	var pit_n := 0
	for k in 10:
		var st: Dictionary = _pin_state[k]
		var pin: Node3D = _pins[k]
		pin.basis = Basis.IDENTITY
		if bool(standing[k]):
			st["spot"] = k
			st["where"] = "up"
			_place_pin(k)
		elif falls.has(k + 1) or falls.has(str(k + 1)):
			var f: Dictionary = falls.get(k + 1, falls.get(str(k + 1), {}))
			_lie(k, f.get("to", RULES.pin_spots()[k]), f.get("dir", Vector2(0, -1)), false)
		else:
			_to_pit_now(k, pit_n)
			pit_n += 1
	_await_set = waiting
	_ball_at = "pit" if waiting else "rack"
	_ball.visible = waiting
	if waiting:
		_ball.position = _pit_ball_spot()
	_rack_ball.visible = _visit != "" and not waiting
	_phase = "idle"


## The pins as the record wants them now that they are set (`standing`): a pin on each
## spot that should have one, the rest and the deadwood back in the pit; the ball back.
## A machine does it in front of you (its cycle).
func _reconcile(standing: Array) -> void:
	if machine != "" and _visit != "":
		_start_cycle(standing)
		return
	var moved := false
	for k in 10:
		var st: Dictionary = _pin_state[k]
		if str(st["where"]) == "up" and not bool(standing[int(st["spot"])]):
			_to_pit_now(k, k)
			moved = true
		elif str(st["where"]) in ["deck", "hand"]:
			_to_pit_now(k, k)
			moved = true
	for s in 10:
		if not bool(standing[s]) or spot_taken(s) >= 0:
			continue
		for k in 10:
			if str(_pin_state[k]["where"]) == "pit":
				_stand_now(k, s)
				moved = true
				break
	if _ball_at == "pit":
		send_ball()
	if moved:
		_play(_sound, "pin_set.mp3", -8.0, _rng.randf_range(0.95, 1.05))
	_rack_ball.visible = _visit != ""


# ── the party ────────────────────────────────────────────────────────────────

## Everyone of the party to their place on the bench (from wherever they are), sitting
## when they get there; the bowler is the lane's to move.
func _seat_all() -> void:
	for k in _figs.size():
		var f: Dictionary = _figs[k]
		var node: Node3D = f.get("node")
		if node == null or not is_instance_valid(node):
			continue
		var to := LAYOUT.bench_spot(index, k)
		_anims = _anims.filter(func(a) -> bool: return a["node"] != node)
		POSES.set_pose(f["sprite"], str(f["base"]), "")
		_anims.append({"node": node, "from": node.position, "to": to, "t": -0.2 * k, "dur": maxf(0.4, node.position.distance_to(to) / 1.1), "sit": f})


func _bowler() -> Dictionary:
	var mi := int((_rec.get("last", {}) as Dictionary).get("member", 0))
	return _figs[mi] if mi < _figs.size() else {}


# ── a ball ───────────────────────────────────────────────────────────────────

func _start_ball(last: Dictionary) -> void:
	_throw = {"last": last, "entry": last.get("entry", {}), "path": (last.get("entry", {}) as Dictionary).get("path", []), "t": 0.0}
	var entry: Dictionary = _throw["entry"]
	_throw["dur"] = float(entry.get("t", 1.0)) * VIS_TIME
	_throw["gutter"] = bool(entry.get("gutter", false))
	_rack_ball.visible = false
	# A warden's ball leaves their hand at the line: no walk up, no swing to see.
	if bool(last.get("quick", false)):
		_swing()
		return
	_phase = "step"
	_t = STEP_SEC
	var m := _bowler()
	if not m.is_empty() and is_instance_valid(m["node"]):
		var node: Node3D = m["node"]
		_anims = _anims.filter(func(a) -> bool: return a["node"] != node)
		POSES.set_pose(m["sprite"], str(m["base"]), "ball")
		_anims.append({"node": node, "from": node.position, "to": LAYOUT.lane_point(index, 0.0, RULES.LANE_LEN + 1.0), "t": 0.0, "dur": STEP_SEC})


func _process(delta: float) -> void:
	_tick_anims(delta)
	if not _cyc.is_empty():
		_tick_cycle(delta)
		return
	if _phase == "idle":
		return
	_t -= delta
	match _phase:
		"step":
			if _t <= 0.0:
				_phase = "hold"
				_t = HOLD_SEC
		"hold":
			if _t <= 0.0:
				_swing()
		"roll":
			_tick_roll(delta)
		"fall":
			if _t <= 0.0:
				_count()


## The swing: the ball leaves the hand and goes its way.
func _swing() -> void:
	var m := _bowler()
	if not m.is_empty():
		POSES.set_pose(m["sprite"], str(m["base"]), "bowl")
	_ball.visible = true
	_ball.basis = Basis.IDENTITY
	_ball.position = _path_at(0.0)
	_ball_at = "rolling"
	_phase = "roll"
	_play(_roll_sound, "roll.mp3", -6.0, _rng.randf_range(0.95, 1.05))


func _path_at(k: float) -> Vector3:
	var path: Array = _throw.get("path", [])
	if path.is_empty():
		return LAYOUT.lane_point(index, 0.0, RULES.LANE_LEN, RULES.BALL_R + 0.06)
	var tt := clampf(k, 0.0, 1.0) * float((path.back() as Vector3).z)
	var prev: Vector3 = path[0]
	for p in path:
		var v: Vector3 = p
		if v.z >= tt:
			var span := maxf(0.0001, v.z - prev.z)
			var f := clampf((tt - prev.z) / span, 0.0, 1.0)
			var x := lerpf(prev.x, v.x, f)
			var z := lerpf(prev.y, v.y, f)
			var drop := 0.0
			if bool(_throw.get("gutter", false)) and absf(x) > RULES.LANE_W * 0.5:
				drop = 0.05
			return LAYOUT.lane_point(index, x, z, RULES.BALL_R + 0.06 - drop)
		prev = v
	var last: Vector3 = path.back()
	return LAYOUT.lane_point(index, last.x, last.y, RULES.BALL_R + 0.06)


func _tick_roll(delta: float) -> void:
	_throw["t"] = float(_throw["t"]) + delta
	var dur := maxf(0.2, float(_throw["dur"]))
	var k := float(_throw["t"]) / dur
	_ball.position = _path_at(k)
	_roll_sound.position = _ball.position
	_ball.rotate_x(-delta * 14.0)
	if k < 1.0:
		return
	_roll_sound.stop()
	var entry: Dictionary = _throw["entry"]
	var res: Dictionary = (_throw["last"] as Dictionary).get("res", {})
	# Down the gutter or through the pins, into the pit where it lies till it is sent back.
	_anims.append({"node": _ball, "from": _ball.position, "to": _pit_ball_spot(), "t": 0.0, "dur": 0.32})
	_ball_at = "pit"
	if bool(_throw["gutter"]):
		_play(_sound, "gutter.mp3", -8.0, 1.0)
	else:
		var falls: Dictionary = res.get("falls", {})
		for n in falls:
			_fall_pin(int(n) - 1, falls[n])
		for n in res.get("wobbled", []):
			var pin: Node3D = _pins[int(n) - 1]
			_anims.append({"node": pin, "wobble": true, "t": 0.0, "dur": 0.9, "base": pin.rotation})
		var downs: Array = res.get("down", [])
		if downs.size() >= 7:
			_play(_sound, "strike.mp3", -2.0, _rng.randf_range(0.95, 1.05))
		elif downs.size() > 0:
			_play(_sound, "pins_few.mp3", -4.0, _rng.randf_range(0.95, 1.05))
	_phase = "fall"
	_t = FALL_SEC
	_throw["entry_x"] = float(entry.get("x", 0.0))


## Where the ball lies in the pit (room space): behind its lane, a little to the side it
## went.
func _pit_ball_spot() -> Vector3:
	var x := 0.0
	if not _throw.is_empty():
		var e: Dictionary = _throw.get("entry", {})
		x = clampf(float(e.get("x", 0.0)) + sin(float(e.get("angle", 0.0))) * 0.6, -0.45, 0.45)
	return LAYOUT.lane_point(index, x, -1.32, RULES.BALL_R)


## A pin goes over the way it was knocked, sliding on to where it ends (into the pit past
## the deck's end).
func _fall_pin(k: int, f: Dictionary) -> void:
	var dir: Vector2 = f.get("dir", Vector2(0, -1))
	var to: Vector2 = f.get("to", RULES.pin_spots()[k])
	var into_pit := to.y < RULES.PIT_Z
	var st: Dictionary = _pin_state[k]
	st["spot"] = -1
	st["where"] = "pit" if into_pit else "deck"
	var end := _lie_point(to, into_pit)
	var pin: Node3D = _pins[k]
	_anims.append({"node": pin, "from": pin.position, "to": end, "t": -float(f.get("t", 0.0)), "dur": 0.55, "axis": _axis_of(dir), "tilt": PI * 0.5})


func _axis_of(dir: Vector2) -> Vector3:
	# Over about the axis across the way it went (room: x across, -z down the lane).
	return Vector3(dir.y, 0.0, -dir.x).normalized() if dir.length() > 0.001 else Vector3.RIGHT


func _lie_point(to: Vector2, into_pit: bool) -> Vector3:
	var x := clampf(to.x, -RULES.KICKBACK_X + 0.06, RULES.KICKBACK_X - 0.06)
	var z := clampf(to.y, PIT_FAR, PIT_NEAR) if into_pit else to.y
	return LAYOUT.lane_point(index, x, z, LYING_Y if into_pit else 0.06 + LYING_Y)


## A pin lying where it went (at once).
func _lie(k: int, to: Vector2, dir: Vector2, _anim: bool) -> void:
	var into_pit := to.y < RULES.PIT_Z
	var st: Dictionary = _pin_state[k]
	st["spot"] = -1
	st["where"] = "pit" if into_pit else "deck"
	var pin: Node3D = _pins[k]
	pin.visible = true
	pin.position = _lie_point(to, into_pit)
	pin.basis = Basis(_axis_of(dir), PI * 0.5)


## The ball has gone through and the pins have fallen: the bowler back to the bench, the
## board counts it.
func _count() -> void:
	var m := _bowler()
	if not m.is_empty() and is_instance_valid(m["node"]):
		var at := _figs.find(m)
		var node: Node3D = m["node"]
		POSES.set_pose(m["sprite"], str(m["base"]), "")
		_anims.append({"node": node, "from": node.position, "to": LAYOUT.bench_spot(index, maxi(0, at)), "t": -0.6, "dur": 0.9, "sit": m})
	var last: Dictionary = _throw.get("last", {})
	var res: Dictionary = last.get("res", {})
	var down := (res.get("down", []) as Array).size()
	var before := int(last.get("before", 10))
	if down == 10 and before == 10:
		_play(_sound, "cheer.mp3", -10.0, 1.0)
	elif down == 0 and before == 10:
		_play(_sound, "groan.mp3", -12.0, 1.0)
	_phase = "idle"
	_await_set = true
	_draw_board()
	# The record may have the pins up already (a hand quicker than the pins fell).
	if str(_rec.get("set", "")) == "":
		_await_set = false
		_reconcile(_rec.get("standing", RULES._all_up()))


func _tick_anims(delta: float) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		a["t"] = float(a["t"]) + delta
		var t := float(a["t"])
		if t < 0.0:
			continue
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			_anims.remove_at(i)
			continue
		var k := clampf(t / float(a["dur"]), 0.0, 1.0)
		if bool(a.get("wobble", false)):
			node.rotation = (a["base"] as Vector3) + Vector3(sin(t * 22.0) * 0.12 * (1.0 - k), 0, cos(t * 19.0) * 0.08 * (1.0 - k))
		else:
			node.position = (a["from"] as Vector3).lerp(a["to"], 1.0 - (1.0 - k) * (1.0 - k))
			if a.has("axis"):
				node.basis = Basis(a["axis"], float(a["tilt"]) * minf(1.0, k * 2.2))
			if bool(a.get("hide", false)) and k >= 1.0:
				node.visible = false
		if k >= 1.0:
			if bool(a.get("wobble", false)):
				node.rotation = a["base"]
			if a.has("sit") and (_phase == "idle" or _bowler() != a["sit"]):
				POSES.set_pose((a["sit"] as Dictionary)["sprite"], str((a["sit"] as Dictionary)["base"]), "sit")
			_anims.remove_at(i)


func _draw_board() -> void:
	var members: Array = _rec.get("members", [])
	if _visit == "" or members.is_empty():
		_board.show_text("")
		return
	var lines: Array = []
	for m in members:
		var card := RULES.card(m.get("balls", []))
		# The last three frames as a score sheet has them, a ball a box: "3 6|X  |9 /".
		var boxes: Array = []
		var fr: Array = card["frames"]
		var from := clampi(int(card["frame"]) - 2, 0, 7)
		for f in range(from, from + 3):
			boxes.append(" ".join(fr[f]["marks"] as Array).rpad(3))
		var nm := tr(str(m.get("name", "?"))).substr(0, 6).to_upper()
		lines.append("%s %s %3d" % [nm.rpad(6), "|".join(boxes), int(card["total"])])
	_board.show_text("\n".join(lines))


# ── the machine ──────────────────────────────────────────────────────────────

func _make_machine() -> void:
	if _table != null:
		return
	var steel := KIT.surface(LAYOUT._tex_or("bowl_machine", "steel_brushed"), 0.5, Color(0.8, 0.82, 0.8))
	_table = KIT.slab(self, Vector3(RULES.LANE_W + 0.1, 0.05, 1.0), LAYOUT.lane_point(index, 0.0, -0.4, MASK_EDGE), steel, "SettingTable")
	_table.visible = false
	_sweep = KIT.slab(self, Vector3(RULES.LANE_W + RULES.GUTTER_W * 2.0, 0.12, 0.04), LAYOUT.lane_point(index, 0.0, 0.25, MASK_EDGE), steel, "SweepBar")
	_sweep.visible = false


## The machine sets the pins: the standing ones taken up, the deadwood swept back into the
## pit, the pins set down where the record has them, the ball sent back.
func _start_cycle(standing: Array) -> void:
	_make_machine()
	# The Stavomat's grey-green iron or the Brnoswick's enamel.
	var paint := KIT.surface(LAYOUT._tex_or("bowl_brnoswick" if machine == "brnoswick" else "bowl_machine", "steel_brushed"), 0.5, Color(0.8, 0.82, 0.8))
	_table.material_override = paint
	_sweep.material_override = paint
	var lifted: Array = []
	for k in 10:
		var st: Dictionary = _pin_state[k]
		if str(st["where"]) == "up":
			if bool(standing[int(st["spot"])]):
				lifted.append(k)
			else:
				st["where"] = "deck"
				st["spot"] = -1
		elif str(st["where"]) == "hand":
			_to_pit_now(k, k)
	_anims = _anims.filter(func(a) -> bool: return not (a["node"] in _pins))
	_cyc = {"t": 0.0, "k": 0.67 if machine == "brnoswick" else 1.0, "standing": standing.duplicate(), "lifted": lifted, "fresh": [], "done": {}}
	_phase = "cycle"
	if _ball_at == "pit":
		send_ball()
	_play(_sound, "machine_cycle.mp3", -5.0, 1.25 if machine == "brnoswick" else _rng.randf_range(0.95, 1.03))


func _tick_cycle(delta: float) -> void:
	var c := _cyc
	c["t"] = float(c["t"]) + delta / float(c["k"])
	var t := float(c["t"])
	var done: Dictionary = c["done"]
	# The table: down to the pin tops, up with the standing ones, down to set, back up.
	var ty := MASK_EDGE
	if t < 0.3:
		ty = lerpf(MASK_EDGE, TABLE_GRAB, _ease(t / 0.3))
	elif t < 0.5:
		ty = lerpf(TABLE_GRAB, TABLE_HOLD, _ease((t - 0.3) / 0.2))
	elif t < 1.3:
		ty = TABLE_HOLD
	elif t < 1.65:
		ty = lerpf(TABLE_HOLD, TABLE_SET, _ease((t - 1.3) / 0.35))
	elif t < 2.0:
		ty = lerpf(TABLE_SET, MASK_EDGE, _ease((t - 1.65) / 0.35))
	_table.position.y = ty
	_table.visible = t < 2.0
	# The sweep bar: drops in front of the deck, sweeps back over it into the pit, goes up.
	var sy := MASK_EDGE
	var sz := 0.25
	if t >= 0.5 and t < 0.7:
		sy = lerpf(MASK_EDGE, SWEEP_LOW, _ease((t - 0.5) / 0.2))
	elif t >= 0.7 and t < 1.15:
		sy = SWEEP_LOW
		sz = lerpf(0.25, -1.3, (t - 0.7) / 0.45)
	elif t >= 1.15 and t < 1.3:
		sy = lerpf(SWEEP_LOW, MASK_EDGE, (t - 1.15) / 0.15)
		sz = -1.3
	_sweep.position = LAYOUT.lane_point(index, 0.0, sz, sy)
	_sweep.visible = sy < MASK_EDGE - 0.001
	# The deadwood in front of the bar goes before it, over the deck's end into the pit.
	if t >= 0.7 and t < 1.15:
		for k in 10:
			if str(_pin_state[k]["where"]) != "deck":
				continue
			var pin: Node3D = _pins[k]
			var lz := pin.position.z - LAYOUT.HEAD_Z
			if lz > sz - 0.09:
				pin.position.z = LAYOUT.HEAD_Z + sz - 0.09
				if sz - 0.09 < RULES.PIT_Z:
					pit_pin(k)
	if t >= 1.15 and not done.has("swept"):
		done["swept"] = true
		for k in 10:
			if str(_pin_state[k]["where"]) == "deck":
				pit_pin(k)
	# A fresh pin for every spot that has to stand and nothing in the table for it.
	if t >= 1.3 and not done.has("fresh"):
		done["fresh"] = true
		var held := {}
		for k in c["lifted"]:
			held[int(_pin_state[k]["spot"])] = true
		var standing: Array = c["standing"]
		for s in 10:
			if not bool(standing[s]) or held.has(s):
				continue
			for k in 10:
				if str(_pin_state[k]["where"]) == "pit":
					_anims = _anims.filter(func(a) -> bool: return a["node"] != _pins[k])
					_pin_state[k]["where"] = "table"
					_pin_state[k]["spot"] = s
					(_pins[k] as Node3D).basis = Basis.IDENTITY
					(c["fresh"] as Array).append(k)
					break
	# What hangs in the table moves with it.
	if t >= 0.3 and t < 1.65:
		for k in c["lifted"]:
			_hang(k, ty)
		for k in c["fresh"]:
			_hang(k, ty)
	if t >= 1.65 and not done.has("set"):
		done["set"] = true
		for k in (c["lifted"] as Array) + (c["fresh"] as Array):
			_stand_now(k, int(_pin_state[k]["spot"]))
		_play(_sound, "pin_set.mp3", -12.0, 1.1 if machine == "brnoswick" else 0.95)
	if t >= 2.0:
		_table.visible = false
		_sweep.visible = false
		_cyc = {}
		_phase = "idle"
		if _visit != "":
			_rack_ball.visible = _ball_at == "rack"


## A pin held in the setting table at its spot, its foot under the table at `ty`.
func _hang(k: int, ty: float) -> void:
	var pin: Node3D = _pins[k]
	var p := spot_point(int(_pin_state[k]["spot"]))
	pin.position = Vector3(p.x, ty - PIN_H - 0.012, p.z)
	pin.visible = true


static func _ease(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The chalkboard, or with the score screens a monitor in a steel case: dark glass, the
## figures in phosphor green.
func _dress_board() -> void:
	if _slate == null:
		return
	var case_node := get_node_or_null("ScreenCase")
	if screens:
		_slate.material_override = _screen_glass()
		_board.set_colour(PHOSPHOR)
		if case_node == null:
			var cs := KIT.slab(self, Vector3(1.42, 0.74, 0.32), _slate.position + Vector3(0, 0, -0.17), KIT.surface(LAYOUT._tex_or("bowl_machine", "steel_brushed"), 0.6, Color(0.35, 0.36, 0.35)), "ScreenCase")
			cs.name = "ScreenCase"
	else:
		_slate.material_override = KIT.surface(LAYOUT._tex_or("bowl_slate", "veneer_dark"), 0.7, Color(1, 1, 1) if ResourceLoader.exists(KIT.TEX + "bowl_slate.png") else Color(0.3, 0.42, 0.34))
		_board.set_colour(CHALK)
		if case_node != null:
			case_node.queue_free()


## The monitor's glass: its picture once over the slate, glowing a little of itself (the
## emission's colour black: the picture alone glows, retro_materials adds the two).
static var _glass: StandardMaterial3D


static func _screen_glass() -> StandardMaterial3D:
	if _glass != null:
		return _glass
	var path := KIT.TEX + "bowl_screen.png"
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		m.albedo_texture = t
		m.emission_enabled = true
		m.emission = Color(0, 0, 0)
		m.emission_texture = t
		m.emission_energy_multiplier = 0.7
	else:
		m.albedo_color = Color(0.05, 0.08, 0.06)
	_glass = m
	return m


## The beer, the Kofola, the hot dog the snack bar brought, on the little table by the bench.
func _show_snacks(items: Array) -> void:
	for s in _snacks:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_snacks.clear()
	var tex := {"beer": "beer", "kofola": "kofola", "hotdog": "hotdog", "pickled": "pickled", "crisps": "crisps", "tatranka": "wafer"}
	for k in items.size():
		var path := "res://assets/textury/bowling/%s.png" % str(tex.get(str(items[k]), items[k]))
		if not ResourceLoader.exists(path):
			continue
		var t: Texture2D = load(path)
		var s := Sprite3D.new()
		s.name = "Snack"
		s.texture = t
		s.pixel_size = 0.16 / float(maxi(t.get_width(), t.get_height()))
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.offset = Vector2(0, float(t.get_height()) * 0.5)
		s.position = LAYOUT.snack_table(index) + Vector3(-0.12 + 0.12 * float(k % 3), 0.0, -0.08 + 0.14 * floorf(float(k) / 3.0))
		add_child(s)
		_snacks.append(s)


# ── the pins, for the pit ────────────────────────────────────────────────────

func pin_node(k: int) -> MeshInstance3D:
	return _pins[k]


## Where pin `k` is: "up", "deck", "pit", "hand".
func pin_where(k: int) -> String:
	return str(_pin_state[k]["where"])


## The pin standing on spot `s` (-1 none).
func spot_taken(s: int) -> int:
	for k in 10:
		if str(_pin_state[k]["where"]) == "up" and int(_pin_state[k]["spot"]) == s:
			return k
	return -1


## Pins lying on the deck (the deadwood).
func deadwood() -> Array:
	var out: Array = []
	for k in 10:
		if str(_pin_state[k]["where"]) == "deck":
			out.append(k)
	return out


func standing_count() -> int:
	var n := 0
	for k in 10:
		if str(_pin_state[k]["where"]) == "up":
			n += 1
	return n


## The ball lies in the pit (to be sent back).
func ball_in_pit() -> bool:
	return _ball_at == "pit" and _phase == "idle"


func ball_node() -> MeshInstance3D:
	return _ball


## The ball onto the return: it rolls up under the capping and comes out on the rack.
func send_ball() -> void:
	if _ball_at != "pit":
		return
	_ball_at = "rack"
	var to := _ball.position + Vector3(float(LAYOUT.RETURNS[0 if index < 2 else 1]) - _ball.position.x, -0.2, 0.0)
	_anims.append({"node": _ball, "from": _ball.position, "to": to, "t": 0.0, "dur": 0.4, "hide": true})
	_play(_sound, "ball_return.mp3", -9.0, _rng.randf_range(0.95, 1.05))
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void:
		if _ball_at == "rack" and _visit != "" and _phase == "idle":
			_rack_ball.visible = true)


## Pin `k` taken up into the pinsetter's hand (off the deck or out of the pit).
func take_pin(k: int) -> bool:
	if not (pin_where(k) in ["deck", "pit"]):
		return false
	_anims = _anims.filter(func(a) -> bool: return a["node"] != _pins[k])
	_pin_state[k]["where"] = "hand"
	_pin_state[k]["spot"] = -1
	(_pins[k] as Node3D).basis = Basis.IDENTITY
	return true


## Pin `k` (in the hand) stood on spot `s`.
func stand_pin(k: int, s: int) -> bool:
	if spot_taken(s) >= 0:
		return false
	_stand_now(k, s)
	_play(_sound, "pin_set.mp3", -14.0, _rng.randf_range(1.05, 1.2))
	return true


## Pin `k` back into the pit (the deadwood cleared, or dropped from the hand).
func pit_pin(k: int) -> void:
	_anims = _anims.filter(func(a) -> bool: return a["node"] != _pins[k])
	var pin: Node3D = _pins[k]
	var to := _pit_slot(k)
	_pin_state[k]["where"] = "pit"
	_pin_state[k]["spot"] = -1
	_anims.append({"node": pin, "from": pin.position, "to": to, "t": 0.0, "dur": 0.22, "axis": Vector3(1, 0, 0.3).normalized(), "tilt": PI * 0.5})


func _stand_now(k: int, s: int) -> void:
	_anims = _anims.filter(func(a) -> bool: return a["node"] != _pins[k])
	_pin_state[k]["where"] = "up"
	_pin_state[k]["spot"] = s
	_place_pin(k)


func _to_pit_now(k: int, slot: int) -> void:
	_anims = _anims.filter(func(a) -> bool: return a["node"] != _pins[k])
	_pin_state[k]["where"] = "pit"
	_pin_state[k]["spot"] = -1
	var pin: Node3D = _pins[k]
	pin.visible = true
	pin.position = _pit_slot(slot)
	pin.basis = Basis(Vector3(1, 0, 0.25 * float(slot % 3 - 1)).normalized(), PI * 0.5)


## A place in the pit for the `n`th pin lying there (the lane's own trough).
func _pit_slot(n: int) -> Vector3:
	var x := -0.5 + float(n % 5) * 0.25 + (0.06 if n >= 5 else 0.0)
	var z := PIT_NEAR - 0.08 - (0.16 if n >= 5 else 0.0)
	return LAYOUT.lane_point(index, x, z, LYING_Y)


## The spot `s`'s place on the deck (room space, the deck's top).
func spot_point(s: int) -> Vector3:
	var spot: Vector2 = RULES.pin_spots()[s]
	return LAYOUT.lane_point(index, spot.x, spot.y, 0.06)


func _place_pin(k: int) -> void:
	if k >= _pins.size():
		return
	var pin: MeshInstance3D = _pins[k]
	pin.basis = Basis.IDENTITY
	pin.position = spot_point(int(_pin_state[k]["spot"]))
	pin.visible = true


func _play(p: AudioStreamPlayer3D, file: String, db: float, pitch: float) -> void:
	var path := SFX + file
	if not ResourceLoader.exists(path):
		return
	if p == _roll_sound:
		p.position = _ball.position
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
