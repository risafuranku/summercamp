extends "res://tools/shot_driver.gd"

## Co-op harness (scripts/coop/coop.gd): two copies of the game on this machine, one
## hosting a sandbox camp, one joining it on 127.0.0.1. They wait for each other by what
## happens (files in the out dir: host_up, client_ready, ...), not by the clock: a camp
## takes the joining copy tens of seconds to build here. On the way:
##   - the joining warden's own look (warden 2, jacket 4) and name are what the host sees;
##   - the joining warden raises the barrier from the road with E and lowers it again:
##     the host's barrier goes up and down with it;
##   - each sees the other in a clearing by day, and by their torch at night;
##   - a tent the host builds after the join stands in the other camp too;
##   - both go into the old cabin: each sees the other in it; the joining warden's job
##     (held, a figure at it in the host's room) is done in the host's camp, the host's
##     (the other sees them at it) comes back to the other room;
##   - both go into the new tent: each sees the other lying on their belly in it;
##   - the joining warden rows out: the boat goes on the host's lake with them in it;
##   - a guest checks in at the host's: the other machine has them too, walking about;
##   - the delivery van at the host's gate: the other warden sees it and signs for it,
##     and it is signed for in the host's camp;
##   - the electrician the host rang for: the other warden sees him come;
##   - both in the generator shed: each sees the other there;
##   - the host sits at the PC: the other, in the office, sees its screen over their shoulder;
##     then the other sits at it: what they build and the mail they read are the host's;
##   - a night enemy on the host's goes for the other warden: the other machine sees it;
##     one only for them: the host neither sees nor hears it; set on the host, the other
##     machine has nothing of it;
##   - a guest lost in the host's corn: the other warden finds them and leads them out;
##   - the next day runs on for a few hours: the two camps are still the same (guests,
##     rooms, breakdowns, mail, the till, the day's events);
##   - one bus to Lesna for both: the other gets on first, the host sits down and the bus
##     waits while the other buys a ticket; both sit, it goes, and both get off in Lesna
##     side by side;
##   - at night both go to the room behind the office: the host lies down first and the
##     night does not pass; the other lies down too and both wake in the morning.
## Each writes what its camp looks like (seed, buildings, trees, terrain, clock, rooms)
## for tools/coop_check.py to compare.
##
##   godot --path godot res://tools/coop_check.tscn -- --role=host --out=DIR
##   godot --path godot res://tools/coop_check.tscn -- --role=client --out=DIR

const PORT := 24990
const WAIT_MS := 150000
const ROOM := Vector2i(10, 2)
const CLIENT_LOOK := [2, 4]
var _role := "host"
var _coop_wait_deadline := 0
var _wait_file := ""
var _task_id := ""
var _row_left := 0.0


