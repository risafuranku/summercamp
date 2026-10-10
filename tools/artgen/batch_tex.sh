#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in tex_plaster_stone tex_brick_red tex_planks_red tex_tiles_green tex_concrete tex_tarp_canvas; do bash gen.sh "$id"; done
echo BATCH DONE
