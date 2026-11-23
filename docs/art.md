# Art, fonts and sound pipelines

Grok, the figures, fonts and audio generation.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Pipelines


- **People from eight sides** (DESIGN.md §10b): `tools/artgen/figure_prompts.py` writes
  `prompts_figures.tsv` (who everyone is, piece by piece: FIGURES; the idles; the poses
  from five sides; the family's new people BASES), `tools/artgen/figures.py batch <fig> turn
  walk1..5 run1..5 idle1 pose_<p>` runs Grok sheet after sheet (a variant more when one
  does not cut into the right number of figures), `figures.py all <fig>` stages, checks,
  draws the contact sheet (`out/fig_<fig>/_contact.png`, `_walk.gif`, `_run.gif`) and packs
  the atlas. What was learnt on the pilot (Pepa): one picture per view (a row of four
  frames), never one per frame; the reference is the front sprite x4 on magenta beside the
  picked turnaround (`figures.py ref`); ask for "a walk cycle" and Grok draws one stride
  four times: name each frame by its shape (STRIDE, PASSING standing on one leg with the
  other knee lifted, "this frame is narrower than frame 1", "each frame a clearly
  DIFFERENT pose"); the five views as "turned toward the right edge of the image" (2, 3,
  4) so 6-8 are mirrors; the frames are snapped to the colours of the person's own front
  sprite (nothing can drift) and scaled per sheet (the turnaround by its front figure, a
  walk by its tallest frame x0.985, a run x0.95); the magenta rim is taken off at Grok's
  size before shrinking (it came out as red flecks on the nose). Picks by eye go in
  `tools/artgen/figure_picks.json` (`mirror`, `order`, `k` per sheet). Never run two
  queues with the same ids, and never kill a `gen.sh` without its agent: a second agent
  at once swaps outputs, and a waiting copy of an id deletes the finished picture.
- **Generated art** — Grok Imagine through the Cursor agent CLI (`cursor-agent`, logged in
  with `cursor-agent login`; `gen.sh` finds it under `%LOCALAPPDATA%\cursor-agent` or takes
  `CURSOR_AGENT`; the bare `agent` command may be the Grok CLI on some PCs):
  `tools/artgen/gen.sh <id>` reads `tools/artgen/prompts.tsv` (id, aspect, reference image
  relative to `godot/` or `-`, prompt), writes `tools/artgen/out/<id>/raw.png` (gitignored).
  **One at a time**: parallel runs swap outputs. ~2-5 min per image; `tools/artgen/queue.sh <id>...`
  runs a list one after another. `tools/artgen/os_art.py` turns the OS/Builder/mail renders
  (ico2_*, oem2_splash, wall2_*, bld_*, tb2_*, spam_*) into game files. The tool supports 1:1,
  4:3, 3:4, 16:9, 9:16 only.
  Then `python tools/artgen/process.py <id> sprite <height> <dest>` (keys out flat magenta,
  box-downsamples, snaps to the game palette) or `texture <size> <dest>`.
  For sprites ask for a flat pure magenta `#FF00FF` background and pass an existing sprite
  as reference so pixel scale and palette match.
- **Building fronts and lettering** (Lesna): ask Grok for a flat orthographic elevation on
  magenta (`lib_*` rows), then `python tools/artgen/town_facades.py [id]`; signs are drawn,
  not generated (Grok cannot spell Czech): `python tools/artgen/lettering.py [name]` (Windows
  fonts for now, swap for OFL faces before a public release).
- **Batches**: `tools/artgen/batch.sh <id>...` (textures, 128 px) and
  `tools/artgen/batch_panels.sh <width> <id>...` (posters, views) generate and process one
  after another; never start a second batch while one runs. `crop_goods.py` crops the
  shop-goods renders (Grok puts the row at the bottom of a dark canvas).
- **The night sky and the moon**: `python tools/artgen/night_sky.py` turns the
  `sky_night_stars` render into `godot/assets/textury/skybox/skystars.png` (the clear
  night's panorama: the render mirrored round the sky, the stars taken out and set back
  as sharp pixels, each of the render's pixels 4 x 4 so the sky shader's linear filter
  keeps them hard) and `spr_moon` into `skybox/moon.png` (24 px).
  `python tools/artgen/light_sprites.py` turns a render of light on black (the lamp's
  cone) into a sprite of four warm shade steps for additive drawing, or of mist into four
  steps of see-through white. `night_sky.py dawn golden sunset bluehour` makes the
  morning's and the evening's panoramas (a glow on one side: east at dawn, west at night).
  `python tools/artgen/sky_fine.py` makes the ones the game takes first (`skyf_dawn`,
  `skyf_golden`, `skyf_sunset`, `skyf_blue`, the late `skyf_grey` and `skyf_greyeve`;
  rows in `prompts_sky.tsv`): two renders per sky, the glow side and the other, side by
  side round the sky (no mirror), seams blended, Grok's fuzzy 4-wide blocks taken out
  (down by area, up smooth, 160 colours): the 4 x 4 blow-up read as coarse blocks.
  `python tools/artgen/cloud_sprites.py` cuts the cloud layers' high streaks and low scud
  (`spr_clouds_high`, `spr_clouds_low` in `prompts_sky.tsv`) into `skybox/cloud_hi_*` and
  `cloud_lo_*` with soft edges (`scripts/ambient/cloud_layers.gd` draws them filtered);
  `cloud_sprites.py cover` makes the cloud deck's cover (`tex_cloud_cover`, `_b` in
  `prompts_deck.tsv`: satellite views straight down, brightness = thickness) into
  `skybox/cloud_cover_a/b.png`, tiling, ranked so `coverage` is the share of sky.
  `python tools/artgen/ground_tex.py <id> <dest> [size] [--own]` makes a ground render
  tile (Grok's "seamless" does not) and snaps it to the palette, or with `--own` to 48
  colours of its own (the palette has few mid greens). Agent B's world rows
  (the lit windows, the reception at night, the sky) are in `tools/artgen/prompts_world.tsv`.
- **Interior props (Blender)**: `tools/blender/build_props.py` (+ `props_more.py`, kit in
  `propkit.py`) builds every low-poly prop from parts and exports
  `godot/assets/models/interior/<name>.glb` **without images** plus `materials.json`
  (material name -> camp texture + tint). Run headless:
  `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/build_props.py [-- name ...]`,
  then `godot --headless --path godot --import`. `preview_props.py -- out.png` renders them all.
  Conventions: metres, origin on the floor at the footprint centre, front towards Blender
  -Y (Godot +Z). Wall-mounted props: mind that the origin is the footprint centre.
  The user's Blender (with the MCP addon on :9876) may have another project open: do not
  touch it, work headless.
- **Interior kit** (`godot/scripts/interior_kit.gd`): `surface(tex, metres)` = a camp
  texture mapped in world space (Build-style, seamless, nearest); `room()`, `slab()`,
  `skirting()`, `picture()` and `prop()` (instances a .glb and puts the shared camp
  materials back by name); `cut_wall(wall, holes)` and `cut_arch(wall, a0, a1, spring, top)`
  (a round-headed opening, the corners over it filled smooth: the chapel's door and arch). New interior work uses it instead of `texture_style` (the old
  colour-matched rips are left only on the cellar machine animation and a few small bits).
- **Fonts**: `python tools/gen_pixel_fonts.py` bakes `tools/font_src/*.ttf` into
  `godot/assets/fonts/*.fnt/.png` on their native grid. Import setting `scaling_mode=1`.
  Czech letters a font lacks (Silkscreen's č ř ě ď ť ň ů, all of W95FA's carons, its broken
  ý Ý) are put together there from the base letter and a mark (`compose_czech`).
- **Flags** (the WARDEN page's languages): `python tools/gen_flags.py`.
- **No synthesised SFX** (the user: "to nechcem", 20. 10.: replace them all): every sound is a
  recording (ElevenLabs, `tools/audiogen/`); exact timings are cut from recordings
  (`tools/audiogen/cuts.py`: the phone line's 425 Hz tone to its cadences, ring 1 s / 4 s,
  engaged 0.33 / 0.33, keys 0.13 s). The one exception is the radio's dread, layered in
  code on purpose (`tools/gen_radio_dread.py`, `scripts/radio/radio_dread.gd`).
- **Palette LUT**: `tools/gen_palette_lut.py`.

Licensing: most world textures are rips from Redneck Rampage (`assets/textury/redneck/RRTX*`).
Fine for a private prototype, a blocker for any public release; replace them with generated
textures (§7) before shipping.

## Traps

- **Grok poses of one character drift** (a cap, another shirt, older): name every piece
  of their clothes in the prompt, and look at each render. Background caught between
  legs or under an arm comes out darker magenta: `process.py` keys it; people then go
  through `tools/artgen/defringe.py --figure` (warden_b's red anorak: `--rows`).

- **Grok draws a station's top in perspective** (its front showing, black round it): the
  four corners of the top go in `tools/artgen/podniky_art.py` TEXTURES and the top is
  unwarped to 16:9; then the station's rects are moved onto the picture's things. Pieces
  that touch (a row of cards) are cut in even slices (EVEN_ROWS); things Grok drew beside a
  hand that the station has as its own sprites are cleared (CLEAR); a ring drawn round
  frames the station already has is cut away (INNER_ONLY). Each run of gen.sh may rewrite
  its raw.png a second time (the agent's own retouch): process again when it does.

- **A long thing beside a figure (Pepik's bicycle) needs room on Grok's sheet**: `figure_prompts.ROOMY` asks for it, but asked too hard the bicycle folds up (`fig_town_kid_walk3_2`); `figures.GAPS` cuts a sheet whose figures nearly touch. Look at every contact sheet: `check` passes what is wrong and fails what is fine.
