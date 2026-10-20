extends Control

## What the pub is waiting for, drawn over the room the bistro's way (bistro_marks.gd,
## Traveller's Rest): pixel bubbles pinned to things in the 3D room (scripts/
## service_interior.gd makes one while you are in the pub):
##   over a guest     what they want (the drink's picture) and a bar for how long they have
##                    waited, green, amber, red; the money floating up when it lands;
##   over a station   the tap: how many want a beer (red: no clean mugs, or the keg);
##                    the back bar: the shots and kofolas wanted; the washer: the dirty
##                    mugs (red with no clean ones left); the keg in the cellar: SPENT, OFF,
##                    the gas out of the green; over the cellar door when the keg needs
##                    you; a station another warden is at: their name;
##   the strip        the open orders in a row at the top left, as beer mats.
## Stepped like the rest of the room (12 a second).

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const PUB = preload("res://core/systems/pub_rules.gd")
const LAYOUT = preload("res://scripts/pub/pub_layout.gd")
const MARK_DIR := "res://assets/textury/ui/"
const STEP := 1.0 / 12.0
const ICON := {"hladinka": "mark_mug", "snyt": "mark_mug", "mliko": "mark_foam", "rum": "mark_shot",
	"zelena": "mark_shot", "slivovice": "mark_shot", "kofola": "mark_kofola"}
## Where the cellar door is in the bar room (its mark when the keg needs you).
const CELLAR_DOOR := Vector3(2.85, 2.3, 0.3)

var key := ""
var taproom
var camera_of: Callable
var viewport_of: Callable
var room_of: Callable
var life_of: Callable
var taken_of: Callable
var roots: Dictionary = {}

var _acc := 0.0
var _t := 0.0
var _tex: Dictionary = {}
var _landed: Dictionary = {}
var _k := 2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["mark_mug", "mark_foam", "mark_shot", "mark_kofola", "mark_keg", "mark_dirty", "mark_tap", "mark_wash"]:
		_tex[m] = load(MARK_DIR + m + ".png") if ResourceLoader.exists(MARK_DIR + m + ".png") else null
	for n in ["mat"]:
		var p := "res://assets/textury/pub/%s.png" % n
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	if taproom != null:
		taproom.poured.connect(_on_poured)


func _icon(name: String) -> Texture2D:
	var t: Texture2D = _tex.get(name)
	if t == null and name == "mark_mug":
		t = _tex.get("mark_tap")
	if t == null and name == "mark_dirty":
		t = _tex.get("mark_wash")
	return t


func _on_poured(k: String, tid: String, rec: Dictionary) -> void:
	if k == key:
		_landed[tid.get_slice("/", 0)] = {"amount": int(rec.get("amount", 0)), "t": 0.0}


func _process(delta: float) -> void:
	_t += delta
	for k in _landed.keys():
		_landed[k]["t"] = float(_landed[k]["t"]) + delta
		if float(_landed[k]["t"]) > 2.4:
			_landed.erase(k)
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	queue_redraw()


func _project(world: Vector3):
	var cam: Camera3D = camera_of.call() if camera_of.is_valid() else null
	var vp: SubViewport = viewport_of.call() if viewport_of.is_valid() else null
	if cam == null or vp == null or cam.is_position_behind(world):
		return null
	var p := cam.unproject_position(world)
	var s := get_viewport_rect().size
	return (p / Vector2(vp.size) * s / float(_k)).floor()


func _draw() -> void:
	if taproom == null or key == "":
		return
	_k = maxi(1, int(floor(minf(get_viewport_rect().size.x / 640.0, get_viewport_rect().size.y / 360.0))))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k, _k))
	var room := str(room_of.call()) if room_of.is_valid() else ""
	var tix: Array = taproom.tickets(key)
	_draw_strip(tix)
	_draw_stations(room, tix)
	if room == "bar":
		_draw_guests()


# ── the strip of mats, top left ──────────────────────────────────────────────

