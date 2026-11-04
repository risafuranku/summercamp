extends RefCounted

## What Liblice's two shops sell, read by the rooms that show it (jednota_view.gd,
## kiosk_view.gd), the counter that sells it (counter_shop.gd) and the close-up that
## takes the money for it (counter_pay.gd): each good's picture and how it lands on the
## counter, what it costs in which shop and what she says as she takes it down, the
## price tags and the money's own pieces. The art is in assets/textury/shop/ (Grok,
## tools/artgen/shop_art.py).

const K = preload("res://scripts/interior_kit.gd")
const LANG = preload("res://scripts/lang.gd")
const SHOP := "res://assets/textury/shop/"
const JEDNOTA := "res://assets/textury/jednota/"
const SFX := "res://assets/sfx/shop/"

## Each good on the counter: its picture, metres tall there (a little bigger than life, so
## it reads across the counter), the sound it is put down with.
const LOOK := {
	"cigs": {"tex": JEDNOTA + "goods_cigs.png", "h": 0.17, "put": "put_pack"},
	"beer": {"tex": JEDNOTA + "goods_beer.png", "h": 0.34, "put": "put_glass"},
	"card": {"tex": "res://assets/textury/items/card.png", "h": 0.16, "put": "put_pack"},
	"matches": {"tex": SHOP + "good_matches.png", "h": 0.09, "put": "put_box"},
	"candle": {"tex": SHOP + "good_candle.png", "h": 0.15, "put": "put_glass"},
	"bread": {"tex": JEDNOTA + "goods_bread.png", "h": 0.2, "put": "put_soft"},
	"kofola": {"tex": "res://assets/textury/pub/bottle_kofola.png", "h": 0.3, "put": "put_glass"},
	"newspaper": {"tex": SHOP + "good_newspaper.png", "h": 0.26, "put": "put_paper"},
}
## What is on sale where: the price (dollars) and what she says taking it down. Price 0:
## none to be had, only the line.
const STOCK := {
	"jednota": {
		"cigs": {"price": 2, "say": "Start. Twenty. Two dollars."},
		"beer": {"price": 1, "say": "Lesnak. A dollar. Bring the bottle back next time."},
		"card": {"price": 1, "say": "Rychla kacka. A dollar. Scratch it at home, not on my counter."},
		"batteries": {"price": 0, "say": "Batteries are sold out until further notice. Please stop asking."},
		"matches": {"price": 1, "say": "Matches. A dollar. Ten in a box, it used to be forty."},
		"candle": {"price": 1, "say": "A candle, a dollar. Light it and go, you do not have to stay and watch it."},
		"bread": {"price": 1, "say": "Bread, a dollar. It came Tuesday. It is still bread."},
		"kofola": {"price": 1, "say": "Kofola, a dollar. Cold, when the fridge feels like it."},
		"newspaper": {"price": 1, "say": "The Bulletin, a dollar. It comes out whether anything happened or not."},
	},
	"kiosk": {
		"cigs": {"price": 3, "say": "Start. Three dollars, it is a petrol station. Mind the pumps with that."},
		"kofola": {"price": 2, "say": "Kofola. Two dollars, love. Same bottle as at the Jednota, further from the Jednota."},
		"matches": {"price": 1, "say": "Matches, a dollar. Not by the pumps, love."},
		"newspaper": {"price": 1, "say": "The Bulletin, a dollar. Lojza does the crossword. Nobody has ever finished it."},
	},
}
## The bread comes Tuesdays and Fridays (her own words): what she says of it by the weekday.
const BREAD_DAYS := {"Tuesday": "Bread, a dollar. This morning's.", "Friday": "Bread, a dollar. This morning's.",
	"Saturday": "Bread, a dollar. It came Friday. It is still bread.", "Sunday": "Bread, a dollar. It came Friday. It is still bread.",
	"Monday": "Bread, a dollar. It came Friday. It is still bread."}
