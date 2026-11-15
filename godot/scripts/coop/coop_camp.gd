extends RefCounted

## The camp for two, main's side of it (out of main.gd 15. 11.; the line itself is the
## Coop autoload, scripts/coop/coop.gd, DESIGN.md §12). The host's camp is the camp: what
## is built, cleared, repaired and how its rooms stand goes to the others as facts, the
## pulse (money, guests, mail, the businesses, the night's jobs) four times a second, the
## office PC's screen as frames; their requests come back to be done on the host. Each
## machine sends its own warden (local_warden: where, in which room, rowing, crawling,
## asleep); the joining machines run the host's clock between its words. A warden the
## night got lies down until somebody gets them up (E) or they come to on the office
## step. The menu's co-op: host a new camp, a saved one, join.

const INSTANCE = preload("res://scripts/instance/instance.gd")
var main: Node


func _init(main_node: Node) -> void:
	main = main_node


var wired := false


func wire() -> void:
	if wired:
		return
	wired = true
	_ensure_night()
	INSTANCE.coop(main).world_arrived.connect(_on_world_arrived)
	INSTANCE.coop(main).join_failed.connect(_on_join_failed)
	INSTANCE.coop(main).session_ended.connect(_on_session_ended)
	INSTANCE.coop(main).warden_joined.connect(_on_peer_joined)
	INSTANCE.coop(main).warden_left.connect(_on_peer_left)
	INSTANCE.coop(main).warden_moved.connect(_on_partner_moved)
	INSTANCE.coop(main).partner_look_changed.connect(func(_look: Dictionary) -> void:
		if main._interior_manager != null and main._interior_manager.has_method("coop_partner_look"):
			main._interior_manager.coop_partner_look({}, 0)
	)
	# The host's camp is the camp: what is built, cleared, repaired and how its rooms
	# stand goes to the other machine (which does it again, apply_fact).
	EventBus.BuildConfirmed.connect(func(t: String, at: Vector2i, rot: int) -> void:
		if INSTANCE.coop(main).is_host():
			INSTANCE.coop(main).send_fact("build", [t, at, rot])
	)
	EventBus.DemolishConfirmed.connect(func(rect: Rect2i, _n: int, _fee: int, _refund: int) -> void:
		if INSTANCE.coop(main).is_host():
			INSTANCE.coop(main).send_fact("demolish", [rect])
	)
	INSTANCE.bus(main).building_serviced.connect(func(at: Vector2i, _t: String, _broken: bool, _cost: int) -> void:
		if INSTANCE.coop(main).is_host():
			INSTANCE.coop(main).send_fact("service", [at])
	)
	INSTANCE.bus(main).room_task_done.connect(func(key: String, _task: String) -> void: _send_room(key))
	INSTANCE.bus(main).accommodation_state_changed.connect(func(key: String, _status: String, _n: int) -> void: _send_room(key))


## The pause menu is up in a co-op camp (the world goes on; you just stand there).
func menu_up() -> bool:
	return INSTANCE.coop(main).is_active() and main._pause_menu != null and main._pause_menu.is_open()


## Host: a new sandbox camp, open to one more warden.
func on_menu_host() -> void:
	if not INSTANCE.coop(main).host():
		if main._main_menu != null:
			main._main_menu.show_coop_notice("Port %d is taken." % INSTANCE.coop(main).port)
		return
	await main._start_new_camp(true)


## Host the camp last hosted for two (its newest save), for the other warden to join.
func on_menu_host_saved(path: String) -> void:
	# (A story camp too: its mails and checklist are the host's, shown to everyone; the
	# Q&A of 15. 11.)
	if not INSTANCE.coop(main).host():
		if main._main_menu != null:
			main._main_menu.show_coop_notice("Port %d is taken." % INSTANCE.coop(main).port)
		return
	var started := Time.get_ticks_msec()
	await main._show_menu_loading_for("Opening the camp...")
	if not main._start_loaded_game_from_path(path):
		INSTANCE.coop(main).leave()
		await main._hide_menu_loading_after(started, 180)
		if main._main_menu != null:
			main._main_menu.show_coop_notice("That camp would not open.")
		return
	await main._hide_menu_loading_after(started, 520, false)
	main._start_game_from_menu()


## Join: call the camp at `address`; it comes back as world_arrived or join_failed.
func on_menu_join(address: String) -> void:
	if main._title_stage != null:
		main._title_stage.let_go()
	if main._main_menu != null:
		main._main_menu.show_loading("Calling the camp...")
	INSTANCE.coop(main).join(address)


func _on_join_failed(reason: String) -> void:
	if main._main_menu != null:
		main._main_menu.hide_loading()
		main._main_menu.show_coop_notice(reason)


## The host's camp has come down the line: it is loaded like a save, and nothing in it
## runs here (sim_here() is false): the host's clock, weather and power drive it.
func _on_world_arrived(snapshot: Dictionary) -> void:
	if not main._apply_save_snapshot(snapshot, false):
		INSTANCE.coop(main).leave()
		_on_join_failed("The camp came through garbled.")
		return
	var bi_set = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	if bi_set != null and "_coop_radio_n" in bi_set:
		# (Back after a drop with the same number on the host's set: it played its own song.)
		bi_set.set("_coop_radio_n", -1)
	main._active_save_path = ""
	main._coop_powered = true
	till_shown = -1
	till_seq = 0
	till_pending.clear()
	main._start_game_from_menu()
	if INSTANCE.core(main).failure_system != null:
		INSTANCE.core(main).failure_system.enabled = false
	_forward_builds(true)
	call_deferred("_flush_facts")
	# Who is about: once they have all said who they are (their hellos come a moment after).
	await main.get_tree().create_timer(2.0).timeout
	if main._hud_manager != null and INSTANCE.coop(main).has_partner():
		# (The English "is" / "are" went into the Czech line, 4. 11.: a line each.)
		main._hud_manager.push_status(("You came in by the barrier. %s is about." if INSTANCE.coop(main).wardens.size() == 1 else "You came in by the barrier. %s are about.") % names_said(), 1)


func _on_session_ended(reason: String) -> void:
	_forward_builds(false)
	if CoreRoot != null and INSTANCE.core(main).actions != null:
		INSTANCE.core(main).actions.biz_remote = Callable()
	if main._gameplay_started:
		main._close_pause_menu(false)
		main._enter_main_menu()
	if main._main_menu != null:
		main._main_menu.hide_loading()
		main._main_menu.show_coop_notice(reason)


func _on_peer_joined(id: int) -> void:
	# A new line: their till changes are numbered from one again.
	till_acked.erase(id)
	sync_last.clear()
	# Their name comes with their hello, a moment after the line opens.
	await main.get_tree().create_timer(1.0).timeout
	if main._hud_manager != null and INSTANCE.coop(main).wardens.has(id):
		main._hud_manager.push_status("%s came in by the barrier." % INSTANCE.coop(main).name_of(id), 1)
	# The office, the PC, the register... sent once more as they finish loading the camp:
	# what came while they were still loading was dropped there, and it is sent again only
	# when it changes (a PC on at the host stayed off for them: playtest 21. 10.).
	for wait in [4.0, 8.0, 16.0]:
		await main.get_tree().create_timer(wait).timeout
		if not INSTANCE.coop(main).wardens.has(id):
			return
		if main._interior_manager != null:
			for key in (main._interior_manager.get("tent_doors") as Dictionary).keys():
				INSTANCE.coop(main).send_tent_door(str(key), true)
		sync_last.clear()


