extends RefCounted

## The store behind the office: through the door in the office's back wall, a lean-to
## of rough boards (ReceptionLayout.STORE_*). Grey steel shelves either side, one stacked
## with the camp's linen and blankets, the other with its supplies (bulbs, paint, bleach,
## mouse traps); on the back wall the boiler and the meter with its porcelain fuses,
## glass blocks letting a little daylight in over them; on the floor the mop in its
## bucket, a gas bottle, two crates of empties and the box of last summer's lost
## property. A bare bulb on its cord, a pull-switch beside it.
##
## Built into the reception's own 3D like the back room (the door opens and you walk
## in, the office stays behind you through the doorway).
##
## Things to use: the bulb's cord (on/off; it comes on as you walk in), the lost
## property, the doorway back.

const K = preload("res://scripts/interior_kit.gd")
const RL = preload("res://scripts/reception/reception_layout.gd")
const SFX_CORD := "res://assets/sfx/rooms/cord_pull.mp3"

## Where you stand just inside, and the view from there (the back wall, a bit down).
const STAND := Vector3(0.0, 1.5, 2.98)
const STAND_ROT := Vector3(-0.2, PI, 0.0)
const BULB := Vector3(-0.06, 2.1, 3.62)

var root: Node3D
var hot: Dictionary = {}     # id -> {body, meshes}
var bulb_on := false
var light: OmniLight3D
var day_light: OmniLight3D
var _bulb_mesh: MeshInstance3D
var _lost: MeshInstance3D
var _bulb_pivot: Node3D
var _blocks_mat: StandardMaterial3D
var _swing := 0.0
var _swing_v := 0.0
var _t := 0.0
var _flicker := 0.0
var _one: AudioStreamPlayer


