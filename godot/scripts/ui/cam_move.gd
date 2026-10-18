extends RefCounted

## Camera moves in rooms (sitting down at the PC, getting up, looking back, leaning to the
## window, the bus seat): one smooth move at the full frame rate. They were stepped twelve
## times a second until the playtest of 18. 10. ("choppy").
##
##   _camera_tween = CAM_MOVE.move(self, camera, {"position": pos, "rotation": rot, "fov": 44.0}, 0.55)
##
## A move (or any tween, `hold`) waits for the first steady frame: one that starts in the
## frame a room is built or a still is read back from the GPU would lose its first part to
## that frame's long delta and jump.


## A new tween on `host` moving all of `props` of `target` together.
static func move(host: Node, target: Object, props: Dictionary, duration: float,
		trans := Tween.TRANS_SINE, easing := Tween.EASE_IN_OUT) -> Tween:
	var tw := host.create_tween()
	tw.set_trans(trans).set_ease(easing)
	var first := true
	for p in props:
		if first:
			tw.tween_property(target, NodePath(p), props[p], duration)
			first = false
		else:
			tw.parallel().tween_property(target, NodePath(p), props[p], duration)
	hold(host, tw)
	return tw


## Pauses `tw` and lets it run from the second frame after this one, so the frame in
## progress (however long it takes) is not counted into it.
static func hold(host: Node, tw: Tween) -> void:
	if host == null or not host.is_inside_tree() or tw == null:
		return
	tw.pause()
	var tree := host.get_tree()
	tree.process_frame.connect(func():
		tree.process_frame.connect(func():
			if tw.is_valid():
				tw.play()
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)
