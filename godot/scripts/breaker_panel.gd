extends CanvasLayer

## The distribution board at the generator: a night job (scripts/night_jobs.gd).
##
## The main breaker has tripped and the camp is dark. One of the six circuits has a
## fault: whenever the main is on with that circuit up, the main throws itself again
## (a crack, a flash, dark). The way to find it is the electrician's way, and Vera's
## note taped inside the door says it: everything down, main up, then the circuits one
## at a time; the one that throws it stays down. Power is back when the main holds
## with the other five up. The faulty circuit stays off for the rest of the night.
##
## Drawn in virtual pixels on an integer scale like the HUD; mouse to flip, Esc to
## leave (the job stays open).
##
## Some nights the family's boy is in here with you, and the board is his game (below,
## "the boy"; DESIGN §5a.2).

signal fixed(fault_index: int)
signal closed

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const NIGHTMARE_FX = preload("res://scripts/night/nightmare_fx.gd")
const LANG = preload("res://scripts/lang.gd")
const SFX := "res://assets/sfx/power/"
const CIRCUITS := ["LAMPS N", "LAMPS S", "OFFICE", "FOOD", "WASH", "PUMP"]
## Two-line labels under the switches (the one-line ones ran into each other).
const LABELS := [["LAMPS", "NORTH"], ["LAMPS", "SOUTH"], ["OFFICE", ""], ["FOOD", ""], ["WASH", "BLOCK"], ["WATER", "PUMP"]]
const CIRCUIT_NAMES := ["LAMPS NORTH", "LAMPS SOUTH", "OFFICE", "FOOD", "WASH BLOCK", "PUMP"]
const TRIP_DELAY := 0.45
const HOLD_TO_FIX := 1.4

var _board: Control
var _scale := 3
var _main_on := false
var _up: Array[bool] = [true, true, true, true, true, true]
var _fault := 0
var _trip_timer := -1.0
var _hold_timer := -1.0
var _flash := 0.0
var _done := false
var _done_t := 0.0
var _status := tr("The main has tripped. The camp is dark.")
var _hum: AudioStreamPlayer
var _one: AudioStreamPlayer
var _hit_main := Rect2()
var _hit_breakers: Array[Rect2] = []
var _hover := -2            # -1 the main, 0..5 a circuit, -2 nothing
var _lever := 0.0           # 0 down .. 1 up, eased toward _main_on
var _needle := 0.0          # ammeter, 0..1 (1 = red, it is about to throw)
var _trips := 0             # how often it has thrown tonight: scorch shows on the bad one
var _sparks: Array = []     # {p: Vector2 (virtual px), v: Vector2, t: float}
var _mouse := Vector2.ZERO
var _torch: Texture2D


func _ready() -> void:
	layer = 90
	add_to_group("closeup")  # the hands are on it (pockets.gd)
	visible = false
	_hum = AudioStreamPlayer.new()
	# The board's hum: a low background, not a buzz over everything (playtest 2026-10-17:
	# the old loop played at about the loudness of the speech).
	_hum.volume_db = -26.0
	add_child(_hum)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Loaded here, not in the draw (a texture first loaded inside a draw call comes out white).
	if ResourceLoader.exists(PIC):
		_pic = load(PIC)
	_board.draw.connect(_draw_board)
	add_child(_board)


func is_open() -> bool:
	return visible


