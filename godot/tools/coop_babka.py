#!/usr/bin/env python3
"""Co-op check of the mushroom granny: a host and a client of the game on this machine
(tools/coop_babka.tscn). PASS when she hunts the warden who is outside and it reaches
them: they see her, her spores are on their screen, her catch hurts them and leaves them
limping.

    python godot/tools/coop_babka.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_babka")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_babka.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP BABKA %s: %s (.*)" % (role, what), text)
    if not m:
        return None
    return dict(kv.split("=") for kv in m.group(1).split())


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            os.remove(p)
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    failures = []
    try:
        client.wait(timeout=600)
        host.wait(timeout=60)
    except subprocess.TimeoutExpired:
        failures.append("timed out")
    for p in (host, client):
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
    h = open(os.path.join(OUT, "host.log"), encoding="utf-8", errors="replace").read()
    c = open(os.path.join(OUT, "client.log"), encoding="utf-8", errors="replace").read()
    for role, text in (("host", h), ("client", c)):
        for line in text.splitlines():
            if "SCRIPT ERROR" in line or "gave up waiting" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    r = report(c, "client", "near_here")
    if r is None or int(r["mirror_shown"]) < 1:
        failures.append("the joining warden does not see her near them: %s" % r)
    if r is None or float(r["spores"]) < 0.05:
        failures.append("her spores are not on the joining warden's screen: %s" % r)
    r = report(c, "client", "struck_here")
    if r is None or int(r["hp"]) >= 100:
        failures.append("her catch does not hurt the joining warden: %s" % r)
    if r is None or float(r["limp"]) >= 1.0:
        failures.append("the joining warden does not limp after her catch: %s" % r)
    print("\n".join(l for l in (h + c).splitlines() if "COOP BABKA" in l))
    if failures:
        print("COOP BABKA: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP BABKA: PASS")


if __name__ == "__main__":
    main()
