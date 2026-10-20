extends Node

## Headless check of the camp world's look and sound (agent B's world polish, 20. 10.),
## a scene so the autoloads are there:
##
##   godot --headless --path godot res://tools/world_check.tscn
##
## Asserts:
## - the lodgings' lights (scripts/ambient/window_lights.gd lit_at): every lodging lit in
##   the evening, all out by 23:30, a few (never all) up round three, some before dawn;
## - the sky by the hour and the weather (weather_visuals._sky_pair): the clear night's
##   stars, the dawn, the day, the gold, the sunset, the blue hour; a weather's own sky by
##   day and its cloud by night; the red anomaly;
## - the snow lies for the footsteps (Season.snow_cover) only from its first night;
## - every picture and sound the world polish added loads (and the sounds are not empty).

const WINDOW_LIGHTS := preload("res://scripts/ambient/window_lights.gd")
const WEATHER_VISUALS := preload("res://scripts/weather_visuals.gd")

const PICTURES := ["skybox/skystars.png", "skybox/skydawn.png", "skybox/skygolden.png", "skybox/skysunset.png",
	"skybox/skybluehour.png", "skybox/moon.png", "camp/window_lit.png", "camp/window_tv.png", "camp/breath_puff.png",
	"camp/recep_office_night.png", "camp/recep_back_night.png", "camp/lamp_beam.png", "world/grass_summer.png",
	"world/mist_bank.png", "world/rain_ring.png", "camp/embers.png", "world/water_drop.png"]
const SOUNDS := ["steps/snow_a.mp3", "steps/snow_b.mp3", "steps/snow_c.mp3", "steps/snow_d.mp3",
	"steps/puddle_a.mp3", "steps/puddle_b.mp3", "steps/puddle_c.mp3", "steps/puddle_d.mp3",
	"world/flag_clank_a.mp3", "world/flag_clank_b.mp3", "world/tube_buzz.mp3", "world/tap_drip.mp3",
	"far/chatter.mp3", "far/kids.mp3", "far/dog.mp3", "far/car.mp3", "far/train.mp3", "far/bell.mp3",
	"world/rain_tin.mp3", "world/rain_lake.mp3", "world/rain_leaves.mp3",
	"player/jacket_a.mp3", "player/jacket_b.mp3", "player/jacket_c.mp3", "player/keys_a.mp3", "player/keys_b.mp3",
	"world/door_creak_a.mp3", "world/door_creak_b.mp3", "world/door_shut_a.mp3", "world/door_shut_b.mp3"]


var _done: Array[String] = []


func _ready() -> void:
	var failures: Array[String] = []
	_lights(failures)
	_skies(failures)
	_snow(failures)
	_assets(failures)
	# A check that stopped on an error has not said its last word.
	for part in ["lights", "skies", "snow", "assets"]:
		if not _done.has(part):
			failures.append("%s: did not run to its end" % part)
	if failures.is_empty():
		print("WORLD CHECK: PASS")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("WORLD CHECK: ", f)
		print("WORLD CHECK: FAIL (%d)" % failures.size())
		get_tree().quit(1)


func _lights(failures: Array[String]) -> void:
	var keys: Array = []
	for x in 12:
		for y in 6:
			keys.append("%d:%d" % [x * 2, y * 3])
	var evening := 0
	var late := 0
	var three := 0
	var dawn := 0
	for day in range(2, 30):
		for k in keys:
			evening += 1 if WINDOW_LIGHTS.lit_at(k, day, 20.5) else 0
			late += 1 if WINDOW_LIGHTS.lit_at(k, day, 23.55) else 0
			var up := false
			for m in range(150, 240, 2):
				if WINDOW_LIGHTS.lit_at(k, day, float(m) / 60.0):
					up = true
					break
			three += 1 if up else 0
			dawn += 1 if WINDOW_LIGHTS.lit_at(k, day, 6.4) else 0
	var n := keys.size() * 28
	if evening != n:
		failures.append("lights: %d of %d lodgings lit at 20:30" % [evening, n])
	if late != 0:
		failures.append("lights: %d still lit at 23:33" % late)
	var share := float(three) / float(n)
	if share < 0.08 or share > 0.3:
		failures.append("lights: %.2f of the lodgings up round three (want about a sixth)" % share)
	var dshare := float(dawn) / float(n)
	if dshare < 0.15 or dshare > 0.6:
		failures.append("lights: %.2f up at 6:24 (want some, not all)" % dshare)
	_done.append("lights")


func _skies(failures: Array[String]) -> void:
	var wv = WEATHER_VISUALS.new()
	wv.season_day = 1
	var want := {
		[0, 3.0]: ["skystars", "skystars"],
		[0, 5.6]: ["skystars", "skydawn"],
		[0, 6.1]: ["skydawn", "skydawn"],
		[0, 6.8]: ["skydawn", "sky1"],
		[0, 12.0]: ["sky1", "sky1"],
		[0, 17.2]: ["skygolden", "skygolden"],
		[0, 18.4]: ["skysunset", "skysunset"],
		[0, 19.2]: ["skybluehour", "skybluehour"],
		[0, 23.0]: ["skystars", "skystars"],
		[1, 23.0]: ["skystars", "skystars"],
		[4, 12.0]: ["rrsky4", "rrsky4"],
		[4, 23.0]: ["skynight", "skynight"],
		[2, 6.1]: ["skynight", "skynight"],
		[6, 12.0]: ["skydusk", "skydusk"],
	}
	for k in want:
		wv._weather_state = int(k[0])
		wv._time_of_day_hours = float(k[1])
		var pair: Array = wv._sky_pair()
		var got := [str(pair[0]).get_file().get_basename(), str(pair[1]).get_file().get_basename()]
		if got != want[k]:
			failures.append("sky: weather %d at %.2f is %s, want %s" % [int(k[0]), float(k[1]), got, want[k]])
	wv.free()
	_done.append("skies")


func _snow(failures: Array[String]) -> void:
	if Season.snow_cover(20, 12.0) >= 0.2:
		failures.append("snow: lies on day 20")
	if Season.snow_cover(Season.FIRST_SNOW_DAY + 2, 12.0) < 0.2:
		failures.append("snow: not lying two days after the first snow")
	_done.append("snow")


func _assets(failures: Array[String]) -> void:
	for p in PICTURES:
		var path: String = "res://assets/textury/" + p
		if not ResourceLoader.exists(path) or load(path) == null:
			failures.append("picture missing: " + path)
	for s in SOUNDS:
		var path: String = "res://assets/sfx/" + s
		var st = load(path) if ResourceLoader.exists(path) else null
		if st == null:
			failures.append("sound missing: " + path)
		elif (st as AudioStream).get_length() < 0.2:
			failures.append("sound empty: " + path)
	_done.append("assets")
