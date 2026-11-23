# Godot and the renderer

Engine, GDScript and rendering traps that cost time.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **List a res:// folder with `scripts/res_dir.gd`, never DirAccess** (`RES_DIR.files(dir, exts)`,
  `RES_DIR.names(dir)`): an exported game (Steam, web) has `song.mp3.import` and `x.tres.remap`
  in the folder, not the files, so a DirAccess listing found nothing (15. 11.: the web export's
  radio had no songs, the texture pack no pictures). user:// folders are real: DirAccess there.

- **`PROJECTION_MATRIX[1][1]` is negative in this renderer** (its clip space has y down).
  A shader that sizes something in pixels from it (`2 * depth / (P[1][1] * VIEWPORT_SIZE.y)`
  metres a pixel) must take `abs()`: without it the least width never held and wires drew
  as dashes (4. 11., `wire_ribbons.gd`, the bus's lamp dots).

- **`get_meta(key, null)` still prints an error when the key is missing** (a null default
  is no default): `x.get_meta(k) if x.has_meta(k) else null`.

- **A Label3D leaves out the pixel fonts' one-stroke glyphs** (the I, the dash, the bar: in
  Jersey and Silkscreen alike they are solid rectangles in the font's page and come out
  blank in 3D; 2D text draws them). Words on a 3D surface go through
  `scripts/bowling/board_text.gd`, out in the world `scripts/town/sign_text.gd` on it (a 2D Label in a small SubViewport, drawn again only when
  the words change, shown on a quad: the bowling's boards and the cellar machine's plate).

- **Nothing under the ground is drawn for a camera under the ground** (`retro_materials`'
  fragment: the lake mirror's cut, camera y < -0.4 and the pixel's y < 0.1 are discarded).
  A room of its own world goes over the ground, never under it (the bowling's cellar sits at
  `CELLAR_AT` y 60 over its hall: built at y -40 it came out black).

- **Inner classes can't call the outer script's static funcs** (they can read its consts).

- **The first scene is the studio splash** (`scenes/studio_splash.tscn`), not main.tscn:
  it loads main.tscn on a thread and changes to it (headless runs skip it at once). The
  engine boot image `assets/boot/undo_labs_boot.png` is its first frame: re-bake it
  (`tools/studio_splash_bake.gd -- --boot`) after changing the sign, wall or shader.

- **Physics ignores visibility**: hidden rooms' bodies still catch rays. Disable a hotspot's
  `collision_layer` when its thing is absent (the empty counter spot stood before the door).

- **Load textures outside draw callbacks**: a texture first `load()`ed inside a `_draw`
  or a `draw` signal handler renders plain white (setup billboard, Display preview).
  Load it when the node is built and draw the cached one.

- **One pixel throughout** (the user, 18. 10.: everything in game pixelated, at the same
  Build-engine resolution): people 128 px to 1.74 m (73.6 px/m; a pose's picture is
  processed to its height in metres times that: lying 0.62 m = 46 px), rooms and things
  in them 128 px to a 1.4 m tile (91 px/m: a sprite 0.26 m tall is 24 px, a sign
  0.38 m is 35). A picture finer than that gets shrunk to it (`service_interior._wall_decal`),
  never shown small at its full size.

- **Emission with a mask texture multiplies, it does not add**: StandardMaterial3D adds
  `emission_texture` to `emission` by default (a mask lit the bus windows white by day);
  set `emission_operator = EMISSION_OP_MULTIPLY`.

- **BoxMesh UVs are a 3 x 2 atlas**: one texture on a box shows a third of it per face;
  `uv1_scale` (3, 2) shows it once per face (`town_lesna._tiled`). Put art that must read
  whole (signs, facades, the bus's sides) on a QuadMesh.

- **GDScript names**: a method called `_set` overrides `Object._set` (parse error about the
  signature); a subclass may not re-declare its base's constants (`SFX_OPEN` in closeup_view).

- **Two faces on the same corners cancel**: a double-sided triangle through `generate_normals()` without `st.set_smooth_group(-1)` has zero normals, no light reaches it and it stands in the sky's colour (every gable did).

- **Frames are not the physics' 60** (`GameSettings.frame_cap`: a whole share of the screen's
  refresh, 72 at 144 Hz, 60 at 60 Hz, never over 100; `run/max_fps` only holds till the settings
  load): anything moved in `_physics_process` judders whenever it moves (a step missed or
  doubled every few frames). The player's head is drawn in
  `_process` between the last two physics positions (`Engine.get_physics_interpolation_fraction`);
  a new camera that follows a physics body must do the same.

