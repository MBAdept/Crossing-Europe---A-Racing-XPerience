class_name Palette
extends RefCounted
## Colours for sky, ground, road and lighting by time of day, weather and tunnel.
## Ground colours (grass, asphalt, props) are defined for daylight and multiplied with "ambient";
## sky colours are absolute. compute() interpolates between four key frames (night, dawn, day, dusk)
## using the hours of config "daytime" and then applies the weather (rain: grey overcast, wet road;
## snow: light grey overcast, white ground).
##
## Keys of the returned dictionary:
##   sky_top, sky_mid, sky_bottom (Color)  sky gradient (zenith, middle, horizon)
##   glow (Color, alpha = strength)         warm horizon glow around the sun (dawn/dusk)
##   fog (Color)                            colour distant things fade into
##   ambient (Color)                        light multiplier for everything lit by the sun/sky
##   lights (0..1)                          vehicle/street lights on (night amount)
##   stars (0..1), night (0..1), overcast (0..1), wet (0/1), snow (0/1)
##   sun (Color), sun_visible (bool), sun_pos (Vector2: x = azimuth -1..1, y = elevation 0..1)
##   moon_visible (bool), moon_pos (Vector2, same convention), cloud (Color), cloud_dark (Color)
##   tunnel (bool)                          true for the tunnel variant (see tunnel())
## Owner: race module.

const KEYS := {
	"night": {
		"sky_top": Color("02040b"), "sky_mid": Color("08112a"), "sky_bottom": Color("1a2645"),
		"glow": Color(0.25, 0.3, 0.5, 0.0), "fog": Color("0d1426"), "ambient": Color("36435f"),
		"lights": 1.0, "stars": 1.0, "sun": Color("dfe6ff"),
		"cloud": Color("1b2338"), "cloud_dark": Color("101626"),
	},
	"dawn": {
		"sky_top": Color("26346e"), "sky_mid": Color("8a6b9c"), "sky_bottom": Color("ffad78"),
		"glow": Color(1.0, 0.62, 0.35, 0.75), "fog": Color("d9a48f"), "ambient": Color("c9a8a2"),
		"lights": 0.55, "stars": 0.1, "sun": Color("ffd08a"),
		"cloud": Color("f4b49e"), "cloud_dark": Color("8a6a86"),
	},
	"day": {
		"sky_top": Color("1d5bc9"), "sky_mid": Color("4b8de3"), "sky_bottom": Color("b9def5"),
		"glow": Color(1.0, 0.98, 0.9, 0.25), "fog": Color("c6dcee"), "ambient": Color("ffffff"),
		"lights": 0.0, "stars": 0.0, "sun": Color("fff8e2"),
		"cloud": Color("ffffff"), "cloud_dark": Color("c9d4e2"),
	},
	"dusk": {
		"sky_top": Color("1b2158"), "sky_mid": Color("7c4778"), "sky_bottom": Color("ff8648"),
		"glow": Color(1.0, 0.5, 0.25, 0.85), "fog": Color("c7866f"), "ambient": Color("c9958a"),
		"lights": 0.65, "stars": 0.2, "sun": Color("ff9550"),
		"cloud": Color("ff9a78"), "cloud_dark": Color("6e4a72"),
	},
}

const ROAD := Color("56585e")
const ROAD_ALT := Color("5a5c62")
const ROAD_LANDSTRASSE := Color("5f6066")
const ROAD_CITY := Color("4f5156")
const SHOULDER_PAVED := Color("6b6c70")
const SHOULDER := Color("8a8064")          ## gravel/grass verge (Bankett)
const SIDEWALK := Color("a3a19a")
const SIDEWALK_ALT := Color("9a9890")
const CURB := Color("c8c6c0")
const RUMBLE_A := Color("dedede")
const RUMBLE_B := Color("b93430")
const LINE := Color("f2f2ec")
const LINE_YELLOW := Color("f2c02a")
const GUARDRAIL := Color("b8bdc3")
const GRASS_DEFAULT := [Color("5d9a3e"), Color("56913a")]
const SNOW_GROUND := Color("eef2f6")
const TUNNEL_FOG := Color("120d08")
const TUNNEL_AMBIENT := Color("e9b67c")


