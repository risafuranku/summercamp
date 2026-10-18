extends CanvasLayer

## Behind the corn stand (playtest 18. 10.: "the corn stand is the bottom of the screen,
## the top is the live view into the camp"):
##   - the top of the screen is the camp as it is, seen from behind the counter: the
##     guests coming up to the stand, the paths, the weather (a camera in the game's own
##     world, through the Build palette like every view);
##   - the bottom is the counter (the lower part of assets/textury/closeup/corn_stand.png):
##     the pot of boiling water, the butter and its brush, the salt, the napkins, the cash
##     box, a crate of raw cobs.
## The guests the simulation sends to the stand say what they want:
##   1. a raw cob from the crate into the pot (off the shelf: no corn, no cob);
##   2. it boils: pale, bright yellow (about ten seconds), then grey and soft;
##   3. click it in the pot: onto the board;
##   4. butter: hold the button and brush along it until it shines;
##   5. salt: a shake per click, as many as they asked ("no salt" means none);
##   6. a napkin round it; click the customer up in the view to hand it over: two
##      dollars, a tip for a good one.
## The books are a tab on the counter (scripts/business/ledger_closeup.gd); the
## wholesaler's leaflet lies beside the cash box: click it to order corn and butter (the
## books open on their ORDER page).
## S or the right button steps away.

signal closed

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const LEDGER := preload("res://scripts/business/ledger_closeup.gd")
const PIC := "res://assets/textury/closeup/corn_stand.png"
## Every part on the counter is a render (closeup/parts/): the cob raw, boiled, mushy,
## buttered and in its napkin, the salt, the steam, the ticket, the books' tab; the
## awning's fringe over the view (camp/awning_fringe.png).
const PARTS := "res://assets/textury/closeup/parts/"
const FRINGE_TEX := "res://assets/textury/camp/awning_fringe.png"
const SFX_SPLASH := "res://assets/sfx/bistro/ladle_plate.mp3"
const SFX_PLATE := "res://assets/sfx/bistro/plate_down.mp3"
const SFX_TILL := "res://assets/sfx/bistro/till.mp3"
const SFX_BOIL := "res://assets/sfx/bistro/fryer.mp3"
const SFX_SALT := "res://assets/sfx/desk/card_drop.mp3"
const PRICE := 2

## The counter: the painting's lower part (from CROP_Y down), in counter px.
const W := 320
const H := 144
const CROP_Y := 96
const WOOD_TEX := "res://assets/textury/camp/planks_dark.png"
const HIDE_LAYER := 1 << 18
const POT := Rect2(0, 0, 115, 84)
const CRATE := Rect2(0, 92, 80, 52)
const BOARD := Rect2(92, 108, 138, 32)
const SALT := Rect2(176, 20, 26, 50)
const NAPKINS := Rect2(205, 30, 56, 42)
const CASH := Rect2(236, 70, 84, 74)
const BOOKS_TAB := Rect2(282, 4, 34, 14)
## The wholesaler's leaflet on the counter (closeup/parts/corn_brochure.png).
const BROCHURE := Rect2(266, 22, 40, 46)
const TICKET := Rect2(118, 4, 110, 34)
const DONE_AT := 9.0
const OVER_AT := 21.0

var building_key := ""
var _open := false
var _pot: Array = []
var _board: Dictionary = {}
var _queue: Array = []
var _next := 1.0
var _t := 0.0
var _floaters: Array = []
var _rng := RandomNumberGenerator.new()
var _pic: Texture2D
var _tex: Dictionary = {}
var _fringe: Texture2D
var _boil: AudioStreamPlayer
var _audio: AudioStreamPlayer
var _ledger: CanvasLayer
# The live view.
var _view_box: SubViewportContainer
var _view: SubViewport
var _cam: Camera3D
# The counter.
var _vp: SubViewport
var _canvas: Control
var _counter: TextureRect
var _wood: TextureRect
## The awning's striped fringe over the top of the view (it flaps in steps) and the
## counter's front lip between the view and the counter.
var _valance: Control
var _lip: TextureRect
## The stand itself is hidden from the view (its counter is the bottom half already):
## its meshes go on HIDE_LAYER, which the view's camera does not render.
var _stand: Node3D
var _stand_layers: Dictionary = {}     # VisualInstance3D -> its layers
var _k := 2
var _mouse := Vector2(-1, -1)
var _hover := ""
var _who := ""
var _say := ""
var _say_t := 0.0


