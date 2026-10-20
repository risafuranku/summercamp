"""Major roads (primary/secondary/tertiary/unclassified) with ref/name and their extent."""
import json
import math
import sys

sys.stdout.reconfigure(encoding="utf-8")
LAT0, LON0 = 50.0606589, 14.8477650
KX = 111320.0 * math.cos(math.radians(LAT0))
KZ = 110574.0
data = json.load(open(sys.argv[1], encoding="utf-8"))
nodes = {e["id"]: e for e in data["elements"] if e["type"] == "node"}
kinds = sys.argv[2].split(",")
box = [float(v) for v in sys.argv[3].split(",")] if len(sys.argv) > 3 else None
for w in data["elements"]:
    if w["type"] != "way":
        continue
    t = w.get("tags", {})
    if t.get("highway") not in kinds:
        continue
    pts = [((nodes[i]["lon"] - LON0) * KX, -(nodes[i]["lat"] - LAT0) * KZ) for i in w["nodes"] if i in nodes]
    if box and not any(box[0] <= x <= box[2] and box[1] <= z <= box[3] for x, z in pts):
        continue
    print(w["id"], t["highway"], t.get("ref", ""), t.get("name", ""), "len %d" % sum(math.hypot(pts[i+1][0]-pts[i][0], pts[i+1][1]-pts[i][1]) for i in range(len(pts)-1)),
          "(%d,%d)->(%d,%d)" % (pts[0][0], pts[0][1], pts[-1][0], pts[-1][1]), "n0=%d n1=%d" % (w["nodes"][0], w["nodes"][-1]))
