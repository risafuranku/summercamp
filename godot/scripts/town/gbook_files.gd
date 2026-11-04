extends RefCounted

## What is on the gBook's disk (gbook_os.gd shows it). The system's own words are a real
## system's (AGENTS.md: the OS never jokes, never knows the story); what the man in eleven
## left is in his documents and their dates: plain lists and half a letter, nothing
## explained. His phone list has one line more every day of the game: the night before.
## Everything shown goes through the lookup (the Czech is in locale/cs.po).

const LANG = preload("res://scripts/lang.gd")

const PHONE_HOUR := "2:40"

const DOC_EXPENSES := "MOTEL LIBLICE, room 11\n\n3 Aug\tmonth in advance\t$250\n3 Aug\tkey deposit\t$5\n7 Aug\tJednota\t$6\n12 Aug\tbulb, from Simek\t$1\n18 Aug\tcandles\t$3\n25 Aug\tsecond key\t$5\n28 Aug\tfish food\t$2\n1 Sep\tthird key\t$5\n2 Sep\tcandles, chalk\t$4\n3 Sep\tmonth\t$250\n15 Sep\tcandles\t$3\n16 Sep\tto New Year. he says it is paid\t$0"
const DOC_LETTER := "Hanka,\n\nthe job was finished in August. I know what I told you.\n\nMr Simek says the room is paid to the end of the year. I did not pay it. I asked to see the book and the page is in my handwriting.\n\nDo not come for your birthday. I will come to you. Tell your mother the car is at the garage, that is all she needs.\n\nThey are kind here. They ask after you by name.\n\nI will write again when"
const DOC_LETTER_OLD := "Hanka,\n\nplease come and get me. Come by day. Take the car, not the bus."
const DOC_PHONE := "nights the phone rang\n\n11 Aug\t2:40\n12 Aug\t2:40\n19 Aug\t2:40\n26 Aug\t2:40\n27 Aug\t2:40\n2 Sep\t2:40\n3 Sep\t2:40 picked up\n4 Sep\t2:40\n9 Sep\t2:40\n10 Sep\t2:40 picked up\n11 Sep\tdid not ring. worse\n16 Sep\t2:40"
const DOC_STEPS := "where the steps were\n\n6\tevery night. Simek says six is not let\n12\tfrom the second week\n10\tthe pipes, he says\n4\tunder me. a chair moved\ncorridor\tup to my door. never back\nroof\tthere is nothing over 11\n11"

