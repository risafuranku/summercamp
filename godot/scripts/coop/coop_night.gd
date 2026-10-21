extends Node

## The night for several (scripts/coop/coop.gd; DESIGN.md §12). The night's enemies live
## on the host's machine, as alone; here they hunt any warden:
##   - every other warden has a stand-in body in the host's world (where they stand,
##     where they look and shine their torch: their warden state), so an enemy brain can
##     take it for "the player" (enemy_base.gd reads the player, its head camera and torch);
##   - each enemy hunts one warden at a time: whoever is out, and the one alone in the
##     dark sooner than the ones by the lamps; it lets go of one gone indoors for one out;
##   - what it does to the warden it hunts (a hit, a line in the feed) goes to that one;
##     the others, far off, hear them cry out;
##   - what the enemies are (their sprites, lights and sounds) is shown on the other
##     machines as it is on the host's, ten times a second;
##   - now and then one is only for the warden it hunts: nobody else sees or hears it at
##     all ("didn't you see that?");
##   - behind it a sanity per warden, kept on the host's machine and never shown or named:
##     hits, an enemy in front of you, the dark alone wear it down; the day, another
##     warden near and sleep give it back. The lower, the sooner the night picks you, the
##     likelier what you see is only yours, and the likelier you see one of the others
##     where they are not.
## A warden is "host" or "p<peer id>" here. Main owns one of these on every machine
## (main._coop_night).

const RETARGET_EVERY := 6.0
const FX_TEX := preload("res://scripts/night/fx_tex.gd")
const NIGHTMARE_FX := preload("res://scripts/night/nightmare_fx.gd")
## The other machine: what the host's enemies do to this warden's screen (remote_fx.gd),
## held here and given to nightmare_fx each frame: the levels (by source, with when they
## came), the close-up / overlay / split as last sent (shaken here each frame), the turn
## of the view (from where it was when it began).
var _rfx_levels := {}
var _rfx_held := {}
var _view_base := {}
var _view_off := Vector3.ZERO
const VIEW_HZ := 10.0
const EYE := Vector3(0.0, 1.8, 0.0)
const TOGETHER_M := 7.0
var main: Node
## Every other warden's stand-in on the host's: who -> {body: CharacterBody3D, cam: Camera3D}.
var _proxies: Dictionary = {}
var _targets: Dictionary = {}        # brain instance id -> who
var _retarget_t := 0.0
var _view_t := 0.0
## The other machines: the enemies as the host's shows them, by node key.
var _mirror_root: Node3D
var _mirror: Dictionary = {}
var _mirror_left := 0.0
## The hidden sanity, 0..100, by who (the host's machine keeps them all; each other machine
## gets its own in the host's clock, coop_clock "sn", as "own").
var sanity := {"host": 100.0}
var _private: Dictionary = {}       # brain instance id -> true: only its quarry sees it
var _wear_t := 0.0
var _last_hp := -1
var _phantom: Node3D
var _phantom_left := 0.0
var _phantom_wait := 60.0


static func who_of(peer: int) -> String:
	return "host" if peer == 1 else "p%d" % peer


static func peer_of(who: String) -> int:
	return 1 if who == "host" else int(who.trim_prefix("p"))


## Every warden in the camp, the host first.
func _all() -> Array:
	var out: Array = ["host"]
	for id in Coop.others():
		if int(id) != 1:
			out.append(who_of(int(id)))
	return out


func _process(delta: float) -> void:
	if main == null or not Coop.has_partner():
		_drop_proxies()
		clear_mirror()
		return
	_phantom_tick(delta)
	if Coop.is_host():
		_host_tick(delta)
	else:
		_rfx_tick()
	if Coop.is_host():
		pass
	elif _mirror_left > 0.0:
		_mirror_left -= delta
		if _mirror_left <= 0.0:
			clear_mirror()


# ── the host ──────────────────────────────────────────────────────────────────

