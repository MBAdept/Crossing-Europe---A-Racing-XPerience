class_name CityData
extends RefCounted
## Individual cities (contract docs/staedte.md): resolves data/cities.json for the destination of a stage –
## building style (outskirts / centre scenery), landmarks, skyline silhouettes and bridges – and fills the
## city fields of a StagePlan. Pure logic, no autoloads (tests pass the parsed JSON).
##
## Positions in cities.json count backwards from the finish (km_to_finish, odometer km); bridge lengths
## (length_m) are visible metres like all *_m values (ARCHITECTURE.md §2: 1 km odometer = 83.3 m).
## Everything degrades gracefully: unknown city -> style of its country -> "german"; unknown style or
## missing scenery -> the generic "city" scenery (StagePlan.scenery_for).
## Owner: data module (data/cities.json), runtime use in the race module (Track, RoadRenderer).

const DEFAULT_STYLE := "german"
const DEFAULT_CENTER_KM := 8.0
const BRIDGE_TYPES: Array[String] = ["truss_arch", "cable_stayed", "stone_arch", "canal", "causeway", "river"]
## Water level below the deck (m) per bridge type; "height_m" in the data overrides it (high bridges).
const WATER_DEPTH := {"truss_arch": 3.6, "cable_stayed": 5.0, "stone_arch": 3.2, "canal": 1.8, "causeway": 1.4, "river": 3.0}
## Default water colours per bridge type (scenery "water" and bridge "water" override them).
const WATER_COLOR := {"canal": "#3e5a50", "causeway": "#4f8a8c", "river": "#4b6878", "stone_arch": "#4f6c72",
	"truss_arch": "#4d6370", "cable_stayed": "#4d6370"}
const DEFAULT_CLEAR_M := [100.0, 40.0]   ## landmark plaza: visible metres kept free before / after it
const MIN_BRIDGE_GAP_KM := 0.3            ## between two bridges and between a bridge and a tunnel


## Style id of a city: its own "style", else the style of its country, else DEFAULT_STYLE.
static func style_for(db: Dictionary, city_id: String, country: String) -> String:
	var entry := city_entry(db, city_id)
	var styles: Dictionary = db.get("styles", {})
	var st := str(entry.get("style", ""))
	if st != "" and styles.has(st):
		return st
	var by_country: Dictionary = db.get("country_style", {})
	st = str(by_country.get(country, ""))
	if st != "" and styles.has(st):
		return st
	return DEFAULT_STYLE


static func city_entry(db: Dictionary, city_id: String) -> Dictionary:
	var cities: Dictionary = db.get("cities", {})
	var e: Variant = cities.get(city_id, {})
	return e if e is Dictionary else {}


## Scenery ids of a style: {outskirts, center} ("" when the style is unknown).
static func scenery_ids(db: Dictionary, style: String) -> Dictionary:
	var styles: Dictionary = db.get("styles", {})
	var s: Dictionary = styles.get(style, {})
	return {"outskirts": str(s.get("outskirts", "")), "center": str(s.get("center", ""))}


## Catalogue entry of a landmark sprite (cities.json "landmark_sets"): name, height_m, width_m, proc,
## fallback, fallback_scale, fallback_tint, required. {} for plain prop sets ("props/church" as a landmark).
static func landmark_info(db: Dictionary, set_id: String) -> Dictionary:
	var sets: Dictionary = db.get("landmark_sets", {})
	var e: Variant = sets.get(set_id, {})
	return e if e is Dictionary else {}


## Fills the city fields of plan p for its destination (p.to_id). Called by StagePlan.build when the
## city data is passed in. cities = network cities (for the destination country).
static func apply(p: StagePlan, db: Dictionary, cities: Dictionary, cfg: Dictionary) -> void:
	if db.is_empty():
		return
	var time_scale := float(ConfigLoader.lookup(cfg, "time.time_scale", 12.0))
	var country := str(cities.get(p.to_id, {}).get("country", p.country_at(p.length_km)))
	var entry := city_entry(db, p.to_id)
	p.city_style = style_for(db, p.to_id, country)
	var ids := scenery_ids(db, p.city_style)
	p.city_scenery_outskirts = str(ids["outskirts"])
	p.city_scenery_center = str(ids["center"])
	var center_km := float(entry.get("center_km", db.get("center_km", DEFAULT_CENTER_KM)))
	p.city_center_km = clampf(p.length_km - center_km, p.city_limits_km, p.length_km)
	var bg: Variant = entry.get("background", {})
	p.city_background = (bg as Dictionary).duplicate(true) if bg is Dictionary else {}
	_apply_bridges(p, entry, time_scale)
	_apply_landmarks(p, db, entry)
	_apply_skyline(p, db, entry)