func open(fault_index: int, boy_tier := 0) -> void:
	_boy_start(boy_tier)
	_fault = clampi(fault_index, 0, CIRCUITS.size() - 1)
	_main_on = false
	for i in _up.size():
		_up[i] = true
	_trip_timer = -1.0
	_hold_timer = -1.0
	_done = false
	_trips = 0
	_sparks.clear()
	_lever = 0.0
	_needle = 0.0
	_status = tr("The main has tripped. The camp is dark.")
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_board.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_hum.stop()
	closed.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	_scale = RETRO_UI.ui_scale(get_viewport().get_visible_rect().size.y)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	if _done:
		_done_t += delta
	_boy_tick(delta)
	_lever = move_toward(_lever, 1.0 if _main_on else 0.0, delta * 7.0)
	# The ammeter: load from the circuits that are up; the bad one pins it before it throws.
	var load := float(_count_up()) / float(CIRCUITS.size()) * 0.55 if _main_on else 0.0
	if _main_on and _up[_fault] and not _done:
		load = 0.75 + 0.25 * (1.0 - clampf(_trip_timer / TRIP_DELAY, 0.0, 1.0))
	_needle = lerpf(_needle, load + (randf_range(-0.02, 0.02) if _main_on else 0.0), clampf(delta * 9.0, 0.0, 1.0))
	for sp in _sparks:
		sp["t"] = float(sp["t"]) - delta
		sp["v"] = Vector2(sp["v"]) + Vector2(0, 160.0) * delta
		sp["p"] = Vector2(sp["p"]) + Vector2(sp["v"]) * delta
	_sparks = _sparks.filter(func(sp): return float(sp["t"]) > 0.0)
	if _main_on and _up[_fault] and not _done:
		if _trip_timer < 0.0:
			_trip_timer = TRIP_DELAY
		_trip_timer -= delta
		if _trip_timer <= 0.0:
			_trip()
	else:
		_trip_timer = -1.0
	if _main_on and not _up[_fault] and _count_up() == CIRCUITS.size() - 1 and not _done:
		if _hold_timer < 0.0:
			_hold_timer = HOLD_TO_FIX
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_finish()
	else:
		_hold_timer = -1.0
	_board.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_S):
		get_viewport().set_input_as_handled()
		close()
		return
	if _boy_sees(event):
		get_viewport().set_input_as_handled()
		_boy_catch()
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_hover = -2
		if _hit_main.has_point(_mouse):
			_hover = -1
		for i in _hit_breakers.size():
			if _hit_breakers[i].has_point(_mouse):
				_hover = i
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _done:
		var p: Vector2 = event.position
		if _hit_main.has_point(p):
			_main_on = not _main_on
			_play("main_switch.mp3", -2.0)
			if _main_on:
				_hum.stream = load(SFX + "board_hum.mp3") if ResourceLoader.exists(SFX + "board_hum.mp3") else load(SFX + "power_hum.mp3")
				if _hum.stream is AudioStreamMP3:
					(_hum.stream as AudioStreamMP3).loop = true
				_hum.play()
				_status = tr("Main on...")
			else:
				_hum.stop()
				_status = tr("Main off.")
		else:
			for i in _hit_breakers.size():
				if _hit_breakers[i].has_point(p):
					_up[i] = not _up[i]
					# A proper clack you can hear (the old click was nearly silent).
					_play("board_toggle.mp3", -3.0, randf_range(0.94, 1.06) * (1.0 if _up[i] else 0.9))
					break
		get_viewport().set_input_as_handled()


func _trip() -> void:
	_main_on = false
	_trip_timer = -1.0
	_flash = 1.0
	_hum.stop()
	_play("main_trip.mp3", -8.0)
	_trips += 1
	for k in 14:
		_sparks.append({"p": Vector2(25, 50), "v": Vector2(randf_range(-90, 90), randf_range(-140, -30)), "t": randf_range(0.3, 0.8)})
	_status = tr("It threw the main again. Something on one of these circuits.") if _trips < 3 else tr("It threw again. Something smells burnt in here.")


func _finish() -> void:
	_done = true
	_done_t = 0.0
	_play("board_restored.mp3", 1.0)
	_status = LANG.f("Done. The main holds. %s stays off until Novotny has looked at it.", tr(CIRCUIT_NAMES[_fault]))
	fixed.emit(_fault)
	get_tree().create_timer(3.4).timeout.connect(close)


func _count_up() -> int:
	var n := 0
	for i in _up.size():
		if _up[i]:
			n += 1
	return n


func _play(file: String, db := 0.0, pitch := 1.0) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.pitch_scale = pitch
		_one.play()


