#!/usr/bin/env python3
"""The reception's counter for two: a host and a joining copy (tools/desk_coop.tscn).
PASS when the check-in drawer the host pulls out and pushes in goes out and in on the
other machine too, the one the other pulls out goes out at the host's, and two changes
at once go the host's way.

    python godot/tools/desk_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
# The windows on a desktop of their own: never the user's mouse (tools/hidden_desktop.py).
sys.path.insert(0, os.path.join(PROJECT, "..", "tools"))
import hidden_desktop as HIDDEN  # noqa: E402
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "desk_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/desk_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'DESK_TAG \["DESK (\w+) (\w+)", (\w+), ([\d.]+), (-?\d+)\]', line)
        if m:
            out[m.group(2)] = (m.group(3) == "true", float(m.group(4)), int(m.group(5)))
        m = re.search(r'DESK_TIE \[(\w+), (\w+), (\w+), (\w+)\]', line)
        if m:
            out["tie"] = tuple(g == "true" for g in m.groups())
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
        print("DESK COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if "SCRIPT ERROR" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    print("host:", h)
    print("client:", c)

    def want(side, tag, is_open):
        got = side.get(tag)
        if got is None or got[0] != is_open or abs(got[1] - (1.0 if is_open else 0.0)) > 0.01:
            failures.append("%s: want the drawer %s; got %s" % (tag, "out" if is_open else "in", got))

    want(c, "client_before", False)
    want(h, "host_out", True)
    want(c, "client_sees_out", True)
    want(h, "host_in", False)
    want(c, "client_sees_in", False)
    want(c, "client_unseen_out", True)
    want(c, "client_back_in", True)
    want(c, "client_out", True)
    want(h, "host_sees_out", True)
    if c.get("tie") != (True, True, True, True):
        failures.append("tie: want (kept, host won, old ignored, newer taken) all true; got %s" % (c.get("tie"),))
    print("DESK COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
