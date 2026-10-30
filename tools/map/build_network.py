#!/usr/bin/env python3
"""Generates data/network.json from tools/map/network_data.py.

    python3 tools/map/build_network.py            # write data/network.json (+ tables in docs/daten.md)
    python3 tools/map/build_network.py --check    # only check rules and print the route report

What it does:
  * converts the compact stage definitions into the network.json format (ARCHITECTURE.md §4.1),
  * places fuel stations every 60–90 km (deterministic, clear of tunnels, radar zones and borders),
  * derives explicit border entries from country changes between sections,
  * checks the StagePlan rules for BOTH driving directions (fuel/radar distances, section sums, …),
  * replays the routing of GameData.next_options (Dijkstra + detour tolerance) and prints all race routes,
  * keeps existing "map_pos" values (they are written by tools/map/build_map.mjs from "latlon"),
  * rewrites the generated block in docs/daten.md (between the NETZ markers).
The committed data/network.json is the source of truth for the game; the Godot tests re-check everything.
"""
import hashlib
import heapq
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import network_data as nd  # noqa: E402

NETWORK_PATH = os.path.join(ROOT, "data", "network.json")
CONFIG_PATH = os.path.join(ROOT, "config", "game_config.json")
COUNTRIES_PATH = os.path.join(ROOT, "data", "countries.json")
DOC_PATH = os.path.join(ROOT, "docs", "daten.md")
DOC_BEGIN = "<!-- BEGIN NETZ (generiert von tools/map/build_network.py) -->"
DOC_END = "<!-- END NETZ -->"

SCENERY_IDS = ["north_plain", "heath", "forest_hills", "rhine_main", "industrial", "polder", "ardennes",
			   "farmland_fr", "loire", "pyrenees", "meseta", "mediterranean", "alps", "lombardy", "karst",
			   "balkan_hills", "pannonian_plain", "bohemian", "east_plain", "baltic_forest", "coast", "city"]
FUEL_TARGET = {"few": 88.0, "normal": 75.0, "many": 62.0}

errors = []


def err(msg):
	errors.append(msg)


def load_json(path):
	with open(path, encoding="utf-8") as f:
		return json.load(f)


CFG = load_json(CONFIG_PATH)
COUNTRIES = load_json(COUNTRIES_PATH)["countries"]
CITY_LEN = float(CFG["city_limits"]["length_km"])
LAST_STATION = float(CFG["fuel"]["last_station_min_before_end_km"])
SPACING = [float(v) for v in CFG["fuel"]["station_spacing_km"]]
LANE_MAX = float(CFG["fuel"]["lane_length_km"][1])
RADAR_ZONE = float(CFG["radar"]["zone_length_km"])
NO_RADAR = float(CFG["radar"]["no_radar_before_city_km"])
TOLERANCE = float(CFG["routing"]["detour_tolerance"])
MAX_OPTIONS = int(CFG["routing"]["max_options"])
EDGE_MIN = LAST_STATION + 1.0     # stations keep this distance to both ends (both directions)
RADAR_MIN = CITY_LEN + NO_RADAR   # radar zones end at least this far before the finish (50 km)


def r1(v):
	v = round(float(v), 1)
	return int(v) if v == int(v) else v


def stable_jitter(key, amplitude):
	h = int(hashlib.md5(key.encode("utf-8")).hexdigest()[:8], 16)
	return ((h % 2001) / 1000.0 - 1.0) * amplitude


# ------------------------------------------------------------------------------------------- stages

def section_limit(sec):
	"""Effective limit like StagePlan: 0 = none."""
	lim = sec["speed_limit"]
	if lim is None:
		return 0
	if lim == nd.DEF:
		d = COUNTRIES.get(sec["country"], {}).get("limits", {}).get(sec["road"])
		return 0 if d is None else int(d)
	return int(lim)


def build_sections(s):
	out = []
	km = 0.0
	for sec in s["sections"]:
		length = float(sec["length_km"])
		out.append(dict(sec, start=km, end=km + length))
		km += length
	return out, km


def limits_in(secs, a, b):
	return {section_limit(x) for x in secs if x["end"] > a + 1e-6 and x["start"] < b - 1e-6}


def obstacles_of(s, secs):
	obs = []
	for (km, length, _name) in s["tunnels"]:
		obs.append((km - 0.5, km + length + 0.5))
	for r in s["radars"]:
		obs.append((r[0] - 0.5, r[0] + RADAR_ZONE + 0.5))
	for i in range(1, len(secs)):
		if secs[i]["country"] != secs[i - 1]["country"]:
			obs.append((secs[i]["start"] - 1.5, secs[i]["start"] + 1.5))
	return obs


