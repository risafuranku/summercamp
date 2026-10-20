#!/usr/bin/env python3
"""Put translations into godot/locale/cs.po from a JSON file {msgid: msgstr}.

  python tools/i18n/fill.py batch.json [--force]

A msgid the catalogue does not have yet is added as a manual entry ("#. manual": the
extractor keeps it even when no code has it literally, e.g. a string put together in
code that the lookup only ever sees whole). A plural is "one||many": [three forms].
Without --force an existing translation is not overwritten (it is reported).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract as ex  # noqa: E402


def main(argv):
    if not argv:
        print(__doc__)
        return
    force = "--force" in argv
    with open(argv[0], encoding="utf-8") as f:
        batch = json.load(f)
    header, entries = ex.read_po(ex.PO)
    added = changed = kept = 0
    for key, val in batch.items():
        if "||" in key:
            one, many = key.split("||", 1)
            forms = val if isinstance(val, list) else [val] * 3
            e = entries.get(one)
            if e is None:
                entries[one] = {"comments": ["#. manual"], "plural": many, "str": forms}
                added += 1
            elif force or not ex.translated(e):
                e["plural"] = many
                e["str"] = forms
                changed += 1
            else:
                kept += 1
            continue
        e = entries.get(key)
        if e is None:
            entries[key] = {"comments": ["#. manual"], "str": val}
            added += 1
        elif force or not ex.translated(e):
            e["str"] = val
            changed += 1
        elif e["str"] != val:
            kept += 1
            print("kept (use --force):", json.dumps(key, ensure_ascii=False), "=", json.dumps(e["str"], ensure_ascii=False))
    ex.write_po(ex.PO, header, entries)
    done = sum(1 for e in entries.values() if ex.translated(e))
    print("filled %d, added %d, kept %d; %d of %d translated" % (changed, added, kept, done, len(entries)))


if __name__ == "__main__":
    main(sys.argv[1:])
