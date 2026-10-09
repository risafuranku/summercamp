extends RefCounted

## The camp computer's disk: folders and the text files on it. Static data; the shell
## adds what is downloaded and installed.
##
## The documents are lore: Vera's instructions, the phone list, the inventory, Karel's
## night notes, a letter somebody deleted. They are written to be read in a hurry by a
## nephew minding a camp, and to make sense later.

const DIRS := {
	"C:\\": ["DOWNLOAD", "OKNA", "PROGRAM FILES", "VERA", "AUTOEXEC.BAT", "CONFIG.SYS"],
	"C:\\OKNA": ["SYSTEM", "FONTS", "OKNA.INI", "SYSTEM.INI", "SETUPLOG.TXT"],
	"C:\\OKNA\\SYSTEM": [],
	"C:\\OKNA\\FONTS": [],
	"C:\\PROGRAM FILES": ["BEETERNET", "CAMPMAIL", "MINES"],
	"C:\\PROGRAM FILES\\BEETERNET": ["BEETER.EXE"],
	"C:\\PROGRAM FILES\\CAMPMAIL": ["CAMPMAIL.EXE", "INBOX.MBX"],
	"C:\\PROGRAM FILES\\MINES": ["MINES.EXE"],
	"C:\\VERA": ["README.TXT", "TELEFONY.TXT", "INVENTAR.TXT", "NOCI.TXT"],
	"C:\\DOWNLOAD": [],
}

## Where a program lands when it is installed, and what it puts there.
const PROGRAM_DIRS := {
	"builder": ["BUILDER98", ["BUILDER.EXE", "README98.TXT", "TERRAIN.DAT"]],
	"camp_status": ["CAMPSTAT", ["CAMPSTAT.EXE", "TARIF96.DAT"]],
	"guestrack": ["GUESTRAK", ["GUESTRAK.EXE", "EVIDENCE.DBF"]],
}

## Files that open a program when double-clicked.
const EXE_APPS := {
	"BEETER.EXE": "browser",
	"CAMPMAIL.EXE": "mail",
	"MINES.EXE": "mines",
	"BUILDER.EXE": "builder",
	"CAMPSTAT.EXE": "camp_status",
	"GUESTRAK.EXE": "guestrack",
}

## In the Recycle Bin when the week starts. Restoring puts them back in C:\VERA.
const BIN_START := ["DOPIS.TXT", "IMG0043.JPG"]

