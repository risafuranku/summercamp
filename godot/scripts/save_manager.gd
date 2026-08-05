extends Node

const SAVE_DIR := "user://saves"
const SAVE_MANIFEST_PATH := "user://saves/manifest.json"
const SAVE_FILE_SUFFIX := ".ccs2save.json"
const SAVE_VERSION := 2
const MAX_AUTOSAVES := 18


func _ready() -> void:
	pass


func has_saves() -> bool:
	return not list_saves().is_empty()


func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(SAVE_FILE_SUFFIX):
			continue
		var path := SAVE_DIR.path_join(file_name)
		var parsed := _read_json_file(path)
		if parsed.is_empty():
			continue
		saves.append(_extract_meta(parsed, path, file_name))
	dir.list_dir_end()

	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("updated_unix", 0)) > int(b.get("updated_unix", 0))
	)
	return saves


func get_latest_save_path() -> String:
	var manifest := _read_json_file(SAVE_MANIFEST_PATH)
	var candidate := str(manifest.get("latest_path", "")).strip_edges()
	if not candidate.is_empty() and FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
		return candidate
	var saves := list_saves()
	if saves.is_empty():
		return ""
	return str(saves[0].get("path", ""))


func read_save(path: String) -> Dictionary:
	var normalized := _normalize_path(path)
	if normalized.is_empty():
		return {}
	var parsed := _read_json_file(normalized)
	if parsed.is_empty():
		return {}
	if int(parsed.get("save_version", 0)) <= 0:
		parsed["save_version"] = SAVE_VERSION
	return parsed


func delete_save(path: String) -> bool:
	var normalized := _normalize_path(path)
	if normalized.is_empty():
		return false
	var manifest := _read_json_file(SAVE_MANIFEST_PATH)
	var manifest_latest := str(manifest.get("latest_path", "")).strip_edges()
	var abs_path := ProjectSettings.globalize_path(normalized)
	if not FileAccess.file_exists(abs_path):
		return false
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		return false

	if manifest_latest == normalized:
		_write_manifest_latest("")
	return true


func write_save(snapshot: Dictionary, slot_name: String = "", kind: String = "manual") -> String:
	_ensure_save_dir()
	var timestamp := int(Time.get_unix_time_from_system())
	var seq := int(Time.get_ticks_usec() % 1000000)
	var safe_kind := _sanitize_name(kind)
	if safe_kind.is_empty():
		safe_kind = "manual"

	var out := snapshot.duplicate(true)
	out["save_version"] = SAVE_VERSION

	var meta := {}
	if out.has("meta") and out["meta"] is Dictionary:
		meta = (out["meta"] as Dictionary).duplicate(true)
	meta["slot_name"] = slot_name.strip_edges() if not slot_name.strip_edges().is_empty() else _default_slot_name(safe_kind, timestamp)
	meta["kind"] = safe_kind
	meta["updated_unix"] = timestamp
	if not meta.has("created_unix"):
		meta["created_unix"] = timestamp
	out["meta"] = meta

	var file_name := "%s_%d_%d%s" % [safe_kind, timestamp, seq, SAVE_FILE_SUFFIX]
	var path := SAVE_DIR.path_join(file_name)
	var json := JSON.stringify(out, "\t")
	if json.is_empty():
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(json)
	file.flush()
	file.close()

	_write_manifest_latest(path)
	if safe_kind == "autosave":
		_prune_old_autosaves()
	return path


func _extract_meta(parsed: Dictionary, path: String, file_name: String) -> Dictionary:
	var meta := {}
	if parsed.has("meta") and parsed["meta"] is Dictionary:
		meta = (parsed["meta"] as Dictionary).duplicate(true)

	var updated_unix := int(meta.get("updated_unix", 0))
	if updated_unix <= 0:
		updated_unix = int(FileAccess.get_modified_time(path))

	var created_unix := int(meta.get("created_unix", updated_unix))
	var slot_name := str(meta.get("slot_name", file_name))
	var kind := str(meta.get("kind", "manual"))

	return {
		"path": path,
		"file_name": file_name,
		"slot_name": slot_name,
		"kind": kind,
		"created_unix": created_unix,
		"updated_unix": updated_unix
	}


func _prune_old_autosaves() -> void:
	var autos: Array[Dictionary] = []
	for item in list_saves():
		if str(item.get("kind", "")) == "autosave":
			autos.append(item)
	if autos.size() <= MAX_AUTOSAVES:
		return
	for i in range(MAX_AUTOSAVES, autos.size()):
		var path := str(autos[i].get("path", ""))
		if path.is_empty():
			continue
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)


func _read_json_file(path: String) -> Dictionary:
	var normalized := _normalize_path(path)
	if normalized.is_empty():
		return {}
	var abs_path := ProjectSettings.globalize_path(normalized)
	if not FileAccess.file_exists(abs_path):
		return {}
	var file := FileAccess.open(normalized, FileAccess.READ)
	if file == null:
		return {}
	var txt := file.get_as_text()
	file.close()
	if txt.strip_edges().is_empty():
		return {}
	var parsed = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _write_manifest_latest(path: String) -> void:
	_ensure_save_dir()
	var payload := {"latest_path": path}
	var file := FileAccess.open(SAVE_MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()


func _normalize_path(path: String) -> String:
	var p := path.strip_edges()
	if p.is_empty():
		return ""
	if p.begins_with("user://"):
		return p
	if p.begins_with(SAVE_DIR):
		return p
	return SAVE_DIR.path_join(p)


func _default_slot_name(kind: String, timestamp: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(timestamp)
	var date_txt := "%04d-%02d-%02d %02d:%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0))
	]
	return "%s %s" % [kind.capitalize(), date_txt]


func _sanitize_name(raw: String) -> String:
	var src := raw.strip_edges().to_lower()
	if src.is_empty():
		return ""
	var out := ""
	for i in src.length():
		var ch := src.substr(i, 1)
		var is_alnum := (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		out += ch if is_alnum else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges()


func _ensure_save_dir() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_DIR)):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