func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.get_slice("=", 1)
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			# A clearing in the middle of the camp, cut before the other copy joins (so
			# its camp has it too), where the two can see each other.
			["money", 9000], ["clear", 11, 12, 5, 5], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["coop_signal", "host_up"],
			["coop_wait", "partner_seen"],
			["coop_wait_file", "client_gate"], ["wait", 0.6], ["coop_fingerprint", "host_gate"], ["coop_signal", "host_gate"],
			["coop_wait_file", "client_gate_down"], ["wait", 0.6], ["coop_fingerprint", "host_gate_down"], ["coop_signal", "host_gate_down"],
			["coop_wait_file", "client_ready"], ["wait", 1.0],
			["coop_face_partner"], ["wait", 1.0], ["shot", "h1_sees_other"],
			["eval", "_open_pause_menu()"], ["wait", 0.6], ["shot", "h1b_pause_with"], ["eval", "_close_pause_menu(true)"], ["wait", 0.4],
			["coop_fingerprint", "host"],
			# One radio: the host's song on both; the other's switch turns the host's set off.
			["wait", 5.0], ["coop_fingerprint", "host_radio"], ["coop_signal", "host_radio"],
			["coop_wait_file", "client_radio_off"], ["wait", 1.5], ["coop_fingerprint", "host_radio_off"], ["coop_signal", "host_radio_off_seen"],
			# Built after the join: the other camp gets it too.
			["build", "tent_1", 13, 16, 0], ["build", "bonfire", 11, 12, 0], ["build", "sports_field", 14, 12, 0], ["build", "pub", 11, 15, 0], ["build", "corn_stand", 15, 13, 0], ["wait", 2.0], ["coop_fingerprint", "host_built"], ["coop_signal", "host_built"],
			# By the fire and at the net together (scripts/attractions/warden_play.gd).
			["coop_att", "fire", 1.0], ["wait", 1.0], ["eval", "_warden_play.try_interact()"], ["wait", 0.5], ["eval", "_warden_play.try_interact()"], ["wait", 1.5],
			["coop_signal", "host_at_fire"], ["coop_wait_file", "client_at_fire"], ["wait", 1.5], ["shot", "h11_fire_other_roasts"], ["coop_fingerprint", "host_fire"],
			["eval", "_warden_play.leave()"], ["coop_signal", "host_fire_done"], ["coop_wait_file", "client_fire_done"],
			["coop_att", "court", -1.0], ["wait", 0.5], ["coop_signal", "host_at_court"], ["coop_wait_file", "client_at_court"],
			["coop_play_ball", 10.0], ["shot", "h12_court_other"], ["coop_fingerprint", "host_court"], ["coop_signal", "host_court_done"],
			["coop_wait_file", "client_court_done"], ["eval", "_warden_play.leave()"], ["wait", 0.5], ["coop_place", 12, 14, 1.0],
			# Behind the pub's bar at the tap: the other warden sees them there.
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 2.0],
			["eval", "_interior_manager._service_interior._open_station('tap')"], ["wait", 1.0], ["coop_signal", "host_at_tap"],
			["coop_wait_file", "client_saw_tap"], ["eval", "_interior_manager._service_interior._stations['tap'].close_station()"], ["wait", 0.5],
			["eval", "_interior_manager._service_interior.close_service()"], ["wait", 1.0], ["coop_place", 12, 14, 1.0],
			# The other warden behind the corn stand, ordering corn: seen there, the order in
			# the host's books.
			["coop_wait_file", "client_at_stand"], ["wait", 2.0], ["coop_face_partner"], ["wait", 0.5], ["shot", "h16_other_at_stand"],
			["coop_fingerprint", "host_corn_stand"], ["coop_signal", "host_saw_stand"],
			# Two in the sewer's pipes: the same pipes, the other's body in the way.
			["coop_wait_file", "client_left_stand"],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('sewer'))"], ["wait", 2.0],
			["eval", "_interior_manager._service_interior._try_request_service_repair()"], ["wait", 2.0], ["eval", "_sewer_pipe_minigame.set('_intro_t', 99.0)"], ["wait", 1.0],
			["coop_signal", "host_in_pipes"], ["coop_wait_file", "client_in_pipes"], ["wait", 1.0],
			["eval", "_sewer_pipe_minigame._forward()"], ["wait", 7.0], ["coop_signal", "host_crawled"],
			["coop_wait_file", "client_bumped"], ["wait", 1.0], ["coop_fingerprint", "host_pipes"],
			["eval", "_sewer_pipe_minigame.abort()"], ["wait", 1.5], ["coop_place", 12, 14, 1.0],
			# Into the old cabin together.
			["open_room", ROOM.x, ROOM.y], ["wait", 1.5], ["coop_signal", "host_in_room"],
			["coop_wait_file", "client_in_room"], ["wait", 2.0], ["shot", "h2_room_sees_other"],
			["coop_wait_file", "client_working"], ["wait", 0.8], ["shot", "h3_other_at_work"], ["coop_fingerprint", "host_sees_work"],
			["coop_wait_file", "client_task_done"], ["wait", 2.0],
			["coop_pick_task", ""], ["wait", 0.6], ["coop_track", 1.4], ["wait", 1.6], ["lmb", true], ["wait", 0.3], ["coop_note_job"], ["coop_signal", "host_working"], ["wait", 3.0], ["coop_job_state"], ["wait", 4.5], ["coop_job_state"], ["lmb", false], ["coop_aim_clear"], ["wait", 1.0],
			["coop_fingerprint", "host_room"], ["coop_signal", "host_task_done"],
			["eval", "_interior_manager._cabin_interior.close_cabin()"], ["wait", 1.0],
			# Into the new tent together.
			["open_room", 13, 16], ["wait", 1.5], ["coop_signal", "host_in_tent"],
			["coop_wait_file", "client_in_tent"], ["wait", 2.0], ["shot", "h3t_tent_other"], ["coop_fingerprint", "host_tent"], ["coop_signal", "host_tent_seen"],
			["coop_wait_file", "client_tent_seen"], ["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 1.0],
			# The joining warden rows out; the host watches from the jetty.
			["coop_at_boat"], ["coop_wait_file", "client_rowing"], ["wait", 0.4], ["shot", "h4_other_rowing"], ["coop_fingerprint", "host_rowing"],
			["wait", 3.0], ["shot", "h4b_other_rows_away"],
			["coop_wait_file", "client_rowed"],
			# At the PC, the other warden looking over the shoulder.
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior.enter_crt_view()"], ["wait", 2.0],
			["coop_signal", "host_at_pc"], ["coop_wait_file", "client_saw_pc"], ["shot", "h8_at_pc"],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			# A guest at the host's camp: on the other machine too (the camp pulse).
			["prep_all"], ["book", "Lads", "drunk", 1, 1, 0], ["hours", 0.05], ["eval", "debug_arrivals()"], ["checkin"], ["hours", 0.3],
			# Two things in the lost and found (the back office is the host's).
			["eval", "debug_bazaar_fill(2)"], ["wait", 3.0],
			["coop_fingerprint", "host_guests"], ["coop_signal", "host_guests"],
			["coop_wait_file", "client_guests_seen"], ["wait", 1.0], ["coop_fingerprint", "host_after_client"],
			["coop_wait_file", "client_spent"], ["coop_fingerprint", "host_till"],
			["eval", "_day_events.debug_start('delivery')"], ["wait", 2.0], ["coop_signal", "host_day_event"],
			["coop_wait_file", "client_day_done"], ["wait", 2.0], ["coop_fingerprint", "host_day_done"],
			["eval", "camp_office.on_phone_effect('electrician', '')"], ["hours", 0.6], ["wait", 3.0], ["coop_signal", "host_electrician"],
			["coop_wait_file", "client_saw_electrician"], ["eval", "camp_office.electrician._leave() if camp_office.electrician != null else null"], ["wait", 1.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('power_generator'))"], ["wait", 2.0], ["coop_signal", "host_in_shed"],
			["coop_wait_file", "client_in_shed"], ["wait", 2.0], ["shot", "h9_shed_other"], ["coop_fingerprint", "host_shed"], ["coop_signal", "host_shed_seen"],
			["coop_wait_file", "client_shed_seen"], ["eval", "_interior_manager._service_interior.close_service()"], ["wait", 1.0],
			["coop_place", 12, 14, 1.0], ["wait", 1.0],
			["eval", "time_system.set_time_hours(21.6)"], ["eval", "_sync_runtime_state_from_systems(true)"], ["wait", 4.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "h5_night_other_torch"],
			["coop_fingerprint", "host_night"],
			# One of the night's enemies, set on the other warden.
			["eval", "debug_spawn_enemy('silent_man', 3)"], ["wait", 1.0], ["eval", "_coop_night._aim(_enemy_brains[0], 'other')"], ["wait", 6.0],
			["coop_fingerprint", "host_enemy"], ["coop_signal", "host_enemy"], ["coop_wait_file", "client_enemy_seen"],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			# One that is only for the warden it hunts.
			["eval", "debug_spawn_enemy('tourist', 3)"], ["wait", 1.0], ["eval", "_coop_night._aim(_enemy_brains[0], 'other')"],
			["eval", "_coop_night.set_private(_enemy_brains[0], true)"], ["wait", 5.0],
			["coop_fingerprint", "host_private"], ["coop_signal", "host_private"], ["coop_wait_file", "client_private_seen"],
			["eval", "_coop_night._aim(_enemy_brains[0], 'host')"], ["wait", 2.0], ["coop_signal", "host_private_mine"], ["coop_wait_file", "client_private_gone"],
			["eval", "_stop_active_enemy_brain()"], ["wait", 1.0],
			# Someone lost in the corn; the other warden takes them by the arm.
			["eval", "start_corn_hunt({})"], ["wait", 2.0], ["coop_signal", "host_corn"], ["coop_wait_file", "client_corn_took"], ["wait", 2.0],
			["coop_fingerprint", "host_corn"], ["eval", "end_corn_hunt()"], ["wait", 1.0], ["coop_signal", "host_corn_done"],
			# The other warden knocked down: lying there till the host gets them up.
			["coop_wait_file", "client_down"], ["wait", 1.5], ["coop_go_to_partner", 3.5], ["wait", 1.0], ["shot", "h13_other_down"], ["coop_fingerprint", "host_down"],
			["coop_go_to_partner", 1.2], ["wait", 0.5], ["eval", "_try_interact()"], ["wait", 1.0], ["coop_signal", "host_lifted"],
			# The night director's touch on the other warden: it happens on their machine.
			["coop_fx", "knock"], ["wait", 1.0],
			# To bed: alone, the night does not pass; with the other one in bed too, it does.
			["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["coop_signal", "host_in_back"], ["coop_wait_file", "client_in_back"], ["wait", 1.5], ["shot", "h7_back_room_other"],
			["eval", "_interior_manager._building_interior._extras._try_sleep()"], ["wait", 8.0], ["coop_fingerprint", "host_waiting"],
			["coop_signal", "host_in_bed"], ["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "host_morning"],
			# The next day goes on a while: is it still one camp?
			["hours", 3.0], ["wait", 4.0], ["coop_signal", "host_day2"], ["coop_wait_file", "client_day2_seen"], ["coop_fingerprint", "host_day2"],
			# The 13:20 bus at the camp stop, for both.
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["coop_to_bus_stop"],
			["eval", "debug_jump_to(2, 13.42)"], ["wait", 3.0], ["coop_signal", "host_bus_here"], ["coop_wait_file", "client_aboard"],
			["eval", "_interior_manager._town_trip._board('camp')"], ["wait", 1.0], ["coop_ticket"], ["eval", "_interior_manager._town_trip._ride._try_sit(1)"], ["wait", 3.0],
			["shot", "h10_bus_waits"], ["coop_fingerprint", "host_bus_wait"], ["coop_signal", "host_sat"],
			["coop_wait_file", "client_sat"], ["wait", 3.0], ["coop_fingerprint", "host_bus_ride"],
			["coop_wait", "in_town"], ["wait", 2.0], ["coop_fingerprint", "host_town"],
			# A beer at U Jezera together: each sees the other at the bar.
			["coop_wait_file", "client_town_seen"], ["eval", "_interior_manager._town_trip._open_room('pub')"], ["wait", 1.5], ["coop_signal", "host_in_pub"],
			["coop_wait_file", "client_in_pub"], ["wait", 1.5], ["shot", "h14_pub_other"], ["coop_fingerprint", "host_pub"], ["coop_signal", "host_pub_seen"],
			["coop_wait_file", "client_pub_seen"], ["coop_signal", "host_day2_done"],
			["coop_wait", "partner_gone"], ["wait", 1.5], ["shot", "h6_other_went_home"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["eval", "_main_menu.show_page('coop')"], ["wait", 1.0], ["shot", "c0_coop_page"],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["coop_fingerprint", "client"],
			# The barrier from the road with E, up and down again: in the host's camp too.
			["coop_at_gate"], ["wait", 1.0], ["eval", "_try_interact()"], ["wait", 2.0],
			["coop_fingerprint", "client_gate"], ["coop_signal", "client_gate"], ["coop_wait_file", "host_gate"],
			["eval", "_try_interact()"], ["wait", 2.0],
			["coop_fingerprint", "client_gate_down"], ["coop_signal", "client_gate_down"], ["coop_wait_file", "host_gate_down"],
			["coop_place", 14, 14, -1.0], ["wait", 1.5],
			["coop_face_partner"], ["wait", 1.0], ["shot", "c1_sees_host"],
			["coop_signal", "client_ready"],
			["coop_wait_file", "host_radio"], ["wait", 1.5], ["coop_fingerprint", "client_radio"],
			["coop_radio_click"], ["wait", 1.0], ["coop_signal", "client_radio_off"], ["coop_wait_file", "host_radio_off_seen"], ["coop_radio_click"],
			["coop_wait_file", "host_built"], ["wait", 2.0], ["coop_fingerprint", "client_built"],
			["coop_wait_file", "host_at_fire"], ["coop_att", "fire", -1.0], ["wait", 1.5], ["shot", "c12_fire_host_sits"],
			["eval", "_warden_play._press()"], ["wait", 2.0], ["shot", "c12b_fire_roasting"], ["coop_fingerprint", "client_fire"], ["coop_signal", "client_at_fire"],
			["coop_wait_file", "host_fire_done"], ["eval", "_warden_play.leave()"], ["coop_signal", "client_fire_done"],
			["coop_wait_file", "host_at_court"], ["coop_att", "court", 1.0], ["wait", 0.5], ["coop_signal", "client_at_court"],
			["coop_play_ball", 8.0], ["shot", "c13_court_host"], ["coop_fingerprint", "client_court"], ["coop_signal", "client_court_done"],
			["coop_wait_file", "host_court_done"], ["eval", "_warden_play.leave()"], ["wait", 0.5], ["coop_place", 14, 14, -1.0],
			["coop_wait_file", "host_at_tap"], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 2.5],
			["shot", "c15_pub_host_at_tap"], ["coop_fingerprint", "client_pub_tap"], ["coop_signal", "client_saw_tap"],
			["eval", "_interior_manager._service_interior.close_service()"], ["wait", 1.0], ["coop_place", 14, 14, -1.0],
			["eval", "_interior_manager._on_corn_stand_interact(debug_structure_of_type('corn_stand'))"], ["wait", 1.5],
			["coop_corn_order"], ["wait", 1.0], ["shot", "c16_behind_the_stand"], ["coop_signal", "client_at_stand"],
			["coop_wait_file", "host_saw_stand"], ["eval", "_interior_manager._corn_stand.close_view()"], ["wait", 1.0], ["coop_place", 14, 14, -1.0], ["coop_signal", "client_left_stand"],
			["coop_wait_file", "host_in_pipes"],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('sewer'))"], ["wait", 2.0],
			["eval", "_interior_manager._service_interior._try_request_service_repair()"], ["wait", 2.0], ["eval", "_sewer_pipe_minigame.set('_intro_t', 99.0)"], ["wait", 1.0],
			["coop_signal", "client_in_pipes"], ["coop_wait_file", "host_crawled"], ["wait", 1.0], ["shot", "c17_pipes_host_ahead"],
			["eval", "_sewer_pipe_minigame._forward()"], ["wait", 1.0], ["coop_fingerprint", "client_pipes"], ["shot", "c17b_bumped"], ["coop_signal", "client_bumped"],
			["wait", 2.0], ["eval", "_sewer_pipe_minigame.abort()"], ["wait", 1.5], ["coop_place", 14, 14, -1.0],
			["coop_wait_file", "host_in_room"], ["open_room", ROOM.x, ROOM.y], ["wait", 1.5], ["coop_signal", "client_in_room"],
			["wait", 2.0], ["shot", "c2_room_sees_host"],
			["coop_pick_task", ""], ["wait", 0.6], ["coop_track", 1.4], ["wait", 1.6], ["lmb", true], ["wait", 0.3], ["coop_note_job"], ["coop_signal", "client_working"], ["wait", 3.0], ["coop_job_state"], ["wait", 4.5], ["coop_job_state"], ["lmb", false], ["coop_aim_clear"],
			["wait", 1.0], ["coop_signal", "client_task_done"],
			["coop_wait_file", "host_working"], ["wait", 0.5], ["coop_aim_partner_job"], ["wait", 0.6], ["shot", "c3_host_at_work"],
			["coop_wait_file", "host_task_done"], ["wait", 2.0], ["shot", "c4_room_after_host"], ["coop_fingerprint", "client_room"],
			["eval", "_interior_manager._cabin_interior.close_cabin()"], ["wait", 1.0],
			["coop_wait_file", "host_in_tent"], ["open_room", 13, 16], ["wait", 1.5], ["coop_signal", "client_in_tent"],
			["wait", 2.0], ["shot", "c4t_tent_host"], ["coop_fingerprint", "client_tent"], ["coop_signal", "client_tent_seen"],
			["coop_wait_file", "host_tent_seen"], ["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 1.0],
			["eval", "_lake_trip._start_rowing('far')"], ["coop_row", 12.0], ["wait", 3.0], ["coop_signal", "client_rowing"], ["wait", 12.0],
			["eval", "_lake_trip.return_home()"], ["wait", 1.5], ["coop_signal", "client_rowed"],
			["coop_wait_file", "host_at_pc"], ["coop_open_office"], ["wait", 3.0], ["shot", "c7_over_the_shoulder"], ["coop_fingerprint", "client_shoulder"],
			["coop_signal", "client_saw_pc"], ["wait", 3.0],
			# Now at the PC yourself: a tent from the Builder, a mail read.
			["eval", "_interior_manager._building_interior.enter_crt_view()"], ["wait", 2.0],
			["coop_build_at", "tent_1", 15, 16], ["coop_read_mail"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0], ["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_wait_file", "host_guests"], ["wait", 3.0], ["coop_list_bazaar"], ["coop_goggle"], ["wait", 0.5], ["coop_fingerprint", "client_guests"], ["coop_signal", "client_guests_seen"],
			# Spent here (a pint in Lesna, say): the host's till pays it.
			["coop_spend", 40], ["wait", 3.0], ["coop_fingerprint", "client_till"], ["coop_signal", "client_spent"],
			["coop_wait_file", "host_day_event"], ["wait", 2.5], ["coop_fingerprint", "client_day_event"],
			["coop_sign_delivery"], ["wait", 3.0], ["coop_fingerprint", "client_day_done"], ["coop_signal", "client_day_done"],
			["coop_wait_file", "host_electrician"], ["wait", 2.0], ["coop_fingerprint", "client_electrician"], ["coop_signal", "client_saw_electrician"],
			["coop_wait_file", "host_in_shed"], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('power_generator'))"], ["wait", 2.0], ["coop_signal", "client_in_shed"],
			["wait", 2.0], ["shot", "c9_shed_host"], ["coop_fingerprint", "client_shed"], ["coop_signal", "client_shed_seen"],
			["coop_wait_file", "host_shed_seen"], ["eval", "_interior_manager._service_interior.close_service()"], ["wait", 1.0],
			["coop_place", 14, 14, -1.0], ["wait", 1.0],
			["coop_wait", "night"], ["wait", 3.0],
			["coop_face_partner"], ["wait", 1.5], ["shot", "c5_night_host_torch"],
			["coop_fingerprint", "client_night"],
			["coop_wait_file", "host_enemy"], ["wait", 2.0], ["shot", "c5b_night_enemy"], ["coop_fingerprint", "client_enemy"], ["coop_signal", "client_enemy_seen"],
			["coop_wait_file", "host_private"], ["wait", 2.0], ["coop_fingerprint", "client_private"], ["coop_signal", "client_private_seen"],
			["coop_wait_file", "host_private_mine"], ["wait", 2.5], ["coop_fingerprint", "client_private_gone"], ["coop_signal", "client_private_gone"],
			["coop_wait_file", "host_corn"], ["wait", 2.0], ["coop_goto_corn_guest"], ["wait", 1.0], ["shot", "c5c_corn_guest"],
			["eval", "_coop_client_interact()"], ["wait", 0.5], ["coop_signal", "client_corn_took"], ["coop_wait_file", "host_corn_done"],
			["eval", "damage_player(500)"], ["wait", 2.5], ["coop_fingerprint", "client_down"], ["coop_signal", "client_down"],
			["coop_wait_file", "host_lifted"], ["wait", 1.5], ["coop_fingerprint", "client_lifted"],
			["coop_wait_file", "host_in_back"], ["coop_open_office"], ["wait", 1.5], ["eval", "_interior_manager._building_interior._extras.go_back_room()"], ["wait", 3.0],
			["coop_signal", "client_in_back"], ["wait", 1.5], ["shot", "c6_back_room_host"],
			# One bed in the back room, and the host has it: the other turns in in a tent
			# (scripts/lodge_bed.gd); the night passes once both lie down.
			["coop_wait_file", "host_in_bed"], ["eval", "_interior_manager._building_interior._extras._try_sleep()"], ["wait", 1.0], ["coop_fingerprint", "client_refused_bed"],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["open_room", 15, 16], ["wait", 2.0], ["eval", "_interior_manager.lodge_bed._try_sleep()"], ["wait", 2.0], ["coop_lodge_fallback", 13, 16],
			["coop_wait", "morning"], ["wait", 1.0], ["coop_fingerprint", "client_morning"],
			["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 1.0],
			["coop_wait_file", "host_day2"], ["wait", 2.5], ["coop_fingerprint", "client_day2"], ["coop_signal", "client_day2_seen"],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0], ["coop_to_bus_stop"],
			["coop_wait_file", "host_bus_here"], ["wait", 1.0], ["shot", "c9b_at_the_stop"], ["eval", "_interior_manager._town_trip._board('camp')"], ["wait", 1.0], ["coop_signal", "client_aboard"],
			["coop_wait_file", "host_sat"], ["wait", 1.0], ["shot", "c10_host_sat_waiting"], ["coop_ticket"], ["eval", "_interior_manager._town_trip._ride._try_sit(6)"],
			["wait", 3.0], ["coop_fingerprint", "client_bus_ride"], ["shot", "c11_riding_with_host"], ["coop_signal", "client_sat"],
			["coop_wait", "in_town"], ["wait", 2.0], ["coop_fingerprint", "client_town"], ["coop_signal", "client_town_seen"],
			["coop_wait_file", "host_in_pub"], ["eval", "_interior_manager._town_trip._open_room('pub')"], ["wait", 1.5], ["coop_signal", "client_in_pub"],
			["wait", 1.5], ["shot", "c14_pub_host"], ["coop_fingerprint", "client_pub"], ["coop_signal", "client_pub_seen"], ["coop_wait_file", "host_pub_seen"],
			["coop_wait", "host_done"], ["coop_leave"], ["wait", 2.0],
		]


func _condition_met(what: String) -> bool:
	if what in ["partner_seen", "partner_gone", "night", "morning", "in_town", "host_done", "file"] and Time.get_ticks_msec() > _coop_wait_deadline:
		print("COOP CHECK %s: gave up waiting for %s %s" % [_role, what, _wait_file])
		get_tree().quit(1)
		return false
	match what:
		"partner_seen":
			var other: Node3D = Coop.remote_figure()
			return other != null and other.visible
		"partner_gone":
			return not Coop.has_partner()
		"night":
			var h := float(_main.get("_time_of_day_hours"))
			return h >= 21.0 or h < 5.0
		"morning":
			# Up again after the night went by.
			var h2 := float(_main.get("_time_of_day_hours"))
			var office = _main.get("camp_office")
			return h2 >= 6.4 and h2 < 12.0 and office != null and not office.in_bed()
		"in_town":
			# Off the bus at the other end.
			var trip = _main.get("_interior_manager").get("_town_trip")
			var ride2 = trip.get("_ride") if trip != null else null
			return trip != null and trip.away() and (ride2 == null or not ride2.is_open())
		"host_done":
			# The host has its last picture: the joining copy may hang up.
			return FileAccess.file_exists(_out_dir.path_join("host_day2_done"))
		"file":
			return FileAccess.file_exists(_out_dir.path_join(_wait_file))
	return super._condition_met(what)


var _ball_left := 0.0
var _track_left := 0.0
var _kick_cd := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if _track_left > 0.0:
		_track_left -= delta
		_track_job()
	if _ball_left > 0.0:
		_ball_left -= delta
		_kick_cd -= delta
		var wp = _main.get("_warden_play") if _main != null else null
		if wp != null and wp.is_active() and _kick_cd <= 0.0 and str(wp.hint()).contains("Kick"):
			_kick_cd = 0.3
			wp._press()
	if _row_left > 0.0:
		_row_left -= delta
		var trip = _main.get("_lake_trip") if _main != null else null
		if trip != null:
			trip.set("_speed", 2.4)


func _run_step(step: Array) -> void:
	match str(step[0]):
		"coop_port":
			Coop.port = PORT
		"coop_look":
			Coop.set_my_look(int(step[1]), int(step[2]))
		"coop_join":
			_main.call("_on_menu_coop_join", "%s:%d" % [str(step[1]), PORT])
		"coop_wait":
			_waiting_for = str(step[1])
			_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS
		"coop_wait_file":
			_wait_file = str(step[1])
			_waiting_for = "file"
			_coop_wait_deadline = Time.get_ticks_msec() + WAIT_MS
		"coop_signal":
			FileAccess.open(_out_dir.path_join(str(step[1])), FileAccess.WRITE).store_string(_role)
		"coop_leave":
			Coop.leave()
		"coop_att":
			# By the fire (11,12) or on the court (14,12), on side `step[2]`, and into it.
			var wp = _main.get("_warden_play")
			var att: Node3D = wp.find_att("11,12" if str(step[1]) == "fire" else "14,12")
			var me4: Node3D = _main.get("_player")
			if att == null or me4 == null:
				print("COOP CHECK %s: no %s" % [_role, step[1]])
				return
			if str(step[1]) == "fire":
				me4.global_position = att.global_position + Vector3(0.0, 0.4, float(step[2]) * 2.4)
			else:
				me4.global_position = att.to_global(Vector3(float(step[2]) * 2.6, 0.4, 0.0))
			for _try in 3:
				if not wp.is_active():
					wp.try_interact()
			print("COOP CHECK %s at the %s: in %s" % [_role, step[1], str(wp.coop_state())])
		"coop_go_to_partner":
			# Up to `step[1]` m from the other warden, facing them.
			var fig: Node3D = Coop.remote_figure()
			var me5: Node3D = _main.get("_player")
			if fig == null or me5 == null:
				print("COOP CHECK %s: no other warden to go to" % _role)
				return
			var away := me5.global_position - fig.global_position
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.BACK
			me5.global_position = fig.global_position + away * float(step[1]) + Vector3(0.0, 0.4, 0.0)
			me5.rotation.y = atan2(away.x, away.z)
			print("COOP CHECK %s by the other warden (%.1f m): %s" % [_role, float(step[1]), str(Coop.partner_state.get("dn", false))])
		"coop_lodge_fallback":
			# That bed taken (guests booked in): the next lodging's.
			var off = _main.get("camp_office")
			if off != null and not bool(off.in_bed()):
				print("COOP CHECK %s: no bed there, trying %d,%d" % [_role, int(step[1]), int(step[2])])
				var tent = _main.get("_interior_manager").get("_tent_interior")
				if tent != null and tent.has_method("close_tent"):
					tent.close_tent()
				_steps.insert(_step_index, ["eval", "_interior_manager.lodge_bed._try_sleep()"])
				_steps.insert(_step_index, ["wait", 2.0])
				_steps.insert(_step_index, ["open_room", int(step[1]), int(step[2])])
		"coop_job_state":
			var cab4 = _main.get("_interior_manager").get("_cabin_interior")
			var tasks4 = cab4.get("_prep").tasks if cab4 != null and cab4.get("_prep") != null else null
			if tasks4 != null:
				print("COOP CHECK %s job: holding %s progress %.2f hover %s under %s" % [_role, tasks4._holding, float(tasks4._progress), tasks4._hover, tasks4._target_under_cursor()])
		"coop_radio_click":
			# The office radio's switch, as a click on it does.
			var bi6 = _main.get("_interior_manager").get("_building_interior")
			bi6._toggle_radio_power()
			if Coop.is_client():
				Coop.send_request("radio", [bool(bi6.get("_radio_power_on"))])
		"coop_aim_clear":
			var cab7 = _main.get("_interior_manager").get("_cabin_interior")
			if cab7 != null and cab7.get("_prep") != null:
				cab7.get("_prep").tasks.debug_aim = ""
		"coop_corn_order":
			# A pack of corn ordered in the stand's books, as their ORDER page does.
			var ok: bool = CoreRoot.actions.biz_order("15:13", {"cobs": 1}, CoreRoot.get_day() + 1)
			print("COOP CHECK %s orders corn: %s" % [_role, ok])
		"coop_track":
			# Keep the cursor on the job for `step[1]` seconds (the room's camera eases
			# after the aim, as a player's hand would follow it). A mess lying in front of
			# it from here is the one the hands get: that one, then.
			_track_left = float(step[1])
			var cab3 = _main.get("_interior_manager").get("_cabin_interior")
			var tasks3 = cab3.get("_prep").tasks if cab3 != null and cab3.get("_prep") != null else null
			# The hands are on it whatever the shared cursor does (interior_tasks.debug_aim).
			if tasks3 != null:
				tasks3.debug_aim = _task_id
			if tasks3 != null and tasks3._targets.has(_task_id):
				var front: String = str(tasks3._pick(tasks3._camera.unproject_position(_seen_at(tasks3._targets[_task_id])))[0])
				if front != "" and front != _task_id and tasks3._targets.has(front) and not bool(tasks3._targets[front].get("done", false)):
					print("COOP CHECK %s: %s lies in front of %s, that one first" % [_role, front, _task_id])
					_task_id = front
					tasks3._targets[front]["seconds"] = 6.0
		"coop_play_ball":
			# Kick the ball whenever it comes to you, for `step[1]` seconds.
			_ball_left = float(step[1])
			_wait_left = _ball_left
		"coop_place":
			# Stand on a tile (its centre), facing along x (+1 east, -1 west).
			var me3: Node3D = _main.get("_player")
			var gm = _main.get("grid_manager")
			if me3 != null and gm != null:
				me3.global_position = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0.0, 0.6, 0.0)
				me3.rotation.y = atan2(-float(step[3]), 0.0)
		"coop_face_partner":
			# Turn to the other warden (yaw only), standing back a little if too close.
			var other: Node3D = Coop.remote_figure()
			var me: Node3D = _main.get("_player")
			if other == null or me == null:
				print("COOP CHECK: no other warden to face (%s)" % _role)
				return
			var to := other.global_position - me.global_position
			to.y = 0.0
			if to.length() < 3.5:
				me.global_position -= to.normalized() * (3.5 - to.length())
				to = other.global_position - me.global_position
				to.y = 0.0
			me.rotation.y = atan2(-to.x, -to.z)
			print("COOP CHECK %s faces the other warden at %s (%.1f m)" % [_role, other.global_position, to.length()])
		"coop_pick_task":
			# A job in the open cabin: `step[1]` if given, else the longest mess job not
			# done yet (here or by the other warden); made slow (6 s) so the other copy
			# can see it being done, and looked at.
			var cab = _main.get("_interior_manager").get("_cabin_interior")
			var tasks = cab.get("_prep").tasks
			var pick := str(step[1])
			var acc_done: Array = CoreRoot.get_state().accommodation_states.get("%d:%d" % [ROOM.x, ROOM.y], {}).get("prep_done", [])
			if pick == "" or not tasks._targets.has(pick):
				var best := -1.0
				for id in tasks._targets.keys():
					var t: Dictionary = tasks._targets[id]
					if str(id) == "bed" or str(id) == _other_task() or bool(t.get("done", false)) or acc_done.has(str(id)) or _near_done(tasks, str(id), acc_done):
						continue
					# Within the head's reach first (a mess at your feet may be past it).
					var sec := float(t.get("seconds", 1.0)) + (1.0 if str(t.get("verb", "")) in ["Mopping", "Sweeping"] else 0.0) - _reach_miss(cab, tasks, str(id)) * 10.0
					if sec > best:
						best = sec
						pick = str(id)
			_task_id = pick
			if tasks._targets.has(pick):
				tasks._targets[pick]["seconds"] = 6.0
			print("COOP CHECK %s works on %s (%s)" % [_role, pick, tasks._targets.get(pick, {}).get("verb", "?")])
			super._run_step(["aim_task", "_cabin_interior", pick])
		"coop_row":
			_row_left = float(step[1])
		"coop_goto_corn_guest":
			# Up to the guest lost in the host's corn (as it is shown here), facing them.
			var lost: Node3D = _main.get("_coop_night").tagged_near("corn_guest", Vector3.ZERO, 100000.0)
			var me5: Node3D = _main.get("_player")
			if lost != null and me5 != null:
				var at := lost.global_position + Vector3(1.0, 0.6, 0.0)
				me5.global_position = at
				me5.rotation.y = atan2(-(lost.global_position.x - at.x), -(lost.global_position.z - at.z))
			print("COOP CHECK %s goes to the lost guest: %s" % [_role, lost != null])
		"coop_fx":
			Coop.send_night_event("fx", [str(step[1])])
		"coop_to_bus_stop":
			# Down the road to the camp stop, where the bus stands (the host a step behind).
			var trip2 = _main.get("_interior_manager").get("_town_trip")
			var spot: Transform3D = trip2._road().wait_spot()
			trip2._put_player(spot.translated(Vector3(1.5, 0.0, 0.0) if _role == "host" else Vector3.ZERO))
		"coop_ticket":
			# A ticket to Lesna out of the machine.
			var ride = _main.get("_interior_manager").get("_town_trip").get("_ride")
			if ride != null:
				ride.set("_ticket", {"to": "LIBLICE", "kind": "full"})
		"coop_spend":
			CoreRoot.actions.spend_money(int(step[1]))
		"coop_sign_delivery":
			# Sign for the van at the gate (what E does there).
			var de = _main.get("_day_events")
			for ev in de.open_events():
				if str(ev["kind"]) == "delivery":
					de._resolve(ev)
					break
		"coop_build_at":
			# What the Builder sends when you place something.
			EventBus.RequestBuild.emit(str(step[1]), Vector2i(int(step[2]), int(step[3])), 0)
		"coop_read_mail":
			for m in EmailManager.inbox:
				if not bool(m.get("_read", false)):
					print("COOP CHECK %s reads mail %s" % [_role, str(m.get("subject", ""))])
					EmailManager.mark_read(m)
					break
		"coop_open_office":
			# Into the office building through the real interaction path.
			var bm2 = _main.get("building_manager")
			for c in bm2.get_node("Structures").get_children():
				if str(c.get_meta("building_type", "")) == "main_building":
					_main.get("_interior_manager").handle_structure_interact(c)
					break
		"coop_note_job":
			# The job under the hands (the aim can land on another mess lying in front).
			var tasks2 = _main.get("_interior_manager").get("_cabin_interior").get("_prep").tasks
			var held := str(tasks2.working_on())
			if held != _task_id:
				print("COOP CHECK %s: the hands are on %s, not %s" % [_role, held, _task_id])
				if tasks2._targets.has(held):
					tasks2._targets[held]["seconds"] = 6.0
			_task_id = held
			# For the other copy's pick (not the same job twice).
			FileAccess.open(_out_dir.path_join("task_%s" % _role), FileAccess.WRITE).store_string(_task_id)
		"coop_aim_partner_job":
			# Look at the job the other warden is doing in this room (their figure is at it).
			var job := str((Coop.partner_state.get("room", {}) as Dictionary).get("w", ""))
			print("COOP CHECK %s looks at the other warden's job %s" % [_role, job])
			if job != "":
				# Only the head turns: both copies share the one OS cursor, and moving it
				# here would take it off the host's job there.
				var cab5 = _main.get("_interior_manager").get("_cabin_interior")
				var tasks5 = cab5.get("_prep").tasks
				var t5: Dictionary = tasks5._targets.get(job, {})
				if not t5.is_empty():
					var look5 = cab5.get("_look")
					var base5: Vector3 = cab5.get("_cam_base_rot")
					var to5: Vector3 = _seen_at(t5) - tasks5._camera.global_position
					look5.yaw_deg = clampf(rad_to_deg(atan2(-to5.x, -to5.z) - base5.y), -look5.yaw_limit_deg, look5.yaw_limit_deg)
					look5.pitch_deg = clampf(rad_to_deg(atan2(to5.y, Vector2(to5.x, to5.z).length()) - base5.x), -look5.pitch_down_deg, look5.pitch_up_deg)
		"coop_at_boat":
			# On the camp jetty behind the boat, looking out over the lake.
			var lake = get_tree().root.find_child("CampLake", true, false)
			var me4: Node3D = _main.get("_player")
			if lake != null and me4 != null:
				var home: Transform3D = lake.get("boat_home")
				me4.global_position = (lake as Node3D).global_transform * home.origin + Vector3(-1.4, 0.9, -4.0)
				me4.rotation.y = PI
		"coop_fingerprint":
			_write_fingerprint(str(step[1]))
		"coop_at_gate":
			# On the road by the barrier's post, looking at it (to work it with E).
			var gate: Node3D = get_tree().get_first_node_in_group("camp_gate")
			var me6: Node3D = _main.get("_player")
			if gate != null and me6 != null:
				var at6 := Vector3(float(gate.get("gap_center_x")) - 1.0, 0.2, float(gate.get("fence_z")) - 1.8)
				var post := Vector3(float(gate.get("gap_center_x")) - 2.3, 0.0, float(gate.get("fence_z")))
				me6.global_position = at6
				me6.rotation.y = atan2(-(post.x - at6.x), -(post.z - at6.z))
				me6.set("_pitch", -0.15)
				me6.set("_pitch_target", -0.15)
		"coop_list_bazaar":
			# The bazaar page's "put it up" for the first thing in the box.
			var box: Array = _main.get("_bazaar").in_box()
			if not box.is_empty():
				_main.bazaar_list(int(box[0]["id"]))
		"coop_goggle":
			# Goggle from the other machine: a bad review booked with SpotlessName, an
			# apology under another; both done on the host's page (main.coop_request).
			var g = _main.get("_goggle")
			if g != null:
				var bad: Array = g.shown().filter(func(e): return int(e["stars"]) <= 2 and str(e.get("ghost_reply", "")) == "")
				if bad.size() >= 2:
					print("COOP CHECK goggle: remove %d, apologise to %d" % [int(bad[0]["id"]), int(bad[1]["id"])])
					_main.goggle_remove(int(bad[0]["id"]))
					_main.goggle_reply(int(bad[1]["id"]), "sorry")
		_:
			super._run_step(step)


