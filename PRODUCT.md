# PRODUCT.md — Summer Camp Incident Simulator 2

*Status snapshot: 2026-08-05*

## What it is

A first-person camp-management horror sim set in a decaying post-communist summer camp.
You are minding your aunt's campsite for a week. You run the place from a beige CRT
terminal in the reception office: read email, accept or reject bookings, build cabins and
toilet blocks, pay the electricity bill. Then night falls, and you find out which of your
guests isn't a guest.

The pitch in one line: **Papers, Please's inbox meets Theme Park's grid meets a haunted
Windows 95 desktop.**

## Player fantasy

You are not a hero and not a detective. You are an underqualified relative with
administrator access. The horror is bureaucratic: the systems keep working, the emails
keep arriving, the bill is still due on the 3rd — and something in cabin three is not
following the schedule.

## Pillars

1. **The terminal is the game.** Most decisions are made through a fake 90s OS: a mail
   client, a builder, a finance app, a browser. Diegetic UI, no floating HUD panels.
2. **Management pressure creates horror pressure.** More guests means more income *and*
   more liminal pressure. The thing that spawns at night is a direct function of how
   greedy you were during the day.
3. **Horror through wrongness, not volume.** Empty spaces, footsteps in the wrong place,
   a mail from `void@null.invalid`, a status readout that disagrees with what you can see.
4. **The camp is legible.** It is a grid. You can read it. The simulation must never be
   mysterious in a way that feels like a bug rather than a threat.

## Setting and tone

- Post-communist Czech summer camp: corrugated roofs, concrete, rust, tarpaulin.
- Visual register: low-poly PSX, CRT scanlines, dithering, texture warp.
- Interface register: corporate-liminal — beige, square, utilitarian, Win95-adjacent.
- Written register: dry and administrative, undercut by things that shouldn't be in an
  inbox. The camp's email cast (Aunt Vera, Nela, unknown senders) carries the story.
- Ships in English.

---

## Feature status

**Legend:** ✅ working · 🟡 partial / needs work · 🔶 built but not driven · ❌ not built

### Core loop

| Feature | State | Notes |
| --- | --- | --- |
| First-person movement, head bob, surface-aware footsteps | ✅ | dual-loop grass/gravel crossfade locked to camera stride |
| Day/night cycle | ✅ | 1 real second = 1 game minute; day 06:30, evening 18:00, night 20:00 |
| Grid build/demolish, multi-tile footprints, refunds | ✅ | drag-demolish, bulldozer, path tool |
| Save / load / autosave | ✅ | save version 3, autosave every 60s, slot list in main menu |
| Main menu with cinematic camp flythrough | ✅ | catmull-rom path over the generated world |
| Weather states (7) + full visual/audio treatment | 🔶 | **never auto-cycles during gameplay** — see AUDIT.md |
| Economy: costs, income, refunds, power/water/sewage/waste balance | 🟡 | works, but split across two catalogs |
| Karma / satisfaction / hrotfaktor metrics | 🟡 | now correctly scaled and fed by real building data; **unbalanced** |

### The terminal (CRT OS)

| Feature | State | Notes |
| --- | --- | --- |
| Boot sequence, splash, desktop, taskbar, start menu | ✅ | draggable icons, persistent layout across saves |
| **CampMail** — inbox, spam folder, confirm/reject bookings | ✅ | story + customer + spam pools, toast + notification sfx |
| **Builder** — category catalog, placement, rotation, demolish | ✅ | locked during NIGHT MODE by design |
| **Camp Status** — electricity, tabs | ✅ | |
| **Finance** — income/power breakdown | ✅ | |
| **GuestRack** — guest overview | ✅ | |
| **Beeternet** — in-game browser, downloads | ✅ | home + 404 pages, download → installer flow |
| **Install wizard** — unlock apps by installing them | ✅ | 4-step fake progress, emits `program_installed` |
| **Minesweeper** | ❌ | skeleton only, opens a text window |
| Notepad / Explorer app entry points | ❌ | functions exist, unreferenced |

