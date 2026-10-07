class_name BuildingRegistry
extends Node

## Global registry for all building definitions.
## Loads data from res://data/buildings/*.tres

const BuildingDef = preload("res://core/data/building_def.gd")

# Map: id (StringName) -> BuildingDef
var _buildings: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	_buildings.clear()
	var dir = DirAccess.open("res://data/buildings/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Exported builds list "x.tres.remap"; load() resolves the remap itself.
			var res_name := file_name.trim_suffix(".remap")
			if !dir.current_is_dir() and (res_name.ends_with(".tres") or res_name.ends_with(".res")):
				var full_path = "res://data/buildings/" + res_name
				var res = load(full_path)
				if res is BuildingDef:
					if res.id == &"":
						printerr("BuildingRegistry: Loaded resource '%s' has no ID! Skipping." % file_name)
					else:
						_buildings[res.id] = res
						# print("BuildingRegistry: Loaded '%s'" % res.id)
			file_name = dir.get_next()
		print("BuildingRegistry: Loaded %d buildings." % _buildings.size())
	else:
		printerr("BuildingRegistry: Failed to open 'res://data/buildings/'")

func get_def(id: StringName) -> BuildingDef:
	return _buildings.get(id)

## Every definition, sorted by id (stable order for catalogs and reports).
func get_all_defs() -> Array[BuildingDef]:
	var ids := _buildings.keys()
	ids.sort()
	var result: Array[BuildingDef] = []
	for id in ids:
		result.append(_buildings[id])
	return result


func get_categories() -> Array:
	var cats = {}
	for id in _buildings:
		var def = _buildings[id]
		if def.category != "":
			cats[def.category] = true
	return cats.keys()

func get_buildings_by_category(category: String) -> Array[BuildingDef]:
	var result: Array[BuildingDef] = []
	for id in _buildings:
		var def = _buildings[id]
		if def.category == category:
			result.append(def)
	return result

