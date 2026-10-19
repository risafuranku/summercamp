extends CanvasLayer

## The warden's bag: an old army canvas satchel that opens on the left of the screen with
## TAB, together with the site plan and the checklist. Held, it is a look and shuts when
## you let go; tapped, it stays open (the cursor out) until TAB again or Esc. Inside, a
## grid of sewn pockets: things take one pocket or more and have to fit. Click a thing
## and it sticks to the cursor, click a pocket to put it down (onto one other thing: the
## two swap), right-click turns it while you hold it, a double click uses it. Clicked
## outside the bag, it is thrown on the ground in front of you, where anyone can pick it
## up (interact on it) - the other warden first: for two seconds the one who threw it
## cannot. The ground is the host's (scripts/coop/coop.gd send_inv).
## Pictures: assets/textury/items/, ui/inv_*.png (Grok, tools/artgen/office_art.py).
## town_trip.gd owns it, with the pockets (smoking, drinking) it feeds, and saves it.

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const COLS := 6
const ROWS := 3
## A pocket, in UI pixels; the leather round the grid and the strap above it.
const CELL := 20
const PAD := 7
const TOP := 16
const FPS := 16.0
const TAP_MS := 250
const DROP_LOCK_MS := 2000
const REACH := 2.4
const PIXEL_M := 0.011
const TEX := "res://assets/textury/items/"
const UI_TEX := "res://assets/textury/ui/"
const SFX := "res://assets/sfx/inventory/"
## What there is: its size in pockets, how many uses ("n": a pack of Start has twenty).
const KINDS := {
	"torch": {"w": 2, "h": 1, "tex": "torch.png"},
	"key_shed": {"w": 1, "h": 1, "tex": "key_shed.png"},
	"cigs": {"w": 1, "h": 1, "tex": "cigs.png", "n": 20},
	"beer": {"w": 1, "h": 1, "tex": "beer.png"},
	"card": {"w": 1, "h": 1, "tex": "card.png"},
}

signal changed

var pockets
var trip
## In the pockets: {"id", "x", "y", "r" (turned a quarter), "n"}.
var items: Array = []
var _held: Dictionary = {}
var _held_ms := 0
var _open := false
var _sticky := false
var _press_ms := 0
var _swallow_release := false
var _k := 0.0
var _tick := 0.0
var _canvas: Control
var _tex: Dictionary = {}
var _audio: AudioStreamPlayer
var _mouse_before := Input.MOUSE_MODE_CAPTURED
## On the ground: id -> {"item": {"id", "n"}, "pos", "by": "host"|"client", "ms", "node"}.
var _drops: Dictionary = {}
var _reconcile_t := -1.0
var _reconcile_give := true
var _rng := RandomNumberGenerator.new()


static func find(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("inventory") if tree != null else null


func _init() -> void:
	name = "Inventory"
	layer = 96
	add_to_group("inventory")


func _ready() -> void:
	_rng.randomize()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_canvas.draw.connect(_draw_bag)
	_canvas.gui_input.connect(_on_gui)
	_canvas.visible = false
	add_child(_canvas)
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)
	if Coop != null and not Coop.peer_left.is_connected(_on_peer_left):
		Coop.peer_left.connect(_on_peer_left)
	reset()


## A new camp: nothing on the ground, the torch in the bag.
func new_camp() -> void:
	close(false)
	_clear_drops()
	reset()


## The torch, nothing else.
func reset() -> void:
	items = [{"id": "torch", "x": 0, "y": 0, "r": false, "n": 1}]
	_held = {}
	_changed()


# ── what is in it ────────────────────────────────────────────────────────────

func has(id: String) -> bool:
	if str(_held.get("id", "")) == id:
		return true
	for it in items:
		if str(it["id"]) == id:
			return true
	return false


func room_for(id: String) -> bool:
	return _free_spot({"id": id, "r": false}) != Vector3i(-1, -1, -1)