func _on_peer_left(id: int) -> void:
	if main._hud_manager != null:
		main._hud_manager.push_status("%s has gone home." % INSTANCE.coop(main).name_of(id), 1)
	_on_partner_moved(id, {})
	partner_was.erase(id)


## Where another warden is (each state of theirs): the boat where they have it, their
## figure in the room you are in if they are in it; the door they go in or out by swings;
## when they lie down, you hear of it.
const COOP_DOOR_ANIM = preload("res://scripts/attractions/door_anim.gd")
## Per warden (peer id): {in: indoors, room: the room they were last in, bed: lying down}.
var partner_was: Dictionary = {}


func _on_partner_moved(id: int, s: Dictionary) -> void:
	if not partner_was.has(id):
		partner_was[id] = {"in": false, "room": "", "bed": false}
	var was: Dictionary = partner_was[id]
	var room_info: Dictionary = s.get("room", {})
	var inside := bool(s.get("in", false))
	if inside != bool(was["in"]) and not s.is_empty():
		# (A door walked through on foot was told as it opened: door.)
		var door_key := str(room_info.get("k", "")) if inside else str(was["room"])
		if Time.get_ticks_msec() - int(door_told.get(door_key, -100000)) > 4000:
			swing_door(door_key)
	was["in"] = inside
	if inside and room_info.has("k"):
		was["room"] = str(room_info["k"])
	var in_bed := bool(s.get("z", false))
	if in_bed and not bool(was["bed"]) and main._hud_manager != null:
		main._hud_manager.push_status("%s has turned in." % INSTANCE.coop(main).name_of(id), 1)
	was["bed"] = in_bed
	if main._lake_trip != null and main._lake_trip.has_method("coop_mirror_boat"):
		# One boat: whoever of the others has it (rowing, or tied up on the far shore).
		var rower := 0
		for oid in INSTANCE.coop(main).others():
			var os: Dictionary = INSTANCE.coop(main).state_of(oid)
			if os.has("boat") or os.has("boat_at"):
				rower = int(oid)
		var rs: Dictionary = INSTANCE.coop(main).state_of(rower) if rower != 0 else {}
		main._lake_trip.coop_mirror_boat(rs.get("boat", rs.get("boat_at", null)), rs.has("boat_at"), rower, rs.get("rp", []))
	if main._interior_manager != null and main._interior_manager.has_method("coop_partner"):
		var room: Dictionary = s.get("room", {})
		if bool(s.get("z", false)) and not room.is_empty():
			# Under the blanket: not standing about the room.
			room = room.duplicate()
			room["b"] = true
		main._interior_manager.coop_partner(room, id)


## Co-op: knocked down, not dead. You fall and lie where you fell (the other warden sees
## you lying there: warden state "dn"); the night leaves you be. They get you up with E,
## or, nobody coming, you come to on the office step a while later, sore.
const COOP_COME_TO_HEALTH := 35
const COOP_DOWN_WAIT := 90.0
var down_left := 0.0


func come_to() -> void:
	if main._player == null or not is_instance_valid(main._player) or main._coop_down:
		return
	main._coop_down = true
	down_left = COOP_DOWN_WAIT
	if main._warden_play != null and main._warden_play.is_active():
		main._warden_play.leave()
	if main._player.has_method("set_controls_enabled"):
		main._player.set_controls_enabled(false)
	if main._player.has_method("play_death_fall"):
		main._player.play_death_fall()
	if main._hud_manager != null:
		main._hud_manager.push_status("You go down. The grass is cold against your face.", 2)


func tick_down(delta: float) -> void:
	if not main._coop_down:
		return
	down_left -= delta
	if down_left <= 0.0 or not INSTANCE.coop(main).has_partner():
		_get_up(false)


## Up again: helped (where you lie) or alone (on the office step, much later).
func _get_up(helped: bool) -> void:
	if not main._coop_down or main._player == null or not is_instance_valid(main._player):
		return
	main._coop_down = false
	if not helped and main.grid_manager != null and main.world_generator != null and main.world_generator.has_method("find_player_spawn_coord"):
		main._player.global_position = main.grid_manager.grid_to_world(main.world_generator.find_player_spawn_coord()) + Vector3(1.6, 1.0, 0.6)
	if main._player.has_method("reset_damage_feedback_state"):
		main._player.reset_damage_feedback_state(false)
	main._set_player_health(COOP_COME_TO_HEALTH, false)
	if main._hud_manager != null:
		if helped:
			main._hud_manager.push_status("%s hauls you up by the jacket. \"Come on. Not here.\"" % INSTANCE.coop(main).sender_name(), 1)
		else:
			main._hud_manager.push_status("You come to on the office step. You don't remember getting here.", 2)


## Another warden lying near you (knocked down): E gets them up (the nearest of them).
var down_near_id := 0


func partner_down_near() -> bool:
	down_near_id = 0
	if main._player == null or not is_instance_valid(main._player):
		return false
	var best := 2.2
	for id in INSTANCE.coop(main).others():
		if not bool(INSTANCE.coop(main).state_of(id).get("dn", false)):
			continue
		var fig = INSTANCE.coop(main).figure_of(id)
		if fig == null or not fig.visible:
			continue
		var d := Vector2(fig.global_position.x - main._player.global_position.x, fig.global_position.z - main._player.global_position.z).length()
		if d < best:
			best = d
			down_near_id = int(id)
	return down_near_id != 0


func lift_partner() -> void:
	# Every machine hears it; only the one lying there gets up (lifted).
	INSTANCE.coop(main).send_play("lift", [down_near_id])
	if main._hud_manager != null:
		main._hud_manager.push_status("You get %s up. They are shaking." % INSTANCE.coop(main).name_of(down_near_id), 1)


## The other wardens' names as said: "Jana", "Jana and Pepa", "Jana, Pepa and Bara".
func names_said() -> String:
	var names: Array = []
	for id in INSTANCE.coop(main).others():
		names.append(INSTANCE.coop(main).name_of(id))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


func _biz_change(kind: String, a: Array) -> void:
	var act = INSTANCE.core(main).actions if CoreRoot != null else null
	if act == null or a.is_empty():
		return
	match kind:
		"take":
			act.biz_take(str(a[0]), a[1])
		"sale":
			act.biz_sale(str(a[0]), int(a[1]), int(a[2]), bool(a[3]), false)
		"lost":
			act.biz_lost(str(a[0]))
		"order":
			act.biz_add_order(str(a[0]), a[1], int(a[2]), int(a[3]))
		"hire":
			if a.size() > 2 and a[1] is Dictionary:
				act.biz_hire(str(a[0]), a[1], int(a[2]))
		"fire":
			act.biz_fire(str(a[0]), str(a[1]) if a.size() > 1 else "")
		"waste":
			act.biz_waste(str(a[0]), a[1])
		"gear":
			act.biz_add_gear(str(a[0]), str(a[1]))
		"rack":
			# A warehouse rack given to a place (scripts/business/store_room.gd).
			if a.size() > 2:
				act.biz_set_rack(str(a[0]), int(a[1]), str(a[2]))
		"licence":
			act.biz_grant_licence(str(a[0]))
		"aid":
			# A first-aid cabinet the other warden emptied (scripts/aid_cabinet.gd).
			if a.size() > 1:
				act.aid_used(str(a[0]), int(a[1]))
		"job":
			act.biz_set_job(str(a[0]), str(a[1]), str(a[2]), str(a[3]))
		"late":
			act.biz_set_late(str(a[0]), bool(a[1]))
		"auto":
			act.biz_set_auto(str(a[0]), bool(a[1]))
		"menu":
			act.biz_set_menu(str(a[0]), str(a[1]), bool(a[2]))
		"score":
			act.biz_score(str(a[0]), a[1])
		# The staffroom's hands (actions.staff_*).
		"s_hire":
			if a[0] is Dictionary:
				act.staff_hire(a[0], int(a[1]) if a.size() > 1 else INSTANCE.core(main).get_day())
		"s_fire":
			act.staff_fire(str(a[0]))
		"s_job":
			if a.size() > 2:
				act.staff_set_job(str(a[0]), str(a[1]), bool(a[2]))
		"s_gear":
			act.staff_add_gear(str(a[0]))
		"camp":
			act.note_camp(str(a[0]), int(a[1]))


