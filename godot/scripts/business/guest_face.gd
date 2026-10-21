extends RefCounted

## A guest's face on their ticket (the brief of 21. 10.: "the customer's face with their
## mood on the ticket"), drawn in pixels like the status bar face of a Build game: 9 x 9
## of their own skin and hair (picked by their name, the same on every machine), and the
## mood as their patience goes: a smile while they are fresh, a flat mouth, then the brows
## down and the mouth turned, at the end red in the face and shouting (it shakes).
##   FACES.draw(c, at, k, left, name, t)   k: the pixel's size (1 on the rail, 2 big)

const SKIN := [Color(0.93, 0.76, 0.6), Color(0.85, 0.64, 0.48), Color(0.72, 0.52, 0.38), Color(0.96, 0.82, 0.7)]
const HAIR := [Color(0.25, 0.16, 0.1), Color(0.55, 0.36, 0.16), Color(0.82, 0.68, 0.36), Color(0.12, 0.1, 0.1), Color(0.55, 0.52, 0.5), Color(0.6, 0.22, 0.1)]
const INK := Color(0.12, 0.08, 0.07)
const RED := Color(0.75, 0.16, 0.1)

## The head's rows (9 wide): which pixels are face (1), hair (2), nothing (0).
const HEAD := [
	"022222220",
	"222222222",
	"211111112",
	"111111111",
	"111111111",
	"111111111",
	"111111111",
	"011111110",
	"001111100",
]


## The mood from patience left (0..1): 0 happy, 1 flat, 2 cross, 3 furious.
static func mood_of(left: float) -> int:
	if left > 0.6:
		return 0
	if left > 0.35:
		return 1
	if left > 0.15:
		return 2
	return 3


static func draw(c: Control, at: Vector2, k: int, left: float, name: String, t: float) -> void:
	var h := absi(hash(name))
	var skin: Color = SKIN[h % SKIN.size()]
	var hair: Color = HAIR[(h / 7) % HAIR.size()]
	var mood := mood_of(left)
	if mood >= 2:
		skin = skin.lerp(RED, 0.18 if mood == 2 else 0.38)
	var o := at
	if mood == 3:
		# Shaking with it.
		o.x += float([0, 1, 0, -1][int(t * 12.0) % 4]) * k
	var px := func(x: int, y: int, col: Color) -> void:
		c.draw_rect(Rect2(o + Vector2(x, y) * k, Vector2(k, k)), col)
	for y in HEAD.size():
		var row: String = HEAD[y]
		for x in row.length():
			match row[x]:
				"1":
					px.call(x, y, skin)
				"2":
					px.call(x, y, hair)
	# The eyes (a blink now and then while they are calm).
	var blink := mood <= 1 and int(t * 1.7 + float(h % 5)) % 9 == 0
	if not blink:
		px.call(2, 4, INK)
		px.call(6, 4, INK)
	else:
		px.call(2, 4, skin.darkened(0.3))
		px.call(6, 4, skin.darkened(0.3))
	# The brows: down to the middle when cross.
	if mood >= 2:
		px.call(1, 2, INK)
		px.call(2, 3, INK)
		px.call(7, 2, INK)
		px.call(6, 3, INK)
	# The mouth.
	match mood:
		0:
			px.call(2, 6, INK)
			px.call(3, 7, INK)
			px.call(4, 7, INK)
			px.call(5, 7, INK)
			px.call(6, 6, INK)
		1:
			for x in range(3, 6):
				px.call(x, 7, INK)
		2:
			px.call(2, 7, INK)
			px.call(3, 6, INK)
			px.call(4, 6, INK)
			px.call(5, 6, INK)
			px.call(6, 7, INK)
		3:
			px.call(3, 6, INK)
			px.call(4, 6, INK)
			px.call(5, 6, INK)
			px.call(3, 7, RED.darkened(0.4))
			px.call(4, 7, RED.darkened(0.4))
			px.call(5, 7, RED.darkened(0.4))
	# Red cheeks when cross.
	if mood >= 2:
		px.call(1, 5, RED)
		px.call(7, 5, RED)