## Into the first pocket it fits (turned if it only fits turned).
func add_item(id: String, n := -1) -> bool:
	if not KINDS.has(id):
		return false
	var it := {"id": id, "x": 0, "y": 0, "r": false, "n": n if n >= 0 else int(KINDS[id].get("n", 1))}
	var spot := _free_spot(it)
	if spot.x < 0:
		return false
	it["x"] = spot.x
	it["y"] = spot.y
	it["r"] = spot.z == 1
	items.append(it)
	_changed()
	return true


## Out of the bag (or off the cursor), one of them.
func remove_item(id: String) -> bool:
	if str(_held.get("id", "")) == id:
		_held = {}
		_changed()
		return true
	for it in items:
		if str(it["id"]) == id:
			items.erase(it)
			_changed()
			return true
	return false


## One use: a cigarette out of the most smoked pack (the empty one thrown away), or the thing.
func consume(id: String) -> bool:
	var best: Dictionary = {}
	for it in items:
		if str(it["id"]) == id and (best.is_empty() or int(it["n"]) < int(best["n"])):
			best = it
	if best.is_empty():
		return remove_item(id)
	best["n"] = int(best["n"]) - 1
	if int(best["n"]) <= 0:
		items.erase(best)
	_changed()
	return true


func _changed() -> void:
	var player = _player()
	if player != null and "torch_carried" in player:
		var carried := has("torch")
		if bool(player.get("torch_carried")) != carried:
			player.set("torch_carried", carried)
			if player.has_method("_refresh_flashlight_state"):
				player.call("_refresh_flashlight_state")
	if _canvas != null:
		_canvas.queue_redraw()
	changed.emit()


func _foot(it: Dictionary) -> Vector2i:
	var k: Dictionary = KINDS.get(str(it["id"]), {"w": 1, "h": 1})
	return Vector2i(int(k["h"]), int(k["w"])) if bool(it.get("r", false)) else Vector2i(int(k["w"]), int(k["h"]))


func _rect(it: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(it["x"]), int(it["y"])), _foot(it))


## The things under `r` (but `skip`).
func _under(r: Rect2i, skip: Dictionary = {}) -> Array:
	var out: Array = []
	for it in items:
		if it != skip and _rect(it).intersects(r):
			out.append(it)
	return out


func _inside(r: Rect2i) -> bool:
	return r.position.x >= 0 and r.position.y >= 0 and r.end.x <= COLS and r.end.y <= ROWS


## (x, y, turned) of the first place it fits, or (-1, -1, -1).
func _free_spot(it: Dictionary) -> Vector3i:
	var k: Dictionary = KINDS.get(str(it["id"]), {"w": 1, "h": 1})
	var turns := [0] if int(k["w"]) == int(k["h"]) else [0, 1]
	for t in turns:
		var f := Vector2i(int(k["h"]), int(k["w"])) if t == 1 else Vector2i(int(k["w"]), int(k["h"]))
		for y in ROWS:
			for x in COLS:
				var r := Rect2i(Vector2i(x, y), f)
				if _inside(r) and _under(r).is_empty():
					return Vector3i(x, y, t)
	return Vector3i(-1, -1, -1)


func _item_at(cell: Vector2i) -> Dictionary:
	for it in items:
		if _rect(it).has_point(cell):
			return it
	return {}


# ── using things ─────────────────────────────────────────────────────────────

func use(it: Dictionary) -> void:
	match str(it["id"]):
		"cigs":
			if pockets != null and pockets.try_use("smoke", true):
				close()
			else:
				_play("nope.mp3")
		"beer":
			if pockets != null and pockets.try_use("drink", true):
				close()
			else:
				_play("nope.mp3")
		"card":
			if trip != null and trip.has_method("scratch_card") and remove_item("card"):
				close(false)
				trip.scratch_card()
		"torch":
			var player = _player()
			if player != null and player.has_method("toggle_flashlight"):
				player.toggle_flashlight()
		"key_shed":
			_say("On the tag, in pen: SHED - BACK.")


# ── open and shut ────────────────────────────────────────────────────────────

