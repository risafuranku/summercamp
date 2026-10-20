extends "res://scripts/closeup/closeup_view.gd"

## A look in through the Hronek ruin's doorway (Pristoupim, hamlet_trip.gd "ham_ruin"):
## the kitchen with no roof over its back, a table laid for one, the chair turned to the
## wall, the tiled stove, a Jednota calendar, and the back doorway into the dark
## (Grok closeup_ruin.png). The Hronek boy went fishing at the lake in eighty-four and
## did not come back (old Vacek tells it on the bus): look long enough and for a moment
## something small and wet stands in that back doorway (Grok ruin_boy.png), a child
## humming. Not every time. After the first time the chair faces the door.

const PIC := "res://assets/textury/town/closeup_ruin.png"
const BOY := "res://assets/textury/town/ruin_boy.png"
const SFX_HUM := "res://assets/sfx/npc/child_hum.mp3"
const SFX_BRUSH := "res://assets/sfx/director/wall_brush.mp3"
const SFX_CREAK := "res://assets/sfx/hamlet/ruin_creak.mp3"
const PLATE := Rect2(148, 128, 32, 16)
const CHAIR := Rect2(206, 120, 40, 74)
const CALENDAR := Rect2(164, 58, 26, 34)
const DOORWAY := Rect2(112, 56, 40, 74)
const STOVE := Rect2(232, 54, 52, 100)
## Where the boy's feet are (the doorway's floor) in picture pixels.
const BOY_FEET := Vector2(131, 129)

## The hamlet's state (hamlet_trip.gd): "ruin" counts the times you have looked in.
var state: Dictionary = {}
var _boy: Texture2D
var _t := 0.0
## When the boy shows this time (seconds after opening; -1 not this time) and for how long.
var _boy_at := -1.0
var _boy_shown := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_boy = load(BOY) if ResourceLoader.exists(BOY) else null
	_rng.randomize()


func _visits() -> int:
	return int(state.get("ruin", 0))


func _opened() -> void:
	_t = 0.0
	_boy_shown = false
	# The first look always; after that now and then.
	_boy_at = _rng.randf_range(3.5, 5.0) if _visits() == 0 or _rng.randf() < 0.3 else -1.0
	play(SFX_CREAK, -8.0)
	if _visits() == 0:
		say("", "The Hronek kitchen. No roof over the back of it. Somebody has laid the table.", false)
	else:
		say("", "The Hronek kitchen. The chair is turned to face the door now. To face you.", false)
	state["ruin"] = _visits() + 1


func _hotspots() -> Array:
	return [{"id": "plate", "rect": PLATE}, {"id": "chair", "rect": CHAIR}, {"id": "calendar", "rect": CALENDAR},
		{"id": "doorway", "rect": DOORWAY}, {"id": "stove", "rect": STOVE}]


func _clicked(id: String) -> void:
	match id:
		"plate":
			say("", "One plate, clean. The fork beside it, the way you lay it for a child. The dust is on everything but the plate.", false)
		"chair":
			if _visits() <= 1:
				say("", "The chair is turned to face the wall, as if somebody sat there being punished. Or waiting.", false)
			else:
				say("", "The chair faces the door. You did not move it.", false)
		"calendar":
			say("", "A Jednota calendar, 1984. August. The days crossed out up to the fourteenth in a child's hand. After that, nothing.", false)
		"stove":
			say("", "Cold. But it smells of wet ash, fresh.", false)
		"doorway":
			if _boy_shown:
				say("", "Nothing there now. The floor in the doorway is wet, and there is lake weed on the threshold.", false)
			else:
				say("", "The back room. Too dark to see into. It goes on further than the house does.", false)


func _tick(delta: float) -> void:
	_t += delta
	if _boy_at >= 0.0 and not _boy_shown and _t >= _boy_at:
		_boy_shown = true
		play(SFX_HUM, -14.0)
		play(SFX_BRUSH, -10.0)
	# He is there for a moment, then the strip says what you think you saw.
	if _boy_shown and _t >= _boy_at + 0.75 and _t < _boy_at + 0.75 + delta * 1.5:
		say("", "Something stood in the back doorway. Small. Wet. Then it did not.", false)


func _paint(c: Control) -> void:
	if _boy == null or not _boy_shown or _t > _boy_at + 0.75:
		return
	# In the dark of the doorway, his feet on its floor, darker than the room.
	var size := _boy.get_size()
	c.draw_texture_rect(_boy, Rect2(BOY_FEET - Vector2(size.x * 0.5, size.y), size), false, Color(0.62, 0.64, 0.66, 0.92))
