extends Node3D

## Cars at a Benzina's pumps. Lojza's side job at the station by the camp's turn off road
## 12 (scripts/geo/geo_world.gd's Benzina): talk to him (or click a pump) while the
## station is open and the shift is on. A car comes in off the road every half a minute
## or so, pulls up at a free pump and waits with its engine off; click that pump and
## serve it in the close-up (pump_closeup.gd). Each car pays Lojza's fee, plus a tip if
## you stopped right on it; the wrong fuel costs you ten. The shift ends when you walk
## off, at nine in the evening, or when you have had enough.
## With `self_service` (Liblice's Benzina: only for filling up) the village's cars come
## in now and then by day, fill up themselves and go; nobody needs you there.
## The cars are Build boxes in a few colours with somebody's head in them.

signal paid(amount: int, line: String)

const PUMP_CLOSEUP = preload("res://scripts/town/pump_closeup.gd")
const SFX := "res://assets/sfx/town/"
const DRIVERS := ["Mr Dvorak", "A woman in a fur hat", "A man in a suit", "A farmer", "A young man", "Mrs Kopecka", "A priest"]
const TOWN_CAR := preload("res://scripts/town/town_car.gd")
const COLOURS := [Color(0.82, 0.8, 0.7), Color(0.5, 0.12, 0.1), Color(0.18, 0.3, 0.5), Color(0.3, 0.4, 0.22), Color(0.82, 0.62, 0.18), Color(0.86, 0.86, 0.86)]

## Where a car stops at each pump, the way in to it (ending there) and the way out from
## it (starting there), all in this node's frame: the station's owner lays them out.
var pump_spots: Array = []
var paths_in: Array = []
var paths_out: Array = []
## Cars fill up by themselves (no shift, no close-up), while `traffic` is on.
var self_service := false
var traffic := false
var on := false
var earned := 0
var _cars: Array = []            # {node, pump, state: in|wait|out, t, path, order}
var _next := 4.0
var _rng := RandomNumberGenerator.new()
var _closeup
var _serving := -1
var _mats: Dictionary = {}
## Called when the close-up shuts (town_trip gives the controls back).
var _closeup_closed_hook: Callable


func setup(stops: Array, ins: Array, outs: Array) -> void:
	pump_spots = stops
	paths_in = ins
	paths_out = outs
	_rng.randomize()


func start_shift() -> void:
	on = true
	earned = 0
	_next = 3.0


func end_shift() -> String:
	if not on:
		return ""
	on = false
	# Whoever is still waiting gives up and drives on.
	for c in _cars:
		if c["state"] == "wait":
			_send_off(c, 0.6)
	return "That's you done. %d dollars today." % earned if earned > 0 else "Done already? You didn't earn your boots."


func is_open() -> bool:
	return _closeup != null and _closeup.visible


func close() -> void:
	if is_open():
		_closeup.close_view()


func _process(delta: float) -> void:
	if on or (self_service and traffic):
		_next -= delta
		if _next <= 0.0:
			_next = _rng.randf_range(16.0, 30.0) if on else _rng.randf_range(40.0, 95.0)
			_spawn()
	for c in _cars:
		_drive(c, delta)
		# Filling up by themselves: a while at the pump, then off.
		if bool(c.get("self", false)) and c["state"] == "wait":
			c["t"] = float(c.get("t", 0.0)) - delta
			if float(c["t"]) <= 0.0:
				_send_off(c, 1.0)
	_cars = _cars.filter(func(c): return c["state"] != "gone")


func waiting_at(pump: int) -> bool:
	for c in _cars:
		if int(c["pump"]) == pump and c["state"] == "wait" and not bool(c.get("self", false)):
			return true
	return false


func _free_pump() -> int:
	for i in pump_spots.size():
		var used := false
		for c in _cars:
			if int(c["pump"]) == i and c["state"] != "out":
				used = true
		if not used:
			return i
	return -1


