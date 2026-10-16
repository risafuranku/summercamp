#!/usr/bin/env python3
"""The back room's sounds, synthesised like tools/gen_sfx.py (22050 Hz / 16-bit mono).

    python tools/gen_room_sfx.py   -> godot/assets/sfx/backroom/*.wav

  alarm.wav        the clock radio's alarm: four short 2.7 kHz beeps and a pause (loop)
  clock_tick.wav   a cheap quartz movement's tick in a quiet room, 1 s (loop)
  tv_hiss.wav      a small black-and-white set between stations: hiss and line hum (loop)
  tv_tone.wav      the 1 kHz tone under the test card after close-down (loop)
  tv_on.wav        the set switched on: the click, the tube's whine rising, static
  tv_off.wav       switched off: a click and the picture collapsing to a dot
  lamp_click.wav   a bedside lamp's rocker switch
  bed_creak.wav    old bed springs taking someone's weight
  door_creak.wav   a light interior door on dry hinges
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "sfx", "backroom")
rng = np.random.default_rng(11)


def save(name, x):
    x = np.clip(x, -1.0, 1.0)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32000).astype(np.int16).tobytes())
    print(name, "%.2fs" % (len(x) / SR))


def t(sec):
    return np.arange(int(sec * SR)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def env(n, attack, release):
    e = np.ones(n)
    a, r = max(1, int(attack * SR)), max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def beep(freq, sec, amp):
    x = np.sign(np.sin(2 * np.pi * freq * t(sec))) * amp
    return lowpass(x, 5000) * env(len(x), 0.002, 0.004)


gap = np.zeros(int(0.07 * SR))
quad = np.concatenate([np.concatenate([beep(2700, 0.07, 0.35), gap]) for _ in range(4)])
save("alarm.wav", np.concatenate([quad, np.zeros(int(0.5 * SR))]))


def click(amp, decay, hz):
    n = int(0.03 * SR)
    k = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (decay * SR))
    k += np.sin(2 * np.pi * hz * t(0.03)) * np.exp(-np.arange(n) / (decay * 1.5 * SR))
    return amp * lowpass(k, 6000)


tick = np.zeros(int(1.0 * SR))
c = click(0.18, 0.0015, 3200)
tick[:len(c)] += c
c2 = click(0.11, 0.0015, 2600)
tick[int(0.5 * SR):int(0.5 * SR) + len(c2)] += c2
save("clock_tick.wav", tick)

n = int(3.0 * SR)
hiss = rng.normal(0, 0.09, n)
hiss = hiss - lowpass(hiss, 400)
hum = 0.03 * np.sin(2 * np.pi * 50 * t(3.0)) + 0.012 * np.sin(2 * np.pi * 15625 / 4 * t(3.0))
save("tv_hiss.wav", hiss + hum)
save("tv_tone.wav", 0.12 * np.sin(2 * np.pi * 1000 * t(2.0)))

on = np.concatenate([click(0.5, 0.004, 900), np.zeros(int(0.05 * SR))])
whine_t = t(1.2)
whine = 0.05 * np.sin(2 * np.pi * (6000 + 9000 * whine_t / 1.2) * whine_t) * env(len(whine_t), 0.3, 0.2)
stat = rng.normal(0, 0.12, len(whine_t)) * np.linspace(0, 1, len(whine_t)) ** 2
save("tv_on.wav", np.concatenate([on, whine + stat]))
off_t = t(0.5)
collapse = 0.08 * np.sin(2 * np.pi * (3000 - 2500 * off_t / 0.5) * off_t) * np.exp(-off_t * 6)
save("tv_off.wav", np.concatenate([click(0.5, 0.004, 700), collapse]))
save("lamp_click.wav", np.concatenate([click(0.45, 0.003, 1500), np.zeros(int(0.04 * SR)), click(0.2, 0.002, 2100), np.zeros(int(0.1 * SR))]))


def creak(sec, f0, f1, amp):
    tt = t(sec)
    f = f0 + (f1 - f0) * tt / sec
    phase = 2 * np.pi * np.cumsum(f) / SR
    # Stick-slip: a buzzy carrier gated by fast irregular pulses.
    gate = (np.sin(2 * np.pi * (35 + 25 * rng.random()) * tt) > 0.2).astype(float)
    x = np.sign(np.sin(phase)) * 0.5 + np.sin(phase * 2.01) * 0.3
    x = lowpass(x * gate, 2400) * env(len(tt), 0.05, 0.15)
    return amp * x


save("bed_creak.wav", np.concatenate([creak(0.45, 380, 300, 0.35), np.zeros(int(0.08 * SR)), creak(0.6, 320, 420, 0.28)]))
save("door_creak.wav", np.concatenate([creak(0.9, 520, 700, 0.3), creak(0.3, 700, 640, 0.18)]))
