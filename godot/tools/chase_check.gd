extends "res://tools/enemy_check.gd"

## The hunts' beat and the Cheap Chick's laugh with the real brains, in the enemy check's
## flat world (the user 5. 11.): the granny's loop in as she comes on, dead while she stands
## up and looks, all of it at a run; the antlered man's charge; the whistler's rush, stopped
## dead where he listens; her laugh out of the dark, carried far, again and again.
##   godot --headless --path godot --audio-driver Dummy res://tools/chase_check.tscn

const NFX := preload("res://scripts/night/nightmare_fx.gd")
const STALKER := preload("res://scripts/enemies/stalker_brain.gd")
const LAUGH := "res://assets/sfx/npc/girl_laugh.mp3"


func _ready() -> void:
	_build_world()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fx = NFX.get_for(self)
	await get_tree().process_frame
	await get_tree().process_frame
	var chase = fx.get("_chase")
	_expect(chase != null, "the night's layer has the chase music")
	if chase == null:
		_done()
		return

	# ── The granny: walk away from her, on while she looks.
	var bk = _start(BASKET)
	bk.soon = true
	bk.tick(1.0 / 30.0)
	bk._body.global_position = Vector3(0, 0, -16)
	var hunt_on := false
	var look_frames := 0
	var look_loud := 0
	var lunge_full := false
	var was := ""
	var in_look := 0
	for i in 30 * 45:
		var ph := str(bk._phase)
		if ph != "away":
			var away: Vector3 = _player.global_position - bk._body.global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
			_player.global_position += away * 3.9 / 30.0
		bk.tick(1.0 / 30.0)
		chase.tick(1.0 / 30.0)
		ph = str(bk._phase)
		in_look = in_look + 1 if ph == "look" else 0
		if ph == "hunt" and chase.playing():
			hunt_on = true
		if in_look > 1:
			look_frames += 1
			if chase.playing():
				look_loud += 1
		if ph == "lunge" and chase.playing() and float(chase._near) > 0.5:
			lunge_full = true
		was = ph
	print("CHASE CHECK: granny hunt %s, look %d frames (%d with music), lunge %s" % [hunt_on, look_frames, look_loud, lunge_full])
	_expect(hunt_on, "granny: her beat while she comes on")
	_expect(look_frames > 0 and look_loud == 0, "granny: dead silent while she stands up and looks (%d of %d frames with music)" % [look_loud, look_frames])
	_expect(lunge_full, "granny: all of it when she comes at a run")
	bk.stop_night()
	for i in 40:
		chase.tick(1.0 / 30.0)
	_expect(not chase.playing(), "granny: gone with her")

	# ── The antlered man's charge.
	var st = _start(STALKER)
	st._perimeter = [Vector3(-30, 0, -14), Vector3(30, 0, -14), Vector3(30, 0, 14), Vector3(-30, 0, 14)] as Array[Vector3]
	st._rest_until = -1.0
	st._charging = true
	var charge_on := false
	for i in 30 * 2:
		st.tick(1.0 / 30.0)
		chase.tick(1.0 / 30.0)
		charge_on = charge_on or (chase.playing() and str(chase._src) == "stalker")
	_expect(charge_on, "antlered man: his charge has its beat")
	st.stop_night()
	for i in 40:
		chase.tick(1.0 / 30.0)

	# ── The whistler: run while he whistles; he rushes. Stand there and he has you (it stops
	# dead with the string round your neck); walk off and he whistles where you were.
	for walk_off in [false, true]:
		_damage = 0
		_player.global_position = Vector3.ZERO
		var w = _start(WHISTLER)
		var rush_on := false
		var stopped := false
		var prev := ""
		var side := Vector3.ZERO
		for i in 30 * 120:
			var phw := str(w._phase)
			if phw == "play" and not rush_on:
				_player.global_position += Vector3(1, 0, 0) * 6.0 / 30.0
			elif phw == "rush" and walk_off:
				if side == Vector3.ZERO:
					side = (w._pos - _player.global_position).cross(Vector3.UP)
					side.y = 0.0
					side = side.normalized()
				_player.global_position += side * 3.3 / 30.0
			var striking := float(w._strike_t) >= 0.0
			w.tick(1.0 / 30.0)
			chase.tick(1.0 / 30.0)
			phw = str(w._phase)
			if phw == "rush" and float(w._strike_t) < 0.0 and chase.playing() and str(chase._src) == "whistler":
				rush_on = true
			if rush_on and ((prev == "rush" and phw == "play") or (not striking and float(w._strike_t) >= 0.0)):
				# (He tells it at the start of his next tick.)
				w.tick(1.0 / 30.0)
				chase.tick(1.0 / 30.0)
				stopped = not chase.playing()
				print("    whistler %s: t %.1f s, phase %s, strike %.2f, chase %s" % ["walking off" if walk_off else "standing", i / 30.0, str(w._phase), float(w._strike_t), chase.playing()])
				break
			prev = phw
		_expect(rush_on, "whistler: his rush has its beat")
		_expect(stopped, "whistler: it stops dead %s" % ["where he listens" if walk_off else "at the strike"])
		w.stop_night()
		for i in 40:
			chase.tick(1.0 / 30.0)

	# ── The Cheap Chick: her laugh out of the dark.
	_damage = 0
	_player.global_position = Vector3.ZERO
	var g = _start(GIRL)
	var heard := {}
	var far_ok := true
	# Kept far: the torch on her (she moves only unseen).
	(_player as FakePlayer).torch = true
	for i in 30 * 60:
		_face(g._body.global_position)
		# (Her voice waits for the wall clock, which stands still in this loop.)
		g._voice_until = 0.0
		g.tick(1.0 / 30.0)
		for n in find_children("*", "AudioStreamPlayer3D", true, false):
			var a := n as AudioStreamPlayer3D
			if a.stream != null and a.stream.resource_path == LAUGH and not heard.has(a.get_instance_id()):
				heard[a.get_instance_id()] = true
				if a.max_distance < 30.0:
					far_ok = false
	print("CHASE CHECK: girl laughed %d times in a minute" % heard.size())
	_expect(heard.size() >= 4 and far_ok, "girl: her laugh out of the dark, again and again, carried far (%d in a minute)" % heard.size())
	g.stop_night()
	(_player as FakePlayer).torch = false
	_done()


func _done() -> void:
	if _failures.is_empty():
		print("CHASE CHECK: PASS")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("CHASE CHECK FAIL: ", f)
		get_tree().quit(1)
