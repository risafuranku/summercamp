# The office PC: Okna 98 and Builder

The camp computer, its programs and Builder 98.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **The camp computer is a panel, not a desktop** (playtest 19. 10.): one program on the
  screen at a time, all kept running; tabs by keys 1-9 (read by `physical_keycode`, a
  Czech keyboard types +ěšč on that row). A program's own keys must not use the digits,
  S (stands you up), A or D (they turn you between the monitors): Builder pans with the arrows, its tools are B/P/L,
  its catalogues F1-F5, O the overlay. A method called `hidden()` clashes with
  CanvasItem's signal: the panel calls `page_hidden()` / `shown()`.

- **The OS's own words are a real 1998 system's**: it never addresses the player, jokes
  about the story or knows Vera ("do not tell Vera" was rejected). The lore goes in the
  data: file dates and contents, the games' high-score names, the mails, the web, the
  programs' publishers' texts.

- **Message boxes are modal**: a catcher under them rings and flashes the dialog on a click
  elsewhere; while one is up the tab keys do nothing (`has_dialog()`).

- **Demolish takes any box up to 64x64** and charges per tile it clears (trees, corn, a
  building's footprint), not per tile of the box; the Builder's tag reads the same numbers
  from `builder_authority.summarize_demolish(rect)`. Build rejections print as
  `SHOT DRIVER build rejected`.

- **Paths go down on release**: the Builder's path tool drags an L-shaped line (Shift keeps
  it straight) and sends the whole line when the button is let go (`_end_path_drag`);
  the confirmations of that batch (`_path_batch`) give one sound and one price, a co-op
  client's arriving later.

- **The OS boot takes ~7 s** (warm-up, BIOS, maker's screen, Okna; a key or click hurries
  each): harness waits must be longer than that, and a test that skips itself when an app
  does not open must fail.

- **The monitor glass bends the picture**: `CRT_CURVE` in `building_interior.gd` must match
  `curve` in `crt_glass.gdshader` and `crt_sharp.gdshader`; `_map_mouse_to_crt` runs the
  same barrel, so clicks land where the OS draws.

- **Builder's building pictures come from the models**: change a model in
  `building_models.gd`/`building_manager.gd` and its four pictures must be drawn again
  (`tools/iso_render.tscn`, then `iso_views.py cut`/`raw`); never mirror one to make
  another side (a mirrored front put the pub's door where the camp has a wall). Bit 19 of
  the render layers is the glass layer (every window in the camp): the render uses bit 18.
  The render turns the retro shader's vertex snap off (`iso_render._unsnap`): at 150 lines
  on its 768 px a thin part (a flagpole's pole, the gnome's coat, a lamp's post) folded to
  nothing from one corner, and Grok repainted the hole.

- **The god cursor hides what it has still to bring down** (`visible` off, the body's
  collision layer 0, a shadow on the ground) until it lands: code that reads a building's
  visibility must expect it; `finish_all()` brings all of it down at once.

- **Builder runs behind the other programs**: its map is `is_visible_in_tree()` while the
  PC shows something else, or nothing (the startup view): "the warden is building now" is
  that and `building_interior.is_crt_view_active()` (`god_cursor._staged`).

- **Two monitors, one picture** (21. 10.): with the second monitor the CRT viewport is two
  screens wide (1280 x 480); the shell stays a 640 x 480 Control at the left (no
  FULL_RECT: it would stretch) with `clip_contents` off, the second screen's pages sit at
  x 640, and each tube's glass shows its half through the shaders' `uv_rect`. Mouse
  positions on the second monitor come in at x 640+ (`_map_mouse_to_crt` adds
  `_look_origin()`); anything that measured the PC by `_crt_viewport.size` must use
  `CRT_RESOLUTION`. Both programs on screen are visible and running: a program that reads
  keys in `_input` must also ask `OS_KEYS.here(self)` (only the screen looked at takes
  keys), message boxes open on the screen looked at (`_make_dialog` adds `screen_origin`).

- **What is still to come from the god cursor is on BUILDER_EYE** (`god_cursor._veil`, meta `god_waiting` till it lands). A node added to the tree again (a leaf going onto its hinge) was noted twice and came back on the Builder's eye: a cabin with no door, the first one built, the one a room stood in at once. A room does not stand in a waiting building (`_find_cabins`, `_find_vans`): the van noted its shell's layers there and put them back, the van gone whenever the room left it. Whoever keeps a building's layers to put back asks for `god_waiting` first. `tools/theatre_check`.
