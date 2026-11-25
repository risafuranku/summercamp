# TODO — Cursed Camp Manager Simulator

## TODO

- [ ] Dělník na staveništi: vzorek od Groka (`site_worker_a`) čeká na schválení; po něm druhý dělník s prkny.
- [ ] Stánek s kukuřicí: všechny předměty na pultu z 2D textury převést na 3D sprity, které na pultu stojí (jako vařící se kukuřice); vzorek máslenky od Groka čeká na schválení (`tools/artgen/prompts_corn_props.tsv`).
- [ ] Objednané zboží přiveze dodávka a někdo ho donese na místo; nový zaměstnanec přijede autobusem.
- [ ] Kamera, animace a optimalizace: projít před co-op playtestem.
- [ ] Noc vyvážit hraním: poškození od nepřátel, jejich četnost, baterie; jak často se potkají dva druhy nepřátel; četnost divných detailů.
- [ ] Nekonečný sandbox: náhodné nabídky, události a mixy nepřátel; nastavení nového kempu (velikost mapy aj.); cíle a obrazovka se skóre a statistikami.
- [ ] Atmosféra: obloha za soumraku, vítr ve stromech přes den, v noci psi nebo vlak v dálce, ranní mlha, místo v hlubokém lese, kam hosté chodí; den a noc projít poslechem a smíchat.
- [ ] Potrubí: tempo tvora vyzkoušet člověkem, čárky na zdi jako obrázek (ne „IIII“), druhý styl mapy (roztržená, částečně špatně).
- [ ] Plátno stanu zevnitř: Grok textura s osnovou a švem, bez záhybů.
- [ ] Pohyb a kamera z 21. 10.: 3b (místnost pod věcmi venku), 4b (klidný pohyb korun).
- [ ] Postavy: vadné listy (warden_c run3, host2 run4 a sit, host3 run3, opilcův run 4 a sit, holčin run 3, Janin run 3) jen pokud je hraní ukáže, znamená to přegenerovat celou sadu postavy; hosté u atrakcí otočení k atrakci.
- [ ] Ruce: druhá varianta každého snímku ruky, víc snímků na pohyb, pohled na hodinky.
- [ ] Herní internet (P12): vlastní titulky her, zvuky, nemožné rekordy; výdělek navázaný na kemp.
- [ ] Builder 98: druhé Grok varianty, nápověda k cheatům někde v PC, ikony nových programů, karta pro cesty a lampy, víc stránek Bohemia Online.
- [ ] Druhý monitor: dodávka zepředu i zezadu a fotka PC Servisu (Grok), dodávka se při odjezdu otočí.
- [ ] Hlavní menu: místa v kanceláři podle řádků knihy a kamera k nim (M5), vlastní načítací obrazovka (M6), logo (M7, Grok, nejdřív 2 vzorky).
- [ ] Záseky první hodiny: první pohled na věc venku kompiluje shadery; Jednota jeden snímek 289 ms; dveře chatky, hospody a záchodů 4–8 snímků po 50–97 ms. Měřit na volném PC (`tools/dvere_check.tscn`).
- [ ] Čeština celá: den a noc hrát česky (`--lang-audit`), obrázky s nápisy (cedule, plakáty, web, splash Builderu).
- [ ] Úklid kódu: `main.gd` (~3,7k řádků) jen na průběh hry, `BuildingManager` jako čistý pohled na `GridModel`, pryč `GameActions.end_day()`, mrtvý kód a nepoužité assety.
- [ ] Nahradit vykradené textury z Redneck Rampage vygenerovanými (docs/art.md).
- [ ] Co-op: konec měsíce (týdenní report, inspekce) jen u hostitele, má být u všech.
- [ ] HUD: u druhého hráče v co-opu sahají šesticiferné peníze s „Kč“ až k okraji rámečku, hostitel „Kč“ nemá (snímek site_coop sc2).
- [ ] Co-op: v Lesné se správci občas nevidí (viděno jednou).
- [ ] Co-op: boží kurzor na dvou kopiích v noci a v mlze, tempo podle pocitu.
- [ ] Co-op: okna zvenku ukazují na PC poslední vlastní snímek; okna chatek, karavanů a podniků jen interior mapping, ne skutečnou místnost.
- [ ] Co-op: test `podniky_coop` čeká na polévku, kterou nikdo neobjednal (chyba testu).
- [ ] Co-op playtest dvou lidí na dvou PC, poznámky sem.
- [ ] Příběhový kemp a demo: Verina polaroidka, tři dny dema, Steam stránka, cíle plné hry (odloženo)
- [ ] Ovladač a Steam Deck (odloženo)
- [ ] Split screen: 60 fps chce refaktor, předtím se zeptat Richarda (odloženo)
- [ ] Webové demo (odloženo)
- [ ] Nápad: mýval a přetékající odpad jako pátá noční hrozba
- [ ] Nápad: něco schovaného v kůlně, víc na druhém břehu, stěny bludiště
- [ ] Nápad: lore chatky elektrikářů, zima, skryté stránky
- [ ] Nápad: hlídka po kempu, viditelné cesty ven z kempu

