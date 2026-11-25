#!/usr/bin/env python3
"""A sandbox camp's land for two (tools/plot_coop.tscn): PASS when the other warden has the host's
plot, buys the west strip (the host pays once, the plot grown on both) and a cabin of theirs
off the plot is turned down on both.

    python godot/tools/plot_coop.py [OUT_DIR]
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "plot_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/plot_coop.tscn", "--",
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
        print("PLOT COOP: FAIL (timed out)")
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
            if line.startswith("PLOT_TAG "):
                a = json.loads(line[len("PLOT_TAG "):])
                tags[a[0]] = a[1:]
    for k in sorted(tags):
        print("  %s %s" % (k, tags[k]))
    small, grown = [9, 0, 21, 12], [5, 0, 21, 12]
    hs, cs = tags.get("host_start"), tags.get("client_start")
    if not hs or hs[0] != small:
        failures.append("the host's plot at the start: %s" % hs)
    if not cs or cs[0] != small:
        failures.append("the other's plot at the start: %s" % cs)
    hb, cb = tags.get("host_bought"), tags.get("client_bought")
    if not hb or hb[0] != grown or hb[1] != 1 or hs[2] - hb[2] != 260:
        failures.append("the host's plot after the other bought: %s (start %s)" % (hb, hs))
    if not cb or cb[0] != grown:
        failures.append("the other's plot after buying: %s" % cb)
    he, ce = tags.get("host_end"), tags.get("client_end")
    if not he or he[3] != "" or not ce or ce[3] != "":
        failures.append("a cabin off the plot: host %s, the other %s" % (he, ce))
    print("PLOT COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
