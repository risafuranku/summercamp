extends RefCounted

## What a res:// folder holds, named as the game loads it (`song.mp3`, `cabin.tres`), the same
## in the editor and in an exported game. An export has no `song.mp3` in the folder, only
## `song.mp3.import` (and `x.tres.remap`): listed with DirAccess the radio found no songs
## and the texture pack no pictures (the web export of 15. 11.; the Steam build alike).
##   RES_DIR.files("res://assets/sfx/radio", ["mp3", "ogg"])   full paths, sorted
##   RES_DIR.names("res://data/buildings")                      {"files": [...], "dirs": [...]}

## The resources in `dir` (not below it) whose extension is one of `exts` (any when empty),
## as full paths, sorted.
static func files(dir: String, exts: Array = []) -> Array[String]:
	var out: Array[String] = []
	var base := dir.trim_suffix("/")
	for f in names(dir)["files"]:
		if exts.is_empty() or exts.has(str(f).get_extension().to_lower()):
			out.append(base + "/" + str(f))
	return out


## The names in `dir`: its resources and its folders (no trailing slash), each sorted.
## Hidden ones (a dot first) left out.
static func names(dir: String) -> Dictionary:
	var files_out: Array[String] = []
	var dirs_out: Array[String] = []
	var base := dir.trim_suffix("/") + "/"
	if not DirAccess.dir_exists_absolute(base):
		return {"files": files_out, "dirs": dirs_out}
	for e in ResourceLoader.list_directory(base):
		if e.begins_with("."):
			continue
		if e.ends_with("/"):
			dirs_out.append(e.trim_suffix("/"))
		else:
			files_out.append(e)
	files_out.sort()
	dirs_out.sort()
	return {"files": files_out, "dirs": dirs_out}
