extends CanvasLayer

## The pipe crawl: fixing a broken sewer from the inside (DESIGN.md §8).
##
## A pipe network is generated for each breakdown (seeded by the sewer and the day it
## broke, so leaving and coming back finds the same pipes). You crawl it in first
## person: W moves to the next junction, A/D take a side branch at a junction, there is
## no turning around. Hold TAB to read the paper map the last worker left: it shows the
## pipes, the coordinates, the entry ladder, the leak (red X) and a few landmarks, but
## not where you are. While you read, you are not moving. Coordinates are stencilled
## at some junctions only; between them you count turns, or recognise a landmark.
## At the leak, hold E to clamp it; then find your way back to the ladder and press E.
##
## Something lives down here, and how much of it you meet grows with your visits; what
## it is and how it is staged is scripts/pipes/pipe_director.gd. The rules, which the old
## worker's note on the map spells out:
##   - It is blind. It hunts by sound: every step you take splashes, and the clamp rings
##     louder. It goes to where it last heard you.
##   - It hates light. Keep the torch on it down a straight pipe and it folds away.
##   - You hear it before you see it: knocks and splashes far off, breathing when it is
##     next to you. Hold S to look back over your shoulder.
##   - If it reaches you it drags you back through the dark to the ladder (and hurts):
##     a half-done clamp slips off. The job is not lost, the time is.
##
## The look of it: you climb down the ladder, the worker's map unfolds for a moment,
## your gloved hand holds the torch in front of you (a Build-engine weapon sprite), the
## water along the bottom of the pipes runs away from the leak (follow it upstream), it
## drips, the torch stutters when something is close.

signal repair_completed(coord: Vector2i, building_type: String)
signal repair_cancelled
signal player_hurt(amount: int)

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")

const PIPE_TEXTURE := "res://assets/textury/pipes/pipe_concrete.png"
## The old 1962 sections that the 1993 works did not reach: brick.
const BRICK_TEXTURE := "res://assets/textury/pipes/pipe_brick.png"
const SHOE_SPRITE := "res://assets/textury/pipes/red_shoe.png"
## The other kinds of pipe: rusted corrugated steel (it rings), concrete gone to slime.
const STEEL_TEXTURE := "res://assets/textury/pipes/pipe_steel.png"
const SLIME_TEXTURE := "res://assets/textury/pipes/pipe_slime.png"
## What grows and lies down here.
const DRESS_MOSS := "res://assets/textury/pipes/decal_moss.png"
const DRESS_FUNGUS := "res://assets/textury/pipes/decal_fungus.png"
const DRESS_ROOTS := "res://assets/textury/pipes/spr_roots.png"
const DRESS_HAIR := "res://assets/textury/pipes/spr_hair.png"
const DRESS_RAT := "res://assets/textury/pipes/spr_rat_dead.png"
const DRESS_TEDDY := "res://assets/textury/pipes/spr_teddy.png"
## Every sound down here goes through one bus: a long hard echo, a metal ring after it.
const BUS := "PipeEcho"
const SCRATCHES := "res://assets/textury/mess/decal_scratches.png"
const PAPER_TEXTURE := "res://assets/textury/pipes/paper_map.png"
const DIRECTOR = preload("res://scripts/pipes/pipe_director.gd")
const OMENS = preload("res://scripts/omens.gd")
const CATCH = preload("res://scripts/pipes/pipe_catch.gd")
const PIPE_VIBE = preload("res://scripts/pipes/pipe_vibe.gd")
const PIPE_REPAIR = preload("res://scripts/pipes/pipe_repair.gd")
## What a hole takes to shut (pipes/pipe_repair.gd; the clamp is held E right here). The
## harder the night, the more kinds of work.
const REPAIRS_BY_LEVEL := [["clamp", "bolts", "valve"], ["clamp", "bolts", "valve", "tar", "clog"], ["bolts", "valve", "tar", "clog", "clog"]]
## The free hand crawling: reaching, and planted on the wet floor (the open right glove,
## mirrored, until they are made).
const HAND_REACH := "res://assets/textury/hands/crawl_reach.png"
const HAND_PLANT := "res://assets/textury/hands/crawl_plant.png"
const WORK_HAND = preload("res://scripts/ui/work_hand.gd")
const WATER_SHADER = preload("res://materials/pipe_water.gdshader")
## Two in the pipes (co-op): the other warden's body in them (scripts/pipes/pipe_mate.gd).
const PIPE_MATE = preload("res://scripts/pipes/pipe_mate.gd")
const PIPE_BOY = preload("res://scripts/pipes/pipe_boy.gd")
## The family's boy down here tonight (scripts/pipes/pipe_boy.gd: tag), null none; his
## tier at the sewer's job (night_jobs.boy_tier_at): light only him, medium only the
## raccoon, heavy both (the user, 21. 10.).
var _boy
var boy_tier := 0
var mate = PIPE_MATE.new()
## The day the sewer broke (the network's seed with its place).
var _since_day := 1
## Crawling back feet first (tap S: out of the other warden's way).
var _backing := false
var _s_down_at := -1.0
## Down with nothing broken (in through the chamber's pipe mouth just to see): every
## hole already clamped, nothing to mend, the raccoon as ever.
var explore := false
const HAND_TORCH := "res://assets/textury/hands/torch.png"
## On the view: its blood running down, and a lump of its guts (the original raccoon art).
const GUTS_SPLATS := ["res://assets/textury/pipes/rac/rac_hblood.png", "res://assets/textury/pipes/rac/rac_hblood.png", "res://assets/textury/pipes/rac/rac_hpile.png"]
const HANDPRINT := "res://assets/textury/mess/decal_handprint.png"
const SCUM := "res://assets/textury/pipes/sludge.png"
const SFX_DIR := "res://assets/sfx/pipes/"
const SFX_AMBIENCE := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const SFX_PIPES := "res://assets/sfx/ambiencesfx/pipesambience.mp3"
const SFX_LEAK := "res://assets/sfx/weather/calmrain.mp3"
const SFX_THING := "res://assets/sfx/npc/silentdistract2.mp3"
const SFX_CLANK := "res://assets/sfx/rednecksfx/rrtick.wav"

## The largest network (the map's letters and the terminal's grid go this far); each
## breakdown makes its own size and shape inside it (`_grid`, `_generate`).
const GRID := Vector2i(8, 6)
const COLS := "ABCDEFGH"
const CELL := 3.2
## Cramped: a pipe you crawl in, not a tunnel you walk. The old brick ones are tighter.
const PIPE_R := 0.40
const BRICK_R := 0.33
const ARM_R := 0.50
const ARM_LEN := 1.0
const SIDES := 10
const EYE_Y := 0.40
## One pipe is three pulls: the free hand reaches, plants, the body drags after it.
const PULLS := 3
const PULL_SECONDS := 0.62
const BRICK_SLOW := 1.25
const TURN_SECONDS := 0.62
## At a junction you lie still and turn your head into a side pipe (A/D, or the pointer
## to that side); W or a click then takes you in. How far the head turns, in radians.
const LOOK_YAW := 1.32
const TEACH_JUNCTIONS := 2
const CLAMP_SECONDS := 2.6
const HAND_OPEN := "res://assets/textury/hands/open.png"
## The mouse: a click on the left or right third turns, in the middle crawls on; the
## torch and the head follow the pointer a little.
const AIM_YAW := 0.16
const AIM_PITCH := 0.10
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
const DIR_YAW := [0.0, -PI * 0.5, PI, PI * 0.5]
const LANDMARKS := ["crack", "tally", "rags", "bucket", "shoe", "scratches"]
const LANDMARK_MAP_GLYPH := {"crack": "~", "tally": "IIII", "rags": "#", "bucket": "o", "shoe": "!", "scratches": "///"}

var _active: bool = false
var _coord: Vector2i = Vector2i.ZERO
var _building_type: String = ""
var _rng := RandomNumberGenerator.new()

# network
var _links: Dictionary = {}
## This network: its size, and where its columns and rows lie (pipes of different lengths).
var _grid := Vector2i(6, 5)
var _col_x: Array[float] = []
var _row_z: Array[float] = []      # Vector2i -> Array[int] of open directions
var _entry: Vector2i
var _leak_a: Vector2i              # the first hole (the map's pen, the old callers)
var _leak_b: Vector2i
## The holes it chewed: {a, b, fixed, fx, audio}. More of them the harder the night
## presses (raccoon_level).
var _leaks: Array = []
var _cur_leak := -1
## How much the night presses on the camp (omens.pressure) when you climbed down, and
## what the raccoon makes of it (1-3, pipe_director.mischief_level). debug_level > 0
## overrides it (shot driver).
var night_pressure := 1.0
var raccoon_level := 1
var debug_level := -1
## Stuck in its snare of guts: pulls left to tear free.
var _stuck := false
var _stuck_need := 0
var _gore := 0.0                   # how much of it is on your gloves
var _splats: Array = []            # {node, t, life, v}
var _catch                         # pipes/pipe_catch.gd: what it does to you
var _vibe                          # pipes/pipe_vibe.gd: breath, drops, the surge, chalk, scares
var _repair                        # pipes/pipe_repair.gd: the close-up work at a hole
## The trickle along the pipes: its quads and materials (the surge raises and speeds them).
var _water_meshes: Array = []
var _water_mats: Array = []
var _hand_reach: Texture2D
var _hand_plant: Texture2D
var _caught_fade := false
var _plates: Dictionary = {}     # Vector2i -> true
var _landmarks: Array = []       # {a, b, kind, on_map}
var _fixed: bool = false

# player
var _node: Vector2i
var _facing: int = 0
var _moving: bool = false
var _move_from: Vector3
var _move_to: Vector3
var _move_t: float = 0.0
var _move_secs: float = 1.65
var _move_target_node: Vector2i
var _pull_idx := -1
var _turning := false
## The way back to the junction you crawled in from (-1 at the ladder or after backing).
var _came_from := -1
var _turn_t := 0.0
var _turn_from := 0.0
var _turn_to := 0.0
var _turn_sign := 1.0
var _bump_t := -1.0
var _look_side := 0                # -1 into the left arm, 1 the right, 0 on ahead
var _look := 0.0
var _nudge := 0.0
var _nudge_t := -1.0
var _auto_looks: Array = []
var _auto_t := 0.0
var _taught := 0
var _aim := Vector2.ZERO
var _aim_target := Vector2.ZERO
var _crawl_hand: TextureRect
var _vignette: TextureRect
var _pant: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _pull_player: AudioStreamPlayer
var _at_leak: bool = false
var _clamp: float = 0.0
var _bob: float = 0.0
var _map_open: bool = false

# the thing and its staging (pipe_director.gd)
var _director
var _visit := 1
## Looking back over your shoulder (hold S): 0..1.
var glancing := false
var _glance := 0.0
## Climbing down at the start, then the map unfolds for a moment.
var _intro_t := -1.0
## Caught: the lunge, the dark, the drag back to the ladder.
var _caught_t := -1.0
var _caught_hit := false
var _torch_hand: TextureRect
var _work_hand: Control
var _black: ColorRect
var _drips: Array = []
var _step_player: AudioStreamPlayer
var _one: AudioStreamPlayer
var _prints_placed := false
var _flicker_t := 0.0
var _night := false

