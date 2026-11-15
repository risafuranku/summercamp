extends RefCounted

## What the night director sees (out of main.gd 15. 11.): the night and the camp (the hour,
## the swell, the guests by kind and who sleeps, the omens' pressure), where you are (office,
## back room, out lit or dark, a room, the lake, a job, away) and how (walking, by a lamp,
## at the window, coming in); tick() asks the director what to do and runs it, in co-op on
## the warden it presses (scripts/coop/coop_night.gd) and those with them. The song at the
## end of the world (caretaker_context) and the omens (omen_context) read the same camp.

const NIGHT_SWELL = preload("res://core/systems/night_swell.gd")
const OMENS_SCRIPT = preload("res://scripts/omens.gd")

var main: Node
## The camp's side, read twice a second (slow_context), and when.
var slow: Dictionary = {}
var slow_at := 0
## You were in the office or the back room the last tick (coming in is an event); the other
## warden likewise.
var was_inside := false
var other_inside := false


func _init(main_node: Node) -> void:
	main = main_node


func tick() -> void:
	if main._director == null or main._director_fx == null or main.get_tree().paused:
		return
	var ctx := context()
	# Co-op: the night presses on one warden at a time (scripts/coop/coop_night.gd); what
	# it does to another happens on their machine, and to those with them too.
	var target := "host"
	if Coop.is_host() and Coop.has_partner() and main._coop_night != null:
		target = main._coop_night.director_target()
		if target != "host":
			ctx = context_other(ctx, main._coop_night.peer_of(target))
	var id: String = main._director.tick(main.get_process_delta_time(), ctx)
	if id != "" and target != "host":
		var peer: int = main._coop_night.peer_of(target)
		Coop.send_night_event("fx", [id], peer)
		for with_them in main._coop_night.near(target):
			if int(with_them) == 1:
				main._director_fx.run(id, context())
			elif int(with_them) != peer:
				Coop.send_night_event("fx", [id], int(with_them))
		main._director.watch(id, ctx["pos"])
		return
	if id != "":
		var at: Vector3 = main._director_fx.run(id, ctx)
		main._director.watch(id, at)
		if Coop.is_host() and Coop.has_partner() and main._coop_night != null:
			for with_you in main._coop_night.near("host"):
				Coop.send_night_event("fx", [id], int(with_you))
		# The log names the guest who stood outside.
		if id == "guest_out" and not main._director.log.is_empty():
			if at == Vector3.INF:
				main._director.log.pop_back()
			else:
				main._director.log.back()["who"] = str(main._director_fx.guest_seen.get("name", "A guest"))


func context() -> Dictionary:
	var hour: float = main._time_of_day_hours
	var night := hour >= 21.0 or hour < 5.5
	# The camp's side (guests, pressure) changes slowly: twice a second is plenty.
	var now := Time.get_ticks_msec()
	if now - slow_at > 500 or slow.is_empty():
		slow_at = now
		slow = slow_context()
	var base: Dictionary = slow["base"]
	var where := place()
	var inside: bool = where == "office" or where == "back_room"
	var entering: bool = inside and not was_inside
	was_inside = inside or where == "modal"
	var pos: Vector3 = main._player.global_position if main._player != null else Vector3.ZERO
	var vel: Vector3 = main._player.velocity if main._player != null else Vector3.ZERO
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	var curtain = bi.get("_office_curtain") if bi != null else null
	var by_arch: Dictionary = slow["by_arch"]
	return {
		"night": night and main._gameplay_started and not main._game_over_active,
		"quiet": main._day_index <= main.QUIET_NIGHTS,
		"swell": float(CoreRoot.get_state().night_swell),
		"build": NIGHT_SWELL.build(hour),
		"hour": hour,
		"place": where,
		"pos": pos,
		"pressure": float(slow["pressure"]),
		"guests_by_arch": by_arch,
		"sleepers": slow.get("sleepers", []),
		"guest_sleeping": not (slow.get("sleepers", []) as Array).is_empty(),
		"admitted": int(base.get("admitted", 0)),
		"hunting": int(base.get("hunting", 0)),
		"hunter_near_m": float(main._senses.nearest),
		"dark": bool(base.get("dark", false)),
		"lamp_near": main.building_manager != null and float(main.building_manager.get_light_level_at(pos)) > 0.2,
		"haunted_near": main._day_events != null and where.begins_with("out") and main._day_events.haunted_near(pos, 14.0) != Vector3.INF,
		"walking": Vector2(vel.x, vel.z).length() > 0.8,
		# (Not with you at the PC, your back to it: the office's strongest scare went by unseen.)
		"window_open": (curtain == null or float(curtain.get("open")) > 0.5) and not main._is_crt_desktop_active(),
		"looking_at_window": bi != null and bi.has_method("is_looking_at_window") and bi.is_looking_at_window(),
		"entering": entering,
		# A run of things may end in the breaker going (night_director.RUNS).
		"can_trip": main._night_jobs != null and main._night_jobs.has_method("can_trip_breaker") and main._night_jobs.can_trip_breaker(),
	}




