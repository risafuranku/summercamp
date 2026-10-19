#!/usr/bin/env python3
"""Bring generated sounds to one loudness, so the volumes in the code mean the same for all.

    python tools/audiogen/normalize.py <file or glob relative to godot/> [...] [--lufs -23] [--tp -2]

ElevenLabs hands back each sound as loud as it likes (one -4 LUFS and clipping, the next
-37): played at the same volume_db they were ear-splitting next to inaudible. This runs
ffmpeg's EBU R128 loudnorm (two passes: measure, then correct linearly) to an integrated
loudness (default -23 LUFS) and a true-peak ceiling (default -2 dBTP), and writes the file
back in place (mp3 stays mp3, wav wav). Then re-import in Godot (`--import`).
"""
import glob
import json
import os
import re
import subprocess
import sys

import imageio_ffmpeg

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
FF = imageio_ffmpeg.get_ffmpeg_exe()


def measure(path, lufs, tp):
	r = subprocess.run([FF, "-hide_banner", "-nostats", "-i", path, "-af",
		"loudnorm=I=%s:TP=%s:LRA=11:print_format=json" % (lufs, tp), "-f", "null", "-"],
		capture_output=True, text=True)
	m = re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S)
	return json.loads(m.group(0)) if m else None


def normalize(path, lufs, tp):
	m = measure(path, lufs, tp)
	if m is None or m["input_i"] in ("-inf", "inf"):
		print("skip (silent?)", path)
		return
	af = ("loudnorm=I=%s:TP=%s:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:"
		"measured_thresh=%s:offset=%s:linear=true" % (lufs, tp, m["input_i"], m["input_tp"],
		m["input_lra"], m["input_thresh"], m["target_offset"]))
	ext = os.path.splitext(path)[1].lower()
	tmp = path + ".norm" + ext
	codec = ["-c:a", "libmp3lame", "-b:a", "128k"] if ext == ".mp3" else ["-c:a", "pcm_s16le"]
	subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", "-i", path, "-af", af,
		"-ar", "44100"] + codec + [tmp], check=True)
	os.replace(tmp, path)
	print("%-28s %6.1f LUFS -> %s" % (os.path.basename(path), float(m["input_i"]), lufs))


def main():
	args = sys.argv[1:]
	lufs, tp = "-23", "-2"
	if "--lufs" in args:
		i = args.index("--lufs")
		lufs = args[i + 1]
		del args[i:i + 2]
	if "--tp" in args:
		i = args.index("--tp")
		tp = args[i + 1]
		del args[i:i + 2]
	files = []
	for a in args:
		files += glob.glob(os.path.join(GODOT, a))
	for f in sorted(set(files)):
		normalize(f, lufs, tp)


if __name__ == "__main__":
	main()
