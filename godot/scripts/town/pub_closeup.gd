extends "res://scripts/closeup/closeup_view.gd"

## Hostinec U Jezera in Lesna, across the bar (Grok picture; Mr Kubat drawn in behind it).
##   - the tap: a dollar, he draws you a Lesnak, the mug lands in front of you; click it to
##     drink (three pulls, then it is empty and you feel it: pockets.gd `drunk`);
##   - the fruit machine in the corner: a dollar a go, three reels that spin in steps and
##     stop one by one; three alike pay (sevens best), two cherries give your dollar back;
##   - Mr Kubat: talk.
## Open 10:00-23:00.

signal drank

const PIC := "res://assets/textury/town/closeup_pub.png"
const HIM := "res://assets/textury/npc/town_landlord.png"
const SFX_PUB := "res://assets/sfx/pub/"
const SFX_TOWN := "res://assets/sfx/town/"
const SFX_COIN := "res://assets/sfx/bus/coin.mp3"
const TAP := Rect2(232, 110, 46, 82)
const MACHINE := Rect2(8, 66, 66, 104)
const HIM_RECT := Rect2(124, 50, 72, 118)
const BAR_Y := 170.0
const MUG := Rect2(136, 176, 40, 44)
const LINES := [
	"Kitchen's shut. The cellar is not open to guests.",
	"Karbanatky to our own recipe. What is in them is the recipe.",
	"If you have meat to sell, regular, any quantity, come round the back.",
	"Your Vera sat where you are standing. Every Friday. Then one Friday she didn't, and she had not missed one in eleven years.",
	"The machine pays. Not often. Like everything here.",
]
## The fruit machine (Grok, assets/textury/closeup/): the red cabinet, the bulbs round the
## top, the symbols on the reels, the START button.
const ART := "res://assets/textury/closeup/"
const REEL := ["cherry", "plum", "bell", "bar", "seven", "plum", "cherry", "bell", "plum", "cherry"]
const PAYS := {"seven": 30, "bar": 15, "bell": 8, "plum": 5, "cherry": 4}
const SLOT := Rect2(70, 30, 180, 150)

var _him: Texture2D
var _line := 0
var _mug := 0              # pulls left in the mug in front of you (0: none)
var _slot := false         # the machine is up close
var _reels := [0, 0, 0]
var _spin_t := -1.0
var _stops := [0.0, 0.0, 0.0]
var _rng := RandomNumberGenerator.new()
var _lamp_t := 0.0
var _won := 0
## Opened from the 3D pub (town_room.gd) for the machine alone.
var slot_only := false


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_him = load(HIM) if ResourceLoader.exists(HIM) else null
	_rng.randomize()


func _opened() -> void:
	_slot = false
	_spin_t = -1.0
	if slot_only:
		return
	say("Mr Kubat", "Sit where you like. Beer's a dollar.")


## The fruit machine in the 3D pub, up close.
func open_slot() -> void:
	slot_only = true
	picture = null
	open_view()
	_slot = true
	say("", "LUCKY 7. Somebody has scratched the 7 off the glass and drawn it back on in pen.")


func _hotspots() -> Array:
	if _slot:
		return [{"id": "spin", "rect": Rect2(SLOT.position.x + 50, SLOT.end.y - 30, 80, 22)},
			{"id": "slot_back", "rect": Rect2(SLOT.end.x - 18, SLOT.position.y + 4, 14, 12)}]
	var out: Array = [{"id": "tap", "rect": TAP}, {"id": "machine", "rect": MACHINE}, {"id": "him", "rect": HIM_RECT}]
	if _mug > 0:
		out.push_front({"id": "mug", "rect": MUG})
	return out


func _clicked(id: String) -> void:
	match id:
		"him":
			_line += 1
			say("Mr Kubat", LINES[_line % LINES.size()])
		"tap":
			if _mug > 0:
				say("Mr Kubat", "Finish that one first.")
				return
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				say("Mr Kubat", "A dollar. I do not run a tab for the camp. Not any more.")
				return
			play(SFX_PUB + "tap_pour.mp3", -4.0)
			_mug = 3
			say("Mr Kubat", "Na zdravi.")
		"mug":
			play(SFX_TOWN + "gulp.mp3", -4.0)
			_mug -= 1
			if _mug == 0:
				play(SFX_PUB + "glass_down.mp3", -6.0)
				drank.emit()
		"machine":
			_slot = true
		"slot_back":
			if _spin_t < 0.0:
				_slot = false
				if slot_only:
					close_view()
		"spin":
			_spin()


