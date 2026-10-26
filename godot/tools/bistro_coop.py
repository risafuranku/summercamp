#!/usr/bin/env python3
"""The bistro for two: a host and a joining copy (tools/bistro_coop.tscn), then what each
saw of the kitchen compared. PASS when the joining machine has the host's slices in its
pan, sees the host at the stove (and is refused it), the pot it topped up and the chips
it cut reach the host's kitchen, and the host's plate is served on both.

    python godot/tools/bistro_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "bistro_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/bistro_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: the whole tree, or it keeps the port.
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'-> \["BISTRO (\w+) (\w+)", (.*)\]\s*$', line)
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
        print("BISTRO COOP: FAIL (timed out)")
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
    # The same slices in the same places (their seconds in the oil were read at another moment).
    def pan(v):
        return re.sub(r'"t": \[[^\]]*\]', "", v or "")
    if not h.get("cooking") or pan(h.get("cooking")) != pan(c.get("cooking")) or h.get("cooking").count('"down"') != 2:
        failures.append("the pans differ (host %s, client %s)" % (h.get("cooking"), c.get("cooking")))
    if '"stove"' not in c.get("taken", ""):
        failures.append("the joining machine does not see the host at the stove: %s" % c.get("taken"))
    if c.get("stove_open", "").strip('"') == "stove":
        failures.append("the stove opened for the joining warden while the host was at it")
    after = h.get("after_client", "")
    pot_host = re.findall(r"(\d+)$", after)
    if not pot_host or pot_host[-1] != c.get("pot"):
        failures.append("the pot differs after the top-up (host %s, client %s)" % (pot_host, c.get("pot")))
    if '"chips_raw": 2' not in after:
        failures.append("the chips cut on the joining machine are not in the host's kitchen: %s" % after)
    if not h.get("served") or h.get("served") != c.get("served") or h.get("served", "").startswith("0"):
        failures.append("served differs or nothing served (host %s, client %s)" % (h.get("served"), c.get("served")))
    print("BISTRO COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