## name, icon (assets/textury/gbook/<icon>.png), kind, what the folder holds and Get Info's
## lines. Sizes and dates are figures, the same in both languages.
const ITEMS := {
	"hd": {"name": "gBook HD", "icon": "hd", "kind": "folder", "items": ["apps", "docs", "system"], "type": "Disk", "size": "38.4 MB", "made": "2.2.1996 9:12", "changed": "16.9.1998 2:41"},
	"trash": {"name": "Trash", "icon": "trash_full", "kind": "folder", "items": ["letter_old"], "type": "Trash", "size": "4K", "made": "2.2.1996 9:12", "changed": "9.9.1998 3:17"},
	"apps": {"name": "Applications", "icon": "folder", "kind": "folder", "items": ["reader", "calc", "puzzle", "installer", "dialer"], "type": "Folder", "size": "1.9 MB", "made": "2.2.1996 9:14", "changed": "2.2.1996 9:40", "where": "gBook HD"},
	"docs": {"name": "Documents", "icon": "folder", "kind": "folder", "items": ["expenses", "letter", "phone", "steps"], "type": "Folder", "size": "16K", "made": "3.8.1998 21:02", "changed": "16.9.1998 2:41", "where": "gBook HD"},
	"system": {"name": "System Folder", "icon": "folder_system", "kind": "locked", "type": "Folder", "size": "11.6 MB", "made": "2.2.1996 9:12", "changed": "2.2.1996 9:40", "where": "gBook HD", "locked": true},
	"panels": {"name": "Control Panels", "icon": "panels", "kind": "folder", "items": ["sound", "date", "about"], "type": "Folder", "size": "212K", "made": "2.2.1996 9:12", "changed": "2.2.1996 9:40", "where": "System Folder"},
	"expenses": {"name": "expenses", "icon": "doc", "kind": "doc", "text": DOC_EXPENSES, "type": "gText document", "size": "4K", "made": "3.8.1998 21:06", "changed": "16.9.1998 19:30", "where": "Documents"},
	"letter": {"name": "letter to Hanka", "icon": "doc", "kind": "doc", "text": DOC_LETTER, "type": "gText document", "size": "4K", "made": "9.9.1998 3:21", "changed": "14.9.1998 23:58", "where": "Documents"},
	"phone": {"name": "phone", "icon": "doc", "kind": "doc", "text": DOC_PHONE, "type": "gText document", "size": "4K", "made": "11.8.1998 2:52", "changed": "", "where": "Documents"},
	"steps": {"name": "steps", "icon": "doc", "kind": "doc", "text": DOC_STEPS, "type": "gText document", "size": "4K", "made": "21.8.1998 1:15", "changed": "16.9.1998 2:41", "where": "Documents"},
	"letter_old": {"name": "letter to Hanka 2", "icon": "doc", "kind": "doc", "text": DOC_LETTER_OLD, "type": "gText document", "size": "4K", "made": "9.9.1998 3:02", "changed": "9.9.1998 3:03", "where": "Trash"},
	"reader": {"name": "gText", "icon": "app_reader", "kind": "app", "type": "application", "size": "184K", "version": "1.2", "made": "2.2.1996 9:14", "changed": "2.2.1996 9:14", "where": "Applications"},
	"calc": {"name": "Calculator", "icon": "app_calc", "kind": "app", "type": "application", "size": "32K", "version": "1.0", "made": "2.2.1996 9:14", "changed": "2.2.1996 9:14", "where": "Applications"},
	"puzzle": {"name": "Puzzle", "icon": "app_puzzle", "kind": "app", "type": "application", "size": "48K", "version": "1.0", "made": "2.2.1996 9:14", "changed": "14.9.1998 4:06", "where": "Applications"},
	"installer": {"name": "Installer", "icon": "app_installer", "kind": "app", "type": "application", "size": "412K", "version": "2.1", "made": "2.2.1996 9:14", "changed": "2.2.1996 9:14", "where": "Applications"},
	"dialer": {"name": "Dialer", "icon": "app_dialer", "kind": "app", "type": "application", "size": "298K", "version": "1.3", "made": "2.2.1996 9:14", "changed": "6.8.1998 20:11", "where": "Applications"},
	"sound": {"name": "Sounds", "icon": "cp_sound", "kind": "app", "type": "control panel", "size": "36K", "version": "2.1", "made": "2.2.1996 9:12", "changed": "2.2.1996 9:12", "where": "Control Panels"},
	"date": {"name": "Date & Time", "icon": "cp_date", "kind": "app", "type": "control panel", "size": "28K", "version": "2.1", "made": "2.2.1996 9:12", "changed": "2.2.1996 9:12", "where": "Control Panels"},
	"about": {"name": "About This gBook", "icon": "about", "kind": "app", "type": "control panel", "size": "20K", "version": "2.1", "made": "2.2.1996 9:12", "changed": "2.2.1996 9:12", "where": "Control Panels"},
}


## A document's words as they stand today (`day` the game's day).
static func text_of(id: String, day: int) -> String:
	var s := LANG.t(str(ITEMS[id].get("text", "")))
	if id == "phone":
		s += "\n%s\t%s" % [short_date(day - 1), PHONE_HOUR]
	return s


static func changed_of(id: String, day: int) -> String:
	if id == "phone":
		return "%s 2:41" % Season.date_str(day - 1)
	return str(ITEMS[id].get("changed", ""))


## A figure as the language writes it: "2,982K", "36.8 MB"; in Czech "2 982K", "36,8 MB".
static func figure(s: String) -> String:
	if not LANG.is_czech():
		return s
	return s.replace(",", " ").replace(".", ",")


## How he dated his lines: "18 Sep", in Czech "18. 9.".
static func short_date(day: int) -> String:
	var dt := Season.date_of(day)
	if LANG.is_czech():
		return "%d. %d." % [dt["d"], dt["m"]]
	return "%d %s" % [dt["d"], str(Season.MONTH_NAMES[int(dt["m"]) - 1]).substr(0, 3)]
