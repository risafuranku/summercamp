extends Translation

## The game's languages: English (the code's own) and Czech (locale/cs.po, made and merged
## by tools/i18n/extract.py; the English text is the msgid). The language is the warden's
## (scripts/profiles.gd "lang", chosen by the flags on the WARDEN page): apply() sets it.
##
## The catalogue is read here, not imported: the .po is kept as a plain file
## (cs.po.import: "keep"), and this Translation answers every lookup the engine makes
## (Controls and Label3D translate their own text; drawn text goes through tr()) and
## more than a plain one would:
##   - the exact msgid;
##   - an UPPER-CASE copy of a msgid (the menus upper-case their rows), answered upper-case;
##   - a formatted msgid ("%d CAMPS" answers "3 CAMPS"): the values are carried over in
##     order, or by {0} {1}... in the translation where Czech wants them in another order;
##     a %s value is itself looked up; {jeden|dva|pět} picks the form for the number
##     before it (1, 2-4, else); {g:zemřel|zemřela} the warden's grammatical gender
##     (Czech past tense talks to you as a man or a woman: Jana's and Bara's figures
##     are women, set_figure());
##   - a line wrapped in what is not a word ("<  Windbreaker  >", "- Done -"), and text of
##     several lines line by line.
## A miss answers nothing and the engine shows the English. Results are kept (the HUD
## asks for the same strings every frame).

const PO := "res://locale/cs.po"
const SCRIPT_PATH := "res://scripts/lang.gd"
const LANGS := ["en", "cs"]
## How each language names itself (the WARDEN page).
const NAMES := {"en": "English", "cs": "Čeština"}
const FLAGS := {"en": "res://assets/textury/ui/flag_en.png", "cs": "res://assets/textury/ui/flag_cs.png"}

## The warden figures who are women (scripts/coop/warden_looks.gd NAMES: Jana, Bara).
const FEMININE_FIGURES := [2, 3]

static var current := "en"
## The warden playing is a woman: {g:...|...} takes its second form.
static var feminine := false
static var _cs = null

var _exact: Dictionary = {}
var _upper: Dictionary = {}
var _plural: Dictionary = {}
var _templates: Array = []
var _memo: Dictionary = {}
var _re_wrap: RegEx
var _re_spec: RegEx
var _re_forms: RegEx


## The language for this machine from now: "en" or "cs".
static func apply(lang: String) -> void:
	# `-- --lang=cs` on the command line wins (tools and shots in either language,
	# whatever the warden's).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			lang = arg.substr(7)
	if not lang in LANGS:
		lang = "en"
	current = lang
	if lang != "en":
		_ensure()
	TranslationServer.set_locale(lang)


## The warden's figure (its gender for the Czech past tense).
static func set_figure(model: int) -> void:
	var f := model in FEMININE_FIGURES
	if f == feminine:
		return
	feminine = f
	if _cs != null:
		_cs._memo.clear()
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and current != "en":
			tree.root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)


## The language a new warden starts in: the system's, if the game has it.
static func system_default() -> String:
	return "cs" if OS.get_locale_language() in ["cs", "sk"] else "en"


static func is_czech() -> bool:
	return current == "cs"


## Translated outside a Node (static code): the same lookup as tr().
static func t(text: String) -> String:
	return TranslationServer.translate(text)


## A count with its noun: t_n(3, "%d guest", "%d guests") -> "3 hosté". The catalogue
## holds the plural as msgid / msgid_plural with Czech's three forms.
static func t_n(n: int, one: String, many: String) -> String:
	var form := TranslationServer.translate_plural(one, many, n)
	return form % n if form.contains("%") else form


static func _ensure() -> void:
	if _cs != null:
		return
	_cs = (load(SCRIPT_PATH) as GDScript).new()
	_cs.locale = "cs"
	_cs._read(PO)
	TranslationServer.add_translation(_cs)


## Read again (after the catalogue changed on disk, the tools' reload).
static func reload() -> void:
	if _cs == null:
		return
	TranslationServer.remove_translation(_cs)
	_cs = null
	if current != "en":
		_ensure()


# ── the catalogue ──────────────────────────────────────────────────────────────

