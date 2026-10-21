extends Control

## What the bistro is waiting for, drawn over the room the way Traveller's Rest draws it
## (DESIGN.md §7b): pixel bubbles and plates at the game's 2D pixel, pinned to things
## in the 3D room (scripts/service_interior.gd makes one while you are in the bistro):
##   over a guest     what they ordered (the dish's picture) and a bar for how long they
##                    have waited, green, amber, red; "..." while they read the menu; the
##                    money floating up when their plate lands;
##   over a station   the stove: a bar for each slice and the basket, "!" when something
##                    is burning; the pot: its portions and a bar for the bottom catching
##                    ("STIR" when it is near); the pass: how many tickets; the sink: the
##                    dirty plates (red with no clean ones left); the cellar's corners
##                    when their trays run low; a station another warden is at: their name;
##   the strip        the tickets in a row at the top left, in every room of the bistro.
## Stepped like the rest of the room (12 a second).

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const RULES = preload("res://core/systems/bistro_rules.gd")
const LAYOUT = preload("res://scripts/bistro/bistro_layout.gd")
const KITCHEN = preload("res://scripts/bistro/kitchen.gd")
const ICON_DIR := "res://assets/textury/closeup/food/"
const MARK_DIR := "res://assets/textury/ui/"
const STEP := 1.0 / 12.0

var key := ""
var kitchen: KITCHEN
## Callables set by the room: the camera, the viewport the room is drawn in, which room
## of the bistro you are in ("dining", "kitchen", "basement"), the guests (service_life),
## who of the other wardens is at which station.
var camera_of: Callable
var viewport_of: Callable
var room_of: Callable
var life_of: Callable
var taken_of: Callable
## The anchors of the stations in their rooms (Node3D roots by room).
var roots: Dictionary = {}

var _acc := 0.0
var _t := 0.0
var _tex: Dictionary = {}
## Plates that just landed: ticket id -> {amount, t}.
var _landed: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in ["goulash", "dumpling", "cheese", "fries", "tartar"]:
		_load(ICON_DIR + "icon_" + d + ".png", "icon:" + d)
	_load(ICON_DIR + "icon_cheese.png", "dish:smazak")
	_load(ICON_DIR + "icon_goulash.png", "dish:goulash")
	_load(ICON_DIR + "icon_fries.png", "dish:fries")
	for m in ["mark_pan", "mark_plate", "mark_wash", "mark_pot", "mark_potato", "mark_slice", "mark_ticket", "mark_bell"]:
		_load(MARK_DIR + m + ".png", m)
	_load("res://assets/textury/bistro/ticket.png", "ticket")
	_load("res://assets/textury/bistro/smoke.png", "smoke")
	_load("res://assets/textury/bistro/star.png", "star")
	_load("res://assets/textury/bistro/star_dim.png", "star_dim")
	if kitchen != null:
		kitchen.plate_out.connect(_on_plate_out)


func _load(path: String, k: String) -> void:
	_tex[k] = load(path) if ResourceLoader.exists(path) else null


func _on_plate_out(k: String, tid: String, verdict: Dictionary) -> void:
	if k == key:
		_landed[tid] = {"amount": int(verdict.get("amount", 0)), "t": 0.0, "stars": int(verdict.get("stars", 0))}


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


## The overlay's pixel: the stations' (640x360 to the screen: 2 at 1280x720, 3 at 1920x1080).
var _k := 2


static func ui_k(screen: Vector2) -> int:
	return maxi(1, int(floor(minf(screen.x / 640.0, screen.y / 360.0))))


## A point of the room (global) on this overlay, in its pixels, or null behind the camera.
func _project(world: Vector3):
	var cam: Camera3D = camera_of.call() if camera_of.is_valid() else null
	var vp: SubViewport = viewport_of.call() if viewport_of.is_valid() else null
	if cam == null or vp == null or cam.is_position_behind(world):
		return null
	var p := cam.unproject_position(world)
	var s := get_viewport_rect().size
	return (p / Vector2(vp.size) * s / float(_k)).floor()


