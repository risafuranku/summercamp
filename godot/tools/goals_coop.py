#!/usr/bin/env python3
"""A camp's goals for two (tools/goals_coop.tscn): PASS when the till's goal met on the host is met
in the other machine's books too and celebrated there (the banner and the fanfare).

    python godot/tools/goals_coop.py [OUT_DIR]
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
# The windows on a desktop of their own: never the user's mouse (tools/hidden_desktop.py).
sys.path.insert(0, os.path.join(PROJECT, "..", "tools"))
import hidden_desktop as HIDDEN  # noqa: E402
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "goals_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/goals_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


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
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        print("GOALS COOP: FAIL (timed out)")
        return 1
    failures = []
    tags = {}
    for role in ("host", "client"):
        text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR" % role)
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if line.startswith("GOAL_TAG "):
                a = json.loads(line[len("GOAL_TAG "):])
                tags[a[0]] = a[1:]
    for k in sorted(tags):
        print("  %s %s" % (k, tags[k]))
    if tags.get("client_before", [None])[0] != ["money", "guests"]:
        failures.append("the other machine's goals: %s" % tags.get("client_before"))
    if tags.get("host_before", [0, 0])[1] != [] or tags.get("client_before", [0, 0])[1] != []:
        failures.append("met before the till was filled: %s %s" % (tags.get("host_before"), tags.get("client_before")))
    hm, cm = tags.get("host_met"), tags.get("client_met")
    if not hm or hm[1] != ["money"] or hm[2] != 1:
        failures.append("the host: %s" % hm)
    if not cm or cm[1] != ["money"] or cm[2] != 1:
        failures.append("the other machine: %s" % cm)
    print("GOALS COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
