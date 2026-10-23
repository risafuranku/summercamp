# Matějův TODO: Liblice, cesta busem, Přistoupim

Moje část hry: mapa okolo kempu (ručně navržená podle mých GPS bodů), cesta autobusem 380
z kempu po dvanáctce přes Přistoupim do Liblic, Liblice a Přistoupim (Vondrův statek). Poznámky z testů piš do sekce **Poznámky z testů**, úkoly do **Úkoly**.

## Jak testovat

- **Hlavní menu → klávesa L → „Bus to Liblice“**: nový kemp (nic se neukládá), stojíš
  na zastávce u kempu, autobus právě přijíždí (stojí 13:18–13:50) a máš v kapse $300
  navíc. Lístek ze žlutého automatu u zastávky ($2) nebo u řidiče s přirážkou ($3),
  v autobuse ho cvakni v oranžovém označovači u dveří, sednout si a jede se.
  Jede se po skutečné silnici: z kempu na dvanáctku (u odbočky Benzina), po ní na
  východ, u Přistoupimi dolů do vsi a nahoru do Liblic. Jízda trvá ~5 minut, hodiny ve
  hře se mezitím zpomalí (jízdní řád počítá 13 minut).
  Pěšky: z kempu cestou na sever k dvanáctce a kamkoli po polích (zdi nejsou).
  Cestou můžeš zmáčknout červené **STOP** na tyči: rozsvítí se STOJÍME a autobus
  zastaví na znamení v Přistoupimi.
- **V Přistoupimi**: oprav panu Vondrovi Škodu 120 v garáži (díly najdeš na statku).
  Zpátky: postav se k zastávce (podle jízdního řádu na tyči), autobus zastaví jen když
  tam stojíš.
- **Celá cesta na screenshotech** (zastávka, jízda, STOP, Přistoupim, oprava, cesta
  zpět; kvůli skutečné délce jízdy běží ~10 min):
  `godot --path godot --resolution 1280x720 res://tools/bus_tour.tscn -- --out=shots`
- **Procházka Liblicemi na screenshotech** (den i noc):
  `godot --path godot --resolution 1280x720 res://tools/lesna_tour.tscn -- --out=shots`
- **Smoke test** před commitem (hledat `SCRIPT ERROR`):
  `godot --headless --path godot --quit-after 400`
  (5× `Parameter "material" is null` v headless režimu je tam i bez našich změn)

## Nástroje

- **Mapa**: `python -I tools/geo/design_world.py` (ručně navržená trasa, pole, lesy,
  rybníky, vysílač; žádná data z OpenStreetMap) udělá `godot/data/geo/world.json`.
  Stavění ve hře: `godot/scripts/geo/geo_world.gd`, trasa a jména míst:
  `godot/scripts/geo/geo_data.gd` (všechna jména na jednom místě). Náhled shora:
  `python tools/geo/preview.py obrazek.png`.

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

- [ ] **Poslechnout hlasy v autobuse** (ElevenLabs, 68 hlášek: babka, děda, žena,
      muž, řidič, Vacek): jestli sedí čeština a hlasy k postavám. Jiný hlas = změnit id
      ve `VOICES` v `tools/audiogen/bus_talk.py`, smazat jeho mp3 v
      `godot/assets/sfx/bus/talk/` a pustit `python tools/audiogen/bus_talk.py` znovu.
      Klíč umí jen mluvit (nevypíše hlasy), takže id hlasů zkoušíme ručně

- [ ] **Poslechnout nové zvuky** (vygenerované přes ElevenLabs, nikdo je ještě neslyšel):
      motor Karosy (`karosa_cruise`, stoupání `karosa_climb`), drnčení, průvan, řazení,
      výmoly, STOP bzučák, štěrk na zastávce, náklaďák, dechovka z rádia
      (`radio_polka` – neměla by mít zpěv), kašel, noviny; Podlesí den/noc, startování
      Škody, volnoběh, benzín, sifon, baterie, jiskra, silonky, kladivo, vrzání.
      Co se nelíbí: upravit prompt v `tools/audiogen/prompts.tsv` a
      `python tools/audiogen/gen.py <id> --force`. Hlasitosti jsou v `bus_ride.gd`
      (`_depart`, `_process`) a `hamlet_trip.gd`.
