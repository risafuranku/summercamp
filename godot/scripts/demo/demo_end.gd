extends RefCounted

## How the demo ends (demo.gd; the Q&A of 15. 11.). On the morning after the last day the
## camp's clock stops at Demo.END_AT. A story camp gets the mail that ends it: not Vera's,
## her sister's grandson's (Vera died in March: who has been writing?); once somebody has
## read it, a line from "Vera" answers it. Whoever then sits at the reception PC (each
## machine its own warden) gets the trial's nag there (os98/apps/trial_app.gd): the order
## form with the camp's own numbers, the Steam Wishlist, the way back to the title. A
## sandbox camp has no story: its nag comes at the PC once the clock has stopped.
## Nothing of it is saved: the inbox, the day and the hour say where it stands.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const DEMO = preload("res://scripts/demo/demo.gd")
const WEEK_LEDGER = preload("res://scripts/week_ledger.gd")
const VERA := "Teta Vera <vera.kralova@rodina.cz>"
const GRANDSON := "Ondrej Blaha <ondra.blaha@volny.cz>"
## Real seconds from somebody reading the grandson's mail to Vera's answer, and from
## reading hers (sitting at the PC) to the nag.
const ANSWER_AFTER := 6.0
const NAG_AFTER := 3.0

const SISTER_MAIL := {
	"subject": "Vera Kralova",
	"body": "Good morning,\n\nI am writing for my grandmother, Ludmila Blahova, Vera Kralova's sister. Grandmother does not use computers. Your address was in Vera's notebook; we found it when we were clearing out her things.\n\nVera died on the fourteenth of March, here in Pelhrimov. The funeral was on the twentieth. We sent you the card; perhaps it never came.\n\nGrandmother asks who has been writing to you. It was not Vera.\n\nShe also asks you not to answer the phone at night.\n\nOndrej Blaha",
}
const VERA_ANSWER := {
	"subject": "Re: Vera Kralova",
	"body": "Do not answer him.\n\nI will explain tonight.\n\n- V.",
}

var main: Node
var _answer_t := 0.0
var _nag_t := 0.0
## This machine's nag is up (it comes again if it is closed).
var _nag: Control


func _init(main_node: Node) -> void:
	main = main_node


## The demo is over in this camp: the morning after its last day, at END_AT or later.
func over() -> bool:
	if not DEMO.active() or not main._gameplay_started or main._menu_mode or str(main._test_night) != "":
		return false
	return main._day_index > DEMO.DAYS and (main._day_index > DEMO.DAYS + 1 or float(main._time_of_day_hours) >= DEMO.END_AT)


## The clock stands still once it is over (main.clock_pace; the other machines take the
## host's pace).
func holds_clock() -> bool:
	return over()


func tick(delta: float) -> void:
	if not over():
		_answer_t = 0.0
		_nag_t = 0.0
		return
	if INSTANCE.coop(main).sim_here() and not main._sandbox:
		_send_mails(delta)
	_tick_nag(delta)


func _send_mails(delta: float) -> void:
	if EmailManager == null:
		return
	var sister: Dictionary = INSTANCE.mail(main).find_mail("demo_end", "sister")
	if sister.is_empty():
		_push("sister", GRANDSON, SISTER_MAIL)
		return
	if not bool(sister.get("_read", false)) or not INSTANCE.mail(main).find_mail("demo_end", "answer").is_empty():
		return
	_answer_t += delta
	if _answer_t >= ANSWER_AFTER:
		_push("answer", VERA, VERA_ANSWER)


func _push(id: String, sender: String, mail: Dictionary) -> void:
	INSTANCE.mail(main).push_system_mail({
		"from": sender, "sender": sender, "type": "story",
		"subject": str(mail["subject"]), "body": str(mail["body"]),
		"demo_end": id,
		"day": main._day_index, "time": _clock(),
	})


func _clock() -> String:
	var h := float(main._time_of_day_hours)
	return "%02d:%02d" % [int(h), int(fposmod(h, 1.0) * 60.0)]


## The nag on this machine's PC: its warden at the desk, the story read to its end (or a
## sandbox camp's clock stopped), a moment's wait.
func _tick_nag(delta: float) -> void:
	if _nag != null and is_instance_valid(_nag) and not _nag.is_queued_for_deletion():
		return
	_nag = null
	var shell := pc()
	if shell == null or not main._is_crt_desktop_active() or not shell.is_desktop_ready() or not _story_told():
		_nag_t = 0.0
		return
	_nag_t += delta
	if _nag_t >= NAG_AFTER:
		_nag_t = 0.0
		_nag = shell.open_trial()


func _story_told() -> bool:
	if main._sandbox:
		return true
	var answer: Dictionary = INSTANCE.mail(main).find_mail("demo_end", "answer") if EmailManager != null else {}
	return not answer.is_empty() and bool(answer.get("_read", false))


## The reception PC's shell (os98/os_shell.gd), null before the office is built.
func pc() -> Node:
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	return bi.get("_crt_ui") if bi != null else null


## The trial's buttons (trial_app.gd).
func wishlist() -> void:
	OS.shell_open(DEMO.store_url())


func quit_to_title() -> void:
	_nag = null
	main._on_pause_quit_requested()


## What the order form fills in: the warden, the camp, its days, its guests and its lost.
func form() -> Dictionary:
	var state = INSTANCE.core(main).get_state()
	var lost: int = (state.lost_guests as Array).size() if state != null and state.get("lost_guests") is Array else 0
	var warden := ""
	var shell := pc()
	if shell != null and shell.has_method("player_name"):
		warden = str(shell.player_name())
	return {
		"warden": warden,
		"camp": main.camp_name(),
		"days": DEMO.DAYS,
		"guests": WEEK_LEDGER.hosted_count(state),
		"lost": lost,
	}
