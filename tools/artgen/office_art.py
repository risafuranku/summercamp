#!/usr/bin/env python3
"""The interiors (the reception, the store, the Jednota, the pub, the bus) and the
village's things: Grok renders into the game.

    python tools/artgen/office_art.py

Every row below is (artgen id, mode, size, file in godot/assets/textury/camp/, or
under godot/assets/textury/ when it has a folder: "town/bin.png"). Missing
renders are skipped. Sprites on the darker magenta some renders come on are re-keyed
first. The stove's embers get a mask (stove_glow.png: the orange of the fire window,
the rest black) for office_dressing.gd to light at night.
"""
import os
import sys

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
CAMP = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "camp")

ROWS = [
    ("tex_knotty_pine2", "texture", 128, "knotty_pine.png"),
    ("tex_ceiling_pine", "texture", 128, "ceiling_pine.png"),
    ("tex_wallpaper_70s2", "texture", 128, "wallpaper_70s.png"),
    ("tex_door_interior", "panel", 72, "door_interior.png"),
    ("tex_rug_runner", "sprite", 128, "rug_runner.png"),
    ("tex_rug_rag", "sprite", 96, "rug_rag.png"),
    ("face_stove", "panel", 64, "stove.png"),
    ("spr_wall_clock", "sprite", 64, "wall_clock.png"),
    ("face_calendar", "panel", 72, "calendar.png"),
    ("face_certificate", "panel", 72, "certificate.png"),
    ("spr_extinguisher", "sprite", 96, "extinguisher.png"),
    ("spr_plant_dry", "sprite", 64, "plant_dry.png"),
    ("spr_ceiling_lamp", "sprite", 64, "ceiling_lamp.png"),
    ("face_shelf_linen", "panel", 96, "shelf_linen.png"),
    ("face_shelf_stuff", "panel", 96, "shelf_stuff.png"),
    ("face_boiler", "panel", 64, "boiler.png"),
    ("face_fusebox", "panel", 72, "fusebox.png"),
    ("spr_mop_bucket", "sprite", 96, "mop_bucket.png"),
    ("spr_gas_bottle", "sprite", 80, "gas_bottle.png"),
    ("spr_lost_found", "sprite", 72, "lost_found.png"),
    ("spr_bulb_cord", "sprite", 64, "bulb_cord.png"),
    ("face_bookshelf", "panel", 96, "bookshelf.png"),
    ("face_photo_family", "panel", 56, "photo_family.png"),
    ("spr_slippers", "sprite", 48, "slippers.png"),
    ("spr_chair_clothes", "sprite", 112, "chair_clothes.png"),
    ("spr_coat_hook", "sprite", 112, "coat_hook.png"),
    ("spr_doormat", "sprite", 64, "doormat.png"),
    # The Jednota.
    ("tex_shop_floor", "texture", 128, "shop_floor.png"),
    ("tex_shop_wall", "texture", 128, "shop_wall.png"),
    ("face_shop_shelf_cigs", "panel", 192, "shop_shelf_cigs.png"),
    ("face_shop_shelf_goods", "panel", 192, "shop_shelf_goods.png"),
    ("face_shop_bread", "panel", 80, "shop_bread.png"),
    ("face_shop_fridge", "panel", 80, "shop_fridge.png"),
    ("face_shop_counter", "panel", 192, "shop_counter.png"),
    ("spr_shop_till", "sprite", 64, "shop_till.png"),
    ("spr_shop_scales", "sprite", 56, "shop_scales.png"),
    ("spr_beer_crate_full", "sprite", 64, "beer_crate_full.png"),
    ("spr_card_box", "sprite", 40, "card_box.png"),
    ("spr_shop_baskets", "sprite", 64, "shop_baskets.png"),
    ("spr_shop_freezer", "sprite", 80, "shop_freezer.png"),
    ("face_shop_poster", "panel", 72, "shop_poster.png"),
    # The pub.
    ("tex_pub_floor", "texture", 128, "pub_floor.png"),
    ("tex_pub_wall", "texture", 128, "pub_wall.png"),
    ("tex_pub_wainscot", "texture", 128, "pub_wainscot.png"),
    ("face_pub_backbar", "panel", 224, "pub_backbar.png"),
    ("face_pub_bar", "panel", 192, "pub_bar.png"),
    ("spr_pub_taps", "sprite", 56, "pub_taps.png"),
    ("face_fruit_machine", "panel", 64, "fruit_machine.png"),
    ("spr_mug_full", "sprite", 32, "mug_full.png"),
    ("spr_mug_empty", "sprite", 32, "mug_empty.png"),
    ("spr_antlers", "sprite", 56, "antlers.png"),
    ("spr_dartboard", "sprite", 56, "dartboard.png"),
    ("face_pub_sign", "panel", 80, "pub_sign.png"),
    ("spr_regular_cap", "sprite", 128, "regular_cap.png"),
    ("spr_regular_track", "sprite", 144, "regular_track.png"),
    ("spr_pub_lamp", "sprite", 48, "pub_lamp.png"),
    ("spr_ashtray", "sprite", 24, "ashtray.png"),
    ("tex_tablecloth", "texture", 64, "tablecloth.png"),
    # The village.
    ("tex_sidewalk", "texture", 128, "town/sidewalk.png"),
    ("tex_dirt_path", "texture", 128, "town/dirt_path.png"),
    ("tex_village_grass", "texture", 128, "town/village_grass.png"),
    ("tex_garden_soil", "texture", 128, "town/garden_soil.png"),
    ("tex_plaster_yellow", "texture", 128, "town/plaster_yellow.png"),
    ("tex_plaster_pink", "texture", 128, "town/plaster_pink.png"),
    ("tex_roof_eternit", "texture", 128, "town/roof_eternit.png"),
    ("spr_fence_picket", "sprite", 64, "town/fence_picket.png"),
    ("spr_fence_mesh", "sprite", 64, "town/fence_mesh.png"),
    ("spr_street_bin", "sprite", 64, "town/street_bin.png"),
    ("spr_post_box", "sprite", 48, "town/post_box.png"),
    ("spr_phone_booth", "sprite", 128, "town/phone_booth.png"),
    ("spr_village_radio", "sprite", 160, "town/village_radio.png"),
    ("spr_noticeboard", "sprite", 80, "town/noticeboard.png"),
    ("spr_woodpile", "sprite", 80, "town/woodpile.png"),
    ("spr_laundry", "sprite", 80, "town/laundry.png"),
    ("spr_hen", "sprite", 32, "town/hen.png"),
    ("spr_hen_peck", "sprite", 32, "town/hen_peck.png"),
    ("spr_dog_kennel", "sprite", 64, "town/dog_kennel.png"),
    ("spr_dog_bark", "sprite", 56, "town/dog_bark.png"),
    ("spr_cat", "sprite", 40, "town/cat.png"),
    ("spr_gnome", "sprite", 40, "town/gnome.png"),
    ("spr_wheelbarrow", "sprite", 48, "town/wheelbarrow.png"),
    ("spr_shrine", "sprite", 128, "town/shrine.png"),
    ("spr_pub_sign", "sprite", 64, "town/pub_sign.png"),
    ("spr_flower_box", "sprite", 40, "town/flower_box.png"),
    ("face_window_shutter", "panel", 72, "town/window_shutter.png"),
    ("face_window_flowers", "panel", 64, "town/window_flowers.png"),
    ("face_house_door2", "panel", 56, "town/house_door2.png"),
    ("face_garage_door", "panel", 96, "town/garage_door.png"),
    ("face_car_side", "panel", 160, "town/car_side.png"),
    ("face_car_front", "panel", 80, "town/car_front.png"),
    ("face_car_back", "panel", 80, "town/car_back.png"),
    # The bus.
    ("face_bus_dash", "panel", 192, "town/bus_dash.png"),
    ("face_bus_door_in", "panel", 56, "town/bus_door_in.png"),
    ("spr_bus_driver_back", "sprite", 112, "town/bus_driver_back.png"),
    ("spr_bus_mascot", "sprite", 40, "town/bus_mascot.png"),
    ("spr_no_smoking", "sprite", 32, "town/no_smoking.png"),
    ("spr_bus_litter", "sprite", 48, "town/bus_litter.png"),
    ("tex_bus_curtain", "texture", 64, "town/bus_curtain.png"),
    ("tex_bus_rack", "panel", 160, "town/bus_rack.png"),
    # The camp: clean enamel, the forest floor's things.
    ("tex_enamel_white2", "texture", 128, "enamel_white.png"),
    ("spr_fern", "sprite", 64, "world/fern.png"),
    ("spr_fly_agaric", "sprite", 40, "world/fly_agaric.png"),
    ("spr_boletus", "sprite", 40, "world/boletus.png"),
    ("spr_stump", "sprite", 56, "world/stump.png"),
    ("spr_rock_moss", "sprite", 56, "world/rock_moss.png"),
    ("spr_molehill", "sprite", 40, "world/molehill.png"),
    ("spr_nettles", "sprite", 72, "world/nettles.png"),
    ("spr_leaf_pile", "sprite", 40, "world/leaf_pile.png"),
    ("spr_branch", "sprite", 40, "world/branch.png"),
    ("spr_anthill", "sprite", 56, "world/anthill.png"),
    ("spr_blueberry", "sprite", 48, "world/blueberry.png"),
    ("spr_thistle", "sprite", 64, "world/thistle.png"),
    # The chapel, the kiosk, the motel.
    ("tex_chapel_floor", "texture", 128, "chapel_floor.png"),
    ("tex_chapel_wall", "texture", 128, "chapel_wall.png"),
    ("face_chapel_pews", "panel", 192, "chapel_pews.png"),
    ("face_chapel_altar", "panel", 160, "chapel_altar.png"),
    ("face_stained_window", "panel", 56, "stained_window.png"),
    ("spr_candles_rack", "sprite", 64, "candles_rack.png"),
    ("spr_saint_statue", "sprite", 112, "saint_statue.png"),
    ("spr_crucifix", "sprite", 64, "crucifix.png"),
    ("face_kiosk_shelves", "panel", 192, "kiosk_shelves.png"),
    ("face_kiosk_counter", "panel", 192, "kiosk_counter.png"),
    ("spr_pin_up_calendar", "sprite", 72, "kiosk_calendar.png"),
    ("face_motel_desk", "panel", 192, "motel_desk.png"),
    ("spr_vending_machine", "sprite", 128, "vending_machine.png"),
    ("tex_motel_carpet", "texture", 128, "motel_carpet.png"),
    ("tex_motel_wall", "texture", 128, "motel_wall.png"),
    ("spr_plastic_plant", "sprite", 72, "plastic_plant.png"),
    ("npc_town_lojzova", "sprite", 128, "npc/town_lojzova.png"),
    ("tex_bus_wall2", "texture", 128, "town/bus_wall.png"),
    ("tex_bus_ceiling2", "texture", 128, "town/bus_ceiling.png"),
    ("spr_owl", "sprite", 48, "world/owl.png"),
    ("spr_owl_eyes", "sprite", 16, "world/owl_eyes.png"),
    # The forest road to the stop.
    ("spr_hunters_seat", "sprite", 192, "world/hunters_seat.png"),
    ("spr_timber_stack", "sprite", 96, "world/timber_stack.png"),
    ("spr_deer_feeder", "sprite", 112, "world/deer_feeder.png"),
    ("spr_trail_mark", "sprite", 24, "world/trail_mark.png"),
    ("spr_deer_sign", "sprite", 96, "world/deer_sign.png"),
    ("spr_km_stone", "sprite", 48, "world/km_stone.png"),
    # Ground: the forest road, the turning loop, the verges, the platform.
    ("tex_road_gravel2", "texture", 128, "town/road_gravel.png"),
    ("tex_turnaround", "texture", 128, "town/turnaround.png"),
    ("tex_verge_autumn", "texture", 128, "town/verge_autumn.png"),
    ("tex_forest_floor2", "texture", 128, "town/forest_floor.png"),
    ("tex_kerb_slabs", "texture", 128, "town/kerb_slabs.png"),
    # The camp's pub and bistro outside.
    ("face_camp_pub_front", "panel", 224, "camp_pub_front.png"),
    ("face_camp_pub_side", "panel", 192, "camp_pub_side.png"),
    ("face_camp_bistro_front", "panel", 224, "camp_bistro_front.png"),
    # The wholesaler's van and what it brings.
    ("face_van_side", "panel", 224, "town/van_side.png"),
    ("face_van_front", "panel", 96, "town/van_front.png"),
    ("face_van_back", "panel", 96, "town/van_back.png"),
    ("spr_crates_bread", "sprite", 56, "town/crates_bread.png"),
    ("spr_keg", "sprite", 40, "town/keg.png"),
    ("spr_sack_potatoes", "sprite", 48, "town/sack_potatoes.png"),
    ("spr_corn_crate", "sprite", 48, "town/corn_crate.png"),
    # The corn stand.
    ("face_corn_stand", "panel", 224, "corn_stand.png"),
    ("spr_corn_cob", "sprite", 48, "corn_cob.png"),
    ("spr_corn_raw", "sprite", 48, "corn_raw.png"),
    ("closeup_corn", "close", 320, "closeup/corn_stand.png"),
    # The counter games' new close-ups and the books.
    ("closeup_pub_shots", "close", 320, "closeup/pub_shots.png"),
    ("closeup_glass_wash", "close", 320, "closeup/glass_wash.png"),
    ("closeup_fryer", "close", 320, "closeup/fryer.png"),
    ("closeup_ledger", "close", 320, "closeup/ledger.png"),
    # The office PC's programs.
    ("spr_icon_pub", "sprite", 32, "os98/icons/pub_app.png"),
    ("spr_icon_bistro", "sprite", 32, "os98/icons/bistro_app.png"),
    ("spr_icon_shop", "sprite", 32, "os98/icons/shop_app.png"),
    ("spr_icon_corn", "sprite", 32, "os98/icons/corn_app.png"),
    ("tex_swing_seat", "panel", 48, "swing_seat.png"),
    # Every part of the counter games is a render too (Ricky 18. 10.: "textures for
    # everything"): the stove's slices and basket, the stand's cobs, the back bar's
    # bottles and glasses, the sink's mugs, the books' tabs, pencil and stamp.
    ("cu_cheese_raw", "sprite", 30, "closeup/parts/cheese_raw.png"),
    ("cu_cheese_golden", "sprite", 30, "closeup/parts/cheese_golden.png"),
    ("cu_cheese_burnt", "sprite", 30, "closeup/parts/cheese_burnt.png"),
    ("cu_basket_oil", "panel", 100, "closeup/parts/basket_oil.png"),
    ("cu_basket_oil_gold", "panel", 100, "closeup/parts/basket_oil_gold.png"),
    ("cu_chips_portion", "sprite", 18, "closeup/parts/chips_portion.png"),
    ("cu_smoke", "sprite", 24, "closeup/parts/smoke.png"),
    ("cu_oil_spit", "sprite", 12, "closeup/parts/oil_spit.png"),
    ("cu_wall_rack", "sprite", 34, "closeup/parts/wall_rack.png"),
    ("cu_cob_raw", "sprite", 22, "closeup/parts/cob_raw.png"),
    ("cu_cob_boiled", "sprite", 22, "closeup/parts/cob_boiled.png"),
    ("cu_cob_mushy", "sprite", 22, "closeup/parts/cob_mushy.png"),
    ("cu_cob_buttered", "sprite", 22, "closeup/parts/cob_buttered.png"),
    ("cu_cob_napkin", "sprite", 24, "closeup/parts/cob_napkin.png"),
    ("cu_salt", "sprite", 14, "closeup/parts/salt.png"),
    ("cu_ticket", "sprite", 34, "closeup/parts/ticket.png"),
    ("cu_paper_tab", "sprite", 14, "closeup/parts/paper_tab.png"),
    ("cu_pencil_box", "sprite", 40, "closeup/parts/pencil_box.png"),
    ("cu_pencil_hatch", "sprite", 9, "closeup/parts/pencil_hatch.png"),
    ("cu_stamp_frame", "sprite", 30, "closeup/parts/stamp_frame.png"),
    ("face_ledger_open", "panel", 128, "ledger_open.png"),
    ("cu_bottle_rum", "sprite", 80, "closeup/parts/bottle_rum.png"),
    ("cu_bottle_zelena", "sprite", 80, "closeup/parts/bottle_zelena.png"),
    ("cu_bottle_slivovice", "sprite", 80, "closeup/parts/bottle_slivovice.png"),
    ("cu_bottle_kofola", "sprite", 86, "closeup/parts/bottle_kofola.png"),
    ("cu_glass_shot", "sprite", 34, "closeup/parts/glass_shot.png"),
    ("cu_glass_tall", "sprite", 76, "closeup/parts/glass_tall.png"),
    ("cu_glass_rum", "sprite", 34, "closeup/parts/glass_rum.png"),
    ("cu_glass_zelena", "sprite", 34, "closeup/parts/glass_zelena.png"),
    ("cu_glass_slivovice", "sprite", 34, "closeup/parts/glass_slivovice.png"),
    ("cu_glass_kofola", "sprite", 76, "closeup/parts/glass_kofola.png"),
    ("cu_pour_stream", "sprite", 64, "closeup/parts/pour_stream.png"),
    ("cu_spill", "sprite", 10, "closeup/parts/spill.png"),
    ("cu_mug_dirty", "sprite", 46, "closeup/parts/mug_dirty.png"),
    ("cu_mug_clean", "sprite", 46, "closeup/parts/mug_clean.png"),
    ("cu_suds", "sprite", 12, "closeup/parts/suds.png"),
    ("cu_ticket_tall", "sprite", 37, "closeup/parts/ticket_tall.png"),
    ("cu_ticket_tall_old", "sprite", 37, "closeup/parts/ticket_tall_old.png"),
    ("cu_note_5", "sprite", 16, "closeup/parts/note_5.png"),
    ("cu_note_10", "sprite", 16, "closeup/parts/note_10.png"),
    ("cu_note_20", "sprite", 16, "closeup/parts/note_20.png"),
    ("cu_coin_1", "sprite", 6, "closeup/parts/coin_1.png"),
    ("cu_coin_2", "sprite", 7, "closeup/parts/coin_2.png"),
    ("cu_price_tag", "sprite", 9, "closeup/parts/price_tag.png"),
    ("cu_tap_glass", "sprite", 92, "closeup/parts/tap_glass.png"),
    ("cu_tap_beer", "sprite", 92, "closeup/parts/tap_beer.png"),
    ("cu_tap_foam", "sprite", 16, "closeup/parts/tap_foam.png"),
    ("cu_foam_stream", "sprite", 64, "closeup/parts/foam_stream.png"),
    ("cu_foam_drip", "sprite", 6, "closeup/parts/foam_drip.png"),
    # The office programs' toolbar and the hands' photos.
    ("ico_tb_stock", "sprite", 16, "os98/icons/tb_stock.png"),
    ("ico_tb_order", "sprite", 16, "os98/icons/tb_order.png"),
    ("ico_tb_staff", "sprite", 16, "os98/icons/tb_staff.png"),
    ("ico_tb_books", "sprite", 16, "os98/icons/tb_books.png"),
    ("ico_tb_warning", "sprite", 16, "os98/icons/tb_warning.png"),
    ("photo_lojza", "panel", 48, "os98/photos/lojza.png"),
    ("photo_franta", "panel", 48, "os98/photos/franta.png"),
    ("photo_mirek", "panel", 48, "os98/photos/mirek.png"),
    ("photo_dvorakova", "panel", 48, "os98/photos/dvorakova.png"),
    ("photo_pepa", "panel", 48, "os98/photos/pepa.png"),
    ("photo_hanka", "panel", 48, "os98/photos/hanka.png"),
    ("photo_novakova", "panel", 48, "os98/photos/novakova.png"),
    ("photo_zdenka", "panel", 48, "os98/photos/zdenka.png"),
    ("photo_ivan", "panel", 48, "os98/photos/ivan.png"),
    ("photo_pepicek", "panel", 48, "os98/photos/pepicek.png"),
    ("photo_klara", "panel", 48, "os98/photos/klara.png"),
    ("photo_novak_boy", "panel", 48, "os98/photos/novak_boy.png"),
    # The van's wheels, the stand's awning.
    ("spr_van_wheel", "sprite", 32, "town/van_wheel.png"),
    ("tex_awning_stripes", "texture", 64, "awning_stripes.png"),
    ("spr_awning_fringe", "sprite", 24, "awning_fringe.png"),
    ("spr_steam_puff", "sprite", 16, "steam_puff.png"),
    # The main menu (scripts/ui/main_menu.gd): its plates, the logo's paint, the cursor.
    ("tex_menu_steel", "texture", 64, "ui/menu_steel.png"),
    ("tex_menu_wood", "texture", 64, "ui/menu_wood.png"),
    ("tex_logo_fill", "texture", 64, "ui/logo_fill.png"),
    ("spr_menu_lantern", "sprite", 16, "ui/menu_lantern.png"),
    # The bag (scripts/ui/inventory.gd): its leather, lining, pockets (one a 20 px pocket),
    # the strap's buckles, and what goes in it (a pocket is 20 px, the torch takes two).
    ("tex_inv_leather", "texture", 64, "ui/inv_leather.png"),
    ("tex_inv_canvas", "texture", 64, "ui/inv_canvas.png"),
    ("tex_inv_pocket", "texture", 20, "ui/inv_pocket.png"),
    ("spr_inv_buckle", "sprite", 14, "ui/inv_buckle.png"),
    ("spr_inv_key", "sprite", 16, "items/key_shed.png"),
    ("spr_inv_cigs", "sprite", 18, "items/cigs.png"),
    ("spr_inv_beer", "sprite", 16, "items/beer.png"),
    ("spr_inv_card", "sprite", 18, "items/card.png"),
    ("spr_inv_torch", "sprite", 13, "items/torch.png"),
    # The wind's leaves (scripts/ambient/wind_life.gd), the birds, crows, bats and moths
    # (sky_life.gd), the arrivals plate's car and bell (scripts/ui/arrival_strip.gd).
    ("spr_leaf_oak", "sprite", 14, "world/leaf_oak.png"),
    ("spr_leaf_maple", "sprite", 14, "world/leaf_maple.png"),
    ("spr_leaf_birch", "sprite", 12, "world/leaf_birch.png"),
    ("spr_sky_bird_up", "sprite", 10, "world/sky_bird_up.png"),
    ("spr_sky_bird_down", "sprite", 10, "world/sky_bird_down.png"),
    ("spr_sky_crow_up", "sprite", 14, "world/sky_crow_up.png"),
    ("spr_sky_crow_down", "sprite", 14, "world/sky_crow_down.png"),
    ("spr_sky_bat_up", "sprite", 12, "world/sky_bat_up.png"),
    ("spr_sky_bat_down", "sprite", 12, "world/sky_bat_down.png"),
    ("spr_sky_moth", "sprite", 8, "world/sky_moth.png"),
    ("spr_hud_car", "sprite", 6, "ui/arrive_car.png"),
    ("spr_hud_bell", "sprite", 9, "ui/arrive_bell.png"),
    # The check-in desk's keys on their hooks (scripts/reception/checkin_desk.gd).
    ("spr_key_cabin", "sprite", 21, "key_cabin.png"),
    ("spr_key_tent", "sprite", 16, "key_tent.png"),
    ("spr_key_caravan", "sprite", 20, "key_caravan.png"),
    # Rychla kacka (scripts/town/shop_closeup.gd) and the pub's LUCKY 7 (pub_closeup.gd):
    # the card's paper, the duck, the symbols, the silver; the cabinet, the reels, the bulbs,
    # the button.
    ("tex_card_paper", "texture", 64, "closeup/card_paper.png"),
    ("tex_scratch_foil", "texture", 32, "closeup/scratch_foil.png"),
    ("cu_card_duck", "sprite", 19, "closeup/card_duck.png"),
    ("cu_sym_duck", "sprite", 20, "closeup/sym_duck.png"),
    ("cu_sym_seven", "sprite", 20, "closeup/sym_seven.png"),
    ("cu_sym_bell", "sprite", 20, "closeup/sym_bell.png"),
    ("cu_sym_cherry", "sprite", 20, "closeup/sym_cherry.png"),
    ("cu_sym_clover", "sprite", 20, "closeup/sym_clover.png"),
    ("cu_sym_acorn", "sprite", 20, "closeup/sym_acorn.png"),
    ("tex_slot_cabinet", "texture", 64, "closeup/slot_cabinet.png"),
    ("cu_reel_cherry", "sprite", 34, "closeup/reel_cherry.png"),
    ("cu_reel_plum", "sprite", 34, "closeup/reel_plum.png"),
    ("cu_reel_bell", "sprite", 34, "closeup/reel_bell.png"),
    ("cu_reel_bar", "sprite", 18, "closeup/reel_bar.png"),
    ("cu_reel_seven", "sprite", 34, "closeup/reel_seven.png"),
    ("cu_slot_lamp_on", "sprite", 9, "closeup/slot_lamp_on.png"),
    ("cu_slot_lamp_off", "sprite", 9, "closeup/slot_lamp_off.png"),
    ("cu_slot_button", "sprite", 22, "closeup/slot_button.png"),
    # The tent's upgrade catalog on the groundsheet (scripts/tent_interior.gd).
    ("face_tent_catalog", "panel", 40, "tent_catalog.png"),
    # The weather (scripts/weather_visuals.gd, season_look.gd): the rain's streak, its
    # splash, the storm's bolt, a snowflake, a puddle.
    ("spr_rain_streak", "sprite", 24, "world/rain_streak.png"),
    ("spr_rain_splash", "sprite", 10, "world/rain_splash.png"),
    ("spr_lightning_bolt", "sprite", 96, "world/lightning_bolt.png"),
    ("spr_snowflake", "sprite", 6, "world/snowflake.png"),
    ("spr_puddle", "sprite", 40, "world/puddle.png"),
    # The weather at a room's windows (scripts/ambient/room_weather.gd): drops on the glass,
    # water running down it, the window's shape the lightning throws in.
    ("tex_glass_drops", "texture", 128, "world/glass_drops.png"),
    ("tex_glass_runs", "texture", 128, "world/glass_runs.png"),
    ("tex_window_cookie", "texture", 64, "world/window_cookie.png"),
    # Your breath in the cold (scripts/ambient/player_breath.gd).
    ("spr_breath_puff", "sprite", 16, "world/breath_puff.png"),
    # The still air (scripts/ambient/air_life.gd): a midge, spider silk, thistle down.
    ("spr_midge", "sprite", 4, "world/midge.png"),
    ("spr_gossamer", "sprite", 14, "world/gossamer.png"),
    ("spr_thistle_down", "sprite", 8, "world/thistle_down.png"),
    # Spider webs (scripts/ambient/spider_webs.gd): the garden spider, the silk with dew
    # beads (the strands' texture), torn strands across your face.
    ("spr_spider", "sprite", 14, "world/spider.png"),
    ("tex_silk_strand", "texture", 64, "world/silk_strand.png"),
    ("face_web_tangle", "panel", 320, "ui/web_face.png"),
    ("warden_a_bedfoot", "sprite", 56, "npc/warden_a_bedfoot.png"),
    ("warden_b_bedfoot", "sprite", 56, "npc/warden_b_bedfoot.png"),
    ("warden_c_bedfoot", "sprite", 56, "npc/warden_c_bedfoot.png"),
    ("warden_d_bedfoot", "sprite", 56, "npc/warden_d_bedfoot.png"),
]
TEXTURY = os.path.join(HERE, "..", "..", "godot", "assets", "textury")
## Textures kept in their own colours, not snapped to the palette.
UNSNAPPED_TEXTURES = {"tex_card_paper"}
## Thin bright things on black (water on glass): fattened before they are shrunk, or the
## shrinking averages them away.
DILATED_TEXTURES = {"tex_glass_drops", "tex_glass_runs", "tex_silk_strand"}


