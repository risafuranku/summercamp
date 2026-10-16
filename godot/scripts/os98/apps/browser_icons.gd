extends RefCounted

## Beeternet Explorer's toolbar icons, painted at 22 px the way IE4's were: in colour
## under the mouse, grey otherwise (the "cool" toolbar). Generated once, cached.

const S := 22
const OUT := Color8(20, 20, 20)

static var _cache: Dictionary = {}


static func get_icon(id: String, color := true) -> Texture2D:
	var key := "%s|%s" % [id, color]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"back":
			_arrow(img, false)
		"forward":
			_arrow(img, true)
		"stop":
			_stop(img)
		"refresh":
			_refresh(img)
		"home":
			_home(img)
		"search":
			_search(img)
		"favorites":
			_star(img)
		"history":
			_clock(img)
		"mail":
			_mail(img)
		"print":
			_printer(img)
		"page":
			_page(img)
	if not color:
		for y in S:
			for x in S:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
					l = 0.35 + l * 0.55
					img.set_pixel(x, y, Color(l, l, l, c.a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _poly(img: Image, pts: PackedVector2Array, fill: Color, outline := true) -> void:
	for y in S:
		for x in S:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, fill)
	if outline:
		for y in S:
			for x in S:
				if img.get_pixel(x, y).a > 0.0 and img.get_pixel(x, y) == fill:
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nx: int = x + d.x
						var ny: int = y + d.y
						if nx < 0 or ny < 0 or nx >= S or ny >= S or not Geometry2D.is_point_in_polygon(Vector2(nx + 0.5, ny + 0.5), pts):
							img.set_pixel(x, y, OUT)
							break


static func _disc(img: Image, c: Vector2, r: float, fill: Color, ring := 0.0, ring_col := OUT) -> void:
	for y in S:
		for x in S:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, ring_col if (ring > 0.0 and d > r - ring) else fill)


static func _rect(img: Image, r: Rect2i, fill: Color, outline := true) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var edge := outline and (x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1)
			img.set_pixel(x, y, OUT if edge else fill)


static func _arrow(img: Image, right: bool) -> void:
	var p := PackedVector2Array([Vector2(2, 11), Vector2(11, 2), Vector2(11, 7), Vector2(20, 7), Vector2(20, 15), Vector2(11, 15), Vector2(11, 20)])
	if right:
		for i in p.size():
			p[i] = Vector2(S - p[i].x, p[i].y)
	_poly(img, p, Color8(40, 170, 60))
	# A highlight along the top.
	for x in range(5, 18):
		var y := 8
		if img.get_pixel(x, y) == Color8(40, 170, 60):
			img.set_pixel(x, y, Color8(150, 230, 140))


static func _stop(img: Image) -> void:
	var p := PackedVector2Array()
	for i in 8:
		var a := PI / 8.0 + i * TAU / 8.0
		p.append(Vector2(11, 11) + Vector2(cos(a), sin(a)) * 10.0)
	_poly(img, p, Color8(210, 30, 30))
	for k in range(-4, 5):
		for t in [-1, 0]:
			img.set_pixel(11 + k + t, 11 + k, Color.WHITE)
			img.set_pixel(11 + k + t, 11 - k, Color.WHITE)


static func _refresh(img: Image) -> void:
	for y in S:
		for x in S:
			var v := Vector2(x + 0.5, y + 0.5) - Vector2(11, 11)
			var d := v.length()
			var a := atan2(v.y, v.x)
			var gap := (a > -0.4 and a < 0.4) or (a > PI - 0.4 or a < -PI + 0.4)
			if d > 5.0 and d < 9.0 and not gap:
				img.set_pixel(x, y, OUT if (d < 6.0 or d > 8.0) else Color8(40, 170, 60))
	_poly(img, PackedVector2Array([Vector2(16, 9), Vector2(22, 9), Vector2(19, 14)]), Color8(40, 170, 60))
	_poly(img, PackedVector2Array([Vector2(0, 13), Vector2(6, 13), Vector2(3, 8)]), Color8(40, 170, 60))


static func _home(img: Image) -> void:
	_rect(img, Rect2i(5, 10, 13, 10), Color8(240, 220, 170))
	_poly(img, PackedVector2Array([Vector2(1, 11), Vector2(11, 2), Vector2(21, 11)]), Color8(200, 40, 30))
	_rect(img, Rect2i(9, 13, 5, 7), Color8(120, 70, 30))
	_rect(img, Rect2i(15, 4, 3, 5), Color8(150, 150, 150))


static func _search(img: Image) -> void:
	_disc(img, Vector2(9, 9), 7.0, Color8(170, 210, 255), 2.0)
	for k in 6:
		_rect(img, Rect2i(13 + k, 13 + k, 3, 3), Color8(120, 80, 40), false)


static func _star(img: Image) -> void:
	var p := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var r := 10.0 if i % 2 == 0 else 4.2
		p.append(Vector2(11, 12) + Vector2(cos(a), sin(a)) * r)
	_poly(img, p, Color8(255, 210, 30))


static func _clock(img: Image) -> void:
	_disc(img, Vector2(11, 11), 10.0, Color.WHITE, 2.0, Color8(30, 60, 180))
	for y in range(5, 12):
		img.set_pixel(11, y, OUT)
	for x in range(11, 16):
		img.set_pixel(x, 11, OUT)


static func _mail(img: Image) -> void:
	_rect(img, Rect2i(2, 5, 18, 13), Color.WHITE)
	for k in 9:
		img.set_pixel(2 + k, 5 + k * 6 / 9, OUT)
		img.set_pixel(19 - k, 5 + k * 6 / 9, OUT)


static func _printer(img: Image) -> void:
	_rect(img, Rect2i(6, 2, 10, 8), Color.WHITE)
	_rect(img, Rect2i(2, 8, 18, 9), Color8(180, 180, 180))
	_rect(img, Rect2i(6, 14, 10, 6), Color.WHITE)
	img.set_pixel(16, 10, Color8(40, 200, 60))


static func _page(img: Image) -> void:
	_poly(img, PackedVector2Array([Vector2(4, 1), Vector2(14, 1), Vector2(18, 5), Vector2(18, 21), Vector2(4, 21)]), Color.WHITE)
	for y in [7, 10, 13, 16]:
		for x in range(7, 15):
			img.set_pixel(x, y, Color8(40, 80, 200))