func _host_tick(delta: float) -> void:
	for who in _all():
		if not sanity.has(who):
			sanity[who] = 100.0
	_wear(delta)
	# Their stand-ins are always about (a lost guest may follow one, an enemy hunt it).
	_sync_proxies()
	var brains: Array = main.get("_enemy_brains")
	if brains.is_empty():
		_targets.clear()
		_private.clear()
	else:
		_hunt(delta, brains)
	_view_t -= delta
	if _view_t <= 0.0:
		_view_t = 1.0 / VIEW_HZ
		# Callers by day too (the electrician): whatever stands in the "coop_mirror" group.
		var common: Array = []
		for root in get_tree().get_nodes_in_group(MIRROR_GROUP):
			if root is Node3D and (root as Node3D).is_inside_tree():
				_snapshot_root(root, "g%d" % root.get_instance_id(), common, true)
		# Each machine its own picture: the enemies all see, and the ones only its warden does.
		var any := false
		for id in Coop.others():
			var items := _snapshot(brains, who_of(int(id)))
			items.append_array(common)
			any = any or not items.is_empty()
			if not items.is_empty() or _sent_any:
				Coop.send_night_view(items, int(id))
		_sent_any = any


## Shown on the other machines as on this one, besides the enemies (scripts/reception/
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
			_private[b.get_instance_id()] = rng.randf() < 0.12 + (100.0 - float(sanity.get(who, 100.0))) / 100.0 * 0.38
	for b in brains:
		if b != null and not _all().has(str(_targets.get(b.get_instance_id(), "host"))):
			# Their quarry went home: someone else.
			_aim(b, _pick_target(b))
	_hide_private(brains)
	if _retarget_t <= 0.0:
		_retarget_t = RETARGET_EVERY
		for b in brains:
			if b == null:
				continue
			var now := str(_targets.get(b.get_instance_id(), "host"))
			if not _is_out(now):
				var next := _pick_target(b)
				if next != now and _is_out(next):
					_aim(b, next)


## Out where the night can reach: not in a room, in the boat or in town.
func _is_out(who: String) -> bool:
	# Knocked down, lying there: the night lets go of them (main._coop_come_to).
	if who == "host":
		return bool(main._can_enemy_runtime_actions()) and not bool(main.get("_coop_down"))
	var s: Dictionary = Coop.state_of(peer_of(who))
	return not s.is_empty() and not bool(s.get("in", false)) and not bool(s.get("dn", false)) and not s.has("boat") and not s.has("ride") and bool(main._is_enemy_night_active())


func _pos(who: String) -> Vector3:
	if who == "host":
		var me := main.get("_player") as Node3D
		return me.global_position if me != null else Vector3.ZERO
	return Coop.state_of(peer_of(who)).get("p", Vector3.ZERO)


func _dark_at(who: String) -> float:
	var bm = main.get("building_manager")
	if bm == null or not bm.has_method("get_light_level_at"):
		return 1.0
	return 1.0 - clampf(float(bm.get_light_level_at(_pos(who))), 0.0, 1.0)


## Whom a new enemy goes for: one of those out, the one in the dark sooner, the one
## with less left of themselves (the dice decide between the rest).
func _pick_target(brain) -> String:
	var pool: Array = []
	for who in _all():
		if _is_out(who):
			pool.append(who)
	if pool.is_empty():
		pool = _all()
	var weights: Array = []
	var total := 0.0
	for who in pool:
		var w := 0.4 + _dark_at(who) + (100.0 - float(sanity.get(who, 100.0))) / 100.0
		weights.append(w)
		total += w
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(brain.get_instance_id())
	var r := rng.randf() * total
	for i in pool.size():
		r -= float(weights[i])
		if r <= 0.0:
			return str(pool[i])
	return str(pool[-1])