def rekeyed(art_id):
    path = os.path.join(HERE, "out", art_id, "raw.png")
    img = Image.open(path).convert("RGB")
    px = img.load()
    r, g, b = px[2, 2]
    if g < 70 and r > 120 and b > 90 and abs(r - b) < 100 and not (r > 240 and b > 240):
        for y in range(img.height):
            for x in range(img.width):
                r, g, b = px[x, y]
                if r > 120 and g < 70 and b > 90 and abs(r - b) < 100:
                    px[x, y] = (255, 0, 255)
        path = os.path.join(HERE, "out", art_id, "raw_keyed.png")
        img.save(path)
    return path


def _no_snap(img, keep_alpha):
    out = img.convert("RGBA")
    out.putalpha(img.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return out


def despilled(art_id):
    """The counter games' parts: everything tinted by the magenta (the soft edge between a
    slice and the background, the pink seen through a glass, a darker pink backdrop)
    becomes the key, so none of it survives as a red or pink rim."""
    img = Image.open(rekeyed(art_id)).convert("RGB")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y]
            if r - g > 50 and b - g > 35:
                px[x, y] = (255, 0, 255)
    path = os.path.join(HERE, "out", art_id, "raw_despilled.png")
    img.save(path)
    return path


def stove_glow():
    """The embers from the render (the palette mutes them): bright orange there, scaled
    to the face's size, white where at least a quarter of a block glowed."""
    raw = os.path.join(HERE, "out", "face_stove", "raw.png")
    face = os.path.join(CAMP, "stove.png")
    if not (os.path.exists(raw) and os.path.exists(face)):
        return
    src = Image.open(raw).convert("RGB")
    m = Image.new("L", src.size, 0)
    sp = src.load()
    mp = m.load()
    # Only inside the fire door's little window (the rust elsewhere is orange too).
    for y in range(int(src.height * 0.33), int(src.height * 0.47)):
        for x in range(int(src.width * 0.3), int(src.width * 0.7)):
            r, g, b = sp[x, y]
            if r >= 95 and r > 1.5 * g and r - b > 70:
                mp[x, y] = 255
    size = Image.open(face).size
    small = m.resize(size, Image.BOX).point(lambda v: 255 if v > 64 else 0)
    out = Image.merge("RGB", (small, small, small))
    out.save(os.path.join(CAMP, "stove_glow.png"))
    print("stove_glow.png", sum(1 for v in small.getdata() if v), "px")