func is_open() -> bool:
	return _open


## Screen pixels the bag takes on the left while it is out (paper_map.gd keeps clear).
func reserve_left() -> float:
	if not _open and _k <= 0.0:
		return 0.0
	return _panel_size().x * float(_scale()) + 32.0


func _open_bag() -> void:
	_open = true
	_sticky = false
	_mouse_before = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.visible = true
	_set_forced(true)
	_play("open.mp3")


## Shut: what is on the cursor goes back in (or on the ground if there is no room).
func close(recapture := true) -> void:
	if not _open:
		return
	if not _held.is_empty():
		_stow_held()
	_open = false
	_sticky = false
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_forced(false)
	if recapture and _mouse_before == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_play("close.mp3", -9.0)


func _set_forced(on: bool) -> void:
	var main := _main()
	if main == null:
		return
	var pm = main.get("_paper_map")
	if pm != null and "force_open" in pm:
		pm.force_open = on
	var hud = main.get("_hud_manager")
	if hud != null and "force_side" in hud:
		hud.force_side = on


func _allowed() -> bool:
	var main := _main()
	if main == null or get_tree().paused:
		return false
	if not bool(main.get("_gameplay_started")) or bool(main.get("_menu_mode")) or bool(main.get("_game_over_active")):
		return false
	if bool(main.get("_coop_down")):
		return false
	if main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")):
		return false
	if trip != null and (trip.is_open() or bool(trip.get("_sleeping"))):
		return false
	var pm = main.get("_pause_menu")
	return not (pm != null and pm.has_method("is_open") and pm.is_open())


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.physical_keycode == KEY_TAB and not key.echo:
		if key.pressed:
			if _open and _sticky:
				close()
				_swallow_release = true
			elif not _open and _allowed():
				_open_bag()
				_press_ms = Time.get_ticks_msec()
		elif _swallow_release:
			_swallow_release = false
		elif _open and not _sticky:
			if Time.get_ticks_msec() - _press_ms <= TAP_MS:
				_sticky = true
			else:
				close()
		return
	if not _open or key == null or not key.pressed:
		return
	if key.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		# E uses the thing under the cursor (a click only moves it); nothing in the world.
		get_viewport().set_input_as_handled()
		var hov := _hovered()
		if not hov.is_empty():
			use(hov)


## Picking a thing up off the ground: interact on it, the bag shut.
func _unhandled_input(event: InputEvent) -> void:
	if _open or _drops.is_empty() or not event.is_action_pressed("interact") or not _allowed():
		return
	var id := _drop_in_view()
	if id == "":
		return
	get_viewport().set_input_as_handled()
	_take_drop(id)


func _process(delta: float) -> void:
	if _reconcile_t > 0.0:
		_reconcile_t -= delta
		if _reconcile_t <= 0.0:
			_reconcile_key()
	if _open and not _allowed():
		close(false)
	_tick += delta
	if _tick >= 1.0 / FPS:
		_tick = 0.0
		# Out and back in steps, sixteen a second.
		_k = move_toward(_k, 1.0 if _open else 0.0, 0.25)
		_canvas.visible = _k > 0.0
	if _canvas.visible:
		_canvas.queue_redraw()


# ── the cursor ───────────────────────────────────────────────────────────────