## The brain hunts `who` from now on: their body, their hits, their feed.
func _aim(brain, who: String) -> void:
	# "other" (from the days of two, the harnesses): the first of the joining wardens.
	if who == "other":
		for id in Coop.others():
			if int(id) != 1:
				who = who_of(int(id))
				break
	_targets[brain.get_instance_id()] = who
	var proxy = _proxies.get(who, {}).get("body") if who != "host" else null
	if who != "host" and proxy != null:
		brain.set("_player", proxy)
		brain.set("_damage_callable", Callable(self, "_hurt_other").bind(who))
		brain.set("_allow_actions_callable", Callable(self, "_is_out").bind(who))
		brain.set("_notify_callable", Callable(self, "_feed_other").bind(who))
	else:
		_targets[brain.get_instance_id()] = "host"
		brain.set("_player", main.get("_player"))
		brain.set("_damage_callable", Callable(main, "damage_player"))
		brain.set("_allow_actions_callable", Callable(main, "_can_enemy_runtime_actions"))
		brain.set("_notify_callable", Callable(main, "_on_enemy_notice"))


func _hurt_other(amount: int, who: String) -> void:
	_shaken(who, amount * 0.6)
	Coop.send_night_event("hurt", [amount], peer_of(who))
	_cried_out(who)


## `who` cried out: the others far off from them hear it (on their own machines).
func _cried_out(who: String) -> void:
	for id in Coop.others():
		if who_of(int(id)) != who:
			Coop.send_night_event("heard", [peer_of(who)], int(id))
	if who != "host":
		_heard(peer_of(who))


## A warden cried out somewhere off in the dark (not heard close by: you are there).
func _heard(peer: int) -> void:
	var me := main.get("_player") as Node3D
	var fig := Coop.figure_of(peer)
	if me != null and fig != null and me.global_position.distance_to(fig.global_position) < TOGETHER_M:
		return
	# No line on the screen: their cry, from where they are, far off.
	if fig == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = load("res://assets/sfx/director/call_far.mp3")
	a.max_distance = 120.0
	a.unit_size = 12.0
	a.pitch_scale = 0.9
	main.add_child(a)
	a.global_position = fig.global_position + Vector3(0, 1.5, 0)
	a.finished.connect(a.queue_free)
	a.play()


func _feed_other(text: String, who: String) -> void:
	Coop.send_night_event("feed", [text], peer_of(who))


## Whom the night director presses on now: one out where the night is (all out or all
## in: the one with less left of themselves); it stays on them a while.
const DIRECTOR_HOLD := 40.0
var _director_on := "host"
var _director_since := -999.0


func director_target() -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _director_since < DIRECTOR_HOLD and _all().has(_director_on):
		return _director_on
	var out: Array = []
	for who in _all():
		if _is_out(who):
			out.append(who)
	var pool: Array = out if not out.is_empty() else _all()
	var pick := str(pool[0])
	for who in pool:
		if float(sanity.get(who, 100.0)) < float(sanity.get(pick, 100.0)) - 5.0:
			pick = str(who)
	if pick != _director_on:
		_director_on = pick
		_director_since = now
	return _director_on


## The wardens near `who` (what the night does to one, they see too): their peer ids.
func near(who: String) -> Array:
	var out: Array = []
	var at := _pos(who)
	for other in _all():
		if other != who and _pos(other).distance_to(at) < TOGETHER_M:
			out.append(peer_of(other))
	return out


## The host with another warden close by.
func together() -> bool:
	return not near("host").is_empty()


## Whether an enemy is only for the warden it hunts (the night decides; the check sets it).
func set_private(brain, on: bool) -> void:
	_private[brain.get_instance_id()] = on


## Who each enemy hunts now (for tools/coop_check.gd): "enemy:host" or "enemy:p<peer>".
func targets() -> Array:
	var out: Array = []
	for b in main.get("_enemy_brains"):
		if b != null:
			out.append("%s:%s" % [str(b.get_enemy_id()), str(_targets.get(b.get_instance_id(), "?"))])
	return out


