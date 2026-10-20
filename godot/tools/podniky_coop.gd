extends "res://tools/coop_check.gd"

## The four places for two (the brief of 20. 10.: "every new station and mechanic works for
## two; checked on two copies"): a host and a joining copy on this machine (run by
## tools/podniky_coop.py), one camp with a corn stand, a pub, a bistro and a Jednota, the
## guests sent to each in turn. In each, one machine does the new thing and the other has
## it done too:
##   corn     the host hands over a drink; the joining one sees it served, hands over
##            another; the host has both
##   pub      the host pours a round (marks on the mats), the clock goes on: the bills
##            are asked for on both machines; the joining one settles one and pulls the
##            LUCKY 7's lever: the host has the bill paid and the reels spun
##   bistro   the joining one lays a sausage on the grill and serves the bufet's oldest
##            ticket: the host has the sausage on the grill and the ticket served
##   jednota  the joining one cuts and wraps a deli order: the host has it done
## Both look into the pub at the end (each sees the other at the bar).
## Each side's evals are tagged ["PODNIKY <role> <tag>", ...] in its log for the runner.
##   godot --path godot res://tools/podniky_coop.tscn -- --role=host --out=DIR

const CS := "get_tree().get_first_node_in_group('cornstands')"
const TR := "get_tree().get_first_node_in_group('taprooms')"
const KI := "get_tree().get_first_node_in_group('kitchens')"
const JE := "get_tree().get_first_node_in_group('jednotas')"
const CORN := "'11:11'"
const PUB := "'14:6'"
const REST := "'17:6'"
const SHOP := "'14:12'"


