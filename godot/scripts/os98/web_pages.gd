extends RefCounted

## The web of 1998 as the camp's modem sees it: a portal, the three software sites the
## camp needs, the district, the shop, the pub, the bus, the local paper's archive, the
## camp's own home page with its guest book, and a teenager's ghost webring.
##
## Pages are BBCode with shorthands the browser expands:
##   {target|text}   a link; target is a URL or download://FILE.EXE
##   {{token}}       live content filled in by the browser (counter, guestbook, ...)
##   {{img:name:w}}  a picture from assets/textury/web (Grok, tools/artgen/web_image.py),
##                   w pixels wide; it comes down the modem after the text, interlaced
##   {{banner:id:url}} a 468x60 GIF ad (tools/artgen/web_extras.py) that turns its frames
##                   and links to url
##   [blink], [marquee w=440 speed=40], [rainbow]   what home pages did with text
## A page may have "tile": a background picture from assets/textury/web, repeated.
## Keys are URLs without "http://", "www." and the trailing slash.

const HOME := "bohemia-online.cz"

const UNDER := "[bgcolor=#ffd800][color=#000000] [b]/!\\ UNDER CONSTRUCTION /!\\[/b] [/color][/bgcolor]"
const HR := "[color=#808080]________________________________________________________________[/color]"

## The browser's Favorites menu.
const FAVORITES := ["bohemia-online.cz", "bohemia-online.cz/weather", "kuryr-hlubocany.cz", "cerne-jezero.cz", "povodi-hlubocany.cz", "volny.cz/~strasidla", "volny.cz/~infravrany"]

## The search engine's masthead, on its front page and over the results.
const SEARCH_HEAD := """[center][font_size=26][b][color=#003399]Bohemia[/color][color=#cc0000]Search[/color][/b][/font_size]
[color=#666666]43 812 Czech pages in our index[/color][/center]"""

## Words the portal's search knows, per page.
const INDEX := {
	"stavitel98.cz": "builder stavitel software shareware plan site camp design build download",
	"campgrid.cz": "campstat campgrid power electricity bill meter tariff download",
	"okres-hlubocany.cz": "district office okres hlubocany guestrack register guests decree forest",
	"okres-hlubocany.cz/register": "guestrack register guests download act",
	"cerne-jezero.cz": "camp cerne jezero black lake vera karel guestbook",
	"cerne-jezero.cz/guestbook": "guestbook guests camp",
	"hostinec-u-jezera.cz": "pub hostinec beer food karbanatky meatballs",
	"jednota-lesna.cz": "shop jednota batteries bulbs fuses paraffin bread",
	"csad-jihlava.cz/380": "bus timetable 380 csad lesna",
	"kuryr-hlubocany.cz": "newspaper courier news archive",
	"kuryr-hlubocany.cz/1987": "1987 girl missing jana search camp",
	"kuryr-hlubocany.cz/1991": "1991 photographer camera flash missing",
	"kuryr-hlubocany.cz/1984": "1984 man hat silent stranger cabin",
	"kuryr-hlubocany.cz/1993": "1993 pipes shoe red sewer works",
	"kuryr-hlubocany.cz/1996": "1996 antlers antlered fence gamekeeper legend parohac",
	"kuryr-hlubocany.cz/1998": "1998 inspection register camp closing",
	"volny.cz/~strasidla": "ghosts legends webring strasidla hat girl antlers photographer",
	"volny.cz/~infravrany": "band music infravrany rock metal gig disco demo tape concert lukas",
	"povodi-hlubocany.cz": "reservoir lake water board dam keeper hruby boat boathouse sluice level fishing shore",
	"cerne-jezero.cz/team": "karel vera team leaders staff camp photos",
	"bohemia-online.cz/weather": "weather forecast rain storm fog sun",
}