## Every other warden with a stand-in, the gone without.
func _sync_proxies() -> void:
	var want := {}
	for id in Coop.others():
		if int(id) != 1:
			want[who_of(int(id))] = true
	for who in _proxies.keys():
		if not want.has(who):
			_drop_proxy(who)
	for who in want.keys():
		if not _proxies.has(who):
			_make_proxy(who)
		_place_proxy(who)


func _make_proxy(who: String) -> void:
	var world: Node3D = main.get("_world_3d")
	if world == null:
		return
	var proxy: CharacterBody3D = PROXY_SCRIPT.new()
	proxy.name = "WardenProxy_%s" % who
	# A body for the enemies' rays to leave out (get_rid); it touches nothing.
	proxy.collision_layer = 0
	proxy.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	shape.shape = cap
	shape.position = Vector3(0.0, 0.85, 0.0)
	proxy.add_child(shape)
	var head := Node3D.new()
	head.name = "Head"
	head.position = EYE
	proxy.add_child(head)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = false
	cam.fov = 75.0
	head.add_child(cam)
	proxy.set_meta("coop_id", peer_of(who))
	world.add_child(proxy)
	_proxies[who] = {"body": proxy, "cam": cam}


func _place_proxy(who: String) -> void:
	var e: Dictionary = _proxies.get(who, {})
	var proxy: CharacterBody3D = e.get("body")
	if proxy == null or not is_instance_valid(proxy):
		return
	var cam: Camera3D = e.get("cam")
	var s: Dictionary = Coop.state_of(peer_of(who))
	var p: Vector3 = s.get("p", proxy.global_position)
	var d: Vector3 = s.get("d", Vector3.FORWARD)
	# How they move (the basket woman listens for steps).
	var dt := get_process_delta_time()
	if dt > 0.0:
		proxy.velocity = (p - proxy.global_position) / dt if p.distance_to(proxy.global_position) < 3.0 else Vector3.ZERO
	proxy.global_position = p
	proxy.rotation.y = float(s.get("y", 0.0))
	if d.length() > 0.01 and cam != null:
		var eye := p + EYE
		var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		cam.global_transform = Transform3D(Basis.looking_at(d.normalized(), up), eye)


func _drop_proxy(who: String) -> void:
	var proxy = _proxies.get(who, {}).get("body")
	if proxy != null and is_instance_valid(proxy):
		proxy.queue_free()
	_proxies.erase(who)
	for k in _targets.keys():
		if str(_targets[k]) == who:
			_targets.erase(k)


func _drop_proxies() -> void:
	for who in _proxies.keys():
		_drop_proxy(who)
	_targets.clear()


const PROXY_SCRIPT = preload("res://scripts/coop/coop_proxy.gd")


## Only its quarry sees it now: a private one ("didn't you see that?"), or any while it
## scares the one it hunts (brain.is_private_now: the strike, right behind them, at their
## window...): the others must not glimpse it, or the scare is spoilt.
func _is_private(b) -> bool:
	if bool(_private.get(b.get_instance_id(), false)):
		return true
	return b.has_method("is_private_now") and bool(b.call("is_private_now"))


## A private enemy hunting another warden: on this machine it is neither seen nor heard
## (its root hidden, its sounds silent; what they were is kept for the picture sent
## over: "coop_db"). What is only ever its quarry's (meta "coop_quarry_only": a decoy
## pair of eyes, the ring round the lamp) likewise, while the quarry is not here.
func _hide_private(brains: Array) -> void:
	for b in brains:
		if b == null:
			continue
		var root = b.get("_root")
		if root == null or not is_instance_valid(root):
			continue
		var quarry := str(_targets.get(b.get_instance_id(), "host"))
		var theirs_alone := _is_private(b) and quarry != "host"
		_privacy(root as Node3D, theirs_alone)
		for n in (root as Node).find_children("*", "Node3D", true, false):
			if (n as Node).has_meta("coop_quarry_only"):
				_privacy(n as Node3D, quarry != "host")
		for n in (root as Node).find_children("*", "AudioStreamPlayer3D", true, false):
			var a := n as AudioStreamPlayer3D
			if theirs_alone or (quarry != "host" and _quarry_only(a, root)):
				if a.volume_db > -79.0:
					a.set_meta("coop_db", a.volume_db)
					a.volume_db = -80.0
			elif a.has_meta("coop_db"):
				a.volume_db = float(a.get_meta("coop_db"))
				a.remove_meta("coop_db")


