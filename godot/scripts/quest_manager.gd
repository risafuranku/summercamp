extends Node

## "Vera's Checklist": the guided questline that teaches the loop and then keeps
## handing out goals.
##
## Each step is data (STEPS): what to do, the mail Teta Vera sends when the step
## starts, the reward, and a condition id checked every half second against the real
## game state (CoreRoot, GuestManager, EmailManager, main). Steps can also complete
## from events that main forwards through notify() (CRT opened, guest talked to).
##
## The questline also owns the story mail pool: on a new game it schedules
## data/pools/emails/story/*.json, which nothing delivered before.
##
## Persistence: export_state()/import_state() go into the save snapshot under "quests".

signal step_started(step_id: String)
signal step_completed(step_id: String)

const VERA := "Teta Vera <vera.kralova@rodina.cz>"
const TRACKER_TITLE := "VERA'S CHECKLIST"
const POLL_SEC := 0.5
const WAYPOINT_LABELS := {"reception": "Office", "gate": "Gate", "unready_room": "Make up", "first_guest": "Guest"}
const FIRST_BOOKING_NAME := "Mirek Dvorak"

## Story-pool mails the questline replaces with its own task mails.
const STORY_SUBJECTS_OWNED := ["You are in charge this week"]

const STEPS: Array[Dictionary] = [
	{
		"id": "read_vera",
		"text": "Open CampMail and read Aunt Vera's email.",
		"hint": "The envelope icon on the desktop.",
		"reward": 0,
		"mail_subject": "You are in charge this week",
		"mail_body": "I am out for seven days. You run the camp now.\n\nEverything happens through this terminal. Read every mail. Bookings have an Accept and a Reject button - use both. Rejecting is not rude, it is management.\n\nFirst job: we have no beds. Open Beeternet (it dials the modem, let it squeal), go to www.stavitel98.cz and download Builder 98. The setup program lands in the Download folder on the desktop. Run it. Then clear some trees and put up a tent.\n\nI left you $850. Do not spend it on the slide.\n\n- Teta Vera",
	},
	{
		"id": "install_builder",
		"text": "Download Builder 98 from www.stavitel98.cz and run its setup.",
		"hint": "Beeternet > Stavitel software > BLDR98SW.EXE, then open it from the Download folder.",
		"reward": 50,
	},
	{
		"id": "build_housing",
		"text": "Bulldoze some trees and build your first tent or cabin.",
		"hint": "Builder: bulldozer, then Housing.",
		"reward": 100,
		"mail_subject": "Beds first",
		"mail_body": "Good, the builder works. Now beds.\n\nTrees are free to cut but the bulldozer costs a little per tile. A tent is cheap and holds one guest. A cabin holds two and they sleep better in it - a guest who slept well pays and smiles.\n\nNo beds, no bookings. No bookings, no money.\n\n- V.",
	},
	{
		"id": "build_toilet",
		"text": "Guests need a toilet. Build a Toilet Block near the beds.",
		"hint": "Builder: Services > Toilet.",
		"reward": 150,
		"mail_subject": "About the bushes",
		"mail_body": "Before anyone sleeps here: a toilet.\n\nPeople without a toilet use the bushes, and then they write reviews. The toilets need the sewer to work - it is the green hatch by the lake. If it ever clogs, somebody has to crawl in there. That somebody is you.\n\n- V.",
	},
	{
		"id": "accept_booking",
		"text": "A booking just arrived. Open CampMail and ACCEPT it.",
		"hint": "Check the NIGHT RISK line before you accept.",
		"reward": 0,
		"scripted_booking": true,
	},
	{
		"id": "make_up_room",
		"text": "Mirek reaches the barrier in about an hour. Get up from the desk, go to the tent and make it up.",
		"hint": "Esc gets you up. Inside, hold the mouse on what needs doing.",
		"reward": 60,
		"waypoint": "unready_room",
		"mail_subject": "You can get up, you know",
		"mail_body": "Somebody is coming. He will be at the barrier within the hour and he will not stand there all day.\n\nThe computer is not the camp. Get up, go outside, find the tent you built and make it up: the sleeping bag, the rubbish the last people left. When it is ready the barrier goes up for him, not before.\n\nEvery bed, every time. That is the job.\n\n- V.",
	},
	{
		"id": "welcome_guest",
		"text": "Your first guest is in. Go and say hello.",
		"hint": "Look at a guest and press E.",
		"reward": 60,
		"waypoint": "first_guest",
	},
	{
		"id": "feed_guests",
		"text": "Guests get hungry. Build a Jednota Mart, a Bistro or a Pub.",
		"hint": "Builder: Services. Food needs power.",
		"reward": 120,
		"mail_subject": "People eat",
		"mail_body": "You will notice the guests wandering around looking lost. They are hungry. The Jednota is cheap, the Bistro is proper food, the Pub is beer with a sandwich next to it.\n\nWatch their faces on the status bar. A grumpy camp is a noisy camp, and a noisy camp at night attracts... noise.\n\n- V.",
	},
	{
		"id": "light_paths",
		"text": "Nights here are dark. Put up 2 lamp posts.",
		"hint": "Builder: Lamp. Guests feel safer under light.",
		"reward": 80,
	},
	{
		"id": "survive_night",
		"text": "Night is coming. Stay alive until 06:30.",
		"hint": "Keep your flashlight on. Run from what you hear. Hide indoors.",
		"reward": 200,
		"mail_subject": "Tonight",
		"mail_body": "When it gets dark the builder locks. That is not a bug, that is the camp.\n\nIf you hear footsteps where there is nobody, turn around. If something follows you, run and get inside - the office, a cabin, the toilets. Do not stand in the dark staring at it.\n\nThe forecast on the status bar is honest. The more of one kind of guest you take, the worse the night. Unhappy guests count double.\n\nSee you in the morning. Please.\n\n- V.",
	},
	{
		"id": "pay_bill",
		"text": "The electricity bill arrived. Pay it in CampStat before it is overdue.",
		"hint": "No CampStat yet? The power company gives it away at www.campgrid.cz.",
		"reward": 50,
	},
	{
		"id": "good_review",
		"text": "Earn a 4-star review from a departing guest.",
		"hint": "Happy guests: food, toilets, showers, fun, a good bed.",
		"reward": 250,
	},
	{
		"id": "grow_camp",
		"text": "Host 6 guests at the same time.",
		"hint": "More beds. Mix the guest types or the nights get worse.",
		"reward": 300,
		"mail_subject": "Not bad",
		"mail_body": "A review with stars in it. Your uncle framed his first one.\n\nNow grow. Six guests at once and I stop worrying. Mix them - quiet ones, drinkers, the fancy ones. Three of a kind is fine, past that the nights get strange.\n\n- V.",
	},
]

