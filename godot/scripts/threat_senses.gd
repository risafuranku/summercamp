extends RefCounted

## What the player's body notices before the player does.
##
## Reads every night enemy's `get_presence()` (a visible body, or where its last sound
## came from) and turns the nearest one into three slow signals:
##   hush  0-1  the insects and frogs fall silent around something (audio_manager);
##   fear  0-1  the HUD face's eyes widen;
##   gaze -1/0/1 the HUD face glances left or right at a presence you are not looking at.
##
## And once in a while, on a quiet night, the face glances at something that is not
## there. (DESIGN §2: rare, short, specific, never explained.)

const HUSH_FAR := 26.0
const HUSH_NEAR := 10.0
## Silence falls in ~1 s; the insects take their time to trust the dark again.
const HUSH_FALL_PER_SEC := 1.0
const HUSH_RISE_PER_SEC := 0.12
const FEAR_RANGE := 18.0
const GAZE_RANGE := 18.0
## Inside this cone the player can see it; the face does not need to point.
const GAZE_SEEN_HALF_DEG := 38.0
const GAZE_HOLD_SECONDS := 0.9
const PHANTOM_STILL_SECONDS := 18.0
const PHANTOM_CHANCE_PER_NIGHT := 0.35
const PHANTOM_SECONDS := 1.6

var hush: float = 0.0
var fear: float = 0.0
var gaze: int = 0
## Distance to the nearest presence (INF when nothing is sensed).
var nearest: float = INF

var _gaze_hold: float = 0.0
var _phantom_left: float = 0.0
var _phantom_used_night: int = -1
var _phantom_allowed_night: int = -1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func reset() -> void:
	hush = 0.0
	fear = 0.0
	gaze = 0
	nearest = INF
	_gaze_hold = 0.0
	_phantom_left = 0.0


## `brains`: the running enemy brains. `camera`: the player's eye. `night_index` lets
## the phantom glance happen at most once a night; `still_seconds` is how long the
## player has stood without moving.
func update(delta: float, brains: Array, camera: Camera3D, night_index: int, still_seconds: float) -> void:
	var dt := maxf(delta, 0.0)
	var pos := Vector3.INF
	nearest = INF
	if camera != null:
		var eye := camera.global_position
		for brain in brains:
			if brain == null or not brain.has_method("get_presence"):
				continue
			var p: Dictionary = brain.get_presence()
			if not p.has("position"):
				continue
			var at: Vector3 = p["position"]
			var d := Vector2(at.x - eye.x, at.z - eye.z).length()
			if d < nearest:
				nearest = d
				pos = at

	var hush_target := clampf((HUSH_FAR - nearest) / (HUSH_FAR - HUSH_NEAR), 0.0, 1.0) if is_finite(nearest) else 0.0
	if hush_target > hush:
		hush = move_toward(hush, hush_target, HUSH_FALL_PER_SEC * dt)
	else:
		hush = move_toward(hush, hush_target, HUSH_RISE_PER_SEC * dt)

	var fear_target := clampf(1.0 - nearest / FEAR_RANGE, 0.0, 1.0) * 1.2 if is_finite(nearest) else 0.0
	fear = move_toward(fear, clampf(fear_target, 0.0, 1.0), (2.0 if fear_target > fear else 0.25) * dt)

	var want := 0
	if pos != Vector3.INF and nearest <= GAZE_RANGE:
		want = _side_of(camera, pos)
	elif _phantom_left > 0.0:
		_phantom_left -= dt
		want = gaze if gaze != 0 else -1
	elif night_index >= 0:
		want = _maybe_phantom(night_index, still_seconds)

	_gaze_hold = maxf(0.0, _gaze_hold - dt)
	if want != gaze and (_gaze_hold <= 0.0 or want != 0):
		gaze = want
		_gaze_hold = GAZE_HOLD_SECONDS


## -1 left, 1 right, 0 when it is in front of you.
func _side_of(camera: Camera3D, at: Vector3) -> int:
	var local := camera.global_transform.affine_inverse() * at
	var flat := Vector2(local.x, -local.z)
	if flat.length_squared() < 0.0001:
		return 0
	var angle := rad_to_deg(atan2(absf(flat.x), flat.y))
	if angle <= GAZE_SEEN_HALF_DEG:
		return 0
	return -1 if flat.x < 0.0 else 1


func _maybe_phantom(night_index: int, still_seconds: float) -> int:
	if _phantom_used_night == night_index:
		return 0
	if _phantom_allowed_night != night_index:
		# One roll per night decides whether tonight has it at all.
		_phantom_allowed_night = night_index
		if _rng.randf() > PHANTOM_CHANCE_PER_NIGHT:
			_phantom_used_night = night_index
			return 0
	if still_seconds < PHANTOM_STILL_SECONDS:
		return 0
	_phantom_used_night = night_index
	_phantom_left = PHANTOM_SECONDS
	return -1 if _rng.randf() < 0.5 else 1
