extends Node

## The warden at the camp's attractions (the other scripts here: the campfire, the
## benches, the picnic table and the hammock, the playground, the slide, the nohejbal
## court, the ping-pong table). E by one and you are in it as its guests are, the
## attraction placing you as it places them (pose_member, with a warden's key), seen from
## your own eyes: sat by the fire, on the swing, up the ladder and down the chute, at the
## net. W, A, S or D gets you up again (not halfway down the slide).
##   by the fire    LMB holds a sausage out over the coals, LMB again when it is done
##                  eats it; Q the guitar; E a log on from the pile
##   the swing      LMB pumps it higher
##   the slide      LMB at the top pushes off
##   the court      LMB kicks the ball coming to you, in time (a volley, or after its
##   and the table  bounce); miss it and it rolls off and you fetch it
##
## Co-op: the other warden is in them too on this machine, placed by this machine's
## attraction with their key and the place they have on theirs (coop_state "att"); the
## ball games are the host's (each flight sent over, the other's swings sent to the
## host), the logs go on through the host (Coop.send_play).

const POSES = preload("res://scripts/attractions/poses.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const HOST_KEY := -11
const OTHER_KEY := -12
const SFX_GUITAR := "res://assets/sfx/life/guitar_fire.mp3"
const EAT_TIME := 2.4
const EAT_HEAL := 10
## Eyes above where the attraction puts you, by pose.
const EYE := {"stand": 1.55, "kick": 1.5, "bat": 1.42, "climb": 1.5, "sit": 1.12, "guitar": 1.12, "eat": 1.12, "swing": 1.16}

var main: Node

var _att: Node3D
var _key := HOST_KEY
var _member: Node3D
var _sprite: Sprite3D
var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _look := Vector3.ZERO
var _act := ""
var _act_t := 0.0
var _clock := 0.0
var _hp := -1
var _pose := "stand"
var _guitar: AudioStreamPlayer3D

var _mate_att: Node3D
var _mate_key := OTHER_KEY
var _mate_member: Node3D
var _mate_sprite: Sprite3D
var _mate_place: Dictionary = {}
var _mate_guitar: AudioStreamPlayer3D


func setup(main_node: Node) -> void:
	main = main_node
	add_to_group("warden_play")


func is_active() -> bool:
	return _att != null


static func local_key() -> int:
	return OTHER_KEY if Coop.is_client() else HOST_KEY


# ── getting in and out ───────────────────────────────────────────────────────

func _player() -> Node3D:
	return main.get("_player") as Node3D if main != null else null


## The nearest attraction offering itself where you stand: {att, verb, act, d}.
func _offer() -> Dictionary:
	var p := _player()
	if p == null or not is_instance_valid(p):
		return {}
	var best: Dictionary = {}
	for att in get_tree().get_nodes_in_group("attraction"):
		if not (att is Node3D) or not att.has_method("warden_offer") or not (att as Node3D).is_visible_in_tree():
			continue
		var o: Dictionary = att.warden_offer(p.global_position)
		if not o.is_empty() and (best.is_empty() or float(o["d"]) < float(best["d"])):
			best = o
			best["att"] = att
	return best


func hint() -> String:
	if is_active():
		return str(_att.warden_hint(_key)) if _att.has_method("warden_hint") else ""
	var o := _offer()
	return "" if o.is_empty() else "[E] %s" % str(o["verb"])


## E: into the attraction at hand (or a log on the fire); true when it was for us.
func try_interact() -> bool:
	if is_active():
		if _att.has_method("add_log"):
			_put_log(_att)
		return true
	var o := _offer()
	if o.is_empty():
		return false
	if str(o["act"]) == "log":
		_put_log(o["att"])
	else:
		_join(o["att"])
	return true


func _join(att: Node3D) -> void:
	var p := _player()
	_key = local_key()
	if p == null or not att.warden_join(_key, p.global_position):
		_say("No room.")
		return
	_att = att
	if _member == null:
		var made := _proxy()
		_member = made[0]
		_sprite = made[1]
	_sprite.set_meta("base_path", _base_path(Coop.my_look()))
	_act = ""
	_yaw = 0.0
	_pitch = 0.0
	_hp = int(main.get("_player_health"))
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "WardenPlayCam"
		_cam.fov = 56.0
		_cam.near = 0.05
		_cam.far = 1000.0
		_world().add_child(_cam)
	_place()
	_look = _att.warden_focus(_key)
	_aim_cam(1.0)
	_cam.current = true
	if p.has_method("set_controls_enabled"):
		p.set_controls_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func leave() -> void:
	if _att == null:
		return
	var p := _player()
	var out: Vector3 = _att.warden_exit(_key) if is_instance_valid(_att) and _att.has_method("warden_exit") else Vector3.INF
	if is_instance_valid(_att):
		_att.warden_leave(_key)
	_att = null
	_act = ""
	_set_loop(_guitar, false, Vector3.ZERO)
	if _cam != null:
		_cam.current = false
	if p != null and is_instance_valid(p):
		if out != Vector3.INF:
			p.global_position = out + Vector3(0.0, 0.05, 0.0)
		# Facing the way you looked.
		if _cam != null:
			var f := -_cam.global_basis.z
			if Vector2(f.x, f.z).length() > 0.01:
				p.rotation.y = atan2(-f.x, -f.z)
		if main.has_method("_sync_active_camera"):
			main._sync_active_camera()


func _world() -> Node:
	var w = main.get("_world_3d") if main != null else null
	return w if w != null else main


## A stand-in for an attraction to place: a node, its (hidden) sprite and a shadow the
## attraction may hide.
func _proxy() -> Array:
	var m := Node3D.new()
	m.name = "WardenSeat"
	var s := Sprite3D.new()
	s.name = "Sprite"
	s.visible = false
	m.add_child(s)
	var sh := Node3D.new()
	sh.name = "BlobShadow"
	m.add_child(sh)
	_world().add_child(m)
	return [m, s]


static func _base_path(look: Dictionary) -> String:
	return LOOKS.DIR + "warden_%s.png" % LOOKS.LETTERS[posmod(int(look.get("m", 0)), LOOKS.count())]


func _info(sprite: Sprite3D) -> Dictionary:
	var base := str(sprite.get_meta("base_path", LOOKS.DIR + "warden_a.png"))
	if sprite.texture == null and ResourceLoader.exists(base):
		sprite.texture = load(base)
	return {"archetype": "warden", "sprite_path": base}


## The pose the attraction gave a stand-in (its sprite's picture: warden_a_sit.png ->
## "sit"), then what the warden does on top (the attraction's: a kick, the bat, the
## swing's chains; or their own: the guitar, a bite).
static func _pose_of(att: Node, key: int, sprite: Sprite3D, act: String) -> String:
	var path := str(sprite.get_meta("pose_path", ""))
	var file := path.get_file().get_basename()
	var cut := file.find("_")
	var base := "stand"
	if cut > 0:
		var rest := file.substr(cut + 1)
		cut = rest.find("_")
		base = rest.substr(cut + 1) if cut >= 0 else "stand"
	if not EYE.has(base):
		base = "sit" if base in ["drink", "eat"] else "stand"
	if act != "":
		return act
	return str(att.warden_pose(key, base)) if att.has_method("warden_pose") else base


# ── in it ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_clock += delta
	if _att != null:
		_tick_local(delta)
	_update_mate()


func _tick_local(delta: float) -> void:
	if not is_instance_valid(_att) or bool(main._is_any_interior_open()):
		leave()
		return
	# Hurt (the night): up on your feet.
	var hp := int(main.get("_player_health"))
	if hp < _hp:
		_hp = hp
		leave()
		return
	_hp = hp
	if not _place():
		leave()
		return
	if _att.has_method("warden_done") and _att.warden_done(_key):
		leave()
		return
	if _act == "eat":
		_act_t -= delta
		if _act_t <= 0.0:
			_act = ""
	_aim_cam(clampf(delta * 5.0, 0.0, 1.0))
	_set_loop(_guitar, _pose == "guitar", _member.global_position + Vector3(0.0, 0.8, 0.0))


## The attraction puts you where you are in it now; false when it has no place for you.
func _place() -> bool:
	if not _att.pose_member(0, _key, 1, _member, _sprite, _info(_sprite), _clock):
		return false
	_pose = _pose_of(_att, _key, _sprite, _act)
	return true


func _aim_cam(k: float) -> void:
	if _cam == null:
		return
	var eye := _member.global_position + _sprite.position + Vector3(0.0, float(EYE.get(_pose, 1.5)), 0.0)
	_look = _look.lerp(_att.warden_focus(_key), k)
	var to := _look - eye
	if to.length() < 0.05:
		to = -_cam.global_basis.z
	var base := Basis.looking_at(to.normalized(), Vector3.UP)
	base = Basis(Vector3.UP, _yaw) * base
	base = base * Basis(Vector3.RIGHT, _pitch)
	_cam.global_transform = Transform3D(base, eye)


func _unhandled_input(event: InputEvent) -> void:
	if _att == null:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens := GameSettings.get_mouse_sensitivity() if GameSettings != null else 1.0
		_yaw = clampf(_yaw - event.relative.x * 0.0024 * sens, -1.9, 1.9)
		_pitch = clampf(_pitch - event.relative.y * 0.002 * sens, -0.7, 0.7)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				if _att.has_method("add_log") and _pose in ["sit", "guitar"]:
					_act = "" if _act == "guitar" else "guitar"
				get_viewport().set_input_as_handled()
			KEY_W, KEY_A, KEY_S, KEY_D:
				if not (_att.has_method("warden_hold") and _att.warden_hold(_key)):
					leave()
				get_viewport().set_input_as_handled()


## LMB: what your hands do in the attraction (the host's ball games: their swing goes
## to the host).
func _press() -> void:
	if Coop.is_client() and _att.has_method("coop_follows") and _att.coop_follows():
		Coop.send_play("press", [att_id(_att), _key])
		_att.warden_press(_key)
		return
	var did := str(_att.warden_press(_key))
	if did == "eat":
		_act = "eat"
		_act_t = EAT_TIME
		var hp := int(main.get("_player_health"))
		if main.has_method("_set_player_health") and hp > 0:
			main._set_player_health(hp + EAT_HEAL, false)
			_hp = int(main.get("_player_health"))


# ── the fire's logs ──────────────────────────────────────────────────────────

func _put_log(att: Node) -> void:
	if int(att.get("logs_left")) <= 0:
		_say("The woodpile is empty.")
		return
	if Coop.is_client():
		Coop.send_play("log", [att_id(att)])
		return
	if att.add_log() and Coop.has_partner():
		Coop.send_play("log", [att_id(att)])


# ── co-op ────────────────────────────────────────────────────────────────────

## Which attraction (its building's grid origin, the same on both machines).
static func att_id(att: Node) -> String:
	var r: Node = att
	while r != null and not r.has_meta("grid_origin"):
		r = r.get_parent()
	if r == null:
		return ""
	var o: Vector2i = r.get_meta("grid_origin")
	return "%d,%d" % [o.x, o.y]


func find_att(id: String) -> Node3D:
	if id == "":
		return null
	for att in get_tree().get_nodes_in_group("attraction"):
		if att is Node3D and att.has_method("warden_offer") and att_id(att) == id:
			return att
	return null


## Where you are in an attraction, for the other machine ({} when in none).
func coop_state() -> Dictionary:
	if _att == null or not is_instance_valid(_att):
		return {}
	var x: Dictionary = _att.warden_extra(_key) if _att.has_method("warden_extra") else {}
	return {"id": att_id(_att), "k": _key, "sl": int(_att.warden_slot(_key)), "ps": _act, "x": x}


## From the other machine (Coop._play): "shot" [id, flight, roster] the host's ball;
## "press" [id, key] the other's swing at it (host); "log" [id] a log on the fire (the
## host puts it on and says so; the other puts it on when told).
func coop_play(kind: String, data: Array) -> void:
	var att := find_att(str(data[0])) if not data.is_empty() else null
	if att == null:
		return
	match kind:
		"shot":
			if Coop.is_client() and att.has_method("coop_take_shot"):
				att.coop_take_shot(data[1], data[2])
		"press":
			if Coop.is_host():
				att.warden_press(int(data[1]))
		"log":
			if Coop.is_host():
				if att.add_log():
					Coop.send_play("log", [att_id(att)])
			else:
				att.add_log()


## The host's ball games: each new flight goes to the other machine.
func shot_out(att: Node, shot: Dictionary, roster: Dictionary) -> void:
	if Coop.is_host() and Coop.has_partner():
		Coop.send_play("shot", [att_id(att), shot, roster])


## The other warden in an attraction on this machine: placed by it with their key and
## place, their figure drawn there (remote_player.gd asks mate_place()).
func _update_mate() -> void:
	var s = Coop.partner_state.get("att") if Coop.has_partner() else null
	var st: Dictionary = s if s is Dictionary else {}
	var att := find_att(str(st.get("id", ""))) if not st.is_empty() else null
	if att != _mate_att and _mate_att != null and is_instance_valid(_mate_att):
		_mate_att.warden_leave(_mate_key)
	_mate_att = att
	if att == null:
		_mate_place = {}
		_set_loop(_mate_guitar, false, Vector3.ZERO)
		return
	_mate_key = int(st.get("k", OTHER_KEY))
	if _mate_member == null:
		var made := _proxy()
		_mate_member = made[0]
		_mate_sprite = made[1]
	_mate_sprite.set_meta("base_path", _base_path(Coop.partner_look))
	var x = st.get("x", {})
	att.warden_force(_mate_key, int(st.get("sl", -1)), x if x is Dictionary else {})
	if not att.pose_member(0, _mate_key, 1, _mate_member, _mate_sprite, _info(_mate_sprite), _clock):
		_mate_place = {}
		return
	var pose := _pose_of(att, _mate_key, _mate_sprite, str(st.get("ps", "")))
	var sh := _mate_member.get_node("BlobShadow") as Node3D
	_mate_place = {"pos": _mate_member.global_position + _mate_sprite.position, "pose": pose,
		"flip": _mate_sprite.flip_h, "rz": _mate_sprite.rotation.z, "ground": sh.visible}
	_set_loop(_mate_guitar if _mate_guitar != null else _new_loop("mate"), pose == "guitar", _mate_member.global_position + Vector3(0.0, 0.8, 0.0))


## Where to draw the other warden while they are in an attraction ({} when not).
func mate_place() -> Dictionary:
	return _mate_place


# ── sounds, words ────────────────────────────────────────────────────────────

func _new_loop(who: String) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.name = "Guitar_" + who
	a.unit_size = 4.0
	a.max_distance = 30.0
	a.volume_db = -6.0
	if ResourceLoader.exists(SFX_GUITAR):
		a.stream = load(SFX_GUITAR)
		if a.stream is AudioStreamMP3:
			(a.stream as AudioStreamMP3).loop = true
	_world().add_child(a)
	if who == "mate":
		_mate_guitar = a
	else:
		_guitar = a
	return a


func _set_loop(a: AudioStreamPlayer3D, on: bool, at: Vector3) -> void:
	if a == null:
		if not on:
			return
		a = _new_loop("own")
	if on:
		a.global_position = at
		if not a.playing:
			a.play()
	elif a.playing:
		a.stop()


func _say(text: String) -> void:
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("push_status"):
		hud.push_status(text, 0)


## Shot driver: each attraction, where it is and what it offers where you stand.
func debug_list() -> Array:
	var out: Array = []
	var p := _player()
	for att in get_tree().get_nodes_in_group("attraction"):
		if att is Node3D and att.has_method("warden_offer"):
			out.append([att_id(att), (att as Node3D).get_script().resource_path.get_file(), (att as Node3D).global_position.snapped(Vector3.ONE * 0.1),
				att.warden_offer(p.global_position) if p != null else {}, p.global_position.snapped(Vector3.ONE * 0.1) if p != null else Vector3.ZERO])
	return out
