# SUNO: the camp's own music

The world's music (not the radio's) is one waltz: every song is a Suno Cover of one motif,
so they all share its melody, rhythm and harmony (the user 21. 10.: "a distinctive
signature like Papers, Please; not generic").

## The signature

A cheap home keyboard's waltz preset (oom-pah-pah) and a harmonium, D Hungarian minor
(D E F G# A Bb C#: the raised fourth is the camp's colour). By day it is a tycoon; by
night the same waltz slower, drifting flat, ending on E flat instead of D.

`python tools/audiogen/motif.py` renders the motif into `tools/audiogen/motif/` (not in
git): `motif_day.wav` (104 bpm, ends on D), `motif_night.wav` (72 bpm, drifts, ends on
E flat), and `*_horn.wav` (the same through the camp's loudspeaker on a pole).

## In Suno

1. Upload `motif_day.wav` or `motif_night.wav`, then **Cover**.
2. Audio Influence 70-85 % (keeps the melody and rhythm), Style Influence ~80 %,
   Weirdness 40-55 %.
3. Styles: the same opening for every song, only the end changes.

Exclude (always; `video game`, `soundtrack` and `rpg` are what pull it to generic fantasy):
```
orchestral, cinematic, fantasy, rpg, celtic, flute, harp, strings, choir, epic, ambient, video game, soundtrack, piano ballad, synthwave, chiptune, keygen, lo-fi hip hop, edm, vocals
```

| Cue | Motif | Styles |
|---|---|---|
| title | day | `casio home keyboard waltz preset, harmonium, hungarian minor, 3/4 waltz, oom-pah-pah, mono, dry, eastern bloc library music, hauntology, melodica lead, 96 bpm` |
| tycoon | day | `... mono, dry, musette, accordion lead, casio bass, busy, 112 bpm` |
| morning | day | `... mono, dry, music box lead, sleepy, 68 bpm` |
| golden | day | `... mono, dry, melodica lead, detuned upright piano, wistful, 90 bpm` |
| rain | day | `casio home keyboard waltz preset, harmonium, hungarian minor, 3/4 waltz, mono, dry, casio electric piano preset, muffled, indoors, 84 bpm` |
| nightstart | night | `casio home keyboard waltz preset, harmonium, hungarian minor, 3/4 waltz, mono, dry, rhythm preset only, harmonium drone, melody missing, 76 bpm` |
| night | night | `... mono, dry, dark cabaret, tape slowed down, detuned, wow and flutter, no drums, sparse, 60 bpm` |
| red | night | `... mono, dry, carousel waltz gone wrong, tape slowed, half-step flat, reversed` |

(`...` = `casio home keyboard waltz preset, harmonium, hungarian minor, 3/4 waltz, oom-pah-pah`.)

## Into the game

1. Download as `<cue>.mp3` (the names in the table: the director picks them by name).
2. Bring it to -18 dB mean, 128 kbps into `godot/assets/music/<cue>.mp3` (title: the menu).
3. `python tools/audiogen/music_sections.py <cue>`: bars, sections and where its own fade
   begins into `music_cues.json`. Without that row the song is not played.
4. Which song when, how a piece comes in (out of slow into its tempo) and winds down (like
   a carousel), co-op: `scripts/audio/music_director.gd`.