func _spin() -> void:
	if _spin_t >= 0.0:
		return
	if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
		say("", "The machine wants a dollar.")
		return
	play(SFX_COIN, -6.0)
	_won = 0
	_spin_t = 0.0
	_stops = [_rng.randf_range(0.9, 1.2), _rng.randf_range(1.5, 1.9), _rng.randf_range(2.2, 2.7)]
	say("", "")


func _tick(delta: float) -> void:
	_lamp_t += delta
	if _spin_t < 0.0:
		return
	_spin_t += delta
	var step := int(floorf(_spin_t * 12.0))
	var all_stopped := true
	for i in 3:
		if _spin_t < float(_stops[i]):
			_reels[i] = (step * (3 + i) + i * 4) % REEL.size()
			all_stopped = false
	if all_stopped:
		_spin_t = -1.0
		_pay()


func _pay() -> void:
	var a: String = REEL[_reels[0]]
	var b: String = REEL[_reels[1]]
	var c: String = REEL[_reels[2]]
	var win := 0
	if a == b and b == c:
		win = int(PAYS.get(a, 0))
	elif [a, b, c].count("cherry") >= 2:
		win = 1
	_won = win
	if win > 0:
		CoreRoot.actions.add_money(win)
		play(SFX_PUB + "coins_bar.mp3", -2.0)
		say("", "The machine rattles out %d dollar%s." % [win, "" if win == 1 else "s"])
	else:
		say("", "Nothing. The lamps go round anyway.")


func _paint(c: Control) -> void:
	if slot_only:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.12, 0.09, 0.08))
		_paint_slot(c)
		return
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.2, 0.15, 0.1))
	if _him != null:
		var size := Vector2(_him.get_width(), _him.get_height())
		var pos := Vector2(HIM_RECT.get_center().x - size.x * 0.5, BAR_Y + 18.0 - size.y)
		var vis := BAR_Y - pos.y
		c.draw_texture_rect_region(_him, Rect2(pos.floor(), Vector2(size.x, vis)), Rect2(0, 0, size.x, vis))
		if picture != null:
			c.draw_texture_rect_region(picture, Rect2(110, BAR_Y - 2, 110, 10), Rect2(110, BAR_Y - 2, 110, 10))
	# The machine's lamps chase round, in steps.
	var lamp := int(floorf(_lamp_t * 6.0)) % 4
	var lamps := [Vector2(32, 126), Vector2(46, 126), Vector2(58, 126), Vector2(46, 138)]
	c.draw_rect(Rect2(lamps[lamp] - Vector2(2, 2), Vector2(5, 5)), Color(1.0, 0.95, 0.6, 0.85))
	if _mug > 0:
		var fill := float(_mug) / 3.0
		c.draw_rect(Rect2(MUG.position + Vector2(4, 6), Vector2(MUG.size.x - 10, MUG.size.y - 8)), Color(0.85, 0.88, 0.86, 0.5))
		var beer_h := (MUG.size.y - 12) * fill
		c.draw_rect(Rect2(MUG.position.x + 6, MUG.end.y - 4 - beer_h, MUG.size.x - 14, beer_h), Color(0.78, 0.5, 0.12))
		c.draw_rect(Rect2(MUG.position.x + 6, MUG.end.y - 6 - beer_h, MUG.size.x - 14, 4), Color(0.96, 0.94, 0.88))
		c.draw_rect(Rect2(MUG.end.x - 6, MUG.position.y + 14, 5, 16), Color(0.85, 0.88, 0.86, 0.6), false, 2.0)
	if hovered() != "" and not _slot:
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.12))
	if _slot:
		_paint_slot(c)


var _art: Dictionary = {}


func _a(name: String) -> Texture2D:
	if not _art.has(name):
		var path := ART + name + ".png"
		_art[name] = load(path) if ResourceLoader.exists(path) else null
	return _art[name]


