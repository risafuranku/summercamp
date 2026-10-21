extends Node3D

## One lane of the camp's bowling alley (scripts/bowling/bowling_interior.gd keeps four):
## its ten pins, the ball, the chalkboard over it and the party bowling on it.
##
## A ball: the bowler gets up from the bench and steps up to the line holding the ball
## (pose "ball"), swings it (pose "bowl"), it rolls its way down (BowlingRules.roll, the
## lane squeezed to the room's), into the pins (BowlingRules.strike: which go, which way,
## which only rock), and the card counts. Then the pins wait to be set (`needs_set`: the
## deadwood swept after a frame's first ball, all ten racked after its last); who sets
## them, by hand in the pit, a hired boy or the machine, is the hall's business:
## set_pins() puts them back. Stepped twelve a second like the camp's machinery, the ball
## and the falling pins smooth.

signal ball_done(lane_index: int, down: int, strike: bool, spare: bool)

const RULES = preload("res://core/systems/bowling_rules.gd")
const LAYOUT = preload("res://scripts/bowling/bowling_layout.gd")
const PIN_MESH = preload("res://scripts/bowling/pin_mesh.gd")
const POSES = preload("res://scripts/attractions/poses.gd")
const FONT := "res://assets/fonts/pomono.fnt"
const SFX := "res://assets/sfx/bowling/"
## The ball takes this share of its real time on the room's shorter lane.
const VIS_TIME := 0.62
const PIN_H := 0.381
## How the guests bowl, by the kind of guest (0 never held a ball, 1 league).
const SKILL := {"drunk": 0.25, "tramp": 0.35, "quiet_guy": 0.6, "cheap_chick": 0.4, "picker": 0.5, "family": 0.3}

var index := 0
## {visit, name, members: [{id, name, base, skill, node, sprite, balls: []}], turn}
var party: Dictionary = {}
var standing: Array = []
## The pins wait for the pinsetter: "" (no), "sweep" (the deadwood off, the rest stay),
## "rack" (all ten again).
var needs_set := ""
var _pins: Array = []
var _ball: MeshInstance3D
var _board: Label3D
var _phase := "idle"
var _t := 0.0
var _throw := {}
var _anims: Array = []
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _sound: AudioStreamPlayer3D
var _roll_sound: AudioStreamPlayer3D


func setup(i: int) -> void:
	index = i
	name = "Lane%d" % i
	_rng.seed = 7919 * (i + 1)
	standing = RULES._all_up()
	var mat := PIN_MESH.material()
	var mesh := PIN_MESH.mesh(PIN_H, 10)
	var spots := RULES.pin_spots()
	for k in 10:
		var p := MeshInstance3D.new()
		p.name = "Pin%d" % (k + 1)
		p.mesh = mesh
		p.material_override = mat
		add_child(p)
		_pins.append(p)
		_place_pin(k)
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = RULES.BALL_R
	sm.height = RULES.BALL_R * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	_ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = [Color(0.08, 0.08, 0.1), Color(0.35, 0.08, 0.1), Color(0.1, 0.16, 0.34), Color(0.18, 0.2, 0.12)][i % 4]
	bm.roughness = 0.35
	_ball.material_override = bm
	_ball.visible = false
	add_child(_ball)
	# The chalkboard over the approach, facing the benches.
	var slate := MeshInstance3D.new()
	slate.name = "Slate"
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 0.62)
	slate.mesh = q
	var slm := StandardMaterial3D.new()
	slm.albedo_color = Color(0.12, 0.15, 0.13)
	slm.roughness = 1.0
	slate.material_override = slm
	slate.position = Vector3(float(LAYOUT.LANES[i]), 2.45, LAYOUT.FOUL_Z + 0.3)
	add_child(slate)
	_board = Label3D.new()
	_board.name = "Board"
	if ResourceLoader.exists(FONT):
		_board.font = load(FONT)
	_board.font_size = 24
	_board.pixel_size = 0.0042
	_board.modulate = Color(0.9, 0.9, 0.84)
	_board.outline_size = 0
	_board.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_board.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_board.position = slate.position + Vector3(-0.6, 0.28, 0.01)
	_board.text = ""
	add_child(_board)
	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 4.0
	_sound.position = LAYOUT.lane_point(i, 0.0, -0.3, 0.3)
	add_child(_sound)
	_roll_sound = AudioStreamPlayer3D.new()
	_roll_sound.unit_size = 4.0
	add_child(_roll_sound)


func busy() -> bool:
	return not party.is_empty()


## A party takes the lane: its people on the bench, the first one up after a moment.
func take(p: Dictionary) -> void:
	party = p
	party["turn"] = 0
	for k in (party["members"] as Array).size():
		var m: Dictionary = party["members"][k]
		m["balls"] = []
		# Over from the table (or the door) to the bench behind the lane.
		POSES.set_pose(m["sprite"], str(m["base"]), "")
		var node: Node3D = m["node"]
		var to := LAYOUT.bench_spot(index, k)
		_anims.append({"node": node, "from": node.position, "to": to, "t": -0.2 * k, "dur": maxf(0.4, node.position.distance_to(to) / 1.1), "sit": m})
	standing = RULES._all_up()
	needs_set = ""
	_seed = hash(str(party.get("visit", ""))) & 0xFFFFFF
	for k in 10:
		_place_pin(k)
	_phase = "wait"
	_t = _rng.randf_range(1.5, 3.5)
	_draw_board()


