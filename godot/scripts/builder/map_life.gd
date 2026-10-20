extends RefCounted

## The small life of Builder 98's map, between the guests (crt_map_panel.gd draws it on
## its dynamic layer): the camp's dog trotting between the lodgings, sniffing, sitting,
## barking; ducks paddling on the lake and the sun glinting on the water; moths round the
## lit lamps at dusk; a mouse darting out by the pub and the bistro; ants trailing to a
## picnic table; now and then a few birds crossing the whole map. All of it Grok's frames
## (tools/artgen: builder/life/<thing>_<n>.png), stepped (four to twelve frames a
## second), sized to the map's people; without the pictures there is simply none of it.

const DIR := "res://assets/textury/builder/life/"
const SFX := "res://assets/sfx/builder/"
const SHEETS := {"dog": 8, "lake": 8, "bugs": 8, "birds": 8}

var _tex: Dictionary = {}       # "dog_3" -> texture
var _minis: Dictionary = {}     # "dog_3|h" -> texture brought down
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _dog: Dictionary = {}
var _ducks: Array = []
var _glints: Array = []
var _mice: Array = []
var _birds: Dictionary = {}
var _birds_at := 25.0


func _init() -> void:
	_rng.randomize()
	for k in SHEETS:
		for i in int(SHEETS[k]):
			var p := DIR + "%s_%d.png" % [k, i]
			if ResourceLoader.exists(p):
				_tex["%s_%d" % [k, i]] = load(p)


func has(kind: String) -> bool:
	return _tex.has(kind + "_0")


func _frame(map, key: String, h: int) -> Texture2D:
	var mk := "%s|%d" % [key, h]
	if not _minis.has(mk):
		_minis[mk] = map._mini_of(_tex[key], h) if _tex.has(key) else null
	return _minis[mk]


## Free open ground (no lake, nothing built, no tree) round `c`.
func _open(map, c: Vector2i) -> bool:
	if not map._is_valid_coord(c):
		return false
	var tile = map.grid_manager.get_tile(c)
	return tile != null and not tile.occupied and tile.tile_type != map.grid_manager.TILE_LAKE


func tick(delta: float, map) -> void:
	_t += delta
	var hour := float(map._wx.get("hour", 12.0))
	var day := hour >= 6.5 and hour <= 19.5
	_tick_dog(delta, map, day)
	_tick_lake(delta, map, day)
	_tick_mice(delta, map, day)
	_tick_birds(delta, map, day)


func _tick_dog(delta: float, map, day: bool) -> void:
	if not has("dog") or not day or map._known.is_empty():
		_dog = {}
		return
	if _dog.is_empty():
		var homes: Array = map._known.keys()
		var o: Vector2i = homes[_rng.randi() % homes.size()]
		_dog = {"cell": Vector2(o) + Vector2(1.2, 0.4), "to": Vector2(o), "state": "run", "t": 0.0, "mirror": false}
	_dog["t"] = float(_dog["t"]) - delta
	match str(_dog["state"]):
		"run":
			var c: Vector2 = _dog["cell"]
			var to: Vector2 = _dog["to"]
			var step := c.move_toward(to, delta * 1.6)
			var dd: Vector2 = map._display_cell_f(step) - map._display_cell_f(c)
			if dd.length_squared() > 0.0:
				_dog["mirror"] = dd.x - dd.y > 0.0
			_dog["cell"] = step
			if step.distance_to(to) < 0.05:
				var r := _rng.randf()
				_dog["state"] = "sniff" if r < 0.5 else ("sit" if r < 0.8 else "bark")
				_dog["t"] = _rng.randf_range(1.5, 4.0)
				if str(_dog["state"]) == "bark":
					map._play("dog", -16.0)
		_:
			if float(_dog["t"]) <= 0.0:
				# Off to another lodging, a tile beside it on open ground.
				var homes: Array = map._known.keys()
				var o: Vector2i = homes[_rng.randi() % homes.size()]
				for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 1)]:
					if _open(map, o + d):
						_dog["to"] = Vector2(o + d)
						break
				_dog["state"] = "run"


