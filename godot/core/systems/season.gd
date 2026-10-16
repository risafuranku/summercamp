extends RefCounted
class_name Season

## The campaign's calendar and its autumn (playtest 2026-10-16: "a month, through the
## autumn"). Pure functions of the game day (1-based) and the hour; no nodes, no state.
##
## Day 1 is Saturday 19 September 1998, the end of the summer: golden evenings, the
## first yellow in the birches. Vera comes back on the morning of day 31 (Monday 19
## October). In between the leaves turn and fall, the days draw in, the fog and the
## rain come, and on the last nights the trees are bare and it snows. From the first
## hard frosts the cold brings its own trouble (scripts/main.gd: frozen pipes, cold
## tents).

const CAMPAIGN_DAYS := 30
## The morning Vera is back (week_ledger.gd).
const RETURN_DAY := CAMPAIGN_DAYS + 1
const START_YEAR := 1998
const START_MONTH := 9
const START_DATE := 19
## 19.9.1998 was a Saturday (0 = Monday).
const START_WEEKDAY := 5
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
## The night the first snow falls (the evening of this day).
const FIRST_SNOW_DAY := 26


## {d, m, y, wd} for a game day (days before day 1 work too: the Water Board's table).
static func date_of(day: int) -> Dictionary:
	var d := START_DATE + (day - 1)
	var m := START_MONTH
	var y := START_YEAR
	while d > int(MONTH_DAYS[m - 1]):
		d -= int(MONTH_DAYS[m - 1])
		m += 1
		if m > 12:
			m = 1
			y += 1
	while d < 1:
		m -= 1
		if m < 1:
			m = 12
			y -= 1
		d += int(MONTH_DAYS[m - 1])
	return {"d": d, "m": m, "y": y, "wd": posmod(START_WEEKDAY + day - 1, 7)}


## "19.9.1998"
static func date_str(day: int) -> String:
	var dt := date_of(day)
	return "%d.%d.%d" % [dt["d"], dt["m"], dt["y"]]


## "19.9."
static func date_short(day: int) -> String:
	var dt := date_of(day)
	return "%d.%d." % [dt["d"], dt["m"]]


## "Saturday 19 September"
static func date_long(day: int) -> String:
	var dt := date_of(day)
	return "%s %d %s" % [WEEKDAYS[int(dt["wd"])], dt["d"], MONTH_NAMES[int(dt["m"]) - 1]]


static func weekday_short(day: int) -> String:
	return str(WEEKDAYS[int(date_of(day)["wd"])]).substr(0, 3)


## 0 at the start of day 1, 1 at the end of the last day.
static func progress(day: int, hour: float = 12.0) -> float:
	return clampf((float(day - 1) + hour / 24.0) / float(CAMPAIGN_DAYS), 0.0, 1.0)


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## How turned the leaves are: 0 summer green, 0.5 yellow, 1 rust brown.
static func leaf_turn(day: int, hour: float = 12.0) -> float:
	return _smooth(0.05, 0.72, progress(day, hour))


## How many leaves are still on the trees: 1 full, 0 bare.
static func leaves_on(day: int, hour: float = 12.0) -> float:
	return 1.0 - _smooth(0.55, 0.88, progress(day, hour))


## The colour of a deciduous crown: green, then gold, then rust.
static func leaf_tint(day: int, hour: float = 12.0) -> Color:
	var t := leaf_turn(day, hour)
	var green := Color(1.0, 1.0, 1.0)
	var gold := Color(1.35, 1.05, 0.38)
	var rust := Color(1.10, 0.62, 0.30)
	return green.lerp(gold, clampf(t * 2.0, 0.0, 1.0)) if t < 0.5 else gold.lerp(rust, (t - 0.5) * 2.0)


## The grass: summer, dry autumn yellow-brown, then frost-grey.
static func grass_tint(day: int, hour: float = 12.0) -> Color:
	var p := progress(day, hour)
	var summer := Color(1.0, 1.0, 1.0)
	var dry := Color(1.12, 0.98, 0.72)
	var late := Color(0.86, 0.84, 0.78)
	return summer.lerp(dry, _smooth(0.1, 0.5, p)).lerp(late, _smooth(0.6, 0.95, p))


## Snow on the ground: from the first snow night it settles and stays.
static func snow_cover(day: int, hour: float = 12.0) -> float:
	var since := float(day - FIRST_SNOW_DAY) + (hour - 20.0) / 24.0
	if since <= 0.0:
		return 0.0
	return clampf(since / 3.2, 0.0, 1.0) * 0.9 + (0.1 if since > 0.5 else 0.0)


## Degrees C: the day's high and the night's low.
static func temp_high(day: int) -> int:
	return int(round(lerpf(22.0, 3.0, pow(progress(day), 1.1))))


static func temp_low(day: int) -> int:
	return int(round(lerpf(10.0, -7.0, pow(progress(day), 1.25))))


## A night hard enough to freeze pipes.
static func hard_frost(day: int) -> bool:
	return temp_low(day) <= -2


## Rain falls as snow: on the first snow evening onward, at night first, then always.
static func precip_is_snow(day: int, hour: float) -> bool:
	if day > FIRST_SNOW_DAY + 1:
		return true
	if day >= FIRST_SNOW_DAY:
		return hour >= 18.0 or hour < 9.0 or day > FIRST_SNOW_DAY
	return false


## How the odds of the weather lean as the autumn goes: the clear golden end of summer,
## the windy middle, the fog and the rain of October, almost no thunder at the end.
static func weather_bias(day: int) -> Dictionary:
	var p := progress(day)
	return {
		"clear": lerpf(1.5, 0.75, p),
		"windy": 0.8 + 0.8 * sin(p * PI),
		"fog": lerpf(0.8, 2.3, p),
		"rain": lerpf(0.75, 1.5, p),
		"storm": lerpf(1.3, 0.15, p),
	}


## Hours the evening comes earlier (the sun sets at about 19:05 on day 1, 17:55 on day
## 30) and the morning later; the lighting shifts by these.
static func evening_earlier(day: int) -> float:
	return lerpf(0.0, 1.15, progress(day))


static func morning_later(day: int) -> float:
	return lerpf(0.0, 0.6, progress(day))


## The low gold of the end of summer: strongest at the start, gone by mid October.
static func golden(day: int) -> float:
	return 1.0 - _smooth(0.15, 0.6, progress(day))
