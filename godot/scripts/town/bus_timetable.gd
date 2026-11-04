extends RefCounted

## Line 380, Cerne jezero, kemp - Pristoupim - Liblice - Lstibor (CSAD Kolin): the buses
## the game runs (scripts/town/bus_line.gd, put on the road by town_trip.gd) and the
## timetables on the poles (scripts/town/timetable_closeup.gd) both come from here, so what
## is printed runs.
##
## The road (scripts/geo/, tools/geo/design_world.py): up from the camp's stop to road
## 12, east along it, at Pristoupim north to the stop at the fork and on up to Liblice,
## then along the village street and out east to Lstibor. Four a day each way (the user,
## 23. 10.). The camp is the end of the line: the bus comes down from Liblice, turns in
## the loop, stands half an hour (the driver smokes at his wheel) and goes back up. In
## Liblice the bus for the camp stands a quarter of an hour at the stop on the far side.
## The game's clock runs as ever while a bus drives (the user, 4. 11.: one real bus in
## the one world, nobody's clock slowed for it): the road takes what it takes at a
## Karosa's pace, about RIDE_HOURS from the camp to Liblice (tools/bus_line_check works
## it out from the road and prints these). The camp's times are the anchors; the rest
## follows from them. The 23:46 works bus does not stop at the camp: do not wave.
##
## Times are game hours (7.5 = 7:30).

## Camp to Liblice (bus_line.gd's "camp" to "l_up"), Liblice to the camp ("l_down" to
## "camp"), the camp to Pristoupim, Liblice to Pristoupim: driven, none stopping between.
const RIDE_HOURS := 164.0 / 60.0
const RIDE_DOWN_HOURS := 170.0 / 60.0
const TO_PRISTOUPIM := 113.0 / 60.0
const FROM_LIBLICE_PRISTOUPIM := 57.0 / 60.0
## Liblice to Lstibor beyond the land, for the printed sheet.
const ON_TO_LSTIBOR := 2.0
## How long it stands: in Liblice for the camp, in Liblice going on (a minute or two for
## who gets off), at Pristoupim when it pulls in.
const TOWN_STAND := 15.0 / 60.0
const THROUGH_STAND := 6.0 / 60.0
const HAMLET_STAND := 8.0 / 60.0
## At the camp stop: in from Liblice, out to Liblice (it stands half an hour).
const CAMP_ARRIVE := [5.5 + 7.0 / 60.0, 9.0 + 42.0 / 60.0, 13.0 + 12.0 / 60.0, 18.5 + 7.0 / 60.0]
const CAMP_LEAVE := [6.0 + 10.0 / 60.0, 10.25, 13.75, 19.0 + 10.0 / 60.0]
## In Liblice, the bus for the camp: in from Lstibor TOWN_STAND before it goes.
const TOWN_LEAVE := [5.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS, 9.0 + 42.0 / 60.0 - RIDE_DOWN_HOURS,
	13.0 + 12.0 / 60.0 - RIDE_DOWN_HOURS, 18.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS]
const TOWN_ARRIVE := [5.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND, 9.0 + 42.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND,
	13.0 + 12.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND, 18.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND]
## In Liblice, the bus from the camp on its way to Lstibor (it stands THROUGH_STAND).
const TOWN_THROUGH := [6.0 + 10.0 / 60.0 + RIDE_HOURS, 10.25 + RIDE_HOURS, 13.75 + RIDE_HOURS, 19.0 + 10.0 / 60.0 + RIDE_HOURS]
## The works bus: through Liblice at 23:46, along road 12 past the camp's turn just after
## midnight.
const WORKS_TOWN := 23.0 + 46.0 / 60.0
const WORKS_CAMP := 0.0 + 6.0 / 60.0
## The hands' bus (the user 26. 10.: the businesses' people come by bus for the opening
## and go home by bus after their shift, and the 380 does not run then): a works run,
## SLUZEBNI on its board, down to the camp stop after the night (the 380 is gone by
## then), after the day's closing and after the late shift's; it stands a few minutes and
## goes back up. Not the line: the poles do not print it and it takes nobody but them
## (scripts/business/hands_commute.gd walks them in from it and out to it).
const STAFF_ARRIVE := [6.0 + 42.0 / 60.0, 20.0 + 45.0 / 60.0, 23.0 + 45.0 / 60.0]
const STAFF_LEAVE := [6.0 + 47.0 / 60.0, 20.0 + 55.0 / 60.0, 23.0 + 55.0 / 60.0]
## Lstibor, for the printed sheet: where the bus for the camp starts, and where the one
## from the camp ends.
const LSTIBOR_LEAVE := [5.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND - ON_TO_LSTIBOR, 9.0 + 42.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND - ON_TO_LSTIBOR,
	13.0 + 12.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND - ON_TO_LSTIBOR, 18.5 + 7.0 / 60.0 - RIDE_DOWN_HOURS - TOWN_STAND - ON_TO_LSTIBOR]
const LSTIBOR_ARRIVE := [6.0 + 10.0 / 60.0 + RIDE_HOURS + THROUGH_STAND + ON_TO_LSTIBOR, 10.25 + RIDE_HOURS + THROUGH_STAND + ON_TO_LSTIBOR,
	13.75 + RIDE_HOURS + THROUGH_STAND + ON_TO_LSTIBOR, 19.0 + 10.0 / 60.0 + RIDE_HOURS + THROUGH_STAND + ON_TO_LSTIBOR]

## Pristoupim, the request stop at the fork for Liblice (hamlet_trip.gd): the buses
## pass it this long after they leave either end. They stop only for somebody waiting
## there, or asked (STOP in the bus, a ticket to Pristoupim).
static func hamlet_frac(towards_town: bool) -> float:
	return TO_PRISTOUPIM / RIDE_HOURS if towards_town else FROM_LIBLICE_PRISTOUPIM / RIDE_DOWN_HOURS


## The buses past Pristoupim towards Liblice (from the camp) and towards the camp (from
## Liblice).
static func hamlet_to_town() -> Array:
	var out: Array = []
	for t in CAMP_LEAVE:
		out.append(float(t) + TO_PRISTOUPIM)
	return out


static func hamlet_to_camp() -> Array:
	var out: Array = []
	for t in TOWN_LEAVE:
		out.append(float(t) + FROM_LIBLICE_PRISTOUPIM)
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