func _init() -> void:
	layer = 95
	add_to_group("closeup")  # the hands are on it (pockets.gd)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_rng.randomize()
	_pic = load(PIC) if ResourceLoader.exists(PIC) else null
	for k in ["cob_raw", "cob_boiled", "cob_mushy", "cob_buttered", "cob_napkin", "salt", "smoke", "ticket", "paper_tab", "corn_brochure"]:
		if ResourceLoader.exists(PARTS + k + ".png"):
			_tex[k] = load(PARTS + k + ".png")
	_fringe = load(FRINGE_TEX) if ResourceLoader.exists(FRINGE_TEX) else null
	_view_box = SubViewportContainer.new()
	_view_box.stretch = true
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view_box)
	_view = SubViewport.new()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_box.add_child(_view)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_cam.far = 400.0
	_cam.cull_mask = 0xFFFFF & ~HIDE_LAYER
	_view.add_child(_cam)
	RETRO_RENDER.register(_view_box)
	_valance = Control.new()
	_valance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_valance.draw.connect(_draw_valance)
	add_child(_valance)
	# Either side of the counter: the stand's dark boards.
	_wood = TextureRect.new()
	_wood.texture = load(WOOD_TEX) if ResourceLoader.exists(WOOD_TEX) else null
	_wood.stretch_mode = TextureRect.STRETCH_TILE
	_wood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wood.modulate = Color(0.5, 0.42, 0.36)
	_wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wood)
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_canvas = Control.new()
	_canvas.size = Vector2(W, H)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	_vp.add_child(_canvas)
	# The counter's front board, darker, along the join.
	_lip = TextureRect.new()
	_lip.texture = load(WOOD_TEX) if ResourceLoader.exists(WOOD_TEX) else null
	_lip.stretch_mode = TextureRect.STRETCH_TILE
	_lip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lip.modulate = Color(0.3, 0.24, 0.2)
	_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lip)
	_counter = TextureRect.new()
	_counter.texture = _vp.get_texture()
	_counter.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_counter.stretch_mode = TextureRect.STRETCH_SCALE
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counter)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_boil = AudioStreamPlayer.new()
	if ResourceLoader.exists(SFX_BOIL):
		var st = load(SFX_BOIL)
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		_boil.stream = st
	_boil.volume_db = -22.0
	add_child(_boil)
	get_tree().root.size_changed.connect(_layout)


func is_open() -> bool:
	return _open


## Behind the stand at `key`; `stand` is its structure in the camp (for the view).
func open_for(key: String, stand: Node3D = null) -> void:
	building_key = key
	if CoreRoot != null and CoreRoot.actions != null and key != "":
		CoreRoot.actions.biz_site(key, "corn_stand")
	if stand != null and stand.is_inside_tree():
		_view.world_3d = stand.get_viewport().find_world_3d()
		# Behind the counter at eye height, looking out over it into the camp.
		var xf := stand.global_transform
		var eye := xf * Vector3(0, 1.66, -0.6)
		var look := xf * Vector3(0, 1.2, 8.0)
		_cam.global_transform = Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
		_hide_stand(stand)
	_open = true
	visible = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_layout()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_next = 1.0
	if _boil.stream != null:
		_boil.play()
	if ORDERS.visitors(building_key).is_empty():
		_line("", "Nobody at the stand. The water rolls in the pot.")


func close_view() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_boil.stop()
	_show_stand()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func _hide_stand(stand: Node3D) -> void:
	_show_stand()
	_stand = stand
	var todo: Array = [stand]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is VisualInstance3D:
			_stand_layers[n] = (n as VisualInstance3D).layers
			(n as VisualInstance3D).layers = HIDE_LAYER
		todo.append_array(n.get_children())


func _show_stand() -> void:
	for n in _stand_layers:
		if is_instance_valid(n):
			(n as VisualInstance3D).layers = int(_stand_layers[n])
	_stand_layers.clear()
	_stand = null


