extends RefCounted

## Room preparation rules (pure): what has to be done in a tent or a cabin before a
## guest can move in, and the life cycle of a room.
##
##   unprepared  built, never made up            -> tasks to do
##   dirty       the last guests have left       -> tasks to do (again)
##   ready       every task done                 -> guests can check in
##
## Whether a room is occupied is not a status: it follows from the guests in it. A
## room shared by two parties stays ready while either is in it and turns dirty when
## the last one leaves. Saves from before this system said "clean": read as ready.
##
## Each task is done inside the interior by holding the mouse on the thing that needs
## doing (scripts/interior_tasks.gd). `seconds` is how long the hold takes.
##
## The bed is always there; the rest is the mess (core/systems/mess_rules.gd): every
## time a room goes dirty it gets a new seed and level, so the mess is somewhere else
## each time and worse after a party of lads than after a quiet pensioner.

const MESS_RULES = preload("res://core/systems/mess_rules.gd")

const STATUS_UNPREPARED := "unprepared"
const STATUS_DIRTY := "dirty"
const STATUS_READY := "ready"

## The bed task per room kind (the rest of the list is the mess).
const BED_TASKS := {
	"tent": {"id": "bed", "label": "Roll out the sleeping bag", "verb": "Rolling out", "seconds": 1.6, "sfx": "task_bed.mp3"},
	"cabin": {"id": "bed", "label": "Make the bed", "verb": "Making the bed", "seconds": 2.0, "sfx": "task_bed.mp3"},
}


## "tent" / "cabin" / "" for anything that is not a room.
static func kind_for(building_type: String) -> String:
	var t := building_type.to_lower()
	if t.begins_with("tent"):
		return "tent"
	if t.begins_with("cabin"):
		return "cabin"
	return ""


## `mess` is the room's {seed, level, archetypes, fresh}; empty = a middling mess.
static func tasks_for(building_type: String, mess: Dictionary = {}) -> Array:
	var kind := kind_for(building_type)
	if kind.is_empty():
		return []
	var m := mess if not mess.is_empty() else {"seed": building_type.hash(), "level": 1}
	# The basic cabin has no bathroom (its bucket is outside the room you can enter).
	return MESS_RULES.room_tasks(kind, has_bathroom(building_type), m, (BED_TASKS[kind] as Dictionary).duplicate())


static func has_bathroom(building_type: String) -> bool:
	var t := building_type.to_lower()
	return t == "cabin_2" or t == "cabin_3"


static func task(building_type: String, task_id: String, mess: Dictionary = {}) -> Dictionary:
	for t in tasks_for(building_type, mess):
		if str(t["id"]) == task_id:
			return t
	return {}


static func normalize_status(status: String) -> String:
	match status.to_lower().strip_edges():
		STATUS_READY, "clean":
			return STATUS_READY
		STATUS_DIRTY:
			return STATUS_DIRTY
		_:
			return STATUS_UNPREPARED


static func all_done(building_type: String, done: Array, mess: Dictionary = {}) -> bool:
	for t in tasks_for(building_type, mess):
		if not done.has(str(t["id"])):
			return false
	return true


static func remaining(building_type: String, done: Array, mess: Dictionary = {}) -> Array:
	var out: Array = []
	for t in tasks_for(building_type, mess):
		if not done.has(str(t["id"])):
			out.append(t)
	return out
