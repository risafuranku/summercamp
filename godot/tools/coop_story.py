#!/usr/bin/env python3
"""A story camp for two (tools/coop_story.tscn): the host makes a story camp for co-op,
the other warden joins, reads Vera's mail and patches the old cabin; Vera's checklist is
the host's and must move on both machines. With --demo also the demo's end for two: the
clock stops on both, the grandson's mail and "Vera's" answer come to both, the joining
warden gets the trial's nag at the PC.

    python godot/tools/coop_story.py [OUT_DIR] [--demo]

Each copy saves into its own APPDATA under OUT_DIR, never the warden's own saves.
"""
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
DEMO = "--demo" in sys.argv
OUT = ARGS[0] if ARGS else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_story")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    env = dict(os.environ)
    env["APPDATA"] = os.path.join(OUT, "appdata_" + role)
    os.makedirs(env["APPDATA"], exist_ok=True)
    extra = ["--demo"] if DEMO else []
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "--resolution", "1280x720", "res://tools/coop_story.tscn", "--",
                             "--role=%s" % role, "--out=%s" % OUT] + extra, stdout=log, stderr=subprocess.STDOUT, env=env)


def tagged(role):
    text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
    out = {}
    for line in text.splitlines():
        if line.startswith("STORY_TAG "):
            d = json.loads(line[len("STORY_TAG "):])
            out[d["tag"]] = d
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
        print("COOP STORY: FAIL (timed out)")
        return 1
    failures = []
    ht, h = tagged("host")
    ct, c = tagged("client")
    for role, text in (("host", ht), ("client", ct)):
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        if "gave up waiting" in text:
            failures.append("%s: gave up waiting" % role)
    for k in ("start", "joined", "read", "fixed", "day4", "end"):
        if k in h:
            print("host  ", k, h[k])
    for k in ("joined", "read", "fixed", "day4", "answer", "nag"):
        if k in c:
            print("client", k, c[k])

    def need(cond, msg):
        if not cond:
            failures.append(msg)

    if any(t not in h for t in ("start", "joined", "read", "fixed")) or any(t not in c for t in ("joined", "read", "fixed")):
        failures.append("missing tags (host %s, client %s)" % (sorted(h), sorted(c)))
    else:
        need(not h["start"]["sandbox"] and h["start"]["step"] == "read_vera" and h["start"]["vera"], "the host's camp is no story camp at its start")
        need(not c["joined"]["sandbox"], "the joining copy thinks it is a sandbox camp")
        need(c["joined"]["following"] and c["joined"]["objective"] != "" and c["joined"]["objective"] == h["joined"]["objective"], "the checklist does not show on the joining copy")
        need(c["joined"]["vera"], "Vera's mail did not come to the joining copy")
        need(h["read"]["vera_read"] and h["read"]["step"] != "read_vera", "reading Vera's mail on the joining copy did not move the host's checklist")
        need(c["read"]["objective"] == h["read"]["objective"], "the joining copy's checklist did not follow (%s | %s)" % (c["read"]["objective"], h["read"]["objective"]))
        need(not h["fixed"]["ruin_broken"] and h["fixed"]["step"] not in ("read_vera", "fix_cabin"), "patching the old cabin from the joining copy did not tick it on the host")
        need(c["fixed"]["objective"] == h["fixed"]["objective"], "the joining copy's checklist did not follow the patch")
    if DEMO:
        if any(t not in h for t in ("day4",)) or any(t not in c for t in ("day4", "answer", "nag")):
            failures.append("missing the demo's tags (host %s, client %s)" % (sorted(h), sorted(c)))
        else:
            need(h["day4"]["over"] and h["day4"]["pace"] == 0.0 and "sister:new" in h["day4"]["demo"], "the host's demo did not end (clock, mail)")
            need(c["day4"]["over"] and c["day4"]["pace"] == 0.0 and any(m.startswith("sister") for m in c["day4"]["demo"]), "the joining copy's demo did not end (clock, mail)")
            need(abs(c["day4"]["hour"] - h["day4"]["hour"]) < 0.05, "the clocks stopped apart (%.3f | %.3f)" % (c["day4"]["hour"], h["day4"]["hour"]))
            need(any(m.startswith("answer") for m in c["answer"]["demo"]), "Vera's answer did not come to the joining copy")
            need(c["nag"]["nag"], "no trial's nag at the joining warden's PC")
    print("COOP STORY: %s" % ("PASS" if not failures else "FAIL"))
    for f in failures:
        print("  -", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
