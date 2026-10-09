#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in spr_corn spr_scarecrow; do bash gen.sh "$id"; done
echo BATCH DONE
