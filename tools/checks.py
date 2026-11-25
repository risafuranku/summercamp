"""Every headless check of the game in one go: the smoke start and the harnesses that need no
window. The one way to say "the checks pass" (they were run from a script outside the repo,
with a path that no longer existed, or by hand, a different set each time: 23. 11. 2026).

    python tools/checks.py                 all of them, three at a time
    python tools/checks.py --only mail_check,lang_check
    python tools/checks.py --list
    python tools/checks.py --jobs 1        one at a time (a busy PC)

Each runs with `--audio-driver Dummy` and its own empty APPDATA (never the player's saves).
A check passes when it exits 0, prints no SCRIPT ERROR and its last verdict line says
PASS/OK (the smoke start: no SCRIPT ERROR). Logs in %TEMP%/summercamp-checks/<name>.log.
Windowed checks (screenshots, co-op for two) are in docs/testing.md and run on a hidden
desktop (tools/hidden_desktop.py).
"""
import argparse
import concurrent.futures as cf
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "godot")
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = os.path.join(os.environ.get("TEMP", "/tmp"), "summercamp-checks")

# (name, args after --path): a scene, or --script for a SceneTree script.
SCENES = ["hud_layout_check", "guest_sim_check", "upkeep_check", "billing_check", "pipes_check", "uncanny_check",
	"radio_game_check", "chase_check", "look_check", "mail_check", "arrival_check", "enemy_check", "nightjobs_check",
	"dayevents_check", "os98_check", "business_check", "staff_check", "pub_check", "stand_check", "jednota_check",
	"proto_check", "podniky_check", "post_check", "pa_check", "settings_check", "site_check", "box_check", "plot_check", "goal_check"]
SCRIPTS = ["radio_dread_check", "radio_tiers_check", "steps_check", "bus_turn_check", "weather_check", "week_check",
	"omens_check", "corn_check", "checkin_check", "season_check", "director_check", "bazaar_check", "goggle_check",
	"builder98_check", "lang_check", "bistro_check", "bowling_check", "night_swell_check"]
CHECKS = [("smoke", ["--quit-after", "400"])]
CHECKS += [(n, ["res://tools/%s.tscn" % n]) for n in SCENES]
CHECKS += [(n, ["--script", "res://tools/%s.gd" % n]) for n in SCRIPTS]

VERDICT = re.compile(r"\b(PASS|FAIL|FAILED|OK|FAILURE\(S\))\b")


def run(name, args):
	log = os.path.join(OUT, name + ".log")
	env = dict(os.environ)
	env["APPDATA"] = os.path.join(OUT, "appdata", name)
	os.makedirs(env["APPDATA"], exist_ok=True)
	t0 = time.time()
	with open(log, "w", encoding="utf-8", errors="replace") as f:
		try:
			code = subprocess.run([GODOT, "--headless", "--audio-driver", "Dummy", "--path", PROJECT] + args,
				stdout=f, stderr=subprocess.STDOUT, env=env, timeout=600).returncode
		except subprocess.TimeoutExpired:
			code = "timeout"
	text = open(log, encoding="utf-8", errors="replace").read()
	errors = text.count("SCRIPT ERROR")
	verdicts = [l.strip() for l in text.splitlines() if VERDICT.search(l)]
	last = verdicts[-1] if verdicts else ""
	if name == "smoke":
		ok = code == 0 and errors == 0
	else:
		ok = code == 0 and errors == 0 and bool(last) and not re.search(r"FAIL", last)
	return name, ok, code, errors, last[:110], time.time() - t0


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--only", default="")
	ap.add_argument("--jobs", type=int, default=3)
	ap.add_argument("--list", action="store_true")
	a = ap.parse_args()
	sys.stdout.reconfigure(encoding="utf-8", errors="replace")
	todo = CHECKS
	if a.only:
		want = set(a.only.split(","))
		todo = [c for c in CHECKS if c[0] in want]
	if a.list:
		for n, _ in todo:
			print(n)
		return 0
	os.makedirs(OUT, exist_ok=True)
	results = []
	with cf.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
		for r in ex.map(lambda c: run(*c), todo):
			results.append(r)
			print("%-4s %-20s %5.0fs  errors %d  %s" % ("ok" if r[1] else "FAIL", r[0], r[5], r[3], r[4] if r[1] else "exit %s | %s" % (r[2], r[4])), flush=True)
	bad = [r for r in results if not r[1]]
	print("CHECKS: %s (%d of %d passed; logs %s)" % ("PASS" if not bad else "FAIL", len(results) - len(bad), len(results), OUT))
	return 0 if not bad else 1


if __name__ == "__main__":
	sys.exit(main())
