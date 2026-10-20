extends Node

## Up to four wardens, one camp: co-op, sandbox camps only (DESIGN.md §12, autoload
## "Coop"). The host runs the camp exactly as one player would; each other machine is a
## window onto it. When one joins it is sent the whole camp (the save snapshot,
## main.coop_world_snapshot()), then the clock and the weather, and every machine streams
## its own warden (where they stand and look, the torch) to all the others, who see them
## walking about as scripts/coop/remote_player.gd (one figure each). Nothing on a joining
## machine runs the camp (sim_here() is false there): no clock of its own, no guests or
## mail rolled, no nights. ENet, one port, the host in the middle (what one joining
## machine says to another goes through the host: SceneMultiplayer's relay); over
## Tailscale or a LAN the address is the host's machine.
##
## Each warden is the player's warden (scripts/profiles.gd: the WARDENS page in the menu),
## with the name and the look chosen there (the figure and the jacket's colour:
## scripts/coop/warden_looks.gd), told to the others when they meet (_hello). A warden who
## never chose a figure gets the one of their place on the line (the host the first, the
## joining ones the next free: _slot).
##
## What changes the camp goes one way: the host's camp is the camp. A joining warden's
## jobs in a room go to the host (send_room_task) and the room comes back as the host has
## it (send_room_state); what the host builds, clears, upgrades and repairs is done again
## on every joining machine (send_fact). Where each warden is (a room and the job in it,
## the boat on the lake) rides on the states (warden_moved).
##
## The other wardens: others() (their peer ids), state_of / look_of / name_of /
## figure_of (id). Who sent what came in: sender (set while a request, a play, a sync is
## handled). From the days of two, partner_* is the first of the others (the lowest id),
## for whatever has not learnt to count past one yet.

signal session_started(role: int)
signal session_ended(reason: String)
## Someone came onto or went off the line (any of them; warden_joined / warden_left say who).
signal peer_joined
signal peer_left
signal warden_joined(id: int)
signal warden_left(id: int)
signal join_failed(reason: String)
signal world_arrived(snapshot: Dictionary)
## A state of another warden came in (main: the boat, the rooms).
signal partner_moved(state: Dictionary)
signal warden_moved(id: int, state: Dictionary)
## Another warden's look came in or changed.
signal partner_look_changed(look: Dictionary)

enum Role { NONE, HOST, CLIENT }

## The host and up to three more.
const MAX_WARDENS := 4
const DEFAULT_PORT := 24898
const WARDEN_HZ := 15.0
const CLOCK_HZ := 4.0
## The host's camp as it changes (guests, breakdowns, lamps, rooms): looked at this often,
## sent when it changed (and now and then anyway).
const PULSE_HZ := 1.0
const PULSE_RESEND := 5
## Over the shoulder: the PC's screen, sent this often while another warden can see it.
const SCREEN_HZ := 6.0
const CONNECT_TIMEOUT := 20.0
const CFG_PATH := "user://coop.cfg"
const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const PROFILES = preload("res://scripts/profiles.gd")
const NO_LOOK := {"m": 1, "c": 0, "n": ""}
const VOICE = preload("res://scripts/coop/voice.gd")
## The walkie-talkie and the megaphone (voice.gd).
var voice

var role := Role.NONE
var port := DEFAULT_PORT
## The address last joined (remembered between runs).
var last_address := ""
var _peer: ENetMultiplayerPeer
var _connect_left := -1.0
var _connected := false
var _warden_t := 0.0
var _clock_t := 0.0
var _screen_t := 0.0
var _sync_t := 0.0
var _pulse_t := 0.0
var _pulse_hash := 0
var _pulse_same := 0
## The other wardens: peer id -> {look: {m, c, n}, state: {}, fig: REMOTE_PLAYER}.
var wardens: Dictionary = {}
## Who sent what is being handled now (a request, a play, a sync); 0 outside them.
var sender := 0
## Your place on the line: 0 the host, 1..3 the joining ones in the order they came
## (the figure of a warden who chose none).
var my_slot := 0
## The host: who has which place.
var _slots: Dictionary = {}
## Hellos from wardens not on the host's roster yet (peer id -> their look).
var _early_looks: Dictionary = {}
## The host's last clock as it came in (a joining machine; harnesses compare it).
var last_clock: Dictionary = {}
## The look from before wardens had their own (coop.cfg), for a warden who never chose
## one; -1: the figure of their place on the line.
var look_model := -1
var look_color := 0
## A look set for this run only (the harnesses: the copies share one warden).
var _look_override := false