func _layout() -> void:
	if _counter == null:
		return
	var vp := get_viewport().get_visible_rect().size
	# The counter as big as a whole multiple lets it be in the bottom ~45% of the screen.
	_k = maxi(1, int(floor(minf(vp.x / float(W), vp.y * 0.46 / float(H)))))
	_counter.size = Vector2(W * _k, H * _k)
	_counter.position = Vector2(floorf((vp.x - _counter.size.x) * 0.5), vp.y - _counter.size.y)
	_wood.position = Vector2(0, _counter.position.y)
	_wood.size = Vector2(vp.x, _counter.size.y)
	_wood.scale = Vector2.ONE
	if _wood.texture != null:
		# Tiled at the counter's own pixel size.
		_wood.size = Vector2(ceilf(vp.x / _k), ceilf(_counter.size.y / _k))
		_wood.scale = Vector2(_k, _k)
	_view_box.position = Vector2.ZERO
	_view_box.size = Vector2(vp.x, _counter.position.y)
	_valance.position = Vector2.ZERO
	_valance.size = Vector2(vp.x, 18 * _k)
	_lip.position = Vector2(0, _counter.position.y - 4 * _k)
	_lip.size = Vector2(ceilf(vp.x / _k), 4)
	_lip.scale = Vector2(_k, _k)
	RETRO_RENDER.apply_to(_view_box)


## The awning's fringe (a render of two tongues, red and cream) along the top of the view,
## each pair lifting a pixel or two in the wind, in steps.
func _draw_valance() -> void:
	if _fringe == null:
		return
	var sz := Vector2(_fringe.get_size())
	var h := 18.0 * _k
	var w := sz.x * h / sz.y
	for i in int(ceil(_valance.size.x / w)) + 1:
		var lift := roundf(sin(_t * 2.3 + i * 0.9) * 1.4) * _k
		_valance.draw_texture_rect(_fringe, Rect2(i * w, -lift - 2.0 * _k, w, h), false)


func _line(who: String, text: String) -> void:
	_who = who
	_say = text
	_say_t = 0.0


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()


# ── input ────────────────────────────────────────────────────────────────────

func _pot_cob_rect(c: Dictionary) -> Rect2:
	var x: float = POT.position.x + 6 + float(c["x"]) * 64.0
	var y := POT.position.y + 12 + float(int(float(c["x"]) * 2.0) % 2) * 8.0 + sin(_t * 3.0 + float(c["phase"])) * 2.0
	return Rect2(x, y, 40, 14)


func _hotspots() -> Array:
	var out: Array = [{"id": "books", "rect": BOOKS_TAB}, {"id": "brochure", "rect": BROCHURE}]
	for i in _pot.size():
		out.append({"id": "pot:%d" % i, "rect": _pot_cob_rect(_pot[i])})
	out.append({"id": "crate", "rect": CRATE})
	if not _board.is_empty():
		out.append({"id": "board", "rect": BOARD})
		out.append({"id": "salt", "rect": SALT})
		out.append({"id": "napkin", "rect": NAPKINS})
	return out


func _in_view(p: Vector2) -> bool:
	return p.y < _counter.position.y


func _input(event: InputEvent) -> void:
	if not _open or get_tree().paused:
		return
	if _ledger != null and _ledger.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_S:
		close_view()
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		close_view()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _in_view(mb.position):
		# Up in the view: whoever is at the counter takes what is on the board.
		if not _board.is_empty():
			_hand_over()
		return
	if _hover != "":
		_clicked(_hover)