## DONE

- [x] Megafon z ampliónů: zní ze tří nejbližších jako rádio; dřív nehrál vůbec (kamera hledaná ve špatném viewportu) (8a8c2530)
- [x] Blesk za okny místností: se stínem má okenní kříž a věci vrhají stíny; bez něj svítil jako obyčejný reflektor (e64ea484)
- [x] Stavba trvá podle velikosti: staveniště s lešením, dělníky a bouchaním, 1–4 h práce přes den, pak stojí budova; i pro dva (db5e7189)
- [x] Programy na PC ukazují kemp naživo: tečky hostů v GuestRacku (Pokoje), fronty a zelené tržby v Boss 98, kamera kempu v CampStatu míří na kemp a vejde se (995cccd6)
- [x] Kuželna pro dva: tác, točení, kolíky, pult a sklep vidí i druhý správce (test `bowling_coop`); stav stanice se posílá znovu každou sekundu, vidí ho i ten, kdo přijde později (800db2c1)
- [x] Co-op u stanic všech podniků: ostatní vidí rozdělanou práci a věc v ruce; u stánku stojí každý u své stanice a pracuje (5e6cd4f8)
- [x] Bez PS jiggle: vrcholy se už nepřichytávají k mřížce obrazovky (všechny modely, stromy, třpyt), textury dál plavou (fbd11418)
- [x] Nastavení v záložkách Obraz, Zvuk, Ovládání, Hra; vlastní hlasitost hudby, efektů a hlasů (a97d2e0a)
- [x] Lehce zaoblené rohy nápověd a zvýraznění (1fb654ab)
- [x] Hlas: V místně, klik během V vysílačka z batohu (abb89818)
- [x] Druhý správce v recepci chodí za zády, u check-inu stojí na zemi, pohled přes rameno u obsazeného PC (da1c21cc)
- [x] Baterka jako stará žárovka, nažloutlá, se stíny (57f5d4a5)
- [x] Obsluha: podržený mezerník odejde, volný pohled u stánku, úhel mezi stanicemi, vstup ke stánku kolem pultu (1a049e47)
- [x] Šuplík u check-inu vidí všichni; „čeká na recepci“ až u pultu; bez nápisu u spodní hrany; pokojík → recepce 2,4 s (0ff3b0e6)
- [x] Esc v pauze vrací do hry (d76aab07)
- [x] Velký krok 24. 11.: nepřátelé ve dvou, bouřka a plynulé počasí (11b396bc), světlo, podniky postupně, amplióny s rádiem, PDA, znělka, PC jako stroj, tiskárna
- [x] Nešťastní hosté platí míň (1148b80a)
- [x] Karta rezervace v CampMailu (edebe46e)
- [x] Balanc peněz: platí jen hosté, dražší elektřina a mzdy (7929f987)
- [x] Nestabilní kontroly radio_tiers_check a steps_check (44541260)
- [x] Zvuky světa: kapradí, brodění, ptáci, tři zvuky ve stánku (vygenerované, neposlechnuté)
- [x] Starší hotové věci do 22. 11.: docs/historie/todo-do-2026-11-22.md
