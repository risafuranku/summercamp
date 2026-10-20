extends RefCounted

## The pub's fun (the brief of 20. 10.: "the LUCKY 7, darts, cards: the guests play, you
## can too; it raises what they spend and their mood, it is the fun in their needs"):
## the slot machine by the corner, the dartboard on the left wall, the cards on the second
## table. Pure data and arithmetic; the pub's state is scripts/pub/taproom.gd ("fun"),
## the stations scripts/pub/slot_station.gd, darts_station.gd, cards_station.gd.

# ── LUCKY 7 ──────────────────────────────────────────────────────────────────

## The reels' pictures (pub/reel_<name>.png) and how often each comes up.
const SYMBOLS := ["seven", "cherry", "bell", "lemon", "bar", "plum"]
const WEIGHTS := {"seven": 1, "cherry": 5, "bell": 3, "lemon": 5, "bar": 2, "plum": 5}
## A game costs a coin (dollars); what comes out for a line, times the coin.
const COIN := 1
const PAY_THREE := {"seven": 50, "bell": 15, "bar": 10, "cherry": 8, "lemon": 5, "plum": 5}
const PAY_TWO_CHERRIES := 2
const PAY_ONE_CHERRY := 1
## Seconds the reels spin, and the gap between them stopping (left to right).
const SPIN_SEC := 1.2
const STOP_GAP := 0.45


static func _pick(h: int) -> String:
	var total := 0
	for s in SYMBOLS:
		total += int(WEIGHTS[s])
	var r := absi(h) % total
	for s in SYMBOLS:
		r -= int(WEIGHTS[s])
		if r < 0:
			return s
	return "lemon"


## Where the three reels stop for game `seed` (the same on every machine).
static func spin(seed: int) -> Array:
	return [_pick(hash("%d/a" % seed)), _pick(hash("%d/b" % seed)), _pick(hash("%d/c" % seed))]


## What a line pays (dollars) for one coin.
static func payout(reels: Array) -> int:
	if reels.size() == 3 and reels[0] == reels[1] and reels[1] == reels[2]:
		return int(PAY_THREE.get(str(reels[0]), 5)) * COIN
	var cherries := reels.count("cherry")
	if cherries == 2:
		return PAY_TWO_CHERRIES * COIN
	if cherries == 1 and reels[0] == "cherry":
		return PAY_ONE_CHERRY * COIN
	return 0


## The machine's take on average a game (the house keeps this share of the coin).
static func house_edge() -> float:
	var total := 0
	for s in SYMBOLS:
		total += int(WEIGHTS[s])
	var back := 0.0
	for a in SYMBOLS:
		for b in SYMBOLS:
			for c in SYMBOLS:
				var p := float(WEIGHTS[a]) * float(WEIGHTS[b]) * float(WEIGHTS[c]) / pow(float(total), 3.0)
				back += p * float(payout([a, b, c]))
	return 1.0 - back / float(COIN)


# ── darts ────────────────────────────────────────────────────────────────────

## The board's numbers clockwise from the top.
const SECTORS := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
## The rings as shares of the double ring's outer edge: bull, outer bull, the treble
## ring, the double ring.
const BULL := 0.037
const OUTER_BULL := 0.094
const TREBLE := Vector2(0.582, 0.629)
const DOUBLE := Vector2(0.953, 1.0)
## Darts a turn.
const DARTS := 3


## A dart's score where it went in: `at` from the board's middle in shares of the double
## ring's edge (x right, y down). Off the board: 0.
static func dart_score(at: Vector2) -> int:
	var r := at.length()
	if r <= BULL:
		return 50
	if r <= OUTER_BULL:
		return 25
	if r > DOUBLE.y:
		return 0
	# Clockwise from straight up; each sector is 18 degrees, the 20 centred on the top.
	var ang := fposmod(rad_to_deg(atan2(at.x, -at.y)) + 9.0, 360.0)
	var n := int(SECTORS[int(ang / 18.0) % 20])
	if r >= TREBLE.x and r <= TREBLE.y:
		return n * 3
	if r >= DOUBLE.x:
		return n * 2
	return n


## A guest's turn of three darts (the same on every machine): how good they are by kind.
static func guest_turn(archetype: String, seed: int) -> Array:
	var skill: float = {"drunk": 0.55, "tramp": 0.45, "quiet_guy": 0.3, "cheap_chick": 0.6, "picker": 0.5, "family": 0.65}.get(archetype, 0.5)
	var out: Array = []
	for i in DARTS:
		var h := absi(hash("%d/%d" % [seed, i]))
		var a := float(h % 3600) / 10.0
		var d := skill * float((h / 3600) % 1000) / 1000.0 * 1.1
		out.append(Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a))) * d)
	return out


# ── cards: oko bere ──────────────────────────────────────────────────────────

## The German-suited pack of the pub's cards (hearts drawn, pub/card_<rank>.png): what
## each counts in oko bere (the Unter and the Ober one, the King two, the Ace eleven).
const RANKS := ["7", "8", "9", "10", "unter", "ober", "king", "ace"]
const VALUE := {"7": 7, "8": 8, "9": 9, "10": 10, "unter": 1, "ober": 1, "king": 2, "ace": 11}
## The stake of a game (dollars), and when the guest dealing stops drawing.
const STAKE := 2
const DEALER_STANDS := 17


## The pack shuffled for game `seed` (four of each rank: the four suits).
static func pack(seed: int) -> Array:
	var out: Array = []
	for r in RANKS:
		for i in 4:
			out.append(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## A hand's count; two aces ("oko") is the best there is.
static func count(hand: Array) -> int:
	if hand.size() == 2 and hand[0] == "ace" and hand[1] == "ace":
		return 21
	var n := 0
	for c in hand:
		n += int(VALUE.get(str(c), 0))
	return n


static func is_oko(hand: Array) -> bool:
	return hand.size() == 2 and hand[0] == "ace" and hand[1] == "ace"


## Who wins: 1 you, -1 the dealer, 0 nobody (the stake back). Over 21 loses (two aces
## never are).
static func result(mine: Array, theirs: Array) -> int:
	var a := count(mine)
	var b := count(theirs)
	if a > 21:
		return -1
	if b > 21:
		return 1
	if is_oko(mine) and not is_oko(theirs):
		return 1
	if is_oko(theirs) and not is_oko(mine):
		return -1
	return 1 if a > b else (-1 if b > a else 0)
