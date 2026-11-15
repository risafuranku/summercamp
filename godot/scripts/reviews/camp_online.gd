extends RefCounted

## The camp on the office PC's web (out of main.gd 15. 11.): Atlas (scripts/reviews/goggle.gd,
## it was Goggle) takes the guests' reviews and gives the camp its tier, the blueprints its
## stars open and the guests they bring, the banners bought there, a review removed or
## answered; the Bazaar sells what checked-out parties left behind; the Builder's graphs
## keep each day. main keeps the objects (_goggle, _bazaar, _day_graph) and answers the PC's
## apps through atlas_hour, atlas_buy_ad, goggle_remove, goggle_reply, goggle_mail_replied,
## bazaar_list.

const SEATS = preload("res://scripts/seats/seats.gd")
var main: Node


func _init(main_node: Node) -> void:
	main = main_node


## A party checked out: what they left behind goes to the lost and found.
func on_guest_state(guest_id: int, _old: String, new_state: String) -> void:
	if new_state != "departed" or not main._gameplay_started or CoreRoot.get_state() == null or not Coop.sim_here():
		return
	for g in CoreRoot.get_state().guests:
		if g is Dictionary and int((g as Dictionary).get("id", -1)) == guest_id:
			var where := ""
			var where_shown := ""
			if main._day_events != null:
				var c: Vector2i = main._day_events._lodging_of(g)
				if c.x >= 0:
					where = "%s %d:%d" % [main._day_events._label_at(c).capitalize(), c.x, c.y]
					where_shown = "%s %d:%d" % [tr(main._day_events._label_at(c).capitalize()), c.x, c.y]
			var it: Dictionary = main._bazaar.on_checkout(str(g.get("name", "")), where, main._day_index, str(g.get("archetype", "")))
			if not it.is_empty() and main._hud_manager != null:
				# (" in " + the place went into the line English, 4. 11.)
				if where_shown != "":
					main._hud_manager.push_status(main.LANG.f("Left behind in %s by %s: %s.", [where_shown, str(it["from"]), tr(str(it["name"]))]))
				else:
					main._hud_manager.push_status(main.LANG.f("Left behind by %s: %s.", [str(it["from"]), tr(str(it["name"]))]))
			return


## The morning: what sold on the bazaar is paid; the lost and found has its say.
func settle_bazaar() -> void:
	var r: Dictionary = main._bazaar.settle(main._day_index)
	for it in r["sold"]:
		if CoreRoot.actions != null and int(it["price"]) > 0:
			CoreRoot.actions.add_money(int(it["price"]))
		if main._hud_manager != null:
			if bool(it.get("uncanny", false)):
				main._hud_manager.push_status("Bazaar: the red shoe sold for $1. The buyer left no name.", 2)
			else:
				main._hud_manager.push_status("Bazaar: the %s sold. $%d." % [str(it["short"]).to_lower(), int(it["price"])], 1)
	if main._hud_manager != null:
		for it in r["back"]:
			main._hud_manager.push_status("The red shoe is in the lost and found again.", 2)
		for it in r["found"]:
			main._hud_manager.push_status("In the lost and found this morning: %s. Nobody left it." % str(it["name"]), 2)


# ── Atlas (scripts/reviews/goggle.gd, the PC's fifth tab; it was Goggle) ───────

## At the start of play: a new camp's page (last summer's reviews), a loaded one's, or a
## save from before the page (its guests' reviews put up again).
func setup_goggle() -> void:
	if not main._pending_goggle.is_empty():
		main._goggle.import_state(main._pending_goggle)
		main._pending_goggle.clear()
	elif main._goggle_fresh:
		main._goggle.reset(main.world_generator.world_seed if main.world_generator != null else 0)
		var state = CoreRoot.get_state()
		if state != null:
			for r in state.guest_reviews:
				if r is Dictionary:
					main._goggle.add_guest_review(r, main._day_index)
		main._goggle.check_tier(main._day_index)
	if not main._pending_graph.is_empty():
		main._day_graph.import_state(main._pending_graph)
		main._pending_graph.clear()
	elif main._goggle_fresh:
		main._day_graph.reset()
	main._goggle_fresh = false
	if not EventBus.guest_review_posted.is_connected(_on_review):
		EventBus.guest_review_posted.connect(_on_review)


