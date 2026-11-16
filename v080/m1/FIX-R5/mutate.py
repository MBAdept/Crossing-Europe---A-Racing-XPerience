#!/usr/bin/env python3
"""FIX-R5: QA-R5's four unguarded mutations (and one for QR5-01) applied one at a time in the worktree; the matching
test file is run, the file is restored from a backup afterwards. Prints one line per mutation."""
import os, shutil, subprocess, sys, json
WT = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6'
F = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5'
B = 'scripts/race3d/builders/bridge.gd'
T = 'scripts/race3d/builders/tunnel.gd'
MUT = [
    ('B10_dark_pylon', B, 'dup.set_shader_parameter("night_albedo", PYLON_NIGHT_ALBEDO)', 'pass', 'test_bridge'),
    ('B12_cables_count', B, 'const CABLES_PER_SIDE := 7', 'const CABLES_PER_SIDE := 5', 'test_bridge'),
    ('B14_lamps_skip', B, '"bridge_lamp":\n\t\t\t\t\t_lamp(', '"bridge_lamp_x":\n\t\t\t\t\t_lamp(', 'test_bridge'),
    ('T4_zone_guard', T, '(env as Object).has_method(&"set_zone")', 'true', 'test_tunnel'),
    ('P1_portal_layer', T, '\t\tpi.layers = PORTAL_LAYERS', '\t\tpass', 'test_tunnel'),
]
os.makedirs(F + '/mutations', exist_ok=True)
env = dict(os.environ, XDG_DATA_HOME=F + '/xdg')
res = {}
for name, path, old, new, test in MUT:
    if len(sys.argv) > 1 and name not in sys.argv[1:]:
        continue
    full = os.path.join(WT, path)
    src = open(full, encoding='utf-8').read()
    assert src.count(old) == 1, (name, src.count(old))
    shutil.copy(full, F + '/mutations/backup.gd')
    try:
        open(full, 'w', encoding='utf-8').write(src.replace(old, new))
        p = subprocess.run(['nice', '-n', '10', 'timeout', '600', 'godot', '--headless', '--path', WT, '-s', 'res://tests/run_tests.gd', '--',
                            '--filter=' + test], capture_output=True, text=True, env=env)
        out = p.stdout + p.stderr
        open(F + '/mutations/%s.log' % name, 'w').write(out)
        summary = [l for l in out.splitlines() if 'Tests,' in l]
        caught_by = [l.split('::')[-1].strip() for l in out.splitlines() if l.startswith('FAIL')]
        res[name] = {'summary': summary[-1] if summary else '?', 'failed_tests': caught_by,
                     'script_errors': sum(1 for l in out.splitlines() if 'SCRIPT ERROR' in l)}
        print(name, res[name], flush=True)
    finally:
        shutil.copy(F + '/mutations/backup.gd', full)
json.dump(res, open(F + '/mutations/results.json', 'w'), indent=1, ensure_ascii=False)
