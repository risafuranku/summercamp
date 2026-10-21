#!/usr/bin/env python3
"""The staffroom for two: a host and a joining copy (tools/staff_coop.tscn). PASS when
the joining warden has the host's two hands in its books, the locker it buys reaches the
host's books, it sits at the laptop, and the host sees it there through the front window
and inside on the laptop's chair.

    python godot/tools/staff_coop.py [OUT_DIR]
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "staff_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "--resolution", "1280x720", "res://tools/staff_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def tags(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for m in re.finditer(r'STAFF_TAG \["STAFF \w+ (\w+)", (.*)\]', text):
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
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        print("STAFF COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tags("host")
    ct, c = tags("client")
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if "SCRIPT ERROR" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    print("host:", h)
    print("client:", c)
    if c.get("client_crew") != 2:
        failures.append("client_crew: want 2, got %s" % c.get("client_crew"))
    if c.get("client_job") != "laptop":
        failures.append("client_job: want laptop, got %s" % c.get("client_job"))
    if h.get("host_lockers") != 3:
        failures.append("host_lockers: want 3 (1 + the host's + the client's), got %s" % h.get("host_lockers"))
    if h.get("outside_figs", 0) < 1:
        failures.append("outside_figs: want 1, got %s" % h.get("outside_figs"))
    if "desk" not in (h.get("inside_figs") or []):
        failures.append("inside_figs: want a 'desk' figure, got %s" % h.get("inside_figs"))
    print("STAFF COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