## A job lying by one already done (its mess would be in front of it, or it behind).
## How many degrees past the interior's look limits it is (0 within: a mess at your feet
## may be past them, and the aim then lands on another one).
static func _reach_miss(interior, tasks, id: String) -> float:
	var body = tasks._targets[id].get("body")
	var cam: Camera3D = tasks._camera
	var look = interior.get("_look")
	if body == null or not is_instance_valid(body) or cam == null or look == null:
		return 0.0
	var base: Vector3 = interior.get("_cam_base_rot")
	var to: Vector3 = (body as Node3D).global_position - cam.global_position
	var yaw := rad_to_deg(atan2(-to.x, -to.z) - base.y)
	var pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()) - base.x)
	var over_yaw := maxf(0.0, absf(wrapf(yaw, -180.0, 180.0)) - (float(look.yaw_limit_deg) - 2.0))
	var over_pitch := maxf(0.0, -float(look.pitch_down_deg) + 2.0 - pitch) + maxf(0.0, pitch - (float(look.pitch_up_deg) - 2.0))
	return over_yaw + over_pitch


static func _near_done(tasks, id: String, acc_done: Array) -> bool:
	var body = tasks._targets[id].get("body")
	if body == null or not is_instance_valid(body):
		return false
	for other in tasks._targets.keys():
		if str(other) == id or not (bool(tasks._targets[other].get("done", false)) or acc_done.has(str(other))):
			continue
		var ob = tasks._targets[other].get("body")
		if ob != null and is_instance_valid(ob) and (ob as Node3D).global_position.distance_to((body as Node3D).global_position) < 0.6:
			return true
	return false


