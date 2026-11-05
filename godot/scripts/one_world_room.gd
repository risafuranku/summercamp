extends RefCounted

## One world (W26, the user 4. 11.: "from outside the rooms real, from inside the camp real,
## always the one same world"): a room is built in the camp's own world where its building
## stands, its viewport drawing that world from the room's eye. Its windows and doorway are
## openings in the building's walls, the sun in it is the camp's own. What every such room
## has in common (the reception has its own copy of these in building_interior.gd).

## The building's glass, its door leaf, its window frames (building_models.GLASS_LAYER): the
## room's eye leaves them out (the room has its own glass, frames and door in them).
const GLASS_LAYER := 1 << 19
## Where a room is put to have its cube drawn (scripts/ui/room_cube.gd): high over the camp,
## past the camp's eye's far plane (under the land nothing is drawn at all).
const BAKE_UP := 2000.0
## The camp's weather -> how much of the day's light it lets through (WEATHER_DAY_K, the
## reception's).
const WEATHER_DAY_K := {1: 0.94, 2: 0.76, 3: 0.68, 4: 0.54, 5: 0.36}


## The camp's own view (main's SubViewport) while you are in a room: not drawn (the room's
## viewport draws the camp through its windows: two views of it cost a third of the frame),
## nor heard from (the room's eye is the ear). `on` gives both back.
static func camp_view(tree: SceneTree, on: bool) -> void:
	var scene := tree.current_scene if tree != null else null
	var w3d = scene.get("_world_3d") if scene != null else null
	if not (w3d is Node3D) or not (w3d as Node3D).is_inside_tree():
		return
	var vp := (w3d as Node3D).get_viewport() as SubViewport
	if vp == null:
		return
	vp.audio_listener_enable_3d = on
	if not vp.has_meta("camp_update_mode"):
		vp.set_meta("camp_update_mode", vp.render_target_update_mode)
	vp.render_target_update_mode = int(vp.get_meta("camp_update_mode")) if on else SubViewport.UPDATE_DISABLED


## The room's viewport draws the camp's world (and the retro look treats it as a room's).
static func viewport(vp: SubViewport) -> void:
	vp.own_world_3d = false
	vp.set_meta("retro_room", true)


## The room's eye: far enough for the camp through its windows, the building's own glass
## and leaf left out, an exposure of its own (up by day: `eye_by_day`).
static func eye(cam: Camera3D) -> CameraAttributesPractical:
	cam.far = 600.0
	cam.cull_mask = 0xFFFFF & ~GLASS_LAYER
	var a := CameraAttributesPractical.new()
	cam.attributes = a
	return a


## The light inside the walls: an interior probe, its ambient the room's own (not the camp
## sky's). `fit` gives it its box.
static func probe(parent: Node3D, n: String) -> ReflectionProbe:
	var p := ReflectionProbe.new()
	p.name = n
	p.interior = true
	p.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.blend_distance = 0.15
	parent.add_child(p)
	return p


## The roof over the room keeps the rain out: weather_visuals' drops hide where they meet
## this box (they fall round your body, through the roofs).
static func dry(parent: Node3D, n: String) -> GPUParticlesCollisionBox3D:
	var d := GPUParticlesCollisionBox3D.new()
	d.name = n
	parent.add_child(d)
	return d


## The probe's and the dry box's extent: room space `lo`..`hi` (the floor to under the roof).
static func fit(p: ReflectionProbe, d: GPUParticlesCollisionBox3D, lo: Vector3, hi: Vector3) -> void:
	if p != null:
		p.position = (lo + hi) * 0.5
		p.size = hi - lo + Vector3(0.1, 0.0, 0.1)
	if d != null:
		d.position = (lo + hi) * 0.5 + Vector3(0, -0.25, 0)
		d.size = hi - lo + Vector3(0.1, 0.5, 0.1)


## How much the camp's sun shines now: 0 under the horizon and on a grey day, 1 a clear
## day's sun, low or high.
static func sun_shining(tree: SceneTree, weather: int) -> float:
	var scene := tree.current_scene if tree != null else null
	var sun = scene.get("sun") if scene != null else null
	if not (sun is DirectionalLight3D) or not (sun as Node3D).is_inside_tree() or not (sun as Node3D).visible:
		return 0.0
	var wk: float = WEATHER_DAY_K.get(weather, 1.0)
	return clampf((sun as DirectionalLight3D).light_energy, 0.0, 1.0) * wk * wk


## How far a room's own light goes down by day: `x` the day (by the hour, or while the sun
## still shines in), `y` how bright it is out there (a grey day has the lamp back on and
## the eye open for it).
static func day_of(daylight: float, tree: SceneTree, weather: int) -> Vector2:
	var day := maxf(clampf(daylight, 0.0, 1.0), sun_shining(tree, weather))
	return Vector2(day, day * float(WEATHER_DAY_K.get(weather, 1.0)))


## The room's sounds are the camp's now (a fridge, a stove, a telly): heard from the camp,
## they come through the walls.
static func sounds_through_walls(root: Node, walls: bool) -> void:
	if root == null:
		return
	var ws = load("res://scripts/ambient/world_sounds.gd")
	for n in root.find_children("*", "AudioStreamPlayer3D", true, false):
		var a := n as AudioStreamPlayer3D
		if not a.has_meta("bus_in"):
			a.set_meta("bus_in", str(a.bus))
		var bus_in := str(a.get_meta("bus_in"))
		a.bus = StringName(ws.wall_bus(bus_in) if walls else bus_in)


## A room's own layer (building_models.ROOM_LAYER, the businesses' rooms have it too): its
## lamps light it and nothing outside its walls (a hall's tubes lit the grass round the
## building through them). Every mesh under `root` on the camp's layer gets it, every lamp
## lights only it; again now and then for what comes in later (guests, things).
const ROOM_LAYER := 1 << 13


static func own_lights(root: Node) -> void:
	if root == null:
		return
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if (g.layers & 1) != 0 and (g.layers & ROOM_LAYER) == 0:
			g.layers |= ROOM_LAYER
	for n in root.find_children("*", "Light3D", true, false):
		(n as Light3D).light_cull_mask = ROOM_LAYER


## Window glass: a little grey-green, the sky and the sun's glint on it at a slant.
static func clear_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.68, 0.68, 0.14)
	m.roughness = 0.06
	m.metallic_specular = 0.9
	return m