func _on_review(review: Dictionary) -> void:
	if not main._gameplay_started or not Coop.sim_here() or not (review is Dictionary):
		return
	main._goggle.add_guest_review(review, main._day_index)
	_announce_tier(main._goggle.check_tier(main._day_index))


func _announce_tier(opened: int) -> void:
	if opened < 1 or main._hud_manager == null:
		return
	main._hud_manager.push_status("%d guests in the camp. Builder 98 has new blueprints." % int(main._goggle.TIERS[opened]["guests"]), 1)
	_pop_blueprints(opened)


## Builder 98's window of the new blueprints over whatever you are doing, wherever you are
## (the user 4. 11.: it waited in the Builder till you next sat at the PC): the best three
## of the tier, OK or a while and it goes; the Builder then has them NEW on their cards and
## does not show the window again.
const BLUEPRINT_NEWS = preload("res://scripts/builder/blueprint_news.gd")
const BUILDER_MODULE_S = preload("res://scripts/builder_module.gd")
const BLUEPRINT_POP_SEC := 9.0


func _pop_blueprints(tier: int) -> void:
	var opened: Array = []
	for it in main._goggle.TIERS[tier]["items"]:
		if not str(it).begins_with("upgrade:"):
			opened.append(str(it))
	if opened.is_empty():
		return
	var price := func(t: String) -> int:
		var def = CoreRoot.registry.get_def(StringName(t)) if CoreRoot != null and CoreRoot.registry != null else null
		return int(def.cost) if def != null and "cost" in def else 0
	opened.sort_custom(func(a, b): return price.call(a) > price.call(b))
	var rows: Array = []
	for t in opened.slice(0, 3):
		var icon_path := str(BUILDER_MODULE_S.ITEM_ICONS.get(t, ""))
		rows.append({"type": t, "name": str(BUILDER_MODULE_S.SHORT_NAMES.get(t, t)), "price": price.call(t),
			"icon": load(icon_path) if icon_path != "" and ResourceLoader.exists(icon_path) else null})
	# The Builder's own record: seen, and NEW on their cards.
	var pc = main._interior_manager._building_interior.get("_crt_ui") if main._interior_manager != null and main._interior_manager.get("_building_interior") != null else null
	if pc != null and pc.has_method("stored") and pc.has_method("store"):
		var st: Dictionary = (pc.stored("blueprints", {}) as Dictionary).duplicate(true)
		st["seen"] = maxi(int(st.get("seen", 0)), tier)
		var fresh: Array = st.get("fresh", [])
		for it in opened:
			if not fresh.has(it):
				fresh.append(it)
		st["fresh"] = fresh
		pc.store("blueprints", st)
	var layer := CanvasLayer.new()
	layer.name = "BlueprintNews"
	layer.layer = 126
	SEATS.screen_of(main).add_child(layer)
	var w = BLUEPRINT_NEWS.new()
	w.setup(rows, int(main._goggle.TIERS[tier]["guests"]), maxi(0, opened.size() - rows.size()))
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var k := maxf(1.0, floorf(vs.y / 320.0))
	w.scale = Vector2(k, k)
	w.position = ((vs - w.size * k) * 0.5).floor()
	layer.add_child(w)
	w.done.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	main.get_tree().create_timer(BLUEPRINT_POP_SEC).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())


## Builder 98's blueprints open by the guests in the camp at once (goggle.check_guests;
## 10, 20, 30...), not by the rating (Richard, 20. 10.). Counted every two seconds.
var blueprint_guests_t := 0.0


func tick_blueprint_guests(delta: float) -> void:
	if not main._gameplay_started or main._menu_mode or GuestManager == null:
		return
	blueprint_guests_t -= delta
	if blueprint_guests_t > 0.0:
		return
	blueprint_guests_t = 2.0
	_announce_tier(main._goggle.check_guests(guests_in_camp()))


## People staying in the camp now (each party's size; not the ones still at the gate).
func guests_in_camp() -> int:
	var n := 0
	if GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
				n += int(g.get("party_size", 1))
	return n


