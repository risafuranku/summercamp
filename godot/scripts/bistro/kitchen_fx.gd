extends Node3D

## The kitchen's air in the room itself, in 3D (Build-style sprites standing up off the
## stations' surfaces, stepped twelve a second): steam off the pot while it is hot and off
## the fryer's oil while a basket is down, grey smoke off the pan when a slice is going
## black and off the pot when it catches. Seen from the room and from over the station.
## scripts/service_interior.gd makes one in the kitchen.

const LAYOUT := preload("res://scripts/bistro/bistro_layout.gd")
const RULES := preload("res://core/systems/bistro_rules.gd")
const STEAM := "res://assets/textury/camp/steam_puff.png"
const SMOKE := "res://assets/textury/bistro/smoke.png"
const STEP := 1.0 / 12.0
const PUFFS := 5
## Where on each surface the air comes off (its picture's 640x360 pixels).
const SPOTS := {"pan": ["stove", Vector2(205, 150)], "fryer": ["stove", Vector2(440, 150)], "pot": ["pot", Vector2(160, 150)]}

var key := ""
var kitchen: Node

var _sources: Dictionary = {}   # spot -> [Sprite3D]
var _acc := 0.0
var _t := 0.0
var _steam: Texture2D
var _smoke: Texture2D


func _ready() -> void:
	_steam = load(STEAM) if ResourceLoader.exists(STEAM) else null
	_smoke = load(SMOKE) if ResourceLoader.exists(SMOKE) else null
	for spot in SPOTS:
		var list: Array = []
		for i in PUFFS:
			var s := Sprite3D.new()
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.shaded = false
			s.transparent = true
			s.visible = false
			add_child(s)
			list.append(s)
		_sources[spot] = list


## A point on a station's surface (picture pixels) in this node's space.
func _at(station: String, px: Vector2) -> Vector3:
	var d: Dictionary = LAYOUT.SURFACES[station]
	var sz: Vector2 = d["size"]
	var local := Vector3((px.x / 640.0 - 0.5) * sz.x, 0.0, (px.y / 360.0 - 0.5) * sz.y)
	return (d["at"] as Vector3) + local.rotated(Vector3.UP, deg_to_rad(float(d["yaw"])))


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc < STEP or kitchen == null or key == "" or not is_visible_in_tree():
		return
	_acc = 0.0
	var s: Dictionary = kitchen.site(key)
	var pot: Dictionary = s["pot"]
	var st: Dictionary = kitchen.stove_state(key)
	_run("pot", int(pot["level"]) > 0 and float(pot["heat"]) >= 0.6, float(pot["catch"]) > 0.75 or kitchen.burnt_flash.has(key))
	_run("fryer", str(s["basket"]["st"]) == "down", false)
	var pan_busy := false
	for slot in s["pan"]:
		pan_busy = pan_busy or not (slot as Dictionary).is_empty()
	_run("pan", pan_busy, bool(st["burning"]))


## The puffs of one spot: rising and fading in a loop, steam or smoke, or none.
func _run(spot: String, on: bool, burning: bool) -> void:
	var list: Array = _sources[spot]
	var base := _at(str(SPOTS[spot][0]), SPOTS[spot][1])
	var tex := _smoke if burning else _steam
	for i in list.size():
		var p: Sprite3D = list[i]
		p.visible = (on or burning) and tex != null
		if not p.visible:
			continue
		p.texture = tex
		p.pixel_size = (0.26 if burning else 0.2) / float(maxi(1, tex.get_height()))
		var age := fmod(_t * (0.45 if burning else 0.35) + float(i) / float(list.size()), 1.0)
		var wob := sin(age * 6.0 + float(i) * 1.7) * 0.05
		p.position = base + Vector3(wob + (float(i % 3) - 1.0) * 0.06, 0.08 + age * (0.9 if burning else 0.6), 0.0)
		var col := Color(0.35, 0.33, 0.32) if burning else Color(0.95, 0.95, 0.92)
		col.a = (1.0 - age) * (0.85 if burning else 0.45)
		p.modulate = col