func _on_gui(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var s := _scale()
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if not _held.is_empty():
			_turn()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := _cell_at(mb.position, s)
	if _held.is_empty():
		var it := _item_at(cell)
		if not it.is_empty():
			_pick(it)
		return
	if mb.double_click and Time.get_ticks_msec() - _held_ms < 600:
		# Two clicks on it: back where it was, and used.
		var placed := _put_back()
		if not placed.is_empty():
			use(placed)
		return
	if _panel_rect(s).has_point(mb.position):
		if cell.x >= 0:
			_place_at(mb.position, s)
		return
	_throw_held()


func _pick(it: Dictionary) -> void:
	items.erase(it)
	_held = it.duplicate()
	_held["fx"] = int(it["x"])
	_held["fy"] = int(it["y"])
	_held["fr"] = bool(it["r"])
	_held_ms = Time.get_ticks_msec()
	_play("pick.mp3")
	_changed()


func _turn() -> void:
	var k: Dictionary = KINDS.get(str(_held["id"]), {"w": 1, "h": 1})
	if int(k["w"]) == int(k["h"]):
		return
	_held["r"] = not bool(_held.get("r", false))
	_play("pick.mp3", -12.0)
	_canvas.queue_redraw()


## Where the held thing would go with the cursor at `mouse`: centred on it, kept inside.
func _target(mouse: Vector2, s: int) -> Rect2i:
	var f := _foot(_held)
	var g := (mouse - _grid_origin(s)) / float(CELL * s)
	var tl := Vector2i(roundi(g.x - float(f.x) * 0.5), roundi(g.y - float(f.y) * 0.5))
	tl.x = clampi(tl.x, 0, COLS - f.x)
	tl.y = clampi(tl.y, 0, ROWS - f.y)
	return Rect2i(tl, f)


func _place_at(mouse: Vector2, s: int) -> void:
	var r := _target(mouse, s)
	var under := _under(r)
	if under.size() > 1:
		_play("nope.mp3")
		return
	var put := _clean(_held)
	put["x"] = r.position.x
	put["y"] = r.position.y
	items.append(put)
	_held = {}
	if under.size() == 1:
		# Onto one other thing: that one comes up on the cursor instead.
		var other: Dictionary = under[0]
		items.erase(other)
		_held = other.duplicate()
		_held["fx"] = int(other["x"])
		_held["fy"] = int(other["y"])
		_held["fr"] = bool(other["r"])
		_held_ms = 0
	_play("place.mp3")
	_changed()


## Back where it came from (or wherever it fits); returns it as placed, or {}.
func _put_back() -> Dictionary:
	var it := _clean(_held)
	it["x"] = int(_held.get("fx", -1))
	it["y"] = int(_held.get("fy", -1))
	it["r"] = bool(_held.get("fr", false))
	_held = {}
	if not (_inside(_rect(it)) and _under(_rect(it)).is_empty()):
		var spot := _free_spot(it)
		if spot.x < 0:
			_throw(it)
			return {}
		it["x"] = spot.x
		it["y"] = spot.y
		it["r"] = spot.z == 1
	items.append(it)
	_play("place.mp3")
	_changed()
	return it


func _stow_held() -> void:
	_put_back()


func _clean(it: Dictionary) -> Dictionary:
	return {"id": str(it["id"]), "x": int(it.get("x", 0)), "y": int(it.get("y", 0)), "r": bool(it.get("r", false)), "n": int(it.get("n", 1))}


# ── the ground ───────────────────────────────────────────────────────────────

func _throw_held() -> void:
	var it := _held
	_held = {}
	_throw(it)
	_changed()


func _throw(it: Dictionary) -> void:
	var item := {"id": str(it["id"]), "n": int(it.get("n", 1))}
	var pos := _drop_point()
	_play("drop.mp3")
	if Coop.is_client():
		Coop.send_inv("drop", [item, pos])
		return
	var id := _new_id()
	_add_drop(id, item, pos, "host")
	if Coop.is_host():
		Coop.send_inv("add", [id, item, pos, "host"])


## A step in front of you on the ground (short of a wall).
func _drop_point() -> Vector3:
	var player := _player()
	if player == null:
		return Vector3.ZERO
	var space := player.get_world_3d().direct_space_state
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP) * _rng.randf_range(-0.15, 0.15)
	var chest := player.global_position + Vector3.UP * 1.0
	var dist := 0.85
	var q := PhysicsRayQueryParameters3D.create(chest, chest + fwd * (dist + 0.3))
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		dist = maxf(0.2, chest.distance_to(hit["position"]) - 0.3)
	var at := chest + fwd * dist + side
	var down := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 4.0)
	down.exclude = [player.get_rid()]
	var ground := space.intersect_ray(down)
	if not ground.is_empty():
		return ground["position"]
	return Vector3(at.x, player.global_position.y, at.z)


