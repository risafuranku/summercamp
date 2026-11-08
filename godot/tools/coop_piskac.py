#!/usr/bin/env python3
"""Co-op Whistler check: a host and a client of the game on this machine
(tools/coop_piskac.tscn). PASS when he hunts the joining warden and their machine has it:
his song heard while he plays with the hush on them, the song stopped dead when it stops
(it used to play out for up to 14 s), his strike on their screen and their health, and none
of the hush or the strike on the host's.

    python godot/tools/coop_piskac.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_piskac")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_piskac.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP PISKAC %s: %s (.*)" % (role, what), text)
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
        client.wait(timeout=500)
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
    r = report(c, "client", "play_here")
    if r is None or int(r["songs"]) < 1:
        failures.append("the joining warden does not hear his song: %s" % r)
    if r is None or float(r["hush"]) < 0.2:
        failures.append("the hush is not on the joining warden: %s" % r)
    r = report(h, "host", "play_other")
    if r is None or float(r["hush"]) > 0.05:
        failures.append("the hush is on the host, who is not hunted: %s" % r)
    r = report(c, "client", "gap_here")
    if r is None or int(r["songs"]) != 0:
        failures.append("his song stopped dead plays on at the joining warden's: %s" % r)
    r = report(c, "client", "strike_here")
    if r is None or r["over"].lower() != "true":
        failures.append("the string is not on the joining warden's screen: %s" % r)
    r = report(h, "host", "struck_other")
    if r is None or int(r["hp"]) < 100:
        failures.append("his strike hurt the host: %s" % r)
    r = report(c, "client", "struck_here")
    if r is None or int(r["hp"]) >= 100:
        failures.append("his strike does not hurt the joining warden: %s" % r)
    print("\n".join(l for l in (h + c).splitlines() if "COOP PISKAC" in l))
    if failures:
        print("COOP PISKAC: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP PISKAC: PASS")


if __name__ == "__main__":
    main()
