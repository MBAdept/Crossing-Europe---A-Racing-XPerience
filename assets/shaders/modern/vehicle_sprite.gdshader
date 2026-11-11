// Modern: Arcade's own picture of a vehicle set that has no 3D model yet (layer "vehicles", VehicleStandIn) – the
// safety net that keeps every vehicle at least as good as in Arcade (docs/renderer-modern.md §10.8).
// kind 0 – sprite sheet (traffic, police: ortho cells with 17 yaw angles; player cars: perspective cells with 21
//   angles). One MultiMesh per sheet; the mesh has 4 columns x 2 rows (UV.x = column 0..3, UV.y = 0 top / 1 bottom).
//   Instance transform: the car's frame at the cell's anchor (ortho: rear centre on the ground, perspective: centre
//   on the ground), -Z = the car's heading. INSTANCE_CUSTOM = (cell index, tail, brake, w): ortho w = beacon layer
//   (0 none, 1 a, 2 b) + 4 when folded; perspective w = body roll (rad). Instance colour = modulate rgb (Arcade's
//   _modulate: ambient + lamp light + fog tint), a = path-distance fade.
//   Flat: an upright quad parallel to the picture, anchored like Arcade's sprite (width image_width_m: the vehicle's
//   real width). Folded (Arcade's flank warp near the camera, VehiclePose.warp_columns): the columns of the cell are
//   put onto the car itself – the rear face across the rear, the visible flank along the flank – so every strip
//   stands at its own depth, exactly what Arcade imitates in screen space. What a traffic picture shows below the
//   ground line lies on the road (onto_road); the player's perspective picture is pulled towards the eye instead.
// kind 1 – face of a box vehicle (trucks, buses: "render": "box"): real geometry of the part's box, UV = the face's
//   picture in the sheet, UV2 = its tail-light picture (x < 0: none), CUSTOM0.xy = its brake-light picture (x < 0:
//   none). Instance uniforms modulate (rgb, a = fade) and ovl (tail, brake).
// The sheets carry baked light: unshaded, modulated like Arcade in display values; albedo_for() hands the renderer the
// ALBEDO that shows as that value (see billboard.gdshader). Light layers are composited "over" like Arcade's draw
// order (base, tail, brake, beacon). Two passes of the same source: this one is opaque with an alpha scissor – the
// body writes depth in the opaque pass, so crests and vehicles hide it and the flares see it in the depth texture
// (they test against it); compiled with CE_SOFT (VehicleStandIn.soft_shader(), the material's next_pass) it blends
// the soft parts the opaque pass left out (the baked ground shadow, thin parts far away) over what lies behind.
// Fade: ordered dither like vpbr (F5).
// Load only through ModernMaterials.shader() – never with preload(). Owner: R3E (vehicles).
shader_type spatial;
#ifdef CE_SOFT
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled, skip_vertex_transform;
#else
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled, shadows_disabled, skip_vertex_transform;
#endif

uniform sampler2D sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int kind = 0;
uniform vec2 tex_px = vec2(1.0);              // size of the sheet (px)
// kind 0
uniform vec2 cell_px = vec2(1.0);             // size of a cell (px)
uniform int grid = 1;                         // cells per row of the sheet
uniform int n_angles = 1;
uniform vec4 rows = vec4(0.0, -1.0, -1.0, -1.0);   // layer rows: base, tail, brake, beacon_a (-1 = none)
uniform float row_beacon_b = -1.0;
uniform vec2 size_m = vec2(4.0, 2.0);         // quad width (image_width_m) and height (m)
uniform vec2 anchor = vec2(0.5, 1.0);         // ground point inside the cell (0..1)
uniform bool persp = false;                   // perspective cells: never folded, w = roll
uniform float elev = 0.0;                     // elevation of the ortho render camera (rad)
uniform vec2 car_wl = vec2(1.8, 4.5);         // width and length of the vehicle (m), for the fold
uniform float yaws[32];                       // yaw of every angle (degrees)
// kind 1
instance uniform vec4 modulate = vec4(1.0);
instance uniform vec4 ovl = vec4(0.0);        // tail, brake (0..1)

uniform float pull_margin = 0.15;             // m below the lowest row the pulled player picture keeps clear (roll)
uniform float skirt_lift = 0.02;              // m above the road the rows of a traffic picture laid onto it lie
uniform float scissor = 0.8;                  // alpha from which a pixel belongs to the opaque body (the baked ground
                                              // shadows of the sheets lie at 0.5 – 0.75: they blend, as in Arcade)

varying flat vec4 v_cell;                     // kind 0: (cell, tail, brake, beacon row)
varying vec4 v_mod;
varying vec2 v_uv;                            // kind 0: inside the cell 0..1; kind 1: sheet uv
varying vec4 v_ovl_uv;                        // kind 1: tail uv, brake uv