## The other machine: the other warden got you up.
func lifted(who: int = 0) -> void:
	if who != 0 and who != main.multiplayer.get_unique_id():
		return
	_get_up(true)


## The night for two: enemies hunt either warden, the other machine sees them
## (scripts/coop/coop_night.gd).


func _ensure_night() -> void:
	if main._coop_night != null and is_instance_valid(main._coop_night):
		return
	main._coop_night = main.COOP_NIGHT_SCRIPT.new()
	main._coop_night.name = "CoopNight"
	main._coop_night.main = main
	main.add_child(main._coop_night)


## The host: what of the camp changes by itself, for the other machine once a second
## (Coop sends it when it changed): the guests and their plans (the agents act them out
## there too), breakdowns, the buildings' condition (the lamps), the rooms, the mail, the
## shed key, the day's events and the night's faults that put lamps out.
func camp_pulse() -> Dictionary:
	var state = INSTANCE.core(main).get_state()
	if state == null:
		return {}
	var maint := {}
	var halves := {}
	for coord in state.grid.cells.keys():
		var cell = state.grid.cells[coord]
		if cell is Dictionary and (cell as Dictionary).has("maintenance"):
			maint[coord] = float(cell["maintenance"])
			# The two halves of a block too: without them the other machine had both as bad as
			# the worse one (the user 7. 11.: "it tells me to clean both toilets").
			if (cell as Dictionary).has("maint_l"):
				halves[coord] = [float(cell["maint_l"]), float(cell.get("maint_r", cell["maint_l"]))]
	var mail: Dictionary = {}
	if EmailManager != null:
		mail = {"inbox": INSTANCE.mail(main).inbox, "sent": INSTANCE.mail(main).sent, "rep": INSTANCE.mail(main).reputation}
	var key: bool = main.camp_office != null and is_instance_valid(main.camp_office) and main.camp_office.has_shed_key
	var day: Dictionary = main._day_events.export_state() if main._day_events != null else {}
	# The night's faults that put lamps out (the breaker, a dead circuit).
	var nj := {"bt": bool(main._night_jobs.breaker_tripped), "dc": int(main._night_jobs.dead_circuit), "jobs": main._night_jobs.coop_jobs()} if main._night_jobs != null else {}
	# The back office (CampStat, the bazaar): the reviews, the takings, the bills, the
	# lost and found.
	var books := {"rev": state.guest_reviews, "tx": state.guest_transactions, "sat": float(state.satisfaction), "karma": float(state.karma),
		"hrot": float(state.hrotfaktor), "elec": main._billing.export_state(), "baz": main._bazaar.export_state(), "gog": main._goggle.export_state()}
	# Vera's checklist, the host's (a story camp's): shown on every machine.
	var quest: Dictionary = main._quest_manager.coop_state() if main._quest_manager != null and is_instance_valid(main._quest_manager) else {}
	return {"guests": state.guests, "failures": state.failures, "maint": maint, "maint_lr": halves, "rooms": state.accommodation_states, "mail": mail, "shed_key": key, "day": day, "nj": nj, "biz": state.biz, "books": books, "lost": state.lost_guests, "quest": quest}


var last_day_hash := 0

## The other machine's till: the host's, plus what was spent or taken here and not yet
## counted there (each change goes to the host numbered; its clock says how far it got).
var till_shown := -1
var till_seq := 0
var till_pending: Array = []      # [[seq, delta]]
## The host: the last of the other warden's till changes it has counted.
var till_acked: Dictionary = {}     # peer id -> the last change counted


func _follow_till(host_money: int, acked: int) -> void:
	var state = INSTANCE.core(main).get_state()
	if till_shown >= 0:
		var here := int(state.money) - till_shown
		if here != 0:
			till_seq += 1
			till_pending.append([till_seq, here])
			INSTANCE.coop(main).send_request("till", [till_seq, here])
	till_pending = till_pending.filter(func(p): return int(p[0]) > acked)
	var shown := host_money
	for p in till_pending:
		shown += int(p[1])
	if int(state.money) != shown:
		INSTANCE.core(main).apply_changes({"money": shown})
	till_shown = shown


## The other warden's machine: the host's camp as it now is (camp_pulse).
func apply_pulse(p: Dictionary) -> void:
	if not INSTANCE.coop(main).is_client() or not main._gameplay_started or main._menu_mode:
		return
	var state = INSTANCE.core(main).get_state()
	if state == null:
		return
	var was := {}
	for g in state.guests:
		if g is Dictionary:
			was[int(g.get("id", -1))] = g
	state.guests = (p.get("guests", []) as Array).duplicate(true)
	if p.get("lost", null) is Array:
		state.lost_guests.assign((p["lost"] as Array).duplicate(true))
	_tell_arrivals(was)
	state.failures = (p.get("failures", {}) as Dictionary).duplicate(true)
	var rooms: Dictionary = p.get("rooms", {})
	if not rooms.is_empty():
		state.accommodation_states = rooms.duplicate(true)
	var maint: Dictionary = p.get("maint", {})
	var halves: Dictionary = p.get("maint_lr", {})
	for coord in maint.keys():
		if state.grid.cells.has(coord) and state.grid.cells[coord] is Dictionary:
			state.grid.cells[coord]["maintenance"] = float(maint[coord])
			if halves.has(coord):
				state.grid.cells[coord]["maint_l"] = float(halves[coord][0])
				state.grid.cells[coord]["maint_r"] = float(halves[coord][1])
			else:
				(state.grid.cells[coord] as Dictionary).erase("maint_l")
				(state.grid.cells[coord] as Dictionary).erase("maint_r")
	if GuestManager != null and INSTANCE.guests(main).has_method("_emit_guest_overview_state"):
		INSTANCE.guests(main)._emit_guest_overview_state(true)
	# The businesses' books are the host's (what is on the shelves, the orders, the hands);
	# what is done to them here goes there.
	if INSTANCE.core(main).actions != null and not INSTANCE.core(main).actions.biz_remote.is_valid():
		INSTANCE.core(main).actions.biz_remote = func(kind: String, args: Array) -> void:
			if INSTANCE.coop(main).is_client():
				INSTANCE.coop(main).send_request("biz", [kind, args])
	if p.get("biz", null) is Dictionary and not (p["biz"] as Dictionary).is_empty():
		state.biz = (p["biz"] as Dictionary).duplicate(true)
	var nj: Dictionary = p.get("nj", {})
	if main._night_jobs != null and not nj.is_empty():
		main._night_jobs.breaker_tripped = bool(nj.get("bt", false))
		main._night_jobs.dead_circuit = int(nj.get("dc", -1))
		# Tonight's jobs, the host's: listed, paged and pointed to here too.
		main._night_jobs.coop_take(nj.get("jobs", []))
	main._sync_dark_lamps()
	if main.camp_office != null and is_instance_valid(main.camp_office):
		main.camp_office.has_shed_key = bool(p.get("shed_key", main.camp_office.has_shed_key))
	# The day's events: only when they changed (bringing them in builds their props anew).
	var day: Dictionary = p.get("day", {})
	var day_hash := hash(var_to_bytes(day))
	if main._day_events != null and day_hash != last_day_hash:
		last_day_hash = day_hash
		main._day_events.import_state(day)
	var mail: Dictionary = p.get("mail", {})
	if not mail.is_empty() and EmailManager != null and INSTANCE.mail(main).has_method("coop_take"):
		INSTANCE.mail(main).coop_take(mail)
	if main._quest_manager != null and is_instance_valid(main._quest_manager):
		main._quest_manager.coop_follow(p.get("quest", {}))
	# The back office is the host's: CampStat's reviews, takings and bills, the bazaar.
	var books: Dictionary = p.get("books", {})
	if not books.is_empty():
		state.guest_reviews = (books.get("rev", []) as Array).duplicate(true)
		state.guest_transactions = (books.get("tx", []) as Array).duplicate(true)
		state.satisfaction = float(books.get("sat", state.satisfaction))
		state.karma = float(books.get("karma", state.karma))
		state.hrotfaktor = float(books.get("hrot", state.hrotfaktor))
		if books.get("elec", null) is Dictionary:
			main._billing.import_state(books["elec"], main._day_index, false)
		if books.get("baz", null) is Dictionary:
			main._bazaar.import_state(books["baz"])
		if books.get("gog", null) is Dictionary:
			main._goggle.import_state(books["gog"])