const PAGES := {
	# ── the portal ─────────────────────────────────────────────────────────────
	"bohemia-online.cz": {
		"title": "Bohemia Online - start",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": """[center]{{banner:mobile:bohemiatel.cz}}
[font_size=24][b][color=#003399]BOHEMIA[/color] [color=#cc0000]ONLINE[/color][/b][/font_size]
[color=#666666]your way into the Internet since 1996[/color][/center]
[bgcolor=#003399][color=#ffff00][b][marquee w=560 speed=36]+++ Nagano gold: the hockey team is home +++ Okna 98 in the shops +++ Fog tonight +++[/marquee][/b][/color][/bgcolor]
{{search}}
[table=2]
[cell][b]SOFTWARE[/b]
 {bohemia-online.cz/search|BohemiaSearch} - find it on the web
 {stavitel98.cz|Stavitel software} - Builder 98
 {campgrid.cz|CampGrid} - for power customers
 {okres-hlubocany.cz/register|GuestRack} - guest register

[b]OUR REGION[/b]
 {okres-hlubocany.cz|District Office Hlubocany}
 {kuryr-hlubocany.cz|Hlubocany Courier} - news
 {csad-jihlava.cz/380|Bus timetables} CSAD Jihlava
 {jednota-lesna.cz|Jednota Lesna} - shop
 {hostinec-u-jezera.cz|Hostinec U Jezera} - pub
 {povodi-hlubocany.cz|Water Board} - the reservoir
[/cell]
[cell][b]LEISURE[/b]
 {cerne-jezero.cz|Kemp Cerne jezero} - summer camp
 {volny.cz/~strasidla|Ghosts of South Bohemia}
 {volny.cz/~infravrany|INFRAVRANY} - band  [color=#cc0000][blink]NEW![/blink][/color]
 {bohemia-online.cz/weather|Weather}

[b]TODAY[/b]
 Day {{day}}, {{time}}
 Connected at 33,600 bps.
 Your call costs 1.20 Kc a minute.
[/cell]
[/table]
""" + HR + """
[center][color=#666666]Bohemia Online s.r.o., Ceske Budejovice  |  helpline 0638 41 41 41 (weekdays 8-16)[/color][/center]""",
	},
	"bohemia-online.cz/weather": {
		"title": "Bohemia Online - Weather",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": """[center]{{banner:beer:jednota-lesna.cz}}[/center]
[b][font_size=18]WEATHER - SOUTH BOHEMIA[/font_size][/b]   [color=#666666]{{date}}, {{time}}[/color]
""" + HR + """
{{weather}}
[b]THE NEXT DAYS[/b]
{{forecast}}

[color=#666666]Data: Hydrometeorological Institute, station Cervena hora. The station at the reservoir has not reported since 1991.[/color]

{bohemia-online.cz|<< Back to Bohemia Online}""",
	},

	"bohemia-online.cz/search": {
		"title": "BohemiaSearch",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": SEARCH_HEAD + """
[center][bgcolor=#e0e8ff] [b]Type what you are looking for in the Address bar and press Go.[/b] [/bgcolor][/center]
""" + HR + """
[table=2]
[cell][b]COMPUTERS[/b]
 {stavitel98.cz|Software}, {campgrid.cz|Utilities}

[b]NEWS[/b]
 {kuryr-hlubocany.cz|Regional papers}, {bohemia-online.cz/weather|Weather}

[b]TRAVEL[/b]
 {csad-jihlava.cz/380|Buses}, {cerne-jezero.cz|Camps}, {povodi-hlubocany.cz|Lakes}
[/cell]
[cell][b]GOVERNMENT[/b]
 {okres-hlubocany.cz|District offices}

[b]SHOPPING[/b]
 {jednota-lesna.cz|Shops}, {hostinec-u-jezera.cz|Pubs}

[b]PERSONAL PAGES[/b]
 {volny.cz/~strasidla|Mysteries}, {volny.cz/~infravrany|Music}
[/cell]
[/table]
""" + HR + """
[center][color=#666666]popular today:[/color] {search?q=builder|builder}  {search?q=weather|weather}  {search?q=1987|1987}  {search?q=hruby|hruby}[/center]""",
	},

	# ── software ───────────────────────────────────────────────────────────────
	"stavitel98.cz": {
		"title": "Stavitel software - Builder 98",
		"bg": "#c0c0c0", "fg": "#000000", "link": "#000080",
		"body": """[center][font_size=24][b][color=#800000]STAVITEL[/color] software[/b][/font_size]
[i]planning software for builders, municipalities and recreational facilities[/i][/center]
""" + HR + """
[b][font_size=16]BUILDER 98[/font_size][/b]  version 1.2  [color=#008000](new!)[/color]
[center]{{img:web_box:200}}[/center]

Plan your site tile by tile: tents, chalets, sanitary blocks, catering, attractions, paths and lighting. Builder 98 keeps the plan in step with the camp's telemetry, so what you draw is what gets built.

 * shows running costs before you build
 * upgrades and demolition
 * works on any 486 with 8 MB of memory and Okna 95 or 98

[b]DOWNLOAD[/b]
 {download://BLDR98SW.EXE|BLDR98SW.EXE} - shareware, 96 KB. Full version for 30 days.
 Registration: 990 Kc by postal order. Your key comes by post.

[b]QUESTIONS[/b]
[b]Q: Builder will not start in the evening.[/b]
A: Recreational facilities have a site licence for Builder 98. It may be used between 06:30 and 20:00 only. This is in the licence and cannot be changed. Please do not write to us about it any more.

[b]Q: Where are the other buildings from the catalogue?[/b]
A: Some buildings appear in Builder only when your site has reached a certain size or rating.

[b]Q: My site plan shows a building I did not build.[/b]
A: Delete it and draw your own.
""" + HR + """
Stavitel software, Brnenska 14, Jihlava  |  {bohemia-online.cz|Bohemia Online}  |  You are visitor no. {{counter}}""",
	},
	"campgrid.cz": {
		"title": "CampGrid - CampStat 98",
		"bg": "#ffffff", "fg": "#000000", "link": "#006633",
		"body": """[bgcolor=#006633][color=#ffffff][b][font_size=20] CampGrid [/font_size][/b] for customers of Hlubocany District Power [/color][/bgcolor]

[b]CampStat 98[/b] - your electricity at a glance
 * what every building draws, live
 * your bills, and you pay them right in the program
 * the condition of your buildings and the maintenance crew

 {download://CAMPSTAT.EXE|Download CAMPSTAT.EXE} (48 KB, free for our customers)

[b]TARIFF 1998[/b] (recreational facilities)
[code]  energy                  per kWh    depends on load
  standing charge         per day    fixed
  bill issued             daily      20:00
  payable within          3 days[/code]

[color=#cc0000][b]NOTICE:[/b] if a bill is not paid on time, the supply is cut off without further notice. Reconnection is made when every overdue bill has been paid.[/color]

Faults: 0663 30 199 (we do not go out to the reservoir after dark).
""" + HR + """
{bohemia-online.cz|Bohemia Online}""",
	},

	# ── the district ───────────────────────────────────────────────────────────
	"okres-hlubocany.cz": {
		"title": "District Office Hlubocany",
		"bg": "#ffffee", "fg": "#000000", "link": "#0000cc",
		"body": """[center][b][font_size=18]DISTRICT OFFICE HLUBOCANY[/font_size][/b]
Namesti Miru 1, 594 01 Hlubocany[/center]
""" + HR + """
[b]NOTICE BOARD[/b]
 * {okres-hlubocany.cz/register|Accommodation facilities: guest register (GuestRack 98)}
 * Decree no. 4/1988: the forest around the reservoir is closed to the public from 22:00 to 05:00. [i]Still in force.[/i]
 * The bridge at Lesna is closed to vehicles over 3.5 t.
 * Lost property: camera, Praktica MTL 5, found 1991 by the reservoir fence. Unclaimed. Ask at room 12.
 * The lake keeper's post at Cerne jezero is vacant. Applications to room 12.

[b]OFFICE HOURS[/b]
Mon, Wed  8:00-17:00     Tue, Thu  8:00-14:00     Fri  closed
""" + HR + """
{bohemia-online.cz|Bohemia Online}""",
	},
	"okres-hlubocany.cz/register": {
		"title": "District Office - Guest register",
		"bg": "#ffffee", "fg": "#000000", "link": "#0000cc",
		"body": """[b][font_size=16]GUEST REGISTER FOR ACCOMMODATION FACILITIES[/font_size][/b]

Every facility in the district where people stay the night must keep a register of guests (Act no. 135/1993, par. 9). The register shows who is staying, from when, until when and where they sleep.

The District Office supplies the program GuestRack 98 free of charge:
 {download://GUESTRAK.EXE|GUESTRAK.EXE} (72 KB)

Please note:
 * Enter every person who stays the night.
 * The register cannot be deleted.
 * Persons found in a facility who are not in the register are not the responsibility of the District Office.

{okres-hlubocany.cz|<< District Office}""",
	},

	# ── local life ─────────────────────────────────────────────────────────────
	"jednota-lesna.cz": {
		"title": "Jednota Lesna",
		"bg": "#ffffff", "fg": "#000000", "link": "#cc0000",
		"body": """[center][bgcolor=#cc0000][color=#ffffff][b][font_size=20] JEDNOTA [/font_size][/b][/color][/bgcolor]
[b]Lesna 42[/b] - your shop by the reservoir
{{img:web_shop:224}}
{{banner:beer:hostinec-u-jezera.cz}}[/center]

[b]OPEN[/b]  Mon-Fri 7:00-17:00, Sat 7:00-11:00

[b]PRICES THIS WEEK[/b]
[code]bread, 1 kg ................. 12.90
milk, 1 l ..................... 9.50
paraffin, 1 l ................ 24.00
bulb 60 W ..................... 8.00
fuse 16 A .................... 15.00
batteries R20 .................. --
candles, 10 ................... 19.00[/code]

[color=#cc0000][b]Batteries are sold out until further notice.[/b] Please stop asking.[/color]

We do not deliver to the camp after the season.
""" + HR + """
{bohemia-online.cz|Bohemia Online}""",
	},
	"hostinec-u-jezera.cz": {
		"title": "Hostinec U Jezera",
		"tile": "tile_wood",
		"bg": "#2b1a0e", "fg": "#f0e0b0", "link": "#ffcc66",
		"body": """[center][font_size=22][b]Hostinec U Jezera[/b][/font_size]
[i]beer, a warm meal and a roof since 1921[/i]
{{img:web_pub:224}}[/center]
""" + HR + """
[b]ON TAP[/b]  Budvar 10, Budvar 12, Kofola

[b]KITCHEN[/b]
 Goulash with dumplings ............. 45 Kc
 Fried cheese, chips ................ 52 Kc
 [b]Karbanatky to our own recipe[/b] ...... 39 Kc   [i]house speciality[/i]
 Pickled sausage .................... 25 Kc

[b]OPEN[/b]  every day 10:00-22:00
We do not serve after ten. Please do not knock.

The cellar is not open to guests.

[i]Wanted: supplier of meat. Regular, any quantity. Ask at the bar.[/i]
""" + HR + """
{bohemia-online.cz|Bohemia Online}  |  you are guest no. {{counter}}""",
	},
	"csad-jihlava.cz/380": {
		"title": "CSAD Jihlava - line 380",
		"bg": "#ffffff", "fg": "#000000", "link": "#0000ee",
		"body": """[b]CSAD Jihlava a.s. - TIMETABLE[/b]
[b]Line 380   Hlubocany - Lesna - Cerne jezero, camp[/b]   valid from 31.5.1998
[center]{{img:web_bus:224}}[/center]

[code]                       Mo-Fr  Mo-Fr  daily  daily  daily    +
Hlubocany, bus station  6:15   9:40  13:05  16:30  18:40  23:30
Lesna, Jednota          6:31   9:56  13:21  16:46  18:56  23:46
Cerne jezero, dam       6:40  10:05  13:30  16:55  19:05  23:55
Cerne jezero, camp      6:44  10:09  13:34  16:59  19:09    |[/code]

[b]+[/b] works bus. It does not stop at Cerne jezero, camp. Please do not wave at it.

The last bus from the camp to Hlubocany leaves at 19:15.
""" + HR + """
{bohemia-online.cz|Bohemia Online}""",
	},

	# ── the camp ───────────────────────────────────────────────────────────────
	"cerne-jezero.cz": {
		"title": "KEMP CERNE JEZERO !!!",
		"tile": "tile_stars",
		"bg": "#000040", "fg": "#ffff99", "link": "#66ffff",
		"body": """[center][font_size=24][b][rainbow freq=0.15 sat=0.7 val=1.0]WELCOME TO KEMP CERNE JEZERO!!![/rainbow][/b][/font_size]
[color=#ffffff]the best camp in the Vysocina woods - right by the water[/color]
{{img:web_camp:224}}
{{img:web_digger:56}}""" + UNDER + """[/center]

[b]WHAT WE HAVE[/b]
 * tents and wooden cabins
 * clean lake for swimming (the water is cold!!)
 * campfire every evening, disco on Saturdays
 * night games with Karel ;-)
 * boats on the lake  [color=#ff3333][blink]NEW[/blink][/color]

{cerne-jezero.cz/team|>> MEET OUR TEAM <<}

[center]{{img:web_campfire:224}}
[color=#ffffff][i]Karel and the guitar, summer 97[/i][/color][/center]

[b]PRICES 1997[/b]
 tent ................ 60 Kc a night
 cabin .............. 120 Kc a night
 dogs free

[b]HOW TO GET HERE[/b]  bus 380 from Hlubocany, stop "Cerne jezero, camp". {csad-jihlava.cz/380|timetable}

{cerne-jezero.cz/guestbook|>>> SIGN OUR GUEST BOOK <<<}

[center][color=#888888]you are visitor no.[/color] {{counter}}
[color=#888888]made by Vera in Notepad. best viewed in Beeternet Explorer at 640x480[/color][/center]""",
	},
	"cerne-jezero.cz/guestbook": {
		"title": "KEMP CERNE JEZERO - guest book",
		"tile": "tile_stars",
		"bg": "#000040", "fg": "#ffff99", "link": "#66ffff",
		"body": """[center][font_size=20][b]GUEST BOOK[/b][/font_size]
[color=#ffffff]write something nice! (Vera reads every entry)[/color][/center]
{{guestbook}}
{cerne-jezero.cz|<< back to the camp}""",
	},

	"cerne-jezero.cz/team": {
		"title": "KEMP CERNE JEZERO - our team",
		"tile": "tile_stars",
		"bg": "#000040", "fg": "#ffff99", "link": "#66ffff",
		"body": """[center][font_size=20][b]OUR TEAM[/b][/font_size][/center]

[b][color=#66ff66]KAREL[/color][/b] - camp leader since 1979
[center]{{img:web_karel:240}}
[color=#ffffff][i]Karel and the July group by the notice board[/i][/color][/center]
Karel knows every path in the woods and every song in the songbook. He runs the night games and the campfire. Ask him about the reservoir and he will tell you how they built the dam (it takes a while!!)

[b][color=#66ff66]VERA[/color][/b] - reception, cooking, everything else
I made this page :-) I do the bookings, the shop runs and the kitchen. If you need anything come to reception. The bell works now!

[b][color=#66ff66]MR HRUBY[/color][/b] - boats
Mr Hruby looks after the boats and the jetty. He lives in the boathouse across the lake and rows over in the morning. Please do not take the boats without him.

[color=#888888](this page was last updated 22.6.1993)[/color]

{cerne-jezero.cz|<< back to the camp}""",
	},

	# ── the paper ──────────────────────────────────────────────────────────────
	"kuryr-hlubocany.cz": {
		"title": "Hlubocany Courier - archive",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[center]{{banner:cd:bohemica.cz}}[/center]
[font_size=22][b]HLUBOCANY COURIER[/b][/font_size]
[i]weekly for the Hlubocany district - archive on the Internet[/i]
""" + HR + """
[b]FROM THE ARCHIVE[/b]  (selected articles; the rest at the district library)

 {kuryr-hlubocany.cz/1998|1998}  District inspects Cerne jezero camp
 {kuryr-hlubocany.cz/1996|1996}  From our history: the Antlered Man
 {kuryr-hlubocany.cz/1993|1993}  Works on the camp sewer finished
 {kuryr-hlubocany.cz/1991|1991}  Photographer missing in the reservoir woods
 {kuryr-hlubocany.cz/1987|1987}  Search for girl from summer camp goes on
 {kuryr-hlubocany.cz/1984|1984}  The stranger in cabin 3
""" + HR + """
{bohemia-online.cz|Bohemia Online}""",
	},
	"kuryr-hlubocany.cz/1987": {
		"title": "Courier 1987 - Search goes on",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 14 August 1987[/color]
[font_size=18][b]Search for girl from summer camp goes on[/b][/font_size]
[center]{{img:news_1987:240}}
[color=#666666][i]Volunteers and soldiers search the woods above the dam.[/i][/color][/center]

Police, soldiers and volunteers from Lesna have searched the woods around the Cerne jezero reservoir for a fourth day. Jana K. (11) from Prague was last seen on Monday evening during the camp's evening programme.

"She was standing at the edge of the lights, where the path goes into the trees," said one of the leaders. "We counted the children at ten and she was there. At midnight we counted again and we had one more than we should have. Then one less."

Divers searched the reservoir by the dam. The camp's leader, Karel H., told the Courier he would not speak about it.

Jana was wearing a blue tracksuit and [b]red sandals[/b]. Anyone who has seen her should call the police at Hlubocany.

{kuryr-hlubocany.cz|<< archive}""",
	},
	"kuryr-hlubocany.cz/1991": {
		"title": "Courier 1991 - Photographer missing",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 3 October 1991[/color]
[font_size=18][b]Photographer missing in the reservoir woods[/b][/font_size]
[center]{{img:news_1991:240}}
[color=#666666][i]The camera as it was found, by the fence above the camp.[/i][/color][/center]

Ludek S., a nature photographer from Jihlava, has not come back from a night trip to photograph the deer rut at Cerne jezero. His car was found at the dam.

His camera stood on its tripod by the fence above the camp, pointing into the forest. The film had been used to the end: thirty-six photographs, all taken with the flash, all of the trees.

"On the last few frames there is someone standing between the trees," said a police spokesman. "Each one a bit closer. It will be a reflection of the flash." The police do not say whether the person in the photographs was facing the camera.

The camera has not been claimed and is kept at the District Office.

{kuryr-hlubocany.cz|<< archive}""",
	},
	"kuryr-hlubocany.cz/1984": {
		"title": "Courier 1984 - The stranger in cabin 3",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 21 July 1984[/color]
[font_size=18][b]The stranger in cabin 3[/b][/font_size]
[center]{{img:news_1984:240}}
[color=#666666][i]Cabin 3, the morning after. Photo: camp staff.[/i][/color][/center]

Staff at the Cerne jezero camp found a man sitting on the bed in cabin 3 one morning. The cabin had been empty and locked all week. The man wore a dark coat and a hat, and he did not say a word.

He was taken to the hospital in Jihlava. Nobody of his description had been reported missing. During the night he left his bed and the hospital, and nobody saw him go.

"He was polite," said a nurse. "He just stood behind you when you were writing. You did not hear him come. When you turned round he was just standing there."

{kuryr-hlubocany.cz|<< archive}""",
	},
	"kuryr-hlubocany.cz/1993": {
		"title": "Courier 1993 - Sewer works finished",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 9 June 1993[/color]
[font_size=18][b]Works on the camp sewer finished[/b][/font_size]
[center]{{img:news_1993:240}}
[color=#666666][i]New pipes going in below the shower block.[/i][/color][/center]

The water board has finished replacing the old sewer pipes at Cerne jezero camp. The pipes from 1962 were blocked along most of their length.

Workers said the blockage was "mostly leaves and hair". In the pipe under the shower block they found a child's [b]red sandal[/b]. The police took a look at it and gave it back to the camp. "It is not connected to anything," a spokesman said.

The lake keeper, Mr H., who had helped the workers clear the old pipes, has not been seen since the works ended. His boat is still tied up at the camp jetty.

The camp will open as usual on 1 July.

{kuryr-hlubocany.cz|<< archive}""",
	},
	"kuryr-hlubocany.cz/1996": {
		"title": "Courier 1996 - The Antlered Man",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 30 October 1996 - From our history[/color]
[font_size=18][b]The Antlered Man[/b][/font_size]
[center]{{img:news_1996:240}}
[color=#666666][i]Parohac on a woodcut from Lesna, 19th century (district museum).[/i][/color][/center]

Every village by the reservoir knows him. Children are told that "Parohac" walks the forest fence at night and takes those who are out after dark.

The oldest written mention is in the gamekeeper's book from Lesna, autumn 1962, the year the reservoir was filled: [i]"Someone walked the new fence all night. Tall, with antlers like a twelve-pointer. The dogs would not go out. In the morning no tracks except along the fence."[/i]

The gamekeeper's book ends a few weeks later. The fence was built to keep people away from the water. It is still there.

{kuryr-hlubocany.cz|<< archive}""",
	},
	"kuryr-hlubocany.cz/1998": {
		"title": "Courier 1998 - District inspects camp",
		"tile": "tile_paper",
		"bg": "#f4f0e6", "fg": "#1a1a1a", "link": "#7a0000",
		"body": """[color=#666666]Hlubocany Courier, 2 September 1998[/color]
[font_size=18][b]District inspects Cerne jezero camp[/b][/font_size]
[center]{{img:news_1998:240}}
[color=#666666][i]The inspectors at the camp office.[/i][/color][/center]

Inspectors from the District Office visited the Cerne jezero camp after complaints about the guest register. "The register says one thing and the beds say another," said the head of the accommodation department. "There were nights with more people in the camp than in the register."

The operator, Vera K., has left the camp. The camp computer and the register stay at the site. The district is looking for a new operator for next season.

The former leader, Karel H., could not be reached.

{kuryr-hlubocany.cz|<< archive}""",
	},

	# ── the webring ───────────────────────────────────────────────────────────
	"volny.cz/~strasidla": {
		"title": "GHOSTS OF SOUTH BOHEMIA",
		"bg": "#000000", "fg": "#c0c0c0", "link": "#ff3333",
		"body": """[center]{{img:web_spooky:420}}
[font_size=24][b][color=#ff0000]GHOSTS[/color] OF SOUTH BOHEMIA[/b][/font_size]
[color=#808080]by Kuba (14). all TRUE stories. if you dont believe it go there at night[/color][/center]
""" + HR + """
[b][color=#ffffff]CERNE JEZERO (the reservoir camp)[/color][/b]
{{img:web_ghost:40}} my uncle says this is the worst place in the district. there are EIGHT (my sister says seven but she is a baby)

[color=#ff6666]THE MAN IN THE HAT[/color] - comes up behind you. you hear steps on the gravel and when you stop he stops. you have to turn round and look at him or he gets closer. he never talks. he just whispers when he is right behind you

[color=#ff6666]THE PHOTOGRAPHER[/color] - you see a little red light in the trees and hear beeping. its his camera. if he takes your photo you are in his film for ever. DONT LOOK at the flash

[color=#ff6666]THE GIRL[/color] - she stands where the lamp light ends. she went missing in 1987. if you look away she comes closer. she is looking for her shoe

[color=#ff6666]THE WHISTLER[/color] - an old tramp who never came back from the potlach in 1974. you hear him whistling Okoli Zlate reky in the woods. DONT GO TO HIM. stand in the light and he stops in the middle of the song

[color=#ff6666]THE EXTRA CHILD[/color] - count the kids at the camp. there is always one more. it stands with its back to you and hums. if you shine a torch on it it turns round. nobody has said what it looks like from the front

[color=#ff6666]THE BASKET MAN[/color] - goes for mushrooms at 3 in the morning. my grandma met him and she says you have to stand still like a tree, he only sees what moves. she never went picking again (she says the boletes were not boletes)

[color=#ff6666]PAROHAC[/color] - the antlered man on the fence. hes the oldest. he doesnt go into the light

[color=#ff6666]THE KEEPER[/color] - Mr Hruby who did the boats. he went down the drains in 1993 when they put the new pipes in and he never came up. my uncle says sometimes you hear knocking in the sewer like somebody wants to be let out. DONT KNOCK BACK. he cant see anymore, he goes for the noise

my uncle says they only come when there are too many people of the same sort in the camp. i dont know what that means

my cousin plays in a band, check them out: {volny.cz/~infravrany|INFRAVRANY}
""" + HR + """
[center][color=#808080]this site is part of the[/color] [b]SOUTH BOHEMIA GHOST RING[/b]
{volny.cz/~blatna|<< previous}  |  {volny.cz/~strasidla|random}  |  {volny.cz/~zamek|next >>}
[color=#808080]you are visitor[/color] {{counter}}[/center]""",
	},

	# ── the band, the reservoir ───────────────────────────────────────────────
	"volny.cz/~infravrany": {
		"title": "..:: INFRAVRANY ::.. official page",
		"tile": "tile_stars",
		"bg": "#000000", "fg": "#d0d0d0", "link": "#ff9900",
		"body": """[center][font_size=26][b][color=#cc0000]..:: INFRAVRANY ::..[/color][/b][/font_size]
[color=#888888]heavy rock from Hlubocany since 1995[/color]
{{img:web_band:240}}
[color=#ffffff][i]Lukas, Mira, Pepa, Standa - the old swimming pool, spring 98[/i][/color][/center]
[bgcolor=#330000][color=#ff9900][b][marquee w=560 speed=44]*** NEW DEMO TAPE "POD HLADINOU" - 50 Kc at gigs or from Lukas ***[/marquee][/b][/color][/bgcolor]

[b][color=#ffffff]GIGS 1998[/color][/b]
 20.6.  Hlubocany, culture house - played
  4.7.  Lesna, fire station ball - played
 11.7.  Kemp Cerne jezero, disco - [color=#ff3333][blink]CANCELLED[/blink][/color]
 25.7.  Jihlava, club Rubin - tickets 40 Kc

[color=#ff9900]about the camp gig:[/color] Vera says the disco is off this year. we played there last summer and it was the best gig we ever did, 200 people, the lake, everything. Pepa says there was a guy in a hat by the door all night who just stood there. he was there at the end when we packed up. the bus had gone and he was still standing in the same place

[b][color=#ffffff]LYRICS: POD HLADINOU[/color][/b]
[i]they count us at ten
they count us at twelve
one more in the water
than there is in the world

down under the surface
the bells of the village
somebody knocking
somebody knocking[/i]

[color=#888888](Mira wrote this one after the camp. he wont say what it means)[/color]
""" + HR + """
[center]{volny.cz/~strasidla|Ghosts of South Bohemia}  |  {bohemia-online.cz|Bohemia Online}
[color=#808080]you are fan no.[/color] {{counter}}
[color=#808080]best viewed at 800x600. made with FrontPage Express[/color][/center]""",
	},
	"povodi-hlubocany.cz": {
		"title": "Hlubocany Water Board - Cerne jezero reservoir",
		"bg": "#ffffff", "fg": "#000000", "link": "#005599",
		"body": """[bgcolor=#005599][color=#ffffff][b][font_size=18] HLUBOCANY WATER BOARD [/font_size][/b][/color][/bgcolor]
[b]CERNE JEZERO RESERVOIR[/b]
[center]{{img:web_lake_photo:280}}
[color=#666666][i]The dam from the camp side, June 1998[/i][/color][/center]

[table=2]
[cell][b]built[/b]
[b]filled[/b]
[b]dam[/b]
[b]greatest depth[/b]
[b]area[/b]
[b]under the water[/b][/cell]
[cell]1958-1962
autumn 1962
earth fill, 34 m high
28 m, by the dam
1.4 square km
the village of Zatopy (cleared 1961)[/cell]
[/table]

[b]WATER LEVEL[/b]  gauge at the camp jetty
{{level}}
[color=#cc0000]No water has flowed into the reservoir since the end of August. The level is rising. A team will come to look at the gauge.[/color]

[b]THE KEEPER[/b]
[center]{{img:web_hruby:200}}
[color=#666666][i]Mr J. Hruby at the boathouse, 1981[/i][/color][/center]
The keeper's post is vacant. The boathouse on the far shore is closed. The boats at the camp jetty may be used by camp guests in daylight. Do not go near the sluice by the boathouse: the water there moves when nothing moves it.

Fishing from the camp shore with a permit from the Water Board. Bathing at your own risk.
""" + HR + """
{bohemia-online.cz|Bohemia Online}  |  {okres-hlubocany.cz|District Office}""",
	},
}