## How far the camp's boat is from its place at the jetty (m).
func _boat_from_home() -> float:
	var lake = get_tree().root.find_child("CampLake", true, false)
	if lake == null or lake.get("boat") == null:
		return -1.0
	var home: Transform3D = lake.get("boat_home")
	return ((lake as Node3D).global_transform * home.origin).distance_to((lake.get("boat") as Node3D).global_position)


## What comes and goes by itself on each machine (a fish's rings on the lake and their
## plop): not the camp.
static func _passing_fx(n: Node3D) -> bool:
	if n is AudioStreamPlayer3D:
		return true
	var mi := n as MeshInstance3D
	return mi != null and mi.mesh is QuadMesh and ((mi.mesh as QuadMesh).size - Vector2(1.6, 1.6)).length() < 0.01 and str(mi.name).begins_with("@")


## A node's name without Godot's per-process counter (@MeshInstance3D@3614).
static func _stable_name(n: Node) -> String:
	var s := str(n.name)
	return n.get_class() if s.begins_with("@") else s


## The camp's derelict buildings (the old cabin of a new camp) and its rooms' derelict mess.
func _derelict_keys() -> Array:
	var out: Array = []
	var state = CoreRoot.get_state()
	for k in state.failures.keys():
		if bool((state.failures[k] as Dictionary).get("derelict", false)):
			out.append("failure %s" % k)
	for k2 in state.accommodation_states.keys():
		var mess = (state.accommodation_states[k2] as Dictionary).get("mess", {})
		if mess is Dictionary and bool((mess as Dictionary).get("derelict", false)):
			out.append("mess %s" % k2)
	out.sort()
	return out


