extends SceneTree
## World check of the mode "Modern" (tools/run_tests.sh): the true world-space path of every stage direction
## (RoadPath3D) must never come close to itself within what is loaded at the same time – the terrain ribbons and
## props of two parts of the road would overlap. Loops of the road are fine as long as they are far apart along the
## path (chunks are streamed by path distance). A future stage that fails gets another seed.
##   godot --headless --path . -s res://tests/sim/modern_path_check.gd [-- --stage=<id>[,<id>…]] [--full] [--verbose]
## Checks (whole network, both directions):
##   modern_path_clearance  two points of the road 360 m … 1,900 m of path apart are at least 250 m apart by air
##   modern_path_loops      an approach below 250 m beyond that only from 2,000 m of path on
## Normal run (about 25 s): stage directions whose bends are too wide for any approach (curviness <= 1: radius
## >= 400 m; Schwarz's arc theorem, Fairness.proven_clear) are not generated. --full generates every stage direction,
## confirms that bound and adds the largest coordinate of a path, the free ribbon width (RoadPath3D.clearance) and
## the chunk load of the streamer rule (information for the terrain and the budgets, no check; about 55 s).
## Exit code 1 when a check fails.
## Rules and numbers: docs/renderer-modern.md. Owner: race3d kernel.

const Fair := preload("res://tests/race3d/fairness.gd")
const MIN_CLEAR_M := 250.0
const SEP_MIN_M := 360.0
const SEP_MAX_M := 1900.0
const LOOP_MIN_SEP_M := 2000.0


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return default


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var cfg := ConfigLoader.load_merged()
	var net := Fair.load_network()
	var only: Array = Array(_arg("stage", "").split(",", false))
	var full := _arg("full", "") != ""
	var verbose := _arg("verbose", "") != ""
	var r1 := float(ConfigLoader.lookup(cfg, "road.curve_radius_at_1_m", 120.0))
	var dirs := Fair.directions(net, only)
	var rows: Array = []
	var ribbons: Array = []
	var proven := 0
	var proven_checked := 0
	var bound_broken: Array[String] = []
	var widest_proven := INF
	for dir: Dictionary in dirs:
		var cmax := Fair.max_curve_of_stage(cfg, dir["stage"])
		var by_bound := cmax <= 1.0e-6 or Fair.proven_clear(r1 / cmax, MIN_CLEAR_M, SEP_MIN_M, LOOP_MIN_SEP_M)
		if by_bound:
			proven += 1
			if cmax > 1.0e-6:
				widest_proven = minf(widest_proven, r1 / cmax)
			if not full:
				continue
		var geo := Fair.build_geo(cfg, net, dir)
		var p := Fair.scan_path(geo, {"sep_min_m": SEP_MIN_M, "sep_max_m": SEP_MAX_M, "loop_m": MIN_CLEAR_M})
		rows.append(p)
		if by_bound:
			# the bound must hold: no curve beyond the limit of the stage, no approach, no early loop
			proven_checked += 1
			var peak := 0.0
			for c in (geo["curve"] as PackedFloat32Array):
				peak = maxf(peak, absf(c))
			if peak > cmax + 1.0e-4 or float(p["min_m"]) < MIN_CLEAR_M or float(p["loop_sep_m"]) < LOOP_MIN_SEP_M:
				bound_broken.append(str(p["name"]))
		if full:
			ribbons.append(Fair.scan_ribbon(cfg, geo))
	var total_m := 0.0
	var near := {}
	var near_dirs := {}
	var loop_sep := INF
	var loop_name := ""
	var loops: Array = []
	var far_m := 0.0
	var far_name := ""
	for p: Dictionary in rows:
		total_m += float(p["length_m"])
		if float(p["max_abs_m"]) > far_m:
			far_m = float(p["max_abs_m"])
			far_name = str(p["name"])
		for lim: float in (p["near_m"] as Dictionary):
			near[lim] = float(near.get(lim, 0.0)) + float(p["near_m"][lim])
			if float(p["near_m"][lim]) > 0.0:
				near_dirs[lim] = int(near_dirs.get(lim, 0)) + 1
		if float(p["loop_sep_m"]) < loop_sep:
			loop_sep = float(p["loop_sep_m"])
			loop_name = str(p["name"])
		if float(p["loop_min_m"]) < INF:
			loops.append(p)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["min_m"]) < float(b["min_m"]))
	loops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["loop_min_m"]) < float(b["loop_min_m"]))
	print("PATH %d Etappenrichtungen: %d gerechnet (%.0f km sichtbare Straße, Punkte alle 12 m), %d durch die Krümmungsschranke ausgeschlossen (Radius >= %s)" % [
		dirs.size(), rows.size(), total_m / 1000.0, proven if not full else 0, ("%.0f m" % widest_proven) if widest_proven < INF else "–"])
	if full:
		print("PATH Krümmungsschranke nachgerechnet für %d Etappenrichtungen: %s" % [proven_checked,
			"hält" if bound_broken.is_empty() else "VERLETZT bei " + ", ".join(bound_broken)])
	var limits := near.keys()
	limits.sort()
	for lim: float in limits:
		print("PATH ein anderer Teil der Straße (%.0f … %.0f m Weg entfernt) näher als %3.0f m: %7.0f m Straße = %.3f %%, %d Etappenrichtungen" % [
			SEP_MIN_M, SEP_MAX_M, lim, float(near[lim]), 100.0 * float(near[lim]) / maxf(1.0, total_m), int(near_dirs.get(lim, 0))])
	for i in mini(10 if verbose or full else 3, rows.size()):
		var p: Dictionary = rows[i]
		if float(p["min_m"]) < INF:
			print("PATH engste Stelle  %-36s %6.1f m  nach %4.0f m Weg  km %6.1f" % [p["name"], float(p["min_m"]), float(p["min_sep_m"]), float(p["min_km"])])
	var crossing := 0
	for p: Dictionary in loops:
		if float(p["loop_min_m"]) < 30.0:
			crossing += 1
	print("PATH Schleifen (1.100 … 8.000 m Weg auseinander, Punkte alle 24 m): %d Etappenrichtungen unter 300 m, %d kreuzen sich (< 30 m)" % [loops.size(), crossing])
	for i in mini(12 if verbose or full else 3, loops.size()):
		var p: Dictionary = loops[i]
		print("PATH Schleife        %-36s %6.1f m  nach %5.0f m Weg  km %6.1f" % [p["name"], float(p["loop_min_m"]), float(p["loop_min_sep_m"]), float(p["loop_min_km"])])
	if full:
		# only with every stage direction computed: the normal run leaves out the long, gentle ones
		print("PATH größte Koordinate eines Pfads ab seinem Start: %.1f km (%s) – 32-Bit-Raster dort %.1f mm ohne schwimmenden Ursprung" % [
			far_m / 1000.0, far_name, pow(2.0, floorf(log(maxf(far_m, 1.0)) / log(2.0)) - 23.0) * 1000.0])
		_print_ribbon(ribbons)
	var worst: Dictionary = rows[0] if not rows.is_empty() else {}
	var min_m := float(worst.get("min_m", INF))
	var checked := not dirs.is_empty() and (not rows.is_empty() or proven == dirs.size())
	var ok_clear := checked and min_m >= MIN_CLEAR_M and bound_broken.is_empty()
	var ok_loops := checked and loop_sep >= LOOP_MIN_SEP_M and bound_broken.is_empty()
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	print("CHECK modern_path_clearance %s kleinster Abstand %s (%s, km %.1f, %.0f m Weg) – verlangt >= %.0f m bei %.0f … %.0f m Weg; %d Etappenrichtungen" % [
		"OK    " if ok_clear else "FEHLER", ("%.1f m" % min_m) if min_m < INF else ">= 300 m", worst.get("name", "–"), float(worst.get("min_km", 0.0)),
		float(worst.get("min_sep_m", 0.0)), MIN_CLEAR_M, SEP_MIN_M, SEP_MAX_M, dirs.size()])
	print("CHECK modern_path_loops     %s Annäherung unter %.0f m jenseits von %.0f m Weg frühestens nach %s%s – verlangt >= %.0f m (%.0f s)" % [
		"OK    " if ok_loops else "FEHLER", MIN_CLEAR_M, SEP_MAX_M, ("%.0f m Weg" % loop_sep) if loop_sep < INF else "keine",
		(" (%s)" % loop_name) if loop_sep < INF else "", LOOP_MIN_SEP_M, secs])
	quit(0 if ok_clear and ok_loops else 1)


