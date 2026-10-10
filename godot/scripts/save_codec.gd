extends RefCounted

const ROOM_RULES = preload("res://core/systems/room_rules.gd")

## Pure save-file encoding helpers (no state, no nodes). JSON has no Vector2i, so
## coordinates travel as {"x", "y"} dictionaries or "x:y" keys; guest, lodging,
## accommodation and failure records are normalised on the way in and out so a
## damaged or older save loads into well-typed data. Extracted from main.gd.

static func serialize_guests(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for guest_any in value:
		if not (guest_any is Dictionary):
			continue
		var guest := (guest_any as Dictionary).duplicate(true)
		guest["lodging_slots"] = serialize_lodging_slots(guest.get("lodging_slots", []))
		out.append(guest)
	return out


static func deserialize_guests(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for guest_any in value:
		if not (guest_any is Dictionary):
			continue
		var guest := (guest_any as Dictionary).duplicate(true)
		guest["lodging_slots"] = deserialize_lodging_slots(guest.get("lodging_slots", []))
		out.append(guest)
	return out


static func serialize_lodging_slots(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for slot_any in value:
		if not (slot_any is Dictionary):
			continue
		var slot := (slot_any as Dictionary).duplicate(true)
		var accommodation_key := str(slot.get("accommodation_key", slot.get("acc_key", ""))).strip_edges()
		if accommodation_key.is_empty():
			if not slot.has("coord"):
				continue
			var coord_from_slot := coord_from_variant(slot.get("coord", null), Vector2i.ZERO)
			accommodation_key = coord_to_key(coord_from_slot)
		if accommodation_key.is_empty():
			continue
		slot["accommodation_key"] = accommodation_key
		slot["coord"] = coord_to_dict(slot.get("coord", Vector2i.ZERO))
		slot["slot_index"] = max(0, int(slot.get("slot_index", 0)))
		slot["building_type"] = str(slot.get("building_type", ""))
		out.append(slot)
	return out


static func deserialize_lodging_slots(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (value is Array):
		return out
	for slot_any in value:
		if not (slot_any is Dictionary):
			continue
		var slot := (slot_any as Dictionary).duplicate(true)
		slot["accommodation_key"] = str(slot.get("accommodation_key", slot.get("acc_key", ""))).strip_edges()
		slot["coord"] = coord_from_variant(slot.get("coord", Vector2i.ZERO), Vector2i.ZERO)
		slot["slot_index"] = max(0, int(slot.get("slot_index", 0)))
		slot["building_type"] = str(slot.get("building_type", ""))
		out.append(slot)
	return out


static func serialize_accommodation_states(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	for key_any in (value as Dictionary).keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = (value as Dictionary).get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var sanitized_guest_ids: Array = []
		var seen_ids: Dictionary = {}
		var guest_ids_any = entry.get("guest_ids", [])
		if guest_ids_any is Array:
			for id_any in guest_ids_any:
				var guest_id := int(id_any)
				if guest_id <= 0 or seen_ids.has(guest_id):
					continue
				seen_ids[guest_id] = true
				sanitized_guest_ids.append(guest_id)
		var done: Array = []
		var done_any = entry.get("prep_done", [])
		if done_any is Array:
			for t in done_any:
				if not done.has(str(t)):
					done.append(str(t))
		out[key] = {
			# Saves from before room preparation said "clean": those rooms were usable.
			"status": ROOM_RULES.normalize_status(str(entry.get("status", "clean"))),
			"building_type": str(entry.get("building_type", "")),
			"capacity": max(0, int(entry.get("capacity", 0))),
			"prep_done": done,
			"mess": _mess_dict(entry.get("mess", {})),
			"mess_hint": _mess_dict(entry.get("mess_hint", {})),
			"occupied": max(0, int(entry.get("occupied", 0))),
			"guest_ids": sanitized_guest_ids
		}
	return out


static func deserialize_accommodation_states(value: Variant) -> Dictionary:
	return serialize_accommodation_states(value)


static func serialize_failures(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	var src := value as Dictionary
	for key_any in src.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = src.get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var fallback_coord := coord_from_key(key)
		var coord := coord_from_variant(entry.get("coord", fallback_coord), fallback_coord)
		out[key] = {
			"type": str(entry.get("type", "")),
			"coord": coord_to_dict(coord),
			"since_day": max(1, int(entry.get("since_day", 1))),
			"repair_progress": clampf(float(entry.get("repair_progress", 0.0)), 0.0, 1.0)
		}
	return out


static func deserialize_failures(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (value is Dictionary):
		return out
	var src := value as Dictionary
	for key_any in src.keys():
		var key := str(key_any).strip_edges()
		if key.is_empty():
			continue
		var entry_any = src.get(key_any, {})
		if not (entry_any is Dictionary):
			continue
		var entry := entry_any as Dictionary
		var fallback_coord := coord_from_key(key)
		var coord := coord_from_variant(entry.get("coord", fallback_coord), fallback_coord)
		out[key] = {
			"type": str(entry.get("type", "")),
			"coord": coord,
			"since_day": max(1, int(entry.get("since_day", 1))),
			"repair_progress": clampf(float(entry.get("repair_progress", 0.0)), 0.0, 1.0)
		}
	return out


static func duplicate_dict_array(value: Variant) -> Array:
	var out: Array = []
	if not (value is Array):
		return out
	for item_any in value:
		if item_any is Dictionary:
			out.append((item_any as Dictionary).duplicate(true))
	return out


static func duplicate_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func coord_from_variant(value: Variant, fallback: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Vector2:
		var vec2 := value as Vector2
		return Vector2i(int(vec2.x), int(vec2.y))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2i(int(dict.get("x", fallback.x)), int(dict.get("y", fallback.y)))
	if value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return fallback


static func coord_to_dict(value: Variant) -> Dictionary:
	var coord := coord_from_variant(value, Vector2i.ZERO)
	return {"x": coord.x, "y": coord.y}


static func coord_from_key(key: String) -> Vector2i:
	var parts := key.split(":")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func coord_to_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


## A room's mess {seed, level, archetypes, fresh} (core/systems/mess_rules.gd); JSON
## brings numbers back as floats.
static func _mess_dict(raw) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var d: Dictionary = raw
	var archetypes: Array = []
	if d.get("archetypes", []) is Array:
		for a in d.get("archetypes", []):
			archetypes.append(str(a))
	var out := {"seed": int(d.get("seed", 1)), "level": int(d.get("level", 1)), "archetypes": archetypes}
	if bool(d.get("fresh", false)):
		out["fresh"] = true
	return out