# scene
var _root: Control
var _container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _geo: Node3D
var _rig: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _leak_fx: GPUParticles3D
var _leak_audio: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer
var _pipes_bed: AudioStreamPlayer
var _hud_status: Label
var _map: Control
var _paper: TextureRect
var _ink: Control
var _pipe_mat: StandardMaterial3D
var _brick_mat: StandardMaterial3D
var _steel_mat: StandardMaterial3D
var _slime_mat: StandardMaterial3D
var _scale: int = 3


func _ready() -> void:
	layer = 128
	visible = false
	_build_shell()


func is_open() -> bool:
	return _active


func open_repair(coord: Vector2i, building_type: String, _label_text: String = "") -> void:
	_coord = coord
	_building_type = building_type
	var since_day := 1
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		since_day = int((state.failures.get("%d:%d" % [coord.x, coord.y], {}) as Dictionary).get("since_day", state.day))
		explore = not state.failures.has("%d:%d" % [coord.x, coord.y])
	# Co-op: the other warden already down this sewer: their pipes, their raccoon.
	mate.clear()
	mate.host = self
	mate.key = "%d:%d" % [coord.x, coord.y]
	var other: Dictionary = mate.mate()
	if not other.is_empty():
		since_day = int(other.get("sd", since_day))
	_since_day = since_day
	_backing = false
	_rng.seed = hash("%d:%d:%d" % [coord.x, coord.y, since_day])
	_night = CoreRoot != null and CoreRoot.is_night()
	_visit = _next_visit()
	night_pressure = _read_night_pressure()
	raccoon_level = debug_level if debug_level > 0 else DIRECTOR.mischief_level(night_pressure, _night, _visit)
	if not other.is_empty():
		raccoon_level = int(other.get("lv", raccoon_level))
	_generate()
	_build_world()
	_fixed = false
	if explore:
		for i in _leaks.size():
			_mark_fixed(i)
		_fixed = true
	for i in (other.get("fx", []) as Array):
		_mark_fixed(int(i))
	if not other.is_empty():
		_fixed = _all_fixed()
	_node = _entry
	_facing = 0
	_came_from = -1
	_moving = false
	_turning = false
	_look_side = 0
	_look = 0.0
	_nudge_t = -1.0
	_auto_looks.clear()
	_taught = 0
	_pull_idx = -1
	_bump_t = -1.0
	_aim = Vector2.ZERO
	_aim_target = Vector2.ZERO
	_at_leak = false
	_clamp = 0.0
	_map_open = false
	_stuck = false
	_stuck_need = 0
	_gore = 0.0
	_cur_leak = -1
	_clear_splats()
	_director = DIRECTOR.new()
	boy_tier = _read_boy_tier()
	_director.absent = boy_tier == 1
	_director.start(self, _visit, _night, _rng.randi())
	if _boy != null:
		_boy.stop()
	_boy = null
	if boy_tier == 1 or boy_tier == 3:
		_boy = PIPE_BOY.new()
		_boy.start(self, boy_tier)
	_prints_placed = false
	glancing = false
	_glance = 0.0
	_caught_t = -1.0
	_black.color.a = 0.0
	_active = true
	visible = true
	_rebuild_hud()
	_set_status("")
	_play(_ambience)
	_play(_pipes_bed)
	_play(_pant)
	_play(_heart)
	for d in _drips:
		(d as AudioStreamPlayer3D).play()
	_intro_t = 0.0
	_vibe.start(raccoon_level, _rng.randi())
	_play_one("ladder.mp3", -4.0)
	_update_rig(0.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## The family's boy's tier at the sewer tonight (scripts/night_jobs.gd), 0 none.
func _read_boy_tier() -> int:
	if debug_boy >= 0:
		return debug_boy
	var main = get_tree().current_scene if is_inside_tree() else null
	var nj = main.get("_night_jobs") if main != null else null
	return int(nj.call("boy_tier_at", "sewer")) if nj != null and nj.has_method("boy_tier_at") else 0


## Tests: the boy's tier whatever the night (-1: the night's).
var debug_boy := -1


## The night's pressure on the camp right now (DESIGN §5e), read from main's omen context.
func _read_night_pressure() -> float:
	var main := get_parent()
	if main != null and main.has_method("_omen_context"):
		var ctx = main.call("_omen_context")
		if ctx is Dictionary:
			return OMENS.pressure(ctx)
	return 1.0


## How many times you have been down (the camp office keeps the count over the week).
func _next_visit() -> int:
	var main := get_parent()
	var office = main.get("camp_office") if main != null else null
	if office == null:
		return 3
	var n := int(office.get("pipe_visits")) + 1
	office.set("pipe_visits", n)
	return n


## Leaving from the pause menu: up the ladder at once (a clamped leak still counts).
func abort() -> void:
	if not _active:
		return
	close_repair(not _fixed)
	if _fixed and not explore:
		repair_completed.emit(_coord, _building_type)


func close_repair(cancelled: bool = true) -> void:
	if not _active:
		return
	_active = false
	visible = false
	mate.clear()
	for a in [_ambience, _pipes_bed, _pant, _heart]:
		if a != null:
			a.stop()
	for l in _leaks:
		var la = (l as Dictionary).get("audio")
		if la != null and is_instance_valid(la):
			la.stop()
	if _director != null:
		_director.stop()
	if _boy != null:
		_boy.stop()
		_boy = null
	for d in _drips:
		(d as AudioStreamPlayer3D).stop()
	if _work_hand != null:
		_work_hand.stop()
	if _vibe != null:
		_vibe.stop()
	if _repair != null:
		_repair.cancel()
	if cancelled:
		repair_cancelled.emit()


# ── network ───────────────────────────────────────────────────────────────────

func _generate() -> void:
	_links.clear()
	_plates.clear()
	_landmarks.clear()
	_layout()
	# Spanning tree by randomised DFS, then extra loops, then no dead ends: with no
	# turning around, every junction needs a way on.
	var nodes := _links.keys()
	var start: Vector2i = nodes[_rng.randi_range(0, nodes.size() - 1)]
	var stack: Array[Vector2i] = [start]
	var seen := {start: true}
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[int] = []
		for d in 4:
			var n: Vector2i = c + DIRS[d]
			if _in_grid(n) and not seen.has(n):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick := options[_rng.randi_range(0, options.size() - 1)]
		var nxt: Vector2i = c + DIRS[pick]
		_connect(c, pick)
		seen[nxt] = true
		stack.append(nxt)
	# Loops: some networks a maze of them, some long single runs.
	var loops := _rng.randf_range(0.12, 0.4)
	for c in _links.keys():
		for d in [1, 2]:
			var n: Vector2i = c + DIRS[d]
			if _in_grid(n) and not _links[c].has(d) and _rng.randf() < loops:
				_connect(c, d)
	for c in _links.keys():
		while _links[c].size() < 2:
			var free: Array[int] = []
			for d in 4:
				if _in_grid(c + DIRS[d]) and not _links[c].has(d):
					free.append(d)
			if free.is_empty():
				break
			_connect(c, free[_rng.randi_range(0, free.size() - 1)])
	if not _links[_entry].has(0):
		_connect(_entry, 0)
	# The holes it chewed: the first as far from the ladder as the network allows, the
	# others far from the ladder and from each other.
	var dist := _distances_from(_entry)
	var edges := _edges()
	_shuffle(edges)
	_leaks.clear()
	var leak_dists: Array = []
	for _i in clampi(raccoon_level, 1, 3):
		var best := -1.0
		var pick: Array = []
		for e in edges:
			if e[0] == _entry or e[1] == _entry or _leak_index(e[0], e[1]) >= 0:
				continue
			var score := float(mini(int(dist.get(e[0], 0)), int(dist.get(e[1], 0))))
			for ld in leak_dists:
				score += 0.9 * float(mini(int(ld.get(e[0], 0)), int(ld.get(e[1], 0)))) / float(leak_dists.size())
			if score > best:
				best = score
				pick = e
		if pick.is_empty():
			break
		var kinds: Array = REPAIRS_BY_LEVEL[clampi(raccoon_level, 1, 3) - 1]
		_leaks.append({"a": pick[0], "b": pick[1], "fixed": false, "kind": kinds[_rng.randi() % kinds.size()]})
		leak_dists.append(_distances_from(pick[0]))
	_leak_a = _leaks[0]["a"]
	_leak_b = _leaks[0]["b"]
	# Stencilled coordinates: always at the ladder, at some junctions, rarely at bends.
	for c in _links.keys():
		var deg: int = _links[c].size()
		if c == _entry or (deg >= 3 and _rng.randf() < 0.45) or (deg == 2 and _rng.randf() < 0.12):
			_plates[c] = true
	# Landmarks on five other pipes; the last worker noted three of them on the map.
	var pool := edges.filter(func(e): return _leak_index(e[0], e[1]) < 0)
	_shuffle(pool)
	for i in mini(6, pool.size()):
		_landmarks.append({"a": pool[i][0], "b": pool[i][1], "kind": LANDMARKS[i % LANDMARKS.size()], "on_map": i < 3})


## Every breakdown its own network: a size (5-8 by 4-6), a shape (the whole grid, holes
## punched in it, or a block cut out of a corner or a side), pipes of their own lengths
## (2.4-4.6 m), the ladder somewhere along the bottom row. Every junction keeps at least
## two neighbours (no dead ends) and the whole stays in one piece.
func _layout() -> void:
	_grid = Vector2i(_rng.randi_range(5, GRID.x), _rng.randi_range(4, GRID.y))
	_col_x = [0.0]
	for _i in range(1, _grid.x):
		_col_x.append(_col_x[-1] + _rng.randf_range(2.4, 4.6))
	_row_z = [0.0]
	for _i in range(1, _grid.y):
		_row_z.append(_row_z[-1] + _rng.randf_range(2.4, 4.6))
	var present := {}
	for y in _grid.y:
		for x in _grid.x:
			present[Vector2i(x, y)] = true
	var shape := _rng.randf()
	var want_out: Array = []
	if shape < 0.35:
		# Holes: a handful of junctions that are not there.
		var n := int(float(_grid.x * _grid.y) * _rng.randf_range(0.08, 0.22))
		for _i in n:
			want_out.append(Vector2i(_rng.randi_range(0, _grid.x - 1), _rng.randi_range(0, _grid.y - 2)))
	elif shape < 0.75:
		# A block out of a corner or a side: an L, a U, a T of pipes.
		var bw := _rng.randi_range(2, maxi(2, _grid.x / 2))
		var bh := _rng.randi_range(1, maxi(1, (_grid.y - 1) / 2))
		var bx: int = [0, _grid.x - bw, (_grid.x - bw) / 2][_rng.randi() % 3]
		for y in bh:
			for x in bw:
				want_out.append(Vector2i(bx + x, y))
	for c in want_out:
		if not present.has(c):
			continue
		present.erase(c)
		if not _one_piece(present):
			present[c] = true
	# Junctions left with a single neighbour would be dead ends: out with them too.
	var changed := true
	while changed:
		changed = false
		for c in present.keys():
			var nb := 0
			for d in 4:
				if present.has(c + DIRS[d]):
					nb += 1
			if nb < 2:
				present.erase(c)
				if _one_piece(present):
					changed = true
				else:
					present[c] = true
	for c in present.keys():
		_links[c] = []
	# The ladder: on the lowest row that has a junction with one to its north.
	var cands: Array[Vector2i] = []
	for y in range(_grid.y - 1, -1, -1):
		for x in _grid.x:
			var c := Vector2i(x, y)
			if present.has(c) and present.has(c + DIRS[0]):
				cands.append(c)
		if not cands.is_empty():
			break
	_entry = cands[_rng.randi_range(0, cands.size() - 1)]


func _one_piece(present: Dictionary) -> bool:
	if present.is_empty():
		return false
	var first: Vector2i = present.keys()[0]
	var seen := {first: true}
	var q: Array[Vector2i] = [first]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in 4:
			var n: Vector2i = c + DIRS[d]
			if present.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen.size() == present.size()


## Seeded shuffle: Array.shuffle() uses the global RNG, which would give the same
## breakdown a different network every time you climbed down.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func _connect(c: Vector2i, d: int) -> void:
	var n: Vector2i = c + DIRS[d]
	if not _links[c].has(d):
		_links[c].append(d)
	var back := (d + 2) % 4
	if not _links[n].has(back):
		_links[n].append(back)


## Which hole is on this pipe (-1 none).
func _leak_index(a: Vector2i, b: Vector2i) -> int:
	for i in _leaks.size():
		if _same_edge(a, b, _leaks[i]["a"], _leaks[i]["b"]):
			return i
	return -1


func _all_fixed() -> bool:
	for l in _leaks:
		if not bool(l["fixed"]):
			return false
	return true


func _in_grid(c: Vector2i) -> bool:
	return _links.has(c)


func _edges() -> Array:
	var out: Array = []
	for c in _links.keys():
		for d in _links[c]:
			if d == 1 or d == 2:
				out.append([c, c + DIRS[d]])
	return out


func _same_edge(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	return (a == c and b == d) or (a == d and b == c)


## Pipes away from the nearest of several junctions (the water runs from the nearest hole).
func _distances_from_many(srcs: Array) -> Dictionary:
	var dist := {}
	var q: Array[Vector2i] = []
	for c in srcs:
		dist[c] = 0
		q.append(c)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in _links[c]:
			var n: Vector2i = c + DIRS[d]
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


func _distances_from(src: Vector2i) -> Dictionary:
	var dist := {src: 0}
	var q: Array[Vector2i] = [src]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in _links[c]:
			var n: Vector2i = c + DIRS[d]
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


func _label(c: Vector2i) -> String:
	return "%s%d" % [COLS[c.x], c.y + 1]


func _world_pos(c: Vector2i) -> Vector3:
	if c.x < 0 or c.y < 0 or c.x >= _col_x.size() or c.y >= _row_z.size():
		return Vector3(float(c.x) * CELL, EYE_Y, float(c.y) * CELL)
	return Vector3(_col_x[c.x], EYE_Y, _row_z[c.y])


# ── 3D ────────────────────────────────────────────────────────────────────────

func _build_shell() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_container)
	RETRO_RENDER.register(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	# Its 3D sounds (the leaks down the pipes) heard from its camera.
	_viewport.audio_listener_enable_3d = true
	_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.09, 0.08)
	env.ambient_light_energy = 0.035
	env.fog_enabled = true
	env.fog_light_color = Color(0.0, 0.0, 0.0)
	# (Thicker from 21. 10.: the pipes read too far.)
	env.fog_density = 0.26
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_rig = Node3D.new()
	_world.add_child(_rig)
	_camera = Camera3D.new()
	_camera.fov = 82.0
	_camera.near = 0.02
	_camera.far = 30.0
	_camera.current = true
	_rig.add_child(_camera)
	_flashlight = SpotLight3D.new()
	_flashlight.light_color = Color(0.95, 0.9, 0.76)
	_flashlight.light_energy = 3.0
	_flashlight.spot_range = 11.0
	_flashlight.spot_angle = 28.0
	_flashlight.spot_attenuation = 0.9
	_camera.add_child(_flashlight)
	# What the torch spills on the wall a hand's breadth away: the pipe pressing in.
	var spill := OmniLight3D.new()
	spill.light_color = Color(0.9, 0.82, 0.66)
	spill.light_energy = 0.35
	spill.omni_range = 1.25
	spill.omni_attenuation = 1.6
	spill.position = Vector3(0.15, -0.1, -0.2)
	_flashlight.add_child(spill)
	_pipe_mat = StandardMaterial3D.new()
	_pipe_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_pipe_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_pipe_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_pipe_mat.roughness = 0.95
	if ResourceLoader.exists(PIPE_TEXTURE):
		_pipe_mat.albedo_texture = load(PIPE_TEXTURE)
	else:
		_pipe_mat.albedo_color = Color(0.3, 0.32, 0.31)
	_brick_mat = _pipe_mat.duplicate() as StandardMaterial3D
	if ResourceLoader.exists(BRICK_TEXTURE):
		_brick_mat.albedo_texture = load(BRICK_TEXTURE)
	_steel_mat = _pipe_mat.duplicate() as StandardMaterial3D
	_steel_mat.roughness = 0.55
	_steel_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_steel_mat.metallic = 0.5
	if ResourceLoader.exists(STEEL_TEXTURE):
		_steel_mat.albedo_texture = load(STEEL_TEXTURE)
	else:
		_steel_mat.albedo_color = Color(0.75, 0.48, 0.32)
	_slime_mat = _pipe_mat.duplicate() as StandardMaterial3D
	_slime_mat.roughness = 0.3
	_slime_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if ResourceLoader.exists(SLIME_TEXTURE):
		_slime_mat.albedo_texture = load(SLIME_TEXTURE)
	else:
		_slime_mat.albedo_color = Color(0.45, 0.58, 0.38)
	_ambience = _make_player(SFX_AMBIENCE, -9.0, true)
	_pipes_bed = _make_player(SFX_PIPES, -14.0, true)
	# Your own breath and heart: quiet while it is quiet, louder as it comes.
	_pant = _make_player(SFX_DIR + "pant.mp3", -30.0, true)
	_heart = _make_player(SFX_DIR + "heart.mp3", -60.0, true)
	_pull_player = AudioStreamPlayer.new()
	_pull_player.bus = audio_bus()
	_pull_player.volume_db = -8.0
	add_child(_pull_player)
	_build_hud_nodes()
	_vibe = PIPE_VIBE.new()
	_vibe.host = self
	add_child(_vibe)


## The echo bus, made the first time it is asked for: a big hard room, a slap-back and a
## second repeat, so every slap and knock rings down the pipes.
func audio_bus() -> String:
	if AudioServer.get_bus_index(BUS) >= 0:
		return BUS
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.9
	rev.damping = 0.08
	rev.spread = 0.7
	rev.hipass = 0.08
	rev.predelay_msec = 40.0
	rev.dry = 0.9
	rev.wet = 0.42
	AudioServer.add_bus_effect(i, rev)
	var dl := AudioEffectDelay.new()
	dl.dry = 1.0
	dl.tap1_active = true
	dl.tap1_delay_ms = 190.0
	dl.tap1_level_db = -13.0
	dl.tap1_pan = -0.3
	dl.tap2_active = true
	dl.tap2_delay_ms = 430.0
	dl.tap2_level_db = -19.0
	dl.tap2_pan = 0.3
	dl.feedback_active = false
	AudioServer.add_bus_effect(i, dl)
	# Then held in: a compressor and a ceiling, so a burst of bangs and the echo of them
	# cannot get loud on top of each other (playtest 19. 10.: "earrape" at the repairs).
	var comp := AudioEffectCompressor.new()
	comp.threshold = -18.0
	comp.ratio = 4.0
	comp.attack_us = 5000.0
	comp.release_ms = 180.0
	AudioServer.add_bus_effect(i, comp)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -3.0
	AudioServer.add_bus_effect(i, lim)
	AudioServer.set_bus_volume_db(i, -2.0)
	return BUS


func _make_player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = audio_bus()
	p.volume_db = db
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if loop:
			_set_loop(s)
		p.stream = s
	add_child(p)
	return p


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null and not p.playing:
		p.play()


func _build_world() -> void:
	if _geo != null and is_instance_valid(_geo):
		_geo.queue_free()
	_geo = Node3D.new()
	_world.add_child(_geo)
	# The whole network is one CSG union: drums at junctions and full-length pipes
	# between them. Separate meshes would cap each other off; a union has only the
	# inside surface, which is what we see (front faces culled).
	var comb := CSGCombiner3D.new()
	for c in _links.keys():
		_junction(comb, c)
		for d in _links[c]:
			if d == 1 or d == 2:
				_pipe(comb, c, c + DIRS[d])
	_geo.add_child(comb)
	for c in _links.keys():
		if _plates.has(c):
			_stencil(c)
	_build_ladder()
	for lm in _landmarks:
		_build_landmark(lm)
	_build_leak()
	_build_water()
	_build_drips()
	_build_dressing()


## The trickle along the bottom of every pipe, running away from the leak (the farther a
## pipe is from the leak, the less there is). Follow it upstream.
func _build_water() -> void:
	var srcs: Array = []
	for l in _leaks:
		srcs.append(l["a"])
	var dist := _distances_from_many(srcs)
	var mat_cache := {}
	_water_meshes.clear()
	var scum: Texture2D = load(SCUM) if ResourceLoader.exists(SCUM) else null
	# The pipe's invert is 0.08 below the junction floor: the water lies a little above it.
	var floor_y := EYE_Y - PIPE_R * 0.9 - 0.02
	for e in _edges():
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var da := int(dist.get(a, 9))
		var db := int(dist.get(b, 9))
		# Flow from the end nearer the leak to the farther one.
		var src := a if da <= db else b
		var dst := b if src == a else a
		var strength := clampf(1.0 - float(mini(da, db)) / 6.0, 0.15, 1.0)
		var key := snappedf(strength, 0.1)
		if not mat_cache.has(key):
			var m := ShaderMaterial.new()
			m.shader = WATER_SHADER
			m.set_shader_parameter("strength", strength)
			m.set_shader_parameter("speed", 0.25 + 0.5 * strength)
			if scum != null:
				m.set_shader_parameter("scum", scum)
				m.set_shader_parameter("has_scum", true)
			mat_cache[key] = m
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(PIPE_R * 0.9, _world_pos(a).distance_to(_world_pos(b)))
		mi.mesh = q
		mi.material_override = mat_cache[key]
		_water_meshes.append(mi)
		var pa := _world_pos(src)
		var pb := _world_pos(dst)
		mi.position = (pa + pb) * 0.5
		mi.position.y = floor_y
		# The quad's +V runs along -Z before turning: face it from src to dst.
		var dir := (pb - pa).normalized()
		mi.rotation.y = atan2(dir.x, dir.z) + PI
		_geo.add_child(mi)
	_water_mats = mat_cache.values()


## A few places where it drips from the crown; they fall silent now and then.
func _build_drips() -> void:
	for d in _drips:
		if is_instance_valid(d):
			d.queue_free()
	_drips.clear()
	var nodes := _links.keys()
	_shuffle(nodes)
	for i in mini(6, nodes.size()):
		var p := AudioStreamPlayer3D.new()
		p.bus = audio_bus()
		var path := SFX_DIR + "drip.mp3"
		if ResourceLoader.exists(path):
			var st := (load(path) as AudioStreamMP3).duplicate() as AudioStreamMP3
			st.loop = true
			p.stream = st
		p.volume_db = -6.0
		p.max_distance = 12.0
		p.pitch_scale = _rng.randf_range(0.85, 1.15)
		p.position = _world_pos(nodes[i]) + Vector3(0, 0.6, 0)
		_geo.add_child(p)
		_drips.append(p)
		_drip_fx(_world_pos(nodes[i]))


## A drop at a time from the crown: a pale streak falling into the trickle.
func _drip_fx(at: Vector3) -> void:
	var fx := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 0.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, -9.0, 0)
	fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.05)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.7, 0.74, 0.62, 0.85)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = qm
	fx.draw_pass_1 = q
	fx.amount = 2
	fx.lifetime = 0.55
	fx.position = Vector3(at.x, ARM_R * 0.9 + ARM_R - 0.06, at.z)
	_geo.add_child(fx)


