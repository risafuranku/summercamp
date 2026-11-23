# The web demo (UNDO.games)

The Godot web export, its page and its hosting.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## The web demo (UNDO.games, TODO.md WEB DEMO)

The demo runs in a browser on undogames.cz (computers only for now). Godot's Web preset
(nothreads, feature `demo`, Compatibility renderer: WebGL 2), its page `web/shell.src.html`.
- `node tools/web/export.mjs [--release]`: composes the page (`godot/.web_shell.html`, ignored),
  exports to `build/web` (ignored), copies the page's pictures and the splash, brotli. `--release`
  adds the UNDO lock (runs only inside the catalogue). `--shell-only` redoes the page alone.
- `node tools/web/qa.mjs --out=DIR --seconds=N --shots=a,b --do="t:click:x,y;t:type:text;t:key:Enter"`:
  the export in a muted headless Chromium (console, shots, fps; `--gl` times each shader program's
  link, `--capture=FILE` keeps their sources, `--angle=vulkan` boots fast for play tests, `--profile=DIR`
  a browser profile kept between runs; storage is per port). Headless shots draw the canvas over
  the page's curtain: look at the page itself in a real browser.
- The engine has one thread there. While it downloads, boots and the browser translates its
  shaders, the page plays the studio splash as a recording (`web/splash.webm`, made by
  `res://tools/splash_movie.tscn` with `--write-movie`) and then the title card with the boot's
  bar, moved by CSS (`scripts/web/page.gd`: `PAGE.step` from main's boot steps, `PAGE.ready` once
  the title has drawn). On the web studio_splash goes straight to main.
- Windows browsers translate every Godot shader program through D3D: 0.5-2 s each, ~470 to the
  title. `web/gl-skip.js` gives the variants Godot translates and never draws an empty program.
  Fewer shaders and material variants is what makes the web boot shorter.
- The shader programs ahead (16. 11., Richard: founding a camp was "the biggest lag in the world"):
  `web/shader-warm.js` compiles the game's programs in the browser's threads (KHR_parallel_shader_compile)
  in a context with exactly Godot's attributes and extensions (else the cache misses), from the list recorded
  by `node tools/web/record-shaders.mjs` (qa.mjs --capture through the warden, NEW CAMP, the stamp and a walk;
  ANGLE on Vulkan, the same sources as D3D) into `build/web/shaders.json`; `tools/web/deploy.mjs` refuses
  without a fresh one and writes it in chunks of 48 (`assets/shaders.<hash>.<n>.json`) plus an index of prints
  (`.keys.json`). The browser keeps only so many compiled programs and drops the oldest: compiled hundreds
  ahead they were gone when the game asked, so with the game on the page the warm follows it (its links matched
  by print) and stays at most 48 programs ahead; a download ahead from the catalogue (kit `prepare`) compiles
  all for the disk cache. Measured (headless Chrome, D3D11, clean profile): to the title 100 -> 70 s, the first
  two minutes after the stamp 139 s of stalls -> 29 s. Windows Firefox has no parallel compile: nothing ahead.
- UNDO.games: `scripts/web/undo_hub.gd` (GameSettings' child "Undo", web only) over
  `web/undo-bridge.js`: the bar's music and effects volumes onto `scripts/audio/mixer.gd`, the time
  played (`set_playing`), a hidden page pauses (a lost focus does not: a click on the hub's bar).
- Sound on the web plays through Godot's mixer (`audio/general/default_playback_type.web=0`):
  the buses' effects work and the songs are not decoded whole. The mixer runs on the engine's one thread, so a
  long frame is a gap in the sound (the user 16. 11.: "it stutters like hell"): `audio/driver/output_latency.web`
  is 100 ms, and the long tracks play in the browser instead. `web/long-tracks.json` lists them (the insects,
  the day's ambience, the pipes, the lake, wind, storm, the camp's music and the menu's theme): `tools/web/export.mjs`
  keeps them out of the Web preset (it writes them into its `exclude_filter`) and serves them as
  `assets/audio/<name>-<print>.mp3`, mapped in the page as `window.__ccAudio`; pack 299 -> 181 MB.
  `scripts/audio/long_player.gd` (an AudioStreamPlayer playing a silent stream) is made by
  `LongPlayer.make(path, loop)` where the page serves the track (`audio_manager._create_sfx_player`,
  `music_director`, main's menu theme, the sewer game's pipes) and follows the silent player each frame into
  `web/stream-audio.js` (an <audio> element through a low-pass and a gain): started, stopped, moved, its
  volume and low-pass worked out down the bus chain to Master like the mixer (other bus effects are not
  followed), `pitch_scale` as the playback rate with the pitch, the tree paused pauses it, a song's end is its
  `finished`. Off the web, or for a track the page does not serve, the caller makes its usual player. A track
  goes into the list only when every player of it goes through `make` (else it is silent on the web).
  QA: `window.__ccStream.debug()` in the page. Parts for UNDO.games (kit 3): the base, Music, Weather and
  ambience (the long tracks; streamed while not kept).
