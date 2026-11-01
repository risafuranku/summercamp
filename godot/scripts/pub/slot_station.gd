extends "res://scripts/pub/pub_station.gd"

## LUCKY 7 (the brief of 20. 10.: the pub's fun), the old one-armed bandit in the corner by
## the dartboard: worked standing at it (its face is the station's wall, pub_layout
## SURFACES "slot"; the cabinet is the room's own cutout, camp/pub_slot.png).
##   the lever   hold it and pull down: the three reels spin and stop one after another
##               (pub_fun.spin: the same game on every machine); a line pays out into the
##               tray with a bell
## It is the camp's machine: what a warden puts in comes back out of the same camp, so a
## warden plays for the fun of it, but three sevens and the whole pub cheers (their mood).
## The guests feed it too (taproom.gd, "fun"): the reels spin for them while you watch,
## and what they leave in it is the pub's takings.

const FUN := preload("res://core/systems/pub_fun.gd")
## The lever's grip on the machine's face (design px over pub_layout SURFACES["slot"],
## 0.96 m across), the tray where a win pops.
const LEVER := Rect2(548, 10, 84, 236)
const TRAY_AT := Vector2(320, 330)
## The reels and the lever are drawn into the machine's own picture (camp/pub_slot.png,
## 74 x 136, a pixel a centimetre), not stood in front of it: the cabinet is a cutout that
## turns to face you, and the three tiles and the lever stood still beside it, off its
## window (playtest 1. 11.: "the symbols show in little squares off the machine").
## Each window shows its drum: the symbols one under another, rolling down past the
## middle and settling there, the drum's top and bottom in shadow.
const REEL_X := [16, 31, 45]
const REEL_Y := 42
const REEL_W := 13
const REEL_H := 22
## A symbol's height on the drum (the reel_*.png pictures are 14 px).
const CELL := 14
## Rows the drum turns a step while it spins (twelve steps a second; not a multiple of
## CELL, or the symbols seem to stand still).
const SPIN_PX := 9
const STEPS := 12.0
## The picture widened on its right for the lever (camp/pub_slot.png ends at the cabinet).
const FACE_W := 82
const LEVER_X := 75
## The lever's foot (picture row) and how far down it goes pulled.
const LEVER_FOOT := 56
const LEVER_DROP := 13
## The drum's shadow by row (top, bottom) and its edges.
const SHADE_TOP := [0.5, 0.68, 0.84, 0.94]
const SHADE_BOTTOM := [0.94, 0.84, 0.7, 0.55, 0.42]
const EDGE := 0.82
## Pulled this far down the screen (a share of the view's height) the lever goes.
const PULL := 0.12

var _face_base: Image
var _strip: Image
var _lever_img: Image
var _face_tex: ImageTexture
var _face_drawn := ""
var _pull := 0.0
var _grab_y := -1.0
## The spin shown: its reels, when it started (seconds here), who played.
var _spin: Dictionary = {}
var _spin_t := 99.0
var _stopped := 0
var _paid := false
var _rng := RandomNumberGenerator.new()


func has_rail() -> bool:
	return false


func _build() -> void:
	super._build()
	_rng.randomize()
	_take_machine()


