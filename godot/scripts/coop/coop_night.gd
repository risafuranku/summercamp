extends Node

## The night for two (scripts/coop/coop.gd; DESIGN.md §12). The night's enemies live on
## the host's machine, as alone; here they hunt either warden:
##   - the other warden has a stand-in body in the host's world (where they stand, where
##     they look and shine their torch: their warden state), so an enemy brain can take
##     it for "the player" (enemy_base.gd reads the player, its head camera and torch);
##   - each enemy hunts one warden at a time: whoever is out, and the one alone in the
##     dark sooner than the one by the lamps; it lets go of one gone indoors for one out;
##   - what it does to the warden it hunts (a hit, a line in the feed) goes to that one;
##   - what the enemies are (their sprites, lights and sounds) is shown on the other
##     machine as it is on the host's, ten times a second;
##   - now and then one is only for the warden it hunts: the other does not see or hear
##     it at all ("didn't you see that?");
##   - behind it a sanity per warden, kept on the host's machine and never shown or named:
##     hits, an enemy in front of you, the dark alone wear it down; the day, the other
##     warden near and sleep give it back. The lower, the sooner the night picks you, the
##     likelier what you see is only yours, and the likelier you see the other warden
##     where they are not.
## Main owns one of these on either machine (main._coop_night).

const RETARGET_EVERY := 6.0
const VIEW_HZ := 10.0
const EYE := Vector3(0.0, 1.62, 0.0)
var main: Node
var _proxy: CharacterBody3D
var _proxy_cam: Camera3D
var _targets: Dictionary = {}        # brain instance id -> "host" | "other"
var _retarget_t := 0.0
var _view_t := 0.0
## The other machine: the enemies as the host's shows them, by node key.
var _mirror_root: Node3D
var _mirror: Dictionary = {}
var _mirror_left := 0.0
## The hidden sanity, 0..100 (the host's machine keeps both; the other gets its own in
## the host's clock, coop_clock "sn", as "own").
var sanity := {"host": 100.0, "other": 100.0}
var _private: Dictionary = {}       # brain instance id -> true: only its quarry sees it
var _wear_t := 0.0
var _last_hp := -1
var _phantom: Node3D
var _phantom_left := 0.0
var _phantom_wait := 60.0


func _process(delta: float) -> void:
	if main == null or not Coop.has_partner():
		_drop_proxy()
		clear_mirror()
		return
	_phantom_tick(delta)
	if Coop.is_host():
		_host_tick(delta)
	elif _mirror_left > 0.0:
		_mirror_left -= delta
		if _mirror_left <= 0.0:
			clear_mirror()


# ── the host ──────────────────────────────────────────────────────────────────

func _host_tick(delta: float) -> void:
	_wear(delta)
	# Their stand-in is always about (a lost guest may follow it, an enemy hunt it).
	_ensure_proxy()
	_place_proxy()
	var brains: Array = main.get("_enemy_brains")
	if brains.is_empty():
		_targets.clear()
		_private.clear()
	else:
		_hunt(delta, brains)
	_view_t -= delta
	if _view_t <= 0.0:
		_view_t = 1.0 / VIEW_HZ
		var items := _snapshot(brains)
		# Callers by day too (the electrician): whatever stands in the "coop_mirror" group.
		for root in get_tree().get_nodes_in_group(MIRROR_GROUP):
			if root is Node3D and (root as Node3D).is_inside_tree():
				_snapshot_root(root, "g%d" % root.get_instance_id(), items, true)
		if not items.is_empty() or _sent_any:
			Coop.send_night_view(items)
		_sent_any = not items.is_empty()


## Shown on the other machine as on this one, besides the enemies (scripts/reception/
## electrician_visit.gd puts its man in it).
const MIRROR_GROUP := "coop_mirror"
var _sent_any := false


func _hunt(delta: float, brains: Array) -> void:
	_retarget_t -= delta
	for b in brains:
		if b != null and not _targets.has(b.get_instance_id()):
			var who := _pick_target(b)
			_aim(b, who)
			# The lower the quarry's sanity, the likelier this one is only theirs.
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(b.get_instance_id()) ^ 77
			_private[b.get_instance_id()] = rng.randf() < 0.12 + (100.0 - float(sanity[who])) / 100.0 * 0.38
	_hide_private(brains)
	if _retarget_t <= 0.0:
		_retarget_t = RETARGET_EVERY
		for b in brains:
			if b == null:
				continue
			var now := str(_targets.get(b.get_instance_id(), "host"))
			if not _is_out(now) and _is_out(_other_of(now)):
				_aim(b, _other_of(now))


