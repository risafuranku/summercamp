#!/usr/bin/env python3
"""PROTOTYP 540's things in the bistro's cellar (the row bz540_sheet in prompts_proto.tsv)
from tools/artgen/out/<id>/raw.png into the game's files: the sack in front of the machine
and the tray of meat under its chute (scripts/bistro/machine_station.gd lays them at the
rooms' pixel).

    python tools/artgen/proto_art.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import jednota_art  # noqa: E402

B = "assets/textury/bistro/"


def main():
    jednota_art.sheet("bz540_sheet", [(B + "proto_sack.png", 64), (B + "proto_meat.png", 64)], gap=9)


if __name__ == "__main__":
    main()