func _spawn() -> void:
	var pump := _free_pump()
	if pump < 0:
		return
	if pump >= paths_in.size() or (paths_in[pump] as Array).is_empty():
		return
	var path: Array = paths_in[pump]
	var car := _make_car()
	add_child(car)
	car.position = path[0]
	if path.size() > 1:
		var first: Vector3 = (path[1] as Vector3) - (path[0] as Vector3)
		car.rotation.y = atan2(-first.x, -first.z)
	var fuel: String = ["natural", "natural", "special", "diesel"][_rng.randi() % 4]
	var kind: String = ["money", "money", "litres", "full"][_rng.randi() % 4]
	var amount := 0
	if kind == "money":
		amount = [5, 8, 10, 12, 15, 20][_rng.randi() % 6]
	elif kind == "litres":
		amount = [5, 10, 15, 20, 25][_rng.randi() % 5]
	var order := {"fuel": fuel, "kind": kind, "amount": amount, "tank": _rng.randf_range(18.0, 34.0), "who": DRIVERS[_rng.randi() % DRIVERS.size()]}
	_cars.append({"node": car, "pump": pump, "state": "in", "path": path, "i": 1, "order": order,
		"self": not on, "t": _rng.randf_range(14.0, 26.0)})
	_sound(SFX + "car_in.mp3", car.global_position)


func _drive(c: Dictionary, delta: float) -> void:
	var node: Node3D = c["node"]
	if c["state"] == "wait":
		return
	var path: Array = c["path"]
	var i := int(c["i"])
	if i >= path.size():
		if c["state"] == "in":
			c["state"] = "wait"
		else:
			c["state"] = "gone"
			node.queue_free()
		return
	var target: Vector3 = path[i]
	var to := target - node.position
	var speed := 9.0 if c["state"] == "out" else (7.0 if i < path.size() - 1 else 3.0)
	if to.length() < 0.15:
		c["i"] = i + 1
		return
	node.position += to.normalized() * minf(to.length(), speed * delta)
	# Into the turn, not round it in one frame.
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.x, -to.z), clampf(delta * 3.5, 0.0, 1.0))


## Serve the car at this pump (from the pump's click).
func serve(pump: int) -> bool:
	for k in _cars.size():
		var c: Dictionary = _cars[k]
		if int(c["pump"]) == pump and c["state"] == "wait":
			if _closeup == null:
				_closeup = PUMP_CLOSEUP.new()
				add_child(_closeup)
				_closeup.served.connect(_on_served)
				_closeup.closed.connect(func():
					if _closeup_closed_hook.is_valid():
						_closeup_closed_hook.call()
				)
			_serving = k
			_closeup.start(c["order"])
			return true
	return false


func _on_served(result: Dictionary) -> void:
	var money := int(result["fee"]) + int(result["tip"])
	if money > 0:
		CoreRoot.actions.add_money(money)
		earned += money
	if int(result["fine"]) > 0:
		CoreRoot.actions.spend_money(mini(int(result["fine"]), CoreRoot.get_money()))
		earned -= int(result["fine"])
	paid.emit(money - int(result["fine"]), str(result["line"]))
	if _serving >= 0 and _serving < _cars.size():
		_send_off(_cars[_serving], 1.4)
	_serving = -1


## A car leaves its pump by the station's way out.
func _send_off(c: Dictionary, after: float) -> void:
	c["state"] = "out"
	var pump := int(c["pump"])
	c["path"] = paths_out[pump] if pump < paths_out.size() else []
	c["i"] = 0
	var node: Node3D = c["node"]
	get_tree().create_timer(after).timeout.connect(func():
		if is_instance_valid(node):
			_sound(SFX + "car_out.mp3", node.global_position)
	)


func _sound(path: String, at: Vector3) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.unit_size = 8.0
	p.max_distance = 90.0
	get_parent().add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


func _mat(c: Color) -> StandardMaterial3D:
	var key := str(c)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	_mats[key] = m
	return m


## An old Skoda (town_car.gd), in one of the colours of the time.
func _make_car() -> Node3D:
	return TOWN_CAR.make((COLOURS[_rng.randi() % COLOURS.size()] as Color).lightened(0.3))


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
