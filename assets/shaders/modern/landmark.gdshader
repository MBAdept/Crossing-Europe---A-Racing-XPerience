// Modern (v0.8.0, R7b): the landmarks of a stage – drawn by scripts/race3d/builders/landmarks.gd with ARCADE'S
// LANDMARK LAW (RoadRenderer.landmark_fade, frozen) and a SOFT fade (no dither: the translucent variant).
// One file, variants by defines (the builder prepends them, as ModernMaterials does for CE_CUTOUT):
//   CE_PICTURE   the Arcade picture: one cell of the landmark's sprite sheet on an upright quad that turns about
//                its vertical axis to stay parallel to the screen (as billboard.gdshader), unshaded – it repeats
//                the renderer's arithmetic for a picture with baked light (Arcade's law: picture x the light a
//                mid-grey surface gets), its light layer at night laid over it unhazed
//   CE_ATLAS     a landmark MODEL's surface of the classes "baked" / "baked_cutout" (+ CE_CUTOUT): albedo atlas,
//                emission atlas at night – the arithmetic of baked.gdshader, lit by the engine
//   CE_VCOL      untextured geometry, lit: the procedural stand-ins of the builder (the shape of Arcade's
//                procedural landmark in 3D) and "vpbr" surfaces of landmark models. COLOR.rgb albedo (sRGB),
//                UV = (roughness, metallic), UV2 = (channel + 0.5, weight) or (-1, 0):
//                  10 / 11 aviation light (red, blinking at night like Arcade's: 1.5 s, lit 0.75 s)
//                  12      lights at night (COLOR.rgb = the unlit albedo, the light is lights_color)
//                  13      always on (COLOR.rgb lit)
//                  14      flood-lit surface: keeps its albedo and adds albedo x weight x flood_color at night
//                  16      glass facade (builder only): floor bands every 4 m and mullions every 3 m of the model's
//                          own metres, windows lit at random at night (Arcade's skyscrapers: 35 %)
//   CE_GLOW      soft additive glow points (aviation lights, a lighthouse lamp – Arcade's _lm_glow): a quad per
//                point whose four corners share the centre; UV = corner (-1..1), UV2 = (size m, minimum px),
//                COLOR = colour and strength, CUSTOM0 = (mode 0 steady / 1 blink / 2 flash, period s, lit s,
//                phase s); mode 3 = a lighthouse beam (see vertex()); drawn only at night
//   CE_BLEND     the translucent variant (blend_mix): the landmark fades out softly over the last 28 % of its range
//                and keeps only its lit pixels beyond it (B-09: the opaque materials faded with an ordered dither).
//                The builder swaps to it from 0.70 x the range on; nearer the opaque variant draws (shadows, depth).
// Per material (one set per landmark – never an instance uniform, amendment A-19), set every frame:
//   lm_fade = (keep, haze, lights, flood): keep = picture/body alpha 1 - smoothstep(0.72 L, L, d), haze = 0.85 x
//   (d - fog begin) / (L - fog begin), lights = night x (1 - smoothstep(0.8 F, F, d)) with F = render.landmark_far_m,
//   flood = 0.55 x lights for a plain prop standing as a landmark (RoadRenderer.LANDMARK_FLOOD: its picture has no
//   illumination of its own) – all of RoadRenderer._draw_landmark for the distance d of the landmark's anchor.
//   tint = placement tint (x fallback_tint), sRGB multiplier as Arcade multiplies the sprite.
// Load only through the builder (it calls ModernMaterials.ensure_globals() first) – never with preload().
shader_type spatial;
#if defined(CE_PICTURE)
#ifdef CE_BLEND
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;
#else
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
#endif
#elif defined(CE_GLOW)
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
#else
#ifdef CE_BLEND
render_mode cull_back, blend_mix, depth_draw_always;
#elif defined(CE_CUTOUT)
render_mode cull_disabled;
#else
render_mode cull_back;
#endif
#endif