func _draw() -> void:
	if kitchen == null or key == "":
		return
	_k = ui_k(get_viewport_rect().size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k, _k))
	var room := str(room_of.call()) if room_of.is_valid() else ""
	var tix: Array = kitchen.tickets(key)
	_draw_strip(tix)
	if room == "dining":
		_draw_guests()
		var hatch_root: Node3D = roots.get("dining", null)
		var plates_tix: Array = kitchen.tickets(key, "pass")
		if hatch_root != null and not plates_tix.is_empty():
			var at = _project(hatch_root.global_transform * Vector3(0.45, 1.75, -2.35))
			if at != null:
				_badge(at, "mark_ticket", str(plates_tix.size()), _oldest_band(plates_tix) == 2)
		_draw_stations(room, kitchen.tickets(key, "floor"))
	elif room == "kitchen" or room == "basement":
		_draw_stations(room, tix)


func _oldest_band(tix: Array) -> int:
	return RULES.patience_band(int(tix[0]["age"])) if not tix.is_empty() else 0


# ── the strip of tickets, top left ───────────────────────────────────────────

func _draw_strip(tix: Array) -> void:
	if tix.is_empty():
		return
	var x := 4.0
	var y := 4.0
	var shown := mini(tix.size(), 10)
	for i in shown:
		var t: Dictionary = tix[i]
		var r := Rect2(x, y, 22, 30)
		var tt: Texture2D = _tex.get("ticket")
		if tt != null:
			draw_texture_rect(tt, r, false)
		else:
			draw_rect(r, Color(0.92, 0.88, 0.76))
		var ic: Texture2D = _tex.get("dish:" + str(t["dish"]))
		if ic != null:
			draw_texture_rect(ic, Rect2(r.position + Vector2(6, 8), ic.get_size()), false)
		var band := RULES.patience_band(int(t["age"]))
		var left := 1.0 - clampf(float(t["age"]) / float(RULES.PATIENCE_GONE), 0.0, 1.0)
		var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
		draw_rect(Rect2(r.position.x + 3, r.end.y - 6, 16, 3), Color(0.1, 0.08, 0.06, 0.85))
		if band < 2 or int(_t * 4.0) % 2 == 0:
			draw_rect(Rect2(r.position.x + 3, r.end.y - 6, floorf(16.0 * left), 3), col)
		x += 24.0
	if tix.size() > shown:
		_text(Vector2(x + 2, y + 18), "+%d" % (tix.size() - shown), RETRO_UI.C_AMBER_LIGHT)


# ── the guests' bubbles ──────────────────────────────────────────────────────

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
		var tid := "%s#%d" % [visit, member]
		if _landed.has(tid):
			var l: Dictionary = _landed[tid]
			var k := float(l["t"]) / 2.4
			var col := RETRO_UI.C_AMBER_LIGHT
			col.a = 1.0 - k * k
			_text((at as Vector2) + Vector2(-8, -10 - k * 18.0), "+$%d" % int(l["amount"]), col, true)
			# And how they liked it: one to three stars over the head.
			var stars := int(l.get("stars", 0))
			for i in 3:
				var st: Texture2D = _tex.get("star" if i < stars else "star_dim")
				if st != null:
					draw_texture_rect(st, Rect2((at as Vector2) + Vector2(-14 + i * 10, -34 - k * 18.0), st.get_size()), false, Color(1, 1, 1, col.a))
			continue
		if bool(h.get("served", false)) or str(h.get("state", "")) != "seat":
			continue
		var t: Dictionary = kitchen.ticket_of(key, visit, member)
		if t.is_empty():
			# Still reading the menu.
			_bubble(at, null, -1.0, 0)
			continue
		var age := int(t["age"])
		_bubble(at, _tex.get("dish:" + str(t["dish"])), 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0), RULES.patience_band(age))