## Hidden here for privacy (and marked so: the quarry's picture still shows it).
static func _privacy(n: Node3D, hide: bool) -> void:
	if hide:
		if n.visible or n.has_meta("coop_privacy"):
			n.set_meta("coop_privacy", true)
			n.visible = false
	elif n.has_meta("coop_privacy"):
		n.remove_meta("coop_privacy")
		n.visible = true


## Shown under `root`, leaving out the root itself (hidden for a private one); the root
## itself, as it is shown. For its quarry what is hidden only for privacy counts as shown.
static func _shown_below(n: Node, root: Node, for_quarry := false) -> bool:
	if n == root:
		return (n as Node3D).visible or (for_quarry and n.has_meta("coop_privacy"))
	var at := n
	while at != null:
		if at is Node3D and not (at as Node3D).visible and not (for_quarry and at.has_meta("coop_privacy")):
			return false
		if at == root:
			break
		at = at.get_parent()
	return true


## Under something only its quarry sees?
static func _quarry_only(n: Node, root: Node) -> bool:
	var at := n
	while at != null and at != root:
		if at.has_meta("coop_quarry_only"):
			return true
		at = at.get_parent()
	return false


## What the enemies show to `viewer`: every sprite, light and sound under each enemy's
## root, but not the ones only another warden, hunted by them, sees.
func _snapshot(brains: Array, viewer: String) -> Array:
	var out: Array = []
	for b in brains:
		if b == null:
			continue
		var quarry := str(_targets.get(b.get_instance_id(), "host"))
		if _is_private(b) and quarry != viewer:
			continue
		var root = b.get("_root")
		if root == null or not is_instance_valid(root):
			continue
		_snapshot_root(root, str(b.get_instance_id()), out, false, quarry == viewer)
	return out


## Every sprite, light and playing sound under `root` (and the root itself when
## `with_root`: a lone sprite in the mirror group), keyed `prefix/path`, into `out`.
func _snapshot_root(root: Node, prefix: String, out: Array, with_root := false, for_quarry := false) -> void:
	var nodes: Array = root.find_children("*", "", true, false)
	if with_root:
		nodes.push_front(root)
	for n in nodes:
		if not for_quarry and _quarry_only(n, root):
			continue
		var key := prefix + "/" + str(root.get_path_to(n))
		if n is Sprite3D:
			var sp := n as Sprite3D
			var tex = FX_TEX.encode(sp.texture)
			if tex == null:
				continue
			out.append({"k": key, "t": "s", "tex": tex, "xf": sp.global_transform, "v": _shown_below(sp, root, for_quarry),
				"px": sp.pixel_size, "off": sp.offset, "fh": sp.flip_h, "fv": sp.flip_v, "mod": sp.modulate, "sh": sp.shaded, "bb": int(sp.billboard),
				"tag": str(sp.get_meta("coop_tag", ""))})
		elif n is AudioStreamPlayer3D:
			var a := n as AudioStreamPlayer3D
			if a.stream == null or a.stream.resource_path == "" or not a.playing:
				continue
			out.append({"k": key, "t": "a", "st": a.stream.resource_path, "pos": a.global_position, "db": float(a.get_meta("coop_db", a.volume_db)), "pt": a.pitch_scale,
				"md": a.max_distance, "us": a.unit_size, "at": a.get_playback_position()})
		elif n is Light3D:
			var l := n as Light3D
			out.append({"k": key, "t": "l", "spot": n is SpotLight3D, "xf": l.global_transform, "v": _shown_below(l, root, for_quarry), "c": l.light_color,
				"e": l.light_energy, "r": (l as SpotLight3D).spot_range if n is SpotLight3D else (l as OmniLight3D).omni_range,
				"ang": (l as SpotLight3D).spot_angle if n is SpotLight3D else 0.0})


