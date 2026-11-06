extends CanvasLayer

## Inside a place in Lesna, in 3D like the camp's rooms (playtest 17. 10.: "replace the
## pixel screens in the town with 3D interiors"): you stand at the counter, look round
## with the mouse, the one who serves stands behind it (a Grok billboard that breathes
## and turns in steps), what you can buy or use glints under the gloved finger. What is
## said comes up in a strip along the bottom, typed out like the close-ups'.
##
##   - the Jednota: the goods where they stand, Mrs Novotna puts what you point at on the
##     counter, the till rings it up, you pay out of your wallet (counter_shop.gd,
##     counter_pay.gd, counter_goods.gd); fluorescent tubes, one dying;
##   - the pub U Jezera: the tap ($1, the mug lands on the bar, three pulls and it is
##     yours: `drank`), the fruit machine in the corner (pub_closeup.gd's reels), Mr Kubat,
##     two regulars; lamps over the tables, smoke in the air, the room's murmur.
##   - the chapel (open day and night): chapel_view.gd, built to its baroque front;
##   - the kiosk at the Benzina: the same counter, Mrs Lojzova, a petrol station's prices;
##   - the motel: motel_view.gd (its reception, Mr Simek and the key board; number four),
##     built from motel_plan.gd with the block in the village.
## S, the bottom edge or the door behind you leaves.
##
## The rooms are Build boxes with Grok faces (assets/textury/camp, tools/artgen/town_rooms.py).

signal closed
## Paid for at the counter (counter_shop.gd), into the bag (scripts/ui/inventory.gd).
signal bought(item: String)
signal drank
## Handed to town_trip.gd: "slot" (the pub's fruit machine, pub_closeup), "motel_room".
signal wants_closeup(kind: String)
## The chapel's candles burning now (chapel_view.gd), for the other wardens.
signal candle_lit(count: int)

const K = preload("res://scripts/interior_kit.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const NPC := "res://assets/textury/npc/"
const SFX_PUB := "res://assets/sfx/pub/"
const SFX_TOWN := "res://assets/sfx/town/"
const RENDER := Vector2i(960, 540)
const STRIP := Vector2i(320, 30)

## The counter of the Jednota and the kiosk: what lies on it, the till, paying
## (counter_shop.gd; what they sell and for how much: counter_goods.gd).
const COUNTER_SHOP = preload("res://scripts/town/counter_shop.gd")
const SHOP_LINES := [
	"What will it be.",
	"My husband does your lamps up there. He says your main is older than he is.",
	"Your Vera bought candles. Boxes of them, that last summer. And chalk.",
	"Bread comes Tuesdays and Fridays. Same as the van to your gate.",
	"We shut at five. After five I do not open for anybody.",
]
const PUB_LINES := [
	"Kitchen's shut. The cellar is not open to guests.",
	"Karbanatky to our own recipe. What is in them is the recipe.",
	"If you have meat to sell, regular, any quantity, come round the back.",
	"Your Vera sat where you are standing. Every Friday. Then one Friday she didn't, and she had not missed one in eleven years.",
	"The machine pays. Not often. Like everything here.",
]
const KIOSK_LINES := [
	"Pump first, then pay. Or pay, then pump. Just pay.",
	"Lojza says you are good at the pumps. Lojza says a lot.",
	"Maps of the district, forty crowns, eight years old. The roads have not moved.",
]
const MOTEL_LINES := [
	"Rooms from seven in the evening. Fifteen dollars.",
	"The camp people used to come down for the shower. Then they stopped coming down at all.",
	"Number four has the best mattress. Number six I do not let.",
]
const REGULAR_LINES := {
	"cap": ["Camp up the lake, is it. My brother worked the boats there. Before.", "Do not swim at night. Nobody tells you that, so I am telling you.", "Kubat, another.", "The bus driver does not stop at the cross after dark. Ask him why. He will not say."],
	"track": ["You buying? No? Then why are you at my bar.", "I drove for the JZD. Twenty years. The silo has a cellar nobody filled in.", "Na zdravi, camp."],
}

var place := ""
var hour := 12.0
## The motel's rooms (motel_view.gd, built from motel_plan.gd): its reception "motel" and
## your room "motel_room"; the chapel's own (chapel_view.gd) the same way. Null elsewhere.
const MOTEL_VIEW = preload("res://scripts/town/motel_view.gd")
const MOTEL_HALL = preload("res://scripts/town/motel_hall.gd")
const CHAPEL_VIEW = preload("res://scripts/town/chapel_view.gd")
const JEDNOTA_VIEW = preload("res://scripts/town/jednota_view.gd")
const PUB_VIEW = preload("res://scripts/town/pub_view.gd")
const KIOSK_VIEW = preload("res://scripts/town/kiosk_view.gd")
const WC_VIEW = preload("res://scripts/town/wc_view.gd")
## Set by town_trip: the place's building in the village and the room built in it behind
## its glass (jednota_view.gd: the windows look out of the one, hide the other).
var place_anchor: Node3D
var place_shell: Node3D
var _view
## Set by town_trip: the motel in the village (motel_block.gd: where its windows look out
## from), the keys on its board.
var motel_block: Node3D
var motel_keys: Array = []
## The room "motel_room" opens, where you come out in "motel_hall"; true for one open: you
## came through from the next place in the building (no greeting, the door is behind you).
var motel_n := MOTEL_VIEW.PLAN.YOURS
var arrive_spot := ""
## The room's walker (room_walk.gd sets it): the floor's lit places are walked to through it.
var walker
var _through := false
var _open := false
var _vpc: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _env: Environment
var _root: Node3D
var _look = INTERIOR_LOOK.new(70.0, 24.0, 30.0)
var _base_rot := Vector3.ZERO
var _hot: Dictionary = {}       # id -> {body, meshes}
var _glint = HOVER_GLINT.new()
var _hover := ""
var _exit_hint: Control
var _audio: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _npc: Sprite3D
var _npc_who := ""
var _npc_base := Vector3.ZERO
var _npc_t := 0.0
var _npc_nod := 0.0
var _line := 0
var _reg_line := {"cap": 0, "track": 0}
var _mug := 0
var _mug_node: MeshInstance3D
var _mug_tex := {}
var _tubes: Array = []          # [{light, mat, dying}]
var _regulars: Array = []       # {node, base, phase}
var _t := 0.0
var _strip_vp: SubViewport
var _strip_canvas: Control
var _strip_view: TextureRect
var _who := ""
var _text := ""
var _shown := -1
var _type := 0.0
var _modal: Callable = func(): return false
var _candles := 0


func _init() -> void:
	layer = 56
	visible = false


func _ready() -> void:
	_vpc = SubViewportContainer.new()
	_vpc.name = "TownRoomContainer"
	_vpc.anchor_right = 1.0
	_vpc.anchor_bottom = 1.0
	_vpc.stretch = true
	_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vpc)
	RETRO_RENDER.register(_vpc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = RENDER
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vpc.add_child(_vp)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.05, 0.05, 0.06)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = _env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 66.0
	_cam.near = 0.05
	_cam.far = 30.0
	_vp.add_child(_cam)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	_build_strip()


