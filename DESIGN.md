# DESIGN.md — Summer Camp Incident Simulator 2

*Status snapshot: 2026-08-05*

How the game is meant to feel, and the systems that produce that feeling.
For what exists today see [PRODUCT.md](PRODUCT.md); for how it's wired see
[ARCHITECTURE.md](ARCHITECTURE.md).

---

## 1. The central tension

Every management decision has a horror cost, and the player can see the exchange rate.

```
accept booking  →  +income  →  +guests of an archetype
                                     │
                                     ▼
                          liminal pressure for that archetype
                                     │
                                     ▼
                          night spawn chance / guarantee
```

The player is never ambushed by this. The **liminal forecast** exposes the odds. The
horror is not "something might be out there" — it's "I know exactly how likely this is
and I took the booking anyway."

This is the load-bearing idea. Any new system should either feed this tension or get out
of its way.

### The liminal pressure curve

Per archetype, based on the count of that archetype currently staying:

| Guests of one archetype | Result |
| --- | --- |
| ≤ 3 (`LIMINAL_FORECAST_SAFE_COUNT`) | safe, no roll |
| 4 → 5 | **tiny** chance (0.12–0.18) |
| 6 → 11 | **small** (0.20–0.32) |
| 12 → 17 | **medium** (0.36–0.56) |
| 18 → 23 | **large** (0.62–0.86) |
| ≥ 24 (safe + 21) | **guaranteed** spawn, then the curve loops every 24 |

Three archetypes roll independently, so a wide mixed camp is safer than a deep
single-archetype camp. The intended read: *diversify your guests, or accept the odds.*

---

## 2. The daily rhythm

One in-game day = 24 real minutes (`TIME_SCALE = 1.0`, 1 real second = 1 game minute).

| Time | Phase | What the player does |
| --- | --- | --- |
| 06:30 | **Day** | build, walk the camp, inspect, repair |
| through the day | | email arrives irregularly; bookings need answers |
| 18:00 | **Evening** | last building window, lamps come on at 19:30 |
| 20:00 | **Night** | **builder locks**; the camp is dark; the roll has been made |
| ~02:00 | | archetype-specific trouble windows peak |
| 06:30 | | next day, bills, reviews, consequences |

The builder lockout at night is the core pacing device: it forcibly converts the player
from *manager* into *occupant*. The day is spreadsheet time. The night is walking time.

---

## 3. Economy

All tuning lives in `core/balance/balance_config.gd`.

- Starting money: **850**
- Refund on demolish: **50%** of cost
- Demolish fee: **4 per tile** of the dragged rectangle
- Income: per-guest rolling income, paid over the stay, scaled by archetype
  (Quiet Guy 70 / Drunk 120 / Cheap Chick 190 per day)

Note the deliberate inversion: **the most profitable guests are the most dangerous.**
Cheap Chick pays 2.7× what Quiet Guy pays and carries the same liminal weight — so the
optimal-income camp is the one most likely to spawn something.

### Electricity — the recurring threat with a due date

- Bill issued at **20:00** (`NIGHT_START_HOUR`), 3-day grace period
- 2.2 per kWh, 3 kWh per power unit, 12/day base fee
- Non-payment → power cut → UPS runs for **360 seconds** → then `GAME_OVER_REASON_UPS`

This is the game's only hard fail state that isn't death, and it's an administrative one.
That is the point.

### Building categories

| Category | Role | Radius effect |
| --- | --- | --- |
| `housing` | capacity, income, hygiene pressure | — |
| `services` | hygiene and comfort for nearby housing | 4 tiles |
| `attractions` | fun for nearby housing | 5 tiles |
| `utilities` | power/water/sewage/waste supply | lamp post 3 tiles |

Housing is upgradeable in place (tent Lv1→3, cabin Lv1→3) from inside the interior.
Upgrade cost is the delta between tiers, floored at 20 (tent) / 30 (cabin).

### Comfort model

`SatisfactionSystem` averages a per-housing score on a **0–100 scale**:

```
score = 50 (neutral)
      + hygiene_delta and fun_delta of every service/attraction within its radius
      + housing's own hygiene_delta (negative: -0.5 per occupant slot)
```

`BuildingDef` fields are derived mechanically from the authored economy numbers:
`hygiene_delta = service_points × 2`, `fun_delta = attraction_points × 2`, food/social
venues get +2 fun. **These derivations are placeholders and want a real tuning pass** —
they were generated on 2026-08-05 when the registry was reconnected, and this is the
first time these numbers have ever reached the simulation.

> ⚠️ **Scale contract:** `GameState.satisfaction` is 0–100. Guest review ratings are
> `round(satisfaction / 25)` clamped to 1–5. Returning a 0–1 value here silently pins
> every review to 1 star. This exact bug shipped and lived for months.

