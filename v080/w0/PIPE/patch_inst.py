from patchlib import patch

patch("assets/shaders/modern/vpbr.gdshader", [
    ('''// per instance (set_instance_shader_parameter on the MeshInstance3D / MultiMeshInstance3D node)
instance uniform vec4 paint : source_color = vec4(0.5, 0.5, 0.52, 0.3);   // rgb + metallic of the paint
instance uniform vec4 paint2 : source_color = vec4(0.9, 0.9, 0.9, 0.1);
instance uniform vec4 paint3 : source_color = vec4(0.1, 0.2, 0.6, 0.1);
instance uniform vec4 lamp_a = vec4(0.0);     // tail, brake, indicator left, indicator right (0..1)
instance uniform vec4 lamp_b = vec4(0.0);     // head, reverse, beacon A, beacon B (0..1)
instance uniform float fade = 1.0;            // path-distance fade: dither discard in the opaque pass
instance uniform float sun = 1.0;             // 0 inside tunnels: masks the directional light
''', '''// per instance (set_instance_shader_parameter on the MeshInstance3D / MultiMeshInstance3D node).
// The indices are fixed: a body carries a vpbr and a glass surface, and the uniforms both shaders know
// (fade, sun) must sit at the same index in both.
instance uniform vec4 paint : source_color, instance_index(0) = vec4(0.5, 0.5, 0.52, 0.3);   // rgb + metallic
instance uniform vec4 paint2 : source_color, instance_index(1) = vec4(0.9, 0.9, 0.9, 0.1);
instance uniform vec4 paint3 : source_color, instance_index(2) = vec4(0.1, 0.2, 0.6, 0.1);
instance uniform vec4 lamp_a : instance_index(3) = vec4(0.0);   // tail, brake, indicator left, indicator right
instance uniform vec4 lamp_b : instance_index(4) = vec4(0.0);   // head, reverse, beacon A, beacon B (0..1)
instance uniform float fade : instance_index(5) = 1.0;          // path-distance fade: dither discard, opaque
instance uniform float sun : instance_index(6) = 1.0;           // 0 inside tunnels: masks the directional light
'''),
])
patch("assets/shaders/modern/glass.gdshader", [
    ('''instance uniform float fade = 1.0;            // path-distance fade (dither discard, as class vpbr)
instance uniform float sun = 1.0;             // 0 inside tunnels: masks the directional light
''', '''// same indices as in vpbr.gdshader: both surfaces of a body share the instance
instance uniform float fade : instance_index(5) = 1.0;          // path-distance fade (dither discard)
instance uniform float sun : instance_index(6) = 1.0;           // 0 inside tunnels: masks the directional light
'''),
])
