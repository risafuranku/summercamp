#!/usr/bin/env bash
# Builder 98's Grok art into the game, once a row's raw.png is in (and chosen, a or b):
#   tools/artgen/builder_art.sh <grok id>      e.g. gst_quiet_a, bld_dozer_b, iso4_pub_b
# Then: godot --headless --path godot --import
set -e
cd "$(dirname "$0")/../.."
id="$1"
base="${id%_[ab]}"
cut="python tools/artgen/cut_frames.py"
case "$base" in
	gst_quiet) $cut "$id" assets/textury/builder/peeps quiet 8 96 ;;
	gst_drunk) $cut "$id" assets/textury/builder/peeps drunk 8 96 ;;
	gst_chick) $cut "$id" assets/textury/builder/peeps chick 8 96 6 ;;
	gst_tramp) $cut "$id" assets/textury/builder/peeps tramp 8 96 ;;
	gst_family) $cut "$id" assets/textury/builder/peeps family 8 96 ;;
	gst_picker) $cut "$id" assets/textury/builder/peeps picker 8 96 ;;
	bld_react) python tools/artgen/split_sheet.py "$id" 0.17 assets/textury/builder/react smile,angry,sick,hearts,notes,zzz,sweat,alert 8 ;;
	bld_stages) $cut "$id" assets/textury/builder/site stage 3 200 ;;
	bld_dozer) $cut "$id" assets/textury/builder/site dozer 8 64 ;;
	bld_dust) $cut "$id" assets/textury/builder/site dust 4 64 ;;
	bld_tree) $cut "$id" assets/textury/builder/life tree 4 120 ;;
	bld_dog) $cut "$id" assets/textury/builder/life dog 8 40 ;;
	bld_lake) $cut "$id" assets/textury/builder/life lake 8 28 ;;
	bld_birds) $cut "$id" assets/textury/builder/life birds 8 36 ;;
	bld_bugs) $cut "$id" assets/textury/builder/life bugs 8 12 ;;
	bld_cursors)
		$cut "$id" assets/textury/builder/cursors c 11 24
		d=godot/assets/textury/builder/cursors
		names=(dozer_0 dozer_1 dozer_2 path_0 path_1 path_2 lamp_0 lamp_1 bp_0 bp_1 bp_2)
		for i in "${!names[@]}"; do mv -f "$d/c_$i.png" "$d/${names[$i]}.png"; done ;;
	bld_icons)
		$cut "$id" assets/textury/builder/news n 8 28
		d=godot/assets/textury/builder/news
		names=(guest toilet medal coins rain cabin warning tree)
		for i in "${!names[@]}"; do mv -f "$d/n_$i.png" "$d/${names[$i]}.png"; done ;;
	iso4_decor1) python tools/artgen/iso_views.py cut4 "$id" bench picnic_table flower_bed gnome ;;
	iso4_decor2) python tools/artgen/iso_views.py cut4 "$id" flagpole lamp_post sewer power_generator ;;
	iso4_fun1) python tools/artgen/iso_views.py cut4 "$id" ping_pong hammock bonfire mega_gnome ;;
	iso4_fun2) python tools/artgen/iso_views.py cut4 "$id" sports_field lake_slide playground corn_stand ;;
	iso4_*) python tools/artgen/iso_views.py cut "$id" "${base#iso4_}" ;;
	*) echo "no rule for $id"; exit 1 ;;
esac
