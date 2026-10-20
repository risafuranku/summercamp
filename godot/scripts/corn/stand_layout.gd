extends RefCounted

## The corn stand's two stations on its counter (DESIGN.md §7b "The corn stand";
## scripts/corn/*_station.gd on scripts/business/station3d.gd). The stand is
## building_models._corn_stand: a counter 2.6 m wide and 1.3 deep, its top 1.11 m up, its
## front (+z) to the camp. Behind it, from the left: the husking (the crate of cobs in
## their husks, the place to husk one, the bowl the husked ones go in, the bucket for the
## husks) and the counter (the pot of boiling water, the board, the butter and its brush,
## the salt, the napkins, the cash box). The camera stands behind them and looks out
## over the counter into the camp: the counter at the bottom of the picture, the camp
## and whoever comes up to the stand above it (the playtest's split, 18. 10.).
## Everything here is in the stand's own space (its model's root).

## id -> {at (the surface's centre), size, yaw (the vendor faces it), flat, how far back
## and up the camera stands and how far over the top it looks, tex: its Build picture}.
const SURFACES := {
	"counter": {"at": Vector3(-0.65, 1.112, -0.28), "size": Vector2(1.3, 0.73125), "yaw": 180.0, "flat": true, "cam_back": 0.62, "cam_up": 0.44, "cam_aim": 0.08, "tex": "res://assets/textury/corn/st_counter.png"},
	"husk": {"at": Vector3(0.65, 1.112, -0.28), "size": Vector2(1.3, 0.73125), "yaw": 180.0, "flat": true, "cam_back": 0.62, "cam_up": 0.44, "cam_aim": 0.08, "tex": "res://assets/textury/corn/st_husk.png"},
}
## id -> {label (said), tab_label (the frame's bar), script}; in the bar's order.
const STATIONS := {
	"counter": {"label": "the counter", "tab_label": "COUNTER", "script": "res://scripts/corn/counter_station.gd"},
	"husk": {"label": "the husking", "tab_label": "HUSK", "script": "res://scripts/corn/husk_station.gd"},
}
## Where the one at the stand stands, behind the counter (on the ground), facing out.
const VENDOR := Vector3(0, 0, -1.15)
## The model's own pot, its gas ring and the crate on the counter: the stations draw
## theirs (the painted pot, the crate in the husking's picture).
const MODEL_PARTS := ["Pot", "Ring", "CornCrate"]


## The stations' Build pictures laid on the counter (quads Surface_<id>, at the room's
## pixel) and the model's own pot and crate put away; under `root` (the stand's model).
static func dress(root: Node3D) -> void:
	for n in MODEL_PARTS:
		for c in root.get_children():
			if str(c.name).begins_with(n):
				(c as Node3D).visible = false
	for id in SURFACES:
		if root.get_node_or_null("Surface_" + str(id)) != null:
			continue
		var d: Dictionary = SURFACES[id]
		var mi := MeshInstance3D.new()
		mi.name = "Surface_" + str(id)
		var q := QuadMesh.new()
		q.size = d["size"]
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 1.0
		var pic: Texture2D = load("res://scripts/business/station3d.gd").room_tex(str(d["tex"]), (d["size"] as Vector2).x)
		m.albedo_texture = pic
		mi.material_override = m
		mi.position = d["at"]
		mi.rotation_degrees.y = float(d["yaw"])
		root.add_child(mi)