## The party goes (their visit is over): the lane stands empty, its pins up.
func release() -> Dictionary:
	var p := party
	party = {}
	_phase = "idle"
	_ball.visible = false
	_roll_sound.stop()
	standing = RULES._all_up()
	needs_set = ""
	for k in 10:
		_place_pin(k)
	_board.text = ""
	return p


## The pinsetter has done it: the deadwood gone, the standing ones straight, or all ten.
func set_pins() -> void:
	if needs_set == "rack":
		standing = RULES._all_up()
	for k in 10:
		_place_pin(k)
	needs_set = ""
	if _phase == "set":
		_phase = "wait"
		_t = _rng.randf_range(0.8, 1.8)


func _process(delta: float) -> void:
	_tick_anims(delta)
	if party.is_empty():
		return
	_t -= delta
	match _phase:
		"wait":
			if _t <= 0.0:
				_phase = "step"
				_t = 0.9
				var m := _bowler()
				POSES.set_pose(m["sprite"], str(m["base"]), "ball")
				_walk(m["node"], (m["node"] as Node3D).position, LAYOUT.lane_point(index, 0.0, RULES.LANE_LEN + 1.0) + Vector3(0, 0, 0.0), 0.9)
		"step":
			if _t <= 0.0:
				_phase = "hold"
				_t = 0.7
		"hold":
			if _t <= 0.0:
				_swing()
		"roll":
			_tick_roll()
		"fall":
			if _t <= 0.0:
				_count()


func _bowler() -> Dictionary:
	return party["members"][int(party.get("turn", 0)) % (party["members"] as Array).size()]


## The swing: the ball leaves the hand and goes its way.
func _swing() -> void:
	var m := _bowler()
	POSES.set_pose(m["sprite"], str(m["base"]), "bowl")
	var b := RULES.guest_ball(float(m.get("skill", 0.4)), standing, _rng)
	var path: Array
	var entry: Dictionary
	if bool(b["gutter"]):
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		entry = RULES.roll(side * 0.12, side * 0.035, float(b["speed"]), 0.0)
		if not bool(entry["gutter"]):
			entry = RULES.roll(side * 0.3, side * 0.06, float(b["speed"]), 0.0)
	else:
		var back := RULES.to_entry(float(b["x"]), float(b["angle"]), float(b["speed"]), float(b["hook"]))
		entry = RULES.roll(float(back["x0"]), float(back["aim"]), float(back["speed0"]), float(b["hook"]))
	path = entry["path"]
	_throw = {"entry": entry, "path": path, "t": 0.0, "dur": float(entry["t"]) * VIS_TIME, "gutter": bool(entry["gutter"])}
	_ball.visible = true
	_ball.position = _path_at(0.0)
	_phase = "roll"
	_play(_roll_sound, "roll.mp3", -6.0, _rng.randf_range(0.95, 1.05))


func _path_at(k: float) -> Vector3:
	var path: Array = _throw["path"]
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


func _tick_roll() -> void:
	_throw["t"] = float(_throw["t"]) + get_process_delta_time()
	var dur := maxf(0.2, float(_throw["dur"]))
	var k := float(_throw["t"]) / dur
	_ball.position = _path_at(k)
	_roll_sound.position = _ball.position
	_ball.rotate_x(-get_process_delta_time() * 14.0)
	if k < 1.0:
		return
	_roll_sound.stop()
	var entry: Dictionary = _throw["entry"]
	if bool(_throw["gutter"]):
		# Down the gutter and into the pit: nothing.
		_anims.append({"node": _ball, "from": _ball.position, "to": LAYOUT.lane_point(index, signf(float(entry["x"])) * (RULES.LANE_W + RULES.GUTTER_W) * 0.5, -1.0, -0.2), "t": 0.0, "dur": 0.35, "hide": true})
		_play(_sound, "gutter.mp3", -8.0, 1.0)
		_throw["result"] = {"down": [], "falls": {}, "wobbled": []}
	else:
		_seed += 1
		var res := RULES.strike(entry, standing, _seed)
		_throw["result"] = res
		var through := LAYOUT.lane_point(index, float(entry["x"]) + sin(float(entry["angle"])) * 0.9, -1.4, -0.2)
		_anims.append({"node": _ball, "from": _ball.position, "to": through, "t": 0.0, "dur": 0.32, "hide": true})
		for n in res["falls"]:
			_fall_pin(int(n) - 1, res["falls"][n])
		for n in res["wobbled"]:
			_anims.append({"node": _pins[int(n) - 1], "wobble": true, "t": 0.0, "dur": 0.9, "base": (_pins[int(n) - 1] as Node3D).rotation})
		var downs: Array = res["down"]
		if downs.size() >= 7:
			_play(_sound, "strike.mp3", -2.0, _rng.randf_range(0.95, 1.05))
		elif downs.size() > 0:
			_play(_sound, "pins_few.mp3", -4.0, _rng.randf_range(0.95, 1.05))
	_phase = "fall"
	_t = 1.5


