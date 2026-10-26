extends SceneTree

## The languages (scripts/lang.gd): the lookup's ways (exact, upper-case, formatted,
## wrapped, lines, forms, gender) on a small catalogue of its own, then the real
## locale/cs.po: it reads, and every translation keeps its msgid's values (the same
## %d %s %f in the same order, or {0} {1} for each).
##   godot --headless --path godot --script res://tools/lang_check.gd

const LANG := preload("res://scripts/lang.gd")

var _fails := 0


func _init() -> void:
	_mechanics()
	_catalogue()
	print("LANG CHECK: %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)


func _expect(what: String, got: String, want: String) -> void:
	if got != want:
		_fails += 1
		print("FAIL %s: got %s, want %s" % [what, JSON.stringify(got), JSON.stringify(want)])


func _mechanics() -> void:
	var path := "user://lang_check.po"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n\n".join([
		"msgid \"\"\nmsgstr \"\"\n\"Language: cs\\n\"",
		"msgid \"Continue\"\nmsgstr \"Pokračovat\"",
		"msgid \"Sandbox\"\nmsgstr \"Volná hra\"",
		"msgid \"DAY %d  %02d:%02d  $%s\"\nmsgstr \"DEN %d  %02d:%02d  $%s\"",
		"msgid \"%s  DAY %d\"\nmsgstr \"%s  DEN %d\"",
		"msgid \"%d DAYS AGO\"\nmsgstr \"PŘED %d {DNEM|DNY|DNY}\"",
		"msgid \"%d guests waiting\"\nmsgstr \"čeká %d {host|hosté|hostů}\"",
		"msgid \"%s paid %s\"\nmsgstr \"{1} zaplatil {0}\"",
		"msgid \"YOU DIED\"\nmsgstr \"{g:ZEMŘEL|ZEMŘELA} JSI\"",
		"msgid \"First line\"\nmsgstr \"První řádek\"",
		"msgid \"%s\\nSEED %d%s\"\nmsgstr \"%s\\nSEMÍNKO %d%s\"",
		"msgid \"%d camp\"\nmsgid_plural \"%d camps\"\nmsgstr[0] \"%d kemp\"\nmsgstr[1] \"%d kempy\"\nmsgstr[2] \"%d kempů\"",
	]) + "\n")
	f.close()
	var t = (load(LANG.SCRIPT_PATH) as GDScript).new()
	t.locale = "cs"
	t._read(path)
	var tr := func(s: String) -> String:
		var r := String(t._get_message(StringName(s), &""))
		return r if r != "" else s
	_expect("exact", tr.call("Continue"), "Pokračovat")
	_expect("upper", tr.call("CONTINUE"), "POKRAČOVAT")
	_expect("miss", tr.call("Pepa"), "Pepa")
	# Money in crowns (lang.gd crowns()).
	_expect("template", tr.call("DAY 3  21:40  $1,234"), "DEN 3  21:40  12 340 Kč")
	_expect("template value looked up", tr.call("SANDBOX  DAY 4"), "VOLNÁ HRA  DEN 4")
	_expect("forms 1", tr.call("1 DAYS AGO"), "PŘED 1 DNEM")
	_expect("forms 3", tr.call("3 DAYS AGO"), "PŘED 3 DNY")
	_expect("forms 5", tr.call("5 guests waiting"), "čeká 5 hostů")
	_expect("forms 2", tr.call("2 guests waiting"), "čeká 2 hosté")
	_expect("reorder", tr.call("Pepa paid $40"), "400 Kč zaplatil Pepa")
	_expect("crowns", tr.call("Tip $3-5, -$5, $%d"), "Tip 30-50 Kč, -50 Kč, %d0 Kč")
	_expect("wrapped", tr.call("<  Sandbox  >"), "<  Volná hra  >")
	_expect("lines", tr.call("First line\nPepa"), "První řádek\nPepa")
	_expect("multi-line template", tr.call("STORY\nSEED 12\nCO-OP"), "STORY\nSEMÍNKO 12\nCO-OP")
	LANG.feminine = false
	t._memo.clear()
	_expect("gender m", tr.call("YOU DIED"), "ZEMŘEL JSI")
	LANG.feminine = true
	t._memo.clear()
	_expect("gender f", tr.call("YOU DIED"), "ZEMŘELA JSI")
	LANG.feminine = false
	_expect("plural 1", String(t._get_plural_message(&"%d camp", &"%d camps", 1, &"")), "%d kemp")
	_expect("plural 4", String(t._get_plural_message(&"%d camp", &"%d camps", 4, &"")), "%d kempy")
	_expect("plural 11", String(t._get_plural_message(&"%d camp", &"%d camps", 11, &"")), "%d kempů")
	# Through the engine, with the language switched.
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("cs")
	_expect("server", TranslationServer.translate("Continue"), "Pokračovat")
	_expect("t_n", LANG.t_n(3, "%d camp", "%d camps"), "3 kempy")
	TranslationServer.set_locale("en")
	_expect("english", TranslationServer.translate("Continue"), "Continue")
	_expect("t_n en", LANG.t_n(3, "%d camp", "%d camps"), "3 camps")
	TranslationServer.remove_translation(t)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Every translation of the real catalogue keeps its values.
func _catalogue() -> void:
	var t = (load(LANG.SCRIPT_PATH) as GDScript).new()
	t.locale = "cs"
	t._read(LANG.PO)
	if t._exact.is_empty():
		_fails += 1
		print("FAIL the catalogue %s has no translations" % LANG.PO)
		return
	var spec := RegEx.create_from_string("%(%|[-+ 0]*[0-9]*(?:\\.[0-9]+)?[dsfxXc])")
	var bad := 0
	for id in t._exact:
		var to: String = t._exact[id]
		var a := _kinds(spec, id)
		var b := _kinds(spec, to)
		var ok := a == b or _drops_only_text(a, b)
		if to.contains("{0}"):
			# by index: each value once as {k}, no % left over (a text value the code fills
			# with an English ending may be left out, as in order)
			ok = b.is_empty()
			for k in a.size():
				ok = ok and (to.contains("{%d}" % k) or a[k] == "s")
		if not ok:
			bad += 1
			if bad <= 20:
				print("FAIL values differ: %s -> %s" % [JSON.stringify(id), JSON.stringify(to)])
	_fails += bad
	print("catalogue: %d translations, %d templates, %d plurals" % [t._exact.size(), t._templates.size(), t._plural.size()])


## The translation keeps the values in order but leaves out some %s (the English endings
## the code fills in, "%d bill%s": the lookup's filling drops what is left over).
func _drops_only_text(a: Array, b: Array) -> bool:
	var i := 0
	for k in a:
		if i < b.size() and b[i] == k:
			i += 1
		elif k != "s":
			return false
	return i == b.size()


func _kinds(spec: RegEx, s: String) -> Array:
	var out: Array = []
	for m in spec.search_all(s):
		if m.get_string(1) != "%":
			out.append(m.get_string(1).right(1))
	return out
