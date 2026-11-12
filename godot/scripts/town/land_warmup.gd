extends Node

## The land round the camp and line 380's buses without a wait in a new camp's first
## frames (the polish pass of 4. 11.: the desk froze 0.5-1.3 s as the PC came on, nearly
## all of it the first loading of the land's and the buses' pictures and sounds; built
## again warm the land takes 25 ms, a bus 25-38 ms; tools/trhnuti_check). Main starts it
## with the boot: the loader's threads read them while the boot and the title are up and
## keep them, so town_trip and the village find them in the cache. Then it goes.
## After them the businesses' stations and pictures (taken from the end of the list): the first
## step into the restaurant froze for 1.3 s, the pub's 0.8 s, the Jednota's 0.5 s, built again
## warm 70-270 ms, nearly all of it compiling their scripts (tools/trhnuti_check --part=bizrooms).

const ROOTS := ["res://assets/sfx/pub/", "res://assets/sfx/bistro/", "res://assets/textury/closeup/food/",
	"res://assets/textury/jednota/", "res://assets/textury/pub/", "res://assets/textury/bistro/",
	"res://scripts/jednota/", "res://scripts/pub/", "res://scripts/bistro/",
	"res://assets/textury/town/", "res://assets/sfx/bus/", "res://assets/sfx/town/",
	# The skies, each read the first time the clock needs it: a hitch at 16:00, 17:45, 18:27...
	"res://assets/textury/skybox/",
	# The motel's inside, its sounds (12. 11.: the corridor's long loops took 57 ms the first
	# time it was made up behind its door; the doors' and the steps' with them).
	"res://assets/sfx/motel/", "res://assets/sfx/backroom/", "res://assets/sfx/rooms/"]
const FILES := ["res://assets/textury/npc/town_pumpar.png", "res://assets/fonts/jersey10.fnt"]
## The motel's inside (the camp's pictures only it uses; its sounds are in ROOTS): since 12. 11.
## the corridor and a room are made up behind their doors as you click them
## (town_room.ready_next), and the first of each froze longer than the rest reading these. The
## list from
## `tools/onesun_check.tscn -- --part=motelwarm` (every place behind the motel's doors made up
## once, what the loader did not have yet); run it again when the motel's inside changes.
const MOTEL := ["bath_basin", "chain_loose", "cleaning_cart", "corridor_carpet", "cuckoo_bird", "hair_clump",
	"hall_phone", "hall_plant", "hall_rubbish", "hall_shoes", "hall_tray", "mirror_cabinet", "mirror_crack",
	"motel_bath_door", "motel_bath_tiles", "motel_door_in", "motel_toilet", "mould_grout", "razor", "roach_0",
	"roach_1", "shower_curtain", "soap_hair", "stove_fire_0", "tiles_brown"]
## How many asked for at once (the loader queues the rest; the boot goes on drawing).
const BATCH := 16

static var _held: Array = []
var _todo := PackedStringArray()
var _pending: Array = []


func _ready() -> void:
	name = "LandWarmup"
	for f in FILES:
		if ResourceLoader.exists(f):
			_todo.append(f)
	for m in MOTEL:
		var f := "res://assets/textury/camp/%s.png" % m
		if ResourceLoader.exists(f):
			_todo.append(f)
	for r in ROOTS:
		_collect(r)


func _process(_delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var p: String = _pending[i]
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_held.append(ResourceLoader.load_threaded_get(p))
		_pending.remove_at(i)
	while _pending.size() < BATCH and not _todo.is_empty():
		var p := _todo[_todo.size() - 1]
		_todo.remove_at(_todo.size() - 1)
		if ResourceLoader.has_cached(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_pending.append(p)
	if _todo.is_empty() and _pending.is_empty():
		queue_free()


func _collect(dir: String) -> void:
	for e in ResourceLoader.list_directory(dir):
		if e.ends_with("/"):
			_collect(dir + e)
		elif e.get_extension().to_lower() in ["png", "jpg", "webp", "mp3", "ogg", "wav", "gd"]:
			_todo.append(dir + e)