var _main: Node
var _index: int = -1
var _completed: Array[String] = []
var _flags: Dictionary = {}
var _poll: float = 0.0
var _active: bool = false
var _waypoint_kind: String = ""
var _finished_all: bool = false


func setup(main_node: Node) -> void:
	_main = main_node
	name = "QuestManager"
	var bindings := [
		["program_installed", "_on_program_installed"],
		["customer_booking_confirmed", "_on_booking_confirmed"],
		["guest_review_posted", "_on_review_posted"],
		["day_tick", "_on_day_tick"],
		["room_prepared", "_on_room_prepared"],
	]
	for pair in bindings:
		if EventBus.has_signal(pair[0]):
			var cb := Callable(self, pair[1])
			if not EventBus.is_connected(pair[0], cb):
				EventBus.connect(pair[0], cb)


## New game: schedule the story pool and start at step 0.
func begin_new_game() -> void:
	_index = -1
	_completed.clear()
	_flags.clear()
	_finished_all = false
	_active = true
	if EmailManager != null and EmailManager.has_method("load_story_pool"):
		EmailManager.load_story_pool(STORY_SUBJECTS_OWNED)
	_advance()


func export_state() -> Dictionary:
	return {
		"index": _index,
		"step_id": current_step_id(),
		"completed": _completed.duplicate(),
		"flags": _flags.duplicate(true),
		"finished_all": _finished_all,
	}


func import_state(data: Dictionary) -> void:
	_completed.clear()
	for id in data.get("completed", []):
		_completed.append(str(id))
	_flags = (data.get("flags", {}) as Dictionary).duplicate(true) if data.get("flags", {}) is Dictionary else {}
	_finished_all = bool(data.get("finished_all", false))
	# Resolve the step by id: indexes shift when the checklist changes between versions.
	_index = -1
	var step_id := str(data.get("step_id", ""))
	for i in STEPS.size():
		if not step_id.is_empty() and str(STEPS[i]["id"]) == step_id:
			_index = i
	if _index < 0 and not bool(data.get("finished_all", false)):
		for i in STEPS.size():
			if not _completed.has(str(STEPS[i]["id"])):
				_index = i
				break
	if bool(data.get("finished_all", false)):
		_index = STEPS.size()
	_active = true
	if data.is_empty():
		# Save from before the questline existed: start it, but skip steps already done.
		_index = -1
		_advance()
		return
	_push_tracker()


