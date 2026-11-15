extends "res://tools/shot_driver.gd"

## The split screen (TODO.md SPLITSCREEN): a co-op host and a local co-op client in one
## program. A new camp, then the second warden started (scripts/instance/local_client.gd):
## its instance's own Coop joins the host over 127.0.0.1, its main gets the host's camp and
## starts, the window is split. Prints "LOCAL ok|FAIL ..." and "LOCAL: PASS".
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
		["eval", C + ".start_client()"], ["wait", 30.0],
		["eval", C + ".check_client()"], ["shot", "ls0_split"],
		["wait", 3.0], ["shot", "ls1_split_later"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]


func check(what: String, ok: bool) -> void:
	print("LOCAL %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func start_client() -> void:
	_client = _main.call("debug_local_client", 1)
	check("the second warden's instance is made", _client != null)


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