## What grows on the walls and what lies in the water: moss and fungus on the pipe
## walls (thick in the slimy ones), roots hanging through cracks in the junctions, and
## here and there a thing: hair, a dead rat, a child's bear. Its own dice off the pipes'.
func _build_dressing() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = _rng.seed + 4099
	var moss: Texture2D = load(DRESS_MOSS) if ResourceLoader.exists(DRESS_MOSS) else DIRECTOR.blob_texture(Color(0.12, 0.17, 0.08), 41)
	var fungus: Texture2D = load(DRESS_FUNGUS) if ResourceLoader.exists(DRESS_FUNGUS) else null
	for e in _edges():
		var kind := _pipe_kind(e[0], e[1])
		var n := r.randi_range(2, 5) if kind == "slime" else (r.randi_range(0, 2) if kind != "steel" else 0)
		for _i in n:
			var tex := fungus if (fungus != null and r.randf() < 0.3) else moss
			_wall_patch(e[0], e[1], tex, r)
	for c in _links.keys():
		if c != _entry and r.randf() < 0.3 and ResourceLoader.exists(DRESS_ROOTS):
			var roots := _dress_sprite(load(DRESS_ROOTS), r.randf_range(0.5, 0.75))
			roots.position = Vector3(_world_pos(c).x + r.randf_range(-0.2, 0.2), ARM_R * 0.9 + ARM_R * 0.9 - roots.pixel_size * roots.texture.get_height(), _world_pos(c).z + r.randf_range(-0.2, 0.2))
	var things := [[DRESS_HAIR, 0.22], [DRESS_RAT, 0.24], [DRESS_HAIR, 0.18], [DRESS_TEDDY, 0.26]]
	var pool := _edges().filter(func(e): return _leak_index(e[0], e[1]) < 0 and e[0] != _entry and e[1] != _entry)
	for t in things:
		if pool.is_empty() or not ResourceLoader.exists(str(t[0])):
			continue
		var e: Array = pool[r.randi() % pool.size()]
		var spr := _dress_sprite(load(str(t[0])), float(t[1]))
		var mid := _edge_mid(e[0], e[1])
		spr.position = Vector3(mid.x, 0.03, mid.z) + Vector3(float(e[1].x - e[0].x), 0, float(e[1].y - e[0].y)) * r.randf_range(-0.8, 0.8)


