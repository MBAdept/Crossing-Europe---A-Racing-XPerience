extends SceneTree
## Contact sheet of the real-time models (docs/modelle.md): renders every model of the manifest with the
## materials of the game (ModelFactory + ModernMaterials) under a small sun / sky rig and writes one PNG.
## Needs OpenGL - run it through tools/models_contact_sheet.sh (Xvfb):
##   godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/models/contact_sheet.gd --
##       --out=<abs.png> [--only=<glob>] [--night] [--tile=480x320] [--cols=4] [--lods=lod0,show]
##       [--showroom] [--channels] [--manifest=<path>] [--sun=x,y,z] [--sun-energy=<e>] [--ambient-energy=<e>]
## --sun: direction to the sun in camera space (default -0.55,0.92,0.55 = upper left, from the viewer's side;
##        e.g. 0.3,0.6,-1 = back light). --sun-energy / --ambient-energy: energies of the rig (day 0.8 / 1.0,
##        night 0.1 / 0.55), e.g. --sun-energy=0 to look at the ambient part alone.
## Day sheet:   every level of detail from the approach / rear view and from the far side, the colour sets
##              of vehicles, the impostor of trees.
## Night sheet: ce_night = 1 (lit windows, lamps of props); vehicles once per lamp channel:
##              tail, brake, both indicators, head, reverse, beacons.
## --showroom:  the `show` level of the player cars from the camera of the Cycles showroom sprites
##              (for A/B pictures; 768x480 per tile).
## --channels:  no model - a strip of 15 panels, one per lamp channel of the vpbr format (0 on the left),
##              once per lamp state: shows that every channel answers to its instance uniform or global.
## --showroom:  ... followed by the Cycles sprite of the same car on the ground colour of the real-time tile
##              (same camera: the A/B picture that decides the manifest flag `showroom`).
## --review:    vehicles only - large tiles for judging a model: rear and front three-quarter views, straight
##              from behind, side, close-ups of the rear end, a wheel and the cabin, the tail and brake lamps at
##              night, close-ups of a tail lamp and a headlight, from above, straight from ahead. Tile 960x600 unless --tile says otherwise. --views=0,4,7 picks tiles of REVIEW_VIEWS,
##              --set=<sprite set> the colour set, --lods=lod0,lod1 the levels.
## --clay:      every surface plain grey, glass hidden - the form alone (steps, blades, dents)
## --caster:    the shadow caster in red over the visible model: red is where it stands out of the hull
## --chase=8,30[,..]  vehicles only - the picture of the GAME camera (contract D12: 3.4 m high, no pitch, focal
##              length 711 px at 720 px, horizon at 45 %) with the vehicle's centre that many metres ahead,
##              rendered at 1280x720 and cut out around the vehicle with whole-number magnification (what the
##              player sees, pixel for pixel), by day and with tail / brake lights at night;
##              --lane=<m> puts the vehicle that far to the side (the next lane: -3.5).
## --look=race (default): the race look of the vehicle materials - the class parameters the vehicle layer sets on
##              the shared materials (scripts/race3d/layers/vehicles.gd LOOK: clear coat mirroring the sky, base coat,
##              flakes, glass reflection; the mirrored sky = the sky of this rig) and, in --chase tiles, the fill light
##              of the player car (PLAYER_FILL). --look=neutral: the neutral defaults of the shaders (the look of the
##              vertex format alone, as tests/race3d/render/check_models.gd measures it).

const VEHICLE_KINDS: Array[String] = ["vehicle", "heavy"]
const LAMP_STATES: Array = [
	["Lampen aus", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), 30.0],
	["Rücklicht", Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 0), 30.0],
	["Bremslicht", Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 0), 30.0],
	["Rück- + Bremslicht", Vector4(1, 1, 0, 0), Vector4(0, 0, 0, 0), 30.0],
	["Blinker links", Vector4(1, 0, 1, 0), Vector4(0, 0, 0, 0), 30.0],
	["Blinker rechts", Vector4(1, 0, 0, 1), Vector4(0, 0, 0, 0), 30.0],
	["Rückfahrlicht", Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), 30.0],
	["Scheinwerfer", Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0), 150.0],
	["Blinker links (vorn)", Vector4(1, 0, 1, 0), Vector4(1, 0, 0, 0), 150.0],
	["Blinker rechts (vorn)", Vector4(1, 0, 0, 1), Vector4(1, 0, 0, 0), 150.0],
	["Blaulicht A", Vector4(1, 0, 0, 0), Vector4(1, 0, 1, 0), 30.0],
	["Blaulicht B", Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 1), 30.0],
]

## lamp channels 0..14: lit colours of the test strip (--channels)
const CHANNEL_COLORS: Array[String] = ["#ff1a0e", "#ff2414", "#ff2010", "#ffa01a", "#ffa01a", "#fff3d6", "#f4f8ff",
	"#f4f6ff", "#fff6e0", "#ffb040", "#2a5cff", "#2a5cff", "#ffe0a0", "#40ff80", "#c8c0b0"]
