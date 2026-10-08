# TODO — Cursed Camp Manager Simulator

*Updated: 2026-10-08. Vision: DESIGN.md. What exists: PRODUCT.md.*

---

## P0 — the vision's missing pieces

- [ ] **Pipe crawl** (sewer repair redesign, DESIGN §8): paper map without your position,
      turn only at junctions, no 180°, coordinates + landmarks; an enemy in later nights.
- [ ] **Interiors: restricted look-around** in tents/cabins/services (claustrophobic, not
      free movement), plus small service minigames.
- [ ] **More uncanny details** (DESIGN §2 rules). Candidates: a mail that arrives at 03:00
      timestamped tomorrow; the radio playing a station that does not exist for a few
      seconds; a guest in GuestRack with no booking; the HUD face looking left when
      something is behind you; Vera's mails getting slightly too familiar.
- [ ] **Atmosphere pass**: dusk sky and sound bed, the reception radio audible outside
      with distance falloff, night insects that stop when an enemy is near.
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
