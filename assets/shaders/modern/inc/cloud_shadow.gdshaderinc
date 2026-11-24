// Modern (v0.8.0, package R7d "Freie Strecke", contract A-27): CLOUD SHADOWS – the shadow of CloudField's layer on
// the land, from the same field the sky draws (layers/backdrop.gd sets the globals every frame). German docs:
// docs/renderer-modern.md §20.
//
// Use:   #include "res://assets/shaders/modern/inc/cloud_shadow.gdshaderinc"
//        float k = ce_cloud_shade(world_pos, ce_sun_dir);        // display factor 1 (in the sun) … 1 − strength
// The point's ray towards the light meets the cloud layer at height ce_cloud_pos.w; the field's density there (its
// domes, billows and groups) gives the shadow, with a wider edge than the
// cloud in the sky. strength (ce_cloud.z) is 0 at night, under a closed deck (rain, snow: diffuse light), inside a
// tunnel and with the sky shader off – a factor of 1 then, nothing changes.
// Who takes it: the terrain ribbon, the far ground, the road (at most ROAD_MAX, the paint with the asphalt, so the
// marking contrast stays), the scenery props. Never vehicles, signs, lamps, glows (contract A-27, Rule 9).
// Needs the global ce_sun_dir (declared by inc/ground_law.gdshaderinc – a shader without that include declares it
// itself before including this file and defines CE_CLOUD_OWN_SUN). Names start with ce_cloud.
global uniform sampler2D ce_cloud_tex : filter_linear_mipmap, repeat_enable;
global uniform vec4 ce_cloud;       // x threshold of n, y soft edge, z strength (display factor taken at full density)
global uniform vec4 ce_cloud_pos;   // xy field position of the origin-relative point (0, 0), z TILE_M, w HEIGHT_M

const vec3 CE_CLOUD_W = vec3(0.55, 0.18, 0.27);      // CloudField.W
const vec2 CE_CLOUD_DETAIL = vec2(2.3, 0.37);        // CloudField.DETAIL (billows, groups)

// Density of the cloud layer above an origin-relative world position, seen along the light (0 … 1).
float ce_cloud_density(vec3 world, vec3 to_sun) {
	vec3 l = normalize(to_sun);
	vec2 hit = world.xz + l.xz / max(l.y, 0.2) * ce_cloud_pos.w;
	vec2 q = (hit + ce_cloud_pos.xy) / ce_cloud_pos.z;
	float n = CE_CLOUD_W.x * texture(ce_cloud_tex, q).r + CE_CLOUD_W.y * texture(ce_cloud_tex, q * CE_CLOUD_DETAIL.x).g
		+ CE_CLOUD_W.z * texture(ce_cloud_tex, q * CE_CLOUD_DETAIL.y).b;
	return smoothstep(ce_cloud.x - ce_cloud.y * 2.0, ce_cloud.x + ce_cloud.y * 3.0, n);
}

// Display factor of the light at a point: 1 in the sun, 1 − strength under a thick cloud.
float ce_cloud_shade(vec3 world, vec3 to_sun) {
	if (ce_cloud.z <= 0.0) {
		return 1.0;
	}
	return 1.0 - ce_cloud.z * ce_cloud_density(world, to_sun);
}

// Factor for the DIRECT light of a prop (its own light() multiplies the directional light by it, the ambient part
// stays): CE_CLOUD_PROP_K × the ground's display strength taken from the sun, from the object's origin – one value per
// object, in the vertex stage (textureLod: no derivatives there).
const float CE_CLOUD_PROP_K = 2.3;
float ce_cloud_sun_v(vec3 world, vec3 to_sun) {
	if (ce_cloud.z <= 0.0) {
		return 1.0;
	}
	vec3 l = normalize(to_sun);
	vec2 hit = world.xz + l.xz / max(l.y, 0.2) * ce_cloud_pos.w;
	vec2 q = (hit + ce_cloud_pos.xy) / ce_cloud_pos.z;
	float n = CE_CLOUD_W.x * textureLod(ce_cloud_tex, q, 0.0).r + CE_CLOUD_W.y * textureLod(ce_cloud_tex, q * CE_CLOUD_DETAIL.x, 0.0).g
		+ CE_CLOUD_W.z * textureLod(ce_cloud_tex, q * CE_CLOUD_DETAIL.y, 0.0).b;
	float dens = smoothstep(ce_cloud.x - ce_cloud.y * 2.0, ce_cloud.x + ce_cloud.y * 3.0, n);
	return clamp(1.0 - CE_CLOUD_PROP_K * ce_cloud.z * dens, 0.2, 1.0);
}

