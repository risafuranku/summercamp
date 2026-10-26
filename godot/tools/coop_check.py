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
    return subprocess.Popen([GODOT, "--audio-driver", "Dummy", "--path", PROJECT, "res://tools/coop_check.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
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
        if f.endswith(".json") or f.endswith(".png") or f in ("host_up", "client_ready", "task_host", "task_client"):
            os.remove(os.path.join(OUT, f))
    host = run("host")
    time.sleep(2.0)
    client = run("client")
    try:
        client.wait(timeout=900)
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
        if "failure 10:2" not in h["derelict"]:
            failures.append("the old cabin the host puts in is not at the room the test opens, 10:2 (%s)" % h["derelict"])
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
        # Called by their warden's name (both copies play the same warden here).
        if not c.get("my_name") or h.get("partner_name") != c.get("my_name"):
            failures.append("the host calls the other warden %r, not their warden's name %r" % (h.get("partner_name"), c.get("my_name")))
        if not h.get("my_name") or c.get("partner_name") != h.get("my_name"):
            failures.append("the other calls the host %r, not their warden's name %r" % (c.get("partner_name"), h.get("my_name")))
    # The barrier, worked from the road by the joining warden: up and down on both.
    hg, cg, hgd, cgd = load("host_gate"), load("client_gate"), load("host_gate_down"), load("client_gate_down")
    if None in (hg, cg, hgd, cgd):
        failures.append("missing barrier fingerprints")
    else:
        if not cg["gate_up"] or not hg["gate_up"]:
            failures.append("the joining warden's E did not raise the barrier (theirs %s, the host's %s)" % (cg["gate_up"], hg["gate_up"]))
        if cgd["gate_up"] or hgd["gate_up"]:
            failures.append("the joining warden's second E did not lower it (theirs %s, the host's %s)" % (cgd["gate_up"], hgd["gate_up"]))
    # One radio: the host's song on the other set too, switched off from either.
    hr_, cr_, ho_ = load("host_radio"), load("client_radio"), load("host_radio_off")
    if hr_ is None or cr_ is None or ho_ is None:
        failures.append("missing radio fingerprints")
    else:
        if not hr_["radio"].get("id") or (hr_["radio"].get("k"), hr_["radio"].get("id")) != (cr_["radio"].get("k"), cr_["radio"].get("id")) or not cr_["radio"].get("playing"):
            failures.append("the radio is not the same on both (host %s, other %s)" % (hr_["radio"], cr_["radio"]))
        if ho_["radio"].get("on", True):
            failures.append("the other warden's switch did not turn the host's radio off")
    # Built after the join.
    hb, cb = load("host_built"), load("client_built")
    if hb is None or cb is None:
        failures.append("missing build fingerprints")
    else:
        if not any(x.startswith("tent_1@(13, 16)") for x in hb["structures"]):
            failures.append("the host's tent was not built")
        diff_list("buildings after the build", hb["structures"], cb["structures"], failures)
    # By the fire: each sees the other sitting there; the other's sausage out (the host's
    # logs lit it on both). On the court: each one's kicks on both machines.
    hf, cf = load("host_fire"), load("client_fire")
    if hf is None or cf is None:
        failures.append("missing fire fingerprints")
    else:
        if not hf["att_me"] or not cf["att_me"] or hf["att_me"]["id"] != "11,12" or cf["att_me"]["id"] != "11,12":
            failures.append("not both by the fire (host %s, client %s)" % (hf["att_me"], cf["att_me"]))
        if hf["att_mate"] not in ("sit", "eat") or cf["att_mate"] not in ("sit", "eat", "guitar"):
            failures.append("the other warden is not seen sitting by the fire (host sees %r, client sees %r)" % (hf["att_mate"], cf["att_mate"]))
        if not cf["att_me"].get("x", {}).get("ro", False):
            failures.append("the other warden's sausage is not out over the fire (%s)" % cf["att_me"])
    hc, cc = load("host_court"), load("client_court")
    if hc is None or cc is None:
        failures.append("missing court fingerprints")
    else:
        if -12 not in hc["court_kicked"]:
            failures.append("the other warden's kicks did not reach the host's court %s" % hc["court_kicked"])
        if -11 not in cc["court_kicked"]:
            failures.append("the host's kicks are not seen on the other court %s" % cc["court_kicked"])
        if not hc["att_mate"] or not cc["att_mate"]:
            failures.append("the other warden is not seen on the court (host %r, client %r)" % (hc["att_mate"], cc["att_mate"]))
    # Knocked down: the other warden lies there (seen so on the host's), and is got up.
    cd, hd, cl = load("client_down"), load("host_down"), load("client_lifted")
    if cd is None or hd is None or cl is None:
        failures.append("missing knocked-down fingerprints")
    else:
        if not cd["down"]:
            failures.append("the other warden did not go down (%s)" % cd["hp"])
        if not hd["partner_down"] or hd["other_pose"] != "prone":
            failures.append("the host does not see the other warden lying there (%s, %s)" % (hd["partner_down"], hd["other_pose"]))
        if cl["down"] or cl["hp"] != 35:
            failures.append("the other warden was not got up (down %s, hp %s)" % (cl["down"], cl["hp"]))
    # The corn stand: the other warden behind it at the pot, their order in the host's books.
    hcs = load("host_corn_stand")
    if hcs is None or hcs["other_pose"] not in ("cook", "stand") or int(hcs["corn_orders"]) < 1:
        failures.append("the host does not see the other warden at the corn stand or their order (%s, %s)" % ((hcs or {}).get("other_pose"), (hcs or {}).get("corn_orders")))
    # Two in the pipes: the same network, each seen by the other, and the host's body in
    # the other's way.
    hp2, cp2 = load("host_pipes"), load("client_pipes")
    if hp2 is None or cp2 is None or not hp2["pipe_net"] or not cp2["pipe_net"]:
        failures.append("missing pipe fingerprints")
    else:
        if hp2["pipe_net"]["hash"] != cp2["pipe_net"]["hash"] or hp2["pipe_net"]["level"] != cp2["pipe_net"]["level"]:
            failures.append("the two are not in the same pipes (%s / %s)" % (hp2["pipe_net"], cp2["pipe_net"]))
        if not hp2["pipe_net"]["mate_seen"] or not cp2["pipe_net"]["mate_seen"]:
            failures.append("in the pipes they do not see each other (host %s, other %s)" % (hp2["pipe_net"]["mate_seen"], cp2["pipe_net"]["mate_seen"]))
        if "boots" not in cp2["pipe_net"]["status"] and "torch" not in cp2["pipe_net"]["status"]:
            failures.append("the other crawled through the host (%s)" % cp2["pipe_net"]["status"])
    # In the pub: the host at the tap is seen behind the bar pulling a beer.
    cpt = load("client_pub_tap")
    if cpt is None or cpt["room_figure"] not in ("tap", "stand") or not cpt["fig_behind_bar"]:
        failures.append("the other warden does not see the host behind the bar at the tap (%s)" % ((cpt or {}).get("room_figure"), ))
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
    elif cr is not None and cr["task"] not in hs["coop_taken"]:
        failures.append("the other warden's job (%s) is not locked for the host (%s)" % (cr["task"], hs["coop_taken"]))
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
    # A guest at the host's: the same on the other machine, and walking about there.
    hg, cg = load("host_guests"), load("client_guests")
    if hg is None or cg is None:
        failures.append("missing guest fingerprints")
    else:
        if not hg["guests"]:
            failures.append("the host's guest did not check in")
        if hg["guests"] != cg["guests"]:
            failures.append("the guests differ (host %s, other %s)" % (hg["guests"], cg["guests"]))
        if cg["agents"] < 1:
            failures.append("the other machine shows no guest walking about (%s)" % cg["agents"])
    # The other warden at the PC: their tent stands in both camps, their mail read is read.
    ha = load("host_after_client")
    if ha is None or cg is None:
        failures.append("missing fingerprints of the other warden at the PC")
    else:
        for fp in (ha, cg):
            if not any(x.startswith("tent_1@(15, 16)") for x in fp["structures"]):
                failures.append("%s: the tent the other warden built is not there" % fp["role"])
        if not any(r.endswith("|read") for r in ha["mail"]):
            failures.append("the mail the other warden read is not read in the host's inbox %s" % ha["mail"])
        if ha["mail"] != cg["mail"]:
            failures.append("the mail differs (host %s, other %s)" % (ha["mail"], cg["mail"]))
        # The back office: the host's lost and found on the other machine, put up from there.
        hb, cb, ab = hg["books"], cg["books"], ha["books"]
        if hb["box"] + len(hb["listed"]) < 2 or cb["box"] + len(cb["listed"]) != hb["box"] + len(hb["listed"]):
            failures.append("the lost and found differs (host %s, other %s)" % (hb, cb))
        if len(ab["listed"]) < 1:
            failures.append("what the other warden put up on the bazaar is not up at the host's %s" % ab)
        if hb["quests"] or cb["quests"]:
            failures.append("Vera's checklist runs in a sandbox camp (host %s, other %s)" % (hb["quests"], cb["quests"]))
        if hb["rev"] != cb["rev"] or hb["bills"] != cb["bills"]:
            failures.append("the reviews or bills differ (host %s, other %s)" % (hb, cb))
        # Goggle from the other machine: the removal booked and the apology on the host's page.
        hgo, cgo = ha.get("goggle", {}), cg.get("goggle", {})
        if not cgo.get("removing") or not cgo.get("replies"):
            failures.append("the other warden's Goggle removal or reply did not happen there %s" % cgo)
        elif cgo.get("removing") != hgo.get("removing") or cgo.get("replies") != hgo.get("replies"):
            failures.append("Goggle differs: the other machine booked %s, answered %s; the host's page %s, %s" % (
                cgo.get("removing"), cgo.get("replies"), hgo.get("removing"), hgo.get("replies")))
    # The delivery at the host's gate: the other sees it, signs for it, and it is done in the host's camp.
    cde, cdd, hdd = load("client_day_event"), load("client_day_done"), load("host_day_done")
    if cde is None or cdd is None or hdd is None:
        failures.append("missing day event fingerprints")
    else:
        if "delivery" not in cde["day_open"]:
            failures.append("the other machine does not show the host's delivery %s" % cde["day_open"])
        if "delivery" in hdd["day_open"] or "delivery" in cdd["day_open"]:
            failures.append("the delivery the other warden signed for is still open (host %s, other %s)" % (hdd["day_open"], cdd["day_open"]))
    # The electrician the host rang for, seen from the other machine.
    ce2 = load("client_electrician")
    if ce2 is None or ce2["mirror"] < 1:
        failures.append("the other warden does not see the electrician come (%s)" % (ce2 or {}).get("mirror"))
    # Both in the generator shed.
    for tag in ("host_shed", "client_shed"):
        fs = load(tag)
        if fs is None or fs["room_figure"] == "":
            failures.append("%s: the other warden is not seen in the shed" % tag)
    # Spent on the other machine: counted in the host's till, the same on both.
    ct, ht = load("client_till"), load("host_till")
    if ct is None or ht is None:
        failures.append("missing till fingerprints")
    else:
        if ht["till_acked"] < 1:
            failures.append("the host did not count what the other warden spent")
        if abs(int(ht["money"]) - int(ct["money"])) > 2:
            failures.append("the tills differ (host %s, other %s)" % (ht["money"], ct["money"]))
    # Over the shoulder: the host's screen on the other's PC.
    cs = load("client_shoulder")
    if cs is None or not cs["coop_screen"]:
        failures.append("the other warden does not see the host's screen over their shoulder")
    # A night enemy set on the other warden: it hunts them, and their machine shows it.
    he, ce = load("host_enemy"), load("client_enemy")
    if he is None or ce is None:
        failures.append("missing night enemy fingerprints")
    else:
        if not any(not t.endswith(":host") and not t.endswith(":?") for t in he["night_targets"]):
            failures.append("the host's enemy does not hunt the other warden %s" % he["night_targets"])
        if ce["mirror"] < 1:
            failures.append("the other machine does not show the host's enemy (%s)" % ce["mirror"])
    # One only for the warden it hunts.
    hp, cp, cg2 = load("host_private"), load("client_private"), load("client_private_gone")
    if hp is None or cp is None or cg2 is None:
        failures.append("missing private enemy fingerprints")
    else:
        if hp["enemy_shown_here"]:
            failures.append("the host sees the enemy that is only the other warden's")
        if cp["mirror"] < 1:
            failures.append("the other warden does not see their own enemy (%s)" % cp["mirror"])
        if cg2["mirror"] != 0:
            failures.append("the other machine shows an enemy that is only the host's (%s)" % cg2["mirror"])
    # The guest lost in the host's corn, led out by the other warden.
    hc = load("host_corn")
    if hc is None or not hc["corn_led_by_other"]:
        failures.append("the other warden did not take the lost guest by the arm")
    # The night director's touch sent to the other warden.
    ctext = open(os.path.join(OUT, "client.log"), encoding="utf-8", errors="replace").read()
    if "Coop: the night, here: knock" not in ctext:
        failures.append("the night director's knock did not reach the other warden")
    # Sleep: alone in bed the night stays; both in bed, both wake on the next morning.
    # One bed in the back room: the other is turned away from it (they sleep in a tent).
    crb = load("client_refused_bed")
    if crb is not None and crb["in_bed"]:
        failures.append("both wardens lie in the one bed of the back room")
    hz, hm, cm = load("host_waiting"), load("host_morning"), load("client_morning")
    if hz is None or hm is None or cm is None:
        failures.append("missing sleep fingerprints (waiting %s, host morning %s, other morning %s)" % (hz is not None, hm is not None, cm is not None))
    else:
        if not hz["in_bed"] or not (float(hz["hour"]) >= 21.0 or float(hz["hour"]) < 5.0):
            failures.append("sleep: the host alone in bed (%s) and the night passed anyway (%.2f)" % (hz["in_bed"], hz["hour"]))
        for fp in (hm, cm):
            if not (6.4 <= float(fp["hour"]) < 12.0) or fp["day"] != hz["day"] + 1:
                failures.append("sleep: %s did not wake on the next morning (day %s, %.2f)" % (fp["role"], fp["day"], fp["hour"]))
    # The next day, hours on: still one camp.
    h2, c2 = load("host_day2"), load("client_day2")
    if h2 is None or c2 is None:
        failures.append("missing day-two fingerprints")
    else:
        for k in ("rooms", "failures", "guests", "day_open"):
            if h2["camp"][k] != c2["camp"][k]:
                failures.append("day two: %s differ (host %s, other %s)" % (k, h2["camp"][k], c2["camp"][k]))
        if h2["mail"] != c2["mail"]:
            failures.append("day two: the mail differs (host %s, other %s)" % (h2["mail"], c2["mail"]))
        if abs(int(h2["money"]) - int(c2["money"])) > 5:
            failures.append("day two: the tills differ (host %s, other %s)" % (h2["money"], c2["money"]))
        if h2["day"] != c2["day"]:
            failures.append("day two: not the same day (host %s, other %s)" % (h2["day"], c2["day"]))
    # One bus for both.
    hw, hr2, cr2, ht, ct = load("host_bus_wait"), load("host_bus_ride"), load("client_bus_ride"), load("host_town"), load("client_town")
    if None in (hw, hr2, cr2, ht, ct):
        failures.append("missing bus fingerprints")
    else:
        hp_, cp_ = load("host_pub"), load("client_pub")
        if hp_ is None or cp_ is None or not hp_["town_mate"] or not cp_["town_mate"]:
            failures.append("at U Jezera they do not see each other (host %s, other %s)" % ((hp_ or {}).get("town_mate"), (cp_ or {}).get("town_mate")))
        if not ht["other_visible"] or not ct["other_visible"]:
            failures.append("in Lesna they do not see each other (host %s, other %s)" % (ht["other_visible"], ct["other_visible"]))
        if hw["bus_state"] != "held":
            failures.append("the bus did not wait for the other warden buying a ticket (%s)" % hw["bus_state"])
        if hr2["bus_state"] not in ("riding", "stopping", "done") or cr2["bus_state"] not in ("riding", "stopping", "done"):
            failures.append("the bus did not go with both (host %s, other %s)" % (hr2["bus_state"], cr2["bus_state"]))
        import re
        def at(fp):
            m = re.findall(r"-?\d+\.?\d*", fp["me_at"])
            return [float(v) for v in m[:3]]
        a, b = at(ht), at(ct)
        d = ((a[0] - b[0]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5
        if d > 3.0:
            failures.append("off the bus in Lesna, the two are %.1f m apart" % d)
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