func stop() -> void:
	_active = false
	_hide_waypoint()


## Events forwarded by main: "talked_to_guest".
func notify(event_id: String, _data: Dictionary = {}) -> void:
	_flags[event_id] = true
	_check_current()


func current_step_id() -> String:
	if _index < 0 or _index >= STEPS.size():
		return ""
	return str(STEPS[_index]["id"])


func _process(delta: float) -> void:
	if not _active:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SEC
		_check_current()
		_sync_waypoint()


# ── progression ───────────────────────────────────────────────────────────────

func _advance() -> void:
	_index += 1
	while _index < STEPS.size() and _is_satisfied(str(STEPS[_index]["id"])) and not _needs_action(str(STEPS[_index]["id"])):
		# Already true (e.g. a loaded camp that has a toilet): count it silently.
		var skip_id := str(STEPS[_index]["id"])
		if not _completed.has(skip_id):
			_completed.append(skip_id)
		_index += 1
	if _index >= STEPS.size():
		_finish_all()
		return
	var step: Dictionary = STEPS[_index]
	_start_step(step)


## Steps that must be *done* now, not merely already true.
func _needs_action(step_id: String) -> bool:
	return step_id in ["read_vera", "accept_booking", "make_up_room", "welcome_guest", "survive_night"]


func _start_step(step: Dictionary) -> void:
	var id := str(step["id"])
	if id == "welcome_guest":
		_flags.erase("talked_to_guest")
	if step.has("mail_subject"):
		_send_task_mail(step)
	if bool(step.get("scripted_booking", false)):
		_send_first_booking()
	if id == "survive_night":
		_flags["survive_start_day"] = _day()
	_push_tracker()
	step_started.emit(id)


func _check_current() -> void:
	if not _active or _index < 0 or _index >= STEPS.size():
		return
	var id := str(STEPS[_index]["id"])
	if _is_satisfied(id):
		_complete_current()


func _complete_current() -> void:
	var step: Dictionary = STEPS[_index]
	var id := str(step["id"])
	if not _completed.has(id):
		_completed.append(id)
	var reward := int(step.get("reward", 0))
	if reward > 0 and CoreRoot.actions != null and CoreRoot.actions.has_method("add_money"):
		CoreRoot.actions.add_money(reward)
	var hud := _hud()
	if hud != null:
		var sub := "+$%d" % reward if reward > 0 else ""
		hud.show_banner("TASK COMPLETE", sub, Color(0.46, 0.86, 0.36), 2.6)
		hud.push_status("Checklist: %s" % str(step["text"]).split(".")[0], 1)
	_play_complete_sound()
	step_completed.emit(id)
	_advance()


func _finish_all() -> void:
	_finished_all = true
	_hide_waypoint()
	var hud := _hud()
	if hud != null:
		hud.set_objective({
			"title": TRACKER_TITLE,
			"text": "Checklist done. Keep the camp alive until Vera is back (day 8).",
			"progress": "%d/%d" % [STEPS.size(), STEPS.size()],
		})
	if EmailManager != null and not bool(_flags.get("final_mail_sent", false)):
		_flags["final_mail_sent"] = true
		EmailManager.push_system_mail({
			"from": VERA, "sender": VERA, "type": "task",
			"subject": "You did everything on my list",
			"body": "Every box ticked. I did not expect that, and I mean it kindly.\n\nNow just keep them alive and keep them happy until I am back. Watch the forecast. Pay the bills. Crawl into the sewer if you must.\n\n- Teta Vera",
			"day": _day(), "time": _time_str(),
		})


# ── conditions ────────────────────────────────────────────────────────────────

func _is_satisfied(step_id: String) -> bool:
	match step_id:
		"read_vera":
			var mail: Dictionary = EmailManager.find_mail("task_id", "read_vera") if EmailManager != null else {}
			return not mail.is_empty() and bool(mail.get("_read", false))
		"install_builder":
			return bool(_flags.get("builder_installed", false)) or _builder_unlocked()
		"build_housing":
			return int(GuestManager.get_bed_metrics().get("capacity", 0)) > 0
		"build_toilet":
			return _count_buildings(["toilet_block"]) > 0
		"accept_booking":
			return bool(_flags.get("booking_accepted", false))
		"make_up_room":
			return bool(_flags.get("room_prepared", false)) or _first_guest_in()
		"welcome_guest":
			return bool(_flags.get("talked_to_guest", false))
		"feed_guests":
			return _count_buildings(["vecerka", "restaurant", "pub"]) > 0
		"light_paths":
			return _count_buildings(["lamp_post"]) >= 2
		"survive_night":
			var start_day := int(_flags.get("survive_start_day", _day()))
			return _day() > start_day and not _is_night_now()
		"pay_bill":
			return _bills_all_paid_and_some_exist()
		"good_review":
			return bool(_flags.get("good_review", false))
		"grow_camp":
			return int(GuestManager.get_bed_metrics().get("occupied", 0)) >= 6
	return false


