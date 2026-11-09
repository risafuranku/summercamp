#!/usr/bin/env python3
"""To bed for two (tools/sleep_coop.tscn): a host and a joining copy lie down in every order
and kind of bed. PASS when in every round the night passed at the first try: both up in the
morning, nobody left lying, and each had their eyes shut through it. In the last round
something is out there: nobody's eyes shut while it is, and when it is gone the night passes.

    python godot/tools/sleep_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "sleep_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_%s" % role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "640x360", "res://tools/sleep_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT, env=env)


def tags(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r'SLEEP_TAG \["SLEEP (\w+) (\w+)", ([\d.]+), (\w+), (\w+), (\w+), (\d+)\]', text):
        out[m.group(2)] = {"h": float(m.group(3)), "bed": m.group(4) == "true", "seq": m.group(5) == "true", "dark": m.group(6) == "true", "day": int(m.group(7))}
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
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            p.kill()
        print("SLEEP COOP: timed out")
    failures = []
    for role in ("host", "client"):
        text, got = tags(role)
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        print(role, got)
        for r in ("r1", "r2", "r3", "r4"):
            t = got.get(r + "_up")
            if t is None:
                failures.append("%s %s: never got that far" % (role, r))
                continue
            if not (6.4 <= t["h"] < 12.0):
                failures.append("%s %s: hour %.2f, not the morning" % (role, r, t["h"]))
            if t["bed"] or t["seq"]:
                failures.append("%s %s: still lying there (in bed %s, sequence %s)" % (role, r, t["bed"], t["seq"]))
            if not t["dark"]:
                failures.append("%s %s: the morning came with their eyes open" % (role, r))
        a = got.get("r4_awake")
        if a is None or a["dark"] or not a["bed"]:
            failures.append("%s r4: eyes shut with something out there, or not lying there: %s" % (role, a))
    print("SLEEP COOP: " + ("PASS" if not failures else "FAIL"))
    for f in failures:
        print(" -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