const CHANNEL_STATES: Array = [
	["alle Lampenwerte 0, Tag: nur 6 (Tagfahrlicht) und 13 (immer an) leuchten", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), 0.0],
	["Rücklicht (lamp_a.x): 0, 2 mit 35 %, 8 Kennzeichen, 9 Umriss", Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 0), 0.0],
	["Bremslicht (lamp_a.y): 1 und 2", Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 0), 0.0],
	["Blinker links (lamp_a.z): 3", Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 0), 0.0],
	["Blinker rechts (lamp_a.w): 4", Vector4(0, 0, 0, 1), Vector4(0, 0, 0, 0), 0.0],
	["Scheinwerfer (lamp_b.x): 5, Tagfahrlicht 6 gedimmt", Vector4(0, 0, 0, 0), Vector4(1, 0, 0, 0), 0.0],
	["Rückfahrlicht (lamp_b.y): 7", Vector4(0, 0, 0, 0), Vector4(0, 1, 0, 0), 0.0],
	["Blaulicht A (lamp_b.z): 10", Vector4(0, 0, 0, 0), Vector4(0, 0, 1, 0), 0.0],
	["Blaulicht B (lamp_b.w): 11", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 1), 0.0],
	["Nacht (ce_night = 1): 12 Lichter, 14 angestrahlte Fläche", Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0), 1.0],
]

var _args: Dictionary = {}
var _mats: ModernMaterials
var _sv: SubViewport
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _ground: MeshInstance3D
var _label: Label
var _holder: Node3D
var _tile := Vector2i(480, 320)
var _night := false
var _first := true          ## the sky radiance needs some frames before the first picture
var _label_sv: SubViewport  ## the caption is drawn in its own viewport and blended onto the tile (chase tiles are cut out)
var _sky_mat: ProceduralSkyMaterial
var _rig_night := false
var _last_image: Image = null
var _race_look := true      ## --look=race: the class parameters of the vehicle layer (see the header)
var _player_fill := 0.0     ## fill light of the player car in --chase tiles (vehicle layer PLAYER_FILL)
const GAME_SIZE := Vector2i(1280, 720)
const GAME_FOCAL_PX := 711.0
const GAME_CAM_HEIGHT := 3.4


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var out := str(_args.get("out", ""))
	if out == "":
		print("contact_sheet: --out=<Datei.png> fehlt")
		quit(1)
		return
	if _args.has("manifest"):
		ModelDB.load_manifest(str(_args["manifest"]))
	if not ModelDB.available():
		print("contact_sheet: kein gültiges Modell-Manifest")
		quit(1)
		return
	_night = _args.has("night") or _args.has("channels")
	var showroom := _args.has("showroom")
	var review := _args.has("review")
	var chase := _args.has("chase")
	if showroom:
		_tile = Vector2i(768, 480)
	elif review or chase:
		_tile = Vector2i(960, 600)
	if _args.has("tile"):
		var p := str(_args["tile"]).split("x")
		_tile = Vector2i(int(p[0]), int(p[1]))
	var cols := int(str(_args.get("cols", "2" if (showroom or review or chase) else "4")))
	_mats = ModernMaterials.new()
	_apply_look()
	_build_rig()
	var tiles: Array = []
	var only := str(_args.get("only", "*"))
	if _args.has("channels"):
		for st: Array in CHANNEL_STATES:
			tiles.append({"strip": true, "lamp_a": st[1], "lamp_b": st[2], "night": st[3], "yaw": 0.0, "el": 4.0,
				"aabb": [0.0, 0.0, -0.1, 15.0 * 0.62 - 0.12, 0.95, 0.1], "text": str(st[0])})
	else:
		for mid: String in ModelDB.model_ids():
			if not _matches(mid, only):
				continue
			if showroom:
				tiles.append_array(_showroom_tiles(mid))
			elif review or chase:
				if review:
					tiles.append_array(_review_tiles(mid))
				if chase:
					tiles.append_array(_chase_tiles(mid))
			else:
				tiles.append_array(_tiles_for(mid))
	if tiles.is_empty():
		print("contact_sheet: kein Modell passt auf ", only)
		quit(1)
		return
	cols = mini(cols, tiles.size())
	var rows := int(ceil(float(tiles.size()) / float(cols)))
	var sheet := Image.create(cols * _tile.x, rows * _tile.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in tiles.size():
		var img: Image = await _render(tiles[i])
		img.convert(Image.FORMAT_RGB8)
		_last_image = img
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, _tile), Vector2i((i % cols) * _tile.x, (i / cols) * _tile.y))
	var err := sheet.save_png(out)
	print("contact_sheet: %d Kacheln (%d x %d) -> %s%s" % [tiles.size(), sheet.get_width(), sheet.get_height(), out, "" if err == OK else "  FEHLER %d" % err])
	quit(0 if err == OK else 1)


