extends Node

## The counter of Liblice's two shops (the user, 4. 11.: "you point at goods, the
## shopkeeper puts them on the counter and rings them up, you pay with coins and notes from
## your wallet, she gives change"). town_room.gd owns one and hands it the shops' clicks
## (`click`): a good clicked where it stands is taken down and put on the counter, a sprite
## of its own, her line, a sound; a good on the counter clicked goes back; the till (or she,
## once something is on the counter) rings it all up: a key for each thing, the sum on the
## till's little display, and then the close-up (counter_pay.gd) where you put the money on
## the mat. What is paid for goes out through town_room's `bought`; what the bag has no room
## for stays on the counter and is not rung up.
##
## The goods, the prices and her words are counter_goods.gd's, the places on the counter the
## rooms' (jednota_view.gd, kiosk_view.gd: `begin`). Co-op: everybody's money is their own
## business, but the other wardens standing in the shop see your goods come onto the counter
## and go, and hear the till (Coop.send_place("shop", place, ...): this node is the group
## "places_shop").

const GOODS = preload("res://scripts/town/counter_goods.gd")
const PAY = preload("res://scripts/town/counter_pay.gd")
const SEVEN = preload("res://scripts/ui/seven_seg.gd")
const LANG = preload("res://scripts/lang.gd")
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
## The bill (the user 6. 11.: "a confirmation that now you really are buying a thing, it
## costs so much, so much money goes; I felt I was just clicking about and bought nothing"):
## while you have things on the counter, a bill at the right with each thing's picture and
## price, the sum, the money you have and Pay (she rings them up: the till, then the money
## close-up as before). Paid: the money going and what is left, a moment; the things go into
## the bag. Left on the counter when you go, she puts them back.
const BILL_PAPER := Color(0.88, 0.85, 0.76)
const BILL_INK := Color(0.13, 0.11, 0.09)
const BILL_PAY := Color(0.24, 0.52, 0.28)
const BILL_PAID_SEC := 2.8
var _bill: Control
var _bill_pay := Rect2()
var _bill_done := 0.0
var _bill_spent := 0
const SFX_TILL := "res://assets/sfx/bistro/till.mp3"
const SFX_DRAWER := "res://assets/sfx/jednota/drawer.mp3"
const STEP := 1.0 / 12.0
## A key of the till for each thing, then the bell, then she looks up at you.
const KEY_SEC := 0.21
const AFTER_BELL := 1.0
## Things on the counter and you just standing there: after this long she asks.
const ASKS_AFTER := 7.0
## How far above the counter a thing is let go, and how fast it comes down (in steps).
const DROP_M := 0.14
const DROP_STEP := 0.05
const DIGITS := Vector2i(48, 14)
const LIT := Color(0.42, 1.0, 0.62)
const GHOST := Color(0.08, 0.2, 0.13)

## town_room.gd.
var room
## "jednota" or "kiosk" while you are in one of them.
var place := ""
var _lines: Dictionary = {}
var _slots: Array = []
var _mate_slots: Array = []
var _yaw := 0.0
var _billboard := false
var _till_x := 0.0
## What you have on the counter: {id, slot, node, rest}.
var _on: Array = []
## The other wardens': peer id -> nodes.
var _mate_on: Dictionary = {}
var _falling: Array = []
var _hear: AudioStreamPlayer
var _step := 0.0
var _back_at := 0
## She steps along behind the counter to what she is doing.
var _her_x := 0.0
var _her_home := 0.0
var _her_wait := 0.0
var _idle := 0.0
## Being rung up: what is being paid for, the sum, the key we are at.
var _to_pay: Array = []
var _total := 0
var _ringing := false
var _ring_i := 0
var _ring_t := 0.0
var _shown := 0
var _pay
var _paid := false
## The till's display.
var _digits_vp: SubViewport
var _digits_canvas: Control
var _digits_quad: MeshInstance3D
var _digits_text := ""
var _mates_known: Array = []


func _ready() -> void:
	add_to_group("places_shop")
	_hear = AudioStreamPlayer.new()
	add_child(_hear)
	_digits_vp = SubViewport.new()
	_digits_vp.size = DIGITS
	_digits_vp.disable_3d = true
	_digits_vp.transparent_bg = false
	_digits_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_digits_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_digits_vp)
	_digits_canvas = Control.new()
	_digits_canvas.size = Vector2(DIGITS)
	_digits_canvas.draw.connect(_draw_digits)
	_digits_vp.add_child(_digits_canvas)