func _draw_strip(tix: Array) -> void:
	var x := 4.0
	var shown := mini(tix.size(), 10)
	for i in shown:
		var t: Dictionary = tix[i]
		var r := Rect2(x, 4, 22, 22)
		var mt: Texture2D = _tex.get("mat")
		if mt != null:
			draw_texture_rect(mt, r, false)
		else:
			draw_rect(r, Color(0.9, 0.87, 0.8))
		var ic := _icon(str(ICON.get(str(t["drink"]), "mark_mug")))
		if ic != null:
			var s := ic.get_size() * minf(1.0, 14.0 / maxf(1.0, ic.get_size().y))
			draw_texture_rect(ic, Rect2((r.get_center() - s * 0.5).floor(), s), false)
		var band := PUB.patience_band(int(t["age"]))
		var left := 1.0 - clampf(float(t["age"]) / float(PUB.PATIENCE_GONE), 0.0, 1.0)
		var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
		draw_rect(Rect2(r.position.x + 2, r.end.y + 1, 18, 3), Color(0.1, 0.08, 0.06, 0.85))
		if band < 2 or int(_t * 4.0) % 2 == 0:
			draw_rect(Rect2(r.position.x + 2, r.end.y + 1, floorf(18.0 * left), 3), col)
		x += 24.0
	if tix.size() > shown:
		_text(Vector2(x + 2, 18), "+%d" % (tix.size() - shown), RETRO_UI.C_AMBER_LIGHT)


# ── the guests ───────────────────────────────────────────────────────────────

func _draw_guests() -> void:
	var life = life_of.call() if life_of.is_valid() else null
	if life == null or not life.has_method("heads"):
		return
	for h in life.heads():
		var at = _project(h["head"])
		if at == null:
			continue
		var visit := str(h["visit"])
		var member := int(h["member"])
		var who := "%s#%d" % [visit, member]
		if _landed.has(who):
			var l: Dictionary = _landed[who]
			var k := float(l["t"]) / 2.4
			var col := RETRO_UI.C_AMBER_LIGHT
			col.a = 1.0 - k * k
			_text((at as Vector2) + Vector2(-8, -10 - k * 18.0), "+$%d" % int(l["amount"]), col, true)
			continue
		if str(h.get("state", "")) != "seat":
			continue
		var t: Dictionary = taproom.ticket_of(key, visit, member)
		if t.is_empty():
			continue
		var age := int(t["age"])
		_bubble(at, _icon(str(ICON.get(str(t["drink"]), "mark_mug"))), 1.0 - clampf(float(age) / float(PUB.PATIENCE_GONE), 0.0, 1.0), PUB.patience_band(age))


func _bubble(at: Vector2, icon: Texture2D, left: float, band: int) -> void:
	var w := 22.0
	var h := 20.0
	var r := Rect2(at + Vector2(-w * 0.5, -h - 4), Vector2(w, h)).abs()
	r.position = r.position.floor()
	var ink := Color(0.12, 0.1, 0.08)
	draw_rect(r.grow(1.0), ink)
	draw_rect(r, Color(0.96, 0.94, 0.86))
	draw_rect(Rect2(at.x - 1, r.end.y, 3, 2), Color(0.96, 0.94, 0.86))
	draw_rect(Rect2(at.x - 2, r.end.y, 1, 2), ink)
	draw_rect(Rect2(at.x + 2, r.end.y, 1, 2), ink)
	draw_rect(Rect2(at.x - 1, r.end.y + 2, 3, 1), ink)
	if icon != null:
		var s := icon.get_size() * minf(1.0, 14.0 / maxf(1.0, icon.get_size().y))
		draw_texture_rect(icon, Rect2((r.position + Vector2((w - s.x) * 0.5, 1)).floor(), s), false)
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	draw_rect(Rect2(r.position.x + 2, r.end.y - 4, w - 4, 2), Color(0.25, 0.22, 0.2))
	if band < 2 or int(_t * 4.0) % 2 == 0:
		draw_rect(Rect2(r.position.x + 2, r.end.y - 4, floorf((w - 4) * left), 2), col)


# ── the stations ─────────────────────────────────────────────────────────────

