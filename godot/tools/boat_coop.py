#!/usr/bin/env python3
"""The rowing boat for two: a host and a joining copy (tools/boat_coop.tscn). PASS when the
boat the other warden rows goes out on the host's lake with them rowing in it and its
oars stroking, the other rides in the bow of the host's boat (seated in it on the host's
machine), both go ashore on the keeper's jetty each on their own spot, the other is back
in the bow when the host rows home, and both are out of the boat at the end.

    python godot/tools/boat_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "boat_coop")
# lake_trip.gd's states.
ROWING, FAR_SHORE, PASSENGER = "1", "2", "3"


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/boat_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: the whole tree, or it keeps the port.
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'-> \["BOAT (\w+) (\w+)", (.*)\]\s*$', line)
        if m:
            out[m.group(2)] = m.group(3).strip()
    return text, out


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if not f.endswith(".log"):
            os.remove(os.path.join(OUT, f))
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        end_tree(host)
        end_tree(client)
        print("BOAT COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
    print("host:", h)
    print("client:", c)
    if float(h.get("away", "0") or 0) < 4.0:
        failures.append("the other's boat did not go out on the host's lake (%s m)" % h.get("away"))
    if h.get("stroking") != "true":
        failures.append("the other's oars do not stroke on the host's machine (%s)" % h.get("stroking"))
    if h.get("pose", "").strip('"&') != "row":
        failures.append("the other warden is not rowing on the host's lake (%s)" % h.get("pose"))
    if "Get in" not in c.get("hint", ""):
        failures.append("no way into the bow by the host's boat (%s)" % c.get("hint"))
    if c.get("bow") != PASSENGER:
        failures.append("the other warden is not in the bow (state %s)" % c.get("bow"))
    if float(h.get("rider", "99") or 99) > 0.6:
        failures.append("the host does not see the other on the bow seat (%s m from it)" % h.get("rider"))
    if h.get("far") != FAR_SHORE or c.get("far") != FAR_SHORE:
        failures.append("not both ashore on the keeper's jetty (host %s, client %s)" % (h.get("far"), c.get("far")))
    if float(c.get("apart", "0") or 0) < 1.5:
        failures.append("the two stand on the same spot of the keeper's jetty (%s m apart)" % c.get("apart"))
    if c.get("back") != PASSENGER:
        failures.append("the other is not back in the bow for the way home (state %s)" % c.get("back"))
    if h.get("end") != "false" or c.get("end") != "false":
        failures.append("somebody is still on the lake at the end (host %s, client %s)" % (h.get("end"), c.get("end")))
    print("BOAT COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