func _paint_slot(c: Control) -> void:
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0, 0, 0, 0.5))
	c.draw_rect(Rect2(SLOT.position + Vector2(4, 5), SLOT.size), Color(0, 0, 0, 0.5))
	var cab := _a("slot_cabinet")
	if cab != null:
		c.draw_texture_rect(cab, SLOT, true)
	else:
		c.draw_rect(SLOT, Color(0.16, 0.12, 0.16))
	c.draw_rect(SLOT.grow(-3), Color(0.5, 0.1, 0.12), false, 2.0)
	ink(c, RETRO_UI.FONT_BIG, SLOT.position + Vector2(48, 22), "LUCKY  7", Color(1.0, 0.8, 0.2), Color(0, 0, 0, 0.8), 10)
	# The bulbs round the top, chasing.
	var lamp_on := _a("slot_lamp_on")
	var lamp_off := _a("slot_lamp_off")
	for i in 12:
		var on := (i + int(floorf(_lamp_t * 10.0))) % 3 == 0
		var lt: Texture2D = lamp_on if on else lamp_off
		var at := SLOT.position + Vector2(13 + i * 14, 30)
		if lt != null:
			c.draw_texture(lt, (at - lt.get_size() * 0.5).floor())
		else:
			c.draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), Color(1.0, 0.85, 0.3) if on else Color(0.35, 0.2, 0.1))
	for i in 3:
		var r := Rect2(SLOT.position + Vector2(18 + i * 50, 42), Vector2(44, 56))
		c.draw_rect(r, Color(0.95, 0.94, 0.88))
		c.draw_rect(r, Color(0.1, 0.1, 0.1), false, 1.0)
		var sym: String = REEL[_reels[i]]
		_draw_sym(c, r.get_center(), sym)
		# Blurred while spinning: a few lines through it.
		if _spin_t >= 0.0 and _spin_t < float(_stops[i]):
			for k in 4:
				c.draw_rect(Rect2(r.position.x + 2, r.position.y + 6 + k * 13, r.size.x - 4, 1), Color(0.3, 0.3, 0.3, 0.5))
	var btn := Rect2(SLOT.position.x + 50, SLOT.end.y - 30, 80, 22)
	var bt := _a("slot_button")
	var lit := hovered() == "spin"
	if bt != null:
		# Its chrome ends as they are, the red middle drawn out to the button's width.
		var cap := 8.0
		var tw := float(bt.get_width())
		var th := float(bt.get_height())
		var top := btn.position + Vector2(0, floorf((btn.size.y - th) * 0.5))
		var mod := Color(1.25, 1.2, 1.15) if lit else Color.WHITE
		c.draw_texture_rect_region(bt, Rect2(top, Vector2(cap, th)), Rect2(0, 0, cap, th), mod)
		c.draw_texture_rect_region(bt, Rect2(top + Vector2(cap, 0), Vector2(btn.size.x - cap * 2.0, th)), Rect2(cap, 0, tw - cap * 2.0, th), mod)
		c.draw_texture_rect_region(bt, Rect2(top + Vector2(btn.size.x - cap, 0), Vector2(cap, th)), Rect2(tw - cap, 0, cap, th), mod)
	else:
		c.draw_rect(btn, Color(0.8, 0.12, 0.1) if not lit else Color(0.95, 0.25, 0.2))
	ink(c, RETRO_UI.FONT_LABEL, btn.position + Vector2(14, 15), "$1  START", Color(1, 0.95, 0.85), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(SLOT.end.x - 18, SLOT.position.y + 4, 14, 12), Color(0.3, 0.3, 0.3))
	ink(c, RETRO_UI.FONT_LABEL, Vector2(SLOT.end.x - 14, SLOT.position.y + 13), "X", Color(1, 1, 1))
	if _won > 0 and _spin_t < 0.0 and int(floorf(_lamp_t * 4.0)) % 2 == 0:
		ink(c, RETRO_UI.FONT_BIG, SLOT.position + Vector2(62, 116), "WIN %d" % _won, Color(1.0, 0.85, 0.2), Color(0, 0, 0, 0.8), 10)


## The reel's symbol (reel_<name>.png) in the middle of its window.
func _draw_sym(c: Control, m: Vector2, s: String) -> void:
	var t := _a("reel_" + s)
	if t != null:
		c.draw_texture(t, (m - t.get_size() * 0.5).floor())
	if s == "bar":
		# The plate's lettering, printed white on the black.
		ink(c, RETRO_UI.FONT_LABEL, m + Vector2(-10, 4), "BAR", Color(1, 1, 1))