# ── the hidden sanity ─────────────────────────────────────────────────────────

func _shaken(who: String, amount: float) -> void:
	sanity[who] = clampf(float(sanity.get(who, 100.0)) - amount, 0.0, 100.0)


## Each second: what wears each warden down or brings them back.
func _wear(delta: float) -> void:
	_wear_t -= delta
	if _wear_t > 0.0:
		return
	_wear_t = 1.0
	# Hits taken on this machine (the others' come through _hurt_other).
	var hp := int(main.get("_player_health"))
	if _last_hp > hp:
		_shaken("host", (_last_hp - hp) * 0.6)
		# Far off, the others hear you.
		_cried_out("host")
	_last_hp = hp
	var night := bool(main._is_enemy_night_active())
	for who in _all():
		var s := float(sanity.get(who, 100.0))
		if not night:
			s += 0.25
		elif not near(who).is_empty():
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
	for who in sanity.keys():
		if who != "own":
			sanity[who] = minf(100.0, float(sanity[who]) + 45.0)


## The host: each other warden's sanity, for their machine (coop_clock "sn": peer -> it).
func sanity_by_peer() -> Dictionary:
	var out := {}
	for id in Coop.others():
		var who := who_of(int(id))
		if sanity.has(who):
			out[int(id)] = float(sanity[who])
	return out


## Another machine: its warden's sanity, as the host's keeps it.
func take_own_sanity(v: float) -> void:
	sanity["own"] = v


func _own_sanity() -> float:
	return float(sanity.get("own", 100.0)) if Coop.is_client() else float(sanity.get("host", 100.0))


## Low, alone, at night, out in the dark: now and then one of the others stands off in
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
	# Not with a real one close by.
	for f in Coop.figures():
		if player.global_position.distance_to((f as Node3D).global_position) < 20.0:
			return
	var ids := Coop.others()
	if ids.is_empty():
		return
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	var fwd := -(cam.global_basis.z if cam != null else player.global_basis.z)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	# Off to the side, at the edge of the torch: there, and when you look, gone.
	var side := fwd.rotated(Vector3.UP, deg_to_rad(rng.randf_range(38.0, 62.0) * (1.0 if rng.randf() < 0.5 else -1.0)))
	var at := player.global_position + side * rng.randf_range(13.0, 19.0)
	var look: Dictionary = Coop.look_of(int(ids[rng.randi() % ids.size()]))
	_phantom = REMOTE_PLAYER.new()
	_phantom.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
	world.add_child(_phantom)
	_phantom.show_at(Vector3(at.x, player.global_position.y - 0.9, at.z), "stand")
	_phantom_left = rng.randf_range(0.9, 1.6)


const REMOTE_PLAYER = preload("res://scripts/coop/remote_player.gd")


# ── the other machines ────────────────────────────────────────────────────────

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
				var tex_key := str(it["tex"])
				if sp.texture == null or str(sp.get_meta("tex_key", "")) != tex_key:
					sp.texture = FX_TEX.decode(it["tex"])
					sp.set_meta("tex_key", tex_key)
				sp.global_transform = it["xf"]
				sp.visible = bool(it["v"])
				sp.pixel_size = float(it["px"])
				sp.offset = it["off"]
				sp.flip_h = bool(it["fh"])
				sp.flip_v = bool(it.get("fv", false))
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


# ── the scare on this machine, from the host's enemies ───────────────────────

func _rfx() -> Node:
	return NIGHTMARE_FX.get_for(main) if main != null else null