## Done, and closed: whether the job was finished (main tells the HUD).
func was_fixed() -> bool:
	return _done



# ── the boy: "Cukr, kava, limonada, caj, rum ... BUM!" ────────────────────────
#
# The family's boy (scripts/enemies/boy_brain.gd) is in the switch room with you, behind
# you, his face to the wall, and it is the Czech red light, green light: while he says
# the words you may work the board; at BUM he turns round and looks, and nothing of yours
# may move (the mouse, a click) till he turns back. Caught: his face, the hit, and every
# switch thrown down again; he says so, and it starts over. His face is in the ammeter's
# glass while he looks. Medium he says them faster and unevenly, heavy he skips to BUM
# now and then and looks longer, and pulls a switch down behind your back between rounds.

const BOY_DIR := "res://assets/sfx/npc/boy/"
const BOY_FACE := "res://assets/textury/npc/boy_face.png"
const BOY_FRONT := "res://assets/textury/npc/boy_t1.png"
const BOY_PITCH := 1.22
## By his tier (1 light .. 3 heavy): the gap between words (s, from, to), the chance he
## skips to BUM after the second or third word, how long he looks, how hard he hits, the
## chance he pulls a switch down between rounds.
const BOY_WORD_GAP := [Vector2.ZERO, Vector2(0.75, 0.8), Vector2(0.45, 0.9), Vector2(0.3, 0.85)]
const BOY_SKIP := [0.0, 0.0, 0.1, 0.25]
const BOY_STARE := [0.0, 1.8, 2.3, 2.9]
const BOY_HIT := [0, 14, 22, 32]
const BOY_PULL := [0.0, 0.0, 0.3, 0.55]
## How far the pointer may drift while he looks (virtual px: a hand is never quite still).
const BOY_STILL_PX := 2.5

## His tier tonight at this board (0: nobody here).
var boy := 0
## How many times he caught you (for the checks), and what he is doing now: "wait",
## "say" (a word), "look" (after BUM).
var boy_caught := 0
var boy_phase := "wait"
var _boy_t := 0.0
var _boy_word := 0
var _boy_ear: AudioStreamPlayer
var _boy_face: Texture2D
var _boy_front: Texture2D
var _boy_still_from := Vector2.INF
## His face over the board when he catches you (the night's own screen is under this one).
var _boy_face_t := 0.0


func _boy_start(tier: int) -> void:
	boy = tier
	boy_caught = 0
	boy_phase = "wait"
	_boy_t = 2.0
	_boy_word = 0
	if tier <= 0:
		return
	if _boy_ear == null:
		_boy_ear = AudioStreamPlayer.new()
		add_child(_boy_ear)
	if _boy_face == null and ResourceLoader.exists(BOY_FACE):
		_boy_face = load(BOY_FACE)
	if _boy_front == null and ResourceLoader.exists(BOY_FRONT):
		_boy_front = load(BOY_FRONT)
	# The night's screen made now (made at the catch, its ringing would come a frame late).
	_night_fx()


func _boy_tick(delta: float) -> void:
	_boy_face_t = maxf(0.0, _boy_face_t - delta)
	if boy <= 0 or _done:
		return
	_boy_t -= delta
	match boy_phase:
		"wait":
			if _boy_t <= 0.0:
				boy_phase = "say"
				_boy_word = 0
				_boy_t = 0.0
		"say":
			if _boy_t > 0.0:
				return
			_boy_word += 1
			var skip: bool = _boy_word >= 3 and randf() < float(BOY_SKIP[boy])
			if _boy_word > 5 or skip:
				_boy_say("bum", -2.0)
				boy_phase = "look"
				_boy_t = BOY_STARE[boy]
				_boy_still_from = _mouse
				return
			_boy_say("chant_%d" % _boy_word, -5.0)
			var gap: Vector2 = BOY_WORD_GAP[boy]
			_boy_t = randf_range(gap.x, gap.y)
		"look":
			if _boy_t <= 0.0:
				boy_phase = "wait"
				_boy_t = randf_range(1.0, 2.2)
				# Behind your back between rounds: a switch of yours down again.
				if randf() < BOY_PULL[boy]:
					var ups: Array = []
					for i in _up.size():
						if _up[i] and i != _fault:
							ups.append(i)
					if not ups.is_empty():
						_up[ups[randi() % ups.size()]] = false
						_play("board_toggle.mp3", -9.0, 0.85)
						_boy_sfx(BOY_DIR + "giggle_2.mp3", -12.0, 1.1)


