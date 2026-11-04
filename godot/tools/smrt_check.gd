extends "res://tools/shot_driver.gd"

## Dead and back (the polish pass of 4. 11.): a warden's camp, saved, the warden killed,
## LOAD LAST SAVE puts you straight back in that camp, at that save, without the list of
## saves. Run with its own APPDATA (it makes a warden). Lines "SMRT ...", "SMRT: PASS".
##   APPDATA=<empty dir> godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/smrt_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('SmrtCheck')"
const PROFILES = preload("res://scripts/profiles.gd")

var fails := 0
var _money := 0


func _fail(what: String) -> void:
	fails += 1
	print("SMRT FAIL " + what)


func warden() -> void:
	PROFILES.select_profile(PROFILES.create_profile("Zkouska"))
	print("SMRT warden %s" % PROFILES.profile_name())


func save_now() -> void:
	CoreRoot.actions.add_money(1234)
	_money = int(CoreRoot.state.money)
	_main.call("_write_autosave", "Autosave")
	print("SMRT saved with %d, saves %d" % [_money, SaveManager.list_saves().size()])
	CoreRoot.actions.add_money(777)


func back() -> void:
	var in_game := bool(_main.get("_gameplay_started")) and not bool(_main.get("_menu_mode"))
	print("SMRT back: playing %s, money %d (saved %d), game over %s" % [str(in_game), int(CoreRoot.state.money), _money, str(_main.get("_game_over_active"))])
	if not in_game:
		_fail("not back in the camp")
	if int(CoreRoot.state.money) != _money:
		_fail("not at the save: %d, not %d" % [int(CoreRoot.state.money), _money])


func verdict() -> void:
	print("SMRT: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["eval", C + ".warden()"], ["wait", 0.5],
		["call", "_on_menu_new_camp", ["Zkouska", 0, false, false, {}]], ["wait_gameplay"], ["wait", 3.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
		["eval", C + ".save_now()"], ["wait", 0.5],
		["call", "_trigger_game_over", ["death"]], ["wait", 3.5], ["shot", "d0_died"],
		["eval", "_on_game_over_load_save_pressed()"], ["wait", 1.0], ["wait_gameplay"], ["wait", 2.0], ["shot", "d1_back"],
		["eval", C + ".back()"],
		["eval", C + ".verdict()"],
		["eval", "get_tree().quit()"],
	]