def station_clear(st, obs):
	# fuel lane = last 1–2 km before the station; in reverse direction it lies on the other side
	a, b = st - LANE_MAX - 1.0, st + LANE_MAX + 1.0
	return all(b <= o0 or a >= o1 for (o0, o1) in obs)


def place_stations(s, length, secs):
	fuel = s["fuel"]
	if isinstance(fuel, list):
		return [float(v) for v in fuel]
	target = FUEL_TARGET[fuel]
	n = max(1, int(round(length / target)))
	while n > 1 and length / n < SPACING[0]:
		n -= 1
	while length / n > SPACING[1] and n > 1 or (n == 1 and length / 2.0 > SPACING[1]):
		n += 1
	obs = obstacles_of(s, secs)
	out = []
	for i in range(n):
		base = (i + 0.5) * length / n + stable_jitter("%s:%d" % (s["id"], i), 3.0)
		placed = None
		for step in range(0, 49):
			off = (step + 1) // 2 * 0.5 * (1 if step % 2 else -1)
			cand = round(base + off, 1)
			if cand < EDGE_MIN or cand > length - EDGE_MIN:
				continue
			if out and not (SPACING[0] <= cand - out[-1] <= SPACING[1]):
				continue
			if not out and cand > SPACING[1]:
				continue
			if i == n - 1 and length - cand > SPACING[1]:
				continue
			if not station_clear(cand, obs):
				continue
			placed = cand
			break
		if placed is None:
			err("%s: Tankstelle %d nicht platzierbar (Basis %.1f km)" % (s["id"], i, base))
			placed = round(base, 1)
		out.append(placed)
	return out


def check_stage(s, secs, length, stations):
	sid = s["id"]
	if abs(length - s["km"]) > 0.01:
		err("%s: Abschnitte ergeben %.1f km statt %s km" % (sid, length, s["km"]))
	cities = {c[0]: c for c in nd.CITIES}
	for end, sec in (("from", secs[0]), ("to", secs[-1])):
		cc = cities[s[end]][2]
		if sec["country"] != cc:
			err("%s: Abschnitt am Ende '%s' liegt in %s, Stadt in %s" % (sid, end, sec["country"], cc))
	for sec in secs:
		if sec["scenery"] not in SCENERY_IDS or sec["scenery"] == "city":
			err("%s: unbekannte/unerlaubte Szenerie %s" % (sid, sec["scenery"]))
		if sec["country"] not in COUNTRIES:
			err("%s: unbekanntes Land %s" % (sid, sec["country"]))
		if sec["speed_limit"] is None and not (sec["country"] == "DE" and sec["road"] == "autobahn"):
			err("%s: 'ohne Limit' nur auf deutscher Autobahn (%s)" % (sid, sec["name"]))
		if not (0 <= sec["curviness"] <= 3 and 0 <= sec["hills"] <= 3):
			err("%s: Kurvigkeit/Hügel außerhalb 0–3" % sid)
	# fuel stations: both directions → [EDGE_MIN, L-EDGE_MIN], spacing 60–90, ends ≤ 90
	prev = 0.0
	for st in stations:
		if st < LAST_STATION or st > length - LAST_STATION:
			err("%s: Tankstelle bei %.1f verletzt den 25-km-Abstand" % (sid, st))
		gap = st - prev
		if prev > 0.0 and not (SPACING[0] - 0.01 <= gap <= SPACING[1] + 0.01):
			err("%s: Tankstellenabstand %.1f km" % (sid, gap))
		if prev == 0.0 and gap > SPACING[1] + 0.01:
			err("%s: erste Tankstelle erst bei %.1f km" % (sid, st))
		prev = st
	if stations and length - stations[-1] > SPACING[1] + 0.01:
		err("%s: letzte Tankstelle %.1f km vor dem Ziel" % (sid, length - stations[-1]))
	if not stations:
		err("%s: keine Tankstelle" % sid)
	# radars
	for r in s["radars"]:
		km, lim = r[0], r[1]
		d = r[2] if len(r) > 2 else "both"
		if d in ("both", "fwd") and km + RADAR_ZONE > length - RADAR_MIN + 1e-6:
			err("%s: Radar bei %.1f liegt vorwärts in den letzten %.0f km" % (sid, km, RADAR_MIN))
		if d in ("both", "rev") and km < RADAR_MIN - 1e-6:
			err("%s: Radar bei %.1f liegt rückwärts in den letzten %.0f km" % (sid, km, RADAR_MIN))
		lims = limits_in(secs, km, km + RADAR_ZONE)
		if lims != {lim}:
			err("%s: Radar bei %.1f (Limit %d) passt nicht zum Tempolimit %s" % (sid, km, lim, sorted(lims)))
		for (tk, tl, _n) in s["tunnels"]:
			if km < tk + tl and km + RADAR_ZONE > tk:
				err("%s: Radar bei %.1f im Tunnel" % (sid, km))
	# tunnels
	last_end = -1.0
	for (tk, tl, name) in sorted(s["tunnels"]):
		if tk < 0.5 or tk + tl > length - 0.5:
			err("%s: Tunnel %s außerhalb der Etappe" % (sid, name))
		if tk < last_end:
			err("%s: Tunnel überlappen sich" % sid)
		last_end = tk + tl