## The host's first enemy is drawn on this machine (its root shown).
func _enemy_shown_here() -> bool:
	var brains: Array = _main.get("_enemy_brains")
	if brains.is_empty() or brains[0] == null:
		return false
	var root = brains[0].get("_root")
	return root != null and is_instance_valid(root) and (root as Node3D).visible


## The camp as both should have it: rooms (status and jobs done), breakdowns, the
## day's open events, the guests (who and how they are).
func _camp_rows() -> Dictionary:
	var state = CoreRoot.get_state()
	var rooms: Array = []
	for k in state.accommodation_states.keys():
		var acc: Dictionary = state.accommodation_states[k]
		var done: Array = (acc.get("prep_done", []) as Array).duplicate()
		done.sort()
		rooms.append("%s %s %s" % [str(k), str(acc.get("status", "")), str(done)])
	rooms.sort()
	var broke: Array = state.failures.keys().map(func(k): return str(k))
	broke.sort()
	var guests: Array = []
	for g in state.guests:
		if g is Dictionary:
			guests.append("%d %s %s" % [int(g.get("id", -1)), str(g.get("name", "")), str(g.get("status", ""))])
	guests.sort()
	var de = _main.get("_day_events")
	var open: Array = (de.open_events() as Array).map(func(e): return str(e["kind"])) if de != null else []
	open.sort()
	return {"rooms": rooms, "failures": broke, "guests": guests, "day_open": open}


