extends "res://scripts/closeup/closeup_view.gd"

## Mr Hruby's logbook, on the table inside the boathouse door (scripts/lake/lake_trip.gd):
## the lake keeper's notes, water levels and the sluice, until the summer of 1993 when
## the new pipes went in. Click the right page to turn on, the left one to turn back.

const PIC := "res://assets/textury/closeup/logbook.png"
## The two pages on the picture (px): where the writing goes.
const LEFT_PAGE := Rect2(70, 40, 76, 118)
const RIGHT_PAGE := Rect2(156, 38, 82, 112)
const SFX_PAGE := "res://assets/sfx/rooms/task_litter.mp3"

## Spreads: [left page, right page].
const PAGES := [
	["LAKE BOOK\nCerne jezero\nreservoir & sluice\n\nP. Hruby, keeper\nfrom 1979", "12.4.\nlevel 4.10\nsluice shut. ice gone\nfrom the bay.\n\n30.4.\nlevel 4.22\noiled the gate.\nboats out of the shed"],
	["19.6.\nlevel 4.30\ncamp open. Karel's\nkids on the jetty\nagain. told them.\n\n2.7.\nlevel 4.31\nsomeone moved the\nboat in the night.\nrope cut clean.", "14.8.87\nthe girl. we went\nalong the shore with\nlamps till four.\nnothing.\n\nthe water stood\nvery still all night\nlike it was holding\nits breath."],
	["3.5.93\nlevel 4.05\nthe water board is\nputting new pipes\nunder the camp.\nthe old ones are\nfull of what the\nlake gave back.", "21.5.93\nthey knock. inside\nthe old pipes, from\nfar along. three\ntimes. the workmen\nlaugh. I knocked\nback once. I should\nnot have."],
	["1.6.93\nit answers the\nhammer now. it\ncomes to the noise.\nkeep the lamp on it\nand it goes.\n\nit cannot see.\nI am almost sure.", "2.6.93\nthey are pulling\nthe last old pipe\ntomorrow. I said I\nwould go down with\nthem and look.\n\nif it knocks three\ntimes it is not\nthe water."],
	["", "\n\n\n\n     (nothing after\n      this. the rest\n      of the pages\n      are swollen\n      with damp.)"],
]

var _spread := 0


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func _opened() -> void:
	_spread = 0
	say("", "", false)


func _hotspots() -> Array:
	return [{"id": "left", "rect": LEFT_PAGE}, {"id": "right", "rect": RIGHT_PAGE}]


func _clicked(id: String) -> void:
	if id == "right" and _spread < PAGES.size() - 1:
		_spread += 1
		play(SFX_PAGE, -12.0)
	elif id == "left" and _spread > 0:
		_spread -= 1
		play(SFX_PAGE, -12.0)


func _key(event: InputEventKey) -> bool:
	if event.physical_keycode in [KEY_RIGHT, KEY_D, KEY_SPACE]:
		_clicked("right")
		return true
	if event.physical_keycode in [KEY_LEFT, KEY_A]:
		_clicked("left")
		return true
	return false


func _paint(c: Control) -> void:
	var ink := Color(0.16, 0.14, 0.22, 0.92)
	var font: Font = RETRO_UI.FONT_TEXT
	var spread: Array = PAGES[_spread]
	for side in 2:
		var r: Rect2 = LEFT_PAGE if side == 0 else RIGHT_PAGE
		var lines := str(spread[side]).split("\n")
		for i in lines.size():
			c.draw_string(font, Vector2(r.position.x + 4, r.position.y + 10 + i * 9), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	if hovered() == "right" and _spread < PAGES.size() - 1:
		c.draw_rect(Rect2(RIGHT_PAGE.end.x - 10, RIGHT_PAGE.end.y - 10, 10, 10), Color(1, 0.9, 0.6, 0.25))
	if hovered() == "left" and _spread > 0:
		c.draw_rect(Rect2(LEFT_PAGE.position.x, LEFT_PAGE.end.y - 10, 10, 10), Color(1, 0.9, 0.6, 0.25))
