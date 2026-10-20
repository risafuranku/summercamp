extends RefCounted

## Wardens (profiles) and their camps (worlds), playtest 18. 10.: "a profile system, you
## make a profile and give it a name, then you play that profile's saves; a world system
## like Minecraft: New camp generates a new camp, Load camp shows the camps as tiles, a
## camp opens its list of saves; delete a camp, duplicate a camp".
##
##   user://profiles/last.json                      {"profile": id, "camp": id}
##   user://profiles/<profile>/profile.json         {"name", "created", "look_model", "look_color", "lang"}
##       (the look: which warden figure and jacket colour, scripts/coop/warden_looks.gd;
##       the other warden in co-op sees it and the name; lang: the warden's language,
##       "en" or "cs", scripts/lang.gd, set for the whole game when the warden is chosen)
##   user://profiles/<profile>/camps/<camp>/camp.json
##       {"name", "seed", "created", "played", "sandbox", "coop", "day", "money", "guests"}
##   user://profiles/<profile>/camps/<camp>/thumb.png   the camp at its last save
##   user://profiles/<profile>/camps/<camp>/saves/      SaveManager's folder for it
##
## SaveManager (the autoload) reads and writes the active camp's saves/ folder: activate
## a camp before loading or starting it. The saves from before profiles (user://saves)
## are copied into the first warden made, a camp per world seed.

const LANG := preload("res://scripts/lang.gd")
const ROOT := "user://profiles"
const LEGACY := "user://saves"
const THUMB_SIZE := Vector2i(192, 108)

static var profile_id := ""
static var camp_id := ""


# ── files ─────────────────────────────────────────────────────────────────────

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _write(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


static func _dirs(path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for n in d.get_directories():
		out.append(n)
	return out


static func _remove_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(f)))
	for sub in d.get_directories():
		_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _copy_tree(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to))
	var d := DirAccess.open(from)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(from.path_join(f)), ProjectSettings.globalize_path(to.path_join(f)))
	for sub in d.get_directories():
		_copy_tree(from.path_join(sub), to.path_join(sub))


static func _new_id(prefix: String) -> String:
	return "%s%d%04d" % [prefix, int(Time.get_unix_time_from_system()), randi() % 10000]


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func profile_dir(pid: String = profile_id) -> String:
	return ROOT.path_join(pid)


static func camp_dir(cid: String = camp_id, pid: String = profile_id) -> String:
	return profile_dir(pid).path_join("camps").path_join(cid)


# ── start ─────────────────────────────────────────────────────────────────────

## At start: the warden and the camp played last (SaveManager pointed at that camp).
static func boot() -> void:
	var last := _read(ROOT.path_join("last.json"))
	var pid := str(last.get("profile", ""))
	if pid == "" or not FileAccess.file_exists(profile_dir(pid).path_join("profile.json")):
		var all := list_profiles()
		pid = str(all[0]["id"]) if not all.is_empty() else ""
	profile_id = pid
	camp_id = ""
	LANG.apply(profile_lang(pid) if pid != "" else LANG.system_default())
	if pid == "":
		return
	LANG.set_figure(int(profile_look(pid)["m"]))
	var cid := str(last.get("camp", ""))
	if cid != "" and FileAccess.file_exists(camp_dir(cid).path_join("camp.json")):
		activate_camp(cid)
	else:
		var camps := list_camps()
		if not camps.is_empty():
			activate_camp(str(camps[0]["id"]))


static func _remember() -> void:
	_write(ROOT.path_join("last.json"), {"profile": profile_id, "camp": camp_id})


## Saves to nobody's camp from now (the tools' camps): the warden's last camp is kept.
static func detach() -> void:
	camp_id = ""
	_point_saves("")


static func has_profile() -> bool:
	return profile_id != ""


# ── wardens ───────────────────────────────────────────────────────────────────

static func list_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in _dirs(ROOT):
		var p := _read(profile_dir(pid).path_join("profile.json"))
		if p.is_empty():
			continue
		var camps := _dirs(profile_dir(pid).path_join("camps"))
		var played := 0
		for cid in camps:
			played = maxi(played, int(_read(camp_dir(cid, pid).path_join("camp.json")).get("played", 0)))
		out.append({"id": pid, "name": str(p.get("name", "Warden")), "created": int(p.get("created", 0)), "camps": camps.size(), "played": maxi(played, int(p.get("created", 0)))})
	out.sort_custom(func(a, b): return int(a["played"]) > int(b["played"]))
	return out


static func profile_name(pid: String = profile_id) -> String:
	return str(_read(profile_dir(pid).path_join("profile.json")).get("name", ""))


static func rename_profile(pid: String, name: String) -> void:
	var path := profile_dir(pid).path_join("profile.json")
	var p := _read(path)
	if p.is_empty() or name.strip_edges() == "":
		return
	p["name"] = name.strip_edges().left(24)
	_write(path, p)