func _new_id() -> String:
	return "%x%04x" % [Time.get_ticks_msec(), _rng.randi() & 0xffff]


## A thing lying on the ground, a flat sprite standing up off it like a Build pickup.
func _add_drop(id: String, item: Dictionary, pos: Vector3, by: String) -> void:
	_remove_drop(id)
	var world := _world()
	if world == null:
		return
	var spr := Sprite3D.new()
	spr.name = "Dropped_" + id
	var t := _item_tex(str(item["id"]))
	spr.texture = t
	spr.pixel_size = PIXEL_M
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	var h := float(t.get_height()) if t != null else 16.0
	world.add_child(spr)
	spr.global_position = pos + Vector3.UP * (h * PIXEL_M * 0.5 + 0.01)
	_drops[id] = {"item": item.duplicate(), "pos": pos, "by": by, "ms": Time.get_ticks_msec(), "node": spr}


func _remove_drop(id: String) -> void:
	if not _drops.has(id):
		return
	var n = _drops[id]["node"]
	if n != null and is_instance_valid(n):
		n.queue_free()
	_drops.erase(id)


func _clear_drops() -> void:
	for id in _drops.keys():
		_remove_drop(id)


func _mine(d: Dictionary) -> bool:
	return (str(d["by"]) == "client") == Coop.is_client()


## The thing on the ground the view is on, within reach, or "".
func _drop_in_view() -> String:
	var player := _player()
	var cam: Camera3D = player.get("_camera") as Camera3D if player != null else null
	if cam == null or not cam.is_inside_tree():
		return ""
	# Through the middle of the picture (the look up and down is partly a shift of it,
	# Build-style: the camera's own forward is not where you look).
	var mid := cam.get_viewport().get_visible_rect().size * 0.5
	var o := cam.project_ray_origin(mid)
	var fwd := cam.project_ray_normal(mid)
	var best := ""
	var best_off := 1e9
	for id in _drops.keys():
		var n = _drops[id]["node"]
		if n == null or not is_instance_valid(n):
			continue
		var to: Vector3 = (n as Node3D).global_position - o
		var d := to.length()
		var along := to.dot(fwd)
		if d > REACH or along <= 0.0:
			continue
		var off := (to - fwd * along).length()
		if off < 0.22 + 0.08 * d and off < best_off:
			best_off = off
			best = id
	return best


func _take_drop(id: String) -> void:
	if not _drops.has(id):
		return
	var d: Dictionary = _drops[id]
	if _mine(d) and Time.get_ticks_msec() - int(d["ms"]) < DROP_LOCK_MS:
		return
	var item: Dictionary = d["item"]
	if not room_for(str(item["id"])):
		_play("nope.mp3")
		_say("No room for it in the bag.")
		return
	if Coop.is_client():
		Coop.send_inv("take", [id])
		return
	_remove_drop(id)
	add_item(str(item["id"]), int(item.get("n", 1)))
	_play("pick.mp3")
	if Coop.is_host():
		Coop.send_inv("del", [id])


## From the other machine (Coop.send_inv): the host decides who gets what off the ground.
func coop_inv(kind: String, data: Array) -> void:
	match kind:
		"drop":
			if Coop.is_host():
				var id := _new_id()
				_add_drop(id, data[0], data[1], "client")
				Coop.send_inv("add", [id, data[0], data[1], "client"])
		"add":
			_add_drop(str(data[0]), data[1], data[2], str(data[3]))
		"del":
			_remove_drop(str(data[0]))
		"take":
			var id := str(data[0])
			if not Coop.is_host() or not _drops.has(id):
				return
			var d: Dictionary = _drops[id]
			if str(d["by"]) == "client" and Time.get_ticks_msec() - int(d["ms"]) < DROP_LOCK_MS:
				return
			_remove_drop(id)
			# To whoever picked it up (the others just see it gone).
			Coop.send_inv("give", [id, d["item"], Coop.sender])
		"give":
			_remove_drop(str(data[0]))
			if data.size() > 2 and int(data[2]) != multiplayer.get_unique_id():
				return
			var item: Dictionary = data[1]
			if add_item(str(item["id"]), int(item.get("n", 1))):
				_play("pick.mp3")
			else:
				Coop.send_inv("drop", [item, _drop_point()])
		"key_back":
			var office = _office()
			if office != null and office.has_method("return_shed_key"):
				office.return_shed_key()


