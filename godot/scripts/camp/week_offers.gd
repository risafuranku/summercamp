extends Node

## A sandbox camp's offer of the week sent (core/systems/offer_rules.gd; Richard 25. 11.
## „Jednou týdně“): every few seconds the camp's day and hour asked whether this week's is due,
## and when it is, sent. A tour: the travel agency's letter in CampMail (EmailManager.offer_tour),
## put off an hour while too few beds are free. Marked in the books once sent
## (actions.offer_done), so a load does not send it again. Only a sandbox camp with its "events"
## rule on (the camp's form), and only where the camp is simulated (the host or a camp alone):
## the other machines get the letter as they get all the mail.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RULES = preload("res://core/systems/offer_rules.gd")
const LOOK_SEC := 2.0

var main: Node
var _t := 0.0
## The last hour asked ("day:hour"): an hour that could not send is tried once.
var _asked := ""


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = LOOK_SEC
	if main == null or main.get("_gameplay_started") != true or main.get("_menu_mode") == true or main.get("_sandbox") != true:
		return
	if not main.camp_rule("events") or not INSTANCE.coop(self).sim_here():
		return
	var core = INSTANCE.core(self)
	if core == null or core.get_state() == null:
		return
	var day := int(core.get_day())
	var hour := int(floor(float(main.get("_time_of_day_hours"))))
	var key := "%d:%d" % [day, hour]
	if key == _asked:
		return
	_asked = key
	var kind := RULES.due(day, hour, camp_seed(), core.actions.offers_done())
	if kind != "" and send(kind, day, hour):
		core.actions.offer_done(RULES.week_of(day), kind)


## The camp's seed (the world's): the days and the kinds follow from it.
func camp_seed() -> int:
	var wg = main.get("world_generator") if main != null else null
	return int(wg.get("world_seed")) if wg != null else 0


## Sends offer `kind`; false when it cannot come this hour.
func send(kind: String, day: int, hour: int) -> bool:
	match kind:
		"tour":
			var em := INSTANCE.mail(self)
			return em != null and em.has_method("offer_tour") and bool(em.offer_tour(day, hour))
	return false