## The warden's look: {m: figure, c: jacket colour}; m -1 when never chosen.
static func profile_look(pid: String = profile_id) -> Dictionary:
	var p := _read(profile_dir(pid).path_join("profile.json"))
	return {"m": int(p.get("look_model", -1)), "c": int(p.get("look_color", 0))}


static func set_profile_look(pid: String, model: int, color: int) -> void:
	var path := profile_dir(pid).path_join("profile.json")
	var p := _read(path)
	if p.is_empty():
		return
	p["look_model"] = model
	p["look_color"] = color
	_write(path, p)
	if pid == profile_id:
		LANG.set_figure(model)


## The warden's language ("en" or "cs"; a warden from before languages: English).
static func profile_lang(pid: String = profile_id) -> String:
	var lang := str(_read(profile_dir(pid).path_join("profile.json")).get("lang", "en"))
	return lang if lang in LANG.LANGS else "en"


## Kept with the warden, and the game's language at once if it is the warden playing.
static func set_profile_lang(pid: String, lang: String) -> void:
	var path := profile_dir(pid).path_join("profile.json")
	var p := _read(path)
	if p.is_empty() or not lang in LANG.LANGS:
		return
	p["lang"] = lang
	_write(path, p)
	if pid == profile_id:
		LANG.apply(lang)


## A new warden, chosen at once. The first one made takes in the saves from before.
static func create_profile(name: String, look_model: int = -1, look_color: int = 0, lang: String = "") -> String:
	var first := list_profiles().is_empty()
	var pid := _new_id("p")
	if not lang in LANG.LANGS:
		lang = LANG.current
	_write(profile_dir(pid).path_join("profile.json"), {"name": name.strip_edges().left(24), "created": _now(), "look_model": look_model, "look_color": look_color, "lang": lang})
	select_profile(pid)
	if first:
		_import_legacy()
	return pid


static func select_profile(pid: String) -> void:
	profile_id = pid
	camp_id = ""
	LANG.apply(profile_lang(pid))
	LANG.set_figure(int(profile_look(pid)["m"]))
	var camps := list_camps()
	if not camps.is_empty():
		activate_camp(str(camps[0]["id"]))
	else:
		_point_saves("")
	_remember()


static func delete_profile(pid: String) -> void:
	_remove_tree(profile_dir(pid))
	if pid == profile_id:
		profile_id = ""
		camp_id = ""
		_point_saves("")
		var rest := list_profiles()
		if not rest.is_empty():
			select_profile(str(rest[0]["id"]))
		else:
			_remember()


# ── camps ─────────────────────────────────────────────────────────────────────

## The warden's camps, the one played last first: {id, name, seed, created, played,
## sandbox, coop, day, money, guests, saves, thumb (path or "")}.
static func list_camps(pid: String = profile_id) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pid == "":
		return out
	for cid in _dirs(profile_dir(pid).path_join("camps")):
		var c := camp_info(cid, pid)
		if not c.is_empty():
			out.append(c)
	out.sort_custom(func(a, b): return int(a["played"]) > int(b["played"]))
	return out


static func camp_info(cid: String, pid: String = profile_id) -> Dictionary:
	var dir := camp_dir(cid, pid)
	var c := _read(dir.path_join("camp.json"))
	if c.is_empty():
		return {}
	var saves := 0
	var sd := DirAccess.open(dir.path_join("saves"))
	if sd != null:
		for f in sd.get_files():
			if f.ends_with(".ccs2save.json"):
				saves += 1
	c["id"] = cid
	c["saves"] = saves
	c["thumb"] = dir.path_join("thumb.png") if FileAccess.file_exists(dir.path_join("thumb.png")) else ""
	return c


## Points SaveManager at the camp's saves (and remembers it as the one played last).
static func activate_camp(cid: String) -> void:
	camp_id = cid
	_point_saves(camp_dir(cid).path_join("saves") if cid != "" else "")
	_remember()


static func _point_saves(dir: String) -> void:
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() != null else null
	if sm != null and sm.has_method("set_save_dir"):
		sm.set_save_dir(dir)


## A new camp in the warden's list (the world generated with `seed`), made the active one.
static func create_camp(name: String, seed: int, sandbox: bool, coop: bool) -> String:
	if profile_id == "":
		create_profile("Warden")
	var cid := _new_id("c")
	var label := name.strip_edges().left(28)
	if label == "":
		label = default_camp_name()
	_write(camp_dir(cid).path_join("camp.json"), {"name": label, "seed": seed, "created": _now(), "played": _now(), "sandbox": sandbox, "coop": coop, "day": 1, "money": 0, "guests": 0})
	activate_camp(cid)
	return cid


static func default_camp_name() -> String:
	var n := list_camps().size() + 1
	var names := ["Black Lake", "Spruce Hollow", "Liblice Meadow", "Kettle Pond", "Birch Bend", "Mill Race", "Fox Hill", "Reed Shore"]
	return "%s %d" % [names[n % names.size()], n]


