extends "res://scripts/closeup/closeup_view.gd"

## The Liblice Bulletin read up close (the bag's "newspaper", bought at the Jednota or the
## kiosk): one page of cheap newsprint, the parish's masthead, a photograph and a handful
## of short notices set in three columns. Which notices and which photograph go by the issue
## (the day it came out, the item's "n"): two papers of one day are the same paper, and what
## you bought last week still says what it said. Nobody explains anything: it is a village
## paper. Any click puts it away.

const SHOP := "res://assets/textury/shop/"
const SFX := "res://assets/sfx/shop/"
const PAPER := Color(0.8, 0.76, 0.66)
const INK := Color(0.13, 0.12, 0.11)
const INK_SOFT := Color(0.13, 0.12, 0.11, 0.8)
const COL_X := [10.0, 113.0, 216.0]
const COL_W := 94.0
const TOP := 62.0
const BOTTOM := 270.0
const LINE_H := 9.0
## A notice: its heading and its text. An issue prints a few of them.
const NOTICES := [
	["FROM THE COUNCIL", "The pond will not be drained this year either. Whoever opened the sluice on the ninth is asked to shut it again."],
	["LOST", "Brown dog, answers to Bobik. Found: a brown collar, still buckled, on the chapel step. If he is yours do not call him after dark."],
	["THE 380", "The 380 keeps to its timetable. Passengers are reminded not to wave at the cross. The driver has been told not to stop there."],
	["THANKS", "Mrs Hruba thanks whoever mended her fence in the night. She did not ask anybody. She would like it to stop."],
	["BREAD", "The Tuesday van came on Wednesday too and nobody can say who ordered it. It was empty. The driver did not get out."],
	["ANNIVERSARIES", "Mr Vondra is 81. Mrs Novotna does not wish to say. Mr Hronek would have been 90 on Sunday; his table is still laid."],
	["THE MOTEL", "Mr Simek asks his guests not to answer the telephone in number four. It is not connected."],
	["THE CAMP", "The camp on the lake has a new warden. We wish the new warden well. We wished the last one well."],
	["THE CHAPEL", "St Prokop will be cleaned before his feast. Whoever keeps turning him to the wall is asked to leave him as he is."],
	["THE PUB", "Mr Kubat reminds the public that the cellar is not open to guests, and that nobody is being kept there."],
	["ROAD 12", "The verge by the Benzina will be mended. Mr Lojza reports the same car at the pumps three nights running, nobody in it."],
	["WEATHER", "Fog over the fields until further notice. Those walking to Pristoupim should count the poles. There are eleven."],
	["THE SILO", "The JZD silo is shut and its cellar filled in, whatever people say. Children will stop listening at the hatch."],
	["FOUND", "A child's sandal in the reeds by the camp's jetty. It has been there a long time. No child in the village has a foot that size."],
	["THE PARISH", "Candles are now a dollar. The box by the door was full again this week. Nobody has been seen putting anything in it."],
	["SMALL ADS", "For sale: pram, as new, used once. Wanted: somebody to sit in the Hronek house at night. Pay by arrangement."],
]
## The photographs (shop/news_photo_<i>.png) and what is printed under them.
const CAPTIONS := [
	"The pond on Sunday. Mr Vondra cannot say who that is on the far bank.",
	"The chapel after the rain. The door was shut when this was taken.",
	"In the field by Pristoupim, last Thursday. Nobody remembers the occasion.",
]
const ISSUE_NOTICES := 7

var _paper: Texture2D
var _photo: Texture2D
var _issue := 1
## Laid out for this issue: {"x", "y", "text", "head"} lines, the photograph's place.
var _lines: Array = []
var _photo_at := Vector2.ZERO
var _photo_size := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_paper = load(SHOP + "newsprint.png") if ResourceLoader.exists(SHOP + "newsprint.png") else null


## The issue of day `issue`.
func read(issue: int) -> void:
	_issue = maxi(1, issue)
	_set_page()
	open_view()
	play(SFX + "paper_open.mp3", -3.0)


