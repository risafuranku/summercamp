extends RefCounted

## Who answers the office phone, and what they say (scripts/closeup/phone_closeup.gd).
## Pure rules: a dialled number and the camp's situation in, a call out. The numbers
## are the ones on the noticeboard and in Vera's TELEFONY.TXT; anything else is the
## exchange telling you it does not exist.
##
## A call: {kind, rings, who, lines: [{who, text, voice}], effect}
##   kind    "talk" (someone picks up), "machine" (a recording), "busy", "sit" (number
##           not in service), "noanswer" (rings out)
##   rings   how many rings you hear before it is picked up (or before giving up)
##   lines   what is said; who "" = the other side, "YOU" = what you tell them (silent)
##   voice   a file id in assets/sfx/phone/voice/ (tools/audiogen/tts.py), optional
##   effect  "electrician" (he is coming), "" otherwise
## ctx: {hour (0-24 float), day, power_fault (bool), electrician_coming (bool),
##       hunted (something big is out tonight), nights_visited, calls: {number: n}}

const ELECTRICIAN := "066322418"
const FEE_DAY := 60
const FEE_NIGHT := 120
const OWN_NUMBER := "066321404"
const HRUBY := "066321224"
const CLOCK := "14112"

const NAMES := {
	ELECTRICIAN: "Novotny",
	"066321007": "Vet",
	"066330112": "District office",
	"066330150": "Water board",
	"066321333": "Bus station",
	"066321090": "Jednota",
	"066321515": "U Jezera",
	"066330199": "Power faults",
	"158": "Police",
	"155": "Ambulance",
	"0602618247": "Nela",
	"0267314420": "Vera",
	CLOCK: "Time",
	OWN_NUMBER: "Camp",
	HRUBY: "Hruby",
}


static func digits(s: String) -> String:
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += ch
	return out


## Whether what has been dialled so far could still become a number (the exchange
## waits), or is complete.
static func is_complete(number: String) -> bool:
	if number in ["158", "155", CLOCK]:
		return true
	if number.begins_with("0663"):
		return number.length() >= 9
	return number.length() >= 10


static func is_night(hour: float) -> bool:
	return hour >= 21.0 or hour < 6.5