func _dress_sprite(tex: Texture2D, height: float) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	spr.pixel_size = height / float(tex.get_height())
	spr.offset = Vector2(0, tex.get_height() * 0.5)
	_geo.add_child(spr)
	return spr


func _wall_patch(a: Vector2i, b: Vector2i, tex: Texture2D, r: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz := r.randf_range(0.25, 0.6)
	q.size = Vector2(sz, sz)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.35
	mi.material_override = m
	var al := Vector3(float(b.x - a.x), 0, float(b.y - a.y)).normalized()
	var ang := r.randf_range(-PI * 0.8, PI * 0.8)
	var rad := (BRICK_R if _is_brick(a, b) else PIPE_R) * 0.93
	var centre := _edge_mid(a, b)
	centre = Vector3(centre.x, rad / 0.93 * 0.9, centre.z) + al * r.randf_range(-1.2, 1.2)
	var side := Vector3(al.z, 0, -al.x)
	var out := (side * sin(ang) + Vector3.UP * cos(ang)).normalized()
	mi.position = centre + out * rad
	_geo.add_child(mi)
	mi.look_at(centre, al if absf(out.dot(Vector3.UP)) > 0.9 else Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)


## Wet hand prints on the ladder rungs and the wall by it: long fingers, still running.
## The first time down, they are there when you come back to the ladder.
func _place_handprints() -> void:
	if _prints_placed:
		return
	_prints_placed = true
	var p := _world_pos(_entry)
	var tex: Texture2D = load(HANDPRINT) if ResourceLoader.exists(HANDPRINT) else null
	for i in 4:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.2)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		if tex != null:
			m.albedo_texture = tex
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else:
			m.albedo_color = Color(0.08, 0.07, 0.05)
			q.size = Vector2(0.09, 0.14)
		m.roughness = 0.2
		mi.material_override = m
		mi.position = p + Vector3(-0.14 + 0.28 * float(i % 2), -0.1 + 0.26 * float(i), ARM_R * 0.82)
		mi.rotation = Vector3(0, PI, 0.4 * (1.0 if i % 2 == 0 else -1.0))
		_geo.add_child(mi)


func _floor_offset(r: float) -> Vector3:
	return Vector3(0, EYE_Y - r * 0.9, 0)


func _junction(comb: CSGCombiner3D, c: Vector2i) -> void:
	var drum := CSGCylinder3D.new()
	drum.radius = ARM_R * 1.12
	drum.height = ARM_R * 2.0
	drum.sides = SIDES
	drum.material = _pipe_mat
	drum.position = _world_pos(c) - _floor_offset(ARM_R)
	comb.add_child(drum)


func _pipe(comb: CSGCombiner3D, a: Vector2i, b: Vector2i) -> void:
	var cyl := CSGCylinder3D.new()
	var kind := _pipe_kind(a, b)
	var r := BRICK_R if kind == "brick" else PIPE_R
	cyl.radius = r
	cyl.height = _world_pos(a).distance_to(_world_pos(b))
	cyl.sides = SIDES
	cyl.material = {"brick": _brick_mat, "steel": _steel_mat, "slime": _slime_mat}.get(kind, _pipe_mat)
	cyl.position = (_world_pos(a) + _world_pos(b)) * 0.5 - _floor_offset(r)
	cyl.rotation = Vector3(0, 0, PI * 0.5) if a.y == b.y else Vector3(PI * 0.5, 0, 0)
	comb.add_child(cyl)


## A seeded third of the pipes are the old 1962 brick ones: tighter, slower, and a
## landmark of sorts.
func _is_brick(a: Vector2i, b: Vector2i) -> bool:
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	return (absi(hash("%s%s%d" % [lo, hi, _rng.seed])) % 3) == 0


## concrete, brick (the old 1962 ones, tight), steel (corrugated, it rings under you) or
## slime (concrete gone green and wet). Seeded per pipe.
func _pipe_kind(a: Vector2i, b: Vector2i) -> String:
	if _is_brick(a, b):
		return "brick"
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	var h := absi(hash("k%s%s%d" % [lo, hi, _rng.seed])) % 8
	if h < 2:
		return "steel"
	if h < 5:
		return "slime"
	return "concrete"


## Coordinates spray-painted on the junction's wall, in the four corners between the
## arms: whichever way you come in, two of them face you across the drum.
func _stencil(c: Vector2i) -> void:
	var centre := _world_pos(c) - _floor_offset(ARM_R)
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var l := Label3D.new()
		l.text = _label(c)
		l.font = RETRO_UI.FONT_BIG
		l.font_size = 32
		l.pixel_size = 0.0026
		l.modulate = Color(0.80, 0.76, 0.62, 0.8)
		l.outline_size = 0
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.shaded = true
		l.double_sided = false
		var dir := Vector3(corner.x, 0, corner.y).normalized()
		# High on the drum's wall: you read it coming down the pipe; in the junction
		# itself it is above your head.
		l.position = Vector3(centre.x, EYE_Y + 0.36, centre.z) + dir * (ARM_R * 1.12 * 0.9)
		_geo.add_child(l)
		l.look_at(Vector3(centre.x, l.position.y, centre.z), Vector3.UP)
		l.rotate_object_local(Vector3.UP, PI)


func _build_ladder() -> void:
	var p := _world_pos(_entry)
	# The manhole's shaft over the junction, round and bricked: you climb down inside it
	# (the way down passed through the crown from above, the whole network in view from
	# outside: playtest 21. 10.); the cover's ring of daylight far above.
	_build_shaft(p)
	for x in [-0.22, 0.22]:
		var rail := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.05, 3.6, 0.05)
		rail.mesh = m
		rail.position = p + Vector3(x * 0.8, 1.2, ARM_R * 0.85)
		rail.material_override = _flat_mat(Color(0.35, 0.22, 0.14))
		_geo.add_child(rail)
	for i in 10:
		var rung := MeshInstance3D.new()
		var m2 := BoxMesh.new()
		m2.size = Vector3(0.48, 0.04, 0.04)
		rung.mesh = m2
		rung.position = p + Vector3(0, -0.3 + float(i) * 0.32, ARM_R * 0.85)
		rung.material_override = _flat_mat(Color(0.35, 0.22, 0.14))
		_geo.add_child(rung)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.85, 0.6)
	light.light_energy = 0.9
	light.omni_range = 3.5
	light.position = p + Vector3(0, 1.4, ARM_R * 0.7)
	_geo.add_child(light)


const SHAFT_TOP := 3.0


func _build_shaft(p: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := ARM_R
	var y0 := ARM_R * 0.6
	var segs := 12
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var c0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var c1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var u0 := float(i) / float(segs) * 3.0
		var u1 := float(i + 1) / float(segs) * 3.0
		# The inside faces (wound to face the middle).
		for v in [[c0, y0, u0, 1.0], [c1, SHAFT_TOP, u1, 0.0], [c1, y0, u1, 1.0], [c0, y0, u0, 1.0], [c0, SHAFT_TOP, u0, 0.0], [c1, SHAFT_TOP, u1, 0.0]]:
			var c: Vector3 = v[0]
			st.set_uv(Vector2(float(v[2]), float(v[3]) * (SHAFT_TOP - y0) / 1.2))
			st.add_vertex(p + c + Vector3(0, float(v[1]), 0))
	st.generate_normals()
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = st.commit()
	var m := StandardMaterial3D.new()
	var tex := BRICK_TEXTURE if ResourceLoader.exists(BRICK_TEXTURE) else PIPE_TEXTURE
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	shaft.material_override = m
	_geo.add_child(shaft)
	# The cover's holes: daylight (or the night) far up.
	var lid := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.04
	disc.radial_segments = segs
	lid.mesh = disc
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.1, 0.1, 0.09) if _night else Color(0.55, 0.56, 0.5)
	lid.material_override = lm
	lid.position = p + Vector3(0, SHAFT_TOP, 0)
	_geo.add_child(lid)


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _edge_mid(a: Vector2i, b: Vector2i) -> Vector3:
	return (_world_pos(a) + _world_pos(b)) * 0.5