## The first of the other wardens (from the days of two): its look and its last state.
var partner_look: Dictionary:
	get:
		var id := _first()
		return (wardens[id]["look"] as Dictionary) if id != 0 else NO_LOOK
var partner_state: Dictionary:
	get:
		var id := _first()
		return (wardens[id]["state"] as Dictionary) if id != 0 else {}
## The first other warden's peer id (0 alone).
var remote_id: int:
	get:
		return _first()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cfg()
	voice = VOICE.new()
	voice.name = "Voice"
	add_child(voice)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_active() -> bool:
	return role != Role.NONE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


## The camp is simulated here: a single-player game or the host's.
func sim_here() -> bool:
	return role != Role.CLIENT


## Another warden is connected.
func has_partner() -> bool:
	return not wardens.is_empty()


## The other wardens' peer ids, lowest first (the host is 1).
func others() -> Array:
	var ids := wardens.keys()
	ids.sort()
	return ids


## How many wardens are in the camp, you with them.
func count() -> int:
	return 1 + wardens.size() if role != Role.NONE else 1


func _first() -> int:
	var best := 0
	for id in wardens.keys():
		if best == 0 or int(id) < best:
			best = int(id)
	return best


func state_of(id: int) -> Dictionary:
	return (wardens[id]["state"] as Dictionary) if wardens.has(id) else {}


func look_of(id: int) -> Dictionary:
	return (wardens[id]["look"] as Dictionary) if wardens.has(id) else NO_LOOK


## A warden's name (their warden's, from the WARDENS page; the figure's from a machine
## that sent none).
func name_of(id: int) -> String:
	var look := look_of(id)
	var n := str(look.get("n", ""))
	return n if n != "" else str(LOOKS.NAMES[posmod(int(look.get("m", 1)), LOOKS.count())])


## The first other warden's name (from the days of two).
func partner_name() -> String:
	return name_of(_first())


## The name of whoever sent what is being handled (a request, a play), else the first's.
func sender_name() -> String:
	return name_of(sender if wardens.has(sender) else _first())


## A warden's figure in the camp, or null.
func figure_of(id: int) -> Node3D:
	if not wardens.has(id):
		return null
	var f = wardens[id].get("fig")
	return f if f != null and is_instance_valid(f) else null


## The first other warden's figure (from the days of two).
func remote_figure() -> Node3D:
	return figure_of(_first())


## The other wardens whose state says `key` is `value` (in a room: "room"... see main).
func others_where(test: Callable) -> Array:
	var out: Array = []
	for id in others():
		if bool(test.call(state_of(id))):
			out.append(id)
	return out


## The other warden nearest to `pos` with a figure in the camp (0 none).
func nearest_other(pos: Vector3, max_dist := INF) -> int:
	var best := 0
	var best_d := max_dist
	for id in others():
		var f := figure_of(id)
		if f == null or not f.visible:
			continue
		var d := f.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = int(id)
	return best


# ── starting and ending ──────────────────────────────────────────────────────

## Opens the camp to up to three other machines on `port`. False when the port is taken.
func host() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	# One more line than there are places: a fifth is told the camp is full, not left
	# hanging (_on_peer_connected).
	if peer.create_server(port, MAX_WARDENS) != OK:
		return false
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	my_slot = 0
	print("Coop: hosting on port %d (up to %d wardens)" % [port, MAX_WARDENS])
	session_started.emit(role)
	return true


