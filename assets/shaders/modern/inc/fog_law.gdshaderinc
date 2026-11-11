// Modern: Arcade's fog of everything that stands in the landscape (FIX1 after the QA of M1, finding QB-07).
// Arcade tints a sprite – a car, a tree, a sign, a house – with RoadRenderer._modulate (frozen): its colour goes
// towards the sprite's own colour times the brightened fog colour (× 1.25) by 0.7 × the fog amount t of its distance
// (t = 0 at the fog begin, 1 at the end of the sight), and it fades out by its alpha (the F5 dither of Modern). A dark
// car stays dark; nothing turns into pure fog colour. The engine's depth fog mixes towards the plain fog colour by the
// whole of t: far trees stood as grey-blue "ghost trees" on green fields (S1: 129/137/145 against Arcade's 26/37/19)
// and a car at 0.839 × the sight kept only about 30 % of Arcade's contrast. Terrain and far ground have used this law
// since RINT-B (terrain.gdshader, far_ground.gdshader); with it every scenery and vehicle material has the same one –
// never more fog than Arcade (F4).
// Use in fragment(): FOG = ce_arcade_fog(<display albedo>, length(VERTEX), ce_fog_color, ce_fog_range);
// FOG replaces the engine's depth fog for the material and is mixed in linear light (measured by RINT-B with
// m1/RINT-B/probe/fog_probe.gd). The including shader declares the globals ce_fog_color and ce_fog_range.

// display value -> linear value (exact sRGB curve; 0 stays 0)
vec3 ce_fog_unshow(vec3 d) {
	vec3 x = pow((max(d, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	return x * step(vec3(1.0e-6), d);
}

// Fog amount 0..1 of a distance: linear from the fog begin to the end of the sight (ce_fog_range).
float ce_fog_amount(float dist, vec2 fog_range) {
	return clamp((dist - fog_range.x) / max(fog_range.y - fog_range.x, 1.0), 0.0, 1.0);
}

// The FOG value of Arcade's law for a surface of display albedo `albedo` at camera distance `dist`.
vec4 ce_arcade_fog(vec3 albedo, float dist, vec4 fog_color, vec2 fog_range) {
	vec3 tinted = min(albedo * fog_color.rgb * 1.25, vec3(1.0));
	return vec4(ce_fog_unshow(tinted), 0.7 * ce_fog_amount(dist, fog_range));
}