## Interpolated palette for hour (0..24), weather and tunnel. Returns a Dictionary of Colors/floats.
static func compute(hour: float, weather: String, daytime: Dictionary, in_tunnel: bool = false) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var dawn0 := float(daytime.get("dawn_start", 5.0))
	var rise := float(daytime.get("sunrise", 6.5))
	var day0 := float(daytime.get("day_start", 7.5))
	var dusk0 := float(daytime.get("dusk_start", 18.0))
	var sset := float(daytime.get("sunset", 19.5))
	var night0 := float(daytime.get("night_start", 20.5))
	var frames := [
		[0.0, "night"], [dawn0, "night"], [rise, "dawn"], [day0 + 0.75, "day"],
		[dusk0, "day"], [sset, "dusk"], [night0 + 0.5, "night"], [24.0, "night"],
	]
	var a: Dictionary = KEYS["night"]
	var b: Dictionary = KEYS["night"]
	var t := 0.0
	for i in range(frames.size() - 1):
		var h0: float = frames[i][0]
		var h1: float = frames[i + 1][0]
		if h >= h0 and h <= h1:
			a = KEYS[frames[i][1]]
			b = KEYS[frames[i + 1][1]]
			t = 0.0 if h1 <= h0 else smoothstep(0.0, 1.0, (h - h0) / (h1 - h0))
			break
	var p := {}
	for k in a:
		if a[k] is Color:
			p[k] = (a[k] as Color).lerp(b[k], t)
		else:
			p[k] = lerpf(float(a[k]), float(b[k]), t)
	# Sun: rises at sunrise on the left, highest at midday, sets at sunset on the right.
	var sun_t := (h - rise) / maxf(0.1, sset - rise)
	p["sun_visible"] = sun_t > -0.04 and sun_t < 1.04
	p["sun_pos"] = Vector2(lerpf(-0.75, 0.75, clampf(sun_t, 0.0, 1.0)), maxf(0.0, sin(clampf(sun_t, 0.0, 1.0) * PI)))
	# Moon: the opposite arc during the night.
	var night_len := 24.0 - (sset - rise)
	var moon_t := fposmod(h - sset, 24.0) / maxf(0.1, night_len)
	p["moon_visible"] = moon_t > 0.02 and moon_t < 0.98 and float(p["stars"]) > 0.3
	p["moon_pos"] = Vector2(lerpf(-0.6, 0.6, clampf(moon_t, 0.0, 1.0)), maxf(0.0, sin(clampf(moon_t, 0.0, 1.0) * PI)) * 0.8)
	p["night"] = float(p["stars"])
	p["overcast"] = 0.0
	p["wet"] = 0.0
	p["snow"] = 0.0
	p["tunnel"] = false
	var light := luminance(p["ambient"])
	match weather:
		"rain":
			var g := Color("6c7580") * (0.25 + 0.75 * light)
			p["sky_top"] = (p["sky_top"] as Color).lerp(Color("4a525c") * (0.2 + 0.8 * light), 0.85)
			p["sky_mid"] = (p["sky_mid"] as Color).lerp(g, 0.85)
			p["sky_bottom"] = (p["sky_bottom"] as Color).lerp(Color("8f99a3") * (0.25 + 0.75 * light), 0.85)
			p["fog"] = (p["fog"] as Color).lerp(Color("8a939c") * (0.2 + 0.8 * light), 0.85)
			p["ambient"] = (p["ambient"] as Color).darkened(0.2)
			p["cloud"] = Color("7d8590") * (0.25 + 0.75 * light)
			p["cloud_dark"] = Color("525a66") * (0.25 + 0.75 * light)
			var gr: Color = p["glow"]
			p["glow"] = Color(gr, gr.a * 0.15)
			p["stars"] = 0.0
			p["sun_visible"] = false
			p["moon_visible"] = false
			p["overcast"] = 1.0
			p["wet"] = 1.0
		"snow":
			p["sky_top"] = (p["sky_top"] as Color).lerp(Color("a5adb8") * (0.2 + 0.8 * light), 0.85)
			p["sky_mid"] = (p["sky_mid"] as Color).lerp(Color("c3c9d1") * (0.2 + 0.8 * light), 0.85)
			p["sky_bottom"] = (p["sky_bottom"] as Color).lerp(Color("dfe4ea") * (0.2 + 0.8 * light), 0.85)
			p["fog"] = (p["fog"] as Color).lerp(Color("d8dee5") * (0.2 + 0.8 * light), 0.88)
			p["ambient"] = (p["ambient"] as Color).darkened(0.04)
			p["cloud"] = Color("d5dae0") * (0.2 + 0.8 * light)
			p["cloud_dark"] = Color("a9b0ba") * (0.2 + 0.8 * light)
			var gs: Color = p["glow"]
			p["glow"] = Color(gs, gs.a * 0.1)
			p["stars"] = 0.0
			p["sun_visible"] = false
			p["moon_visible"] = false
			p["overcast"] = 1.0
			p["snow"] = 1.0
	if in_tunnel:
		return tunnel(p)
	return p


## Tunnel variant of a palette: warm artificial light, dark fog, lights on, no sky elements.
static func tunnel(p: Dictionary) -> Dictionary:
	var q := p.duplicate()
	q["ambient"] = TUNNEL_AMBIENT
	q["fog"] = TUNNEL_FOG
	q["lights"] = 1.0
	q["stars"] = 0.0
	q["sun_visible"] = false
	q["moon_visible"] = false
	q["snow"] = 0.0
	q["wet"] = 0.0
	q["tunnel"] = true
	return q


## Perceived brightness (0..1) of a colour.
static func luminance(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


## Ground colour (grass etc.) under the palette's lighting and weather.
static func ground(base: Color, p: Dictionary) -> Color:
	var c := base
	if float(p.get("snow", 0.0)) > 0.0:
		c = c.lerp(SNOW_GROUND, 0.85 * float(p["snow"]))
	return c * (p["ambient"] as Color)


## Asphalt colour under the palette's lighting and weather (wet = darker, snow = lighter grey).
static func road(base: Color, p: Dictionary) -> Color:
	var c := base
	if float(p.get("wet", 0.0)) > 0.0:
		c = c.darkened(0.32 * float(p["wet"]))
	if float(p.get("snow", 0.0)) > 0.0:
		c = c.lerp(Color("8f949b"), 0.3 * float(p["snow"]))
	return c * (p["ambient"] as Color)


## Colour of a lit object (sprite modulate): ambient plus extra light (headlights, lamps).
static func lit(p: Dictionary, extra: float) -> Color:
	var a: Color = p["ambient"]
	return Color(minf(1.0, a.r + extra), minf(1.0, a.g + extra * 0.97), minf(1.0, a.b + extra * 0.85), 1.0)
