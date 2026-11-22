#!/bin/bash
# Render-check mutations in the scratch copy S/mut (one at a time; each restores its files afterwards).
# Usage: render_mut.sh <id ...>   ids: static eyespec nightglow spotspec tint
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
M="python3 $S/sh/mutate.py"
OUT=$S/out/rmut
mkdir -p "$OUT" "$S/xdg/rmut"
export XDG_DATA_HOME=$S/xdg/rmut MESA_SHADER_CACHE_DIR=$S/xdg/rmut/mesa
run() {   # $1 = id, $2 = filter
	echo "$(date +%T) run $1 filter=$2"
	(cd "$S/mut" && tools/run_render_checks.sh modern "$2" > "$OUT/$1.log" 2>&1)
	echo "$(date +%T) end $1 rc=$?"
	grep -E "^RENDER-CHECK |RENDER-CHECK-DATEI|RENDER-CHECKS" "$OUT/$1.log" | cut -c1-260
}
for id in "$@"; do
	case "$id" in
	static)
		$M apply scripts/race3d/modern_materials.gd "	if cls == \"vpbr\" and not model.is_empty() and not (str(model.get(\"kind\", \"\")) in [\"vehicle\", \"heavy\"]):
		return VPBR_STATIC" "	if false:  # QA-MUTATION: every model draws with the shared vpbr (instance uniforms)
		return VPBR_STATIC"
		run static instance_budget_wald
		$M restore scripts/race3d/modern_materials.gd ;;
	eyespec)
		$M apply scripts/race3d/modern_materials.gd "	[\"vpbr\", \"eye_lamp_spec\", 0.0], [\"glass\", \"eye_lamp_spec\", 0.0]]" "	[\"vpbr\", \"eye_lamp_spec\", 1.0], [\"glass\", \"eye_lamp_spec\", 1.0]]  # QA-MUTATION"
		run eyespec vehicle_lights
		$M restore scripts/race3d/modern_materials.gd ;;
	nightglow)
		$M apply scripts/race3d/vehicle_pose3d.gd "const MODEL_BRAKE_NIGHT_NEAR := 0.6
const MODEL_BRAKE_NIGHT_FAR := 0.15" "const MODEL_BRAKE_NIGHT_NEAR := 1.0
const MODEL_BRAKE_NIGHT_FAR := 1.0  # QA-MUTATION"
		run nightglow vehicle_lights
		$M restore scripts/race3d/vehicle_pose3d.gd ;;
	spotspec)
		$M apply scripts/race3d/layers/lights.gd "const SPOT_SPECULAR := 0.5" "const SPOT_SPECULAR := 0.0  # QA-MUTATION"
		run spotspec_vl vehicle_lights
		run spotspec_nass night_nass
		$M restore scripts/race3d/layers/lights.gd ;;
	roadlight)
		$M apply assets/shaders/modern/road.gdshader "	vec3 extra = ce_pools(v_world) * reflect + ce_headlight_light(v_world, reflect);" "	vec3 extra = ce_pools(v_world) * reflect; /* QA-MUTATION: no low beam on the road */"
		run roadlight_nass night_nass
		$M restore assets/shaders/modern/road.gdshader ;;
	tint)
		$M apply assets/shaders/modern/baked.gdshader "	a.rgb *= v_tint;" "	a.rgb *= vec3(1.0); /* QA-MUTATION */"
		$M apply assets/shaders/modern/leaves.gdshader "	ALBEDO = t.rgb * v_bright * v_tint;" "	ALBEDO = t.rgb * v_bright; /* QA-MUTATION */"
		run tint props_render
		run tint_models models
		run tint_facade facade_render
		$M restore assets/shaders/modern/baked.gdshader
		$M restore assets/shaders/modern/leaves.gdshader ;;
	esac
done
echo "$(date +%T) render_mut done"
