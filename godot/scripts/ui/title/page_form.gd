extends RefCounted

## A new camp as a form on the counter (a title_desk.gd page; main_menu.gd's NEW CAMP and
## the co-op page's new camp): the district's application printed on the striped computer
## paper of the day (assets/textury/desk/booking.png, twice its pixels), the camp's name
## and its seed written into it, STORY or SANDBOX circled in red, a sandbox camp's rules
## ticked in pencil boxes. The rubber stamp beside it makes the camp: it comes down on
## the form, APPROVED in red, and the camp is made (main_menu.new_camp_requested). For
## co-op either: a story camp's mails and checklist are the host's, everyone sees them.

const PAPER := "res://assets/textury/desk/booking.png"
const STAMP := "res://assets/textury/desk/stamp.png"
const SFX_STAMP := "res://assets/sfx/desk/stamp.mp3"
const SFX_PEN := "res://assets/sfx/desk/pen.mp3"
const FORM_AT := Vector2(64, 14)
const FORM_K := 2
## On the form (native px of the counter): the lines written on.
const X := 92.0
const Y0 := 40.0
const PITCH := 11.0
const STAMP_AT := Vector2(318, 120)
const RULES := ["threats", "weather", "events", "wear", "money"]
const RULE_TEXT := {"threats": "Nights", "weather": "Weather", "events": "Day events", "wear": "Breakdowns", "money": "Money"}
## The nights' row, stepped by a click (25. 11. „Tři stupně“): off, then quiet, usual, bad
## (rules "threats" off, or on with "nights" 0..2: night_swell.SEVERITY_*).
const NIGHT_WORD := ["Nights off", "Quiet nights", "Usual nights", "Bad nights"]
## The sandbox's starting till, stepped by a click (0: the game's own).
const MONEY := [0, 2500, 5000, 10000, 50000]

const PROFILES = preload("res://scripts/profiles.gd")
const CAMP_TEXT = preload("res://scripts/ui/title/camp_text.gd")
const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")

var menu
var desk
var sandbox := false
var rules: Dictionary = {}
var _name: LineEdit
var _seed: LineEdit
var _stamped := -1.0


func _init(main_menu, title_desk) -> void:
	menu = main_menu
	desk = title_desk


func opened() -> void:
	sandbox = false
	rules = {"threats": true, "weather": true, "events": true, "wear": true, "money": 0, "nights": 1}
	_stamped = -1.0
	_name = desk.field(Rect2(X + 58, Y0 + PITCH * 1 - 8, 96, 10))
	_name.text = PROFILES.default_camp_name()
	_name.max_length = 24
	_seed = desk.field(Rect2(X + 58, Y0 + PITCH * 2 - 8, 96, 10), tr("Random"))
	_seed.max_length = 20
	_name.text_submitted.connect(func(_t: String) -> void: _seed.grab_focus())
	_seed.text_submitted.connect(func(_t: String) -> void: click("stamp"))
	_name.grab_focus()
	_name.select_all()


func _flip(id: String) -> void:
	if id == "money":
		var i := MONEY.find(int(rules.get("money", 0)))
		rules["money"] = MONEY[(i + 1) % MONEY.size()]
	elif id == "threats":
		var step := (_night_step() + 1) % NIGHT_WORD.size()
		rules["threats"] = step > 0
		rules["nights"] = maxi(0, step - 1)
	else:
		rules[id] = not bool(rules.get(id, true))


## The camp made: its name (the warden's next if left empty), its seed (a number is the
## seed itself, words make one: the same words, the same camp), its mode and rules.
func _make() -> void:
	var name := _name.text.strip_edges()
	if name == "":
		name = PROFILES.default_camp_name()
	var seed_txt := _seed.text.strip_edges()
	var seed := 0
	if seed_txt != "":
		seed = int(seed_txt) if seed_txt.is_valid_int() else absi(seed_txt.hash())
		seed = (seed & 0x7fffffff) | 1
	_name.release_focus()
	_seed.release_focus()
	var sb: bool = sandbox
	menu.new_camp_requested.emit(name, seed, menu.for_coop, sb, rules.duplicate() if sb else {})


func _row(i: int) -> float:
	return Y0 + PITCH * float(i)


func hotspots() -> Array:
	var out: Array = []
	out.append({"id": "story", "rect": Rect2(X + 30, _row(4) - 8, 46, 11)})
	out.append({"id": "sandbox", "rect": Rect2(X + 84, _row(4) - 8, 56, 11)})
	if sandbox:
		for i in RULES.size():
			out.append({"id": "rule:" + str(RULES[i]), "rect": Rect2(X - 2, _row(7 + i) - 8, 150, 11)})
	out.append({"id": "stamp", "rect": Rect2(STAMP_AT, Vector2(84, 76))})
	out.append({"id": "back", "rect": desk.tape_rect(Vector2(430, 242), tr("Back"))})
	return out