def convert_stage(s):
	secs, length = build_sections(s)
	stations = place_stations(s, length, secs)
	check_stage(s, secs, length, stations)
	out_secs = []
	for sec in secs:
		o = {"length_km": r1(sec["length_km"]), "road": sec["road"], "curviness": sec["curviness"],
			 "hills": sec["hills"], "scenery": sec["scenery"], "country": sec["country"]}
		if sec["speed_limit"] != nd.DEF:
			o["speed_limit"] = sec["speed_limit"]
		o["traffic"] = sec["traffic"]
		if sec["name"]:
			o["name"] = sec["name"]
		out_secs.append(o)
	borders = []
	for i in range(1, len(secs)):
		if secs[i]["country"] != secs[i - 1]["country"]:
			borders.append({"km": r1(secs[i]["start"]), "to": secs[i]["country"]})
	radars = []
	for r in s["radars"]:
		o = {"km": r1(r[0]), "limit": int(r[1])}
		if len(r) > 2:
			o["dir"] = r[2]
		radars.append(o)
	st = {"id": s["id"], "from": s["from"], "to": s["to"], "length_km": r1(length), "roads": s["roads"]}
	if s["doc"]:
		st["description"] = s["doc"]
	st["sections"] = out_secs
	st["fuel_stations_km"] = [r1(v) for v in stations]
	st["radars"] = radars
	st["tunnels"] = [{"km": r1(t[0]), "length_km": r1(t[1]), "name": t[2]} for t in s["tunnels"]]
	st["borders"] = borders
	return st


# ------------------------------------------------------------------------------------------ routing
# Mirrors RoadNetwork.next_options() in scripts/data/road_network.gd.

def build_graph(stages, ferries):
	adj = {}
	for st in stages:
		if st.get("dev"):
			continue
		for a, b in ((st["from"], st["to"]), (st["to"], st["from"])):
			adj.setdefault(a, []).append(("stage", st["id"], b, float(st["length_km"])))
	for f in ferries:
		for a, b in ((f["from"], f["to"]), (f["to"], f["from"])):
			adj.setdefault(a, []).append(("ferry", f["id"], b, 0.0))
	return adj


def dijkstra(adj, src, dst, avoid_cities, avoid_stages):
	dist = {src: 0.0}
	heap = [(0.0, src)]
	while heap:
		d, c = heapq.heappop(heap)
		if c == dst:
			return d
		if d > dist.get(c, math.inf):
			continue
		for (kind, lid, to, length) in adj.get(c, []):
			if lid in avoid_stages or (to in avoid_cities and to != dst):
				continue
			nd_ = d + length
			if nd_ < dist.get(to, math.inf) - 1e-9:
				dist[to] = nd_
				heapq.heappush(heap, (nd_, to))
	return math.inf


def next_options(adj, race, current, idx, leg_visited):
	targets = race["waypoints"] + [race["finish"]]
	target = targets[idx]
	avoid_stages = set(race.get("avoid_stages", []))
	visited = set(leg_visited) | {current}
	opts = []
	for (kind, lid, to, length) in adj.get(current, []):
		if lid in avoid_stages or to in visited:
			continue
		rem = 0.0 if to == target else dijkstra(adj, to, target, visited, avoid_stages)
		if math.isinf(rem):
			continue
		opts.append((length + rem, kind, lid, to, length))
	if not opts:
		return []
	best = min(o[0] for o in opts)
	opts = [o for o in opts if o[0] <= best * (1.0 + TOLERANCE) + 1e-6]
	opts.sort()
	return opts[:MAX_OPTIONS]


