#!/usr/bin/env python3
"""The voice for two (tools/voice_coop.tscn): the walkie in both bags, V held is the joining
warden's own voice (heard at the host as "local"), a click while it is held the walkie ("radio"),
and the choice stays for the next go. PASS when the host heard both and the joining side's
modes went local, radio, radio.

    python godot/tools/voice_coop.py [OUT_DIR]
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
# The windows on a desktop of their own: never the user's mouse (tools/hidden_desktop.py).
sys.path.insert(0, os.path.join(PROJECT, "..", "tools"))
import hidden_desktop as HIDDEN  # noqa: E402
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "voice_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/voice_coop.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def tags(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'VOICE_TAG \["VOICE (\w+) (\w+)", "(.*)"\]', line)
        if m:
            out[m.group(2)] = m.group(3)
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
        print("VOICE COOP: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tags("host")
    ct, c = tags("client")
    for role, text in (("host", ht), ("client", ct)):
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
        for line in text.splitlines():
            if "SCRIPT ERROR" in line:
                failures.append("%s: %s" % (role, line.strip()))
                break
    print("host:", h)
    print("client:", c)
    if "walkie=true" not in h.get("walkie", "") or "walkie=true" not in c.get("walkie", ""):
        failures.append("the walkie not in both bags")
    if "sending=local" not in c.get("v_held", ""):
        failures.append("V held: want local, got %s" % c.get("v_held"))
    if "sending=radio" not in c.get("v_clicked", ""):
        failures.append("V and a click: want radio, got %s" % c.get("v_clicked"))
    if "sending=radio" not in c.get("v_again", ""):
        failures.append("V again: want radio still, got %s" % c.get("v_again"))
    if ":local" not in h.get("heard_local", ""):
        failures.append("the host heard no local voice: %s" % h.get("heard_local"))
    if ":radio" not in h.get("heard_radio", ""):
        failures.append("the host heard no radio: %s" % h.get("heard_radio"))
    print("VOICE COOP: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  " + f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
