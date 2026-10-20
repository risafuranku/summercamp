extends Node3D

## A dirty toilet or shower block stinks where you can see it (playtest 20. 10.): green
## wavy fumes rise out of its doors and off its roof, more of them and thicker the
## dirtier it is (MaintenanceRules.stink), and flies circle the doors when it is filthy.
## Build-engine billboards, stepped twelve a second; the fume frames are drawn by
## tools/gen_stink_sprites.py. Shaded, so at night they do not glow (nothing over the
## camp at night may read as a pair of eyes). maintenance_controller.gd says which block
## stinks how much (`set_block`); this only draws it.

const FUMES := preload("res://assets/textury/npc/stink_fumes.png")
const FRAMES := 6
const FRAME_FPS := 8.0
const STEP := 1.0 / 12.0
## People's pixel (73.6 px to the metre): a fume 64 px tall stands 0.87 m.
const PIXEL := 0.0136
## A fume rises this far over its life, then is gone and starts again.
const RISE := 0.9
const LIFE := 2.8
## Fumes per spot; the last ones only once the block is really bad.
const PUFFS := 3
const FLIES := 3
const FLIES_FROM := 0.5
## The doors the block models build (building_models._toilets / _showers).
const DOOR_NAMES := ["Door", "Door0", "Door1"]

var _blocks: Dictionary = {}  # key -> {structure, level, spots: [Vector3 local], puffs: [Sprite3D], flies: [Sprite3D]}
var _acc := 0.0
var _time := 0.0
var _fly_tex: Texture2D


## `level` 0 (clean: nothing) .. 1 (filthy). A key not set again by `keep_only` goes.
func set_block(key: String, structure: Node3D, level: float) -> void:
	var b: Dictionary = _blocks.get(key, {})
	if level <= 0.0 or structure == null or not is_instance_valid(structure):
		_drop(key)
		return
	if b.is_empty() or b["structure"] != structure:
		_drop(key)
		b = _build(structure)
		_blocks[key] = b
	b["level"] = clampf(level, 0.0, 1.0)


## Takes away every block not in `keys` (demolished, or clean again).
func keep_only(keys: Dictionary) -> void:
	for key in _blocks.keys():
		if not keys.has(key):
			_drop(key)


func clear_all() -> void:
	for key in _blocks.keys():
		_drop(key)


func _drop(key: String) -> void:
	var b: Dictionary = _blocks.get(key, {})
	for n in b.get("puffs", []) + b.get("flies", []):
		if is_instance_valid(n):
			n.queue_free()
	_blocks.erase(key)


## Where it stinks from: a step out of each door, and the middle of the roof.
func _build(structure: Node3D) -> Dictionary:
	var inv := structure.global_transform.affine_inverse()
	var spots: Array = []
	var doors: Array = []
	for n in structure.find_children("Door*", "", true, false):
		if DOOR_NAMES.has(str(n.name)) and n is Node3D:
			doors.append(inv * ((n as Node3D).global_position))
	for d in doors:
		spots.append((d as Vector3) + Vector3(0.0, 0.45, 0.32))
	var top := _top_of(structure)
	spots.append(inv * Vector3(structure.global_position.x, top - 0.15, structure.global_position.z))
	var puffs: Array = []
	for s in spots.size():
		for i in PUFFS:
			var p := Sprite3D.new()
			p.texture = FUMES
			p.hframes = FRAMES
			p.pixel_size = PIXEL
			p.offset = Vector2(0.0, 32.0)
			p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			p.shaded = true
			p.double_sided = true
			p.visible = false
			p.set_meta("spot", s)
			p.set_meta("index", i)
			p.set_meta("seed", float(s * 3 + i) * 0.37 + randf())
			add_child(p)
			puffs.append(p)
	var flies: Array = []
	if not doors.is_empty():
		for i in FLIES:
			var f := Sprite3D.new()
			f.texture = _fly_texture()
			f.pixel_size = PIXEL
			f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			f.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			f.shaded = true
			f.visible = false
			f.set_meta("spot", i % doors.size())
			f.set_meta("seed", randf() * TAU)
			add_child(f)
			flies.append(f)
	return {"structure": structure, "level": 0.0, "spots": spots, "puffs": puffs, "flies": flies}


func _top_of(structure: Node3D) -> float:
	var top := structure.global_position.y + 2.4
	var found := false
	for n in structure.find_children("*", "VisualInstance3D", true, false):
		if n is Sprite3D or not (n as VisualInstance3D).visible:
			continue
		var box: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		top = box.end.y if not found else maxf(top, box.end.y)
		found = true
	return top


func _fly_texture() -> Texture2D:
	if _fly_tex == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.05, 0.05, 0.04, 1.0))
		img.set_pixel(1, 0, Color(0, 0, 0, 0))
		_fly_tex = ImageTexture.create_from_image(img)
	return _fly_tex


func _process(delta: float) -> void:
	if _blocks.is_empty():
		return
	_acc += delta
	if _acc < STEP:
		return
	_time += _acc
	_acc = 0.0
	for key in _blocks.keys():
		var b: Dictionary = _blocks[key]
		var s: Node3D = b["structure"]
		if not is_instance_valid(s):
			_drop(key)
			continue
		_step_block(b, s)


func _step_block(b: Dictionary, s: Node3D) -> void:
	var level: float = b["level"]
	var xf := s.global_transform
	var right := xf.basis.x.normalized()
	var spots: Array = b["spots"]
	# Thin at first, three thick fumes per spot when it is filthy.
	var shown := clampi(1 + int(level * float(PUFFS)), 1, PUFFS)
	var strength := lerpf(0.35, 0.85, level)
	for p_any in b["puffs"]:
		var p: Sprite3D = p_any
		var seed: float = p.get_meta("seed")
		if int(p.get_meta("index")) >= shown:
			p.visible = false
			continue
		var phase := fmod(_time / LIFE + seed, 1.0)
		var base: Vector3 = xf * (spots[int(p.get_meta("spot"))] as Vector3)
		var drift := sin(_time * 0.9 + seed * 7.0) * 0.12
		p.global_position = base + right * drift + Vector3(0.0, phase * RISE, 0.0)
		var grow := 0.85 + 0.45 * phase
		p.scale = Vector3(grow, grow, grow)
		p.frame = int(_time * FRAME_FPS + seed * 13.0) % FRAMES
		var fade := smoothstep(0.0, 0.2, phase) * (1.0 - smoothstep(0.6, 1.0, phase))
		p.modulate = Color(1.0, 1.0, 1.0, strength * fade)
		p.visible = fade > 0.02
	var buzzing := level >= FLIES_FROM
	for f_any in b["flies"]:
		var f: Sprite3D = f_any
		f.visible = buzzing
		if not buzzing:
			continue
		var seed: float = f.get_meta("seed")
		var door: Vector3 = xf * (spots[int(f.get_meta("spot"))] as Vector3)
		# Darting round the door in a jerky loop.
		var a := _time * (2.3 + fmod(seed, 1.0)) + seed
		var r := 0.28 + 0.12 * sin(_time * 3.1 + seed)
		f.global_position = door + Vector3(cos(a) * r, 0.1 + 0.25 * sin(a * 1.7), sin(a) * r)
