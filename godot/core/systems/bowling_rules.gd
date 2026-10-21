extends RefCounted

## Real ten-pin bowling (the user 21. 10.: "we want real bowling", in the camp's concrete
## hall with KUŽELKY in neon on the roof): the lane, the ten pins, the ball's way down the
## lane, what it takes down, and the score card. Pure data and arithmetic, seeded, so the
## same ball takes the same pins on every machine (co-op).
##
## The lane in metres: x across it from the middle (the bowler's left minus), z along it,
## the head pin at 0 and the foul line at +LANE_LEN. The pins by their numbers: 1 the head
## pin, 2 and 3 behind it, 4 5 6, and 7 8 9 10 in the back row, left to right as the
## bowler sees them.
##
##   roll(x0, aim, speed, hook)            the ball's way to the pins (or the gutter)
##   to_entry(x, angle, speed, hook)       the same backwards: where to let go for that
##   strike(entry, standing, seed)         the pins it takes down, and how they go
##   card(balls)                           frames, marks and the running total
##   guest_ball(skill, standing, rng)      a guest's ball

const LANE_W := 1.0541           # 41.5 in between the gutters
const GUTTER_W := 0.235
const LANE_LEN := 18.288         # foul line to the head pin, 60 ft
const OIL_LEN := 12.19           # the oil from the foul line, 40 ft: no hook on it
const PIN_SPACING := 0.3048      # 12 in between pin centres
const PIN_R := 0.0605            # the belly, 4.766 in across
const PIN_LYING_R := 0.075        # a pin down and tumbling sweeps more than its belly
const BALL_R := 0.1085           # 8.5 in across
const BALL_MASS := 6.5
const PIN_MASS := 1.55
## The side boards by the deck that throw the pins back in.
const KICKBACK_X := LANE_W * 0.5 + GUTTER_W
## Behind the back row: a pin past it is in the pit.
const PIT_Z := -1.15
## A standing pin knocked faster than this goes down; between WOBBLE and FALL it rocks
## and may go.
const FALL_SPEED := 0.34
const WOBBLE_SPEED := 0.1
const SIM_DT := 1.0 / 400.0
const SIM_SECONDS := 1.8
const PIN_FRICTION := 3.6        # m/s² a pin down slows by, sliding and tumbling
const BALL_FRICTION := 0.15

const FRAMES := 10


## The ten pins' spots: [Vector2(x, z)], index 0 is pin 1.
static func pin_spots() -> Array:
	var out: Array = []
	var row_dz := PIN_SPACING * sqrt(3.0) * 0.5
	for row in 4:
		for k in row + 1:
			out.append(Vector2((float(k) - float(row) * 0.5) * PIN_SPACING, -row_dz * float(row)))
	return out


# ── the ball's way down the lane ─────────────────────────────────────────────

## The ball let go at `x0` on the foul line, at `aim` (radians; plus toward +x), `speed`
## m/s, with `hook` (m/s² of sideways pull on the dry back end; minus pulls left). Returns
## {gutter: bool, x, angle, speed (at the head pin's row, or where it dropped), t (s),
## path: [Vector3(x, z, t)] every twentieth of a second}.
static func roll(x0: float, aim: float, speed: float, hook: float) -> Dictionary:
	var x := x0
	var z := LANE_LEN
	var vx := sin(aim) * speed
	var vz := cos(aim) * speed
	var t := 0.0
	var dt := 1.0 / 120.0
	var path: Array = [Vector3(x, z, 0.0)]
	var next_mark := 0.05
	while z > 0.0:
		if z < LANE_LEN - OIL_LEN:
			# The back end grips: the hook bites harder the slower and drier it gets.
			vx += hook * dt * clampf((LANE_LEN - OIL_LEN - z) / 4.0, 0.3, 1.0)
		vz = maxf(1.0, vz - BALL_FRICTION * dt)
		x += vx * dt
		z -= vz * dt
		t += dt
		if t >= next_mark:
			path.append(Vector3(x, z, t))
			next_mark += 0.05
		if absf(x) > LANE_W * 0.5:
			path.append(Vector3(signf(x) * (LANE_W * 0.5 + GUTTER_W * 0.5), z, t))
			return {"gutter": true, "x": x, "angle": atan2(vx, vz), "speed": sqrt(vx * vx + vz * vz), "t": t, "path": path}
	path.append(Vector3(x, 0.0, t))
	return {"gutter": false, "x": x, "angle": atan2(vx, vz), "speed": sqrt(vx * vx + vz * vz), "t": t, "path": path}