func _print_ribbon(ribbons: Array) -> void:
	var sides := 0
	var free := {}
	var min_clear := INF
	var min_name := ""
	var chunks_max := 0
	var chunks_name := ""
	var cap_hits := 0
	var cap_nearest := INF
	var positions := 0
	for rb: Dictionary in ribbons:
		sides += int(rb["sides"])
		for w: float in (rb["free"] as Dictionary):
			free[w] = int(free.get(w, 0)) + int(rb["free"][w])
		if float(rb["min_clear_m"]) < min_clear:
			min_clear = float(rb["min_clear_m"])
			min_name = str(rb["name"])
		if int(rb["chunks_max"]) > chunks_max:
			chunks_max = int(rb["chunks_max"])
			chunks_name = str(rb["name"])
		cap_hits += int(rb["cap_hits"])
		cap_nearest = minf(cap_nearest, float(rb["cap_nearest_m"]))
		positions += int(rb["positions"])
	print("RIBBON %d Querschnittsseiten (alle 24 m), freie Breite bis zur Mittelachse zu einem anderen Straßenteil:" % sides)
	var widths := free.keys()
	widths.sort()
	for w: float in widths:
		print("RIBBON   >= %3.0f m frei: %6.2f %% der Seiten (nicht: %d = %.1f km Straßenseite)" % [w, 100.0 * float(free[w]) / maxf(1.0, float(sides)),
			sides - int(free[w]), float(sides - int(free[w])) * 24.0 / 1000.0])
	print("RIBBON   kleinste freie Breite %.1f m (%s)" % [min_clear, min_name])
	print("CHUNKS Laderegel bei 900 m Sicht, Kamera alle 96 m (%d Positionen): höchstens %d Stücke gewünscht (%s); über der Grenze von %d (graphics.modern.max_chunks): %d Positionen%s" % [
		positions, chunks_max, chunks_name, int(ConfigLoader.lookup(ConfigLoader.load_merged(), "graphics.modern.max_chunks", 16)), cap_hits, (", nächstes ausgelassenes Stück %.0f m Luftlinie" % cap_nearest) if cap_nearest < INF else ""])
