#!/usr/bin/env python3
"""Co-op Photographer check: a host and a client of the game on this machine
(tools/coop_photo.tscn). PASS when what the Photographer does to the joining warden is on
their machine alone: the white and their polaroid there, his run at their back and him at
their window unseen on the host's, the shot through their window and the last picture
(his lens-face, their face developing, down) on their screen, nothing of it on the host's.

    python godot/tools/coop_photo.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_photo")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_photo.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP PHOTO %s: %s (.*)" % (role, what), text)
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
            if "SCRIPT ERROR" in line or "gave up waiting" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break

    def need(ok, what, r):
        if r is None or not ok(r):
            failures.append("%s: %s" % (what, r))

    need(lambda r: r["hit"] == "true", "his shot did not catch the joining warden (setup)", report(h, "host", "shot_other"))
    need(lambda r: r["white"] == "true" and r["photo"] == "true" and int(r["hp"]) < 100,
         "the joining warden has no white / polaroid / hit on their screen", report(c, "client", "shot_here"))
    need(lambda r: r["private"] == "true" and r["root_seen"] == "false" and r["leak"] == "false",
         "the host sees him run at the other's back", report(h, "host", "rush_other"))
    need(lambda r: int(r["mirror"]) > 0, "the joining warden does not see him run at them", report(c, "client", "rush_here"))
    need(lambda r: r["window"] == "true" and r["private"] == "true" and r["root_seen"] == "false" and r["leak"] == "false",
         "him at the other's window is not theirs alone", report(h, "host", "window_other"))
    need(lambda r: int(r["mirror"]) > 0, "the joining warden does not see him at their window", report(c, "client", "window_here"))
    before = report(c, "client", "window_here")
    need(lambda r: r["photo"] == "true" and before is not None and int(r["hp"]) < int(before["hp"]),
         "the shot through their window: no polaroid / no hit on their screen", report(c, "client", "window_shot_here"))
    need(lambda r: r["close"] == "true" and r["big"] == "true", "the last picture is not on their screen", report(c, "client", "last_here"))
    need(lambda r: r["down"] == "true" or int(r["hp"]) <= 0, "the last picture did not end them", report(c, "client", "last_after"))
    need(lambda r: r["white"] == "false" and r["close"] == "false" and r["photo"] == "false" and r["leak"] == "false",
         "the host's screen had some of it", report(h, "host", "host_end"))
    print("\n".join(l for l in (h + c).splitlines() if "COOP PHOTO" in l))
    if failures:
        print("COOP PHOTO: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP PHOTO: PASS")


if __name__ == "__main__":
    main()
