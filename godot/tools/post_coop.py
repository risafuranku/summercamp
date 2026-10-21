#!/usr/bin/env python3
"""The second monitor for two: a host and a joining copy (tools/post_coop.tscn), then
what each saw compared. PASS when the joining warden's order reaches the host (and is
paid once), the host's clock brings the postman to the counter on both machines, and the
joining warden's signature puts the second monitor on the desk on both.

    python godot/tools/post_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "post_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "--resolution", "1280x720", "res://tools/post_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'POST_TAG \["POST (\w+) (\w+)", "(\w*)", (\w+), (-?\d+)\]', line)
        if m:
            out[m.group(2)] = (m.group(3), m.group(4) == "true", int(m.group(5)))
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
        print("POST COOP: FAIL (timed out)")
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

    def want(d, tag, stage, dual, who):
        got = d.get(tag)
        if got is None or got[0] != stage or got[1] != dual:
            failures.append("%s %s: want %s/%s, got %s" % (who, tag, stage, dual, got))

    want(c, "ordered", "ordered", False, "client")
    want(h, "ordered", "ordered", False, "host")
    want(h, "arriving", "arriving", False, "host")
    want(h, "at_desk", "at_desk", False, "host")
    want(c, "at_desk", "at_desk", False, "client")
    want(c, "delivered", "delivered", True, "client")
    want(h, "delivered", "delivered", True, "host")
    if "before" in c and "ordered" in h and "ordered" in c:
        paid = c["before"][2] - h["ordered"][2]
        if paid != 149:
            failures.append("the host's till took %d, not 149" % paid)
        if h["ordered"][2] != c["ordered"][2]:
            failures.append("the tills differ: host %d, client %d" % (h["ordered"][2], c["ordered"][2]))
    print("POST COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