## Her words at the counter, each shop in its own voice.
const LINES := {
	"jednota": {
		"who": "Mrs Novotna",
		"back": ["Back it goes.", "As you like.", "People change their minds. It does not help them."],
		"more": "Anything else?",
		"none": "And what am I to ring up, the air?",
		"crowded": "That is enough on my counter. Pay for it first.",
		"bag": "And where will you put it? Your bag is full.",
		"stays": "That stays here, your bag is full. The rest makes $%d.",
		"total": "That makes $%d.",
		"short": "That's %d dollars. You have not got %d dollars.",
		"exact": "Exact. Good.",
		"change": "$%d back.",
		"big": "Have you nothing smaller? No. Nobody has.",
		"thanks": ["There you are.", "We shut at five.", "Mind the step."],
		"left": "The rest stays on the counter until you have room for it.",
		"cancel": "It can lie there. It is not going anywhere.",
		"candles": "Your Vera took them three at a time too.",
	},
	"kiosk": {
		"who": "Mrs Lojzova",
		"back": ["Put it back then, love.", "Your money.", "Please yourself."],
		"more": "Anything else, love?",
		"short_cigs": "Start is three dollars here. Two at the Jednota. Go to the Jednota.",
		"none": "Ring up what, love?",
		"crowded": "One thing at a time, love. Pay for that lot first.",
		"bag": "Your bag is full, love. Make room first.",
		"stays": "That stays here, love, your bag is full. The rest makes $%d.",
		"total": "That makes $%d, love.",
		"short": "That's %d dollars. You have not got %d dollars.",
		"exact": "Exact. Lojza would be pleased.",
		"change": "$%d back, love.",
		"big": "A note like that in a kiosk. Lojza will want to see it.",
		"thanks": ["Mind how you go, love.", "Pump first, then pay. You paid.", "Off you go."],
		"left": "The rest can wait here, love, until you have room.",
		"cancel": "It will keep, love.",
	},
}
## The money, as in the camp's own till (jednota/till_station.gd): coins to two, notes on.
const PIECES := [50, 20, 10, 5, 2, 1]
## How many of each a wallet holds, however rich the camp (two hundred and thirty at most).
const WALLET_CAP := {50: 3, 20: 2, 10: 2, 5: 2, 2: 3, 1: 4}


## What she says taking `id` down today.
static func taking_line(place: String, id: String) -> String:
	if id == "bread":
		var weekday := str(Season.WEEKDAYS[int(Season.date_of(CoreRoot.get_day())["wd"])])
		if BREAD_DAYS.has(weekday):
			return str(BREAD_DAYS[weekday])
	return str(STOCK[place][id]["say"])


## What your money looks like in the wallet: value -> how many.
static func wallet(money: int) -> Dictionary:
	var out := {}
	var left := money
	for v in PIECES:
		var n := mini(int(WALLET_CAP[v]), left / int(v))
		if n > 0:
			out[v] = n
			left -= n * int(v)
	return out


## The fewest pieces that make `amount` (the change she counts out), biggest first.
static func change_in(amount: int) -> Array:
	var out: Array = []
	var left := amount
	for v in PIECES:
		while left >= int(v):
			out.append(v)
			left -= int(v)
	return out


## The value as printed on the money (Czech money is ten crowns to the game's dollar).
static func face(v: int) -> String:
	return str(v * LANG.CROWNS_PER_DOLLAR) if LANG.is_czech() else str(v)


## A price tag's picture (shop_art.py paints them in both languages).
static func tag_path(price: int) -> String:
	return SHOP + "tag_%d%s.png" % [price, "_cs" if LANG.is_czech() else ""]


## A sprite of ours standing on `pos` (bottom edge), `height` metres tall, as wide as its
## picture says; `K.cutout` for pictures outside the camp's folder.
static func sprite(parent: Node3D, path: String, height: float, pos: Vector3, yaw_deg := 0.0, billboard := false, name := "Good") -> MeshInstance3D:
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var size := Vector2(height, height)
	if t != null:
		size.x = height * float(t.get_width()) / float(t.get_height())
	var mi := K.cutout(parent, "", size, pos, yaw_deg, billboard, name)
	(mi.material_override as StandardMaterial3D).albedo_texture = t
	return mi


## A good's own sprite for the counter.
static func good(parent: Node3D, id: String, pos: Vector3, yaw_deg := 0.0, billboard := false) -> MeshInstance3D:
	var look: Dictionary = LOOK.get(id, {})
	return sprite(parent, str(look.get("tex", "")), float(look.get("h", 0.2)), pos, yaw_deg, billboard, "On_" + id)


## The price tag standing by the goods.
static func tag(parent: Node3D, price: int, pos: Vector3, yaw_deg := 0.0, height := 0.11) -> MeshInstance3D:
	return sprite(parent, tag_path(price), height, pos, yaw_deg, false, "Tag")


## The counters' worn laminate, world-mapped like K.surface.
static func laminate(metres := 1.1) -> StandardMaterial3D:
	var m := K.surface("plastic", metres).duplicate() as StandardMaterial3D
	var path := SHOP + "laminate.png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	return m
