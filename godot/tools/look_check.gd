extends Node

## Headless check of scripts/interior_look.gd (restricted look-around in interiors).
##
##   godot --headless --path godot res://tools/look_check.tscn

const LOOK := preload("res://scripts/interior_look.gd")

var _failures: Array[String] = []


func _ready() -> void:
	var look = LOOK.new(60.0, 18.0, 24.0)

	# The cursor in the middle of the screen never turns the head.
	_run(look, Vector2(0.5, 0.5), 0.0, 3.0)
	_expect(is_zero_approx(look.yaw_deg) and is_zero_approx(look.pitch_deg), "centre cursor turned the head: %.1f / %.1f" % [look.yaw_deg, look.pitch_deg])

	# Nor does aiming anywhere inside the edge band.
	_run(look, Vector2(0.80, 0.30), 0.0, 3.0)
	_expect(is_zero_approx(look.yaw_deg), "cursor inside the band turned the head: %.1f" % look.yaw_deg)

	# At the right edge the head turns right and stops at the limit, softly.
	_run(look, Vector2(0.995, 0.5), 0.0, 0.5)
	var early: float = look.yaw_deg
	_expect(early < -5.0, "right edge after 0.5 s: yaw %.1f, want clearly turning right" % early)
	_run(look, Vector2(0.995, 0.5), 0.0, 6.0)
	_expect(look.yaw_deg >= -60.0 and look.yaw_deg < -55.0, "right edge after 6 s: yaw %.1f, want near -60" % look.yaw_deg)

	# Back from the left edge, through centre, to the other limit.
	_run(look, Vector2(0.005, 0.5), 0.0, 8.0)
	_expect(look.yaw_deg <= 60.0 and look.yaw_deg > 55.0, "left edge: yaw %.1f, want near 60" % look.yaw_deg)

	# Pitch has its own limits (up 18, down 24).
	_run(look, Vector2(0.5, 0.0), 0.0, 6.0)
	_expect(look.pitch_deg <= 18.0 and look.pitch_deg > 14.0, "top edge: pitch %.1f, want near 18" % look.pitch_deg)
	_run(look, Vector2(0.5, 1.0), 0.0, 8.0)
	_expect(look.pitch_deg >= -24.0 and look.pitch_deg < -20.0, "bottom edge: pitch %.1f, want near -24" % look.pitch_deg)

	# Arrow keys turn too, with the cursor outside the window.
	look.reset()
	_run(look, Vector2(-1, -1), 1.0, 1.0)
	_expect(look.yaw_deg < -20.0, "right arrow: yaw %.1f, want turning right" % look.yaw_deg)

	# The returned offset is the head plus a little sway, in radians.
	look.reset()
	var off: Vector3 = look.update(0.016, Vector2(1.0 - LOOK.EDGE_BAND, 0.5), 0.0)
	_expect(off.y < 0.0 and absf(rad_to_deg(off.y)) <= LOOK.SWAY_YAW_DEG + 0.1, "sway at band edge: %.2f deg" % rad_to_deg(off.y))

	print("")
	if _failures.is_empty():
		print("LOOK CHECK: PASS")
		get_tree().quit(0)
	else:
		print("LOOK CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _run(look, cursor: Vector2, keys: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		look.update(1.0 / 60.0, cursor, keys)
		t += 1.0 / 60.0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