func _on_program_installed(app_id: String) -> void:
	if app_id == "builder":
		_flags["builder_installed"] = true
	_check_current()


func _on_booking_confirmed(_mail: Dictionary) -> void:
	_flags["booking_accepted"] = true
	_check_current()


func _on_review_posted(review: Dictionary) -> void:
	if int(review.get("rating", 0)) >= 4:
		_flags["good_review"] = true
	_check_current()


func _on_room_prepared(_key: String) -> void:
	if current_step_id() == "make_up_room":
		_flags["room_prepared"] = true
	_check_current()


func _first_guest_in() -> bool:
	for g in GuestManager.get_guest_life_snapshot():
		if str((g as Dictionary).get("status", "")) in ["active", "sleep"]:
			return true
	return false


func _on_day_tick(_day_index: int) -> void:
	_check_current()


func _builder_unlocked() -> bool:
	var shell = _crt_shell()
	if shell != null and shell.has_method("_is_program_unlocked"):
		return bool(shell.call("_is_program_unlocked", "builder"))
	return false


func _crt_shell() -> Node:
	var im = _main.get("_interior_manager") if _main != null else null
	if im == null:
		return null
	var bi = im.get("_building_interior")
	if bi == null:
		return null
	return bi.get("_crt_ui")


func _bills_all_paid_and_some_exist() -> bool:
	if _main == null or not _main.has_method("get_electricity_ui_snapshot"):
		return false
	var snap: Dictionary = _main.get_electricity_ui_snapshot()
	var bills: Array = snap.get("bills", []) if snap.get("bills", []) is Array else []
	if bills.is_empty():
		return false
	for bill_any in bills:
		if bill_any is Dictionary and str((bill_any as Dictionary).get("status", "")) != "paid":
			return false
	return true


func _count_buildings(types: Array) -> int:
	var state = CoreRoot.get_state()
	if state == null or state.grid == null:
		return 0
	var n := 0
	for coord in state.grid.cells.keys():
		var cell: Dictionary = state.grid.cells[coord]
		if cell.get("root_coord", coord) != coord:
			continue
		if types.has(str(cell.get("type", ""))):
			n += 1
		elif types.has("lamp_post") and str(cell.get("type", "")) == "path" and bool(cell.get("lamp", false)):
			n += 1
	return n


# ── mails ─────────────────────────────────────────────────────────────────────

func _send_task_mail(step: Dictionary) -> void:
	if EmailManager == null:
		return
	var id := str(step["id"])
	if not EmailManager.find_mail("task_id", id).is_empty():
		return
	var reward := int(step.get("reward", 0))
	var body := str(step.get("mail_body", ""))
	var task_line := "\n\n[TASK] %s" % str(step["text"])
	if reward > 0:
		task_line += "\n[REWARD] $%d" % reward
	EmailManager.push_system_mail({
		"from": VERA, "sender": VERA, "type": "task",
		"subject": str(step["mail_subject"]),
		"body": body + task_line,
		"task_id": id,
		"reward": reward,
		"day": _day(), "time": _time_str(),
	})


func _send_first_booking() -> void:
	if EmailManager == null or not EmailManager.find_mail("task_id", "accept_booking").is_empty():
		return
	var sender := "%s <mirek.dvorak@seznam.cz>" % FIRST_BOOKING_NAME
	EmailManager.push_system_mail({
		"from": sender, "sender": sender, "type": "customer",
		"subject": "One quiet night, one bed",
		"body": "Hello reception,\n\nI walk the ridge trail and need one bed for one night. I do not snore and I do not drink. I pay cash.\n\nArchetype: Quiet Guy\nArrival: today\nTotal payment per day: $90\n\n- Mirek",
		"task_id": "accept_booking",
		"archetype": "quiet_guy", "difficulty": 1,
		"guests": 1, "party_size": 1, "nights": 1, "stay_nights": 1,
		"arrival_time": _time_str(), "daily_total": 90,
		"night_trouble_time": "22:40",
		"guest_name": FIRST_BOOKING_NAME, "guest_names": [FIRST_BOOKING_NAME],
		"arrival_minutes": 90,
		"day": _day(), "time": _time_str(),
	})


