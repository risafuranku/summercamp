extends RefCounted

## Work by a gesture of the mouse instead of a hold bar (the brief of 21. 10.: "a short
## gesture for every job"): what the hand does, the mouse does, and every stroke moves
## the job on:
##   sweep    to and fro sideways (sweeping, mopping, wiping, sawing)
##   circle   round and round (scrubbing, a screw or a nut turned: either way)
##   hammer   a sharp jerk down (knocking a nail in)
##   pull     drawn towards you, down (plunging, pulling, a sack lifted)
##   pick     down and up again (picking up, bagging, making the bed)
## Fed with the mouse's movement in screen pixels (a captured mouse's relative motion,
## or the cursor's); thresholds are a share of the view's height, so any window works.
##   var g := GESTURE.new(); g.kind = GESTURE.kind_for("Sweeping")
##   strokes = g.feed(motion, delta, view_height)       (0, 1 or more strokes)
## `idle` says how long since the last stroke: the ghost hand shows the motion after a few
## seconds of nothing (work_hand.ghost). Tools (the shot driver) set `auto`: a press held
## still makes strokes by itself at `auto_rate` a second, so the harnesses' held clicks
## still do the work (a little sooner than the old hold).

static var auto := false
static var auto_rate := 3.0

const BY_VERB := {
	"Sweeping": "sweep", "Mopping": "sweep", "Wiping": "sweep", "Scraping": "sweep", "Sawing": "sweep",
	"Scrubbing": "circle", "Fixing": "circle", "Repairing": "circle", "Clamping": "circle",
	"Hammering": "hammer",
	"Plunging": "pull", "Pulling": "pull", "Emptying": "pull",
	"Clearing up": "pick", "Bagging": "pick", "Throwing out": "pick", "Picking up": "pick",
	"Making the bed": "pick", "Rolling out": "pick", "Refilling": "pick",
}

var kind := "sweep"
## Seconds since the last stroke (or since the work began).
var idle := 0.0
## The hand's offset from where it works (px, a share of the view: the hand follows the
## mouse within a small box and drifts back).
var offset := Vector2.ZERO
var _travel := Vector2.ZERO
var _sign := 0
var _angle := 0.0
var _last_dir := Vector2.ZERO
var _cool := 0.0
var _down := false
var _auto_t := 0.0


static func kind_for(verb: String) -> String:
	return str(BY_VERB.get(verb, "sweep"))


## How many strokes a job of `seconds` held (the old bar) takes.
static func strokes_for(seconds: float) -> int:
	return clampi(int(round(seconds * 2.2)), 2, 12)


func reset() -> void:
	idle = 0.0
	offset = Vector2.ZERO
	_travel = Vector2.ZERO
	_sign = 0
	_angle = 0.0
	_last_dir = Vector2.ZERO
	_cool = 0.0
	_down = false
	_auto_t = 0.0


## The mouse moved `motion` (px) this frame; the view is `h` px high. Strokes completed.
func feed(motion: Vector2, delta: float, h: float) -> int:
	idle += delta
	_cool = maxf(0.0, _cool - delta)
	var u := maxf(h, 1.0) / 100.0          # one unit: a hundredth of the view's height
	offset = (offset + motion).limit_length(u * 9.0)
	offset = offset.move_toward(Vector2.ZERO, u * 18.0 * delta)
	if auto:
		# Tools: by the clock alone (two copies of the game share one cursor, which moves).
		_auto_t += delta * auto_rate
		if _auto_t >= 1.0:
			_auto_t -= 1.0
			return _stroke()
		return 0
	var n := 0
	match kind:
		"sweep":
			if absf(motion.x) > 0.01:
				var sg := 1 if motion.x > 0.0 else -1
				if sg != _sign and absf(_travel.x) > u * 6.0:
					n += _stroke()
					_travel = Vector2.ZERO
				if sg != _sign:
					_travel.x = 0.0
				_sign = sg
				_travel.x += motion.x
		"circle":
			if motion.length() > u * 0.25:
				var d := motion.normalized()
				if _last_dir != Vector2.ZERO:
					_angle += _last_dir.angle_to(d)
				_last_dir = d
				# Half a turn either way is a stroke (a circle, not a line to and fro).
				if absf(_angle) >= PI:
					_angle = 0.0
					n += _stroke()
		"hammer":
			if _cool <= 0.0 and motion.y > u * 2.0 and motion.y / maxf(delta, 0.001) > u * 90.0:
				_cool = 0.22
				n += _stroke()
		"pull":
			if motion.y > 0.0:
				_travel.y += motion.y
				if _travel.y > u * 10.0:
					_travel.y = 0.0
					n += _stroke()
			else:
				_travel.y = maxf(0.0, _travel.y + motion.y * 0.25)
		"pick":
			_travel.y += motion.y
			if not _down and _travel.y > u * 5.0:
				_down = true
			elif _down and _travel.y < u * 1.0:
				_down = false
				_travel.y = 0.0
				n += _stroke()
			_travel.y = clampf(_travel.y, -u * 2.0, u * 8.0)
	return n


func _stroke() -> int:
	idle = 0.0
	return 1


## The motion the ghost hand shows (offset in view-height hundredths) at time `t`.
static func ghost_offset(k: String, t: float) -> Vector2:
	match k:
		"sweep":
			return Vector2(sin(t * 5.0) * 8.0, 0.0)
		"circle":
			return Vector2(cos(t * 5.0), sin(t * 5.0)) * 5.0
		"hammer":
			var f := fposmod(t * 2.0, 1.0)
			return Vector2(0.0, (8.0 * (f / 0.15) if f < 0.15 else 8.0 * (1.0 - (f - 0.15) / 0.85)) - 4.0)
		"pull":
			return Vector2(0.0, fposmod(t * 1.2, 1.0) * 12.0 - 6.0)
		"pick":
			return Vector2(0.0, absf(sin(t * 3.0)) * 8.0 - 4.0)
	return Vector2.ZERO