## The other warden's machine: a party reached the barrier, was let in or gave up in the
## host's camp. GuestManager only signals it where it simulates, so here the barrier
## stayed down (the party walked through it), and no line, car or hello came: the same
## signals, from the change of status in the pulse. `was`: id -> the guest before it.
func _tell_arrivals(was: Dictionary) -> void:
	if GuestManager == null or not INSTANCE.guests(main).has_method("_arrival_row"):
		return
	var now_abs: int = INSTANCE.guests(main)._absolute_minutes(maxi(1, main._day_index), int(main._time_of_day_hours), int(fposmod(main._time_of_day_hours, 1.0) * 60.0))
	var still := {}
	for g in INSTANCE.core(main).get_state().guests:
		if not (g is Dictionary):
			continue
		var id := int(g.get("id", -1))
		still[id] = true
		var before := str((was[id] as Dictionary).get("status", "")) if was.has(id) else "expected"
		var now := str(g.get("status", ""))
		if before == now:
			continue
		if now == "waiting" and before != "waiting":
			INSTANCE.bus(main).guest_at_gate.emit(INSTANCE.guests(main)._arrival_row(g, now_abs))
		elif before == "waiting" and now == "active":
			INSTANCE.bus(main).guest_checked_in.emit((g as Dictionary).duplicate(true))
	# Waiting at reception for the full time and gone from the list: they gave up and drove
	# off (sooner, the host turned them away at the desk).
	for id in was.keys():
		var old: Dictionary = was[id]
		if str(old.get("status", "")) == "waiting" and not still.has(id) \
				and now_abs - int(old.get("gate_since_abs", now_abs)) >= GuestManager.GATE_GIVE_UP_MINUTES - 2:
			INSTANCE.bus(main).guest_gave_up.emit(INSTANCE.guests(main)._arrival_row(old, now_abs))


## What both machines keep alike, sent when it changes here (INSTANCE.coop(main).send_sync): the
## office's lights, curtains and set; the desk's register and key hooks. The joining
## machine first takes the host's (it sends only what it changes itself).
var sync_last: Dictionary = {}


func sync_things() -> Dictionary:
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	if bi == null:
		return {}
	var out := {}
	if bi.has_method("coop_office_state"):
		out["office"] = bi.coop_office_state()
	var desk = bi.get("_desk_room")
	if desk != null and desk.has_method("coop_register"):
		out["register"] = desk.coop_register()
	# The office PC: what is installed, downloaded, binned, on the wallpaper (both ways).
	if bi.has_method("coop_pc_state"):
		out["pc"] = bi.coop_pc_state()
	# The radio is the host's: its set plays on the other machine too.
	if INSTANCE.coop(main).is_host() and bi.has_method("coop_radio_state"):
		out["radio"] = bi.coop_radio_state()
	# Who has been served what in the businesses (the host serves too: the mug lands on
	# their table on the other machine, and they stop waiting there).
	if INSTANCE.coop(main).is_host():
		out["served"] = main.ORDERS_SERVED._served.duplicate()
	# Pristoupim's job (hamlet_trip.gd): one for everyone, merged forwards both ways.
	var trip = main._interior_manager.get("_town_trip") if main._interior_manager != null else null
	if trip != null and trip.has_method("coop_hamlet"):
		out["hamlet"] = trip.coop_hamlet()
	# The camp's music: the host's piece; the client's being out and about (for the host's
	# choosing when a piece comes in).
	if main._music_director != null:
		out["music"] = main._music_director.coop_state()
	return out


func sync_poll() -> void:
	if not main._gameplay_started or main._menu_mode:
		return
	var things := sync_things()
	for kind in things.keys():
		var h := hash(var_to_bytes(things[kind]))
		if not sync_last.has(kind) and INSTANCE.coop(main).is_client():
			sync_last[kind] = h
			continue
		if int(sync_last.get(kind, 0)) != h:
			sync_last[kind] = h
			INSTANCE.coop(main).send_sync(kind, [things[kind]])


func sync(kind: String, data: Array) -> void:
	if not main._gameplay_started or main._menu_mode:
		return
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	match kind:
		"office":
			if bi != null and bi.has_method("coop_take_office_state"):
				bi.coop_take_office_state(data[0])
		"pc":
			if bi != null and bi.has_method("coop_take_pc_state"):
				bi.coop_take_pc_state(data[0])
		"radio":
			if INSTANCE.coop(main).is_client() and bi != null and bi.has_method("coop_take_radio"):
				bi.coop_take_radio(data[0])
			return
		"radio_ev":
			if INSTANCE.coop(main).is_client() and bi != null and bi.has_method("coop_take_radio_event") and data.size() >= 2:
				bi.coop_take_radio_event(int(data[0]), int(data[1]))
			return
		"music":
			if main._music_director != null:
				main._music_director.coop_take(data[0])
			return
		"served":
			if INSTANCE.coop(main).is_client():
				var got: Dictionary = data[0]
				for v in got:
					main.ORDERS_SERVED._served[v] = maxi(int(main.ORDERS_SERVED._served.get(v, 0)), int(got[v]))
			return
		"register":
			var desk = bi.get("_desk_room") if bi != null else null
			if desk != null and desk.has_method("coop_take_register"):
				desk.coop_take_register(data[0])
		"hamlet":
			var trip = main._interior_manager.get("_town_trip") if main._interior_manager != null else null
			if trip != null and trip.has_method("coop_take_hamlet") and data.size() > 0 and data[0] is Dictionary:
				trip.coop_take_hamlet(data[0])
				sync_last["hamlet"] = hash(var_to_bytes(trip.coop_hamlet()))
			return
		"camp_name":
			if not data.is_empty():
				main.set_camp_name(str(data[0]), true)
			return
		"gate":
			var gate = main.get_tree().get_first_node_in_group("camp_gate")
			if gate == null:
				return
			if not data.is_empty() and str(data[0]) == "down":
				gate.close_for_player()
			else:
				gate.open_for_player()
			return
	# Not sent back as it came; the register goes back if it merged with rows written here.
	var now := sync_things()
	if kind in ["office", "pc"] and now.has(kind):
		sync_last[kind] = hash(var_to_bytes(now[kind]))
	elif kind == "register":
		sync_last[kind] = hash(var_to_bytes(data[0]))


