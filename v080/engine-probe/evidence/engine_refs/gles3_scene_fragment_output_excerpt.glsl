	orm_output_buffer.a = 1.0;
	emission_output_buffer.rgb = emission;
	emission_output_buffer.a = 0.0;
#else // !RENDER_MATERIAL
#ifdef BASE_PASS
#ifdef MODE_UNSHADED
	frag_color = vec4(albedo, alpha);
#else
	diffuse_light *= albedo;
	diffuse_light *= 1.0 - metallic;
	ambient_light *= 1.0 - metallic;
	frag_color = vec4(diffuse_light + specular_light, alpha);
	frag_color.rgb += emission + ambient_light;
#endif //!MODE_UNSHADED
#ifndef FOG_DISABLED
	fog.xy = unpackHalf2x16(fog_rg);
	fog.zw = unpackHalf2x16(fog_ba);
	frag_color.rgb = mix(frag_color.rgb, fog.rgb, fog.a);
#endif // !FOG_DISABLED
	// Tonemap before writing as we are writing to an sRGB framebuffer
	frag_color.rgb *= exposure;
#ifdef APPLY_TONEMAPPING
	frag_color.rgb = apply_tonemapping(frag_color.rgb);
#endif
	frag_color.rgb = linear_to_srgb(frag_color.rgb);
#else // !BASE_PASS
	frag_color = vec4(0.0, 0.0, 0.0, alpha);
#endif // !BASE_PASS
/* ADDITIVE LIGHTING PASS */
#ifdef USE_ADDITIVE_LIGHTING
	diffuse_light = vec3(0.0);
	specular_light = vec3(0.0);
#ifdef USE_VERTEX_LIGHTING
	diffuse_light = additive_diffuse_light_interp;
	specular_light = additive_specular_light_interp * f0;
#endif // USE_VERTEX_LIGHTING
#if !defined(ADDITIVE_OMNI) && !defined(ADDITIVE_SPOT)
#ifndef SHADOWS_DISABLED
// Baked shadowmasks
#ifdef USE_LIGHTMAP
	float shadowmask = 1.0f;
	if (lightmap_shadowmask_mode != SHADOWMASK_MODE_NONE) {
		vec3 uvw;
		uvw.xy = uv2 * lightmap_uv_scale.zw + lightmap_uv_scale.xy;
		uvw.z = float(lightmap_slice);
#ifdef LIGHTMAP_BICUBIC_FILTER
		shadowmask = textureArray_bicubic(shadowmask_textures, uvw, lightmap_texture_size).x;
#else
		shadowmask = textureLod(shadowmask_textures, uvw, 0.0).x;
#endif
	}
#endif //USE_LIGHTMAP
	float directional_shadow = 1.0;
#ifdef USE_LIGHTMAP
	if (lightmap_shadowmask_mode != SHADOWMASK_MODE_ONLY) {
#endif
// Orthogonal shadows
#if !defined(LIGHT_USE_PSSM2) && !defined(LIGHT_USE_PSSM4)
		directional_shadow = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord);
#endif // !defined(LIGHT_USE_PSSM2) && !defined(LIGHT_USE_PSSM4)
// PSSM2 shadows
#ifdef LIGHT_USE_PSSM2
		float depth_z = -vertex.z;
		vec4 light_split_offsets = directional_shadows[directional_shadow_index].shadow_split_offsets;
		//take advantage of prefetch
		float shadow1 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord);
		float shadow2 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord2);
		if (depth_z < light_split_offsets.y) {
#ifdef LIGHT_USE_PSSM_BLEND
			float directional_shadow2 = 1.0;
			float pssm_blend = 0.0;
			bool use_blend = true;
#endif
			if (depth_z < light_split_offsets.x) {
				directional_shadow = shadow1;
#ifdef LIGHT_USE_PSSM_BLEND
				directional_shadow2 = shadow2;
				pssm_blend = smoothstep(0.0, light_split_offsets.x, depth_z);
#endif
			} else {
				directional_shadow = shadow2;
#ifdef LIGHT_USE_PSSM_BLEND
				use_blend = false;
#endif
			}
#ifdef LIGHT_USE_PSSM_BLEND
			if (use_blend) {
				directional_shadow = mix(directional_shadow, directional_shadow2, pssm_blend);
			}
#endif
		}