# --- tiles ---------------------------------------------------------------------------------------------

## --only: one glob or several separated by commas ("traffic/suv,traffic/van")
func _matches(mid: String, only: String) -> bool:
	for g: String in only.split(",", false):
		if mid.match(g.strip_edges()):
			return true
	return false


func _tiles_for(mid: String) -> Array:
	var m := ModelDB.model(mid)
	var kind := str(m.get("kind", ""))
	var sets := _sets_of(mid)
	var out: Array = []
	var want_lods: Array = str(_args.get("lods", "")).split(",", false)
	if VEHICLE_KINDS.has(kind):
		var first := str(sets[0]) if not sets.is_empty() else ""
		if _night:
			first = _lightest_set(sets)
			for st: Array in LAMP_STATES:
				if (str(st[0]).begins_with("Blaulicht")) and not _has_light(m, "beacon_a"):
					continue
				var tile := {"set": first, "model": mid, "lod": "lod0", "yaw": st[3], "el": 12.0,
					"lamp_a": st[1], "lamp_b": st[2], "text": "%s · %s" % [mid, st[0]]}
				if st != LAMP_STATES[0]:
					# close-up of the end of the car that carries the lamps (the first tile shows the whole car)
					var bb: Array = m.get("aabb", [-1, 0, -2, 1, 1.5, 2])
					var rear := float(st[3]) < 90.0
					var z0 := (float(bb[5]) - 1.2) if rear else float(bb[2])
					tile["aabb"] = [float(bb[0]), 0.2, z0, float(bb[3]), float(bb[4]) * 0.82, z0 + 1.2]
				out.append(tile)
			return out
		for l: Variant in m.get("lods", []):
			var ln := str((l as Dictionary)["name"])
			if not want_lods.is_empty() and not want_lods.has(ln):
				continue
			for yaw: float in [30.0, 150.0]:
				out.append({"set": first, "model": mid, "lod": ln, "yaw": yaw, "el": 14.0,
					"text": "%s · %s · %d Dreiecke" % [mid, ln, int((l as Dictionary).get("tris", 0))]})
		if m.has("shadow") and want_lods.is_empty():
			out.append({"set": first, "model": mid, "lod": "lod0", "yaw": 30.0, "el": 14.0, "show_caster": true,
				"text": "%s · Schattenwerfer · %d Dreiecke" % [mid, int((m["shadow"] as Dictionary).get("tris", 0))]})
		if want_lods.is_empty():
			for i in range(1, sets.size()):
				var sid := str(sets[i])
				if str(ModelDB.resolve(sid).get("lod", "")) != "":
					continue
				out.append({"set": sid, "model": mid, "lod": "lod0", "yaw": 30.0, "el": 14.0, "text": sid})
		return out
	# props, buildings, landmarks, trees: as seen from the road (approach) and from the far side
	var set_id := str(sets[0]) if not sets.is_empty() else ""
	for l: Variant in m.get("lods", []):
		var ln := str((l as Dictionary)["name"])
		if not want_lods.is_empty() and not want_lods.has(ln):
			continue
		for view: Array in [[-32.0, "Anfahrt"], [148.0, "Rückseite"]]:
			out.append({"set": set_id, "model": mid, "lod": ln, "yaw": view[0], "el": 9.0,
				"text": "%s · %s · %s · %d Dreiecke" % [mid, ln, view[1], int((l as Dictionary).get("tris", 0))]})
	if m.has("impostor"):
		out.append({"set": set_id, "model": mid, "lod": "impostor", "yaw": -32.0, "el": 9.0, "text": "%s · Impostor" % mid})
	return out


func _showroom_tiles(mid: String) -> Array:
	var m := ModelDB.model(mid)
	if ModelDB.lod(m, "show").is_empty():
		return []
	for sid: String in _sets_of(mid):
		if str(ModelDB.resolve(sid).get("lod", "")) == "show":
			var out: Array = [{"set": sid, "model": mid, "lod": "show", "showroom": true, "text": "%s · show · Echtzeit" % mid}]
			var sprite := "res://assets/sprites/" + sid + ".png"
			if FileAccess.file_exists(sprite):
				out.append({"sprite": sprite, "model": mid, "text": "%s · Sprite (Cycles), dieselbe Kamera" % sid})
			return out
	return []