func _clicked(id: String) -> void:
	if id == "books" or id == "brochure":
		if _ledger == null:
			_ledger = LEDGER.new()
			add_child(_ledger)
		_ledger.layer = layer + 1
		_ledger.open_for(building_key, "corn_stand", "order" if id == "brochure" else "stock")
		return
	if id == "crate":
		if _pot.size() >= 3:
			_line("", "The pot is full.")
			return
		if BUSINESS.stock_of(building_key, "cobs") == 0:
			_line("", "The crate is empty. Order corn in the books.")
			return
		if CoreRoot != null and CoreRoot.actions != null and BUSINESS.stock_of(building_key, "cobs") > 0:
			CoreRoot.actions.biz_take(building_key, {"cobs": 1})
		var used: Array = _pot.map(func(c): return float(c["x"]))
		var x := 0.0
		for cand in [0.0, 0.5, 1.0]:
			if not used.has(cand):
				x = cand
				break
		_pot.append({"t": 0.0, "x": x, "phase": _rng.randf() * TAU})
		_play(SFX_SPLASH, -8.0)
		return
	if id.begins_with("pot:"):
		if not _board.is_empty():
			_line("", "There is one on the board already.")
			return
		var i := int(id.get_slice(":", 1))
		var c: Dictionary = _pot[i]
		_pot.remove_at(i)
		var cook := clampf(float(c["t"]) / DONE_AT, 0.0, 1.0) + clampf((float(c["t"]) - OVER_AT) / 15.0, 0.0, 1.0)
		var mask := PackedByteArray()
		mask.resize(20)
		_board = {"cook": cook, "butter": mask, "salt": 0, "napkin": false}
		_play(SFX_PLATE, -8.0)
		return
	match id:
		"salt":
			_board["salt"] = int(_board["salt"]) + 1
			_play(SFX_SALT, -10.0)
		"napkin":
			_board["napkin"] = true
			_play(SFX_PLATE, -14.0)


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	_say_t += delta
	var m := get_viewport().get_mouse_position()
	var local := (m - _counter.position) / float(_k)
	_mouse = local if Rect2(Vector2.ZERO, Vector2(W, H)).has_point(local) else Vector2(-1, -1)
	_hover = ""
	if _mouse.x >= 0.0:
		for h in _hotspots():
			if (h["rect"] as Rect2).has_point(_mouse):
				_hover = str(h["id"])
				break
	if _hover != "" and _hover != "board":
		HandCursor.want(HandCursor.POINT)
	elif _in_view(m) and not _board.is_empty() and not _queue.is_empty():
		HandCursor.want(HandCursor.POINT)
	for c in _pot:
		c["t"] = float(c["t"]) + delta
	for f in _floaters:
		f["t"] = float(f["t"]) + delta
	_floaters = _floaters.filter(func(f): return float(f["t"]) < 1.4)
	# Buttering: brush along the cob with the button held.
	if not _board.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and BOARD.has_point(_mouse):
		HandCursor.want(HandCursor.GRAB)
		if BUSINESS.stock_of(building_key, "butter") != 0:
			var mask: PackedByteArray = _board["butter"]
			var u := clampi(int((_mouse.x - BOARD.position.x - 20) / 96.0 * 20.0), 0, 19)
			for k in range(maxi(0, u - 1), mini(20, u + 2)):
				mask[k] = 1
	_next -= delta
	if _next <= 0.0:
		_next = 1.5
		_sync_queue()
	_canvas.queue_redraw()
	_valance.queue_redraw()


func _sync_queue() -> void:
	var here := {}
	for v in ORDERS.visitors(building_key):
		here[str(v["visit"])] = v
	_queue = _queue.filter(func(o): return here.has(str((o["v"] as Dictionary)["visit"])))
	if _queue.size() >= 2:
		return
	for k in here:
		var v: Dictionary = here[k]
		var queued := false
		for o in _queue:
			if str((o["v"] as Dictionary)["visit"]) == k:
				queued = true
		if queued or ORDERS.left_for(v, "corn") <= 0:
			continue
		var salt: int = [0, 1, 1, 2, 3][_rng.randi() % 5]
		_queue.append({"v": v, "salt": salt})
		if _queue.size() == 1:
			_ask()
		return


func _ask() -> void:
	if _queue.is_empty():
		return
	var o: Dictionary = _queue[0]
	var lines := {0: ["One, no salt. My heart.", "Butter, no salt, please."], 1: ["One cob, a pinch of salt.", "A cob. Bit of salt."], 2: ["Two shakes of salt on mine.", "Butter and salt, the works."], 3: ["Salt it like the sea. Three shakes.", "Loads of salt. Three."]}
	var opts: Array = lines[int(o["salt"])]
	_line(ORDERS.first_name(str((o["v"] as Dictionary)["name"])), str(opts[_rng.randi() % opts.size()]))


func _butter_share() -> float:
	var mask: PackedByteArray = _board["butter"]
	var n := 0
	for v in mask:
		n += v
	return float(n) / float(mask.size())


