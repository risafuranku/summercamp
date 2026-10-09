#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in tb_bulldoze tb_path tb_lamp tb_housing tb_services tb_fun tb_utilities; do bash gen.sh "$id"; done
echo BATCH DONE