## A speech bubble above `at` (its tail's tip) with `icon` and a bar `left` long.
func _bubble(at: Vector2, icon: Texture2D, left: float, band: int) -> void:
	if band == 2:
		# Red: the bubble shakes (they are about to get up).
		at.x += float([0, 1, 0, -1][int(_t * 12.0) % 4])
	var w := 20.0
	var h := 18.0 if left >= 0.0 else 10.0
	var r := Rect2(at + Vector2(-w * 0.5, -h - 4), Vector2(w, h)).abs()
	r.position = r.position.floor()
	var ink := Color(0.12, 0.1, 0.08)
	draw_rect(r.grow(1.0), ink)
	draw_rect(r, Color(0.96, 0.94, 0.86))
	# The tail.
	draw_rect(Rect2(at.x - 1, r.end.y, 3, 2), Color(0.96, 0.94, 0.86))
	draw_rect(Rect2(at.x - 2, r.end.y, 1, 2), ink)
	draw_rect(Rect2(at.x + 2, r.end.y, 1, 2), ink)
	draw_rect(Rect2(at.x - 1, r.end.y + 2, 3, 1), ink)
	if left < 0.0:
		var dot := int(_t * 3.0) % 4
		for i in 3:
			draw_rect(Rect2(r.position.x + 5 + i * 4, r.position.y + 4, 2, 2), ink if i < dot else Color(0.7, 0.66, 0.6))
		return
	if icon != null:
		draw_texture_rect(icon, Rect2((r.position + Vector2((w - icon.get_width()) * 0.5, 2)).floor(), icon.get_size()), false)
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
	var s: Dictionary = kitchen.site(key)
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
			"stove":
				_stove(at, s)
			"pot":
				_pot(at, s["pot"])
			"pass":
				var ptix: Array = kitchen.tickets(key, "pass")
				if not ptix.is_empty():
					_badge(at, "mark_ticket", str(ptix.size()), _oldest_band(ptix) == 2)
			"grill":
				var gs: Dictionary = kitchen.grill_state(key)
				if bool(gs["burning"]):
					_smoke(at + Vector2(0, 30), Color(0.35, 0.33, 0.32))
					_badge(at, "mark_pan", "BURNING", true)
				elif bool(gs["ready"]):
					_badge(at, "mark_pan", "TURN", false)
				else:
					var want := 0
					for t in kitchen.tickets(key, "pass"):
						want += int((t["parts"] as Dictionary).get("sausage", 0))
					if want > kitchen.prep(key, "sausage"):
						_badge(at, "mark_pan", str(want - kitchen.prep(key, "sausage")), false)
			"bufet":
				var soups: Array = kitchen.tickets(key, "bufet")
				if not soups.is_empty():
					_badge(at, "mark_ticket", str(soups.size()), _oldest_band(soups) == 2)
				elif int(s["soup"]["level"]) <= 2:
					_badge(at, "mark_pot", "SOUP", true)
			"floor":
				# The plates waiting on the hatch, and the bottles wanted.
				var out: Array = kitchen.tickets(key, "floor")
				var plates_n := kitchen.hatch(key).size()
				if plates_n > 0:
					_badge(at, "mark_plate", str(plates_n), _oldest_band(out) == 2)
				elif not out.is_empty():
					_badge(at, "mark_kofola", str(out.size()), _oldest_band(out) == 2)
			"sink":
				var pl: Dictionary = s["plates"]
				if int(pl["dirty"]) > 0 or int(pl["clean"]) == 0:
					_badge(at, "mark_wash", str(int(pl["dirty"])), int(pl["clean"]) == 0)
			"potatoes":
				if kitchen.prep(key, "chips_raw") < 2:
					_badge(at, "mark_potato", "LOW", kitchen.prep(key, "chips_raw") == 0)
			"breading":
				if kitchen.prep(key, "cheese_raw") + kitchen.prep(key, "cheese_bad") < 2:
					_badge(at, "mark_slice", "LOW", kitchen.prep(key, "cheese_raw") + kitchen.prep(key, "cheese_bad") == 0)
	if room == "kitchen":
		# The cellar's trays run low: over its door.
		var low := kitchen.prep(key, "chips_raw") == 0 or kitchen.prep(key, "cheese_raw") + kitchen.prep(key, "cheese_bad") == 0
		if low:
			var door = _project(root.global_transform * Vector3(3.0, 2.35, 1.45))
			if door != null:
				_badge(door, "mark_potato", "CELLAR", false)


