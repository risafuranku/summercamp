extends "res://scripts/pda/apps/pda_app.gd"

## Messages (Richard 24. 11.: the pager goes, its messages come to the PDA): whatever happens
## away from you (hud_manager.push_pager: a breakdown, the post, the mains, the hands' news),
## newest first, a page at a time (no scrolling: the arrows turn the page). The ones not read
## yet are marked; opening the app reads the page you see. A message of the same group as the
## newest unread one takes its place (the post's "new mail" once, however many letters came).

const KEEP := 40
## hud_manager's STATUS_* that light the warning.
const WARN := 2

## {text, kind, group, at ("21:07"), read}
var messages: Array = []
var _page := 0


func add(text: String, kind: int, group: String, at: String) -> void:
	if group != "" and not messages.is_empty() and str(messages[0].get("group", "")) == group and not bool(messages[0].get("read", false)):
		messages[0] = {"text": text, "kind": kind, "group": group, "at": at, "read": false}
		return
	messages.push_front({"text": text, "kind": kind, "group": group, "at": at, "read": false})
	while messages.size() > KEEP:
		messages.pop_back()


func unread() -> int:
	var n := 0
	for m in messages:
		if not bool(m.get("read", false)):
			n += 1
	return n


func opened() -> void:
	_page = 0


func draw(r: Rect2) -> void:
	if messages.is_empty():
		os.text_c(Rect2(r.position.x, r.position.y + 20, r.size.x, 10), os.tr("No messages."), os.mid())
		return
	var pages := _pages(r)
	_page = clampi(_page, 0, pages.size() - 1)
	var y := r.position.y + 2
	for i in pages[_page]:
		var m: Dictionary = messages[i]
		var unread := not bool(m.get("read", false))
		var lines: Array = os.wrap(str(m["text"]), r.size.x - 10)
		# The time and a mark: unread filled, a warning with "!".
		var mark := Rect2(r.position.x + 2, y + 2, 4, 4)
		if unread:
			os.fill(mark)
		else:
			os.frame(mark)
		if int(m.get("kind", 0)) == WARN:
			os.text_r(r.end.x - 2, y, "!")
		os.text(r.position.x + 8, y, str(m.get("at", "")), os.mid())
		y += 9
		for l in lines:
			os.text(r.position.x + 8, y, str(l))
			y += 9
		y += 3
		os.hline(r.position.x + 2, r.end.x - 2, y - 2, os.mid())
		# What is on the screen has been read.
		m["read"] = true
	if pages.size() > 1:
		_arrows(r, pages.size())


## The messages that fit on each page: [[index...], ...].
func _pages(r: Rect2) -> Array:
	var out: Array = []
	var cur: Array = []
	var room := r.size.y - 16.0
	var used := 0.0
	for i in messages.size():
		var hgt := 9.0 * float(1 + os.wrap(str(messages[i]["text"]), r.size.x - 10).size()) + 3.0
		if not cur.is_empty() and used + hgt > room:
			out.append(cur)
			cur = []
			used = 0.0
		cur.append(i)
		used += hgt
	if not cur.is_empty():
		out.append(cur)
	return out


func _arrows(r: Rect2, n: int) -> void:
	var y := r.end.y - 13
	os.button(Rect2(r.position.x + 2, y, 18, 11), "<", "prev", _page > 0)
	os.button(Rect2(r.end.x - 20, y, 18, 11), ">", "next", _page < n - 1)
	os.text_c(Rect2(r.position.x + 20, y + 1, r.size.x - 40, 10), "%d/%d" % [_page + 1, n], os.mid())


func press(id: String) -> void:
	if id == "prev":
		_page -= 1
	elif id == "next":
		_page += 1