## What a host's enemy does to this warden's screen (remote_fx.gd -> Coop.send_night_fx):
## nightmare_fx's calls, the turn of the view ("look"), being dragged, a sound in the room,
## an enemy's own thing ("ext").
func on_fx(method: String, args: Array) -> void:
	var a: Array = _unpack(args)
	match method:
		"look":
			_view_set(Vector3(float(a[0]), float(a[1]), float(a[2])))
		"view_off":
			_view_clear()
		"move_to":
			var pn = main.get("_player") if main != null else null
			if pn != null:
				(pn as Node3D).global_position = a[0]
		"play_2d":
			var path := str(a[0])
			if ResourceLoader.exists(path):
				var p := AudioStreamPlayer.new()
				p.stream = load(path)
				p.volume_db = float(a[1])
				p.pitch_scale = float(a[2])
				add_child(p)
				p.finished.connect(p.queue_free)
				p.play()
		"ext":
			_on_ext(str(a[0]), a[1] as Array)
		_:
			_rfx_apply(method, a)


## An enemy's own thing on this screen: the Photographer's (tourist_brain.gd) picture of
## you, taken here of your own warden ([his lens, him in it or null, the last one, the
## window's place or null]); his flash through one of your windows ([its place]).
func _on_ext(what: String, args: Array) -> void:
	match what:
		"polaroid":
			var pl = main.get("_player")
			var world: Node3D = main.get("_world_3d")
			if pl == null or world == null or args.size() < 4:
				return
			var w := {}
			if args[3] != null:
				w = _window_at(args[3])
				if w.is_empty():
					return
			if _polaroid == null or not is_instance_valid(_polaroid):
				_polaroid = POLAROID.new()
				main.get_tree().root.add_child(_polaroid)
			_polaroid.take_of(world.get_world_3d(), args[0], pl, args[1], w, bool(args[2]))
		"window_flash":
			var flash: Callable = _window_at(args[0]).get("flash", Callable())
			if flash.is_valid():
				flash.call()


const POLAROID := preload("res://scripts/enemies/polaroid.gd")
var _polaroid: CanvasLayer


## The window of the room you are in at `at` (InteriorManager.photo_windows), {} none.
func _window_at(at) -> Dictionary:
	var im = main.get("_interior_manager")
	if not (at is Vector3) or im == null or not im.has_method("photo_windows"):
		return {}
	for w in im.photo_windows():
		if (w["pos"] as Vector3).distance_to(at) < 0.3:
			return w
	return {}


## remote_fx.pack backwards: a texture from fx_tex, "their camera" this warden's.
func _unpack(v):
	if v is Dictionary:
		if (v as Dictionary).has("_tex"):
			return FX_TEX.decode((v as Dictionary)["_tex"])
		if (v as Dictionary).has("_cam"):
			return _view_cam()
		return v
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_unpack(x))
		return out
	return v


## One of nightmare_fx's calls (its textures and camera made here already); what holds
## is kept and given again each frame (_rfx_tick).
func _rfx_apply(method: String, args: Array) -> void:
	var fx := _rfx()
	if fx == null:
		return
	match method:
		"set_dread", "set_presence":
			_rfx_levels[method + "|" + str(args[0])] = [method, str(args[0]), float(args[1]), Time.get_ticks_msec()]
		"set_eyes":
			_rfx_levels["set_eyes|" + str(args[0])] = ["set_eyes", args, 0.0, Time.get_ticks_msec()]
		"close_up", "overlay", "split":
			if args.is_empty() or args[0] == null:
				return
			_rfx_held[method] = args
			fx.callv(method, args)
		"close_up_off":
			_rfx_held.clear()
			fx.call("close_up_off")
		"overlay_off", "split_off":
			_rfx_held.erase(method.trim_suffix("_off"))
			fx.call(method)
		"subliminal":
			if args[0] != null:
				fx.callv("subliminal", args)
		_:
			if fx.has_method(method):
				fx.callv(method, args)


