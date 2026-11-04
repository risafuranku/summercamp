#!/usr/bin/env python3
"""Liblice for two: a host and a joining copy (tools/motel_coop.tscn). PASS when each sees
the other standing in the Jednota, the pub and the kiosk, the joining
warden sees the host's two candles burn in the chapel, at night both see as many flames
on the stand (somebody lit more in the evening); the other sees the host at the
reception's counter, the key go off the board, the host gone and then in the corridor,
goes in at four after them, sees the set the host put on; each sees the other in the room
(the host standing, then asleep in the second bed), a knock wakes both in the night, and
the rest of it goes by for both: both wake in four in the morning.

    python godot/tools/motel_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "motel_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_%s" % role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/motel_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT, env=env)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'MOTEL_TAG \["MOTEL (\w+) (\w+)", ([\d.]+), "(\w*)", (\d+), (\d+), (\d+), (\w+)(?:, "(\w*)")?(?:, (\d+), (\w+))?\]', line)
        if m:
            out[m.group(2)] = {"h": float(m.group(3)), "place": m.group(4), "figs": int(m.group(5)),
                               "sleepers": int(m.group(6)), "flames": int(m.group(7)), "key": m.group(8) == "true",
                               "ev": m.group(9) or "", "board": int(m.group(10) or 0), "tv": m.group(11) == "true"}
    return text, out


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            os.remove(p)
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=1200)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        print("MOTEL COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if "SCRIPT ERROR" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    print("host:", h)
    print("client:", c)

    def want(side, tag, test, what):
        got = side.get(tag)
        if got is None or not test(got):
            failures.append("%s: want %s; got %s" % (tag, what, got))

    for p in ("jednota", "pub", "kiosk"):
        for side, who in ((h, "the host"), (c, "the other")):
            want(side, p + "_mate", lambda g, p=p: g["place"] == p and g["figs"] >= 1, "%s seeing the other warden in the %s" % (who, p))
    want(h, "candles_lit", lambda g: g["flames"] >= 2, "two candles on the host's stand")
    want(c, "candles", lambda g: g["place"] == "chapel" and g["flames"] >= 2, "the host's two candles burning for the other")
    want(h, "night_chapel", lambda g: g["place"] == "chapel" and g["flames"] >= 3 and (g["h"] >= 19.0 or g["h"] < 6.0),
         "the stand lit at night for the host")
    want(c, "night_chapel", lambda g: g["place"] == "chapel" and g["flames"] == h.get("night_chapel", {}).get("flames", -1),
         "as many flames at night for the other as for the host")
    for side, who in ((h, "the host"), (c, "the other")):
        want(side, "lobby_mate", lambda g: g["place"] == "motel" and g["figs"] >= 1, "%s seeing the other at the reception" % who)
    want(h, "booked", lambda g: g["key"], "the host's key off the board")
    want(c, "board", lambda g: g["place"] == "motel" and g["board"] == 3, "the key gone from the other's board")
    want(h, "hall_host", lambda g: g["place"] == "motel_hall", "the host in the corridor")
    want(c, "hall_mate", lambda g: g["place"] == "motel_hall" and g["figs"] >= 1, "the other seeing the host in the corridor")
    for side, who in ((h, "the host"), (c, "the other")):
        want(side, "in_four", lambda g: g["place"] == "motel_room", "%s in four" % who)
        want(side, "set_on", lambda g: g["tv"], "the set on for %s" % who)
    want(h, "mate_in_room", lambda g: g["place"] == "motel_room" and g["figs"] >= 1 and g["key"], "the other warden in four with the host")
    want(c, "mate_asleep", lambda g: g["place"] == "motel_room" and g["sleepers"] >= 1, "the host asleep in the second bed")
    want(h, "lying_alone", lambda g: g["place"] == "motel_room", "the host lying in four while the other is up")
    for side, who in ((h, "the host"), (c, "the other")):
        want(side, "woken", lambda g: g["place"] == "motel_room" and g["ev"] == "knock" and (g["h"] >= 18.0 or g["h"] < 6.0),
             "%s woken in four in the night by the knock" % who)
    want(h, "morning", lambda g: g["place"] == "motel_room" and 6.0 <= g["h"] < 12.0, "the host waking in four")
    want(c, "morning", lambda g: g["place"] == "motel_room" and 6.0 <= g["h"] < 12.0, "the other waking in four")
    print("MOTEL COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
