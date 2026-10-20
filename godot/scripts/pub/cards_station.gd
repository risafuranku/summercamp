extends "res://scripts/pub/pub_station.gd"

## Cards at the second table (the brief of 20. 10.: the pub's fun): oko bere with the
## Czech pack (pub_fun.gd), against whoever is in the pub, two dollars a game. The table's
## top is the station (pub_layout SURFACES "cards"); the cards are the pub's Grok cards
## (pub/card_<rank>.png, card_back.png).
##   the pack    a click: DEAL a game (two dollars on the table), then a card for you a
##               click; STAND (the frame) and the guest draws to seventeen
## Over twenty-one and you have lost; two aces (oko) beat everything. Win and the camp has
## their two dollars (the pub's takings); lose and they have yours, and like you better.

const FUN := preload("res://core/systems/pub_fun.gd")
const PACK_AT := Vector2(120, 180)
const PACK := Rect2(60, 110, 120, 140)
const MINE_AT := Vector2(250, 270)
const THEIRS_AT := Vector2(250, 92)
const CARD_STEP := 62.0
const CARD_M := 0.09

## The game: {seed, mine: [ranks], theirs: [ranks], drawn (cards off the pack), who,
## guest_id, over: -1 lost, 0 draw, 1 won, -2 going on} ({} none).
var _game: Dictionary = {}
var _mine_spr: Array = []
var _theirs_spr: Array = []
var _rng := RandomNumberGenerator.new()


func has_rail() -> bool:
	return false


func _build() -> void:
	super._build()
	_rng.randomize()
	put(sprite(PUB_TEX + "card_back.png", CARD_M, true), PACK_AT, 0.006)
	put(sprite(PUB_TEX + "card_back.png", CARD_M, true), PACK_AT + Vector2(3, -3), 0.009)
	for i in 6:
		var a := sprite(PUB_TEX + "card_back.png", CARD_M, true)
		a.visible = false
		_mine_spr.append(a)
		var b := sprite(PUB_TEX + "card_back.png", CARD_M, true)
		b.visible = false
		_theirs_spr.append(b)


func _show() -> void:
	var mine: Array = _game.get("mine", [])
	var theirs: Array = _game.get("theirs", [])
	var done := int(_game.get("over", -2)) != -2
	for i in _mine_spr.size():
		var s: Sprite3D = _mine_spr[i]
		s.visible = i < mine.size()
		if s.visible:
			retex(s, PUB_TEX + "card_%s.png" % str(mine[i]), CARD_M)
			put(s, MINE_AT + Vector2(CARD_STEP * i, 0), 0.006 + 0.001 * i)
	for i in _theirs_spr.size():
		var s2: Sprite3D = _theirs_spr[i]
		s2.visible = i < theirs.size()
		if s2.visible:
			# Theirs face down till you stand.
			retex(s2, PUB_TEX + ("card_%s.png" % str(theirs[i]) if done or i == 0 else "card_back.png"), CARD_M)
			put(s2, THEIRS_AT + Vector2(CARD_STEP * i, 0), 0.006 + 0.001 * i)


## Who you play: the first in the pub ({} nobody).
func _opponent() -> Dictionary:
	var vis: Array = ORDERS_visitors()
	return vis[0] if not vis.is_empty() else {}


func ORDERS_visitors() -> Array:
	return load("res://scripts/food/orders.gd").visitors(building_key)


func _spots() -> Array:
	if _game.is_empty() or int(_game.get("over", -2)) != -2:
		var who := _opponent()
		if who.is_empty():
			return [{"id": "pack", "rect": PACK, "verb": "Nobody in to play with"}]
		return [{"id": "pack", "rect": PACK, "verb": "Deal a game of oko bere with %s: $%d" % [ORDERS_first(str(who["name"])), FUN.STAKE]}]
	return [{"id": "pack", "rect": PACK, "verb": "A card for you (%d)" % FUN.count(_game["mine"])}]