#endif //LIGHT_USE_PSSM2
// PSSM4 shadows
#ifdef LIGHT_USE_PSSM4
		float depth_z = -vertex.z;
		vec4 light_split_offsets = directional_shadows[directional_shadow_index].shadow_split_offsets;
		float shadow1 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord);
		float shadow2 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord2);
		float shadow3 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord3);
		float shadow4 = sample_shadow(directional_shadow_atlas, directional_shadows[directional_shadow_index].shadow_atlas_pixel_size, shadow_coord4);
		if (depth_z < light_split_offsets.w) {
#ifdef LIGHT_USE_PSSM_BLEND
			float directional_shadow2 = 1.0;
			float pssm_blend = 0.0;
			bool use_blend = true;
#endif
			if (depth_z < light_split_offsets.y) {
				if (depth_z < light_split_offsets.x) {
					directional_shadow = shadow1;
#ifdef LIGHT_USE_PSSM_BLEND
					directional_shadow2 = shadow2;
					pssm_blend = smoothstep(0.0, light_split_offsets.x, depth_z);
#endif
				} else {
					directional_shadow = shadow2;
#ifdef LIGHT_USE_PSSM_BLEND
					directional_shadow2 = shadow3;
					pssm_blend = smoothstep(light_split_offsets.x, light_split_offsets.y, depth_z);
#endif
				}
			} else {
				if (depth_z < light_split_offsets.z) {
					directional_shadow = shadow3;
#if defined(LIGHT_USE_PSSM_BLEND)
					directional_shadow2 = shadow4;
					pssm_blend = smoothstep(light_split_offsets.y, light_split_offsets.z, depth_z);
#endif
				} else {
					directional_shadow = shadow4;
#if defined(LIGHT_USE_PSSM_BLEND)
					use_blend = false;
#endif
				}
			}
#if defined(LIGHT_USE_PSSM_BLEND)
			if (use_blend) {
				directional_shadow = mix(directional_shadow, directional_shadow2, pssm_blend);
			}
#endif
		}
#endif //LIGHT_USE_PSSM4
#ifdef USE_LIGHTMAP
		if (lightmap_shadowmask_mode == SHADOWMASK_MODE_REPLACE) {
			directional_shadow = mix(directional_shadow, shadowmask, smoothstep(directional_shadows[directional_shadow_index].fade_from, directional_shadows[directional_shadow_index].fade_to, vertex.z));
		} else if (lightmap_shadowmask_mode == SHADOWMASK_MODE_OVERLAY) {
			directional_shadow = shadowmask * mix(directional_shadow, 1.0, smoothstep(directional_shadows[directional_shadow_index].fade_from, directional_shadows[directional_shadow_index].fade_to, vertex.z));
		} else {
#endif
			directional_shadow = mix(directional_shadow, 1.0, smoothstep(directional_shadows[directional_shadow_index].fade_from, directional_shadows[directional_shadow_index].fade_to, vertex.z));
#ifdef USE_LIGHTMAP
		}
	} else { // lightmap_shadowmask_mode == SHADOWMASK_MODE_ONLY
		directional_shadow = shadowmask;
	}
#endif
	directional_shadow = mix(1.0, directional_shadow, directional_lights[directional_shadow_index].shadow_opacity);
#else
	float directional_shadow = 1.0f;
#endif // SHADOWS_DISABLED
#ifndef USE_VERTEX_LIGHTING
	if (bool(directional_lights[directional_shadow_index].mask & layer_mask)) {
		light_compute(normal, normalize(directional_lights[directional_shadow_index].direction), normalize(view), directional_lights[directional_shadow_index].size, directional_lights[directional_shadow_index].color * directional_lights[directional_shadow_index].energy, true, directional_shadow, f0, roughness, metallic, directional_lights[directional_shadow_index].specular, albedo, alpha, screen_uv,
#ifdef LIGHT_BACKLIGHT_USED
				backlight,
#endif
#ifdef LIGHT_RIM_USED
				rim, rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
				clearcoat, clearcoat_roughness, geo_normal,
#endif // LIGHT_CLEARCOAT_USED
#ifdef LIGHT_ANISOTROPY_USED
				binormal,
				tangent, anisotropy,
#endif
				diffuse_light,
				specular_light);
	} else {
#endif // !USE_VERTEX_LIGHTING
	   // Just apply shadows to vertex lighting.
		diffuse_light *= directional_shadow;
		specular_light *= directional_shadow;
#ifndef USE_VERTEX_LIGHTING
	}
