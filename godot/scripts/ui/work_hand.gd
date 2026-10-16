extends Control

## Your hand while you work (room prep inside interiors, repairs and chores outside): a
## Build-engine "weapon" sprite of a gloved hand with the right tool, rising from the
## bottom of the screen and going at the thing under the cursor: scrubbing in circles,
## sweeping, mopping, wiping, plunging, turning a wrench, picking things up. Dust, suds
## and drops fly off it.
##
## Everything moves in steps, STEP_FPS a second (no smooth tweening), like a 1996 game's
## hand animation: that stutter is the look.
##
##   hand.start("Scrubbing", target_screen_pos)   (verb from core/systems/mess_rules.gd)
##   hand.aim(target_screen_pos)                   while held
##   hand.stop()                                   drops the hand out of view

const STEP_FPS := 10.0
const DIR := "res://assets/textury/hands/"
## verb -> [tool sprite, motion, particles]
const BY_VERB := {
	"Scrubbing": ["brush", "scrub", "suds"],
	"Sweeping": ["broom", "sweep", "dust"],
	"Mopping": ["mop", "mop", "drops"],
	"Wiping": ["rag", "wipe", "suds"],
	"Scraping": ["rag", "wipe", "dust"],
	"Clearing up": ["bag", "pick", "dust"],
	"Bagging": ["bag", "pick", "dust"],
	"Throwing out": ["bag", "pick", "dust"],
	"Picking up": ["open", "pick", "dust"],
	"Making the bed": ["open", "pat", "fluff"],
	"Rolling out": ["open", "pat", "fluff"],
	"Plunging": ["plunger", "plunge", "drops"],
	"Fixing": ["wrench", "turn", "sparks"],
	"Repairing": ["wrench", "turn", "sparks"],
	"Refilling": ["open", "pick", ""],
	"Pulling": ["open", "pick", "drops"],
	"Emptying": ["open", "pick", "drops"],
	"Sawing": ["open", "sweep", "dust"],
	"Clamping": ["clamp", "turn", "drops"],
}
## Where on each sprite the tool does its work (share of width, height): that point goes
## on the target.
const TIPS := {
	"brush": Vector2(0.1, 0.4), "broom": Vector2(0.16, 0.45), "mop": Vector2(0.22, 0.22),
	"rag": Vector2(0.2, 0.28), "bag": Vector2(0.28, 0.62), "plunger": Vector2(0.14, 0.14),
	"wrench": Vector2(0.2, 0.14), "open": Vector2(0.22, 0.2), "clamp": Vector2(0.24, 0.3),
}
const PARTICLE_COLORS := {
	"suds": [Color(0.92, 0.94, 0.95), Color(0.78, 0.84, 0.88)],
	"dust": [Color(0.62, 0.56, 0.46), Color(0.48, 0.44, 0.38)],
	"drops": [Color(0.55, 0.66, 0.74), Color(0.36, 0.46, 0.56)],
	"fluff": [Color(0.9, 0.88, 0.8), Color(0.76, 0.72, 0.64)],
	"sparks": [Color(1.0, 0.86, 0.4), Color(1.0, 0.6, 0.2)],
}

var _tex: Texture2D
var _verb := ""
var _tip := Vector2(0.3, 0.28)
var _motion := "pick"
var _particles_kind := ""
var _target := Vector2.ZERO
var _raise := 0.0          # 0 hidden .. 1 up, in steps
var _active := false
var _frame := 0
var _acc := 0.0
var _parts: Array = []     # {p, v, life, c}
var _rng := RandomNumberGenerator.new()
var _cache: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()


func start(verb: String, target: Vector2) -> void:
	_target = target
	if _active and verb == _verb:
		return
	_verb = verb
	var spec: Array = BY_VERB.get(verb, ["open", "pick", "dust"])
	_tex = _load(str(spec[0]))
	_tip = TIPS.get(str(spec[0]), Vector2(0.3, 0.28))
	_motion = str(spec[1])
	_particles_kind = str(spec[2])
	_target = target
	_active = true
	_frame = 0


func aim(target: Vector2) -> void:
	_target = target


func stop() -> void:
	_active = false


func is_showing() -> bool:
	return _raise > 0.0 or not _parts.is_empty()


