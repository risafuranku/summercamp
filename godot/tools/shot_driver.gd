extends Node

## Scripted screenshot driver for visual verification.
##
## Boots the real main scene, walks it through a named scenario and writes PNGs.
## It re-parents itself to the SceneTree root before swapping scenes, so it survives
## the change to `main.tscn` and can keep poking the live game.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 \
##       res://tools/shot_driver.tscn -- --scenario=tour --out=/tmp/shots
##
## Scenarios are plain step lists (see SCENARIOS). Steps:
##   ["wait", seconds]          real-time wait
##   ["shot", "name"]           save <out>/<name>.png
##   ["call", "method", args]   call a method on Main
##   ["call_on", "prop", "method", args]  call a method on one of Main's members
##   ["hours", h]               advance the in-game clock by h hours
##   ["eval", "expr"]           evaluate a GDScript Expression with Main as base
##   ["money", amount]          set cash
##   ["clear", x, y, w, h]      bulldoze trees/buildings in a rect (<= 5x5, real builder path)
##   ["build", type, x, y, rot] request a build through the real builder authority
##   ["book", name, archetype, party, nights, arrival_min?]  confirm a booking (GuestManager path)
##   ["prep_all"]                                    make every room up (as if done in the interiors)
##   ["player", x, y, yaw_deg]  put the player on a grid tile facing yaw
##   ["timescale", k]           Engine.time_scale
##
## Debug tooling only; never referenced by the game itself.

const MAIN_SCENE := "res://scenes/main.tscn"