## Into the shop. `cfg`: "slots" where your things go on the counter and "mate_slots" the
## others', "till" (its sprite) and "window" (its display, a share of the picture), "yaw" or
## "billboard" (how things stand there).
func begin(p_place: String, cfg: Dictionary) -> void:
	place = p_place
	_lines = GOODS.LINES.get(place, {})
	_slots = cfg.get("slots", [])
	_mate_slots = cfg.get("mate_slots", [])
	_yaw = float(cfg.get("yaw", 0.0))
	_billboard = bool(cfg.get("billboard", false))
	_on.clear()
	_falling.clear()
	_mate_on.clear()
	_mates_known = []
	_to_pay = []
	_total = 0
	_ringing = false
	_paid = false
	_digits_text = ""
	_digits_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_digits_quad = null
	var till = cfg.get("till")
	if till is MeshInstance3D:
		_till_x = (till as Node3D).position.x
		_digits_quad = _make_window(till, cfg.get("window", Rect2(0.3, 0.1, 0.4, 0.14)))
	_her_home = float(room._npc_base.x) if room._npc != null else 0.0
	_her_x = _her_home
	_her_wait = 0.0
	if _bill == null or not is_instance_valid(_bill):
		_bill = Control.new()
		_bill.name = "ShopBill"
		_bill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bill.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bill.draw.connect(_draw_bill)
		room.add_child(_bill)
	_bill.visible = true
	_bill_done = 0.0


## Out of the shop: what lay on the counter she puts back; a close-up up goes with you.
func end() -> void:
	if _pay != null and _pay.visible:
		_pay.force_close()
	place = ""
	_on.clear()
	_falling.clear()
	_mate_on.clear()
	if not _paid:
		_to_pay = []
	_ringing = false
	if _bill != null and is_instance_valid(_bill):
		_bill.visible = false
	_bill_pay = Rect2()


func busy() -> bool:
	return _ringing or (_pay != null and _pay.visible)


func _say(key: String) -> void:
	room.say(str(_lines.get("who", "")), str(_lines.get(key, "")))


## A click in the shop. True: it was the counter's (else town_room's small talk).
func click(id: String) -> bool:
	if place == "":
		return false
	if busy():
		return true
	if id.begins_with("ctr"):
		_take_back(int(id.substr(3)))
		return true
	if id == "till" or (id == "her" and not _on.is_empty()):
		_ring()
		return true
	var stock: Dictionary = GOODS.STOCK.get(place, {}).get(id, {})
	if stock.is_empty():
		return false
	room._npc_nod = 0.5
	if int(stock["price"]) <= 0:
		room.say(str(_lines.get("who", "")), str(stock["say"]))
		return true
	if _free_slot() < 0:
		_say("crowded")
		return true
	_put(id)
	var line := GOODS.taking_line(place, id)
	if id == "candle" and _count("candle") == 3 and _lines.has("candles"):
		line = str(_lines["candles"])
	room.say(str(_lines.get("who", "")), line)
	return true


func _count(id: String) -> int:
	var n := 0
	for g in _on:
		if str(g["id"]) == id:
			n += 1
	return n


func _free_slot() -> int:
	for i in _slots.size():
		var taken := false
		for g in _on:
			if int(g["slot"]) == i:
				taken = true
				break
		if not taken:
			return i
	return -1


## She takes it down and puts it on the counter.
func _put(id: String) -> void:
	var slot := _free_slot()
	var rest: Vector3 = _slots[slot]
	var node := GOODS.good(room._root, id, rest + Vector3(0, DROP_M, 0), _yaw, _billboard)
	var g := {"id": id, "slot": slot, "node": node, "rest": rest}
	_on.append(g)
	_falling.append({"node": node, "y": rest.y})
	var look: Dictionary = GOODS.LOOK.get(id, {})
	var h := float(look.get("h", 0.2))
	var w := (node.mesh as QuadMesh).size.x
	room._hot_box("ctr%d" % slot, rest + Vector3(0, h * 0.5, 0), Vector3(maxf(w, 0.16), maxf(h, 0.14), 0.18), [node])
	_sound(GOODS.SFX + str(look.get("put", "put_box")) + ".mp3", -3.0)
	_her_to(rest.x)
	_clear_digits()
	_idle = 0.0
	_tell()


## A good on the counter clicked: back where it came from.
func _take_back(slot: int) -> void:
	for g in _on:
		if int(g["slot"]) == slot:
			_remove(g)
			var lines: Array = _lines.get("back", [""])
			_back_at += 1
			room.say(str(_lines.get("who", "")), str(lines[_back_at % lines.size()]))
			room._npc_nod = 0.5
			_her_to((g["rest"] as Vector3).x)
			_sound(GOODS.SFX + "take_back.mp3", -4.0)
			_clear_digits()
			_idle = 0.0
			_tell()
			return


