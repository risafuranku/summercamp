extends RefCounted

## The boy's face when you break his game's rule (DESIGN §5a.2; Richard 8. 11.: "ve stylu
## holky, tichomě"), in steps as every strike of the night and the same in all three of his
## games (corn_hunt.gd, breaker_panel.gd, pipes/pipe_boy.gd): his head comes round to you
## (the face drawn narrow and widening in four steps, a head turning), then it comes at you
## twitching with the shriek, the hit, and it goes dark.

## How long it is (s), the turn of his head, when the hit lands.
const LEN := 1.45
const TURN := 0.33
const HIT_AT := 1.0


## The face `t` s in: {"on", "w" and "h" (its size against the screen's height, 1 = all of
## it), "rot" (radians), "shake" (a share of the screen's height), "dark" (0-1 over it)}.
static func step(t: float) -> Dictionary:
	if t < 0.0 or t >= LEN:
		return {"on": false}
	var st := floorf(t * 12.0) / 12.0
	var n := int(st * 12.0)
	if st < TURN:
		var k := floorf(st / TURN * 4.0 + 1.0) / 4.0
		return {"on": true, "w": 0.72 * k, "h": 0.72, "rot": 0.2 * (1.0 - k), "shake": 0.004, "dark": 0.0}
	if st < HIT_AT:
		var k := (st - TURN) / (HIT_AT - TURN)
		var twitch := 0.07 if n % 4 == 1 else (-0.045 if n % 4 == 3 else 0.0)
		var s := lerpf(0.72, 1.45, k * k)
		return {"on": true, "w": s, "h": s * (1.0 + 0.06 * k), "rot": twitch, "shake": 0.008 + 0.02 * k, "dark": 0.0}
	var k := (st - HIT_AT) / (LEN - HIT_AT)
	return {"on": true, "w": 1.5, "h": 1.6, "rot": 0.0, "shake": 0.03 * (1.0 - k), "dark": k * k}


## The step laid on a full-screen TextureRect of the face (its own retro material): its
## size, its turn about its middle, the shake, how dark.
static func lay(rect: TextureRect, t: float, screen: Vector2) -> bool:
	var s := step(t)
	if not bool(s["on"]):
		rect.visible = false
		return false
	var size := Vector2(float(s["w"]), float(s["h"])) * screen.y
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * float(s["shake"]) * screen.y
	rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = size
	rect.pivot_offset = size * 0.5
	rect.position = ((screen - size) * 0.5 + shake).floor()
	rect.rotation = float(s["rot"])
	var d := 1.0 - float(s["dark"])
	rect.modulate = Color(d, d, d, 1.0)
	rect.visible = true
	return true
