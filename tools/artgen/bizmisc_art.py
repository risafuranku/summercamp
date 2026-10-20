#!/usr/bin/env python3
"""The businesses' odd things (rows in prompts_bizmisc.tsv) from tools/artgen/out/<id>/raw.png
into the game's files: the note a hand away today leaves where they would stand
(scripts/business/crew_figures.gd).

    python tools/artgen/bizmisc_art.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jednota_art  # noqa: E402


def main():
    jednota_art.sheet("bzn_note", [("assets/textury/camp/note_away.png", 40)], gap=9)


if __name__ == "__main__":
    main()
