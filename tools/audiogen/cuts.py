#!/usr/bin/env python3
"""Cut recordings into the game's timed sounds (the user, 20. 10.: no sounds synthesised by
code; this only cuts, fades, resamples and mixes recordings).

    python tools/audiogen/cuts.py

The raw recordings are ElevenLabs takes in tools/audiogen/raw/ (rows *_raw in
prompts_world.tsv: `python tools/audiogen/gen.py ph_tone_raw ph_dtmf_raw un_pip_raw
room_tv_tone_raw`). From them, into godot/assets/sfx/:
  phone/dialtone    the exchange's tone, brought to 425 Hz, a seamless 2 s loop
  phone/ringback    one ring down the line: 1 s tone, 4 s quiet (the line's hiss under it)
  phone/busy        engaged: 0.33 s on, 0.33 s off (loop)
  phone/dead        the line gone after a hang-up: 0.17 s on, 0.53 s off (loop)
  phone/dtmf_<k>    a key: 0.13 s of the keypad beep, each key a little higher or lower
  uncanny/station_pip(5)   the time pip, a tenth of a second in a 1 s slot (every fifth 2 s)
  backroom/tv_tone  the set's tone after close-down, brought to 1 kHz, a seamless loop
then brings them to -23 LUFS (normalize.py; the keys, too short to measure, to the dial
tone's level).
"""
import glob
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
SFX = os.path.join(HERE, "..", "..", "godot", "assets", "sfx")
FF = imageio_ffmpeg.get_ffmpeg_exe()
SR = 44100
sys.path.insert(0, HERE)
import normalize  # noqa: E402


def load(path):
	raw = subprocess.run([FF, "-v", "quiet", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).copy()


def save(x, path):
	pcm = np.clip(x, -1.0, 1.0).astype(np.float32).tobytes()
	subprocess.run([FF, "-v", "quiet", "-y", "-f", "f32le", "-ac", "1", "-ar", str(SR), "-i", "-",
		"-codec:a", "libmp3lame", "-b:a", "128k", path], input=pcm, check=True)


def dominant(x):
	spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
	freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
	band = (freqs >= 60.0) & (freqs <= 8000.0)
	return float(freqs[band][np.argmax(spec[band])])


def resample(x, factor):
	"""`x` played `factor` times faster (pitch and speed together)."""
	n = int(len(x) / factor)
	return np.interp(np.arange(n) * factor, np.arange(len(x)), x).astype(np.float32)


def fade(x, a=0.004, r=0.004):
	x = x.copy()
	na, nr = int(a * SR), int(r * SR)
	x[:na] *= np.linspace(0.0, 1.0, na)
	x[-nr:] *= np.linspace(1.0, 0.0, nr)
	return x


def seg(x, start, dur):
	return x[int(start * SR):int((start + dur) * SR)].copy()


def loopable(x, xfade=0.03):
	"""A seamless loop: the tail crossfaded into the head."""
	n = int(xfade * SR)
	t = np.linspace(0.0, 1.0, n)
	return np.concatenate([x[n:-n], x[-n:] * (1.0 - t) + x[:n] * t]).astype(np.float32)


def bed(hiss, n, gain):
	"""The line's hiss for `n` samples."""
	return (np.tile(hiss, int(np.ceil(n / len(hiss))) + 1)[:n] * gain).astype(np.float32)


def with_quiet(on, quiet_s, hiss):
	x = np.concatenate([on, np.zeros(int(quiet_s * SR), np.float32)])
	return x + bed(hiss, len(x), 0.25)


def out(rel):
	return os.path.join(SFX, rel)


def main():
	tone = load(os.path.join(RAW, "tone425.mp3"))
	hz = dominant(seg(tone, 0.5, 2.0))
	tone = resample(tone, 425.0 / hz)
	tone /= max(1e-6, np.abs(seg(tone, 0.5, 2.0)).max()) / 0.5
	hiss = load(out("phone/line_hiss.mp3"))
	hiss /= max(1e-6, np.sqrt(np.mean(hiss ** 2))) / 0.05
	save(loopable(seg(tone, 0.6, 2.06)), out("phone/dialtone.mp3"))
	save(with_quiet(fade(seg(tone, 0.8, 1.0), 0.006, 0.006), 4.0, hiss), out("phone/ringback.mp3"))
	save(with_quiet(fade(seg(tone, 1.0, 0.33), 0.005, 0.005), 0.33, hiss), out("phone/busy.mp3"))
	save(with_quiet(fade(seg(tone, 1.4, 0.17), 0.005, 0.005), 0.53, hiss), out("phone/dead.mp3"))
	beep = load(os.path.join(RAW, "dtmf.mp3"))
	env = np.array([np.sqrt(np.mean(beep[i:i + 441] ** 2)) for i in range(0, len(beep) - 441, 441)])
	core = seg(beep, max(0.0, int(np.argmax(env > env.max() * 0.5)) * 0.01 + 0.03), 0.2)
	keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "star", "0", "hash"]
	for i, k in enumerate(keys):
		save(fade(seg(resample(core, 0.88 + 0.025 * i), 0.0, 0.13), 0.004, 0.006), out("phone/dtmf_%s.mp3" % k))
	pip = fade(seg(load(os.path.join(RAW, "pip.mp3")), 0.05, 0.10), 0.004, 0.008)
	save(np.concatenate([pip, np.zeros(int(0.90 * SR), np.float32)]), out("uncanny/station_pip.mp3"))
	save(np.concatenate([pip, np.zeros(int(1.90 * SR), np.float32)]), out("uncanny/station_pip5.mp3"))
	tv = load(os.path.join(RAW, "tv_tone.mp3"))
	tv = resample(tv, 1000.0 / dominant(tv))
	save(loopable(seg(tv, 0.2, min(4.0, len(tv) / SR - 0.4))), out("backroom/tv_tone.mp3"))
	for rel in ["phone/dialtone.mp3", "phone/ringback.mp3", "phone/busy.mp3", "phone/dead.mp3",
			"uncanny/station_pip.mp3", "uncanny/station_pip5.mp3", "backroom/tv_tone.mp3"]:
		normalize.normalize(out(rel), -23, -2)
	ref = load(out("phone/dialtone.mp3"))
	level = np.sqrt(np.mean(ref ** 2))
	for f in sorted(glob.glob(out("phone/dtmf_*.mp3"))):
		x = load(f)
		save(x * (level / max(1e-6, np.sqrt(np.mean(x ** 2)))), f)
	print("cut from a %.0f Hz recording; then: godot --headless --path godot --import" % hz)


if __name__ == "__main__":
	main()