## `modal` says when a close-up is up over the room (its input is its own then).
func set_modal_check(modal: Callable) -> void:
	_modal = modal


## Close-ups and screens a place puts over the room (the laptop's, the counter's, the
## candles' up close): while one of them is visible, its input is its own.
var _overlays: Array = []


func add_overlay(n: Node) -> void:
	if not _overlays.has(n):
		_overlays.append(n)


func _is_modal() -> bool:
	if _modal.call():
		return true
	for n in _overlays:
		if is_instance_valid(n) and n.get("visible") == true:
			return true
	return false


## Callable(item) -> bool: is there room in the bag for it (nothing is sold without).
var can_buy: Callable
var _counter


func is_open() -> bool:
	return _open


func open(p_place: String, p_hour: float) -> void:
	place = p_place
	hour = p_hour
	if _root != null:
		_vp.remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_vp.add_child(_root)
	_hot.clear()
	walker = null
	_tubes.clear()
	_regulars.clear()
	_npc = null
	_mug = 0
	_mug_node = null
	# What was said in the last room is not said in this one.
	_text = ""
	_who = ""
	_shown = -1
	_look.yaw_limit_deg = 70.0
	_look.pitch_up_deg = 24.0
	_look.pitch_down_deg = 30.0
	_cam.fov = 66.0
	# The pub's smoke and the chapel's haze stay in their rooms.
	_env.fog_enabled = false
	if _view != null:
		_view.close()
	_view = null
	var motel_ok := motel_block != null and is_instance_valid(motel_block)
	match place:
		"jednota":
			if place_anchor != null and is_instance_valid(place_anchor) and place_anchor.get_node_or_null("SalesRoom") != null:
				_view = JEDNOTA_VIEW.new(self, place_anchor, place_shell)
				_view.build_inside(hour)
			else:
				_build_jednota()
		"pub":
			if place_anchor != null and is_instance_valid(place_anchor) and place_anchor.get_node_or_null("Taproom") != null:
				_view = PUB_VIEW.new(self, place_anchor, place_shell)
				_view.build_inside(hour)
			else:
				_build_pub()
		"chapel":
			_view = CHAPEL_VIEW.new(self)
			_view.build(hour, _candles)
		"kiosk":
			if place_anchor != null and is_instance_valid(place_anchor) and place_anchor.get_node_or_null("Shop") != null:
				_view = KIOSK_VIEW.new(self, place_anchor, place_shell)
				_view.build_inside(hour)
			else:
				_build_kiosk()
		"motel":
			if motel_ok:
				_view = MOTEL_VIEW.new(self, 0, motel_block)
				_view.build(hour, motel_keys)
			else:
				_build_motel()
		"motel_room":
			_view = MOTEL_VIEW.new(self, motel_n, motel_block)
			_view.build(hour, [])
		"motel_hall":
			_view = MOTEL_HALL.new(self, motel_block)
			_view.build(hour, arrive_spot)
		"wc":
			_view = WC_VIEW.new(self)
			_view.build_inside(hour)
	_look.reset()
	_cam.rotation = _base_rot
	# Once used: come in again from outside and it is the room's start (the user 6. 11.: "I
	# went out from the corridor's door and every time I came back I was at that door").
	arrive_spot = ""
	_open = true
	visible = true
	RETRO_RENDER.apply_to(_vpc)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _through:
		_through = false
		return
	match place:
		"jednota":
			_play(SFX_TOWN + "shop_bell.mp3", -8.0)
			say("Mrs Novotna", "What will it be.")
		"pub":
			say("Mr Kubat", "Sit where you like. Beer's a dollar.")
			_loop(SFX_PUB + "pub_room.mp3", -16.0)
		"chapel":
			_play("res://assets/sfx/chapel/door.mp3", -8.0)
		"kiosk":
			_play(SFX_TOWN + "shop_bell.mp3", -10.0)
			say("Mrs Lojzova", "Yes?")
		"motel":
			say("Mr Simek", "Evening. Or is it.")
		"motel_room":
			_play("res://assets/sfx/backroom/room_door_close.mp3", -8.0)


# ── co-op: the other wardens in here too ───────────────────────────────────────

const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")


## In the same place on their machines (town_trip.coop_place): stood beside you at the
## counter (or the pew), as each of them looks.
## The other wardens in this place with you (peer ids): standing at the counter beside
## you, a little ahead, one on your right, the next on your left, the next further left.
var _mates: Dictionary = {}


func coop_mates(ids: Array) -> void:
	for id in _mates.keys():
		if not ids.has(id) or not _open or _root == null:
			# A view with a door can see them out through it (then their figure is its own).
			var fig = _mates[id]
			_mates.erase(id)
			var where := str(Coop.state_of(int(id)).get("tr", ""))
			if _open and _view != null and _view.has_method("mate_leaves") and is_instance_valid(fig) and bool(_view.mate_leaves(int(id), fig, where)):
				continue
			if is_instance_valid(fig):
				fig.queue_free()
	if not _open or _root == null:
		return
	if _view != null:
		for id in ids:
			var f2 = _mates.get(int(id))
			if f2 == null or not is_instance_valid(f2) or f2.get_parent() != _root:
				var lk: Dictionary = Coop.look_of(int(id))
				f2 = REMOTE_PLAYER.new()
				f2.setup(int(lk.get("m", 1)), int(lk.get("c", 0)), true)
				_root.add_child(f2)
				_mates[int(id)] = f2
		_view.place_mates(_mates, ids)
		return
	var b := Basis.from_euler(Vector3(0.0, _base_rot.y, 0.0))
	for i in ids.size():
		var id := int(ids[i])
		var fig = _mates.get(id)
		if fig == null or not is_instance_valid(fig) or fig.get_parent() != _root:
			var look: Dictionary = Coop.look_of(id)
			fig = REMOTE_PLAYER.new()
			fig.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
			_root.add_child(fig)
			_mates[id] = fig
		# At the counter with you, a little ahead (in sight, not out at your elbows).
		var side: Array = [Vector3(0.95, 0.0, -1.0), Vector3(-0.95, 0.0, -1.0), Vector3(-1.75, 0.0, -1.2)]
		var at: Vector3 = _cam.position + b * (side[i % side.size()] as Vector3)
		at.y = _cam.position.y - 1.6
		fig.show_at(at, "stand")