## Backwards from the pins: the ball that comes to the head pin's row at `x` with
## `angle` and `speed`, hooking `hook`: where it was let go and at what aim
## ({x0, aim, speed0}), so roll() of those comes out there (near enough).
static func to_entry(x: float, angle: float, speed: float, hook: float) -> Dictionary:
	var px := x
	var z := 0.0
	var vx := sin(angle) * speed
	var vz := cos(angle) * speed
	var dt := 1.0 / 120.0
	while z < LANE_LEN:
		px -= vx * dt
		z += vz * dt
		vz += BALL_FRICTION * dt
		if z < LANE_LEN - OIL_LEN:
			vx -= hook * dt * clampf((LANE_LEN - OIL_LEN - z) / 4.0, 0.3, 1.0)
	return {"x0": px, "aim": atan2(vx, vz), "speed0": sqrt(vx * vx + vz * vz)}


# ── the pins ─────────────────────────────────────────────────────────────────

## What the ball (`entry`: roll()'s result) takes down of `standing` (ten bools; all up
## for a frame's first ball). Returns {down: [pin numbers 1-10 that fell, in the order they
## went], falls: {pin number: {t (s after the ball reached the head pin), dir (Vector2,
## the way it went over), to (Vector2, where it ended; past PIT_Z: in the pit)}},
## wobbled: [pin numbers that rocked and stayed]}.
static func strike(entry: Dictionary, standing: Array, seed: int) -> Dictionary:
	var down: Array = []
	var falls := {}
	var wobbled: Array = []
	if bool(entry.get("gutter", false)):
		return {"down": down, "falls": falls, "wobbled": wobbled}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spots := pin_spots()
	# Bodies: [pos, vel, radius, mass, state (0 up, 1 going down, 2 out), pin number].
	var bodies: Array = []
	var a := float(entry.get("angle", 0.0))
	var sp := float(entry.get("speed", 7.0))
	bodies.append({"p": Vector2(float(entry.get("x", 0.0)), PIN_SPACING * 0.5), "v": Vector2(sin(a) * sp, -cos(a) * sp),
		"r": BALL_R, "m": BALL_MASS, "s": 1, "n": 0})
	for i in 10:
		if i < standing.size() and bool(standing[i]):
			# Each pin a hair off its spot, as the pinsetter left it.
			var jitter := Vector2(rng.randf_range(-0.004, 0.004), rng.randf_range(-0.004, 0.004))
			bodies.append({"p": (spots[i] as Vector2) + jitter, "v": Vector2.ZERO, "r": PIN_R, "m": PIN_MASS, "s": 0, "n": i + 1})
	var t := 0.0
	while t < SIM_SECONDS:
		t += SIM_DT
		for b in bodies:
			if int(b["s"]) != 1:
				continue
			var v: Vector2 = b["v"]
			var fr := (BALL_FRICTION if int(b["n"]) == 0 else PIN_FRICTION) * SIM_DT
			b["v"] = v.move_toward(Vector2.ZERO, fr)
			b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * SIM_DT
			var p: Vector2 = b["p"]
			# The side boards throw a moving pin back in.
			if int(b["n"]) != 0 and absf(p.x) > KICKBACK_X - float(b["r"]):
				b["p"] = Vector2(signf(p.x) * (KICKBACK_X - float(b["r"])), p.y)
				b["v"] = Vector2(-(b["v"] as Vector2).x * 0.35, (b["v"] as Vector2).y * 0.8)
			if p.y < PIT_Z:
				if int(b["n"]) != 0:
					b["s"] = 2
					var fx: Dictionary = falls.get(int(b["n"]), {})
					fx["to"] = p
					falls[int(b["n"])] = fx
				elif (b["v"] as Vector2).length() < 0.05:
					b["s"] = 2
		for i in bodies.size():
			var bi: Dictionary = bodies[i]
			if int(bi["s"]) == 2:
				continue
			for j in range(i + 1, bodies.size()):
				var bj: Dictionary = bodies[j]
				if int(bj["s"]) == 2 or (int(bi["s"]) == 0 and int(bj["s"]) == 0):
					continue
				var ri := float(bi["r"]) if int(bi["s"]) != 1 or int(bi["n"]) == 0 else PIN_LYING_R
				var rj := float(bj["r"]) if int(bj["s"]) != 1 or int(bj["n"]) == 0 else PIN_LYING_R
				var d: Vector2 = (bj["p"] as Vector2) - (bi["p"] as Vector2)
				var dist := d.length()
				if dist >= ri + rj or dist < 0.00001:
					continue
				var nrm := d / dist
				var vrel := ((bi["v"] as Vector2) - (bj["v"] as Vector2)).dot(nrm)
				if vrel <= 0.0:
					continue
				var mi := float(bi["m"])
				var mj := float(bj["m"])
				var imp := 1.5 * vrel / (1.0 / mi + 1.0 / mj)
				var dvi := -imp / mi
				var dvj := imp / mj
				_take_hit(bi, nrm * dvi, t, rng, down, falls, wobbled)
				_take_hit(bj, nrm * dvj, t, rng, down, falls, wobbled)
				# Apart again.
				var push := (ri + rj - dist) * 0.5
				if int(bi["s"]) == 1:
					bi["p"] = (bi["p"] as Vector2) - nrm * push
				if int(bj["s"]) == 1:
					bj["p"] = (bj["p"] as Vector2) + nrm * push
	for b in bodies:
		var n := int(b["n"])
		if n > 0 and falls.has(n) and not (falls[n] as Dictionary).has("to"):
			falls[n]["to"] = b["p"]
	return {"down": down, "falls": falls, "wobbled": wobbled}


