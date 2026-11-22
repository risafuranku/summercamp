extends Node

## A split screen's second warden (TODO.md SPLITSCREEN): a co-op client like any other,
## running in this program. This node is its instance's root (group "game_instance": what
## is under it finds its own Coop, CoreRoot, EventBus, GuestManager, EmailManager and main
## here, scripts/instance/instance.gd) with a MultiplayerAPI of its own, so its Coop joins the
## host's over the loopback line exactly as one on another machine does; its main is the
## game's own main, drawn into the right half of the window, its world its own copy built
## from the host's snapshot. Its input is its own pad's (input: scripts/instance/instance_input.gd).
##   LOCAL_CLIENT.start(host_main, pad_device)    LOCAL_CLIENT.stop()

const INSTANCE = preload("res://scripts/instance/instance.gd")
const INPUT = preload("res://scripts/instance/instance_input.gd")
const PAD = preload("res://scripts/input/pad.gd")
const COOP = preload("res://scripts/coop/coop.gd")
## The second warden's camp sounds go here, silent: the camp is heard once, from the host's
## game (its own world's music, ambience and radio would play everything twice). What is its
## own stays heard on its own bus: its steps, its torch, its hurt, its pager, its PC, its
## work, the pipes, a chase at it (they were all silent till 22. 11.: it did things in silence).
const BUS := INSTANCE.SILENT_BUS
## The buses whose sound is the camp's, the same in both games: silent in the second's.
const CAMP_BUSES := ["WorldMusic", "AmbientMusic", "OutdoorAmbience", "NightInsects", "Radio", "RadioMusic", "Caretaker", "Music"]
## (And the world's sounds through walls: world_sounds.gd's "ThroughWalls..." buses.)
const CAMP_BUS_PREFIX := "ThroughWalls"
## How often its players are looked at again (a script may give one its bus as it plays).
const ROUTE_EVERY := 0.5
var _players: Array = []
var _route_t := 0.0
const MAIN_SCENE := "res://scenes/main.tscn"
## The services a co-op machine has one of, in the autoloads' order (project.godot).
const SERVICES := [
	["EventBus", "res://core/events/event_bus.gd"],
	["CoreRoot", "res://core/state/core_root.gd"],
	["EmailManager", "res://scripts/email_manager.gd"],
	["GuestManager", "res://scripts/guest_manager.gd"],
	["Coop", "res://scripts/coop/coop.gd"],
]
## The line between the two pictures, in the window's pixels.
const GAP := 2
## Its pad's Menu held this long: the second warden leaves (once the Menu that joined it is
## let go).
const LEAVE_HOLD := 1.2

## Its main (INSTANCE.main_of for what is under this node).
var main: Node
var input = INPUT.new()
var box: SubViewportContainer
var screen: SubViewport
var _menu_held := 0.0
var _menu_armed := false


## The second warden in: the host's camp hosted (if it is not), this instance made, its
## main drawn on the right, joined to 127.0.0.1. Returns the node (in the tree), null where
## the build has no co-op line (the web: its pads all play the one warden).
static func start(host_main: Node, pad_device: int) -> Node:
	if not COOP.line_available():
		return null
	var tree := host_main.get_tree()
	var host_coop := INSTANCE.coop(host_main)
	if not host_coop.is_active() and not host_coop.host():
		return null
	var me = load("res://scripts/instance/local_client.gd").new()
	me.name = "LocalClient"
	me.input.device = pad_device
	me.add_to_group(INSTANCE.GROUP)
	tree.root.add_child(me)
	INSTANCE.count = 2
	tree.set_multiplayer(SceneMultiplayer.new(), me.get_path())
	me._build(host_coop.port)
	return me


func _build(port: int) -> void:
	for s in SERVICES:
		var n: Node = load(str(s[1])).new()
		n.name = str(s[0])
		add_child(n)
	var coop := get_node("Coop")
	coop.port = port
	# Its own pad's translator: its events into its screen and its own input (feed_event).
	var pad = PAD.new()
	pad.name = "Pad"
	pad.sink = self
	pad.only_device = input.device
	add_child(pad)
	_quiet()
	box = SubViewportContainer.new()
	box.name = "Screen"
	box.stretch = true
	# The window's keys and mouse are the host's: its pad's events are pushed in (I5).
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_process_input(false)
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(box)
	screen = SubViewport.new()
	screen.name = "View"
	# Its world is its own copy (built from the host's snapshot, as on another machine).
	screen.own_world_3d = true
	screen.audio_listener_enable_3d = false
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	box.add_child(screen)
	main = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("local_client", true)
	screen.add_child(main)
	layout(true)


## One of its pad's made events: into its own input and pushed into its screen (the
## window's input never reaches it: its box takes none).
func feed_event(event: InputEvent) -> void:
	input.feed(event)
	if screen != null:
		screen.push_input(event, true)


## Its sounds on a silent bus of their own (now and for everything it makes later).
func _quiet() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS), true)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D) and is_ancestor_of(node):
		_players.append(node)
		_route(node)
		# (Its own _ready may set a bus of its own: after that, looked at again.)
		node.ready.connect(func() -> void: _route(node), CONNECT_ONE_SHOT)


## A player of the second's: silent if its sound is the camp's (or 3D: its world's listener
## is off, the camp's 3D sound is the host's), else on the bus its script gave it.
func _route(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var bus := str(node.get("bus"))
	if bus == BUS:
		return
	if node is AudioStreamPlayer3D or CAMP_BUSES.has(bus) or bus.begins_with(CAMP_BUS_PREFIX):
		node.set("bus", BUS)


func _route_all(delta: float) -> void:
	_route_t -= delta
	if _route_t > 0.0:
		return
	_route_t = ROUTE_EVERY
	for i in range(_players.size() - 1, -1, -1):
		var p = _players[i]
		if not is_instance_valid(p):
			_players.remove_at(i)
		else:
			_route(p)


## The window split down the middle (true) or the host's alone (false).
func layout(split: bool) -> void:
	var host_main := (Engine.get_main_loop() as SceneTree).current_scene
	var one := host_main.get_node_or_null("Seat1") as Control if host_main != null else null
	if box != null:
		box.anchor_left = 0.5
		box.anchor_right = 1.0
		box.anchor_top = 0.0
		box.anchor_bottom = 1.0
		box.offset_left = GAP * 0.5
		box.offset_right = 0
		box.offset_top = 0
		box.offset_bottom = 0
		box.visible = split
	if one != null:
		one.anchor_right = 0.5 if split else 1.0
		one.offset_right = -GAP * 0.5 if split else 0.0


func _process(delta: float) -> void:
	_route_all(delta)
	if not Input.is_joy_button_pressed(input.device, JOY_BUTTON_START):
		_menu_armed = true
		_menu_held = 0.0
		return
	if _menu_armed:
		_menu_held += delta
		if _menu_held >= LEAVE_HOLD:
			stop()


## The second warden out: its Coop leaves the line, its instance goes, its pad is the
## window's again, the window whole.
func stop() -> void:
	set_process(false)
	var coop := get_node_or_null("Coop")
	if coop != null:
		coop.leave()
	var pad := PAD.node()
	if pad != null:
		pad.claim(input.device, false)
	layout(false)
	INSTANCE.count = 1
	queue_free()
