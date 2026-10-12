#!/usr/bin/env bash
# Like batch.sh but processed as `panel <width>` (keeps the aspect: posters, views).
#   tools/artgen/batch_panels.sh <width> tex_a tex_b ...
cd "$(dirname "$0")/../.."
width="$1"; shift
for id in "$@"; do
  bash tools/artgen/gen.sh "$id"
  if [ -f "tools/artgen/out/$id/raw.png" ]; then
    python tools/artgen/process.py "$id" panel "$width" "assets/textury/camp/${id#tex_}.png" && echo "DONE $id"
  else
    echo "FAILED $id"
  fi
done
echo "BATCH FINISHED"
