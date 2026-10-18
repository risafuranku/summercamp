extends Node

## Two wardens, one camp: co-op for two, sandbox camps only (DESIGN.md §12, autoload
## "Coop"). The host runs the camp exactly as one player would; the other machine is a
## window onto it. When it joins it is sent the whole camp (the save snapshot,
## main.coop_world_snapshot()), then the clock and the weather, and each side streams
## its own warden (where they stand and look, the torch) to the other, who sees them
## walking about as scripts/coop/remote_player.gd. Nothing on the joining machine runs
## the camp (sim_here() is false there): no clock of its own, no guests or mail rolled,
## no nights. ENet, one guest, one port; over Tailscale or a LAN the address is the
## other machine's.
##
## Each warden has the look chosen on the CO-OP page (who, and the jacket's colour:
## scripts/coop/warden_looks.gd), told to the other when they meet (_hello).
##
## What changes the camp goes one way: the host's camp is the camp. The joining
## warden's jobs in a room go to the host (send_room_task) and the room comes back as
## the host has it (send_room_state); what the host builds, clears, upgrades and repairs
## is done again on the joining machine (send_fact). Where each warden is (a room and
## the job in it, the boat on the lake) rides on the states (partner_moved).

signal session_started(role: int)
signal session_ended(reason: String)
signal peer_joined
signal peer_left
signal join_failed(reason: String)
signal world_arrived(snapshot: Dictionary)
## A state of the other warden came in (main: the boat, the rooms).
signal partner_moved(state: Dictionary)
## The other warden's look came in or changed.
signal partner_look_changed(look: Dictionary)

enum Role { NONE, HOST, CLIENT }

const DEFAULT_PORT := 24898
const WARDEN_HZ := 15.0
const CLOCK_HZ := 4.0
## The host's camp as it changes (guests, breakdowns, lamps, rooms): looked at this often,
## sent when it changed (and now and then anyway).
const PULSE_HZ := 1.0
const PULSE_RESEND := 5
## Over the shoulder: the PC's screen, sent this often while the other warden can see it.
const SCREEN_HZ := 6.0
const CONNECT_TIMEOUT := 20.0
const CFG_PATH := "user://coop.cfg"
const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")

var role := Role.NONE
var port := DEFAULT_PORT
## The address last joined (remembered between runs).
var last_address := ""
## The other machine's peer id, 0 while you are alone.
var remote_id := 0
var _peer: ENetMultiplayerPeer
var _connect_left := -1.0
var _warden_t := 0.0
var _clock_t := 0.0
var _screen_t := 0.0
var _pulse_t := 0.0
var _pulse_hash := 0
var _pulse_same := 0
var _remote: REMOTE_PLAYER
## The host's last clock as it came in (the joining machine; harnesses compare it).
var last_clock: Dictionary = {}
## Your look (the CO-OP page; -1: the host's warden 0, the other's warden 1).
var look_model := -1
var look_color := 0
## The other warden's look, and their last state.
var partner_look: Dictionary = {"m": 1, "c": 0}
var partner_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cfg()
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


## The other warden is connected.
func has_partner() -> bool:
	return remote_id != 0


# ── starting and ending ──────────────────────────────────────────────────────

## Opens the camp to one other machine on `port`. False when the port is taken.
func host() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, 1) != OK:
		return false
	_peer = peer
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	print("Coop: hosting on port %d" % port)
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
	_drop_remote()
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.NONE
	remote_id = 0
	partner_state = {}
	_connect_left = -1.0


## This machine's addresses the other one can call: Tailscale's first, then the LAN's.
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
	cfg.set_value("coop", "look_model", look_model)
	cfg.set_value("coop", "look_color", look_color)
	cfg.save(CFG_PATH)


## Your look now: {m: warden, c: jacket colour}.
func my_look() -> Dictionary:
	var m := look_model if look_model >= 0 else (1 if role == Role.CLIENT else 0)
	return {"m": posmod(m, LOOKS.count()), "c": posmod(look_color, LOOKS.color_count())}


## The CO-OP page changed your look: kept, and told to the other warden if they are here.
func set_my_look(model: int, color: int) -> void:
	look_model = posmod(model, LOOKS.count())
	look_color = posmod(color, LOOKS.color_count())
	_save_cfg()
	if remote_id != 0:
		_hello.rpc_id(remote_id, my_look())


# ── the line ─────────────────────────────────────────────────────────────────