- [ ] Co-op: Vondrovo svezení Škodou vidí jen ten, kdo jede (druhý správce auto na
      silnici zatím nevidí)
- [ ] Domy v Lesné a v Podlesí nejdou otevřít (interiér mají jen Jednota, hospoda,
      kaple, benzinka, motel)
- [ ] Písma nápisů jsou zatím Windows fonty (Bahnschrift, Arial Narrow) → před vydáním
      nahradit OFL fontem
- [ ] Autobus: zkontrolovat ve hře dveře (otevírání a zvuk), místo řidiče a sedačky;
      zadní dveře jsou jen namalované (neotevírají se)
- [ ] Jestli chceš Benzinu u kempu i na koupi (cigarety v kiosku jako v Liblicích)
- [ ] **Doladit jména** (zatím skutečná: Liblice, Přistoupim, Český Brod, Lstiboř jako
      konečná, kemp Černé jezero; obchod Jednota u Marků): `scripts/geo/geo_data.gd`,
      jízdní řád `bus_timetable.gd` / `timetable_closeup.gd`, cedule
      `tools/artgen/lettering.py`. Skripty se pořád jmenují `town_lesna.gd` a
      `hamlet_podlesi.gd` (jen soubory, ve hře to nevidíš)
- [ ] Podél silnic teď nejsou žádné domy (jen pole, remízky, aleje, vysílač);
      domy jsou jen v Liblicích a na statku v Přistoupimi. Jestli chceš někde u cesty
      ještě něco (JZD kravín, hájovnu, boží muka), napiš kde
- [ ] **Vysílačka v co-opu**: vyzkoušet ve dvou na dvou počítačích (V, jde
      přenastavit v Ovládání); bez vysílačky zatím hlas zblízka není
- [ ] **Rozhlas v kempu**: megafon už je (pokojík za recepcí, G) a hosté na něj
      koukají („!“ nad hlavou); chybí ampliony na sloupech a hlášení jako ve Waterpark
      Tycoonu

## Hotovo

- **Kratší cesta bez OpenStreetMap (23. 10.)**: mapa je ručně navržená přes moje GPS
  body (kemp, Přistoupim, Liblice) a moji červenou trasu, hlavní silnice je zhruba
  poloviční (z kempu do Liblic asi 2,2 km místo 4,5); podél dvanáctky jen pole,
  remízky, potok s olšemi, rybníky, vysílač za plotem a stožáry vedení, žádné domy;
  Liblice začínají hned za zastávkou. OSM už není ani v titulcích. Autobus jede
  rychleji (na dvanáctce kolem 85 km/h), jezdí 4x denně (z Liblic 5:30, 9:35, 13:05,
  18:30; z kempu 6:10, 10:15, 13:45, 19:10), jízda trvá 7 minut. Patníky jsou české
  všude (i na lesní silničce od kempu, ten divný kilometrovník zmizel), automat na
  zastávce prodává jen jízdenky na zastávky linky (+ STORNO) a štípač v autobuse je ve
  výšce očí u dveří

- **Ze seznamu (20. 10.)**: označovač konečně cvakne (zvuk vyrobený skriptem
  `tools/audiogen/synth_sfx.py`); v Konfiguraci jsou Titulky (credits) s „© OpenStreetMap
  contributors“, fonty, Godotem a ElevenLabs; hosté na megafon koukají („!“); do
  Hronkovic ruiny se dá nahlédnout (kuchyň se stolem prostřeným pro jednoho, kalendář
  z Jednoty 1984 a v zadních dveřích na chvíli stojí mokrý kluk; pak je tam mokro a vodní
  řasa; podruhé je židle otočená ke dveřím); Přistoupim a oprava Škody je v co-opu
  společná (co jeden sebere nebo namontuje, má i druhý) a bus v Přistoupimi zastaví
  a počká, i když na zastávce stojí ten druhý; Vondra tě po opravě odveze Škodou nahoru
  do kempu (sedíš vedle něj, mluví česky cestou, po dvanáctce kolem vysílače až
  na zastávku u kempu; po tmě nejede)