static func _other_of(who: String) -> String:
	return "other" if who == "host" else "host"


## Out where the night can reach: not in a room, in the boat or in town.
func _is_out(who: String) -> bool:
	if who == "host":
		return bool(main._can_enemy_runtime_actions())
	var s: Dictionary = Coop.partner_state
	return not s.is_empty() and not bool(s.get("in", false)) and not s.has("boat") and bool(main._is_enemy_night_active())


func _dark_at(who: String) -> float:
	var bm = main.get("building_manager")
	var p: Vector3 = (main.get("_player") as Node3D).global_position if who == "host" else _partner_pos()
	if bm == null or not bm.has_method("get_light_level_at"):
		return 1.0
	return 1.0 - clampf(float(bm.get_light_level_at(p)), 0.0, 1.0)


## Whom a new enemy goes for: one out, the one in the dark sooner (the dice decide
## between two alike).
func _pick_target(brain) -> String:
	var host_out := _is_out("host")
	var other_out := _is_out("other")
	if host_out != other_out:
		return "host" if host_out else "other"
	var w_host := 0.4 + _dark_at("host") + (100.0 - float(sanity["host"])) / 100.0
	var w_other := 0.4 + _dark_at("other") + (100.0 - float(sanity["other"])) / 100.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(brain.get_instance_id())
	return "host" if rng.randf() * (w_host + w_other) < w_host else "other"


## The brain hunts `who` from now on: their body, their hits, their feed.
func _aim(brain, who: String) -> void:
	_targets[brain.get_instance_id()] = who
	if who == "other" and _proxy != null:
		brain.set("_player", _proxy)
		brain.set("_damage_callable", Callable(self, "_hurt_other"))
		brain.set("_allow_actions_callable", Callable(self, "_other_reachable"))
		brain.set("_notify_callable", Callable(self, "_feed_other"))
	else:
		brain.set("_player", main.get("_player"))
		brain.set("_damage_callable", Callable(main, "damage_player"))
		brain.set("_allow_actions_callable", Callable(main, "_can_enemy_runtime_actions"))
		brain.set("_notify_callable", Callable(main, "_on_enemy_notice"))


func _other_reachable() -> bool:
	return _is_out("other")


func _hurt_other(amount: int) -> void:
	_shaken("other", amount * 0.6)
	Coop.send_night_event("hurt", [amount])


func _feed_other(text: String) -> void:
	Coop.send_night_event("feed", [text])


## Whether an enemy is only for the warden it hunts (the night decides; the check sets it).
func set_private(brain, on: bool) -> void:
	_private[brain.get_instance_id()] = on


## Who each enemy hunts now (for tools/coop_check.gd).
func targets() -> Array:
	var out: Array = []
	for b in main.get("_enemy_brains"):
		if b != null:
			out.append("%s:%s" % [str(b.get_enemy_id()), str(_targets.get(b.get_instance_id(), "?"))])
	return out


func _partner_pos() -> Vector3:
	return Coop.partner_state.get("p", Vector3.ZERO)


func _ensure_proxy() -> void:
	if _proxy != null and is_instance_valid(_proxy):
		return
	var world: Node3D = main.get("_world_3d")
	if world == null:
		return
	_proxy = PROXY_SCRIPT.new()
	_proxy.name = "OtherWardenProxy"
	# A body for the enemies' rays to leave out (get_rid); it touches nothing.
	_proxy.collision_layer = 0
	_proxy.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0.0, 0.85, 0.0)
	_proxy.add_child(shape)
	var head := Node3D.new()
	head.name = "Head"
	head.position = EYE
	_proxy.add_child(head)
	_proxy_cam = Camera3D.new()
	_proxy_cam.name = "Camera3D"
	_proxy_cam.current = false
	_proxy_cam.fov = 75.0
	head.add_child(_proxy_cam)
	world.add_child(_proxy)