static func dial(number: String, ctx: Dictionary) -> Dictionary:
	var hour := float(ctx.get("hour", 12.0))
	var night := is_night(hour)
	var n := int((ctx.get("calls", {}) as Dictionary).get(number, 0))
	match number:
		ELECTRICIAN:
			return _electrician(ctx, night, n)
		"066321007":
			return _machine("VET", 3, [["", "Veterinary practice, Lesna. Surgery hours are eight till twelve. For large animals, ring after six.", "vet"]])
		"066330112":
			if night or hour < 8.0 or hour >= 15.0:
				return {"kind": "noanswer", "rings": 9}
			return _talk("CLERK", 2, [
				["", "District office, accommodation.", "dist_1"],
				["YOU", "It's the camp at the reservoir.", ""],
				["", "The guest register goes in GuestRack. We have told Mrs Kralova twice. Good day.", "dist_2"]])
		"066330150":
			return _machine("WATER BOARD", 2, [["", "Water board. Blockages inside the camp are the operator's responsibility. Do not flush rags.", "water"]])
		"066321333":
			return _machine("BUS STATION", 1, [["", "Hlubocany bus station. Line three-eighty to Cerne jezero: six fifteen, nine forty, thirteen oh five, sixteen thirty and eighteen forty. The last bus back from the camp leaves at nineteen fifteen.", "bus"]])
		"066321090":
			if hour < 7.0 or hour >= 18.0:
				return {"kind": "noanswer", "rings": 8}
			return _talk("JEDNOTA", 3, [
				["", "Jednota, Lesna.", "jed_1"],
				["YOU", "It's Vera's camp.", ""],
				["", "Bread comes with the van. And tell Vera the crates are hers to bring back.", "jed_2"]])
		"066321515":
			if hour >= 1.0 and hour < 10.0:
				return {"kind": "noanswer", "rings": 10}
			return _talk("U JEZERA", 4, [
				["", "U Jezera!", "pub_1"],
				["YOU", "It's the camp. Is anyone from the camp with you?", ""],
				["", "What? I can't hear you, the jukebox is on. Come down if you want a drink!", "pub_2"]])
		"066330199":
			if night:
				return _machine("POWER FAULTS", 2, [["", "Hlubocany District Power, faults. Our crews do not go out to the reservoir after dark. Call your electrician.", "power_night"]])
			return _talk("POWER FAULTS", 2, [
				["", "District Power, faults.", "power_1"],
				["YOU", "The camp at the reservoir. The main keeps tripping.", ""],
				["", "Your side of the meter is your electrician's job. Novotny, isn't it? His number's in the book.", "power_2"]])
		"158":
			if night:
				return _talk("POLICE", 2, [
					["", "Police, Hlubocany.", "pol_1"],
					["YOU", "It's the camp at the reservoir. Someone is out by the fence.", ""],
					["", "The camp. Right. Lock the office door and stay inside. We will send someone in the morning.", "pol_night"]])
			return _talk("POLICE", 2, [
				["", "Police, Hlubocany.", "pol_1"],
				["YOU", "It's the camp at the reservoir.", ""],
				["", "Lost property is on Wednesdays. Is there anything else?", "pol_day"]])
		"155":
			return _talk("AMBULANCE", 1, [
				["", "Emergency.", "amb_1"],
				["YOU", "It's the camp at the reservoir.", ""],
				["", "Is anyone hurt? The forest road is closed to us after dark. Bandage it and ring in the morning.", "amb_2"]])
		"0602618247":
			return _machine("EUROTEL", 0, [["", "The mobile subscriber is unavailable. Please call later.", "nela"]])
		"0267314420":
			var vera := [["", "This is Vera Kralova. If it is about the camp, the camp is fine.", "vera_1"]]
			if int(ctx.get("nights_visited", 0)) >= 3:
				vera = [["", "This is Vera Kralova. If it is about the camp, count them again.", "vera_2"]]
			return _machine("VERA", 4, vera)
		CLOCK:
			return {"kind": "machine", "rings": 0, "who": "TIME", "lines": [{"who": "", "text": "At the third stroke it will be %s." % _clock_text(hour), "voice": "clock"}], "effect": "clock"}
		OWN_NUMBER:
			return {"kind": "busy", "rings": 0}
		HRUBY:
			# Mr Hruby kept the lake. The number is crossed out on the board.
			if night and hour >= 23.0 and n == 0:
				return {"kind": "talk", "rings": 7, "who": "", "lines": [
					{"who": "", "text": "(water, dripping, close to the receiver)", "voice": "hruby"},
					{"who": "YOU", "text": "Hello? Mr Hruby?", "voice": ""},
					{"who": "", "text": "(a breath, a long one, as if through a wet cloth)", "voice": ""}], "effect": "hruby"}
			return {"kind": "sit", "rings": 0}
	return {"kind": "sit", "rings": 0}


static func _electrician(ctx: Dictionary, night: bool, n: int) -> Dictionary:
	if bool(ctx.get("electrician_coming", false)):
		return _talk("NOVOTNY", 2, [["", "I said I'm on my way. Don't ring again.", "nov_coming"]])
	var fault := bool(ctx.get("power_fault", false))
	if not night:
		var day := [
			["", "Novotny.", "nov_1"],
			["YOU", "It's the camp at the reservoir. The power.", ""]]
		if fault:
			day.append(["", "Vera's place. The main again. Right, I'll come out. Half an hour. Sixty for the call-out.", "nov_day"])
			return _talk("NOVOTNY", 2, day, "electrician")
		day.append(["", "Nothing's broken? Then I'm not driving out to look at a working box.", "nov_nothing"])
		return _talk("NOVOTNY", 2, day)
	var lines := [
		["", "Mm. Novotny.", "nov_night_1"],
		["YOU", "It's the camp at the reservoir. The power's out.", ""]]
	if bool(ctx.get("hunted", false)):
		lines.append(["", "No. Not tonight. I drove past there an hour ago and I didn't stop. Ring me in the morning.", "nov_refuse"])
		return _talk("NOVOTNY", 7, lines)
	if not fault:
		lines.append(["", "Then why are you ringing me at this hour?", "nov_night_nothing"])
		return _talk("NOVOTNY", 6, lines)
	lines.append(["", "It's gone nine. Double after nine: a hundred and twenty. I'll be an hour. Leave the barrier up.", "nov_night"])
	return _talk("NOVOTNY", 6 if n == 0 else 3, lines, "electrician")


static func _talk(who: String, rings: int, lines: Array, effect := "") -> Dictionary:
	return {"kind": "talk", "rings": rings, "who": who, "lines": _lines(lines), "effect": effect}


static func _machine(who: String, rings: int, lines: Array) -> Dictionary:
	return {"kind": "machine", "rings": rings, "who": who, "lines": _lines(lines), "effect": ""}


static func _lines(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append({"who": str(r[0]), "text": str(r[1]), "voice": str(r[2])})
	return out


static func _clock_text(hour: float) -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%d:%02d precisely" % [h, m]