// Factor (<= 1) by which an upright picture whose anchor is ay m above the eye (negative: below) is pulled towards
// the eye so that its lowest row (vb m below the anchor, negative) does not reach under the road there – scaling
// about the eye keeps every pixel where it was. VehicleStandIn.persp_pull() is the same on the CPU.
float persp_pull(float ay, float vb, float margin) {
	if (ay > -0.1) {
		return 1.0;
	}
	return clamp(ay / (ay + vb - margin), 0.3, 1.0);
}

// A point p (view space) of a traffic picture that lies below the plane m above the road at the anchor a (n = the
// road's up) moves along its eye ray onto that plane: the same pixel at the depth of the road there. The rows that
// show the road under and in front of the car (Arcade's baked shadow) lie on the road instead of reaching under it;
// the body keeps the depth of the car, so crests and vehicles in front hide it exactly as a model.
vec3 onto_road(vec3 p, vec3 a, vec3 n, float m) {
	float h = dot(n, a) + m;            // < 0: the eye is above the plane
	float q = dot(n, p);
	if (h >= 0.0 || q >= h) {
		return p;
	}
	return p * max(h / q, 0.3);
}

void vertex() {
	if (kind == 0) {
		vec4 cu = INSTANCE_CUSTOM;
		v_mod = COLOR;
		float W = size_m.x;
		float H = size_m.y;
		float xl = -anchor.x * W;
		float xr = (1.0 - anchor.x) * W;
		float v_top = anchor.y * H;
		float v_bot = (anchor.y - 1.0) * H;
		int col = int(UV.x + 0.5);
		int row = int(UV.y + 0.5);          // 0 top of the cell, 1 the ground line, 2 bottom of the cell
		float v;                            // height of the row in the picture, m above the anchor row
		float wcode = persp ? 0.0 : cu.w;
		bool fold = !persp && wcode >= 3.5;
		float beacon = wcode - (fold ? 4.0 : 0.0);
		float brow = -1.0;
		if (beacon > 0.5 && beacon < 1.5) {
			brow = rows.w;
		} else if (beacon > 1.5) {
			brow = row_beacon_b;
		}
		v_cell = vec4(cu.x, cu.y, cu.z, brow);
		vec3 a = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 n = normalize((MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		float x;
		if (!fold) {
			// upright quad parallel to the picture through the anchor (camera without pitch and roll: view y = up)
			x = mix(xl, xr, float(col) / 3.0);
			v = row == 0 ? v_top : (row == 1 ? clamp(0.0, v_bot, v_top) : v_bot);
			vec2 off = vec2(x, v);
			if (persp) {
				float r = cu.w;     // body roll: Arcade turns its player sprite about the anchor on the screen
				off = vec2(off.x * cos(r) + off.y * sin(r), -off.x * sin(r) + off.y * cos(r));
			}
			VERTEX = a + vec3(off, 0.0);
			if (persp) {
				// a perspective cell reaches far below its anchor (the rear of the car is nearer than its centre): the
				// whole picture is pulled towards the eye until its lowest row stands on the road – the same picture,
				// nearer (the player's car: nothing stands between it and the camera)
				VERTEX *= persp_pull(a.y, v_bot, pull_margin);
			} else {
				VERTEX = onto_road(VERTEX, a, n, skirt_lift);
			}
		} else {
			// Arcade's warp columns (VehiclePose.warp_columns) with one strip per face: the GPU interpolates each
			// planar strip perspective-correctly, so four columns are exact
			int ang = clamp(int(cu.x + 0.5), 0, min(n_angles, 32) - 1);
			float psi = radians(yaws[ang]);
			float sn = sin(psi);
			float cs = cos(psi);
			float hw = car_wl.x * 0.5;
			float L = car_wl.y;
			float s;
			float t;
			if (psi > 0.0) {
				float corner = clamp(hw * cs, xl, xr);
				float front = clamp(hw * cs + L * sn, corner, xr);
				if (col == 0) {
					x = min(xl, corner); s = x / cs; t = 0.0;
				} else if (col == 1) {
					x = corner; s = hw; t = 0.0;
				} else if (col == 2) {
					x = front; s = hw; t = clamp((front - hw * cs) / max(sn, 1.0e-4), 0.0, L);
				} else {
					x = max(xr, front); s = hw + (x - front) / cs; t = (front - hw * cs) / max(sn, 1.0e-4);
					t = clamp(t, 0.0, L);
				}
			} else {
				float corner = clamp(-hw * cs, xl, xr);
				float front = clamp(-hw * cs + L * sn, xl, corner);
				if (col == 0) {
					x = min(xl, front);
					t = clamp((front + hw * cs) / min(sn, -1.0e-4), 0.0, L);
					s = -hw - (front - x) / cs;
				} else if (col == 1) {
					x = front; s = -hw; t = clamp((front + hw * cs) / min(sn, -1.0e-4), 0.0, L);
				} else if (col == 2) {
					x = corner; s = -hw; t = 0.0;
				} else {
					x = max(xr, corner); s = x / cs; t = 0.0;
				}
			}
			// the column's ground point on the car and the row where the picture shows it (Arcade: warp_screen – a
			// ground point dz deeper appears dz sin(elev) higher): above it the column stands upright on the car;
			// below it the picture shows the road nearer to the camera (the baked shadow) – laid onto the road where
			// the ortho camera saw it, instead of reaching under it
			float se = sin(elev);
			float vg = (t * cs - s * sn) * se;
			v = row == 0 ? v_top : (row == 1 ? clamp(vg, v_bot, v_top) : v_bot);
			if (v >= vg - 1.0e-5) {
				vec3 g = (MODELVIEW_MATRIX * vec4(s, 0.0, -t, 1.0)).xyz;
				VERTEX = g + vec3(0.0, v - vg, 0.0);
			} else {
				float f = v / max(se, 0.01);
				VERTEX = (MODELVIEW_MATRIX * vec4(x * cs - f * sn, 0.0, -(x * sn + f * cs), 1.0)).xyz;
			}
			// what lies on the road: skirt_lift above it along the eye ray (no fighting with the road's depth)
			VERTEX = onto_road(VERTEX, a, n, skirt_lift);
		}
		v_uv = vec2((x - xl) / W, (v_top - v) / H);
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		v_mod = modulate;
		v_cell = vec4(ovl.x, ovl.y, 0.0, 0.0);
		v_uv = UV;
		v_ovl_uv = vec4(UV2, CUSTOM0.xy);
		VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

// uv of a point inside cell (angle index, layer row) of the sheet; inset by half a texel (no bleeding into the
// neighbour cell at the edge)
vec2 cell_uv(float ai, float row, vec2 p) {
	float i = row * float(n_angles) + ai;
	float g = float(max(grid, 1));
	float cx = mod(i, g);
	float cy = floor(i / g + 0.0001);
	vec2 q = clamp(p * cell_px, vec2(0.5), cell_px - vec2(0.5));
	return (vec2(cx, cy) * cell_px + q) / tex_px;
}

// The Compatibility renderer takes an unshaded ALBEDO through its sRGB -> linear polynomial and shows the result with
// the exact sRGB curve (measured, billboard.gdshader): dark values would come out darker than in Arcade (0.10 shows as
// 0.088, 0.05 as 0.030 – at night the whole picture is dark). albedo_for(d) is the ALBEDO that shows as the display
// value d: Arcade's product of sheet and modulate, made in display values like its canvas.
vec3 to_lin(vec3 c) {
	return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878);
}

vec3 albedo_for(vec3 d) {
	vec3 x = pow((max(d, vec3(0.0)) + 0.055) / 1.055, vec3(2.4));
	vec3 c = pow(x, vec3(0.4545));
	for (int i = 0; i < 2; i++) {
		c -= (to_lin(c) - x) / (c * (c * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return max(c, vec3(0.0));
}

// Arcade's draw order: a layer drawn with alpha k over what is there ("over", straight alpha)
vec4 over(vec4 dst, vec4 src, float k) {
	float a = src.a * k;
	float o = a + dst.a * (1.0 - a);
	vec3 c = (src.rgb * a + dst.rgb * dst.a * (1.0 - a)) / max(o, 1.0e-4);
	return vec4(c, o);
}

void fragment() {
	// path-distance fade (same law as the simulation's visibility): ordered dither like vpbr
	if (v_mod.a < 0.999) {
		float d = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548776662, 0.5698402910)));
		if (d >= v_mod.a) {
			discard;
		}
	}
	vec4 acc;
	if (kind == 0) {
		float ai = floor(v_cell.x + 0.5);
		vec4 b = texture(sheet, cell_uv(ai, rows.x, v_uv));
		acc = vec4(b.rgb * v_mod.rgb, b.a);
		if (v_cell.y > 0.004 && rows.y >= 0.0) {
			acc = over(acc, texture(sheet, cell_uv(ai, rows.y, v_uv)), v_cell.y);
		}
		if (v_cell.z > 0.004 && rows.z >= 0.0) {
			acc = over(acc, texture(sheet, cell_uv(ai, rows.z, v_uv)), v_cell.z);
		}
		if (v_cell.w >= 0.0) {
			acc = over(acc, texture(sheet, cell_uv(ai, v_cell.w, v_uv)), 1.0);
		}
	} else {
		vec4 b = texture(sheet, v_uv);
		acc = vec4(b.rgb * v_mod.rgb, b.a);
		if (v_cell.x > 0.004 && v_ovl_uv.x >= 0.0) {
			acc = over(acc, texture(sheet, v_ovl_uv.xy), v_cell.x);
		}
		if (v_cell.y > 0.004 && v_ovl_uv.z >= 0.0) {
			acc = over(acc, texture(sheet, v_ovl_uv.zw), v_cell.y);
		}
	}
#ifdef CE_SOFT
	// only what the opaque pass left out (the same alpha in both passes: the split is exact)
	if (acc.a >= scissor || acc.a < 0.004) {
		discard;
	}
	ALBEDO = albedo_for(acc.rgb);
	ALPHA = acc.a;
#else
	ALBEDO = albedo_for(acc.rgb);
	ALPHA = acc.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
#endif
}
