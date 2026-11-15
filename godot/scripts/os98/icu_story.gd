extends RefCounted

## ICU on the office PC (playtest 14. 11.: "simulate an internet messenger where you can really
## write with somebody regularly for a few days, and then they disappear"). The warden before
## you left it in the tray, the eye. From the second evening a girl writes, jana_k, eleven (the Jana K. of 1987),
## at a summer camp by a black lake like yours: five evenings, a few lines each, your replies
## picked from two. Each evening she is nearer: she lost her red shoe in the night game, she
## knows who sleeps in your tents, she likes your light on, nobody looks in the water. On the
## last she is at the office window (you hear her tap on the glass), and then her account does
## not exist. Karel's last message is in your list too, from June.
##
## The clock is the camp's (main's hours, CoreRoot's day): she is on from 20:00 to 02:00, an
## evening a day, starting the evening after the PC was first switched on. The PC off, she
## leaves her first line as an offline message. Kept in the PC's store ("icu": shell.store), so
## the other warden's PC in co-op shows the same.
##
## Steps of an evening:
##   ["say", text]                       her line ({guest}: one of your guests by name)
##   ["ask", [you, [her lines]], ...]    your reply, picked from two
##   ["off"]                             she goes offline
##   ["tap"]                             a tap at the office's front window (shell.knock_glass)
##   ["gone"]                            her account no longer exists

const INSTANCE = preload("res://scripts/instance/instance.gd")
const NICK := "jana_k"
const KAREL := "karel_cj"
const FROM_H := 20.0
const TO_H := 2.0
const LOG_MAX := 160
## Seconds she types a line: a beat, and longer for a longer line.
const TYPE_BASE := 1.6
const TYPE_PER_CHAR := 0.055

const KAREL_LINES := [
	["15.6.1998 23:41", "if jana writes, dont answer."],
	["15.6.1998 23:44", "dont tell her the light is on"],
]

const EVENINGS := [
	[
		["say", "hi!! found you in the ICU directory"],
		["say", "you are the camp by the black lake? i am at a summer camp too. its sooo boring lol"],
		["ask", ["Hi! Which camp?", ["cerne jezero", "like you. funny :)"]],
			["Who is this?", ["jana. 11", "you have the camp now right? the man before you was nice"]]],
		["say", "they are calling us for the night game. bye!!"],
		["off"],
	],
	[
		["say", "are you there?"],
		["say", "we did the night game. i lost my shoe in the woods. the left one. its red"],
		["ask", ["Did you find it?", ["no. karel says tomorrow", "its dark in the woods. its so dark"]],
			["Tell your leaders.", ["the leaders are asleep", "everyone is asleep but me"]]],
		["say", "who is {guest}? the light is on in their tent"],
		["ask", ["How do you know that?", ["i can see it from here"]],
			["Go to sleep, Jana.", ["i cant sleep", "the man in the hat is by the fence again"]]],
		["off"],
	],
	[
		["say", "its cold"],
		["say", "your light is on. i like it. leave it on please"],
		["ask", ["Where are you?", ["by the water"]],
			["Stop this.", ["ok :(", "im sorry. i just want to go home"]]],
		["say", "did you count them at ten?"],
		["off"],
	],
	[
		["say", "they are looking for me. i saw the torches"],
		["say", "nobody looks in the water"],
		["ask", ["I will call the police.", ["the police came in 87", "they looked everywhere but the water"]],
			["Come to the reception.", ["i cant", "the door is locked from inside. you locked it"]]],
		["say", "tomorrow i will come to your window. dont be scared"],
		["off"],
	],
	[
		["say", "im here"],
		["say", "at your window"],
		["tap"],
		["say", "why wont you look"],
		["say", "i found my shoe"],
		["off"],
		["gone"],
	],
]

var shell
var _queue: Array = []        # [{t, line}] her lines still being typed
var _typing := 0.0
var _asking: Array = []
var _poll := 0.0
## This sitting has taken her up where the books left her (a game loaded mid-evening).
var _live := false


func setup(owner) -> void:
	shell = owner


func _state() -> Dictionary:
	var s = shell.stored("icu", {})
	if not (s is Dictionary) or (s as Dictionary).is_empty():
		s = {"start": _day() + 1, "ev": 0, "step": 0, "log": [], "online": false, "gone": false, "unread": 0, "missed": -1}
		shell.store("icu", s)
	return s


func _save(s: Dictionary) -> void:
	shell.store("icu", s)


func is_online() -> bool:
	return bool(_state().get("online", false))


func is_gone() -> bool:
	return bool(_state().get("gone", false))


func unread() -> int:
	return int(_state().get("unread", 0))


func read_all() -> void:
	var s := _state()
	if int(s.get("unread", 0)) != 0:
		s["unread"] = 0
		_save(s)


func log_lines() -> Array:
	return _state().get("log", [])


func karel_lines() -> Array:
	return KAREL_LINES


