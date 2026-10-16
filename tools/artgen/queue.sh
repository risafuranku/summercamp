#!/usr/bin/env bash
# Generate several artgen rows one after another (raw.png only, process by hand).
#   tools/artgen/queue.sh id_a id_b ...
cd "$(dirname "$0")"
for id in "$@"; do bash gen.sh "$id"; done
echo "QUEUE FINISHED"