func _hand_over() -> void:
	if _queue.is_empty():
		_line("", "Nobody's waiting. You eat it yourself. It is good.")
		_board = {}
		return
	var o: Dictionary = _queue[0]
	var v: Dictionary = o["v"]
	var who := ORDERS.first_name(str(v["name"]))
	if not bool(_board["napkin"]):
		_line(who, "In my hand? It's boiling. A napkin, please.")
		return
	var cook: float = _board["cook"]
	var q := 1.0
	var notes: Array = []
	if cook < 0.75:
		q -= 0.6
		notes.append("It's still hard.")
	elif cook > 1.25:
		q -= 0.5
		notes.append("It's gone soft and grey.")
	var b := _butter_share()
	if b < 0.5:
		q -= 0.35
		notes.append("Where's the butter?")
	elif b < 0.85:
		q -= 0.12
	var dsalt := absi(int(_board["salt"]) - int(o["salt"]))
	if dsalt > 0:
		q -= 0.18 * float(dsalt)
		notes.append("Too salty." if int(_board["salt"]) > int(o["salt"]) else "Bit bland.")
	q = clampf(q, 0.0, 1.0)
	if q < 0.25:
		_line(who, " ".join(notes) + " Do another one.")
		ORDERS.mood(int(v["id"]), -1.0, "The corn at the camp stand was awful.")
		_board = {}
		return
	var tip := 2 if q >= 0.9 else (1 if q >= 0.65 else 0)
	var needs := {"butter": 1} if BUSINESS.stock_of(building_key, "butter") > 0 else {}
	if not BUSINESS.sell(building_key, needs, PRICE + tip):
		_line("", "No butter left. Order it in the books.")
		return
	ORDERS.note_served(v)
	_queue.pop_front()
	_board = {}
	_play(SFX_TILL, -8.0)
	_floaters.append({"text": "+$%d" % (PRICE + tip), "at": Vector2(CASH.position.x + 20, CASH.position.y), "t": 0.0, "col": RETRO_UI.C_AMBER_LIGHT if tip > 0 else RETRO_UI.C_BONE})
	if q >= 0.9:
		_line(who, ["Now that is a cob.", "Like at my gran's.", "Perfect. Keep the change."][_rng.randi() % 3])
		ORDERS.mood(int(v["id"]), 2.0, "The corn at the camp stand is the best thing here.")
	else:
		_line(who, " ".join(notes) if not notes.is_empty() else "Cheers.")
		ORDERS.mood(int(v["id"]), 0.4, "")
	get_tree().create_timer(1.2).timeout.connect(_ask)


# ── drawing the counter ──────────────────────────────────────────────────────

static func ink(c: Control, font: Font, pos: Vector2, text: String, col: Color, shadow := Color(0, 0, 0, 0.0), size := 8) -> void:
	if shadow.a > 0.0:
		c.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	c.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## A render's own shape fitted into `r`, centred.
func _fit(key: String, r: Rect2) -> Rect2:
	var t: Texture2D = _tex.get(key)
	if t == null:
		return r
	var sz := Vector2(t.get_size())
	var k := minf(r.size.x / sz.x, r.size.y / sz.y)
	return Rect2(r.get_center() - sz * k * 0.5, sz * k)


func _blit(c: Control, key: String, d: Rect2, alpha := 1.0, tint := Color(1, 1, 1)) -> void:
	var t: Texture2D = _tex.get(key)
	if t != null and alpha > 0.0:
		c.draw_texture_rect(t, d, false, Color(tint.r, tint.g, tint.b, alpha))


## A cob as it cooks: the raw render going over to the boiled one, then to the mushy.
func _draw_cob(c: Control, d: Rect2, cook: float) -> void:
	_blit(c, "cob_raw", d, 1.0 - clampf((cook - 0.3) / 0.6, 0.0, 1.0))
	_blit(c, "cob_boiled", d, clampf((cook - 0.3) / 0.6, 0.0, 1.0))
	_blit(c, "cob_mushy", d, clampf((cook - 1.25) / 0.55, 0.0, 1.0))


