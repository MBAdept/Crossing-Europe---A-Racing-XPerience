"""scratch: the fixture written again from the pre-hook tree (with ctopo / nstat) against the committed one."""
import json
import sys

a = json.load(open(sys.argv[1]))      # committed (10 fields)
b = json.load(open(sys.argv[2]))      # rewritten (12 fields)
fa, fb = a["fields"], b["fields"]
same = diff = 0
for sid in sorted(a["sets"]):
    if sid not in b["sets"]:
        print("fehlt neu:", sid)
        diff += 1
        continue
    wa = dict(zip(fa, a["sets"][sid]))
    wb = dict(zip(fb, b["sets"][sid]))
    d = [f for f in fa if wa[f] != wb[f]]
    if d:
        diff += 1
        print("anders: %-40s %s" % (sid, d))
    else:
        same += 1
extra = sorted(set(b["sets"]) - set(a["sets"]))
print("%d Sets in der alten Fixture, %d in der neuen; %d in allen %d alten Feldern gleich, %d anders, %d zusätzlich"
      % (len(a["sets"]), len(b["sets"]), same, len(fa), diff, len(extra)))