func _load(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := DIR + name + ".png"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


func _process(delta: float) -> void:
	if not _active and _raise <= 0.0 and _parts.is_empty():
		return
	_acc += delta
	var stepped := false
	while _acc >= 1.0 / STEP_FPS:
		_acc -= 1.0 / STEP_FPS
		_step()
		stepped = true
	if stepped:
		queue_redraw()


## One frame of the animation.
func _step() -> void:
	_frame += 1
	_raise = clampf(_raise + (0.34 if _active else -0.34), 0.0, 1.0)
	if _active and _raise >= 1.0 and _particles_kind != "":
		var cols: Array = PARTICLE_COLORS.get(_particles_kind, [Color.WHITE])
		for i in _rng.randi_range(1, 3):
			var v := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.6, -0.2))
			if _particles_kind == "drops":
				v.y = _rng.randf_range(-0.8, 0.4)
			_parts.append({"p": _target + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-8, 8)), "v": v, "life": _rng.randi_range(3, 6), "c": cols[_rng.randi_range(0, cols.size() - 1)]})
	var s := _px()
	for p in _parts:
		p["p"] += p["v"] * 6.0 * s
		if _particles_kind == "drops" or _particles_kind == "sparks":
			p["v"].y += 0.5
		p["life"] -= 1
	_parts = _parts.filter(func(p): return int(p["life"]) > 0)


func _px() -> float:
	return maxf(1.0, floorf(size.y / 360.0))


## Where the work happens, in frames: an offset from the target for this frame.
func _motion_offset() -> Vector2:
	var s := _px()
	var f := float(_frame)
	match _motion:
		"scrub":
			var a := TAU * fposmod(f, 6.0) / 6.0
			return Vector2(cos(a) * 9.0, sin(a) * 6.0) * s
		"sweep":
			var k := fposmod(f, 8.0)
			var x := (k if k < 4.0 else 8.0 - k) / 4.0 * 2.0 - 1.0
			return Vector2(x * 26.0, absf(x) * -5.0) * s
		"mop":
			var a := TAU * fposmod(f, 12.0) / 12.0
			return Vector2(sin(a) * 40.0, cos(a * 2.0) * 4.0) * s
		"wipe":
			return Vector2((10.0 if int(f) % 2 == 0 else -10.0) + (4.0 if int(f) % 4 < 2 else -4.0), 0.0) * s
		"pick":
			var k := int(fposmod(f, 6.0))
			return Vector2(0.0, [0.0, 10.0, 20.0, 20.0, 10.0, 0.0][k]) * s
		"pat":
			return Vector2(0.0, (8.0 if int(f) % 2 == 0 else 0.0) + (int(f) % 6) * 2.0) * s
		"plunge":
			return Vector2(0.0, [0.0, 14.0, 28.0, 14.0][int(fposmod(f, 4.0))]) * s
		"turn":
			return Vector2([0.0, 6.0, 10.0, 6.0][int(fposmod(f, 4.0))], [0.0, -4.0, 0.0, 4.0][int(fposmod(f, 4.0))]) * s
	return Vector2.ZERO


func _draw() -> void:
	var s := _px()
	for p in _parts:
		var sz := 2.0 * s
		draw_rect(Rect2((p["p"] as Vector2).floor(), Vector2(sz, sz)), p["c"])
	if _raise <= 0.0:
		return
	var screen := size
	var scale := maxf(1.0, floorf(screen.y * 0.5 / 180.0))
	if _tex == null:
		# No art: a plain gloved fist so the motion still reads.
		var fist := Rect2(_target + _motion_offset() + Vector2(10, 10) * s, Vector2(40, 30) * s)
		fist.position.y += (1.0 - _raise) * screen.y * 0.4
		draw_rect(fist, Color(0.62, 0.5, 0.34))
		return
	var tsz := _tex.get_size() * scale
	# The tool's working end sits about a third in from the sprite's top-left; put that on
	# the target, keep the arm on the bottom edge (the sprite can rise above it, never float).
	var tip := tsz * _tip
	var pos := _target + _motion_offset() - tip
	pos.x = clampf(pos.x, screen.x * 0.18, screen.x - tsz.x * 0.62)
	pos.y = maxf(pos.y, screen.y - tsz.y)
	pos.y += (1.0 - _raise) * tsz.y
	draw_texture_rect(_tex, Rect2(pos.floor(), tsz), false)
