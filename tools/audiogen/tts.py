#!/usr/bin/env python3
"""Voices for the office telephone (scripts/closeup/phone_book.gd) with the ElevenLabs
text-to-speech API.

    python tools/audiogen/tts.py              every line whose file is missing
    python tools/audiogen/tts.py <id> ...     these lines (regenerated)

Lines live in tools/audiogen/voices.tsv:  id <TAB> voice <TAB> text
`voice` is a name from VOICES below. The talking clock's numbers (h0-h23, m00-m59)
are added here, not in the TSV. Output: godot/assets/sfx/phone/voice/<id>.mp3 (the
phone bus in the game band-limits and roughens them, so they are generated clean).

The key comes from ELEVENLABS_API_KEY (it needs the text_to_speech permission; the
sound-effects key in tools/audiogen/.env does not have it). Never commit a key.
"""
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "sfx", "phone", "voice")
API = "https://api.elevenlabs.io/v1/text-to-speech/%s"
MODEL = "eleven_multilingual_v2"

# Premade ElevenLabs voices.
VOICES = {
    "novotny": "pqHfZKP75CvOlQylNhV4",    # Bill: old, gruff
    "vera": "pFZP5JQG7iQjIQuC4Bku",       # Lily
    "clerk": "XrExE9yKIg1WjnnlVkGX",      # Matilda
    "shop": "EXAVITQu4vr4xnYOxXFl",       # Sarah
    "pub": "IKne3meq5aSn9XLyUdCD",        # Charlie
    "police": "nPczCjzI2devNBz1zQrb",     # Brian
    "ambulance": "FGY2WhTYpPnrIDTdsKH5",  # Laura
    "faults": "cjVigY5qzO86Huf0OWal",     # Eric
    "recording": "onwK4e9ZLuTAKqWW03F9",  # Daniel: the recorded announcements
    "vet": "Xb7hH8MSUJpSbSDYk0k2",        # Alice
    "water": "iP95p4xoKVk53GoZ742B",      # Chris
    "operator": "XrExE9yKIg1WjnnlVkGX",   # Matilda again: the exchange's own voice
}

ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
TENS = {2: "twenty", 3: "thirty", 4: "forty", 5: "fifty"}


def words(n):
    if n < 20:
        return ONES[n]
    t, o = divmod(n, 10)
    return TENS[t] + ("" if o == 0 else "-" + ONES[o])


def rows():
    out = {}
    for line in open(os.path.join(HERE, "voices.tsv"), encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        rid, voice, text = line.split("\t", 2)
        out[rid] = (voice, text)
    for h in range(24):
        out["h%d" % h] = ("recording", words(h) + ",")
    for m in range(60):
        out["m%02d" % m] = ("recording", "hundred" if m == 0 else ("oh " + ONES[m] if m < 10 else words(m)))
    return out


def generate(rid, voice, text, key):
    body = json.dumps({
        "text": text,
        "model_id": MODEL,
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.75, "style": 0.2},
    }).encode("utf-8")
    req = urllib.request.Request(API % VOICES[voice] + "?output_format=mp3_22050_32", data=body, method="POST", headers={
        "xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, rid + ".mp3"), "wb") as f:
        f.write(data)
    print(rid, voice, len(data))


def main():
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit("Set ELEVENLABS_API_KEY (with text_to_speech permission).")
    table = rows()
    ids = sys.argv[1:] or [r for r in table if not os.path.exists(os.path.join(OUT, r + ".mp3"))]
    for rid in ids:
        voice, text = table[rid]
        try:
            generate(rid, voice, text, key)
        except Exception as e:  # noqa: BLE001 - report and go on with the rest
            print("FAILED", rid, e)


if __name__ == "__main__":
    main()
