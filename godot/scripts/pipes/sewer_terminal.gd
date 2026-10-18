extends "res://scripts/closeup/closeup_view.gd"

## The monitoring terminal in the sewer's pumping chamber, close up (Grok,
## assets/textury/closeup/amber_terminal.png): a 1980s amber screen that knows the
## pipes. It draws the network under this sewer (the same pipes the crawl will build:
## sewer_pipe_minigame.preview_network) as a grid of junctions, the ladder at D5, and
## where the pressure is lost (the holes the raccoon chewed) blinking; nothing broken,
## it says so. On the worse nights a MOTION line wanders from pipe to pipe and the
## screen tears now and then. What it shows you, you can remember for down there (the
## worker's paper map does not show where you are either).

const PIC := "res://assets/textury/closeup/amber_terminal.png"
const AMBER := Color(1.0, 0.66, 0.16)
const AMBER_DIM := Color(0.62, 0.36, 0.06)
## The glass of the screen in the picture (px).
const SCREEN := Rect2(52, 30, 216, 140)
const COLS := "ABCDEFGH"
const SFX_HUM := "res://assets/sfx/crtui/crt_on.mp3"
const SFX_KEY := "res://assets/sfx/desk/card_drop.mp3"

var network: Dictionary = {}
var raccoon_level := 1
var night := false

var _t := 0.0
var _typed := 0.0
var _motion := Vector2i(-1, -1)
var _motion_t := 0.0
var _tear_t := -1.0
var _rng := RandomNumberGenerator.new()


func open_for(net: Dictionary, level: int, is_night: bool) -> void:
	network = net
	raccoon_level = level
	night = is_night
	if picture == null and ResourceLoader.exists(PIC):
		picture = load(PIC)
	_rng.randomize()
	_t = 0.0
	_typed = 0.0
	_motion = Vector2i(-1, -1)
	open_view()


func _opened() -> void:
	play(SFX_HUM, -10.0)
	var faults := _faults()
	if bool(network.get("explore", false)) or faults.is_empty():
		say("", "The screen hums. Nothing on it is blinking.")
	else:
		say("", "Pressure loss. %d %s down there." % [faults.size(), "place" if faults.size() == 1 else "places"])


func _faults() -> Array:
	var out: Array = []
	if bool(network.get("explore", false)):
		return out
	for l in network.get("leaks", []):
		if not bool(l[2]):
			out.append(l)
	return out


func _tick(delta: float) -> void:
	_t += delta
	_typed += delta * 60.0
	if raccoon_level >= 2 or night:
		_motion_t -= delta
		if _motion_t <= 0.0:
			_motion_t = _rng.randf_range(2.5, 5.0)
			var links: Dictionary = network.get("links", {})
			var keys := links.keys()
			if not keys.is_empty():
				# On from where it was, along a pipe, or somewhere else altogether.
				if _motion != Vector2i(-1, -1) and links.has(_motion) and _rng.randf() < 0.7 and not (links[_motion] as Array).is_empty():
					var d: int = links[_motion][_rng.randi() % (links[_motion] as Array).size()]
					_motion = _motion + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][d]
				else:
					_motion = keys[_rng.randi() % keys.size()]
		if _tear_t < 0.0 and _rng.randf() < delta * (0.04 + 0.05 * raccoon_level):
			_tear_t = 0.0
	if _tear_t >= 0.0:
		_tear_t += delta
		if _tear_t > 0.35:
			_tear_t = -1.0


func _label(c: Vector2i) -> String:
	return "%s%d" % [COLS[c.x], c.y + 1]


func _paint(c: Control) -> void:
	var f: Font = RETRO_UI.FONT_TEXT
	var fs := RETRO_UI.SIZE_TEXT
	var flick := 0.86 + 0.14 * float(int(_t * 9.0) % 3 == 0)
	var ink := Color(AMBER.r, AMBER.g, AMBER.b, flick)
	var dim := Color(AMBER_DIM.r, AMBER_DIM.g, AMBER_DIM.b, flick)
	var x0 := SCREEN.position.x + 6.0
	var y0 := SCREEN.position.y + 10.0
	var tear := 0.0
	if _tear_t >= 0.0:
		tear = sin(_tear_t * 40.0) * 3.0
	var shown := int(_typed)
	var lines := ["ZVS-84  SEWER CONTROL", "LESNA CAMP  NET A1-F5"]
	var drawn := 0
	for i in lines.size():
		var txt: String = lines[i]
		txt = txt.substr(0, clampi(shown - drawn, 0, txt.length()))
		drawn += lines[i].length()
		c.draw_string(f, Vector2(x0 + (tear if i == 1 else 0.0), y0 + i * 9.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if shown < drawn:
		return
	# The grid of junctions and the pipes between them.
	var links: Dictionary = network.get("links", {})
	var entry: Vector2i = network.get("entry", Vector2i(2, 4))
	var faults := _faults()
	var gx := x0 + 14.0
	var gy := y0 + 30.0
	var cw := 26.0
	var ch := 17.0
	var blink := int(_t * 2.5) % 2 == 0
	for col in 6:
		c.draw_string(f, Vector2(gx + col * cw - 2.0, gy - 9.0), COLS[col], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
	for row in 5:
		c.draw_string(f, Vector2(gx - 12.0, gy + row * ch + 3.0), str(row + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
	for cell in links:
		var p := Vector2(gx + cell.x * cw, gy + cell.y * ch) + Vector2(tear * float(cell.y % 2), 0.0)
		for d in links[cell]:
			if d != 1 and d != 2:
				continue
			var n: Vector2i = cell + (Vector2i(1, 0) if d == 1 else Vector2i(0, 1))
			var bad := false
			for l in faults:
				if (l[0] == cell and l[1] == n) or (l[0] == n and l[1] == cell):
					bad = true
			var steps := 3
			for k in range(1, steps + 1):
				var q := p.lerp(Vector2(gx + n.x * cw, gy + n.y * ch), float(k) / float(steps + 1))
				var glyph := "-" if d == 1 else "|"
				if bad and k == 2:
					if blink:
						c.draw_string(f, q + Vector2(-1.5, 3.0), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
					continue
				c.draw_string(f, q + Vector2(-1.0, 3.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
		var mark := "#" if cell == entry else "o"
		if cell == _motion and int(_t * 6.0) % 2 == 0:
			mark = "?"
		c.draw_string(f, p + Vector2(-2.0, 3.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# The status lines.
	var sy := gy + 5.0 * ch + 4.0
	if faults.is_empty():
		c.draw_string(f, Vector2(x0, sy), "STATUS  NO FAULTS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	else:
		var row_txt := "FAULT  "
		for l in faults:
			row_txt += "%s-%s  " % [_label(l[0]), _label(l[1])]
		if blink:
			c.draw_string(f, Vector2(x0, sy), row_txt + "PRESSURE LOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if _motion != Vector2i(-1, -1):
		c.draw_string(f, Vector2(x0, sy + 9.0), "MOTION  %s" % _label(_motion), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
	c.draw_string(f, Vector2(x0, sy + 18.0), "LADDER  %s   _" % _label(entry) if blink else "LADDER  %s" % _label(entry), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dim)
