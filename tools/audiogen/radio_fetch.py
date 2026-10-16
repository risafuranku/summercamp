#!/usr/bin/env python3
"""Raw sources for the radio going wrong (tools/audiogen/radio_lines.tsv) from ElevenLabs.

    python tools/audiogen/radio_fetch.py            every row whose raw file is missing
    python tools/audiogen/radio_fetch.py <id> ...   these rows (fetched again)

`tts` rows go through text to speech (the key needs the text_to_speech permission),
`sfx` rows through sound generation. Files land in tools/audiogen/raw_radio/<id>.mp3
(gitignored): clean sources. tools/gen_radio_dread.py then ruins them for the game.

Keys: ELEVENLABS_TTS_KEY for speech, ELEVENLABS_API_KEY (or tools/audiogen/.env) for
sound effects. Never commit a key.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw_radio")
TTS_API = "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128"
SFX_API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"
MODEL = "eleven_multilingual_v2"

# Premade ElevenLabs voices, read flat: a numbers station does not act.
VOICES = {
    "operator": ("nPczCjzI2devNBz1zQrb", 0.9),  # Brian: deep, tired
    "other": ("pqHfZKP75CvOlQylNhV4", 0.75),    # Bill: old, the second man in the room
    "woman": ("XrExE9yKIg1WjnnlVkGX", 0.9),     # Matilda: the cold reader
}


def env_key(name):
    key = os.environ.get(name, "").strip()
    if key:
        return key
    env = os.path.join(HERE, ".env")
    if name == "ELEVENLABS_API_KEY" and os.path.exists(env):
        for line in open(env, encoding="utf-8"):
            if line.startswith("ELEVENLABS_API_KEY="):
                return line.split("=", 1)[1].strip()
    return ""


def rows():
    out = {}
    for line in open(os.path.join(HERE, "radio_lines.tsv"), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        rid, kind, arg, text = line.split("\t", 3)
        out[rid] = (kind, arg, text)
    return out


def post(url, body, key):
    req = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"), method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=180) as resp:
        return resp.read()


def fetch(rid, kind, arg, text):
    if kind == "tts":
        key = env_key("ELEVENLABS_TTS_KEY")
        if not key:
            sys.exit("No text-to-speech key: set ELEVENLABS_TTS_KEY")
        voice, stability = VOICES[arg]
        data = post(TTS_API % voice, {
            "text": text,
            "model_id": MODEL,
            "language_code": "cs",
            "voice_settings": {"stability": stability, "similarity_boost": 0.7, "style": 0.0, "speed": 0.85},
        }, key)
    else:
        key = env_key("ELEVENLABS_API_KEY")
        if not key:
            sys.exit("No sound-effects key: set ELEVENLABS_API_KEY or write tools/audiogen/.env")
        data = post(SFX_API, {"text": text, "duration_seconds": float(arg), "prompt_influence": 0.6}, key)
    os.makedirs(RAW, exist_ok=True)
    with open(os.path.join(RAW, rid + ".mp3"), "wb") as f:
        f.write(data)
    print(rid, len(data), "bytes")


def main():
    table = rows()
    ids = sys.argv[1:]
    if not ids:
        ids = [r for r in table if not os.path.exists(os.path.join(RAW, r + ".mp3"))]
    for rid in ids:
        if rid not in table:
            sys.exit("unknown id: " + rid)
        try:
            fetch(rid, *table[rid])
        except urllib.error.HTTPError as e:
            print(rid, "FAILED", e.code, e.read()[:300])


if __name__ == "__main__":
    main()
