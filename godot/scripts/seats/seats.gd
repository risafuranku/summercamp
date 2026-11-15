extends Node

## The wardens at this machine (TODO.md SPLITSCREEN). A seat is one warden here: its input,
## its screen (a SubViewport everything this warden sees is drawn into, the world's view
## and the UI; its input goes only into it, and `get_viewport()` inside it is the seat's
## part of the window, so layouts follow by themselves), its view of the one world, its body
## and its player-facing layer. Seat 1's screen is main's (scenes/main.tscn Seat1/Screen):
## one player, the whole window. A second pad's Menu out in the camp makes seat 2: its
## warden beside yours, the window split down the middle; its Menu held leaves.
##
## What draws for a warden goes on its seat's screen, never on the window's root:
##   SEATS.screen_of(self).add_child(layer)
##
## Seat 2 so far (stage S3): its body walks, looks, runs, jumps, crouches and lights its
## torch in the camp; its HUD, its hands and the rooms are the next stages.

const SEAT_PAD = preload("res://scripts/seats/seat_pad.gd")
const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const PAD = preload("res://scripts/input/pad.gd")
const FIGURE = preload("res://scripts/coop/remote_player.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const PROFILES = preload("res://scripts/profiles.gd")
const HUD_SCRIPT = preload("res://scripts/hud_manager.gd")

## Every seat's screen is in this group.
const GROUP := "seat_screen"
## Seat 2's Menu held this long leaves (a press alone does nothing yet).
const LEAVE_HOLD := 1.2
## The line between the two screens, in the window's pixels.
const GAP := 2
## Each seat's warden as the other seat sees them (the co-op's figure, remote_player.gd),
## on a render layer of its own that its own eye leaves out: seat 1's, seat 2's.
const FIG_LAYER := [1 << 10, 1 << 12]
## The bar's cells while the window is split (hud_manager shown_cells): each its own
## HEALTH and STAMINA, the camp's cells once across the TV.
const CELLS_ONE := ["health", "stamina", "cash", "clock"]
const CELLS_TWO := ["health", "stamina", "guests", "mail", "risk"]

signal seats_changed(count: int)

var main: Node
## Seat 2 while it is here: {"body", "pad", "box" (its SubViewportContainer), "screen",
## "eye" (its camera in the world), "view" (the world's viewport it looks through), "figs"
## (both wardens' figures), "hud" (its own HUD on its screen)}; {} when nobody sits there.
var two: Dictionary = {}
var _menu_held := 0.0
## The Menu that joined is let go first (held on, it would leave at once).
var _menu_armed := false


## The screen of the seat `node` is drawn for: the nearest seat screen over it; for a node
## outside every seat (an autoload, a node not in the tree yet) seat 1's.
static func screen_of(node: Node) -> Node:
	var at := node
	while at != null:
		if at.is_in_group(GROUP):
			return at
		at = at.get_parent()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var first := tree.get_first_node_in_group(GROUP)
	return first if first != null else tree.root


func _ready() -> void:
	name = "Seats"
	var pad := PAD.node()
	if pad != null:
		pad.join_handler = try_join


func count() -> int:
	return 2 if not two.is_empty() else 1


## A pad not seat 1's pressed Menu: seat 2 out in the camp, if the game is there.
func try_join(device: int) -> bool:
	if not two.is_empty() or main == null:
		return false
	if not bool(main.get("_gameplay_started")) or bool(main.get("_menu_mode")) or bool(main.get("_game_over_active")):
		return false
	var p1 = main.get("_player")
	if p1 == null or not is_instance_valid(p1):
		return false
	join(device)
	return true


func join(device: int) -> void:
	var p1: Node3D = main.get("_player")
	var body = PLAYER_SCRIPT.new()
	body.seat = 2
	body.seat_input = SEAT_PAD.new(device)
	var gm = main.get("grid_manager")
	if gm != null and body.has_method("set_grid_manager"):
		body.set_grid_manager(gm)
	# Beside you, a step to the right, looking the same way.
	var side := p1.global_transform.basis.x.normalized()
	body.position = p1.global_position + side * 1.3 + Vector3(0, 0.2, 0)
	body.rotation.y = p1.rotation.y
	(main.get("_world_3d") as Node).add_child(body)
	var box := SubViewportContainer.new()
	box.name = "Seat2"
	box.stretch = true
	# Its input is its pad's alone: the window's keys and mouse are seat 1's.
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_process_input(false)
	var screen := SubViewport.new()
	screen.name = "Screen"
	screen.transparent_bg = true
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	screen.add_to_group(GROUP)
	box.add_child(screen)
	var view := SubViewportContainer.new()
	view.name = "SubViewportContainer"
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_process_input(false)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(view)
	var world_vp := SubViewport.new()
	world_vp.name = "SubViewport"
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The camp's sounds are heard by seat 1's ears (one listener: two would play it twice).
	world_vp.audio_listener_enable_3d = false
	view.add_child(world_vp)
	var eye := Camera3D.new()
	eye.name = "Eye"
	world_vp.add_child(eye)
	main.add_child(box)
	# Its own HUD on its screen: its health and stamina, the camp's cells yours leaves out.
	var hud = HUD_SCRIPT.new()
	hud.name = "HudManager"
	hud.shown_cells = CELLS_TWO
	hud.pager_sound = false
	screen.add_child(hud)
	hud.setup_interaction_hint()
	hud.setup_money_hud()
	hud.setup_weather_hud()
	hud.setup_time_hud()
	hud.set_camera_provider(func(): return eye)
	var hud1 = main.get("_hud_manager")
	if hud1 != null:
		hud1.show_cells(CELLS_ONE)
	world_vp.world_3d = ((main.get("_sub_viewport_container") as Node).get_child(0) as SubViewport).find_world_3d()
	eye.current = true
	RETRO_RENDER.register(view)
	# The warden's own 2D (its feet looking down, the blood on the view) on its own view.
	for layer in body.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).custom_viewport = world_vp
	# Each sees the other: your figure for seat 2, its figure for you (the co-op's look:
	# yours from your warden, the next one for seat 2).
	var look: Dictionary = PROFILES.profile_look()
	var m1 := maxi(0, int(look.get("m", 0)))
	var figs := [_figure(m1, int(look.get("c", 0)), 0), _figure((m1 + 1) % LOOKS.count(), (int(look.get("c", 0)) + 3) % LOOKS.color_count(), 1)]
	var cam1 := p1.get_node_or_null("Head/Camera3D") as Camera3D
	if cam1 != null:
		cam1.cull_mask &= ~int(FIG_LAYER[0])
	# Your figure is seen by seat 2's eye, seat 2's by yours (each faces the one who looks).
	figs[0].viewer = eye
	figs[1].viewer = cam1
	two = {"body": body, "pad": body.seat_input, "box": box, "screen": screen, "eye": eye, "view": world_vp, "figs": figs, "hud": hud}
	_menu_held = 0.0
	_menu_armed = false
	_layout()
	RenderingServer.frame_pre_draw.connect(_put_eye)
	seats_changed.emit(count())