## Calls the camp at `address` ("100.64.1.2", "pc-name", "10.0.0.5:24898"). The answer
## is world_arrived (the camp) or join_failed.
func join(address: String) -> void:
	leave()
	var text := address.strip_edges()
	var addr := text
	var p := port
	if addr.count(":") == 1:
		p = int(addr.get_slice(":", 1))
		addr = addr.get_slice(":", 0)
	if addr.is_empty():
		join_failed.emit("No address.")
		return
	last_address = text
	_save_cfg()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(addr, p) != OK:
		print("Coop: cannot call %s:%d" % [addr, p])
		join_failed.emit("No answer.")
		return
	print("Coop: calling %s:%d" % [addr, p])
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	_connect_left = CONNECT_TIMEOUT


## Closes the line (back to the menu, or the host's camp goes on alone).
func leave() -> void:
	for id in wardens.keys():
		_drop_figure(int(id))
	wardens.clear()
	_slots.clear()
	_early_looks.clear()
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	my_slot = 0
	sender = 0
	_connected = false
	_connect_left = -1.0


## This machine's addresses the others can call: Tailscale's first, then the LAN's.
func local_addresses() -> Array[String]:
	var tail: Array[String] = []
	var lan: Array[String] = []
	for a in IP.get_local_addresses():
		var s := str(a)
		if not s.contains(".") or s.begins_with("127.") or s.begins_with("169.254."):
			continue
		if s.begins_with("100."):
			tail.append(s)
		elif s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			lan.append(s)
	var out: Array[String] = []
	out.append_array(tail)
	out.append_array(lan)
	return out


func _load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		last_address = str(cfg.get_value("coop", "last_address", ""))
		look_model = int(cfg.get_value("coop", "look_model", -1))
		look_color = int(cfg.get_value("coop", "look_color", 0))


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("coop", "last_address", last_address)
	cfg.save(CFG_PATH)


## You now: {m: figure, c: jacket colour, n: the warden's name}.
func my_look() -> Dictionary:
	var m := look_model
	var c := look_color
	var n := PROFILES.profile_name() if PROFILES.has_profile() else ""
	if not _look_override and PROFILES.has_profile():
		var own: Dictionary = PROFILES.profile_look()
		if int(own["m"]) >= 0:
			m = int(own["m"])
			c = int(own["c"])
	if m < 0:
		m = my_slot
	return {"m": posmod(m, LOOKS.count()), "c": posmod(c, LOOKS.color_count()), "n": n}


## A look for this run only, not the warden's (the harnesses), told to the others.
func set_my_look(model: int, color: int) -> void:
	look_model = posmod(model, LOOKS.count())
	look_color = posmod(color, LOOKS.color_count())
	_look_override = true
	announce_look()


## The warden's name or look changed (the WARDENS page): told to the others.
func announce_look() -> void:
	if not wardens.is_empty():
		_hello.rpc(my_look())


# ── the line ─────────────────────────────────────────────────────────────────

func _add_warden(id: int) -> void:
	if not wardens.has(id):
		wardens[id] = {"look": NO_LOOK.duplicate(), "state": {}, "fig": null}


func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		if wardens.size() >= MAX_WARDENS - 1:
			print("Coop: a fifth warden called (%d): the camp is full" % id)
			_full.rpc_id(id)
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				if _peer != null:
					_peer.disconnect_peer(id))
			return
		_add_warden(id)
		_patient(id)
		# The next free place on the line (the figure of one who chose none).
		var slot := 1
		while slot in _slots.values():
			slot += 1
		_slots[id] = slot
		_slot.rpc_id(id, slot)
		print("Coop: a warden is on the line (%d, place %d; %d in the camp)" % [id, slot, count()])
		_hello.rpc_id(id, my_look())
		warden_joined.emit(id)
		peer_joined.emit()
		_send_roster()
	elif role == Role.CLIENT and id == 1:
		_add_warden(1)
	# Another joining warden the host relays to us: they come in with the host's roster
	# (a fifth one turned away never does).