def race_routes(adj, race, limit=64):
	targets = race["waypoints"] + [race["finish"]]
	routes = []
	choices = {}

	def rec(city, idx, leg_visited, cities, legs, km):
		if len(routes) >= limit:
			return
		while idx < len(targets) and targets[idx] == city and len(cities) > 1:
			idx += 1
			leg_visited = [city]
		if idx >= len(targets):
			routes.append((km, list(cities), list(legs)))
			return
		opts = next_options(adj, race, city, idx, leg_visited)
		if len(opts) > 1:
			choices.setdefault((city, idx), [o[3] for o in opts])
		for (_cost, kind, lid, to, length) in opts:
			rec(to, idx, leg_visited + [to], cities + [to], legs + [(kind, lid, city, to, length)], km + length)

	rec(race["start"], 0, [race["start"]], [race["start"]], [], 0.0)
	routes.sort(key=lambda r: r[0])
	return routes, choices


# --------------------------------------------------------------------------------------------- JSON

def fmt(v):
	return json.dumps(v, ensure_ascii=False)


def obj_line(d):
	return "{ " + ", ".join("%s: %s" % (fmt(k), fmt(v)) for k, v in d.items()) + " }"


def write_network(cities, stages, ferries, races):
	lines = ["{"]
	lines.append('\t"_doc": %s,' % fmt(
		"Streckennetz: Städte (Knoten), Etappen (Verbindungen, in beide Richtungen fahrbar), Fähren und Rennen "
		"(Start, Ziel, Pflichtstationen). Positionen von Tankstellen, Radar, Tunneln und Grenzen in km ab 'from'. "
		"City Limits = automatisch die letzten 20 km. Radar 'dir': nur in einer Richtung (fwd = from→to, "
		"rev = to→from). Erzeugt mit tools/map/build_network.py (Quelle tools/map/network_data.py), map_pos mit "
		"tools/map/build_map.mjs – Details in docs/daten.md."))
	lines.append('\t"version": 2,')
	lines.append('\t"cities": [')
	lines.append(",\n".join("\t\t" + obj_line(c) for c in cities))
	lines.append("\t],")
	lines.append('\t"stages": [')
	blocks = []
	for st in stages:
		b = ["\t\t{"]
		head = {k: v for k, v in st.items() if k not in ("sections", "fuel_stations_km", "radars", "tunnels", "borders")}
		items = list(head.items())
		b.append("\t\t\t" + ", ".join("%s: %s" % (fmt(k), fmt(v)) for k, v in items) + ",")
		b.append('\t\t\t"sections": [')
		b.append(",\n".join("\t\t\t\t" + obj_line(x) for x in st["sections"]))
		b.append("\t\t\t],")
		b.append('\t\t\t"fuel_stations_km": %s,' % fmt(st["fuel_stations_km"]))
		for key in ("radars", "tunnels", "borders"):
			arr = st[key]
			inner = ", ".join(obj_line(x) for x in arr)
			b.append('\t\t\t"%s": [%s]%s' % (key, (" " + inner + " ") if arr else "", "," if key != "borders" else ""))
		b.append("\t\t}")
		blocks.append("\n".join(b))
	lines.append(",\n".join(blocks))
	lines.append("\t],")
	lines.append('\t"ferries": [')
	lines.append(",\n".join("\t\t" + obj_line(f) for f in ferries))
	lines.append("\t],")
	lines.append('\t"races": [')
	rb = []
	for r in races:
		rb.append("\t\t{\n" + ",\n".join("\t\t\t%s: %s" % (fmt(k), fmt(v)) for k, v in r.items()) + "\n\t\t}")
	lines.append(",\n".join(rb))
	lines.append("\t]")
	lines.append("}")
	text = "\n".join(lines) + "\n"
	json.loads(text)  # sanity
	with open(NETWORK_PATH, "w", encoding="utf-8") as f:
		f.write(text)


def raw_dev_stage():
	st = json.loads(json.dumps(nd.DEV_STAGE))
	return st


# --------------------------------------------------------------------------------------------- docs

def de_num(v, digits=2):
	return ("%.*f" % (digits, v)).replace(".", ",")