func _build_landmark(lm: Dictionary) -> void:
	var p := _edge_mid(lm["a"], lm["b"])
	# Offsets below are from the eye: this puts things on the pipe's invert.
	var floor_y := -EYE_Y + 0.02
	match str(lm["kind"]):
		"scratches":
			if ResourceLoader.exists(SCRATCHES):
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(0.6, 0.6)
				mi.mesh = q
				var m := StandardMaterial3D.new()
				m.albedo_texture = load(SCRATCHES)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.material_override = m
				var side2 := Vector3(lm["b"].y - lm["a"].y, 0, lm["a"].x - lm["b"].x).normalized()
				mi.position = p + side2 * (PIPE_R * 0.7) + Vector3(0, 0.1, 0)
				_geo.add_child(mi)
				mi.look_at(p + Vector3(0, 0.1, 0), Vector3.UP)
				mi.rotate_object_local(Vector3.UP, PI)
		"crack", "tally":
			var l := Label3D.new()
			l.text = "\\/\\_/\\" if lm["kind"] == "crack" else "IIII IIII IIII II"
			l.font = RETRO_UI.FONT_TEXT
			l.font_size = 48
			l.pixel_size = 0.006
			l.modulate = Color(0.05, 0.04, 0.04, 0.9) if lm["kind"] == "crack" else Color(0.55, 0.5, 0.45, 0.9)
			l.shaded = true
			l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var side := Vector3(lm["b"].y - lm["a"].y, 0, lm["a"].x - lm["b"].x).normalized()
			l.position = p + side * (PIPE_R * 0.75) + Vector3(0, 0.15, 0)
			l.look_at_from_position(l.position, p + Vector3(0, 0.15, 0), Vector3.UP)
			l.rotate_object_local(Vector3.UP, PI)
			_geo.add_child(l)
		"rags":
			_lump(p + Vector3(0.12, floor_y + 0.05, 0.1), Vector3(0.3, 0.07, 0.22), Color(0.22, 0.18, 0.12))
		"bucket":
			# A rusted paint tin on its side, half in the sludge.
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.08
			cyl.height = 0.18
			cyl.radial_segments = 8
			mi.mesh = cyl
			var tin := _flat_mat(Color(0.26, 0.15, 0.09))
			if ResourceLoader.exists(SCUM):
				tin.albedo_texture = load(SCUM)
				tin.albedo_color = Color(0.7, 0.45, 0.3)
				tin.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.material_override = tin
			mi.position = p + Vector3(-0.14, floor_y + 0.06, 0.0)
			mi.rotation = Vector3(PI * 0.5, 0.4, 0.0)
			_geo.add_child(mi)
		"shoe":
			# One red high-heeled shoe. You have seen someone missing one.
			if ResourceLoader.exists(SHOE_SPRITE):
				var shoe := Sprite3D.new()
				shoe.texture = load(SHOE_SPRITE)
				shoe.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				shoe.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				shoe.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				shoe.shaded = true
				shoe.pixel_size = 0.22 / float(shoe.texture.get_width())
				shoe.position = p + Vector3(0.12, floor_y + 0.08, 0.0)
				_geo.add_child(shoe)
			else:
				_lump(p + Vector3(0.1, floor_y + 0.05, 0.0), Vector3(0.22, 0.08, 0.08), Color(0.62, 0.08, 0.06))


func _lump(at: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _flat_mat(c)
	mi.position = at
	_geo.add_child(mi)


func _build_leak() -> void:
	for l in _leaks:
		_build_one_leak(l)
	_leak_fx = (_leaks[0] as Dictionary).get("fx")
	_leak_audio = (_leaks[0] as Dictionary).get("audio")


## One chewed hole: the spray from the crown, its hiss, and the guts it left round it.
func _build_one_leak(l: Dictionary) -> void:
	var p := _edge_mid(l["a"], l["b"])
	var _leak_fx := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.color = Color(0.55, 0.6, 0.5, 0.8)
	_leak_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.08)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.6, 0.66, 0.55, 0.8)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	_leak_fx.draw_pass_1 = q
	_leak_fx.amount = 120
	_leak_fx.lifetime = 0.7
	_leak_fx.position = p + Vector3(0, PIPE_R * 0.6, 0)
	_geo.add_child(_leak_fx)
	var _leak_audio := AudioStreamPlayer3D.new()
	_leak_audio.bus = audio_bus()
	if ResourceLoader.exists(SFX_LEAK):
		var s := load(SFX_LEAK) as AudioStream
		_set_loop(s)
		_leak_audio.stream = s
	_leak_audio.volume_db = 4.0
	_leak_audio.max_distance = 14.0
	_leak_audio.position = p
	_geo.add_child(_leak_audio)
	_leak_audio.play()
	l["fx"] = _leak_fx
	l["audio"] = _leak_audio


# ── HUD and map ───────────────────────────────────────────────────────────────

func _build_hud_nodes() -> void:
	# The pipe closing in: a dark ring round the view that tightens as it comes.
	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.set_offset(0, 0.45)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 128
	gt.height = 72
	_vignette.texture = gt
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.55
	_root.add_child(_vignette)
	# The free hand: it reaches out ahead, plants on the wet concrete, and the body drags
	# after it. The torch stays in the right.
	_crawl_hand = TextureRect.new()
	_crawl_hand.texture = load(HAND_OPEN) if ResourceLoader.exists(HAND_OPEN) else null
	_crawl_hand.flip_h = true
	_crawl_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crawl_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_crawl_hand.visible = false
	_root.add_child(_crawl_hand)
	_torch_hand = TextureRect.new()
	_torch_hand.texture = load(HAND_TORCH) if ResourceLoader.exists(HAND_TORCH) else null
	_torch_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_torch_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_torch_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_torch_hand)
	_work_hand = WORK_HAND.new()
	_root.add_child(_work_hand)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = audio_bus()
	_step_player.volume_db = -7.0
	add_child(_step_player)
	_one = AudioStreamPlayer.new()
	_one.bus = audio_bus()
	add_child(_one)
	_hud_status = Label.new()
	_root.add_child(_hud_status)
	_map = ColorRect.new()
	_map.color = Color(0, 0, 0, 0.55)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.visible = false
	_root.add_child(_map)
	_paper = TextureRect.new()
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PAPER_TEXTURE):
		_paper.texture = load(PAPER_TEXTURE)
	_map.add_child(_paper)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_map)
	_map.add_child(_ink)
	_repair = PIPE_REPAIR.new()
	_repair.host = self
	_repair.done.connect(_leak_done)
	_root.add_child(_repair)
	_catch = CATCH.new()
	_catch.host = self
	_catch.hit.connect(_on_catch_hit)
	_catch.finished.connect(_on_catch_done)
	_root.add_child(_catch)
	_root.add_child(_black)


func _rebuild_hud() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	var s := float(_scale)
	_vignette.position = Vector2.ZERO
	_vignette.size = vp
	RETRO_UI.style_label(_hud_status, RETRO_UI.FONT_TEXT, 8, RETRO_UI.C_BONE, _scale, true)
	_hud_status.position = Vector2(6.0 * s, 5.0 * s)
	_map.position = Vector2.ZERO
	_map.size = vp
	_black.position = Vector2.ZERO
	_black.size = vp
	if _torch_hand.texture != null:
		var k := float(maxi(1, int(round(vp.y / 300.0))))
		_torch_hand.size = _torch_hand.texture.get_size() * k
		if _crawl_hand.texture != null:
			_crawl_hand.size = _crawl_hand.texture.get_size() * k


func _set_status(text: String) -> void:
	if _hud_status != null:
		_hud_status.text = text


## The paper map: the pipes as the last worker drew them, in pen, slightly wobbly.
## No "you are here".
func _draw_map() -> void:
	var vp := _map.size
	var s := float(_scale)
	var w := minf(vp.x * 0.8, vp.y * 1.15)
	var h := w * 0.75
	var r := Rect2((vp - Vector2(w, h)) * 0.5, Vector2(w, h))
	_paper.position = r.position
	_paper.size = r.size
	var margin := Vector2(w * 0.12, h * 0.14)
	# Drawn to scale: long pipes long on the paper too.
	var span := Vector2(w - margin.x * 2.0, h - margin.y * 2.0)
	var xs: Array[float] = _col_x if not _col_x.is_empty() else [0.0, 1.0]
	var zs: Array[float] = _row_z if not _row_z.is_empty() else [0.0, 1.0]
	var ink := Color(0.12, 0.10, 0.18, 0.92)
	var pen_rng := RandomNumberGenerator.new()
	pen_rng.seed = hash(_label(_leak_a)) + 7
	var to_px := func(c: Vector2i) -> Vector2:
		return r.position + margin + Vector2(xs[c.x] / maxf(0.01, xs[-1]) * span.x, zs[c.y] / maxf(0.01, zs[-1]) * span.y)
	for e in _edges():
		var a: Vector2 = to_px.call(e[0])
		var b: Vector2 = to_px.call(e[1])
		var mid := (a + b) * 0.5 + Vector2(pen_rng.randf_range(-1.5, 1.5), pen_rng.randf_range(-1.5, 1.5)) * s
		_ink.draw_line(a, mid, ink, 2.0 * s)
		_ink.draw_line(mid, b, ink, 2.0 * s)
	var font := RETRO_UI.FONT_TEXT
	var fs := 8 * _scale
	for c in _links.keys():
		var p: Vector2 = to_px.call(c)
		_ink.draw_rect(Rect2(p - Vector2(s, s) * 1.5, Vector2(s, s) * 3.0), ink)
		_ink.draw_string(font, p + Vector2(3.0, -3.0) * s, _label(c), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.7))
	# entry
	var ep: Vector2 = to_px.call(_entry)
	_ink.draw_string(RETRO_UI.FONT_LABEL, ep + Vector2(-14.0, 14.0) * s, tr("LADDER"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# leak (none marked when nothing is broken: you came down just to see)
	var red := Color(0.72, 0.08, 0.06, 0.95)
	for l in ([] if explore else _leaks):
		var lp: Vector2 = (to_px.call(l["a"]) + to_px.call(l["b"])) * 0.5
		_ink.draw_line(lp + Vector2(-5, -5) * s, lp + Vector2(5, 5) * s, red, 2.5 * s)
		_ink.draw_line(lp + Vector2(-5, 5) * s, lp + Vector2(5, -5) * s, red, 2.5 * s)
		if bool(l["fixed"]):
			_ink.draw_arc(lp, 9.0 * s, 0.0, TAU, 14, ink, 1.5 * s)
	# landmarks the last worker bothered to note
	for lm in _landmarks:
		if not bool(lm["on_map"]):
			continue
		var mp: Vector2 = (to_px.call(lm["a"]) + to_px.call(lm["b"])) * 0.5
		_ink.draw_string(font, mp + Vector2(-2.0, 10.0) * s, str(LANDMARK_MAP_GLYPH[lm["kind"]]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.22, 0.2, 0.9))
	# The controls, as the last worker scribbled them in the margin (no HUD bar down here).
	_ink.draw_string(font, r.position + Vector2(margin.x, margin.y * 0.45), tr("junctions: A/D look in a side pipe, W crawl in (or point + click). S look behind. F torch. E clamp, ladder."), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.18, 0.3, 0.75))
	_ink.draw_string(font, r.position + Vector2(margin.x, h - margin.y * 0.35), tr("it cant see. it hears you crawl + the clamp. stand still, keep the light on it. water runs from the leak. - P."), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.18, 0.3, 0.8))