## Large tiles for judging a vehicle (--review): [caption, yaw, elevation, part of the bounding box, night,
## lamp_a, lamp_b, level]. Parts: "" whole car, "rear" / "front" the last / first 1.3 m, "wheel" the rear
## right wheel, "cabin" the greenhouse seen from behind and above (what the chase camera looks into).
const REVIEW_VIEWS: Array = [
	["Heck schräg", 32.0, 13.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["von hinten", 0.0, 9.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Seite", 90.0, 4.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Front schräg", 148.0, 11.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Heck nah", 18.0, 10.0, "rear", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Front nah", 162.0, 8.0, "front", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Rad", 68.0, 6.0, "wheel", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Innenraum durch das Heckfenster", 10.0, 20.0, "cabin", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Nacht: Rücklicht", 18.0, 10.0, "rear", true, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0)],
	["Nacht: Rück- + Bremslicht", 18.0, 10.0, "rear", true, Vector4(1, 1, 0, 0), Vector4(1, 0, 0, 0)],
	["Nacht: Blinker links + Rückfahrlicht", 18.0, 10.0, "rear", true, Vector4(1, 0, 1, 0), Vector4(1, 1, 0, 0)],
	["Nacht: Scheinwerfer + Blinker rechts", 162.0, 8.0, "front", true, Vector4(1, 0, 0, 1), Vector4(1, 0, 0, 0)],
	["Rückleuchte nah", 28.0, 12.0, "taillamp", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Scheinwerfer nah", 152.0, 10.0, "headlamp", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Rückleuchte nah, Nacht: Rücklicht", 28.0, 12.0, "taillamp", true, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0)],
	["von oben hinten", 0.0, 38.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Front", 180.0, 6.0, "", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Vorderrad", 112.0, 7.0, "wheel_front", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Vorderrad von hinten (Radhaus)", 52.0, 9.0, "wheel_front", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)],
	["Heck nah, Nacht: Rücklicht (Spielkamera-Höhe)", 0.0, 21.0, "rear", true, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0)],
	["Heck nah, Nacht: Bremslicht", 0.0, 21.0, "rear", true, Vector4(1, 1, 0, 0), Vector4(1, 0, 0, 0)],
]


func _part_aabb(m: Dictionary, part: String) -> Array:
	var bb: Array = m.get("aabb", [-1, 0, -2, 1, 1.5, 2])
	var x0 := float(bb[0])
	var x1 := float(bb[3])
	var z0 := float(bb[2])
	var z1 := float(bb[5])
	var h := float(bb[4])
	match part:
		"rear":
			return [x0, 0.15, z1 - 1.3, x1, h * 0.86, z1]
		"front":
			return [x0, 0.1, z0, x1, h * 0.8, z0 + 1.3]
		"wheel", "wheel_front":
			# the rear right wheel ("wheel") or the front right wheel ("wheel_front", for the arch and the bumper end)
			var front := part == "wheel_front"
			for l: Variant in m.get("lods", []):
				for p: Variant in (l as Dictionary).get("parts", []):
					var pd: Dictionary = p
					if pd.has("wheel") and float((pd.get("pos", [0, 0, 0]) as Array)[0]) > 0.0 and ((float((pd.get("pos", [0, 0, 0]) as Array)[2]) < 0.0) == front):
						var pos: Array = pd["pos"]
						var r := float((pd["wheel"] as Dictionary).get("radius", 0.33)) + 0.12
						return [float(pos[0]) - 0.3, 0.0, float(pos[2]) - r, float(pos[0]) + 0.15, 2.0 * r, float(pos[2]) + r]
			return bb
		"cabin":
			return [x0 * 0.82, h * 0.62, z0 * 0.2, x1 * 0.82, h, z1 * 0.8]
		"taillamp", "headlamp":
			# around the light anchor of the right tail lamp / the right headlight
			var role := "tail" if part == "taillamp" else "head"
			for l: Variant in m.get("lights", []):
				var ld: Dictionary = l
				var lp: Array = ld.get("pos", [0, 0, 0])
				if str(ld.get("role", "")) == role and float(lp[0]) > 0.2:
					var c := Vector3(float(lp[0]), float(lp[1]), float(lp[2]))
					return [c.x - 0.34, c.y - 0.2, c.z - 0.3, c.x + 0.26, c.y + 0.2, c.z + 0.3]
			return bb
	return bb


func _review_tiles(mid: String) -> Array:
	var m := ModelDB.model(mid)
	if not VEHICLE_KINDS.has(str(m.get("kind", ""))):
		return []
	var sets := _sets_of(mid)
	if sets.is_empty():
		return []
	var set_id := str(_args.get("set", str(sets[0])))
	var out: Array = []
	var levels: Array = str(_args.get("lods", "lod0")).split(",", false)
	var pick: Array = str(_args.get("views", "")).split(",", false)
	for ln: Variant in levels:
		for vi in REVIEW_VIEWS.size():
			var v: Array = REVIEW_VIEWS[vi]
			if not pick.is_empty() and not pick.has(str(vi)):
				continue
			if str(ln) != "lod0" and str(ln) != "show" and (str(v[3]).begins_with("wheel") or str(v[3]) == "cabin"):
				continue
			var tile := {"set": set_id, "model": mid, "lod": str(ln), "yaw": v[1], "el": v[2], "is_night": v[4],
				"lamp_a": v[5], "lamp_b": v[6], "text": "%s · %s · %s" % [mid, ln, v[0]]}
			if str(v[3]) != "":
				tile["aabb"] = _part_aabb(m, str(v[3]))
			out.append(tile)
	return out


## Pictures of the game camera (--chase=<m>,<m>...): by day, with tail lights and with brake lights at night.
func _chase_tiles(mid: String) -> Array:
	var m := ModelDB.model(mid)
	if not VEHICLE_KINDS.has(str(m.get("kind", ""))):
		return []
	var sets := _sets_of(mid)
	if sets.is_empty():
		return []
	var set_id := str(_args.get("set", str(sets[0])))
	var lane := float(str(_args.get("lane", "0")))
	var out: Array = []
	var dists: Array = str(_args.get("chase", "9,30")).split(",", false)
	if dists.is_empty() or str(dists[0]) == "1":
		dists = ["9", "30"]
	for d: Variant in dists:
		var dist := float(str(d))
		var lod := ModelDB.lod_for_distance(m, dist) if not _args.has("lods") else str(_args["lods"]).split(",")[0]
		if lod == ModelDB.IMPOSTOR:
			lod = "lod0"
		for st: Array in [["Tag", false, Vector4(0, 0, 0, 0), Vector4(0, 0, 0, 0)], ["Nacht, Rücklicht", true, Vector4(1, 0, 0, 0), Vector4(1, 0, 0, 0)],
				["Nacht, Bremslicht + Blinker links", true, Vector4(1, 1, 1, 0), Vector4(1, 0, 0, 0)]]:
			out.append({"set": set_id, "model": mid, "lod": lod, "chase": dist, "lane": lane, "is_night": st[1], "lamp_a": st[2], "lamp_b": st[3],
				"text": "%s · %s · Spielkamera %.0f m%s · %s" % [mid, lod, dist, "" if lane == 0.0 else " (%.1f m seitlich)" % lane, st[0]]})
	return out


func _sets_of(mid: String) -> Array:
	var out: Array = []
	for sid: String in ModelDB.set_ids():
		if str(ModelDB.resolve(sid).get("model_id", "")) == mid:
			out.append(sid)
	return out


## The set with the lightest paint: a black car shows nothing of its body on the night sheet.
func _lightest_set(sets: Array) -> String:
	var best := ""
	var best_l := -1.0
	for sid: Variant in sets:
		var paint: Dictionary = ModelDB.resolve(str(sid)).get("paint", {})
		var l := Color(str(paint.get("paint", "#808080"))).get_luminance()
		if l > best_l:
			best_l = l
			best = str(sid)
	return best


func _has_light(m: Dictionary, role: String) -> bool:
	for l: Variant in m.get("lights", []):
		if str((l as Dictionary).get("role", "")) == role:
			return true
	return false


## Test strip of the vpbr lamp channels: 15 upright panels, channel 0 on the left, each with its number.
func _channel_strip() -> Node3D:
	var root := Node3D.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for ch in CHANNEL_COLORS.size():
		var x0 := float(ch) * 0.62
		var base := verts.size()
		for c: Vector2 in [Vector2(x0, 0.9), Vector2(x0 + 0.5, 0.9), Vector2(x0 + 0.5, 0.3), Vector2(x0, 0.3)]:
			verts.append(Vector3(c.x, c.y, 0.0))
			normals.append(Vector3(0.0, 0.0, 1.0))
			colors.append(Color(CHANNEL_COLORS[ch]))          # alpha 1 = fixed colour
			uv.append(Vector2(0.5, 0.0))                       # roughness, metallic
			uv2.append(Vector2(float(ch) + 0.5, 1.0))          # lamp channel, weight
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		var lab := Label3D.new()
		lab.text = str(ch)
		lab.font_size = 56
		lab.pixel_size = 0.0035
		lab.position = Vector3(x0 + 0.25, 0.14, 0.02)
		root.add_child(lab)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _mats.material("vpbr"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	return root


# --- rig -------------------------------------------------------------------------------------------------

## The race look of the shared vehicle materials (--look=race, the default): the class parameters the vehicle layer
## sets (its constant LOOK) and the fill light of the player car (PLAYER_FILL) - read from the layer's script, so the
## sheet follows the renderer. The values below stand in if the script cannot be loaded.
func _apply_look() -> void:
	_race_look = str(_args.get("look", "race")) == "race"
	if not _race_look:
		return
	var look: Array = [["vpbr", "env_energy", 1.6], ["vpbr", "paint_base", 0.9], ["vpbr", "flake_strength", 0.6],
		["glass", "env_energy", 2.2]]
	_player_fill = 0.7
	var path := "res://scripts/race3d/layers/vehicles.gd"
	if ResourceLoader.exists(path):
		var scr := load(path) as Script
		if scr != null:
			var cm := scr.get_script_constant_map()
			if cm.get("LOOK") is Array:
				look = cm["LOOK"]
			if cm.has("PLAYER_FILL"):
				_player_fill = float(cm["PLAYER_FILL"])
	for l: Variant in look:
		var e: Array = l
		_mats.set_class_parameter(str(e[0]), str(e[1]), e[2])


## The environment the clear coat, metals and glass mirror (race look): the sky of this rig, the ground below - set
## the way the vehicle layer derives it from the palette (layers/vehicles.gd _set_environment).
func _set_env_reflection(top: Color, horizon: Color, ambient: Color) -> void:
	if not _race_look:
		return
	var ground := Color(0.30 * ambient.r, 0.31 * ambient.g, 0.32 * ambient.b)
	for cls: String in ["vpbr", "glass"]:
		_mats.set_class_parameter(cls, "env_zenith", top)
		_mats.set_class_parameter(cls, "env_horizon", horizon)
		_mats.set_class_parameter(cls, "env_ground", ground)


func _build_rig() -> void:
	_sv = SubViewport.new()
	_sv.size = _tile
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(_sv)
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	# as the race will do it (contract D6 / D7): ambient colour from the palette, sky only for reflections,
	# linear tonemapper, post path pinned on
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	# glow only adds light around what is brighter than white; the default blend mode (soft light) would
	# change the contrast of the whole picture and crush the dark tones of the night sheet
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_sv.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38.0, 205.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.0
	_sv.add_child(_sun)
	_ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000.0, 6000.0)
	_ground.mesh = pm
	_ground.material_override = StandardMaterial3D.new()
	_sv.add_child(_ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_sv.add_child(_cam)
	_holder = Node3D.new()
	_sv.add_child(_holder)
	# the caption has its own transparent viewport: it is blended onto the finished tile
	_label_sv = SubViewport.new()
	_label_sv.size = _tile
	_label_sv.transparent_bg = true
	_label_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_label_sv)
	_label = Label.new()
	_label.position = Vector2(8.0, float(_tile.y) - 26.0)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	_label_sv.add_child(_label)
	_set_night(_night)
	ModernMaterials.set_global("ce_time", 1.7)
	ModernMaterials.set_global("ce_wind", Vector4(1.0, 0.0, 0.3, 0.0))


## Day or night rig: sky, ambient light, sun / moon, glow, ce_night. True if something changed (the sky radiance
## then needs some frames).
func _set_night(night: bool) -> bool:
	var changed := night != _rig_night or _first
	_rig_night = night
	if night:
		_sky_mat.sky_top_color = Color(0.01, 0.014, 0.035)
		_sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.075)
		_sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.012)
		_sky_mat.ground_horizon_color = Color(0.03, 0.035, 0.06)
	else:
		_sky_mat.sky_top_color = Color(0.24, 0.44, 0.78)
		_sky_mat.sky_horizon_color = Color(0.7, 0.79, 0.9)
		_sky_mat.ground_bottom_color = Color(0.2, 0.19, 0.17)
		_sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.74)
	# daylight close to the Cycles rig of the sprites (sun 2.4 W/m2 = energy 0.76 here, sky about 0.35)
	_env.ambient_light_color = Color(0.1, 0.12, 0.2) if night else Color(0.6, 0.64, 0.7)
	_env.ambient_light_energy = float(str(_args.get("ambient-energy", "0.55" if night else "1.0")))
	_set_env_reflection(_sky_mat.sky_top_color, _sky_mat.sky_horizon_color, _env.ambient_light_color)
	_env.glow_intensity = 0.7 if night else 0.25
	_sun.light_energy = float(str(_args.get("sun-energy", "0.1" if night else "0.8")))
	_sun.light_color = Color(0.62, 0.72, 1.0) if night else Color(1.0, 0.97, 0.92)
	ModernMaterials.set_global("ce_night", 1.0 if night else 0.0)
	ModernMaterials.set_global("ce_sun_color", ModernMaterials.light_value(_sun.light_color, _sun.light_energy))
	ModernMaterials.set_global("ce_ambient", ModernMaterials.light_value(_env.ambient_light_color, _env.ambient_light_energy))
	return changed