## While he looks: the board's input is his to see.
func _boy_sees(event: InputEvent) -> bool:
	if boy <= 0 or boy_phase != "look" or _done:
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		return true
	if event is InputEventMouseMotion and _boy_still_from != Vector2.INF:
		return (event as InputEventMouseMotion).position.distance_to(_boy_still_from) > BOY_STILL_PX * float(_scale)
	return false


## Caught moving: his face over the board, the shriek, the hit; every switch down, the
## main off; "you moved", and again.
func _boy_catch() -> void:
	boy_caught += 1
	boy_phase = "wait"
	_boy_t = 3.2
	_main_on = false
	_hum.stop()
	for i in _up.size():
		_up[i] = false
	_flash = 1.0
	_boy_face_t = 0.85
	var fx = _night_fx()
	_boy_sfx(BOY_DIR + "shriek.mp3", 2.0, 1.0)
	if fx != null:
		fx.glitch(0.9, 0.6)
		fx.red_flash(0.5)
		fx.tinnitus(2.0)
	var main := get_parent()
	if main != null and main.has_method("damage_player"):
		main.damage_player(BOY_HIT[boy])
	get_tree().create_timer(1.6).timeout.connect(func():
		if visible and boy > 0:
			_boy_say("moved_1", -4.0))
	get_tree().create_timer(2.8).timeout.connect(func():
		if visible and boy > 0:
			_boy_say("again", -6.0))


func _night_fx():
	var main := get_parent()
	var world = main.get("_world_3d") if main != null else null
	return NIGHTMARE_FX.get_for(world) if world != null else null


func _boy_say(id: String, db: float) -> void:
	_boy_sfx(BOY_DIR + id + ".mp3", db, BOY_PITCH)


func _boy_sfx(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := _boy_ear
	if p == null or p.playing:
		p = AudioStreamPlayer.new()
		add_child(p)
		p.finished.connect(p.queue_free)
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## His face in the ammeter's glass while he looks (you see him behind you in it).
func _draw_boy_reflection(o: Vector2, s: float) -> void:
	if boy <= 0 or boy_phase != "look" or _boy_front == null:
		return
	var h := 26.0
	var w := h * float(_boy_front.get_width()) / float(_boy_front.get_height())
	var at := o + (DIAL + Vector2(-w * 0.5 + 4.0, -h * 0.45)) * s
	_board.draw_texture_rect(_boy_front, Rect2(at, Vector2(w, h) * s), false, Color(0.5, 0.55, 0.6, 0.62))


## His face, all of the screen, shaking, in the world's game pixels and palette.
var _face_rect: TextureRect


func _draw_boy_face(screen: Vector2) -> void:
	if _boy_face_t <= 0.0 or _boy_face == null:
		if _face_rect != null:
			_face_rect.visible = false
		return
	if _face_rect == null:
		_face_rect = TextureRect.new()
		_face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_face_rect.material = NIGHTMARE_FX.retro_material()
		add_child(_face_rect)
	NIGHTMARE_FX.update_retro(screen.y)
	var side := minf(screen.x, screen.y) * (1.05 + 0.25 * (1.0 - _boy_face_t / 0.85))
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * screen.y * 0.012
	_board.draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.85))
	_face_rect.texture = _boy_face
	_face_rect.position = ((screen - Vector2(side, side)) * 0.5 + shake).floor()
	_face_rect.size = Vector2(side, side)
	_face_rect.visible = true


# ── drawing: the Grok picture of the board, the states painted onto it ───────

