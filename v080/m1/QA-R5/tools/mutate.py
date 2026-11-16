#!/usr/bin/env python3
"""QA-R5 mutation runner: apply one mutation at a time to the scratch copy, run the unit test file that guards the
rule, record whether it fails, restore. Usage: mutate.py [id ...]  (no ids: all)"""
import json, os, shutil, subprocess, sys, time

Q = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5'
MUT = Q + '/mut'
OUT = Q + '/mutations'
os.makedirs(OUT, exist_ok=True)

B = 'scripts/race3d/builders/bridge.gd'
T = 'scripts/race3d/builders/tunnel.gd'
F = 'scripts/race3d/layers/far_ground.gd'
MUTS = [
    # id, file, old, new, test filter, rule
    ('B1_water_height', B, 'var ha := la + WATER_LIFT', 'var ha := la + WATER_LIFT + 0.5', 'test_bridge', 'water on the water rows'),
    ('B2_water_reach', B, 'for j in ctx.rings:\n\t\t\tvar xa := ring_x(ctx, ra, side, j)',
     'for j in mini(ctx.rings, 3):\n\t\t\tvar xa := ring_x(ctx, ra, side, j)', 'test_bridge', 'water out to the last ring'),
    ('B3_bank_rule', B, 'if bank != "":\n\t\tstyle = "slope"', 'if bank == "":\n\t\tstyle = "slope"', 'test_bridge', 'banks by Arcade rule'),
    ('B4_far_wall_faces', B, '_quay(wb, ctx, i + 1, i, zb, za, br, -1.0, counts)', '_quay(wb, ctx, i + 1, i, zb, za, br, 1.0, counts)',
     'test_bridge', 'far quay wall faces camera'),
    ('B5_pylon_scale', B, 'scaled_local(Vector3(1.0, hgt / PYLON_MODEL_H, 1.0))', 'scaled_local(Vector3(1.0, 1.0, 1.0))',
     'test_bridge', 'pylon height_m/88.8'),
    ('B6_beacon_height', B, 'var top := ctx.local(z, cx, hgt + PYLON_CAP_H + 0.12)', 'var top := ctx.local(z, cx, hgt - 8.0)',
     'test_bridge', 'beacon at height_m + 1.6'),
    ('B7_cable_lane', B, 'var x_deck := x - side * 1.4', 'var x_deck := x - side * 4.5', 'test_bridge', 'no cable over a lane'),
    ('B8_truss_lane', B, 'var xa := s * (ctx.shoulder_edge(i, side) + extra + TRUSS_OUT)',
     'var xa := s * (ctx.shoulder_edge(i, side) + extra + TRUSS_OUT - 3.0)', 'test_bridge', 'structure out of the lanes'),
    ('B9_edge_beam_lane', B, 'var xl_a := -(ctx.shoulder_edge(i, -1) + extra + RAIL_BACK_M)',
     'var xl_a := -(ctx.shoulder_edge(i, -1) + extra + RAIL_BACK_M) + 5.0', 'test_bridge', 'structure out of the lanes (edge beam)'),
    ('B10_dark_pylon', B, 'dup.set_shader_parameter("night_albedo", PYLON_NIGHT_ALBEDO)', 'pass', 'test_bridge', 'pylon dark at night'),
    ('B11_blink_phase', B, '"blink": Vector3(PYLON_BLINK.x, PYLON_BLINK.y, s * PYLON_BLINK.z)})',
     '"blink": Vector3(PYLON_BLINK.x, PYLON_BLINK.y, 0.0)})', 'test_bridge', 'blink phase per side'),
    ('B12_cables_count', B, 'const CABLES_PER_SIDE := 7', 'const CABLES_PER_SIDE := 5', 'test_bridge', '7 cables per side (Arcade)'),
    ('B13_portals_skip', B, '"truss_portal":\n\t\t\t\t\t_portal(', '"truss_portal_x":\n\t\t\t\t\t_portal(', 'test_bridge',
     'truss portals built'),
    ('B14_lamps_skip', B, '"bridge_lamp":\n\t\t\t\t\t_lamp(', '"bridge_lamp_x":\n\t\t\t\t\t_lamp(', 'test_bridge', 'bridge lamps built'),
    ('T1_niches', T, 'var niche := in_segment(z0, seg_len, NICHE_EVERY, 0.0)', 'var niche := false', 'test_tunnel', 'SOS niches'),
    ('T2_fans_low', T, 'var hc := maxf(_ceil_h - FAN_R - 0.16, FAN_MIN_BOTTOM + FAN_R)', 'var hc := 3.6', 'test_tunnel',
     'nothing of the tube over the road (fans)'),
    ('T3_cap_inside', T, 'cam_tunnel = float(ceili(track.km_to_z(float(t["start_km"])) / track.seg_len - 1.0e-6)) * track.seg_len',
     'cam_tunnel = -1.0e9', 'test_tunnel', 'cap only from outside'),
    ('T4_zone_guard', T, '(env as Object).has_method(&"set_zone")', 'true', 'test_tunnel', 'set_zone duck-typed'),
    ('T5_peek_cap', T, 'if z_cap >= z0 and z_cap < z1 and z_cap < z_end - seg_len:', 'if false:', 'test_tunnel', 'end cap at peek_m'),
    ('T6_portal', T, 'if seg == int(t[0]):\n\t\t\tcounts["portals"] += 1', 'if false:\n\t\t\tcounts["portals"] += 1', 'test_tunnel',
     'portal + hill'),
    ('F1_zs1_rule', F, 'return minf(lowest_road(path, cam_z, visibility_m) - _drop, water_y - WATER_MARGIN_M)',
     'return lowest_road(path, cam_z, visibility_m) - _drop', 'test_far_ground_water', 'ZS1 far ground below water'),
    ('F2_quay_copy', F, '"canal": Color("7a5648")', '"canal": Color("7a5649")', 'test_bridge', 'pinned Arcade quay copy'),
]


