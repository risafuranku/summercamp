# Sound

Buses, 3D sound, the mixer and the sounds' own rules.

*Moved out of AGENTS.md on 23. 11. 2026 (one file an area: add what you learn here, not to AGENTS.md).*

## Traps

- **Music and effects are two channels** (`scripts/audio/mixer.gd`, buses "Music" and "Sfx" into
  Master; UNDO.games' bar sets them apart). A bus the game makes is sent on by its name: the
  songs' buses are listed in `MIXER.MUSIC_BUSES`, every other bus is effects; a player left on
  Master is effects. Music on a player of its own: `bus = MIXER.MUSIC`.

- **A SubViewport hears no 3D sound unless `audio_listener_enable_3d` is on** (Godot's
  default is off). The camp's (main.tscn) had it off until 21. 10.: every
  AudioStreamPlayer3D in the camp (the enemies, world_sounds, the radio outside, the
  co-op voices) was silent and nobody could tell from the code. A new viewport with 3D
  sounds turns it on (the office room's only while it is open, else its sounds play
  outdoors); a sound heard through a building's walls goes on `world_sounds.wall_bus(...)`
  (a low-pass bus; the 3D player's own filter only works with distance).

- **Footstep pitch modulation must stay subtle** (whoosh artifact otherwise).

- **The voice in co-op: V is your own voice, a click while it is held the walkie** (Richard
  24. 11.: „když držim V, kliknutím přepínám jestli mluvim lokálně nebo do vysílačky, když jí
  mám v inventáři“; `scripts/coop/voice.gd`): "local" comes out of an AudioStreamPlayer3D on
  the "VoiceLocal" bus at the talker's figure (the room's figure, else the camp's; neither
  seen: silent), full within 3 m, gone at 32 m; the walkie ("radio") needs a walkie in the
  bag at both ends (one goes into every bag as a game for two starts) and sounds out of yours,
  crushed, the squelch with it; the choice stays for the next go; the click is the voice's
  and does nothing else. Test `python godot/tools/voice_coop.py` (the packets only: the
  hidden desktop has no microphone).

- **A 3D sound at the player's ear**: 0.3 m off with `unit_size` 3 it gets +20 dB and every
  one hits `max_db` (+3) alike; set its `unit_size` to the distance it is at
  (`_near_you` in the Silent Man and the Girl) and the gain written is what plays.

- **Paper sounds:** `rooms/task_litter.mp3` is a bag of empty bottles, for clearing a room. A sheet is `desk/paper_pick`, `desk/paper_slide`, a key `desk/keys`, `desk/key_hang`.

## Rozhodnutí 24. 11. 2026: amplióny s rádiem

Richard, 24. 11. 2026: „Napadlo mě že by ampliony mohly kromě hlášení taky vysílat to co běží na
recepci v rádiu? nějak do backgroundu, s hustym efektem starýho rozhlasu. přidávalo by to happiness
(bacha na balanc a mechaniky hry co již existují!) a taky by to mohlo dělat dobrou neplechu během noci“

Kolo 1:
- *Amplióny na sloupech: kromě hlášení megafonem potichu hrají rádio z recepce. Jak s tím má hra
  pracovat?* „Rádio recepce + noční klid“: co hraje rádio v recepci, jde i do ampliónů; hosté v dosahu
  mají pomalu víc zábavy; po 22:00 hraní ruší spáče (hůř se vyspí a hodnotí), tak ho večer ztišíš nebo
  vypneš; v noci amplióny občas samy přeladí na cizí stanici, šum nebo hlasy, jako rádio v recepci při
  děsu.

Kolo 2:
- *Kde stojí sloupy s amplióny?* „Stavíš je v Builderu“: „Rozhlasový sloup“ v Builderu za peníze a
  proud, dosah asi 35 m; kde stojí, tam hraje rádio a lépe je slyšet megafon; rozmístění je tvoje
  rozhodnutí (hudba u ohniště ano, u stanů spáčů opatrně).

Kolo 3:
- *Amplióny v noci: jak silná má být „neplecha“?* „Jen atmosféra“: v noci jen strašidelné zvuky
  z ampliónů, na hosty nemají vliv.

Hotovo 24. 11.: stavba „Rozhlas“ (`pa_pole`, `data/buildings/pa_pole.tres`: 280 Kč×10, proud 2) je
v Builderu mezi zábavou; při stavění ukazuje zelený kruh dosahu 35 m (`builder/map3d.gd`). Ve světě
je to obrázek sloupu od Groka (`assets/textury/world/pa_pole.png`, 7,5 m, `building_models._pa_pole`,
skupina `pa_poles`). `scripts/audio/pa_horns.gd` (main ho tiká) pouští do tří nejbližších sloupů
přesně to, co hraje rádio v recepci (`building_interior.pa_feed`: stejná skladba na stejném místě,
noční nálady sady), na sběrnici „PA“ (úzké pásmo, overdrive, odraz od lesa, dál do RadioMusic,
takže to řídí hlasitost hudby). V noci 23:00–4:00 dvakrát až čtyřikrát amplióny samy přeladí
(šum a pak hlas, kolébavka, hrací strojek…, 7–13 s); kdy, losuje datum noci, takže v co-opu
na obou počítačích stejně. Hosté: pravidla v `core/systems/pa_rules.gd`; vzhůru v dosahu sloupu,
když rádio hraje, mají +0,08 zábavy za minutu, ale jen do 60 (oheň dá 45 za návštěvu a může
do 100); od 22 do 6 hodin hrající sloup u ubytování lehce spícího hosta (důchodce, Ticháč,
rodina, slečna) ruší jako 0,7 hlučné party, ráno si postěžuje. Vypnuté rádio v recepci = ticho
i spánek. Megafon: hosté u každého sloupu se otočí (`voice._alert_guests`) a druhý hráč slyší
hlas i z nejbližšího ampliónu (`voice._make_rx` „pa_player“). Test `tools/pa_check.tscn`, snímky
`shot_driver --scenario=pa_pole` (den, dálka, noc, vynucené přeladění).
