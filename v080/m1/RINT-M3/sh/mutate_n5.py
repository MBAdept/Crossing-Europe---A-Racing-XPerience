import subprocess, sys, shutil
W = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_a71eeb2e-3b7-1'
S = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3'
P = 'scripts/race3d/builders/props.gd'
I = 'assets/shaders/modern/inc/lod_band.gdshaderinc'
MUTS = [
    ("N1_no_threshold_refresh", P, "\t\t_thresholds(h)          # new bands and shadow reach: new thresholds (and no stale key)\n", "\t\tpass\n"),
    ("N3_no_caster_threshold", P, "\tvar hi := PackedFloat32Array([_shadow_m + SHADOW_KEEP_M])\n", "\tvar hi := PackedFloat32Array()\n"),
    ("N4_far_corner_min", P, "\tvar far := (p - wb.position).abs().max((wb.end - p).abs()).length()\n",
     "\tvar far := (p - wb.position).abs().min((wb.end - p).abs()).length()\n"),
    ("N5_band_global_never_set", P, "\t\tModernMaterials.set_global(\"ce_lod_band_m\", _band_m)\n", "\t\tpass\n"),
    ("N6_shader_band_ignored", I, "vec2(max(ce_lod_band_m, 0.0))", "vec2(1.0e4)"),
    ("N7_band_binary_like_still", P, "\tvar target := clampf(speed * LOD_BAND_S, 0.0, LOD_BAND_MAX_M)\n",
     "\tvar target := 0.0 if speed < 1.5 else LOD_BAND_MAX_M\n"),
]
for name, f, old, new in MUTS:
    path = W + '/' + f
    src = open(path, encoding='utf-8').read()
    if src.count(old) != 1:
        print("MUT %s: pattern count %d – skipped" % (name, src.count(old)))
        continue
    shutil.copy(path, S + '/mut.keep')
    open(path, 'w', encoding='utf-8').write(src.replace(old, new))
    try:
        r = subprocess.run([S + '/sh/rt.sh', 'mut_' + name, 'test_props'], capture_output=True, text=True, timeout=900)
        log = open(S + '/logs/rt_mut_' + name + '.log', encoding='utf-8').read()
        fails = [l for l in log.splitlines() if l.startswith('FAIL')]
        summ = [l for l in log.splitlines() if 'Tests,' in l]
        print("MUT %-28s %s  %s" % (name, "ROT" if fails else "GRÜN", (summ[-1] if summ else '') + ' ' + '; '.join(fails[:3])))
    finally:
        shutil.copy(S + '/mut.keep', path)
print("restored")