### Guests

| Feature | State | Notes |
| --- | --- | --- |
| Booking via email → instant check-in → stay → checkout | ✅ | rolling income, bed reservation |
| Three archetypes (Quiet Guy, Drunk, Cheap Chick) | ✅ | different income and trouble times |
| Reviews on checkout | ✅ | **was pinned to 1 star until 2026-08-05; now scales with satisfaction** |
| Guest needs (hunger, energy, hygiene, fun, comfort, safety) | ❌ | designed in TODO, not implemented |
| Visual guest agents in the world | ❌ | guests are data-only; sprites exist, unplaced |
| Assignment / cleaning / staff automation | ❌ | **cut** — the UI and stubs were deleted 2026-08-05 |

### Horror layer

| Feature | State | Notes |
| --- | --- | --- |
| Liminal forecast — guest count per archetype drives spawn pressure | ✅ | tiered chance: tiny → small → medium → large → guaranteed |
| Night spawn roll + HUD threat indicator | ✅ | |
| **Silent Man** enemy brain | ✅ | 4-state AI: haunting → pressure → attack window → cooldown; presence cues, flashlight blink, teleport despawn |
| Player health, damage tiers, blood decals/projectiles | ✅ | 5 damage tiers, decal budget, timed fade |
| Game over (death, UPS power loss) | ✅ | |
| Additional enemy archetypes | ❌ | only Silent Man; `i_enemy_brain.gd` is the interface |

### Interiors

| Feature | State | Notes |
| --- | --- | --- |
| Reception office (CRT room, radio, light switch) | ✅ | radio playlist auto-loads from the radio folder |
| Tent / cabin interiors, upgrade menus | ✅ | Lv1→Lv3 upgrade chain |
| Service interiors (toilet, shower, sewer, generator) | ✅ | generated from profiles |
| Reception notebook interaction | ❌ | prop exists, hotspot reserved, no handler (assignment UI was cut) |
| Sewer pipe repair minigame | ✅ | `SEWER_PIPE_REPAIR_ENABLED = true` |
| Utility repair minigame | 🔶 | complete, gated off by `UTILITY_REPAIRS_ENABLED = false` |

### Systems built but not connected

| System | Why it matters |
| --- | --- |
| Weather auto-cycle | ~1700 lines of weather visuals + a full weather audio mix never fire in a real session |
| `MaintenanceSystem` / `FailureSystem` | run, but maintenance decay has no player-visible consequence loop |
| `GameActions.end_day()` | legacy; warns on use, bypasses the canonical `day_tick` path |
| `EconomyManager.get_builder_catalog()` and 11 sibling methods | never called — the builder reads its catalog elsewhere |

---

## Roadmap

### Now — make the existing simulation actually run

1. **Drive the weather.** Enable auto-cycle during gameplay and tune the transition
   table. The single highest-value/lowest-cost change in the project: a large finished
   subsystem currently contributes nothing.
2. **Balance pass on the revived metrics.** Satisfaction, karma and infra load are now
   fed by real building data for the first time. They need numbers that mean something.
3. **Close the maintenance loop.** Decay → failure → visible consequence → repair.

### Next — guest simulation phase 2

4. Guest needs model + tick.
5. ACTIVE-state behaviour brain: goal selection weighted by needs, cooldowns, anti-stuck.
6. Service usage: guests read what the camp offers and react to it.
7. Visual guest agents — placeholder 3D representation bound to the guest entity.
8. Random ambient events + timed story events.

### Later

9. Second enemy archetype against the `i_enemy_brain` interface.
10. Minesweeper as a real app (it's the reward for a quiet night).
11. Email threads/replies for story and lore pacing.
12. Retire `EconomyManager.BUILDING_DATA`; `BuildingRegistry` becomes the sole catalog.
13. Break `main.gd` and `crt_os_shell.gd` down to orchestration-only layers.

## Known non-goals

- Multiplayer.
- Modern UI polish.
- Combat. The player can be hurt and killed; the player cannot fight back.