## Over the shoulder: your PC screen for the other machine while you sit at it and the
## other warden is in the office (InteriorManager has the picture), else nothing.
func screen_frame() -> PackedByteArray:
	if main._interior_manager == null or not main._interior_manager.has_method("coop_room"):
		return PackedByteArray()
	var mine: Dictionary = main._interior_manager.coop_room()
	if str(mine.get("w", "")) == "laptop":
		# At the staffroom's laptop (scripts/staff/laptop_view.gd): for whoever is in its
		# room with you.
		for id in INSTANCE.coop(main).others():
			var th: Dictionary = INSTANCE.coop(main).state_of(id).get("room", {})
			if str(th.get("k", "")) == str(mine.get("k", "")) and str(th.get("s", "")) == str(mine.get("s", "")) and str(th.get("w", "")) != "laptop":
				var bi_l = main._interior_manager.get("_building_interior")
				return bi_l.coop_screen_frame_any() if bi_l != null else PackedByteArray()
		return PackedByteArray()
	if str(mine.get("t", "")) != "office" or str(mine.get("w", "")) != "pc":
		return PackedByteArray()
	# Someone in the office to look over your shoulder.
	var watched := false
	for id in INSTANCE.coop(main).others():
		var theirs: Dictionary = INSTANCE.coop(main).state_of(id).get("room", {})
		# Anywhere in the office building (from the back room's doorway too: one space).
		if str(theirs.get("t", "")) == "office" and str(theirs.get("w", "")) != "pc":
			watched = true
	if not watched:
		return PackedByteArray()
	var bi = main._interior_manager.get("_building_interior")
	return bi.coop_screen_frame() if bi != null and bi.has_method("coop_screen_frame") else PackedByteArray()


## The other warden's screen, on your office's PC.
func show_screen(frame: PackedByteArray) -> void:
	# In the staffroom: the frame is from its laptop.
	var si = main._interior_manager.get("_service_interior") if main._interior_manager != null else null
	if si != null and si.has_method("coop_show_laptop") and si.is_open():
		si.coop_show_laptop(frame)
		return
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	if bi != null and bi.has_method("coop_show_screen") and bi.is_open():
		bi.coop_show_screen(frame)


## The door of the building with room key `key` ("x:y", or "office") opens and shuts.
func swing_door(key: String, pick := 0, seconds := 1.4) -> void:
	var st: Node3D = null
	if key == "office":
		st = main.debug_structure_of_type("main_building")
	elif key.begins_with("town_"):
		# Liblice's doors (town_trip.door_node), there on this machine too when its warden is.
		var trip = main._interior_manager.town_trip() if main._interior_manager != null and main._interior_manager.has_method("town_trip") else null
		st = trip.door_node(key.substr(5)) if trip != null and trip.has_method("door_node") else null
	elif key.contains(":"):
		var parts := key.split(":")
		st = COOP_DOOR_ANIM.structure_at(Vector2i(int(parts[0]), int(parts[1])))
	if st == null:
		return
	var doors: Array = COOP_DOOR_ANIM.find_doors(st)
	if not doors.is_empty():
		COOP_DOOR_ANIM.open(doors[clampi(pick, 0, doors.size() - 1)], seconds)


var door_told: Dictionary = {}


## Another warden is opening this door now (coop.gd `_door`).
func door(key: String, pick: int, seconds: float) -> void:
	door_told[key] = Time.get_ticks_msec()
	swing_door(key, pick, seconds)


## The host: a room's state as it is now, to the other machine.
func _send_room(key: String) -> void:
	if not INSTANCE.coop(main).is_host() or not INSTANCE.coop(main).has_partner():
		return
	var state = INSTANCE.core(main).get_state()
	if state != null and state.accommodation_states.has(key):
		INSTANCE.coop(main).send_room_state(key, (state.accommodation_states[key] as Dictionary).duplicate(true))


## The host: the other warden finished a job in a room; it is done in the real camp (and
## the room goes back to them, _send_room).
func room_task(key: String, task_id: String) -> void:
	if not INSTANCE.coop(main).is_host() or GuestManager == null:
		return
	INSTANCE.guests(main).complete_room_task(key, task_id)
	if main._interior_manager != null and main._interior_manager.has_method("coop_refresh_room"):
		main._interior_manager.coop_refresh_room(key)


## What the host has done since you joined, kept until your camp is built (it came
## with the snapshot only up to the moment it was sent).
var facts: Array = []


## The other warden's machine: the host's room as it is now.
func room_state(key: String, acc: Dictionary) -> void:
	if not INSTANCE.coop(main).is_client():
		return
	if not main._gameplay_started or main._menu_mode:
		facts.append(["room", [key, acc]])
		return
	INSTANCE.core(main).get_state().accommodation_states[key] = acc.duplicate(true)
	if main._interior_manager != null and main._interior_manager.has_method("coop_refresh_room"):
		main._interior_manager.coop_refresh_room(key)


## The other warden's machine: what the host did to the camp, done again here (the
## till is the host's: it is put back as it was).
func apply_fact(kind: String, data: Array) -> void:
	if not INSTANCE.coop(main).is_client():
		return
	if not main._gameplay_started or main._menu_mode:
		facts.append([kind, data])
		return
	if kind == "room":
		room_state(str(data[0]), data[1])
		return
	if kind == "biz_say":
		if main._hud_manager != null and data.size() >= 3:
			main._hud_manager.push_status(str(data[0]), int(data[1]), str(data[2]))
		return
	if kind == "books":
		main._coop_show_books(data[0])
		return
	if kind == "books_shut":
		main._coop_books_closed()
		return
	var state = INSTANCE.core(main).get_state()
	var keep := int(state.money)
	state.money = 1 << 30
	match kind:
		# Straight to the builder (the joining machine's own requests go to the host).
		# The host built it at its PC: the god cursor brings it down here too.
		"build":
			_god_from_peer(true)
			INSTANCE.core(main).builder_authority._on_request_build(str(data[0]), data[1], int(data[2]))
			_god_from_peer(false)
		"demolish":
			_god_from_peer(true)
			INSTANCE.core(main).builder_authority._on_request_demolish(data[0])
			_god_from_peer(false)
		"build_rejected":
			EventBus.BuildRejected.emit(str(data[0]), data[1], int(data[2]), str(data[3]))
		"demolish_rejected":
			EventBus.DemolishRejected.emit(data[0], str(data[1]))
		"upgrade":
			if main._interior_manager != null:
				main._interior_manager._handle_replace_upgrade(data[0], str(data[1]), str(data[2]), 0)
		"service":
			INSTANCE.core(main).actions.service_building(data[0], 0)
	state.money = keep
	INSTANCE.bus(main).money_changed.emit(keep)


