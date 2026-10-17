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
## Stage 1 of the co-op plan (TODO.md): the camp, the two of you, the clock, the
## weather. What the other one does to the camp follows in the next stages.

signal session_started(role: int)
signal session_ended(reason: String)
signal peer_joined
signal peer_left
signal join_failed(reason: String)
signal world_arrived(snapshot: Dictionary)

enum Role { NONE, HOST, CLIENT }

const DEFAULT_PORT := 24898
const WARDEN_HZ := 15.0
const CLOCK_HZ := 4.0
const CONNECT_TIMEOUT := 20.0
const CFG_PATH := "user://coop.cfg"
## Who looks like whom: the host wears the green windbreaker, the other the red anorak.
const LOOK_HOST := "res://assets/textury/npc/warden_a.png"
const LOOK_GUEST := "res://assets/textury/npc/warden_b.png"
const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")

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
var _remote: REMOTE_PLAYER
## The host's last clock as it came in (the joining machine; harnesses compare it).
var last_clock: Dictionary = {}


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


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("coop", "last_address", last_address)
	cfg.save(CFG_PATH)


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
		peer_joined.emit()
	elif role == Role.CLIENT and id == 1:
		remote_id = 1


func _on_peer_disconnected(id: int) -> void:
	if id != remote_id:
		return
	print("Coop: the other warden hung up")
	remote_id = 0
	_drop_remote()
	peer_left.emit()


func _on_connected() -> void:
	print("Coop: connected, asking for the camp")
	_connect_left = -1.0
	remote_id = 1
	_patient(1)
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


## The other warden's state (both ways).
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _warden(s: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != remote_id:
		return
	var r := _ensure_remote()
	if r != null:
		r.push_state(s)


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
	_remote.setup(LOOK_GUEST if role == Role.HOST else LOOK_HOST)
	root.add_child(_remote)
	return _remote


func _drop_remote() -> void:
	if _remote != null and is_instance_valid(_remote):
		_remote.queue_free()
	_remote = null


## The other warden's figure in the camp, or null (harnesses, the sanity of later stages).
func remote_figure() -> Node3D:
	return _remote if _remote != null and is_instance_valid(_remote) else null
