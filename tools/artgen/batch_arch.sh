#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in host_tramp host_family host_pensioner enemy_whistler enemy_child enemy_basket; do bash gen.sh "$id"; done
echo BATCH DONE
