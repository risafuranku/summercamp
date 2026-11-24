# The player: body, eye, input, HUD, cursor and hands

What the warden is and how the player drives them.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **Leaving is Esc or Space, the pause menu P or F10** (the user, 4. 11.): Esc leaves a
 room, the PC, a close-up or a job a step at a time (`INTERIOR_LOOK.is_exit_event`) and is
 the pause menu only outdoors (main `_unhandled_input`); Space leaves the same way wherever
 it is nobody else's (`INTERIOR_LOOK.is_space`; a close-up asks its `_key` first, so the
 till, the phone, a page and the PC keep it); P and F10 pause anywhere
 (`ui/pause_keys.gd`). The pause menu's CanvasLayer is 150, above every full-screen overlay
 (the check-in desk is 140); a new overlay stays below it. Leaving is also the bottom band
 or a right click; the pause menu's "Go outside" (`main._on_pause_leave_requested`) ends any
 room or job the way its own exit would. Back to the title screen closes them too, silently
 (`main._leave_everything(true)` in `_enter_main_menu`): a room left open went on taking
 clicks behind the menu. Always-processing modals return early from
  `_input` while the tree is paused. In a co-op camp the tree is not paused: the menu turns
  every other node's input off while it is up (`pause_menu._mute_others`, back as it was on
  closing; the walkie-talkie stays) and `HandCursor.menu_over` is set: something that reads
  the mouse in `_process` (room tasks, the scrubbing, a signature, a station's hand) must
  look at it.

- **Mouse clicks never reach `_unhandled_input`** outdoors: the world's
  SubViewportContainer takes them. Read clicks in `_input`. A ray from a camera inside a
  SubViewport needs the window mouse scaled into that viewport (`lake_trip._mouse_in_cam_viewport`).

- **2D integer scale is chosen at runtime** (`main._apply_integer_canvas_scale`): the
  logical size is window / k so the canvas scale is a whole number and the window is
  filled. The engine's own integer mode letterboxes; do not switch to it.

- **Pixel fonts are bitmaps with integer-only scaling**: request `size_vp` = 8 (labels,
 text) or 10 (Jersey) or multiples; other sizes snap down.

- **2D is nearest everywhere**: the project's canvas default filter is Nearest, and
 `GameSettings` sets every SubViewport's `canvas_item_default_texture_filter` to nearest
 as it enters the tree (a SubViewport's own default is linear: centred text landed on
 half pixels and came out smeared, playtest 18. 10.). Nothing in the game wants linear.

- **Cursor art is a hardware cursor**: `HandCursor` swaps the ARROW shape's image; scale
  is by whole numbers of the window height (not the logical 2D size).

- **Interaction rays are cast in the camera's own viewport**: the world is drawn small and
  scaled up, so screen points must be in that viewport's pixels
  (`camera.get_viewport().get_visible_rect()`), not the window's. Until 17. 10. they were in
  window pixels and only the structures fallback ever found anything.

- **Hands are claimed** (`scripts/ui/hands.gd`): anything drawn in the player's hand claims
  "right" or "left" while it is up and releases it when it is down (work > bottle >
  lighter > torch/cigarette). The torch changes hands by itself (the right busy: the left,
  mirrored; both busy: in the pocket, `player_controller.hand_busy` puts its light out).
  A new hand overlay must claim, draw at `Hands.px(view height)` on that pixel grid, take
  `light` as its modulate and add `motion`; never rotate a hand sprite.

- **The camp camera's picture can be shifted** (Build's look up and down is a frustum offset,
  `player_controller._apply_projection`): a camera that copies it must copy `projection`,
  `size` and `frustum_offset` (scaled to its own near), and "where the warden looks" is
  `player.look_basis()` (the camera's -Z is up to 12° off).

- **Work goes by gestures** (`scripts/ui/gesture.gd`): a held click or key with no mouse
  movement does nothing. The shot driver sets `GESTURE.auto` (a held press makes strokes by
  itself, ~the old hold's time), so scenarios with `["lmb", true], ["wait", s]` still work; a
  harness that does not extend the shot driver must set it.

- **A close-up hides the hands**: `closeup_view.gd` (and the breaker, scrub, corn stand,
  check-in desk) are in group "closeup"; pockets.gd keeps the hands down while one is
  visible. A new full-screen overlay where your hands are busy joins that group.

- **The eye's motion is the body's, never a wobble** (the user, 25. 10., furious at a sprint
  "shake" of 23-37 Hz sines: "like being shaken, linear up and down, mad fast"): a camera
  movement comes from a cause (a foot landing kicks a spring, a landing, a stop) and settles
  on a spring; nothing faster than the steps, no noise on top. Measure it before handing it
  over (the head's y, pitch and roll sampled while sprinting: reversals a second, the biggest
  second difference): the sprint is 3.6 steps a second, 4 cm, the nod a soft spring kicked
  per foot (player_controller RUN_NOD_*).

- **A body moved by a tween, not physics** (a door walk, a seat): `player_controller` draws the
  head between physics steps only for physics' own moves; one put somewhere between steps
  (`_moved_outside`, checked at the top of `_physics_process`) is drawn where it is (14. 11.:
  every walk out of a door shook, the head a part of a frame behind after each step).

- **The site plan on TAB draws the Builder's pictures** (`assets/textury/builder/iso3d/<type>_0.png`, anchors in views.json, scaled once by `_picture` with the camp's own proportions, warmed one a frame before the first TAB). A new building needs a picture there or in `FILE_OF`, and a name in `NAMES` unless its picture says it.

- **`player.torch_fade`:** going in by a door the torch goes down over the walk; a lit room burnt white at arm's length.

- **Made input events need device 0.** An action made in code (`InputEventKey.new()` added to
  the InputMap) answers device 0 only; an event parsed with another device does nothing
  (15. 11.: the pad's Esc and F, sent as device 77, opened nothing). The pad's events are
  the keyboard's device marked with meta `"pad"` (`scripts/input/pad.gd`).

## Rozhodnutí 24. 11. 2026: PDA se stylusem

Richard, 24. 11. 2026: „TAB mapa je hrozně clunky, co kdyby jsmě měli nějaké staré windows PDA se
stylusem? předělali by jsme teda i ten pager na kterym ti pípaj upozornění. Měl bys na tom PDA novej
operační systém, a custom appky který by jsme spolu navrhli.“

Kolo 1:
- *PDA se stylusem (Windows CE kolem roku 1998) místo TAB mapy a pípajícího pageru: co na něm hlavně
  dělat?* „Jen mapa a upozornění“: přesná náhrada TAB mapy a pageru, nic víc.

Kolo 2:
- *Jak se PDA vytáhne a ovládá?* „Podržet TAB“: dokud držíš TAB, je PDA v levé ruce před tebou a
  stylus ovládáš myší; chodíš pomaleji, kemp běží dál. Upozornění: PDA zavrní v kapse a v rohu
  obrazovky blikne malá ikonka. Pager zmizí.

Kolo 3:
- *Jak má vypadat displej a systém PDA?* „Šedozelené LCD“: monochromní zelenkavý LCD jako Palm nebo
  Psion z roku 1998, vlastní systém „Okna CE“ v duchu Oken 98 (spodní lišta, pixelové ikony z Groka),
  šedá plastová krabička se stylusem v ruce v rukavici; v noci podsvícení slabě zeleně svítí.
- *Jaké aplikace kromě plánku kempu a upozornění?* „Úkoly, Hodiny a počasí, Hra na PDA“: úkoly
  z dnešní TAB obrazovky (Verin seznam v příběhu, co čeká v kempu); čas, předpověď a odpočet do
  zamčení PC ve 20:00; jedna malá hra na krácení času, třeba had.