func _init() -> void:
	_re_wrap = RegEx.create_from_string("^([^\\p{L}\\p{N}%{]*)(.*?)([^\\p{L}\\p{N}%}]*)$")
	_re_spec = RegEx.create_from_string("%(%|[-+ 0]*[0-9]*(?:\\.[0-9]+)?[dsfxXc])")
	_re_forms = RegEx.create_from_string("\\{([^{}|]*\\|[^{}]*)\\}")


func _read(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("lang: no catalogue at %s" % path)
		return
	var field := ""
	var cur := {}
	var lines := f.get_as_text().split("\n")
	for raw in lines:
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			if line == "":
				_take(cur)
				cur = {}
				field = ""
			continue
		if line.begins_with("\""):
			if field != "":
				cur[field] = str(cur.get(field, "")) + _unquote(line)
			continue
		var sp := line.find(" ")
		if sp < 0:
			continue
		field = line.substr(0, sp)
		cur[field] = _unquote(line.substr(sp + 1).strip_edges())
	_take(cur)


func _unquote(q: String) -> String:
	if q.length() < 2:
		return ""
	return q.substr(1, q.length() - 2).c_unescape()


func _take(e: Dictionary) -> void:
	var id := str(e.get("msgid", ""))
	if id == "":
		return
	if e.has("msgid_plural"):
		var forms: Array[String] = []
		for k in 3:
			forms.append(str(e.get("msgstr[%d]" % k, "")))
		if forms[0] != "":
			_plural[id] = forms
		return
	var to := str(e.get("msgstr", ""))
	if to == "":
		return
	_exact[id] = to
	var up := id.to_upper()
	if up != id and not _upper.has(up):
		_upper[up] = to.to_upper()
	if _re_spec.search(id) != null:
		_add_template(id, to)


## A formatted msgid as a pattern: its words must be there to try it (`lit`, the
## longest run of them), the values are caught by the pattern.
func _add_template(id: String, to: String) -> void:
	var pattern := "(?s)^"
	var specs: Array[String] = []
	var at := 0
	var lit := ""
	var letters := 0
	for m in _re_spec.search_all(id):
		var chunk := id.substr(at, m.get_start() - at)
		pattern += _escape(chunk)
		if chunk.strip_edges().length() > lit.length():
			lit = chunk.strip_edges()
		letters += _letter_count(chunk)
		var spec := m.get_string(1)
		if spec == "%":
			pattern += "%"
		else:
			specs.append(spec)
			var kind := spec.right(1)
			if kind == "d":
				pattern += "(-?[0-9]+)"
			elif kind == "f":
				pattern += "(-?[0-9]+(?:\\.[0-9]+)?)"
			elif kind == "x" or kind == "X":
				pattern += "([0-9a-fA-F]+)"
			else:
				pattern += "(.*?)" if spec.right(1) == "s" else "(.)"
		at = m.get_end()
	var tail := id.substr(at)
	pattern += _escape(tail) + "$"
	letters += _letter_count(tail)
	if tail.strip_edges().length() > lit.length():
		lit = tail.strip_edges()
	# Too few words of its own: it would catch anything ("%s: %s").
	if specs.is_empty() or letters < 3:
		return
	var re := RegEx.create_from_string(pattern)
	if not re.is_valid():
		return
	var entry := {"re": re, "lit": lit, "to": to, "specs": specs, "upper": false}
	_templates.append(entry)
	var up := id.to_upper()
	if up != id:
		var re_up := RegEx.create_from_string(_upper_pattern(pattern))
		if re_up.is_valid():
			_templates.append({"re": re_up, "lit": lit.to_upper(), "to": to.to_upper(), "specs": specs, "upper": true})


func _upper_pattern(pattern: String) -> String:
	# Upper-case the literal parts only (the groups' classes keep their a-f).
	var out := ""
	var depth := 0
	var i := 0
	while i < pattern.length():
		var c := pattern[i]
		if c == "\\" and i + 1 < pattern.length():
			out += c + pattern[i + 1]
			i += 2
			continue
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
		out += c if depth > 0 else c.to_upper()
		i += 1
	return out


func _escape(s: String) -> String:
	var out := ""
	for c in s:
		if c in ["\\", ".", "+", "*", "?", "(", ")", "[", "]", "{", "}", "^", "$", "|"]:
			out += "\\" + c
		else:
			out += c
	return out


func _letter_count(s: String) -> int:
	var n := 0
	for c in s:
		if c.to_upper() != c.to_lower():
			n += 1
	return n


# ── the lookup ─────────────────────────────────────────────────────────────────

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	var hit = _memo.get(s)
	if hit == null:
		hit = _find(s, true)
		if _memo.size() > 20000:
			_memo.clear()
		_memo[s] = hit
	return StringName(hit) if hit != "" else StringName()


func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, _context: StringName) -> StringName:
	var forms = _plural.get(String(src_message))
	if forms == null:
		return StringName()
	var k := _form_index(n)
	return StringName(forms[k] if forms[k] != "" else forms[0])