def run_test(filt):
    xdg = Q + '/tmp/xdg_mut'
    shutil.rmtree(xdg, ignore_errors=True)
    os.makedirs(xdg, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=xdg)
    t0 = time.time()
    p = subprocess.run(['nice', '-n', '10', 'timeout', '900', 'godot', '--headless', '--path', MUT, '-s', 'res://tests/run_tests.gd',
                        '--', '--filter=' + filt], capture_output=True, text=True, env=env)
    out = p.stdout + p.stderr
    summary = [l for l in out.splitlines() if 'Tests,' in l and 'fehlgeschlagen' in l]
    fails = [l for l in out.splitlines() if l.startswith('FAIL')]
    errs = [l for l in out.splitlines() if 'SCRIPT ERROR' in l or 'Parse Error' in l]
    return p.returncode, summary[-1] if summary else '?', fails, errs, time.time() - t0, out


def main():
    ids = sys.argv[1:]
    res = {}
    rpath = OUT + '/results.json'
    if os.path.exists(rpath):
        res = json.load(open(rpath))
    if not ids or 'baseline' in ids:
        for filt in ['test_bridge', 'test_tunnel', 'test_far_ground_water']:
            code, summ, fails, errs, dt, out = run_test(filt)
            open(OUT + '/baseline_%s.log' % filt, 'w').write(out)
            res['baseline_' + filt] = {'code': code, 'summary': summ, 'fails': fails, 'errs': errs[:3], 'secs': round(dt)}
            json.dump(res, open(rpath, 'w'), indent=1)
            print('baseline', filt, code, summ, round(dt), flush=True)
    for mid, f, old, new, filt, rule in MUTS:
        if ids and mid not in ids and 'all' not in ids:
            continue
        path = MUT + '/' + f
        src = open(path).read()
        n = src.count(old)
        if n != 1:
            res[mid] = {'error': 'pattern found %d times' % n}
            print(mid, 'PATTERN', n, flush=True)
            continue
        try:
            open(path, 'w').write(src.replace(old, new))
            code, summ, fails, errs, dt, out = run_test(filt)
        finally:
            open(path, 'w').write(src)
        open(OUT + '/%s.log' % mid, 'w').write(out)
        caught = code != 0 or len(fails) > 0
        res[mid] = {'rule': rule, 'test': filt, 'caught': caught, 'code': code, 'summary': summ, 'fails': fails[:6], 'errs': errs[:3],
                    'secs': round(dt)}
        json.dump(res, open(rpath, 'w'), indent=1)
        print(mid, 'CAUGHT' if caught else 'MISSED', summ, fails[:3], round(dt), flush=True)


main()
