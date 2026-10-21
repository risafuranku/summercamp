extends Control

## Room preparation inside an interior (tent, cabin): the things that need doing glow
## faintly under the cursor; hold the left mouse button on one and work it with the job's
## gesture (scripts/ui/gesture.gd: the broom to and fro, the brush round, the bed picked
## up and patted; the brief of 21. 10.): every stroke the hand makes the mess smaller and
## a pixel ring round the cursor fills a dot further, the sound of the work plays while
## you work; stand still and after a few seconds a see-through hand shows the motion. When
## the ring closes the thing is done (the interior swaps its look) and the checklist ticks.
##
## The interior owns the 3D: it registers each target with a collision body and the
## meshes to highlight, and listens to `task_completed`. Rules (what tasks exist, how
## long they take) come from core/systems/room_rules.gd through GuestManager.

signal task_completed(task_id: String)

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const WORK_HAND = preload("res://scripts/ui/work_hand.gd")
const GESTURE = preload("res://scripts/ui/gesture.gd")
## Mess that gets smaller stroke by stroke (a made bed does not).
const SHRINKS := ["Scrubbing", "Sweeping", "Mopping", "Wiping", "Scraping", "Clearing up", "Picking up", "Bagging"]
const SCRUB = preload("res://scripts/scrub_minigame.gd")
## The thing being worked on shakes in steps, this many a second (see work_hand.gd).
const SHAKE_FPS := 10.0
const SFX_DIR := "res://assets/sfx/rooms/"
const SFX_BY_TASK := {"bed": "task_bed.mp3", "floor": "task_litter.mp3", "bathroom": "task_scrub.mp3"}
const SFX_DONE := "task_done.mp3"
const SFX_READY := "room_ready.mp3"
const RING_DOTS := 16
## Picked up with one click, no gesture (playtest 21. 10.: "picking up the mess just a
## click; I can't move the mouse enough to clear the cans").
const CLICK_VERBS := ["Picking up", "Clearing up", "Bagging", "Throwing out"]
## Missed by the ray, a thing of the mess this close on the screen (a share of the view's
## height) is still taken: cans far off are a few pixels.
const MAGNET := 0.07

var _camera: Camera3D
var _viewport: SubViewport
var _targets: Dictionary = {}   # task_id -> {body, meshes, label, verb, seconds, done}
var _hover := ""
var _holding := ""
var _progress := 0.0
var _room_label := ""
var _room_status := ""
var _highlight: StandardMaterial3D
var _work_player: AudioStreamPlayer
var _one_shot: AudioStreamPlayer
var _scale := 3
var _checklist: VBoxContainer
var _prompt: Label
var _t := 0.0
var _hand: Control
var _shake_acc := 0.0
var _shaken: Dictionary = {}   # MeshInstance3D -> its rest position
## Toilets are scrubbed close up (scripts/scrub_minigame.gd), not held.
var _scrub
var _lmb_was := false
var _scrub_seed := 0
var _gesture = GESTURE.new()
var _mouse_last := Vector2.INF
var _scaled: Dictionary = {}    # MeshInstance3D -> its scale before the work


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(camera: Camera3D, viewport: SubViewport) -> void:
	_camera = camera
	_viewport = viewport
	_highlight = StandardMaterial3D.new()
	_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_highlight.albedo_color = Color(1.0, 0.85, 0.45, 0.32)
	_highlight.cull_mode = BaseMaterial3D.CULL_DISABLED
	_work_player = AudioStreamPlayer.new()
	_work_player.volume_db = -4.0
	add_child(_work_player)
	_one_shot = AudioStreamPlayer.new()
	_one_shot.volume_db = -3.0
	add_child(_one_shot)
	_hand = WORK_HAND.new()
	_hand.show_behind_parent = true
	_hand.name = "WorkHand"
	add_child(_hand)
	_build_overlay()


func clear_targets() -> void:
	_set_hover("")
	_cancel_hold()
	_targets.clear()


## One thing to do. `body` is what the cursor ray hits; `meshes` light up on hover.
func add_target(task: Dictionary, body: CollisionObject3D, meshes: Array) -> void:
	var id := str(task.get("id", ""))
	_targets[id] = {
		"body": body,
		"meshes": meshes,
		"label": str(task.get("label", id)),
		"verb": str(task.get("verb", "Working")),
		"seconds": float(task.get("seconds", 1.5)),
		"sfx": str(task.get("sfx", SFX_BY_TASK.get(id, "task_litter.mp3"))),
		"scrub": bool(task.get("scrub", false)),
		"done": false,
	}


