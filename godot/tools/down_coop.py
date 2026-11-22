#!/usr/bin/env python3
"""A warden knocked down at night, seen by the other (tools/down_coop.tscn): PASS when the
host sees them lying (dn) with their torch lit on the ground at 4, 10 and 18 m.
    python godot/tools/down_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "down_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_%s" % role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/down_coop.tscn", "--",
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
        client.wait(timeout=600)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            p.kill()
        print("DOWN COOP: timed out")
    failures = []
    seen = {}
    for role in ("host", "client"):
        text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        for m in re.finditer(r"DOWN_TAG (\d+) dn=(\w+) t=(\w+) beam=(\w+)", text):
            seen[m.group(1)] = m.groups()[1:]
    print(seen)
    for d in ("4", "10", "18"):
        s = seen.get(d)
        if s is None:
            failures.append("%s m: never looked" % d)
        elif s != ("true", "true", "true"):
            failures.append("%s m: dn/t/beam %s" % (d, s))
    print("DOWN COOP: " + ("PASS" if not failures else "FAIL"))
    for f in failures:
        print(" -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
