extends "res://tools/shot_driver.gd"

## A walk into a spruce (player_controller._hold_off_branches, 4. 11.): you stop at the tips
## of its lower branches, your eyes never in the needles; crouched you get in under it;
## stood up there you are eased out without a jump. Lines "SMRK ...", "SMRK: PASS".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/smrk_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('SmrkCheck')"
const WG = preload("res://scripts/world_generator.gd")

var fails := 0
var _tree: Node3D
var _max_jump := 0.0
var _last := Vector3.INF
var _track := false


func _fail(what: String) -> void:
	fails += 1
	print("SMRK FAIL " + what)


func pl() -> CharacterBody3D:
	return _main.get("_player")


## The spruce nearest the camp's middle with room round it to walk at it.
func pick() -> void:
	var best := INF
	var at := pl().global_position
	for t in get_tree().get_nodes_in_group("trees"):
		if not (t is StaticBody3D) or int(t.get_meta("tree_kind", -1)) != WG.TREE_KIND_SPRUCE:
			continue
		var d: float = (t as Node3D).global_position.distance_to(at)
		if d > 6.0 and d < best and _clear_round(t):
			best = d
			_tree = t
	print("SMRK spruce at %s, %.1f m off, scale %s" % [str(_tree.global_position.snapped(Vector3.ONE * 0.1)), best, str(_tree.global_transform.basis.get_scale().snapped(Vector3.ONE * 0.01))])


func _clear_round(t: Node3D) -> bool:
	for o in get_tree().get_nodes_in_group("trees"):
		if o != t and o is Node3D and (o as Node3D).global_position.distance_to(t.global_position) < 5.0:
			return false
	return true


## The warden 5 m off the spruce, facing it.
func stand_off() -> void:
	var p := pl()
	var to := Vector3(5.0, 0.0, 0.0)
	p.global_position = _tree.global_position + to + Vector3(0.0, 1.0, 0.0)
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(to.x, to.z)
	p.set("_pitch", 0.0)


func reach_at_eye() -> float:
	var p := pl()
	var cam: Camera3D = p.get_node("Head/Camera3D")
	var b := _tree.global_transform.basis
	var over := cam.global_position.y - _tree.global_position.y
	return WG.spruce_reach(over / b.y.length(), over < 1.1) * b.x.length()


func eye_off() -> float:
	var cam: Camera3D = pl().get_node("Head/Camera3D")
	return Vector2(cam.global_position.x - _tree.global_position.x, cam.global_position.z - _tree.global_position.z).length()


func walked(tag: String, crouched: bool) -> void:
	var r := reach_at_eye()
	var d := eye_off()
	print("SMRK %s: eye %.2f m from the trunk, the branches reach %.2f m there" % [tag, d, r])
	if not crouched and d < r:
		_fail("%s: the eye %.2f m from the trunk is inside the branches (%.2f m)" % [tag, d, r])
	if crouched and d > 1.2:
		_fail("%s: crouched it should get in under the spruce (%.2f m)" % [tag, d])


func track(on: bool) -> void:
	_track = on
	_last = Vector3.INF
	if not on:
		print("SMRK biggest step while eased out %.3f m" % _max_jump)
		if _max_jump > 0.12:
			_fail("eased out with a jump of %.3f m" % _max_jump)


func _physics_process(_delta: float) -> void:
	if not _track or pl() == null:
		return
	var p := pl().global_position
	if _last != Vector3.INF:
		_max_jump = maxf(_max_jump, Vector2(p.x - _last.x, p.z - _last.z).length())
	_last = p