## The room's state from GuestManager.get_room_state(): label, status, which are done.
func set_room(room: Dictionary) -> void:
	_room_label = str(room.get("label", ""))
	_room_status = str(room.get("status", ""))
	var done: Array = room.get("done", [])
	var occupied := bool(room.get("occupied", false))
	for id in _targets.keys():
		_targets[id]["done"] = done.has(id) or _room_status == "ready" or occupied
	_refresh_checklist(room)


func is_busy() -> bool:
	return not _hover.is_empty()


## The scrub close-up is open over the room.
func is_scrubbing() -> bool:
	return _scrub != null and _scrub.is_open()


## Co-op: the jobs the other wardens' hands are on in this room (InteriorManager.coop_partner):
## not yours to take while they are at it.
var coop_taken: Array = []


## The job your hands are on now ("" when none): held, or the bowl being scrubbed.
## Co-op shows the other warden at it (InteriorManager.coop_partner).
func working_on() -> String:
	if not _holding.is_empty():
		return _holding
	if is_scrubbing() and _scrub.get("_task") != null:
		return str(_scrub.get("_task"))
	return ""


## Where a job's mess is (its body, in the room's own world) and how it is done:
## {pos: Vector3, verb: String}, or {} when the room has no such job.
func target_info(id: String) -> Dictionary:
	var t: Dictionary = _targets.get(id, {})
	var body = t.get("body", null)
	if body == null or not is_instance_valid(body) or not (body as Node3D).is_inside_tree():
		return {}
	return {"pos": (body as Node3D).global_position, "verb": str(t.get("verb", "")), "done": bool(t.get("done", false))}


## The interior's day / room key: the same bowl gets new filth on a new day.
func set_scrub_seed(seed: int) -> void:
	_scrub_seed = seed


func _open_scrub(id: String) -> void:
	if _scrub == null:
		_scrub = SCRUB.new()
		add_child(_scrub)
		_scrub.finished.connect(func(done_id: String):
			if _targets.has(done_id) and not _targets[done_id]["done"]:
				_finish(done_id))
	_cancel_hold()
	_set_hover("")
	_scrub.open(id, absi(("%s|%d" % [id, _scrub_seed]).hash()))


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree() or _camera == null:
		return
	var lmb_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var pressed_now := lmb_now and not _lmb_was
	_lmb_was = lmb_now
	if is_scrubbing():
		_prompt.visible = false
		queue_redraw()
		return
	var hit := _target_under_cursor()
	if hit != "" and coop_taken.has(hit) and hit != _holding:
		hit = ""
	if _holding.is_empty():
		_set_hover(hit)
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed_now and not _hover.is_empty() and _holding.is_empty() and bool(_targets[_hover].get("scrub", false)):
		_open_scrub(_hover)
		return
	if pressed_now and not _hover.is_empty() and _holding.is_empty() and str(_targets[_hover].get("verb", "")) in CLICK_VERBS:
		_pick_up(_hover)
		return
	if lmb and not _hover.is_empty() and not bool(_targets[_hover].get("scrub", false)) and (_holding.is_empty() or _holding == _hover):
		if _holding.is_empty():
			_start_hold(_hover)
		if hit != _holding:
			_cancel_hold()
		else:
			var m := get_viewport().get_mouse_position()
			var motion := m - _mouse_last if _mouse_last != Vector2.INF else Vector2.ZERO
			_mouse_last = m
			var t: Dictionary = _targets[_holding]
			var strokes: int = _gesture.feed(motion, delta, get_viewport().get_visible_rect().size.y)
			if strokes > 0:
				_progress += float(strokes) / float(GESTURE.strokes_for(float(t["seconds"])))
				_hand.stroke()
				_shrink(t)
				if not _work_player.playing and _work_player.stream != null:
					_work_player.play()
			elif _gesture.idle > 0.9 and _work_player.playing:
				_work_player.stop()
			_hand.aim(m)
			_hand.gesture_offset = Vector2.ZERO
			_hand.ghost_kind = _gesture.kind if _gesture.idle > 2.4 else ""
			if _gesture.idle < 0.4:
				_shake(t, delta)
			if _progress >= 1.0:
				_finish(_holding)
	elif not lmb and not _holding.is_empty():
		_cancel_hold()
	# Gentle pulse on the hovered thing.
	if _highlight != null:
		_highlight.albedo_color.a = 0.24 + 0.14 * (0.5 + 0.5 * sin(_t * 5.0))
	_prompt.visible = not _hover.is_empty()
	if _prompt.visible:
		var target: Dictionary = _targets[_hover]
		var how := "CLICK" if bool(target.get("scrub", false)) or str(target.get("verb", "")) in CLICK_VERBS else "[LMB]"
		_prompt.text = ("%s..." % str(target["verb"]).to_upper()) if not _holding.is_empty() else ("%s  %s" % [how, str(target["label"]).to_upper()])
		var m := get_viewport().get_mouse_position()
		_prompt.position = (m + Vector2(-_prompt.size.x * 0.5, 16.0 * _scale)).floor()
	queue_redraw()


