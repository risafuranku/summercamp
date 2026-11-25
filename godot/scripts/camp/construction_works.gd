extends Node

## The workers' hours on the camp's sites (core/systems/construction_rules.gd): every tick of
## the game clock takes the work done since the last one (the workers' day only, 7 to 19)
## off every site; one that is done stands up as its building (actions.finish_site) on the
## host or a camp played alone. The other machines count along for their pictures and wait
## for the host's fact (coop_camp "site_done"). The last planks taken down are heard there.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RULES = preload("res://core/systems/construction_rules.gd")
const DONE_SFX := "res://assets/sfx/site/done.mp3"
## A jump on the clock longer than this (a load, a new camp) counts no work.
const MAX_STEP_H := 48.0

var main: Node
var _last_abs := -1.0


func _ready() -> void:
	var bus = INSTANCE.bus(self)
	if bus.has_signal("time_tick") and not bus.time_tick.is_connected(_on_time):
		bus.time_tick.connect(_on_time)
	if bus.has_signal("site_finished") and not bus.site_finished.is_connected(_on_finished):
		bus.site_finished.connect(_on_finished)


func _on_time(hour: int, minute: int) -> void:
	var core = INSTANCE.core(self)
	if core == null or core.get_state() == null:
		return
	var now := float(core.get_day() - 1) * 24.0 + float(hour) + float(minute) / 60.0
	if _last_abs < 0.0 or now < _last_abs or now - _last_abs > MAX_STEP_H:
		_last_abs = now
		return
	var worked := RULES.work_between(_last_abs, now)
	_last_abs = now
	if worked <= 0.0 or core.get_state().sites.is_empty():
		return
	var done: Array = core.actions.site_work(worked)
	if INSTANCE.coop(self).is_client():
		return
	for k in done:
		var p := str(k).split(":")
		core.actions.finish_site(Vector2i(int(p[0]), int(p[1])))


## The scaffold down and the building up: the planks on the pile, heard where it stands.
func _on_finished(_type: String, origin: Vector2i, _rot: int) -> void:
	var gm = main.get("grid_manager") if main != null else null
	var world: Node3D = main.get("_world_3d") if main != null else null
	if gm == null or world == null or not ResourceLoader.exists(DONE_SFX):
		return
	var fp: Vector2i = INSTANCE.core(self).get_state().grid.footprint_of(origin)
	var p := AudioStreamPlayer3D.new()
	p.stream = load(DONE_SFX)
	p.max_distance = 50.0
	p.unit_size = 4.0
	p.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	world.add_child(p)
	p.global_position = gm.get_footprint_center(origin, fp) + Vector3(0, 1.0, 0)
	p.finished.connect(p.queue_free)
	p.play()