uniform vec4 lm_fade = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec3 tint = vec3(1.0);
uniform vec3 flood_color = vec3(1.0, 0.86, 0.62);     // RoadRenderer.LANDMARK_FLOOD (display value)

#if defined(CE_PICTURE)
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 lights_rect = vec4(0.0);
uniform float shadow_cut = 0.97;                       // PropLibrary.STANDIN_SHADOW_CUT: the baked ground shadow
uniform vec2 sun_k = vec2(0.8, 1.15);                  // PropLibrary.STANDIN_SUN
uniform vec3 headlight_color = vec3(1.0, 0.95, 0.84);
#elif defined(CE_ATLAS)
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emit_tex : source_color, hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float roughness = 0.9;
uniform float emit_energy = 1.6;
uniform vec3 snow_albedo = vec3(0.86, 0.88, 0.91);
uniform float snow_night = 0.3;
#elif defined(CE_VCOL)
uniform vec3 lights_color = vec3(1.0, 0.85, 0.55);     // channel 12 at night (display value)
uniform float lights_energy = 1.4;
uniform vec3 flood_light = vec3(1.0, 0.8, 0.5);        // channel 14: Arcade's floodlight overlay (1.0, 0.8, 0.5)
uniform vec3 window_color = vec3(1.0, 0.88, 0.6);      // channel 16 at night: Arcade's lit office windows
uniform float window_share = 0.35;
uniform vec3 beacon_color = vec3(1.0, 0.12, 0.08);
#elif defined(CE_GLOW)
uniform float viewport_h = 720.0;                       // height of the picture in pixels (set by the builder)
#endif

global uniform float ce_snow;
global uniform float ce_time;
global uniform vec4 ce_fog_color;
global uniform vec2 ce_fog_range;
#if defined(CE_PICTURE)
global uniform vec4 ce_sun_color;
global uniform vec4 ce_ambient;
global uniform vec3 ce_sun_dir;
global uniform vec3 ce_headlight_pos;
global uniform vec3 ce_headlight_dir;
global uniform vec2 ce_headlight;
#endif

#include "res://assets/shaders/modern/inc/fog_law.gdshaderinc"

#if defined(CE_PICTURE)
varying float v_sun;
varying float v_head;
const float REF_GREY = 0.38;
#elif defined(CE_VCOL)
varying vec3 v_obj;
varying vec3 v_onrm;
#elif defined(CE_GLOW)
varying float v_on;
varying float v_beam;
#endif

// the renderer's sRGB -> linear for albedo values
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

// the renderer's linear -> display value at the end of every pass
vec3 show(vec3 x) {
	return max(1.055 * pow(max(x, vec3(0.0)), vec3(0.416666667)) - 0.055, vec3(0.0));
}