const TEXTS := {
	"README.TXT": """COMPUTER - READ THIS FIRST

This computer belongs to the camp. Do not install games on it.
Mines is already there. That is enough.

CAMPMAIL - the bookings come here. Read every one. Accept or
refuse. Before you accept, look at the beds and at the night
risk line at the bottom of the booking.

THE INTERNET costs money by the minute (we are on the modem).
Look up what you need and hang up.

BUILDER - for planning the camp. Download it from
www.stavitel98.cz, it is shareware. Karel paid for it once and
then lost the disk.

CAMPSTAT - the power company wants us to use their program for
the bills. www.campgrid.cz

GUESTRACK - the district wants the guest register kept in this.
www.okres-hlubocany.cz

If the screen goes blue, switch it off and on again.
If the main trips, read NOCI.TXT.

- V.""",

	"TELEFONY.TXT": """TELEPHONE NUMBERS                        (updated 4/96)

Electrician Novotny ............ 0663 22 418  (not after 9 pm)
Vet, Lesna ..................... 0663 21 007
District office, accommodation . 0663 30 112
Water board .................... 0663 30 150
Bus station Hlubocany .......... 0663 21 333
Jednota Lesna (shop) ........... 0663 21 090
Hostinec U Jezera (pub) ........ 0663 21 515
Pan Hruby (lake keeper) ........ -- no longer --
Police ......................... 158
Ambulance ...................... 155

Nela ........................... 0602 618 247
Vera (the flat) ................ 02 / 6731 4420""",

	"INVENTAR.TXT": """INVENTORY - spring count 1996

Blankets, wool, check ......... 41  (3 missing since last year)
Pillows ....................... 38
Sheets ........................ 60
Paraffin lamps ................ 6
Torches ....................... 2   (one works)
Spare bulbs, lamp posts ....... 12
Fuses 16A ..................... 5
Sewer rod ..................... 1   (do not lend it)
Pipe clamps ................... 4
Bicycle ....................... 1   (the one by the shed is
                                     not ours, leave it)
Shoe, ladies, red, left ....... 1   (found in the pipes 1993,
                                     keep for the owner)""",

	"NOCI.TXT": """NIGHTS - Karel's notes. Read before the first night.

- Lamps on by half past seven. A lit path is a safe path.
- If the main trips at the generator: everything down, main
  up, then one at a time. The one that throws it stays down.
  (Novotny showed me. He will not come out at night.)
- Keep the torch charged. It lasts about half the night.
- Do not answer anyone calling from the lake.
- The man in the hat does not come into the light. He is
  patient. If you hear him, turn round and look at him.
- If you hear a camera, do not look round. Whatever you
  do, do not look round.
- The girl stands where the light stops. Keep her where you
  can see her.
- Count the guests at ten. Count them again at midnight.
  Write both numbers down.

    ten   midnight
    10    11
    12    13
     9    10
     7     8
    11    12""",

	"DOPIS.TXT": """Vero,

I am not selling. I know what you think about the lake and I
know what the district thinks. The camp was here before the
reservoir and it will be here after it.

What happened in 1987 was not our fault. I told the police
everything I know, and I do not know anything.

Come in June. Bring the boy if he wants to come. He can mind
the place for a week while you are at your sister's. It is
good for a young man to be responsible for something.

Do not let him go to the lake after dark.

K.""",

	"AUTOEXEC.BAT": """@ECHO OFF
PROMPT $P$G
PATH C:\\OKNA;C:\\OKNA\\COMMAND;C:\\
SET TEMP=C:\\OKNA\\TEMP
SET BLASTER=A220 I5 D1 T4
LH C:\\OKNA\\COMMAND\\MSCDEX.EXE /D:CAMPCD /L:D
LH C:\\OKNA\\COMMAND\\DOSKEY.COM
LH C:\\OKNA\\COMMAND\\KEYB.COM CZ,,C:\\OKNA\\COMMAND\\KEYBOARD.SYS
REM Modem on COM2 - do not remove
MODE COM2:9600,N,8,1""",

	"CONFIG.SYS": """DEVICE=C:\\OKNA\\HIMEM.SYS
DEVICE=C:\\OKNA\\EMM386.EXE NOEMS
DOS=HIGH,UMB
FILES=40
BUFFERS=20
DEVICEHIGH=C:\\OKNA\\COMMAND\\DISPLAY.SYS CON=(EGA,,1)
COUNTRY=042,852,C:\\OKNA\\COMMAND\\COUNTRY.SYS
DEVICEHIGH=C:\\CDROM\\CAMPCD.SYS /D:CAMPCD""",

	"SETUPLOG.TXT": """[Setup]
Version=4.10.1998
InstallDate=06/02/1996
Owner=Kemp Cerne jezero
Organization=Kemp Cerne jezero
ProductKey=*****-*****-*****-*****-*****
OEM=Camptronics Fieldware

[Errors]
Device detect: COM3 - no response
Device detect: COM3 - no response
Device detect: COM3 - no response""",

	"OKNA.INI": """[okna]
load=
run=CAMPMAIL.EXE
Beep=yes
NullPort=None
device=Epson LX-400,EPSON9,LPT1:

[Desktop]
Wallpaper=C:\\OKNA\\KEMP.BMP
TileWallpaper=0""",

	"SYSTEM.INI": """[boot]
shell=Explorer.exe
system.drv=system.drv
drivers=mmsystem.dll power.drv

[386Enh]
woafont=dosapp.fon""",

	"README98.TXT": """BUILDER 98 - version 1.2 (shareware)
(c) 1996-98 Stavitel software, Jihlava

Thank you for trying Builder 98.

This copy is fully working for 30 days. After that the
Save function is limited to one site. Register for 990 Kc
by postal order (see ORDER.TXT) and you will receive your
personal key by return of post.

Plan your recreational facility tile by tile: tents,
chalets, sanitary blocks, catering, attractions and
lighting. Builder 98 keeps the site plan in step with the
live camp telemetry, if your site is equipped with it.

Use of Builder 98 between 20:00 and 06:30 is not permitted
under the site licence for recreational facilities (Act
no. 455/1991, schedule 3).""",
}

const NOT_TEXT := {
	"IMG0043.JPG": "image",
	"INBOX.MBX": "data",
	"TERRAIN.DAT": "data",
	"TARIF96.DAT": "data",
	"EVIDENCE.DBF": "data",
}


static func is_dir(path: String) -> bool:
	return DIRS.has(path)


static func file_kind(name: String) -> String:
	var n := name.to_upper()
	if n.ends_with(".TXT") or n.ends_with(".BAT") or n.ends_with(".SYS") or n.ends_with(".INI"):
		return "text"
	if n.ends_with(".EXE"):
		return "exe"
	if n.ends_with(".JPG") or n.ends_with(".BMP"):
		return "image"
	if n.ends_with(".HTM"):
		return "html"
	return "data"


static func text_of(name: String) -> String:
	return str(TEXTS.get(name.to_upper(), ""))