## Co-op: the night's context as another warden (`peer`) is in it (where they are, in the
## light or the dark, walking), the camp's side as it is.
func context_other(ctx: Dictionary, peer: int) -> Dictionary:
	var s: Dictionary = Coop.state_of(peer)
	var room: Dictionary = s.get("room", {})
	var pos: Vector3 = s.get("p", Vector3.ZERO)
	var where := "out_dark"
	if s.has("boat") or s.has("boat_at") or s.has("ride"):
		where = "lake"
	elif str(room.get("t", "")) == "office":
		where = "back_room" if str(room.get("s", "")) == "back" else "office"
	elif bool(s.get("in", false)):
		where = "room"
	elif main.building_manager != null and float(main.building_manager.get_light_level_at(pos)) > 0.2:
		where = "out_lit"
	var inside: bool = where == "office" or where == "back_room"
	var out := ctx.duplicate()
	out["place"] = where
	out["pos"] = pos
	out["walking"] = float(s.get("v", 0.0)) > 0.8
	out["lamp_near"] = where == "out_lit"
	out["haunted_near"] = main._day_events != null and where.begins_with("out") and main._day_events.haunted_near(pos, 14.0) != Vector3.INF
	out["looking_at_window"] = false
	out["hunter_near_m"] = 99.0
	out["entering"] = inside and not other_inside
	other_inside = inside
	return out


func slow_context() -> Dictionary:
	var base := omen_context()
	var by_arch := {}
	var sleepers: Array = []
	# Everyone checked in, awake or asleep: at night they are all "sleep".
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			var a := str((g as Dictionary).get("archetype", ""))
			by_arch[a] = int(by_arch.get(a, 0)) + 1
			if str((g as Dictionary).get("status", "")) == "sleep":
				sleepers.append({"id": int(g.get("id", -1)), "name": str(g.get("name", "")), "sprite_path": GuestManager._sprite_path_for_archetype(a)})
	return {"base": base, "by_arch": by_arch, "sleepers": sleepers, "pressure": OMENS_SCRIPT.pressure(base)}


## Where you are, for the director: office, back_room, out_lit, out_dark, or somewhere
## it leaves alone (modal: a close-up or the desk; job; lake; room: a guest's room).
func place() -> String:
	if main._lake_trip != null and main._lake_trip.is_active():
		return "lake"
	if main._away_in_town():
		return "away"
	if (main._sewer_pipe_minigame != null and main._sewer_pipe_minigame.is_open()) or (main._utility_repair_minigame != null and main._utility_repair_minigame.is_open()):
		return "job"
	if main._breaker_panel != null and is_instance_valid(main._breaker_panel) and main._breaker_panel.visible:
		return "job"
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	if bi != null and bi.is_open():
		var ex = bi.get("_extras")
		if ex != null and ex.is_modal():
			return "modal"
		return "back_room" if ex != null and ex.in_back_room() else "office"
	if main._is_any_interior_open():
		return "room"
	var pos: Vector3 = main._player.global_position if main._player != null else Vector3.ZERO
	return "out_lit" if main.building_manager != null and float(main.building_manager.get_light_level_at(pos)) > 0.2 else "out_dark"


## What the song at the end of the world asks (scripts/audio/caretaker.gd): not the
## director's context, which is its own to read (it notices you coming in).
func caretaker_context() -> Dictionary:
	var hour: float = main._time_of_day_hours
	var where := place()
	var bi = main._interior_manager.get("_building_interior") if main._interior_manager != null else null
	var set_dread = bi.get("_dread") if bi != null else null
	var vel: Vector3 = main._player.velocity if main._player != null else Vector3.ZERO
	return {
		"night": (hour >= 21.0 or hour < 5.5) and main._gameplay_started and not main._game_over_active,
		"quiet": main._day_index <= main.QUIET_NIGHTS,
		"place": where,
		"dread": float(set_dread.get("dread")) if set_dread != null else 0.0,
		"tension": float(main._director.tension),
		"near_m": float(main._senses.nearest),
		"walking": Vector2(vel.x, vel.z).length() > 0.8,
		"set_beside": (where == "office" or where == "back_room") and bi != null and bi.get("_radio_power_on") == true and bi.get("_grid_power_available") == true,
	}


## What the night presses on the camp with, for scripts/omens.gd.
func omen_context() -> Dictionary:
	var mood: Dictionary = GuestManager.get_camp_mood_summary() if GuestManager != null and GuestManager.has_method("get_camp_mood_summary") else {}
	var hunting := 0
	for b in main._enemy_brains:
		if b != null and b.get("_night_active") != false:
			hunting += 1
	return {
		"guests": int(mood.get("guests", 0)),
		"unhappy": int(mood.get("unhappy", 0)),
		"kinds_seen": main._week_ledger.kinds_seen() if main._week_ledger != null else 0,
		"nights_visited": main._week_ledger.nights_visited() if main._week_ledger != null else 0,
		"hunting": hunting,
		"dark": not main._is_grid_powered(),
		"admitted": main._desk_strangers_admitted(),
	}