- **The palette bends the dark**: `build_palette_lut.png` has no neutral ramp low down, a dark grey comes out plum and an orange light on grey comes out red. Mix what must stay grey toward blue (`cloud_layers.NIGHT_CLOUD`) and a warm light toward amber, `(1, .72, .42)` (a lookup in Python, sqrt space, shows it before a run does).

- **A new PNG is not there until imported**: `ResourceLoader.exists` is false for a picture
  with no `.import` in a run that is not the editor. Run `godot --headless --path godot --import`
  after adding art, before a shot run.

- **Faces, signs and boards on walls fight them** under the PS1 vertex snap (the snap moves
  the corners of a quad and the wall under it a different way; a centimetre between them
  is not enough). `retro_materials.gd` pulls every QuadMesh / PlaneMesh and every thin
  BoxMesh (under 6 cm) towards the eye along its own ray (`depth_pull`, a plain uniform on
  a material of their own: smaller quads more, so a sign wins over the face under it;
  never an `instance uniform` in that shader: every instance drawn with it takes a slot,
  they run out and the game crashed); keep new ones as such meshes and they are handled.
  The sun's shadow pass (an orthographic projection) gets neither the snap nor the pull,
  and the light and shadows are worked out at the true point under each pixel
  (`LIGHT_VERTEX` on the face's plane), so the faces warp and their shadows do not.
  Lettering (Label3D) is not redrawn by it: `retro_materials._pull_labels` puts every
  Label3D 1.1 % of its distance nearer its eye each frame (the board under it is pulled, the
  number was under its enamel). A thing that must stay over a pulled quad takes the meta
  `retro_pull` (a window's bar: building_models.WINDOW_BAR_PULL).

- **A spring stepped by the frame must hold at any frame time** (playtest 25. 10.: in the
  caravan "the view flies everywhere with the mouse"): `interior_look`'s sway was a stiff
  spring (w 16) stepped by Euler, unstable over 52 ms a frame, and the caravan's windows
  took the frame there. Step a stiff spring by its exact solution (interior_look) or clamp
  what it moves; check `4 - k dt^2 - 2 c dt > 0` at 0.1 s for a semi-implicit one.

- **D3D12 resource descriptors** (`rendering_device/d3d12/max_resource_descriptors`, raised
  to 524288 on 25. 10.): the default 65536 ran out after a long session; every draw past it
  failed (black screen in the busy directions) and the log took hundreds of errors a frame.

- **Label3D is unlit by default**: paint on a board or a wall needs `shaded = true`, or its
  letters shine on the air at night with the board gone dark (4. 11.: the sluice's board,
  the buildings' signs). Lit signs (the bus's boards) stay unshaded.

- **Springs in `_process`**: a long frame's delta thrown at an explicit spring multiplies its
  speed; step it in hundredths and cap the time (`player_controller._update_head_motion`).
  A fast clock (`Engine.time_scale`) finds these: the head's speeds ran off to infinity and
  the whole view went NaN (`tools/soak_check`).

- **First-time loads**: what is built the first time costs its pictures and sounds from
  disk, not the building (the land 265-947 ms cold, 25 ms warm). Read them on the loader's
  threads while something else is on screen (`builder/warmup.gd`, `town/land_warmup.gd`).

- **A painted front (`_painted`) is `retro_text`:** it neither swims nor snaps, or its painted frames lean away from the real panes.

- **`_camp()` is triplanar, two metres a repeat:** a picture meant whole (a door) on a box shows a slice of it, its handle off the leaf. Give the leaf a `_side_quad` face, as the caravan and the cabins have (`DoorFace`, door_anim hangs it with the leaf).
