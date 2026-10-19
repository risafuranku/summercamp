# Matějův TODO: Lesná, cesta busem, Podlesí

Moje část hry: celé město (Lesná), cesta autobusem 380 z kempu do města a osada
Podlesí po cestě. Poznámky z testů piš do sekce **Poznámky z testů**, úkoly do **Úkoly**.

## Jak testovat

- **Hlavní menu → klávesa L → „Bus to Lesna“**: nový kemp (nic se neukládá), stojíš
  na zastávce u kempu, autobus právě přijíždí (stojí 13:20–13:50) a máš v kapse $300
  navíc. Lístek z automatu uvnitř (LESNA, nebo PODL = Podlesí), sednout si a jede se.
  Cestou můžeš zmáčknout červené **STOP** na tyči: rozsvítí se STOJÍME a autobus
  zastaví na znamení v Podlesí.
- **V Podlesí**: oprav panu Vondrovi Škodu 120 v garáži (díly najdeš v osadě a
  u rozpadlého statku u silnice). Zpátky: postav se k zastávce (podle jízdního řádu na
  tyči), autobus zastaví jen když tam stojíš.
- **Celá cesta na screenshotech** (zastávka, jízda, STOP, Podlesí, oprava, cesta zpět):
  `godot --path godot --resolution 1280x720 res://tools/bus_tour.tscn -- --out=shots`
- **Procházka Lesnou na screenshotech** (den i noc):
  `godot --path godot --resolution 1280x720 res://tools/lesna_tour.tscn -- --out=shots`
- **Smoke test** před commitem (hledat `SCRIPT ERROR`):
  `godot --headless --path godot --quit-after 400`
  (5× `Parameter "material" is null` v headless režimu je tam i bez našich změn)

## Nástroje

- **Grafika (Grok přes Cursor CLI)**: příkaz je `cursor-agent` (ne `agent`, to je u mě
  Grok CLI). Řádek do `tools/artgen/prompts.tsv`, pak `bash tools/artgen/gen.sh <id>`
  (jeden obrázek ~2–5 min, víc najednou `tools/artgen/queue.sh id1 id2 ...`).
- **Budovy**: pohled zepředu na purpurovém pozadí (řádky `lib_*`), pak
  `python tools/artgen/town_facades.py` → textura, okna na večer, boční zdi, rozměry.
  Okna se měří ručně v `FRONTS` (zlomky plátna).
- **Nápisy na budovách**: kreslí je `python tools/artgen/lettering.py` (Grok česky psát
  neumí). Nový nápis = nový řádek v `SIGNS`.
- **Sprity a close-upy**: `tools/artgen/town_art.py` (`sprite()`, `picture()`).
- **Zvuky (ElevenLabs)**: řádek do `tools/audiogen/prompts.tsv`, pak
  `python tools/audiogen/gen.py <id>`. Klíč je v `tools/audiogen/.env` (mimo git,
  nikdy necommitovat).

## Poznámky z testů

- (sem piš, co při testu uvidíš)

## Úkoly

- [ ] **Zvuky Karosy a Podlesí ještě nejsou vygenerované**: v `tools/audiogen/.env` je
      ID klíče, ne klíč (ElevenLabs: „API key ID used as API key“). Pravý klíč začíná
      `sk_` a ElevenLabs ho ukáže jen jednou při vytvoření (Developers → API Keys →
      Create API key). Až tam bude pravý, stačí:
      `python tools/audiogen/gen.py karosa_cruise karosa_climb karosa_rattle karosa_wind karosa_gear karosa_pothole karosa_indicator karosa_stop_bell karosa_gravel karosa_truck bus_radio_polka bus_cough bus_newspaper hamlet_day hamlet_night ruin_creak car_crank_fail car_click car_start car_idle hammer_hit fuel_pour siphon battery_clunk spark stocking garage_door pick_up`
      Kód je na ně připravený (do té doby hraje starý ride.mp3 a v Podlesí je ticho).
- [ ] Co-op: Podlesí a oprava auta zatím jen pro jednoho; druhý správce tě tam uvidí,
      ale díly a stav auta se nesdílí a autobus v Podlesí na něj nečeká
- [ ] Opravená Škoda zatím jen stojí a kouří; chtělo by to odměnu navíc (svézt se
      s Vondrou do Lesné nebo do kempu?)
- [ ] Domy v Lesné a v Podlesí nejdou otevřít (interiér mají jen Jednota, hospoda,
      kaple, benzinka, motel)
- [ ] Rozpadlý statek (Hronkovic) jde jen „okouknout“ – dovnitř by se hodil malý
      strašidelný moment
- [ ] Písma nápisů jsou zatím Windows fonty (Bahnschrift, Arial Narrow) → před vydáním
      nahradit OFL fontem
- [ ] Lípy na návsi a stromy v Podlesí jsou koule z břízy kempu, chtělo by to vlastní
      stromy
- [ ] Motel má tmavé holé boční zdi
- [ ] Jméno města: zatím Lesna (případně přejmenovat i v jízdním řádu a hláškách)

## Hotovo

- Lesná podle Liblic: štítové domy z Grok fasád, kostka, vrata statku, stodola se
  sloganem, hasičárna, kaple, náves (rybníček, pomník, zvonička, kříž, lípy, lavičky),
  pole a topoly místo lesa
- České nápisy přímo na zdech (JEDNOTA, SAMOOBSLUHA, HOSTINEC U JEZERA, MOTEL, BENZINA,
  HASIČSKÁ ZBROJNICE, čísla domů, cedule obce, PODLESÍ, zastávka na znamení, STOJÍME)
- Vysílač Liblice B (2 stožáry, v noci červená světla, v mlze zmizí)
- Patníky Z 11 podle normy (za vsí a podél cesty busem)
- Test L: „Bus to Lesna“ + `tools/bus_tour.tscn`
- Cesta na jih: rozpadlý statek u silnice, odbočka do Podlesí, rybník na hrázi s duby
- Zastávka na znamení: tlačítka STOP, STOJÍME, zastavení v Podlesí, jízdenka do
  Podlesí, občas vystoupí i někdo jiný; nástup v Podlesí podle jízdního řádu
- Podlesí: prašná cesta, Vondrův barokní statek, chalupa, garáž se Škodou 120, Trabant,
  prádlo se silonkami, špalek s kladivem, rybníček
- Oprava Škody: benzín z Babetty, baterie z Trabantu, silonky místo klínového řemene,
  startér kladivem, klíček → Vondra dá $50
- Stožáry Liblice B i z okna autobusu (před Lesnou rostou nad poli, cestou zpět za vámi)
- Pomník padlým: PADLÝM a letopočty vytesané do kamene; stříška benzinky z betonu
- Zvuky Karosy v kódu: motor, drnčení, průvan, řazení, výmoly, protijedoucí náklaďák,
  řidičovo rádio s dechovkou, kašel, noviny (čekají na vygenerování)