func close() -> void:
	if not _open:
		return
	if _view != null:
		_view.close()
		_view = null
	elif _counter != null:
		_counter.end()
	_open = false
	visible = false
	_glint.clear()
	_amb.stop()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _exit_hint != null:
		_exit_hint.modulate.a = 0.0
	closed.emit()


## Through a door to the next place in the same building (the motel's reception, corridor
## and rooms): `n` the room, `spot` where you come out.
func go_to(p_place: String, n := 0, spot := "") -> void:
	if n > 0:
		motel_n = n
	arrive_spot = spot
	_through = true
	var trip = get_parent()
	if trip != null and trip.has_method("_door_fx"):
		trip._door_fx(true)
	open(p_place, float(trip.hour()) if trip != null and trip.has_method("hour") else hour)


## The night passed in the motel's room (town_trip): the morning's light in it.
func morning_now(h: float) -> void:
	hour = h
	if _view != null and _view.has_method("morning"):
		_view.morning(h)


## Simek takes room `n`'s key off the board (the reception).
func take_key(n: int) -> void:
	if _view == null:
		return
	var keys: Dictionary = _view.parts.get("keys", {})
	var k = keys.get(n)
	if k != null and is_instance_valid(k):
		(k as Node3D).visible = false


## You sleep: the room stops drawing its windows (town_trip's black over it all).
func set_asleep(on: bool) -> void:
	if _view != null:
		_view.asleep = on


## Woken in the night in the motel's room by `kind` (motel_night.gd; "" nothing).
func woken_now(kind: String) -> void:
	if _view != null and _view.has_method("woken"):
		_view.woken(kind)


func say(who: String, text: String) -> void:
	_who = tr(who)
	_text = tr(text)
	_shown = 0
	_type = 0.0


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	var modal: bool = _is_modal()
	if not modal:
		var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
		_cam.rotation = _base_rot + offset
		_hover = _hover_at(get_viewport().get_mouse_position())
		if not _hot.has(_hover):
			_hover = ""
		if _hover != "":
			HandCursor.want(_cursor_for(_hover))
			_glint.show_on(_hot[_hover]["meshes"])
		else:
			_glint.clear()
			if INTERIOR_LOOK.in_exit_zone(get_viewport()):
				HandCursor.want(HandCursor.WALK)
	else:
		_glint.clear()
		_hover = ""
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self, "Go out   [Esc]")
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, not modal)
	_animate_npc(delta)
	_animate_tubes()
	_animate_regulars()
	if _view != null:
		_view.tick(delta)
	if _shown >= 0 and _shown < _text.length():
		_type += delta * 48.0
		while _type >= 1.0 and _shown < _text.length():
			_type -= 1.0
			_shown += 1
	_layout_strip()
	_strip_canvas.queue_redraw()


## The one behind the counter breathes, now and then looks aside, nods when spoken to
## (all in steps, twelve a second).
func _animate_npc(delta: float) -> void:
	if _npc == null:
		return
	_npc_t += delta
	_npc_nod = maxf(0.0, _npc_nod - delta)
	var step := floorf(_npc_t * 12.0) / 12.0
	var breathe := sin(step * 1.7) * 0.006
	var nod := sin(_npc_nod * 18.0) * 0.012 if _npc_nod > 0.0 else 0.0
	_npc.position = _npc_base + Vector3(0, breathe - absf(nod), 0)
	_npc.flip_h = fmod(step, 9.0) > 7.6


## The regulars shift on their seats and lean on the bar, now and then (in steps).
func _animate_regulars() -> void:
	var step := floorf(_t * 12.0) / 12.0
	for r in _regulars:
		var n: Node3D = r["node"]
		if not is_instance_valid(n):
			continue
		var ph: float = r["phase"]
		var lean := 0.02 if fmod(step + ph, 11.0) > 8.5 else 0.0
		n.position = (r["base"] as Vector3) + Vector3(0, sin(step * 1.3 + ph) * 0.008 - lean, 0)


func _animate_tubes() -> void:
	for tb in _tubes:
		var on := true
		if tb["dying"]:
			# Buzzes off for a beat, stutters back.
			var k := fmod(floorf(_t * 12.0) * 0.37, 7.3)
			on = k > 0.9 and not (k > 3.1 and k < 3.5)
		(tb["light"] as OmniLight3D).visible = on
		(tb["mat"] as StandardMaterial3D).emission_energy_multiplier = 1.4 if on else 0.08


# ── input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _open or _is_modal():
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		get_viewport().set_input_as_handled()
		# The motel's room: off the bed first, the key turned back before you go.
		if _view != null and not _view.wants_out():
			return
		close()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		# The shop's bill: its Pay before anything in the room.
		if _counter != null and (place == "jednota" or place == "kiosk") and _counter.bill_hit((event as InputEventMouseButton).position):
			return
		if _shown >= 0 and _shown < _text.length() and _hover == "":
			_shown = -1
			return
		if _hover != "":
			_clicked(_hover)


## The eye for what you only look at, the hand for what you use, the feet for where you go
## (the user 6. 11.: as everywhere else in the game).
func _cursor_for(id: String) -> int:
	if id == "door" or id.begins_with("walk:") or (_view != null and _view.has_method("walks") and bool(_view.walks(id))):
		return HandCursor.WALK
	if _view != null and _view.has_method("only_look") and bool(_view.only_look(id)):
		return HandCursor.LOOK
	return HandCursor.POINT


func _hover_at(mouse: Vector2) -> String:
	var id := _hover_hit(mouse)
	if id == "":
		return ""
	# Not through a floor or a ceiling: the patch on another floor is not yours to click,
	# nor what stands up there (the user 6. 11.: "I could click the upper doors through the
	# ceiling, that is how I got up").
	if id.begins_with("walk:") and walker != null and not walker.floor_near(id):
		return ""
	if _view != null and _view.has_method("hot_ok") and not bool(_view.hot_ok(id)):
		return ""
	# In a place you walk about in, what stands on another floor is not within reach.
	if walker != null and not id.begins_with("walk:"):
		var b = _hot.get(id, {}).get("body")
		if b != null and absf((b as Node3D).position.y - _cam.position.y) > 2.0:
			return ""
	return id


