#!/usr/bin/env python3
"""Seen from the camp, for two (tools/rooms_coop.tscn): PASS when the joining warden outside
sees the cabin's door open before the host is in, and the host's figure in the room where
the host stands at each of its windows.

    python godot/tools/rooms_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "rooms_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_%s" % role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "960x540", "res://tools/rooms_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT, env=env)


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
        client.wait(timeout=420)
        host.wait(timeout=60)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            p.kill()
        print("ROOMS COOP: timed out")
    h = open(os.path.join(OUT, "host.log"), encoding="utf-8", errors="replace").read()
    c = open(os.path.join(OUT, "client.log"), encoding="utf-8", errors="replace").read()
    failures = []
    for name, t in (("host", h), ("client", c)):
        if "SCRIPT ERROR" in t:
            failures.append("%s: SCRIPT ERROR" % name)
    d = re.search(r"ROOMS_DOOR door told (-?\d+) ms, in flag (-?\d+) ms", c)
    if not d or int(d.group(1)) < 0 or int(d.group(2)) < 0 or int(d.group(1)) >= int(d.group(2)):
        failures.append("the door did not open before the warden was in: %s" % (d.group(0) if d else "no line"))
    else:
        print("door told %d ms before the warden was in" % (int(d.group(2)) - int(d.group(1))))
    for s in ("s0", "s1"):
        hm = re.search(r'ROOMS_TAG \["host %s", (-?[\d.]+), (-?[\d.]+)\]' % s, h)
        cm = re.search(r'ROOMS_TAG \["client %s", (-?[\d.]+), (-?[\d.]+), (\d+), (\w+), (\w+)\]' % s, c)
        if not hm or not cm:
            failures.append("%s: no line" % s)
            continue
        print(s, "host at", hm.group(1), hm.group(2), "figure at", cm.group(1), cm.group(2), "figures", cm.group(3), "visible", cm.group(4), "room taken", cm.group(5))
        if int(cm.group(3)) != 1 or cm.group(4) != "true" or abs(float(hm.group(1)) - float(cm.group(1))) > 0.2 or abs(float(hm.group(2)) - float(cm.group(2))) > 0.2:
            failures.append("%s: the figure is not where the host stands" % s)
    print("ROOMS COOP: " + ("PASS" if not failures else "FAIL"))
    for f in failures:
        print(" -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
