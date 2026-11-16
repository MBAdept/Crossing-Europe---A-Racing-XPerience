#!/usr/bin/env python3
"""FIX-R5: does the exact network scan (check_tunnel_bridge.gd -- --full) catch a lost part? One mutation at a time in
the worktree, the scan of one stage, the file restored afterwards."""
import os, shutil, subprocess, json
WT = '/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-6'
F = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R5'
B = 'scripts/race3d/builders/bridge.gd'
T = 'scripts/race3d/builders/tunnel.gd'
MUT = [
    ('S_lamps_skip', B, '"bridge_lamp":\n\t\t\t\t\t_lamp(', '"bridge_lamp_x":\n\t\t\t\t\t_lamp(', 'kassel_wuerzburg'),
    ('S_cables_5', B, 'const CABLES_PER_SIDE := 7', 'const CABLES_PER_SIDE := 5', 'kiel_hamburg'),
    ('S_portals_skip', B, '"truss_portal":\n\t\t\t\t\t_portal(', '"truss_portal_x":\n\t\t\t\t\t_portal(', 'kiel_hamburg'),
    ('S_niches_off', T, 'var niche := in_segment(z0, seg_len, NICHE_EVERY, 0.0)', 'var niche := false', 'bern_mailand'),
    ('S_cap_off', T, 'if z_cap >= z0 and z_cap < z1 and z_cap < z_end - seg_len:', 'if false:', 'bern_mailand'),
]
env = dict(os.environ, XDG_DATA_HOME=F + '/xdg')
os.makedirs(F + '/mutations', exist_ok=True)
res = {}
for name, path, old, new, stage in MUT:
    full = os.path.join(WT, path)
    src = open(full, encoding='utf-8').read()
    assert src.count(old) == 1, name
    shutil.copy(full, F + '/mutations/backup_scan.gd')
    try:
        open(full, 'w', encoding='utf-8').write(src.replace(old, new))
        p = subprocess.run(['nice', '-n', '10', 'timeout', '600', 'godot', '--headless', '--path', WT, '-s',
                            'res://tests/race3d/render/check_tunnel_bridge.gd', '--', '--full', '--only-stage=' + stage],
                           capture_output=True, text=True, env=env)
        out = p.stdout + p.stderr
        open(F + '/mutations/%s.log' % name, 'w').write(out)
        lines = [l for l in out.splitlines() if l.startswith('MANGEL') or l.startswith('RENDER-CHECK ')]
        res[name] = {'exit': p.returncode, 'first': lines[:2]}
        print(name, p.returncode, lines[:1], flush=True)
    finally:
        shutil.copy(F + '/mutations/backup_scan.gd', full)
json.dump(res, open(F + '/mutations/results_scan.json', 'w'), indent=1, ensure_ascii=False)