def key_white(names):
    """Faces rendered on a pale sky (the cars): flood the near-white in from the edges."""
    from collections import deque
    for n in names:
        path = os.path.join(TEXTURY, n)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        px = im.load()
        w, h = im.size
        q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
        seen = set()
        while q:
            x, y = q.popleft()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            r, g, b, a = px[x, y]
            if not (r > 170 and g > 165 and b > 150 and max(r, g, b) - min(r, g, b) < 45):
                continue
            px[x, y] = (0, 0, 0, 0)
            q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
        im.save(path)


def small_icons():
    """The 16 px twins of the OS icons (os98/icons/<name>_16.png)."""
    for k in ["pub", "bistro", "shop", "corn"]:
        src = os.path.join(TEXTURY, "os98", "icons", "%s_app.png" % k)
        if os.path.exists(src):
            im = Image.open(src).convert("RGBA")
            if im.size != (32, 32):
                # Into a 32 x 32 square, centred, nothing stretched.
                im.thumbnail((32, 32), Image.NEAREST)
                sq = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
                sq.paste(im, ((32 - im.width) // 2, 32 - im.height), im)
                im = sq
                im.save(src)
            im.resize((16, 16), Image.BOX).point(lambda v: v).save(os.path.join(TEXTURY, "os98", "icons", "%s_app_16.png" % k))


def main():
    for art_id, mode, size, name in ROWS:
        raw = os.path.join(HERE, "out", art_id, "raw.png")
        if not os.path.exists(raw):
            print("missing", art_id)
            continue
        # Already done from this render (--all redoes everything).
        dest = os.path.join(TEXTURY, name) if "/" in name else os.path.join(CAMP, name)
        if os.path.exists(dest) and os.path.getmtime(dest) > os.path.getmtime(raw) and "--all" not in sys.argv:
            continue
        if mode == "close":
            # A 320x240 close-up picture: the whole render, scaled to fit, on the palette.
            src = Image.open(raw).convert("RGB")
            src = src.crop(((src.width - src.height * 4 // 3) // 2, 0, (src.width + src.height * 4 // 3) // 2, src.height)) if src.width * 3 > src.height * 4 else src
            out = process.snap(src.resize((320, 240), Image.BOX), False)
        elif mode == "sprite":
            if art_id.startswith("cu_"):
                # The close-ups' own colours (the Build palette has no dark orange: a golden
                # slice came out red): shrunk into pixels, not snapped to it.
                snap = process.snap
                process.snap = lambda img, keep: _no_snap(img, keep)
                out = process.sprite(despilled(art_id), size)
                process.snap = snap
            else:
                out = process.sprite(rekeyed(art_id), size)
        elif mode == "panel":
            out = process.panel(raw, size)
        elif art_id in DILATED_TEXTURES:
            from PIL import ImageFilter
            fat = os.path.join(HERE, "out", art_id, "raw_dilated.png")
            Image.open(raw).convert("RGB").filter(ImageFilter.MaxFilter(7)).save(fat)
            out = process.texture(fat, size)
        elif art_id in UNSNAPPED_TEXTURES:
            # Printed colours the Build palette has not got (the card's bright yellow).
            snap = process.snap
            process.snap = lambda img, keep: img.convert("RGB")
            out = process.texture(raw, size)
            process.snap = snap
        else:
            out = process.texture(raw, size)
        out.save(dest)
        print(name, out.size)
    stove_glow()
    small_icons()
    key_white(["town/car_side.png", "town/car_front.png", "town/car_back.png"])


if __name__ == "__main__":
    main()
