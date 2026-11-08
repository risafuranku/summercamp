extends RefCounted

## The Photographer's flash going off behind you throws your shadow far out ahead of you
## on the ground (DESIGN §5a.5; Richard 8. 11.: "ve stylu holky, tichomě"): you turned away
## in time, and you see that you did, and from where he fired (the shadow points away from
## him). Your own warden's outline (warden_looks.gd, the look you wear) in black, laid along
## the ground from your feet, gone as the flash falls off. On the machine of the warden he
## hunts (coop_night `_on_ext` "flash_shadow"); one decal per world, kept.

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const NODE := "FlashShadow"
## How far it reaches (m: the whole of you in the ground you see ahead, the head and the
## arms there to know it is you; his lamp is lower than your head and the true one would run
## off into the dark), how wide, how dark at first, how long it lasts (s, the flash's).
const LONG := 5.5
const WIDE := 1.35
const DARK := 0.9
const SECONDS := 0.35

static var _sil: Dictionary = {}


## Your outline in black (its alpha kept), made once per look.
static func silhouette(model: int) -> Texture2D:
	if _sil.has(model):
		return _sil[model]
	var src := LOOKS.texture(model, 0, "stand")
	var tex: Texture2D = null
	if src != null:
		var img := src.get_image()
		if img != null:
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0 if c.a > 0.3 else 0.0))
			tex = ImageTexture.create_from_image(img)
	_sil[model] = tex
	return tex


static func decal_of(world: Node3D) -> Decal:
	var d := world.get_node_or_null(NODE) as Decal
	if d == null:
		d = Decal.new()
		d.name = NODE
		d.visible = false
		d.size = Vector3(WIDE, 4.0, LONG)
		d.upper_fade = 0.0
		d.lower_fade = 0.2
		# Laid on the ground, not up the walls and the trees it meets.
		d.normal_fade = 0.6
		world.add_child(d)
	return d


## Made and laid once, unseen (the first flash is no first use).
static func prewarm(world: Node3D, model: int) -> void:
	if world == null or not world.is_inside_tree():
		return
	var d := decal_of(world)
	d.texture_albedo = silhouette(model)


## Your shadow from the flash at `lens`, from `player`'s feet away from it.
static func throw(world: Node3D, lens: Vector3, player: Node3D, model: int) -> void:
	if world == null or player == null or not world.is_inside_tree():
		return
	var dir := player.global_position - lens
	dir.y = 0.0
	if dir.length() < 0.3:
		return
	dir = dir.normalized()
	var d := decal_of(world)
	d.texture_albedo = silhouette(model)
	# Its -Z along the shadow: the picture's top (your head) far out, your feet at you.
	var mid := player.global_position + dir * (LONG * 0.5 + 0.15)
	d.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mid)
	d.modulate = Color(0.0, 0.0, 0.0, DARK)
	d.visible = true
	var tw := d.create_tween()
	tw.tween_property(d, "modulate:a", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): d.visible = false)
