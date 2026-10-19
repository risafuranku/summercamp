extends RefCounted

## Line 380, Hlubocany - Lesna - Cerne jezero, camp (CSAD Jihlava): the buses the game
## runs (scripts/town/town_trip.gd) and the timetables on the poles
## (scripts/town/timetable_closeup.gd) both come from here, so what is printed runs.
##
## Three a day each way. The camp is the end of the line: the bus comes up from Lesna,
## stands half an hour at the stop (the driver smokes), turns in the loop and goes back
## down through Lesna to Hlubocany. The first one in, at 5:45, is the one Vera comes out
## on for the district's inspection on day 31 (main.gd's pager). In Lesna the bus to the
## camp stands a quarter of an hour by the Jednota. A ride between the two takes an hour
## and a half of game time (a minute). The 23:46 works bus does not stop at the camp: do
## not wave.
##
## Times are game hours (7.5 = 7:30).

const RIDE_HOURS := 1.5

## At the camp stop: in from Lesna, out to Lesna and Hlubocany.
const CAMP_ARRIVE := [5.0 + 45.0 / 60.0, 13.0 + 20.0 / 60.0, 18.0 + 45.0 / 60.0]
const CAMP_LEAVE := [6.0 + 15.0 / 60.0, 13.0 + 50.0 / 60.0, 19.0 + 15.0 / 60.0]
## In Lesna, the bus to the camp: in from Hlubocany, out to the camp.
const TOWN_ARRIVE := [4.0, 11.0 + 35.0 / 60.0, 17.0]
const TOWN_LEAVE := [4.0 + 15.0 / 60.0, 11.0 + 50.0 / 60.0, 17.0 + 15.0 / 60.0]
## In Lesna, the bus from the camp on its way to Hlubocany (it stops a minute).
const TOWN_THROUGH := [7.0 + 45.0 / 60.0, 15.0 + 20.0 / 60.0, 20.0 + 45.0 / 60.0]
## The works bus: through Lesna at 23:46, past the camp stop a little after midnight.
const WORKS_TOWN := 23.0 + 46.0 / 60.0
const WORKS_CAMP := 0.0 + 6.0 / 60.0
## Hlubocany, for the printed sheet.
const HLUBOCANY_LEAVE := [3.0 + 35.0 / 60.0, 11.0 + 10.0 / 60.0, 16.0 + 35.0 / 60.0]
const HLUBOCANY_ARRIVE := [8.0 + 10.0 / 60.0, 15.0 + 45.0 / 60.0, 21.0 + 10.0 / 60.0]


## Podlesi, the request stop at the turn for the hamlet (hamlet_trip.gd): the buses pass
## it this far into their ride (where its pole is on ride_scenery.gd's route), so that
## long after they leave either end. They stop only for somebody waiting there, or
## asked (STOP in the bus, a ticket to Podlesi).
const SCENERY = preload("res://scripts/town/ride_scenery.gd")


static func hamlet_frac(towards_town: bool) -> float:
	var length := float(SCENERY.ROUTE.size() - 1) * SCENERY.PIECE + SCENERY.PIECE * 0.5
	return SCENERY.stop_along("hamlet", towards_town) / length


## The buses past Podlesi towards Lesna (from the camp) and towards the camp (from Lesna).
static func hamlet_to_town() -> Array:
	var out: Array = []
	for t in CAMP_LEAVE:
		out.append(float(t) + hamlet_frac(true) * RIDE_HOURS)
	return out


static func hamlet_to_camp() -> Array:
	var out: Array = []
	for t in TOWN_LEAVE:
		out.append(float(t) + hamlet_frac(false) * RIDE_HOURS)
	return out


static func hm(hours: float) -> String:
	var m := int(roundf(fposmod(hours, 24.0) * 60.0)) % (24 * 60)
	return "%d:%02d" % [m / 60, m % 60]


## The index of the run standing at the stop at `hour` (between its arrive and leave),
## or -1.
static func standing(arrive: Array, leave: Array, hour: float) -> int:
	for i in arrive.size():
		if hour >= float(arrive[i]) and hour < float(leave[i]):
			return i
	return -1


## The next departure from `leave` after `hour` (wrapping to tomorrow), as hours.
static func next_after(leave: Array, hour: float) -> float:
	for t in leave:
		if float(t) > hour:
			return float(t)
	return float(leave[0]) + 24.0