func _stove(at: Vector2, s: Dictionary) -> void:
	var st: Dictionary = kitchen.stove_state(key)
	if bool(st["burning"]):
		_smoke(at + Vector2(0, 30), Color(0.35, 0.33, 0.32))
	if not bool(st["cooking"]):
		return
	var bars: Array = []
	for slot in s["pan"]:
		if (slot as Dictionary).is_empty():
			continue
		var bad := bool(slot.get("bad", false))
		var t := maxf(float(slot["t"][0]), float(slot["t"][1]))
		var down_t := float(slot["t"][int(slot["down"])])
		bars.append([down_t / 16.0, RULES.cheese_side(down_t, bad), RULES.cheese_side(t, bad) == 2])
	var b: Dictionary = s["basket"]
	if str(b["st"]) == "down":
		var bt := float(b["t"])
		bars.append([bt / 18.0, RULES.fries_state(bt), RULES.fries_state(bt) == 2])
	var w := 24.0
	var h := 4.0 + bars.size() * 4.0
	var r := Rect2(at - Vector2(w * 0.5, h + 12), Vector2(w, h)).abs()
	r.position = r.position.floor()
	draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.9))
	draw_rect(r, Color(0.2, 0.17, 0.14, 0.9))
	for i in bars.size():
		var bar: Array = bars[i]
		var col: Color = [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][int(bar[1])]
		draw_rect(Rect2(r.position.x + 2, r.position.y + 2 + i * 4, floorf((w - 4) * clampf(float(bar[0]), 0.0, 1.0)), 2), col)
	if bool(st["burning"]) and int(_t * 4.0) % 2 == 0:
		_text(Vector2(r.end.x + 3, r.position.y + 7), "!", RETRO_UI.C_RED_LIGHT, true)
	elif bool(st["ready"]):
		_text(Vector2(r.end.x + 3, r.position.y + 7), "!", RETRO_UI.C_GREEN_LIGHT, true)


## Puffs rising from `at`, in steps (the stove burning, the pot catching).
func _smoke(at: Vector2, tint: Color) -> void:
	var t: Texture2D = _tex.get("smoke")
	if t == null:
		return
	for i in 4:
		var age := fmod(_t * 0.5 + i * 0.25, 1.0)
		var p := at + Vector2(-10 + i * 7 + sin(age * 5.0 + i) * 4.0, -age * 40.0)
		draw_texture_rect(t, Rect2(p.floor(), t.get_size()), false, Color(tint.r, tint.g, tint.b, (1.0 - age) * 0.8))


func _pot(at: Vector2, pot: Dictionary) -> void:
	var level := int(pot["level"])
	var c := float(pot["catch"])
	if level > 0 and (c > 0.75 or kitchen.burnt_flash.has(key)):
		_smoke(at + Vector2(0, 30), Color(0.35, 0.33, 0.32))
	var warn := level > 0 and c > 0.6
	var label := str(level) if level > 0 else "EMPTY"
	if warn:
		label = "STIR"
	_badge(at, "mark_pot", label, warn or level == 0)
	if level > 0:
		var r := Rect2(at + Vector2(-12, 2), Vector2(24, 3)).abs()
		r.position = r.position.floor()
		draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.9))
		draw_rect(Rect2(r.position, Vector2(floorf(r.size.x * c), r.size.y)), RETRO_UI.C_RED if c > 0.6 else RETRO_UI.C_AMBER_DIM)


## An icon on a little plate with a word or a number; `alarm` blinks it red.
func _badge(at: Vector2, icon: String, text: String, alarm: bool) -> void:
	var ic: Texture2D = _tex.get(icon)
	var tw := RETRO_UI.FONT_LABEL.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var iw := float(ic.get_width()) if ic != null else 0.0
	var ih := float(ic.get_height()) if ic != null else 10.0
	var w := iw + tw + (6.0 if ic != null else 4.0)
	var h := maxf(ih, 10.0) + 2.0
	var bob := 1.0 if int(_t * 3.0) % 2 == 0 else 0.0
	var r := Rect2(at - Vector2(w * 0.5, h + 4 + bob), Vector2(w, h)).abs()
	r.position = r.position.floor()
	var on := not alarm or int(_t * 4.0) % 2 == 0
	draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.03, 0.92))
	draw_rect(r, RETRO_UI.C_RED_DARK if alarm and on else Color(0.2, 0.17, 0.14, 0.92))
	var x := r.position.x + 2
	if ic != null:
		draw_texture_rect(ic, Rect2(Vector2(x, r.position.y + 1), ic.get_size()), false)
		x += iw + 2
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