## Where this warden's bus ride is: "", "boarding", "sitting", "held", "riding"...
func _bus_state() -> String:
	var trip = _main.get("_interior_manager").get("_town_trip")
	var ride = trip.get("_ride") if trip != null else null
	if ride == null:
		return ""
	return ["closed", "boarding", "sitting", "riding", "stopping", "done", "held"][int(ride.get("_state"))]


## The mail: subject and whether it was read.
func _mail_rows() -> Array:
	var out: Array = []
	for m in EmailManager.inbox:
		out.append("%s|%s" % [str(m.get("subject", "")), "read" if bool(m.get("_read", false)) else "new"])
	out.sort()
	return out


## The camp's guests: id and name.
func _guest_rows() -> Array:
	var out: Array = []
	for g in CoreRoot.get_state().guests:
		if g is Dictionary:
			# (What they do changes with the clock between the two pictures: only who.)
			out.append("%d %s" % [int(g.get("id", -1)), str(g.get("name", ""))])
	out.sort()
	return out


## The job in the old cabin the other warden has their hands on (locked for this one).
func _cabin_taken() -> String:
	var cab = _main.get("_interior_manager").get("_cabin_interior")
	var prep = cab.get("_prep") if cab != null else null
	return str(prep.tasks.coop_taken) if prep != null and prep.tasks != null else ""