## The room's cutout of the cabinet (pub_layout "SlotMachine") gets a picture of its own,
## the reels and the lever drawn in.
func _take_machine() -> void:
	var mesh: MeshInstance3D = null
	var n: Node = get_parent()
	while n != null and not (n is Viewport):
		mesh = n.find_child("SlotMachine", true, false) as MeshInstance3D
		if mesh != null:
			break
		n = n.get_parent()
	var mat := mesh.material_override as StandardMaterial3D if mesh != null else null
	if mat == null or mat.albedo_texture == null:
		return
	var src: Image = mat.albedo_texture.get_image()
	if src == null:
		return
	src = src.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	_face_base = Image.create(FACE_W, src.get_height(), false, Image.FORMAT_RGBA8)
	_face_base.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
	# The drum: every symbol once, one under another (FUN.SYMBOLS' order).
	_strip = Image.create(REEL_W, CELL * FUN.SYMBOLS.size(), false, Image.FORMAT_RGBA8)
	for k in FUN.SYMBOLS.size():
		var sym := _rgba(PUB_TEX + "reel_%s.png" % FUN.SYMBOLS[k])
		if sym != null:
			_strip.blit_rect(sym, Rect2i(0, 0, REEL_W, CELL), Vector2i(0, k * CELL))
	_lever_img = _rgba(PUB_TEX + "slot_lever.png")
	_face_tex = ImageTexture.create_from_image(_face_base)
	mat.albedo_texture = _face_tex
	# Wider by the lever, on its right: the cabinet stays where it stood.
	var q := mesh.mesh as QuadMesh
	if q != null:
		var k := q.size.x / float(src.get_width())
		var wide := QuadMesh.new()
		wide.size = Vector2(k * FACE_W, q.size.y)
		wide.center_offset = q.center_offset + Vector3(k * float(FACE_W - src.get_width()) * 0.5, 0, 0)
		mesh.mesh = wide
	_face_drawn = ""