## The host: what the other warden's hands ask of the camp (INSTANCE.coop(main).send_request). Done
## here as if done here; a build or demolition turned down goes back to them.
func request(kind: String, data: Array) -> void:
	if not INSTANCE.coop(main).is_host() or not main._gameplay_started:
		return
	match kind:
		"served":
			var visit := str(data[0])
			main.ORDERS_SERVED._served[visit] = int(main.ORDERS_SERVED._served.get(visit, 0)) + 1
		"meal":
			# What the other warden served, for the guest's review (scripts/food/orders.gd).
			if GuestManager != null and INSTANCE.guests(main).has_method("note_meal") and data.size() >= 3:
				INSTANCE.guests(main).note_meal(int(data[0]), str(data[1]), int(data[2]))
		"build":
			var turned: Array = []
			var cb := func(t: String, at: Vector2i, rot: int, reason: String) -> void: turned.append([t, at, rot, reason])
			EventBus.BuildRejected.connect(cb)
			_god_from_peer(true)
			EventBus.RequestBuild.emit(str(data[0]), data[1], int(data[2]))
			_god_from_peer(false)
			EventBus.BuildRejected.disconnect(cb)
			if not turned.is_empty():
				INSTANCE.coop(main).send_fact("build_rejected", turned[0])
		"demolish":
			var turned2: Array = []
			var cb2 := func(rect: Rect2i, reason: String) -> void: turned2.append([rect, reason])
			EventBus.DemolishRejected.connect(cb2)
			_god_from_peer(true)
			EventBus.RequestDemolish.emit(data[0])
			_god_from_peer(false)
			EventBus.DemolishRejected.disconnect(cb2)
			if not turned2.is_empty():
				INSTANCE.coop(main).send_fact("demolish_rejected", turned2[0])
		"money":
			INSTANCE.core(main).actions.add_money(int(data[0]))
		"till":
			# Spent or taken on the other machine (the town, the pub, the pump...).
			var seq := int(data[0])
			if seq > int(till_acked.get(INSTANCE.coop(main).sender, 0)):
				till_acked[INSTANCE.coop(main).sender] = seq
				var delta := int(data[1])
				if delta >= 0:
					INSTANCE.core(main).actions.add_money(delta)
				else:
					INSTANCE.core(main).actions.spend_money(mini(-delta, INSTANCE.core(main).get_money()))
		"service":
			INSTANCE.core(main).actions.service_building(data[0], int(data[1]))
		"service_side":
			INSTANCE.core(main).actions.service_side(data[0], str(data[1]))
		"upgrade":
			if main._interior_manager != null and data[0] is Dictionary:
				main._interior_manager.coop_upgrade(data[0])
		"day_event":
			if main._day_events != null:
				main._day_events.coop_resolve(int(data[0]))
		"biz":
			# The other warden's hands on the businesses' books (actions.biz_remote there);
			# the money came with their till.
			_biz_change(str(data[0]), data[1] if data.size() > 1 and data[1] is Array else [])
		"radio":
			# The other warden switched the office radio: the set is the host's.
			var bi_r = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
			if bi_r != null and bi_r.has_method("coop_set_radio_power"):
				bi_r.coop_set_radio_power(bool(data[0]))
		"corn_take":
			# The other warden leads them out: they follow the stand-in.
			if main._corn_hunt != null and is_instance_valid(main._corn_hunt) and main._coop_night != null and main._coop_night.proxy(INSTANCE.coop(main).sender) != null:
				main._corn_hunt.coop_take(main._coop_night.proxy(INSTANCE.coop(main).sender))
		"repair":
			if main.economy_manager != null and main.economy_manager.has_method("add_repair_progress"):
				main.economy_manager.add_repair_progress(data[0], 1.0)
		"breaker":
			if main._night_jobs != null:
				main._night_jobs.on_breaker_fixed(int(data[0]))
		"checkin":
			INSTANCE.guests(main).request_check_in(int(data[0]))
		"refuse":
			INSTANCE.guests(main).refuse_at_desk(int(data[0]))
		"phone":
			if main.camp_office != null:
				main.camp_office.on_phone_effect(str(data[0]), str(data[1]))
		"shed_key":
			if main.camp_office != null:
				main.camp_office.take_shed_key()
		"mail":
			if EmailManager != null and INSTANCE.mail(main).has_method("coop_do"):
				INSTANCE.mail(main).coop_do(data)
		"pay_bill":
			main.request_pay_electricity_bill(str(data[0]))
		"crew":
			main.request_maintenance_crew()
		"crew_at":
			main.request_maintenance_crew_at(data[0])
		"bazaar_list":
			main.bazaar_list(int(data[0]))
		"goggle_remove":
			# Paid on their machine (the till brings it).
			main._goggle.request_removal(int(data[0]), main._day_index)
		"goggle_reply":
			main.goggle_reply(int(data[0]), str(data[1]))
		"atlas_ad":
			# Paid on their machine (the till brings it); one of the kind already running
			# (both wardens bought it at once): the fee back.
			if not main._goggle.buy_ad(str(data[0]), int(data[1]), int(data[2])):
				INSTANCE.core(main).actions.add_money(main._goggle.ad_cost(str(data[0]), int(data[1])))
		"builder98_mail":
			# Builder 98 on the other machine: its registration key or the district's
			# letter comes in the host's mail (the other machine gets it from there).
			if EmailManager != null and INSTANCE.mail(main).has_method("schedule_pool_mail"):
				INSTANCE.mail(main).schedule_pool_mail(preload("res://scripts/builder/shareware.gd").mail_for(str(data[0]), str(data[1]), main._day_index))


## A build or demolition from another warden's PC: the god cursor stages it here too.
func _god_from_peer(on: bool) -> void:
	if main._god_cursor != null and is_instance_valid(main._god_cursor):
		main._god_cursor.from_peer = on


## The other warden's machine builds nothing of its own accord: what its Builder asks
## goes to the host (and comes back as a fact). Off again outside co-op.
var build_forwarding := false


func _forward_builds(on: bool) -> void:
	var auth = INSTANCE.core(main).builder_authority
	if auth == null or on == build_forwarding:
		return
	build_forwarding = on
	var b := Callable(auth, "_on_request_build")
	var d := Callable(auth, "_on_request_demolish")
	var fb := Callable(self, "_send_build")
	var fd := Callable(self, "_send_demolish")
	if on:
		if EventBus.RequestBuild.is_connected(b):
			EventBus.RequestBuild.disconnect(b)
		if EventBus.RequestDemolish.is_connected(d):
			EventBus.RequestDemolish.disconnect(d)
		EventBus.RequestBuild.connect(fb)
		EventBus.RequestDemolish.connect(fd)
	else:
		if EventBus.RequestBuild.is_connected(fb):
			EventBus.RequestBuild.disconnect(fb)
		if EventBus.RequestDemolish.is_connected(fd):
			EventBus.RequestDemolish.disconnect(fd)
		auth._connect_event_bus()


func _send_build(t: String, at: Vector2i, rot: int) -> void:
	if not INSTANCE.coop(main).is_client():
		# Left the co-op camp without the end being heard: the builder is ours again.
		_forward_builds(false)
		INSTANCE.core(main).builder_authority._on_request_build(t, at, rot)
		return
	INSTANCE.coop(main).send_request("build", [t, at, rot])


func _send_demolish(rect: Rect2i) -> void:
	if not INSTANCE.coop(main).is_client():
		_forward_builds(false)
		INSTANCE.core(main).builder_authority._on_request_demolish(rect)
		return
	INSTANCE.coop(main).send_request("demolish", [rect])


func _flush_facts() -> void:
	var queued := facts.duplicate()
	facts.clear()
	for f in queued:
		apply_fact(str(f[0]), f[1])


