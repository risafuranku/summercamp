#!/usr/bin/env python3
"""Liblice for two: a host and a joining copy (tools/motel_coop.tscn). PASS when each sees
the other standing in the Jednota, the pub and the kiosk, the joining
warden sees the host's two candles burn in the chapel, both get number four's key, each
sees the other in the room (the host standing, then asleep in the second bed), and the
night goes by for both: both wake in four in the morning.

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
        m = re.search(r'MOTEL_TAG \["MOTEL (\w+) (\w+)", ([\d.]+), "(\w*)", (\d+), (\d+), (\d+), (\w+)\]', line)
        if m:
            out[m.group(2)] = {"h": float(m.group(3)), "place": m.group(4), "figs": int(m.group(5)),
                               "sleepers": int(m.group(6)), "flames": int(m.group(7)), "key": m.group(8) == "true"}
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
    want(h, "mate_in_room", lambda g: g["place"] == "motel_room" and g["figs"] >= 1 and g["key"], "the other warden in four with the host")
    want(c, "mate_asleep", lambda g: g["place"] == "motel_room" and g["sleepers"] >= 1 and g["key"], "the host asleep in the second bed")
    want(h, "lying_alone", lambda g: g["place"] == "motel_room", "the host lying in four while the other is up")
    want(h, "morning", lambda g: g["place"] == "motel_room" and 6.0 <= g["h"] < 12.0, "the host waking in four")
    want(c, "morning", lambda g: g["place"] == "motel_room" and 6.0 <= g["h"] < 12.0, "the other waking in four")
    print("MOTEL COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