func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		if remote_id != 0 and remote_id != id:
			# One camp, two wardens: a third is turned away at the barrier.
			_peer.disconnect_peer(id)
			return
		remote_id = id
		_patient(id)
		print("Coop: the other warden is on the line (%d)" % id)
		_hello.rpc_id(id, my_look())
		peer_joined.emit()
	elif role == Role.CLIENT and id == 1:
		remote_id = 1


func _on_peer_disconnected(id: int) -> void:
	if id != remote_id:
		return
	print("Coop: the other warden hung up")
	remote_id = 0
	partner_state = {}
	_drop_remote()
	peer_left.emit()


func _on_connected() -> void:
	print("Coop: connected, asking for the camp")
	_connect_left = -1.0
	remote_id = 1
	_patient(1)
	_hello.rpc_id(1, my_look())
	_request_world.rpc_id(1)


func _on_connection_failed() -> void:
	print("Coop: the call failed")
	leave()
	join_failed.emit("No answer.")


func _on_server_disconnected() -> void:
	print("Coop: the host's line went dead")
	leave()
	session_ended.emit("The line to the camp went dead.")


## Building a camp (the joining machine loads the whole camp at once) stops the line
## being answered for seconds: ENet's default would drop the other warden by then.
## Up to a minute of silence is waited out.
func _patient(id: int) -> void:
	if _peer == null:
		return
	var pp: ENetPacketPeer = _peer.get_peer(id)
	if pp != null:
		pp.set_timeout(64, 30000, 60000)


func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


# ── the camp, sent once ──────────────────────────────────────────────────────

## The joining machine asks for the camp: the host sends its save snapshot, packed.
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
		if _connect_left <= 0.0 and remote_id == 0:
			print("Coop: no answer in %.0f s" % CONNECT_TIMEOUT)
			leave()
			join_failed.emit("No answer.")
			return
	if remote_id == 0:
		return
	var main := _main()
	if main == null or not main.has_method("coop_local_warden"):
		return
	_warden_t -= delta
	if _warden_t <= 0.0:
		_warden_t = 1.0 / WARDEN_HZ
		var s: Dictionary = main.coop_local_warden()
		if not s.is_empty():
			_warden.rpc_id(remote_id, s)
	if role == Role.HOST:
		_clock_t -= delta
		if _clock_t <= 0.0:
			_clock_t = 1.0 / CLOCK_HZ
			_clock.rpc_id(remote_id, main.coop_clock())
		_pulse_t -= delta
		if _pulse_t <= 0.0 and main.has_method("coop_camp_pulse"):
			_pulse_t = 1.0 / PULSE_HZ
			var raw: PackedByteArray = var_to_bytes(main.coop_camp_pulse())
			var h := hash(raw)
			_pulse_same += 1
			if h != _pulse_hash or _pulse_same >= PULSE_RESEND:
				_pulse_hash = h
				_pulse_same = 0
				_pulse.rpc_id(remote_id, raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size())
	# At the PC with the other warden in the office: they see your screen over your
	# shoulder (a small picture of it, a few times a second).
	_screen_t -= delta
	if _screen_t <= 0.0 and main.has_method("coop_screen_frame"):
		_screen_t = 1.0 / SCREEN_HZ
		var frame: PackedByteArray = main.coop_screen_frame()
		if not frame.is_empty():
			_screen.rpc_id(remote_id, frame)


