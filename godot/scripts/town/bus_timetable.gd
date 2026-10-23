extends RefCounted

## Line 380, Cerne jezero, kemp - Pristoupim - Liblice - Lstibor (CSAD Kolin): the buses
## the game runs (scripts/town/town_trip.gd) and the timetables on the poles
## (scripts/town/timetable_closeup.gd) both come from here, so what is printed runs.
##
## The road (scripts/geo/, tools/geo/design_world.py): up from the camp's stop to road
## 12, east along it, at Pristoupim north to the stop at the fork and on up to Liblice,
## then along the village street and out east to Lstibor. Four a day each way (the user,
## 23. 10.). The camp is the end of the line: the bus comes down from Liblice, turns in
## the loop, stands half an hour (the driver smokes at his wheel) and goes back up. In
## Liblice the bus for the camp stands ten minutes at the stop on the far side. Camp to
## Liblice is seven minutes (Pristoupim at five): ridden, the game's clock runs slow so
## the minutes are the timetable's (town_trip.gd). The 23:46 works bus does not stop at
## the camp: do not wave.
##
## Times are game hours (7.5 = 7:30).

## Camp to Liblice and back, Pristoupim on the way (hours).
const RIDE_HOURS := 7.0 / 60.0
const TO_PRISTOUPIM := 5.0 / 60.0
## Liblice to Pristoupim going down to the camp.
const FROM_LIBLICE_PRISTOUPIM := 2.0 / 60.0
## Liblice to Lstibor, for the printed sheet.
const ON_TO_LSTIBOR := 11.0 / 60.0

## At the camp stop: in from Liblice, out to Liblice (it stands half an hour).
const CAMP_LEAVE := [6.0 + 10.0 / 60.0, 10.25, 13.75, 19.0 + 10.0 / 60.0]
const TOWN_LEAVE := [5.5, 9.0 + 35.0 / 60.0, 13.0 + 5.0 / 60.0, 18.5]
const CAMP_ARRIVE := [5.5 + RIDE_HOURS, 9.0 + 35.0 / 60.0 + RIDE_HOURS, 13.0 + 5.0 / 60.0 + RIDE_HOURS, 18.5 + RIDE_HOURS]
## In Liblice, the bus for the camp: in from Lstibor ten minutes before it goes.
const TOWN_ARRIVE := [5.5 - 10.0 / 60.0, 9.0 + 25.0 / 60.0, 13.0 - 5.0 / 60.0, 18.5 - 10.0 / 60.0]
## In Liblice, the bus from the camp on its way to Lstibor (it stops a minute).
const TOWN_THROUGH := [6.0 + 10.0 / 60.0 + RIDE_HOURS, 10.25 + RIDE_HOURS, 13.75 + RIDE_HOURS, 19.0 + 10.0 / 60.0 + RIDE_HOURS]
## The works bus: through Liblice at 23:46, along road 12 past the camp's turn just after
## midnight.
const WORKS_TOWN := 23.0 + 46.0 / 60.0
const WORKS_CAMP := 0.0 + 6.0 / 60.0
## Lstibor, for the printed sheet: where the bus for the camp starts, and where the one
## from the camp ends.
const LSTIBOR_LEAVE := [5.5 - 21.0 / 60.0, 9.0 + 14.0 / 60.0, 13.0 - 16.0 / 60.0, 18.5 - 21.0 / 60.0]
const LSTIBOR_ARRIVE := [6.0 + 10.0 / 60.0 + RIDE_HOURS + ON_TO_LSTIBOR, 10.25 + RIDE_HOURS + ON_TO_LSTIBOR,
	13.75 + RIDE_HOURS + ON_TO_LSTIBOR, 19.0 + 10.0 / 60.0 + RIDE_HOURS + ON_TO_LSTIBOR]


## Pristoupim, the request stop at the fork for Liblice (hamlet_trip.gd): the buses
## pass it this long after they leave either end. They stop only for somebody waiting
## there, or asked (STOP in the bus, a ticket to Pristoupim).
static func hamlet_frac(towards_town: bool) -> float:
	return TO_PRISTOUPIM / RIDE_HOURS if towards_town else FROM_LIBLICE_PRISTOUPIM / RIDE_HOURS


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
