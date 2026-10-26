#!/usr/bin/env python3
"""The four places for two: a host and a joining copy (tools/podniky_coop.tscn), then what
each saw compared. PASS when a corn drink handed over on either machine is served on both,
the pub's bills are asked for on both and one settled on the joining machine is paid in the
host's pub (and its LUCKY 7 spun there), the bistro's grill and bufet ops from the joining
machine reach the host, and the Jednota's deli parcel cut there is done in the host's shop.

    python godot/tools/podniky_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "podniky_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/podniky_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: the whole tree, or it keeps the port.
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'-> \["PODNIKY (\w+) (\w+)", (.*)\]\s*$', line)
        if m:
            out[m.group(2)] = m.group(3).strip()
    return text, out


def num(v):
    try:
        return int(str(v).strip().strip('"'))
    except ValueError:
        return -1


def main():
    # The wardens' names may be Czech: print them whatever the console's code page.
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
        client.wait(timeout=1500)
        host.wait(timeout=180)
    except subprocess.TimeoutExpired:
        end_tree(host)
        end_tree(client)
        print("PODNIKY COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        for line in text.splitlines():
            if "SCRIPT ERROR" in line and "voice.gd" not in text[text.find(line):text.find(line) + 400]:
                failures.append("%s: %s" % (role, line.strip()))
                break
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
    print("host:", h)
    print("client:", c)
    if num(h.get("corn_served")) < 1 or num(c.get("corn_served")) != num(h.get("corn_served")):
        failures.append("the host's drink is not served on both (host %s, client %s)" % (h.get("corn_served"), c.get("corn_served")))
    if num(h.get("corn_after")) != num(h.get("corn_served")) + 1:
        failures.append("the joining machine's drink did not reach the host (%s -> %s)" % (h.get("corn_served"), h.get("corn_after")))
    if num(h.get("pub_bills")) < 1 or num(c.get("pub_bills")) != num(h.get("pub_bills")):
        failures.append("the bills differ (host %s, client %s)" % (h.get("pub_bills"), c.get("pub_bills")))
    if c.get("pub_settled") != "true" or num(h.get("pub_bills_after")) != num(h.get("pub_bills")) - 1:
        failures.append("the bill settled on the joining machine is not paid at the host's (%s, %s -> %s)" % (c.get("pub_settled"), h.get("pub_bills"), h.get("pub_bills_after")))
    if num(h.get("pub_slot")) != 777:
        failures.append("the LUCKY 7 pulled on the joining machine did not spin at the host's: %s" % h.get("pub_slot"))
    if h.get("rest_grill") != "true":
        failures.append("the sausage laid on the grill did not reach the host")
    if c.get("rest_served") != "true" or num(h.get("rest_bufet_after")) != num(h.get("rest_bufet")) - 1:
        failures.append("the bufet ticket served on the joining machine is not served at the host's (%s, %s -> %s)" % (c.get("rest_served"), h.get("rest_bufet"), h.get("rest_bufet_after")))
    if c.get("shop_cut") != "true" or num(h.get("shop_deli_after")) != num(h.get("shop_deli")) - 1:
        failures.append("the deli parcel cut on the joining machine is not done at the host's (%s, %s -> %s)" % (c.get("shop_cut"), h.get("shop_deli"), h.get("shop_deli_after")))
    if '"tap"' not in c.get("pub_taken", ""):
        failures.append("the joining machine does not see the host at the tap: %s" % c.get("pub_taken"))
    print("PODNIKY COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
