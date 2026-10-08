#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in tex_gravel_road tex_planks_grey tex_planks_dark tex_corrugated_roof tex_blanket_check tex_lino_floor tex_wallpaper_70s tex_tiles_bathroom tex_lake_water tex_lake_shore tex_window_curtain tex_door_wood; do
  bash gen.sh "$id"
done
echo BATCH DONE