static func _form_index(n: int) -> int:
	n = absi(n)
	return 0 if n == 1 else 1 if n >= 2 and n <= 4 else 2


## The translation of `s`, or "".
func _find(s: String, deep: bool) -> String:
	if s.strip_edges() == "":
		return ""
	var to = _exact.get(s)
	if to != null:
		return _forms(to, [])
	to = _upper.get(s)
	if to != null:
		return _forms(to, [])
	# Wrapped in what is not a word.
	var m := _re_wrap.search(s)
	if m != null and (m.get_string(1) != "" or m.get_string(3) != "") and m.get_string(2) != "":
		var core := _find(m.get_string(2), deep)
		if core != "":
			return m.get_string(1) + core + m.get_string(3)
	if deep:
		var t := _from_template(s)
		if t != "":
			return t
		if s.contains("\n"):
			var parts := s.split("\n")
			var any := false
			for i in parts.size():
				var p := _find(parts[i], true)
				if p != "":
					parts[i] = p
					any = true
			if any:
				return "\n".join(parts)
	return ""


func _from_template(s: String) -> String:
	var is_upper := s == s.to_upper()
	for e in _templates:
		if bool(e["upper"]) and not is_upper:
			continue
		var lit: String = e["lit"]
		if lit != "" and not s.contains(lit):
			continue
		var m: RegExMatch = (e["re"] as RegEx).search(s)
		if m == null:
			continue
		var vals: Array[String] = []
		var specs: Array = e["specs"]
		for k in specs.size():
			var v := m.get_string(k + 1)
			if str(specs[k]).right(1) == "s":
				var tv := _find(v, false)
				if tv != "":
					v = tv.to_upper() if bool(e["upper"]) else tv
			vals.append(v)
		return _fill(str(e["to"]), vals)
	return ""


## The translation's placeholders filled: %x in order, {k} by index; then the forms.
func _fill(to: String, vals: Array[String]) -> String:
	var out := ""
	var at := 0
	var next := 0
	for m in _re_spec.search_all(to):
		out += to.substr(at, m.get_start() - at)
		if m.get_string(1) == "%":
			out += "%"
		else:
			out += vals[next] if next < vals.size() else ""
			next += 1
		at = m.get_end()
	out += to.substr(at)
	for k in vals.size():
		out = out.replace("{%d}" % k, vals[k])
	return _forms(out, vals)


## {jeden|dva|pět}: the form for the last number before it.
func _forms(text: String, _vals: Array) -> String:
	if not text.contains("|"):
		return text
	var out := ""
	var at := 0
	for m in _re_forms.search_all(text):
		var body := m.get_string(1)
		out += text.substr(at, m.get_start() - at)
		if body.begins_with("g:"):
			var g := body.substr(2).split("|")
			out += g[1] if feminine and g.size() > 1 else g[0]
		else:
			var forms := body.split("|")
			out += forms[mini(_form_index(_last_number(text.substr(0, m.get_start()))), forms.size() - 1)]
		at = m.get_end()
	return out + text.substr(at)


func _last_number(s: String) -> int:
	var i := s.length() - 1
	while i >= 0 and not s[i].is_valid_int():
		i -= 1
	if i < 0:
		return 5
	var j := i
	while j >= 0 and (s[j].is_valid_int() or s[j] in [",", " "] and j > 0 and s[j - 1].is_valid_int()):
		j -= 1
	return int(s.substr(j + 1, i - j).replace(",", "").replace(" ", ""))
