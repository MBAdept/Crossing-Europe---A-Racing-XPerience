#!/usr/bin/env python3
"""NACH-R5: re-run QA-R5's unguarded mutations plus FIX-R5's P1 and two of my own (L1, X1) one at a time in the
worktree; only the matching unit-test file runs; the file is restored from a backup afterwards (and checked with git)."""
import os, shutil, subprocess, sys, json
WT = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8'
N = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5'
B = 'scripts/race3d/builders/bridge.gd'
T = 'scripts/race3d/builders/tunnel.gd'
MUT = [
    ('BASE', None, None, None, 'test_bridge'),
    ('BASE_T', None, None, None, 'test_tunnel'),
    ('B10_dark_pylon', B, 'dup.set_shader_parameter("night_albedo", PYLON_NIGHT_ALBEDO)', 'pass', 'test_bridge'),
    ('B12_cables_count', B, 'const CABLES_PER_SIDE := 7', 'const CABLES_PER_SIDE := 5', 'test_bridge'),
    ('B14_lamps_skip', B, '"bridge_lamp":\n\t\t\t\t\t_lamp(', '"bridge_lamp_x":\n\t\t\t\t\t_lamp(', 'test_bridge'),
    ('T4_zone_guard', T, '(env as Object).has_method(&"set_zone")', 'true', 'test_tunnel'),
    ('P1_portal_layer', T, '\t\tpi.layers = PORTAL_LAYERS', '\t\tpass', 'test_tunnel'),
    ('L1_light_early_return', T, '\tif key == _state_key:\n\t\ttunnel_state["light"] = _light\n', '\tif key == _state_key:\n', 'test_tunnel'),
    ('X1_exit_z_end_km', T, 'exit_z = float(ceili(track.km_to_z(float(t["end_km"])) / track.seg_len - 1.0e-6)) * track.seg_len',
     'exit_z = track.km_to_z(float(t["end_km"]))', 'test_tunnel'),
]
os.makedirs(N + '/mutations', exist_ok=True)
env = dict(os.environ, XDG_DATA_HOME=N + '/xdg')
res = {}
for name, path, old, new, test in MUT:
    if len(sys.argv) > 1 and name not in sys.argv[1:]:
        continue
    full = os.path.join(WT, path) if path else None
    if full:
        src = open(full, encoding='utf-8').read()
        assert src.count(old) == 1, (name, src.count(old))
        shutil.copy(full, N + '/mutations/backup.gd')
    try:
        if full:
            open(full, 'w', encoding='utf-8').write(src.replace(old, new))
        p = subprocess.run(['nice', '-n', '10', 'timeout', '900', 'godot', '--headless', '--path', WT, '-s', 'res://tests/run_tests.gd', '--',
                            '--filter=' + test], capture_output=True, text=True, env=env)
        out = p.stdout + p.stderr
        open(N + '/mutations/%s.log' % name, 'w').write(out)
        summary = [l for l in out.splitlines() if 'Tests,' in l]
        caught_by = sorted(set(l.split('::')[-1].strip()[:90] for l in out.splitlines() if l.startswith('FAIL')))
        res[name] = {'exit': p.returncode, 'summary': summary[-1] if summary else '?', 'failed_tests': caught_by,
                     'script_errors': sum(1 for l in out.splitlines() if 'SCRIPT ERROR' in l)}
        print(name, json.dumps(res[name], ensure_ascii=False), flush=True)
    finally:
        if full:
            shutil.copy(N + '/mutations/backup.gd', full)
st = subprocess.run(['git', '-C', WT, 'status', '--porcelain', '--', 'scripts'], capture_output=True, text=True).stdout
print('GIT STATUS scripts after restore:', repr(st))
json.dump(res, open(N + '/mutations/results.json', 'w'), indent=1, ensure_ascii=False)
