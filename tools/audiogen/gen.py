#!/usr/bin/env python3
"""Generate sound effects with the ElevenLabs sound-generation API.

    python tools/audiogen/gen.py <id> [<id> ...]     generate these rows
    python tools/audiogen/gen.py --all               every row whose file is missing
    python tools/audiogen/gen.py <id> --force        regenerate even if it exists

Rows live in tools/audiogen/prompts.tsv:
    id <TAB> seconds <TAB> destination (relative to godot/) <TAB> prompt

The API key is read from the environment (ELEVENLABS_API_KEY) or from
tools/audiogen/.env, which is gitignored. Output is MP3 as the API returns it; Godot
imports it directly. Keep prompts concrete and physical: what makes the sound, what
it is made of, how far away, what room.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
API = "https://api.elevenlabs.io/v1/sound-generation"


def api_key():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    env = os.path.join(HERE, ".env")
    if os.path.exists(env):
        for line in open(env, encoding="utf-8"):
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No ElevenLabs key: set ELEVENLABS_API_KEY or write tools/audiogen/.env")


def rows():
    out = {}
    for line in open(os.path.join(HERE, "prompts.tsv"), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        rid, seconds, dest, prompt = line.split("\t", 3)
        out[rid] = (float(seconds), dest, prompt)
    return out


def generate(rid, seconds, dest, prompt, key):
    body = json.dumps({
        "text": prompt,
        "duration_seconds": seconds,
        "prompt_influence": 0.6,
    }).encode("utf-8")
    req = urllib.request.Request(API, data=body, method="POST", headers={
        "xi-api-key": key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    })
    with urllib.request.urlopen(req, timeout=180) as resp:
        data = resp.read()
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    print("%s -> %s (%d KB)" % (rid, dest, len(data) // 1024))


def main(argv):
    force = "--force" in argv
    ids = [a for a in argv if not a.startswith("--")]
    table = rows()
    if "--all" in argv:
        ids = [rid for rid, (_, dest, _) in table.items() if force or not os.path.exists(os.path.join(GODOT, dest))]
    key = api_key()
    failed = 0
    for rid in ids:
        if rid not in table:
            print("unknown id:", rid)
            failed += 1
            continue
        seconds, dest, prompt = table[rid]
        if os.path.exists(os.path.join(GODOT, dest)) and not force:
            print("%s exists" % rid)
            continue
        try:
            generate(rid, seconds, dest, prompt, key)
        except Exception as e:  # keep going; report at the end
            print("%s FAILED: %s" % (rid, e))
            failed += 1
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
