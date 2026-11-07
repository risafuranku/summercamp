#!/usr/bin/env python3
"""What the playtest of 7. 11. found wrong between two machines: tools/playtest_coop.tscn.

    python godot/tools/playtest_coop.py [OUT_DIR]
"""
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "playtest_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/playtest_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def lines(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r"^PLAYCOOP (\w+) (.*)$", text, re.M):
        out[m.group(1)] = json.loads(m.group(2))
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
        client.wait(timeout=240)
        host.wait(timeout=60)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        print("PLAYTEST COOP: timed out")
    ht, h = lines("host")
    ct, c = lines("client")
    print("host:", h)
    print("client:", c)
    bad = []
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            bad.append("%s gave up waiting" % role)
        if "SCRIPT ERROR" in text:
            bad.append("%s: %s" % (role, re.search(r"SCRIPT ERROR.*", text).group(0)[:140]))
    s = c.get("sign", {})
    if s.get("name") != "Kemp U Hrachu" or s.get("hits", 0) < 1:
        bad.append("P5 the board on the other machine: %s" % s)
    if c.get("plates") not in (["WC left"], ["WC levý"]):
        bad.append("P16 plates: %s" % c.get("plates"))
    k = c.get("clock", {})
    if k.get("distinct", 0) < 30:
        bad.append("P34 the clock in steps: %s" % k)
    d = c.get("desk", {})
    if not d.get("front"):
        bad.append("P1 nobody at the counter from outside: %s" % d)
    a, b = h.get("radio", {}), c.get("radio", {})
    if a and b:
        moved = float(b.get("at", 0)) - float(a.get("at", 0))
        off = abs(float(b.get("pos", 0)) - float(a.get("pos", 0)) - moved)
        print("radio off by %.2f s" % off)
        if a.get("path") != b.get("path") or off > 0.8:
            bad.append("P7 the radio: %s %s" % (a, b))
    print("PLAYTEST COOP: %s" % ("PASS" if not bad else "FAIL"))
    for f in bad:
        print("  -", f)
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
