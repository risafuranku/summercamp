extends RefCounted

## What the title writes about a camp and its saves (main_menu.gd's guest book, the key
## board's card, a camp's saves on the printout): a save's day, hour and till, a sum with
## its commas, how long ago, a camp's photograph (read from its file, kept while the file
## stays the same).

const LANG = preload("res://scripts/lang.gd")

static var _thumbs: Dictionary = {}


static func summary(entry: Dictionary) -> String:
	var hours := float(entry.get("time_hours", 9.0))
	var h := int(floor(hours)) % 24
	var m := int(floor((hours - floor(hours)) * 60.0))
	return LANG.t("DAY %d  %02d:%02d  $%s") % [int(entry.get("day", 1)), h, m, money(int(entry.get("money", 0)))]


static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if amount < 0 else "") + out


static func ago(unix: int) -> String:
	if unix <= 0:
		return ""
	var delta := int(Time.get_unix_time_from_system()) - unix
	if delta < 90:
		return LANG.t("JUST NOW")
	if delta < 3600:
		return LANG.t("%d MIN AGO") % (delta / 60)
	if delta < 86400:
		return LANG.t("%d H AGO") % (delta / 3600)
	# (One day apart: "1 DAYS AGO", and a filled-in lookup would not choose Czech's form.)
	if delta < 172800:
		return LANG.t("A DAY AGO")
	return LANG.t("%d DAYS AGO") % (delta / 86400)


static func thumb(path: String) -> Texture2D:
	if path == "":
		return null
	var stamp := FileAccess.get_modified_time(ProjectSettings.globalize_path(path))
	var key := "%s|%d" % [path, stamp]
	if not _thumbs.has(key):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_thumbs[key] = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	return _thumbs[key]