## A pin goes over the way it was knocked, sliding on to where it ends (into the pit past
## the deck's end).
func _fall_pin(k: int, f: Dictionary) -> void:
	var pin: Node3D = _pins[k]
	var dir: Vector2 = f.get("dir", Vector2(0, -1))
	var to: Vector2 = f.get("to", RULES.pin_spots()[k])
	var into_pit := to.y < RULES.PIT_Z
	var end := LAYOUT.lane_point(index, clampf(to.x, -RULES.KICKBACK_X, RULES.KICKBACK_X), to.y, 0.06 + (-0.35 if into_pit else 0.02))
	# Over about the axis across the way it went (room: x across, -z down the lane).
	var axis := Vector3(dir.y, 0.0, -dir.x).normalized() if dir.length() > 0.001 else Vector3.RIGHT
	_anims.append({"node": pin, "from": pin.position, "to": end, "t": -float(f.get("t", 0.0)), "dur": 0.55, "axis": axis, "tilt": PI * 0.5, "hide": into_pit})


func _tick_anims(delta: float) -> void:
	for i in range(_anims.size() - 1, -1, -1):
		var a: Dictionary = _anims[i]
		a["t"] = float(a["t"]) + delta
		var t := float(a["t"])
		if t < 0.0:
			continue
		var node: Node3D = a["node"]
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
			if a.has("sit") and not party.is_empty() and _bowler() != a["sit"]:
				POSES.set_pose((a["sit"] as Dictionary)["sprite"], str((a["sit"] as Dictionary)["base"]), "sit")
			_anims.remove_at(i)


## The ball is counted: the card, the board, whose turn, and what the pinsetter must do.
func _count() -> void:
	var m := _bowler()
	var res: Dictionary = _throw.get("result", {"down": []})
	var down: Array = res["down"]
	var before := 0
	for s in standing:
		if s:
			before += 1
	for n in down:
		standing[int(n) - 1] = false
	var balls: Array = m["balls"]
	balls.append(down.size())
	var card := RULES.card(balls)
	var strike := down.size() == 10 and before == 10
	var spare := down.size() == before and before < 10
	ball_done.emit(index, down.size(), strike, spare)
	# The bowler back to the bench.
	var at := _members().find(m)
	_anims.append({"node": m["node"], "from": (m["node"] as Node3D).position, "to": LAYOUT.bench_spot(index, maxi(0, at)), "t": -0.6, "dur": 0.9, "sit": m})
	POSES.set_pose(m["sprite"], str(m["base"]), "")
	var frame_over := int(card["ball"]) == 0 or bool(card["done"])
	if frame_over:
		party["turn"] = int(party.get("turn", 0)) + 1
		needs_set = "rack"
		# A whole round done (everyone's tenth): another game.
		var all_done := true
		for mm in _members():
			if not bool(RULES.card(mm["balls"])["done"]):
				all_done = false
		if all_done:
			for mm in _members():
				mm["games"] = int(mm.get("games", 0)) + 1
				mm["last"] = int(RULES.card(mm["balls"])["total"])
				mm["balls"] = []
	else:
		# The tenth frame racks again after a strike or a spare.
		var fresh := true
		for s in card["standing"]:
			if not s:
				fresh = false
		needs_set = "rack" if fresh else "sweep"
	_phase = "set"
	_draw_board()


func _members() -> Array:
	return party.get("members", [])


func _draw_board() -> void:
	if party.is_empty():
		_board.text = ""
		return
	var lines: Array = []
	for m in _members():
		var card := RULES.card(m["balls"])
		var marks := ""
		var fr: Array = card["frames"]
		var from := maxi(0, int(card["frame"]) - 3)
		for f in range(from, mini(10, from + 4)):
			marks += "".join((fr[f]["marks"] as Array)).rpad(3) + " "
		var nm := str(m.get("name", "?")).split(" ")[0].substr(0, 8)
		lines.append("%s %s%3d" % [nm.rpad(8), marks, int(card["total"])])
	_board.text = "\n".join(lines)


func _place_pin(k: int) -> void:
	if k >= _pins.size():
		return
	var pin: MeshInstance3D = _pins[k]
	var spot: Vector2 = RULES.pin_spots()[k]
	pin.basis = Basis.IDENTITY
	pin.position = LAYOUT.lane_point(index, spot.x, spot.y, 0.06)
	pin.visible = k < standing.size() and bool(standing[k])


func _walk(node: Node3D, from: Vector3, to: Vector3, dur: float) -> void:
	_anims.append({"node": node, "from": from, "to": to, "t": 0.0, "dur": dur})


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