## Your two replies when she has asked (["", ""] none).
func choices() -> Array:
	var out: Array = []
	for c in _asking:
		out.append(str(c[0]))
	return out


func typing() -> bool:
	return not _queue.is_empty()


## Every frame the PC's desktop is up.
func tick(delta: float) -> void:
	if is_gone():
		return
	if not _queue.is_empty():
		_typing -= delta
		if _typing <= 0.0:
			var line: String = _queue.pop_front()
			_say(NICK, line)
			_typing = _type_time(str(_queue[0])) if not _queue.is_empty() else 0.0
			if _queue.is_empty():
				_run()
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 1.0
	var s := _state()
	if not _asking.is_empty():
		return
	var ev := int(s.get("ev", 0))
	if ev >= EVENINGS.size():
		return
	if bool(s.get("online", false)) and not _live:
		# On where she was: a question asked is asked again.
		_live = true
		var at := int(s.get("step", 0))
		if at > 0 and str((EVENINGS[ev][at - 1] as Array)[0]) == "ask":
			s["step"] = at - 1
			_save(s)
		_run()
		return
	var tonight := _day() - (1 if _hour() < 12.0 else 0)
	if tonight < int(s.get("start", 0)) + ev:
		return
	if not bool(s.get("online", false)):
		if not _evening():
			return
		s["online"] = true
		s["step"] = 0
		_save(s)
		_live = true
		shell.play("icu_on", -10.0)
		_run()


## On through the evening's steps till it asks or ends.
func _run() -> void:
	var s := _state()
	var ev := int(s.get("ev", 0))
	if ev >= EVENINGS.size():
		return
	var steps: Array = EVENINGS[ev]
	var i := int(s.get("step", 0))
	while i < steps.size():
		var st: Array = steps[i]
		i += 1
		s["step"] = i
		_save(s)
		match str(st[0]):
			"say":
				_queue.append(_fill(tr(str(st[1]))))
				_typing = _type_time(str(_queue[0]))
				return
			"ask":
				_asking = st.slice(1)
				return
			"off":
				s["online"] = false
				s["ev"] = ev + 1
				s["step"] = 0
				_save(s)
				shell.play("icu_off", -10.0)
			"tap":
				if shell.has_method("knock_glass"):
					shell.knock_glass()
			"gone":
				s["gone"] = true
				_save(s)
				_note(LANG_USER_GONE)
				return
	return


const LANG_USER_GONE := "jana_k: user not found."


## You picked a reply: it goes, her answer comes.
func choose(i: int) -> void:
	if i < 0 or i >= _asking.size():
		return
	var c: Array = _asking[i]
	_asking = []
	_say("you", tr(str(c[0])))
	for line in c[1]:
		_queue.append(_fill(tr(str(line))))
	_typing = _type_time(str(_queue[0])) + 0.8 if not _queue.is_empty() else 0.0
	if _queue.is_empty():
		_run()


## Shot driver: on to evening `i` (0-4), as if the ones before were done.
func debug_evening(i: int) -> void:
	var s := _state()
	s["ev"] = clampi(i, 0, EVENINGS.size())
	s["step"] = 0
	s["online"] = false
	s["start"] = mini(int(s.get("start", 1)), _day() - i)
	_save(s)
	_queue.clear()
	_asking = []
	_poll = 0.0


func _say(who: String, text: String) -> void:
	var s := _state()
	var log: Array = s.get("log", [])
	log.append([who, text, _clock()])
	while log.size() > LOG_MAX:
		log.pop_front()
	s["log"] = log
	if who != "you":
		s["unread"] = int(s.get("unread", 0)) + 1
		shell.play("icu_msg", -8.0)
	_save(s)


func _note(text: String) -> void:
	var s := _state()
	var log: Array = s.get("log", [])
	log.append(["*", tr(text), _clock()])
	s["log"] = log
	_save(s)


func _type_time(line: String) -> float:
	return minf(6.0, TYPE_BASE + TYPE_PER_CHAR * float(line.length()))


## {guest}: one of the camp's guests by name (the one first on the books), else "somebody".
func _fill(text: String) -> String:
	if text.find("{guest}") < 0:
		return text
	var who := tr("somebody")
	if GuestManager != null and INSTANCE.guests(shell).has_method("get_guest_life_snapshot"):
		var rows: Array = INSTANCE.guests(shell).get_guest_life_snapshot()
		if not rows.is_empty():
			who = str((rows[0] as Dictionary).get("name", who))
	return text.replace("{guest}", who)


func _evening() -> bool:
	var h := _hour()
	return h >= FROM_H or h < TO_H


func _hour() -> float:
	var m = shell.main_node()
	return float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0


func _day() -> int:
	return INSTANCE.core(shell).get_day() if CoreRoot != null else 1


func _clock() -> String:
	var h := _hour()
	return "%02d:%02d" % [int(h) % 24, int(fmod(h, 1.0) * 60.0)]