func _remove(g: Dictionary) -> void:
	_on.erase(g)
	var node = g["node"]
	if is_instance_valid(node):
		node.queue_free()
	var key := "ctr%d" % int(g["slot"])
	var hot: Dictionary = room._hot.get(key, {})
	if not hot.is_empty():
		if is_instance_valid(hot["body"]):
			hot["body"].queue_free()
		room._hot.erase(key)


# ── ringing it up ────────────────────────────────────────────────────────────

func _ring() -> void:
	room._npc_nod = 0.5
	if _on.is_empty():
		_say("none")
		return
	var ids: Array = []
	for g in _on:
		ids.append(str(g["id"]))
	var fits := ids
	var bag = INVENTORY.find(get_tree())
	if bag != null:
		fits = bag.fitting(ids)
	if fits.is_empty():
		_say("bag")
		return
	_to_pay = []
	_total = 0
	var left := fits.duplicate()
	for g in _on:
		if left.has(g["id"]):
			left.erase(g["id"])
			_to_pay.append(g)
			_total += int(GOODS.STOCK[place][g["id"]]["price"])
	_ringing = true
	_ring_i = 0
	_ring_t = 0.32
	_shown = 0
	_paid = false
	_her_to(_till_x, 30.0)
	_show_digits("0")


func _tick_ring(delta: float) -> void:
	_ring_t -= delta
	if _ring_t > 0.0:
		return
	if _ring_i < _to_pay.size():
		var g: Dictionary = _to_pay[_ring_i]
		_shown += int(GOODS.STOCK[place][g["id"]]["price"])
		_show_digits(GOODS.face(_shown))
		_sound(GOODS.SFX + "till_key.mp3", -3.0)
		_ring_i += 1
		_ring_t = KEY_SEC
		return
	if _ring_i == _to_pay.size():
		_sound(SFX_TILL, -6.0)
		Coop.send_place("shop", place, "till", [_total])
		_ring_i += 1
		_ring_t = AFTER_BELL
		return
	_ringing = false
	if CoreRoot.get_money() < _total:
		room._npc_nod = 0.5
		if _lines.has("short_cigs") and _to_pay.size() == 1 and str(_to_pay[0]["id"]) == "cigs":
			_say("short_cigs")
		else:
			room.say(str(_lines.get("who", "")), str(_lines.get("short", "")) % [_total, _total])
		_her_wait = 1.4
		return
	var line := str(_lines.get("stays" if _to_pay.size() < _on.size() else "total", "")) % _total
	var ids: Array = []
	for g in _to_pay:
		ids.append(str(g["id"]))
	if _pay == null:
		_pay = PAY.new()
		add_child(_pay)
		room.add_overlay(_pay)
		_pay.paid.connect(_on_paid)
		_pay.closed.connect(_on_pay_closed)
	_pay.open_pay(_lines, _total, ids, line)


## She has swept the money off the mat: it is hers now. False: it is not there any more.
func _on_paid() -> void:
	_paid = CoreRoot.actions.spend_money(_total)


func _on_pay_closed() -> void:
	if place == "":
		# The room went first: what was paid for is still yours.
		_deliver(true)
		return
	_her_wait = 0.8
	if not _paid:
		_clear_digits()
		_say("cancel")
		return
	_bill_spent = _total
	_bill_done = BILL_PAID_SEC
	_deliver(false)
	_clear_digits()
	var lines: Array = _lines.get("thanks", [""])
	_back_at += 1
	if _on.is_empty():
		room.say(str(_lines.get("who", "")), str(lines[_back_at % lines.size()]))
	else:
		_say("left")
	_tell()


## Off the counter into the bag.
func _deliver(gone: bool) -> void:
	if not _paid:
		_to_pay = []
		return
	_paid = false
	_sound("res://assets/sfx/jednota/bag.mp3", -8.0)
	for g in _to_pay.duplicate():
		if not gone:
			_remove(g)
		room.bought.emit(str(g["id"]))
	_to_pay = []
	_total = 0


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if place == "":
		return
	if _ringing:
		_tick_ring(delta)
	_step += delta
	if _step < STEP:
		return
	_step -= STEP
	for f in _falling.duplicate():
		var n = f["node"]
		if not is_instance_valid(n):
			_falling.erase(f)
			continue
		n.position.y = maxf(float(f["y"]), n.position.y - DROP_STEP)
		if n.position.y <= float(f["y"]):
			_falling.erase(f)
	_bill_done = maxf(0.0, _bill_done - STEP)
	if _bill != null and is_instance_valid(_bill) and _bill.visible:
		_bill.queue_redraw()
	if _her_wait > 0.0 and not busy():
		_her_wait -= STEP
		if _her_wait <= 0.0:
			_her_x = _her_home
	_walk_her()
	if not _on.is_empty() and not busy() and _idle >= 0.0:
		_idle += STEP
		if _idle >= ASKS_AFTER:
			_idle = -1.0
			room._npc_nod = 0.5
			_say("more")