## The Cycles sprite of a showroom set on the ground colour of the tile rendered before it (the real-time picture
## of the same car from the same camera).
func _sprite_tile(t: Dictionary) -> Image:
	var img := Image.create(_tile.x, _tile.y, false, Image.FORMAT_RGBA8)
	var bg := Color(0.3, 0.3, 0.32)
	if _last_image != null:
		bg = _last_image.get_pixel(12, _last_image.get_height() - 60)
	bg.a = 1.0
	img.fill(bg)
	var sprite := Image.load_from_file(ProjectSettings.globalize_path(str(t["sprite"])))
	if sprite != null:
		sprite.convert(Image.FORMAT_RGBA8)
		if sprite.get_size() != _tile:
			sprite.resize(_tile.x, _tile.y, Image.INTERPOLATE_LANCZOS)
		img.blend_rect(sprite, Rect2i(Vector2i.ZERO, _tile), Vector2i.ZERO)
	return img


func _caption(img: Image, text: String) -> Image:
	_label.text = text
	await process_frame
	await RenderingServer.frame_post_draw
	var lab := _label_sv.get_texture().get_image()
	lab.convert(Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	img.blend_rect(lab, Rect2i(Vector2i.ZERO, _tile), Vector2i.ZERO)
	return img


func _render(t: Dictionary) -> Image:
	if t.has("sprite"):
		return await _caption(_sprite_tile(t), str(t["text"]))
	for c: Node in _holder.get_children():
		c.free()
	var m := ModelDB.model(str(t.get("model", "")))
	var vehicle := VEHICLE_KINDS.has(str(m.get("kind", ""))) or t.has("strip")
	var night := bool(t.get("is_night", _night))
	var rig_changed := _set_night(night)
	ModernMaterials.set_global("ce_night", float(t.get("night", 1.0 if night else 0.0)))
	var gm: StandardMaterial3D = _ground.material_override
	gm.albedo_color = Color(0.2, 0.2, 0.21) if vehicle else Color(0.22, 0.33, 0.14)
	gm.roughness = 0.85 if vehicle else 0.95
	var node: Node3D = null
	var text := str(t["text"])
	if t.has("strip"):
		node = _channel_strip()
	elif str(t["lod"]) == "impostor":
		node = ModelFactory.build_impostor(str(t["set"]), _mats)
	else:
		node = ModelFactory.build(str(t["set"]), str(t["lod"]), _mats)
	if node == null:
		text += "  (fehlt)"
	else:
		_holder.add_child(node)
		if t.has("lamp_a"):
			ModelFactory.set_lamps(node, t["lamp_a"], t["lamp_b"])
		if t.has("chase") and _player_fill > 0.0 and str(t.get("model", "")).begins_with("player/"):
			# the player car in the race: the vehicle layer adds a fill light (Arcade brightens its player sprite)
			for c: Node in node.find_children("*", "GeometryInstance3D", true, false):
				(c as GeometryInstance3D).set_instance_shader_parameter(&"fill", _player_fill)
		if t.get("show_caster", false):
			# show the caster itself instead of the body
			for c: Node in node.get_children():
				var mi := c as MeshInstance3D
				mi.visible = mi.name == "shadow"
				if mi.name == "shadow":
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _args.has("caster"):
			# --caster: the shadow caster in red over the visible model - red shows only where the caster stands
			# out of the hull (there it would shade its own body)
			var red := StandardMaterial3D.new()
			red.albedo_color = Color(1.0, 0.05, 0.05)
			red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for c: Node in node.find_children("shadow", "MeshInstance3D", true, false):
				var mi := c as MeshInstance3D
				mi.visible = true
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON    # (shadows-only nodes are not drawn)
				mi.material_override = red
		if _args.has("clay"):
			# --clay: the form alone - every surface plain grey, glass hidden (steps, blades and dents show)
			var clay := StandardMaterial3D.new()
			clay.albedo_color = Color(0.72, 0.72, 0.74)
			clay.roughness = 0.65
			for c: Node in node.find_children("*", "MeshInstance3D", true, false):
				var mi := c as MeshInstance3D
				if mi.name == "shadow":
					continue
				for si in mi.mesh.get_surface_count():
					mi.set_surface_override_material(si, clay if mi.mesh.surface_get_name(si) != "glass" else _invisible())
	var bb: Array = t.get("aabb", m.get("aabb", [-1, 0, -1, 1, 2, 1]))
	var lo := Vector3(float(bb[0]), float(bb[1]), float(bb[2]))
	var hi := Vector3(float(bb[3]), float(bb[4]), float(bb[5]))
	var centre := (lo + hi) * 0.5
	var radius := (hi - lo).length() * 0.5
	var chase := t.has("chase")
	_sv.size = GAME_SIZE if chase else _tile
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	if chase:
		# the game camera (contract D12): frustum with a constant focal length, no pitch, horizon at 45 %
		var near := 1.0
		var size := near * float(GAME_SIZE.y) / GAME_FOCAL_PX
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.set_frustum(size, Vector2(0.0, -0.05 * size), near, 2600.0)
		_cam.basis = Basis.IDENTITY
		_cam.position = Vector3(-float(t.get("lane", 0.0)), GAME_CAM_HEIGHT, float(t["chase"]))
	elif t.get("showroom", false):
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_showroom_camera(m)
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 30.0
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		var yaw := deg_to_rad(float(t.get("yaw", 30.0)))
		var el := deg_to_rad(float(t.get("el", 12.0)))
		var dir := Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el))
		# tight fit of the bounding box: the distance every corner needs, horizontally and vertically
		var basis := Basis.looking_at(-dir, Vector3.UP)
		var tan_v := tan(deg_to_rad(_cam.fov * 0.5))
		var tan_h := tan_v * float(_tile.x) / float(_tile.y)
		var dist := 0.5
		for i in 8:
			var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z) - centre
			var c := basis.inverse() * corner          # camera space: x right, y up, z towards the camera
			dist = maxf(dist, maxf(absf(c.x) / tan_h, absf(c.y) / (tan_v * 0.84)) + c.z)
		dist *= float(t.get("fit", 1.06))
		_cam.position = centre + dir * dist
		_cam.basis = basis
		_cam.near = maxf(0.05, dist * 0.01)
		_cam.far = dist * 4.0 + 2000.0
	# night: the lamps of props light their surroundings as the renderer's omni pool will
	if night and not vehicle:
		for l: Variant in m.get("lights", []):
			var ld: Dictionary = l
			if str(ld.get("role", "")) != "lights" or _holder.get_child_count() > 8:
				continue
			var om := OmniLight3D.new()
			var lp: Array = ld.get("pos", [0, 0, 0])
			om.position = Vector3(float(lp[0]), float(lp[1]) - 0.4, float(lp[2]))
			om.light_color = Color(str(ld.get("color", "#fff0cf")))
			om.light_energy = 3.0
			om.omni_range = 18.0
			_holder.add_child(om)
	# sun as in the sprite rig: fixed relative to the camera - upper left, slightly from the viewer's side
	var sv := Vector3(-0.55, 0.92, 0.55)
	if _args.has("sun"):
		var sp := str(_args["sun"]).split(",")
		sv = Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	var to_sun := (_cam.basis * sv).normalized()
	_sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	ModernMaterials.set_global("ce_sun_dir", to_sun)
	_sun.directional_shadow_max_distance = 120.0 if chase else maxf(30.0, radius * 6.0)
	for i in (16 if (_first or rig_changed) else 4):
		await process_frame
	_first = false
	await RenderingServer.frame_post_draw
	var img := _sv.get_texture().get_image()
	if chase:
		# cut the vehicle out of the 1280 x 720 picture: the largest whole-number magnification that shows it all
		var r := Rect2()
		for i in 8:
			var corner := Vector3(lo.x if i & 1 == 0 else hi.x, lo.y if i & 2 == 0 else hi.y, lo.z if i & 4 == 0 else hi.z)
			var sp := _cam.unproject_position(corner)
			r = Rect2(sp, Vector2.ZERO) if i == 0 else r.expand(sp)
		var k := clampi(int(floor(minf(float(_tile.x) / (r.size.x * 1.1), float(_tile.y) / (r.size.y * 1.1)))), 1, 12)
		var cw := _tile.x / k
		var ch := _tile.y / k
		var c2 := r.get_center()
		var x0 := clampi(int(round(c2.x - cw * 0.5)), 0, GAME_SIZE.x - cw)
		var y0 := clampi(int(round(c2.y - ch * 0.5)), 0, GAME_SIZE.y - ch)
		img = img.get_region(Rect2i(x0, y0, cw, ch))
		img.resize(_tile.x, _tile.y, Image.INTERPOLATE_NEAREST)
		text += " · %d-fach vergrößert" % k
	return await _caption(img, text)


