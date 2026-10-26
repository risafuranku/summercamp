#!/usr/bin/env python3
"""The pub for two: a host and a joining copy (tools/pub_coop.tscn), then what each saw of
the bar compared. PASS when the beer the host poured is served on both machines, the
joining one sees the host at the tap (and is refused it), and the mug it washed and the
head it took off the keg reach the host's bar.

    python godot/tools/pub_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "pub_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/pub_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: the whole tree, or it keeps the port.
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'-> \["PUB (\w+) (\w+)", (.*)\]\s*$', line)
        if m:
            out[m.group(2)] = m.group(3).strip()
    return text, out


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
        print("PUB COOP: FAIL (timed out)")
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
    if not h.get("served") or h.get("served", "").startswith("0") or h.get("served") != c.get("served"):
        failures.append("served differs or nothing served (host %s, client %s)" % (h.get("served"), c.get("served")))
    if '"tap"' not in c.get("taken", ""):
        failures.append("the joining machine does not see the host at the tap: %s" % c.get("taken"))
    if c.get("tap_open", "").strip('"') == "tap":
        failures.append("the tap opened for the joining warden while the host was at it")
    after = [x.strip() for x in h.get("after_client", "").split(",")]
    if len(after) < 2 or after[0] != c.get("mugs", "").strip():
        failures.append("the mug washed on the joining machine is not on the host's board (host %s, client %s)" % (after, c.get("mugs")))
    if len(after) < 2 or after[1] != "false" or c.get("keg", "").strip() != "false":
        failures.append("the head taken off on the joining machine is still on at the host (host %s, client %s)" % (after, c.get("keg")))
    print("PUB COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
