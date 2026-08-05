# TODO - Cursed Camp Simulator
*Poslední update: 2026-02-23 (16:34 CET)*

## P0 - Guest simulation phase 2 (aktuální priorita)
- [ ] Rozpad statusů `omw/book/active/sleep/leave` na detailní sub-flow + jasné přechodové podmínky.
- [ ] Zavést systém potřeb hosta (hlad, energie, hygiena, social/fun, comfort, safety) + tick model.
- [ ] ACTIVE "RNG mozek": výběr cíle, váhy dle potřeb, cooldowny, anti-stuck fallback.
- [ ] Service usage layer: hosté mají číst dostupné služby v kempu a rozhodovat se podle nich.
- [ ] Event pool:
- [ ] random ambient eventy (malé),
- [ ] timed story eventy (větší, řízené podmínkami).
- [ ] Vizuální agenti hostů:
- [ ] placeholder 3D reprezentace + navázání na data guest entity,
- [ ] outdoor/indoor pohyb (zatím simple pathing + teleport fallback).
- [ ] Integrace na staff automation:
- [ ] scheduler nad `GuestManager.enqueue_staff_task/process_staff_tasks`,
- [ ] režimy "manual only / assisted / full staff auto".

## P1 - Existing guest loop stabilization
- [ ] Balancing ekonomiky checkout payout (`RATE_*`) a pacing příjezdů.
- [ ] Přidat UX feedback při chybách assign/clean (konzistentní hlášky + zvuk).
- [ ] Napojit dirty/clean stav na vizuální feedback budovy ve worldu.
- [ ] QA test cases pro notebook flow (assign, reject, clean, clean all, edge cases capacity).

## P1 - Email/CampMail polish
- [x] Inbox rework na real-row styl + newest-first + preview snippet.
- [x] Incoming email toast + notif sfx.
- [x] Audio konsistence notifikace s radiem (interiér/exteriér stejné pravidlo).
- [ ] Ticker dynamicky napojit na runtime stav (počasí/obsazenost/finance).
- [ ] Přidat thread/reply simulaci pro story a "aunt/gf/spam/cursed" lore pacing.

## P2 - CRT desktop debt
- [ ] Minesweeper full app window (zatím skeleton).
- [ ] icon texture filter: blur -> pixel (asset pipeline).
- [ ] fake loading progress tuning.
- [ ] cleanup: regions, dedup style funcs, dead code pryč.

## P2 - Main refactor track
- [ ] Dokončit `weather_visuals.gd`.
- [ ] Dokončit `interior_manager.gd`.
- [ ] Dál stahovat `main.gd` na orchestrace-only vrstvu.