static func _apply_bridges(p: StagePlan, entry: Dictionary, time_scale: float) -> void:
	var out: Array[Dictionary] = []
	for raw: Variant in entry.get("bridges", []):
		if not raw is Dictionary:
			continue
		var b: Dictionary = raw
		var typ := str(b.get("type", "river"))
		var name := str(b.get("name", ""))
		if not BRIDGE_TYPES.has(typ):
			p.warnings.append("Brücke %s in %s: unbekannter Typ '%s' – nutze river" % [name, p.to_name, typ])
			typ = "river"
		var length_m := maxf(3.0, float(b.get("length_m", 60.0)))
		var start := p.length_km - float(b.get("km_to_finish", 0.0))
		var end := start + length_m * time_scale / 1000.0
		if start < 0.0 or end > p.length_km - 0.2:
			p.warnings.append("Brücke %s in %s liegt außerhalb der Etappe %s – verworfen" % [name, p.to_name, p.stage_id])
			continue
		var clash := ""
		for t in p.tunnels:
			if start < float(t["end_km"]) + MIN_BRIDGE_GAP_KM and end > float(t["start_km"]) - MIN_BRIDGE_GAP_KM:
				clash = "Tunnel " + str(t["name"])
		for o in out:
			if start < float(o["end_km"]) + MIN_BRIDGE_GAP_KM and end > float(o["start_km"]) - MIN_BRIDGE_GAP_KM:
				clash = "Brücke " + str(o["name"])
		if clash != "":
			p.warnings.append("Brücke %s in %s überschneidet %s (Etappe %s) – verworfen" % [name, p.to_name, clash, p.stage_id])
			continue
		var depth := float(b.get("height_m", WATER_DEPTH.get(typ, 3.0)))
		out.append({
			"start_km": start, "end_km": end, "length_m": length_m, "type": typ, "name": name,
			"depth_m": clampf(depth, 0.5, 60.0),
			"water": str(b.get("water", "")),
			"color": str(b.get("color", "")),
			"bank": str(b.get("bank", "")),
			"ships": int(b.get("ships", 0)),
			"pylon_m": float(b.get("pylon_m", 80.0)),
			"boats": int(b.get("boats", 2 if typ == "canal" else 0)),
		})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["start_km"]) < float(y["start_km"]))
	p.bridges = out


## Landmark props: catalogue data merged into every placement. Placements must lie inside the City Limits
## and outside tunnels; otherwise they are dropped with a warning.
static func _apply_landmarks(p: StagePlan, db: Dictionary, entry: Dictionary) -> void:
	var out: Array[Dictionary] = []
	for raw: Variant in entry.get("landmarks", []):
		if not raw is Dictionary:
			continue
		var lm: Dictionary = raw
		var set_id := str(lm.get("set", ""))
		var km := p.length_km - float(lm.get("km_to_finish", 0.0))
		if set_id == "":
			continue
		if km < p.city_limits_km or km > p.length_km:
			p.warnings.append("Wahrzeichen %s in %s liegt nicht in den City Limits – verworfen" % [set_id, p.to_name])
			continue
		if p.in_tunnel(km):
			p.warnings.append("Wahrzeichen %s in %s liegt im Tunnel (Etappe %s) – verworfen" % [set_id, p.to_name, p.stage_id])
			continue
		if p.on_bridge(km):
			p.warnings.append("Wahrzeichen %s in %s steht auf einer Brücke (im Wasser) – verworfen" % [set_id, p.to_name])
			continue
		var d := landmark_entry(db, set_id, lm)
		d["km"] = km
		d["side"] = -1 if int(lm.get("side", 1)) < 0 else 1
		d["x_m"] = maxf(0.0, float(lm.get("x_m", 40.0)))
		d["scale"] = float(lm.get("scale", 1.0))
		var cl: Array = lm.get("clear_m", DEFAULT_CLEAR_M)
		d["clear_m"] = [float(cl[0]), float(cl[1])] if cl.size() >= 2 else DEFAULT_CLEAR_M.duplicate()
		d["plaza"] = str(lm.get("plaza", "park"))
		out.append(d)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["km"]) < float(y["km"]))
	p.landmarks = out


## Drawing data of a landmark (set, procedural fallback, fallback sprite, size) from the catalogue, with the
## values of the placement / skyline entry taking precedence.
static func landmark_entry(db: Dictionary, set_id: String, over: Dictionary = {}) -> Dictionary:
	var info := landmark_info(db, set_id)
	var d := {"set": set_id, "name": str(over.get("name", info.get("name", set_id.get_file())))}
	for key: String in ["proc", "fallback", "fallback_scale", "fallback_tint", "tint", "height_m", "width_m", "dome", "wall", "cross"]:
		if over.has(key):
			d[key] = over[key]
		elif info.has(key):
			d[key] = info[key]
	if not d.has("height_m"):
		d["height_m"] = 40.0
	return d


