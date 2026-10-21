"""The camp's motif: one waltz the whole soundtrack is made from (uploaded to Suno as the
source of every Cover, so every cue shares its melody, rhythm and harmony).

A cheap home keyboard's waltz preset (oom-pah-pah), a harmonium for the chords, D
Hungarian minor (D E F G# A Bb C#: the raised fourth is the camp's colour). The day
version resolves on D; the night version is slower, drifts flat and ends on E flat.

    python tools/audiogen/motif.py            -> tools/audiogen/motif/*.wav
"""
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "motif")

# (midi note, beats) per bar; 3/4.
MELODY = [
	[(69, 2), (70, 1)], [(69, 1), (68, 1), (65, 1)], [(64, 2), (65, 1)], [(62, 3)],
	[(65, 2), (68, 1)], [(69, 1), (70, 1), (73, 1)], [(74, 2), (73, 1)], [(70, 1), (69, 2)],
	[(69, 2), (70, 1)], [(69, 1), (68, 1), (65, 1)], [(64, 1), (65, 1), (64, 1)], [(62, 3)],
	[(65, 2), (68, 1)], [(69, 1), (70, 1), (73, 1)], [(70, 1), (69, 1), (68, 1)], [(62, 3)],
]
CHORDS = {
	"Dm": [50, 53, 57], "E7": [52, 56, 59, 62], "Bb": [46, 50, 53], "A7": [45, 49, 52, 55],
}
PROGRESSION = ["Dm", "E7", "Bb", "Dm", "Dm", "A7", "Dm", "A7",
	"Dm", "E7", "Bb", "Dm", "Dm", "A7", "E7", "Dm"]


def hz(m, cents=0.0):
	return 440.0 * 2 ** ((m - 69 + cents / 100.0) / 12.0)


def env(n, a=0.004, d=0.18, s=0.55, r=0.05):
	t = np.arange(n) / SR
	e = np.minimum(t / a, 1.0) * (s + (1 - s) * np.exp(-t / d))
	rel = int(r * SR)
	if n > rel:
		e[-rel:] *= np.linspace(1, 0, rel)
	return e


def pulse(f, n, duty=0.25, vib=0.0):
	t = np.arange(n) / SR
	ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.35, 0, 1)) / SR)
	return np.where((ph % 1.0) < duty, 1.0, -1.0)


def saw(f, n):
	ph = np.cumsum(np.full(n, f) / SR)
	return 2 * (ph % 1.0) - 1


def lp(x, hz_, order=2):
	return sosfilt(butter(order, hz_, "low", fs=SR, output="sos"), x)


def bp(x, lo, hi):
	return sosfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x)


def render(bpm, end_note, drift_cents, hats, reps, name):
	beat = 60.0 / bpm
	bars = len(MELODY)
	total = int(bars * 3 * beat * SR * reps) + SR
	out = np.zeros(total)
	for r in range(reps):
		for b in range(bars):
			t0 = (r * bars + b) * 3 * beat
			# Drifting flat over the whole take (the night's tape slowing).
			prog = (r * bars + b) / float(bars * reps)
			cents = -drift_cents * prog
			# Melody.
			pos = t0
			for i, (note, beats) in enumerate(MELODY[b]):
				if b == bars - 1 and r == reps - 1 and i == len(MELODY[b]) - 1:
					note = end_note
				n = int(beats * beat * SR * 0.92)
				s = int(pos * SR)
				out[s:s + n] += 0.32 * lp(pulse(hz(note, cents), n, 0.25, 0.006), 3800) * env(n)
				pos += beats * beat
			# Oom (bass on 1), pah-pah (harmonium on 2 and 3).
			ch = CHORDS[PROGRESSION[b]]
			n = int(beat * SR * 0.8)
			s = int(t0 * SR)
			bass = sum(saw(hz(ch[0] - 12, cents), n) for _ in [0])
			out[s:s + n] += 0.30 * lp(bass, 600) * env(n, d=0.25, s=0.3)
			for k in (1, 2):
				s = int((t0 + k * beat) * SR)
				n2 = int(beat * SR * 0.55)
				h = sum(saw(hz(m, cents + dt), n2) for m in ch for dt in (-6, 6))
				out[s:s + n2] += 0.06 * lp(h, 1800) * env(n2, a=0.02, d=0.3, s=0.6)
			# The preset's drums: a thud on 1, a tick on 2 and 3.
			n = int(0.12 * SR)
			s = int(t0 * SR)
			tt = np.arange(n) / SR
			out[s:s + n] += 0.5 * np.sin(2 * np.pi * (60 + 90 * np.exp(-tt * 40)) * tt) * np.exp(-tt * 28)
			if hats:
				for k in (1, 2):
					s = int((t0 + k * beat) * SR)
					n = int(0.04 * SR)
					out[s:s + n] += 0.12 * bp(np.random.randn(n), 6000, 11000) * np.exp(-np.arange(n) / SR * 90)
	out = np.tanh(out * 1.4) / np.tanh(1.4)
	out /= max(1e-6, np.max(np.abs(out))) / 0.89
	wavfile.write(os.path.join(OUT, name + ".wav"), SR, (out * 32767).astype(np.int16))
	# The same through the camp's loudspeaker (a horn on a pole).
	horn = np.tanh(bp(out, 350, 3600) * 2.2)
	horn /= max(1e-6, np.max(np.abs(horn))) / 0.89
	wavfile.write(os.path.join(OUT, name + "_horn.wav"), SR, (horn * 32767).astype(np.int16))


if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	np.random.seed(7)
	render(104, 62, 0.0, True, 2, "motif_day")
	render(72, 63, 45.0, False, 2, "motif_night")
	print("written", OUT)
