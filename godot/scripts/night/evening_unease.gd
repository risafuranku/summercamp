extends Node

## The evening before a bad night (the user 4. 11.: "use the moments of silence as music;
## the more the night presses, the stranger the evening before it: the feeling that this
## time something is different", and "a total spook genius: just right; too much is
## embarrassing, too little and they cool off; badly timed or not seen and it does nothing;
## read them: what they are doing, where they are going, what just happened").
##
## Nothing scripted. From the evening (EVENING_FROM) to when the night's own director takes
## over (NIGHT_FROM) a few beats are spread over the hours, as many as the coming night
## presses (omens.pressure: an empty camp none, a full and troubled one up to MAX_BEATS),
## each held back until the warden is where it works:
##   hold     the world holds its breath: the insects, the birds and the music stop for a
##            few seconds of nothing (the music winds down as it does for any hush), then
##            the evening comes back
##   holdfar  the same, and in the silence one wrong sound far off across the camp
##   far      the wrong sound alone: children's laughter stopping dead, a dog's howl cut
##            short, one bell where no church is, somebody calling once, an axe stopping
##            halfway (assets/sfx/far/e_*, each once an evening)
##   radio    the warden in the office: the set sickens a while instead (radio_dread.nudge)
## Read off the warden (main's evening context): busy at something (the PC, the desk, a
## station, a book) or running, and it waits a few minutes; indoors, a sound from far off
## waits for the outside; two beats never closer than MIN_GAP_SEC; a quiet first night has
## none. Each co-op machine its own, like the omens (they are signs near you).

const EVENING_FROM := 18.5 * 60.0
const NIGHT_FROM := 21.4 * 60.0
const MAX_BEATS := 4
const MIN_GAP_SEC := 40.0
const HOLD_SEC := Vector2(6.5, 11.0)
const HOLD_IN := 0.8
const HOLD_OUT := 2.6
const FAR_DIR := "res://assets/sfx/far/"
const FAR_SOUNDS := ["e_kids_stop", "e_dog_cut", "e_bell_one", "e_call", "e_axe_stop"]
const FAR_M := Vector2(45.0, 75.0)
const OUTDOOR_BUS := "OutdoorAmbience"

## 0..1: the evening holding its breath (main puts it on the insects' hush and the world's).
var hold := 0.0

var _main: Node
var _rng := RandomNumberGenerator.new()
var _plan: Array = []          # [{at: abs minute, kind}], soonest first
var _planned_day := -1
var _hold_t := -1.0
var _hold_len := 0.0
var _far_in_hold := false
var _since_beat := 999.0
var _used: Dictionary = {}
var _player_pos := Vector3.ZERO


func setup(main_node: Node) -> void:
	_main = main_node
	_rng.randomize()


func reset() -> void:
	_plan.clear()
	_planned_day = -1
	_hold_t = -1.0
	hold = 0.0
	_used.clear()


## Every frame. `ctx`: pressure (omens.pressure), quiet (a quiet first night), busy,
## running, indoors, in_office, player_pos.
func tick(delta: float, abs_minute: int, ctx: Dictionary) -> void:
	_since_beat += delta
	_player_pos = ctx.get("player_pos", _player_pos)
	_tick_hold(delta)
	var day := abs_minute / 1440
	var minute := posmod(abs_minute, 1440)
	if minute >= int(EVENING_FROM) and minute < int(NIGHT_FROM) and day != _planned_day:
		_planned_day = day
		_plan_evening(abs_minute, ctx)
	if minute >= int(NIGHT_FROM) or minute < int(EVENING_FROM):
		_plan.clear()
		return
	if _plan.is_empty() or abs_minute < int(_plan[0]["at"]):
		return
	if _since_beat < MIN_GAP_SEC or _hold_t >= 0.0:
		return
	var b: Dictionary = _plan[0]
	# Not while they are at something or running: unseen, unheard, it would be wasted.
	if bool(ctx.get("busy", false)) or bool(ctx.get("running", false)):
		b["at"] = abs_minute + _rng.randi_range(2, 5)
		return
	var kind := str(b["kind"])
	if bool(ctx.get("indoors", false)):
		if bool(ctx.get("in_office", false)):
			kind = "radio"
		elif kind != "hold":
			b["at"] = abs_minute + 4
			return
	_plan.pop_front()
	_fire(kind)


func _plan_evening(abs_minute: int, ctx: Dictionary) -> void:
	_plan.clear()
	_used.clear()
	if bool(ctx.get("quiet", false)):
		return
	var n := clampi(int(round((float(ctx.get("pressure", 0.3)) - 0.6) * 1.1)), 0, MAX_BEATS)
	if n <= 0:
		return
	var day_start := abs_minute - posmod(abs_minute, 1440)
	var a := maxi(abs_minute + 5, day_start + int(EVENING_FROM) + 10)
	var b := day_start + int(NIGHT_FROM) - 10
	if b <= a:
		return
	for i in n:
		var at := a + int(float(b - a) * (float(i) + _rng.randf_range(0.2, 0.8)) / float(n))
		# The first a silence alone; the later ones a silence with something in it, or it.
		var kind := "hold" if i == 0 else ("holdfar" if _rng.randf() < 0.6 else "far")
		_plan.append({"at": at, "kind": kind})


func _fire(kind: String) -> void:
	_since_beat = 0.0
	match kind:
		"hold", "holdfar":
			_hold_t = 0.0
			_hold_len = _rng.randf_range(HOLD_SEC.x, HOLD_SEC.y)
			_far_in_hold = kind == "holdfar"
		"far":
			_far()
		"radio":
			var im = _main.get("_interior_manager") if _main != null else null
			var bi = im.get("_building_interior") if im != null else null
			var dread = bi.get("_dread") if bi != null else null
			if dread != null and dread.has_method("nudge"):
				dread.nudge(0.45, 12.0)


func _tick_hold(delta: float) -> void:
	if _hold_t < 0.0:
		hold = 0.0
		return
	_hold_t += delta
	hold = minf(clampf(_hold_t / HOLD_IN, 0.0, 1.0), clampf((_hold_len - _hold_t) / HOLD_OUT, 0.0, 1.0))
	if _far_in_hold and _hold_t >= _hold_len * 0.5:
		_far_in_hold = false
		_far()
	if _hold_t >= _hold_len:
		_hold_t = -1.0
		hold = 0.0


## One wrong sound far off, somewhere round the warden, once an evening each.
func _far() -> void:
	var left: Array = FAR_SOUNDS.filter(func(s): return not _used.has(s))
	if left.is_empty():
		return
	var id := str(left[_rng.randi() % left.size()])
	_used[id] = true
	var path := FAR_DIR + id + ".mp3"
	if not ResourceLoader.exists(path) or _main == null:
		return
	var world := _main.find_child("World3D", true, false) as Node3D
	if world == null:
		world = _main as Node3D
	if world == null:
		return
	var a := _rng.randf() * TAU
	var p := AudioStreamPlayer3D.new()
	p.name = "EveningFar"
	p.stream = load(path)
	p.unit_size = 12.0
	p.max_distance = 170.0
	p.volume_db = 0.0
	if AudioServer.get_bus_index(OUTDOOR_BUS) >= 0:
		p.bus = OUTDOOR_BUS
	world.add_child(p)
	p.global_position = _player_pos + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(FAR_M.x, FAR_M.y) + Vector3(0, 1.5, 0)
	p.play()
	p.finished.connect(p.queue_free)


func debug_plan() -> Array:
	return _plan.duplicate(true)


## Debug (tools/evening_check): a beat now.
func debug_fire(kind: String) -> void:
	_fire(kind)