func _on_peer_disconnected(id: int) -> void:
	if not wardens.has(id):
		return
	_forget(id)
	if role == Role.HOST:
		_send_roster()


func _forget(id: int) -> void:
	print("Coop: %s hung up" % name_of(id))
	_drop_figure(id)
	# Told while they are still known (their name), then gone.
	warden_left.emit(id)
	wardens.erase(id)
	_slots.erase(id)
	peer_left.emit()


## The host: who is in the camp now (the joining machines' peer ids), for every one of them.
func _send_roster() -> void:
	if role == Role.HOST and not wardens.is_empty():
		_roster.rpc(others())


## A joining machine: the host's roster. Those new to it say who you are (and are
## told who they are); those gone from it are gone.
@rpc("authority", "call_remote", "reliable")
func _roster(ids: Array) -> void:
	if role != Role.CLIENT:
		return
	var me := multiplayer.get_unique_id()
	for id in ids:
		var i := int(id)
		if i == me or i == 1 or wardens.has(i):
			continue
		_add_warden(i)
		if _early_looks.has(i):
			wardens[i]["look"] = _early_looks[i]
			_early_looks.erase(i)
		_hello.rpc_id(i, my_look())
		warden_joined.emit(i)
		peer_joined.emit()
	for id in wardens.keys():
		if int(id) != 1 and not ids.has(id):
			_forget(int(id))


func _on_connected() -> void:
	print("Coop: connected, asking for the camp")
	_connect_left = -1.0
	_connected = true
	_add_warden(1)
	_patient(1)
	_hello.rpc_id(1, my_look())
	_request_world.rpc_id(1)
	# Wardens already in the camp come with the host's roster (_roster).


func _on_connection_failed() -> void:
	print("Coop: the call failed")
	leave()
	join_failed.emit("No answer.")


func _on_server_disconnected() -> void:
	print("Coop: the host's line went dead")
	leave()
	session_ended.emit("The line to the camp went dead.")


## Building a camp (a joining machine loads the whole camp at once) stops the line
## being answered for seconds: ENet's default would drop the warden by then. Up to a
## minute of silence is waited out.
func _patient(id: int) -> void:
	if _peer == null:
		return
	var pp: ENetPacketPeer = _peer.get_peer(id)
	if pp != null:
		pp.set_timeout(64, 30000, 60000)


func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


## The host: four wardens are in the camp already.
@rpc("authority", "call_remote", "reliable")
func _full() -> void:
	if role != Role.CLIENT:
		return
	leave()
	join_failed.emit("The camp is full: four wardens are in it.")


## The host tells a joining machine its place on the line.
@rpc("authority", "call_remote", "reliable")
func _slot(slot: int) -> void:
	my_slot = clampi(slot, 1, MAX_WARDENS - 1)
	announce_look()


# ── the camp, sent once ──────────────────────────────────────────────────────

## A joining machine asks for the camp: the host sends its save snapshot, packed.
@rpc("any_peer", "call_remote", "reliable")
func _request_world() -> void:
	if role != Role.HOST:
		return
	var who := multiplayer.get_remote_sender_id()
	var main := _main()
	if main == null or not main.has_method("coop_world_snapshot"):
		return
	var snap: Dictionary = main.coop_world_snapshot()
	var raw := JSON.stringify(snap).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	print("Coop: sending the camp (%d bytes, %d packed)" % [raw.size(), packed.size()])
	_receive_world.rpc_id(who, packed, raw.size())


@rpc("authority", "call_remote", "reliable")
func _receive_world(packed: PackedByteArray, size: int) -> void:
	if role != Role.CLIENT:
		return
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		leave()
		join_failed.emit("The camp came through garbled.")
		return
	print("Coop: the camp arrived (%d bytes)" % raw.size())
	world_arrived.emit(parsed as Dictionary)


# ── every frame: your warden out, the clock out (host) ───────────────────────