func click(id: String) -> void:
	if id.begins_with("rule:"):
		_flip(id.trim_prefix("rule:"))
		desk.play(SFX_PEN, -10.0)
		return
	match id:
		"story":
			sandbox = false
			desk.play(SFX_PEN, -10.0)
		"sandbox":
			sandbox = true
			desk.play(SFX_PEN, -10.0)
		"stamp":
			if _stamped >= 0.0:
				return
			_stamped = 0.0
			desk.play(SFX_STAMP, -4.0)
			desk.redraw()
			# The red APPROVED seen on the form a moment, then the camp is made.
			desk.get_tree().create_timer(0.45).timeout.connect(func() -> void:
				if desk.page == self:
					_make())
		"back":
			menu.show_page("coop" if menu.for_coop else "main")


## The nights' row as it stands: 0 off, 1 quiet, 2 usual, 3 bad.
func _night_step() -> int:
	return 0 if not bool(rules.get("threats", true)) else 1 + clampi(int(rules.get("nights", 1)), 0, 2)


func key(_event: InputEvent) -> bool:
	return false


func paint(d, c: Control) -> void:
	var paper: Texture2D = d.tex(PAPER)
	if paper != null:
		var r := Rect2(FORM_AT, paper.get_size() * FORM_K)
		c.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
		c.draw_texture_rect(paper, r, false)
	d.text(c, Vector2(X, _row(0) - 2), tr("APPLICATION FOR A CAMP"), d.RED)
	d.text(c, Vector2(X, _row(1)), tr("CAMP NAME"), d.PENCIL)
	d.text(c, Vector2(X, _row(2)), tr("Seed").to_upper(), d.PENCIL)
	# The field's line to write on.
	for i in [1, 2]:
		c.draw_rect(Rect2(X + 58, _row(i) + 2, 96, 1), Color(d.PENCIL, 0.5))
	d.text(c, Vector2(X, _row(4)), tr("Mode").to_upper(), d.PENCIL)
	_choice(d, c, Vector2(X + 32, _row(4)), tr("Story").to_upper(), not sandbox, false, "story")
	_choice(d, c, Vector2(X + 86, _row(4)), tr("Sandbox").to_upper(), sandbox, false, "sandbox")
	if sandbox:
		for i in RULES.size():
			var id: String = RULES[i]
			var y := _row(7 + i)
			if id == "money":
				var m := int(rules.get("money", 0))
				d.text(c, Vector2(X + 12, y), tr(str(RULE_TEXT[id])).to_upper(), d.INK)
				d.text(c, Vector2(X + 100, y), "$" + CAMP_TEXT.money(m if m > 0 else BALANCE_CONFIG.STARTING_MONEY), d.INK)
			elif id == "threats":
				var st := _night_step()
				d.text(c, Vector2(X + 12, y), tr(str(RULE_TEXT[id])).to_upper(), d.INK)
				d.text(c, Vector2(X + 100, y), tr(str(NIGHT_WORD[st])).to_upper(), d.INK if st > 0 else d.PENCIL)
			else:
				var on := bool(rules.get(id, true))
				var box := Rect2(X, y - 7, 7, 7)
				c.draw_rect(box, Color(d.PENCIL, 0.8), false, 1.0)
				if on:
					c.draw_line(box.position + Vector2(1, 4), box.position + Vector2(3, 6), Color8(26, 100, 36), 1.0)
					c.draw_line(box.position + Vector2(3, 6), box.position + Vector2(7, 0), Color8(26, 100, 36), 1.0)
				d.text(c, Vector2(X + 12, y), tr(str(RULE_TEXT[id])).to_upper(), d.INK if on else d.PENCIL)
			if d.hovered() == "rule:" + id:
				c.draw_rect(Rect2(X + 12, y + 1, 120, 1), d.RED)
	# The stamp beside the form, and what it leaves.
	var stamp: Texture2D = d.tex(STAMP)
	var lift := Vector2(0, -3) if d.hovered() == "stamp" and _stamped < 0.0 else Vector2.ZERO
	if stamp != null:
		c.draw_texture_rect(stamp, Rect2(STAMP_AT + Vector2(6, 8), stamp.get_size() * 2), false, Color(0, 0, 0, 0.3))
		c.draw_texture_rect(stamp, Rect2(STAMP_AT + lift, stamp.get_size() * 2), false)
	if _stamped >= 0.0:
		var sr := Rect2(X + 40, _row(13) - 12, 92, 18)
		c.draw_rect(sr, Color(0.72, 0.1, 0.08, 0.85), false, 2.0)
		var s := tr("APPROVED")
		d.text(c, Vector2(sr.position.x + (sr.size.x - d.text_w(s)) * 0.5, sr.position.y + 12), s, Color(0.72, 0.1, 0.08, 0.9))
	d.tape(c, Vector2(430, 242), tr("Back"), "back")


## One of two words to circle: the chosen one in a red ring, the other plain (greyed when
## it cannot be chosen).
func _choice(d, c: Control, pos: Vector2, s: String, on: bool, off: bool, id: String) -> void:
	var w: float = d.text_w(s)
	d.text(c, pos, s, d.PENCIL if off else d.INK)
	if on:
		c.draw_rect(Rect2(pos.x - 3, pos.y - 9, w + 6, 12), d.RED, false, 1.0)
	elif d.hovered() == id and not off:
		c.draw_rect(Rect2(pos.x - 1, pos.y + 1, w + 2, 1), d.RED)
