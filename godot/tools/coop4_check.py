#!/usr/bin/env python3
"""Co-op for four: a host and three joining copies of the game on this machine
(tools/coop4_check.tscn), then what each wrote compared. PASS when everyone sees the
other three as four different wardens, the host's till pays what two of them spent (each
once), the night waits for the last one up and all of them wake in the morning.

    python godot/tools/coop4_check.py [OUT_DIR]
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "coop4_check")
ROLES = ["host", "c1", "c2", "c3"]


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "res://tools/coop4_check.tscn", "--resolution", "640x360",
                             "--", "--role=%s" % role, "--out=%s" % OUT], stdout=log, stderr=subprocess.STDOUT)


def end_tree(proc):
    subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)


def load(tag):
    p = os.path.join(OUT, "%s.json" % tag)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else None


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        full = os.path.join(OUT, f)
        if os.path.isfile(full) and not f.endswith(".log"):
            os.remove(full)
    procs = {}
    procs["host"] = run("host")
    time.sleep(2.0)
    for r in ROLES[1:]:
        procs[r] = run(r)
        time.sleep(1.5)
    # A fifth, once the four are in: turned away.
    procs["c4"] = run("c4")
    try:
        for r in ROLES[1:] + ["c4"]:
            procs[r].wait(timeout=1700)
        procs["host"].wait(timeout=90)
    except subprocess.TimeoutExpired:
        for p in procs.values():
            end_tree(p)
        print("COOP4 CHECK: FAIL (timed out)")
        return 1
    failures = []
    for role in ROLES:
        text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
        if "SCRIPT ERROR" in text:
            failures.append("%s: SCRIPT ERROR in the log: %s" % (role, [l for l in text.splitlines() if "SCRIPT ERROR" in l][:2]))
        if "gave up waiting" in text:
            failures.append("%s: %s" % (role, [l for l in text.splitlines() if "gave up waiting" in l][0]))
    # Everyone sees the other three, four different wardens.
    for role in ROLES:
        fp = load("%s_seen" % role)
        if fp is None:
            failures.append("%s: no fingerprint of the others" % role)
            continue
        ws = fp["wardens"]
        if len(ws) != 3 or not all(w[3] for w in ws):
            failures.append("%s does not see three others %s" % (role, ws))
        models = sorted([w[0] for w in ws] + [fp["my_look"][0]])
        if models != [0, 1, 2, 3]:
            failures.append("%s: the four are not four different wardens (figures %s)" % (role, models))
        if role != "host" and fp["my_slot"] not in (1, 2, 3):
            failures.append("%s has no place on the line (%s)" % (role, fp["my_slot"]))
    slots = sorted(load("%s_seen" % r)["my_slot"] for r in ROLES[1:] if load("%s_seen" % r))
    if slots != [1, 2, 3]:
        failures.append("the joining wardens' places on the line are not 1, 2, 3 (%s)" % slots)
    # The fifth: told the camp is full, not let in; the others never heard of them.
    c4 = load("c4_full")
    if c4 is None:
        failures.append("the fifth warden wrote nothing")
    else:
        if "full" not in c4["notice"].lower():
            failures.append("the fifth was not told the camp is full (%r)" % c4["notice"])
        if c4["active"] or c4["in_game"]:
            failures.append("the fifth got into the camp (active %s, in game %s)" % (c4["active"], c4["in_game"]))
    ht0 = load("host_till")
    if ht0 is not None and len(ht0["wardens"]) != 3:
        failures.append("the host has %d others after the fifth called" % len(ht0["wardens"]))
    for role in ROLES[1:]:
        fp = load("%s_private" % role)
        if fp is not None and len(fp["wardens"]) != 3:
            failures.append("%s has %d others after the fifth called" % (role, len(fp["wardens"])))
    # The till: both spends paid by the host, once each.
    hs, ht = load("host_seen"), load("host_till")
    if hs is None or ht is None:
        failures.append("missing till fingerprints")
    elif hs["money"] - ht["money"] != 80:
        failures.append("the host's till paid %d of the 80 the two spent (%d -> %d)" % (hs["money"] - ht["money"], hs["money"], ht["money"]))
    # All four round the fire, in the cabin, down the pipes: each sees the other three.
    for scene, key in (("fire", "att_mates"), ("room", "room_figs"), ("pipes", "pipe_mates")):
        for role in ROLES:
            fp = load("%s_%s" % (role, scene))
            if fp is None:
                failures.append("%s: no fingerprint of the %s" % (role, scene))
            elif fp[key] != 3:
                failures.append("%s sees %s of the other three in the %s" % (role, fp[key], scene))
    blocked = [r for r in ROLES[1:] if load("%s_pipes" % r) and any(w in load("%s_pipes" % r)["pipe_net"]["status"] for w in ("boots", "torch"))]
    if not blocked:
        failures.append("nobody behind the first crawled into anyone in the pipes %s" % [(load("%s_pipes" % r) or {}).get("pipe_net", {}).get("status") for r in ROLES[1:]])
    hashes = set((load("%s_pipes" % r) or {}).get("pipe_net", {}).get("hash") for r in ROLES)
    if len(hashes) != 1:
        failures.append("the four are not in the same pipes (%d networks)" % len(hashes))
    # The night waits for the last one up, then everyone wakes.
    hw = load("host_waiting")
    if hw is None:
        failures.append("missing the host's fingerprint with one still up")
    elif hw["night_passing"]:
        failures.append("the night passed with one warden still up")
    hm = load("host_morning")
    for role in ROLES:
        fm = load("%s_morning" % role)
        if fm is None:
            failures.append("%s did not see the morning" % role)
        elif hm is not None and fm["day"] != hm["day"]:
            failures.append("%s woke on day %s, the host on %s" % (role, fm["day"], hm["day"]))
    if hm is not None and hs is not None and hm["day"] <= hs["day"]:
        failures.append("the night did not pass (day %s -> %s)" % (hs["day"], hm["day"]))
    # The night: one enemy only for the warden second on the line, then one for all.
    hp = load("host_private")
    if hp is None or hp["enemy_seen"] != 0:
        failures.append("the host sees the enemy that is only one joining warden's (%s)" % (hp or {}).get("enemy_seen"))
    for role in ROLES[1:]:
        fp, fs = load("%s_private" % role), load("%s_shared" % role)
        if fp is None or fs is None:
            failures.append("%s: missing night fingerprints" % role)
            continue
        mine = fp["my_slot"] == 2
        if mine and fp["enemy_seen"] == 0:
            failures.append("%s (second on the line) does not see the enemy hunting them alone" % role)
        if not mine and fp["enemy_seen"] != 0:
            failures.append("%s sees the enemy that is only the second one's (%d)" % (role, fp["enemy_seen"]))
        if fs["enemy_seen"] == 0:
            failures.append("%s does not see the enemy everyone should" % role)
    # One bus for four: it waits for the last one, then all ride it; at U Jezera together.
    hw = load("host_bus_wait")
    if hw is None or hw["bus_state"] != "held":
        failures.append("the bus did not wait for the fourth buying a ticket (%s)" % (hw or {}).get("bus_state"))
    for role in ROLES:
        br, tw, pb = load("%s_bus_ride" % role), load("%s_town" % role), load("%s_pub" % role)
        if br is None or br["bus_state"] not in ("riding", "stopping", "done"):
            failures.append("%s did not ride the bus (%s)" % (role, (br or {}).get("bus_state")))
        elif br["bus_mates"] != 3:
            failures.append("%s sees %d of the other three on the bus" % (role, br["bus_mates"]))
        if tw is None:
            failures.append("%s did not get to Lesna" % role)
        if pb is None or pb["town_mates"] != 3:
            failures.append("%s sees %s of the other three at the bar of U Jezera" % (role, (pb or {}).get("town_mates")))
    # One went home: the other three still have each other (the host may be indoors), not them.
    for role in ("host", "c1", "c2"):
        fa = load("%s_after_c3" % role)
        if fa is None:
            failures.append("%s: no fingerprint after the fourth went home" % role)
        elif len(fa["wardens"]) != 2:
            failures.append("%s after the fourth went home: %s" % (role, fa["wardens"]))
    if failures:
        print("COOP4 CHECK: %d FAILURE(S)" % len(failures))
        for f in failures:
            print("  - " + f)
        return 1
    print("COOP4 CHECK: PASS (4 wardens, slots %s, till -80, night waited, day %s)" % (slots, hm["day"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