func _tick_lake(delta: float, map, day: bool) -> void:
	if not has("lake") or map._lake_cells_f.is_empty():
		_ducks.clear()
		return
	var cells: Array = map._lake_cells_f
	if _ducks.is_empty():
		for i in mini(3, cells.size()):
			var c: Vector2 = cells[_rng.randi() % cells.size()]
			_ducks.append({"cell": c, "to": c, "dip": 0.0})
	for d in _ducks:
		var c: Vector2 = d["cell"]
		if c.distance_to(d["to"]) < 0.05:
			d["to"] = cells[_rng.randi() % cells.size()] if _rng.randf() < 0.01 else c
			if _rng.randf() < 0.003:
				d["dip"] = 1.2
		else:
			var nxt: Vector2 = c.move_toward(d["to"], delta * 0.35)
			var dd: Vector2 = map._display_cell_f(nxt) - map._display_cell_f(c)
			d["mirror"] = dd.x - dd.y > 0.0
			d["cell"] = nxt
		d["dip"] = maxf(0.0, float(d["dip"]) - delta)
	# The sun on the water: a glint here and there by day, a moment each.
	for i in range(_glints.size() - 1, -1, -1):
		_glints[i]["t"] = float(_glints[i]["t"]) + delta
		if float(_glints[i]["t"]) > 0.5:
			_glints.remove_at(i)
	if day and _glints.size() < 6 and _rng.randf() < delta * 6.0:
		_glints.append({"cell": cells[_rng.randi() % cells.size()] + Vector2(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)), "t": 0.0})


func _tick_mice(delta: float, map, day: bool) -> void:
	if not has("bugs"):
		return
	for i in range(_mice.size() - 1, -1, -1):
		_mice[i]["t"] = float(_mice[i]["t"]) + delta
		if float(_mice[i]["t"]) > 2.4:
			_mice.remove_at(i)
	if _mice.size() < 2 and _rng.randf() < delta * 0.05:
		var eats: Array = []
		for o in map._known:
			if str(map._known[o][0]) in ["pub", "restaurant", "vecerka", "corn_stand"]:
				eats.append(o)
		if not eats.is_empty():
			var o: Vector2i = eats[_rng.randi() % eats.size()]
			var f: Vector2i = map._known[o][1]
			var at := Vector2(o) + Vector2(f) - Vector2(0.4, 0.6)
			_mice.append({"from": at, "to": at + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.4, 1.2)), "t": 0.0})


func _tick_birds(delta: float, map, day: bool) -> void:
	if not has("birds"):
		return
	_birds_at -= delta
	if _birds.is_empty() and _birds_at <= 0.0 and day:
		_birds_at = _rng.randf_range(40.0, 95.0)
		var left := _rng.randf() < 0.5
		var y := _rng.randf_range(0.1, 0.6)
		_birds = {"from": Vector2(-0.1 if left else 1.1, y), "to": Vector2(1.1 if left else -0.1, y + _rng.randf_range(-0.2, 0.25)), "t": 0.0, "mirror": left}
		map._play("birds", -18.0)
	if not _birds.is_empty():
		_birds["t"] = float(_birds["t"]) + delta / 7.0
		if float(_birds["t"]) >= 1.0:
			_birds = {}


