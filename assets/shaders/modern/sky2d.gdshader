// Modern (v0.8.0, package R7d "Freie Strecke", contract A-27): the SKY of the canvas backdrop – drawn behind the
// silhouettes, skylines and landmarks of layers/backdrop.gd (they stay as they were), in Modern only; Arcade keeps
// RaceBackdrop.draw_sky. German docs: docs/renderer-modern.md §20.
//
// What Arcade draws, at Arcade's places (RaceBackdrop.draw_sky, values passed by backdrop.gd): the palette's gradient
// (sky_top → sky_mid at 0.52 of the horizon row → sky_bottom), the dawn and dusk glow around the sun's azimuth, the
// stars (twinkling), the moon with its crescent and the sun disc with its halo, the darker top under a closed deck –
// and instead of Arcade's 16 cloud sprites and the overcast ellipses the CLOUD LAYER of clouds2d.gdshader, drawn at
// half resolution into a viewport of its own (premultiplied colour and coverage) and laid over all of it: clouds hide
// the stars, the moon and, where thick, the sun.
// Everything is a function of the uniforms – view time and the positions of the simulation, never TIME (Rule 10).
// Colours are display values (the canvas draws without conversion, like Arcade's GeoBatch).
// Canvas pixels: v_pos = canvas-local position (x 0 … screen.x, the backdrop's projection with its margins; y rows).
shader_type canvas_item;
render_mode unshaded;

uniform vec2 screen = vec2(1376.0, 720.0);      // backdrop projection: logical picture + margins
uniform float horizon_y = 324.0;                // row of the infinitely distant ground
uniform float focal = 711.0;                    // pixels per radian
uniform float pan = 0.0;                        // Arcade's panorama angle of the screen centre (stars)
uniform float time = 0.0;                       // view time (s)
uniform vec4 sky_top = vec4(0.11, 0.36, 0.79, 1.0);
uniform vec4 sky_mid = vec4(0.4, 0.62, 0.9, 1.0);
uniform vec4 sky_bottom = vec4(0.73, 0.87, 0.96, 1.0);
uniform vec4 glow = vec4(0.0);                  // rgb, a = strength (Arcade's "glow")
uniform vec3 sun = vec3(1.0, 0.97, 0.89);       // the sun's colour
uniform vec3 sun_disc = vec3(0.0, -1000.0, 0.0);  // x, y of the disc (canvas px), z = 1 visible
uniform vec3 moon_disc = vec3(0.0, -1000.0, 0.0); // x, y of the moon, z = 1 visible
uniform float stars = 0.0;
uniform vec4 cloud_shade = vec4(0.79, 0.83, 0.89, 1.0);  // palette "cloud_dark" (the closed deck's top)
uniform float overcast = 0.0;                   // palette "overcast" (rain, snow)
uniform sampler2D clouds : filter_linear;       // the cloud layer (clouds2d.gdshader): premultiplied rgb, coverage
uniform vec4 clouds_rect = vec4(0.0, -48.0, 1376.0, 816.0);  // canvas rectangle the cloud viewport covers
uniform float clouds_on = 0.0;                  // 1 once the cloud viewport exists

varying vec2 v_pos;

void vertex() {
	v_pos = VERTEX;
}

// Arcade's GeoBatch.ellipse: the centre colour fading linearly to the rim
float ce_ellipse(vec2 p, vec2 c, vec2 r) {
	return clamp(1.0 - length((p - c) / r), 0.0, 1.0);
}

float ce_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = v_pos;
	float hy = horizon_y;
	float my = hy * 0.52;
	// Arcade's gradient
	vec3 c = p.y < my ? mix(sky_top.rgb, sky_mid.rgb, clamp((p.y + 40.0) / (my + 40.0), 0.0, 1.0))
		: mix(sky_mid.rgb, sky_bottom.rgb, clamp((p.y - my) / (hy + 3.0 - my), 0.0, 1.0));
	// stars (Arcade: 260 of them, more of them high up, twinkling): one candidate in each cell of the panorama
	if (stars > 0.02 && p.y < hy) {
		float az = pan + (p.x - screen.x * 0.5) / focal;
		vec2 cell = vec2(floor(az / 0.03), floor(p.y / 20.0));
		float hsh = ce_hash(cell);
		if (hsh < 0.085 * (1.4 - p.y / hy)) {
			vec2 at = vec2((cell.x + ce_hash(cell + 3.1)) * 0.03, (cell.y + ce_hash(cell + 7.7)) * 20.0);
			float sz = 0.7 + 1.4 * ce_hash(cell + 11.3);
			float dx = abs(az - at.x) * focal;
			float dy = abs(p.y - at.y);
			if (dx < sz * 0.5 + 0.5 && dy < sz * 0.5 + 0.5) {
				float tw = 0.65 + 0.35 * sin(time * (1.3 + sz) + at.x * 17.0);
				float a = stars * tw * clamp((hy - p.y) / (hy * 0.3), 0.15, 1.0);
				c = mix(c, vec3(1.0, 1.0, 0.95), a);
			}
		}
	}
	// dawn / dusk glow around the sun's azimuth (Arcade: an ellipse on the horizon and a band above it)
	if (glow.a > 0.02) {
		c = mix(c, glow.rgb, glow.a * 0.85 * ce_ellipse(p, vec2(sun_disc.x, hy), vec2(screen.x * 0.55, hy * 0.75)));
		c = mix(c, glow.rgb, glow.a * 0.45 * clamp((p.y - (hy - 70.0)) / 72.0, 0.0, 1.0) * step(p.y, hy + 2.0));
	}
	// the moon: halo, disc, the crescent cut by a disc of the sky
	if (moon_disc.z > 0.5) {
		c = mix(c, vec3(0.75, 0.8, 1.0), 0.12 * ce_ellipse(p, moon_disc.xy, vec2(60.0)));
		float d = length(p - moon_disc.xy);
		if (d < 15.0) {
			c = mix(vec3(0.933, 0.941, 1.0), vec3(0.875, 0.89, 0.961), d / 15.0);
		}
		if (length(p - moon_disc.xy - vec2(6.0, -4.0)) < 13.0) {
			c = mix(sky_top.rgb, sky_mid.rgb, 0.3);
		}
	}
	// the sun: halo, glow, disc
	if (sun_disc.z > 0.5) {
		c = mix(c, sun, 0.22 * ce_ellipse(p, sun_disc.xy, vec2(110.0)));
		c = mix(c, sun, 0.45 * ce_ellipse(p, sun_disc.xy, vec2(44.0)));
		float d = length(p - sun_disc.xy);
		if (d < 22.0) {
			c = mix(vec3(1.0, 1.0, 0.97), sun, d / 22.0);
		}
	}
	// a closed deck is thicker overhead (Arcade: a darker band at the top under overcast)
	c = mix(c, cloud_shade.rgb, 0.75 * overcast * clamp(1.0 - (p.y + 40.0) / (hy * 0.65 + 40.0), 0.0, 1.0));
	// the cloud layer (clouds2d.gdshader, half resolution)
	if (clouds_on > 0.5) {
		vec4 cl = texture(clouds, (p - clouds_rect.xy) / clouds_rect.zw);
		c = c * (1.0 - cl.a) + cl.rgb;
	}
	COLOR = vec4(c, 1.0);
}