static func _apply_skyline(p: StagePlan, db: Dictionary, entry: Dictionary) -> void:
	var out: Array[Dictionary] = []
	for raw: Variant in entry.get("skyline", []):
		var over: Dictionary = {}
		var set_id := ""
		if raw is Dictionary:
			over = raw
			set_id = str(over.get("set", ""))
		else:
			set_id = str(raw)
		if set_id == "":
			continue
		var d := landmark_entry(db, set_id, over)
		if d.has("proc"):
			# like the landmark props (Track._build_landmark): until the sprite exists the procedural stand-in is
			# drawn, not the generic fallback sprite (a TV tower as a 369 m glass office block)
			d.erase("fallback")
		d["azimuth_deg"] = float(over.get("azimuth_deg", NAN))
		d["scale"] = float(over.get("scale", 1.0))
		d["prop_km"] = -1.0
		for lm in p.landmarks:
			if str(lm["set"]) == set_id:
				d["prop_km"] = float(lm["km"])
		out.append(d)
	p.skyline = out


# --- validation (tests, GameData) ----------------------------------------------------------------

## Checks the city data against the network, the scenery and the sprite ids (Dictionary set id -> any).
## Returns German messages; [] = all fine. Stage-dependent checks (bridges vs. tunnels …) run through
## StagePlan.build in the data tests.
static func validate(db: Dictionary, cities: Dictionary, scenery: Dictionary, sprites: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var styles: Dictionary = db.get("styles", {})
	if not styles.has(DEFAULT_STYLE):
		out.append("Stil %s fehlt" % DEFAULT_STYLE)
	for st: String in styles:
		var ids := scenery_ids(db, st)
		for part: String in ["outskirts", "center"]:
			var sid := str(ids[part])
			if sid == "" or not scenery.has(sid):
				out.append("Stil %s: Landschaft %s fehlt in data/scenery.json" % [st, sid])
	var by_country: Dictionary = db.get("country_style", {})
	for c: String in by_country:
		if not styles.has(str(by_country[c])):
			out.append("Land %s: unbekannter Stil %s" % [c, str(by_country[c])])
	var known: Dictionary = db.get("cities", {})
	for cid: String in known:
		if not cities.has(cid):
			out.append("cities.json: unbekannte Stadt %s" % cid)
	for cid: String in cities:
		var st := str(city_entry(db, cid).get("style", ""))
		if st != "" and not styles.has(st):
			out.append("%s: unbekannter Stil %s" % [cid, st])
	# landmark sprites: the sprite itself, its procedural stand-in or a fallback sprite must exist
	var sets: Dictionary = db.get("landmark_sets", {})
	for sid: String in sets:
		var info: Dictionary = sets[sid]
		if not sprites.has(sid) and str(info.get("proc", "")) == "" and not sprites.has(str(info.get("fallback", ""))):
			out.append("Wahrzeichen %s: weder Sprite noch Ersatz" % sid)
		if float(info.get("height_m", 0.0)) <= 0.0:
			out.append("Wahrzeichen %s: height_m fehlt" % sid)
	for cid: String in known:
		var e := city_entry(db, cid)
		for lm: Variant in e.get("landmarks", []):
			var sid := str((lm as Dictionary).get("set", "")) if lm is Dictionary else ""
			if not sets.has(sid) and not sprites.has(sid):
				out.append("%s: Wahrzeichen %s weder im Katalog noch als Sprite" % [cid, sid])
		for sk: Variant in e.get("skyline", []):
			var sid := str((sk as Dictionary).get("set", "")) if sk is Dictionary else str(sk)
			if not sets.has(sid) and not sprites.has(sid):
				out.append("%s: Skyline %s weder im Katalog noch als Sprite" % [cid, sid])
		for b: Variant in e.get("bridges", []):
			if b is Dictionary and not BRIDGE_TYPES.has(str((b as Dictionary).get("type", ""))):
				out.append("%s: Brückentyp %s unbekannt" % [cid, str((b as Dictionary).get("type", ""))])
	return out


## Scenery prop rules whose sprite set and fallback both do not exist (would draw nothing).
static func missing_props(scenery: Dictionary, sprites: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for sid: String in scenery:
		for r: Dictionary in (scenery[sid] as Dictionary).get("props", []):
			var set_id := str(r.get("set", ""))
			if not sprites.has(set_id) and not sprites.has(str(r.get("fallback", ""))):
				out.append("%s: %s ohne vorhandenes Sprite oder Ersatz" % [sid, set_id])
	return out
