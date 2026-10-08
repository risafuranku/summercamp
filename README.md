# Cursed Camp Manager Simulator

A mid-90s Build-engine game you found on an unlabeled CD in the attic. By day you run your
aunt's run-down summer camp from the office PC like RollerCoaster Tycoon: bookings, cabins,
toilets, the electricity bill, tiny guests walking around the map. At 20:00 the PC locks,
and you go outside in first person with a flashlight, to find out what your bookings let in.

It is played straight, like a serious product of its time. Now and then it is wrong in a
way nobody would have made on purpose.

Built in **Godot 4.7.1**. The project root is [`godot/`](godot/).
(The project's internal `config/name` is still "icloud ccs2": it names the folder that holds
players' saves and settings, so it must not change.)

## Run it

```bash
godot --path godot
```

Verification (see [AGENTS.md](AGENTS.md) §3 for all harnesses):

```bash
godot --headless --path godot --quit-after 400          # smoke: must print no SCRIPT ERROR
godot --headless --path godot res://tools/hud_layout_check.tscn
```

## Documentation

| Document | Read it for |
| --- | --- |
| [AGENTS.md](AGENTS.md) | **Start here.** Ground rules, layout, how to verify, art pipeline, gotchas |
| [PRODUCT.md](PRODUCT.md) | What the game is; feature-by-feature status |
| [DESIGN.md](DESIGN.md) | Vision and rules: day tycoon, night horror, enemies, upkeep, tone |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, modules, state ownership, signal contract, data flows |
| [TODO.md](TODO.md) | Current priorities |
| [AUDIT.md](AUDIT.md) | History: the 2026-08-05 cleanup and the 2026-10-07 remaster pass |

## Repository layout

```
godot/          the Godot project
tools/          Python/Node tooling: font baker, art generation, SFX synthesis, MCP
mementowiki/    superseded, kept only as historical changelog
ost/            music and radio source files (not imported into the project)
```