## A body takes `dv` from a hit: a standing pin knocked hard enough goes down (rocked a
## little, it may); one going down already just takes it.
static func _take_hit(b: Dictionary, dv: Vector2, t: float, rng: RandomNumberGenerator, down: Array, falls: Dictionary, wobbled: Array) -> void:
	var n := int(b["n"])
	if int(b["s"]) == 1:
		b["v"] = (b["v"] as Vector2) + dv
		return
	var hit := dv.length()
	var goes := hit >= FALL_SPEED
	if not goes and hit >= WOBBLE_SPEED:
		goes = rng.randf() < (hit - WOBBLE_SPEED) / (FALL_SPEED - WOBBLE_SPEED) * 0.55
		if not goes and not wobbled.has(n):
			wobbled.append(n)
	if not goes:
		return
	b["s"] = 1
	b["v"] = dv
	down.append(n)
	falls[n] = {"t": t, "dir": dv.normalized() if hit > 0.0001 else Vector2(0, -1)}


# ── the score card ───────────────────────────────────────────────────────────

## A game's card from its balls (pins down by each, in order): {frames: [{balls: [n...],
## marks: ["X", "/", "-", "7"...], total: running total or -1 while it waits for its
## bonus balls}], total, frame (the one being bowled, 0-9; 10 when done), ball (in it),
## standing (ten bools for the next ball), done}.
static func card(balls: Array) -> Dictionary:
	var frames: Array = []
	var i := 0
	var running := 0
	for f in FRAMES:
		var fr := {"balls": [], "marks": [], "total": -1}
		if i >= balls.size():
			frames.append(fr)
			continue
		if f < FRAMES - 1:
			var b1 := int(balls[i])
			fr["balls"].append(b1)
			if b1 == 10:
				fr["marks"].append("X")
				if i + 2 < balls.size():
					running += 10 + int(balls[i + 1]) + int(balls[i + 2])
					fr["total"] = running
				i += 1
			else:
				fr["marks"].append(_mark(b1))
				if i + 1 < balls.size():
					var b2 := int(balls[i + 1])
					fr["balls"].append(b2)
					if b1 + b2 == 10:
						fr["marks"].append("/")
						if i + 2 < balls.size():
							running += 10 + int(balls[i + 2])
							fr["total"] = running
					else:
						fr["marks"].append(_mark(b2))
						running += b1 + b2
						fr["total"] = running
				i += 2
		else:
			# The tenth: a strike or a spare earns its bonus balls in the frame itself.
			var rest: Array = balls.slice(i)
			var up := 10
			for k in mini(3, rest.size()):
				var b := int(rest[k])
				fr["balls"].append(b)
				if up == 10 and b == 10:
					fr["marks"].append("X")
				elif b == up and k > 0 and up < 10:
					fr["marks"].append("/")
				else:
					fr["marks"].append(_mark(b))
				up = 10 if (b == up) else up - b
			var nb: int = fr["balls"].size()
			var need := 3 if nb >= 2 and int(fr["balls"][0]) + int(fr["balls"][1]) >= 10 or (nb >= 1 and int(fr["balls"][0]) == 10) else 2
			if nb >= need:
				for b in fr["balls"]:
					running += int(b)
				fr["total"] = running
			i += nb
		frames.append(fr)
	var state := _where(balls)
	return {"frames": frames, "total": running, "frame": state["frame"], "ball": state["ball"], "standing": state["standing"], "done": int(state["frame"]) >= FRAMES}