# ── tracker + waypoint ────────────────────────────────────────────────────────

func _push_tracker() -> void:
	var hud := _hud()
	if hud == null:
		return
	if _index < 0 or _index >= STEPS.size():
		if _finished_all:
			_finish_all()
		else:
			hud.clear_objective()
		_hide_waypoint()
		return
	var step: Dictionary = STEPS[_index]
	var reward := int(step.get("reward", 0))
	hud.set_objective({
		"title": "%s %d/%d" % [TRACKER_TITLE, _completed.size() + 1, STEPS.size()],
		"text": str(step["text"]),
		"hint": str(step.get("hint", "")),
		"reward": "$%d" % reward if reward > 0 else "",
	})
	var wp := str(step.get("waypoint", ""))
	if wp.is_empty():
		_hide_waypoint()
	else:
		_show_waypoint(wp)


## The marker itself is drawn by the HUD in screen space (constant size, clamps to the
## screen edge); this only tracks which place it points at.
func _show_waypoint(kind: String) -> void:
	_waypoint_kind = kind
	_sync_waypoint()


func _hide_waypoint() -> void:
	_waypoint_kind = ""
	var hud := _hud()
	if hud != null and hud.has_method("clear_waypoint"):
		hud.clear_waypoint()


## Targets can move (the reception is placed after load), so re-resolve on the poll.
func _sync_waypoint() -> void:
	var hud := _hud()
	if hud == null or not hud.has_method("set_waypoint"):
		return
	var job: Dictionary = _night_job_waypoint()
	if not job.is_empty():
		hud.set_waypoint(job["position"], str(job["label"]))
		return
	if _waypoint_kind.is_empty():
		hud.clear_waypoint()
		return
	var pos := _waypoint_position(_waypoint_kind)
	hud.set_waypoint(pos, WAYPOINT_LABELS.get(_waypoint_kind, ""))


## A night job outranks the checklist: it is happening now.
func _night_job_waypoint() -> Dictionary:
	if _main != null and _main.has_method("night_job_waypoint"):
		return _main.night_job_waypoint()
	return {}


func _waypoint_position(kind: String) -> Vector3:
	var gm = _main.get("grid_manager") if _main != null else null
	if gm == null:
		return Vector3.INF
	match kind:
		"reception":
			if _main.has_method("get_reception_door_position"):
				var door: Vector3 = _main.get_reception_door_position()
				if door != Vector3.INF:
					return door + Vector3(0.0, 2.4, 0.0)
		"gate":
			if GuestManager != null and GuestManager.has_method("get_gate_coord"):
				return gm.grid_to_world(GuestManager.get_gate_coord()) + Vector3(0.0, 1.6, 0.0)
		"unready_room":
			# The first room a coming party is waiting for.
			for row in GuestManager.get_arrivals():
				for r in (row as Dictionary).get("rooms", []):
					if not bool((r as Dictionary).get("ready", true)):
						var parts := str(r["key"]).split(":")
						if parts.size() == 2:
							return gm.grid_to_world(Vector2i(int(parts[0]), int(parts[1]))) + Vector3(0.0, 2.2, 0.0)
		"first_guest":
			for g in GuestManager.get_guest_life_snapshot():
				var lodging = (g as Dictionary).get("lodging", Vector2i(-1, -1))
				if lodging is Vector2i and (lodging as Vector2i).x >= 0:
					return gm.grid_to_world(lodging) + Vector3(0.0, 2.2, 0.0)
	return Vector3.INF


# ── helpers ───────────────────────────────────────────────────────────────────

func _hud() -> Node:
	return _main.get("_hud_manager") if _main != null else null


func _main_call(method: String, fallback: bool) -> bool:
	if _main != null and _main.has_method(method):
		return bool(_main.call(method))
	return fallback


func _day() -> int:
	return maxi(1, CoreRoot.get_day())


func _time_str() -> String:
	var ts = _main.get("time_system") if _main != null else null
	if ts != null and ts.has_method("get_time_string"):
		return ts.get_time_string()
	return "09:00"


func _is_night_now() -> bool:
	return CoreRoot.is_night()


func _play_complete_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/sfx/crtui/tudu.mp3")
	player.volume_db = -6.0
	player.pitch_scale = 1.25
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