# ── play ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	if _caught_t >= 0.0:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		# The head and the torch follow the pointer a little.
		var vp := get_viewport().get_visible_rect().size
		var m := (mm.position / vp) * 2.0 - Vector2.ONE
		_aim_target = Vector2(clampf(m.x, -1.0, 1.0), clampf(m.y, -1.0, 1.0))
		if _can_choose():
			if m.x > 0.62 and _has_side(1):
				_set_look(1)
			elif m.x < -0.62 and _has_side(-1):
				_set_look(-1)
			elif absf(m.x) < 0.3 and _look_side != 0:
				_set_look(0)
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if _intro_t >= 0.0:
			if mb.pressed:
				_intro_t = 99.0
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			glancing = mb.pressed and not _moving and not _at_leak and not _turning
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _stuck:
			_struggle()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and not _map_open and not _at_leak:
			var x := mb.position.x / maxf(1.0, get_viewport().get_visible_rect().size.x)
			if x < 0.3 and _look_side != -1:
				_look_toward(-1)
			elif x > 0.7 and _look_side != 1:
				_look_toward(1)
			else:
				_forward()
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null:
		return
	if _intro_t >= 0.0 and key.pressed and not key.echo:
		_intro_t = 99.0
		get_viewport().set_input_as_handled()
		return
	if key.physical_keycode == KEY_S or key.physical_keycode == KEY_DOWN:
		glancing = key.pressed and not _moving and not _at_leak and not _turning
		# A tap (not the held look back): back up a pipe, feet first.
		if key.pressed and not key.echo:
			_s_down_at = Time.get_ticks_msec() / 1000.0
		elif not key.pressed and _s_down_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - _s_down_at < 0.25:
			_s_down_at = -1.0
			_back_up()
		get_viewport().set_input_as_handled()
		return
	if key.physical_keycode == KEY_TAB:
		_map_open = key.pressed
		_map.visible = _map_open
		_ink.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or key.echo or _map_open:
		return
	var used := true
	match key.physical_keycode:
		KEY_W, KEY_UP:
			_forward()
		KEY_A, KEY_LEFT:
			_look_toward(-1)
		KEY_D, KEY_RIGHT:
			_look_toward(1)
		KEY_F:
			_flashlight.visible = not _flashlight.visible
		KEY_C:
			_vibe.chalk()
		KEY_E:
			if not _moving and not _turning and _node == _entry:
				_climb_out()
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


## One pull against the snare: the hands sink, come out wet, and it comes for the noise.
func _struggle() -> void:
	if not _stuck:
		return
	_stuck_need -= 1
	_bump_t = 0.0
	_play_pull("pull2.mp3", -4.0)
	_play_one("rac_squelch.mp3", -4.0)
	if _rng.randf() < 0.5:
		splatter(1)
	if _director != null:
		_director.heard(_node, 2)
	if _stuck_need <= 0:
		_stuck = false
		if _director != null:
			_director.trap_done(_node, _move_target_node)


## It bit you (stuck in its snare, or reaching past you): the blow, the blood on the view.
func bitten(amount: int) -> void:
	player_hurt.emit(amount)
	_gore = minf(1.0, _gore + 0.3)
	splatter(4)
	_bump_t = 0.0
	_play_one("rac_bite.mp3", 0.0)


## Guts and blood on the view: they run down and fade.
func splatter(n: int) -> void:
	var texs: Array = []
	for path in GUTS_SPLATS:
		if ResourceLoader.exists(path):
			texs.append(load(path))
	if texs.is_empty():
		texs.append(DIRECTOR.blob_texture(Color(0.32, 0.03, 0.03), 9))
	var vp := get_viewport().get_visible_rect().size
	for _i in n:
		var tex: Texture2D = texs[_rng.randi() % texs.size()]
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var side := vp.y * (_rng.randf_range(0.18, 0.42) if tex.get_width() < tex.get_height() else _rng.randf_range(0.08, 0.16))
		r.size = Vector2(side * float(tex.get_width()) / float(tex.get_height()), side)
		r.pivot_offset = r.size * 0.5
		# Runs of blood hang roughly downwards; a lump lands any way up.
		r.rotation = _rng.randf_range(-0.35, 0.35) if tex.get_width() < tex.get_height() else _rng.randf_range(-PI, PI)
		r.position = Vector2(_rng.randf_range(-0.1, 0.85) * vp.x, _rng.randf_range(-0.1, 0.7) * vp.y)
		_root.add_child(r)
		_root.move_child(r, _vignette.get_index() + 1)
		_splats.append({"node": r, "t": 0.0, "life": _rng.randf_range(5.0, 8.0), "v": _rng.randf_range(4.0, 14.0)})


func _update_splats(delta: float) -> void:
	for i in range(_splats.size() - 1, -1, -1):
		var sp: Dictionary = _splats[i]
		sp["t"] = float(sp["t"]) + delta
		var r: TextureRect = sp["node"]
		r.position.y += float(sp["v"]) * delta * float(_scale)
		r.modulate.a = clampf((float(sp["life"]) - float(sp["t"])) / 2.5, 0.0, 1.0)
		if float(sp["t"]) >= float(sp["life"]):
			r.queue_free()
			_splats.remove_at(i)


func _clear_splats() -> void:
	for sp in _splats:
		if is_instance_valid(sp["node"]):
			(sp["node"] as Node).queue_free()
	_splats.clear()


func _climb_out() -> void:
	close_repair(not _fixed)
	if _fixed and not explore:
		repair_completed.emit(_coord, _building_type)


## On where you look: down the pipe ahead, or into the side pipe your head is turned
## to. Facing concrete, your hand meets the wall (and your head goes to the ways there
## are); facing the ladder (behind you at the start), you climb it.
func _forward() -> void:
	if _stuck:
		_struggle()
		return
	if _moving or _at_leak or _turning or _map_open or _intro_t >= 0.0:
		return
	_auto_looks.clear()
	if _look_side != 0 and _has_side(_look_side):
		var d := _side_dir(_look_side)
		_look_side = 0
		_look = 0.0
		_try_move(d)
	elif _links[_node].has(_facing):
		_try_move(_facing)
	elif _node == _entry and _facing == 2:
		_climb_out()
	else:
		_bump_t = 0.0
		_play_pull("wall.mp3", -6.0)
		_teach_sides()


## Lying in the pipe you cannot turn round; at a junction you can turn your head into a
## side pipe. Asking twice for the side you already look into takes you in; asking for a
## side with no pipe, your head knocks the wall.
func _look_toward(side: int) -> void:
	if _stuck:
		_struggle()
		return
	if not _can_choose():
		return
	_auto_looks.clear()
	if side == _look_side:
		_forward()
		return
	if not _has_side(side):
		if _look_side != 0:
			_set_look(0)
		else:
			_nudge = float(side)
			_nudge_t = 0.0
			_play_pull("wall.mp3", -10.0)
		return
	_set_look(side)


func _set_look(side: int) -> void:
	if side == _look_side:
		return
	_look_side = side
	glancing = false
	_play_pull("turn.mp3", -13.0)


func _can_choose() -> bool:
	return not (_moving or _at_leak or _turning or _map_open or _intro_t >= 0.0 or _caught_t >= 0.0)


func _side_dir(side: int) -> int:
	return (_facing + (1 if side > 0 else 3)) % 4


## Not the pipe you came in by: round a bend it is at your side, and taking it turned you
## round in a pipe you cannot turn round in (playtest 25. 10.). Back you go feet first (S).
func _has_side(side: int) -> bool:
	return side != 0 and _links[_node].has(_side_dir(side)) and _side_dir(side) != _came_from


## Where the torch points, as a pipe direction: back over the shoulder, into the side
## pipe you look into, or on ahead.
func beam_dir() -> int:
	if glancing:
		return (_facing + 2) % 4
	if _look_side != 0 and _look > 0.6:
		return _side_dir(_look_side)
	return _facing


## The first junctions (and any time you crawl into a wall), the head goes by itself to
## each way on there is, a moment each: this is where you choose.
func _teach_sides() -> void:
	_auto_looks.clear()
	for side in [-1, 1]:
		if _has_side(side):
			_auto_looks.append(side)
	if not _auto_looks.is_empty():
		_auto_looks.append(0)
		_auto_t = 0.0
		_set_look(int(_auto_looks[0]))


func _update_auto_look(delta: float) -> void:
	if _auto_looks.is_empty():
		return
	_auto_t += delta
	if _auto_t < 0.75:
		return
	_auto_t = 0.0
	_auto_looks.pop_front()
	if not _auto_looks.is_empty():
		_set_look(int(_auto_looks[0]))


func _begin_turn(to_facing: int, sign: float) -> void:
	_turn_from = DIR_YAW[_facing]
	_facing = to_facing
	_turn_to = DIR_YAW[_facing]
	_turn_sign = sign
	_turn_t = 0.0
	_turning = true
	glancing = false
	_play_pull("turn.mp3", -7.0)


func _try_move(d: int) -> void:
	if _moving or _at_leak or _turning:
		return
	if not _links[_node].has(d) or d == _came_from:
		return
	var nxt: Vector2i = _node + DIRS[d]
	if mate.blocks(_node, nxt):
		_blocked_by_mate()
		return
	_facing = d
	_backing = false
	_move_from = _world_pos(_node)
	_move_to = _world_pos(nxt)
	_move_target_node = nxt
	_move_t = 0.0
	_move_secs = PULL_SECONDS * float(PULLS) * (BRICK_SLOW if _is_brick(_node, nxt) else 1.0)
	_pull_idx = -1
	_moving = true
	glancing = false
	# Knees and palms in the water: it hears every pipe you crawl.
	if _director != null:
		_director.heard(_node, 1)
	if _boy != null:
		_boy.moved()


# -- two in the pipes ---------------------------------------------------------------

## Back the way you came, feet first and slowly (out of the other warden's way), still
## looking ahead.
func _back_up() -> void:
	if _moving or _at_leak or _turning or _stuck or _map_open or _intro_t >= 0.0:
		return
	var back := (_facing + 2) % 4
	if not _links[_node].has(back):
		_bump_t = 0.0
		_play_pull("wall.mp3", -6.0)
		return
	var prev: Vector2i = _node + DIRS[back]
	if mate.blocks(_node, prev):
		_blocked_by_mate()
		return
	_move_from = _world_pos(_node)
	_move_to = _world_pos(prev)
	_move_target_node = prev
	_move_t = 0.0
	_move_secs = PULL_SECONDS * float(PULLS) * 1.7
	_pull_idx = -1
	_moving = true
	_backing = true
	glancing = false
	_set_status("")
	if _director != null:
		_director.heard(_node, 1)
	if _boy != null:
		_boy.moved()


## One of the others is in the way: their boots or their head, and nowhere to go.
func _blocked_by_mate() -> void:
	_bump_t = 0.0
	_play_one("bump.mp3", -4.0)
	var who := Coop.name_of(mate.blocker)
	var m: Dictionary = mate.mate()
	var facing_you := false
	if not m.is_empty():
		var their: int = int(m.get("f", 0))
		facing_you = (their + 2) % 4 == _facing
	_set_status(("%s's torch in your face. One of you backs up  [S]" if facing_you else "%s's boots, right in front of you.") % who)
	mate.bumped_into()