def stage_stats(st):
	auto = sum(s["length_km"] for s in st["sections"] if s["road"] == "autobahn")
	free = sum(s["length_km"] for s in st["sections"] if s["road"] == "autobahn" and "speed_limit" in s and s["speed_limit"] is None)
	traffic = sum(s["length_km"] * s["traffic"] for s in st["sections"]) / st["length_km"]
	countries = []
	for s in st["sections"]:
		if not countries or countries[-1] != s["country"]:
			countries.append(s["country"])
	rad_f = sum(1 for r in st["radars"] if r.get("dir", "both") in ("both", "fwd"))
	rad_r = sum(1 for r in st["radars"] if r.get("dir", "both") in ("both", "rev"))
	return auto, free, traffic, countries, rad_f, rad_r


def doc_block(cities, stages, ferries, races, route_info):
	cname = {c["id"]: c["name"] for c in cities}
	sname = {s["id"]: "%s – %s" % (cname[s["from"]], cname[s["to"]]) for s in stages}
	out = []
	out.append("### Rennen\n")
	out.append("| Rennen | Start → Ziel | Pflichtstationen | Routen | km (kürzeste–längste) | Etappen |")
	out.append("|---|---|---|---|---|---|")
	for r in races:
		routes, _choices = route_info[r["id"]]
		kms = [x[0] for x in routes]
		nst = [sum(1 for l in x[2] if l[0] == "stage") for x in routes]
		out.append("| %s (`%s`) | %s → %s | %d | %d | %s–%s | %d–%d |" % (
			r["name"], r["id"], cname[r["start"]], cname[r["finish"]], len(r["waypoints"]), len(routes),
			"{:,}".format(int(round(min(kms)))).replace(",", "."), "{:,}".format(int(round(max(kms)))).replace(",", "."),
			min(nst), max(nst)))
	out.append("")
	by_id = {s["id"]: s for s in stages}
	for r in races:
		routes, choices = route_info[r["id"]]
		out.append("**%s** – Routen:\n" % r["name"])
		if len(routes) > 1:
			out.append("| Route | km | Etappen | frei km | Radar | Tankstellen | Verkehr Ø | max. Hügel | Landstraße km |")
			out.append("|---|---|---|---|---|---|---|---|---|")
			for (km, cs, legs) in routes:
				free = radars = stations = hills = 0
				land = traffic = 0.0
				for (kind, lid, a, b, length) in legs:
					if kind != "stage":
						continue
					st = by_id[lid]
					auto, fr, tr, _c, rf, rr = stage_stats(st)
					free += fr
					radars += rf if a == st["from"] else rr
					stations += len(st["fuel_stations_km"])
					traffic += tr * st["length_km"]
					land += st["length_km"] - auto
					hills = max(hills, max(s["hills"] for s in st["sections"]))
				diff = [cname[c] for c in cs if all(c not in o[1] for o in routes if o[1] is not cs)]
				label = "über " + ", ".join(diff[:3]) if diff else " – ".join(cname[c] for c in cs[:3]) + " …"
				out.append("| %s | %s | %d | %s | %d | %d | %s | %d | %s |" % (
					label, "{:,}".format(int(round(km))).replace(",", "."), sum(1 for l in legs if l[0] == "stage"),
					r1(free), radars, stations, de_num(traffic / max(km, 1)), hills, r1(land)))
			out.append("")
		for (km, cs, legs) in routes:
			seq = " – ".join(cname[c] for c in cs)
			out.append("- %s km, %d Etappen: %s" % ("{:,}".format(int(round(km))).replace(",", "."),
				sum(1 for l in legs if l[0] == "stage"), seq))
		if choices:
			out.append("- Wahlpunkte: " + "; ".join("%s → %s" % (cname[c], " / ".join(cname[t] for t in opts))
				for (c, _i), opts in choices.items()))
		out.append("")
	out.append("### Etappen\n")
	out.append("Radar = Radarfallen vorwärts/rückwärts, Tank = Tankstellen, Verkehr = längengewichteter Faktor, "
			   "frei = Autobahn ohne Tempolimit.\n")
	out.append("| Etappe (`id`) | Straßen | km | Länder | Autobahn / frei km | Radar | Tank | Tunnel | Verkehr |")
	out.append("|---|---|---|---|---|---|---|---|---|")
	for st in stages:
		if st.get("dev"):
			continue
		auto, free, traffic, countries, rf, rr = stage_stats(st)
		tunnels = ", ".join("%s (%s km)" % (t["name"], str(t["length_km"]).replace(".", ",")) for t in st["tunnels"]) or "–"
		out.append("| %s (`%s`) | %s | %s | %s | %s / %s | %d/%d | %d | %s | %s |" % (
			sname[st["id"]], st["id"], st.get("roads", ""), str(st["length_km"]).replace(".", ","), " → ".join(countries),
			r1(auto), r1(free), rf, rr, len(st["fuel_stations_km"]), tunnels, de_num(traffic)))
	out.append("")
	out.append("Fähren: " + "; ".join("%s (`%s`, %d s Rennzeit, %d h Weltzeit)" % (
		f["name"], f["id"], f["fixed_time_s"], f["world_hours"]) for f in ferries))
	total = sum(st["length_km"] for st in stages if not st.get("dev"))
	out.append("")
	out.append("Summe aller Etappen: %s km in %d Etappen, %d Städte." % (
		"{:,}".format(int(round(total))).replace(",", "."), sum(1 for s in stages if not s.get("dev")),
		sum(1 for c in cities if not c.get("dev"))))
	return "\n".join(out)