func build(parent: Node3D, audio_parent: Node) -> void:
	root = Node3D.new()
	root.name = "StoreRoom"
	parent.add_child(root)
	_one = AudioStreamPlayer.new()
	audio_parent.add_child(_one)
	var x0: float = RL.STORE_X.x + 0.1
	var x1: float = RL.STORE_X.y - 0.1
	var z0: float = RL.STORE_Z.x
	var z1: float = RL.STORE_Z.y - 0.1
	var w := x1 - x0
	var d := z1 - z0
	var boards := K.surface("planks_grey", 0.9, Color(0.86, 0.8, 0.72))
	# The floor a step down from the office's, bare concrete.
	K.slab(root, Vector3(w, 0.1, d), Vector3(0, -0.07, (z0 + z1) * 0.5), K.surface("concrete", 1.2, Color(0.8, 0.78, 0.74)), "StoreFloor")
	K.slab(root, Vector3(0.1, 2.7, d), Vector3(x0 - 0.05, 1.3, (z0 + z1) * 0.5), boards, "StoreWallL")
	K.slab(root, Vector3(0.1, 2.7, d), Vector3(x1 + 0.05, 1.3, (z0 + z1) * 0.5), boards, "StoreWallR")
	_back_wall(x0, x1, z1, boards)
	# The roof boards, falling from the office wall to the back.
	var top_a: float = RL.STORE_ROOF.x - 0.06
	var top_b: float = RL.STORE_ROOF.y - 0.06
	var slope := atan2(top_a - top_b, d)
	var ceil := K.slab(root, Vector3(w + 0.2, 0.06, sqrt(d * d + (top_a - top_b) * (top_a - top_b)) + 0.1), Vector3(0, (top_a + top_b) * 0.5 + 0.03, (z0 + z1) * 0.5), K.surface("planks_dark", 0.7), "StoreCeiling")
	ceil.rotation.x = slope
	for i in 3:
		var bz := z0 + 0.25 + i * 0.6
		var by := lerpf(top_a, top_b, (bz - z0) / d) - 0.05
		K.slab(root, Vector3(w, 0.09, 0.07), Vector3(0, by, bz), K.surface("planks_dark", 0.6, Color(0.7, 0.62, 0.55)), "StoreJoist")

	# The shelves: grey steel, a Grok face of what is on them.
	var steel := K.surface("galvanized", 0.6, Color(0.72, 0.72, 0.7))
	var sz := (z0 + z1) * 0.5 + 0.08
	var sl := d - 0.22
	K.slab(root, Vector3(0.42, 1.96, sl), Vector3(x0 + 0.21, 0.98, sz), steel, "ShelfL")
	K.picture(root, "shelf_linen", Vector2(sl - 0.04, 1.94), Vector3(x0 + 0.425, 0.98, sz), 90.0, "ShelfLinen")
	K.slab(root, Vector3(0.42, 1.96, sl), Vector3(x1 - 0.21, 0.98, sz), steel, "ShelfR")
	K.picture(root, "shelf_stuff", Vector2(sl - 0.04, 1.94), Vector3(x1 - 0.425, 0.98, sz), -90.0, "ShelfStuff")

	# The back wall: the meter and the fuses on their board, the boiler and its pipes.
	K.slab(root, Vector3(0.5, 0.64, 0.03), Vector3(-0.42, 1.52, z1 - 0.015), K.surface("planks_dark", 0.5), "FuseBoard")
	K.picture(root, "fusebox", Vector2(0.44, 0.58), Vector3(-0.42, 1.52, z1 - 0.032), 180.0, "FuseBox")
	var enamel := K.surface("enamel_white", 0.5, Color(0.74, 0.7, 0.6))
	K.slab(root, Vector3(0.44, 0.88, 0.4), Vector3(0.42, 1.74, z1 - 0.2), enamel, "Boiler")
	K.picture(root, "boiler", Vector2(0.44, 0.88), Vector3(0.42, 1.74, z1 - 0.402), 180.0, "BoilerFace")
	var pipe := K.surface("galvanized", 0.3, Color(0.6, 0.58, 0.5))
	for px in [0.32, 0.52]:
		K.slab(root, Vector3(0.03, 0.62, 0.03), Vector3(px, 1.0, z1 - 0.12), pipe, "BoilerPipe")
	# The floor along the back: the lost property, the mop, the gas, the empties.
	_lost = K.cutout(root, "lost_found", Vector2(0.54, 0.42), Vector3(-0.52, -0.02, z1 - 0.32), 0.0, true, "LostFound")
	K.cutout(root, "mop_bucket", Vector2(0.47, 0.8), Vector3(-0.02, -0.02, z1 - 0.3), 0.0, true, "MopBucket")
	K.cutout(root, "gas_bottle", Vector2(0.29, 0.6), Vector3(0.28, -0.02, z1 - 0.22), 0.0, true, "GasBottle")
	var crate := K.surface("beer_crate", 0.4)
	K.slab(root, Vector3(0.4, 0.3, 0.32), Vector3(0.6, 0.13, z1 - 0.62), crate, "Crate1")
	var c2 := K.slab(root, Vector3(0.4, 0.3, 0.32), Vector3(0.62, 0.43, z1 - 0.6), crate, "Crate2")
	c2.rotation.y = 0.12
	_hot("lost_found", Vector3(-0.52, 0.2, z1 - 0.32), Vector3(0.5, 0.44, 0.4), [_lost])

	# The bulb on its cord, the pull-switch's string beside it.
	_bulb_pivot = Node3D.new()
	_bulb_pivot.name = "BulbPivot"
	var top_y := lerpf(top_a, top_b, (BULB.z - z0) / d)
	_bulb_pivot.position = Vector3(BULB.x, top_y, BULB.z)
	root.add_child(_bulb_pivot)
	_bulb_mesh = K.cutout(_bulb_pivot, "bulb_cord", Vector2(0.14, top_y - BULB.y + 0.12), Vector3(0, BULB.y - top_y - 0.12, 0), 0.0, true, "Bulb")
	var cord := K.slab(root, Vector3(0.008, top_y - 1.74, 0.008), Vector3(BULB.x - 0.15, (top_y + 1.74) * 0.5, BULB.z), K.surface("planks_dark", 0.3, Color(0.6, 0.55, 0.5)), "PullCord")
	var knob := K.slab(root, Vector3(0.025, 0.04, 0.025), Vector3(BULB.x - 0.15, 1.72, BULB.z), K.surface("plastic", 0.2, Color(0.2, 0.18, 0.16)), "PullKnob")
	for n in [_bulb_mesh, cord, knob]:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hot("store_bulb", Vector3(BULB.x - 0.07, 1.98, BULB.z), Vector3(0.3, 0.8, 0.3), [_bulb_mesh, cord, knob])

	light = OmniLight3D.new()
	light.name = "StoreBulb"
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 1.25
	light.omni_range = 3.4
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.position = BULB + Vector3(0, -0.04, 0)
	light.visible = false
	root.add_child(light)
	# What comes in through the glass blocks by day.
	day_light = OmniLight3D.new()
	day_light.light_color = Color(0.86, 0.9, 0.96)
	day_light.omni_range = 2.6
	day_light.omni_attenuation = 1.6
	day_light.position = Vector3(RL.STORE_BLOCKS.get_center().x, RL.STORE_BLOCKS.get_center().y - 0.3, z1 - 0.3)
	root.add_child(day_light)
	# The doorway seen from inside: the way back to the office.
	_hot("store_doorway", Vector3(0.0, 1.05, z0 - 0.02), Vector3(1.0, 2.1, 0.12), [])
	_apply_bulb()



