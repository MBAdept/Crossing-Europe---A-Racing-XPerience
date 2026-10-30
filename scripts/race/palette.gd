class_name Palette
extends RefCounted
## Colours for sky, ground, road and lighting by time of day, weather and tunnel.
## Ground colours are defined for daylight and multiplied with "ambient"; sky colours are absolute.
## Owner: race module.

const KEYS := {
	"night": {
		"sky_top": Color("05070f"), "sky_bottom": Color("15203d"), "fog": Color("0b1020"),
		"ambient": Color("39415a"), "lights": 1.0, "stars": 1.0, "sun": Color("dfe6ff"),
	},
	"dawn": {
		"sky_top": Color("34477d"), "sky_bottom": Color("f4a669"), "fog": Color("d0a38a"),
		"ambient": Color("c7aaa4"), "lights": 0.55, "stars": 0.15, "sun": Color("ffcf8a"),
	},
	"day": {
		"sky_top": Color("2a6ad8"), "sky_bottom": Color("b3daf7"), "fog": Color("c9e0f2"),
		"ambient": Color("ffffff"), "lights": 0.0, "stars": 0.0, "sun": Color("fff6d8"),
	},
	"dusk": {
		"sky_top": Color("272b66"), "sky_bottom": Color("f2773b"), "fog": Color("b8806d"),
		"ambient": Color("c49a8e"), "lights": 0.65, "stars": 0.25, "sun": Color("ff9a52"),
	},
}

const ROAD := Color("5c5e64")
const ROAD_ALT := Color("606268")
const SHOULDER := Color("7b7462")
const RUMBLE_A := Color("dedede")
const RUMBLE_B := Color("b93430")
const LINE := Color("f0f0ea")
const SIDEWALK := Color("9a9890")
const GRASS_DEFAULT := [Color("5d9a3e"), Color("56913a")]


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
			t = 0.0 if h1 <= h0 else (h - h0) / (h1 - h0)
			break
	var p := {}
	for k in a:
		if a[k] is Color:
			p[k] = (a[k] as Color).lerp(b[k], t)
		else:
			p[k] = lerpf(float(a[k]), float(b[k]), t)
	# sun / moon position: x across the screen during the day, y high at noon
	var sun_t := clampf((h - rise) / maxf(0.1, sset - rise), 0.0, 1.0)
	p["sun_visible"] = h > dawn0 and h < night0
	p["sun_pos"] = Vector2(0.15 + 0.7 * sun_t, 0.95 - 0.8 * sin(sun_t * PI))
	p["night"] = float(p["stars"])
	p["wet"] = 0.0
	p["snow"] = 0.0
	match weather:
		"rain":
			p["sky_top"] = (p["sky_top"] as Color).lerp(Color("5d656f") * (p["ambient"] as Color), 0.75)
			p["sky_bottom"] = (p["sky_bottom"] as Color).lerp(Color("9aa3ab") * (p["ambient"] as Color), 0.75)
			p["fog"] = (p["fog"] as Color).lerp(Color("8f989f") * (p["ambient"] as Color), 0.8)
			p["ambient"] = (p["ambient"] as Color).darkened(0.18)
			p["stars"] = 0.0
			p["sun_visible"] = false
			p["wet"] = 1.0
		"snow":
			p["sky_top"] = (p["sky_top"] as Color).lerp(Color("aeb6c0") * (p["ambient"] as Color), 0.8)
			p["sky_bottom"] = (p["sky_bottom"] as Color).lerp(Color("e3e8ee") * (p["ambient"] as Color), 0.8)
			p["fog"] = (p["fog"] as Color).lerp(Color("dde3e9") * (p["ambient"] as Color), 0.85)
			p["ambient"] = (p["ambient"] as Color).darkened(0.05)
			p["stars"] = 0.0
			p["sun_visible"] = false
			p["snow"] = 1.0
	if in_tunnel:
		p["ambient"] = Color("d8a46a")
		p["fog"] = Color("1c140b")
		p["lights"] = 1.0
	return p


## Ground colour (grass etc.) under the palette's lighting and weather.
static func ground(base: Color, p: Dictionary) -> Color:
	var c := base
	if float(p.get("snow", 0.0)) > 0.0:
		c = c.lerp(Color("eef2f6"), 0.82)
	return c * (p["ambient"] as Color)


static func road(base: Color, p: Dictionary) -> Color:
	var c := base
	if float(p.get("wet", 0.0)) > 0.0:
		c = c.darkened(0.28)
	if float(p.get("snow", 0.0)) > 0.0:
		c = c.lerp(Color("9a9ea4"), 0.35)
	return c * (p["ambient"] as Color)