## Drawn among the map's living things: `mini_h` is how tall a guest is now.
func draw(cv: CanvasItem, map, origin: Vector2, tile_w: float, tile_h: float, mini_h: int) -> void:
	var step := floorf(_t * 12.0)
	# Glints on the water.
	for g in _glints:
		var f := 4 + mini(3, int(float(g["t"]) / 0.5 * 4.0))
		var tex := _frame(map, "lake_%d" % f, maxi(3, int(mini_h * 0.3)))
		if tex != null:
			var p: Vector2 = map._cell_to_iso_f(g["cell"], origin, tile_w, tile_h)
			cv.draw_texture(tex, (p - tex.get_size() * 0.5).floor())
	for d in _ducks:
		var dip := float(d["dip"]) > 0.0
		var f := 3 if dip else int(step / 4.0) % 3
		_put(cv, map, "lake_%d" % f, d["cell"], origin, tile_w, tile_h, maxi(4, int(mini_h * 0.35)), bool(d.get("mirror", false)))
	if not _dog.is_empty():
		var f := 0
		match str(_dog["state"]):
			"run":
				f = int(step / 2.0) % 4
			"sniff":
				f = 4 + int(step / 4.0) % 2
			"sit":
				f = 6
			"bark":
				f = 7 if int(step / 3.0) % 2 == 0 else 6
		_put(cv, map, "dog_%d" % f, _dog["cell"], origin, tile_w, tile_h, maxi(5, int(mini_h * 0.45)), bool(_dog["mirror"]))
	for m in _mice:
		var k := clampf(float(m["t"]) / 1.2, 0.0, 2.0)
		var at: Vector2 = (m["from"] as Vector2).lerp(m["to"], k if k <= 1.0 else 2.0 - k)
		_put(cv, map, "bugs_%d" % (2 + int(step / 2.0) % 3), at, origin, tile_w, tile_h, maxi(3, int(mini_h * 0.16)), k > 1.0)
	# Moths round the lit lamps, after dusk.
	if map._night > 0.15 and has("bugs"):
		for l in map._lights:
			var c: Vector2 = map._s2d(l[0])
			for i in 2:
				var a := floorf(_t * 6.0) / 6.0 * (2.2 + float(i)) + float(i) * 3.0 + c.x
				var p := c + Vector2(cos(a) * tile_h * 0.35, -tile_h * (0.9 + 0.15 * sin(a * 1.7)) + sin(a) * tile_h * 0.15)
				var tex := _frame(map, "bugs_%d" % (int(step / 2.0 + float(i)) % 2), maxi(3, int(mini_h * 0.14)))
				if tex != null:
					cv.draw_texture(tex, (p - tex.get_size() * 0.5).floor(), Color(1, 1, 1, clampf(map._night * 1.5, 0.0, 1.0)))
	# Ants by the picnic tables, close enough to see them.
	if mini_h >= 28 and has("bugs"):
		for o in map._known:
			if str(map._known[o][0]) == "picnic_table":
				_put(cv, map, "bugs_%d" % (5 + int(step / 3.0) % 3), Vector2(o) + Vector2(0.35, 0.3), origin, tile_w, tile_h, maxi(3, int(mini_h * 0.18)), false)


## Birds over everything (they fly over the map, not on it).
func draw_sky(cv: CanvasItem, map, size: Vector2, mini_h: int) -> void:
	if _birds.is_empty():
		return
	var k := float(_birds["t"])
	var p: Vector2 = (_birds["from"] as Vector2).lerp(_birds["to"], k) * size
	var tex := _frame(map, "birds_%d" % (int(floorf(_t * 10.0)) % 8), maxi(8, int(mini_h * 0.7)))
	if tex == null:
		return
	if bool(_birds["mirror"]):
		cv.draw_set_transform((p - tex.get_size() * 0.5).floor() + Vector2(tex.get_width(), 0), 0.0, Vector2(-1, 1))
		cv.draw_texture(tex, Vector2.ZERO)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		cv.draw_texture(tex, (p - tex.get_size() * 0.5).floor())


func _put(cv: CanvasItem, map, key: String, cell: Vector2, origin: Vector2, tile_w: float, tile_h: float, h: int, mirror: bool) -> void:
	var tex := _frame(map, key, h)
	if tex == null:
		return
	var foot: Vector2 = map._cell_to_iso_f(cell, origin, tile_w, tile_h)
	var at := (foot - Vector2(tex.get_width() * 0.5, tex.get_height())).floor()
	if mirror:
		cv.draw_set_transform(at + Vector2(tex.get_width(), 0), 0.0, Vector2(-1, 1))
		cv.draw_texture(tex, Vector2.ZERO)
		cv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		cv.draw_texture(tex, at)
