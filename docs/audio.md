# Sound

Buses, 3D sound, the mixer and the sounds' own rules.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **Music and effects are two channels** (`scripts/audio/mixer.gd`, buses "Music" and "Sfx" into
  Master; UNDO.games' bar sets them apart). A bus the game makes is sent on by its name: the
  songs' buses are listed in `MIXER.MUSIC_BUSES`, every other bus is effects; a player left on
  Master is effects. Music on a player of its own: `bus = MIXER.MUSIC`.

- **A SubViewport hears no 3D sound unless `audio_listener_enable_3d` is on** (Godot's
  default is off). The camp's (main.tscn) had it off until 21. 10.: every
  AudioStreamPlayer3D in the camp (the enemies, world_sounds, the radio outside, the
  co-op voices) was silent and nobody could tell from the code. A new viewport with 3D
  sounds turns it on (the office room's only while it is open, else its sounds play
  outdoors); a sound heard through a building's walls goes on `world_sounds.wall_bus(...)`
  (a low-pass bus; the 3D player's own filter only works with distance).

- **Footstep pitch modulation must stay subtle** (whoosh artifact otherwise).

- **A 3D sound at the player's ear**: 0.3 m off with `unit_size` 3 it gets +20 dB and every
  one hits `max_db` (+3) alike; set its `unit_size` to the distance it is at
  (`_near_you` in the Silent Man and the Girl) and the gain written is what plays.

- **Paper sounds:** `rooms/task_litter.mp3` is a bag of empty bottles, for clearing a room. A sheet is `desk/paper_pick`, `desk/paper_slide`, a key `desk/keys`, `desk/key_hang`.
