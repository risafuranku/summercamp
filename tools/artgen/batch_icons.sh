#!/usr/bin/env bash
cd "$(dirname "$0")"
for id in ico_txt ico_setup ico_html ico_image ico_drive ico_floppy ico_help ico_run ico_shutdown ico_documents ico_notepad; do
  bash gen.sh "$id"
done
echo BATCH DONE
