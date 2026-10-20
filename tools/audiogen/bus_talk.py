#!/usr/bin/env python3
"""People talking on the 380 (Czech), with the ElevenLabs text-to-speech API.

    python tools/audiogen/bus_talk.py          every line whose file is missing
    python tools/audiogen/bus_talk.py --index  only rewrite the index (no API calls)

Lines live in tools/audiogen/bus_talk.tsv:
    scene <TAB> n <TAB> role <TAB> voice <TAB> Czech <TAB> English
Output: godot/assets/sfx/bus/talk/<scene>_<n>.mp3 and talk.json beside them (the
scenes, who says what, the subtitle). scripts/town/bus_ride.gd plays a scene only when
all its files are there. The key: ELEVENLABS_API_KEY or tools/audiogen/.env (it needs
the text_to_speech permission and the characters in the quota). Never commit a key.
"""
import json
import os
import sys
import urllib.error
import urllib.request

import gen

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "bus", "talk")
API = "https://api.elevenlabs.io/v1/text-to-speech/%s"
MODEL = "eleven_multilingual_v2"
# Premade ElevenLabs voices; the game picks people on board to match "gender".
VOICES = {
    "babka": ("XrExE9yKIg1WjnnlVkGX", "f"),   # Matilda
    "deda": ("pqHfZKP75CvOlQylNhV4", "m"),    # Bill
    "zena": ("pFZP5JQG7iQjIQuC4Bku", "f"),    # Lily
    "muz": ("nPczCjzI2devNBz1zQrb", "m"),     # Brian
    "ridic": ("2EiwWnXFnvU5JabPnv8n", "m"),   # Clyde: gruff, a voice that has seen things
    "soused": ("t0jbNlBVZ17f02VDIeMI", "m"),  # Jessie: old and raspy, old Vacek from Pristoupim
    "vondra": ("flq6f7yk4E4fJM5XTYuZ", "m"),  # Michael: old, slow, old Vondra in his Skoda
}


def rows():
    out = []
    for line in open(os.path.join(HERE, "bus_talk.tsv"), encoding="utf-8"):
        line = line.rstrip("\r\n")
        if not line or line.startswith("#"):
            continue
        scene, n, role, voice, cs, en = line.split("\t")
        out.append({"scene": scene, "n": int(n), "role": role, "voice": voice, "cs": cs, "en": en,
                    "file": "%s_%s.mp3" % (scene, n), "gender": VOICES[voice][1]})
    return out


def say(row, key):
    body = json.dumps({"text": row["cs"], "model_id": MODEL,
                       "voice_settings": {"stability": 0.45, "similarity_boost": 0.75}}).encode("utf-8")
    req = urllib.request.Request(API % VOICES[row["voice"]][0], data=body, method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    with open(os.path.join(OUT, row["file"]), "wb") as f:
        f.write(data)
    print(row["file"], len(data) // 1024, "KB")


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    table = rows()
    scenes = {}
    for r in table:
        scenes.setdefault(r["scene"], []).append({k: r[k] for k in ("n", "role", "voice", "gender", "file", "en")})
    with open(os.path.join(OUT, "talk.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"scenes": scenes}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if "--index" in argv:
        return
    key = gen.api_key()
    for r in table:
        if os.path.exists(os.path.join(OUT, r["file"])):
            continue
        try:
            say(r, key)
        except urllib.error.HTTPError as e:
            print(r["file"], "FAILED", e.code, e.read()[:200])
            break


if __name__ == "__main__":
    main(sys.argv[1:])
