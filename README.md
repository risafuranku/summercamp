# Summer Camp Incident Simulator 2

A first-person camp-management horror sim set in a decaying post-communist summer camp.
You mind your aunt's campsite for a week from a beige CRT terminal: read email, accept
bookings, build cabins, pay the electricity bill. Then night falls.

Built in **Godot 4.7.1**. The project root is [`godot/`](godot/).

## Run it

```bash
godot --path godot
```

Headless smoke test (catches parse errors and startup regressions):

```bash
godot --headless --path godot --quit-after 400
```

## Documentation

| Document | Read it for |
| --- | --- |
| [AGENTS.md](AGENTS.md) | **Start here.** Ground rules, layout, gotchas, workflow |
| [PRODUCT.md](PRODUCT.md) | What the game is; feature-by-feature status; roadmap |
| [DESIGN.md](DESIGN.md) | Game design: the core tension, economy, guests, horror rules |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, state ownership, signal contract, data flows |
| [AUDIT.md](AUDIT.md) | 2026-08-05 cleanup pass: what was broken and what was done |
| [TODO.md](TODO.md) | Current priorities |

## Repository layout

```
godot/          the Godot project
mementowiki/    superseded — kept only as historical changelog
ost/            music and radio source files (not imported into the project)
```