static func rename_camp(cid: String, name: String) -> void:
	var path := camp_dir(cid).path_join("camp.json")
	var c := _read(path)
	if c.is_empty() or name.strip_edges() == "":
		return
	c["name"] = name.strip_edges().left(28)
	_write(path, c)


static func delete_camp(cid: String) -> void:
	_remove_tree(camp_dir(cid))
	if cid == camp_id:
		camp_id = ""
		_point_saves("")
		_remember()


## A copy of the camp (its saves and picture), named "<name> (copy)".
static func duplicate_camp(cid: String) -> String:
	var src := camp_info(cid)
	if src.is_empty():
		return ""
	var nid := _new_id("c")
	_copy_tree(camp_dir(cid), camp_dir(nid))
	var c := _read(camp_dir(nid).path_join("camp.json"))
	c["name"] = ("%s (copy)" % str(src["name"])).left(28)
	c["created"] = _now()
	c["played"] = _now() - 1
	_write(camp_dir(nid).path_join("camp.json"), c)
	return nid


## The camp a save file belongs to (its path is inside it), made the active one.
static func activate_for_save(path: String) -> void:
	var p := path.replace("\\", "/")
	var at := p.find("/camps/")
	if not p.begins_with(ROOT) or at < 0:
		return
	var rest := p.substr(at + 7)
	var cid := rest.get_slice("/", 0)
	if cid != "" and cid != camp_id:
		activate_camp(cid)


## After a save: the camp's card (day, money, guests, when) for the tiles.
static func after_save(snapshot: Dictionary) -> void:
	if camp_id == "":
		return
	var path := camp_dir().path_join("camp.json")
	var c := _read(path)
	if c.is_empty():
		return
	var state: Dictionary = snapshot.get("state", {}) if snapshot.get("state", {}) is Dictionary else {}
	var runtime: Dictionary = snapshot.get("runtime", {}) if snapshot.get("runtime", {}) is Dictionary else {}
	c["day"] = int(runtime.get("day_index", state.get("day", 1)))
	c["money"] = int(state.get("money", 0))
	var guests = state.get("guests", [])
	c["guests"] = (guests as Array).size() if guests is Array else 0
	c["played"] = _now()
	if bool(snapshot.get("coop", false)):
		c["coop"] = true
	_write(path, c)
	_remember()


## The camp as it looks now (the 3D view), for its tile: 16:9, small.
static func save_thumbnail(img: Image) -> void:
	if camp_id == "" or img == null or img.is_empty():
		return
	var im := img.duplicate() as Image
	var w := im.get_width()
	var h := im.get_height()
	var want_h := int(w * 9.0 / 16.0)
	if want_h <= h:
		im = im.get_region(Rect2i(0, (h - want_h) / 2, w, want_h))
	else:
		var want_w := int(h * 16.0 / 9.0)
		im = im.get_region(Rect2i((w - want_w) / 2, 0, want_w, h))
	im.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	im.save_png(ProjectSettings.globalize_path(camp_dir().path_join("thumb.png")))


# ── the saves from before profiles ──────────────────────────────────────────────

## user://saves into the warden's camps: one camp per world seed (saves from before the
## seed was kept make one camp of their own), named by when it was first saved.
static func _import_legacy() -> void:
	var d := DirAccess.open(LEGACY)
	if d == null:
		return
	var by_seed: Dictionary = {}
	for f in d.get_files():
		if not f.ends_with(".ccs2save.json"):
			continue
		var snap := _read(LEGACY.path_join(f))
		if snap.is_empty():
			continue
		var grid: Dictionary = snap.get("grid", {}) if snap.get("grid", {}) is Dictionary else {}
		var seed := int(grid.get("seed", 0))
		if not by_seed.has(seed):
			by_seed[seed] = []
		var meta: Dictionary = snap.get("meta", {}) if snap.get("meta", {}) is Dictionary else {}
		(by_seed[seed] as Array).append({"file": f, "snap": snap, "at": int(meta.get("updated_unix", 0))})
	var n := 0
	for seed in by_seed:
		var files: Array = by_seed[seed]
		files.sort_custom(func(a, b): return int(a["at"]) < int(b["at"]))
		n += 1
		var first := Time.get_datetime_dict_from_unix_time(int(files[0]["at"]))
		var cid := create_camp("Old camp %d (%02d.%02d.)" % [n, int(first.get("day", 1)), int(first.get("month", 1))], int(seed), false, bool(files.back()["snap"].get("coop", false)))
		var saves := camp_dir(cid).path_join("saves")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves))
		for e in files:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY.path_join(str(e["file"]))), ProjectSettings.globalize_path(saves.path_join(str(e["file"]))))
		after_save(files.back()["snap"])
		var c := _read(camp_dir(cid).path_join("camp.json"))
		c["played"] = int(files.back()["at"])
		c["created"] = int(files[0]["at"])
		_write(camp_dir(cid).path_join("camp.json"), c)
	var camps := list_camps()
	if not camps.is_empty():
		activate_camp(str(camps[0]["id"]))
