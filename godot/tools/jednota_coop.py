#!/usr/bin/env python3
"""The Jednota for two: a host and a joining copy (tools/jednota_coop.tscn), then what each
saw of the shop compared. PASS when the one the host served at the till is served on both
machines, the joining one sees the host at the till and is refused it, the box it made up
in the storeroom and shelved is on the host's trolley and rack the same, and the one it
served at the till once the host stepped away is served on the host's machine too.

    python godot/tools/jednota_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "jednota_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/jednota_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: the whole tree, or it keeps the port.
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'-> \["JED (\w+) (\w+)", (.*)\]\s*$', line)
        if m:
            out[m.group(2)] = m.group(3).strip()
    return text, out


def first_int(s):
    m = re.search(r"-?\d+", s or "")
    return int(m.group(0)) if m else None


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if not f.endswith(".log"):
            os.remove(os.path.join(OUT, f))
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        end_tree(host)
        end_tree(client)
        print("JEDNOTA COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
    print("host:", h)
    print("client:", c)
    if not h.get("served") or (first_int(h.get("served")) or 0) < 1 or h.get("served") != c.get("served"):
        failures.append("served differs or nothing served (host %s, client %s)" % (h.get("served"), c.get("served")))
    if '"till"' not in c.get("taken", ""):
        failures.append("the joining machine does not see the host at the till: %s" % c.get("taken"))
    if c.get("till_open", "").strip('"') == "till":
        failures.append("the joining warden got the host's till")
    if (first_int(c.get("box")) or 0) <= 0:
        failures.append("no box made up in the storeroom: %s" % c.get("box"))
    if (first_int(c.get("shelved")) or 0) <= 0:
        failures.append("the box not shelved: %s" % c.get("shelved"))
    if not c.get("counts") or h.get("after_client", "").replace(" ", "") != c.get("counts", "").replace(" ", ""):
        failures.append("the rack and the trolley differ (host %s, client %s)" % (h.get("after_client"), c.get("counts")))
    if not c.get("after_till") or h.get("after_till") != c.get("after_till") or (first_int(c.get("after_till")) or 0) < 2:
        failures.append("the one served at the joining machine's till is not served on the host (host %s, client %s)" % (h.get("after_till"), c.get("after_till")))
    print("JEDNOTA COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