## Each frame: the levels while they hold (gone a second after the host stops saying),
## the close-up and the rest shaken again.
func _rfx_tick() -> void:
	if _rfx_levels.is_empty() and _rfx_held.is_empty() and _view_base.is_empty():
		return
	var fx := _rfx()
	if fx == null:
		return
	var now := Time.get_ticks_msec()
	for k in _rfx_levels.keys():
		var e: Array = _rfx_levels[k]
		if now - int(e[3]) > (250 if str(e[0]) == "set_eyes" else 1000):
			_rfx_levels.erase(k)
			continue
		if str(e[0]) == "set_eyes":
			fx.callv("set_eyes", e[1])
		else:
			fx.call(str(e[0]), str(e[1]), float(e[2]))
	for m in _rfx_held:
		fx.callv(m, _rfx_held[m])
	if not _view_base.is_empty():
		_view_apply()


func _view_cam() -> Camera3D:
	var pl = main.get("_player") if main != null else null
	if pl == null:
		return null
	return (pl as Node).get_node_or_null("Head/Camera3D") as Camera3D


## The host's enemy turns this warden's view: pitch, roll, yaw from where it was.
func _view_set(off: Vector3) -> void:
	var pl = main.get("_player") if main != null else null
	var cam := _view_cam()
	if pl == null or cam == null:
		return
	if _view_base.is_empty():
		_view_base = {"yaw": (pl as Node3D).rotation.y, "pitch": cam.rotation.x, "roll": cam.rotation.z}
	_view_off = off
	_view_apply()


func _view_apply() -> void:
	var pl = main.get("_player")
	var cam := _view_cam()
	if pl == null or cam == null:
		return
	(pl as Node3D).rotation.y = float(_view_base["yaw"]) + _view_off.z
	cam.rotation.x = float(_view_base["pitch"]) + _view_off.x
	cam.rotation.z = float(_view_base["roll"]) + _view_off.y


func _view_clear() -> void:
	if _view_base.is_empty():
		return
	_view_off = Vector3.ZERO
	_view_apply()
	_view_base = {}


## Another machine: a shown thing of the host's tagged `tag` within `radius` of `at`
## (the guest lost in the corn), or null.
func tagged_near(tag: String, at: Vector3, radius: float) -> Node3D:
	for v in _mirror.values():
		if v is Sprite3D and is_instance_valid(v) and (v as Sprite3D).visible and str(v.get_meta("coop_tag", "")) == tag:
			var p := (v as Node3D).global_position
			if Vector2(p.x - at.x, p.z - at.z).length() < radius:
				return v
	return null


## The host: a warden's stand-in (for a lost guest to follow): `peer`'s, or the first's.
func proxy(peer := 0) -> Node3D:
	if peer == 0:
		for who in _proxies.keys():
			return _proxies[who].get("body")
		return null
	return _proxies.get(who_of(peer), {}).get("body")


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


## Another machine: what the night did to you on the host's.
func on_event(kind: String, data: Array) -> void:
	match kind:
		"hurt":
			main.damage_player(int(data[0]))
		"feed":
			main._on_enemy_notice(str(data[0]))
		"heard":
			_heard(int(data[0]) if not data.is_empty() else 1)
		"fx":
			# The night director's touch, here (a knock, a lamp out, the phone...).
			var fx = main.get("_director_fx")
			print("Coop: the night, here: %s" % str(data[0]))
			if fx != null and fx.has_method("run"):
				fx.run(str(data[0]), main._director_context())
		"stutter":
			var ps = main.get("_player")
			if ps != null:
				ps.set("flashlight_stutter", float(data[0]))
		"held":
			var ph = main.get("_player")
			if ph != null and "held_speed_mult" in ph:
				ph.set("held_speed_mult", float(data[0]))
		"controls":
			var pc = main.get("_player")
			if pc != null and pc.has_method("set_controls_enabled"):
				pc.call("set_controls_enabled", bool(data[0]))
		"drain":
			var pl = main.get("_player")
			if pl != null:
				pl.set("flashlight_drain_boost", float(data[0]))
