# The night and its enemies

Enemy brains, the director, the night's rules.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **An enemy's ground**: `enemy_base._ground` casts from 20 m up and stops on roofs and in
  tree crowns (the Photographer stood up there a quarter of the time); spots go through
  `_stand` (refuses covered ones), steps through `_floor_at` (from over the warden's feet).

- **A ray from another warden's torch** starts inside their own body: pass them to
  `enemy_base._ray_blocked(from, to, [them])`, or it stops on them (till 4. 11. no
  other warden's torch ever held the Girl or the Silent Man; `tools/coop_girl.py`).

- **First-use hitches at night**: `main._prewarm_hurt` (when the night begins, and at an
  enemy's start) makes the night's layer, the hurt and the blood and draws them once
  unseen. A new material on the night's layer gets its see-through pixel in
  `nightmare_fx._ready` too (not the layer's own parts: a test reads them as a flash). Find one with `tools/holka_shots.tscn --part=hitch` and a cold cache (a fresh
  `APPDATA`): each long frame prints the pipelines compiled in it.

- **An enemy's step goes by `_floor_at`, its spot by `_stand`** (`enemy_base`): `_ground` shoots from 20 m up and stands on roofs and the corn's wall. The camp's last row is a flat box called Lake: `_ground` and `_floor_at` give INF there, `_on_water` is the lake past the map. Round what stands in the way: `_clear_dir`. Nothing appears or goes in view: test `_is_seen` first.

- **The night's sounds and faces come to a room of the camp** (`main.in_camp_room`, through `_quarry_indoors`), not to all that `_is_any_interior_open` counts: that is Liblice, the bus and the pipes too.

- **`main._enemies_leave_at_dawn`, not `_stop_active_enemy_brain`, ends the night**: a brain stays unticked (`leave_at_dawn`, `dawn_tick`) until nobody looks. Whatever holds the player is nearer than `DAWN_ON_YOU` and goes at once.

- **The nights follow on through `core/systems/night_swell.gd`, by the guests, never by the night's number** (the user 7. 11.: "it must not be scripted"). `GameState.night_swell` is kept from night to night and moved once a night in `main._activate_runtime_enemy_for_night`; the roll says what the camp brings, the swell how much of it the night may have. Anything new that gets worse "later on" hangs on the swell. `tools/night_swell_check.gd`.

- **The Whistler's rule is the other way round from before:** he listens while he whistles, you move in the quiet. `_grace` is the song's first notes. Going in through a door sends him to rest.

## Rozhodnutí 24. 11. 2026: nepřátelé v co-opu

Richard, 24. 11. 2026: „mám pocit že v coopu naprosto se rozpadá creepy iluze quiet guye a dalších
enemáků“. Na otázku *Co přesně se děje?*: „vidím movement který z POV prvního hráče bude
strašidelný, ale z POV druhýho vidím jak se ten bubák jakoby schovává. chce to aby počítal z dvoumi
hráči, prostě podle mě na to nebyl moc stavěný a huntil jednoho, měl by hrát s námi s oboumi.
všichni enemies by nás měli vidět jako skupinku a huntit nás jako skupinku, zkoušet různé finty jak
nás třeba rozdělit a postupně dojebat“ + „Druhý vidí, co je pro jednoho“.

Kolo 1 (otázka → odpověď doslova):
- *Jak těžká má být noc ve dvou proti noci sám?* „Stejně těžká, chytřejší“: ve dvou není nepřátel víc
  ani silnějších, ale hrají chytřeji: čekají, rozdělují, běží po tom, kdo zůstal sám. Kdo drží
  pospolu, je většinou v bezpečí, ale kemp se sám neobslouží.
- *Jakými fintami mají skupinku rozdělovat?* „Lov opozdilých“: kdo se zdrží víc než ~25 m od ostatních
  nebo zhasne, toho si vybere.
- *Co s nočním strašením určeným jen pro jednoho hráče?* „Druhý to nesmí vidět“: nepřítel se hýbe,
  jen když se nekouká žádný hráč; strašení pro jednoho se odehraje jen tam, kam druhý nevidí, takže
  iluze drží z obou pohledů.
