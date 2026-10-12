#!/usr/bin/env bash
# Generate several artgen rows one after another and process each as a 128 px texture
# into godot/assets/textury/camp/<id without "tex_">.png.
#   tools/artgen/batch.sh tex_a tex_b ...
cd "$(dirname "$0")/../.."
for id in "$@"; do
  bash tools/artgen/gen.sh "$id"
  if [ -f "tools/artgen/out/$id/raw.png" ]; then
    python tools/artgen/process.py "$id" texture 128 "assets/textury/camp/${id#tex_}.png" && echo "DONE $id"
  else
    echo "FAILED $id"
  fi
done
echo "BATCH FINISHED"