func _draw_stations(room: String, tix: Array) -> void:
	var root: Node3D = roots.get(room, null)
	if root == null:
		return
	var taken: Dictionary = taken_of.call() if taken_of.is_valid() else {}
	var tap_n := 0
	var bar_n := 0
	var red_tap := false
	var red_bar := false
	for t in tix:
		var band := PUB.patience_band(int(t["age"]))
		if PUB.kind(str(t["drink"])) == "tap":
			tap_n += 1
			red_tap = red_tap or band == 2
		else:
			bar_n += 1
			red_bar = red_bar or band == 2
	var mugs: Dictionary = taproom.mugs(key)
	var n_bills: int = taproom.bills(key).size()
	var trouble: String = taproom.tap_trouble(key)
	var gas := float(taproom.keg(key)["gas"])
	for id in LAYOUT.STATIONS:
		var st: Dictionary = LAYOUT.STATIONS[id]
		if str(st["room"]) != room:
			continue
		var at = _project(root.global_transform * (st["mark"] as Vector3))
		if at == null:
			continue
		if str(taken.get(id, "")) != "":
			_tag(at, str(taken[id]).to_upper())
			continue
		match str(id):
			"tap":
				if trouble != "" and tap_n > 0:
					_badge(at, "mark_keg", {"dry": "NO BEER", "empty": "KEG", "off": "KEG"}.get(trouble, "KEG"), true)
				elif int(mugs["clean"]) == 0 and tap_n > 0:
					_badge(at, "mark_dirty", "NO MUGS", true)
				elif tap_n > 0:
					_badge(at, "mark_mug", str(tap_n) + ("  BILL %d" % n_bills if n_bills > 0 else ""), red_tap)
				elif n_bills > 0:
					_badge(at, "mark_mug", "BILL %d" % n_bills, false)
			"back":
				if bar_n > 0:
					_badge(at, "mark_shot", str(bar_n), red_bar)
			"wash":
				if int(mugs["dirty"]) > 0 or int(mugs["clean"]) == 0:
					_badge(at, "mark_dirty", str(int(mugs["dirty"])), int(mugs["clean"]) == 0)
			"keg":
				if trouble == "empty":
					_badge(at, "mark_keg", "SPENT", true)
				elif trouble == "off":
					_badge(at, "mark_keg", "OFF", true)
				elif trouble == "dry":
					_badge(at, "mark_keg", "NO BEER", true)
				elif PUB.gas_band(gas) != "OK":
					_badge(at, "mark_keg", "GAS " + PUB.gas_band(gas), PUB.gas_band(gas) == "HIGH" or gas < PUB.GAS_LOW - 0.1)
	if room == "bar" and (trouble == "empty" or trouble == "off" or PUB.gas_band(gas) != "OK"):
		var door = _project(root.global_transform * CELLAR_DOOR)
		if door != null:
			_badge(door, "mark_keg", "CELLAR", trouble != "")


func _badge(at: Vector2, icon: String, text: String, alarm: bool) -> void:
	var ic := _icon(icon)
	var s := ic.get_size() * minf(1.0, 16.0 / maxf(1.0, ic.get_size().y)) if ic != null else Vector2.ZERO
	var tw := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := s.x + tw + (6.0 if ic != null else 4.0)
	var h := maxf(s.y, 10.0) + 2.0
	var bob := 1.0 if int(_t * 3.0) % 2 == 0 else 0.0
	var r := Rect2(at - Vector2(w * 0.5, h + 4 + bob), Vector2(w, h)).abs()
	r.position = r.position.floor()
	var on := not alarm or int(_t * 4.0) % 2 == 0
	draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.92))
	draw_rect(r, RETRO_UI.C_RED_DARK if alarm and on else Color(0.2, 0.17, 0.14, 0.92))
	var x := r.position.x + 2
	if ic != null:
		draw_texture_rect(ic, Rect2(Vector2(x, r.position.y + 1), s), false)
		x += s.x + 2
	_text(Vector2(x, r.position.y + floorf(h * 0.5) + 4), text, RETRO_UI.C_RED_LIGHT if alarm else RETRO_UI.C_BONE)


func _tag(at: Vector2, who: String) -> void:
	var tw := RETRO_UI.FONT_LABEL.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var r := Rect2((at - Vector2(tw * 0.5 + 3, 16)).floor(), Vector2(tw + 6, 11))
	draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.9))
	draw_rect(r, Color(0.16, 0.22, 0.3, 0.92))
	_text(r.position + Vector2(3, 9), who, RETRO_UI.C_NIGHT)


func _text(at: Vector2, text: String, col: Color, big := false) -> void:
	var f: Font = RETRO_UI.FONT_BIG if big else RETRO_UI.FONT_LABEL
	var s := 10 if big else 8
	draw_string(f, at.floor() + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(0, 0, 0, col.a))
	draw_string(f, at.floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