## The bill's Pay clicked (town_room asks before anything in the room): she rings it up.
func bill_hit(pos: Vector2) -> bool:
	if place == "" or _on.is_empty() or busy() or not _bill_pay.has_point(pos):
		return false
	_ring()
	return true


## The things' pictures on the bill (TextureRects: drawn by hand they came out white).
var _bill_icons: Array = []


func _bill_icon(i: int, tex: Texture2D, r: Rect2) -> void:
	while _bill_icons.size() <= i:
		var tr_ := TextureRect.new()
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bill.add_child(tr_)
		_bill_icons.append(tr_)
	var t: TextureRect = _bill_icons[i]
	t.texture = tex
	t.position = r.position
	t.size = r.size
	t.visible = true


func _draw_bill() -> void:
	_bill_pay = Rect2()
	for t in _bill_icons:
		(t as TextureRect).visible = false
	if place == "" or (_on.is_empty() and _bill_done <= 0.0):
		return
	var vp := _bill.get_viewport_rect().size
	var s := maxf(1.0, floorf(vp.y / 300.0))
	var font: Font = RETRO_UI.FONT_LABEL
	var fs := int(8.0 * s)
	var w := 112.0 * s
	var row := 16.0 * s
	var paid := _bill_done > 0.0 and _on.is_empty()
	var lines := 1 if paid else _on.size()
	var h := 14.0 * s + row * float(lines) + 44.0 * s
	var x := vp.x - w - 14.0 * s
	# (Under the camp's cards on the right.)
	var y := vp.y * 0.42
	_bill.draw_rect(Rect2(x + 2.0 * s, y + 2.0 * s, w, h), Color(0, 0, 0, 0.45))
	_bill.draw_rect(Rect2(x, y, w, h), BILL_PAPER)
	var yy := y + 6.0 * s
	if paid:
		_bill.draw_string(font, Vector2(x + 6.0 * s, yy + 9.0 * s), tr("PAID"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BILL_PAY)
		_bill.draw_string(font, Vector2(x + 6.0 * s, yy + 9.0 * s), "-$%d" % _bill_spent, HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0 * s, fs, Color(0.62, 0.12, 0.08))
		yy += row
	else:
		var total := 0
		var shown := 0
		for g in _on:
			var id := str(g["id"])
			var price := int(GOODS.STOCK.get(place, {}).get(id, {}).get("price", 0))
			total += price
			var kind: Dictionary = INVENTORY.KINDS.get(id, {})
			var icon: Texture2D = null
			if kind.has("tex") and ResourceLoader.exists(INVENTORY.TEX + str(kind["tex"])):
				icon = load(INVENTORY.TEX + str(kind["tex"])) as Texture2D
			if icon != null:
				# The thing's own picture, in whole pixels, as the bag shows it.
				var k := floorf(maxf(1.0, 13.0 * s / float(icon.get_height())))
				_bill_icon(shown, icon, Rect2(x + 6.0 * s, yy - 1.0 * s, float(icon.get_width()) * k, float(icon.get_height()) * k))
				shown += 1
			_bill.draw_string(font, Vector2(x + 6.0 * s, yy + 9.0 * s), "$%d" % price, HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0 * s, fs, BILL_INK)
			yy += row
		_bill.draw_line(Vector2(x + 5.0 * s, yy), Vector2(x + w - 5.0 * s, yy), BILL_INK, s)
		yy += 4.0 * s
		_bill.draw_string(font, Vector2(x + 6.0 * s, yy + 9.0 * s), "= $%d" % total, HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0 * s, fs, BILL_INK)
		yy += row
		var short := CoreRoot.get_money() < total
		_bill_pay = Rect2(x + 6.0 * s, yy, w - 12.0 * s, 16.0 * s)
		_bill.draw_rect(_bill_pay, Color(0.55, 0.2, 0.15) if short else BILL_PAY)
		_bill.draw_string(font, Vector2(_bill_pay.position.x, yy + 11.5 * s), tr("Pay"), HORIZONTAL_ALIGNMENT_CENTER, _bill_pay.size.x, fs, BILL_PAPER)
		return
	_bill.draw_string(font, Vector2(x + 6.0 * s, yy + 9.0 * s), "$%d" % CoreRoot.get_money(), HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0 * s, fs, BILL_INK)


## She goes to `x`; back to her place when it has been quiet for `stay` seconds.
func _her_to(x: float, stay := 1.6) -> void:
	_her_x = clampf(x, _her_home - 1.1, _her_home + 1.3)
	_her_wait = stay


func _walk_her() -> void:
	if room._npc == null:
		return
	var b: Vector3 = room._npc_base
	if is_equal_approx(b.x, _her_x):
		return
	b.x = move_toward(b.x, _her_x, 0.17)
	room._npc_base = b
	room._npc_nod = maxf(room._npc_nod, 0.17)
	var hot: Dictionary = room._hot.get("her", {})
	if not hot.is_empty() and is_instance_valid(hot["body"]):
		(hot["body"] as Node3D).position.x = b.x


func _sound(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	_hear.stream = load(path)
	_hear.volume_db = db
	_hear.play()


# ── the till's display ───────────────────────────────────────────────────────

## The digits in their little viewport, laid on the till's window (a share of its picture).
func _make_window(till: MeshInstance3D, win: Rect2) -> MeshInstance3D:
	var s: Vector2 = (till.mesh as QuadMesh).size
	var q := MeshInstance3D.new()
	q.name = "TillDigits"
	var qm := QuadMesh.new()
	qm.size = Vector2(win.size.x * s.x, win.size.y * s.y)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = _digits_vp.get_texture()
	q.material_override = m
	q.position = Vector3((win.position.x + win.size.x * 0.5 - 0.5) * s.x, (1.0 - win.position.y - win.size.y * 0.5) * s.y, 0.004)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.set_meta("retro_skip", true)
	till.add_child(q)
	_digits_canvas.queue_redraw()
	return q


func _show_digits(text: String) -> void:
	_digits_text = text
	_digits_canvas.queue_redraw()
	_digits_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _clear_digits() -> void:
	if _digits_text != "":
		_show_digits("")


func _draw_digits() -> void:
	var c := _digits_canvas
	var size := Vector2(DIGITS)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.02))
	var h := 10.0
	var w := SEVEN.text_width("8888", h)
	var x := size.x - w - 2.0
	var y := (size.y - h) * 0.5
	SEVEN.draw_text(c, Vector2(x, y), h, "8888", GHOST, GHOST, true, false)
	if _digits_text != "":
		var tw := SEVEN.text_width(_digits_text, h)
		SEVEN.draw_text(c, Vector2(size.x - tw - 2.0, y), h, _digits_text, LIT, GHOST, true, false)