func _hover_hit(mouse: Vector2) -> String:
	if INTERIOR_LOOK.in_exit_zone(get_viewport()):
		return ""
	var screen := get_viewport().get_visible_rect().size
	if screen.x <= 0.0:
		return ""
	var local := mouse / screen * Vector2(_vp.size)
	var from := _cam.project_ray_origin(local)
	var to := from + _cam.project_ray_normal(local) * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := _vp.find_world_3d().direct_space_state.intersect_ray(q)
	var n = hit.get("collider", null) as Node
	while n != null:
		if n.has_meta("room_hot"):
			return str(n.get_meta("room_hot"))
		n = n.get_parent()
	return ""


func _clicked(id: String) -> void:
	if id.begins_with("walk:"):
		if walker != null and not walker.busy:
			walker.go_floor(id.substr(5))
		return
	if _view != null:
		if id == "door":
			# A place you walk about in (room_walk.gd): you go to the door first.
			if _view.has_method("walk_out"):
				_view.walk_out()
			elif _view.wants_out():
				close()
			return
		if _view.click(id, hour):
			return
	if id == "door":
		_play("res://assets/sfx/dvereotevrit.mp3", -8.0)
		close()
		return
	match place:
		"jednota":
			_shop_click(id)
		"pub":
			_pub_click(id)
		"kiosk":
			_kiosk_click(id)
		"motel":
			_motel_click(id)


## The counter of the shop you are in.
func counter():
	if _counter == null:
		_counter = COUNTER_SHOP.new()
		_counter.room = self
		add_child(_counter)
	return _counter


## Goods, the till and what is on the counter are the counter's; she herself, talk.
func _shop_click(id: String) -> void:
	if counter().click(id):
		return
	if id == "her":
		_line += 1
		_npc_nod = 0.5
		say("Mrs Novotna", SHOP_LINES[_line % SHOP_LINES.size()])


func _pub_click(id: String) -> void:
	match id:
		"him":
			_line += 1
			_npc_nod = 0.5
			say("Mr Kubat", PUB_LINES[_line % PUB_LINES.size()])
		"tap":
			_npc_nod = 0.5
			if _mug > 0:
				say("Mr Kubat", "Finish that one first.")
				return
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				say("Mr Kubat", "A dollar. I do not run a tab for the camp. Not any more.")
				return
			_play(SFX_PUB + "tap_pour.mp3", -4.0)
			_mug = 3
			_show_mug(true)
			say("Mr Kubat", "Na zdravi.")
		"mug":
			if _mug <= 0:
				return
			_play(SFX_TOWN + "gulp.mp3", -4.0)
			_mug -= 1
			if _mug == 0:
				_play(SFX_PUB + "glass_down.mp3", -6.0)
				_show_mug(false)
				drank.emit()
		"machine":
			wants_closeup.emit("slot")
		"cap", "track":
			var lines: Array = REGULAR_LINES[id]
			say("Regular", lines[_reg_line[id] % lines.size()])
			_reg_line[id] += 1


func _kiosk_click(id: String) -> void:
	if counter().click(id):
		return
	if id == "her":
		_line += 1
		_npc_nod = 0.5
		say("Mrs Lojzova", KIOSK_LINES[_line % KIOSK_LINES.size()])


func _motel_click(id: String) -> void:
	match id:
		"him":
			_line += 1
			_npc_nod = 0.5
			say("Mr Simek", MOTEL_LINES[_line % MOTEL_LINES.size()])
		"desk":
			_npc_nod = 0.5
			wants_closeup.emit("motel_room")
		"machine":
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				say("", "The machine wants a dollar.")
				return
			_play(SFX_TOWN + "bottle_down.mp3", -4.0)
			say("", "A can of lemonade drops, warm. The light in the machine flickers off and on again.")


func _show_mug(full: bool) -> void:
	if _mug_node == null:
		return
	_mug_node.visible = true
	var m := _mug_node.material_override as StandardMaterial3D
	m.albedo_texture = _mug_tex.get("full" if full else "empty")
	if not full:
		get_tree().create_timer(2.5).timeout.connect(func():
			if _mug == 0 and is_instance_valid(_mug_node):
				_mug_node.visible = false)


# ── the strip of what is said ────────────────────────────────────────────────

func _build_strip() -> void:
	_strip_vp = SubViewport.new()
	_strip_vp.size = STRIP
	_strip_vp.transparent_bg = true
	_strip_vp.disable_3d = true
	_strip_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_strip_vp)
	_strip_canvas = Control.new()
	_strip_canvas.size = Vector2(STRIP)
	_strip_canvas.draw.connect(_draw_strip)
	_strip_vp.add_child(_strip_canvas)
	_strip_view = TextureRect.new()
	_strip_view.texture = _strip_vp.get_texture()
	_strip_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_strip_view.stretch_mode = TextureRect.STRETCH_SCALE
	_strip_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip_view)


func _layout_strip() -> void:
	var vp := get_viewport().get_visible_rect().size
	var k := maxi(1, int(floor(minf(vp.x * 0.7 / STRIP.x, vp.y / 270.0))))
	_strip_view.size = Vector2(STRIP * k)
	_strip_view.position = Vector2(floorf((vp.x - _strip_view.size.x) * 0.5), vp.y - _strip_view.size.y - 6.0 * k)
	_strip_view.visible = _text != "" and not _is_modal()


func _draw_strip() -> void:
	var c := _strip_canvas
	if _text == "":
		return
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(STRIP)), Color(0.05, 0.045, 0.035, 0.88))
	c.draw_rect(Rect2(0, 0, STRIP.x, 1), RETRO_UI.C_PLATE_LIGHT)
	c.draw_rect(Rect2(0, STRIP.y - 1, STRIP.x, 1), RETRO_UI.C_PLATE_DARK)
	var x := 6.0
	var y := 10.0
	if _who != "":
		c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), _who.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER)
		x += RETRO_UI.FONT_LABEL.get_string_size(_who.to_upper() + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2.0
	var text := _text if _shown < 0 else _text.substr(0, _shown)
	var lines := _wrap(text, RETRO_UI.FONT_TEXT, STRIP.x - 6.0 - x)
	for i in mini(lines.size(), 3):
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y + i * 9.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_BONE)