---

## 4. Guests

### Lifecycle

```
customer email → CONFIRM → immediate check-in → beds reserved → active/sleep
                                                                     │
                                       nightly trouble roll ─────────┤
                                                                     ▼
                                                   stay ends → payout + review → leave
```

Rejecting a booking deletes the mail. There is no waiting queue and no manual
assignment — that system existed, was cut, and its UI was removed on 2026-08-05.
Beds are allocated automatically at check-in.

### Archetypes

| Archetype | Daily income | Trouble window | Character |
| --- | --- | --- | --- |
| Quiet Guy | 70 | 22:40 | low-yield, low-noise, the safe default |
| Drunk | 120 | 00:30 | mid-yield, noisy |
| Cheap Chick | 190 | 02:20 | high-yield, latest trouble, deepest into the night |

Trouble events subtract satisfaction and karma and add hrotfaktor, scaled by the
booking's difficulty (1–5).

### Hrotfaktor

The camp's "weirdness pressure" (0–1). Rises with guest trouble, feeds `EmailManager`'s
generation rates: higher hrotfaktor means more customer mail *and* more spam. The camp
getting stranger makes the inbox louder — pressure begets pressure.

### Not yet built

The needs model (hunger, energy, hygiene, social/fun, comfort, safety) with a tick and an
RNG-weighted goal-selection brain. Guests are currently pure data with no world presence.
This is the largest single gap between the design and the build.

---

## 5. The horror layer

### Silent Man

The only implemented enemy. A four-state brain:

| State | Behaviour |
| --- | --- |
| `HAUNTING` | ambient presence cues, distant audio, never visible |
| `PRESSURE` | closer cues, flashlight flicker, peeks at the edge of vision |
| `ATTACK_WINDOW` | commits over ~1.4s, 16 damage per hit |
| `COOLDOWN` | retreats, teleport-despawns beyond 45m |

It reads whether the player is looking at it, and it reacts to player cues (yaw change
> 22°, movement > 0.48m within a 1.05s window). It is designed to be *avoidable by
paying attention* — the player who sweeps their light and turns around survives.

`i_enemy_brain.gd` is the interface for adding more. Any new enemy implements the same
tick/spawn/despawn contract so `main.gd`'s night orchestration doesn't need to change.

### Damage and death

Five damage tiers, each with its own blood chunk count and spread. Decals fade after
180s over a 34s window, capped at 260 on screen with a spawn budget of 8/frame.
Player health is 100; there is no healing item — there is only surviving the night.

### Rules of the scare

- No jumpscare stingers as a substitute for build-up.
- The threat is always *forecast* before it is *encountered*.
- The systems never lie to the player, but they may be quiet about it.
- Ambiguity should come from anomaly (footprints, a mail from nowhere, a light that was
  off), never from a UI that failed to update.

---

## 6. Presentation

### Visual

- Low-poly PSX: vertex jitter, affine texture warp, limited colour depth
  (`psx_post.gdshader`, `psx_surface.gdshader`)
- CRT treatment over the terminal (`crt_post.gdshader` — scanlines, curvature, bloom)
- Stylized multimesh grass; skybox transitions blended continuously across dusk
- Night sky transition starts **19:30**, ends **21:15**; stars fade in from **20:30**
- The time profile is applied **every frame**, not per minute — per-minute stepping
  caused visible colour jumps

### Interface

Corporate-liminal. Beige, square, bevelled. Explicitly **not** modern:

- No rounded corners, no gradients, no drop shadows as decoration, no easing flourishes
- Square 1px borders, 3D bevels baked into sprites where possible
- Fixed-width layout metrics (top bar 22px, taskbar 24px, start menu 336px)
- The player never sees a floating game HUD panel where a diegetic window would do

### Audio

- Weather loops, thunder sync, interior rain occlusion
- Radio in the reception office with distance-based falloff — the same falloff rule set
  is reused for email notification pings so interior/exterior loudness stays consistent
- Ambient wildlife gated by the day/night window (birds by day, crickets by night)
- Ambient OST rolls once per evening with a randomised track pick
- Guard: any audio stream source over 8MB is skipped during fallback loading — deliberate

---

## 7. Open design questions

1. **What does the player do with a *quiet* night?** Right now: walk around and wait.
   Minesweeper was the intended answer. It's still a skeleton.
2. **Should maintenance decay be visible before it fails?** Currently the failure is the
   first signal, which reads as arbitrary rather than negligent.
3. **What is the win condition?** Aunt Vera returns after seven days — but survival is
   the only defined outcome. Is there a "good" ending, and what does it cost?
4. **How much should the terminal lie?** A status readout that is subtly wrong is the
   single strongest horror tool available in a game about administration — and the most
   dangerous, because it's indistinguishable from a bug. Needs a deliberate rule.
