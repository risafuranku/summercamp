extends "res://tools/shot_driver.gd"

## The Family's night on pictures (scripts/enemies/boy_brain.gd, scripts/night/boy_face.gd,
## DESIGN §5a.2):
##   --part=face  the boy in the corn and his face in steps when you look back at him (the
##                same steps at the board and in the pipes)
##   --part=heat  the corn's hot and cold on the picture, as he says it
##   --part=dad   his father in your way in the dark: looked at, looked away from and back
##                (nearer), twice, and the third time gone
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/rodina_shots.tscn -- --part=face --out=DIR

const R := "get_tree().root.get_node('RodinaShots')"


func boy():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "child":
			return b
	return null


func face_now() -> String:
	var h = _main.get("_corn_hunt")
	if h == null:
		return "no hunt"
	h._boy_strike(_main.get("_player"))
	return "his face"


## The father shown now, then you looking at him.
func dad_now() -> String:
	var b = boy()
	if b == null:
		return "no boy"
	b.set("_dad_next", 0.0)
	return "dad due, out %s" % str(b._boy_out())


func look_at_dad() -> String:
	var b = boy()
	var dad: Node3D = b.get("_dad") if b != null else null
	if dad == null or not dad.visible:
		return "no dad shown"
	var p: Node3D = _main.get("_player")
	var to := dad.global_position - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	return "looking at him %.1f m, steps %d" % [Vector2(to.x, to.z).length(), int(b.get("_dad_steps"))]


func look_away() -> String:
	var p: Node3D = _main.get("_player")
	p.rotation.y += PI * 0.75
	return "looked away"


## Open ground (nothing at eye height for 12 m all round): the father needs room to be seen.
func open_ground() -> String:
	var b = boy()
	var p: Node3D = _main.get("_player")
	var from := p.global_position
	for r in [0.0, 6.0, 12.0, 18.0, 24.0, 30.0, 36.0]:
		for k in 12:
			var c: Vector3 = from + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * float(k) / 12.0)
			var g: Vector3 = b._stand(c)
			if g == Vector3.INF:
				continue
			var ok := true
			for a in 12:
				var d := Vector3(0, 0, -12.0).rotated(Vector3.UP, TAU * float(a) / 12.0)
				if b._ray_blocked(g + Vector3(0, 1.5, 0), g + d + Vector3(0, 1.5, 0)):
					ok = false
					break
			if ok:
				p.global_position = g + Vector3(0, 0.05, 0)
				return "open ground %.0f m off" % r
	return "no open ground"


const START := [
	["wait_menu"], ["call", "_on_menu_test_night", ["child"]], ["wait", 4.0],
	["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
	["eval", "_set_player_health(100)"],
]

const HEAT_STEPS := [
	["eval", "start_corn_hunt({'boy': 3, 'boy_of': {}})"], ["eval", "debug_goto_corn_gate(-3.0)"], ["wait", 2.0],
	["eval", "_corn_hunt.set('_whisper_t', 99.0)"],
	["eval", "_corn_hunt.set('last_hint', 'cold')"], ["wait", 2.2], ["shot", "h1_cold"],
	["eval", "_corn_hunt.set('last_hint', 'warm')"], ["wait", 2.2], ["shot", "h2_warm"],
	["eval", "_corn_hunt.set('last_hint', 'hot')"], ["wait", 2.2], ["shot", "h3_burning"],
]

const FACE_STEPS := [
	["eval", "start_corn_hunt({'boy': 3, 'boy_of': {}})"], ["eval", "debug_goto_corn_gate(-3.0)"], ["wait", 2.0],
	["eval", R + ".face_now()"],
	["wait", 0.12], ["shot", "f1_turning"],
	["wait", 0.15], ["shot", "f2_turned"],
	["wait", 0.25], ["shot", "f3_at_you"],
	["wait", 0.25], ["shot", "f4_nearer"],
	["wait", 0.2], ["shot", "f5_hit"],
	["wait", 0.25], ["shot", "f6_dark"],
	["wait", 1.0], ["eval", "_player_health"],
]

const DAD_STEPS := [
	["eval", R + ".open_ground()"], ["wait", 0.5], ["eval", R + ".dad_now()"], ["wait", 0.6], ["eval", R + ".look_at_dad()"], ["wait", 1.0], ["shot", "d1_dad"],
	["eval", R + ".look_away()"], ["wait", 1.2], ["eval", R + ".look_at_dad()"], ["wait", 0.6], ["shot", "d2_nearer"],
	["eval", R + ".look_away()"], ["wait", 1.2], ["eval", R + ".look_at_dad()"], ["wait", 0.6], ["shot", "d3_nearer_again"],
	["eval", R + ".look_away()"], ["wait", 1.2], ["eval", R + ".look_at_dad()"], ["wait", 0.6], ["shot", "d4_gone"],
]


func _ready() -> void:
	super._ready()
	var part := "face"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.get_slice("=", 1)
	var steps: Array = {"face": FACE_STEPS, "dad": DAD_STEPS, "heat": HEAT_STEPS}.get(part, FACE_STEPS)
	_steps = START.duplicate(true) + steps.duplicate(true) + [["eval", "get_tree().quit()"]]
