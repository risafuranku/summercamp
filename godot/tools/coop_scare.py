#!/usr/bin/env python3
"""Co-op scare check: a host and a client of the game on this machine
(tools/coop_scare.tscn). PASS when a scare is one warden's alone: the Girl's strike on the
joining warden is on their screen and nowhere on the host's; on the host, it is the
host's and the joining machine shows nothing of her.

    python godot/tools/coop_scare.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_scare")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_scare.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP SCARE %s: %s (.*)" % (role, what), text)
    if not m:
        return None
    return dict(kv.split("=") for kv in m.group(1).split())


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            os.remove(p)
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    failures = []
    try:
        client.wait(timeout=600)
        host.wait(timeout=60)
    except subprocess.TimeoutExpired:
        failures.append("timed out")
    for p in (host, client):
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
    h = open(os.path.join(OUT, "host.log"), encoding="utf-8", errors="replace").read()
    c = open(os.path.join(OUT, "client.log"), encoding="utf-8", errors="replace").read()
    for role, text in (("host", h), ("client", c)):
        for line in text.splitlines():
            if "SCRIPT ERROR" in line or "gave up waiting" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    r = report(h, "host", "strike_on_other")
    if r is None or r["enemy_root_seen"] != "false" or r["close"] != "false":
        failures.append("host sees the strike on the other warden: %s" % r)
    r = report(c, "client", "struck_here")
    if r is None or r["close"] != "true":
        failures.append("the joining warden has no strike on their screen: %s" % r)
    r = report(c, "client", "struck_after")
    if r is None or abs(float(r["roll"])) < 0.3:
        failures.append("the joining warden's view is not turned by the strike: %s" % r)
    r = report(h, "host", "strike_on_host")
    if r is None or r["close"] != "true":
        failures.append("the host has no strike on their screen: %s" % r)
    r = report(c, "client", "host_struck_seen_from_here")
    if r is None or r["mirror_shown"] != "0" or r["close"] != "false":
        failures.append("the joining machine sees the host's strike: %s" % r)
    print("\n".join(l for l in (h + c).splitlines() if "COOP SCARE" in l))
    if failures:
        print("COOP SCARE: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP SCARE: PASS")


if __name__ == "__main__":
    main()