## The morning: SpotlessName's removals done (or caught), the apologies answered.
func settle_goggle() -> void:
	_record_day_graph(main._day_index - 1)
	_morning_line()
	var r: Dictionary = main._goggle.settle(main._day_index)
	if main._hud_manager != null:
		for e in r["removed"]:
			main._hud_manager.push_status("SpotlessName Ltd: %s's review is gone." % str(e["name"]), 1)
		for e in r["caught"]:
			main._hud_manager.push_status("Atlas caught the removal of %s's review. It stays, and so does the fee." % str(e["name"]), 2)
		for e in r["edited"]:
			main._hud_manager.push_status("Atlas: %s added a star to their review." % str(e["name"]), 1)
	_announce_tier(int(r["tier"]))


## The hour now counted from day 0: Atlas's campaigns run from hour to hour.
func atlas_hour() -> int:
	return main._day_index * 24 + int(main._time_of_day_hours)


## Atlas's advertising page: a campaign of `kind` (goggle.ADS) for `days`, paid now and
## running from this hour. {ok, cost, reason}.
func atlas_buy_ad(kind: String, days: int) -> Dictionary:
	var cost: int = main._goggle.ad_cost(kind, days)
	if CoreRoot.get_money() < cost:
		return {"ok": false, "reason": "money", "cost": cost}
	var now := atlas_hour()
	if not main._goggle.buy_ad(kind, days, now):
		return {"ok": false, "reason": "no", "cost": cost}
	CoreRoot.actions.spend_money(cost)
	CoreRoot.actions.note_camp("ads", cost)
	if Coop.is_client():
		# The host's page runs it (the fee goes with the till).
		Coop.send_request("atlas_ad", [kind, days, now])
	return {"ok": true, "cost": cost}


## Atlas's campaigns that are over (looked at every two seconds where the camp runs):
## the status line, and Atlas's mail with what it did, as RollerCoaster Tycoon's news
## said a campaign had finished.
var ads_t := 0.0


func tick_ads(delta: float) -> void:
	ads_t -= delta
	if ads_t > 0.0 or not main._gameplay_started or main._menu_mode:
		return
	ads_t = 2.0
	for a in main._goggle.end_ads(atlas_hour()):
		var what: String = str(main._goggle.ADS[str(a["kind"])]["name"])
		if main._hud_manager != null:
			main._hud_manager.push_status("Atlas: your campaign (%s) has ended." % what, 1)
		if EmailManager != null and EmailManager.has_method("schedule_pool_mail"):
			var at: int = main._day_index * 1440 + int(main._time_of_day_hours * 60.0) + 10
			EmailManager.schedule_pool_mail({"day": at / 1440, "time": "%02d:%02d" % [(at % 1440) / 60, at % 60],
				"from": "Atlas s.r.o. <reklama@atlas.cz>", "sender": "Atlas s.r.o.", "type": "system",
				"subject": "Your campaign on Atlas has ended",
				"body": "Dear customer,\n\nyour campaign %s (%s) has ended.\n\nShown: %d times\nClicked: %d times\nBooking letters while it ran: %d\n\nThank you for advertising on Atlas. Another campaign can be ordered at any time on Atlas, under Advertise.\n\nAtlas s.r.o., advertising\nNa Porici 12, Praha 1" % [
					what, "%d day%s" % [int(a["days"]), "" if int(a["days"]) == 1 else "s"], int(a["views"]), int(a["clicks"]), int(a["letters"])]})


## Reviews tab: have a review taken down by the morning. {ok, cost, reason}.
func goggle_remove(id: int) -> Dictionary:
	var cost: int = main._goggle.removal_cost()
	if CoreRoot.get_money() < cost:
		return {"ok": false, "reason": "money", "cost": cost}
	if Coop.is_client():
		# The host's page; the fee goes with the till.
		CoreRoot.actions.spend_money(cost)
		CoreRoot.actions.note_camp("ads", cost)
		var e: Dictionary = main._goggle.by_id(id)
		if not e.is_empty():
			e["removing"] = main._day_index
		Coop.send_request("goggle_remove", [id])
		return {"ok": true, "cost": cost}
	if not main._goggle.request_removal(id, main._day_index):
		return {"ok": false, "reason": "no", "cost": cost}
	CoreRoot.actions.spend_money(cost)
	CoreRoot.actions.note_camp("ads", cost)
	return {"ok": true, "cost": cost}


