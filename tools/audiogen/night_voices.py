#!/usr/bin/env python3
"""Voices of the night things (the boy and his father, ...) with the ElevenLabs
text-to-speech API.

    python tools/audiogen/night_voices.py            every line whose file is missing
    python tools/audiogen/night_voices.py <id> ...   these lines (regenerated)

Lines live in tools/audiogen/night_voices.tsv: id <TAB> voice <TAB> file <TAB> Czech.
The boy is a light young voice the game pitches up (no child voices on this account);
said slowly and flat. The key comes from ELEVENLABS_API_KEY (text_to_speech permission).
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "npc")
API = "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_64"
MODEL = "eleven_multilingual_v2"
# Premade voices: [id, fallback id, settings].
VOICES = {
    "boy": ["cgSgspJ2msm6clMCkdW9", "pFZP5JQG7iQjIQuC4Bku", {"stability": 0.35, "similarity_boost": 0.7, "style": 0.35}],
    "dad": ["iP95p4xoKVk53GoZ742B", "nPczCjzI2devNBz1zQrb", {"stability": 0.75, "similarity_boost": 0.75, "style": 0.0}],
    # The mushroom granny: an older woman's voice said slowly (the game pitches it down).
    "granny": ["XrExE9yKIg1WjnnlVkGX", "pFZP5JQG7iQjIQuC4Bku", {"stability": 0.7, "similarity_boost": 0.7, "style": 0.3}],
    # The Whistler's calls in a guest's voice out of the dark.
    "mimic": ["nPczCjzI2devNBz1zQrb", "iP95p4xoKVk53GoZ742B", {"stability": 0.55, "similarity_boost": 0.7, "style": 0.2}],
}


def rows():
    out = {}
    for line in open(os.path.join(HERE, "night_voices.tsv"), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        rid, voice, path, text = line.split("\t", 3)
        out[rid] = (voice, path, text)
    return out


def say(voice_id, settings, text, key):
    body = json.dumps({"text": text, "model_id": MODEL, "voice_settings": settings}).encode("utf-8")
    req = urllib.request.Request(API % voice_id, data=body, method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def main():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit("Set ELEVENLABS_API_KEY (with text_to_speech permission).")
    table = rows()
    ids = sys.argv[1:] or [r for r in table if not os.path.exists(os.path.join(OUT, table[r][1]))]
    for rid in ids:
        voice, path, text = table[rid]
        vid, fallback, settings = VOICES[voice]
        data = None
        for v in (vid, fallback):
            try:
                data = say(v, settings, text, key)
                break
            except Exception as e:  # noqa: BLE001 - the fallback voice, then report
                print("voice", v, "failed:", e)
        if data is None:
            print("FAILED", rid)
            continue
        dest = os.path.join(OUT, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(data)
        print(rid, voice, len(data))


if __name__ == "__main__":
    main()