- **Autobus a lidi (21. 10.)**: sedačky už neblikají jedna do druhé; za jízdy klikneš
  na jiné volné místo a postava vstane, projde uličkou a sedne si (v co-opu tě ten
  druhý vidí jít); v Přistoupimi občas přistoupí starý Vacek, pozdraví řidiče, sedne si
  za tebe / před tebe / přes uličku, zeptá se „Můžu?" a otočený přes rameno vypráví
  (vysílač Liblice B, Hronkovic kluk u jezera, vesnické řeči); řidič mluví česky;
  všechny hlasy z ElevenLabs (68 hlášek, české titulky anglicky)
- Co-op v autobuse: jedna jízda pro oba (hlášky, kašel, výmoly, náklaďáky, zastavení
  ve stejnou chvíli; STOP od kohokoli zastaví oběma); ověřeno dvěma kopiemi hry
- **Vysílačka a megafon**: v co-opu podržíš V a mluvíš (ostatní tě slyší z vysílačky,
  šum na začátku a konci, tvoje jméno na obrazovce, vysílačka v ruce); megafon leží
  v pokojíku za recepcí u komody, vezmeš ho do batohu a s G tě slyší celý kemp; obě
  klávesy jdou změnit v Ovládání (klikni na klávesu a zmáčkni novou)

- **Karosa ŠM 11 (20. 10.)**: bílo-žlutá jako na fotce, kreslená na metr
  (`tools/artgen/karosa.py`); přední dveře před předním kolem jsou skutečný otvor se
  zárubní, čtyři prosklená křídla se skládají dovnitř se syčením (rychlý start, měkký
  doraz); oknem a dveřmi je vidět řidič, schody, tyč s označovačem; místo řidiče podle
  fotky (sedačka na pérovaném podstavci, koženka se žlutou látkou, opěrka hlavy, velký
  skoro vodorovný volant, černá palubní deska s budíky, dlouhá řadicí páka, šedá trubka
  u schodů) zvenku i zevnitř stejné; řidič od Groka bez namalované sedačky; nikdo už
  nesedí na stejném místě jako ty
- Brigáda u stojanu je na nové Benzině u odbočky ke kempu (Lojza je tam); liblická
  Benzina je jen na tankování (auta vesničanů si natankují sama, do Vondrova kanystru
  natankuješ za $4)
- Co-op: druhý správce vidí autobus, ve kterém jedeš, na silnici
- Lípy (vlastní strom: kmen, široká koruna, listy na kartách) na návsi, v alejích,
  u Přistoupimi; ovocné stromy na zahradách; motel má okna i na bocích a vzadu

- **Skutečná mapa 1:1 (20. 10.)**: okolí kempu z OpenStreetMap (dvanáctka s pruhy a
  patníky, polní cesty, pole s brázdami, louky, lesy, sady, zahrady, rybníky, potoky,
  elektrické vedení na sloupech i stožárech, ~1600 domů, stodol a kůlen z půdorysů,
  stromy v alejích); Přistoupim, Liblice a kraj Českého Brodu. Kemp zůstal stejný
  (zmizely jen jeho vymyšlené kopce na obzoru, stály by v polích)
- Autobus jede celou skutečnou trasu kemp → dvanáctka → Přistoupim (zastávka
  50.0637817 N, 14.8760308 E) → Liblice (50.0713692 N, 14.8845433 E), jako autem:
  70 km/h po dvanáctce, pomaleji ve vsích a v zatáčkách, čas ve hře se zpomalí
- Dobová Benzina na odbočce ke kempu, kde je dnes Orlen (bílá stříška, červený pás
  s BENZINA, dva stojany, kiosek, ceník na sloupu); bílé cedule obcí Přistoupim
  a Liblice