## The back wall round the glass blocks; the blocks glow with the day.
func _back_wall(x0: float, x1: float, z1: float, mat: Material) -> void:
	var b: Rect2 = RL.STORE_BLOCKS
	var z := z1 + 0.05
	var h := 2.7
	K.slab(root, Vector3(b.position.x - x0, h, 0.1), Vector3((x0 + b.position.x) * 0.5, h * 0.5 - 0.05, z), mat, "StoreBackA")
	K.slab(root, Vector3(x1 - b.end.x, h, 0.1), Vector3((b.end.x + x1) * 0.5, h * 0.5 - 0.05, z), mat, "StoreBackB")
	K.slab(root, Vector3(b.size.x, b.position.y + 0.1, 0.1), Vector3(b.get_center().x, (b.position.y - 0.1) * 0.5, z), mat, "StoreBackUnder")
	K.slab(root, Vector3(b.size.x, h - b.end.y, 0.1), Vector3(b.get_center().x, (b.end.y + h) * 0.5 - 0.05, z), mat, "StoreBackOver")
	var q := MeshInstance3D.new()
	q.name = "GlassBlocks"
	var qm := QuadMesh.new()
	qm.size = b.size
	q.mesh = qm
	_blocks_mat = K._base(Color(0.9, 0.92, 0.94))
	if ResourceLoader.exists(K.TEX + "glass_blocks.png"):
		_blocks_mat.albedo_texture = load(K.TEX + "glass_blocks.png")
		_blocks_mat.uv1_scale = Vector3(b.size.x / 0.2, b.size.y / 0.2, 1.0)
	_blocks_mat.emission_enabled = true
	_blocks_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_blocks_mat.emission_texture = _blocks_mat.albedo_texture
	_blocks_mat.emission = Color(0.9, 0.94, 1.0)
	q.material_override = _blocks_mat
	q.position = Vector3(b.get_center().x, b.get_center().y, z - 0.01)
	q.rotation_degrees.y = 180.0
	root.add_child(q)


func _hot(id: String, pos: Vector3, size: Vector3, meshes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Hot_" + id
	body.set_meta("extra_hot", id)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	body.add_child(cs)
	body.position = pos
	root.add_child(body)
	hot[id] = {"body": body, "meshes": meshes}


## Every frame: the bulb swinging on its cord (in steps), the day through the blocks.
func update(delta: float, daylight: float, power: bool) -> void:
	_t += delta
	# A pendulum that is pushed when the cord is pulled and dies away.
	_swing_v += (-_swing * 9.0 - _swing_v * 0.9) * delta
	_swing += _swing_v * delta
	if _bulb_pivot != null:
		var shown := floorf((_swing + sin(_t * 0.7) * 0.012) * 120.0) / 120.0
		_bulb_pivot.rotation.x = shown
	if _flicker > 0.0:
		_flicker -= delta
	var lit := bulb_on and power
	if light != null:
		var f := 1.0
		if _flicker > 0.0:
			f = 0.25 if int(_flicker * 24.0) % 3 == 0 else 1.0
		light.visible = lit and f > 0.3
		light.light_energy = 1.25 * f
	if day_light != null:
		day_light.light_energy = 0.55 * daylight
		day_light.visible = daylight > 0.02
	if _blocks_mat != null:
		_blocks_mat.emission_energy_multiplier = 0.25 + 1.1 * daylight


func set_bulb(on: bool, sound := true) -> void:
	if on == bulb_on:
		return
	bulb_on = on
	if on:
		_flicker = 0.22
	_swing_v += 0.55
	if sound:
		_play(SFX_CORD, -6.0)
	_apply_bulb()


func toggle_bulb() -> void:
	set_bulb(not bulb_on)


func is_dark(daylight: float, power: bool) -> bool:
	return not (bulb_on and power) and daylight < 0.25


func _apply_bulb() -> void:
	if _bulb_mesh == null:
		return
	var m := _bulb_mesh.material_override as StandardMaterial3D
	if m == null:
		return
	m.emission_enabled = bulb_on
	m.emission = Color(1.0, 0.85, 0.55)
	m.emission_energy_multiplier = 0.6 if bulb_on else 0.0
	m.albedo_color = Color(1, 1, 1) if bulb_on else Color(0.55, 0.52, 0.48)


func _play(path: String, db: float) -> void:
	if _one != null and ResourceLoader.exists(path):
		_one.stream = load(path)
		_one.volume_db = db
		_one.play()
