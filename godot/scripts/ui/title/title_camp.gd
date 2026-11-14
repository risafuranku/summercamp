extends RefCounted

## The title screen's camp (playtest 14. 11.: "always a showcase camp behind the window"):
## the same world every time (SEED), the reception and what can be seen of the camp out of
## its front window in the last of the light: the lamps along the way lit, two tents and a
## cabin, the bonfire burning. Never the player's camp; the game starts its own world.
## Places are worked out along the window's own line of sight (ReceptionLayout room space:
## out of the front wall, -Z, `d` metres from the glass and `x` across), so they stand in
## view whatever the world makes of the land round the reception.

const RL = preload("res://scripts/reception/reception_layout.gd")
const SEED := 19981031
## [building, metres out of the window, metres across (room x)].
const PLAN := [
	["bonfire", 14.0, -1.2],
	["picnic_table", 14.5, 1.0],
	["lamp_post", 12.0, 1.4],
	["tent_1", 17.0, -3.6],
	["tent_2", 19.0, 1.8],
	["tent_1", 21.0, -0.2],
	["lamp_post", 24.0, -4.4],
	["cabin_1", 30.0, -1.2],
]


## Builds it in main's fresh world (called after the world is generated, before the title
## stage opens).
static func build(main: Node) -> void:
	var world: Node3D = main.get("_world_3d")
	var grid = main.get("grid_manager")
	var office := world.find_child("MainBuilding", true, false) as Node3D if world != null else null
	if office == null or grid == null:
		return
	CoreRoot.actions.add_money(20000)
	var room_xf: Transform3D = office.global_transform * RL.room_to_local()
	var taken := {}
	for item in PLAN:
		var p: Vector3 = room_xf * Vector3(float(item[2]), 0.0, RL.OFFICE_WINDOW_CENTER.z - float(item[1]))
		var tile: Vector2i = grid.world_to_grid(p)
		if taken.has(tile):
			continue
		taken[tile] = true
		EventBus.RequestDemolish.emit(Rect2i(tile.x - 1, tile.y - 1, 3, 3))
		EventBus.RequestBuild.emit(str(item[0]), tile, 0)


## The bonfire going (the guests have just put a piece on), once the camp stands.
static func light(main: Node) -> void:
	var tree := main.get_tree() if main != null else null
	if tree == null:
		return
	for f in tree.get_nodes_in_group("campfire"):
		if f.has_method("import_state"):
			# (After its own setup, deferred when it was built: its sparks are made there.)
			f.call_deferred("import_state", {"fuel": 1.1, "embers": 0.3, "logs": 6})
