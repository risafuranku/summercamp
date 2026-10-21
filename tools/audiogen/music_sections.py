"""The world music's map (godot/assets/music/*.mp3 -> music_cues.json), read by
scripts/audio/music_director.gd: each song's beat, bars (3/4 or 4/4, found from where the
low end hits), its sections (where it changes: a cue may come in there) with how loud each
is, and where its own fade-out begins (the music is wound down before it).

    python tools/audiogen/music_sections.py
"""
import json
import os
import subprocess
import sys

import imageio_ffmpeg
import librosa
import numpy as np

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "godot", "assets", "music")
SR = 22050
FF = imageio_ffmpeg.get_ffmpeg_exe()


def load(path):
	pcm = subprocess.run([FF, "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(pcm, np.float32)


def analyse(path):
	y = load(path)
	length = len(y) / SR
	tempo, beats = librosa.beat.beat_track(y=y, sr=SR, units="time")
	tempo = float(np.atleast_1d(tempo)[0])
	beats = np.asarray(beats)
	# The bar: which beat is the one (the low end hits hardest there), in threes or fours.
	S = np.abs(librosa.stft(y, n_fft=2048, hop_length=512))
	fr = librosa.fft_frequencies(sr=SR, n_fft=2048)
	low = librosa.onset.onset_strength(S=librosa.amplitude_to_db(S[fr < 160]), sr=SR)
	bf = librosa.time_to_frames(beats, sr=SR)
	hit = np.array([low[max(0, f - 2):f + 3].max() for f in bf])
	best = None
	for meter in (3, 4):
		means = [hit[p::meter].mean() for p in range(meter)]
		contrast = max(means) / (np.mean(means) + 1e-9)
		if best is None or contrast > best[0] * 1.04:
			best = (contrast, meter, int(np.argmax(means)))
	_, meter, phase = best
	bars = beats[phase::meter]
	# Each bar's loudness, in dB under the song's loudest.
	rms = librosa.feature.rms(y=y, hop_length=512)[0]
	rf = librosa.time_to_frames(bars, sr=SR, hop_length=512)
	bar_db = []
	for i in range(len(rf)):
		seg = rms[rf[i]:rf[i + 1] if i + 1 < len(rf) else len(rms)]
		bar_db.append(float(20 * np.log10(seg.mean() + 1e-6)) if len(seg) else -80.0)
	bar_db = np.array(bar_db)
	top = np.percentile(bar_db, 95)
	# Sections: where the bars' sound changes (chroma and timbre, clustered in time).
	chroma = librosa.feature.chroma_cqt(y=y, sr=SR)
	mfcc = librosa.feature.mfcc(y=y, sr=SR, n_mfcc=13)
	bfr = librosa.time_to_frames(bars, sr=SR)
	F = np.vstack([librosa.util.sync(chroma, bfr), librosa.util.normalize(librosa.util.sync(mfcc, bfr), axis=1)])
	k = max(3, int(round(length / 28.0)))
	bounds = librosa.segment.agglomerative(F, k)
	starts = sorted(set(int(b) - 1 for b in bounds if 0 < b <= len(bars)) | {0})
	sections = []
	for j, s in enumerate(starts):
		e = starts[j + 1] if j + 1 < len(starts) else len(bars)
		level = float(np.mean(bar_db[s:e])) - top if e > s else -60.0
		sections.append({"t": round(float(bars[s]), 3), "bar": s, "db": round(level, 1)})
	# Where its own fade-out begins: the last bar still near the song's level.
	median = np.median(bar_db)
	alive = np.where(bar_db > median - 9.0)[0]
	end = float(bars[alive[-1]]) if len(alive) else length
	bar_len = float(np.median(np.diff(bars))) if len(bars) > 1 else 60.0 / tempo * meter
	return {
		"length": round(length, 3),
		"bpm": round(60.0 * meter / bar_len, 2),
		"meter": meter,
		"bar": round(bar_len, 4),
		"bars": [round(float(t), 3) for t in bars],
		"sections": sections,
		"end": round(end, 3),
	}


def main():
	out = {}
	names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(ROOT) if f.endswith(".mp3"))
	for name in names:
		cue = analyse(os.path.join(ROOT, name + ".mp3"))
		out[name] = cue
		print("%-11s %3.0f s  %d/4  %.1f bpm  %d bars  %d sections  end %.1f" % (
			name, cue["length"], cue["meter"], cue["bpm"], len(cue["bars"]), len(cue["sections"]), cue["end"]))
		print("            " + "  ".join("%.0f(%+.0f)" % (s["t"], s["db"]) for s in cue["sections"]))
	path = os.path.join(ROOT, "music_cues.json")
	old = {}
	if sys.argv[1:] and os.path.exists(path):
		old = json.load(open(path, encoding="utf-8"))
	old.update(out)
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		json.dump(old, f, indent="\t")
		f.write("\n")


if __name__ == "__main__":
	main()