## Seat 2 gone: its body, its screen; the window whole again.
func leave() -> void:
	if two.is_empty():
		return
	if RenderingServer.frame_pre_draw.is_connected(_put_eye):
		RenderingServer.frame_pre_draw.disconnect(_put_eye)
	var pad := PAD.node()
	if pad != null:
		pad.release(int((two["pad"]).device))
	for n in [two.get("body"), two.get("box")] + (two.get("figs", []) as Array):
		if n != null and is_instance_valid(n):
			n.queue_free()
	var p1 = main.get("_player")
	var cam1 := p1.get_node_or_null("Head/Camera3D") as Camera3D if p1 != null and is_instance_valid(p1) else null
	if cam1 != null:
		cam1.cull_mask |= int(FIG_LAYER[0])
	var hud1 = main.get("_hud_manager")
	if hud1 != null:
		hud1.show_cells([])
	two = {}
	_layout()
	seats_changed.emit(count())


func _process(delta: float) -> void:
	if two.is_empty():
		return
	var body = two["body"]
	if body == null or not is_instance_valid(body):
		leave()
		return
	_feed_figures()
	_feed_hud(body)
	var pad = two["pad"]
	pad.poll()
	if not pad.held("menu"):
		_menu_armed = true
	if pad.held("menu") and _menu_armed:
		_menu_held += delta
		if _menu_held >= LEAVE_HOLD:
			leave()
	else:
		_menu_held = 0.0


