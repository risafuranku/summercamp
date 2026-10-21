extends RefCounted

## Inside the staffroom (built by scripts/service_interior.gd for the "staff" profile,
## the boxes by scripts/staff/staffroom_plan.gd; DESIGN.md §7c). Two rooms, point and
## click, one walk through the open doorway between them (scripts/ui/walk_path.gd):
##   the lounge   the old chunky laptop on the table (click: you sit down at it and the
##                office PC's desktop is on its screen, scripts/staff/laptop_view.gd),
##                the staffroom's books beside it (the hands, their jobs, the lockers:
##                scripts/staff/staff_ledger.gd), the coffee machine (a cup), the fridge,
##                the TV (its programmes, round and off), the windows and their curtains;
##   the boiler   the lockers (one to a hand: their name on the tape, their coat inside),
##                the mattress (yours: from the evening a click lies you down to sleep,
##                scripts/lodge_bed.gd's "staff" bed), the boiler.
## The hands resting in here are the runtime's (scripts/staff/staff_runtime.gd): on the
## sofa and in the armchairs. Another warden at the laptop
## sits on its chair with their back to you (service_interior.coop_job_spot).

const PLAN = preload("res://scripts/staff/staffroom_plan.gd")
const WALK_PATH = preload("res://scripts/ui/walk_path.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const STAFF_RULES = preload("res://core/systems/staff_rules.gd")
const STAFF_DIR := "res://assets/textury/npc/staff/"
const PERSON_M := 1.74
const SFX := {
	"tv_on": "res://assets/sfx/backroom/tv_on.mp3", "tv_off": "res://assets/sfx/backroom/tv_off.mp3",
	"tv_hiss": "res://assets/sfx/backroom/tv_hiss.mp3", "fridge": "res://assets/sfx/jednota/clunk.mp3",
	"coffee": "res://assets/sfx/bistro/pour.mp3", "locker": "res://assets/sfx/jednota/drawer.mp3",
	"steps": "res://assets/sfx/rooms/steps_wood.mp3", "book": "res://assets/sfx/desk/book.mp3",
}
## The TV's programmes, round on each click (the last: off).
const SHOWS := ["tvshow_testcard", "tvshow_forest", "tvshow_weather"]
const SHOW_FALLBACK := {"tvshow_testcard": "tv_testcard", "tvshow_forest": "tv_programme", "tvshow_weather": "tv_programme"}

var host                       # service_interior
var root: Node3D
var refs: Dictionary = {}
var room := "lounge"
var glint = HOVER_GLINT.new()
var _bodies: Dictionary = {}   # hot id -> StaticBody3D
var _hover := ""
var _walk: Tween
var _sfx: AudioStreamPlayer
var _tv := -1
var _tv_t := 0.0
var _tv_tex: Array = []
var _figs: Dictionary = {}     # slug -> Sprite3D
var _figs_t := 0.0
var _open_locker := -1
var _laptop_mat: StandardMaterial3D


func build(host_node, parent: Node3D) -> void:
	host = host_node
	root = Node3D.new()
	root.name = "Staffroom"
	parent.add_child(root)
	refs = PLAN.build(root, false)
	_sfx = AudioStreamPlayer.new()
	host.add_child(_sfx)
	for id in refs["hot"]:
		var h: Array = refs["hot"][id]
		_body(str(id), h[0], h[1])
	# The doorway through to the boiler room, and back.
	_body("to_boiler", Vector3(PLAN.L_MAX.x - 0.05, PLAN.FLOOR + 1.0, PLAN.INNER_Z), Vector3(0.3, 2.0, PLAN.INNER_W))
	_body("to_lounge", Vector3(PLAN.B_MIN.x + 0.05, PLAN.FLOOR + 1.0, PLAN.INNER_Z), Vector3(0.3, 2.0, PLAN.INNER_W))
	for s in SHOWS:
		var t := str(PLAN.tex(s, str(SHOW_FALLBACK[s])))
		_tv_tex.append(load(PLAN.CAMP + t + ".png") if ResourceLoader.exists(PLAN.CAMP + t + ".png") else null)
	_laptop_mat = (refs["laptop_screen"] as MeshInstance3D).material_override as StandardMaterial3D
	apply_gear()


func _body(id: String, at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.name = "Hot_" + id
	b.set_meta("staff_hot", id)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = at
	root.add_child(b)
	_bodies[id] = b


## The windows made real (scripts/ui/window_portal.gd): [{w, root}] for the interior.
func make_windows(portal_script) -> Array:
	var out: Array = []
	for id in PLAN.WINDOW_ORDER:
		var w: Dictionary = PLAN.WINDOWS[id]
		var wp = portal_script.make(host, root, w["c"], w["out"], w["size"], "curtain_floral")
		out.append({"w": wp, "root": root, "id": id, "room": w["room"]})
	return out


# ── the room you are in ──────────────────────────────────────────────────────

func set_room(which: String, camera: Camera3D) -> void:
	room = which
	if camera == null:
		return
	camera.position = PLAN.EYE_BOILER if which == "boiler" else PLAN.EYE_LOUNGE
	camera.rotation = PLAN.LOOK_BOILER if which == "boiler" else PLAN.LOOK_LOUNGE
	camera.fov = 70.0
	camera.far = 22.0


func walking() -> bool:
	return _walk != null and _walk.is_valid() and _walk.is_running()


## Through the doorway to the other room, one smooth walk.
func walk_to(which: String) -> void:
	if which == room or walking():
		return
	var cam: Camera3D = host._interior_camera
	var way: Array = PLAN.WAY_TO_BOILER.duplicate()
	if which == "lounge":
		way.reverse()
	var keys: Array = [{"pos": cam.position, "rot": cam.rotation}]
	for i in range(1, way.size()):
		var p: Vector3 = way[i]
		var rot: Vector3
		if i == way.size() - 1:
			rot = PLAN.LOOK_BOILER if which == "boiler" else PLAN.LOOK_LOUNGE
		else:
			var d: Vector3 = (way[i + 1] as Vector3) - p
			rot = Vector3(-0.05, atan2(-d.x, -d.z), 0.0)
		keys.append({"pos": p, "rot": rot})
	_play("steps", -10.0)
	glint.clear()
	_walk = WALK_PATH.play(host, cam, keys, 1.5)
	_walk.finished.connect(func():
		room = which
		host._cam_base_rot = cam.rotation
		host._look.reset()
		host._active_subroom = which)


# ── hover and click ──────────────────────────────────────────────────────────

## The thing under the cursor in the room you are in ("" none); the hand and the glint.
func update_hover(mouse: Vector2) -> String:
	if walking():
		_hover = ""
		glint.clear()
		return ""
	var hit: Dictionary = host._raycast_world(mouse)
	var n = hit.get("collider", null) as Node
	var id := ""
	while n != null:
		if n.has_meta("staff_hot"):
			id = str(n.get_meta("staff_hot"))
			break
		# Your mattress (lodge_bed's click box, there only when it is time to sleep).
		if str(n.get_meta("interior_click_type", "")) == "lodge_bed":
			id = "bed"
			break
		n = n.get_parent()
	if id.begins_with("locker") and int(id.substr(6)) >= _lockers():
		id = ""
	if id == "to_boiler" and room != "lounge" or id == "to_lounge" and room != "boiler":
		id = ""
	_hover = id
	if id == "":
		glint.clear()
		return ""
	HandCursor.want(HandCursor.WALK if id.begins_with("to_") else HandCursor.POINT)
	glint.show_on(_meshes_of(id))
	return id


func hovered() -> String:
	return _hover


## A line for the room's sentence under the cursor ("" none).
func hover_line(id: String) -> String:
	match id:
		"laptop":
			return "The laptop: the office PC from here"
		"ledger":
			return "The staffroom's books: the hands, their jobs"
		"coffee":
			return "Coffee"
		"fridge":
			return "The fridge"
		"tv":
			return "The TV"
		"to_boiler":
			return "The boiler room"
		"to_lounge":
			return "Back to the lounge"
	if id.begins_with("locker"):
		var who := _locker_name(int(id.substr(6)))
		return tr("%s's locker") % who if who != "" else tr("An empty locker")
	if id == "bed":
		return "The mattress: lie down"
	return ""


func _meshes_of(id: String) -> Array:
	match id:
		"laptop":
			return [root.find_child("Laptop", true, false)]
		"ledger":
			return [root.find_child("Ledger", true, false), root.find_child("LedgerPages", true, false)]
		"coffee":
			return [root.find_child("CoffeeMaker", true, false)]
		"fridge":
			return [root.find_child("Fridge", true, false), root.find_child("FridgeFront", true, false)]
		"tv":
			return [root.find_child("Tv", true, false)]
		"to_boiler", "to_lounge":
			return [root.find_child("InnerDoorHinge", true, false)]
	if id.begins_with("locker"):
		var i := int(id.substr(6))
		return [refs["lockers"][i]] if i < (refs["lockers"] as Array).size() else []
	if id == "bed":
		return [refs["mattress"]]
	return []


## A click on what is hovered: true when it was something here.
func click() -> bool:
	var id := _hover
	# The mattress is lodge_bed's to answer (it lies you down).
	if id == "" or id == "bed":
		return false
	match id:
		"to_boiler":
			walk_to("boiler")
		"to_lounge":
			walk_to("lounge")
		"laptop":
			glint.clear()
			host.call("_staff_open_laptop")
		"ledger":
			glint.clear()
			_play("book", -8.0)
			host.call("_staff_open_ledger")
		"coffee":
			_play("coffee", -6.0)
			_say(["You pour a cup. It has been on the plate since the morning.", "Black, thick, lukewarm. It does the job.", "The jug is nearly empty. Somebody had the rest."][randi() % 3])
		"fridge":
			_play("fridge", -6.0)
			_say(_fridge_line())
		"tv":
			_tv_click()
		_:
			if id.begins_with("locker"):
				_locker_click(int(id.substr(6)))
	return true


func _fridge_line() -> String:
	var lines := ["Three bottles of beer, a jar of pickles and somebody's lunch in a bag with a name on it.",
		"Milk past its date. A paper bag of something soft. A note on the shelf: DO NOT TOUCH.",
		"Cold air and the smell of salami. The light inside flickers when you shut it."]
	return str(lines[(CoreRoot.get_day() if CoreRoot != null else 0) % lines.size()])


func _locker_click(i: int) -> void:
	_play("locker", -6.0)
	var parts: Array = refs["lockers_open"][i]
	var open: bool = not (parts[1] as Node3D).visible
	if _open_locker >= 0 and _open_locker != i:
		var prev: Array = refs["lockers_open"][_open_locker]
		(prev[0] as Node3D).visible = true
		(prev[1] as Node3D).visible = false
	(parts[0] as Node3D).visible = not open
	(parts[1] as Node3D).visible = open
	_open_locker = i if open else -1
	var who := _locker_name(i)
	if open:
		_say(tr("%s's work coat, rubber boots, a thermos.") % who if who != "" else tr("Empty. A coat hanger and the smell of somebody else's boots."))


func _locker_name(i: int) -> String:
	var crew: Array = _crew()
	return str(crew[i].get("name", "")) if i < crew.size() else ""


func _crew() -> Array:
	var st = CoreRoot.get_state().biz.get("staff", {}) if CoreRoot != null and CoreRoot.get_state() != null else {}
	return st.get("crew", []) if st is Dictionary else []


func _staff() -> Dictionary:
	var st = CoreRoot.get_state().biz.get("staff", {}) if CoreRoot != null and CoreRoot.get_state() != null else {}
	return st if st is Dictionary else {}


func _lockers() -> int:
	return STAFF_RULES.gear_count(_staff(), "locker")


func _armchairs() -> int:
	return STAFF_RULES.gear_count(_staff(), "armchair")


## As many lockers and armchairs as the books have bought.
func apply_gear() -> void:
	var nl := _lockers()
	for i in (refs["lockers"] as Array).size():
		(refs["lockers"][i] as Node3D).visible = i < nl
		var b: StaticBody3D = _bodies.get("locker%d" % i)
		if b != null:
			b.process_mode = Node.PROCESS_MODE_INHERIT if i < nl else Node.PROCESS_MODE_DISABLED
	var na := _armchairs()
	for i in (refs["armchairs"] as Array).size():
		(refs["armchairs"][i] as Node3D).visible = i < na


# ── the TV ───────────────────────────────────────────────────────────────────

func _tv_click() -> void:
	_tv += 1
	if _tv >= SHOWS.size():
		_tv = -1
		_play("tv_off", -6.0)
	else:
		_play("tv_on" if _tv == 0 else "tv_hiss", -8.0)
	_tv_t = 0.0
	_apply_tv()


func _apply_tv() -> void:
	var m := (refs["tv_screen"] as MeshInstance3D).material_override as StandardMaterial3D
	if _tv < 0 or _tv >= _tv_tex.size() or _tv_tex[_tv] == null:
		m.albedo_texture = null
		m.albedo_color = Color(0.05, 0.06, 0.06)
		return
	m.albedo_texture = _tv_tex[_tv]
	# A picture tube: the brightness breathes a little, a frame of roll now and then.
	var k := 0.9 + 0.1 * sin(_tv_t * 7.0)
	if int(_tv_t * 8.0) % 37 == 0:
		k = 1.25
	m.albedo_color = Color(k, k, k)


func tv_on() -> bool:
	return _tv >= 0


# ── each frame while open ────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_tv_t += delta
	if _tv >= 0:
		_apply_tv()
	_update_laptop()
	_figs_t -= delta
	if _figs_t <= 0.0:
		_figs_t = 0.5
		apply_gear()
		_update_figures()


## The laptop's screen: the office PC's desktop (its picture as it was last drawn; while
## somebody sits at it, live).
func _update_laptop() -> void:
	if _laptop_mat == null:
		return
	var tex: Texture2D = host.call("_staff_pc_texture")
	if tex != null:
		_laptop_mat.albedo_texture = tex
		_laptop_mat.albedo_color = Color(1, 1, 1) if bool(host.call("_staff_laptop_live")) else Color(0.55, 0.6, 0.62)
	else:
		_laptop_mat.albedo_texture = null
		_laptop_mat.albedo_color = Color(0.1, 0.13, 0.16)


## The hands resting in here (staff_runtime.inside()): on the sofa, in the armchairs.
func _update_figures() -> void:
	var rt = _runtime()
	var want: Array = rt.inside() if rt != null else []
	var seen := {}
	for f in want:
		var slug := str(f["slug"])
		seen[slug] = true
		var spr: Sprite3D = _figs.get(slug)
		if spr == null or not is_instance_valid(spr):
			spr = Sprite3D.new()
			spr.name = "Hand_" + slug
			spr.pixel_size = PERSON_M / 128.0
			spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			spr.shaded = true
			root.add_child(spr)
			_figs[slug] = spr
		spr.set_meta("spot", str(f.get("spot", "")))
		spr.set_meta("name", str(f.get("name", "")))
		_place(spr, slug, str(f["pose"]), f["at"], f.get("head", Vector3.ZERO))
	for slug in _figs.keys():
		if not seen.has(slug):
			(_figs[slug] as Node).queue_free()
			_figs.erase(slug)


static func pose_tex(slug: String, pose: String) -> Texture2D:
	var p := STAFF_DIR + slug + "_" + pose + ".png"
	if ResourceLoader.exists(p):
		return load(p)
	p = STAFF_DIR + slug + ".png"
	return load(p) if ResourceLoader.exists(p) else null


## A hand's sprite at `at` (building space, on the floor): lying along a mattress (the
## head toward `head`), sitting on the sofa, standing.
static func _place(spr: Sprite3D, slug: String, pose: String, at: Vector3, head: Vector3) -> void:
	var t := pose_tex(slug, pose)
	spr.texture = t
	spr.visible = t != null
	spr.offset = Vector2.ZERO
	spr.centered = true
	if t == null:
		return
	var h := float(t.get_height()) * spr.pixel_size
	match pose:
		"lie":
			# Flat on the mattress, along it, seen from the side (a Build sprite lying).
			spr.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			var along := head - at
			along.y = 0.0
			var yaw := atan2(along.x, along.z) + PI * 0.5 if along.length() > 0.01 else 0.0
			spr.rotation = Vector3(-PI * 0.5, yaw, 0.0)
			spr.position = at + Vector3(0, PLAN.MATTRESS_SIZE.y + 0.02, 0)
			spr.flip_h = false
		"sit":
			spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			spr.rotation = Vector3.ZERO
			spr.position = at + Vector3(0, h * 0.5 + 0.1, 0)
		_:
			spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			spr.rotation = Vector3.ZERO
			spr.position = at + Vector3(0, h * 0.5, 0)


func _runtime():
	var tree: SceneTree = host.get_tree() if host != null and host.is_inside_tree() else null
	return tree.get_first_node_in_group("staff_runtime") if tree != null else null


func on_open() -> void:
	set_room("lounge", host._interior_camera)
	host._active_subroom = "lounge"
	_open_locker = -1
	for parts in refs["lockers_open"]:
		(parts[0] as Node3D).visible = true
		(parts[1] as Node3D).visible = false
	_figs_t = 0.0


func _say(text: String) -> void:
	var main = host.get_tree().current_scene if host != null and host.is_inside_tree() else null
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null:
		hud.push_status(tr(text), 1)


func _play(key: String, db: float) -> void:
	var path := str(SFX.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.volume_db = db
		_sfx.play()
