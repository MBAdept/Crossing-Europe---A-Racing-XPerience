import json, sys
root = sys.argv[1]
n = json.load(open(root + "/data/network.json"))
c = json.load(open(root + "/data/cities.json"))
cities = c.get("cities", {})
for st in n["stages"]:
    sid = st["id"]
    fr = st["from"]
    to = st["to"]
    L = st["length_km"]
    tun = [(t["name"], t["km"], t["length_km"]) for t in st.get("tunnels", [])]
    br_to = [(b.get("name"), b.get("type"), L - b.get("km_to_finish", 0)) for b in cities.get(to, {}).get("bridges", [])]
    br_fr = [(b.get("name"), b.get("type"), L - b.get("km_to_finish", 0)) for b in cities.get(fr, {}).get("bridges", [])]
    if tun or br_to or br_fr:
        print(sid, fr, "->", to, L, "tunnels", tun, "| bridges at", to, br_to, "| at", fr, "(reverse dir)", br_fr)