## The day that ended, for Builder 98's Graphs: the cash, the people staying, their mood,
## the rating it had.
func _record_day_graph(day: int) -> void:
	if day < 1:
		return
	var people := 0
	var mood := 0.0
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			if g is Dictionary:
				people += int(g.get("party_size", 1))
	if GuestManager != null and GuestManager.has_method("get_camp_mood_summary"):
		mood = float((GuestManager.get_camp_mood_summary() as Dictionary).get("avg_mood", 0.0))
	# The businesses' takings of the day that closed (each site's "yesterday" by now).
	var takings := {}
	var st = CoreRoot.get_state()
	var sites: Dictionary = st.biz.get("sites", {}) if st != null and st.biz is Dictionary else {}
	for key in sites:
		var site: Dictionary = sites[key] if sites[key] is Dictionary else {}
		var kind := str(site.get("kind", ""))
		if kind != "":
			takings[kind] = int(takings.get(kind, 0)) + int((site.get("yesterday", {}) as Dictionary).get("takings", 0))
	main._day_graph.record(day, CoreRoot.get_money(), people, mood, main._goggle.rating(day), takings)


## The morning: yesterday in a line on the feed (and so in CampStat's Log): what it made,
## who stayed, how they liked it. Not till there is a day before it to count from.
func _morning_line() -> void:
	var d: int = main._day_index - 1
	if main._hud_manager == null or not main._day_graph.days.has(d) or not main._day_graph.days.has(d - 1):
		return
	var y: Dictionary = main._day_graph.days[d]
	var made := int(y.get("money", 0)) - int((main._day_graph.days[d - 1] as Dictionary).get("money", 0))
	main._hud_manager.push_status(main.LANG.f("Yesterday: %s$%d, %d guests, %.1f stars.", ["+" if made >= 0 else "-", absi(made), int(y.get("guests", 0)), float(y.get("rating", 0.0))]), 1 if made >= 0 else 2, "morning")


## Reviews tab: answer a review as the owner ("sorry" / "weather"). The guest book's mail
## of the same review is answered with it (its effect on the bookings).
func goggle_reply(id: int, kind: String) -> void:
	var e: Dictionary = main._goggle.by_id(id)
	if e.is_empty():
		return
	if Coop.is_client():
		e["reply"] = kind
		e["reply_day"] = main._day_index
		Coop.send_request("goggle_reply", [id, kind])
		return
	if not main._goggle.reply(id, kind, main._day_index):
		return
	if EmailManager != null and EmailManager.has_method("reply_to_review") and int(e["guest_id"]) >= 0:
		for m in EmailManager.inbox:
			if m is Dictionary and str(m.get("type", "")) == "review" and int((m.get("review", {}) as Dictionary).get("guest_id", -2)) == int(e["guest_id"]):
				EmailManager.reply_to_review(m, "sorry" if kind == "sorry" else "defend")
				break


## The guest book mail answered in CampMail: the same review on Atlas has the answer.
func goggle_mail_replied(guest_id: int, reply_id: String) -> void:
	if guest_id < 0:
		return
	for e in main._goggle.reviews:
		if int(e["guest_id"]) == guest_id and str(e["reply"]) == "":
			main._goggle.reply(int(e["id"]), {"sorry": "sorry", "thank": "thanks"}.get(reply_id, "weather"), main._day_index)
			return


## Builder 98: may this be built (or this upgrade bought) at the camp's rating?
func goggle_unlocked(item: String) -> bool:
	return main._goggle.unlocked(item)


## The bazaar page's "put it up" link (browser).
func bazaar_list(id: int) -> bool:
	# Co-op: the host's lost and found (the pulse brings it back as the host has it).
	if Coop.is_client():
		Coop.send_request("bazaar_list", [id])
	return main._bazaar.list(id, main._day_index)