func _draw() -> void:
	if _holding.is_empty():
		return
	var m := get_viewport().get_mouse_position().floor()
	var radius := 9.0 * _scale
	var dot := float(_scale) * 2.0
	var lit := int(floor(_progress * RING_DOTS))
	for i in RING_DOTS:
		var a := -PI * 0.5 + TAU * float(i) / float(RING_DOTS)
		var p := (m + Vector2(cos(a), sin(a)) * radius - Vector2(dot, dot) * 0.5).floor()
		draw_rect(Rect2(p + Vector2(_scale, _scale), Vector2(dot, dot)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(p, Vector2(dot, dot)), RETRO_UI.C_AMBER if i < lit else Color(0.25, 0.22, 0.18, 0.9))


# ── internals ─────────────────────────────────────────────────────────────────

## Shot driver (tools/coop_check.gd): the job the cursor is taken to be on ("" the real
## cursor). Two copies of the game on one desktop share the one OS cursor.
var debug_aim := ""


func _target_under_cursor() -> String:
	if debug_aim != "" and _targets.has(debug_aim):
		return "" if bool(_targets[debug_aim].get("done", false)) else debug_aim
	# A SubViewport with its own world returns null from get_world_3d(); ask the camera.
	if _viewport == null or _camera.get_world_3d() == null:
		return ""
	var screen := get_viewport().get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return ""
	var m := get_viewport().get_mouse_position()
	var local := Vector2(clampf(m.x / screen.x, 0.0, 1.0) * float(_viewport.size.x), clampf(m.y / screen.y, 0.0, 1.0) * float(_viewport.size.y))
	return str(_pick(local)[0])


## Shot driver: for every task, what a ray at its own mess hits ([id, hit, collider]).
func debug_probe() -> Array:
	var out := []
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		var at: Vector3 = (t["body"] as Node3D).global_position
		for mm in t["meshes"]:
			if mm is MeshInstance3D and is_instance_valid(mm) and (mm as Node3D).is_visible_in_tree():
				at = (mm as Node3D).global_position
				break
		if _camera.is_position_behind(at):
			out.append([id, "behind", ""])
			continue
		var r: Array = _pick(_camera.unproject_position(at))
		out.append([id, r[0], r[1], t["done"]])
	return out


## The task whose body a ray through `local` (the interior viewport's pixels) hits
## first, and the name of what it hit.
func _pick(local: Vector2) -> Array:
	var from := _camera.project_ray_origin(local)
	var q := PhysicsRayQueryParameters3D.create(from, from + _camera.project_ray_normal(local) * 6.0)
	q.collide_with_areas = false
	# Things already done (a made bed, a scrubbed toilet) must not hide the mess behind them.
	var skip: Array[RID] = []
	for id in _targets.keys():
		var b = _targets[id]["body"]
		if _targets[id]["done"] and b != null and is_instance_valid(b):
			skip.append((b as CollisionObject3D).get_rid())
	# Through everything else on the ray (the bed you lie down on, a heap's big box), and of
	# the mess it passes, the smallest: the cans by the sleeping bag, not the bag (playtest
	# 18. 10.: in the tents the bed's bodies took every click meant for the litter).
	var space := _camera.get_world_3d().direct_space_state
	var first_name := ""
	var best := ""
	var best_size := INF
	for _i in 8:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var collider = hit.get("collider")
		if first_name == "":
			first_name = str(collider.get_path()) if collider is Node else str(collider)
		var id := _target_of(collider)
		if id != "":
			var size := _body_size(collider)
			if size < best_size:
				best = id
				best_size = size
		skip.append(hit.get("rid"))
	if best != "":
		return [best, str((_targets[best]["body"] as Node).name)]
	# Nothing on the ray: the nearest of the mess on the screen, if it is close enough.
	var reach := MAGNET * float(_viewport.size.y)
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		var b = t["body"]
		if t["done"] or bool(t.get("scrub", false)) or coop_taken.has(id) or b == null or not is_instance_valid(b) or not (b as Node3D).is_visible_in_tree():
			continue
		var at: Vector3 = (b as Node3D).global_position
		if _camera.is_position_behind(at) or at.distance_to(_camera.global_position) > 6.0:
			continue
		var d := _camera.unproject_position(at).distance_to(local)
		if d < reach:
			reach = d
			best = id
	if best != "":
		return [best, str((_targets[best]["body"] as Node).name)]
	return ["", first_name]


func _target_of(collider) -> String:
	for id in _targets.keys():
		var t: Dictionary = _targets[id]
		if t["done"]:
			continue
		var body = t["body"]
		if body != null and is_instance_valid(body) and body.is_visible_in_tree() and body == collider:
			return id
	return ""


## How big a target's body is (the volume of its boxes).
static func _body_size(body) -> float:
	var v := 0.0
	if body is Node:
		for c in (body as Node).get_children():
			var cs := c as CollisionShape3D
			if cs != null and cs.shape is BoxShape3D:
				var s: Vector3 = (cs.shape as BoxShape3D).size * cs.global_basis.get_scale()
				v += s.x * s.y * s.z
	return v if v > 0.0 else 1.0


func _set_hover(id: String) -> void:
	if id == _hover:
		return
	if not _hover.is_empty() and _targets.has(_hover):
		_apply_highlight(_targets[_hover], false)
	_hover = id
	if not _hover.is_empty():
		_apply_highlight(_targets[_hover], true)


func _apply_highlight(target: Dictionary, on: bool) -> void:
	for m in target["meshes"]:
		if m is MeshInstance3D and is_instance_valid(m):
			var mi := m as MeshInstance3D
			# A flat mess sprite glows itself (an overlay would light its whole quad).
			if mi.has_meta("hl_material"):
				mi.material_override = mi.get_meta("hl_material") if on else mi.get_meta("base_material")
			else:
				mi.material_overlay = _highlight if on else null


## The mess jumps about under the brush, a few millimetres, in steps.
func _shake(target: Dictionary, delta: float) -> void:
	_shake_acc += delta
	if _shake_acc < 1.0 / SHAKE_FPS:
		return
	_shake_acc = 0.0
	for m in target["meshes"]:
		if not (m is Node3D) or not is_instance_valid(m):
			continue
		var n := m as Node3D
		if not _shaken.has(n):
			_shaken[n] = n.position
		n.position = (_shaken[n] as Vector3) + Vector3(randf_range(-0.012, 0.012), randf_range(0.0, 0.01), randf_range(-0.012, 0.012))


func _unshake() -> void:
	for n in _shaken.keys():
		if is_instance_valid(n):
			(n as Node3D).position = _shaken[n]
	_shaken.clear()
	for n in _scaled.keys():
		if is_instance_valid(n):
			(n as Node3D).scale = _scaled[n]
	_scaled.clear()


## The mess under the hand goes stroke by stroke (it is swapped for its done look at the
## end): smaller each time.
func _shrink(target: Dictionary) -> void:
	if not str(target.get("verb", "")) in SHRINKS:
		return
	for m in target["meshes"]:
		if not (m is Node3D) or not is_instance_valid(m):
			continue
		var n := m as Node3D
		if not _scaled.has(n):
			_scaled[n] = n.scale
		n.scale = (_scaled[n] as Vector3) * clampf(1.0 - _progress * 0.55, 0.4, 1.0)


func _start_hold(id: String) -> void:
	_holding = id
	_progress = 0.0
	_gesture.reset()
	_gesture.kind = GESTURE.kind_for(str(_targets[id].get("verb", "")))
	_mouse_last = get_viewport().get_mouse_position()
	_hand.start(str(_targets[id].get("verb", "")), get_viewport().get_mouse_position())
	var path := SFX_DIR + str(_targets[id].get("sfx", "task_litter.mp3"))
	if ResourceLoader.exists(path):
		_work_player.stream = load(path)


func _cancel_hold() -> void:
	_holding = ""
	_progress = 0.0
	if _hand != null:
		_hand.stop()
	_unshake()
	if _work_player != null and _work_player.playing:
		_work_player.stop()


## One click: the hand takes it with the work's sound, and it is done.
func _pick_up(id: String) -> void:
	var t: Dictionary = _targets[id]
	_targets[id]["done"] = true
	_set_hover("")
	_play(str(t.get("sfx", "task_litter.mp3")))
	task_completed.emit(id)
	_hand.start(str(t.get("verb", "")), get_viewport().get_mouse_position())
	_hand.stroke()
	get_tree().create_timer(0.35).timeout.connect(func():
		if _holding.is_empty() and _hand != null and is_instance_valid(_hand):
			_hand.stop())


func _finish(id: String) -> void:
	_targets[id]["done"] = true
	_cancel_hold()
	_set_hover("")
	_play(SFX_DONE)
	task_completed.emit(id)


func play_room_ready() -> void:
	_play(SFX_READY)
	_stamp()


## A rubber stamp slams down in the middle of the screen: big, then down to size with a
## jolt, held, then fades out, in steps (8 a second).
func _stamp() -> void:
	var lbl := RETRO_UI.label("READY", RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, RETRO_UI.C_GREEN_LIGHT, _scale)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.05))
	lbl.add_theme_constant_override("outline_size", 2 * _scale)
	add_child(lbl)
	lbl.reset_size()
	lbl.pivot_offset = lbl.size * 0.5
	lbl.rotation = deg_to_rad(-8.0)
	var screen := get_viewport().get_visible_rect().size
	lbl.position = (screen - lbl.size) * 0.5 - Vector2(0, screen.y * 0.12)
	var tw := lbl.create_tween()
	for k in [2.2, 1.5, 0.92, 1.0]:
		tw.tween_callback(func(): lbl.scale = Vector2.ONE * k)
		tw.tween_interval(0.125)
	tw.tween_interval(1.0)
	for a in [0.7, 0.4, 0.15]:
		tw.tween_callback(func(): lbl.modulate.a = a)
		tw.tween_interval(0.125)
	tw.tween_callback(lbl.queue_free)