func _closing() -> void:
	play(SFX + "paper_shut.mp3", -3.0)


## Which notices this issue prints, set in the shortest column each.
func _set_page() -> void:
	_lines.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _issue * 7919 + 31
	var order: Array = []
	for i in NOTICES.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var y := [TOP, TOP, TOP]
	var which := _issue % CAPTIONS.size()
	var path := SHOP + "news_photo_%d.png" % which
	_photo = load(path) if ResourceLoader.exists(path) else null
	if _photo != null:
		# Under the masthead in the middle column, with its caption.
		_photo_size = Vector2(COL_W, floorf(COL_W * float(_photo.get_height()) / float(_photo.get_width())))
		_photo_at = Vector2(COL_X[1], TOP)
		y[1] = TOP + _photo_size.y + 3.0
		for line in _wrap(tr(CAPTIONS[which]), RETRO_UI.FONT_TEXT, 8, COL_W):
			_lines.append({"x": COL_X[1], "y": y[1] + 7.0, "text": line, "head": false, "soft": true})
			y[1] += LINE_H
		y[1] += 8.0
	for k in ISSUE_NOTICES:
		var n: Array = NOTICES[order[k]]
		var col := 0
		for c in 3:
			if y[c] < y[col]:
				col = c
		var head := tr(str(n[0]))
		var body: Array = _wrap(tr(str(n[1])), RETRO_UI.FONT_TEXT, 8, COL_W)
		var needs: float = 10.0 + float(body.size()) * LINE_H
		if y[col] + needs > BOTTOM:
			continue
		_lines.append({"x": COL_X[col], "y": y[col] + 7.0, "text": head, "head": true})
		y[col] += 11.0
		for line in body:
			_lines.append({"x": COL_X[col], "y": y[col] + 7.0, "text": line, "head": false})
			y[col] += LINE_H
		y[col] += 9.0


func _hotspots() -> Array:
	return [{"id": "page", "rect": Rect2(0, 0, W, H)}]


func _clicked(_id: String) -> void:
	close_view()


## The whole plate is the page: no strip of what is said under it.
func _draw_strip(_c: Control) -> void:
	pass


func _paint(c: Control) -> void:
	var page := Rect2(0, 0, W, H)
	if _paper != null:
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		c.draw_texture_rect(_paper, page, true)
	else:
		c.draw_rect(page, PAPER)
	var big: Font = RETRO_UI.FONT_BIG
	var head := tr("LIBLICE BULLETIN")
	# The Czech name is longer: a size down if it does not fit the page.
	var size := 30
	var hw := big.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if hw > W - 20.0:
		size = 20
		hw = big.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ink(c, big, Vector2(floorf((W - hw) * 0.5), 32.0), head, INK, Color(0, 0, 0, 0), size)
	c.draw_rect(Rect2(10, 39, W - 20, 1), INK)
	c.draw_rect(Rect2(10, 51, W - 20, 1), INK)
	var f: Font = RETRO_UI.FONT_TEXT
	ink(c, f, Vector2(10, 48), (tr("No. %d") % _issue) + "    " + Season.date_str(_issue), INK)
	var right := tr("Published by the parish council")
	ink(c, f, Vector2(W - 10 - f.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 48), right, INK)
	for x in [COL_X[1] - 5.0, COL_X[2] - 5.0]:
		c.draw_rect(Rect2(x, TOP - 4.0, 1, BOTTOM - TOP + 6.0), Color(INK, 0.5))
	if _photo != null:
		c.draw_texture_rect(_photo, Rect2(_photo_at, _photo_size), false)
	for l in _lines:
		var at := Vector2(float(l["x"]), float(l["y"]))
		if bool(l["head"]):
			ink(c, RETRO_UI.FONT_LABEL, at, str(l["text"]), INK)
		else:
			ink(c, f, at, str(l["text"]), INK_SOFT if bool(l.get("soft", false)) else INK)