func _process(delta: float) -> void:
	if role == Role.NONE:
		return
	if _connect_left > 0.0:
		_connect_left -= delta
		if _connect_left <= 0.0 and not _connected:
			print("Coop: no answer in %.0f s" % CONNECT_TIMEOUT)
			leave()
			join_failed.emit("No answer.")
			return
	if wardens.is_empty():
		return
	var main := _main()
	if main == null or not main.has_method("coop_local_warden"):
		return
	_warden_t -= delta
	if _warden_t <= 0.0:
		_warden_t = 1.0 / WARDEN_HZ
		var s: Dictionary = main.coop_local_warden()
		if not s.is_empty():
			# The cigarette and the bottle in your hands (scripts/town/pockets.gd).
			var hands := get_tree().get_first_node_in_group("habits")
			if hands != null:
				var hb: Dictionary = hands.coop_state()
				if not hb.is_empty():
					s["hb"] = hb
					# What the other machine draws you doing (warden_looks: smoke, light,
					# drink, cigar, bottle); holding one while walking you walk.
					var pose: String = hands.coop_pose(float(s.get("v", 0.0)))
					if pose != "" and not s.has("act"):
						s["act"] = pose
			_warden.rpc(s)
	# What all have (the office's lights, the register): sent when it changed here.
	_sync_t -= delta
	if _sync_t <= 0.0 and main.has_method("coop_sync_poll"):
		_sync_t = 0.3
		main.coop_sync_poll()
	if role == Role.HOST:
		_clock_t -= delta
		if _clock_t <= 0.0:
			_clock_t = 1.0 / CLOCK_HZ
			_clock.rpc(main.coop_clock())
		_pulse_t -= delta
		if _pulse_t <= 0.0 and main.has_method("coop_camp_pulse"):
			_pulse_t = 1.0 / PULSE_HZ
			var raw: PackedByteArray = var_to_bytes(main.coop_camp_pulse())
			var h := hash(raw)
			_pulse_same += 1
			if h != _pulse_hash or _pulse_same >= PULSE_RESEND:
				_pulse_hash = h
				_pulse_same = 0
				_pulse.rpc(raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())
	# At the PC with another warden in the office: they see your screen over your
	# shoulder (a small picture of it, a few times a second).
	_screen_t -= delta
	if _screen_t <= 0.0 and main.has_method("coop_screen_frame"):
		_screen_t = 1.0 / SCREEN_HZ
		var frame: PackedByteArray = main.coop_screen_frame()
		if not frame.is_empty():
			_screen.rpc(frame)


