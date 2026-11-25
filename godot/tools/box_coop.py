#!/usr/bin/env python3
"""The van's boxes for two (tools/box_coop.tscn): PASS when the other warden takes the host's
pub's box off the pallet (the host cannot take it then), carries it in, and the beer is on
the host's shelves, the box gone on both.

    python godot/tools/box_coop.py [OUT_DIR]
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "box_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/box_coop.tscn", "--",
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
        print("BOX COOP: FAIL (timed out)")
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
            if line.startswith("BOX_TAG "):
                a = json.loads(line[len("BOX_TAG "):])
                tags[a[0]] = a[1:]
    for k in sorted(tags):
        print("  %s %s" % (k, tags[k]))
    hs, cs = tags.get("host_start"), tags.get("client_start")
    if not hs or hs[0] != 1 or hs[1] != "" or hs[2] != 5:
        failures.append("the host's pallet at the start: %s" % hs)
    if cs != hs:
        failures.append("the other's pallet at the start %s, the host's %s" % (cs, hs))
    ht = tags.get("host_taken")
    if not ht or ht[0] != 1 or not str(ht[1]).startswith("p") or ht[1] == "p1":
        failures.append("the host's books with the box in the other's arms: %s" % ht)
    if tags.get("host_steal") != [False]:
        failures.append("the host took the other's box: %s" % tags.get("host_steal"))
    ch = tags.get("client_held")
    if not ch or ch[3] != "box":
        failures.append("the box in the other's arms: %s" % ch)
    he, ce = tags.get("host_end"), tags.get("client_end")
    if not he or he[0] != 0 or he[2] <= 5:
        failures.append("carried in, on the host's shelves: %s" % he)
    if not ce or ce[0] != 0 or ce[2] != he[2] or ce[3] != "":
        failures.append("carried in, on the other machine: %s (host %s)" % (ce, he))
    print("BOX COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
