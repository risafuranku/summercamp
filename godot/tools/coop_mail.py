#!/usr/bin/env python3
"""Mail in a camp hosted from a save, for two (tools/coop_mail.tscn): a single-player
sandbox camp saved, hosted, joined; the host's clock runs on. PASS when new bookings keep
coming after the join and the joining copy has the host's inbox.

    python godot/tools/coop_mail.py [OUT_DIR]

Each copy saves into its own APPDATA under OUT_DIR, never the warden's own saves.
"""
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
# The windows on a desktop of their own: never the user's mouse (tools/hidden_desktop.py).
sys.path.insert(0, os.path.join(PROJECT, "..", "tools"))
import hidden_desktop as HIDDEN  # noqa: E402
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_mail")
## Optional: a save to host instead of the camp the test makes (python coop_mail.py OUT SAVE).
SAVE = sys.argv[2] if len(sys.argv) > 2 else ""


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_" + role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    if role == "host" and SAVE:
        # A copy of the given save in the host's own user:// (never the warden's file).
        dst = os.path.join(env["APPDATA"], "Godot", "app_userdata", "Cursed Camp Simulator Manager", "debug")
        os.makedirs(dst, exist_ok=True)
        shutil.copyfile(SAVE, os.path.join(dst, "hosted.ccs2save.json"))
        env["COOP_MAIL_SAVE"] = "user://debug/hosted.ccs2save.json"
    return HIDDEN.popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_mail.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT, env=env)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        m = re.search(r'MAIL_TAG \["MAIL (\w+) (\w+)", (\d+), ([\d.]+), (\d+), (\d+), (-?\d+), (-?\d+), "([^"]*)"\]', line)
        if m:
            out[m.group(2)] = {"day": int(m.group(3)), "hour": float(m.group(4)), "inbox": int(m.group(5)), "scheduled": int(m.group(6)),
                               "free": int(m.group(7)), "money": int(m.group(8)), "rolled": m.group(9)}
    return text, out


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p):
            os.remove(p)
        elif f.startswith("appdata_"):
            shutil.rmtree(p, ignore_errors=True)
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=900)
        host.wait(timeout=120)
    except subprocess.TimeoutExpired:
        for p in (host, client):
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(p.pid)], capture_output=True)
        print("COOP MAIL: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
    for k, v in sorted(h.items(), key=lambda kv: (len(kv[0]), kv[0])):
        print("host  ", k, v)
    for k, v in sorted(c.items()):
        print("client", k, v)
    need = ("solo", "hosted", "joined", "run1", "run2")
    if any(t not in h for t in need) or "end" not in c:
        failures.append("missing tags (host %s, client %s)" % (sorted(h), sorted(c)))
    else:
        if h["hosted"]["inbox"] < h["solo"]["inbox"]:
            failures.append("the hosted camp lost mail (%d -> %d)" % (h["solo"]["inbox"], h["hosted"]["inbox"]))
        if h["run2"]["inbox"] <= h["joined"]["inbox"]:
            failures.append("no new mail after the join (%d -> %d)" % (h["joined"]["inbox"], h["run2"]["inbox"]))
        if c["end"]["inbox"] != h["run2"]["inbox"]:
            failures.append("the joining copy's inbox differs (%d, host %d)" % (c["end"]["inbox"], h["run2"]["inbox"]))
    print("COOP MAIL: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
