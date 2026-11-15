extends RefCounted

## The demo build (TODO.md D1, the Q&A of 15. 11.): a camp's first DAYS days, then on the
## next morning the clock stops at END_AT, the mail that ends it comes (demo_end.gd) and
## the reception PC shows the trial's nag with the Steam Wishlist (os98/apps/trial_app.gd).
## A build is the demo when it is exported with the feature tag "demo"; the tools ask for
## it with `-- --demo`.

const DAYS := 3
## The morning after the last day, in hours: the clock stops here and the mail comes.
const END_AT := 7.2
## The Steam store's app id once the page exists ("" till then: the store's search).
const STEAM_APP_ID := ""
const GAME_NAME := "Cursed Camp Manager Simulator"


static func active() -> bool:
	return OS.has_feature("demo") or OS.get_cmdline_user_args().has("--demo")


## The store page to wishlist the game on: in the Steam client when it runs (the Deck),
## else the browser.
static func store_url() -> String:
	if STEAM_APP_ID != "":
		if OS.has_feature("steam") or OS.get_environment("SteamAppId") != "":
			return "steam://store/%s" % STEAM_APP_ID
		return "https://store.steampowered.com/app/%s/" % STEAM_APP_ID
	return "https://store.steampowered.com/search/?term=%s" % GAME_NAME.uri_encode()
