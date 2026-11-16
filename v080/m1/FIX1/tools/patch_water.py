import sys
wt = sys.argv[1]
# --- terrain.gd: Arcade's water colour of the bridge (RoadRenderer._water_base)
p = wt + '/scripts/race3d/builders/terrain.gd'
s = open(p, encoding='utf-8').read()
pairs = [
('''	var styles: Variant = ConfigLoader.lookup(ctx.cfg, "graphics.modern.terrain.styles", {})
	return {"city": GroundLook.city_info(ctx.track),
		"band": maxi(1, int(ConfigLoader.lookup(ctx.cfg, "render.stripes.grass", 4))),
		"styles": styles if styles is Dictionary else {}}''',
 '''	var styles: Variant = ConfigLoader.lookup(ctx.cfg, "graphics.modern.terrain.styles", {})
	# FIX1 (QA QB-03: dark water under the Köhlbrand bridge): Arcade's water colour of a bridge (RoadRenderer.
	# _water_base, frozen) – the bridge's own "water", else the scenery's, else the default of its type
	var waters := {}
	for seg: Dictionary in ctx.segs:
		if not bool(seg["water"]):
			continue
		var bi := int(seg["bridge_i"])
		var key := "%d|%s" % [bi, str(seg["scenery"])]
		if waters.has(key):
			continue
		var c := ""
		if ctx.track != null and bi >= 0 and bi < ctx.track.bridges.size():
			c = str(ctx.track.bridges[bi].get("water", ""))
		if c == "":
			c = str(_dict(ctx.scenery_db.get(str(seg["scenery"]))).get("water", ""))
		if c == "":
			c = str(CityData.WATER_COLOR.get(str(seg["bridge"]), "#4b6878"))
		waters[key] = Color(c)
	return {"city": GroundLook.city_info(ctx.track),
		"band": maxi(1, int(ConfigLoader.lookup(ctx.cfg, "render.stripes.grass", 4))),
		"styles": styles if styles is Dictionary else {}, "waters": waters}'''),
('''	var overrides: Dictionary = inp.get("styles", {})''', '''	var overrides: Dictionary = inp.get("styles", {})
	var waters: Dictionary = inp.get("waters", {})'''),
('''		if water:
			water_rows += 1
			mean = cached[2]''', '''		if water:
			water_rows += 1
			mean = waters.get("%d|%s" % [int(seg["bridge_i"]), scen_id], cached[2])'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)

# --- terrain.gdshader: the water mirrors the sky towards the horizon (RoadRenderer.water_tint)
p = wt + '/assets/shaders/modern/terrain.gdshader'
s = open(p, encoding='utf-8').read()
pairs = [
('''//   water             (bridges) a smooth surface in the water colour of the scenery''',
 '''//   water             (bridges) a smooth surface in the water colour of the bridge (or the scenery) that mirrors
//                     the sky towards the horizon: Arcade's water_tint, 16 % near, up to 70 % at 324 m (FIX1)'''),
('''	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);
	EMISSION = ce_pools_encode(ce_ground_base_lin(ALBEDO) + ce_pools_to_lin(ALBEDO) * extra);''',
 '''	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);
	// the water mirrors the sky (RoadRenderer.water_tint: the lit water towards sky_bottom by 0.16 + d / 600, at most
	// 0.7; the fog colour stands in for the palette's sky_bottom): its own light falls by that share
	float mirror = clamp(0.16 + dist / 600.0, 0.16, 0.7) * water;
	ALBEDO *= 1.0 - mirror;
	EMISSION = ce_pools_encode(ce_ground_base_lin(ALBEDO) + ce_pools_to_lin(ALBEDO) * extra
		+ ce_ground_unshow(ce_fog_color.rgb) * mirror);'''),
]
for old, new in pairs:
    assert s.count(old) == 1, old[:80]
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
print('ok')
