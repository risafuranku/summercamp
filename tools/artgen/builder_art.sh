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
	gst_family) $cut "$id" assets/textury/builder/peeps family 8 96 20 && cp godot/assets/textury/builder/peeps/family_7.png godot/assets/textury/builder/peeps/family_6.png ;;
	gst_picker) $cut "$id" assets/textury/builder/peeps picker 8 96 8 ;;
	bld_react) python tools/artgen/split_sheet.py "$id" 0.17 assets/textury/builder/react smile,angry,sick,hearts,notes,zzz,sweat,alert 8 ;;
	bld_stages) $cut "$id" assets/textury/builder/site stage 3 200 10 ;;
	bld_dozer) $cut "$id" assets/textury/builder/site dozer 8 64 6 ;;
	bld_dust) $cut "$id" assets/textury/builder/site dust 4 64 30 ;;
	# Grok's tree row stood upright three times out of four: the frames are strom.png leaned.
	bld_tree) python tools/artgen/tree_sway.py ;;
	bld_dog) $cut "$id" assets/textury/builder/life dog 8 40 ;;
	# Grok's ducks stand on their feet: the swimming ones cut at the waterline (no legs).
	bld_lake) $cut "$id" assets/textury/builder/life lake 8 28 && python -c "
from PIL import Image
for i in range(3):
	p = 'godot/assets/textury/builder/life/lake_%d.png' % i
	im = Image.open(p)
	im.crop((0, 0, im.width, round(im.height * 0.74))).save(p)" ;;
	bld_birds) $cut "$id" assets/textury/builder/life birds 8 36 ;;
	bld_bugs) $cut "$id" assets/textury/builder/life bugs 8 12 ;;
	bld_cursors) python tools/artgen/cursor_frames.py "$id" ;;
	bld_icons)
		$cut "$id" assets/textury/builder/news n 8 28
		d=godot/assets/textury/builder/news
		names=(guest toilet medal coins rain cabin warning tree)
		for i in "${!names[@]}"; do mv -f "$d/n_$i.png" "$d/${names[$i]}.png"; done ;;
	# Rows left out ("-") stay the render's (iso_views.py raw): in decor1_a Grok painted the
	# green bench brown and turned it front-on in all four, its gnome in a green coat; in
	# decor2_a the flagpole and the lamp are other designs (and the flag waves from the
	# render's frames); in fun1_a the mega gnome lost its moss and turned its back; in fun2_a
	# the playground has no swings (their frame was missing from the reference) and the
	# corn stand lost its posts.
	iso4_decor1) python tools/artgen/iso_views.py cut4 "$id" - picnic_table flower_bed - ;;
	iso4_decor2) python tools/artgen/iso_views.py cut4 "$id" - - sewer power_generator ;;
	iso4_fun1) python tools/artgen/iso_views.py cut4 "$id" ping_pong hammock bonfire - ;;
	iso4_fun2) python tools/artgen/iso_views.py cut4 "$id" sports_field lake_slide - - ;;
	iso4_*) python tools/artgen/iso_views.py cut "$id" "${base#iso4_}" ;;
	*) echo "no rule for $id"; exit 1 ;;
esac
