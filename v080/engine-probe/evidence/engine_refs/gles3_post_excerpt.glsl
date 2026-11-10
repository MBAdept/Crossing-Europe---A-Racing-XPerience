0123456789abcdef
-
,
/* clang-format on */
// If we reach this code, we always tonemap.
#define APPLY_TONEMAPPING
layout(std140) uniform TonemapData { //ubo:0
	float exposure;
	int tonemapper;
	int pad;
	int pad2;
	vec4 tonemapper_params;
	float brightness;
	float contrast;
	float saturation;
	int pad3;
};
// This approximation expects non-negative input; negative input is undefined behavior.
vec3 linear_to_srgb(vec3 color) {
	//const vec3 a = vec3(0.055f);
	//return mix((vec3(1.0f) + a) * pow(color.rgb, vec3(1.0f / 2.4f)) - a, 12.92f * color.rgb, lessThan(color.rgb, vec3(0.0031308f)));
	// Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
	return max(vec3(1.055) * pow(color, vec3(0.416666667)) - vec3(0.055), vec3(0.0));
}
// This approximation expects non-negative input; negative input behaves poorly.
vec3 srgb_to_linear(vec3 color) {
	// Approximation from http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
	return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
}
#ifdef APPLY_TONEMAPPING
// Based on Reinhard's extended formula, see equation 4 in https://doi.org/cjbgrt
vec3 tonemap_reinhard(vec3 color) {
	float white_squared = tonemapper_params.x;
	vec3 white_squared_color = white_squared * color;
	// Equivalent to color * (1 + color / white_squared) / (1 + color)
	return (white_squared_color + color * color) / (white_squared_color + white_squared);
}
vec3 tonemap_filmic(vec3 color) {
	// These constants must match the those in the C++ code that calculates the parameters.
	// exposure_bias: Input scale (color *= bias, env->white *= bias) to make the brightness consistent with other tonemappers.
	// Also useful to scale the input to the range that the tonemapper is designed for (some require very high input values).
	// Has no effect on the curve's general shape or visual properties.
	const float exposure_bias = 2.0f;
	const float A = 0.22f * exposure_bias * exposure_bias; // bias baked into constants for performance
	const float B = 0.30f * exposure_bias;
	const float C = 0.10f;
	const float D = 0.20f;
	const float E = 0.01f;
	const float F = 0.30f;
	vec3 color_tonemapped = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	return color_tonemapped / tonemapper_params.x;
}
// Adapted from https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
// (MIT License).
vec3 tonemap_aces(vec3 color) {
	// These constants must match the those in the C++ code that calculates the parameters.
	const float exposure_bias = 1.8f;
	const float A = 0.0245786f;
	const float B = 0.000090537f;
	const float C = 0.983729f;
	const float D = 0.432951f;
	const float E = 0.238081f;
	// Exposure bias baked into transform to save shader instructions. Equivalent to `color *= exposure_bias`
	const mat3 rgb_to_rrt = mat3(
			vec3(0.59719f * exposure_bias, 0.35458f * exposure_bias, 0.04823f * exposure_bias),
			vec3(0.07600f * exposure_bias, 0.90834f * exposure_bias, 0.01566f * exposure_bias),
			vec3(0.02840f * exposure_bias, 0.13383f * exposure_bias, 0.83777f * exposure_bias));
	const mat3 odt_to_rgb = mat3(
			vec3(1.60475f, -0.53108f, -0.07367f),
			vec3(-0.10208f, 1.10813f, -0.00605f),
			vec3(-0.00327f, -0.07276f, 1.07602f));
	color *= rgb_to_rrt;
	vec3 color_tonemapped = (color * (color + A) - B) / (color * (C * color + D) + E);
	color_tonemapped *= odt_to_rgb;
	return color_tonemapped / tonemapper_params.x;
}
// allenwp tonemapping curve; developed for use in the Godot game engine.
// Source and details: https://allenwp.com/blog/2025/05/29/allenwp-tonemapping-curve/
// Input must be a non-negative linear scene value.
vec3 allenwp_curve(vec3 x) {
	const float output_max_value = 1.0; // SDR always has an output_max_value of 1.0
	// These constants must match the those in the C++ code that calculates the parameters.
	// 18% "middle gray" is perceptually 50% of the brightness of reference white.
	const float awp_crossover_point = 0.18;
	// When output_max_value and/or awp_crossover_point are no longer constant,
	// awp_shoulder_max can be calculated on the CPU and passed in as tonemap_e.
	const float awp_shoulder_max = output_max_value - awp_crossover_point;
	float awp_contrast = tonemapper_params.x;
	float awp_toe_a = tonemapper_params.y;
	float awp_slope = tonemapper_params.z;
	float awp_w = tonemapper_params.w;
	// Reinhard-like shoulder:
	vec3 s = x - awp_crossover_point;
	vec3 slope_s = awp_slope * s;
	s = slope_s * (1.0 + s / awp_w) / (1.0 + (slope_s / awp_shoulder_max));
	s += awp_crossover_point;
	// Sigmoid power function toe:
	vec3 t = pow(x, vec3(awp_contrast));
	t = t / (t + awp_toe_a);
	return mix(s, t, lessThan(x, vec3(awp_crossover_point)));
}
// This is an approximation and simplification of EaryChow's AgX implementation that is used by Blender.
// This code is based off of the script that generates the AgX_Base_sRGB.cube LUT that Blender uses.
// Source: https://github.com/EaryChow/AgX_LUT_Gen/blob/main/AgXBasesRGB.py
// Colorspace transformation source: https://www.colour-science.org:8010/apps/rgb_colourspace_transformation_matrix
vec3 tonemap_agx(vec3 color) {
	// Input color should be non-negative!
	// Large negative values in one channel and large positive values in other
	// channels can result in a colour that appears darker and more saturated than
	// desired after passing it through the inset matrix. For this reason, it is
	// best to prevent negative input values.
	// This is done before the Rec. 2020 transform to allow the Rec. 2020
	// transform to be combined with the AgX inset matrix. This results in a loss
	// of color information that could be correctly interpreted within the
	// Rec. 2020 color space as positive RGB values, but is often not worth
	// the performance cost of an additional matrix multiplication.
	//
	// Additionally, this AgX configuration was created subjectively based on
	// output appearance in the Rec. 709 color gamut, so it is possible that these
	// matrices will not perform well with non-Rec. 709 output (more testing with
	// future wide-gamut displays is be needed).
	// See this comment from the author on the decisions made to create the matrices:
	// https://github.com/godotengine/godot-proposals/issues/12317#issuecomment-2835824250
	// Combined Rec. 709 to Rec. 2020 and Blender AgX inset matrices:
	const mat3 rec709_to_rec2020_agx_inset_matrix = mat3(
			0.544814746488245, 0.140416948464053, 0.0888104196149096,
			0.373787398372697, 0.754137554567394, 0.178871756420858,
			0.0813978551390581, 0.105445496968552, 0.732317823964232);
	// Combined inverse AgX outset matrix and Rec. 2020 to Rec. 709 matrices.
	const mat3 agx_outset_rec2020_to_rec709_matrix = mat3(
			1.96488741169489, -0.299313364904742, -0.164352742528393,
			-0.855988495690215, 1.32639796461980, -0.238183969428088,
			-0.108898916004672, -0.0270845997150571, 1.40253671195648);
	const float output_max_value = 1.0; // SDR always has an output_max_value of 1.0
	// Apply inset matrix.
	color = rec709_to_rec2020_agx_inset_matrix * color;
	// Use the allenwp tonemapping curve to match the Blender AgX curve while
	// providing stability across all variable dyanimc range (SDR, HDR, EDR).
	color = allenwp_curve(color);
	// Clipping to output_max_value is required to address a cyan colour that occurs
	// with very bright inputs.
	color = min(vec3(output_max_value), color);
	// Apply outset to make the result more chroma-laden and then go back to Rec. 709.
	color = agx_outset_rec2020_to_rec709_matrix * color;
	// Blender's lusRGB.compensate_low_side is too complex for this shader, so
	// simply return the color, even if it has negative components. These negative
	// components may be useful for subsequent color adjustments.
	return color;
}
#define TONEMAPPER_LINEAR 0
#define TONEMAPPER_REINHARD 1
#define TONEMAPPER_FILMIC 2
#define TONEMAPPER_ACES 3
#define TONEMAPPER_AGX 4
vec3 apply_tonemapping(vec3 color) { // inputs are LINEAR
	if (tonemapper == TONEMAPPER_LINEAR) {
		return color;
	}
	// Ensure color values passed to tonemappers are positive.
	// They can be negative in the case of negative lights, which leads to undesired behavior.
	color = max(vec3(0.0), color);
	if (tonemapper == TONEMAPPER_REINHARD) {
		return tonemap_reinhard(color);
	} else if (tonemapper == TONEMAPPER_FILMIC) {
		return tonemap_filmic(color);
	} else if (tonemapper == TONEMAPPER_ACES) {
		return tonemap_aces(color);
	} else { // TONEMAPPER_AGX
		return tonemap_agx(color);
	}
}
#endif // APPLY_TONEMAPPING
#ifdef USE_MULTIVIEW
uniform sampler2DArray source_color; // texunit:0
#else
uniform sampler2D source_color; // texunit:0
#endif // USE_MULTIVIEW
uniform float view;
uniform float luminance_multiplier;
#ifdef USE_GLOW
uniform sampler2D glow_color; // texunit:1
uniform vec2 pixel_size;
uniform float glow_intensity;
uniform float srgb_white;
vec4 get_glow_color(vec2 uv) {
	vec2 half_pixel = pixel_size * 0.5;
	vec4 color = textureLod(glow_color, uv + vec2(-half_pixel.x * 2.0, 0.0), 0.0);
	color += textureLod(glow_color, uv + vec2(-half_pixel.x, half_pixel.y), 0.0) * 2.0;
	color += textureLod(glow_color, uv + vec2(0.0, half_pixel.y * 2.0), 0.0);
	color += textureLod(glow_color, uv + vec2(half_pixel.x, half_pixel.y), 0.0) * 2.0;
	color += textureLod(glow_color, uv + vec2(half_pixel.x * 2.0, 0.0), 0.0);
	color += textureLod(glow_color, uv + vec2(half_pixel.x, -half_pixel.y), 0.0) * 2.0;
	color += textureLod(glow_color, uv + vec2(0.0, -half_pixel.y * 2.0), 0.0);
	color += textureLod(glow_color, uv + vec2(-half_pixel.x, -half_pixel.y), 0.0) * 2.0;
#ifdef USE_LUMINANCE_MULTIPLIER
	color = color / luminance_multiplier;
#endif
	return color / 12.0;
}
#endif // USE_GLOW
#ifdef USE_COLOR_CORRECTION
#ifdef USE_1D_LUT
uniform sampler2D source_color_correction; //texunit:2
vec3 apply_color_correction(vec3 color) {
	color.r = texture(source_color_correction, vec2(color.r, 0.0f)).r;
	color.g = texture(source_color_correction, vec2(color.g, 0.0f)).g;
	color.b = texture(source_color_correction, vec2(color.b, 0.0f)).b;
	return color;
}
#else
uniform sampler3D source_color_correction; //texunit:2
vec3 apply_color_correction(vec3 color) {
	return textureLod(source_color_correction, color, 0.0).rgb;
}
#endif // USE_1D_LUT
#endif // USE_COLOR_CORRECTION
#if defined(USE_SSAO_ABYSS) || defined(USE_SSAO_LOW) || defined(USE_SSAO_MED) || defined(USE_SSAO_HIGH) || defined(USE_SSAO_MEGA)
#define USE_SOME_SSAO
uniform float ssao_intensity;
uniform float ssao_radius_frac;
uniform vec2 ssao_prn_UV;
#ifdef USE_MULTIVIEW
// VR will have 2 depth buffers.
uniform sampler2DArray depth_buffer_array; // texunit:3
#else
uniform sampler2D depth_buffer; // texunit:3
#endif
#if defined(USE_SSAO_ABYSS)
// Use the tiny 2-sample version.
// S4AO (Stupid Simple Screen Space Ambient Occlusion) - Jonathan Dummer (O1S)
// This micro version uses only 3 depth samples, the midpoint and a randomly-rotated, balanced pair.
const mediump float ssao_falloff_frac = 0.25;
// Perform the SSAO.
float s4ao(vec2 UV) {
#ifdef USE_MULTIVIEW
	mediump float depth = texture(depth_buffer_array, vec3(UV, view)).r;
#else
	mediump float depth = texture(depth_buffer, UV).r;
#endif
	mediump float inv_falloff = 1.0f / max(1e-4f, depth * ssao_falloff_frac);
	// Random 2D rotation per pixel (0..1 -> parabola approximating a 180 deg arc)
	mediump float r01 = fract(dot(UV, ssao_prn_UV));
	mediump vec2 duv = vec2(r01 - 0.5f, 2.0f * (r01 - r01 * r01)) * (2.0f * depth * ssao_radius_frac); // 180 degrees.
	// Grab the samples and determine the occlusion.
	mediump float occlusion = 0.0f;
	for (int s = 0; s < 2; ++s) {
#ifdef USE_MULTIVIEW
		mediump float dz = texture(depth_buffer_array, vec3(UV + duv, view)).r - depth;
#else
		mediump float dz = texture(depth_buffer, UV + duv).r - depth;
#endif
		// How 'directly overhead' is it?  Factor in the falloff depth.
		occlusion += normalize(vec3(duv, dz)).z * mix(1.0f, 0.0f, dz * inv_falloff);
		// Mirror the next sample.
		duv = -duv;
	}
	// Adjust the occlusion for intensity, and # samples.
	occlusion = 1.0f - clamp(occlusion * 0.5f * ssao_intensity, 0.0f, 1.0f);
	return occlusion * occlusion;
}
#elif defined(USE_SSAO_HIGH) || defined(USE_SSAO_MEGA)
// Use the rings version for the higher qualities.
// S4AO (Stupid Simple Screen Space Ambient Occlusion) - Jonathan Dummer (O1S)
// The mega version uses N concentric rings of samples.
#if defined(USE_SSAO_MEGA)
const int rings = 4; // Start with the outer ring.
const int samps[] = int[](24, 18, 12, 6); // ( 9, 6, 3 ) is a minimum, but I want better.
#else
const int rings = 3; // Start with the outer ring.
const int samps[] = int[](15, 10, 5, 1); // ( 9, 6, 3 ) is a minimum, but I want better.
#endif
const float average_samples = 1.0 / float(samps[0] + samps[1] * int(rings > 1) + samps[2] * int(rings > 2) + samps[3] * int(rings > 3));
const float ssao_falloff_frac = 0.25;
// Perform the SSAO.
float s4ao(vec2 UV) {
#ifdef USE_MULTIVIEW
	float depth = texture(depth_buffer_array, vec3(UV, view)).r;
#else
	float depth = texture(depth_buffer, UV).r;
#endif
	float inv_falloff = 1.0f / max(1e-4f, depth * ssao_falloff_frac);
	// Random 2D rotation per pixel (0..1 -> parabola approximating a 180 deg arc)
	float r01 = fract(dot(UV, ssao_prn_UV));
	vec2 rcos = vec2(r01 - 0.5f, 2.0f * (r01 - r01 * r01)) * (2.0f * depth * ssao_radius_frac); // 180 degrees.
	vec2 rsin = rcos.yx * vec2(-1, 1); // Perpendicular to the random cosine vector.
	// Grab the samples and determine the occlusion.
	float occlusion = 0.0f;
	float ring_shrink = 0.75f; // Shrink every ring.
	for (int r = 0; r < rings; ++r) {
		float dt = (6.283185307f) / float(samps[r]);
		float t = float(r & 1) * 0.5f * dt;
		for (int s = 0; s < samps[r]; ++s) {
			vec2 duv = cos(t) * rcos + sin(t) * rsin;
#ifdef USE_MULTIVIEW
			float dz = texture(depth_buffer_array, vec3(UV + duv, view)).r - depth;
#else
			float dz = texture(depth_buffer, UV + duv).r - depth;
#endif
			// How 'directly overhead' is it?  Factor in the falloff depth.
			occlusion += normalize(vec3(duv, dz)).z * smoothstep(1.0f, 0.0f, dz * inv_falloff);
			t += dt;
		}
		// The next ring will be smaller.
		rcos *= ring_shrink;
		rsin *= ring_shrink;
	}
	// Adjust the occlusion for intensity, and # samples.
	occlusion *= ssao_intensity * average_samples;
	occlusion = 1.0f - clamp(occlusion, 0.0f, 1.0f);
	return occlusion * occlusion;
}
#else
// Use the more generic NxN grid version.
// S4AO (Stupid Simple Screen Space Ambient Occlusion) - Jonathan Dummer (O1S)
// The sample_width should be even, else the midpoint is at UV.
// Takes sample_width^2 samples in a grid, with the corners notched.
#if defined(USE_SSAO_LOW)
const int sample_width = 2;
#elif defined(USE_SSAO_HIGH)
const int sample_width = 6;
#else
const int sample_width = 4;
#endif
const int notch_01 = int(sample_width > 3); // Set to 1 to skip the corner samples, 0 to include them.
const float sample_mid = (float(sample_width) - 1.0) * 0.50001; // Can't be exactly 0.5 in case sample_width is odd.
#if defined(USE_SSAO_LOW)
const float inv_half_width = 1.0 / sample_mid; // The 2x2 sampling looks wider as all samples are at radius.
#else
const float inv_half_width = 1.7 / sample_mid; // Bake in the 1.7 scale for the random rotation.
#endif
const float average_samples = 1.0 / float(sample_width * sample_width - 4 * notch_01); //  1 / number_of_samples
const float ssao_falloff_frac = 0.25;
// Perform the SSAO.
float s4ao(vec2 UV) {
#ifdef USE_MULTIVIEW
	float depth = texture(depth_buffer_array, vec3(UV, view)).r;
#else
	float depth = texture(depth_buffer, UV).r;
#endif
	float radius = max(1e-4f, depth * ssao_radius_frac);
	float inv_falloff = 1.0f / max(1e-4f, depth * ssao_falloff_frac);
	// Random 2D rotation per pixel (+/-45 deg, with 0 having a lower probability).
	// The random cosine vector is vec2( 0.5, -0.5 to +0.5 ) and *1.7 makes the average length ~ 1.
	vec2 rcos = (inv_half_width * radius) * vec2(0.5f, fract(dot(UV, ssao_prn_UV)) - 0.5f);
	vec2 rsin = rcos.yx * vec2(-1, 1); // Perpendicular to the random cosine vector.
	// Grab the samples and determine the occlusion.
	float occlusion = 0.0f;
	vec2 base_duv = -sample_mid * rsin;
	for (int j = sample_width; --j >= 0;) {
#if defined(USE_SSAO_LOW)
		// Low quality uses 2x2 samples, no notching.
		vec2 duv = -sample_mid * rcos + base_duv;
		for (int i = sample_width; --i >= 0;) {
#else
		//	Will uses 4x4 or 6x6 samples, with the corners notched out.
		int o = /*notch_01 &*/ int((j <= 0) || (j >= (sample_width - 1))); // Notch corners of the grid.
		vec2 duv = (float(o) - sample_mid) * rcos + base_duv;
		for (int i = sample_width - o - o; --i >= 0;) {
#endif
#ifdef USE_MULTIVIEW
			float dz = texture(depth_buffer_array, vec3(UV + duv, view)).r - depth;
#else
			float dz = texture(depth_buffer, UV + duv).r - depth;
#endif
			float validity = smoothstep(1.0f, 0.0f, dz * inv_falloff);
			occlusion += normalize(vec3(duv, dz)).z * validity; // How 'directly overhead' is it?
			duv += rcos; // March along the rcos direction with i.
		}
		base_duv += rsin; // March along the rsin direction with j.
	}
	// Adjust the occlusion for intensity, and # samples.
	occlusion *= ssao_intensity * average_samples;
	occlusion = clamp(1.0f - occlusion, 0.0f, 1.0f);
	return occlusion * occlusion;
}
#endif
#endif
in vec2 uv_interp;
layout(location = 0) out vec4 frag_color;
void main() {
#ifdef USE_MULTIVIEW
	vec4 color = texture(source_color, vec3(uv_interp, view));
#else
	vec4 color = texture(source_color, uv_interp);
#endif
#ifdef USE_LUMINANCE_MULTIPLIER
	color = color / luminance_multiplier;
#endif
#ifdef USE_GLOW
	// Glow blending is performed before srgb_to_linear because
	// the glow texture was created from a nonlinear sRGB-encoded
	// scene, so it only makes sense to add this glow to an equally
	// nonlinear sRGB-encoded scene.
	vec4 glow = get_glow_color(uv_interp) * glow_intensity;
	// Glow always uses the screen blend mode in the Compatibility renderer:
	// Glow cannot be above 1.0 after normalizing and should be non-negative
	// to produce expected results. It is possible that glow can be negative
	// if negative lights were used in the scene.
	// We clamp to srgb_white because glow will be normalized to this range.
	// Note: srgb_white cannot be smaller than the maximum output value (1.0).
	glow.rgb = clamp(glow.rgb, 0.0, srgb_white);
	// Normalize to srgb_white range.
	//glow.rgb /= srgb_white;
	//color.rgb /= srgb_white;
	//color.rgb = (color.rgb + glow.rgb) - (color.rgb * glow.rgb);
	// Expand back to original range.
	//color.rgb *= srgb_white;
	// The following is a mathematically simplified version of the above.
	color.rgb = color.rgb + glow.rgb - (color.rgb * glow.rgb / srgb_white);
#endif // USE_GLOW
	color.rgb = srgb_to_linear(color.rgb);
#if defined(USE_SOME_SSAO)
	// Putting SSAO after the conversion to linear color, though it might be better before the glow.
	color.rgb *= s4ao(uv_interp); // The USE_SSAO_X controls the number of samples.
#endif
	color.rgb = apply_tonemapping(color.rgb);
#ifdef USE_BCS
	// Apply brightness:
	// Apply to relative luminance. This ensures that the hue and saturation of
	// colors is not affected by the adjustment, but requires the multiplication
	// to be performed on linear-encoded values.
	color.rgb = color.rgb * brightness;
	color.rgb = linear_to_srgb(color.rgb);
	// Apply contrast:
	// By applying contrast to RGB values that are perceptually uniform (nonlinear),
	// the darkest values are not hard-clipped as badly, which produces a
	// higher quality contrast adjustment and maintains compatibility with
	// existing projects.
	color.rgb = mix(vec3(0.5), color.rgb, contrast);
	// Apply saturation:
	// By applying saturation adjustment to nonlinear sRGB-encoded values with
	// even weights the preceived brightness of blues are affected, but this
	// maintains compatibility with existing projects.
	color.rgb = mix(vec3(dot(vec3(1.0), color.rgb) * (1.0 / 3.0)), color.rgb, saturation);
#else
	color.rgb = linear_to_srgb(color.rgb);
#endif // USE_BCS
#ifdef USE_COLOR_CORRECTION
	color.rgb = apply_color_correction(color.rgb);
#endif
	frag_color = color;
}
layout(location = 0) in vec2 vertex_attrib;
/* clang-format on */
out vec2 uv_interp;
void main() {
	uv_interp = vertex_attrib * 0.5 + 0.5;
	gl_Position = vec4(vertex_attrib, 1.0, 1.0);
}
/* clang-format off */
/* clang-format on */
#ifdef MODE_FILTER
#ifdef USE_MULTIVIEW
uniform sampler2DArray source_color; // texunit:0
#else
uniform sampler2D source_color; // texunit:0
#endif // USE_MULTIVIEW
uniform float view;
uniform vec2 pixel_size;
uniform float luminance_multiplier;
uniform float glow_bloom;
uniform float glow_hdr_threshold;
uniform float glow_hdr_scale;
uniform float glow_luminance_cap;
#endif // MODE_FILTER
#ifdef MODE_DOWNSAMPLE
uniform sampler2D source_color; // texunit:0
uniform vec2 pixel_size;
#endif // MODE_DOWNSAMPLE
#ifdef MODE_UPSAMPLE
uniform sampler2D source_color; // texunit:0
uniform vec2 pixel_size;
#endif // MODE_UPSAMPLE
in vec2 uv_interp;
layout(location = 0) out vec4 frag_color;
void main() {
#ifdef MODE_FILTER
	// Note, we read from an image with double resolution, so we average those out
#ifdef USE_MULTIVIEW
	vec2 half_pixel = pixel_size * 0.5;
	vec3 uv = vec3(uv_interp, view);
	vec3 color = textureLod(source_color, uv, 0.0).rgb * 4.0;
	color += textureLod(source_color, uv - vec3(half_pixel, 0.0), 0.0).rgb;
	color += textureLod(source_color, uv + vec3(half_pixel, 0.0), 0.0).rgb;
	color += textureLod(source_color, uv - vec3(half_pixel.x, -half_pixel.y, 0.0), 0.0).rgb;
	color += textureLod(source_color, uv + vec3(half_pixel.x, -half_pixel.y, 0.0), 0.0).rgb;
#else
	vec2 half_pixel = pixel_size * 0.5;
	vec2 uv = uv_interp;
	vec3 color = textureLod(source_color, uv, 0.0).rgb * 4.0;
	color += textureLod(source_color, uv - half_pixel, 0.0).rgb;
	color += textureLod(source_color, uv + half_pixel, 0.0).rgb;
	color += textureLod(source_color, uv - vec2(half_pixel.x, -half_pixel.y), 0.0).rgb;
	color += textureLod(source_color, uv + vec2(half_pixel.x, -half_pixel.y), 0.0).rgb;
#endif // USE_MULTIVIEW
	color /= luminance_multiplier * 8.0;
	float feedback_factor = max(color.r, max(color.g, color.b));
	float feedback = max(smoothstep(glow_hdr_threshold, glow_hdr_threshold + glow_hdr_scale, feedback_factor), glow_bloom);
	color = min(color * feedback, vec3(glow_luminance_cap));
	frag_color = vec4(luminance_multiplier * color, 1.0);