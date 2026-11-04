#!/usr/bin/env python3
"""Co-op Girl check: a host and a client of the game on this machine
(tools/coop_girl.tscn). PASS when the Girl hunting the joining warden is held by the
host's torch (no step, not behind them while it is on her), comes once nobody lights
her, and is theirs alone: her stage, the cold in their torch, the presence, her interference
and the set catching its picture as they find her on their machine, none of it on the host's.

    python godot/tools/coop_girl.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_girl")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_girl.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP GIRL %s: %s (.*)" % (role, what), text)
    if not m:
        return None
    return dict(kv.split("=", 1) for kv in m.group(1).split())


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
            if "SCRIPT ERROR" in line or "gave up waiting" in line or "no copy of her" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break

    def need(ok, what, r):
        if r is None or not ok(r):
            failures.append("%s: %s" % (what, r))

    need(lambda r: r["moved"] == "false" and r["held"] == "true" and r["phase"] == "1",
         "the host's torch on her did not hold her while the other looked away", report(h, "host", "held"))
    need(lambda r: r["moved"] == "true", "she did not come once nobody lit her", report(h, "host", "free"))
    need(lambda r: int(r["mirror"]) > 0, "the joining warden does not see her", report(c, "client", "faced_here"))
    need(lambda r: float(r["drain"]) > 0.0, "no cold in the joining warden's torch on her", report(c, "client", "faced_here"))
    need(lambda r: float(r["presence"]) > 0.05, "the joining warden does not feel her near", report(c, "client", "faced_here"))
    need(lambda r: float(r["jam"]) > 0.2, "no interference from her on the joining warden's screen", report(c, "client", "faced_here"))
    need(lambda r: r["lock"] == "true", "the joining warden's set did not catch its picture as they found her", report(c, "client", "faced_here"))
    need(lambda r: float(r["presence"]) < 0.05 and float(r["dread"]) < 0.05 and float(r["drain"]) == 0.0 and float(r["jam"]) == 0.0 and r["lock"] == "false",
         "the host's screen or torch had some of the other's hunt", report(h, "host", "host_end"))
    print("\n".join(l for l in (h + c).splitlines() if "COOP GIRL" in l))
    if failures:
        print("COOP GIRL: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP GIRL: PASS")


if __name__ == "__main__":
    main()