static func _wrap(text: String, font: Font, width: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	out.append(line)
	return out


# ── building ─────────────────────────────────────────────────────────────────

func _hot_box(id: String, pos: Vector3, size: Vector3, meshes: Array) -> void:
	var b := StaticBody3D.new()
	b.set_meta("room_hot", id)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	b.add_child(cs)
	b.position = pos
	_root.add_child(b)
	# Nothing to light up given: its box, unseen but under the glint (every thing you can
	# click lights up under the pointer, the user 6. 11.).
	if meshes.is_empty():
		var bm := BoxMesh.new()
		bm.size = size
		var mi := MeshInstance3D.new()
		mi.name = "Hot_" + id
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)
		meshes = [mi]
	_hot[id] = {"body": b, "meshes": meshes}


func _box(size: Vector3, pos: Vector3, mat: Material, name := "Box") -> MeshInstance3D:
	return K.slab(_root, size, pos, mat, name)


func _face(tex: String, size: Vector2, pos: Vector3, yaw: float, name := "Face") -> MeshInstance3D:
	return K.picture(_root, tex, size, pos, yaw, name)


## A Grok sprite `size.y` tall, as wide as its picture says (size.x when there is none).
func _sprite(tex: String, size: Vector2, pos: Vector3, yaw := 0.0, billboard := false, name := "Sprite") -> MeshInstance3D:
	var path := K.TEX + tex + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		size.x = size.y * float(t.get_width()) / float(t.get_height())
	return K.cutout(_root, tex, size, pos, yaw, billboard, name)


func _room(size: Vector3, floor_tex: String, wall_tex: String, ceil_tex: String, wall_m := 1.4, floor_m := 1.0) -> void:
	K.room(_root, size, floor_tex, wall_tex, ceil_tex, wall_m, floor_m)


func _omni(pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	_root.add_child(l)
	return l


## A fluorescent tube on the ceiling: a glowing box and its light.
func _tube(pos: Vector3, dying := false) -> void:
	var m := K._base(Color(0.95, 0.97, 0.98))
	m.emission_enabled = true
	m.emission = Color(0.9, 0.96, 1.0)
	m.emission_energy_multiplier = 1.4
	var mi := _box(Vector3(1.2, 0.05, 0.1), pos, m, "Tube")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(1.3, 0.04, 0.16), pos + Vector3(0, 0.04, 0), K.surface("galvanized", 0.4), "TubeHousing")
	var l := _omni(pos + Vector3(0, -0.2, 0), Color(0.88, 0.94, 1.0), 0.9, 5.0)
	_tubes.append({"light": l, "mat": m, "dying": dying})


## A window: glass glowing with the hour outside (no view: net curtains, frosted).
func _window(size: Vector2, pos: Vector3, yaw: float) -> void:
	var day := hour >= 7.0 and hour < 18.5
	var dusk := (hour >= 18.5 and hour < 20.0) or (hour >= 5.5 and hour < 7.0)
	var col := Color(0.86, 0.9, 0.92) if day else (Color(0.62, 0.42, 0.36) if dusk else Color(0.08, 0.1, 0.16))
	var m := K._base(col)
	if ResourceLoader.exists(K.TEX + "window_curtain.png"):
		m.albedo_texture = load(K.TEX + "window_curtain.png")
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = m.albedo_texture
	m.emission = col
	m.emission_energy_multiplier = 1.2 if day else 0.5
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = m
	q.position = pos
	q.rotation_degrees.y = yaw
	_root.add_child(q)
	var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(yaw))
	var frame := K.surface("planks_grey", 0.5, Color(0.9, 0.88, 0.84))
	var right := fwd.cross(Vector3.UP)
	for sgn in [-1.0, 1.0]:
		var side := K.slab(_root, Vector3(0.06, size.y + 0.12, 0.06), pos + right * sgn * (size.x * 0.5 + 0.03) + fwd * 0.02, frame, "WinFrame")
		side.rotation_degrees.y = yaw
		var tb := K.slab(_root, Vector3(size.x + 0.12, 0.06, 0.06), pos + Vector3(0, sgn * (size.y * 0.5 + 0.03), 0) + fwd * 0.02, frame, "WinFrame")
		tb.rotation_degrees.y = yaw
	if day:
		_omni(pos + fwd * 1.2, Color(0.9, 0.93, 0.98), 0.7, 5.0)


func _npc_sprite(tex: String, height: float, pos: Vector3, who: String) -> void:
	var path := NPC + tex + ".png"
	if not ResourceLoader.exists(path):
		return
	var t: Texture2D = load(path)
	_npc = Sprite3D.new()
	_npc.texture = t
	_npc.pixel_size = height / float(t.get_height())
	_npc.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_npc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_npc.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_npc.shaded = true
	_npc.offset = Vector2(0, t.get_height() * 0.5)
	_npc_base = pos
	_npc.position = pos
	_npc_who = who
	_root.add_child(_npc)
	_hot_box(who, pos + Vector3(0, height * 0.6, 0), Vector3(0.6, height * 0.8, 0.4), [])


func _regular(tex: String, size: Vector2, pos: Vector3, id: String) -> void:
	var s := _sprite(tex, size, pos, 0.0, true, "Regular")
	_regulars.append({"node": s, "base": pos, "phase": randf() * 9.0})
	_hot_box(id, pos + Vector3(0, size.y * 0.5, 0), Vector3(size.x * 0.8, size.y, 0.5), [s])


func _light_profile(lamps_warm: bool) -> void:
	var day := hour >= 7.0 and hour < 18.5
	_env.ambient_light_color = Color(0.92, 0.88, 0.78) if lamps_warm else Color(0.82, 0.86, 0.88)
	_env.ambient_light_energy = 0.55 if day else 0.32


# ── the Jednota ──────────────────────────────────────────────────────────────

