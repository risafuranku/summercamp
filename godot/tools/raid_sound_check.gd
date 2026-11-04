extends "res://tools/shot_driver.gd"

## What of the granny's raid on a lodging reaches the warden hiding in the reception (TODO
## W32, the user 4. 11.: "she eats the guests and at the reception I know nothing of it"):
## a test night with her, the warden in the office, each of her sounds as it starts ("RAID
## <phase> <file> dist=<m to the camp's ear> reach=<max_distance> heard=<in reach> bus=..."),
## and the office radio's relay of her meal (on with the set switched off).
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/raid_sound_check.tscn

var _seen := {}
var _work_stream := ""


func granny():
	for b in _main.get("_enemy_brains"):
		if b != null and b.has_method("get_enemy_id") and str(b.get_enemy_id()) == "basket":
			return b
	return null


func probe() -> void:
	var g = granny()
	if g == null:
		return
	var root: Node = g.get("_root")
	var vp := _main.get_node_or_null("SubViewportContainer/SubViewport") as Viewport
	var cam := vp.get_camera_3d() if vp != null else null
	var ear: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var phase := str(g.get("_phase"))
	if root == null:
		return
	for n in root.find_children("*", "AudioStreamPlayer3D", true, false):
		var a := n as AudioStreamPlayer3D
		if not a.playing or a.stream == null:
			continue
		var id := a.get_instance_id()
		var path := a.stream.resource_path.get_file()
		if a == g.get("_work"):
			if path == _work_stream:
				continue
			_work_stream = path
		elif _seen.has(id):
			continue
		_seen[id] = true
		var d := a.global_position.distance_to(ear)
		print("RAID %s %s dist=%.0f reach=%.0f heard=%s unit=%.0f bus=%s db=%.1f" % [phase, path, d, a.max_distance, str(d < a.max_distance), a.unit_size, a.bus, a.volume_db])
	var dread = _main.get("_interior_manager").get("_building_interior").get("_dread")
	if dread != null and bool(dread.get("_relay_on")):
		var radio_on = _main.get("_interior_manager").get("_building_interior").get("_radio_power_on")
		print("RAID relay on: radio switched %s, set power %.2f" % [str(radio_on), float(dread.get("_power"))])


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_test_night", ["basket"]], ["wait", 4.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.open_interior()"], ["timescale", 2.0],
	]
	for i in 200:
		_steps.append(["wait", 0.4])
		_steps.append(["eval", "get_tree().root.get_node('RaidSoundCheck').probe()"])
	_steps.append(["timescale", 1.0])
	_steps.append(["eval", "get_tree().quit()"])
