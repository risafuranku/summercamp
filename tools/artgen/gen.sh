#!/usr/bin/env bash
# Generate one piece of art with Grok Imagine through the Cursor agent CLI.
#
#   tools/artgen/gen.sh <id>            generate tools/artgen/out/<id>/raw.png
#   tools/artgen/gen.sh <id> --force    regenerate even if raw.png exists
#
# Rows live in tools/artgen/prompts.tsv:  id <TAB> aspect <TAB> reference(or -) <TAB> prompt
# `reference` is a path relative to godot/ (e.g. assets/textury/npc/host3.png) that is
# copied next to the output and handed to the image tool as a reference.
#
# Generate ONE AT A TIME: parallel agents have been seen swapping each other's output.
# Then run tools/artgen/process.py <id> to bring the result into the game's look.
set -u
cd "$(dirname "$0")"
id="$1"; force="${2:-}"
line=$(grep -P "^$id\t" prompts.tsv) || { echo "unknown id: $id"; exit 1; }
IFS=$'\t' read -r _id aspect ref prompt <<<"$line"
mkdir -p "out/$id"
cd "out/$id"
if [ -f raw.png ] && [ "$force" != "--force" ]; then echo "$id exists"; exit 0; fi
rm -f raw.png
ref_clause=""
if [ "$ref" != "-" ]; then
  cp "../../../../godot/$ref" ref.png
  ref_clause="Pass ref.png from this folder to the image tool as the reference image. "
fi
full="Use your image generation tool. ${ref_clause}Generate natively in ${aspect} aspect ratio and keep the full canvas. ${prompt} Save the result as raw.png in the current directory and report its pixel size. Do not write any other files."
for attempt in 1 2; do
  timeout 900 /c/Users/arnold/AppData/Local/cursor-agent/cursor-agent.cmd -p --force --trust --model grok-4.7-medium-fast "$full" > gen.log 2>&1
  [ -f raw.png ] && break
done
echo "$id $( [ -f raw.png ] && echo ok || echo FAILED )"