func _on_peer_left() -> void:
	# A key that went home with the other warden is back on its pin.
	_reconcile_give = false
	_reconcile_t = 0.5


## The shed key is off the board but nobody here has it and it is not on the ground:
## after a load it is in the bag (saves from before the bag), otherwise back on the board.
func _reconcile_key() -> void:
	if Coop.is_client():
		return
	var office = _office()
	if office == null or not bool(office.get("has_shed_key")) or has("key_shed"):
		return
	for d in _drops.values():
		if str(d["item"]["id"]) == "key_shed":
			return
	if _reconcile_give and add_item("key_shed"):
		return
	if office.has_method("return_shed_key"):
		office.return_shed_key()


# ── saved with the game ──────────────────────────────────────────────────────

func export_state() -> Dictionary:
	var bag: Array = []
	for it in items:
		bag.append(_clean(it))
	if not _held.is_empty():
		var h := _clean(_held)
		var spot := _free_spot(h)
		if spot.x >= 0:
			h["x"] = spot.x
			h["y"] = spot.y
			h["r"] = spot.z == 1
			bag.append(h)
	var ground: Array = []
	for id in _drops.keys():
		var d: Dictionary = _drops[id]
		var p: Vector3 = d["pos"]
		ground.append({"k": id, "id": str(d["item"]["id"]), "n": int(d["item"].get("n", 1)), "p": [p.x, p.y, p.z]})
	return {"bag": bag, "ground": ground}


## `client`: a camp that came from the host - its ground, but the bag stays this warden's.
func import_state(d: Dictionary, client := false) -> void:
	_clear_drops()
	if not client:
		_held = {}
		items = []
		var bag = d.get("bag", null)
		if bag is Array:
			for raw in bag:
				if raw is Dictionary and KINDS.has(str(raw.get("id", ""))):
					var it := _clean(raw)
					if _inside(_rect(it)) and _under(_rect(it)).is_empty():
						items.append(it)
					else:
						add_item(str(it["id"]), int(it["n"]))
		else:
			reset()
		_reconcile_give = true
		_reconcile_t = 1.0
	var ground = d.get("ground", [])
	if ground is Array:
		for g in ground:
			if g is Dictionary and KINDS.has(str(g.get("id", ""))):
				var p: Array = g.get("p", [0, 0, 0])
				_add_drop(str(g.get("k", _new_id())), {"id": str(g["id"]), "n": int(g.get("n", 1))}, Vector3(float(p[0]), float(p[1]), float(p[2])), "host")
	_changed()


# ── drawing ──────────────────────────────────────────────────────────────────

## A step smaller than the rest of the UI: the plan and the checklist share the screen.
func _scale() -> int:
	var vp := get_viewport().get_visible_rect().size
	return maxi(2, RETRO_UI.ui_scale(vp.y, vp.x, 400.0) - 1)


func _panel_size() -> Vector2:
	return Vector2(COLS * CELL + PAD * 2, ROWS * CELL + TOP + PAD)


## Top left of the bag on screen: in from the left edge as it opens.
func _origin(s: int) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var size := _panel_size() * float(s)
	var x := 16.0 - (1.0 - _k) * (size.x + 32.0)
	return Vector2(x, (vp.y - size.y) * 0.5).floor()


func _grid_origin(s: int) -> Vector2:
	return _origin(s) + Vector2(PAD, TOP) * float(s)


func _panel_rect(s: int) -> Rect2:
	return Rect2(_origin(s), _panel_size() * float(s))