## Seat 2's eye where its warden's head is, the moment before the frame is drawn (the head
## moves in the frame's own steps: a frame behind, the view swam).
func _put_eye() -> void:
	if two.is_empty():
		return
	var body = two["body"]
	var eye: Camera3D = two["eye"]
	if body == null or not is_instance_valid(body) or eye == null or not is_instance_valid(eye):
		return
	var cam := body.get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		return
	eye.global_transform = cam.global_transform
	eye.fov = cam.fov
	eye.near = cam.near
	eye.far = cam.far
	eye.cull_mask = cam.cull_mask & ~int(FIG_LAYER[1])
	eye.h_offset = cam.h_offset
	eye.v_offset = cam.v_offset
	eye.environment = cam.environment
	eye.attributes = cam.attributes


## Seat 2's HUD: the camp's clock, weather and night risk as yours shows them, its own
## stamina and torch (its health is whole: the night goes for the window's warden so far).
func _feed_hud(body: Node) -> void:
	var hud = two.get("hud")
	if hud == null or not is_instance_valid(hud):
		return
	hud.mirror_camp(main.get("_hud_manager"))
	main.sync_player_meters(hud, body)
	hud.set_health_ratio(1.0)


func _figure(model: int, color: int, seat_index: int) -> Node3D:
	var f = FIGURE.new()
	f.setup(model, color)
	# (Fed every frame here: drawn a hair behind, not the wire's tenth of a second.)
	f.delay = 0.03
	(main.get("_world_3d") as Node).add_child(f)
	f.set_render_layers(int(FIG_LAYER[seat_index]))
	# (Seat 2's figure stands for its body to the camp's feet, prints and gates, as an
	# other warden's does; the window's warden is counted as "you" already.)
	if seat_index == 0:
		f.remove_from_group("coop_remote_player")
	return f


## Where each warden is, for its figure: as the co-op's state says it (coop_camp
## local_warden), out of sight while the window's warden is in a room, at the PC, on the
## lake (seat 2 is in the camp only so far).
func _feed_figures() -> void:
	var figs: Array = two.get("figs", [])
	var bodies: Array = [main.get("_player"), two.get("body")]
	for i in mini(figs.size(), bodies.size()):
		var f = figs[i]
		var b = bodies[i]
		if f == null or not is_instance_valid(f) or b == null or not is_instance_valid(b):
			continue
		var inside := false
		if i == 0:
			var lake = main.get("_lake_trip")
			inside = bool(main.call("_is_any_interior_open")) or (lake != null and lake.is_active())
		f.push_state({"p": (b as Node3D).global_position, "y": (b as Node3D).rotation.y, "t": false,
			"d": -(b as Node3D).global_basis.z, "v": Vector2(b.velocity.x, b.velocity.z).length(), "in": inside})


## One seat: its screen the whole window. Two: side by side, a thin line between.
func _layout() -> void:
	var one := main.get_node_or_null("Seat1") as Control
	if one == null:
		return
	if two.is_empty():
		one.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		one.anchor_left = 0.0
		one.anchor_top = 0.0
		one.anchor_right = 0.5
		one.anchor_bottom = 1.0
		one.offset_left = 0
		one.offset_top = 0
		one.offset_right = -GAP * 0.5
		one.offset_bottom = 0
		var box: Control = two["box"]
		box.anchor_left = 0.5
		box.anchor_top = 0.0
		box.anchor_right = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = GAP * 0.5
		box.offset_top = 0
		box.offset_right = 0
		box.offset_bottom = 0
	RETRO_RENDER.refresh_all(get_tree())