func _draw() -> void:
	var c := _canvas
	if _pic != null:
		c.draw_texture_rect_region(_pic, Rect2(0, 0, W, H), Rect2(0, CROP_Y, W, H))
	var st := floorf(_t * 12.0) / 12.0
	# Steam off the pot, in steps.
	for i in 5:
		var age := fmod(st * 0.4 + i * 0.2, 1.0)
		var at := Vector2(POT.position.x + 10 + i * 18 + sin(st * 2.0 + i) * 4.0, POT.position.y + 4 - age * 30.0)
		var size := 14.0 + age * 14.0
		_blit(c, "smoke", Rect2(at, Vector2(size, size)), (1.0 - age) * 0.45, Color(1, 1, 1))
	for cb in _pot:
		var r := _pot_cob_rect(cb)
		var cook := clampf(float(cb["t"]) / DONE_AT, 0.0, 1.0) + clampf((float(cb["t"]) - OVER_AT) / 15.0, 0.0, 1.0)
		_draw_cob(c, _fit("cob_boiled", r), cook)
		if _hover == "pot:%d" % _pot.find(cb):
			c.draw_rect(r.grow(1), Color(1, 0.95, 0.6, 0.25))
	# The raw cobs lying in the crate, as many as are left (up to six).
	var left := BUSINESS.stock_of(building_key, "cobs")
	for i in mini(6, maxi(0, left)):
		var d := _fit("cob_raw", Rect2(CRATE.position + Vector2(6 + (i % 2) * 30, 18 + (i / 2) * 9), Vector2(44, 14)))
		_blit(c, "cob_raw", d)
	if _hover == "crate":
		c.draw_rect(CRATE, Color(1, 0.95, 0.6, 0.15))
	# The cob on the board: boiled, buttered where the brush has been, salted, wrapped.
	if not _board.is_empty():
		var d := _fit("cob_boiled", Rect2(BOARD.position.x + 20, BOARD.position.y + 2, 96, 26))
		if bool(_board["napkin"]):
			_blit(c, "cob_napkin", _fit("cob_napkin", d.grow(2)))
		else:
			_draw_cob(c, d, float(_board["cook"]))
			var bt: Texture2D = _tex.get("cob_buttered")
			var mask: PackedByteArray = _board["butter"]
			if bt != null:
				var tw := float(bt.get_width()) / float(mask.size())
				var dw := d.size.x / float(mask.size())
				for k in mask.size():
					if mask[k] == 1:
						c.draw_texture_rect_region(bt, Rect2(d.position.x + k * dw, d.position.y, dw, d.size.y), Rect2(k * tw, 0, tw, bt.get_height()))
		for k in int(_board["salt"]) * 2:
			var at := Vector2(d.position.x + 6 + fmod(float(k) * 23.7, d.size.x - 20), d.position.y + fmod(float(k) * 7.3, d.size.y - 10))
			_blit(c, "salt", Rect2(at, Vector2(7, 7)))
		if _hover == "salt":
			c.draw_rect(SALT, Color(1, 0.95, 0.6, 0.18))
		if _hover == "napkin":
			c.draw_rect(NAPKINS, Color(1, 0.95, 0.6, 0.18))
	# The order ticket, pinned to the awning post.
	if not _queue.is_empty():
		var o: Dictionary = _queue[0]
		_blit(c, "ticket", TICKET)
		ink(c, RETRO_UI.FONT_LABEL, TICKET.position + Vector2(8, 12), ORDERS.first_name(str((o["v"] as Dictionary)["name"])).to_upper(), Color(0.2, 0.16, 0.34))
		ink(c, RETRO_UI.FONT_TEXT, TICKET.position + Vector2(8, 22), "1 cob, butter", Color(0.2, 0.16, 0.34))
		var salts: Array = ["none", "a pinch", "two", "three"]
		ink(c, RETRO_UI.FONT_TEXT, TICKET.position + Vector2(8, 30), "salt: %s" % str(salts[int(o["salt"])]), Color(0.6, 0.12, 0.1))
		if _queue.size() > 1:
			ink(c, RETRO_UI.FONT_TEXT, Vector2(TICKET.end.x + 4, TICKET.position.y + 11), "+%d" % (_queue.size() - 1), RETRO_UI.C_BONE, Color(0, 0, 0, 0.8))
	# The wholesaler's leaflet.
	_blit(c, "corn_brochure", BROCHURE)
	if _hover == "brochure":
		c.draw_rect(BROCHURE, Color(1, 0.95, 0.6, 0.22))
	# The books tab.
	_blit(c, "paper_tab", BOOKS_TAB)
	if _hover == "books":
		c.draw_rect(BOOKS_TAB, Color(1, 0.95, 0.6, 0.25))
	ink(c, RETRO_UI.FONT_LABEL, BOOKS_TAB.position + Vector2(3, 10), "BOOKS", Color(0.2, 0.16, 0.34))
	# What is said, along the counter's bottom edge.
	if _say != "" and _say_t < 6.0:
		var a := clampf(6.0 - _say_t, 0.0, 1.0)
		var text := _say if _who == "" else "%s: %s" % [_who.to_upper(), _say]
		c.draw_rect(Rect2(0, H - 12, W, 12), Color(0.05, 0.04, 0.03, 0.82 * a))
		ink(c, RETRO_UI.FONT_TEXT, Vector2(4, H - 3), text, Color(RETRO_UI.C_BONE.r, RETRO_UI.C_BONE.g, RETRO_UI.C_BONE.b, a))
	for f in _floaters:
		var fa := 1.0 - float(f["t"]) / 1.4
		var at: Vector2 = f["at"] - Vector2(0, float(f["t"]) * 18.0)
		ink(c, RETRO_UI.FONT_BIG, at, str(f["text"]), Color(f["col"].r, f["col"].g, f["col"].b, fa), Color(0, 0, 0, fa), 10)