## Does the hold-off shut anything? The camp on a half-metre grid, walked from where the
## warden stands with only trunks in the way and then with the branches: what no longer
## can be reached standing up (crouched you still pass).
func reach_map() -> void:
	var step := 0.5
	var eye_h := 1.45
	var trunks: Array = []
	var skirts: Array = []
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for t in get_tree().get_nodes_in_group("trees"):
		if not (t is StaticBody3D):
			continue
		var at: Vector3 = (t as Node3D).global_position
		var b: Basis = (t as Node3D).global_transform.basis
		var c := Vector2(at.x, at.z)
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
		trunks.append([c, 0.24 * b.x.length() + 0.35])
		if int(t.get_meta("tree_kind", -1)) == WG.TREE_KIND_SPRUCE:
			var r := 0.0
			for dy in [0.0, -0.18]:
				r = maxf(r, WG.spruce_reach((eye_h + dy) / b.y.length(), eye_h + dy < 1.1))
			if r > 0.0:
				skirts.append([c, r * b.x.length() + 0.14])
	lo -= Vector2(4, 4)
	hi += Vector2(4, 4)
	var w := int((hi.x - lo.x) / step) + 1
	var h := int((hi.y - lo.y) / step) + 1
	var solid := PackedByteArray()
	solid.resize(w * h)
	var branch := PackedByteArray()
	branch.resize(w * h)
	for pair in [[trunks, solid], [skirts, branch]]:
		for e in pair[0]:
			var c: Vector2 = e[0]
			var r: float = e[1]
			var gx0 := int((c.x - r - lo.x) / step)
			var gy0 := int((c.y - r - lo.y) / step)
			for gy in range(gy0, gy0 + int(2.0 * r / step) + 2):
				for gx in range(gx0, gx0 + int(2.0 * r / step) + 2):
					if gx < 0 or gy < 0 or gx >= w or gy >= h:
						continue
					if Vector2(lo.x + gx * step, lo.y + gy * step).distance_to(c) <= r:
						pair[1][gy * w + gx] = 1
	var start := pl().global_position
	var sx := clampi(int((start.x - lo.x) / step), 0, w - 1)
	var sy := clampi(int((start.z - lo.y) / step), 0, h - 1)
	var a := _flood(w, h, sx, sy, solid, PackedByteArray())
	var b2 := _flood(w, h, sx, sy, solid, branch)
	var free_cells := 0
	var shut := 0
	var in_branches := 0
	for i in w * h:
		if a[i] == 1:
			free_cells += 1
			if b2[i] == 0:
				if branch[i] == 1:
					in_branches += 1
				else:
					shut += 1
	print("SMRK map %d x %d m: %d trees, %d spruces; open ground %.0f m2, under the branches %.0f m2, cut off by them %.0f m2 (%.2f %%)" % [
		int(hi.x - lo.x), int(hi.y - lo.y), trunks.size(), skirts.size(), free_cells * step * step, in_branches * step * step, shut * step * step, 100.0 * float(shut) / float(maxi(1, free_cells))])


func _flood(w: int, h: int, sx: int, sy: int, solid: PackedByteArray, branch: PackedByteArray) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var todo := PackedInt32Array([sy * w + sx])
	seen[sy * w + sx] = 1
	var head := 0
	while head < todo.size():
		var i := todo[head]
		head += 1
		var x := i % w
		var y := i / w
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + int(d[0])
			var ny: int = y + int(d[1])
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j := ny * w + nx
			if seen[j] == 1 or solid[j] == 1 or (not branch.is_empty() and branch[j] == 1):
				continue
			seen[j] = 1
			todo.append(j)
	return seen


func verdict() -> void:
	print("SMRK: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.5],
		["eval", C + ".reach_map()"],
		["eval", C + ".pick()"], ["eval", C + ".stand_off()"], ["wait", 1.0], ["shot", "s0_facing"],
		["keyhold", "W", true], ["wait", 2.5], ["shot", "s1_at_the_branches"], ["keyhold", "W", false], ["wait", 0.4],
		["eval", C + ".walked('walked in', false)"],
		# Sideways along it: still held off.
		["keyhold", "A", true], ["keyhold", "W", true], ["wait", 2.0], ["keyhold", "W", false], ["keyhold", "A", false], ["wait", 0.3],
		["eval", C + ".walked('along it', false)"], ["shot", "s2_along"],
		# Crouched: in under it.
		["eval", C + ".stand_off()"], ["wait", 0.5],
		["eval", "_player._set_stance(1)"], ["wait", 0.6],
		["keyhold", "W", true], ["wait", 4.0], ["keyhold", "W", false], ["wait", 0.4],
		["eval", C + ".walked('crouched', true)"], ["shot", "s3_under"],
		# Up under it: eased out.
		["eval", C + ".track(true)"], ["eval", "_player._set_stance(0)"], ["wait", 1.5], ["eval", C + ".track(false)"],
		["eval", C + ".walked('stood up', false)"], ["shot", "s4_stood_up"],
		["eval", C + ".verdict()"],
		["eval", "get_tree().quit()"],
	]