func _rgba(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var img: Image = (load(path) as Texture2D).get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## The reels as the spin has them (stepping twelve a second; the last game's symbols when
## nothing spins) and the lever down while pulled, drawn into the machine.
func _show() -> void:
	if taproom == null or building_key == "":
		return
	var f: Dictionary = taproom.fun(building_key)
	var s: Dictionary = f.get("slot", {})
	if str(s.get("id", "")) != str(_spin.get("id", "")):
		_spin = s
		_spin_t = 0.0 if not s.is_empty() else 99.0
		_stopped = 0
		_paid = false
	if _face_tex == null:
		return
	var reels: Array = FUN.spin(int(_spin.get("seed", 0))) if not _spin.is_empty() else ["seven", "seven", "seven"]
	var drum := CELL * FUN.SYMBOLS.size()
	var rows: Array[int] = []
	var blur: Array[bool] = []
	for i in 3:
		var stop_at := FUN.SPIN_SEC + FUN.STOP_GAP * float(i)
		# The symbol's middle on the window's middle.
		var top: int = FUN.SYMBOLS.find(str(reels[i])) * CELL + CELL / 2 - REEL_H / 2
		var fast := false
		if _spin_t < stop_at:
			# Rolling down onto where it stops: so many steps still to go, SPIN_PX a step.
			var left := ceili((stop_at - _spin_t) * STEPS)
			top += left * SPIN_PX
			fast = left > 2
		elif _spin_t < stop_at + 1.0 / STEPS:
			# A row or two past it, and back (the drum's catch).
			top -= 2
		rows.append(posmod(top, drum))
		blur.append(fast)
	# The lever down while pulled, in three steps (moved down its slot; never turned).
	var down := roundi(floorf(clampf(_pull, 0.0, 1.0) * 3.0) / 3.0 * float(LEVER_DROP))
	_paint_face(rows, blur, down)


func _paint_face(rows: Array[int], blur: Array[bool], lever_down: int) -> void:
	var sig := "%s|%s|%d" % [str(rows), str(blur), lever_down]
	if sig == _face_drawn:
		return
	_face_drawn = sig
	var img := _face_base.duplicate() as Image
	var drum := _strip.get_height()
	for i in 3:
		for y in REEL_H:
			var shade := 1.0
			if y < SHADE_TOP.size():
				shade = SHADE_TOP[y]
			elif y >= REEL_H - SHADE_BOTTOM.size():
				shade = SHADE_BOTTOM[y - (REEL_H - SHADE_BOTTOM.size())]
			for x in REEL_W:
				var c := _strip.get_pixel(x, posmod(rows[i] + y, drum))
				if blur[i]:
					# Spinning fast: the symbols smeared down the drum.
					c = c.lerp(_strip.get_pixel(x, posmod(rows[i] + y - 4, drum)), 0.4)
					c = c.lerp(_strip.get_pixel(x, posmod(rows[i] + y - 8, drum)), 0.25)
				var k := shade * (EDGE if x == 0 or x == REEL_W - 1 else 1.0)
				img.set_pixel(REEL_X[i] + x, REEL_Y + y, Color(c.r * k, c.g * k, c.b * k, 1.0))
	if _lever_img != null:
		var at := Vector2i(LEVER_X, LEVER_FOOT - _lever_img.get_height() + lever_down)
		img.blend_rect(_lever_img, Rect2i(Vector2i.ZERO, _lever_img.get_size()), at)
	_face_tex.update(img)


func _tick(delta: float) -> void:
	_spin_tick(delta)
	if _held != "lever":
		_pull = move_toward(_pull, 0.0, delta * 6.0)


func _process(delta: float) -> void:
	super._process(delta)
	# The reels run whether anybody stands at it (the guests' games too).
	if not is_open():
		_spin_tick(delta)


func _spin_tick(delta: float) -> void:
	if _spin.is_empty():
		return
	var was := _spin_t
	_spin_t += delta
	for i in 3:
		var stop_at := FUN.SPIN_SEC + FUN.STOP_GAP * float(i)
		if was < stop_at and _spin_t >= stop_at:
			_stopped = i + 1
			if is_visible_in_tree():
				sfx("slot_stop", -10.0, 1.0 + 0.05 * i)
	if not _paid and _spin_t >= FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.1:
		_paid = true
		var win := FUN.payout(FUN.spin(int(_spin.get("seed", 0))))
		if win > 0 and is_visible_in_tree():
			sfx("slot_win", -8.0)
			if is_open():
				pop("$%d" % win, TRAY_AT + Vector2(0, -30), RETRO_UI.C_AMBER_LIGHT, true)
		if is_open() and str(_spin.get("who", "")) == "you":
			taproom.slot_done(building_key, _spin)


func _spots() -> Array:
	var spinning := not _spin.is_empty() and _spin_t < FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.2
	if spinning:
		return [{"id": "lever", "rect": LEVER, "verb": "The reels are going"}]
	return [{"id": "lever", "rect": LEVER, "verb": "Hold the lever and pull it down: a coin's game"}]


func hand_tool() -> String:
	return "open"


func _press(id: String) -> void:
	if id == "lever":
		_grab_y = _vp_mouse.y


func _drag(_at: Vector2) -> void:
	if _held != "lever" or _grab_y < 0.0 or _vp_mouse.y < 0.0:
		return
	var full := 36.0
	if camera != null and is_instance_valid(camera):
		full = maxf(12.0, float(camera.get_viewport().size.y) * PULL)
	var was := _pull
	_pull = clampf((_vp_mouse.y - _grab_y) / full, 0.0, 1.0)
	if _pull >= 1.0 and was < 1.0:
		_pulled()


func _release(_id: String) -> void:
	_grab_y = -1.0


## The lever all the way down: a game, if the reels are still.
func _pulled() -> void:
	if not _spin.is_empty() and _spin_t < FUN.SPIN_SEC + FUN.STOP_GAP * 2.0 + 0.2:
		return
	sfx("slot_lever", -8.0)
	sfx("slot_reels", -10.0)
	taproom.slot_play(building_key, _rng.randi(), "you")


func bar_text() -> String:
	return "LUCKY 7   777 PAYS %d" % int(FUN.PAY_THREE["seven"])


# ── debug (tools/pub_check.gd, tools/pub_shots.gd) ───────────────────────────

func debug_click(id: String) -> void:
	_press(id)
	_release(id)


func debug_pull() -> void:
	_pull = 1.0
	_pulled()


## The spin shown as if `seconds` had passed.
func debug_run(seconds: float) -> void:
	_spin_tick(seconds)