func _cell_at(p: Vector2, s: int) -> Vector2i:
	var g := ((p - _grid_origin(s)) / float(CELL * s)).floor()
	if g.x < 0 or g.y < 0 or g.x >= COLS or g.y >= ROWS:
		return Vector2i(-1, -1)
	return Vector2i(g)


func _ui(name: String) -> Texture2D:
	return _load(UI_TEX + name)


func _item_tex(id: String) -> Texture2D:
	return _load(TEX + str(KINDS.get(id, {}).get("tex", "")))


func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


func _draw_bag() -> void:
	if _k <= 0.0:
		return
	var s := _scale()
	var fs := float(s)
	var o := _origin(s)
	var pw := _panel_size()
	var c := _canvas
	c.draw_rect(Rect2(o + Vector2(2, 3) * fs, pw * fs), Color(0, 0, 0, 0.45))
	c.draw_set_transform(o, 0.0, Vector2(fs, fs))
	var leather := _ui("inv_leather.png")
	var canvas := _ui("inv_canvas.png")
	var pocket := _ui("inv_pocket.png")
	if leather != null:
		c.draw_texture_rect(leather, Rect2(Vector2.ZERO, pw), true, Color(0.85, 0.8, 0.75))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, pw), Color(0.22, 0.14, 0.09))
	var lining := Rect2(Vector2(PAD - 2, TOP - 2), Vector2(COLS * CELL + 4, ROWS * CELL + 4))
	if canvas != null:
		c.draw_texture_rect(canvas, lining, true, Color(0.55, 0.55, 0.5))
	else:
		c.draw_rect(lining, Color(0.2, 0.21, 0.14))
	# Where the held thing would go: the pockets under it lit (green: fits, amber: swaps,
	# red: no).
	var mouse := c.get_local_mouse_position()
	var target := Rect2i(-1, -1, 0, 0)
	var tint := Color.WHITE
	if not _held.is_empty() and _cell_at(mouse, s).x >= 0:
		target = _target(mouse, s)
		var n := _under(target).size()
		tint = Color(0.75, 1.0, 0.65) if n == 0 else (Color(1.0, 0.82, 0.5) if n == 1 else Color(1.0, 0.5, 0.45))
	var hover := _item_at(_cell_at(mouse, s)) if _held.is_empty() else {}
	for y in ROWS:
		for x in COLS:
			var r := Rect2(Vector2(PAD + x * CELL, TOP + y * CELL), Vector2(CELL, CELL))
			var lit := target.has_point(Vector2i(x, y))
			var m := tint if lit else Color(0.8, 0.8, 0.76)
			if pocket != null:
				# Mirrored now and then, so the same stain is not in every pocket.
				var flip := Vector2(-1.0 if (x * 7 + y * 3) % 3 == 1 else 1.0, -1.0 if (x + y * 5) % 4 == 2 else 1.0)
				c.draw_set_transform(o + (r.position + r.size * 0.5) * fs, 0.0, flip * fs)
				c.draw_texture_rect(pocket, Rect2(-r.size * 0.5, r.size), false, m)
				c.draw_set_transform(o, 0.0, Vector2(fs, fs))
			else:
				c.draw_rect(r.grow(-1), Color(0.26, 0.27, 0.18) * m)
	var buckle := _ui("inv_buckle.png")
	if buckle != null:
		var bw := buckle.get_size()
		c.draw_texture(buckle, Vector2(PAD + 14, 1))
		c.draw_texture(buckle, Vector2(pw.x - PAD - 14 - bw.x, 1))
	for it in items:
		var at := Vector2(PAD + int(it["x"]) * CELL, TOP + int(it["y"]) * CELL)
		_draw_item(it, o + at * fs, fs, Color(1.15, 1.12, 1.05) if it == hover else Color.WHITE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not hover.is_empty():
		_draw_hint(hover, mouse)
	if not _held.is_empty():
		# On the cursor, lifted: its shadow below it.
		var f := Vector2(_foot(_held)) * float(CELL) * fs
		var tl := (mouse - f * 0.5).floor()
		_draw_item(_held, tl + Vector2(3, 4) * fs, fs, Color(0, 0, 0, 0.5), false)
		_draw_item(_held, tl, fs, Color.WHITE)


## The thing under the cursor in the bag (nothing held), or {}.
func _hovered() -> Dictionary:
	if not _open or not _held.is_empty() or _canvas == null:
		return {}
	return _item_at(_cell_at(_canvas.get_local_mouse_position(), _scale()))


## What E does with a thing, for the line by the cursor ("" nothing).
const VERBS := {"cigs": "Smoke one", "beer": "Drink", "card": "Scratch it", "torch": "Torch on / off", "key_shed": "Read the tag"}


## The line by the cursor over a thing: what it is for and that E does it (a click
## picks it up to move it).
func _draw_hint(it: Dictionary, mouse: Vector2) -> void:
	var verb := str(VERBS.get(str(it["id"]), ""))
	if verb == "":
		return
	var txt := "E  %s" % verb
	if KINDS.get(str(it["id"]), {}).has("n"):
		txt += "  (%d)" % int(it.get("n", 1))
	var c := _canvas
	var fs := float(_scale())
	var w := RETRO_UI.FONT_LABEL.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_LABEL).x
	var at := (mouse + Vector2(10, 12) * fs).floor()
	c.draw_set_transform(at, 0.0, Vector2(fs, fs))
	c.draw_rect(Rect2(Vector2(-3, -9), Vector2(w + 6, 12)), Color(0.08, 0.06, 0.04, 0.92))
	c.draw_rect(Rect2(Vector2(-3, -9), Vector2(w + 6, 12)), Color(0.55, 0.44, 0.28), false, 1.0)
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(0, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A thing with its top left at `at` (screen): its picture in the middle of its pockets,
## turned with it, the uses left in the corner.
func _draw_item(it: Dictionary, at: Vector2, fs: float, mod: Color, count := true) -> void:
	var c := _canvas
	var f := Vector2(_foot(it)) * float(CELL)
	var t := _item_tex(str(it["id"]))
	var turned := bool(it.get("r", false))
	if t != null:
		var ts := t.get_size()
		c.draw_set_transform((at + f * 0.5 * fs).floor(), PI * 0.5 if turned else 0.0, Vector2(fs, fs))
		c.draw_texture(t, (-ts * 0.5).floor(), mod)
	else:
		c.draw_set_transform(at, 0.0, Vector2(fs, fs))
		c.draw_rect(Rect2(Vector2(2, 2), f - Vector2(4, 4)), Color(0.6, 0.55, 0.45) * mod)
	if count and KINDS.get(str(it["id"]), {}).has("n"):
		c.draw_set_transform(at, 0.0, Vector2(fs, fs))
		var txt := str(int(it.get("n", 1)))
		var w := RETRO_UI.FONT_LABEL.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_LABEL).x
		var p := Vector2(f.x - w - 1, f.y - 1)
		c.draw_string(RETRO_UI.FONT_LABEL, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_LABEL, Color(0, 0, 0, 0.9))
		c.draw_string(RETRO_UI.FONT_LABEL, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── helpers ──────────────────────────────────────────────────────────────────

func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


## Where the camp is (main's 3D world in its low-resolution viewport).
func _world() -> Node:
	var main := _main()
	if main == null:
		return null
	var w = main.get("_world_3d")
	return w if w != null else main


func _player() -> Node3D:
	var main := _main()
	return main.get("_player") as Node3D if main != null else null


func _office():
	var main := _main()
	return main.get("camp_office") if main != null else null


func _say(text: String) -> void:
	var main := _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0)


func _play(file: String, db := -6.0) -> void:
	if ResourceLoader.exists(SFX + file):
		_audio.stream = load(SFX + file)
		_audio.volume_db = db
		_audio.pitch_scale = _rng.randf_range(0.94, 1.06)
		_audio.play()
