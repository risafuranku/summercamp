#!/usr/bin/env python3
"""The reception's windows for two: a host and a joining copy (tools/window_coop.tscn).
PASS when the warden outside sees, through the office's glass, the host at the PC, the
host in the back room through its own window, the curtain drawn and the lights out.

    python godot/tools/window_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "window_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "--resolution", "1280x720", "res://tools/window_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'WINDOW_TAG \["WINDOW (\w+) (\w+)", (\d+), (\w+), (\w+), (\w+)\]', line)
        if m:
            out[m.group(2)] = (int(m.group(3)), m.group(4) == "true", m.group(5) == "true", m.group(6) == "true")
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
        print("WINDOW COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if "SCRIPT ERROR" in line and "post" in text[text.find(line):text.find(line) + 300].lower():
                failures.append("%s: %s" % (role, line.strip()))
                break
    print("host:", h)
    print("client:", c)

    def want(tag, figs, curtain, lights):
        got = c.get(tag)
        if got is None or got[0] < figs or got[1] != curtain or got[2] != lights or not got[3]:
            failures.append("%s: want %d figure(s), curtain open %s, lights %s, live; got %s" % (tag, figs, curtain, lights, got))

    want("pc", 1, True, True)
    want("back", 1, True, True)
    want("curtain", 1, False, True)
    want("dark", 1, True, False)
    print("WINDOW COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
