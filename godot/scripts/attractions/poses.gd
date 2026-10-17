extends RefCounted

## Guest sprites in other poses than standing: <sprite>_<pose>.png beside the standing
## one (assets/textury/npc/host1_sit.png ...), generated from it (tools/artgen rows
## host*_sit, _drink, _eat, host_tramp_guitar). A seated sprite is a person on an
## invisible seat at knee height, feet at the bottom edge: put its node on the floor just
## in front of the bench or chair and they sit on it.

const SEATED_HEIGHT_M := 1.3
const POSES := ["sit", "drink", "eat", "guitar"]

static var _tex: Dictionary = {}


## How many figures a party is on screen: the family sprite is two people (a father and
## his boy), so a family of four is two of them; everyone else is one each.
static func figure_count(archetype: String, party_size: int, most := 4) -> int:
	var n := maxi(1, party_size)
	if archetype == "family":
		n = int(ceil(float(n) / 2.0))
	return clampi(n, 1, most)


static func path_for(base_path: String, pose: String) -> String:
	if pose == "" or base_path == "":
		return base_path
	return base_path.replace(".png", "_%s.png" % pose)


static func has_pose(base_path: String, pose: String) -> bool:
	return ResourceLoader.exists(path_for(base_path, pose))


## Show `sprite` in `pose` ("" = standing as created). Falls back to sitting, then to
## standing, when the guest has no sprite for that pose.
static func set_pose(sprite: Sprite3D, base_path: String, pose: String) -> void:
	if sprite == null:
		return
	if base_path == "":
		base_path = str(sprite.get_meta("base_path", ""))
	if pose != "" and not has_pose(base_path, pose):
		pose = "sit" if has_pose(base_path, "sit") else ""
	var want := path_for(base_path, pose)
	if str(sprite.get_meta("pose_path", "")) == want:
		return
	if not sprite.has_meta("stand_px"):
		sprite.set_meta("stand_px", sprite.pixel_size)
		sprite.set_meta("stand_tex", sprite.texture)
	var tex: Texture2D
	if pose == "":
		tex = sprite.get_meta("stand_tex") as Texture2D
	else:
		if not _tex.has(want):
			_tex[want] = load(want)
		tex = _tex[want]
	if tex == null:
		return
	sprite.texture = tex
	sprite.pixel_size = float(sprite.get_meta("stand_px")) if pose == "" else SEATED_HEIGHT_M / float(tex.get_height())
	sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	sprite.set_meta("pose_path", want)