func _place_proxy() -> void:
	if _proxy == null:
		return
	var s: Dictionary = Coop.partner_state
	var p: Vector3 = s.get("p", _proxy.global_position)
	var d: Vector3 = s.get("d", Vector3.FORWARD)
	# How they move (the basket woman listens for steps).
	var dt := get_process_delta_time()
	if dt > 0.0:
		_proxy.velocity = (p - _proxy.global_position) / dt if p.distance_to(_proxy.global_position) < 3.0 else Vector3.ZERO
	_proxy.global_position = p
	_proxy.rotation.y = float(s.get("y", 0.0))
	if d.length() > 0.01 and _proxy_cam != null:
		var eye := p + EYE
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		_proxy_cam.global_transform = Transform3D(Basis.looking_at(d.normalized(), up), eye)


func _drop_proxy() -> void:
	if _proxy != null and is_instance_valid(_proxy):
		_proxy.queue_free()
	_proxy = null
	_proxy_cam = null
	_targets.clear()


const PROXY_SCRIPT = preload("res://scripts/coop/coop_proxy.gd")


## A private enemy hunting the other warden: on this machine it is neither seen nor
## heard (its root hidden, its sounds silent; what they were is kept for the picture
## sent over: "coop_db").
func _hide_private(brains: Array) -> void:
	for b in brains:
		if b == null:
			continue
		var root = b.get("_root")
		if root == null or not is_instance_valid(root):
			continue
		var theirs_alone := bool(_private.get(b.get_instance_id(), false)) and str(_targets.get(b.get_instance_id(), "")) == "other"
		(root as Node3D).visible = not theirs_alone
		for n in (root as Node).find_children("*", "AudioStreamPlayer3D", true, false):
			var a := n as AudioStreamPlayer3D
			if theirs_alone:
				if a.volume_db > -79.0:
					a.set_meta("coop_db", a.volume_db)
					a.volume_db = -80.0
			elif a.has_meta("coop_db"):
				a.volume_db = float(a.get_meta("coop_db"))
				a.remove_meta("coop_db")


## Shown under `root`, leaving out the root itself (hidden for a private one); the root
## itself, as it is shown.
static func _shown_below(n: Node, root: Node) -> bool:
	if n == root:
		return (n as Node3D).is_visible_in_tree()
	var at := n
	while at != null and at != root:
		if at is Node3D and not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return true


## What the enemies show: every sprite, light and sound under each enemy's root (not
## the ones only the host, hunted by them, sees).
func _snapshot(brains: Array) -> Array:
	var out: Array = []
	for b in brains:
		if b == null:
			continue
		if bool(_private.get(b.get_instance_id(), false)) and str(_targets.get(b.get_instance_id(), "")) == "host":
			continue
		var root = b.get("_root")
		if root == null or not is_instance_valid(root):
			continue
		_snapshot_root(root, str(b.get_instance_id()), out)
	return out


## Every sprite, light and playing sound under `root` (and the root itself when
## `with_root`: a lone sprite in the mirror group), keyed `prefix/path`, into `out`.
func _snapshot_root(root: Node, prefix: String, out: Array, with_root := false) -> void:
	var nodes: Array = root.find_children("*", "", true, false)
	if with_root:
		nodes.push_front(root)
	for n in nodes:
		var key := prefix + "/" + str(root.get_path_to(n))
		if n is Sprite3D:
			var sp := n as Sprite3D
			if sp.texture == null or sp.texture.resource_path == "":
				continue
			out.append({"k": key, "t": "s", "tex": sp.texture.resource_path, "xf": sp.global_transform, "v": _shown_below(sp, root),
				"px": sp.pixel_size, "off": sp.offset, "fh": sp.flip_h, "mod": sp.modulate, "sh": sp.shaded, "bb": int(sp.billboard),
				"tag": str(sp.get_meta("coop_tag", ""))})
		elif n is AudioStreamPlayer3D:
			var a := n as AudioStreamPlayer3D
			if a.stream == null or a.stream.resource_path == "" or not a.playing:
				continue
			out.append({"k": key, "t": "a", "st": a.stream.resource_path, "pos": a.global_position, "db": float(a.get_meta("coop_db", a.volume_db)), "pt": a.pitch_scale,
				"md": a.max_distance, "us": a.unit_size, "at": a.get_playback_position()})
		elif n is Light3D:
			var l := n as Light3D
			out.append({"k": key, "t": "l", "spot": n is SpotLight3D, "xf": l.global_transform, "v": _shown_below(l, root), "c": l.light_color,
				"e": l.light_energy, "r": (l as SpotLight3D).spot_range if n is SpotLight3D else (l as OmniLight3D).omni_range,
				"ang": (l as SpotLight3D).spot_angle if n is SpotLight3D else 0.0})