## The other warden's figure in the room this one is in: its pose, "" when none.
## The other warden's figure behind the pub's bar (room z past the counter).
## How many of the other wardens stand with you in the place in Lesna you are in.
func _town_mate_count() -> int:
	var trip = _main.get("_interior_manager").get("_town_trip") if _main != null else null
	var room = trip.get("_room") if trip != null else null
	var mates: Dictionary = room.get("_mates") if room != null else {}
	var n := 0
	for m in mates.values():
		if m != null and is_instance_valid(m) and (m as Node3D).visible:
			n += 1
	return n


## How many of the other wardens are seen on your bus.
func _bus_mate_count() -> int:
	var trip = _main.get("_interior_manager").get("_town_trip") if _main != null else null
	var ride = trip.get("_ride") if trip != null else null
	var mates: Dictionary = ride.get("_mates") if ride != null else {}
	var n := 0
	for m in mates.values():
		if m != null and is_instance_valid(m) and (m as Node3D).visible:
			n += 1
	return n


## How many of the other wardens stand (or lie) in your room, seen.
func _room_fig_count() -> int:
	var im = _main.get("_interior_manager")
	var figs: Dictionary = im.get("_coop_figs") if im != null else {}
	var n := 0
	for id in figs.keys():
		var f = figs[id].get("fig")
		var sl = figs[id].get("sleeper")
		if (f != null and is_instance_valid(f) and (f as Node3D).visible) or (sl != null and is_instance_valid(sl)):
			n += 1
	return n


## How many of the other wardens an attraction here has placed (warden_play._mates).
func _att_mate_count() -> int:
	var wp = _main.get("_warden_play")
	var n := 0
	for e in (wp.get("_mates") as Dictionary).values():
		if not (e.get("place", {}) as Dictionary).is_empty():
			n += 1
	return n


## How many of the other wardens are down the pipes with you (drawn, or lying right
## where you lie).
func _pipe_mate_count() -> int:
	var crawl = _main.get("_sewer_pipe_minigame")
	if crawl == null or not crawl.is_open():
		return 0
	var n := 0
	for spr in (crawl.mate._sprites as Dictionary).values():
		if spr != null and is_instance_valid(spr):
			n += 1
	return n


## The first of the other wardens' figures in your room (interior_manager._coop_figs).
func _first_room_fig():
	var im = _main.get("_interior_manager")
	var figs: Dictionary = im.get("_coop_figs") if im != null else {}
	for id in figs.keys():
		var f = figs[id].get("fig")
		if f != null and is_instance_valid(f):
			return f
	return null


func _fig_behind_bar() -> bool:
	var im = _main.get("_interior_manager")
	var fig = _first_room_fig()
	var si = im.get("_service_interior") if im != null else null
	var root = si.get("_pub_main_root") if si != null else null
	if fig == null or not is_instance_valid(fig) or root == null:
		return false
	return (root as Node3D).to_local((fig as Node3D).global_position).z < -1.6


func _room_figure() -> String:
	var fig = _first_room_fig()
	if fig == null or not is_instance_valid(fig) or not (fig as Node3D).visible:
		return ""
	return str(fig.get("pose"))


## What this machine's camp is: enough to tell two camps apart.
## The job the other copy took in the room (tools: task_<role>), "" if none yet.
func _other_task() -> String:
	var path := _out_dir.path_join("task_%s" % ("client" if _role == "host" else "host"))
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""


## Where a job's mess is seen (its first shown mesh, as interior_tasks.debug_probe aims;
## the click body of a floor mess sits partly under the floor).
static func _seen_at(t: Dictionary) -> Vector3:
	for mm in t["meshes"]:
		if mm is MeshInstance3D and is_instance_valid(mm) and (mm as Node3D).is_visible_in_tree():
			return (mm as Node3D).global_position
	return (t["body"] as Node3D).global_position


func _track_job() -> void:
	var cab = _main.get("_interior_manager").get("_cabin_interior") if _main != null else null
	if cab == null or not cab.visible or cab.get("_prep") == null:
		return
	var tasks = cab.get("_prep").tasks
	var t: Dictionary = tasks._targets.get(_task_id, {})
	if t.is_empty() or not is_instance_valid(t["body"]):
		return
	var screen := get_viewport().get_visible_rect().size
	var sp: Vector2 = tasks._camera.unproject_position(_seen_at(t)) / Vector2(tasks._viewport.size) * screen
	Input.warp_mouse(sp * Vector2(DisplayServer.window_get_size()) / screen)


## The office radio: the switch and what is on it (not where in it).
func _radio_row() -> Dictionary:
	var bi = _main.get("_interior_manager").get("_building_interior") if _main != null else null
	if bi == null or not bi.has_method("coop_radio_state"):
		return {}
	var r: Dictionary = bi.coop_radio_state()
	var player = bi.get("_radio_player")
	return {"on": r["on"], "k": r["k"], "id": str(r["id"]), "playing": player != null and player.playing}


## Down the sewer's pipes: the network (as a hash), whether the other warden is seen in
## it, what the status line says, where you are.
func _pipe_net() -> Dictionary:
	var crawl = _main.get("_sewer_pipe_minigame")
	if crawl == null or not crawl.is_open():
		return {}
	var rows: Array = []
	for c in crawl._links:
		var ds: Array = (crawl._links[c] as Array).duplicate()
		ds.sort()
		rows.append("%s:%s" % [c, ds])
	rows.sort()
	var seen := false
	for spr in (crawl.mate._sprites as Dictionary).values():
		seen = seen or (spr != null and is_instance_valid(spr) and spr.visible)
	return {"hash": hash(str(rows)), "mate_seen": seen, "status": str(crawl._hud_status.text), "node": str(crawl._node), "level": int(crawl.raccoon_level)}


## The other warden in the place in Lesna you are in (scripts/town/town_room.gd).
func _town_mate() -> bool:
	var trip = _main.get("_interior_manager").get("_town_trip") if _main != null else null
	var room = trip.get("_room") if trip != null else null
	var mates: Dictionary = room.get("_mates") if room != null else {}
	for m in mates.values():
		if m != null and is_instance_valid(m) and (m as Node3D).visible:
			return true
	return false


## Who has kicked the ball on the court here (warden keys: -11 the host, -12 the other).
func _court_kicked() -> Array:
	var att = _main.get("_warden_play").find_att("14,12")
	return (att.get("_kick_at") as Dictionary).keys() if att != null else []