const SCENARIOS := {
	"boot": [
		["wait", 0.4], ["shot", "00_loading"],
		["wait_menu"], ["wait", 2.5], ["shot", "01_menu"],
	],
	"views": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_player.rotate_y(PI)"], ["wait", 1.0], ["shot", "10_day_camp"],
		["eval", "_player.rotate_y(PI * 0.5)"], ["wait", 1.0], ["shot", "11_day_side"],
		["hours", 9.5], ["wait", 2.0], ["eval", "_player.rotate_y(PI * 0.5)"], ["wait", 1.0], ["shot", "12_dusk"],
		["hours", 3.0], ["wait", 3.0], ["shot", "13_night"],
	],
	"guests": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 20000],
		["clear", 2, 3, 5, 5], ["clear", 7, 3, 5, 5], ["clear", 12, 3, 5, 5],
		["clear", 2, 8, 5, 5], ["clear", 7, 8, 5, 5], ["clear", 12, 8, 5, 5],
		["build", "path", 9, 3, 0], ["build", "path", 9, 4, 0], ["build", "path", 9, 5, 0], ["build", "path", 9, 6, 0],
		["build", "path", 10, 3, 0], ["build", "path", 8, 4, 0], ["build", "path", 7, 4, 0], ["build", "path", 11, 4, 0],
		["build", "tent_1", 4, 5, 0], ["build", "tent_1", 5, 5, 0], ["build", "tent_1", 6, 6, 0],
		["build", "cabin_1", 12, 6, 0], ["build", "toilet_block", 7, 7, 0], ["build", "shower_block", 8, 8, 0],
		["build", "vecerka", 12, 9, 0], ["build", "bonfire", 5, 10, 0], ["build", "lamp_post", 10, 7, 0],
		["wait", 0.5],
		["prep_all"], ["book", "Novak family", "quiet_guy", 2, 2], ["prep_all"], ["book", "Pepa", "drunk", 1, 2], ["prep_all"], ["book", "Kristyna", "cheap_chick", 1, 1],
		["player", 9, 2, 180.0], ["timescale", 3.0],
		["wait", 3.0], ["shot", "20_arrivals"],
		["wait", 10.0], ["shot", "21_camp_life"],
		["hours", 3.0], ["wait", 4.0], ["shot", "22_camp_later"],
		["player", 10, 6, 90.0], ["wait", 2.0], ["shot", "23_close"],
		["player", 8, 4, 150.0], ["wait", 2.0], ["shot", "24_close2"],
		["timescale", 1.0],
	],
	"hud": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 7, 3, 5, 5], ["build", "tent_1", 8, 5, 0], ["build", "tent_1", 9, 5, 0],
		["build", "toilet_block", 10, 5, 0],
		["prep_all"], ["book", "Pepa", "drunk", 2, 2],
		["player", 9, 2, 180.0], ["wait", 2.0],
		["eval", "_hud_manager.push_status('Build confirmed: Toilet Block', 1)"],
		["eval", "_hud_manager.show_quote('Pepa', 'One more beer. Just one.', 70.0)"],
		["eval", "_hud_manager.set_objective({'title': \"Vera's checklist\", 'text': 'Build a toilet block so guests stop using the bushes.', 'progress': '0/1', 'reward': '$150'})"],
		["eval", "_hud_manager.set_hint_text('[E] Enter reception')"],
		["eval", "_hud_manager.show_banner('NIGHT 1', 'BUILDER LOCKED. SURVIVE UNTIL 06:30.', Color(1.0, 0.3, 0.24), 6.0)"],
		["wait", 1.0], ["shot", "30_hud"],
		["guest_card"],
		["wait", 0.5], ["shot", "31_hud_card"],
	],
	"quest": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 14.0],
		["eval", "[_quest_manager.current_step_id(), _is_crt_desktop_active()]"], ["shot", "40_quest_start_at_desk"],
		["mail_read", "task_id", "read_vera"], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"],
		["money", 5000], ["clear", 16, 3, 4, 4], ["build", "tent_1", 17, 4, 0], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"],
		["build", "toilet_block", 19, 4, 0], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"],
		["mail_accept", "task_id", "accept_booking"], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"],
		["call_on", "_interior_manager", "close_main_interior_if_open", []], ["wait", 1.5], ["shot", "41_quest_stood_up"],
		["player", 15, 3, 0.0], ["eval", "_player.rotate_y(PI)"], ["wait", 1.0], ["shot", "42_quest_make_up"],
		["prep_all"], ["wait", 1.0], ["eval", "_quest_manager.current_step_id()"],
		["hours", 1.6], ["wait", 2.0], ["eval", "_quest_manager.current_step_id()"],
		["eval", "_quest_manager.notify('talked_to_guest')"], ["wait", 1.0],
		["eval", "_quest_manager.current_step_id()"], ["shot", "43_quest_feed"],
		["eval", "_quest_manager.export_state()"],
	],
	"menu": [
		["wait_menu"], ["wait", 2.5], ["shot", "01_menu"],
		["call_on", "_main_menu", "show_page", ["load"]], ["wait", 0.4], ["shot", "05_menu_load"],
		["call_on", "_main_menu", "show_page", ["options"]], ["wait", 0.4], ["shot", "06_menu_options"],
		["call_on", "_main_menu", "show_page", ["controls"]], ["wait", 0.4], ["shot", "07_menu_controls"],
		["call_on", "_main_menu", "show_page", ["main"]],
		["call_on", "_main_menu", "show_loading", ["Generating a fresh camp..."]], ["wait", 0.6], ["shot", "08_menu_loading"],
	],
	"pause": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["call", "_open_pause_menu", []], ["wait", 0.5], ["shot", "50_pause"],
		["call_on", "_pause_menu", "_show", ["options"]], ["wait", 0.4], ["shot", "51_pause_options"],
		["call_on", "_pause_menu", "_show", ["main"]],
		["call", "_on_pause_save_requested", []], ["wait", 0.4], ["shot", "52_pause_saved"],
		["call", "_close_pause_menu", [true]], ["wait", 0.5], ["shot", "53_resumed"],
	],
	"gameover": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.5],
		["call", "_trigger_game_over", ["death"]], ["wait", 3.5], ["shot", "60_gameover"],
	],
	"crt": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0], ["shot", "70_crt_desktop"],
	],
	"upkeep": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 7, 3, 5, 5],
		["build", "toilet_block", 8, 5, 0], ["build", "shower_block", 10, 5, 0], ["build", "lamp_post", 9, 7, 0],
		["wait", 0.5],
		["condition", 8, 5, 0.3], ["break", 10, 5], ["condition", 9, 7, 0.65],
		["eval", "_maintenance.get_upkeep_snapshot()"], ["eval", "_maintenance._active"], ["eval", "CoreRoot.get_state().failures"],
		["player", 9, 2, 180.0], ["wait", 1.5], ["shot", "90_upkeep_signs"], ["eval", "_maintenance._markers"],
		["player", 8, 4, 180.0], ["wait", 1.0], ["shot", "91_upkeep_hint"],
		["press", "maintain"], ["wait", 0.8], ["shot", "92_upkeep_working"],
		["wait", 1.6], ["release", "maintain"], ["wait", 0.3], ["shot", "93_upkeep_done"],
		["hours", 12.0], ["player", 9, 2, 180.0], ["wait", 2.0], ["shot", "94_upkeep_night"],
	],
	"crtmap": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 20000],
		["clear", 2, 3, 5, 5], ["clear", 7, 3, 5, 5], ["clear", 12, 3, 5, 5], ["clear", 7, 8, 5, 5],
		["build", "path", 9, 3, 0], ["build", "path", 9, 4, 0], ["build", "path", 9, 5, 0], ["build", "path", 9, 6, 0], ["build", "path", 8, 4, 0], ["build", "path", 10, 4, 0],
		["build", "tent_1", 4, 5, 0], ["build", "tent_1", 5, 5, 0], ["build", "cabin_1", 12, 6, 0],
		["build", "toilet_block", 7, 7, 0], ["build", "bonfire", 10, 9, 0], ["build", "lamp_post", 10, 7, 0],
		["prep_all"], ["book", "Novak family", "quiet_guy", 2, 2], ["prep_all"], ["book", "Pepa", "drunk", 1, 2], ["prep_all"], ["book", "Kristyna", "cheap_chick", 1, 1],
		["timescale", 3.0], ["wait", 6.0], ["timescale", 1.0],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior._crt_ui.open_app('builder') != null"], ["wait", 4.2], ["shot", "b0_crt_builder"],
		["eval", "_interior_manager._building_interior._crt_ui.is_desktop_ready()"],
		["wait", 1.5], ["shot", "b1_crt_builder_later"],
		["crt_screen", "b2_crt_screen"], ["timescale", 3.0], ["wait", 4.0], ["timescale", 1.0], ["crt_screen", "b3_crt_screen_later"],
	],
	"pipes": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_sewer_pipe_minigame.open_repair(Vector2i(0, 25), 'sewer')"], ["wait", 1.5], ["shot", "c0_pipes_ladder"], ["eval", "_sewer_pipe_minigame._rig.position"], ["eval", "_sewer_pipe_minigame._rig.rotation"], ["eval", "_sewer_pipe_minigame._links[_sewer_pipe_minigame._entry]"], ["eval", "_sewer_pipe_minigame._entry"],
		["key", "W"], ["wait", 1.0], ["shot", "c1_pipes_fwd"],
		["key", "W"], ["wait", 1.0], ["key", "D"], ["wait", 1.0], ["shot", "c2_pipes_turn"],
		["keyhold", "Tab", true], ["wait", 0.4], ["shot", "c3_pipes_map"], ["keyhold", "Tab", false],
		["eval", "_sewer_pipe_minigame._thing_on"],
	],
	"night": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["player", 12, 8, 0.0], ["hours", 13.0], ["wait", 3.0],
		["call", "debug_spawn_enemy", ["girl", 3]], ["wait", 1.0], ["enemy_dist"],
		["look_at_enemy"], ["wait", 0.6], ["shot", "a0_girl_far"], ["enemy_dist"],
		["eval", "_player.rotate_y(PI)"], ["wait", 9.0], ["look_at_enemy"], ["wait", 0.4], ["enemy_dist"], ["shot", "a1_girl_closer"],
		["call", "_stop_active_enemy_brain", []],
		["call", "debug_spawn_enemy", ["tourist", 3]], ["wait", 1.0], ["look_at_enemy"], ["enemy_dist"],
		["wait", 6.5], ["shot", "a2_tourist_1"], ["wait", 0.5], ["shot", "a3_tourist_2"], ["wait", 0.6], ["shot", "a4_tourist_3"],
		["call", "_stop_active_enemy_brain", []],
		["call", "debug_spawn_enemy", ["silent_man", 3]], ["wait", 6.0], ["shot", "a5_hatter"],
		["call", "_stop_active_enemy_brain", []],
		["player", 1, 1, 225.0], ["call", "debug_spawn_enemy", ["stalker", 3]], ["wait", 1.0], ["look_at_enemy"], ["enemy_dist"], ["wait", 0.5], ["shot", "a6_stalker"],
		["wait", 5.0], ["look_at_enemy"], ["enemy_dist"], ["shot", "a7_stalker_close"],
	],
	"night2": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["player", 12, 8, 0.0], ["hours", 13.0], ["wait", 3.0],
		["call", "debug_spawn_enemy", ["tourist", 3]],
		["until", "_enemy_brains[0]._phase == 1", 20.0], ["look_at_enemy"], ["wait", 1.2], ["shot", "n0_photo_framing"],
		["eval", "_player.rotate_y(PI)"], ["until", "_enemy_brains[0]._flash_t > 0.2", 10.0], ["shot", "n1_photo_flash_behind"],
		["eval", "_enemy_brains[0].get_debug_snapshot()"],
		["call", "_stop_active_enemy_brain", []],
		["call", "debug_spawn_enemy", ["silent_man", 3]], ["until", "_enemy_brains[0]._dist < 8.0", 40.0],
		["eval", "_enemy_brains[0].get_debug_snapshot()"], ["look_at_enemy"], ["wait", 0.2], ["shot", "n2_hatter_in_light"],
		["eval", "_enemy_brains[0].get_debug_snapshot()"],
	],
	"breaker": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["call_on", "_interior_manager", "close_main_interior_if_open", []],
		["money", 5000], ["clear", 16, 3, 3, 3], ["build", "lamp_post", 17, 4, 0], ["build", "lamp_post", 17, 20, 0],
		["hours", 12.5], ["wait", 2.0], ["player", 15, 5, 0.0], ["eval", "_player.rotate_y(PI)"], ["wait", 1.0], ["shot", "b0_lamps_on"],
		["eval", "_night_jobs._jobs.map(func(j): return [j.kind, j.at])"],
		["eval", "_night_jobs.set('breaker_tripped', true)"], ["eval", "_night_jobs.changed.emit()"], ["wait", 1.0], ["shot", "b1_power_out"],
		["eval", "_breaker_panel.open(1)"], ["wait", 0.6], ["shot", "b2_board"],
		["eval", "_breaker_panel.set('_main_on', true)"], ["wait", 0.5], ["shot", "b3_tripped"],
		["eval", "_breaker_panel._up.fill(false)"], ["eval", "_breaker_panel.set('_main_on', true)"],
		["eval", "_breaker_panel._up.fill(true)"], ["eval", "_breaker_panel._up.set(1, false)"], ["wait", 1.8], ["shot", "b4_fixed"],
		["wait", 2.0], ["shot", "b5_half_lamps"],
	],
	"senses": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "[get_tree().root.find_child('RadioOutdoor', true, false).playing, snappedf(get_tree().root.find_child('RadioOutdoor', true, false).volume_db, 0.1), get_tree().root.find_child('RadioOutdoor', true, false).global_position.distance_to(_player.global_position), get_tree().root.find_child('RadioPlayer', true, false).volume_db]"],
		["hours", 13.0], ["wait", 2.0],
		["player", 1, 1, 225.0], ["call", "debug_spawn_enemy", ["girl", 3]], ["wait", 1.0],
		["look_at_enemy"], ["eval", "_player.rotate_y(deg_to_rad(120))"], ["wait", 1.2], ["enemy_dist"],
		["eval", "[_senses.gaze, snappedf(_senses.hush, 0.01), snappedf(_senses.fear, 0.01), _senses.nearest]"],
		["shot", "s0_face_glances"],
		["look_at_enemy"], ["wait", 1.5],
		["eval", "[_senses.gaze, snappedf(_senses.hush, 0.01), snappedf(_senses.fear, 0.01)]"],
		["shot", "s1_face_sees_it"],
		["call", "_stop_active_enemy_brain", []],
		["money", 5000], ["clear", 7, 3, 5, 5], ["build", "tent_1", 8, 5, 0], ["prep_all"], ["book", "Pepa", "drunk", 1, 3], ["wait", 0.5],
		["call", "debug_spawn_enemy", ["girl", 3]], ["wait", 1.0],
		["look_at_enemy"], ["eval", "_player.rotate_y(deg_to_rad(-120))"], ["wait", 1.2],
		["eval", "[_senses.gaze, snappedf(_senses.fear, 0.01)]"],
		["shot", "s2_guest_face_glances"],
	],
	"uncanny": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 7, 3, 5, 5], ["build", "tent_1", 8, 5, 0], ["build", "tent_1", 10, 5, 0],
		["prep_all"], ["book", "Pepa", "drunk", 1, 4], ["book", "Mirek", "quiet_guy", 1, 4], ["wait", 0.5],
		["hours", 33.0], ["wait", 1.0], ["eval", "[_day_index, _time_of_day_hours]"],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 16.0],
		["eval", "_interior_manager._building_interior._crt_ui._on_program_installed('guestrack')"],
		["eval", "_interior_manager._building_interior._crt_ui._open_guestrack_app()"], ["wait", 2.0],
		["crt_screen", "u0_guestrack"],
		["eval", "_interior_manager._building_interior._crt_ui._open_email_app()"], ["wait", 1.5],
		["crt_screen", "u1_mail"],
	],
	"builder98": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 3000], ["clear", 7, 3, 5, 5], ["clear", 12, 8, 4, 4],
		["build", "path", 9, 3, 0], ["build", "path", 9, 4, 0], ["build", "path", 9, 5, 0], ["build", "path", 9, 6, 0], ["build", "path", 8, 4, 0], ["build", "path", 10, 4, 0],
		["build", "tent_1", 8, 5, 0], ["build", "cabin_1", 10, 6, 0], ["build", "bonfire", 12, 8, 0], ["build", "lamp_post", 10, 5, 0], ["build", "pub", 13, 10, 0],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 7.0],
		["signal", "program_installed", "builder"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior._crt_ui.open_app('builder') != null"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._open_category('housing')"],
		["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._select('cabin_1')"], ["wait", 0.3],
		["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._map_panel.apply_zoom_step(1)"], ["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._map_panel.apply_zoom_step(1)"], ["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._map_panel.apply_zoom_step(1)"],
		["wait", 0.5], ["crt_screen", "c0_builder_catalogue"],
		["build", "tent_1", 7, 7, 0], ["wait", 0.12], ["crt_screen", "c1_builder_dropin"], ["wait", 0.35], ["crt_screen", "c2_builder_pop"],
		["eval", "_interior_manager._building_interior._crt_ui.app_of('builder')._module._open_category('fun')"], ["wait", 0.3], ["crt_screen", "c3_builder_fun"],
		["hours", 9.4], ["wait", 1.5], ["crt_screen", "c4_builder_dusk"],
	],
	"look": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._tent_interior.open_tent(1)"], ["wait", 1.2], ["shot", "tent_interior_0_center"], ["eval", "_interior_manager._tent_interior._catalog_screen_rect()"],
		["eval", "_interior_manager._tent_interior._look.set('yaw_deg', 48)"], ["eval", "_interior_manager._tent_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "tent_interior_1_left"], ["eval", "_interior_manager._tent_interior._catalog_screen_rect()"],
		["eval", "_interior_manager._tent_interior._look.set('yaw_deg', -48)"], ["eval", "_interior_manager._tent_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "tent_interior_2_right"],
		["eval", "_interior_manager._tent_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._tent_interior._look.set('pitch_deg', 16)"], ["wait", 0.8], ["shot", "tent_interior_3_up"],
		["eval", "_interior_manager._tent_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._tent_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "tent_interior_4_down"],
		["eval", "_interior_manager._tent_interior._look.set('yaw_deg', 48)"], ["eval", "_interior_manager._tent_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "tent_interior_5_left_down"],
		["eval", "_interior_manager._tent_interior.close_tent()"], ["wait", 0.5],
		["eval", "_interior_manager._cabin_interior.open_cabin(1)"], ["wait", 1.2], ["shot", "cabin_interior_0_center"], ["eval", "_interior_manager._cabin_interior._catalog_screen_rect()"],
		["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 72)"], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "cabin_interior_1_left"],
		["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', -72)"], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "cabin_interior_2_right"],
		["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', 20)"], ["wait", 0.8], ["shot", "cabin_interior_3_up"],
		["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "cabin_interior_4_down"],
		["eval", "_interior_manager._cabin_interior._look.set('yaw_deg', 72)"], ["eval", "_interior_manager._cabin_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "cabin_interior_5_left_down"],
		["eval", "_interior_manager._cabin_interior.close_cabin()"], ["wait", 0.5],
		["eval", "_interior_manager._service_interior.open_service('toilet_block')"], ["wait", 1.2], ["shot", "service_interior_0_center"],
		["eval", "_interior_manager._service_interior._look.set('yaw_deg', 65)"], ["eval", "_interior_manager._service_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "service_interior_1_left"],
		["eval", "_interior_manager._service_interior._look.set('yaw_deg', -65)"], ["eval", "_interior_manager._service_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "service_interior_2_right"],
		["eval", "_interior_manager._service_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._service_interior._look.set('pitch_deg', 20)"], ["wait", 0.8], ["shot", "service_interior_3_up"],
		["eval", "_interior_manager._service_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._service_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "service_interior_4_down"],
		["eval", "_interior_manager._service_interior._look.set('yaw_deg', 65)"], ["eval", "_interior_manager._service_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "service_interior_5_left_down"],
		["eval", "_interior_manager._service_interior.close_service()"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 1.2], ["shot", "building_interior_0_center"],
		["eval", "_interior_manager._building_interior._look.set('yaw_deg', 70)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "building_interior_1_left"],
		["eval", "_interior_manager._building_interior._look.set('yaw_deg', -70)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', 0)"], ["wait", 0.8], ["shot", "building_interior_2_right"],
		["eval", "_interior_manager._building_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', 22)"], ["wait", 0.8], ["shot", "building_interior_3_up"],
		["eval", "_interior_manager._building_interior._look.set('yaw_deg', 0)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "building_interior_4_down"],
		["eval", "_interior_manager._building_interior._look.set('yaw_deg', 70)"], ["eval", "_interior_manager._building_interior._look.set('pitch_deg', -30)"], ["wait", 0.8], ["shot", "building_interior_5_left_down"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.5],
	],
	"gate": [
		["auto_checkin", false],
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8],
		["eval", "[grid_manager.grid_width, get_tree().get_first_node_in_group('camp_gate').gap_center_x]"],
		["money", 5000], ["clear", 16, 3, 3, 3], ["build", "tent_1", 17, 4, 0], ["build", "tent_1", 18, 4, 0], ["build", "tent_1", 17, 5, 0], ["wait", 0.5],
		["book", "Pepa", "drunk", 1, 2, 0], ["book", "Mirek", "quiet_guy", 1, 1, 0], ["book", "Kristyna", "cheap_chick", 1, 1, 50], ["hours", 0.1], ["wait", 1.0],
		["player", 15, 3, 0.0], ["wait", 1.0], ["shot", "g0_from_camp"],
		["player", 15, -4, 180.0], ["wait", 1.0], ["shot", "g1_from_road"],
		["player", 16, -4, 135.0], ["wait", 1.0], ["shot", "g2_booth"],
		["player", 15, 1, 180.0], ["wait", 1.0], ["shot", "g2b_checkin_hint"], ["eval", "_find_guest_in_view()"],
		["prep_all"], ["hours", 0.05], ["checkin"], ["player", 14, -3, 160.0], ["wait", 2.2], ["shot", "g3_barrier_up"],
		["wait", 7.0], ["shot", "g4_barrier_down"],
		["hours", 12.0], ["wait", 2.0], ["player", 15, -4, 180.0], ["wait", 1.0], ["shot", "g5_gate_night"], ["eval", "[get_tree().get_first_node_in_group('camp_gate')._booth_light.visible, _time_state, _time_of_day_hours]"],
	],
	"prep": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 16, 3, 3, 3], ["build", "tent_1", 17, 4, 0], ["wait", 0.5],
		["book", "Pepa", "drunk", 1, 2, 0], ["hours", 0.05], ["wait", 0.5],
		["open_room", 17, 4], ["wait", 1.2], ["shot", "p0_tent_messy"],
		["aim_task", "_tent_interior", "bed"], ["wait", 0.4], ["shot", "p1_hover_bed"],
		["eval", "[_interior_manager._tent_interior._prep.tasks._target_under_cursor(), _interior_manager._tent_interior._prep.tasks._hover, _interior_manager._tent_interior._prep.tasks.is_visible_in_tree(), _interior_manager._tent_interior._prep.tasks._targets.keys()]"],
		["lmb", true], ["wait", 0.9], ["shot", "p2_holding"], ["wait", 1.2], ["lmb", false], ["wait", 0.4], ["shot", "p3_bed_done"],
		["aim_task", "_tent_interior", "floor"], ["wait", 0.3], ["lmb", true], ["wait", 1.8], ["lmb", false], ["wait", 0.6], ["shot", "p4_tent_ready"],
		["eval", "GuestManager.get_room_state('17:4')"],
	],
	"prepcabin": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 9000], ["clear", 16, 3, 4, 4], ["build", "cabin_1", 17, 4, 0], ["wait", 0.5], ["eval", "_interior_manager._handle_replace_upgrade(Vector2i(17, 4), 'cabin_1', 'cabin_2', 0)"], ["wait", 0.5], ["gm", "get_room_state", "17:4"],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 0.8], ["open_room", 17, 4], ["wait", 1.2], ["shot", "q0_cabin_messy"],
		["aim_task", "_cabin_interior", "bed"], ["wait", 0.4], ["shot", "q1_hover_bed"],
		["lmb", true], ["wait", 2.4], ["lmb", false], ["wait", 0.4],
		["aim_task", "_cabin_interior", "floor"], ["wait", 0.3], ["shot", "q2_hover_bottles"], ["lmb", true], ["wait", 1.8], ["lmb", false], ["wait", 0.4], ["shot", "q3_main_done"],
		["eval", "_interior_manager._cabin_interior._switch_cabin_room(1)"], ["wait", 0.8], ["shot", "q4_bathroom_dirty"],
		["aim_task", "_cabin_interior", "bathroom"], ["wait", 0.3], ["lmb", true], ["wait", 1.2], ["shot", "q5_scrubbing"], ["wait", 1.3], ["lmb", false], ["wait", 0.5], ["shot", "q6_cabin_ready"],
	],
	"saveload": [
		["wait_menu"], ["wait", 1.0], ["shot", "01_menu"],
		["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["money", 5000], ["clear", 7, 3, 5, 5],
		["build", "tent_1", 8, 5, 0], ["build", "toilet_block", 10, 5, 0], ["wait", 0.5],
		["prep_all"], ["book", "Pepa", "drunk", 1, 3], ["condition", 10, 5, 0.4],
		["hours", 26.0], ["wait", 1.0],
		["eval", "get_upkeep_snapshot()['rows'].size()"],
		["eval", "get_electricity_ui_snapshot()['unpaid_count']"],
		["eval", "GuestManager.get_bed_metrics()"],
		["eval", "_day_index"],
		["call", "request_manual_save", ["check"]], ["wait", 0.5],
		["call", "_enter_main_menu", []], ["wait_menu"], ["wait", 1.0],
		["call", "_on_menu_continue_pressed", []], ["wait_gameplay"], ["wait", 1.5],
		["eval", "get_upkeep_snapshot()['rows'].size()"],
		["eval", "get_electricity_ui_snapshot()['unpaid_count']"],
		["eval", "GuestManager.get_bed_metrics()"],
		["eval", "_day_index"],
		["shot", "99_after_load"],
	],
	"blood": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["player", 9, 4, 180.0], ["wait", 0.5],
		["call", "damage_player", [30]], ["wait", 0.12], ["shot", "94_blood_flight"], ["eval", "_blood_fx._drops.size()"],
		["wait", 1.0], ["shot", "95_blood"], ["eval", "[_blood_fx._drops.size(), _blood_fx._decals.size()]"],
		["call", "damage_player", [60]], ["wait", 1.2], ["shot", "96_blood_heavy"], ["eval", "[_blood_fx._drops.size(), _blood_fx._decals.size()]"],
		["eval", "_player.rotate_y(PI)"], ["wait", 0.5], ["shot", "97_blood_behind"],
	],
	"weather": [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["player", 9, 2, 180.0], ["wait", 1.0], ["shot", "80_clear"],
		["eval", "weather_system.set_weather(4)"], ["wait", 20.0], ["shot", "81_rain_half"],
		["wait", 25.0], ["shot", "82_rain"],
		["eval", "weather_system.set_weather(2)"], ["wait", 45.0], ["shot", "83_fog"],
		["hours", 13.0], ["eval", "weather_system.set_weather(6)"], ["wait", 45.0], ["shot", "84_anomaly_night"],
	],
	"probe": [
		["wait_menu"], ["wait", 1.0],
		["eval", "get_viewport().get_visible_rect().size"],
		["eval", "get_tree().root.size"],
		["eval", "get_tree().root.content_scale_factor"],
		["eval", "DisplayServer.window_get_size()"],
	],
	"tour": [
		["wait_menu"], ["wait", 2.0], ["shot", "01_menu"],
		["call", "_on_menu_new_game_pressed", []],
		["wait", 0.25], ["shot", "02_loading_new"],
		["wait_gameplay"], ["wait", 2.5], ["shot", "03_gameplay"],
		["call_on", "_interior_manager", "open_startup_crt_view", []], ["wait", 6.0], ["shot", "04_crt"],
	],
}

var _main: Node
var _out_dir := "user://shots"
var _steps: Array = []
var _step_index := 0
var _wait_left := 0.0
var _waiting_for := ""


func _ready() -> void:
	var scenario := "boot"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out_dir = arg.get_slice("=", 1)
	_steps = SCENARIOS.get(scenario, SCENARIOS["boot"]).duplicate(true)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_detach_and_boot")


func _detach_and_boot() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	get_tree().change_scene_to_file(MAIN_SCENE)


var _until_expr := ""
var _until_deadline := 0


## Waiting parties are checked in by hand in the game; scenarios that are not about the
## barrier get it done for them every second. ["auto_checkin", false] turns it off.
var _auto_checkin := true
var _checkin_timer := 0.0


func _process(delta: float) -> void:
	_checkin_timer -= delta
	if _auto_checkin and _checkin_timer <= 0.0 and _main != null:
		_checkin_timer = 1.0
		for row in GuestManager.get_arrivals():
			if bool(row.get("at_gate", false)):
				GuestManager.request_check_in(int(row.get("id", -1)))
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene
		if _main == null or _main == self:
			return
	if _wait_left > 0.0:
		_wait_left -= delta
		return
	if not _waiting_for.is_empty():
		if not _condition_met(_waiting_for):
			return
		_waiting_for = ""
	if not _until_expr.is_empty():
		var ex := Expression.new()
		if ex.parse(_until_expr) == OK and bool(ex.execute([], _main)) == false and Time.get_ticks_msec() < _until_deadline:
			return
		_until_expr = ""
	if _step_index >= _steps.size():
		print("SHOT DRIVER: done")
		get_tree().quit(0)
		set_process(false)
		return
	var step: Array = _steps[_step_index]
	_step_index += 1
	_run_step(step)


func _condition_met(what: String) -> bool:
	match what:
		"menu":
			return bool(_main.get("_startup_bootstrap_complete")) and bool(_main.get("_menu_mode"))
		"gameplay":
			return bool(_main.get("_gameplay_started")) and not bool(_main.get("_menu_mode"))
	return true


func _run_step(step: Array) -> void:
	var kind := str(step[0])
	match kind:
		"wait":
			_wait_left = float(step[1])
		"wait_menu":
			_waiting_for = "menu"
		"wait_gameplay":
			_waiting_for = "gameplay"
		"shot":
			_save_shot(str(step[1]))
		"call":
			var args: Array = step[2] if step.size() > 2 else []
			if _main.has_method(str(step[1])):
				_main.callv(str(step[1]), args)
			else:
				push_warning("SHOT DRIVER: Main has no method %s" % step[1])
		"call_on":
			var target = _main.get(str(step[1]))
			var args2: Array = step[3] if step.size() > 3 else []
			if target != null and target.has_method(str(step[2])):
				target.callv(str(step[2]), args2)
			else:
				push_warning("SHOT DRIVER: %s has no method %s" % [step[1], step[2]])
		"money":
			CoreRoot.apply_changes({"money": int(step[1])})
		"clear":
			EventBus.RequestDemolish.emit(Rect2i(int(step[1]), int(step[2]), int(step[3]), int(step[4])))
		"build":
			EventBus.RequestBuild.emit(str(step[1]), Vector2i(int(step[2]), int(step[3])), int(step[4]))
		"book":
			# Optional 6th field: minutes until the party reaches the barrier (default 0).
			EventBus.customer_booking_confirmed.emit({
				"guest_name": str(step[1]), "archetype": str(step[2]),
				"guests": int(step[3]), "nights": int(step[4]), "from": "%s <guest@mail>" % step[1],
				"arrival_minutes": int(step[5]) if step.size() > 5 else 0,
			})
		"until":
			# Hold the script until an Expression on Main is true (or [2] seconds pass).
			_until_expr = str(step[1])
			_until_deadline = Time.get_ticks_msec() + int(float(step[2] if step.size() > 2 else 20.0) * 1000.0)
		"gm":
			# Call a GuestManager method (Expression cannot reach autoloads): [method, args...]
			print("SHOT DRIVER gm %s -> %s" % [step[1], GuestManager.callv(str(step[1]), step.slice(2))])
		"auto_checkin":
			_auto_checkin = bool(step[1])
		"checkin":
			for row in GuestManager.get_arrivals():
				print("SHOT DRIVER checkin %s -> %s" % [row.get("name", ""), GuestManager.request_check_in(int(row.get("id", -1)))])
		"prep_all":
			# Make every room up, as the player would in the interiors.
			for key in GuestManager.get_accommodation_states().keys():
				for t in GuestManager.get_room_state(str(key)).get("tasks", []):
					GuestManager.complete_room_task(str(key), str(t["id"]))
		"player":
			_main.set("debug_camera", null)
			var player = _main.get("_player")
			var gm = _main.get("grid_manager")
			if player != null and gm != null:
				player.global_position = gm.grid_to_world(Vector2i(int(step[1]), int(step[2]))) + Vector3(0, 0.2, 0)
				player.rotation.y = deg_to_rad(float(step[3]))
		"mail_read":
			var mail: Dictionary = EmailManager.find_mail(str(step[1]), step[2])
			print("SHOT DRIVER mail_read: ", mail.get("subject", "(none)"))
			if not mail.is_empty():
				EmailManager.mark_read(mail)
		"mail_accept":
			var mail2: Dictionary = EmailManager.find_mail(str(step[1]), step[2])
			print("SHOT DRIVER mail_accept: ", mail2.get("subject", "(none)"), " -> ", EmailManager.confirm_customer_booking(mail2) if not mail2.is_empty() else false)
		"signal":
			EventBus.emit_signal(str(step[1]), step[2])
		"guest_card":
			var snap: Array = GuestManager.get_guest_life_snapshot()
			if not snap.is_empty():
				_main.get("_hud_manager").show_guest_card(snap[0])
		"press":
			Input.action_press(str(step[1]))
		"release":
			Input.action_release(str(step[1]))
		"condition":
			# ["condition", x, y, value] sets a building's condition (0..1)
			var st = CoreRoot.get_state()
			var at := Vector2i(int(step[1]), int(step[2]))
			for c in st.grid.cells.keys():
				var d: Dictionary = st.grid.cells[c]
				if d.get("root_coord", c) == at:
					d["maintenance"] = float(step[3])
					st.grid.cells[c] = d
		"break":
			var bc := Vector2i(int(step[1]), int(step[2]))
			var bstate = CoreRoot.get_state()
			bstate.failures["%d:%d" % [bc.x, bc.y]] = {"type": "x", "coord": bc, "since_day": 1, "repair_progress": 0.0}
			EventBus.building_failed.emit(bc, str(bstate.grid.cells[bc].get("type", "")))
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = OS.find_keycode_from_string(str(step[1]))
			ev.keycode = ev.physical_keycode
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
		"keyhold":
			var ev2 := InputEventKey.new()
			ev2.physical_keycode = OS.find_keycode_from_string(str(step[1]))
			ev2.keycode = ev2.physical_keycode
			ev2.pressed = bool(step[2])
			Input.parse_input_event(ev2)
		"crt_screen":
			# Save the CRT desktop's own viewport (what is drawn on the monitor).
			var crt = _main.get("_interior_manager").get("_building_interior").get("_crt_ui")
			if crt != null:
				var img: Image = crt.get_viewport().get_texture().get_image()
				img.save_png(_out_dir.path_join(str(step[1]) + ".png"))
				print("SHOT DRIVER: crt %s %s" % [step[1], img.get_size()])
		"topdown":
			# A camera high above a point (grid x, y, height, tilt deg) for layout shots.
			var gm2 = _main.get("grid_manager")
			var world3d: Node3D = _main.get("_world_3d")
			var cam3 := Camera3D.new()
			world3d.add_child(cam3)
			var at: Vector3 = gm2.grid_to_world(Vector2i(int(step[1]), int(step[2])))
			cam3.global_position = at + Vector3(0, float(step[3]), float(step[3]) * tan(deg_to_rad(90.0 - float(step[4]))))
			cam3.look_at(at, Vector3.FORWARD if float(step[4]) >= 89.0 else Vector3.UP)
			cam3.far = 600.0
			var env_src: Environment = cam3.get_world_3d().environment if cam3.get_world_3d() != null else null
			if env_src == null:
				var we = _main.find_child("WorldEnvironment", true, false)
				if we != null:
					env_src = we.environment
			if env_src != null:
				var env_clear: Environment = env_src.duplicate()
				env_clear.fog_enabled = false
				env_clear.volumetric_fog_enabled = false
				cam3.environment = env_clear
			var old_cam = _main.get("debug_camera")
			if old_cam != null and is_instance_valid(old_cam):
				old_cam.queue_free()
			_main.set("debug_camera", cam3)
		"open_room":
			# Walk into the structure at grid (x, y) through the real interaction path.
			var bm = _main.get("building_manager")
			var root3 = bm.get_node_or_null("Structures")
			for c in root3.get_children():
				if c.get_meta("grid_origin", Vector2i(-99, -99)) == Vector2i(int(step[1]), int(step[2])):
					var im = _main.get("_interior_manager")
					print("SHOT DRIVER open_room %s type=%s module=%s" % [c.name, c.get_meta("building_type", ""), im._module_for_building_type(str(c.get_meta("building_type", "")))])
					im.handle_structure_interact(c)
					break
		"aim_task":
			# Turn the interior's head toward a room task, then put the OS cursor on it
			# ([interior, id]), as a player would look at the thing before clicking it.
			var interior = _main.get("_interior_manager").get(str(step[1]))
			var tasks = interior.get("_prep").tasks
			var target: Dictionary = tasks._targets.get(str(step[2]), {})
			if not target.is_empty():
				var cam: Camera3D = tasks._camera
				var look = interior.get("_look")
				var base: Vector3 = interior.get("_cam_base_rot")
				var to: Vector3 = target["body"].global_position - cam.global_position
				var yaw := rad_to_deg(atan2(-to.x, -to.z) - base.y)
				var pitch := rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()) - base.x)
				look.yaw_deg = clampf(yaw, -look.yaw_limit_deg, look.yaw_limit_deg)
				look.pitch_deg = clampf(pitch, -look.pitch_down_deg, look.pitch_up_deg)
				Input.warp_mouse(Vector2(DisplayServer.window_get_size()) * 0.5)
				print("SHOT DRIVER aim look -> %.1f %.1f (base %s, to %s)" % [look.yaw_deg, look.pitch_deg, base, to])
				# Let the head turn settle, then aim (an internal follow-up step).
				_steps.insert(_step_index, ["_aim_cursor", step[1], step[2]])
				_wait_left = 0.6
		"_aim_cursor":
			var interior2 = _main.get("_interior_manager").get(str(step[1]))
			var tasks2 = interior2.get("_prep").tasks
			var target2: Dictionary = tasks2._targets.get(str(step[2]), {})
			if not target2.is_empty():
				var cam2: Camera3D = tasks2._camera
				var vp_size := Vector2(tasks2._viewport.size)
				var screen := get_viewport().get_visible_rect().size
				var sp: Vector2 = cam2.unproject_position(target2["body"].global_position) / vp_size * screen
				# warp_mouse takes window pixels; the canvas may be scaled to the window.
				Input.warp_mouse(sp * Vector2(DisplayServer.window_get_size()) / screen)
				print("SHOT DRIVER aim_task %s at %s look now %.1f %.1f rot %s" % [step[2], sp, interior2.get("_look").yaw_deg, interior2.get("_look").pitch_deg, cam2.rotation_degrees])
		"lmb":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = bool(step[1])
			ev.position = get_viewport().get_mouse_position()
			ev.button_mask = MOUSE_BUTTON_MASK_LEFT if bool(step[1]) else 0
			Input.parse_input_event(ev)
		"look_at_enemy":
			# Turn the player toward the newest enemy's body.
			var brains: Array = _main.get("_enemy_brains")
			var pl = _main.get("_player")
			if not brains.is_empty() and pl != null:
				var body = brains.back().get("_body")
				if body != null and is_instance_valid(body):
					var to: Vector3 = body.global_position - pl.global_position
					pl.rotation.y = atan2(-to.x, -to.z)
		"enemy_dist":
			var brains2: Array = _main.get("_enemy_brains")
			var pl2 = _main.get("_player")
			if not brains2.is_empty() and pl2 != null:
				var b2 = brains2.back().get("_body")
				if b2 != null:
					print("SHOT DRIVER enemy %s at %.1f m visible=%s" % [brains2.back().get_enemy_id(), b2.global_position.distance_to(pl2.global_position), b2.visible])
		"timescale":
			Engine.time_scale = float(step[1])
		"hours":
			var ts = _main.get("time_system")
			if ts != null:
				ts.step_time_hours(float(step[1]))
				_main.call("_sync_runtime_state_from_systems", true)
		"eval":
			var expr := Expression.new()
			if expr.parse(str(step[1])) == OK:
				var result = expr.execute([], _main)
				if expr.has_execute_failed():
					push_warning("SHOT DRIVER: eval failed: %s" % step[1])
				else:
					print("SHOT DRIVER eval: %s -> %s" % [step[1], str(result)])
			else:
				push_warning("SHOT DRIVER: eval parse error: %s" % expr.get_error_text())


func _save_shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	print("SHOT DRIVER: %s -> %s (%s)" % [shot_name, path, error_string(err)])