## 6 x 5 m, the counter across the back third, the door behind you.
func _build_jednota() -> void:
	var size := Vector3(6.0, 2.9, 5.0)
	# The Czech institutional wall: green oil paint to the dado, the red line, whitewash.
	_room(size, "shop_floor", "oil_wall", "ceiling_board", K.oil_wall_metres(size.y), 2.6)
	K.skirting(_root, size, "planks_dark")
	_light_profile(false)
	_tube(Vector3(-1.2, 2.84, -0.6))
	_tube(Vector3(1.4, 2.84, -0.6), true)
	_tube(Vector3(0.0, 2.84, 1.4))
	# The counter, the till, the scales, the cards, the batteries' empty box.
	var top := _laminate()
	_box(Vector3(3.4, 0.9, 0.62), Vector3(0.0, 0.45, -0.5), K.surface("veneer_dark", 0.8), "Counter")
	_face("shop_counter", Vector2(3.4, 0.9), Vector3(0.0, 0.45, -0.185), 0.0, "CounterFront")
	_box(Vector3(3.5, 0.05, 0.7), Vector3(0.0, 0.925, -0.5), top, "CounterTop")
	var till := _sprite("shop_till", Vector2(0.5, 0.46), Vector3(0.95, 0.95, -0.6), 0.0, false, "Till")
	_hot_box("till", Vector3(0.95, 1.18, -0.6), Vector3(0.52, 0.48, 0.24), [till])
	_sprite("shop_scales", Vector2(0.42, 0.42), Vector3(-1.05, 0.95, -0.55), 0.0, false, "Scales")
	var cards := _sprite("card_box", Vector2(0.26, 0.26), Vector3(0.45, 0.95, -0.36), 0.0, false, "CardBox")
	_hot_box("card", Vector3(0.45, 1.08, -0.36), Vector3(0.3, 0.28, 0.2), [cards])
	var batt := _box(Vector3(0.3, 0.16, 0.2), Vector3(-0.5, 1.03, -0.36), K.surface("cardboard", 0.3), "BatteryBox")
	_hot_box("batteries", Vector3(-0.5, 1.03, -0.36), Vector3(0.32, 0.2, 0.22), [batt])
	# Behind the counter: the shelf of cigarettes and spirits, Mrs Novotna.
	_box(Vector3(3.0, 1.5, 0.3), Vector3(0.0, 1.55, -2.35), K.surface("planks_dark", 0.6), "BackShelf")
	var cigs := _face("shop_shelf_cigs", Vector2(2.9, 1.45), Vector3(0.0, 1.55, -2.195), 0.0, "Cigarettes")
	_hot_box("cigs", Vector3(0.0, 1.55, -2.2), Vector3(2.9, 1.45, 0.3), [cigs])
	_npc_sprite("town_shopgirl", 1.62, Vector3(0.1, 0.0, -1.35), "her")
	# Left wall: the long shelf of tins and jars, the baskets by the door.
	_box(Vector3(0.45, 2.0, 3.4), Vector3(-2.77, 1.0, 0.3), K.surface("galvanized", 0.6, Color(0.7, 0.7, 0.68)), "GoodsShelf")
	_face("shop_shelf_goods", Vector2(3.3, 1.86), Vector3(-2.54, 1.0, 0.3), 90.0, "Goods")
	_sprite("shop_baskets", Vector2(0.5, 0.5), Vector3(-1.9, 0.0, 2.0), 0.0, true, "Baskets")
	# Right wall: the drinks fridge humming, the bread, the ice cream freezer.
	var fridge := _box(Vector3(0.7, 1.9, 0.7), Vector3(2.62, 0.95, -0.6), K.surface("enamel_white", 0.6, Color(0.85, 0.86, 0.84)), "Fridge")
	fridge.name = "Fridge"
	var fglass := _face("shop_fridge", Vector2(0.66, 1.84), Vector3(2.265, 0.97, -0.6), -90.0, "FridgeDoor")
	var fm := fglass.material_override as StandardMaterial3D
	fm.emission_enabled = true
	fm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	fm.emission_texture = fm.albedo_texture
	fm.emission = Color(0.7, 0.85, 1.0)
	fm.emission_energy_multiplier = 0.5
	_omni(Vector3(1.9, 1.2, -0.6), Color(0.7, 0.85, 1.0), 0.25, 1.8)
	_box(Vector3(0.4, 1.6, 0.9), Vector3(2.78, 0.8, 0.6), K.surface("planks_grey", 0.5, Color(0.8, 0.7, 0.55)), "BreadRack")
	_face("shop_bread", Vector2(0.86, 1.15), Vector3(2.575, 0.95, 0.6), -90.0, "Bread")
	_sprite("shop_freezer", Vector2(1.0, 0.75), Vector3(2.3, 0.0, 1.6), -90.0, false, "Freezer")
	# The beer crates by the counter's end.
	var crate := _sprite("beer_crate_full", Vector2(0.56, 0.42), Vector3(-1.95, 0.0, -0.1), 0.0, true, "BeerCrate")
	_sprite("beer_crate_full", Vector2(0.56, 0.42), Vector3(-2.0, 0.42, -0.14), 0.0, true, "BeerCrate2")
	_hot_box("beer", Vector3(-1.95, 0.42, -0.1), Vector3(0.6, 0.84, 0.5), [crate])
	_face("shop_poster", Vector2(0.6, 0.8), Vector3(1.3, 1.75, -2.495), 0.0, "Poster")
	K.picture(_root, "calendar", Vector2(0.36, 0.48), Vector3(-1.9, 1.7, -2.495), 0.0, "Calendar")
	# The door you came in by, the shop window beside it.
	var door := _face("door_interior", Vector2(0.95, 2.05), Vector3(-1.6, 1.03, 2.495), 180.0, "Door")
	_hot_box("door", Vector3(-1.6, 1.03, 2.45), Vector3(1.0, 2.05, 0.12), [door])
	_window(Vector2(2.4, 1.4), Vector3(1.0, 1.55, 2.49), 180.0)
	_cam.position = Vector3(0.0, 1.58, 0.95)
	_base_rot = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
	counter().begin("jednota", {"slots": [Vector3(-0.2, 0.95, -0.3), Vector3(0.05, 0.95, -0.3), Vector3(0.3, 0.95, -0.3), Vector3(-0.7, 0.95, -0.3), Vector3(0.7, 0.95, -0.3)], "till": till})


# ── the pub U Jezera ─────────────────────────────────────────────────────────

