// Modern: 2D overlay of a race on canvas layer 2 (contract §4.4.4) – the lights of a police chase at the two lower
// corners of the picture: a blue and a red glow that change sides (Arcade: RoadRenderer._draw_overlays – radius
// 330 px and 260 px of the 720 rows high picture, strength 0.32 and 0.22 × chase01, sides swapped 2.5 times a
// second). One full-rect ColorRect, additive; the layer hides it while no chase runs.
// The corners are those of the LOGICAL picture – 1280 × 720, 1280 × 800, 1680 × 720 … (stretch aspect "expand").
// Load only through ModernMaterials.shader("overlay") – never with preload().
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec2 rect_size = vec2(1280.0, 720.0);   // logical size of the picture in pixels
uniform float chase = 0.0;                       // 0..1 (view.chase01)
uniform float swap = 0.0;                        // 0: blue left, red right; 1: the other way round
uniform vec3 blue = vec3(0.15, 0.3, 1.0);
uniform vec3 red = vec3(1.0, 0.1, 0.1);

// Arcade's glow gradient: 1 at the centre, 0.55 at a quarter of the radius, 0 at the radius.
float glow(float d) {
	return d < 0.25 ? mix(1.0, 0.55, d * 4.0) : mix(0.55, 0.0, clamp((d - 0.25) / 0.75, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * rect_size;
	float scale = rect_size.y / 720.0;
	vec2 left = vec2(0.0, rect_size.y);
	vec2 right = rect_size;
	vec2 at_blue = swap < 0.5 ? left : right;
	vec2 at_red = swap < 0.5 ? right : left;
	vec3 c = blue * (0.32 * chase * glow(distance(p, at_blue) / (330.0 * scale)))
		+ red * (0.22 * chase * glow(distance(p, at_red) / (260.0 * scale)));
	COLOR = vec4(c, 1.0);
}