const PIC := "res://assets/textury/closeup/breaker.png"
const PIC_SIZE := Vector2(320, 240)
const STRIP := 30.0
## Where things are on the picture (px).
const TOGGLE_X := [113.0, 135.0, 157.5, 180.0, 202.0, 224.5]
const TOGGLE_Y := 115.0
const LED_Y := 108.0
const LABEL_Y := 144.0
const SHORT := ["L-N", "L-S", "OFC", "KIT", "WSH", "PMP"]
const LEVER_RECT := Rect2(46, 74, 34, 104)
const LEVER_COVER_SRC := Rect2(80, 74, 12, 104)
const LEVER_PIVOT := Vector2(65, 84)
const DIAL := Vector2(216, 63)
const NOTE_RECT := Rect2(281, 101, 30, 51)
const NOTE := "Vera's note, taped inside the door: \"main keeps jumping? all down, main up, then one at a time. the one that throws it stays down. - V.\""

var _pic: Texture2D


func _draw_board() -> void:
	var screen := _board.size
	var k := float(maxi(1, int(floor(minf(screen.x * 0.94 / PIC_SIZE.x, screen.y * 0.9 / (PIC_SIZE.y + STRIP))))))
	var origin := ((screen - Vector2(PIC_SIZE.x, PIC_SIZE.y + STRIP) * k) * 0.5).floor()
	var P := func(x: float, y: float) -> Vector2:
		return origin + Vector2(x, y) * k
	var R := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(origin + Vector2(x, y) * k, Vector2(w, h) * k)
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_board.draw_rect(R.call(-2, -2, PIC_SIZE.x + 4, PIC_SIZE.y + STRIP + 4), Color(0.05, 0.05, 0.04))
	if _pic != null:
		_board.draw_texture_rect(_pic, R.call(0, 0, PIC_SIZE.x, PIC_SIZE.y), false)

	# The main: the picture shows it down (off). Up, the painted lever is covered with
	# the housing beside it and the lever drawn swung up, in two steps.
	if _lever > 0.34 and _pic != null:
		_board.draw_texture_rect_region(_pic, R.call(LEVER_RECT.position.x, LEVER_RECT.position.y, LEVER_RECT.size.x, LEVER_RECT.size.y), LEVER_COVER_SRC)
		var up := 1.0 if _lever > 0.67 else 0.55
		var ang := lerpf(PI * 0.5, -PI * 0.58, up)
		var tip := LEVER_PIVOT + Vector2(cos(ang), sin(ang)) * 30.0
		var side := Vector2(-sin(ang), cos(ang)) * 4.5
		var poly := PackedVector2Array([P.call(LEVER_PIVOT.x + side.x, LEVER_PIVOT.y + side.y), P.call(LEVER_PIVOT.x - side.x, LEVER_PIVOT.y - side.y), P.call(tip.x - side.x * 0.8, tip.y - side.y * 0.8), P.call(tip.x + side.x * 0.8, tip.y + side.y * 0.8)])
		_board.draw_colored_polygon(poly, Color(0.55, 0.1, 0.07))
		_board.draw_line(P.call(LEVER_PIVOT.x - side.x * 0.4, LEVER_PIVOT.y - side.y * 0.4), P.call(tip.x - side.x * 0.4, tip.y - side.y * 0.4), Color(0.82, 0.3, 0.2), k)
		_board.draw_rect(R.call(LEVER_PIVOT.x - 4, LEVER_PIVOT.y - 3, 8, 6), Color(0.1, 0.1, 0.1))
	if _hover == -1:
		_board.draw_rect(R.call(LEVER_RECT.position.x - 1, LEVER_RECT.position.y - 1, LEVER_RECT.size.x + 2, LEVER_RECT.size.y + 2), Color(1.0, 0.85, 0.3, 0.8), false, k)
	_hit_main = R.call(LEVER_RECT.position.x, LEVER_RECT.position.y - 20, LEVER_RECT.size.x, LEVER_RECT.size.y + 20)

	# The six breakers: the toggle up or down, the lamp above, the label strip.
	_hit_breakers.clear()
	for i in CIRCUITS.size():
		var x: float = TOGGLE_X[i]
		var powered: bool = _main_on and _up[i]
		if i == _fault and _trips >= 3:
			_board.draw_rect(R.call(x - 10, 102, 20, 46), Color(0.1, 0.06, 0.02, 0.5))
		_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 15), Color(0.05, 0.05, 0.05))
		if _up[i]:
			_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 7), Color(0.58, 0.58, 0.55))
			_board.draw_rect(R.call(x - 3, TOGGLE_Y, 6, 1), Color(0.85, 0.85, 0.8))
		else:
			_board.draw_rect(R.call(x - 3, TOGGLE_Y + 8, 6, 7), Color(0.5, 0.12, 0.08))
			_board.draw_rect(R.call(x - 3, TOGGLE_Y + 8, 6, 1), Color(0.75, 0.3, 0.2))
		var led := Color(0.45, 1.0, 0.4) if powered else Color(0.12, 0.14, 0.1)
		_board.draw_rect(R.call(x - 1.5, LED_Y - 1.5, 3, 3), led)
		if powered:
			_board.draw_rect(R.call(x - 3, LED_Y - 3, 6, 6), Color(0.5, 1.0, 0.4, 0.22))
		var short := tr(SHORT[i])
		var lw: float = RETRO_UI.FONT_TEXT.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k)).x
		_board.draw_string(RETRO_UI.FONT_TEXT, (P.call(x, LABEL_Y) - Vector2(lw * 0.5, 0)).floor(), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k), Color(0.15, 0.13, 0.12))
		if _hover == i:
			_board.draw_rect(R.call(x - 9, 103, 18, 31), Color(1.0, 0.85, 0.3, 0.8), false, k)
		_hit_breakers.append(R.call(x - 9, 103, 18, 31))

	# The ammeter: a fresh dial face over the picture's, ticks green, amber, red.
	_board.draw_circle(P.call(DIAL.x, DIAL.y), 14.0 * k, Color(0.86, 0.82, 0.7))
	var pivot: Vector2 = P.call(DIAL.x, DIAL.y + 8)
	for t in 11:
		var a0 := PI + PI * float(t) / 10.0
		var col := Color(0.2, 0.5, 0.2) if t < 6 else (Color(0.8, 0.6, 0.1) if t < 8 else Color(0.8, 0.15, 0.1))
		_board.draw_line(pivot + Vector2(cos(a0), sin(a0)) * 10.0 * k, pivot + Vector2(cos(a0), sin(a0)) * 12.5 * k, col, k)
	var an := PI + PI * clampf(_needle, 0.0, 1.0)
	_board.draw_line(pivot, pivot + Vector2(cos(an), sin(an)) * 12.0 * k, Color(0.08, 0.08, 0.08), k)
	_board.draw_rect(Rect2(pivot - Vector2(k, k), Vector2(2, 2) * k), Color(0.1, 0.1, 0.1))

	# Vera's note: scribbles you can read by pointing at it.
	for li in 6:
		_board.draw_rect(R.call(NOTE_RECT.position.x + 4, NOTE_RECT.position.y + 8 + li * 6, NOTE_RECT.size.x - 8 - (li % 3) * 3, 1), Color(0.2, 0.18, 0.3, 0.7))
	var over_note: bool = R.call(NOTE_RECT.position.x, NOTE_RECT.position.y, NOTE_RECT.size.x, NOTE_RECT.size.y).has_point(_mouse)

	# The strip under the picture: what is happening, or the note when you point at it.
	_board.draw_rect(R.call(0, PIC_SIZE.y, PIC_SIZE.x, STRIP), Color(0.06, 0.05, 0.04))
	_board.draw_rect(R.call(0, PIC_SIZE.y, PIC_SIZE.x, 1), RETRO_UI.C_PLATE_LIGHT * Color(1, 1, 1, 0.5))
	var lines := _wrap(tr(NOTE) if over_note else _status, 74)
	for li in mini(lines.size(), 3):
		_board.draw_string(RETRO_UI.FONT_TEXT, P.call(6, PIC_SIZE.y + 10 + li * 8).floor(), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * int(k), RETRO_UI.C_BONE if over_note else Color(0.95, 0.85, 0.5))

	for sp in _sparks:
		var pp: Vector2 = P.call(LEVER_PIVOT.x + float(sp["p"].x) - 25.0, LEVER_PIVOT.y + float(sp["p"].y) - 50.0)
		_board.draw_rect(Rect2(pp, Vector2(k, k)), Color(1.0, 0.9, 0.5, clampf(float(sp["t"]) * 2.0, 0.0, 1.0)))

	# Torchlight: the box is lit where you point the torch, dark elsewhere.
	if not (_main_on and not _done) and _torch_texture() != null:
		var r := 120.0 * k
		var m := _mouse if _mouse != Vector2.ZERO else screen * 0.5
		var rect := Rect2(m - Vector2(r, r), Vector2(r, r) * 2.0)
		var dark := Color(0, 0, 0, 0.7)
		_board.draw_rect(Rect2(0, 0, screen.x, rect.position.y), dark)
		_board.draw_rect(Rect2(0, rect.end.y, screen.x, screen.y - rect.end.y), dark)
		_board.draw_rect(Rect2(0, rect.position.y, rect.position.x, rect.size.y), dark)
		_board.draw_rect(Rect2(rect.end.x, rect.position.y, screen.x - rect.end.x, rect.size.y), dark)
		_board.draw_texture_rect(_torch, rect, false, Color(1, 1, 1, 0.7))
	_draw_boy_reflection(origin, k)
	if _flash > 0.0:
		_board.draw_rect(Rect2(Vector2.ZERO, screen), Color(1, 1, 0.9, _flash * 0.75))
	_draw_boy_face(screen)
	# Done: stamped across the board, so there is no doubt that is all there is to do.
	if _done:
		var a := clampf(_done_t / 0.25, 0.0, 1.0)
		var band: Rect2 = R.call(26, 96, PIC_SIZE.x - 52, 40)
		_board.draw_rect(band, Color(0.04, 0.16, 0.06, 0.86 * a))
		_board.draw_rect(band, Color(0.45, 0.95, 0.5, a), false, maxf(1.0, k))
		var t1 := tr("POWER BACK ON")
		var fs := RETRO_UI.SIZE_BIG * int(k)
		var w1 := RETRO_UI.FONT_BIG.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_board.draw_string(RETRO_UI.FONT_BIG, (band.position + Vector2((band.size.x - w1) * 0.5, 18 * k)).floor(), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.62, 1.0, 0.6, a))
		var t2 := tr("JOB DONE")
		var fs2 := 8 * int(k)
		var w2 := RETRO_UI.FONT_TEXT.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		_board.draw_string(RETRO_UI.FONT_TEXT, (band.position + Vector2((band.size.x - w2) * 0.5, 32 * k)).floor(), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.9, 0.95, 0.8, a))
	if _hover != -2:
		HandCursor.want(HandCursor.POINT)


## A disc of light: transparent in the middle, black at the rim.
func _torch_texture() -> Texture2D:
	if _torch != null:
		return _torch
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, Color(0, 0, 0, clampf((d - 0.45) / 0.55, 0.0, 1.0)))
	_torch = ImageTexture.create_from_image(img)
	return _torch


func _wrap(t: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for w in t.split(" "):
		if line.length() + w.length() + 1 > width and not line.is_empty():
			out.append(line)
			line = w
		else:
			line = w if line.is_empty() else line + " " + w
	if not line.is_empty():
		out.append(line)
	return out


func _text(t: String, pos: Vector2, font: Font, size_vp: int, color: Color) -> void:
	var size_px := size_vp * _scale
	var shadow := float(RETRO_UI.font_pixel(font, size_vp) * _scale)
	_board.draw_string(font, pos.floor() + Vector2(shadow, shadow), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, 0.7))
	_board.draw_string(font, pos.floor(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
