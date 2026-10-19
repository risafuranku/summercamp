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
# ONE AT A TIME: parallel agents have been seen swapping each other's output. So every
# run takes a ticket in out/.grok_queue and waits its turn (oldest ticket first; tickets
# of runs that died are dropped), which also lets two sessions with their own queues take
# turns, one image each, instead of one waiting hours for the other's batch to end.
# Then run tools/artgen/process.py <id> to bring the result into the game's look.
set -u
cd "$(dirname "$0")"
id="$1"; force="${2:-}"
# prompts.tsv, or a prompts_<area>.tsv beside it (prompts_bistro.tsv ...).
line=$(grep -hP "^$id\t" prompts.tsv prompts_*.tsv 2>/dev/null | head -1)
[ -n "$line" ] || { echo "unknown id: $id"; exit 1; }
IFS=$'\t' read -r _id aspect ref prompt <<<"$line"
if [ -f "out/$id/raw.png" ] && [ "$force" != "--force" ]; then echo "$id exists"; exit 0; fi

QDIR="$(pwd)/out/.grok_queue"
mkdir -p "$QDIR"
ticket="$QDIR/$(date +%s%N)-$$"
: > "$ticket"
trap 'rm -f "$ticket"' EXIT

# Another gen.sh running without a ticket (an older copy of this script): wait for it.
untracked_running() {
  local c p
  for c in /proc/[0-9]*/cmdline; do
    p=${c#/proc/}; p=${p%/cmdline}
    [ "$p" = "$$" ] && continue
    # The script itself (argv[1]), not a shell whose command line merely mentions it.
    case "$( { tr '\0' '\n' < "$c"; } 2>/dev/null | sed -n 2p)" in
      *artgen/gen.sh) ;;
      *) continue ;;
    esac
    ls "$QDIR" | grep -q -- "-$p\$" || return 0
  done
  return 1
}

while :; do
  for t in "$QDIR"/*; do
    [ -e "$t" ] || continue
    kill -0 "${t##*-}" 2>/dev/null || rm -f "$t"
  done
  first=$(ls "$QDIR" | sort | head -1)
  if [ "$QDIR/$first" = "$ticket" ] && ! untracked_running; then
    break
  fi
  sleep 3
done

mkdir -p "out/$id"
cd "out/$id"
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