# ── the hidden sanity ─────────────────────────────────────────────────────────

func _shaken(who: String, amount: float) -> void:
	sanity[who] = clampf(float(sanity[who]) - amount, 0.0, 100.0)


## Each second: what wears either warden down or brings them back.
func _wear(delta: float) -> void:
	_wear_t -= delta
	if _wear_t > 0.0:
		return
	_wear_t = 1.0
	# Hits taken on this machine (the other's come through _hurt_other).
	var hp := int(main.get("_player_health"))
	if _last_hp > hp:
		_shaken("host", (_last_hp - hp) * 0.6)
	_last_hp = hp
	var night := bool(main._is_enemy_night_active())
	var me := main.get("_player") as Node3D
	var together := me != null and me.global_position.distance_to(_partner_pos()) < 7.0
	for who in ["host", "other"]:
		var s := float(sanity[who])
		if not night:
			s += 0.25
		elif together:
			s += 0.12
		elif _is_out(who) and _dark_at(who) > 0.7:
			s -= 0.15
		# An enemy hunting you, there in front of you.
		for b in main.get("_enemy_brains"):
			if b == null or str(_targets.get(b.get_instance_id(), "")) != who:
				continue
			var body = b.get("_body")
			var root = b.get("_root")
			if body == null or not is_instance_valid(body) or root == null or not _shown_below(body, root):
				continue
			if b.has_method("_is_seen") and b._is_seen((body as Node3D).global_position + Vector3(0.0, 1.0, 0.0)):
				s -= 1.2
		sanity[who] = clampf(s, 0.0, 100.0)


## A night slept through brings it back (camp_office.gd, the morning after).
func slept() -> void:
	for who in ["host", "other"]:
		sanity[who] = minf(100.0, float(sanity[who]) + 45.0)


## The other machine: its warden's sanity, as the host's keeps it.
func take_own_sanity(v: float) -> void:
	sanity["own"] = v


func _own_sanity() -> float:
	return float(sanity.get("own", 100.0)) if Coop.is_client() else float(sanity["host"])


## Low, alone, at night, out in the dark: now and then the other warden stands off in
## the dark where they are not, for a moment, and is gone. Each machine, its own warden.
func _phantom_tick(delta: float) -> void:
	if _phantom != null and is_instance_valid(_phantom):
		_phantom_left -= delta
		if _phantom_left <= 0.0:
			_phantom.queue_free()
			_phantom = null
		return
	var own := _own_sanity()
	if own >= 45.0 or not bool(main._is_enemy_night_active()) or bool(main._is_any_interior_open()):
		return
	_phantom_wait -= delta * (1.0 + (45.0 - own) / 15.0)
	if _phantom_wait > 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_phantom_wait = rng.randf_range(70.0, 160.0)
	var player := main.get("_player") as Node3D
	var world: Node3D = main.get("_world_3d")
	if player == null or world == null:
		return
	# Not with the real one close by.
	if player.global_position.distance_to(_partner_pos()) < 20.0:
		return
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	var fwd := -(cam.global_basis.z if cam != null else player.global_basis.z)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Off to the side, at the edge of the torch: there, and when you look, gone.
	var side := fwd.rotated(Vector3.UP, deg_to_rad(rng.randf_range(38.0, 62.0) * (1.0 if rng.randf() < 0.5 else -1.0)))
	var at := player.global_position + side * rng.randf_range(13.0, 19.0)
	var look: Dictionary = Coop.partner_look
	_phantom = REMOTE_PLAYER.new()
	_phantom.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
	world.add_child(_phantom)
	_phantom.show_at(Vector3(at.x, player.global_position.y - 0.9, at.z), "stand")
	_phantom_left = rng.randf_range(0.9, 1.6)


const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")


# ── the other machine ─────────────────────────────────────────────────────────

