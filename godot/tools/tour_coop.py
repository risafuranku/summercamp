#!/usr/bin/env python3
"""The week's tour for two (tools/tour_coop.tscn): PASS when the agency's letter sent on the host is
in the other machine's CampMail, accepted there it is booked in the host's camp (8-15 of them on
the 380), and the party is at the barrier on both when its run is in.

    python godot/tools/tour_coop.py [OUT_DIR]
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "tour_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/tour_coop.tscn", "--",
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
        print("TOUR COOP: FAIL (timed out)")
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
            if line.startswith("TOUR_TAG "):
                a = json.loads(line[len("TOUR_TAG "):])
                tags[a[0]] = a[1:]
    for k in sorted(tags):
        print("  %s %s" % (k, tags[k]))
    if (tags.get("host_mail") or [0])[0] != 1 or (tags.get("client_mail") or [0])[0] != 1:
        failures.append("the letter in both inboxes: %s %s" % (tags.get("host_mail"), tags.get("client_mail")))
    hb, cb = tags.get("host_booked"), tags.get("client_booked")
    if not hb or not (8 <= hb[1] <= 15) or hb[2] != "expected" or hb[3] <= 0:
        failures.append("booked in the host's camp: %s" % hb)
    if not cb or not hb or cb[1:] != hb[1:]:
        failures.append("the booking on the other machine: %s against %s" % (cb, hb))
    hg, cg = tags.get("host_gate"), tags.get("client_gate")
    # Come: at the barrier, or let in already (the test camp's reception may be quick).
    if not hg or hg[2] not in ("waiting", "active") or not cg or cg[2] != hg[2]:
        failures.append("come on both: %s %s" % (hg, cg))
    print("TOUR COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