## The other warden's hands, so far: the boat, the rooms (tents, cabins, caravans), to be
## in them and to clean them (the jobs go to the host), and the office building, to be
## in it and to sleep (its PC, phone, board and check-ins stay the host's). The rest
## stays the host's until the next stages.
func client_interact() -> void:
	if main._lake_trip != null and not main._is_any_interior_open() and main._lake_trip.try_interact():
		return
	if main._in_attraction() and main._warden_play.try_interact():
		return
	# The guest lost in the corn (the host's): take them by the arm.
	if _corn_guest_near() != null:
		INSTANCE.coop(main).send_request("corn_take", [])
		if main._hud_manager != null:
			main._hud_manager.push_status("They grab your sleeve. \"Get me out of here.\"", 1)
		return
	# The day's events (the host's, shown here): sorted out through the host.
	if main._day_events != null and not main._is_any_interior_open() and main._day_events.try_interact():
		return
	# A guest: a word with them (a noise complaint settles through the host too).
	if not main._is_any_interior_open():
		var guest_in_view: Dictionary = main._find_guest_in_view()
		if not guest_in_view.is_empty():
			if str(guest_in_view.get("status", "")) == "waiting":
				if main._hud_manager != null:
					main._hud_manager.push_status("%s: \"We are waiting for the desk. Is anyone in there?\"" % str(guest_in_view.get("name", "Guest")), 0, "arrivals")
			else:
				main._talk_to_guest(guest_in_view)
			return
	# The attractions: in them on this machine, seen in them on the host's.
	if main._warden_play != null and not main._is_any_interior_open() and main._warden_play.try_interact():
		return
	var st := _client_room_target()
	if st != null:
		main._handle_structure_interior_interact(st)


func client_hint() -> String:
	if main._is_any_interior_open():
		return ""
	if main._in_attraction():
		return str(main._warden_play.hint())
	if _corn_guest_near() != null:
		return "[E] Take them by the arm"
	var day_hint: String = main._day_events.hint() if main._day_events != null else ""
	if not day_hint.is_empty():
		return day_hint
	var guest_in_view: Dictionary = main._find_guest_in_view()
	if not guest_in_view.is_empty():
		return ("[E] Check in %s" if str(guest_in_view.get("status", "")) == "waiting" else "[E] Talk to %s") % str(guest_in_view.get("name", "guest"))
	var h: String = main._lake_trip.hint() if main._lake_trip != null else ""
	if h.is_empty() and main._warden_play != null:
		h = str(main._warden_play.hint())
	if h.is_empty() and _client_room_target() != null and main._interaction_controller.has_method("build_hint_text"):
		h = str(main._interaction_controller.build_hint_text(main.INTERACT_DISTANCE, false))
	return h


func _corn_guest_near() -> Node3D:
	if main._coop_night == null or main._player == null or not is_instance_valid(main._player):
		return null
	return main._coop_night.tagged_near("corn_guest", main._player.global_position, 1.8)


func _client_room_target() -> Node3D:
	if main._interaction_controller == null or not main._interaction_controller.has_method("resolve_interaction"):
		return null
	var hit: Dictionary = main._interaction_controller.resolve_interaction(main.INTERACT_DISTANCE, false)
	if str(hit.get("type", "")) != "structure":
		return null
	var st := hit.get("structure") as Node3D
	if st == null:
		return null
	var t := str(st.get_meta("building_type", ""))
	if t.begins_with("tent_") or t.begins_with("cabin") or t.begins_with("caravan_") or t == "main_building" or t == "corn_stand" or t == "camp_sign":
		return st
	# Out of the camp (the barrier, the bus, Lesna): each machine's own (town_trip.gd),
	# the barrier sent over.
	if t.begins_with("trip_") or t.begins_with("town_"):
		return st
	# The toilets, showers, pub, shed and the rest: in to look and to clean and mend (what
	# that does goes to the host).
	if main._interior_manager != null and main._interior_manager.has_method("_is_supported_service_building_type") and main._interior_manager._is_supported_service_building_type(t):
		return st
	return null


## The camp for the other warden (Coop sends it when they join): the save snapshot,
## with them standing a step from where a new day starts, facing the office.
func world_snapshot() -> Dictionary:
	var snap: Dictionary = main._build_save_snapshot("Co-op", "coop")
	snap.erase("player")
	if main.grid_manager != null and main.world_generator != null and main.world_generator.has_method("find_player_spawn_coord"):
		var at: Vector3 = main.grid_manager.grid_to_world(main.world_generator.find_player_spawn_coord()) + Vector3(1.6, 1.0, 0.6)
		snap["player"] = {"position": {"x": at.x, "y": at.y, "z": at.z}}
	return snap


## Where the other warden's figure stands (the camp's 3D world), or null outside a game.
func world_root() -> Node3D:
	return main._world_3d if main._gameplay_started and not main._menu_mode else null