// ALBEDO value the renderer turns into the linear value x: inverse of to_lin (two Newton steps)
vec3 albedo_for(vec3 x) {
	vec3 c = pow(max(x, vec3(0.0)), vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

// share of a pixel covered by a periodic band of width w (in periods) at coordinate v: the band itself near the
// camera, its mean w where a period gets smaller than about two pixels
float bands(float v, float w) {
	float fw = fwidth(v);
	return mix(step(fract(v), w), w, clamp(fw * 2.0 - 0.25, 0.0, 1.0));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
#if defined(CE_PICTURE)
	// right vector of the camera, flattened: the picture only turns about the vertical axis
	vec3 cr = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 wp = origin + cr * (VERTEX.x * sx) + vec3(0.0, VERTEX.y * sy, 0.0);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	float facing = dot(normalize(CAMERA_POSITION_WORLD - origin), normalize(ce_sun_dir)) * 0.5 + 0.5;
	// a picture with baked light gets the sun as level ground does, a little less against it, a little more with it
	v_sun = mix(sun_k.x, sun_k.y, facing * facing) * max(normalize(ce_sun_dir).y, 0.0);
	vec3 to = origin + vec3(0.0, 1.5, 0.0) - ce_headlight_pos;
	float d = max(length(to), 0.001);
	float reach = max(1.0 - d / max(ce_headlight.x, 1.0), 0.0);
	v_head = smoothstep(0.80, 0.97, dot(to / d, normalize(ce_headlight_dir))) * reach * reach * ce_headlight.y;
#elif defined(CE_VCOL)
	v_obj = VERTEX;
	v_onrm = NORMAL;
#elif defined(CE_GLOW)
	v_beam = 0.0;
	if (CUSTOM0.x > 2.5) {
		// a lighthouse beam (mode 3): a long flat quad from the lamp, turning about the vertical once in CUSTOM0.y
		// seconds (CUSTOM0.w = its phase), widening along its CUSTOM0.z metres to UV2.x; it faces the camera about
		// its own axis. UV.x = 0 at the lamp .. 1 at the tip, UV.y = -1 .. 1 across.
		float ang = ce_time * 6.2831853 / max(CUSTOM0.y, 0.01) + CUSTOM0.w;
		vec3 dir = normalize(vec3(cos(ang), -0.03, sin(ang)));
		vec3 cam_m = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
		vec3 side = cross(dir, normalize(cam_m - VERTEX));
		side = length(side) > 1.0e-3 ? normalize(side) : vec3(0.0, 1.0, 0.0);
		vec3 p = VERTEX + dir * (UV.x * CUSTOM0.z) + side * (UV.y * (0.4 + UV2.x * UV.x));
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(p, 1.0));
		// brighter while it sweeps across the view than when it points away (Arcade: 0.45 .. 1)
		v_on = mix(0.45, 1.0, 0.5 + 0.5 * dot(dir, normalize(cam_m - VERTEX)));
		v_beam = 1.0;
	} else {
	// a camera-facing quad round the point, at least UV2.y pixels across, pulled towards the camera so that the
	// lamp's own geometry does not cut it
	vec4 c = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float depth = max(-c.z, 0.1);
	// pixels per metre at this depth (viewport_h from the builder: VIEWPORT_SIZE reads 0 in the vertex stage of the
	// Compatibility renderer – the quads covered the whole sky); never more than a few per cent of the depth
	float px_per_m = PROJECTION_MATRIX[1][1] * viewport_h * 0.5 / depth;
	float r = min(max(UV2.x, UV2.y / max(px_per_m, 1.0e-4)), depth * 0.03);
	c.xyz += normalize(-c.xyz) * min(r * 1.5, depth * 0.5);
	c.xy += UV * r;
	POSITION = PROJECTION_MATRIX * c;
	float on = 1.0;
	if (CUSTOM0.x > 0.5 && CUSTOM0.x < 1.5) {
		on = mod(ce_time + CUSTOM0.w, max(CUSTOM0.y, 0.01)) < CUSTOM0.z ? 1.0 : 0.0;
	} else if (CUSTOM0.x > 1.5) {
		// four beams turning once in CUSTOM0.y seconds: a flash whenever one points at the camera (Arcade's lighthouse)
		float turn = mod(ce_time * 6.2831853 / max(CUSTOM0.y, 0.01) + CUSTOM0.w, 1.5707963);
		on = 0.35 + 0.65 * pow(max(cos(turn - 0.785398), 0.0), 24.0);
	}
	v_on = on;
	}
#endif
}

void fragment() {
	float keep = clamp(lm_fade.x, 0.0, 1.0);
	float haze = clamp(lm_fade.y, 0.0, 0.85);
	float lights = clamp(lm_fade.z, 0.0, 1.0);
	float flood = clamp(lm_fade.w, 0.0, 1.0);
#if defined(CE_PICTURE)
	vec4 t = texture(tex, uv_rect.xy + UV * uv_rect.zw);
	vec4 l = lights_rect.z > 0.0 ? texture(tex, lights_rect.xy + UV * lights_rect.zw) : vec4(0.0);
	float la = clamp(l.a * lights, 0.0, 1.0);
	// the dark, half-transparent ground shadow baked into the Arcade sprites stays out (a real ground is under it)
	bool shadow_px = t.a < shadow_cut && max(t.r, max(t.g, t.b)) < 0.1;
#ifdef CE_BLEND
	float ba = shadow_px ? 0.0 : t.a * keep;
	float a_out = la + (1.0 - la) * ba;
	if (a_out < 0.004) {
		discard;
	}
#else
	bool base_px = t.a >= 0.5 && !shadow_px;
	if (!base_px && la < 0.5) {
		discard;
	}
	// opaque: a pixel outside the picture that the light layer covers shows the light alone
	float a_out = base_px ? 1.0 : la;
#endif
	vec3 base = mix(t.rgb * tint, vec3(0.75, 0.8, 0.84), 0.15 * clamp(ce_snow, 0.0, 1.0));
	vec3 g = vec3(to_lin(vec3(REF_GREY)).r);
	vec3 d = base * (show(g * ce_ambient.rgb) + show(g * ce_sun_color.rgb * v_sun)) / REF_GREY;
	// Arcade floods a plain prop that stands as a landmark at night: picture x the floodlight colour
	d = mix(d, base * flood_color, flood);
	vec3 x = pow((min(d, vec3(1.0)) + 0.055) / 1.055, vec3(2.4)) + to_lin(base) * headlight_color * v_head;
	vec3 lit = pow((min(l.rgb, vec3(1.0)) + 0.055) / 1.055, vec3(2.4));
	// the light layer over the picture ("over" compositing), the picture's share hazed, the light not
	float wl = la / max(a_out, 1.0e-4);
	vec3 col = mix(x, lit, wl);
	ALBEDO = albedo_for(col);
	float hz = haze * (1.0 - wl) * (1.0 - flood);
	FOG = vec4(ce_fog_unshow(min(t.rgb * tint * ce_fog_color.rgb * 1.15, vec3(1.0))), hz);
#ifdef CE_BLEND
	ALPHA = a_out;
#endif
#elif defined(CE_ATLAS)
	vec4 a = texture(albedo_tex, UV);
	a.rgb *= tint;
#ifdef CE_CUTOUT
	if (a.a < 0.5) {
		discard;
	}
#endif
	vec3 e = texture(emit_tex, UV).rgb;
	float la = clamp(max(e.r, max(e.g, e.b)) * 3.0, 0.0, 1.0) * lights;
	float a_out = la + (1.0 - la) * keep;
#ifdef CE_BLEND
	if (a_out < 0.004) {
		discard;
	}
	ALPHA = a_out;
	float wb = (1.0 - la) * keep / max(a_out, 1.0e-4);
#else
	float wb = 1.0;
#endif
	vec3 alb = a.rgb;
	if (ce_snow > 0.0) {
		float up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
		float k = clamp(ce_snow, 0.0, 1.0) * smoothstep(0.5, 0.82, up) * (1.0 - la);
		alb = mix(alb, snow_albedo * (1.0 - snow_night * lights), k);
	}
	alb = mix(alb, alb * flood_color * 1.6, flood);
	ALBEDO = alb * wb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.35 * wb;
	// colours are sRGB-encoded here (the engine linearises ALBEDO and EMISSION): energy as pow(e, 1 / 2.2)
	EMISSION = e * pow(lights * emit_energy, 0.4545);
	FOG = vec4(ce_fog_unshow(min(a.rgb * ce_fog_color.rgb * 1.15, vec3(1.0))), haze * (1.0 - la) * (1.0 - flood));
#elif defined(CE_VCOL)
	vec3 alb = COLOR.rgb * tint;
	float rough = clamp(UV.x, 0.04, 1.0);
	float metal = clamp(UV.y, 0.0, 1.0);
	int ch = UV2.x < 0.0 ? -1 : int(floor(UV2.x));
	float w = UV2.y;
	vec3 emis = vec3(0.0);
	float la = 0.0;
	float fl_keep = 0.0;
	if (ch == 16) {
		// glass facade: floor bands every 4 m, mullions every 3 m (model metres), random lit windows at night
		vec3 n = abs(normalize(v_onrm));
		float u = n.x > n.z ? v_obj.z : v_obj.x;
		// floor bands and mullions, faded to their mean where they get finer than a pixel (no stair-step aliasing)
		float band = bands(v_obj.y / 4.0, 0.14) + bands(u / 3.0, 0.1);
		alb *= 1.0 - 0.3 * min(band, 1.0);
		rough = 0.25;
		// night: offices lit at random (Arcade: 35 %) on a coarser grid – two mullion fields wide, one floor high, a
		// pane inside each cell; where the cells get smaller than a few pixels they melt into their mean glow
		// instead of glittering
		float cu = u / 6.0;
		float cv = v_obj.y / 4.0;
		float pane = step(0.18, fract(cu)) * step(fract(cu), 0.82) * step(0.3, fract(cv)) * step(fract(cv), 0.85);
		float lit = step(hash12(vec2(floor(cu), floor(cv)) + floor(v_obj.xz * 0.01)), window_share) * pane;
		float fw = max(fwidth(cu), fwidth(cv));
		lit = mix(lit, window_share * 0.64 * 0.55, clamp(fw * 1.5 - 0.2, 0.0, 1.0));
		la = lit * lights;
		emis = window_color * la * 1.2;
	} else if (ch == 12) {
		la = w * lights;
		emis = lights_color * la * lights_energy;
	} else if (ch == 13) {
		la = w;
		emis = alb * w;
	} else if (ch == 14) {
		// Arcade lays its floodlight over the hazed picture: the lit share keeps its light through the haze
		fl_keep = w * lights;
		emis = alb * flood_light * fl_keep;
	} else if (ch == 10 || ch == 11) {
		float on = mod(ce_time + (ch == 11 ? 0.75 : 0.0), 1.5) < 0.75 ? 1.0 : 0.0;
		la = w * lights * on;
		emis = beacon_color * la * 2.0;
	}
	if (ce_snow > 0.0) {
		float up = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
		alb = mix(alb, vec3(0.86, 0.88, 0.91) * (1.0 - 0.3 * lights), clamp(ce_snow, 0.0, 1.0) * smoothstep(0.5, 0.82, up) * (1.0 - la));
	}
	float a_out = la + (1.0 - la) * keep;
#ifdef CE_BLEND
	if (a_out < 0.004) {
		discard;
	}
	ALPHA = a_out;
	float wb = (1.0 - la) * keep / max(a_out, 1.0e-4);
#else
	float wb = 1.0;
#endif
	ALBEDO = alb * wb;
	ROUGHNESS = rough;
	METALLIC = metal * wb;
	SPECULAR = 0.4 * wb;
	EMISSION = pow(max(emis, vec3(0.0)), vec3(1.0));
	FOG = vec4(ce_fog_unshow(min(COLOR.rgb * tint * ce_fog_color.rgb * 1.15, vec3(1.0))), haze * (1.0 - la) * (1.0 - fl_keep));
#elif defined(CE_GLOW)
	float fall;
	if (v_beam > 0.5) {
		float t = clamp(UV.x, 0.0, 1.0);
		fall = pow(1.0 - t, 1.6) * (1.0 - UV.y * UV.y) * smoothstep(0.0, 0.04, t);
	} else {
		float r2 = dot(UV, UV);
		if (r2 > 1.0) {
			discard;
		}
		fall = exp(-r2 * 4.0) + 0.6 * exp(-r2 * 40.0);
	}
	ALBEDO = COLOR.rgb * (COLOR.a * fall * v_on * lights);
	FOG = vec4(0.0);
#endif
}
