# TODO — Cursed Camp Manager Simulator

*Updated: 2026-10-08. Vision: DESIGN.md. What exists: PRODUCT.md.*

---

## P0 — the vision's missing pieces

- [ ] Interiors visual pass: real toilet / sink / bed models, the camp textures
      (lino, wallpaper, tiles, blanket) on the walls and floors; pub and cellar rooms.
- [ ] Pipe crawl polish: a proper shoe/bucket sprite, junction props, playtest the
      thing's pace; consider a second map style (torn, partly wrong).
- [ ] **Service minigames** inside the interiors (now that you can look around them):
      unclog a toilet, reset the generator breaker, restock the shop shelf.
- [ ] Atmosphere: a proper dusk skybox (generated), wind in the trees by day, distant dogs
      or a train at night; listen through a whole day/night with headphones and mix.
- [ ] Playtest the uncanny details' frequency (station 14%/track at night, phantom glance
      35% of nights): rare enough to doubt, common enough to be met in a week.
- [ ] **Night playtest + balance** of the four enemies (damage, cadence, battery, how
      often two archetypes cross the threshold on a lazy vs. a careful booking).

## P1 — management depth

- [ ] Booking offers that make the puzzle explicit (party mix, demands, a tempting
      high-paying lazy option) and a booking screen that shows the night price per guest.
- [ ] Balance pass: satisfaction/fun deltas, income vs. upkeep vs. electricity.
- [ ] The raccoon thing: waste overflow (dumpsters) as a fifth night threat; art exists.
- [ ] Win/end of week (Vera returns on day 8): what a good week means.

## P2 — structure

- [ ] Split `crt_os_shell.gd` per app; start with the pure Camp Status text builders.
- [ ] Move the liminal debug window and night orchestration out of `main.gd`.
- [ ] `BuildingManager` as a pure view over `GridModel`.
- [ ] Remove `GameActions.end_day()`.

## P2 — release blockers

- [ ] Replace Redneck Rampage texture rips with generated textures (AGENTS §7).
- [ ] GitLab remote auth on the dev PC (pushes hang in Git Credential Manager; GitHub is
      the up-to-date mirror until fixed).
- [ ] Export test (the building registry now handles `.remap`; verify a real export).

## Done in the 2026-10-07 remaster

HUD fonts/layout, objective marker, front end + pause, integer scaling, weather cycle,
upkeep loop, single building catalog, main.gd extractions, four night enemies, stamina and
battery, RCT guests on the Builder map. Details: AUDIT.md.

Then: the pipe crawl (sewer repair rebuilt); night senses (insect hush, HUD face glance);
the radio as a place; the station, the night log, the unbooked sleeper; the story week
rewritten without filler; restricted look-around in every interior, closed rooms, English
signs in the interiors.