## The back office: the lost and found, Vera's checklist (none in a sandbox), the
## reviews and the bills.
func _books() -> Dictionary:
	var baz = _main.get("_bazaar")
	var qm = _main.get("_quest_manager")
	return {"box": baz.in_box().size(), "listed": baz.listed().map(func(i): return str(i["short"])),
		"quests": bool(qm.get("_active")) if qm != null else false, "rev": (CoreRoot.get_state().guest_reviews as Array).size(),
		"bills": (_main.get("_billing").bills as Array).size()}


## The camp's Goggle page: what is up, what is booked to go, what is answered.
func _goggle_row() -> Dictionary:
	var g = _main.get("_goggle")
	if g == null:
		return {}
	var removing: Array = []
	var replies: Array = []
	for e in g.reviews:
		if int(e["removing"]) >= 0 and not bool(e["removed"]):
			removing.append(int(e["id"]))
		if str(e["reply"]) != "":
			replies.append("%d:%s" % [int(e["id"]), str(e["reply"])])
	return {"count": int(g.count()), "removing": removing, "replies": replies}


func _write_fingerprint(tag: String) -> void:
	var wg = _main.get("world_generator")
	var bm = _main.get("building_manager")
	var structures: Array = []
	var root: Node = bm.get_node_or_null("Structures") if bm != null else null
	if root != null:
		for c in root.get_children():
			structures.append("%s@%s r%d" % [str(c.get_meta("building_type", "")), str(c.get_meta("grid_origin", Vector2i.ZERO)), int(c.get_meta("build_rotation", 0))])
	structures.sort()
	var nature: Array = []
	for e in wg.nature_snapshot():
		nature.append("%s:%d:%d" % [e["k"], e["x"], e["y"]])
	nature.sort()
	var trees: Array = []
	var nat: Node = wg.get_node_or_null("Nature")
	if nat != null:
		for n in nat.get_children():
			if n is Node3D:
				var t := (n as Node3D)
				trees.append("%s %.2f,%.2f,%.2f,%.2f" % [_stable_name(t), t.global_position.x, t.global_position.z, t.rotation.y, t.scale.x])
	trees.sort()
	var terrain: Array = []
	var ter: Node = wg.get_node_or_null("Terrain")
	if ter != null:
		for n in ter.find_children("*", "Node3D", true, false):
			var t2 := n as Node3D
			if t2.is_inside_tree() and not _passing_fx(t2):
				terrain.append("%s %.2f,%.2f,%.2f" % [_stable_name(t2), t2.global_position.x, t2.global_position.y, t2.global_position.z])
	terrain.sort()
	var room_key := "%d:%d" % [ROOM.x, ROOM.y]
	var acc: Dictionary = CoreRoot.get_state().accommodation_states.get(room_key, {})
	var done: Array = (acc.get("prep_done", []) as Array).duplicate()
	done.sort()
	var other: Node3D = Coop.remote_figure()
	var fp := {
		"tag": tag,
		"role": _role,
		"seed": int(wg.world_seed),
		"structures": structures,
		"nature": nature,
		"trees": trees,
		"terrain": terrain,
		"beds": int(GuestManager.get_bed_metrics().get("capacity", -1)),
		"derelict": _derelict_keys(),
		"money": int(CoreRoot.get_money()),
		"day": int(CoreRoot.get_day()),
		"hour": float(_main.get("_time_of_day_hours")),
		"host_clock": float(Coop.last_clock.get("h", -1.0)),
		"weather": int(_main.get("_weather_state")),
		"sandbox": bool(_main.get("_sandbox")),
		"partner": Coop.has_partner(),
		"partner_look": [int(Coop.partner_look.get("m", -1)), int(Coop.partner_look.get("c", -1))],
		"my_look": [int(Coop.my_look()["m"]), int(Coop.my_look()["c"])],
		"partner_name": Coop.partner_name(),
		"my_name": str(Coop.my_look().get("n", "")),
		"gate_up": get_tree().get_first_node_in_group("camp_gate") != null and get_tree().get_first_node_in_group("camp_gate").is_raised(),
		"other_visible": other != null and other.visible,
		"other_at": str(other.global_position) if other != null else "",
		"me_at": str((_main.get("_player") as Node3D).global_position) if _main.get("_player") != null else "",
		"room_done": done,
		"boat_from_home": _boat_from_home(),
		"other_pose": str(other.get("pose")) if other != null else "",
		"room_figure": _room_figure(),
		"fig_behind_bar": _fig_behind_bar(),
		"coop_taken": _cabin_taken(),
		"coop_screen": float(_main.get("_interior_manager").get("_building_interior").get("_coop_screen_left")) > 0.0,
		"guests": _guest_rows(),
		"mail": _mail_rows(),
		"agents": int((_main.get("_guest_agents").get("_parties") as Dictionary).size()) if _main.get("_guest_agents") != null else -1,
		"me_state": str(_main.coop_local_warden().get("in", "")) + " " + str(_main.coop_local_warden().get("room", {})),
		"night_targets": _main.get("_coop_night").targets() if Coop.is_host() and _main.get("_coop_night") != null else [],
		"mirror": int(_main.get("_coop_night").mirror_count()) if _main.get("_coop_night") != null else -1,
		"enemy_shown_here": _enemy_shown_here(),
		"sanity": (_main.get("_coop_night").sanity as Dictionary).duplicate() if _main.get("_coop_night") != null else {},
		"day_open": (_main.get("_day_events").open_events() as Array).map(func(e): return str(e["kind"])) if _main.get("_day_events") != null else [],
		"corn_led_by_other": Coop.is_host() and _main.get("_corn_hunt") != null and is_instance_valid(_main.get("_corn_hunt")) and _main.get("_corn_hunt").leader != null and _main.get("_corn_hunt").leader == _main.get("_coop_night").proxy(),
		"till_acked": int((_main.get("_coop_till_acked") as Dictionary).values().max()) if not (_main.get("_coop_till_acked") as Dictionary).is_empty() else 0,
		"camp": _camp_rows(),
		"bus_state": _bus_state(),
		"att_me": _main.get("_warden_play").coop_state(),
		"att_mate": str(_main.get("_warden_play").mate_place().get("pose", "")),
		"court_kicked": _court_kicked(),
		"town_mate": _town_mate(),
		"pipe_net": _pipe_net(),
		"books": _books(),
		"goggle": _goggle_row(),
		"wardens": Coop.others().map(func(id): return [int(Coop.look_of(id)["m"]), int(Coop.look_of(id)["c"]), Coop.name_of(id), Coop.figure_of(id) != null and Coop.figure_of(id).visible]),
		"night_passing": _main.get("camp_office") != null and bool(_main.get("camp_office").is_fast_forwarding()),
		"my_slot": Coop.my_slot,
		"room_figs": _room_fig_count(),
		"att_mates": _att_mate_count(),
		"pipe_mates": _pipe_mate_count(),
		"town_mates": _town_mate_count(),
		"enemy_seen": _main.get("_coop_night").mirror_count() if Coop.is_client() and _main.get("_coop_night") != null else (1 if _enemy_shown_here() else 0),
		"bus_mates": _bus_mate_count(),
		"corn_orders": (CoreRoot.get_state().biz.get("orders", []) as Array).filter(func(o): return str(o.get("key", "")) == "15:13").size(),
		"radio": _radio_row(),
		"down": bool(_main.get("_coop_down")),
		"hp": int(_main.get("_player_health")),
		"partner_down": bool(Coop.partner_state.get("dn", false)),
		"in_bed": _main.get("camp_office") != null and bool(_main.get("camp_office").in_bed()),
		"room_status": str(acc.get("status", "")),
		"task": _task_id,
	}
	var f := FileAccess.open(_out_dir.path_join("%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(fp, "\t"))
	f.close()
	print("COOP CHECK fingerprint %s: seed %d, %d structures, %d trees, hour %.2f, room %s %s" % [tag, fp["seed"], structures.size(), trees.size(), fp["hour"], fp["room_status"], str(done)])