func hand_tool() -> String:
	return "open"


func _press(id: String) -> void:
	if id != "pack":
		return
	if _game.is_empty() or int(_game.get("over", -2)) != -2:
		_deal()
	else:
		_draw_mine()


func _deal() -> void:
	var who := _opponent()
	if who.is_empty():
		say("", "Nobody in to play with.")
		return
	var seed := _rng.randi()
	var pack := FUN.pack(seed)
	_game = {"seed": seed, "pack": pack, "drawn": 2, "mine": [pack[0]], "theirs": [pack[1]], "who": str(who["name"]), "guest_id": int(who["id"]), "over": -2}
	sfx("card_deal", -8.0)
	say(ORDERS_first(str(who["name"])), "Two dollars, then. Your card.")


func _draw_mine() -> void:
	var pack: Array = _game["pack"]
	(_game["mine"] as Array).append(pack[int(_game["drawn"])])
	_game["drawn"] = int(_game["drawn"]) + 1
	sfx("card_deal", -8.0, _rng.randf_range(0.95, 1.05))
	var n := FUN.count(_game["mine"])
	if FUN.is_oko(_game["mine"]):
		_stand()
	elif n > 21:
		_end()
	elif n == 21:
		_stand()


## You stand: the guest draws to seventeen, and the game is decided.
func _stand() -> void:
	var pack: Array = _game["pack"]
	if FUN.count(_game["mine"]) <= 21:
		while FUN.count(_game["theirs"]) < FUN.DEALER_STANDS and int(_game["drawn"]) < pack.size():
			(_game["theirs"] as Array).append(pack[int(_game["drawn"])])
			_game["drawn"] = int(_game["drawn"]) + 1
	_end()


func _end() -> void:
	var r := FUN.result(_game["mine"], _game["theirs"])
	_game["over"] = r
	var who := ORDERS_first(str(_game["who"]))
	taproom.cards_done(building_key, int(_game["guest_id"]), r)
	match r:
		1:
			pop("+$%d" % FUN.STAKE, PACK_AT + Vector2(0, -40), RETRO_UI.C_AMBER_LIGHT)
			say(who, "Oko! Lucky devil." if FUN.is_oko(_game["mine"]) else "%d. You win, curse you." % FUN.count(_game["mine"]))
		-1:
			pop("-$%d" % FUN.STAKE, PACK_AT + Vector2(0, -40), RETRO_UI.C_RED)
			say(who, "Over. Thank you kindly." if FUN.count(_game["mine"]) > 21 else "%d beats %d. Mine." % [FUN.count(_game["theirs"]), FUN.count(_game["mine"])])
		_:
			say(who, "The same. Keep your money.")


func bar_buttons() -> Array:
	if not _game.is_empty() and int(_game.get("over", -2)) == -2:
		return [{"id": "stand", "label": "STAND"}]
	return []


func bar_button(id: String) -> void:
	if id == "stand" and not _game.is_empty() and int(_game.get("over", -2)) == -2:
		_stand()


func bar_text() -> String:
	if _game.is_empty():
		return "OKO BERE  $%d" % FUN.STAKE
	return "YOU %d" % FUN.count(_game["mine"]) + ("   %s %d" % [ORDERS_first(str(_game["who"])).to_upper(), FUN.count(_game["theirs"])] if int(_game.get("over", -2)) != -2 else "")


# ── debug (tools/pub_check.gd) ───────────────────────────────────────────────

func debug_click(id: String) -> void:
	_press(id)
	_release(id)


func debug_game(mine: Array, theirs: Array) -> int:
	var who := _opponent()
	_game = {"seed": 1, "pack": [], "drawn": 0, "mine": mine, "theirs": theirs, "who": str(who.get("name", "Nobody")), "guest_id": int(who.get("id", -1)), "over": -2}
	_end()
	return int(_game["over"])
