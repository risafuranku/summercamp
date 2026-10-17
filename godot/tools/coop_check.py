#!/usr/bin/env python3
"""Co-op check: a host and a client of the game on this machine (tools/coop_check.tscn),
then their camps compared. PASS when the joining copy has the host's camp to the tree
(seed, buildings, every tree and corn patch, the terrain), follows the host's clock into
the night, and each sees the other warden.

    python godot/tools/coop_check.py [OUT_DIR]

GODOT (env) is the Godot console binary; pictures and fingerprints go to OUT_DIR.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop_check")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "res://tools/coop_check.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
                            stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    # The console binary starts the game as its child: end the whole tree, or a stray
    # copy keeps the port (and answers the next run's calls).
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def load(tag):
    p = os.path.join(OUT, "%s.json" % tag)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else None


def diff_list(name, a, b, failures):
    if a != b:
        only_a = sorted(set(a) - set(b))
        only_b = sorted(set(b) - set(a))
        failures.append("%s differ: %d only on the host, %d only on the client (e.g. %s | %s)" % (
            name, len(only_a), len(only_b), only_a[:2], only_b[:2]))


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".json") or f.endswith(".png") or f in ("host_up", "client_ready"):
            os.remove(os.path.join(OUT, f))
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=420)
        host.wait(timeout=60)
    except subprocess.TimeoutExpired:
        end_tree(host)
        end_tree(client)
        print("COOP CHECK: FAIL (timed out)")
        return 1
    failures = []
    for role in ("host", "client"):
        text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log" % role)
        if "gave up waiting" in text:
            failures.append("%s: %s" % (role, [l for l in text.splitlines() if "gave up waiting" in l][0]))
    h, c = load("host"), load("client")
    hn, cn = load("host_night"), load("client_night")
    if h is None or c is None:
        failures.append("missing day fingerprints (host %s, client %s)" % (h is not None, c is not None))
    else:
        for k in ("seed", "money", "day", "weather", "beds", "derelict"):
            if h[k] != c[k]:
                failures.append("%s differs (host %s, client %s)" % (k, h[k], c[k]))
        if not h["derelict"]:
            failures.append("the host's new camp has no derelict cabin")
        diff_list("buildings", h["structures"], c["structures"], failures)
        diff_list("nature tiles", h["nature"], c["nature"], failures)
        diff_list("trees", h["trees"], c["trees"], failures)
        diff_list("terrain", h["terrain"], c["terrain"], failures)
        if abs(float(c["hour"]) - float(c["host_clock"])) > 0.1:
            failures.append("the client's clock is not the host's (%.2f, host sent %.2f)" % (c["hour"], c["host_clock"]))
        for fp in (h, c):
            if not fp["sandbox"]:
                failures.append("%s: not a sandbox camp" % fp["role"])
            if not fp["partner"] or not fp["other_visible"]:
                failures.append("%s: does not see the other warden" % fp["role"])
    # The joining warden's look, as the host sees it, and the host's as the other does.
    if h is not None and c is not None:
        if h["partner_look"] != [2, 4]:
            failures.append("the host sees the other warden as %s, not [2, 4]" % h["partner_look"])
        if c["partner_look"] != h["my_look"]:
            failures.append("the other sees the host as %s, not %s" % (c["partner_look"], h["my_look"]))
    # Built after the join.
    hb, cb = load("host_built"), load("client_built")
    if hb is None or cb is None:
        failures.append("missing build fingerprints")
    else:
        if not any(x.startswith("tent_1@(13, 16)") for x in hb["structures"]):
            failures.append("the host's tent was not built")
        diff_list("buildings after the build", hb["structures"], cb["structures"], failures)
    # The room: the other's job done in the host's camp, the host's back in the other's.
    hr, cr = load("host_room"), load("client_room")
    if hr is None or cr is None:
        failures.append("missing room fingerprints")
    else:
        if cr["task"] == "" or cr["task"] not in hr["room_done"]:
            failures.append("the other warden's job (%s) is not done in the host's camp %s" % (cr["task"], hr["room_done"]))
        if hr["task"] == "" or hr["task"] == cr["task"] or hr["task"] not in cr["room_done"]:
            failures.append("the host's own job (%s) is not done in the other room %s" % (hr["task"], cr["room_done"]))
        if sorted(hr["room_done"]) != sorted(cr["room_done"]):
            failures.append("the rooms differ (host %s, other %s)" % (hr["room_done"], cr["room_done"]))
    # The other warden's figure in the room: at the job in the cabin, on their belly in the tent.
    hs = load("host_sees_work")
    if hs is None or hs["room_figure"] not in ("sweep", "crouch", "stand"):
        failures.append("the host does not see the other warden at their job (%s)" % (hs or {}).get("room_figure"))
    for tag in ("host_tent", "client_tent"):
        ft = load(tag)
        if ft is None or ft["room_figure"] != "prone":
            failures.append("%s: the other warden is not lying in the tent (%s)" % (tag, (ft or {}).get("room_figure")))
    # The boat out on the host's lake with the other warden rowing it.
    hw = load("host_rowing")
    if hw is None:
        failures.append("missing rowing fingerprint")
    else:
        if float(hw["boat_from_home"]) < 4.0:
            failures.append("the boat did not leave the jetty on the host's lake (%.1f m)" % hw["boat_from_home"])
        if hw["other_pose"] != "row":
            failures.append("the other warden is not rowing on the host's lake (%s)" % hw["other_pose"])
    if hn is None or cn is None:
        failures.append("missing night fingerprints (host %s, client %s)" % (hn is not None, cn is not None))
    else:
        if float(cn["hour"]) < 21.0 and float(cn["hour"]) > 5.0:
            failures.append("night: the client's clock did not follow (%.2f)" % cn["hour"])
        for fp in (hn, cn):
            if not fp["other_visible"]:
                failures.append("night: %s does not see the other warden" % fp["role"])
    if failures:
        print("COOP CHECK: %d FAILURE(S)" % len(failures))
        for f in failures:
            print("  - " + f)
        return 1
    print("COOP CHECK: PASS (seed %d, %d buildings, %d trees, %d terrain nodes, clock %.2f, night %.2f / %.2f)" % (
        h["seed"], len(h["structures"]), len(h["trees"]), len(h["terrain"]), c["hour"], hn["hour"], cn["hour"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
