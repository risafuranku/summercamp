#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in iso_bonfire iso_caravan iso_sports iso_slide iso_jednota iso_lamp; do
  bash gen.sh "$id"
done
echo BATCH DONE