## 7 x 6 m: the bar across in front of you, the tables to the left, the machine right.
func _build_pub() -> void:
	var size := Vector3(7.0, 2.8, 6.0)
	_room(size, "pub_floor", "pub_wall", "ceiling_pine", 1.6, 1.6)
	# Dark panelling up to the dado.
	var wain := K.surface("pub_wainscot", 1.0)
	_box(Vector3(size.x, 1.1, 0.04), Vector3(0, 0.55, -size.z * 0.5 + 0.02), wain, "WainBack")
	_box(Vector3(size.x, 1.1, 0.04), Vector3(0, 0.55, size.z * 0.5 - 0.02), wain, "WainFront")
	_box(Vector3(0.04, 1.1, size.z), Vector3(-size.x * 0.5 + 0.02, 0.55, 0), wain, "WainL")
	_box(Vector3(0.04, 1.1, size.z), Vector3(size.x * 0.5 - 0.02, 0.55, 0), wain, "WainR")
	_light_profile(true)
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.5, 0.42, 0.32)
	_env.fog_density = 0.035
	# The bar, the taps, the back bar, Mr Kubat.
	_box(Vector3(3.6, 1.05, 0.6), Vector3(0.3, 0.525, -1.0), K.surface("pub_wainscot", 0.8), "Bar")
	_face("pub_bar", Vector2(3.6, 1.05), Vector3(0.3, 0.525, -0.695), 0.0, "BarFront")
	_box(Vector3(3.7, 0.06, 0.72), Vector3(0.3, 1.08, -1.0), K.surface("veneer_dark", 0.6), "BarTop")
	var taps := _sprite("pub_taps", Vector2(0.5, 0.42), Vector3(0.95, 1.11, -1.1), 0.0, false, "Taps")
	_hot_box("tap", Vector3(0.95, 1.3, -1.1), Vector3(0.5, 0.4, 0.3), [taps])
	_box(Vector3(4.0, 1.7, 0.35), Vector3(0.3, 1.6, -2.82), K.surface("pub_wainscot", 0.8), "BackBar")
	_face("pub_backbar", Vector2(3.9, 1.6), Vector3(0.3, 1.6, -2.64), 0.0, "BackBarFace")
	_npc_sprite("town_landlord", 1.7, Vector3(0.1, 0.0, -1.75), "him")
	_mug_tex = {"full": load(K.TEX + "mug_full.png") if ResourceLoader.exists(K.TEX + "mug_full.png") else null,
		"empty": load(K.TEX + "mug_empty.png") if ResourceLoader.exists(K.TEX + "mug_empty.png") else null}
	_mug_node = _sprite("mug_full", Vector2(0.2, 0.2), Vector3(0.15, 1.11, -0.82), 0.0, true, "Mug")
	_mug_node.visible = false
	_hot_box("mug", Vector3(0.15, 1.21, -0.82), Vector3(0.26, 0.24, 0.24), [_mug_node])
	_sprite("ashtray", Vector2(0.16, 0.16), Vector3(-0.5, 1.11, -0.8), 0.0, true, "Ashtray")
	# The tracksuit at the bar's left end.
	_regular("regular_track", Vector2(0.95, 1.75), Vector3(-1.7, 0.0, -0.45), "track")
	# The fruit machine in the corner, its lights.
	_box(Vector3(0.7, 1.75, 0.55), Vector3(3.05, 0.875, -1.3), K.surface("galvanized", 0.5, Color(0.3, 0.25, 0.3)), "Machine")
	var mface := _face("fruit_machine", Vector2(0.68, 1.72), Vector3(2.695, 0.875, -1.3), -90.0, "MachineFace")
	var mm := mface.material_override as StandardMaterial3D
	mm.emission_enabled = true
	mm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mm.emission_texture = mm.albedo_texture
	mm.emission = Color(1.0, 0.85, 0.7)
	mm.emission_energy_multiplier = 0.6
	_hot_box("machine", Vector3(2.75, 0.9, -1.3), Vector3(0.2, 1.75, 0.7), [mface])
	_omni(Vector3(2.3, 1.5, -1.3), Color(1.0, 0.5, 0.6), 0.35, 2.0)
	# The tables on the left, checked cloths, the old man in the cap at one of them.
	var cloth := K.surface("tablecloth", 0.5)
	var wood := K.surface("veneer_dark", 0.6)
	for tz in [0.2, 1.9]:
		_box(Vector3(1.0, 0.04, 0.8), Vector3(-2.6, 0.76, tz), cloth, "Table")
		_box(Vector3(0.08, 0.74, 0.08), Vector3(-2.6, 0.37, tz), wood, "TableLeg")
		for cx in [-0.75, 0.75]:
			_box(Vector3(0.42, 0.05, 0.42), Vector3(-2.6 + cx, 0.46, tz), wood, "Seat")
			_box(Vector3(0.05, 0.5, 0.42), Vector3(-2.6 + cx * 1.24, 0.72, tz), wood, "SeatBack")
		_sprite("ashtray", Vector2(0.14, 0.14), Vector3(-2.5, 0.78, tz + 0.1), 0.0, true, "TableAshtray")
		_hang_lamp(Vector3(-2.6, 2.1, tz))
	_regular("regular_cap", Vector2(1.1, 1.45), Vector3(-2.75, 0.0, 1.9), "cap")
	_hang_lamp(Vector3(0.3, 2.2, -1.0))
	# The walls: antlers, the brewery sign, the dartboard, a clock, the coat hooks.
	_sprite("antlers", Vector2(0.5, 0.5), Vector3(-3.47, 1.75, 1.0), 90.0, false, "Antlers")
	_face("pub_sign", Vector2(0.8, 0.6), Vector3(-3.475, 1.75, -1.2), 90.0, "BrewerySign")
	_sprite("dartboard", Vector2(0.5, 0.5), Vector3(3.47, 1.45, 1.2), -90.0, false, "Dartboard")
	_sprite("wall_clock", Vector2(0.32, 0.32), Vector3(-1.5, 1.95, -2.98), 0.0, false, "Clock")
	_sprite("coat_hook", Vector2(0.46, 0.68), Vector3(2.0, 1.0, 2.97), 180.0, false, "Coat")
	_window(Vector2(1.3, 1.1), Vector3(-1.2, 1.65, 2.99), 180.0)
	_window(Vector2(1.1, 1.1), Vector3(-3.49, 1.65, 0.9 + 0.0), 90.0)
	var door := _face("door_interior", Vector2(0.95, 2.05), Vector3(1.0, 1.03, 2.995), 180.0, "Door")
	_hot_box("door", Vector3(1.0, 1.03, 2.95), Vector3(1.0, 2.05, 0.12), [door])
	_cam.position = Vector3(0.2, 1.6, 0.5)
	_base_rot = Vector3(deg_to_rad(-7.0), deg_to_rad(8.0), 0.0)


# ── the kiosk ────────────────────────────────────────────────────────────────

