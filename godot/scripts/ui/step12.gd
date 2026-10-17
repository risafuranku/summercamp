extends RefCounted


## Animation in steps, twelve a second, like the campfire, the torch hand and the old
## machinery: a tween's properties hold still between steps and jump to the next pose
## (same duration and easing as a smooth tween, just no in-betweens).
##
##   var tw := create_tween()
##   Step12.add(tw, camera, {"position": pos, "rotation": rot, "fov": 44.0}, 0.55)
##   Step12.add(tw, door, {"rotation_degrees:y": 90.0}, 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT, true)
##
## Segments chain like tween_property (pass `parallel` to run with the previous one);
## the start values are read when the segment starts, as tween_property does.

const FPS := 12.0


## Appends one stepped move of `target`'s properties (paths as for set_indexed) to `tw`.
static func add(tw: Tween, target: Object, props: Dictionary, duration: float,
		trans := Tween.TRANS_SINE, easing := Tween.EASE_IN_OUT, parallel := false) -> MethodTweener:
	var steps := maxi(1, int(round(duration * FPS)))
	var from := {}
	var apply := func(k: float) -> void:
		if not is_instance_valid(target):
			return
		if from.is_empty():
			for p in props:
				from[p] = target.get_indexed(NodePath(p))
		var e: float = Tween.interpolate_value(0.0, 1.0, floorf(k * steps) / steps, 1.0, trans, easing)
		for p in props:
			target.set_indexed(NodePath(p), _mix(from[p], props[p], e))
	if parallel:
		return tw.parallel().tween_method(apply, 0.0, 1.0, duration)
	return tw.tween_method(apply, 0.0, 1.0, duration)


## A new tween on `host` moving `target` in steps (all `props` together).
static func move(host: Node, target: Object, props: Dictionary, duration: float,
		trans := Tween.TRANS_SINE, easing := Tween.EASE_IN_OUT) -> Tween:
	var tw := host.create_tween()
	add(tw, target, props, duration, trans, easing)
	return tw


static func _mix(a: Variant, b: Variant, t: float) -> Variant:
	if a is float or a is int:
		return lerpf(float(a), float(b), t)
	if a is Vector3:
		return (a as Vector3).lerp(b, t)
	if a is Vector2:
		return (a as Vector2).lerp(b, t)
	if a is Color:
		return (a as Color).lerp(b, t)
	return b if t >= 1.0 else a