## What the other machine needs to draw you (Coop sends it ~15 times a second): where
## you stand and face, the torch and where it points, how fast you go, whether you are
## inside something (a room, the PC, the bus, the boat) and so out of sight.
func local_warden() -> Dictionary:
	if not main._gameplay_started or main._menu_mode or main._player == null or not is_instance_valid(main._player):
		return {}
	var aim: Dictionary = main._player.get_flashlight_aim() if main._player.has_method("get_flashlight_aim") else {}
	var s := {
		"p": main._player.global_position,
		"y": main._player.rotation.y,
		"t": not aim.is_empty(),
		"d": aim.get("dir", -main._player.global_basis.z),
		"v": Vector2(main._player.velocity.x, main._player.velocity.z).length(),
		"in": main._is_any_interior_open() or (main._lake_trip != null and main._lake_trip.is_active()),
	}
	# On the lake: in the boat (it rows where you row), or across on the keeper's jetty.
	var lake: Dictionary = main._lake_trip.coop_state() if main._lake_trip != null and main._lake_trip.has_method("coop_state") else {}
	if lake.has("boat") or lake.has("ride"):
		var key := "boat" if lake.has("boat") else "ride"
		s[key] = lake[key]
		# Your oars' strokes: their boat strokes as yours does (boat_rig.gd).
		if lake.has("rp"):
			s["rp"] = lake["rp"]
		s["p"] = (lake[key] as Transform3D).origin
		s["in"] = false
		s["t"] = false
	elif lake.has("shore"):
		s["p"] = lake["shore"]
		if bool(lake.get("fish", false)):
			s["act"] = "fish"
		if lake.has("boat_at"):
			s["boat_at"] = lake["boat_at"]
		s["in"] = false
		s["t"] = false
		s["v"] = 0.0
	# In a room: which, which part of it and the job your hands are on.
	var room: Dictionary = main._interior_manager.coop_room() if main._interior_manager != null and main._interior_manager.has_method("coop_room") else {}
	if not room.is_empty():
		s["room"] = room
	# At night in a room: its windows (where in the camp, which way, the curtain, how
	# squarely you look at it), for the host's Photographer to come to (tourist_brain.gd).
	if bool(s["in"]) and main._is_enemy_night_active() and main._interior_manager != null and main._interior_manager.has_method("photo_windows"):
		var pw: Array = []
		for w in main._interior_manager.photo_windows():
			# (Last, where its camera looks out from: on the line from there through the
			# glass the Silent Man shows in that window however slant it is looked through.)
			pw.append([(w["pos"] as Vector3).snapped(Vector3.ONE * 0.01), (w["out"] as Vector3).snapped(Vector3.ONE * 0.01),
				snappedf(float(w.get("open", 1.0)), 0.05), snappedf(float(w.get("facing", 0.0)), 0.05),
				(w.get("view", w["pos"]) as Vector3).snapped(Vector3.ONE * 0.01)])
		if not pw.is_empty():
			s["pw"] = pw
	# Your health, for the host's enemies to know a hit will be your last (their kills).
	s["hp"] = main._player_health
	# On a bus (one bus for both: town_trip.gd, bus_ride.gd).
	var trip = main._interior_manager.get("_town_trip") if main._interior_manager != null else null
	var bus: Dictionary = trip.coop_state() if trip != null and trip.has_method("coop_state") else {}
	if not bus.is_empty():
		s["bus"] = bus
	# Line 380's rounds (scripts/town/bus_line.gd): the host's word on what they wait and
	# pull in for, so the bus is in the same place on every machine.
	var ln: Dictionary = trip.coop_line() if trip != null and trip.has_method("coop_line") else {}
	if not ln.is_empty():
		s["ln"] = ln
	# In a place in Lesna (the pub, the Jednota...): the other sees you there with them.
	var town_place: String = trip.coop_place() if trip != null and trip.has_method("coop_place") else ""
	if town_place != "":
		s["tr"] = town_place
	# Down the sewer's pipes: where, for the other warden down there too (pipe_mate.gd).
	if main._sewer_pipe_minigame != null and main._sewer_pipe_minigame.is_open() and main._sewer_pipe_minigame.has_method("coop_pipe_state"):
		var pipe: Dictionary = main._sewer_pipe_minigame.coop_pipe_state()
		if not pipe.is_empty():
			s["pipe"] = pipe
	# In an attraction: the other machine places you in it (scripts/attractions/warden_play.gd).
	var att: Dictionary = main._warden_play.coop_state() if main._warden_play != null and is_instance_valid(main._warden_play) else {}
	if not att.is_empty():
		s["att"] = att
	# Behind the corn stand: stood behind its counter at the pot (the close-up hides you).
	var corn = main._interior_manager.get("_corn_stand") if main._interior_manager != null else null
	if corn != null and is_instance_valid(corn) and corn.visible:
		var stand = corn.get("_stand")
		if stand != null and is_instance_valid(stand):
			s["p"] = (stand as Node3D).global_transform * Vector3(0.0, 0.0, -0.85)
			s["in"] = false
			s["t"] = false
			s["v"] = 0.0
			s["act"] = "cook"
	# Crouched or on your belly, or something carried in your arms (player_controller
	# stance, scripts/ambient/carry.gd): the other machine draws that pose.
	if not s.has("act") and main._player != null and not bool(s.get("in", false)):
		var stance := int(main._player.get("stance")) if main._player.get("stance") != null else 0
		var carry: Node = main.get_tree().get_first_node_in_group("carry")
		var carried: String = carry.coop_pose() if carry != null else ""
		if carry != null and str(carry.coop_held()) != "":
			s["cr"] = str(carry.coop_held())
		if stance == 2:
			s["act"] = "prone"
		elif stance == 1:
			s["act"] = "crouch"
		elif carried != "":
			s["act"] = carried
	# At work out in the camp: holding R at something, a branch sawn, rubbish bagged.
	if not s.has("act"):
		var chore: String = main._day_events.coop_work() if main._day_events != null and main._day_events.has_method("coop_work") else ""
		if chore != "":
			s["act"] = chore
		elif main._maintenance != null and main._maintenance.has_method("coop_working") and main._maintenance.coop_working():
			s["act"] = "fix"
	# Knocked down, lying there.
	if main._coop_down:
		s["dn"] = true
		s["t"] = false
	# In bed (the night passes only when both are: camp_office.gd).
	if main.camp_office != null and is_instance_valid(main.camp_office) and main.camp_office.in_bed():
		s["z"] = true
		if main.camp_office.eyes_shut():
			s["zs"] = true
	return s


## The host's clock, weather, power and till for the other machine.
func clock() -> Dictionary:
	var state = INSTANCE.core(main).get_state()
	var night_passing: bool = main.camp_office != null and is_instance_valid(main.camp_office) and main.camp_office.is_fast_forwarding()
	var c := {"d": main._day_index, "h": main._time_of_day_hours, "w": main._weather_state, "pw": main._is_grid_powered(), "m": int(state.money) if state != null else 0, "sl": night_passing, "mq": till_acked}
	# The nights slept here, what keeps the others from sleeping (camp_office.gd).
	if main.camp_office != null and is_instance_valid(main.camp_office):
		c["sln"] = main.camp_office.nights_passed
		if main.camp_office.kept_awake_here():
			c["ka"] = true
	var pace: float = main.clock_pace()
	if pace != 1.0:
		c["cs"] = pace
	var build: float = main.weather_system.storm_build() if main.weather_system != null else 0.0
	if build > 0.0:
		c["sb"] = snappedf(build, 0.01)
	if main._coop_night != null:
		c["sn"] = main._coop_night.sanity_by_peer()
	return c


## The other warden's machine sets its day, sky, weather, lamps and till by the host's.
func apply_clock(c: Dictionary) -> void:
	if not INSTANCE.coop(main).is_client() or not main._gameplay_started or main._menu_mode:
		return
	var state = INSTANCE.core(main).get_state()
	if state != null:
		var day := maxi(1, int(c.get("d", main._day_index)))
		if int(state.day) != day:
			state.day = day
		var acked = c.get("mq", {})
		_follow_till(int(c.get("m", state.money)), int((acked as Dictionary).get(main.multiplayer.get_unique_id(), 0)) if acked is Dictionary else 0)
	if main.time_system != null:
		clock_pace = float(c.get("cs", 1.0))
		var told := float(c.get("h", main._time_of_day_hours))
		var off: float = told - float(main.time_system.time_of_day_hours)
		if absf(off) > COOP_CLOCK_SNAP:
			# (Over midnight too: with the new day from the same word.)
			main.time_system.set_time_hours(told)
			clock_off = 0.0
		else:
			clock_off = off
	if main._coop_night != null and c.get("sn") is Dictionary and (c["sn"] as Dictionary).has(main.multiplayer.get_unique_id()):
		main._coop_night.take_own_sanity(float(c["sn"][main.multiplayer.get_unique_id()]))
	var w := int(c.get("w", main._weather_state))
	if main.weather_system != null and w != main._weather_state:
		main.weather_system.set_weather(w)
	main._coop_storm_build = float(c.get("sb", 0.0))
	var pw := bool(c.get("pw", true))
	if pw != main._coop_powered:
		main._coop_powered = pw
		main._note_grid_power(pw)
		main._apply_time_from_clock(true, false)
	main._sync_runtime_state_from_systems()


## The other warden's clock runs by itself between the host's words (four a second, the first
## to go when the line is busy): what is worked out from it every frame moved in steps (the
## user 7. 11.: "the bus ride goes at two frames a second for the guest; the host's is fine":
## the road, the bus and the guests on it are all the clock's). A word only brings it back in
## line, softly; far out, at once.
const COOP_CLOCK_SNAP := 0.05
const COOP_CLOCK_EASE := 0.02
var clock_off := 0.0
var clock_pace := 1.0


func run_clock(delta: float) -> void:
	var step := maxf(delta, 0.0) * clock_pace * float(main.time_system.game_hours_per_real_second)
	var fix := clampf(clock_off, -COOP_CLOCK_EASE * delta, COOP_CLOCK_EASE * delta)
	clock_off -= fix
	# Midnight is the host's word: the day and the hour turn over together.
	main.time_system.set_time_hours(minf(float(main.time_system.time_of_day_hours) + step + fix, 23.9999))