func _play(file: String) -> void:
	if ResourceLoader.exists(SFX_DIR + file):
		_one_shot.stream = load(SFX_DIR + file)
		_one_shot.play()


func _build_overlay() -> void:
	_scale = RETRO_UI.ui_scale(get_viewport().get_visible_rect().size.y)
	var plate := RETRO_UI.BevelPanel.new()
	plate.fit_children = true
	plate.position = Vector2(4, 4) * _scale
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.ui_scale = _scale
	add_child(plate)
	_checklist = VBoxContainer.new()
	_checklist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checklist.add_theme_constant_override("separation", 2 * _scale)
	plate.add_child(_checklist)
	_prompt = RETRO_UI.label("", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER_LIGHT, _scale)
	_prompt.visible = false
	add_child(_prompt)


func _refresh_checklist(room: Dictionary) -> void:
	if _checklist == null:
		return
	for c in _checklist.get_children():
		_checklist.remove_child(c)
		c.queue_free()
	var plate := _checklist.get_parent() as Control
	if room.is_empty():
		plate.visible = false
		return
	plate.visible = true
	var occupied := bool(room.get("occupied", false))
	var ready := _room_status == "ready"
	var state := "OCCUPIED" if occupied else (str(room.get("ready_text", "READY FOR GUESTS")) if ready else (str(room.get("dirty_text", "NEEDS CLEANING")) if _room_status == "dirty" else "NOT MADE UP"))
	_checklist.add_child(RETRO_UI.label(_room_label.to_upper(), RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, _scale))
	_checklist.add_child(RETRO_UI.label(state, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_GREEN if (ready or occupied) else RETRO_UI.C_RED_LIGHT, _scale))
	if not str(room.get("note", "")).is_empty():
		_checklist.add_child(RETRO_UI.label(str(room["note"]), RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_RED_LIGHT, _scale))
	if ready or occupied:
		return
	var done: Array = room.get("done", [])
	for t in room.get("tasks", []):
		var is_done := done.has(str(t["id"]))
		var text := "%s %s" % ["[X]" if is_done else "[ ]", str(t["label"])]
		_checklist.add_child(RETRO_UI.label(text, RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_TEXT, RETRO_UI.C_BONE_DIM if is_done else RETRO_UI.C_BONE, _scale))


## Shot driver: what a task's registered body is ([path, visible, instance id, done]).
func debug_target(id: String) -> Array:
	if not _targets.has(id):
		return ["none"]
	var b = _targets[id]["body"]
	if b == null or not is_instance_valid(b):
		return ["freed"]
	return [str((b as Node).get_path()), (b as Node3D).is_visible_in_tree(), (b as Object).get_instance_id(), _targets[id]["done"]]
