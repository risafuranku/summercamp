#!/usr/bin/env python3
"""The god cursor for two (tools/god_coop.gd): a host and a client of the game on this
machine; the host builds at its PC and the client watches the sky, then the other way.
Prints both logs' script errors and the GOD COOP lines; pictures go to OUT_DIR.

    python godot/tools/god_coop.py [OUT_DIR]

GODOT (env) is the Godot console binary.
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
GODOT = os.environ.get("GODOT", "C:/Users/arnold/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("TEMP", "/tmp"), "god_coop")


def run(role):
    log = open(os.path.join(OUT, "%s.log" % role), "w", encoding="utf-8")
    return subprocess.Popen([GODOT, "--path", PROJECT, "res://tools/god_coop.tscn", "--", "--role=%s" % role, "--out=%s" % OUT],
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
        if not f.endswith(".log"):
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
        print("GOD COOP: timed out")
        return 1
    for role in ("host", "client"):
        text = open(os.path.join(OUT, "%s.log" % role), encoding="utf-8", errors="replace").read()
        for line in text.splitlines():
            if "SCRIPT ERROR" in line or "gave up" in line or "GOD COOP" in line or "eval:" in line:
                print(role, line[:300])
    print("GOD COOP: done, pictures in", OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
