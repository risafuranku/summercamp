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

const STATUS_UNPREPARED := "unprepared"
const STATUS_DIRTY := "dirty"
const STATUS_READY := "ready"

const TASKS := {
	"tent": [
		{"id": "bed", "label": "Roll out the sleeping bag", "verb": "Rolling out", "seconds": 1.6},
		{"id": "floor", "label": "Pick up the litter", "verb": "Picking up", "seconds": 1.3},
	],
	"cabin": [
		{"id": "bed", "label": "Make the bed", "verb": "Making the bed", "seconds": 2.0},
		{"id": "floor", "label": "Clear away the bottles", "verb": "Clearing up", "seconds": 1.5},
		{"id": "bathroom", "label": "Scrub the toilet", "verb": "Scrubbing", "seconds": 2.2},
	],
}


## "tent" / "cabin" / "" for anything that is not a room.
static func kind_for(building_type: String) -> String:
	var t := building_type.to_lower()
	if t.begins_with("tent"):
		return "tent"
	if t.begins_with("cabin"):
		return "cabin"
	return ""


static func tasks_for(building_type: String) -> Array:
	var out := (TASKS.get(kind_for(building_type), []) as Array).duplicate(true)
	# The basic cabin has no bathroom (its bucket is outside the room you can enter).
	if not has_bathroom(building_type):
		out = out.filter(func(t): return str(t["id"]) != "bathroom")
	return out


static func has_bathroom(building_type: String) -> bool:
	var t := building_type.to_lower()
	return t == "cabin_2" or t == "cabin_3"


static func task(building_type: String, task_id: String) -> Dictionary:
	for t in tasks_for(building_type):
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


static func all_done(building_type: String, done: Array) -> bool:
	for t in tasks_for(building_type):
		if not done.has(str(t["id"])):
			return false
	return true


static func remaining(building_type: String, done: Array) -> Array:
	var out: Array = []
	for t in tasks_for(building_type):
		if not done.has(str(t["id"])):
			out.append(t)
	return out
