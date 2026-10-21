extends RefCounted

## Builder 98 without the wait on its first click (the user, 21. 10.: "the first click on
## Builder hangs"; measured: 1.7 s warm, 4.3 s off a cold disk, nearly all of it loading:
## its scripts, a hundred and sixty pictures of the buildings in four views, the icons,
## the little people). The PC's boot starts it (os_shell._start_boot): the loader's threads
## read everything under the Builder's art and its scripts while the BIOS counts and Okna
## comes up, and keeps them, so the first click finds them in the cache.

const ROOTS := ["res://assets/textury/builder/", "res://assets/sfx/builder/"]
const SCRIPTS := ["res://scripts/builder_module.gd", "res://scripts/os98/apps/builder_app.gd"]
## How many to start at once (the loader queues the rest; the game goes on drawing).
const BATCH := 24

static var _todo: PackedStringArray = PackedStringArray()
static var _pending: Array = []
static var _held: Array = []
static var _started := false


static func start() -> void:
	if _started:
		return
	_started = true
	for r in ROOTS:
		_collect(r)
	# Taken from the end: the scripts first.
	for s in SCRIPTS:
		_todo.append(s)


## Each frame from the shell: a few more asked for, the finished ones kept.
static func poll() -> void:
	if not _started:
		return
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


static func done() -> bool:
	return _started and _todo.is_empty() and _pending.is_empty()


static func _collect(dir: String) -> void:
	for e in ResourceLoader.list_directory(dir):
		if e.ends_with("/"):
			_collect(dir + e)
		elif e.get_extension().to_lower() in ["png", "jpg", "webp", "mp3", "ogg", "wav"]:
			_todo.append(dir + e)