- Vysílač Liblice B na skutečném místě, z kempu vykukuje nad stromy
- Jednota u Marků místo Jednoty, přejmenování v celé hře (jízdní řád, telefonní
  seznam, web ČSAD, hlášky lidí, PC); Lstiboř jako konečná 380

- Lesná podle Liblic: štítové domy z Grok fasád, kostka, vrata statku, stodola se
  sloganem, hasičárna, kaple, náves (rybníček, pomník, zvonička, kříž, lípy, lavičky),
  pole a topoly místo lesa
- České nápisy přímo na zdech (JEDNOTA, SAMOOBSLUHA, HOSTINEC U JEZERA, MOTEL, BENZINA,
  HASIČSKÁ ZBROJNICE, čísla domů, cedule obce, PODLESÍ, zastávka na znamení, STOJÍME)
- Vysílač Liblice B (2 stožáry, v noci červená světla, v mlze zmizí)
- Patníky Z 11 podle normy (za vsí a podél cesty busem)
- Test L: „Bus to Lesna“ + `tools/bus_tour.tscn`
- Cesta na jih: rozpadlý statek u silnice, odbočka do Podlesí, rybník na hrázi s duby
- Zastávka na znamení: tlačítka STOP, STOJÍME, zastavení v Podlesí, občas vystoupí
  i někdo jiný; nástup v Podlesí podle jízdního řádu
- Mapa odemčená: pěšky z kempu po silnici do Podlesí a do Lesné, Lesná má boční
  ulici se zatáčkou doprava, lavičky (jde si na ně sednout)
- Lístky po staru: automat na zastávce (kemp, Lesná), u řidiče s přirážkou,
  oranžový označovač u dveří; automat uvnitř autobusu zmizel
- Autobus: skládací dveře na pantech (otvor v boku, schody, tyč), zrcátka,
  nárazníky, SPZ, cedulka 380; v noci je skly vidět ven
- Cestující: vesničané (babka, děda, paní, pán) sedí čelem po směru jízdy, zezadu
  záda, občas se někdo otočí a promluví; v co-opu stejné u obou
- Jízdní řád jako v Česku (číslo linky v rámečku, zastávky s minutami, hodiny
  a minuty pro pracovní dny a víkend, poznámky)
- Rozpadlý statek blíž u silnice, ať je z okna vidět
- Automat na zastávce a označovač jako přiblížené pohledy: lístek vyjede ze štěrbiny,
  v označovači cvakne a vrátí se s dírkami a časem
- Dveřmi autobusu je vidět dovnitř (schody, tyč s označovačem, sedačky, řidič za
  volantem; kouří vevnitř, ne venku); síťky na zavazadla už nejsou šikmé tyče
- Lidi v buse si povídají (zatím náhradní hlas Windows, titulky anglicky)
- Domy: sokl, parapety, okapy se svodem, hřebenáče, stříšky komínů, antény k
  vysílači, schod a stříška u dveří do dvora, okna i vzadu
- Podlesí: prašná cesta, Vondrův barokní statek, chalupa, garáž se Škodou 120, Trabant,
  prádlo se silonkami, špalek s kladivem, rybníček
- Oprava Škody: benzín z Babetty, baterie z Trabantu, silonky místo klínového řemene,
  startér kladivem, klíček → Vondra dá $50
- Stožáry Liblice B i z okna autobusu (před Lesnou rostou nad poli, cestou zpět za vámi)
- Pomník padlým: PADLÝM a letopočty vytesané do kamene; stříška benzinky z betonu
- Zvuky Karosy a Podlesí vygenerované (ElevenLabs, 28 kusů): motor na rovině
  a do kopce z údolí od jezera, drnčení sílící na výmolech, průvan, řazení, výmoly,
  protijedoucí náklaďák, řidičovo rádio s dechovkou, kašel, noviny, STOP bzučák;
  Podlesí ve dne a v noci, celá oprava Škody i její volnoběh
