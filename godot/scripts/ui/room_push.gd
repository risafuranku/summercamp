extends RefCounted

## Going from one room to the next with A/D (a cabin and its bathroom, the stalls of a
## block): the room you leave slides off to one side as the next slides in after it,
## smoothly at the full frame rate (playtest 17. 10.: "smoother transitions between the
## rooms"; it was a dark wipe in steps).
##
##   ROOM_PUSH.play(self, _viewport_container, _viewport, direction, func(): _set_room(target), func(): _done())
##
## The room left behind is a still of the viewport, drawn through the container's own
## material (the palette) so it looks the same while it goes.

const DURATION := 0.36
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")


static func play(host: Node, container: SubViewportContainer, vp: SubViewport, direction: int, switch: Callable, done: Callable) -> Tween:
	if container == null or vp == null or container.size.x <= 0.0:
		switch.call()
		done.call()
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		switch.call()
		done.call()
		return null
	var snap := TextureRect.new()
	snap.name = "RoomPushStill"
	snap.texture = ImageTexture.create_from_image(img)
	snap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snap.stretch_mode = TextureRect.STRETCH_SCALE
	snap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	snap.material = container.material
	snap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parent := container.get_parent()
	parent.add_child(snap)
	parent.move_child(snap, container.get_index() + 1)
	cancel(container)
	var base := container.position
	var w := container.size.x
	container.set_meta("room_push", {"still": snap, "base": base})
	snap.position = base
	snap.size = container.size
	# A soft dark edge on the still's trailing side, so the two rooms read as two.
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0) if direction >= 0 else Vector2(1, 0)
	grad.fill_to = Vector2(1, 0) if direction >= 0 else Vector2(0, 0)
	var shade := TextureRect.new()
	shade.texture = grad
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.size = Vector2(w * 0.05, container.size.y)
	shade.position = Vector2(w if direction >= 0 else -w * 0.05, 0.0)
	snap.add_child(shade)
	switch.call()
	var dir := 1.0 if direction >= 0 else -1.0
	container.position = base + Vector2(w * dir, 0.0)
	var tw := host.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(snap, "position:x", base.x - w * dir, DURATION)
	tw.parallel().tween_property(container, "position:x", base.x, DURATION)
	tw.parallel().tween_property(snap, "modulate", Color(0.7, 0.7, 0.72), DURATION)
	tw.tween_callback(func():
		if is_instance_valid(snap):
			snap.queue_free()
		if is_instance_valid(container):
			container.position = base
			container.remove_meta("room_push")
		done.call()
	)
	# The next room was built and the still read back in this very frame: start the slide
	# on a steady frame, or its first third goes in one jump.
	CAM_MOVE.hold(host, tw)
	return tw


## A push cut short (the room shut, rebuilt): the still goes, the room is back in place.
static func cancel(container: SubViewportContainer) -> void:
	if container == null or not container.has_meta("room_push"):
		return
	var m: Dictionary = container.get_meta("room_push")
	var still = m.get("still")
	if still != null and is_instance_valid(still):
		(still as Node).queue_free()
	container.position = m.get("base", container.position)
	container.remove_meta("room_push")