var _invisible_mat: StandardMaterial3D = null


## A material that draws nothing (glass in the --clay views).
func _invisible() -> StandardMaterial3D:
	if _invisible_mat == null:
		_invisible_mat = StandardMaterial3D.new()
		_invisible_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_invisible_mat.albedo_color = Color(1, 1, 1, 0)
		_invisible_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _invisible_mat


## Camera of the Cycles showroom sprites (tools/blender/cesprites/catalog.py, player_sets): the car turned
## by 142 degrees about its centre, 56 mm lens on a 36 mm sensor, 11 degrees above the horizon.
func _showroom_camera(m: Dictionary) -> void:
	var obj: Dictionary = m.get("object", {})
	var length := float(obj.get("length_m", 4.5))
	var height := float(obj.get("height_m", 1.45))
	var el := deg_to_rad(11.0)
	var dist := 1.72 * length
	var target := Vector3(0.0, height * 0.4, 0.0)
	# Blender: camera at (0, -dist cos el, tz + dist sin el), car turned by -142 deg about Z. Here the car
	# stays and the camera goes around it by +142 deg about the model's Y axis (Blender -y is model +Z):
	# it ends up in front of the car on its right-hand side.
	var a := deg_to_rad(142.0)
	_cam.position = target + Vector3(sin(a) * cos(el), sin(el), cos(a) * cos(el)) * dist
	_cam.look_at(target, Vector3.UP)
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.fov = rad_to_deg(2.0 * atan(18.0 / 56.0))
	_cam.near = 0.1
	_cam.far = 500.0
	# lens shift of the sprite camera (shift_y = -0.03 of the picture width): the car sits higher in the frame
	_cam.v_offset = -0.03 * 2.0 * dist * (18.0 / 56.0)
