#!/usr/bin/env python3
"""Co-op Silent Man check: a host and a client of the game on this machine
(tools/coop_quiet.tscn). PASS when every scare of the Silent Man is his quarry's alone:
his catch, his hold at the neck, his coming apart in the light and his neck round a
corner on the joining warden are on their screen and nowhere on the host's; his catch
on the host is the host's and the joining machine shows nothing of him.

    python godot/tools/coop_quiet.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_quiet")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_quiet.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def report(text, role, what):
    m = re.search(r"COOP QUIET %s: %s (.*)" % (role, what), text)
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
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if "SCRIPT ERROR" in line or "gave up waiting" in line:
                where = lines[i + 1].strip() if i + 1 < len(lines) else ""
                failures.append("%s: %s %s" % (role, line.strip(), where))
                break

    def expect(text, role, what, ok, why):
        r = report(text, role, what)
        if r is None or not ok(r):
            failures.append("%s: %s" % (why, r))

    # His catch at the joining warden's ear.
    expect(h, "host", "strike_other", lambda r: r["leak"] == "false" and r["close"] == "false" and r["private"] == "true", "the host sees his catch on the other warden")
    expect(c, "client", "strike_here", lambda r: r["close"] == "true", "the joining warden has no catch on their screen")
    expect(c, "client", "strike_after", lambda r: float(r["roll"]) > 0.1, "the joining warden's view is not turned by his catch")
    # At their neck.
    expect(h, "host", "neck_other", lambda r: r["leak"] == "false" and r["private"] == "true", "the host sees him at the other warden's neck")
    expect(c, "client", "neck_here", lambda r: r["close"] == "true" and r["slow"] == "true", "the joining warden is not held at the neck (hands, half speed)")
    # Their torch on him.
    expect(h, "host", "lit_other", lambda r: r["leak"] == "false", "the host sees him come apart in the other warden's light")
    expect(c, "client", "lit_here", lambda r: r["dissolve"] == "true", "the joining warden does not see him come apart (the dither)")
    # His neck round a corner.
    expect(h, "host", "peek_other", lambda r: r["leak"] == "false" and r["private"] == "true", "the host sees his neck round the other warden's corner")
    expect(c, "client", "peek_here", lambda r: r["neck"] == "true", "the joining warden does not see his neck round the corner")
    # His catch on the host.
    expect(h, "host", "strike_host", lambda r: r["close"] == "true", "the host has no catch on their screen")
    expect(c, "client", "host_struck_seen_from_here", lambda r: r["close"] == "false" and r["mirror"] == "0", "the joining machine sees the host's catch")
    print("\n".join(l for l in (h + c).splitlines() if "COOP QUIET" in l))
    if failures:
        print("COOP QUIET: FAIL")
        for f in failures:
            print("  - " + f)
        sys.exit(1)
    print("COOP QUIET: PASS")


if __name__ == "__main__":
    main()