## The other machine: they crawled into you.
func coop_bumped() -> void:
	if not _active:
		return
	_bump_t = 0.0
	_play_one("bump.mp3", -2.0)
	_set_status("Something knocks against you. %s." % Coop.sender_name())


## The other machine: they clamped hole `i`.
func coop_fixed(i: int) -> void:
	if not _active:
		return
	_mark_fixed(i)
	_fixed = _all_fixed()
	if _cur_leak == i:
		_cur_leak = -1
		_at_leak = false
		_clamp = 0.0
		_moving = true


func _mark_fixed(i: int) -> void:
	if i < 0 or i >= _leaks.size():
		return
	var l: Dictionary = _leaks[i]
	l["fixed"] = true
	if l.get("fx") != null:
		l["fx"].emitting = false
	if l.get("audio") != null:
		l["audio"].stop()


## The chamber's amber terminal (scripts/pipes/sewer_terminal.gd): the network under
## the sewer at `coord` as it would be built now (the same seed and level as climbing
## down; the other warden's if they are down already), without going down:
## {links, entry, leaks [[a, b, fixed]], explore, level}.
func preview_network(coord: Vector2i) -> Dictionary:
	if not _active:
		var state = CoreRoot.get_state() if CoreRoot != null else null
		var key := "%d:%d" % [coord.x, coord.y]
		var since_day := int(state.day) if state != null else 1
		var broken := false
		if state != null:
			broken = state.failures.has(key)
			since_day = int((state.failures.get(key, {}) as Dictionary).get("since_day", state.day))
		mate.host = self
		mate.key = key
		var other: Dictionary = mate.mate()
		if not other.is_empty():
			since_day = int(other.get("sd", since_day))
		_rng.seed = hash("%d:%d:%d" % [coord.x, coord.y, since_day])
		var night := CoreRoot != null and CoreRoot.is_night()
		var office = get_parent().get("camp_office") if get_parent() != null else null
		var visit := int(office.get("pipe_visits")) + 1 if office != null else 3
		raccoon_level = debug_level if debug_level > 0 else DIRECTOR.mischief_level(_read_night_pressure(), night, visit)
		if not other.is_empty():
			raccoon_level = int(other.get("lv", raccoon_level))
		_generate()
		explore = not broken
	var leaks: Array = []
	for l in _leaks:
		leaks.append([l["a"], l["b"], bool(l.get("fixed", false)) or explore])
	return {"links": _links.duplicate(true), "entry": _entry, "leaks": leaks, "explore": explore, "level": raccoon_level, "size": _grid}


## Where you are down here, for the other machine (main.coop_local_warden "pipe").
func coop_pipe_state() -> Dictionary:
	var s: Dictionary = mate.state()
	if not s.is_empty():
		var fixed: Array = []
		for i in _leaks.size():
			if bool(_leaks[i].get("fixed", false)):
				fixed.append(i)
		s["fx"] = fixed
	return s


## One pull: the palm slaps down, the body drags after it. Now and then (more in the
## tight brick) your head finds the crown.
func _on_pull() -> void:
	_play_pull("pull.mp3" if _pull_idx % 2 == 0 else "pull2.mp3", -7.0)
	if _pipe_kind(_node, _move_target_node) == "steel":
		# The steel rings under your knees, all the way down the pipes.
		_clank()
	var tight := _is_brick(_node, _move_target_node)
	if _pull_idx > 0 and _rng.randf() < (0.12 if tight else 0.035):
		_bump_t = 0.0
		_play_one("bump.mp3", -5.0)
	if _director != null and _director.has_method("on_pull"):
		_director.on_pull()
	_vibe.on_pull(_pull_idx)


func _play_pull(file: String, db: float) -> void:
	if not ResourceLoader.exists(SFX_DIR + file):
		return
	_pull_player.stream = load(SFX_DIR + file)
	_pull_player.volume_db = db
	_pull_player.pitch_scale = _rng.randf_range(0.88, 1.08)
	_pull_player.play()


## How far along the pipe you are at move time t (0..1): each pull is a reach where
## nothing moves, then the drag, quick at first and dying away.
func _crawl_progress(t: float) -> float:
	var f := t * float(PULLS)
	var i := floorf(f)
	var k := f - i
	var m := clampf((k - 0.4) / 0.6, 0.0, 1.0)
	m = 1.0 - (1.0 - m) * (1.0 - m)
	return minf(1.0, (i + m) / float(PULLS))


func _process(delta: float) -> void:
	if not _active:
		return
	mate.update(delta)
	_update_body_sounds(delta)
	if _caught_t >= 0.0:
		_update_caught(delta)
		return
	if _intro_t >= 0.0:
		_update_intro(delta)
		return
	if _turning:
		_turn_t += delta
		if _turn_t >= TURN_SECONDS:
			_turning = false
	_update_auto_look(delta)
	if _moving:
		var li := _leak_index(_node, _move_target_node)
		var leak_here := li >= 0 and not bool(_leaks[li]["fixed"])
		var limit := 0.5 if leak_here else 1.0
		# Its snare: a heap of guts across the pipe. In it, you go nowhere till you tear free.
		if not _stuck and _move_t >= 0.3 and _move_t < 0.5 and _director != null and _director.is_trap(_node, _move_target_node):
			_stuck = true
			_stuck_need = 4 + raccoon_level
			_director.spring_trap(_node, _move_target_node)
			_gore = minf(1.0, _gore + 0.5)
			splatter(3)
			_play_one("rac_squelch.mp3", 0.0)
		if not _stuck:
			_move_t = minf(limit, _move_t + delta / _move_secs)
		var pull := int(_move_t * float(PULLS))
		if pull != _pull_idx and pull < PULLS and _move_t < limit:
			_pull_idx = pull
			_on_pull()
		if leak_here and _move_t >= 0.5:
			_moving = false
			_at_leak = true
			_cur_leak = li
			var work := str(_leaks[li].get("kind", "clamp"))
			if work != "clamp":
				_repair.begin(work, _rng.randi())
		elif _move_t >= 1.0:
			_arrive()
	if _at_leak:
		if _repair.is_active():
			_work_hand.stop()
		else:
			_update_clamp(delta)
	else:
		_work_hand.stop()
	if _director != null:
		_director.tick(delta)
	if _boy != null:
		_boy.tick(delta)
	_vibe.tick(delta)
	_update_torch(delta)
	if _fixed and _director != null and _director.leaves_prints():
		_place_handprints()
	_update_rig(delta)


## Your own breath and heart, and the dark closing in round the view, follow how close
## it is and how the director has wound you up.
func _update_body_sounds(delta: float) -> void:
	_update_splats(delta)
	# Its guts on your gloves.
	var glove := Color(1.0, 1.0 - 0.3 * _gore, 1.0 - 0.36 * _gore)
	if _crawl_hand != null:
		_crawl_hand.self_modulate = glove
	if _torch_hand != null:
		_torch_hand.self_modulate = glove
	var t: float = _director.tension if _director != null else 0.0
	# The other warden right there in the pipe: the walls close in.
	t = maxf(t, mate.squeeze * 0.85)
	var f: float = _director.flicker if _director != null else 0.0
	var pant_db := lerpf(-24.0, -11.0, t) + (3.0 if _moving else 0.0)
	var heart_db := -60.0 if t < 0.25 else lerpf(-26.0, -7.0, (t - 0.25) / 0.75)
	if _pant != null:
		_pant.volume_db = lerpf(_pant.volume_db, pant_db, clampf(delta * 1.5, 0.0, 1.0))
		_pant.pitch_scale = lerpf(0.95, 1.15, t)
	if _heart != null:
		_heart.volume_db = lerpf(_heart.volume_db, heart_db, clampf(delta * 1.2, 0.0, 1.0))
		_heart.pitch_scale = lerpf(0.9, 1.35, t)
	if _vignette != null:
		_vignette.modulate.a = clampf(0.62 + 0.35 * t + 0.25 * f, 0.0, 1.0)


func _arrive() -> void:
	_moving = false
	_pull_idx = -1
	_node = _move_target_node
	if _backing:
		# Backed out feet first: still facing the way you were (the pipe you came by is
		# ahead of you, nothing at the sides was it).
		_backing = false
		_came_from = -1
		_set_status("")
		return
	_came_from = (_facing + 2) % 4
	# A bend takes you round it (the pipe gives you no choice); a junction leaves you
	# facing on, to look and turn as you like.
	if not _links[_node].has(_facing):
		var right := (_facing + 1) % 4
		var left := (_facing + 3) % 4
		if _links[_node].has(right) and not _links[_node].has(left):
			_begin_turn(right, 1.0)
		elif _links[_node].has(left) and not _links[_node].has(right):
			_begin_turn(left, -1.0)
	_set_status("")
	if not _turning and (_has_side(-1) or _has_side(1)):
		var taught := _taught < TEACH_JUNCTIONS
		if taught or not _links[_node].has(_facing):
			_taught += 1
			_teach_sides()