func _build_kiosk() -> void:
	var size := Vector3(4.0, 2.6, 3.4)
	_room(size, "shop_floor", "oil_wall", "ceiling_board", K.oil_wall_metres(size.y), 2.4)
	_light_profile(false)
	_tube(Vector3(0.0, 2.54, -0.4))
	_box(Vector3(2.8, 0.95, 0.55), Vector3(0, 0.475, -0.55), K.surface("veneer_dark", 0.6), "Counter")
	var front := _face("kiosk_counter", Vector2(2.8, 0.95), Vector3(0, 0.475, -0.27), 0.0, "CounterFront")
	_hot_box("till", Vector3(0.9, 0.5, -0.27), Vector3(0.6, 0.9, 0.1), [front])
	_box(Vector3(2.9, 0.05, 0.62), Vector3(0, 0.975, -0.55), _laminate(), "CounterTop")
	_box(Vector3(3.6, 1.6, 0.3), Vector3(0, 1.4, -1.5), K.surface("planks_dark", 0.6), "Shelves")
	var shelves := _face("kiosk_shelves", Vector2(3.5, 1.55), Vector3(0, 1.4, -1.345), 0.0, "ShelvesFace")
	_hot_box("cigs", Vector3(0, 1.4, -1.35), Vector3(3.5, 1.5, 0.2), [shelves])
	_sprite("kiosk_calendar", Vector2(0.4, 0.55), Vector3(1.5, 1.4, 1.695), 180.0, false, "Calendar")
	_npc_sprite("town_lojzova", 1.6, Vector3(-0.3, 0.0, -1.05), "her")
	_window(Vector2(1.6, 1.0), Vector3(-0.9, 1.55, 1.69), 180.0)
	var door := _face("door_interior", Vector2(0.9, 2.0), Vector3(1.1, 1.0, 1.695), 180.0, "Door")
	_hot_box("door", Vector3(1.1, 1.0, 1.65), Vector3(0.9, 2.0, 0.12), [door])
	_cam.position = Vector3(0.0, 1.58, 0.75)
	_base_rot = Vector3(deg_to_rad(-6.0), 0.0, 0.0)
	counter().begin("kiosk", {"slots": [Vector3(-0.4, 1.0, -0.4), Vector3(-0.1, 1.0, -0.4), Vector3(0.2, 1.0, -0.4), Vector3(0.5, 1.0, -0.4)], "billboard": true})


# ── the motel's lobby ────────────────────────────────────────────────────────

func _build_motel() -> void:
	var size := Vector3(5.5, 2.7, 5.0)
	_room(size, "motel_carpet", "motel_wall", "ceiling_board", 1.2, 1.6)
	_light_profile(true)
	_env.ambient_light_energy = 0.3
	_box(Vector3(2.6, 1.05, 0.6), Vector3(0.3, 0.525, -1.2), K.surface("veneer_dark", 0.6), "Desk")
	var desk := _face("motel_desk", Vector2(2.6, 1.05), Vector3(0.3, 0.525, -0.895), 0.0, "DeskFront")
	_box(Vector3(2.7, 0.05, 0.7), Vector3(0.3, 1.075, -1.2), K.surface("veneer_dark", 0.5), "DeskTop")
	_hot_box("desk", Vector3(0.3, 0.6, -0.9), Vector3(2.6, 1.1, 0.2), [desk])
	K.picture(_root, "key_rack", Vector2(0.9, 0.5), Vector3(0.3, 1.7, -2.49), 0.0, "Keys")
	_npc_sprite("town_motel", 1.7, Vector3(0.4, 0.0, -1.85), "him")
	var vm := _sprite("vending_machine", Vector2(0.9, 1.8), Vector3(-2.3, 0.0, 0.6), 90.0, false, "Vending")
	if vm != null:
		var mm := vm.material_override as StandardMaterial3D
		mm.emission_enabled = true
		mm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mm.emission_texture = mm.albedo_texture
		mm.emission = Color(0.85, 0.95, 1.0)
		mm.emission_energy_multiplier = 0.7
	_hot_box("machine", Vector3(-2.3, 0.9, 0.6), Vector3(0.4, 1.8, 0.9), [vm])
	_omni(Vector3(-1.8, 1.2, 0.6), Color(0.75, 0.9, 1.0), 0.35, 2.4)
	_sprite("plastic_plant", Vector2(0.5, 0.9), Vector3(2.3, 0.0, -2.0), 0.0, true, "Plant")
	K.prop(_root, "tv_small", Vector3(2.2, 0.75, 1.3), -120.0)
	_box(Vector3(0.6, 0.75, 0.5), Vector3(2.2, 0.375, 1.3), K.surface("veneer_dark", 0.5), "TvStand")
	_omni(Vector3(1.8, 1.1, 1.0), Color(0.6, 0.72, 1.0), 0.3, 2.2)
	_omni(Vector3(0.3, 2.3, -0.6), Color(1.0, 0.8, 0.55), 0.9, 4.5, true)
	_window(Vector2(1.5, 1.1), Vector3(-1.0, 1.6, 2.49), 180.0)
	var door := _face("door_interior", Vector2(0.95, 2.05), Vector3(1.3, 1.03, 2.495), 180.0, "Door")
	_hot_box("door", Vector3(1.3, 1.03, 2.45), Vector3(1.0, 2.05, 0.12), [door])
	_cam.position = Vector3(0.2, 1.6, 0.6)
	_base_rot = Vector3(deg_to_rad(-6.0), 0.0, 0.0)


## A lamp over a table on its chain, warm, the shade a sprite.
## A plain grey-brown laminate counter top.
func _laminate() -> StandardMaterial3D:
	return K.surface("plastic", 0.5, Color(0.56, 0.52, 0.46))


func _hang_lamp(pos: Vector3) -> void:
	_box(Vector3(0.015, 2.8 - pos.y - 0.2, 0.015), Vector3(pos.x, (2.8 + pos.y + 0.2) * 0.5, pos.z), K.surface("galvanized", 0.3, Color(0.3, 0.3, 0.3)), "Chain")
	var s := _sprite("pub_lamp", Vector2(0.42, 0.42), pos - Vector3(0, 0.2, 0), 0.0, true, "Lamp")
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := s.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	m.emission_texture = m.albedo_texture
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 0.7
	_omni(pos - Vector3(0, 0.35, 0), Color(1.0, 0.76, 0.45), 1.0, 3.6, true)


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.volume_db = db
		_audio.play()


func _loop(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var s = load(path)
	if s is AudioStreamMP3:
		s = (s as AudioStreamMP3).duplicate()
		s.loop = true
	_amb.stream = s
	_amb.volume_db = db
	_amb.play()