#endif // !USE_VERTEX_LIGHTING
#endif // !defined(ADDITIVE_OMNI) && !defined(ADDITIVE_SPOT)
#ifdef ADDITIVE_OMNI
	float omni_shadow = 1.0f;
#ifndef SHADOWS_DISABLED
	vec3 light_ray = ((positional_shadows[positional_shadow_index].shadow_matrix * vec4(shadow_coord.xyz, 1.0))).xyz;
	omni_shadow = texture(omni_shadow_texture, vec4(light_ray, 1.0 - length(light_ray) * omni_lights[omni_light_index].inv_radius));
	omni_shadow = mix(1.0, omni_shadow, omni_lights[omni_light_index].shadow_opacity);
#endif // SHADOWS_DISABLED
#ifndef USE_VERTEX_LIGHTING
	light_process_omni(omni_light_index, vertex, view, normal, f0, roughness, metallic, omni_shadow, albedo, alpha, screen_uv,
#ifdef LIGHT_BACKLIGHT_USED
			backlight,
#endif
#ifdef LIGHT_RIM_USED
			rim,
			rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
			clearcoat, clearcoat_roughness, geo_normal,
#endif // LIGHT_CLEARCOAT_USED
#ifdef LIGHT_ANISOTROPY_USED
			binormal, tangent, anisotropy,
#endif
			diffuse_light, specular_light);
#else
	// Just apply shadows to vertex lighting.
	diffuse_light *= omni_shadow;
	specular_light *= omni_shadow;
#endif // !USE_VERTEX_LIGHTING
#endif // ADDITIVE_OMNI
#ifdef ADDITIVE_SPOT
	float spot_shadow = 1.0f;
#ifndef SHADOWS_DISABLED
	spot_shadow = sample_shadow(spot_shadow_texture, positional_shadows[positional_shadow_index].shadow_atlas_pixel_size, shadow_coord);
	spot_shadow = mix(1.0, spot_shadow, spot_lights[spot_light_index].shadow_opacity);
#endif // SHADOWS_DISABLED
#ifndef USE_VERTEX_LIGHTING
	light_process_spot(spot_light_index, vertex, view, normal, f0, roughness, metallic, spot_shadow, albedo, alpha, screen_uv,
#ifdef LIGHT_BACKLIGHT_USED
			backlight,
#endif
#ifdef LIGHT_RIM_USED
			rim,
			rim_tint,
#endif
#ifdef LIGHT_CLEARCOAT_USED
			clearcoat, clearcoat_roughness, geo_normal,
#endif // LIGHT_RIM_USED
#ifdef LIGHT_ANISOTROPY_USED
			tangent,
			binormal, anisotropy,
#endif
			diffuse_light, specular_light);
#else
	// Just apply shadows to vertex lighting.
	diffuse_light *= spot_shadow;
	specular_light *= spot_shadow;
#endif // !USE_VERTEX_LIGHTING
#endif // ADDITIVE_SPOT
	diffuse_light *= albedo;
	diffuse_light *= 1.0 - metallic;
	vec3 additive_light_color = diffuse_light + specular_light;
#ifndef FOG_DISABLED
	fog.xy = unpackHalf2x16(fog_rg);
	fog.zw = unpackHalf2x16(fog_ba);
	additive_light_color *= (1.0 - fog.a);
#endif // !FOG_DISABLED
	// Tonemap before writing as we are writing to an sRGB framebuffer
	additive_light_color *= exposure;
#ifdef APPLY_TONEMAPPING
	additive_light_color = apply_tonemapping(additive_light_color);
#endif
	additive_light_color = linear_to_srgb(additive_light_color);
	frag_color.rgb += additive_light_color;
#endif // USE_ADDITIVE_LIGHTING
	frag_color.rgb *= scene_data_block.data.luminance_multiplier;
#endif // !RENDER_MATERIAL
#endif // !MODE_RENDER_DEPTH
#ifdef PREMUL_ALPHA_USED
	frag_color.rgb *= premul_alpha;
#endif // PREMUL_ALPHA_USED
#endif // !RENDER_MOTION_VECTORS
#if defined(RENDER_MOTION_VECTORS)
	// These motion vectors are in NDC space (as opposed to screen space) to fit the OpenXR XR_FB_space_warp specification.
	// https://registry.khronos.org/OpenXR/specs/1.0/html/xrspec.html#XR_FB_space_warp