# ── the other wardens ────────────────────────────────────────────────────────

## What you have on the counter, for whoever stands in the shop.
func _tell() -> void:
	var ids: Array = []
	for g in _on:
		ids.append(str(g["id"]))
	Coop.send_place("shop", place, "goods", [ids])


## town_room's mates in the shop now: someone new sees what lies here; someone gone takes
## what they had on the counter with them.
func mates_here(ids: Array) -> void:
	if place == "":
		return
	for id in _mate_on.keys():
		if not ids.has(int(id)):
			_set_mate_goods(int(id), [])
	if ids == _mates_known:
		return
	var fresh := false
	for id in ids:
		if not _mates_known.has(id):
			fresh = true
	_mates_known = ids.duplicate()
	if fresh and not _on.is_empty():
		_tell()


## From the other machine (Coop.send_place "shop").
func coop_place(key: String, op: String, data: Array) -> void:
	if place == "" or key != place:
		return
	match op:
		"goods":
			_set_mate_goods(Coop.sender, data[0] as Array)
		"till":
			_sound(SFX_TILL, -9.0)
			if not busy():
				_show_digits(GOODS.face(int(data[0])))
				_her_to(_till_x, 2.0)


func _set_mate_goods(id: int, goods: Array) -> void:
	for n in _mate_on.get(id, []):
		if is_instance_valid(n):
			n.queue_free()
	_mate_on.erase(id)
	if goods.is_empty():
		return
	var nodes: Array = []
	# Each warden from the far end of the others' places.
	var from := 0
	for other in _mate_on.values():
		from += (other as Array).size()
	for i in goods.size():
		if from + i >= _mate_slots.size():
			break
		nodes.append(GOODS.good(room._root, str(goods[i]), _mate_slots[from + i], _yaw, _billboard))
	_mate_on[id] = nodes
	if not busy():
		_clear_digits()