## The other warden's state (both ways).
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _warden(s: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_id:
		return
	partner_state = s
	var r := _ensure_remote()
	if r != null:
		r.push_state(s)
	partner_moved.emit(s)


## The night (scripts/coop/coop_night.gd): what the host's enemies (and callers) show, for the other
## machine, and what they do to its warden.
func send_night_view(items: Array) -> void:
	if role == Role.HOST and remote_id != 0:
		_night_view.rpc_id(remote_id, items)


func send_night_event(kind: String, data: Array) -> void:
	if role == Role.HOST and remote_id != 0:
		_night_event.rpc_id(remote_id, kind, data)


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


## The other warden's PC screen (a JPEG), while you stand in the office with them at it.
@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _screen(frame: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != remote_id:
		return
	var main := _main()
	if main != null and main.has_method("coop_show_screen"):
		main.coop_show_screen(frame)


## Who the other warden is and their jacket (when you meet, and when they change it).
@rpc("any_peer", "call_remote", "reliable")
func _hello(look: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_id and remote_id != 0:
		return
	partner_look = {"m": posmod(int(look.get("m", 1)), LOOKS.count()), "c": posmod(int(look.get("c", 0)), LOOKS.color_count())}
	if _remote != null and is_instance_valid(_remote):
		_remote.set_look(int(partner_look["m"]), int(partner_look["c"]))
	partner_look_changed.emit(partner_look)


# ── the camp's changes, one way ─────────────────────────────────────────────

## The other warden's name (who they chose to be on the CO-OP page).
func partner_name() -> String:
	return str(LOOKS.NAMES[posmod(int(partner_look.get("m", 1)), LOOKS.count())])


## The joining warden's hands at the PC and elsewhere: what they ask the host's camp to
## do ("build" [type, origin, rotation], "demolish" [rect], "money" [amount], "mail"
## [what, mail id, ...]); the host does it (main.coop_request) and the camp comes back.
func send_request(kind: String, data: Array) -> void:
	if role == Role.CLIENT and remote_id != 0:
		_request.rpc_id(1, kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _request(kind: String, data: Array) -> void:
	var main := _main()
	if role == Role.HOST and multiplayer.get_remote_sender_id() == remote_id and main != null and main.has_method("coop_request"):
		main.coop_request(kind, data)


## The joining warden finished a job in a room: the host does it in the real camp.
func send_room_task(key: String, task_id: String) -> void:
	if role == Role.CLIENT and remote_id != 0:
		_room_task.rpc_id(1, key, task_id)


@rpc("any_peer", "call_remote", "reliable")
func _room_task(key: String, task_id: String) -> void:
	var main := _main()
	if role == Role.HOST and main != null and main.has_method("coop_room_task"):
		main.coop_room_task(key, task_id)


## The host's room as it now is (its accommodation state), for the joining machine.
func send_room_state(key: String, acc: Dictionary) -> void:
	if role == Role.HOST and remote_id != 0:
		_room_state.rpc_id(remote_id, key, acc)


@rpc("authority", "call_remote", "reliable")
func _room_state(key: String, acc: Dictionary) -> void:
	var main := _main()
	if role == Role.CLIENT and main != null and main.has_method("coop_room_state"):
		main.coop_room_state(key, acc)


## Something the host did to the camp, to be done again on the joining machine:
## "build" [type, origin, rotation], "demolish" [rect], "upgrade" [origin, old, new],
## "service" [root].
func send_fact(kind: String, data: Array) -> void:
	if role == Role.HOST and remote_id != 0:
		_fact.rpc_id(remote_id, kind, data)


@rpc("authority", "call_remote", "reliable")
func _fact(kind: String, data: Array) -> void:
	var main := _main()
	if role == Role.CLIENT and main != null and main.has_method("coop_apply_fact"):
		main.coop_apply_fact(kind, data)


## The camp's attractions for two (scripts/attractions/warden_play.gd), both ways: the
## host's ball in flight, the other's swing at it, a log on the fire.
func send_play(kind: String, data: Array) -> void:
	if role != Role.NONE and remote_id != 0:
		_play.rpc_id(remote_id, kind, data)


@rpc("any_peer", "call_remote", "reliable")
func _play(kind: String, data: Array) -> void:
	if multiplayer.get_remote_sender_id() != remote_id:
		return
	var wp := get_tree().get_first_node_in_group("warden_play")
	if wp != null:
		wp.coop_play(kind, data)


## The host's clock and weather, a few times a second.
@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _clock(c: Dictionary) -> void:
	last_clock = c
	var main := _main()
	if main != null and main.has_method("coop_apply_clock"):
		main.coop_apply_clock(c)


## The other warden in this camp, made once the camp is there to stand in.
func _ensure_remote() -> REMOTE_PLAYER:
	if _remote != null and is_instance_valid(_remote):
		return _remote
	var main := _main()
	var root: Node3D = main.coop_world_root() if main != null and main.has_method("coop_world_root") else null
	if root == null:
		return null
	_remote = REMOTE_PLAYER.new()
	_remote.setup(int(partner_look["m"]), int(partner_look["c"]))
	root.add_child(_remote)
	return _remote


func _drop_remote() -> void:
	if _remote != null and is_instance_valid(_remote):
		_remote.queue_free()
	_remote = null


## The other warden's figure in the camp, or null (harnesses, the sanity of later stages).
func remote_figure() -> Node3D:
	return _remote if _remote != null and is_instance_valid(_remote) else null