func show_view(items: Array) -> void:
	var world: Node3D = main.get("_world_3d") if main != null else null
	if world == null:
		return
	if _mirror_root == null or not is_instance_valid(_mirror_root):
		_mirror_root = Node3D.new()
		_mirror_root.name = "CoopNightMirror"
		world.add_child(_mirror_root)
		_mirror.clear()
	_mirror_left = 0.6
	var seen := {}
	for it in items:
		if not (it is Dictionary):
			continue
		var key := str(it.get("k", ""))
		seen[key] = true
		var n: Node = _mirror.get(key)
		match str(it.get("t", "")):
			"s":
				var sp := n as Sprite3D
				if sp == null or not is_instance_valid(sp):
					sp = Sprite3D.new()
					sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
					sp.double_sided = true
					_mirror_root.add_child(sp)
					_mirror[key] = sp
				var tex_path := str(it["tex"])
				if sp.texture == null or sp.texture.resource_path != tex_path:
					sp.texture = load(tex_path) if ResourceLoader.exists(tex_path) else null
				sp.global_transform = it["xf"]
				sp.visible = bool(it["v"])
				sp.pixel_size = float(it["px"])
				sp.offset = it["off"]
				sp.flip_h = bool(it["fh"])
				sp.modulate = it["mod"]
				sp.shaded = bool(it["sh"])
				sp.billboard = int(it["bb"]) as BaseMaterial3D.BillboardMode
				sp.set_meta("coop_tag", str(it.get("tag", "")))
			"a":
				var a := n as AudioStreamPlayer3D
				if a == null or not is_instance_valid(a):
					var st_path := str(it["st"])
					if not ResourceLoader.exists(st_path):
						continue
					a = AudioStreamPlayer3D.new()
					a.stream = load(st_path)
					_mirror_root.add_child(a)
					_mirror[key] = a
					a.global_position = it["pos"]
					a.play(float(it.get("at", 0.0)))
				a.global_position = it["pos"]
				a.volume_db = float(it["db"])
				a.pitch_scale = float(it["pt"])
				a.max_distance = float(it["md"])
				a.unit_size = float(it["us"])
			"l":
				var l := n as Light3D
				if l == null or not is_instance_valid(l):
					l = SpotLight3D.new() if bool(it["spot"]) else OmniLight3D.new()
					_mirror_root.add_child(l)
					_mirror[key] = l
				l.global_transform = it["xf"]
				l.visible = bool(it["v"])
				l.light_color = it["c"]
				l.light_energy = float(it["e"])
				if l is SpotLight3D:
					(l as SpotLight3D).spot_range = float(it["r"])
					(l as SpotLight3D).spot_angle = float(it["ang"])
				else:
					(l as OmniLight3D).omni_range = float(it["r"])
	for key in _mirror.keys():
		if not seen.has(key):
			var gone = _mirror[key]
			if gone != null and is_instance_valid(gone):
				# A sound plays out; the rest goes at once.
				if gone is AudioStreamPlayer3D and (gone as AudioStreamPlayer3D).playing:
					(gone as AudioStreamPlayer3D).finished.connect((gone as Node).queue_free)
				else:
					(gone as Node).queue_free()
			_mirror.erase(key)


## The other machine: a shown thing of the host's tagged `tag` within `radius` of `at`
## (the guest lost in the corn), or null.
func tagged_near(tag: String, at: Vector3, radius: float) -> Node3D:
	for v in _mirror.values():
		if v is Sprite3D and is_instance_valid(v) and (v as Sprite3D).visible and str(v.get_meta("coop_tag", "")) == tag:
			var p := (v as Node3D).global_position
			if Vector2(p.x - at.x, p.z - at.z).length() < radius:
				return v
	return null


## The host: the other warden's stand-in (for a lost guest to follow).
func proxy() -> Node3D:
	return _proxy


func mirror_count() -> int:
	var n := 0
	for v in _mirror.values():
		if v != null and is_instance_valid(v):
			n += 1
	return n


func clear_mirror() -> void:
	if _mirror_root != null and is_instance_valid(_mirror_root):
		_mirror_root.queue_free()
	_mirror_root = null
	_mirror.clear()


## The other machine: what the night did to you on the host's.
func on_event(kind: String, data: Array) -> void:
	match kind:
		"hurt":
			main.damage_player(int(data[0]))
		"feed":
			main._on_enemy_notice(str(data[0]))
		"drain":
			var pl = main.get("_player")
			if pl != null:
				pl.set("flashlight_drain_boost", float(data[0]))
