extends RefCounted

## The torch's light, the warden's own and the others' (player_controller.gd, the co-op
## figure's remote_player.gd): an old incandescent hand torch (Richard 24. 11.: „lepší
## světelný kužel baterky, takový co se více hodí do hry, klidně nažloutlý“): a warm yellow
## pool with the bulb's dark dot in its middle and the reflector's rings round it, fading to
## a soft spill, from a picture (Grok, tools/artgen/prompts_torch.tsv torch_cookie_a, made
## grey and black at the rim: world/torch_cookie.png) laid over the cone; it casts shadows
## (the trees, whoever stands in it). It was a plain round spot and a wider dim one.
## The picture goes over the cone through the light's shadow view: Godot 4.7 lays a
## spotlight's projector by its shadow matrix, and with the shadow off the beam went out
## (docs/godot.md). The others' torches are the yellow alone (rings = false): a shadow for
## each warden's beam would be four shadow views a frame.

const COOKIE := "res://assets/textury/world/torch_cookie.png"
const COLOR := Color(1.0, 0.85, 0.58)
const HALO_COLOR := Color(1.0, 0.82, 0.55)
## The cone the picture is spread over, degrees from its middle to its edge: the bright pool
## is about its inner half, the beam the night's rules count (player_controller.
## flashlight_angle, 19). Its edge left to the picture: the angular falloff is an exponent
## (1 - rim^k), high is flat to the rim (0.25 left only the very middle lit).
const CONE_DEG := 40.0
const CONE_SOFT := 3.0

static var _cookie: Texture2D


## `beam` lit as the torch: its colour and (`rings`) its picture, cone and shadow; its energy
## and range are the owner's.
static func dress(beam: SpotLight3D, rings := true) -> void:
	beam.light_color = COLOR
	if not rings:
		return
	if _cookie == null and ResourceLoader.exists(COOKIE):
		_cookie = load(COOKIE)
	beam.light_projector = _cookie
	beam.spot_angle = CONE_DEG
	beam.spot_angle_attenuation = CONE_SOFT
	beam.shadow_enabled = true
