extends "res://scripts/enemies/enemy_base.gd"

## The Whistler (spawned by Tramps).
##
## Out in the trees somebody whistles a campfire song, always a little way off, and
## the whistling moves. It wants you to come and find it. Walk towards it in the dark
## and it lets you get close, then it is suddenly behind you. The counter: do not go
## to it. Stand in lamp light and it loses interest after a while; the tune stops in
## the middle of a phrase. Tell: the tune, positional, never in sight until too late.

const SPRITE := "res://assets/textury/npc/enemy_whistler.png"
const SFX_TUNE := "res://assets/sfx/npc/whistler_tune.mp3"
const LAMP_SAFE := 0.22
const TUNE_EVERY := Vector2(9.0, 14.0)
## Seconds of walking towards it (outside the light) before it takes you.
const LURE_LIMIT := 7.0
const GIVE_UP_IN_LIGHT := 14.0

var _source := Vector3.INF
var _next_tune := 4.0
var _lured := 0.0
var _lit_for := 0.0
var _last_dist := 0.0
var _hit := 30
var _resting_until := 0.0
var _strike_at := -1.0


func get_enemy_id() -> String:
	return "whistler"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(25.0, 40.0, t))
	_body = _make_body(SPRITE, 2.3)
	_body.visible = false
	_relocate()


func _relocate() -> void:
	for _i in 12:
		var p := _point_from_player(_rng.randf_range(18.0, 26.0), _rng.randf_range(-120.0, 120.0))
		if p != Vector3.INF and _lamp_light_at(p) < LAMP_SAFE:
			_source = p
			_last_dist = _distance_to_player(p)
			return


func _on_tick(dt: float) -> void:
	if _elapsed < _resting_until or _source == Vector3.INF:
		return
	var player := _player_pos()
	var in_light := _lamp_light_at(player) > LAMP_SAFE
	# Too late: it is behind you.
	if _strike_at >= 0.0:
		_place_body(_point_from_player(1.6, 180.0))
		if _elapsed >= _strike_at:
			_hurt(_hit)
			_feed("The whistling was right behind you.")
			_body.visible = false
			_strike_at = -1.0
			_lured = 0.0
			_resting_until = _elapsed + 40.0
			_relocate()
		return
	_next_tune -= dt
	if _next_tune <= 0.0:
		_next_tune = _rng.randf_range(TUNE_EVERY.x, TUNE_EVERY.y)
		# It drifts between songs, keeping its distance.
		_source = _source.lerp(_point_from_player(_rng.randf_range(16.0, 24.0), _rng.randf_range(-90.0, 90.0)), 0.5)
		_sound(SFX_TUNE, _source + Vector3(0, 1.6, 0), 0.0, _rng.randf_range(0.95, 1.05), 60.0)
		_announce("Somebody is whistling out in the trees.")
	var d := _distance_to_player(_source)
	if in_light:
		_lit_for += dt
		_lured = maxf(0.0, _lured - dt)
		if _lit_for >= GIVE_UP_IN_LIGHT:
			_lit_for = 0.0
			_resting_until = _elapsed + 60.0
			_feed("The whistling stopped in the middle of the tune.")
			_relocate()
		return
	_lit_for = 0.0
	# Following it: the distance shrinks while you are out in the dark.
	if d < _last_dist - 0.05:
		_lured += dt
	else:
		_lured = maxf(0.0, _lured - dt * 0.5)
	_last_dist = d
	if _lured >= LURE_LIMIT or d < 4.0:
		_strike_at = _elapsed + 1.2
		_sound(SFX_TUNE, player + Vector3(0, 1.6, 0), 4.0, 0.8, 12.0)
