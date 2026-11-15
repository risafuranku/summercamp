extends "res://tools/shot_driver.gd"

## The split screen (TODO.md SPLITSCREEN): a co-op host and a local co-op client in one
## program. A new camp, then the second warden started (scripts/instance/local_client.gd):
## its instance's own Coop joins the host over 127.0.0.1, its main gets the host's camp and
## starts, the window is split; joined by pad 1's Menu, each pad walks only its own warden,
## pad 1's Menu held leaves. Prints "LOCAL ok|FAIL ..." and "LOCAL: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/local_split_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('LocalCheck')"

var _fails := 0
var _client: Node


func _ready() -> void:
	super._ready()
	name = "LocalCheck"
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 6.0],
		["eval", "_interior_manager.close_everything(true)"], ["wait", 1.5],
		# Pad 0 is the host's; pad 1's Menu out in the camp: the second warden.
		["pad_button", 0, JOY_BUTTON_X], ["wait", 0.5],
		["pad_button", 1, JOY_BUTTON_START], ["wait", 1.0], ["eval", C + ".find_client()"], ["wait", 30.0],
		["eval", C + ".check_client()"], ["shot", "ls0_split"],
		# Each pad its own warden.
		["eval", C + ".mark()"], ["pad_axis", 1, JOY_AXIS_LEFT_Y, -1.0], ["wait", 1.2], ["pad_axis", 1, JOY_AXIS_LEFT_Y, 0.0], ["wait", 0.4],
		["eval", C + ".check_moved('client', true)"], ["eval", C + ".check_moved('host', false)"], ["shot", "ls1_client_walked"],
		["eval", C + ".mark()"], ["pad_axis", 0, JOY_AXIS_LEFT_Y, -1.0], ["wait", 1.2], ["pad_axis", 0, JOY_AXIS_LEFT_Y, 0.0], ["wait", 0.4],
		["eval", C + ".check_moved('host', true)"], ["eval", C + ".check_moved('client', false)"],
		# Pad 1's Menu held: the second warden leaves.
		["pad_button", 1, JOY_BUTTON_START, 2.2], ["wait", 3.0],
		["eval", C + ".check_left()"], ["shot", "ls2_left"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]


func check(what: String, ok: bool) -> void:
	print("LOCAL %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _run_step(step: Array) -> void:
	match str(step[0]):
		"pad_axis":
			var m := InputEventJoypadMotion.new()
			m.device = int(step[1])
			m.axis = int(step[2])
			m.axis_value = float(step[3])
			Input.parse_input_event(m)
		"pad_button":
			var b := InputEventJoypadButton.new()
			b.device = int(step[1])
			b.button_index = int(step[2])
			b.pressed = true
			Input.parse_input_event(b)
			get_tree().create_timer(float(step[3]) if step.size() > 3 else 0.15).timeout.connect(func() -> void:
				var up := b.duplicate() as InputEventJoypadButton
				up.pressed = false
				Input.parse_input_event(up))
		_:
			super._run_step(step)


func find_client() -> void:
	_client = get_tree().root.get_node_or_null("LocalClient")
	check("pad 1's Menu makes the second warden's instance", _client != null)


var _mark: Dictionary = {}


func _body(who: String) -> Node3D:
	if who == "host":
		return _main.get("_player")
	var cm = _client.get("main") if _client != null and is_instance_valid(_client) else null
	return cm.get("_player") if cm != null else null


func mark() -> void:
	for w in ["host", "client"]:
		var b := _body(w)
		_mark[w] = b.global_position if b != null else Vector3.INF


func check_moved(who: String, should: bool) -> void:
	var b := _body(who)
	if b == null or _mark.get(who, Vector3.INF) == Vector3.INF:
		check("%s has a body" % who, false)
		return
	var d: float = ((b.global_position - (_mark[who] as Vector3)) * Vector3(1, 0, 1)).length()
	check("the %s %s (%.2f m)" % [who, "walks" if should else "stays", d], (d > 1.0) if should else (d < 0.2))


func check_left() -> void:
	check("pad 1's Menu held: the second warden gone", get_tree().root.get_node_or_null("LocalClient") == null)
	var one := _main.get_node_or_null("Seat1") as Control
	check("the window whole again (%.0f)" % (one.size.x if one != null else -1.0), one != null and absf(one.size.x - float(get_viewport().get_visible_rect().size.x)) < 4.0)
	check("one instance again", load("res://scripts/instance/instance.gd").count == 1)


func check_client() -> void:
	if _client == null:
		return
	var host_coop = get_node("/root/Coop")
	var client_coop = _client.get_node_or_null("Coop")
	var cm = _client.get("main")
	check("the host hosts (role %s)" % host_coop.role, host_coop.is_host())
	check("the client's own Coop is a client (role %s)" % (client_coop.role if client_coop != null else "-"), client_coop != null and client_coop.is_client())
	check("the host sees the client warden (%s)" % [host_coop.wardens.keys()], host_coop.wardens.size() == 1)
	check("the client's game started (%s)" % (cm.get("_gameplay_started") if cm != null else "-"), cm != null and bool(cm.get("_gameplay_started")))
	var hcr = get_node("/root/CoreRoot")
	var ccr = _client.get_node_or_null("CoreRoot")
	check("its own camp state, the host's money (%s / %s)" % [hcr.get_money(), ccr.get_money() if ccr != null else "-"], ccr != null and ccr != hcr and int(ccr.get_money()) == int(hcr.get_money()))
	var hp = _main.get("_player")
	var cp = cm.get("_player") if cm != null else null
	check("two wardens' bodies, each its own (%s, %s)" % [hp, cp], hp != null and cp != null and hp != cp)


func verdict() -> void:
	print("LOCAL: %s" % ("PASS" if _fails == 0 else "%d FAILURE(S)" % _fails))
