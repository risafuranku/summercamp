#!/usr/bin/env python3
"""The bowling for two (tools/bowling_coop.tscn): PASS when what the host does at the hall's
stations shows on the other warden's: the bufet's tray and the glass under the tap, the pit's
pin in the hand (where the host holds it) and the pin in the pit, the counter's lane picked,
the cellar's crank.

    python godot/tools/bowling_coop.py [OUT_DIR]
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
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "bowling_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/bowling_coop.tscn", "--",
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
        print("BOWLING COOP: FAIL (timed out)")
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
            if line.startswith("BOWL_TAG "):
                a = json.loads(line[len("BOWL_TAG "):])
                tags[a[0]] = a[1:]
    for k in sorted(tags):
        print("  %s %s" % (k, tags[k]))
    # The bufet: the same tray (two things, crisps first, shown), the same glass under the tap.
    if tags.get("host_tray", [0])[0] != 2:
        failures.append("the host's tray: %s" % tags.get("host_tray"))
    if tags.get("client_tray") != tags.get("host_tray"):
        failures.append("the other warden's tray %s, the host's %s" % (tags.get("client_tray"), tags.get("host_tray")))
    hp, cp = tags.get("host_pour"), tags.get("client_pour")
    if not hp or hp[0] != "beer" or not cp or cp[0] != "beer" or not cp[2] or cp[1] <= 0.0:
        failures.append("the glass under the tap: host %s, the other %s" % (hp, cp))
    if tags.get("host_tray_poured", [0])[0] != 3 or tags.get("client_tray_poured") != tags.get("host_tray_poured"):
        failures.append("the poured glass onto the tray: host %s, the other %s" % (tags.get("host_tray_poured"), tags.get("client_tray_poured")))
    if tags.get("client_tray_back") != tags.get("host_tray_poured"):
        failures.append("the tray after coming back in: %s, the host's %s" % (tags.get("client_tray_back"), tags.get("host_tray_poured")))
    # The pit: pin 3 in the hand, 5 in the pit, the held pin where the host holds it.
    hn, cn = tags.get("host_pin"), tags.get("client_pin")
    if not hn or hn[:3] != ["hand", "pit", True]:
        failures.append("the host's pit: %s" % hn)
    if not cn or cn[:3] != ["hand", "pit", True] or max(abs(cn[i] - hn[i]) for i in (3, 4, 5)) > 0.06:
        failures.append("the other warden's pit %s, the host's %s" % (cn, hn))
    # The counter and the cellar.
    if tags.get("client_desk") != [2]:
        failures.append("the counter's pick on the other machine: %s" % tags.get("client_desk"))
    if tags.get("client_cellar") != [1.25, 3]:
        failures.append("the cellar's crank on the other machine: %s" % tags.get("client_cellar"))
    print("BOWLING COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
