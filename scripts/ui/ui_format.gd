class_name UiFormat
extends RefCounted
## Text formatting for menus and HUD: German number style (decimal comma), times, deltas,
## weather/daytime names, the record marquee. Pure functions (no autoloads) – unit tested.

const WEATHER_IDS: Array[String] = ["normal", "rain", "snow"]
const DAYTIME_IDS: Array[String] = ["day", "dawn", "dusk", "night"]


## Translation in static context (gettext style: the German text is the key).
static func t(s: String) -> String:
	return String(TranslationServer.translate(s))


## Race/stage time ("m:ss.cc", "h:mm:ss.c"), "--:--.--" for invalid values.
static func time(seconds: float) -> String:
	return Units.format_race_time(seconds)


## Signed time difference: "+0:02.31" / "-0:01.10".
static func delta(seconds: float) -> String:
	if is_nan(seconds) or is_inf(seconds):
		return "--:--.--"
	return ("+" if seconds >= 0.0 else "-") + Units.format_race_time(absf(seconds))


## Compact signed difference for the HUD: "+2.31" below one minute, else like delta().
static func delta_short(seconds: float) -> String:
	if is_nan(seconds) or is_inf(seconds):
		return "--"
	var a := absf(seconds)
	var sgn := "+" if seconds >= 0.0 else "-"
	if a < 60.0:
		return sgn + ("%.2f" % a)
	return sgn + Units.format_race_time(a)


## German decimal: 12.5 -> "12,5". Thousands separated with a dot for integers >= 10000.
static func decimal(v: float, digits: int = 1) -> String:
	if digits <= 0:
		return grouped(roundi(v))
	var s := ("%." + str(digits) + "f") % v
	var parts := s.split(".")
	var int_part := int(parts[0])
	var head := grouped(int_part)
	if s.begins_with("-") and int_part == 0:
		head = "-0"
	return head + "," + parts[1]


## Integer with German thousands separator: 11250 -> "11.250" (4-digit numbers stay unseparated).
static func grouped(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	if s.length() >= 5:
		var out := ""
		var n := s.length()
		for i in n:
			out += s[i]
			var rest := n - i - 1
			if rest > 0 and rest % 3 == 0:
				out += "."
		s = out
	return ("-" if neg else "") + s


static func km(v: float, digits: int = 0) -> String:
	return decimal(v, digits) + " km"


static func kmh(v: float) -> String:
	return "%d km/h" % roundi(v)


static func liters(v: float) -> String:
	return "%d L" % roundi(v)


## "HH:MM" for an hour of the day (8.5 -> "08:30").
static func clock_hour(hour: float) -> String:
	return Units.format_clock(hour * 60.0)


## All selectable start times (minutes of the day) for a step in minutes: 0, 30, …, 1410.
static func start_time_steps(step_minutes: int = 30) -> Array[int]:
	var out: Array[int] = []
	var step := maxi(step_minutes, 1)
	var m := 0
	while m < 1440:
		out.append(m)
		m += step
	return out


static func weather_name(w: String) -> String:
	match w:
		"rain":
			return t("Regen")
		"snow":
			return t("Schnee")
	return t("Klar")


static func daytime_name(cat: String) -> String:
	match cat:
		"night":
			return t("Nacht")
		"dawn":
			return t("Morgendämmerung")
		"dusk":
			return t("Abenddämmerung")
	return t("Tag")


## Traffic factor (StagePlan.summary().traffic) as a word.
static func traffic_level(f: float) -> String:
	if f < 0.9:
		return t("gering")
	if f < 1.15:
		return t("mittel")
	if f < 1.45:
		return t("hoch")
	return t("sehr hoch")


## Vehicle display name from the configuration.
static func vehicle_name(vehicle_id: String, config: Dictionary) -> String:
	if vehicle_id == "" or vehicle_id == "all":
		return t("Alle Fahrzeuge")
	var types: Dictionary = ConfigLoader.lookup(config, "vehicles.types", {})
	var v: Dictionary = types.get(vehicle_id, {})
	return str(v.get("name", vehicle_id.capitalize()))


## "2026-10-30" -> "30.10.2026"; other strings unchanged.
static func date_de(iso: String) -> String:
	var p := iso.substr(0, 10).split("-")
	if p.size() != 3:
		return iso
	return "%s.%s.%s" % [p[2], p[1], p[0]]


## Record marquee (Laufschrift) text: name, time, average speed (+ vehicle).
static func marquee_text(record: Dictionary, stage_name: String, config: Dictionary = {}) -> String:
	var sep := "  +++  "
	if record.is_empty():
		return t("%s – noch kein Rekord. Fahr die erste Bestzeit!") % stage_name
	var parts: Array[String] = []
	parts.append(t("REKORD %s") % stage_name)
	parts.append(str(record.get("name", "?")))
	parts.append(time(float(record.get("time_s", -1.0))))
	parts.append(t("Ø %s") % kmh(float(record.get("avg_kmh", 0.0))))
	var veh := str(record.get("vehicle", ""))
	if veh != "":
		parts.append(vehicle_name(veh, config))
	var d := str(record.get("date", ""))
	if d != "":
		parts.append(date_de(d))
	return sep.join(parts)


## "1." rank label.
static func rank(r: int) -> String:
	return "%d." % r


## Pace delta during a stage: actual time minus the record time scaled to the covered share.
static func pace_delta(stage_time_s: float, record_time_s: float, stage_km: float, length_km: float) -> float:
	if record_time_s <= 0.0 or length_km <= 0.0:
		return NAN
	var share := clampf(stage_km / length_km, 0.0, 1.0)
	return stage_time_s - record_time_s * share


## Country codes in order as "DE › NL › BE".
static func countries_chain(codes: Array) -> String:
	var parts: Array[String] = []
	for c in codes:
		parts.append(str(c))
	return " › ".join(parts)