static func _mark(n: int) -> String:
	return "-" if n == 0 else str(n)


## Where a game stands after `balls`: the frame and ball to bowl next, and which pins are up.
static func _where(balls: Array) -> Dictionary:
	var i := 0
	for f in FRAMES:
		if f < FRAMES - 1:
			if i >= balls.size():
				return {"frame": f, "ball": 0, "standing": _all_up()}
			var b1 := int(balls[i])
			if b1 == 10:
				i += 1
				continue
			if i + 1 >= balls.size():
				return {"frame": f, "ball": 1, "standing": _left_after([b1])}
			i += 2
		else:
			var rest: Array = balls.slice(i)
			if rest.size() == 0:
				return {"frame": f, "ball": 0, "standing": _all_up()}
			var b1t := int(rest[0])
			if rest.size() == 1:
				return {"frame": f, "ball": 1, "standing": _all_up() if b1t == 10 else _left_after([b1t])}
			var b2t := int(rest[1])
			var bonus := b1t == 10 or b1t + b2t == 10
			if rest.size() == 2 and bonus:
				var fresh := b2t == 10 or (b1t != 10 and b1t + b2t == 10) or (b1t == 10 and b2t == 10)
				return {"frame": f, "ball": 2, "standing": _all_up() if fresh else _left_after([b2t])}
	return {"frame": FRAMES, "ball": 0, "standing": _all_up()}


static func _all_up() -> Array:
	return [true, true, true, true, true, true, true, true, true, true]


## Only a count of what fell is known here: the card's view of the deck (the alley keeps
## which pins, scripts/bowling/lane.gd); a count with the first n down.
static func _left_after(fallen: Array) -> Array:
	var down := 0
	for n in fallen:
		down += int(n)
	var out := _all_up()
	for k in mini(10, down):
		out[k] = false
	return out


# ── the guests' balls ────────────────────────────────────────────────────────

## A guest's ball, `skill` 0 (never held one) to 1 (league): where it comes to the pins
## ({x, angle, speed, hook, gutter}). A frame's first ball goes for the pocket (between the
## 1 and the 3, coming in from the right at a few degrees); a second goes for the middle
## of what is left standing.
static func guest_ball(skill: float, standing: Array, rng: RandomNumberGenerator) -> Dictionary:
	var spots := pin_spots()
	var target := 0.065
	var up := 0
	var cx := 0.0
	for i in 10:
		if i < standing.size() and bool(standing[i]):
			up += 1
			cx += (spots[i] as Vector2).x
	if up > 0 and up < 10:
		target = cx / float(up)
	var spread := lerpf(0.26, 0.05, clampf(skill, 0.0, 1.0))
	var x := target + rng.randfn(0.0, spread)
	var angle := lerpf(-0.02, -0.08, skill) + rng.randfn(0.0, lerpf(0.04, 0.012, skill))
	var speed := lerpf(5.5, 8.4, skill) + rng.randfn(0.0, 0.5)
	var hook := lerpf(-0.1, -0.9, skill)
	# A beginner's ball can find the gutter on the way.
	var gutter := absf(x) > LANE_W * 0.5 - BALL_R * 0.4 or rng.randf() < lerpf(0.12, 0.005, skill)
	return {"x": clampf(x, -LANE_W * 0.5, LANE_W * 0.5), "angle": angle, "speed": maxf(4.0, speed), "hook": hook, "gutter": gutter}