func _tag(role: String, tag: String, expr: String) -> Array:
	return ["eval", "['PODNIKY %s %s', %s]" % [role, tag, expr]]


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 60000], ["clear", 5, 5, 15, 12], ["build", "corn_stand", 11, 11, 0], ["build", "pub", 14, 6, 0],
			["build", "restaurant", 17, 6, 0], ["build", "vecerka", 14, 12, 0],
			["build", "cabin_1", 6, 8, 0], ["build", "cabin_1", 9, 8, 0], ["build", "cabin_1", 6, 12, 0], ["wait", 1.0],
			["coop_place", 8, 10, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_joined"], ["wait", 2.0],
			["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Jarda", "tramp", 1, 3],
			["hours", 0.4], ["checkin"], ["hours", 2.0], ["wait", 5.0],
			# The corn stand: a drink over the counter.
			["eval", "debug_send_guests_to('corn_stand', 300)"], ["wait", 3.0],
			_tag("host", "corn_drinks", CS + ".tickets(" + CORN + ", 'drink').size()"),
			["eval", CS + ".serve_drink(" + CORN + ", " + CS + ".tickets(" + CORN + ", 'drink')[0], " + CS + ".tickets(" + CORN + ", 'drink')[0]['kind'], 0.9, true)"],
			["wait", 1.0], _tag("host", "corn_served", CS + ".site(" + CORN + ")['served'].size()"),
			["coop_signal", "host_corn"], ["coop_wait_file", "client_corn"], ["wait", 2.0],
			_tag("host", "corn_after", CS + ".site(" + CORN + ")['served'].size()"),
			# The pub: a round on the mats, the bills asked for later.
			["eval", "debug_send_guests_to('pub', 400)"], ["wait", 3.0],
			_tag("host", "pub_poured", TR + ".debug_pour_some(" + PUB + ", 4)"),
			# Past their last round: the bills asked for, and not yet left on the bar.
			["hours", 0.3], ["until", TR + ".bills(" + PUB + ").size() > 0", 40.0],
			_tag("host", "pub_bills", TR + ".bills(" + PUB + ").size()"),
			_tag("host", "pub_bill_age", TR + ".bills(" + PUB + ")[0]['age'] if " + TR + ".bills(" + PUB + ").size() > 0 else -1"),
			_tag("host", "pub_now", TR + ".now_min()"),
			_tag("host", "pub_vis", "load('res://scripts/food/orders.gd').visitors(" + PUB + ")"),
			_tag("host", "pub_tabs", TR + ".site(" + PUB + ")['served'].size()"),
			["coop_signal", "host_pub"], ["coop_wait_file", "client_pub"], ["wait", 2.0],
			_tag("host", "pub_bills_after", TR + ".bills(" + PUB + ").size()"),
			_tag("host", "pub_slot", TR + ".fun(" + PUB + ")['slot'].get('seed', -1)"),
			# The bistro: the joining one at the grill and the bufet.
			["eval", "debug_send_guests_to('restaurant', 300)"], ["wait", 3.0],
			_tag("host", "rest_bufet", KI + ".tickets(" + REST + ", 'bufet').size()"),
			["coop_signal", "host_rest"], ["coop_wait_file", "client_rest"], ["wait", 2.0],
			_tag("host", "rest_grill", KI + ".site(" + REST + ")['grill'][0].size() > 0"),
			_tag("host", "rest_bufet_after", KI + ".tickets(" + REST + ", 'bufet').size()"),
			# The Jednota: the joining one at the deli counter.
			["eval", "debug_send_guests_to('vecerka', 300)"], ["wait", 6.0],
			# A deli order for sure (whether a guest wants one is their dice).
			["until", JE + ".deli_tickets(" + SHOP + ").size() > 0 or " + JE + ".debug_deli_order(" + SHOP + ", 'salami', 150)", 10.0], ["wait", 1.0],
			_tag("host", "shop_deli", JE + ".deli_tickets(" + SHOP + ").size()"),
			["coop_signal", "host_shop"], ["coop_wait_file", "client_shop"], ["wait", 2.0],
			_tag("host", "shop_deli_after", JE + ".deli_tickets(" + SHOP + ").size()"),
			# Both in the pub: the host at the tap.
			["eval", "debug_send_guests_to('pub', 300)"], ["wait", 2.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 4.0],
			["eval", "_interior_manager._service_interior._open_station('tap')"], ["wait", 2.0],
			["coop_signal", "host_in_pub"], ["coop_wait_file", "client_in_pub"], ["wait", 3.0], ["shot", "ph1_host_tap"],
			["coop_signal", "host_done"], ["coop_wait_file", "client_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 8, 10, -1.0], ["coop_signal", "client_joined"],
			# The corn stand.
			["coop_wait_file", "host_corn"], ["wait", 3.0],
			_tag("client", "corn_served", CS + ".site(" + CORN + ")['served'].size()"),
			_tag("client", "corn_drinks", CS + ".tickets(" + CORN + ", 'drink').size()"),
			["eval", CS + ".serve_drink(" + CORN + ", " + CS + ".tickets(" + CORN + ", 'drink')[0], " + CS + ".tickets(" + CORN + ", 'drink')[0]['kind'], 0.9, true)"],
			["wait", 1.0], _tag("client", "corn_mine", CS + ".site(" + CORN + ")['served'].size()"),
			["coop_signal", "client_corn"],
			# The pub.
			["coop_wait_file", "host_pub"], ["wait", 1.0],
			_tag("client", "pub_bills", TR + ".bills(" + PUB + ").size()"),
			_tag("client", "pub_now", TR + ".now_min()"),
			_tag("client", "pub_vis", "load('res://scripts/food/orders.gd').visitors(" + PUB + ")"),
			_tag("client", "pub_tabs", TR + ".site(" + PUB + ")['served'].size()"),
			_tag("client", "pub_settled", TR + ".debug_settle_first(" + PUB + ")"),
			["eval", TR + ".slot_play(" + PUB + ", 777, 'you')"], ["wait", 1.0],
			["coop_signal", "client_pub"],
			# The bistro.
			["coop_wait_file", "host_rest"], ["wait", 3.0],
			["eval", KI + ".act(" + REST + ", 'grill', [0, {'down': 0, 't': [0.0, 0.0]}])"],
			_tag("client", "rest_bufet", KI + ".tickets(" + REST + ", 'bufet').size()"),
			_tag("client", "rest_served", KI + ".debug_serve_first_bufet(" + REST + ")"),
			["wait", 1.0], ["coop_signal", "client_rest"],
			# The Jednota.
			["coop_wait_file", "host_shop"], ["wait", 3.0],
			_tag("client", "shop_deli", JE + ".deli_tickets(" + SHOP + ").size()"),
			_tag("client", "shop_cut", JE + ".debug_deli_first(" + SHOP + ")"),
			["wait", 1.0], ["coop_signal", "client_shop"],
			# The pub: in, looking at the bar (the host at the tap).
			["coop_wait_file", "host_in_pub"], ["wait", 2.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 5.0],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.7, 0.45))"],
			["coop_signal", "client_in_pub"], ["wait", 3.0], ["shot", "pc1_client_sees_host"],
			_tag("client", "pub_taken", "_interior_manager._service_interior._bistro_taken()"),
			["coop_signal", "client_done"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