func _update_clamp(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_clamp += delta / CLAMP_SECONDS
		_work_hand.start("Clamping", get_viewport().get_visible_rect().size * Vector2(0.5, 0.55))
		_work_hand.aim(get_viewport().get_visible_rect().size * Vector2(0.5, 0.55))
		if int(_clamp * 8.0) != int((_clamp - delta / CLAMP_SECONDS) * 8.0):
			_clank()
			if _director != null:
				_director.heard(_node, 2)
		_set_status("Clamping... %d%%" % int(clampf(_clamp, 0.0, 1.0) * 100.0))
		if _clamp >= 1.0:
			_play_one("clamp.mp3", -3.0)
			_leak_done()
	else:
		_work_hand.stop()
		_clamp = maxf(0.0, _clamp - delta * 0.5)
		if _clamp <= 0.0:
			_set_status("")


## A hole shut (the clamp, or pipe_repair's work): for both wardens, then on along the pipe.
func _leak_done() -> void:
	var l: Dictionary = _leaks[maxi(0, _cur_leak)]
	Coop.send_play("pipe_fixed", [mate.key, maxi(0, _cur_leak)])
	l["fixed"] = true
	if l.get("fx") != null:
		l["fx"].emitting = false
	if l.get("audio") != null:
		l["audio"].stop()
	_fixed = _all_fixed()
	_clamp = 0.0
	_cur_leak = -1
	_at_leak = false
	_set_status("")
	_work_hand.stop()
	# finish crossing the pipe
	_moving = true


func _clank() -> void:
	var p := AudioStreamPlayer.new()
	p.bus = audio_bus()
	if ResourceLoader.exists(SFX_CLANK):
		p.stream = load(SFX_CLANK)
	p.pitch_scale = randf_range(0.5, 0.65)
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _update_rig(delta: float) -> void:
	var pos: Vector3
	if _moving or _at_leak:
		pos = _move_from.lerp(_move_to, _crawl_progress(_move_t))
	else:
		pos = _world_pos(_node)
	_rig.position = pos
	_aim = _aim.lerp(_aim_target, clampf(delta * 5.0, 0.0, 1.0)) if delta > 0.0 else _aim_target
	_glance = move_toward(_glance, 1.0 if glancing else 0.0, delta * 4.5)
	var g := _glance * _glance * (3.0 - 2.0 * _glance)
	var base_yaw: float = DIR_YAW[_facing]
	var turn_k := 0.0
	if _turning:
		turn_k = clampf(_turn_t / TURN_SECONDS, 0.0, 1.0)
		base_yaw = lerp_angle(_turn_from, _turn_to, turn_k * turn_k * (3.0 - 2.0 * turn_k))
	_look = move_toward(_look, float(_look_side), delta * 3.2)
	var lk := _look * absf(_look) * (3.0 - 2.0 * absf(_look)) if absf(_look) < 1.0 else _look
	var nudge := 0.0
	if _nudge_t >= 0.0:
		_nudge_t += delta
		nudge = sin(clampf(_nudge_t / 0.35, 0.0, 1.0) * PI) * 0.32 * _nudge
		if _nudge_t >= 0.35:
			_nudge_t = -1.0
	var free_aim := 1.0 - g - absf(lk) * 0.7
	var target_yaw: float = base_yaw + PI * 0.94 * g - lk * LOOK_YAW - nudge - _aim.x * AIM_YAW * free_aim
	_rig.rotation.y = lerp_angle(_rig.rotation.y, target_yaw, minf(1.0, delta * 14.0)) if delta > 0.0 else target_yaw
	# The body in the pipe: each pull the head dips and leans to the reaching side, then
	# comes up as you drag; squeezing round, you lean into it; the crown knocks you back.
	var bob_y := 0.0
	var roll := 0.0
	var pitch := 0.0
	if _moving:
		var f := _move_t * float(PULLS)
		var k := f - floorf(f)
		var side := 1.0 if int(f) % 2 == 0 else -1.0
		var s := sin(k * PI)
		bob_y -= 0.05 * s
		roll += 0.045 * s * side
		pitch -= 0.05 * s
	if _turning:
		var s2 := sin(turn_k * PI)
		roll += 0.09 * s2 * _turn_sign
		bob_y -= 0.04 * s2
	var shake := Vector2.ZERO
	if _bump_t >= 0.0:
		_bump_t += delta
		var b := maxf(0.0, 1.0 - _bump_t / 0.4)
		shake = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.025 * b
		pitch += 0.07 * b
		if _bump_t >= 0.4:
			_bump_t = -1.0
	_bob += delta * 1.6
	bob_y += sin(_bob) * 0.006
	_camera.position = Vector3(shake.x, bob_y + shake.y, 0)
	_camera.rotation = Vector3(-0.12 * g - _aim.y * AIM_PITCH * (1.0 - g) + pitch, 0.0, roll)
	_flashlight.rotation = Vector3(-_aim.y * 0.05, -_aim.x * 0.07, 0.0)


# ── the thing in the pipes ────────────────────────────────────────────────────

func _next_step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var dist := _distances_from(to)
	var best := from
	var best_d := int(dist.get(from, 999))
	for d in _links[from]:
		var n: Vector2i = from + DIRS[d]
		if int(dist.get(n, 999)) < best_d:
			best_d = int(dist[n])
			best = n
	return best


# ── staging: the torch, the intro, being caught ─────────────────────────────

## Your hand holding the torch, bottom right, bobbing in steps with your walk; lowered
## when the torch is off; the beam stutters when the director says something is near.
func _update_torch(delta: float) -> void:
	_flicker_t += delta
	var f: float = _director.flicker if _director != null else 0.0
	var stutter := f > 0.0 and fmod(floorf(_flicker_t * 14.0) * 0.618, 1.0) < f * 0.6
	_flashlight.light_energy = 0.15 if stutter else 3.0
	if _torch_hand == null or _torch_hand.texture == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := _torch_hand.size.x / maxf(1.0, _torch_hand.texture.get_width())
	# Hand sprites move like a Build-engine weapon: in steps, twelve a second.
	var pull_k := 0.0
	if _moving:
		var pf := _move_t * float(PULLS)
		pull_k = floorf((pf - floorf(pf)) * PULL_SECONDS * 12.0) / (PULL_SECONDS * 12.0)
	var bob := (sin(pull_k * PI) * 14.0 * k) if _moving else (floorf(sin(_bob * 0.8) * 2.0) * k)
	var lowered := 0.0 if _flashlight.visible else _torch_hand.size.y * 0.55
	var clamping := _at_leak and (Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var hide := _torch_hand.size.y * (1.0 if clamping else 0.0)
	var turn_x := 0.0
	if _turning:
		turn_x = -sin(clampf(_turn_t / TURN_SECONDS, 0.0, 1.0) * PI) * 26.0 * k * _turn_sign
	_torch_hand.position = Vector2(vp.x * 0.62 + turn_x, vp.y - _torch_hand.size.y * 0.80 + bob + lowered + hide).floor()
	_torch_hand.modulate = Color(0.8, 0.78, 0.72) if not _flashlight.visible else Color.WHITE
	_torch_hand.visible = _glance < 0.5
	_update_crawl_hand(vp, k, pull_k)


## The free hand: each pull it comes up out of the bottom left, slaps down ahead on the
## wet concrete and slides back under you as the body drags over it. Turning, it pushes
## off the wall; at a dead end it is flat on the concrete in front of you.
func _update_crawl_hand(vp: Vector2, k: float, pull_k: float) -> void:
	if _crawl_hand == null or _crawl_hand.texture == null:
		return
	var sz := _crawl_hand.size
	var plant := Vector2(vp.x * 0.16, vp.y - sz.y * 0.78)
	var show := false
	var at := plant
	if _moving:
		show = true
		if pull_k < 0.4:
			var r := pull_k / 0.4
			at = plant + Vector2(-20.0 * k * (1.0 - r), sz.y * 0.9 * (1.0 - r) * (1.0 - r))
		else:
			var d := (pull_k - 0.4) / 0.6
			at = plant + Vector2(-8.0 * k * d, sz.y * 0.95 * d * d)
	elif _turning:
		show = true
		var tk := sin(clampf(_turn_t / TURN_SECONDS, 0.0, 1.0) * PI)
		at = Vector2(vp.x * 0.04, vp.y - sz.y * 0.55 * tk)
	elif absf(_look) > 0.25:
		# Head in the side pipe: the hand takes hold of the edge of it.
		show = true
		at = Vector2(vp.x * 0.08, vp.y - sz.y * 0.62 * minf(1.0, absf(_look) * 1.3))
	elif _bump_t >= 0.0 and not _at_leak:
		show = true
		at = Vector2(vp.x * 0.30, vp.y * 0.30 + sz.y * 0.1 * (_bump_t / 0.4))
	# The made hands: reaching while it goes forward, planted on the floor otherwise.
	if _hand_plant == null and ResourceLoader.exists(HAND_PLANT):
		_hand_plant = load(HAND_PLANT)
	if _hand_reach == null and ResourceLoader.exists(HAND_REACH):
		_hand_reach = load(HAND_REACH)
	if _hand_plant != null:
		var want: Texture2D = _hand_reach if (_moving and pull_k < 0.4 and _hand_reach != null) else _hand_plant
		if _crawl_hand.texture != want:
			_crawl_hand.texture = want
			_crawl_hand.flip_h = false
			_crawl_hand.size = want.get_size() * k
	_crawl_hand.visible = show and _glance < 0.5 and _caught_t < 0.0
	_crawl_hand.position = at.floor()


## Down the ladder: the rungs go up past you, the splash at the bottom, then the map you
## were given unfolds for a moment so you know what you have. Any key skips.
func _update_intro(delta: float) -> void:
	_intro_t += delta
	_update_torch(delta)
	var base := _world_pos(_entry)
	var k := clampf(_intro_t / 2.2, 0.0, 1.0)
	_rig.position = base + Vector3(0, lerpf(2.6, 0.0, k * k * (3.0 - 2.0 * k)), 0.35 * (1.0 - k))
	_rig.rotation.y = DIR_YAW[_facing]
	_camera.rotation.x = lerpf(-0.5, 0.0, k)
	var map_on := _intro_t >= 2.3 and _intro_t < 5.6
	if _map.visible != map_on:
		_map.visible = map_on
		_ink.queue_redraw()
	if _intro_t >= 5.6:
		_intro_t = -1.0
		_map.visible = false
		_camera.rotation.x = 0.0
		_update_rig(0.0)


## Called by the director: it has you. One of its catches plays (pipes/pipe_catch.gd),
## then the dark, and you come to at the foot of the ladder.
func caught_by_thing() -> void:
	if _caught_t >= 0.0:
		return
	_caught_t = 0.0
	_caught_hit = false
	_caught_fade = false
	var behind: bool = glancing or (_director != null and str((_director._scene as Dictionary).get("kind", "")) == "behind")
	var stuck := _stuck
	glancing = false
	_turning = false
	_stuck = false
	_moving = false
	_at_leak = false
	_clamp = 0.0
	_cur_leak = -1
	_repair.cancel()
	_work_hand.stop()
	_set_status("")
	_catch.play_for(stuck, behind)


## The shot driver: put you at a junction with a pipe on both sides (or one), facing on.
func debug_goto_junction() -> void:
	var best := [-1, _node, _facing]
	for c in _links.keys():
		for d in _links[c]:
			if c == _entry:
				continue
			var sides := int(_links[c].has((d + 1) % 4)) + int(_links[c].has((d + 3) % 4))
			if sides > int(best[0]):
				best = [sides, c, d]
	_node = best[1]
	_facing = best[2]
	_moving = false
	_turning = false
	_look_side = 0
	_look = 0.0
	_auto_looks.clear()
	_update_rig(0.0)


## The shot driver: one catch by name.
func debug_catch(k: String) -> void:
	caught_by_thing()
	_catch.play(k)


func _on_catch_hit() -> void:
	if _caught_hit:
		return
	_caught_hit = true
	_gore = 1.0
	player_hurt.emit(DIRECTOR.DAMAGE)


func _on_catch_done() -> void:
	if not _caught_hit:
		_on_catch_hit()
	_node = _entry
	_facing = 0
	_look_side = 0
	_look = 0.0
	_aim = Vector2.ZERO
	_crawl_hand.scale = Vector2.ONE
	_crawl_hand.visible = false
	_camera.rotation = Vector3.ZERO
	_camera.position = Vector3.ZERO
	_flashlight.visible = true
	_rig.rotation.y = DIR_YAW[_facing]
	_update_rig(0.0)
	_black.color.a = 1.0
	_caught_fade = true


func _update_caught(delta: float) -> void:
	_caught_t += delta
	if _catch.is_playing():
		# The torch stutters as the catch says.
		var f: float = _director.flicker if _director != null else 0.0
		_flashlight.light_energy = 0.15 if (f > 0.0 and randf() < f * 0.6) else 3.0
		if _director != null:
			_director.flicker = maxf(0.0, f - delta * 1.2)
		return
	if _caught_fade:
		_black.color.a = maxf(0.0, _black.color.a - delta * 0.7)
		_update_torch(delta)
		if _black.color.a <= 0.0:
			_caught_fade = false
			_caught_t = -1.0


func _play_one(file: String, db: float) -> void:
	if ResourceLoader.exists(SFX_DIR + file):
		_one.stream = load(SFX_DIR + file)
		_one.volume_db = db
		_one.play()