def update_doc(block):
	if not os.path.exists(DOC_PATH):
		return False
	with open(DOC_PATH, encoding="utf-8") as f:
		text = f.read()
	if DOC_BEGIN not in text or DOC_END not in text:
		return False
	a = text.index(DOC_BEGIN) + len(DOC_BEGIN)
	b = text.index(DOC_END)
	text = text[:a] + "\n" + block + "\n" + text[b:]
	with open(DOC_PATH, "w", encoding="utf-8") as f:
		f.write(text)
	return True


# --------------------------------------------------------------------------------------------- main

def main():
	check_only = "--check" in sys.argv
	old_pos = {}
	if os.path.exists(NETWORK_PATH):
		try:
			for c in load_json(NETWORK_PATH).get("cities", []):
				if "map_pos" in c:
					old_pos[c["id"]] = c["map_pos"]
		except (ValueError, KeyError):
			pass
	cities = []
	ids = set()
	for (cid, name, country, lat, lon, local) in nd.CITIES:
		if cid in ids:
			err("Stadt doppelt: " + cid)
		ids.add(cid)
		c = {"id": cid, "name": name, "country": country}
		if local:
			c["name_local"] = local
		c["latlon"] = [lat, lon]
		c["map_pos"] = old_pos.get(cid, [0, 0])
		cities.append(c)
	for dc in nd.DEV_CITIES:
		c = dict(dc)
		c["map_pos"] = old_pos.get(c["id"], [0, 0])
		cities.append(c)
	stages = []
	sids = set()
	for s in nd.STAGES:
		if s["id"] in sids:
			err("Etappe doppelt: " + s["id"])
		sids.add(s["id"])
		for end in ("from", "to"):
			if s[end] not in ids:
				err("%s: unbekannte Stadt %s" % (s["id"], s[end]))
		stages.append(convert_stage(s))
	stages.append(raw_dev_stage())
	ferries = nd.FERRIES
	races = nd.RACES
	adj = build_graph(stages, ferries)
	route_info = {}
	for r in races:
		for avoid in r.get("avoid_stages", []):
			if avoid not in sids:
				err("%s: avoid_stages enthält unbekannte Etappe %s" % (r["id"], avoid))
		routes, choices = race_routes(adj, r)
		if not routes:
			err("Rennen %s ist nicht fahrbar" % r["id"])
		route_info[r["id"]] = (routes, choices)
		print("== %s: %d Route(n)" % (r["name"], len(routes)))
		for (km, cs, legs) in routes:
			print("   %6.0f km, %2d Etappen: %s" % (km, sum(1 for l in legs if l[0] == "stage"), " – ".join(cs)))
		for (c, i), opts in choices.items():
			print("   Wahl in %s (Ziel #%d): %s" % (c, i, ", ".join(opts)))
	if errors:
		print("\nFEHLER:")
		for e in errors:
			print("  - " + e)
		sys.exit(1)
	if check_only:
		print("\nRegeln ok (nur geprüft, nichts geschrieben).")
		return
	write_network(cities, stages, ferries, races)
	print("\n%s geschrieben (%d Städte, %d Etappen)." % (os.path.relpath(NETWORK_PATH, ROOT), len(cities), len(stages)))
	if update_doc(doc_block(cities, stages, ferries, races, route_info)):
		print("docs/daten.md: Netz-Tabellen aktualisiert.")
	missing = [c["id"] for c in cities if c["map_pos"] == [0, 0]]
	if missing:
		print("Hinweis: map_pos fehlt für %d Städte – tools/map/build_map.mjs ausführen." % len(missing))


if __name__ == "__main__":
	main()