## Another warden's state (everyone's to everyone).
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _warden(s: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	wardens[id]["state"] = s
	var r := _ensure_figure(id)
	if r != null:
		r.push_state(s)
	warden_moved.emit(id, s)
	partner_moved.emit(s)


## The night (scripts/coop/coop_night.gd): what the host's enemies (and callers) show,
## for the joining machines, and what they do to a warden (`to`: that warden's machine;
## 0 all of them).
func send_night_view(items: Array, to := 0) -> void:
	if role != Role.HOST or wardens.is_empty():
		return
	if to != 0:
		if wardens.has(to):
			_night_view.rpc_id(to, items)
	else:
		_night_view.rpc(items)


func send_night_event(kind: String, data: Array, to := 0) -> void:
	if role != Role.HOST or wardens.is_empty():
		return
	if to != 0:
		if wardens.has(to):
			_night_event.rpc_id(to, kind, data)
	else:
		_night_event.rpc(kind, data)


@rpc("authority", "call_remote", "unreliable_ordered", 5)
func _night_view(items: Array) -> void:
	var main := _main()
	var night = main.get("_coop_night") if main != null else null
	if night != null and role == Role.CLIENT:
		night.show_view(items)


@rpc("authority", "call_remote", "reliable")
func _night_event(kind: String, data: Array) -> void:
	var main := _main()
	var night = main.get("_coop_night") if main != null else null
	if night != null and role == Role.CLIENT:
		night.on_event(kind, data)


## The host's camp pulse (main.coop_camp_pulse), packed.
@rpc("authority", "call_remote", "reliable", 4)
func _pulse(packed: PackedByteArray, size: int) -> void:
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	var p = bytes_to_var(raw)
	var main := _main()
	if p is Dictionary and main != null and main.has_method("coop_apply_pulse"):
		main.coop_apply_pulse(p)


## A warden's PC screen (a JPEG), while you stand in the office with them at it.
@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _screen(frame: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var main := _main()
	if main != null and main.has_method("coop_show_screen"):
		sender = id
		main.coop_show_screen(frame)
		sender = 0


## Who a warden is and their jacket (when you meet, and when they change it).
@rpc("any_peer", "call_remote", "reliable")
func _hello(look: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	var l := {"m": posmod(int(look.get("m", 1)), LOOKS.count()), "c": posmod(int(look.get("c", 0)), LOOKS.color_count()), "n": str(look.get("n", "")).strip_edges().left(24)}
	if not wardens.has(id):
		# Not on the host's roster yet: kept for when they are (_roster).
		_early_looks[id] = l
		return
	wardens[id]["look"] = l
	var f := figure_of(id)
	if f != null:
		(f as REMOTE_PLAYER).set_look(int(l["m"]), int(l["c"]))
	partner_look_changed.emit(l)


# ── the camp's changes, one way ─────────────────────────────────────────────

## A joining warden's hands at the PC and elsewhere: what they ask the host's camp to
## do ("build" [type, origin, rotation], "demolish" [rect], "money" [amount], "mail"
## [what, mail id, ...]); the host does it (main.coop_request, `sender` says who) and the
## camp comes back.
func send_request(kind: String, data: Array) -> void:
	if role == Role.CLIENT and _connected:
		_request.rpc_id(1, kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _request(kind: String, data: Array) -> void:
	var main := _main()
	var id := multiplayer.get_remote_sender_id()
	if role == Role.HOST and wardens.has(id) and main != null and main.has_method("coop_request"):
		sender = id
		main.coop_request(kind, data)
		sender = 0


## A joining warden finished a job in a room: the host does it in the real camp.
func send_room_task(key: String, task_id: String) -> void:
	if role == Role.CLIENT and _connected:
		_room_task.rpc_id(1, key, task_id)


@rpc("any_peer", "call_remote", "reliable")
func _room_task(key: String, task_id: String) -> void:
	var main := _main()
	if role == Role.HOST and main != null and main.has_method("coop_room_task"):
		sender = multiplayer.get_remote_sender_id()
		main.coop_room_task(key, task_id)
		sender = 0


## The host's room as it now is (its accommodation state), for the joining machines.
func send_room_state(key: String, acc: Dictionary) -> void:
	if role == Role.HOST and not wardens.is_empty():
		_room_state.rpc(key, acc)


@rpc("authority", "call_remote", "reliable")
func _room_state(key: String, acc: Dictionary) -> void:
	var main := _main()
	if role == Role.CLIENT and main != null and main.has_method("coop_room_state"):
		main.coop_room_state(key, acc)


## Something the host did to the camp, to be done again on the joining machines:
## "build" [type, origin, rotation], "demolish" [rect], "upgrade" [origin, old, new],
## "service" [root].
func send_fact(kind: String, data: Array) -> void:
	if role == Role.HOST and not wardens.is_empty():
		_fact.rpc(kind, data)


@rpc("authority", "call_remote", "reliable")
func _fact(kind: String, data: Array) -> void:
	var main := _main()
	if role == Role.CLIENT and main != null and main.has_method("coop_apply_fact"):
		main.coop_apply_fact(kind, data)


## The camp's attractions for several (scripts/attractions/warden_play.gd), everyone's to
## everyone: the host's ball in flight, another's swing at it, a log on the fire.
func send_play(kind: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_play.rpc(kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _play(kind: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var wp := get_tree().get_first_node_in_group("warden_play")
	if wp != null:
		sender = id
		wp.coop_play(kind, data)
		sender = 0


## The cigarette and the bottle (scripts/habits/habit_world.gd), everyone's to everyone:
## a flick of the lighter, a breath of smoke, a gulp, a light given, bottles clinked, a
## butt thrown.
func send_habit(kind: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_habit.rpc(kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _habit(kind: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var hands := get_tree().get_first_node_in_group("habits")
	if hands != null:
		sender = id
		hands.coop_habit(kind, data)
		sender = 0


## The bags (scripts/ui/inventory.gd), everyone's to everyone: things thrown on the
## ground and who picks them up (the host decides), the shed key hung back on the board.
func send_inv(kind: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_inv.rpc(kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _inv(kind: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var inv := get_tree().get_first_node_in_group("inventory")
	if inv != null:
		sender = id
		inv.coop_inv(kind, data)
		sender = 0


## The bistros' kitchens (scripts/bistro/kitchen.gd), everyone's to everyone: a slice in
## the pan, the pot stirred, a tray filled, a plate out of the hatch.
func send_kitchen(key: String, op: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_kitchen.rpc(key, op, data)


@rpc("any_peer", "call_remote", "reliable")
func _kitchen(key: String, op: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var k := get_tree().get_first_node_in_group("kitchens")
	if k != null:
		sender = id
		k.coop_kitchen(key, op, data)
		sender = 0


## The pubs' bars (scripts/pub/taproom.gd), everyone's to everyone: a mug poured, a keg
## changed, the gas turned, a mug washed.
func send_taproom(key: String, op: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_taproom.rpc(key, op, data)


@rpc("any_peer", "call_remote", "reliable")
func _taproom(key: String, op: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var t := get_tree().get_first_node_in_group("taprooms")
	if t == null:
		t = load("res://scripts/pub/taproom.gd").of(get_tree())
	if t != null:
		sender = id
		t.coop_taproom(key, op, data)
		sender = 0


## Something every machine has that the others must have too, everyone's to everyone
## (main.coop_sync): "office" [the lights, curtains and set], "register" [the desk's
## register and key hooks], "gate" ["up" / "down"] (a warden worked the barrier).
## A packet of your voice (scripts/coop/voice.gd): `flags` say radio or megaphone, the
## first and the last of a go; `data` 20 ms of 16 kHz mu-law.
func send_voice(flags: int, data: PackedByteArray) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_voice.rpc(flags, data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 6)
func _voice(flags: int, data: PackedByteArray) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id) or voice == null:
		return
	voice.on_voice(id, flags, data)


func send_sync(kind: String, data: Array) -> void:
	if role != Role.NONE and not wardens.is_empty():
		_sync.rpc(kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _sync(kind: String, data: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not wardens.has(id):
		return
	var main := _main()
	if main != null and main.has_method("coop_sync"):
		sender = id
		main.coop_sync(kind, data)
		sender = 0


## The host's clock and weather, a few times a second.
@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _clock(c: Dictionary) -> void:
	last_clock = c
	var main := _main()
	if main != null and main.has_method("coop_apply_clock"):
		main.coop_apply_clock(c)


## A warden in this camp, made once the camp is there to stand in.
func _ensure_figure(id: int) -> REMOTE_PLAYER:
	var f := figure_of(id)
	if f != null:
		return f as REMOTE_PLAYER
	var main := _main()
	var root: Node3D = main.coop_world_root() if main != null and main.has_method("coop_world_root") else null
	if root == null:
		return null
	var r := REMOTE_PLAYER.new()
	var look := look_of(id)
	r.setup(int(look["m"]), int(look["c"]))
	r.set_meta("coop_id", id)
	root.add_child(r)
	wardens[id]["fig"] = r
	return r


func _drop_figure(id: int) -> void:
	var f := figure_of(id)
	if f != null:
		f.queue_free()
	if wardens.has(id):
		wardens[id]["fig"] = null


## Every other warden's figure in the camp.
func figures() -> Array:
	var out: Array = []
	for id in others():
		var f := figure_of(id)
		if f != null:
			out.append(f)
	return out
